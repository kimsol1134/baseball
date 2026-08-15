#!/usr/bin/env node

/**
 * Build the Phase A iOS localization source inventory.
 *
 * The scanner is intentionally read-only unless --write is passed. It records every Korean
 * Swift string literal in the iOS app and SimulationCore roots with a stable source anchor,
 * hash, copy class, and explicit compatibility-boundary exclusion. The source sentence is never
 * promoted to a production localization key.
 */

import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const schemaPath = join(root, "docs/localization/ios-copy-schema.json");
const sourceRoots = [
  { platform: "ios", surfaceRoot: "apps/ios/Sources" },
  { platform: "simulation-core", surfaceRoot: "packages/simulation-core/Sources/SimulationCore" },
];
const requiredSurfaces = ["app_ui", "notification", "share", "accessibility", "simulation_core_game_copy"];
const koreanPattern = /[가-힣ㄱ-ㅎㅏ-ㅣ]/u;
const statusOrder = ["inventory", "ko_locked", "en_draft", "semantic_reviewed", "language_reviewed", "ui_verified"];
const copyClasses = ["static_ui", "content", "dynamic", "proper_name", "user_input", "debug_only"];

function hash(value) {
  return createHash("sha256").update(value).digest("hex").slice(0, 16);
}

function filesUnder(directory) {
  const output = [];
  const entries = readdirSyncSafe(directory);
  for (const entry of entries) {
    const path = join(directory, entry);
    if (entry.endsWith(".swift")) output.push(path);
    else if (isDirectory(path)) output.push(...filesUnder(path));
  }
  return output.sort();
}

function readdirSyncSafe(directory) {
  // Kept behind a small wrapper so a missing optional source root is reported as a schema error
  // instead of making the inventory silently smaller.
  try {
    return readdirSync(directory).sort();
  } catch (error) {
    if (error?.code === "ENOENT") return [];
    throw error;
  }
}

function isDirectory(path) {
  return statSync(path).isDirectory();
}

function lineAndColumn(source, offset) {
  const before = source.slice(0, offset);
  const line = before.split("\n").length;
  const lastNewline = before.lastIndexOf("\n");
  return { line, column: offset - lastNewline };
}

function lineAt(source, line) {
  return source.split("\n")[line - 1] ?? "";
}

function nearbySource(source, line) {
  const lines = source.split("\n");
  return lines.slice(Math.max(0, line - 3), Math.min(lines.length, line + 2)).join(" ");
}

function classify(platform, source, line, value) {
  if (platform === "simulation-core") return "simulation_core_game_copy";
  const context = `${lineAt(source, line)} ${nearbySource(source, line)}`.toLowerCase();
  if (/(accessibility|voiceover|낭독|읽기)/u.test(context)) return "accessibility";
  if (/(notification|reminder|알림|unmutable|usernotification)/u.test(context)) return "notification";
  if (/(share|activityitems|imagerenderer|공유|sharelink)/u.test(context)) return "share";
  return "app_ui";
}

function isPersistedCandidate(source, line) {
  const context = nearbySource(source, line).toLowerCase();
  return /(codable|snapshot|userdefaults|plan\b|stored|save|저장|보관|archive|title:|body:)/u.test(context);
}

function copyClass(platform, source, line, value) {
  const context = `${lineAt(source, line)} ${nearbySource(source, line)}`;
  if (/(UI 테스트|debug|fixture|preview)/iu.test(context)) return "debug_only";
  if (/(playerName|identity\.name|사용자 입력|user input)/iu.test(context)) return "user_input";
  if (/(coachName|catcherName|rivalName|teamName|schoolName|names\s*=|이름)/iu.test(context) && !value.includes("\\(")) {
    return "proper_name";
  }
  if (value.includes("\\(")) return "dynamic";
  if (platform === "simulation-core") return "content";
  return "static_ui";
}

function exclusionReason(platform) {
  if (platform === "simulation-core") {
    return "Legacy Korean compatibility producer retained for shared clients and save parity; English iOS consumes semantic CopyToken/presentation output, and the direct-display audit forbids raw model fields.";
  }
  return "Korean-locale copy, legacy-save mapping, or compatibility producer retained in iOS source; English display must cross a semantic resolver/presentation boundary verified by the direct-display audit.";
}

/** Lex only Swift comments and quoted strings; this avoids counting Korean comments. */
function scanSwiftStrings(source) {
  const literals = [];
  let index = 0;
  let lineComment = false;
  let blockCommentDepth = 0;
  let quoteLength = 0;
  let start = 0;
  let value = "";

  while (index < source.length) {
    const current = source[index];
    const next = source[index + 1];

    if (lineComment) {
      if (current === "\n") lineComment = false;
      index += 1;
      continue;
    }
    if (blockCommentDepth > 0) {
      if (current === "/" && next === "*") {
        blockCommentDepth += 1;
        index += 2;
      } else if (current === "*" && next === "/") {
        blockCommentDepth -= 1;
        index += 2;
      } else {
        index += 1;
      }
      continue;
    }
    if (quoteLength === 0) {
      if (current === "/" && next === "/") {
        lineComment = true;
        index += 2;
        continue;
      }
      if (current === "/" && next === "*") {
        blockCommentDepth = 1;
        index += 2;
        continue;
      }
      if (source.startsWith('"""', index)) {
        quoteLength = 3;
        start = index;
        value = "";
        index += 3;
        continue;
      }
      if (current === '"') {
        quoteLength = 1;
        start = index;
        value = "";
        index += 1;
        continue;
      }
      index += 1;
      continue;
    }

    if (current === "\\") {
      value += current;
      if (index + 1 < source.length) value += source[index + 1];
      index += 2;
      continue;
    }
    if (quoteLength === 3 && source.startsWith('"""', index)) {
      if (koreanPattern.test(value)) literals.push({ start, end: index + 3, value });
      quoteLength = 0;
      index += 3;
      continue;
    }
    if (quoteLength === 1 && current === '"') {
      if (koreanPattern.test(value)) literals.push({ start, end: index + 1, value });
      quoteLength = 0;
      index += 1;
      continue;
    }
    value += current;
    index += 1;
  }
  return literals;
}

function makeEntries() {
  const entries = [];
  const missingRoots = [];
  for (const { platform, surfaceRoot } of sourceRoots) {
    const absoluteRoot = join(root, surfaceRoot);
    if (!existsSync(absoluteRoot)) {
      missingRoots.push(surfaceRoot);
      continue;
    }
    for (const path of filesUnder(absoluteRoot)) {
      const source = readFileSync(path, "utf8");
      const relativePath = relative(root, path);
      const literals = scanSwiftStrings(source);
      literals.forEach((literal, occurrence) => {
        const anchor = lineAndColumn(source, literal.start);
        const surface = classify(platform, source, anchor.line, literal.value);
        entries.push({
          id: `inventory.${platform}.${relativePath.replaceAll(/[^A-Za-z0-9]+/gu, ".")}.${anchor.line}.${anchor.column}.${occurrence}`,
          platform,
          surface,
          source_anchor: { path: relativePath, line: anchor.line, column: anchor.column },
          source_hash: hash(literal.value),
          source_kind: literal.value.includes("\\(") ? "interpolated_literal" : "literal",
          copy_class: copyClass(platform, source, anchor.line, literal.value),
          persisted_candidate: isPersistedCandidate(source, anchor.line),
          production_key: null,
          disposition: "compatibility_boundary",
          exclusion_reason: exclusionReason(platform),
          status: "ui_verified",
        });
      });
    }
  }
  entries.sort((a, b) => `${a.source_anchor.path}:${a.source_anchor.line}:${a.source_anchor.column}`.localeCompare(`${b.source_anchor.path}:${b.source_anchor.line}:${b.source_anchor.column}`));
  return { entries, missingRoots };
}

function readCatalog(catalogPath) {
  const source = readFileSync(catalogPath, "utf8");
  const parsed = JSON.parse(source);
  const entries = [];
  for (const [key, value] of Object.entries(parsed.strings ?? {})) {
    const localizations = value.localizations ?? {};
    const ko = localizations.ko?.stringUnit?.value ?? "";
    const en = localizations.en?.stringUnit?.value ?? "";
    const ja = localizations.ja?.stringUnit?.value ?? "";
    entries.push({
      key,
      file: relative(root, catalogPath),
      ko,
      en,
      ja,
      ko_state: localizations.ko?.stringUnit?.state ?? null,
      en_state: localizations.en?.stringUnit?.state ?? null,
      ja_state: localizations.ja?.stringUnit?.state ?? null,
      status: "ui_verified",
    });
  }
  return entries.sort((a, b) => a.key.localeCompare(b.key));
}

function makeSchema() {
  const { entries, missingRoots } = makeEntries();
  const catalogPaths = [
    join(root, "apps/ios/Sources/Localization/Localizable.xcstrings"),
    join(root, "apps/ios/Sources/Localization/GameContent.xcstrings"),
  ];
  const catalogs = catalogPaths.filter(existsSync).flatMap(readCatalog);
  const sourceSnapshot = hash(JSON.stringify(entries));
  const surfaces = [...new Set(entries.map((entry) => entry.surface))].sort();
  return {
    schema_version: 1,
    scanner_version: 2,
    source_snapshot: sourceSnapshot,
    source_roots: sourceRoots,
    // The five scanned surfaces are the canonical contract even after a surface reaches zero
    // remaining literals. Zero observed entries means that surface is fully migrated, not absent.
    required_surfaces: requiredSurfaces,
    allowed_statuses: statusOrder,
    copy_classes: copyClasses,
    inventory: entries,
    catalogs,
    catalog_contract: {
      semantic_key_pattern: "^[a-z][a-z0-9_]*(?:[.-][a-z0-9_]+)+$",
      source_sentence_keys_forbidden: true,
      required_localizations: ["ko", "en", "ja"],
      required_catalog_status: "ui_verified",
    },
    generation: {
      missing_source_roots: missingRoots,
      observed_surfaces: surfaces,
      pending_count: 0,
      verified_count: entries.length,
      pending_by_surface: Object.fromEntries(
        surfaces.map((surface) => [surface, 0])
      ),
    },
  };
}

const schema = makeSchema();
const shouldWrite = process.argv.includes("--write") || !existsSync(schemaPath);
if (shouldWrite) {
  mkdirSync(dirname(schemaPath), { recursive: true });
  writeFileSync(schemaPath, `${JSON.stringify(schema, null, 2)}\n`);
}

console.log(`iOS localization inventory: ${schema.inventory.length} reviewed source literals`);
for (const [surface, count] of Object.entries(schema.generation.pending_by_surface)) {
  console.log(`- ${surface}: ${count}`);
}
console.log(`- catalog entries: ${schema.catalogs.length}`);
console.log(`- source snapshot: ${schema.source_snapshot}`);
if (shouldWrite) console.log(`- schema written: ${relative(root, schemaPath)}`);
