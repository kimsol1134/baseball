#!/usr/bin/env node

import { readdirSync, readFileSync, statSync } from "node:fs";
import { dirname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const android = resolve(root, "apps/android");
const errors = [];

function walk(dir, acc = []) {
  for (const name of readdirSync(dir)) {
    if (name === "build" || name === ".gradle") continue;
    const path = join(dir, name);
    const stat = statSync(path);
    if (stat.isDirectory()) walk(path, acc);
    else if (name.endsWith(".kt")) acc.push(path);
  }
  return acc;
}

function importsOf(source) {
  return [...source.matchAll(/^import\s+([^\s]+)/gm)].map((match) => match[1]);
}

function scan(relativeDir, predicate, message) {
  const dir = resolve(android, relativeDir);
  for (const file of walk(dir)) {
    const source = readFileSync(file, "utf8");
    const rel = relative(android, file);
    if (predicate(source, rel)) errors.push(`${message}: ${rel}`);
  }
}

function hasImport(source, prefix) {
  return importsOf(source).some((value) => value === prefix || value.startsWith(`${prefix}.`));
}

function hasPhaseTypeName(source) {
  return /\b(Phase[789][A-Za-z]|performPhase8)\b/.test(source);
}

scan("app/src/main", (source) => hasImport(source, "com.solkim.baseball.core"), "app main must not import game-core packages");
scan("app/src/main", (source) => hasPhaseTypeName(source), "app main must not use Phase7/8/9 product type names");
scan("app/src/main", (source) => /\bstate\.highSchool\b/.test(source) || /\bstate\.pro\b/.test(source), "app main must read careers through CareerUiRules, not GameAggregateState.highSchool/pro");
scan("app/src/main", (source) => /\bCareerAccess\b/.test(source), "app main must not use CareerAccess; that boundary is test-fixture only");
scan("game-application/src/main", (source) => /\bobject CareerAccess\b/.test(source) || /\bfun GameAggregateState\.withCareers\b/.test(source), "CareerAccess/withCareers belong in game-application testFixtures");
scan("game-application/src/main", (source) => hasPhaseTypeName(source), "game-application main must not use Phase7/8/9 product type names");
scan("game-application/src/main", (source, rel) => {
  if (rel.endsWith("CareerWire.kt")) return false;
  return /"phase8-\$\{|"phase8-ui"|"phase7-shell"|"phase7:tutorial"|"phase8:tutorial|"phase7-index:/.test(source);
}, "new aggregate writes must not use Phase 7/8 save-wire prefixes");
scan("app/src/test", (source, rel) => rel.endsWith("AppLayerBoundaryTest.kt") ? false : hasImport(source, "com.solkim.baseball.core"), "app unit tests must import core types through game-application or fixtures");
scan("app/src/androidTest", (source) => hasImport(source, "com.solkim.baseball.core"), "androidTest must import core types through application fixtures, not game-core packages");
scan("app/src/test", (source, rel) => rel.endsWith("AppLayerBoundaryTest.kt") ? false : hasPhaseTypeName(source), "app unit tests must not use Phase7/8/9 product type names");
scan("app/src/androidTest", (source) => hasPhaseTypeName(source), "androidTest must not use Phase7/8/9 product type names");
scan("game-application/src/test", (source) => hasPhaseTypeName(source), "game-application tests must not use Phase7/8/9 product type names");
scan("app/src/androidTest", (source) => /\b(HighSchoolKernel|HighSchoolPhase4Kernel|ProKernel|PitchKernel)\b/.test(source), "androidTest must build fixtures through CareerFixtures, not kernels");
scan("design-system/src/main", (source) => hasImport(source, "com.solkim.baseball.core") || hasImport(source, "com.solkim.baseball.application"), "design-system must stay presentation-only");

scan("game-core-api/src/main", (source) =>
  /androidx\.compose|android\.app|android\.content|com\.solkim\.baseball\.application/.test(source) ||
  /\bclass (HighSchoolPhase4Kernel|HighSchoolKernel|ProKernel|PitchKernel|ProCommandStore|HighSchoolPhase4CommandStore)\b/.test(source),
  "game-core-api must not contain Android/Compose, application, or kernel classes");
scan("game-core/src/main", (source) => /androidx\.compose|android\.app|android\.content|com\.solkim\.baseball\.application/.test(source), "game-core must not import Android/Compose or application");
scan("game-application/src/main", (source) => /androidx\.compose|android\.app\.|android\.content\.|android\.os\./.test(source), "game-application must not import Android/Compose");
scan("game-persistence/src/main", (source) =>
  hasImport(source, "com.solkim.baseball.core") ||
  hasImport(source, "com.solkim.baseball.application") ||
  /androidx\.compose|android\.app/.test(source),
  "game-persistence must depend only on game-model");
scan("game-model/src/main", (source) =>
  hasImport(source, "com.solkim.baseball.core") ||
  hasImport(source, "com.solkim.baseball.application") ||
  /androidx\.compose|android\.app/.test(source),
  "game-model must stay a leaf module");

const settings = readFileSync(resolve(android, "settings.gradle.kts"), "utf8");
if (!settings.includes('":game-core-api"')) errors.push("settings.gradle.kts must include :game-core-api");
for (const stub of [":feature-shell", ":feature-records", ":feature-settings", ":feature-pitch", ":feature-career"]) {
  if (settings.includes(`"${stub}"`)) errors.push(`unused stub module still included: ${stub}`);
}

const applicationGradle = readFileSync(resolve(android, "game-application/build.gradle.kts"), "utf8");
if (/api\(project\(":game-core"\)\)/.test(applicationGradle)) {
  errors.push("game-application must not api() game-core; kernels stay implementation-only");
}
if (!applicationGradle.includes('api(project(":game-core-api"))')) {
  errors.push("game-application must api() game-core-api so UI can see state types, not kernels");
}
if (!applicationGradle.includes('implementation(project(":game-core"))')) {
  errors.push("game-application must implementation() game-core");
}

const appGradle = readFileSync(resolve(android, "app/build.gradle.kts"), "utf8");
if (appGradle.includes('project(":game-core")')) {
  errors.push("app must not depend on game-core");
}

if (errors.length > 0) {
  console.error(errors.map((error) => `layer: ${error}`).join("\n"));
  process.exit(1);
}
console.log("Android layer boundaries hold.");
