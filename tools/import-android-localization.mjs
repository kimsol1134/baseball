#!/usr/bin/env node
// Import the reviewed iOS translations as semantic keys. Android-only copy stays in a
// separate reviewed catalogue; generating this file never changes simulation state.
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { createHash } from "node:crypto";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const entries = {};
const sourceIndex = {};
for (const name of ["Localizable", "GameContent"]) {
  const data = JSON.parse(readFileSync(resolve(root, `apps/ios/Sources/Presentation/Localization/${name}.xcstrings`), "utf8"));
  for (const [key, value] of Object.entries(data.strings)) {
    const translations = Object.fromEntries(["ko", "en", "ja"].map(language => [language, value.localizations?.[language]?.stringUnit?.value]));
    if (!Object.values(translations).every(value => typeof value === "string" && value.length)) continue;
    entries[key] = translations;
    sourceIndex[translations.ko] = key;
    // Shared authored scenes retain the player token until after language resolution.
    if (key.startsWith("content.relationship.") && key.includes(".quote.") && translations.ko.includes("%@")) {
      const playerKey = `${key}.android-player`;
      entries[playerKey] = Object.fromEntries(Object.entries(translations).map(([language, text]) => [language, text.replaceAll("%@", "{player}")]));
      sourceIndex[entries[playerKey].ko] = playerKey;
    }
  }
}
const overrides = JSON.parse(readFileSync(resolve(root, "docs/localization/android-copy.json"), "utf8"));
const legacyRows = JSON.parse(readFileSync(resolve(root, "docs/localization/android-legacy-copy.json"), "utf8"));
for (const [ko, en, ja] of legacyRows) {
  if (![ko, en, ja].every(value => typeof value === "string" && value.length)) throw Error("Incomplete legacy translation");
  const key = `android.legacy.${createHash("sha256").update(ko).digest("hex").slice(0, 16)}`;
  entries[key] = { ko, en, ja };
  sourceIndex[ko] = key;
}
for (const [key, translations] of Object.entries(overrides)) {
  if (!["ko", "en", "ja"].every(language => typeof translations[language] === "string" && translations[language].length)) throw Error(`Incomplete Android translation: ${key}`);
  entries[key] = translations;
  sourceIndex[translations.ko] = key;
}
const target = resolve(root, "apps/android/game-application/src/main/resources/localization/game-copy.json");
// Editorial aliases also cover sentences already saved by older versions. Only presentation
// changes; simulation text and commitments remain byte-for-byte intact.
const playerRows = JSON.parse(readFileSync(resolve(root, "docs/localization/android-player-copy.json"), "utf8"));
for (const [source, ko, en, ja] of playerRows) {
  if (![source, ko, en, ja].every(value => typeof value === "string" && value.length)) throw Error("Incomplete player copy");
  const key = `android.player.${createHash("sha256").update(source).digest("hex").slice(0, 16)}`;
  entries[key] = { ko, en, ja };
  sourceIndex[source] = key;
  sourceIndex[ko] = key;
}
mkdirSync(dirname(target), { recursive: true });
const ordered = object => Object.fromEntries(Object.entries(object).sort(([a], [b]) => a.localeCompare(b, "en")));
const bytes = JSON.stringify({ schemaVersion: 1, entries: ordered(entries), legacySourceIndex: ordered(sourceIndex) }) + "\n";
if (process.argv.includes("--check")) {
  if (readFileSync(target, "utf8") !== bytes) throw Error("Android copy catalogue is out of date; run tools/import-android-localization.mjs");
} else writeFileSync(target, bytes);
console.log(`Android semantic copy catalogue: ${Object.keys(entries).length} ko/en/ja entries`);
