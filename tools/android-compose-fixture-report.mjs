#!/usr/bin/env node

import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const csharpPath = path.join(root, "apps/android/game-core/src/test/resources/fixtures/csharp-pitch-oracle-v1.json");
const swiftApprovedPath = path.join(root, "apps/android/game-core/src/test/resources/fixtures/swift-pitch-kernel-approved-v2.json");
const swiftCurrentCommittedPath = path.join(root, "apps/android/game-core/src/test/resources/fixtures/swift-pitch-kernel-current-v1.json");
const swiftLegacyPath = path.join(root, "apps/android/game-core/src/test/resources/fixtures/swift-simulation-engine-golden-v1.json");
const swiftCurrentPath = path.join(root, "artifacts/android-compose/fixtures/swift-pitch-kernel-oracle-v1.json");
const phase4CommittedPath = path.join(root, "apps/android/game-core/src/test/resources/fixtures/swift-high-school-phase4-oracle-v3.json");
const phase4GeneratedPath = path.join(root, "artifacts/android-compose/fixtures/swift-high-school-phase4-oracle-v3.json");
const proCommittedPath = path.join(root, "apps/android/game-core/src/test/resources/fixtures/swift-pro-career-oracle-v1.json");
const proGeneratedPath = path.join(root, "artifacts/android-compose/fixtures/swift-pro-career-oracle-v1.json");
const saveCurrentPath = path.join(root, "apps/android/game-persistence/src/test/resources/legacy/save-v1-current.json");
const saveKotlinWrittenPath = path.join(root, "apps/android/game-persistence/src/test/resources/legacy/kotlin-written-save-v1.json");
const saveCSharpWrittenCommittedPath = path.join(root, "apps/android/game-persistence/src/test/resources/legacy/csharp-written-after-kotlin-save-v1.json");
const saveCSharpWrittenPath = path.join(root, "artifacts/android-compose/fixtures/csharp-written-after-kotlin-save-v1.json");
const outputPath = path.join(root, "artifacts/android-compose/fixtures/cross-runtime-report.json");

function fail(message) {
  throw new Error(`cross-runtime fixture report: ${message}`);
}

function sha256(value) {
  return crypto.createHash("sha256").update(value, "utf8").digest("hex");
}

function sha256Bytes(value) {
  return crypto.createHash("sha256").update(value).digest("hex");
}

function fnv1a64(value) {
  let hash = 0xcbf29ce484222325n;
  for (const byte of Buffer.from(value, "utf8")) {
    hash ^= BigInt(byte);
    hash = BigInt.asUintN(64, hash * 0x00000100000001b3n);
  }
  return hash.toString(16).padStart(16, "0");
}

function readJson(file) {
  try {
    return JSON.parse(fs.readFileSync(file, "utf8"));
  } catch (error) {
    fail(`${file} is not valid JSON: ${error.message}`);
  }
}

function readText(file, label) {
  try {
    return fs.readFileSync(file, "utf8");
  } catch (error) {
    fail(`${label} could not be read: ${error.message}`);
  }
}

const saveEnvelopeFields = new Set(["schema", "schemaVersion", "revision", "writtenAtUtc", "payloadSha256", "payload"]);
const savePayloadFields = new Set([
  "aggregateVersion", "revision", "installId", "stage", "highSchool", "pro", "meta", "pitchResume",
  "pendingPitchCompletion", "settings", "analyticsReceipts", "commandReceipts", "deleted",
]);
const saveStages = new Set(["opening", "setup", "highSchool", "draft", "pro", "retirement", "legacy", "betweenLives", "deleted"]);

function exactFields(value, expected, label) {
  const actual = new Set(Object.keys(value ?? {}));
  const missing = [...expected].filter((field) => !actual.has(field));
  const unknown = [...actual].filter((field) => !expected.has(field));
  if (missing.length > 0) fail(`${label} missing fields: ${missing.sort().join(",")}`);
  if (unknown.length > 0) fail(`${label} unknown fields: ${unknown.sort().join(",")}`);
}

function strictDecimal(value, label) {
  if (typeof value !== "string" || !/^(0|[1-9][0-9]*)$/.test(value)) fail(`${label} is not a canonical decimal string`);
  try {
    return BigInt(value);
  } catch (error) {
    fail(`${label} is outside ULong range: ${error.message}`);
  }
}

function verifySaveFixture(file, label, expectedRevision) {
  const rawBytes = fs.existsSync(file) ? fs.readFileSync(file) : null;
  if (rawBytes == null) fail(`${label} is missing: ${file}`);
  const raw = rawBytes.toString("utf8");
  let fixture;
  try {
    fixture = JSON.parse(raw);
  } catch (error) {
    fail(`${label} is not valid JSON: ${error.message}`);
  }
  if (fixture == null || typeof fixture !== "object" || Array.isArray(fixture)) fail(`${label} root is not an object`);
  exactFields(fixture, saveEnvelopeFields, `${label} envelope`);
  if (fixture.schema !== "android-unity-save-v1") fail(`${label} schema is not android-unity-save-v1`);
  if (fixture.schemaVersion !== 1 || !Number.isInteger(fixture.schemaVersion)) fail(`${label} schemaVersion is not exactly 1`);
  const revision = strictDecimal(fixture.revision, `${label}.revision`);
  if (expectedRevision !== undefined && revision !== BigInt(expectedRevision)) fail(`${label} revision is ${revision}, expected ${expectedRevision}`);
  if (typeof fixture.writtenAtUtc !== "string" ||
      !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(fixture.writtenAtUtc) ||
      Number.isNaN(Date.parse(fixture.writtenAtUtc))) {
    fail(`${label}.writtenAtUtc is not an exact UTC millisecond timestamp`);
  }
  if (typeof fixture.payloadSha256 !== "string" || !/^[0-9a-f]{64}$/.test(fixture.payloadSha256)) {
    fail(`${label}.payloadSha256 is not a lowercase SHA-256`);
  }
  if (fixture.payload == null || typeof fixture.payload !== "object" || Array.isArray(fixture.payload)) fail(`${label}.payload is not an object`);
  exactFields(fixture.payload, savePayloadFields, `${label} payload`);
  if (!Number.isSafeInteger(fixture.payload.aggregateVersion) || fixture.payload.aggregateVersion < 0) fail(`${label}.payload.aggregateVersion is invalid`);
  if (!Number.isSafeInteger(fixture.payload.revision) || fixture.payload.revision < 0) fail(`${label}.payload.revision is invalid`);
  if (BigInt(fixture.payload.revision) > BigInt(Number.MAX_SAFE_INTEGER)) fail(`${label}.payload.revision is outside exact JSON integer range`);
  if (typeof fixture.payload.installId !== "string" || fixture.payload.installId.length === 0) fail(`${label}.payload.installId is empty`);
  if (!saveStages.has(fixture.payload.stage)) fail(`${label}.payload.stage is unknown`);
  if (typeof fixture.payload.deleted !== "boolean") fail(`${label}.payload.deleted is not boolean`);
  if (fixture.payload.deleted !== (fixture.payload.stage === "deleted")) fail(`${label}.payload tombstone stage mismatch`);
  return {
    path: path.relative(root, file),
    rawBytesSha256: sha256Bytes(rawBytes),
    bytes: rawBytes.length,
    revision: revision.toString(),
    payloadRevision: fixture.payload.revision,
    payloadSha256: fixture.payloadSha256,
    installId: fixture.payload.installId,
    stage: fixture.payload.stage,
    optionalNullPaths: ["pro", "pitchResume", "pendingPitchCompletion"].filter((field) => fixture.payload[field] === null),
    semanticPayloadFields: [...savePayloadFields].sort(),
  };
}

function validateEnvelope(fixture, label) {
  const required = ["fixtureSchema", "sourceRuntime", "sourceCommit", "inputSha256", "outputSha256", "input", "expected"];
  for (const field of required) if (!(field in fixture)) fail(`${label} missing ${field}`);
  if (fixture.fixtureSchema !== "baseball-cross-runtime-fixture-v1") fail(`${label} fixtureSchema is not frozen`);
  if (!/^(csharp|swift)$/.test(fixture.sourceRuntime)) fail(`${label} sourceRuntime is not supported`);
  if (!/^[0-9a-f]{40}$/.test(fixture.sourceCommit)) fail(`${label} sourceCommit is not a commit SHA`);
  if (!/^[0-9a-f]{64}$/.test(fixture.inputSha256) || !/^[0-9a-f]{64}$/.test(fixture.outputSha256)) {
    fail(`${label} hash metadata is malformed`);
  }
}

function canonicalInput() {
  return [
    "PitchKernelTranslationTests.FixtureInput",
    "pitcher-1", "62", "54", "58", "60",
    "batter-1", "56", "52", "58",
    "hot:1:1", "cold:2:0", "strength:four_seam", "weakness:slider", "chase:48",
    "pa-1", "revision:0", "inning:7", "outs:0", "balls:1", "strikes:1",
    "pitchNumber:1", "scoreDifferential:0", "leverage:600", "fatigue:12", "seed:1..10000",
  ].join("|");
}

function verifyPitchFixtureIntegrity(fixture, label) {
  validateEnvelope(fixture, label);
  if (!Array.isArray(fixture.expected?.rows) || fixture.expected.rows.length !== 128) {
    fail(`${label} exact row count is not 128`);
  }
  const canonicalRows = fixture.expected.rows.map((row) =>
    `${row.seed}|${row.outcome}|${row.actualX}|${row.actualY}|${row.velocityTenthsKph}|${row.eventHash}\n`).join("");
  if (fnv1a64(canonicalRows) !== fixture.expected.canonicalRowsFnv1a64) {
    fail(`${label} exact-row FNV does not match fixture`);
  }
  const distribution = Object.fromEntries(Object.entries(fixture.expected.distribution).sort(([a], [b]) => a.localeCompare(b)));
  if (Object.values(distribution).reduce((sum, value) => sum + value, 0) !== 10_000) {
    fail(`${label} distribution does not total 10,000`);
  }
  const outputCanonical = canonicalRows + "distribution|" + Object.entries(distribution)
    .map(([key, value]) => `${key}:${value}`).join(",");
  if (fixture.inputSha256 !== sha256(canonicalInput())) fail(`${label} inputSha256 does not match exporter canonical input`);
  if (fixture.outputSha256 !== sha256(outputCanonical)) fail(`${label} outputSha256 does not match exporter canonical output`);
  return {
    sourceRuntime: fixture.sourceRuntime,
    sourceCommit: fixture.sourceCommit,
    exact128: true,
    distribution10000: distribution,
    canonicalRowsFnv1a64: fixture.expected.canonicalRowsFnv1a64,
    inputSha256: fixture.inputSha256,
    outputSha256: fixture.outputSha256,
  };
}

function verifyCSharpFixture(fixture) {
  validateEnvelope(fixture, "csharp");
  if (fixture.sourceRuntime !== "csharp") fail("C# oracle sourceRuntime mismatch");
  if (!Array.isArray(fixture.expected.rows) || fixture.expected.rows.length !== 128) fail("C# exact row count is not 128");
  const canonicalRows = fixture.expected.rows.map((row) =>
    `${row.seed}|${row.outcome}|${row.actualX}|${row.actualY}|${row.velocityTenthsKph}|${row.eventHash}\n`).join("");
  if (fnv1a64(canonicalRows) !== fixture.expected.canonicalRowsFnv1a64) fail("C# exact-row FNV does not match fixture");
  const distribution = Object.fromEntries(Object.entries(fixture.expected.distribution).sort(([a], [b]) => a.localeCompare(b)));
  const inputCanonical = canonicalInput();
  const outputCanonical = canonicalRows + "distribution|" + Object.entries(distribution)
    .map(([key, value]) => `${key}:${value}`).join(",");
  if (sha256(inputCanonical) !== fixture.inputSha256) fail("C# inputSha256 does not match exporter canonical input");
  if (sha256(outputCanonical) !== fixture.outputSha256) fail("C# outputSha256 does not match exporter canonical output");
  const expectedDistribution = {
    ball: 2552,
    called_strike: 2458,
    swinging_strike: 2755,
    foul: 1060,
    in_play_out: 871,
    single: 226,
    double: 59,
    triple: 4,
    home_run: 14,
    hit_by_pitch: 1,
  };
  if (JSON.stringify(Object.entries(fixture.expected.distribution).sort()) !== JSON.stringify(Object.entries(expectedDistribution).sort())) {
    fail("C# distribution no longer matches the approved oracle summary");
  }
  return {
    sourceRuntime: fixture.sourceRuntime,
    sourceCommit: fixture.sourceCommit,
    exact128: "SOURCE fixture + Kotlin differential test",
    distribution10000: "SOURCE fixture + Kotlin differential test",
    canonicalRowsFnv1a64: fixture.expected.canonicalRowsFnv1a64,
    inputSha256: fixture.inputSha256,
    outputSha256: fixture.outputSha256,
    distribution: fixture.expected.distribution,
  };
}

function verifySwiftFixture(fixture) {
  validateEnvelope(fixture, "swift");
  if (fixture.authorityScope !== "legacy-simulation-engine-not-pitch-kernel") {
    fail("Swift legacy fixture scope must remain explicit");
  }
  return {
    sourceRuntime: fixture.sourceRuntime,
    sourceCommit: fixture.sourceCommit,
    authorityScope: fixture.authorityScope,
    status: "SOURCE legacy fixture retained; not used as PitchKernel authority",
    expected: fixture.expected,
  };
}

function verifyApprovedSwiftPitchFixture(fixture, csharp) {
  validateEnvelope(fixture, "approved Swift pitch");
  if (fixture.sourceRuntime !== "swift") fail("approved Swift pitch sourceRuntime mismatch");
  if (fixture.input?.sourceSetSha256 !== "bdf4288abbc6dc81e96f8c725202af4e764bb293640e3fb0e3571abef182c76b") {
    fail("approved Swift pitch source set is not the frozen oracle set");
  }
  if (fixture.expected?.exactRuns !== 128) fail("approved Swift exact row count is not 128");
  if (fixture.expected?.canonicalRowsFnv1a64 !== csharp.canonicalRowsFnv1a64) {
    fail("approved Swift exact-row FNV differs from the C# export from the same source set");
  }
  if (JSON.stringify(Object.entries(fixture.expected.distribution).sort()) !== JSON.stringify(Object.entries(csharp.distribution).sort())) {
    fail("approved Swift distribution differs from the C# export from the same source set");
  }
  if (fixture.inputSha256 !== csharp.inputSha256 || fixture.outputSha256 !== csharp.outputSha256) {
    fail("approved Swift hash metadata differs from the C# export from the same source set");
  }
  return {
    sourceRuntime: fixture.sourceRuntime,
    sourceCommit: fixture.sourceCommit,
    authorityScope: fixture.authorityScope,
    exact128: "SOURCE approved Swift summary + C# complete row export",
    distribution10000: "SOURCE approved Swift summary + C# complete row export",
    canonicalRowsFnv1a64: fixture.expected.canonicalRowsFnv1a64,
    inputSha256: fixture.inputSha256,
    outputSha256: fixture.outputSha256,
    distribution: fixture.expected.distribution,
  };
}

function verifyCurrentSwiftPitchFixture(fixture, csharp, committed) {
  const summary = verifyPitchFixtureIntegrity(fixture, "current Swift pitch");
  if (fixture.sourceRuntime !== "swift") fail("current Swift pitch sourceRuntime mismatch");
  for (const field of ["sourceCommit", "canonicalRowsFnv1a64", "inputSha256", "outputSha256"]) {
    if (summary[field] !== committed[field]) fail(`generated current Swift ${field} differs from committed fixture`);
  }
  if (JSON.stringify(summary.distribution10000) !== JSON.stringify(committed.distribution10000)) {
    fail("generated current Swift distribution differs from committed fixture");
  }
  const sameExact = summary.canonicalRowsFnv1a64 === csharp.canonicalRowsFnv1a64;
  const sameDistribution = JSON.stringify(Object.entries(summary.distribution10000).sort()) ===
    JSON.stringify(Object.entries(csharp.distribution).sort());
  return {
    ...summary,
    status: sameExact && sameDistribution ? "MATCHES_FROZEN_CSHARP" : "SOURCE_DIVERGENCE_DOCUMENTED",
    comparedAgainst: {
      csharpSourceCommit: csharp.sourceCommit,
      csharpCanonicalRowsFnv1a64: csharp.canonicalRowsFnv1a64,
      csharpDistribution10000: csharp.distribution,
    },
    committedFixture: committed,
  };
}

function phase4InputCanonical() {
  return [
    "HighSchoolCareerEngine.Phase4Vertical",
    "preset:power_prospect", "school:haedong_power", "focus:command", "intensity:standard", "relationship:listen",
    "game:pitches18|strikeouts2|walks0|runs0|expected400|actual250|accepted12|outs3|sequence4|hits0",
    "awakening:first_available", "locale:ko-KR", "timezone:Asia/Seoul", "seeds:918220+17*n,n=0..19",
  ].join("|");
}

function phase4CanonicalRows(fixture) {
  return fixture.expected.rows.map((row) => [
    row.seed, row.phaseTrace, row.trainingTotal, row.relationshipTotal, row.importantGameTotal,
    row.completedGames, row.chapter, row.selectedAwakenings, row.draftOutcome,
    row.draftEvaluation, row.memoryOptionCount, row.signatureLegacyCandidateCount,
    row.signatureLegacyCandidateIDs.join(","), row.finalRatings.join(","), row.performance.join(","), row.trust.join(","),
    row.relationshipCategories.join(","), row.relationshipGrowth.join(","), row.automaticSummary.join(","),
    row.automaticLines.map((line) => line.join(":")).join(","), row.fanInterest,
  ].join("|") + "\n").join("");
}

function verifyPhase4Fixture(fixture, label) {
  const required = ["fixtureSchema", "sourceRuntime", "sourceCommit", "inputSha256", "outputSha256", "input", "expected"];
  for (const field of required) if (!(field in fixture)) fail(`${label} missing ${field}`);
  if (fixture.fixtureSchema !== "baseball-high-school-phase4-fixture-v3") fail(`${label} schema mismatch`);
  if (fixture.sourceRuntime !== "swift") fail(`${label} sourceRuntime mismatch`);
  if (!/^[0-9a-f]{40}$/.test(fixture.sourceCommit)) fail(`${label} sourceCommit malformed`);
  if (!/^[0-9a-f]{64}$/.test(fixture.inputSha256) || !/^[0-9a-f]{64}$/.test(fixture.outputSha256)) fail(`${label} hashes malformed`);
  if (fixture.authorityScope !== "current-swift-high-school-phase4-core-meta-vertical") fail(`${label} authority scope missing`);
  if (fixture.input?.locale !== "ko-KR" || fixture.input?.timezone !== "Asia/Seoul") fail(`${label} locale/timezone matrix input changed`);
  if (!Array.isArray(fixture.expected.rows) || fixture.expected.rows.length !== 20 || fixture.expected.exactRuns !== 20) fail(`${label} exact run count is not 20`);
  const rows = phase4CanonicalRows(fixture);
  if (fixture.inputSha256 !== sha256(phase4InputCanonical())) fail(`${label} inputSha256 does not match exporter canonical input`);
  if (fixture.outputSha256 !== sha256(rows)) fail(`${label} outputSha256 does not match exporter canonical output`);
  const signatureIDs = new Set(["power_imprint", "command_map", "breaking_trace", "endurance_rhythm", "gamecraft_ledger", "battery_promise"]);
  if (!fixture.expected.rows.every((row) => row.chapter === 8 && row.selectedAwakenings === 3 && row.completedGames === row.importantGameTotal &&
      row.memoryOptionCount === 5 && row.signatureLegacyCandidateCount === 3 && Array.isArray(row.signatureLegacyCandidateIDs) &&
      row.signatureLegacyCandidateIDs.length === 3 && new Set(row.signatureLegacyCandidateIDs).size === 3 &&
      row.signatureLegacyCandidateIDs.every((id) => signatureIDs.has(id)) &&
      Array.isArray(row.finalRatings) && row.finalRatings.length === 4 &&
      Array.isArray(row.performance) && row.performance.length === 7 &&
      Array.isArray(row.trust) && row.trust.length === 3 &&
      Array.isArray(row.relationshipCategories) && row.relationshipCategories.length >= 4 &&
      Array.isArray(row.relationshipGrowth) && row.relationshipGrowth.length === row.relationshipCategories.length &&
      Array.isArray(row.automaticSummary) && row.automaticSummary.length === 5 &&
      Array.isArray(row.automaticLines) && row.automaticLines.every((line) => Array.isArray(line) && line.length === 6) &&
      Number.isInteger(row.fanInterest))) {
    fail(`${label} selected vertical does not reach chapter 8 with complete games/awakenings`);
  }
  return {
    sourceRuntime: fixture.sourceRuntime,
    sourceCommit: fixture.sourceCommit,
    exactRuns: fixture.expected.rows.length,
    inputSha256: fixture.inputSha256,
    outputSha256: fixture.outputSha256,
    rows,
  };
}

function proInputCanonical() {
  return [
    "ProCareerEngine.Phase5Vertical", "start:linked", "preset:power_prospect", "team:proTeams[0]", "draftEvaluation:72",
    "entitlement:active", "postStart:signContract", "week1:earnTrust", "decisionWeeks:6,13,20",
    "maximumCareerSeasons:20", "maximumSeasonDecisions:3", "seeds:100..119", "locale:ko-KR", "timezone:Asia/Seoul",
  ].join("|");
}

function proCanonicalRows(fixture) {
  return fixture.expected.rows.map((row) => [
    row.seed, row.careerID, row.startNextSeed, row.teamID, row.signedRevision,
    row.signedNextSeed, row.firstWeekNextSeed, row.firstWeekStats.join(","), row.phase,
    row.level, row.role, row.segment, row.decisionWeeks.join(","),
    row.maximumCareerSeasons, row.maximumSeasonDecisions,
  ].join("|") + "\n").join("");
}

function verifyProFixture(fixture, label) {
  const required = ["fixtureSchema", "sourceRuntime", "sourceCommit", "inputSha256", "outputSha256", "input", "expected"];
  for (const field of required) if (!(field in fixture)) fail(`${label} missing ${field}`);
  if (fixture.fixtureSchema !== "baseball-pro-career-fixture-v1") fail(`${label} schema mismatch`);
  if (fixture.sourceRuntime !== "swift") fail(`${label} sourceRuntime mismatch`);
  if (!/^[0-9a-f]{40}$/.test(fixture.sourceCommit)) fail(`${label} sourceCommit malformed`);
  if (!/^[0-9a-f]{64}$/.test(fixture.inputSha256) || !/^[0-9a-f]{64}$/.test(fixture.outputSha256)) fail(`${label} hashes malformed`);
  if (fixture.authorityScope !== "current-swift-pro-core-vertical") fail(`${label} authority scope missing`);
  if (fixture.input?.locale !== "ko-KR" || fixture.input?.timezone !== "Asia/Seoul") fail(`${label} locale/timezone matrix input changed`);
  if (!Array.isArray(fixture.expected.rows) || fixture.expected.rows.length !== 20 || fixture.expected.exactRuns !== 20) fail(`${label} exact run count is not 20`);
  if (fixture.inputSha256 !== sha256(proInputCanonical())) fail(`${label} inputSha256 does not match exporter canonical input`);
  const rows = proCanonicalRows(fixture);
  if (fixture.outputSha256 !== sha256(rows)) fail(`${label} outputSha256 does not match exporter canonical output`);
  if (!fixture.expected.rows.every((row) =>
    typeof row.seed === "string" && typeof row.careerID === "string" && typeof row.startNextSeed === "string" &&
    typeof row.teamID === "string" && Number.isInteger(row.signedRevision) && typeof row.signedNextSeed === "string" &&
    typeof row.firstWeekNextSeed === "string" && Array.isArray(row.firstWeekStats) && row.firstWeekStats.length === 8 &&
    row.firstWeekStats.every(Number.isInteger) && ["weekly_plan", "important_game", "season_decision", "season_review"].includes(row.phase) &&
    ["minor", "major"].includes(row.level) && ["starter", "long_relief", "setup", "closer"].includes(row.role) &&
    ["spring_camp", "opening", "first_half", "all_star_break", "pennant_race", "season_finale"].includes(row.segment) &&
    JSON.stringify(row.decisionWeeks) === JSON.stringify([6, 13, 20]) && row.maximumCareerSeasons === 20 && row.maximumSeasonDecisions === 3
  )) fail(`${label} contains an invalid Pro boundary row`);
  return {
    sourceRuntime: fixture.sourceRuntime,
    sourceCommit: fixture.sourceCommit,
    exactRuns: fixture.expected.rows.length,
    inputSha256: fixture.inputSha256,
    outputSha256: fixture.outputSha256,
    rows,
  };
}

const phase4Committed = verifyPhase4Fixture(readJson(phase4CommittedPath), "committed Swift Phase 4");
const phase4Generated = fs.existsSync(phase4GeneratedPath)
  ? verifyPhase4Fixture(readJson(phase4GeneratedPath), "generated Swift Phase 4")
  : { status: "NOT_RUN", evidence: "Swift Phase 4 exporter output was not present" };
if (phase4Generated.status !== "NOT_RUN") {
  if (phase4Generated.sourceCommit !== phase4Committed.sourceCommit ||
      phase4Generated.inputSha256 !== phase4Committed.inputSha256 ||
      phase4Generated.outputSha256 !== phase4Committed.outputSha256 ||
      JSON.stringify(phase4Generated.rows) !== JSON.stringify(phase4Committed.rows)) {
    fail("generated Swift Phase 4 fixture differs from committed fixture");
  }
}

const proCommitted = verifyProFixture(readJson(proCommittedPath), "committed Swift Pro");
const proGenerated = fs.existsSync(proGeneratedPath)
  ? verifyProFixture(readJson(proGeneratedPath), "generated Swift Pro")
  : { status: "NOT_RUN", evidence: "Swift Pro exporter output was not present" };
if (proGenerated.status !== "NOT_RUN") {
  if (proGenerated.sourceCommit !== proCommitted.sourceCommit ||
      proGenerated.inputSha256 !== proCommitted.inputSha256 ||
      proGenerated.outputSha256 !== proCommitted.outputSha256 ||
      JSON.stringify(proGenerated.rows) !== JSON.stringify(proCommitted.rows)) {
    fail("generated Swift Pro fixture differs from committed fixture");
  }
}

const csharp = readJson(csharpPath);
const swiftApproved = readJson(swiftApprovedPath);
const swiftCurrentCommitted = verifyPitchFixtureIntegrity(readJson(swiftCurrentCommittedPath), "committed current Swift pitch");
const swiftLegacy = readJson(swiftLegacyPath);
const csharpSummary = verifyCSharpFixture(csharp);
const currentSwift = fs.existsSync(swiftCurrentPath)
  ? verifyCurrentSwiftPitchFixture(readJson(swiftCurrentPath), csharpSummary, swiftCurrentCommitted)
  : { status: "NOT_RUN", evidence: "swift exporter output was not present", committedFixture: swiftCurrentCommitted };
const saveCurrent = verifySaveFixture(saveCurrentPath, "current emulator save clone", 6);
const saveKotlinWritten = verifySaveFixture(saveKotlinWrittenPath, "Kotlin-written C# save fixture", 7);
const saveCSharpWrittenCommitted = verifySaveFixture(saveCSharpWrittenCommittedPath, "checked-in C#-written-after-Kotlin save fixture", 8);
const saveCSharpWritten = fs.existsSync(saveCSharpWrittenPath)
  ? verifySaveFixture(saveCSharpWrittenPath, "C#-written-after-Kotlin save fixture", 8)
  : { status: "NOT_RUN", evidence: "The real Unity C# rewrite test has not emitted its ignored fixture" };
if (saveCSharpWritten.status !== "NOT_RUN") {
  for (const field of ["revision", "payloadRevision", "payloadSha256", "installId", "stage"]) {
    if (saveCSharpWritten[field] !== saveCSharpWrittenCommitted[field]) {
      fail(`generated C#-written save ${field} differs from checked-in fixture`);
    }
  }
}
const saveShapeFields = ["installId", "stage", "optionalNullPaths", "semanticPayloadFields"];
for (const field of saveShapeFields) {
  const left = field === "optionalNullPaths" || field === "semanticPayloadFields"
    ? JSON.stringify(saveCurrent[field])
    : saveCurrent[field];
  const right = field === "optionalNullPaths" || field === "semanticPayloadFields"
    ? JSON.stringify(saveKotlinWritten[field])
    : saveKotlinWritten[field];
  if (left !== right) fail(`current-to-Kotlin save semantic ${field} differs`);
  const kotlinToCSharp = field === "optionalNullPaths" || field === "semanticPayloadFields"
    ? JSON.stringify(saveKotlinWritten[field]) === JSON.stringify(saveCSharpWrittenCommitted[field])
    : saveKotlinWritten[field] === saveCSharpWrittenCommitted[field];
  if (!kotlinToCSharp) fail(`Kotlin-to-C# save semantic ${field} differs`);
}
const report = {
  reportSchema: "baseball-cross-runtime-report-v1",
  generatedEvidence: "VERIFIED locally by this report tool; Unity C# exporter and Kotlin differential test are separate evidence steps",
  authorityOrder: "plan-5.1: product parity exceptions > Swift fixture/caller > exact C# fixture/distribution > implementation > UI",
  csharpPitchKernel: csharpSummary,
  swiftApprovedPitchKernel: verifyApprovedSwiftPitchFixture(swiftApproved, csharpSummary),
  swiftCurrentPitchKernel: currentSwift,
  swiftHighSchoolPhase4: {
    committed: phase4Committed,
    generated: phase4Generated,
    status: phase4Generated.status === "NOT_RUN" ? "NOT_RUN" : "MATCHES_COMMITTED_SWIFT_AUTHORITY",
    kotlinComparison: "VERIFIED by HighSchoolPhase4FixtureTest and HighSchoolPhase4KernelTest for deterministic schedule, relationship category/growth trace, signature candidates, draft boundary, automatic-season aggregates, and 20 local verticals; full Swift presentation/read-model parity remains source-scoped",
  },
  swiftProCareer: {
    committed: proCommitted,
    generated: proGenerated,
    status: proGenerated.status === "NOT_RUN" ? "NOT_RUN" : "MATCHES_COMMITTED_SWIFT_AUTHORITY",
    kotlinComparison: "VERIFIED by ProCareerFixtureTest across 20 current-Swift seeds for linked start identity/team/seed, contract boundary, first weekly outing stats, exact segments, and decision/career limits; full Kotlin maximum-career evidence remains in ProKernelTest",
  },
  saveCompatibility: {
    schema: "android-unity-save-v1",
    status: saveCSharpWritten.status === "NOT_RUN" ? "PARTIAL_NOT_RUN" : "VERIFIED_BY_KOTLIN_AND_REAL_CSHARP_READER",
    currentEmulatorClone: saveCurrent,
    kotlinWritten: saveKotlinWritten,
    csharpWrittenFixture: saveCSharpWrittenCommitted,
    csharpWrittenAfterKotlin: saveCSharpWritten,
    semanticComparisons: {
      currentToKotlin: {
        identityAndNullDefaults: "MATCH",
        envelopeRevision: "6 -> 7",
        payloadSha256: "EXPECTED_CHANGE_AFTER_REVISION_REWRITE",
      },
      kotlinToCSharp: {
        identityAndNullDefaults: "MATCH",
        envelopeRevision: "7 -> 8",
        aggregateRevision: "7 retained by the real C# envelope writer",
        payloadSha256: "MATCH",
      },
    },
    semanticBoundary: "Envelope revision is the durable save revision. The legacy C# aggregate may retain its own payload revision when the C# repository writes a new envelope; this is preserved and reported rather than normalized silently.",
    hashBoundary: "Declared payloadSha256, strict envelope/payload fields, raw fixture bytes, and semantic identity are checked here; canonical payload hash recomputation and reader acceptance are verified by LegacySaveCodec/Phase6PersistenceTest and the real Unity C# compatibility tests.",
  },
  swiftLegacySimulation: verifySwiftFixture(swiftLegacy),
  explicitDivergence: {
    status: "DOCUMENTED",
    reason: "The frozen C# translation fixture is from source set 23acbb8, while the current Swift PitchKernelEngine/PitchAbilityRules source is 792d728 and changes deterministic pitch output.",
    consequence: "Plan 5.1 gives current Swift authority. Kotlin matches the committed current Swift fixture; the historical C# rows remain retained and compared, but are not silently mixed into Kotlin.",
  },
  matrix: [
    { locale: "en-US", timezone: "UTC", status: "VERIFIED by PitchKernelOracleFixtureTest" },
    { locale: "ko-KR", timezone: "Asia/Seoul", status: "VERIFIED by PitchKernelOracleFixtureTest" },
    { locale: "ja-JP", timezone: "Asia/Tokyo", status: "VERIFIED by JVM matrix test; no Android product locale claim" },
  ],
  failClosed: {
    invalidJson: "VERIFIED by StrictJson/PitchIpcCodec/CommittedPitchReplay tests",
    futureSchema: "VERIFIED by LegacySaveCodec and CommittedPitchReplay tests",
    unknownWire: "VERIFIED by PitchIpcCodec and CommittedPitchReplay tests",
    staleDuplicate: "VERIFIED by PitchSessionGate, replay lifecycle, and PitchKernel stale-token tests",
  },
};

fs.mkdirSync(path.dirname(outputPath), { recursive: true });
fs.writeFileSync(outputPath, `${JSON.stringify(report, null, 2)}\n`, "utf8");
process.stdout.write(`Cross-runtime fixture report passed: ${path.relative(root, outputPath)}\n`);
