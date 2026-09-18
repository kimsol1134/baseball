#!/usr/bin/env python3
"""Stage the user-approved 2026-09 creative in the existing 1.2.10 version only."""
import hashlib
import json
import pathlib
import subprocess

repo=pathlib.Path(__file__).resolve().parents[1]
evidence=repo/'apps/ios/releases/1.2.10/evidence-b69'
creative=repo/'marketing/appstore/2026-09-refresh'
version='4f58916e-106d-4d32-9ffa-7acecdeae3fa'
locales=json.loads((evidence/'localizations-before.json').read_text())['data']
manifest=json.loads((creative/'manifest.json').read_text())
for item in manifest['screenshots']+manifest['previews']:
    p=creative/item['path']
    assert hashlib.sha256(p.read_bytes()).hexdigest()==item['sha256'],p

def run(args,name):
    p=subprocess.run(['asc',*args],capture_output=True,text=True)
    (evidence/(name+'.json')).write_text(p.stdout)
    (evidence/(name+'.stderr.txt')).write_text(p.stderr)
    if p.returncode: raise RuntimeError(f'{name}: {p.stderr[-1600:]}')
    return json.loads(p.stdout)

notes=(repo/'marketing/appstore/RELEASE_NOTES_1.2.10.md').read_text()
def section(lang):
    return notes.split(f'## whatsNew ({lang})',1)[1].split('\n## ',1)[0].strip()

for row in locales:
    locale=row['attributes']['locale'];identifier=row['id']
    lang='ko' if locale=='ko' else 'ja' if locale=='ja' else 'en'
    folder={'ko':'ko-KR','ja':'ja-JP','en':'en-US'}[lang]
    for kind in ['screenshots','video-previews']:
        run([kind,'list','--version-localization',identifier],f'{locale}-{kind}-before')
    for device,size in [('IPHONE_67','6.9'),('IPHONE_65','6.5')]:
        args=['screenshots','upload','--version-localization',identifier,'--path',str(creative/folder/f'screenshots-{size}'),'--device-type',device,'--replace']
        run([*args,'--dry-run'],f'{locale}-screens-{size}-plan')
        done=run(args,f'{locale}-screens-{size}-uploaded')
        print(f'SCREENSHOTS {locale} {size}: uploaded',flush=True)
        args=['video-previews','upload','--version-localization',identifier,'--path',str(creative/folder/'preview'/f'app-preview-{lang}-886x1920.mp4'),'--device-type',device,'--replace']
        run([*args,'--dry-run'],f'{locale}-video-{size}-plan')
        run(args,f'{locale}-video-{size}-uploaded')
        print(f'VIDEO {locale} {size}: uploaded',flush=True)
    run(['localizations','update','--version',version,'--locale',locale,'--whats-new',section(lang)],f'{locale}-notes-updated')
    print(f'NOTES {locale}: updated',flush=True)
