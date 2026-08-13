#!/usr/bin/env node

/** Strict Phase A localization gate plus an explicit schema-only mode. */

import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { fileURLToPath } from "node:url";
import { createHash } from "node:crypto";

const root = fileURLToPath(new URL("..", import.meta.url));
const schemaPath = join(root, "docs/localization/ios-copy-schema.json");
const schemaOnly = process.argv.includes("--schema-only");
const koreanPattern = /[가-힣ㄱ-ㅎㅏ-ㅣ]/u;
const allowedStatuses = ["inventory", "ko_locked", "en_draft", "semantic_reviewed", "language_reviewed", "ui_verified"];
const requiredSurfaces = ["app_ui", "notification", "share", "accessibility", "simulation_core_game_copy"];
const allowedCopyClasses = ["static_ui", "content", "dynamic", "proper_name", "user_input", "debug_only"];
const statusIndex = new Map(allowedStatuses.map((value, index) => [value, index]));

function hash(value) {
  return createHash("sha256").update(value).digest("hex").slice(0, 16);
}

function readJSON(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

function swiftFiles(directory) {
  if (!existsSync(directory)) return [];
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) return swiftFiles(path);
    return entry.name.endsWith(".swift") ? [path] : [];
  }).sort();
}

function placeholderSignature(value) {
  const matches = new Map();
  let sequentialIndex = 1;
  for (let index = 0; index < value.length; index += 1) {
    if (value[index] !== "%") continue;
    if (value[index + 1] === "%") {
      index += 1;
      continue;
    }
    const match = value.slice(index).match(/^%(?:(\d+)\$)?[-+ #0]*\d*(?:\.\d+)?l{0,2}([@diufFeEgG])/u);
    if (!match) continue;
    const argumentIndex = match[1] ? Number(match[1]) : sequentialIndex++;
    const conversion = match[2];
    const kind = conversion === "@" ? "string" : "diu".includes(conversion) ? "integer" : "decimal";
    const previous = matches.get(argumentIndex);
    matches.set(argumentIndex, previous && previous !== kind ? `${previous}|${kind}` : kind);
    index += match[0].length - 1;
  }
  return [...matches.entries()].sort(([left], [right]) => left - right).map(([, kind]) => kind);
}

function swiftCodeMask(source) {
  const output = [...source];
  let index = 0;
  let lineComment = false;
  let blockCommentDepth = 0;
  let quoteLength = 0;
  while (index < source.length) {
    const current = source[index];
    const next = source[index + 1];
    if (lineComment) {
      if (current === "\n") lineComment = false;
      else output[index] = " ";
      index += 1;
      continue;
    }
    if (blockCommentDepth > 0) {
      output[index] = current === "\n" ? "\n" : " ";
      if (current === "/" && next === "*") {
        output[index + 1] = " ";
        blockCommentDepth += 1;
        index += 2;
      } else if (current === "*" && next === "/") {
        output[index + 1] = " ";
        blockCommentDepth -= 1;
        index += 2;
      } else index += 1;
      continue;
    }
    if (quoteLength > 0) {
      output[index] = current === "\n" ? "\n" : " ";
      if (current === "\\") {
        if (index + 1 < source.length) output[index + 1] = source[index + 1] === "\n" ? "\n" : " ";
        index += 2;
      } else if (quoteLength === 3 && source.startsWith('"""', index)) {
        output[index] = output[index + 1] = output[index + 2] = " ";
        quoteLength = 0;
        index += 3;
      } else if (quoteLength === 1 && current === '"') {
        quoteLength = 0;
        index += 1;
      } else index += 1;
      continue;
    }
    if (current === "/" && next === "/") {
      output[index] = output[index + 1] = " ";
      lineComment = true;
      index += 2;
    } else if (current === "/" && next === "*") {
      output[index] = output[index + 1] = " ";
      blockCommentDepth = 1;
      index += 2;
    } else if (source.startsWith('"""', index)) {
      output[index] = output[index + 1] = output[index + 2] = " ";
      quoteLength = 3;
      index += 3;
    } else if (current === '"') {
      output[index] = " ";
      quoteLength = 1;
      index += 1;
    } else index += 1;
  }
  return output.join("");
}

function invocationEnd(source, openParen) {
  let depth = 0;
  let index = openParen;
  let lineComment = false;
  let blockCommentDepth = 0;
  let quoteLength = 0;
  while (index < source.length) {
    const current = source[index];
    const next = source[index + 1];
    if (lineComment) {
      if (current === "\n") lineComment = false;
      index += 1;
      continue;
    }
    if (blockCommentDepth > 0) {
      if (current === "/" && next === "*") { blockCommentDepth += 1; index += 2; }
      else if (current === "*" && next === "/") { blockCommentDepth -= 1; index += 2; }
      else index += 1;
      continue;
    }
    if (quoteLength > 0) {
      if (current === "\\") index += 2;
      else if (quoteLength === 3 && source.startsWith('"""', index)) { quoteLength = 0; index += 3; }
      else if (quoteLength === 1 && current === '"') { quoteLength = 0; index += 1; }
      else index += 1;
      continue;
    }
    if (current === "/" && next === "/") { lineComment = true; index += 2; continue; }
    if (current === "/" && next === "*") { blockCommentDepth = 1; index += 2; continue; }
    if (source.startsWith('"""', index)) { quoteLength = 3; index += 3; continue; }
    if (current === '"') { quoteLength = 1; index += 1; continue; }
    if (current === "(") depth += 1;
    if (current === ")") {
      depth -= 1;
      if (depth === 0) return index + 1;
    }
    index += 1;
  }
  return source.length;
}

function swiftCallSites(source, names) {
  const mask = swiftCodeMask(source);
  const pattern = new RegExp(`\\b(${names.join("|")})\\s*\\(`, "gu");
  const sites = [];
  for (const match of mask.matchAll(pattern)) {
    const openParen = mask.indexOf("(", match.index);
    const end = invocationEnd(source, openParen);
    sites.push({
      name: match[1],
      line: source.slice(0, match.index).split("\n").length,
      source: source.slice(match.index, end),
    });
  }
  return sites;
}

const dynamicTextBoundaries = [
  /\b(?:copyResolver|gameCopyResolver|localizedCopyResolver)\.resolve\s*\(/u,
  /\b(?:ProCareerPresentation|HighSchoolPresentation|HighSchoolConclusionPresentation|PitchCopy|MetaPresentation|LegacyPresentation|RecordPresentation)\./u,
  /\bGameFormatters\./u,
];
const localizationSafetyAnnotation = /\/\/\s*localization-safe:\s*(user-input|numeric|resolved-copy|stable-id|symbol)\b/u;

function isSafeDynamicText(site, sourceLines) {
  const argument = site.source.replace(/^Text\s*\(/u, "").trimStart();
  if (/^(?:verbatim\s*:|"|#")/u.test(argument)) return true;
  if (dynamicTextBoundaries.some((pattern) => pattern.test(site.source))) return true;
  const nearby = sourceLines.slice(Math.max(0, site.line - 3), site.line).join("\n");
  return localizationSafetyAnnotation.test(nearby) || localizationSafetyAnnotation.test(site.source);
}

function directDisplayPaths() {
  const failures = [];
  for (const path of swiftFiles(join(root, "apps/ios/Sources"))) {
    const source = readFileSync(path, "utf8");
    const lines = source.split("\n");
    for (const site of swiftCallSites(source, ["Text", "Label", "Button", "Toggle", "Section"])) {
      if (koreanPattern.test(site.source)) {
        failures.push({ path: relative(root, path), line: site.line, kind: "korean_display_literal" });
      }
      if (site.name === "Text" && !isSafeDynamicText(site, lines)) {
        failures.push({ path: relative(root, path), line: site.line, kind: "dynamic_text_path" });
      }
    }
    for (const site of swiftCallSites(source, ["accessibilityLabel", "accessibilityHint", "accessibilityValue"])) {
      if (koreanPattern.test(site.source)) {
        failures.push({ path: relative(root, path), line: site.line, kind: "korean_accessibility_literal" });
      }
    }
  }
  return failures;
}

function parseInfoPlistStrings(path) {
  if (!existsSync(path)) return {};
  const result = {};
  const source = readFileSync(path, "utf8");
  for (const match of source.matchAll(/"([^"]+)"\s*=\s*"((?:\\.|[^"\\])*)"\s*;/gu)) {
    result[match[1]] = match[2];
  }
  return result;
}

function realWorldIPFailures(catalogs) {
  const blocklist = [
    "KBO", "KBO League", "Korean Baseball Organization", "MLB", "Major League Baseball", "NPB", "Nippon Professional Baseball",
    "LG Twins", "Hanwha Eagles", "SSG Landers", "Samsung Lions", "Lotte Giants", "KIA Tigers", "Doosan Bears", "KT Wiz", "NC Dinos", "Kiwoom Heroes",
    "Los Angeles Dodgers", "New York Yankees", "Shohei Ohtani", "Mike Trout",
  ];
  const failures = [];
  for (const entry of catalogs) {
    for (const term of blocklist) {
      if (entry.en.includes(term)) failures.push(`${entry.file}:${entry.key} contains ${term}`);
    }
  }
  const marketingRoot = join(root, "marketing/appstore/en-US");
  for (const path of swiftFiles(marketingRoot).concat(existsSync(marketingRoot) ? collectTextFiles(marketingRoot) : [])) {
    const source = readFileSync(path, "utf8");
    for (const term of blocklist) if (source.includes(term)) failures.push(`${relative(root, path)} contains ${term}`);
  }
  return failures;
}

function collectTextFiles(directory) {
  if (!existsSync(directory)) return [];
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) return collectTextFiles(path);
    return /\.(md|json|txt|strings|xcstrings)$/u.test(entry.name) ? [path] : [];
  });
}

function validateSchema(schema) {
  const failures = [];
  if (schema.schema_version !== 1) failures.push("schema_version must be 1");
  if (!Number.isInteger(schema.scanner_version) || schema.scanner_version < 2) {
    failures.push("scanner_version must be at least 2 for compatibility-boundary review");
  }
  if (JSON.stringify(schema.required_surfaces) !== JSON.stringify(requiredSurfaces)) {
    failures.push(`required_surfaces must remain the canonical set: ${requiredSurfaces.join(", ")}`);
  }
  const sourceRootsPresent = Array.isArray(schema.source_roots) && schema.source_roots.length > 0 &&
    schema.source_roots.every((sourceRoot) =>
      typeof sourceRoot?.surfaceRoot === "string" && existsSync(join(root, sourceRoot.surfaceRoot))
    ) &&
    Array.isArray(schema.generation?.missing_source_roots) &&
    schema.generation.missing_source_roots.length === 0;
  if (!Array.isArray(schema.generation?.missing_source_roots)) {
    failures.push("generation.missing_source_roots must be an array");
  }
  if (!Array.isArray(schema.generation?.observed_surfaces)) {
    failures.push("generation.observed_surfaces must be an array");
  }
  if (!Array.isArray(schema.inventory)) failures.push("inventory must be an array");
  if (Array.isArray(schema.inventory) && schema.inventory.length === 0 && !sourceRootsPresent) {
    failures.push("empty inventory is only valid when all source roots are present and no roots are missing");
  }
  const ids = new Set();
  for (const entry of schema.inventory ?? []) {
    if (ids.has(entry.id)) failures.push(`duplicate inventory id: ${entry.id}`);
    ids.add(entry.id);
    if (!entry.source_anchor?.path || !Number.isInteger(entry.source_anchor.line)) failures.push(`invalid source anchor: ${entry.id}`);
    if (!statusIndex.has(entry.status)) failures.push(`invalid status ${entry.status}: ${entry.id}`);
    if (!allowedCopyClasses.includes(entry.copy_class)) failures.push(`invalid copy class ${entry.copy_class}: ${entry.id}`);
    if (entry.production_key !== null && !/^[a-z][a-z0-9_]*(?:[.-][a-z0-9_]+)+$/u.test(entry.production_key)) {
      failures.push(`non-semantic production key: ${entry.id}`);
    }
    if (entry.production_key === null && (typeof entry.exclusion_reason !== "string" || entry.exclusion_reason.trim().length < 20)) {
      failures.push(`source literal lacks a semantic key or explicit exclusion reason: ${entry.id}`);
    }
    if (entry.status === "ui_verified" && entry.production_key === null && entry.disposition !== "compatibility_boundary") {
      failures.push(`verified excluded literal lacks compatibility_boundary disposition: ${entry.id}`);
    }
    if (!requiredSurfaces.includes(entry.surface)) failures.push(`unsupported inventory surface ${entry.surface}: ${entry.id}`);
  }
  const observed = [...new Set((schema.inventory ?? []).map((entry) => entry.surface))].sort();
  const generatedObserved = [...new Set(
    Array.isArray(schema.generation?.observed_surfaces) ? schema.generation.observed_surfaces : []
  )].sort();
  for (const surface of generatedObserved) {
    if (!requiredSurfaces.includes(surface)) failures.push(`unsupported observed surface: ${surface}`);
  }
  if (JSON.stringify(generatedObserved) !== JSON.stringify(observed)) {
    failures.push(`generation.observed_surfaces does not match inventory: expected ${observed.join(", ")}, found ${generatedObserved.join(", ")}`);
  }
  const pendingCount = (schema.inventory ?? []).filter((entry) => entry.status !== "ui_verified").length;
  if (schema.generation?.pending_count !== pendingCount) {
    failures.push(`generation.pending_count mismatch: expected ${pendingCount}, found ${schema.generation?.pending_count}`);
  }
  const snapshot = hash(JSON.stringify(schema.inventory ?? []));
  if (snapshot !== schema.source_snapshot) failures.push(`source snapshot stale: expected ${snapshot}, found ${schema.source_snapshot}`);
  if (!Array.isArray(schema.catalogs)) failures.push("catalogs must be an array");
  return failures;
}

function validateCatalogs(schema) {
  const failures = [];
  const keys = new Set();
  for (const entry of schema.catalogs ?? []) {
    if (keys.has(entry.key)) failures.push(`duplicate catalog key: ${entry.key}`);
    keys.add(entry.key);
    if (!/^[a-z][a-z0-9_]*(?:[.-][a-z0-9_]+)+$/u.test(entry.key)) failures.push(`non-semantic catalog key: ${entry.key}`);
    if (!entry.ko || !entry.en) failures.push(`empty ko/en value: ${entry.key}`);
    if (!allowedStatuses.includes(entry.status) || statusIndex.get(entry.status) < statusIndex.get("ui_verified")) {
      failures.push(`catalog key is not ui_verified: ${entry.key} (${entry.status})`);
    }
    if (JSON.stringify(placeholderSignature(entry.ko)) !== JSON.stringify(placeholderSignature(entry.en))) {
      failures.push(`placeholder parity mismatch: ${entry.key}`);
    }
  }
  return failures;
}

function validateInfoPlist() {
  const failures = [];
  const ko = parseInfoPlistStrings(join(root, "apps/ios/Sources/Localization/ko.lproj/InfoPlist.strings"));
  const en = parseInfoPlistStrings(join(root, "apps/ios/Sources/Localization/en.lproj/InfoPlist.strings"));
  if (!ko.CFBundleDisplayName) failures.push("ko InfoPlist.strings is missing CFBundleDisplayName");
  if (!en.CFBundleDisplayName) failures.push("en InfoPlist.strings is missing CFBundleDisplayName");
  if (en.CFBundleDisplayName && koreanPattern.test(en.CFBundleDisplayName)) failures.push("English InfoPlist display name contains Korean");
  return failures;
}

if (!existsSync(schemaPath)) {
  console.error("iOS localization schema is missing. Run npm run inventory:ios-localization first.");
  process.exit(1);
}

const schema = readJSON(schemaPath);
const failures = validateSchema(schema);
if (schemaOnly) {
  failures.push(...validateCatalogs(schema));
  failures.push(...validateInfoPlist());
  if (failures.length) {
    console.error(`iOS localization schema validation FAILED (${failures.length} issue${failures.length === 1 ? "" : "s"})`);
    failures.slice(0, 20).forEach((failure) => console.error(`- ${failure}`));
    process.exit(1);
  }
  console.log(`iOS localization schema validation passed: ${schema.inventory.length} source entries, ${schema.catalogs.length} catalog entries`);
  process.exit(0);
}

failures.push(...validateCatalogs(schema));
failures.push(...validateInfoPlist());

const pending = (schema.inventory ?? []).filter((entry) => entry.status !== "ui_verified");
const pendingBySurface = Object.fromEntries(
  [...new Set(pending.map((entry) => entry.surface))].sort().map((surface) => [surface, pending.filter((entry) => entry.surface === surface).length])
);
const legacyPaths = directDisplayPaths();
const fixturePath = join(root, "docs/localization/ios-en-resolved-fixtures.json");
if (existsSync(fixturePath)) {
  const fixtures = readJSON(fixturePath);
  for (const [id, value] of Object.entries(fixtures)) if (koreanPattern.test(String(value))) failures.push(`English resolved fixture contains Korean: ${id}`);
}
failures.push(...realWorldIPFailures(schema.catalogs));

if (pending.length) failures.push(`pending inventory: ${pending.length}`);
if (legacyPaths.length) failures.push(`direct legacy display paths: ${legacyPaths.length}`);

if (failures.length) {
  console.error("iOS localization release check FAILED");
  console.error(`- pending inventory: ${pending.length}`);
  for (const [surface, count] of Object.entries(pendingBySurface)) console.error(`  - ${surface}: ${count}`);
  console.error(`- direct legacy display paths: ${legacyPaths.length}`);
  legacyPaths.slice(0, 100).forEach((failure) => {
    console.error(`  - ${failure.path}:${failure.line} (${failure.kind})`);
  });
  console.error(`- catalog entries checked: ${schema.catalogs.length}`);
  console.error("- use --schema-only to validate the Phase A schema without claiming release readiness");
  const detailFailures = failures.filter((failure) => !failure.startsWith("pending inventory:") && !failure.startsWith("direct legacy display paths:"));
  detailFailures.slice(0, 20).forEach((failure) => console.error(`- ${failure}`));
  process.exit(1);
}

console.log(`iOS localization release check passed: ${schema.catalogs.length} catalog entries and zero pending surfaces`);
