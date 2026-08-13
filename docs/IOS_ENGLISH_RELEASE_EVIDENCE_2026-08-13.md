# iOS English Release Evidence — 2026-08-13

## Release identity

| Item | Verified value |
|---|---|
| Product | Existing paid iOS app; no separate English SKU or target |
| App Store Connect app | `6794754217` |
| Bundle ID | `com.solkim.baseball.ios` |
| App Store version ID | `a5e34851-ad52-43d6-b8aa-399707ae25ff` |
| App version | `1.1.1` |
| Release build | `52` (`55f1bf9c-3b05-45be-94be-1ed1a73269ba`) |
| Development region | `ko` |
| App languages | `ko`, `en` in the same binary |
| English home-screen name | `Mound Reborn` |
| English App Store name | `Mound Reborn: Baseball Career` |
| Release mode | Manual release after approval; seven-day phased release configured |
| Save/gameplay contract | Existing IDs, save data, event order, outcomes, and paid SKU retained |

The signed distribution IPA contains both `ko.lproj` and `en.lproj`, including compiled
`Localizable.strings`, `GameContent.strings`, and `InfoPlist.strings`. Its `Info.plist` reports version
`1.1.1`, build `52`, minimum iOS `17.0`, and `ITSAppUsesNonExemptEncryption=false`. Distribution
signature verification passed with `get-task-allow=false`, Game Center, and iCloud KVS entitlements.

## Implemented product scope

- iOS follows the system app-language setting; there is no in-app language selector.
- Static UI, game content, pitching, high-school conclusion, draft, rebirth, legacy, professional
  career, records, weekly/meta systems, reminders, sharing, errors, and accessibility presentation
  have English display paths.
- User-entered names and seeds are preserved verbatim.
- Existing save keys, stable content IDs, Game Center identifiers, and simulation rules remain shared
  between Korean and English.
- Analytics events keep their existing names and include `app_language` and `copy_schema_version`.
- The release fallback policy does not expose Korean app-owned copy in English.

## Automated verification

| Gate | Result |
|---|---|
| iOS localization inventory | 3,228 reviewed literals; 3,154 catalog entries; 0 pending accessibility, app UI, notification, or core-game-copy surfaces |
| `check:ios-localization` | Passed; 3,154 catalog entries and zero pending surfaces |
| `check:copy` | Passed; internal terms and 42 real-baseball-IP terms not exposed |
| `check:dialogue-parity` | Passed; all nine three-stage relationship scenes match the core |
| SimulationCore tests | 359 passed, 0 failed |
| iOS unit tests | 407 passed, 0 failed |
| English UI fixtures | Pitch, undrafted/rebirth, and drafted completion fixtures passed on iPhone 17 Pro Max simulator |
| Korean UI smoke | Deterministic pitch flow passed with explicit `ko-KR` launch language |
| Signed archive and IPA | Release archive/export succeeded; bundle, version, build, languages, entitlements, and distribution signature verified |
| App Store submission validation | 0 errors, 0 warnings, 0 blockers after setting `socialMediaAgeRestricted=false` on the unchanged no-social-media age declaration |
| Landing pages | Production deployment passed; `/en/support` and `/en/privacy` return HTTP 200 |
| Patch hygiene | `git diff --check` passed |

Known non-blocking build noise: Xcode 26 emits Swift 6 actor-isolation warnings from existing UI-test
helpers. Tests and builds complete successfully; this warning cleanup is outside the localization
change.

## App Store media evidence

Source directory: `marketing/appstore/en-US/`

- 8 actual English iOS simulator captures at 1,320 × 2,868; RGB, no alpha.
- 7 screenshots for 6.9-inch displays at 1,320 × 2,868.
- 7 screenshots for 6.5-inch displays at 1,284 × 2,778.
- 27.6-second, 886 × 1,920, 30 fps H.264 High Profile Level 4.0 preview with stereo AAC.
- The original Remotion MP4 contained a 5.9-second audio track inside a 27.6-second video and Apple
  rejected it as `MOV_RESAVE_CORRUPTED`. `prepare-asc-preview.mjs` produces a clean MOV with a
  full-length stereo track; Apple accepted it with asset state `COMPLETE`.
- Preview product scenes use actual English iOS captures only. Marketing copy and motion are layered
  around those captures; no synthetic app UI or Korean app screen remains.
- macOS Vision OCR found zero Hangul syllables across all 14 final screenshots and 28 one-second
  preview samples.
- Each of `en-US`, `en-GB`, `en-CA`, and `en-AU` has 14 `COMPLETE` screenshots and one `COMPLETE`
  app preview in App Store Connect: 56 screenshots and four preview assets total.
- `manifest.json` records final sizes, checksums, version/build, and completed upload authorization.

Primary files:

- `marketing/appstore/en-US/STORE_COPY.md`
- `marketing/appstore/en-US/GAME_CENTER_COPY.md`
- `marketing/appstore/en-US/SCREENSHOT_PLAN.md`
- `marketing/appstore/en-US/manifest.json`
- `marketing/appstore/en-US/evidence/screenshots-contact-sheet.jpg`
- `marketing/appstore/en-US/evidence/preview-contact-sheet.jpg`

## External release actions completed

| Action | Result |
|---|---|
| English web pages | Vercel production deployment `dpl_9pzjWk3cMoo1XEfRf8CmTTzvNFiw`; alias `https://baseball-reincarnation.vercel.app` |
| TestFlight backup | Version 1.1.0 build 51 uploaded and processed as `VALID`; English What to Test notes added |
| TestFlight release candidate | Version 1.1.1 build 52 uploaded and processed as `VALID`; internal group `내부 테스트` has access to all builds |
| TestFlight app localization | `en-US` description, feedback email, support URL, and privacy URL added |
| Game Center | `en-US` added to 15 existing achievements and four existing leaderboards; identifiers, points, rules, and records unchanged |
| Previous review | Submission `3da655b8-d65e-4c7d-8681-c6b3f915fb51` canceled by owner request; terminal state `COMPLETE` |
| New review | Submission `413eeac9-8127-4f58-9ae7-4b26fc5b66e3` submitted at `2026-08-13T06:30:19.01Z`; state `WAITING_FOR_REVIEW` |

The same App Store version record was changed from 1.1.0 to 1.1.1 after cancellation, preserving the
existing Korean and Japanese localizations and media. Build 52 was attached. Four English App Info
and version localizations were added: U.S., U.K., Canada, and Australia.

Post-write regression checks:

- Korean version-localization hash: `79aa29445c176637d95400110ce91392190f4a9a7f12e199edb77846dc259068`.
- Japanese version-localization hash: `dceee188721936154696a7b690db48402043312eb0ea08fb1e930ac2c84dd789`.
- Korean and Japanese names, subtitles, and privacy URLs remain unchanged.
- Paid price remains KRW 4,400 in base territory Korea; the app was not made free.
- Availability remains enabled in all 175 configured territories. USA, Canada, U.K., Australia, New
  Zealand, Ireland, and Singapore all report `AVAILABLE`.
- Release remains manual after approval. Phased release exists in `INACTIVE` state and starts only
  when the approved version is manually released.

## Remaining owner action

1. Install TestFlight version 1.1.1 build 52 and complete the planned real-device English pass.
2. If a release-blocking issue is found, cancel the in-flight review before uploading a replacement
   build. Otherwise leave the submission in review.
3. After approval, perform the explicit manual release; the configured seven-day phased rollout will
   then begin.

No Git stage, commit, or push was performed.
