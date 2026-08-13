# App Store Connect Creative — English (U.S.)

This directory is the submission source for the English localization of the existing iOS App Store record. It combines actual English iOS app captures with deterministic Remotion layouts; it does not create a separate English product or alter the Korean listing.

## Intended deliverables

```text
en-US/
├── STORE_COPY.md
├── GAME_CENTER_COPY.md
├── SCREENSHOT_PLAN.md
├── manifest.json
├── preview/
│   ├── preview-en-US-886x1920.mp4
│   └── poster-en-US.png
├── screenshots-6.9/
│   └── 01.png … 07.png
├── screenshots-6.5/
│   └── 01.png … 07.png
└── evidence/
    ├── screenshots-contact-sheet.jpg
    └── preview-contact-sheet.jpg
```

Rendered files and the manifest are release evidence, not authorization to upload them. App Store Connect submission remains a separate manual action.

## Source of truth

- Store copy: `marketing/appstore/en-US/STORE_COPY.md`
- Game Center localization: `marketing/appstore/en-US/GAME_CENTER_COPY.md`
- Narrative and capture contract: `marketing/appstore/en-US/SCREENSHOT_PLAN.md`
- Remotion composition: `apps/promo/src/asc/StoreCreative.tsx`
- Composition registration: `apps/promo/src/Root.tsx`
- Actual English app captures: `apps/promo/public/asc/en-US/`
- Release verification and external handoff: `docs/IOS_ENGLISH_RELEASE_EVIDENCE_2026-08-13.md`

## Reproduce

After all eight actual English source captures are present (seven gallery states plus the separate
release-gesture state used by the preview):

```bash
cd apps/promo
npm run render:asc:en
```

The renders must be followed by media inspection, contact-sheet review, screenshot text audit, and checksum generation. A successful render alone is not release approval.

## Submission guardrails

- App Store primary language remains Korean.
- Add English (U.S.) as localized metadata on the existing app record and bundle ID.
- Do not upload or replace Korean media while preparing this directory.
- Do not publish a synthetic app screen, Korean UI with an English overlay, or a fixture that cannot occur in the app.
- Do not hard-code a storefront price in media.
- Do not imply affiliation with a real baseball league, club, school, or player.
- Confirm the support and privacy URLs show complete English content before submission.
- Verify the active App Store version and build again before entering metadata.

## Release gates

- Every visible app-owned string in the captures is English.
- Captured states match the current 1.1.0 build and the claims in `STORE_COPY.md`.
- The 6.9-inch and 6.5-inch sets each contain seven ordered RGB PNG files with no alpha channel.
- The preview passes current App Store media validation and communicates its core promise without sound.
- Contact sheets have been visually reviewed at full resolution.
- `manifest.json` matches the final bytes delivered to App Store Connect.
- No App Store upload occurs without explicit user authorization.
