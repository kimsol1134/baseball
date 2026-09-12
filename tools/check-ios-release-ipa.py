#!/usr/bin/env python3
"""Inspect a signed export without uploading it or treating inspection as release approval."""
import argparse, hashlib, json, pathlib, plistlib, shutil, subprocess, zipfile

def require(condition, message):
    if not condition:
        raise ValueError(message)

parser = argparse.ArgumentParser()
parser.add_argument('ipa', type=pathlib.Path)
parser.add_argument('--version', required=True)
parser.add_argument('--build', required=True)
parser.add_argument('--output', required=True, type=pathlib.Path)
args = parser.parse_args()
ipa = args.ipa.resolve()
inspection = ipa.parent / 'ipa-inspection'
if inspection.exists():
    raise SystemExit(f'Inspection directory already exists; verify it is inactive before removing: {inspection}')
inspection.mkdir()
try:
    with zipfile.ZipFile(ipa) as package:
        for item in package.infolist():
            path = pathlib.PurePosixPath(item.filename)
            if path.is_absolute() or '..' in path.parts:
                raise ValueError('Unsafe archive path')
        package.extractall(inspection)
    app, = list((inspection / 'Payload').glob('*.app'))
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    require(info['CFBundleIdentifier'] == 'com.solkim.baseball.ios', 'Unexpected bundle identifier')
    require(info['CFBundleShortVersionString'] == args.version, 'Marketing version mismatch')
    require(info['CFBundleVersion'] == args.build, 'Build number mismatch')
    require(info['ITSAppUsesNonExemptEncryption'] is False, 'Encryption declaration mismatch')
    verification = subprocess.run(['codesign', '--verify', '--deep', '--strict', '--verbose=2', str(app)], capture_output=True, text=True)
    if verification.returncode:
        raise RuntimeError(verification.stderr)
    entitlement_data = subprocess.check_output(['codesign', '-d', '--entitlements', ':-', str(app)], stderr=subprocess.DEVNULL)
    entitlements = plistlib.loads(entitlement_data)
    require(entitlements.get('get-task-allow') is False, 'Development debugging entitlement in distribution export')
    require(entitlements['application-identifier'] == 'D48DDX5D5W.com.solkim.baseball.ios', 'Signed app identifier mismatch')
    require(entitlements.get('com.apple.developer.game-center') is True, 'Missing Game Center entitlement')
    require(entitlements['com.apple.developer.ubiquity-kvstore-identifier'] == 'D48DDX5D5W.com.solkim.baseball.ios', 'Cloud store identifier mismatch')
    profile = plistlib.loads(subprocess.check_output(['security', 'cms', '-D', '-i', str(app / 'embedded.mobileprovision')], stderr=subprocess.DEVNULL))
    require(not profile.get('ProvisionedDevices'), 'Device-only provisioning profile')
    require(not profile.get('ProvisionsAllDevices'), 'Enterprise provisioning profile')
    locales = {}
    for language in ['ko', 'en', 'ja']:
        folder = app / (language + '.lproj')
        localizable = plistlib.loads((folder / 'Localizable.strings').read_bytes())
        content = plistlib.loads((folder / 'GameContent.strings').read_bytes())
        system = plistlib.loads((folder / 'InfoPlist.strings').read_bytes())
        require(bool(system.get('CFBundleDisplayName')), f'Missing {language} app name')
        require((folder / 'LaunchScreenV2.storyboardc').exists(), f'Missing {language} launch screen')
        for key in ['record.album.play', 'record.album.catcher-view', 'record.saber.era']:
            require(bool(localizable.get(key)), f'Missing {language} {key}')
        role = content['content.pro-milestone.season-role']
        require('%1$lld' in role and '%2$@' in role, f'Unsafe {language} season-role format')
        locales[language] = {'displayName': system['CFBundleDisplayName'], 'localizableCount': len(localizable),
                             'gameContentCount': len(content), 'albumPlay': localizable['record.album.play'],
                             'seasonRole': role, 'launchScreen': True}
    binary = app / info['CFBundleExecutable']
    architecture = subprocess.check_output(['lipo', '-archs', str(binary)], text=True).strip()
    require(architecture == 'arm64', 'Unexpected architecture')
    binary_strings = subprocess.check_output(['strings', '-a', str(binary)], text=True)
    require('invalid_mixed_positioning' in binary_strings, 'Latest format guard missing')
    require('-uiTestPopulatedProFixture' not in binary_strings, 'Debug fixture in distribution export')
    result = {'version': args.version, 'build': args.build, 'bundleID': info['CFBundleIdentifier'],
              'sha256': hashlib.sha256(ipa.read_bytes()).hexdigest(), 'ipaBytes': ipa.stat().st_size,
              'architecture': architecture, 'signatureVerified': True, 'debuggingAllowed': False,
              'profileName': profile['Name'], 'profileExpires': profile['ExpirationDate'].isoformat(),
              'localizations': locales, 'latestRuntimeFormatGuardPresent': True, 'debugProFixtureAbsent': True,
              'deviceJapaneseSmoke': 'not verified by this inspection',
              'targetAppStoreJapaneseDisplay': 'not verified by this inspection'}
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(result, ensure_ascii=False, indent=2))
finally:
    # This tool created the unpacked copy and no process runs from it. The IPA remains intact.
    shutil.rmtree(inspection)
