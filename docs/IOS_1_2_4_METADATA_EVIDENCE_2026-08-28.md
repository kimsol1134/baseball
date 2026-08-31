# iOS 1.2.4 App Store metadata evidence

Checked 2026-08-28 (Asia/Seoul) against App Store Connect API.

## Scope

Only these two attributes were patched on the existing iOS 1.2.4 version:

- `appStoreVersionLocalizations.description`
- `appStoreVersionLocalizations.whatsNew`

No version was created, and no app-info localization, keyword, promotional text, screenshot,
app preview, build relationship, review submission, or release state was changed.

## ASC resources

| Version | Version resource | State at verification |
|---|---|---|
| 1.2.4 | `e6ef5f26-1919-445d-831a-2fb618906eca` | `PREPARE_FOR_SUBMISSION` |

| Locale | Localization resource | Description chars | What's New chars |
|---|---|---:|---:|
| `en-US` | `8ef1b6d9-6d54-4c7f-b23b-76347d24882e` | 2,216 | 497 |
| `en-GB` | `20286b16-28b4-4685-a256-a0cdc72302a5` | 2,216 | 497 |
| `en-AU` | `8c738d25-c83e-48c0-b43a-88d76c87c21e` | 2,216 | 497 |
| `en-CA` | `8bbc3238-c037-4ccf-98f6-29c2e793e957` | 2,216 | 497 |
| `ko` | `1807d426-b3f3-48de-b8ae-1c6e9ca19372` | 981 | 285 |
| `ja` | `cc304a07-7a8d-4187-afdf-1a22f9aa86d9` | 801 | 227 |

## Verification

The repository checker validates character limits, the 1–100 wording, separate mastery beyond the
base cap, and a small denylist of real league/team names:

```bash
node tools/asc-metadata-1-2-4.mjs check
node tools/asc-metadata-1-2-4.mjs verify
```

`verify` completed successfully for all six locales. English copy is intentionally identical across
`en-US`, `en-GB`, `en-AU`, and `en-CA`; Korean and Japanese are independently localized. The copy
describes injuries with cause/recovery/next-step guidance, compact repeated story explanations, and
readable 1–100 ratings with separate mastery progression; it does not claim infinite ability stats.
