# English App Store Screenshot and Preview Plan

The English media keeps the Korean product page's seven-step story and uses only screenshots captured from the real iOS app running in English. English captions over Korean UI and reconstructed marketing-only app screens are not acceptable.

## Gallery order

| # | Headline | Supporting line | Real app state | Buyer question answered |
|---:|---|---|---|---|
| 1 | `ONE PITCH LEFT` | `Choose it. Throw it.` | Pitch result and strike zone | Do I actually make pitching decisions? |
| 2 | `THREE YEARS. NO GUARANTEES.` | `Miss the cut. Your name goes uncalled.` | Undrafted result | Do my choices have real stakes? |
| 3 | `FAILURE STILL LEAVES SOMETHING` | `This career ends. The next one begins.` | Rebirth transition | What makes this career game different? |
| 4 | `BUILT FROM THE CAREER YOU PLAYED` | `Carry one legacy into the next life.` | Signature legacy selection | Is rebirth more than a reset? |
| 5 | `HITTERS REMEMBER YOUR PATTERNS` | `They adjust. So must you.` | Pitch, location, and sign choice | Is pitching more than repeating the best option? |
| 6 | `A NEW PLAYER. NOT A BLANK SLATE.` | `Your last failure becomes a head start.` | Next player's inherited opening state | Does progress survive between careers? |
| 7 | `ANOTHER CAREER. ANOTHER DRAFT.` | `Will they call your name this time?` | Successful draft reveal | Is there a complete payoff to pursue? |

## First-three-frame contract

The first three assets must read as one compact promise even when a visitor sees nothing else:

1. The player directly controls an important pitch.
2. A three-year career can still end without a draft selection.
3. Failure becomes useful progress through rebirth.

The product name and screenshot story should therefore agree before the visitor reaches the longer description.

## Real-app capture contract

- Launch with `-AppleLanguages (en)` and `-AppleLocale en_US`.
- Capture deterministic fixtures from the current Release-equivalent iOS build.
- Keep system bars, debug overlays, test identifiers, and personal information out of frame.
- Do not expose Korean app-owned text anywhere in the image or accessibility tree.
- User-entered text may be preserved verbatim, but store fixtures should use neutral Latin-script names.
- Use the same fictional clubs, schools, competitions, and characters as the product. Never add a real league or team reference to a caption.
- Retain the original screenshot pixels inside the device frame; Remotion may crop, scale, grade, and add marketing typography but may not alter game state or replace product UI.

Expected source capture directory:

```text
apps/promo/public/asc/en-US/
├── pitch-strike.png
├── draft-failure.png
├── rebirth.png
├── legacy-choice.png
├── next-life.png
├── pitch-decision.png
├── release-gesture.png
└── draft-success.png
```

## Preview structure

The app preview is designed for silent autoplay and tells the same story as the gallery:

```text
direct pitch → undrafted result → rebirth → legacy → hitter adjustment → next player → drafted result
```

- Make the genre and direct pitching interaction clear in the opening seconds.
- Put all essential claims on screen; audio is atmosphere, not required information.
- End with `Mound Reborn`, `Build. Fail. Return.`, and `Premium game · No ads · No in-app purchases`.
- Do not show a fixed price because storefront pricing can change independently of the video.
- Keep every claim demonstrable in the captured build.

## Conversion hypotheses

- H1: A real strike-zone interaction first reduces the risk that visitors mistake the product for a passive text-only simulation.
- H2: Showing the undrafted outcome before rebirth makes the loop understandable and gives the restart emotional weight.
- H3: Showing inherited progress before the successful draft makes rebirth feel like a playable system rather than a narrative slogan.
- H4: Stating the premium model at the close reduces uncertainty about ads and additional purchases without anchoring a regional price.

## Render targets

- App preview composition: `ASCPreviewEN`, 886×1920, 30 fps.
- 6.9-inch screenshots: `ASCScreenshots69EN`, 1320×2868.
- 6.5-inch screenshots: `ASCScreenshots65EN`, 1284×2778.
- Output root: `marketing/appstore/en-US/`.

The final manifest must record each file's dimensions, media format, duration when applicable, and SHA-256 checksum.
