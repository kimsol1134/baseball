#!/usr/bin/env node

import { existsSync, readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const required = [
  "apps/android/settings.gradle.kts",
  "apps/android/app/src/main/AndroidManifest.xml",
  "apps/android/app/src/main/java/com/solkim/baseball/android/MainActivity.kt",
  "apps/android/app/src/main/java/com/solkim/baseball/android/PitchUnityActivity.kt",
  "apps/android/unity-runtime/src/main/kotlin/com/solkim/baseball/bridge/UnityRuntimeHost.kt",
  "apps/android/game-model/src/main/kotlin/com/solkim/baseball/model/PitchIpcModels.kt",
  "apps/android/game-core/src/main/kotlin/com/solkim/baseball/core/pitch/PitchKernel.kt",
  "apps/android/game-core/src/main/kotlin/com/solkim/baseball/core/highschool/HighSchoolContentCatalog.kt",
  "apps/android/game-core/src/main/kotlin/com/solkim/baseball/core/highschool/HighSchoolKernel.kt",
  "apps/android/game-core/src/main/kotlin/com/solkim/baseball/core/highschool/HighSchoolStateCodec.kt",
  "apps/android/game-core/src/main/kotlin/com/solkim/baseball/core/highschool/CSharpHighSchoolSnapshotCodec.kt",
  "apps/android/game-core/src/main/kotlin/com/solkim/baseball/core/highschool/CSharpHighSchoolSnapshotWire.kt",
  "apps/android/game-core/src/test/resources/fixtures/csharp-high-school-snapshot-relationship-v1.json",
  "apps/android/game-application/src/main/kotlin/com/solkim/baseball/application/CSharpLegacyAggregateBridge.kt",
  "apps/android/game-application/src/main/kotlin/com/solkim/baseball/application/CSharpLegacyProBridge.kt",
  "apps/android/game-core/src/main/kotlin/com/solkim/baseball/core/pitch/CommittedPitchReplay.kt",
  "apps/android/game-core/src/main/kotlin/com/solkim/baseball/core/pro/ProJourneyModels.kt",
  "apps/android/game-core/src/main/kotlin/com/solkim/baseball/core/pro/ProJourneyKernel.kt",
  "apps/android/game-core/src/main/kotlin/com/solkim/baseball/core/pro/ProJourneyStateCodec.kt",
  "apps/android/game-core/src/main/kotlin/com/solkim/baseball/core/pro/ProStateCodecV2.kt",
  "apps/android/game-core/src/main/kotlin/com/solkim/baseball/core/pro/ProJourneyCommands.kt",
  "apps/android/game-core/src/main/kotlin/com/solkim/baseball/core/pro/ProCareerDistributionRunner.kt",
  "apps/android/game-core/src/test/resources/fixtures/swift-pro-career-oracle-v2.json",
  "apps/android/game-application/src/main/kotlin/com/solkim/baseball/application/ProCareerJourneyApplication.kt",
  "apps/android/feature-career/src/main/kotlin/com/solkim/baseball/feature/career/ProCareerJourneyScreens.kt",
  "apps/android/game-core/src/test/resources/fixtures/csharp-pitch-oracle-v1.json",
  "apps/android/game-core/src/test/resources/fixtures/swift-pitch-kernel-approved-v2.json",
  "apps/android/game-core/src/test/resources/fixtures/swift-pitch-kernel-current-v1.json",
  "apps/android/game-core/src/test/resources/fixtures/swift-simulation-engine-golden-v1.json",
  "apps/android/game-application/src/main/kotlin/com/solkim/baseball/application/PitchPresentationFactory.kt",
  "apps/android/unity-bridge/src/main/kotlin/com/solkim/baseball/bridge/PitchIpcCodec.kt",
  "apps/android/unity-bridge/src/main/kotlin/com/solkim/baseball/bridge/PitchSessionGate.kt",
  "apps/android/game-persistence/src/main/kotlin/com/solkim/baseball/persistence/LegacySaveCodec.kt",
  "apps/android-pitch-unity/Assets/PitchRuntime/Bridge/PitchBridgeReceiver.cs",
  "apps/android-pitch-unity/Assets/PitchRuntime/Rendering/PitchTrajectoryRenderer.cs",
  "tools/export-android-pitch-unity.sh",
  "tools/android-compose-build.sh",
  "tools/android-compose-instrumentation.sh",
  "tools/check-android-compose-release.mjs",
  "apps/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml",
  "apps/android/app/src/main/res/values/strings.xml",
];

const errors = [];
for (const relativePath of required) {
  if (!existsSync(resolve(root, relativePath))) errors.push(`missing: ${relativePath}`);
}

const manifest = readFileSync(resolve(root, "apps/android/app/src/main/AndroidManifest.xml"), "utf8");
const appGradle = readFileSync(resolve(root, "apps/android/app/build.gradle.kts"), "utf8");
const applicationRoot = readFileSync(
  resolve(root, "apps/android/app/src/main/java/com/solkim/baseball/android/BaseballApplication.kt"),
  "utf8",
);
const kotlinContract = readFileSync(
  resolve(root, "apps/android/game-model/src/main/kotlin/com/solkim/baseball/model/PitchIpcModels.kt"),
  "utf8",
);
const csharpContract = readFileSync(
  resolve(root, "apps/android-pitch-unity/Assets/PitchRuntime/Bridge/PitchIpcWire.cs"),
  "utf8",
);
const activity = readFileSync(
  resolve(root, "apps/android/app/src/main/java/com/solkim/baseball/android/PitchUnityActivity.kt"),
  "utf8",
);
const pitchKernel = readFileSync(
  resolve(root, "apps/android/game-core/src/main/kotlin/com/solkim/baseball/core/pitch/PitchKernel.kt"),
  "utf8",
);
const replayCodec = readFileSync(
  resolve(root, "apps/android/game-core/src/main/kotlin/com/solkim/baseball/core/pitch/CommittedPitchReplay.kt"),
  "utf8",
);
const highSchoolKernel = readFileSync(
  resolve(root, "apps/android/game-core/src/main/kotlin/com/solkim/baseball/core/highschool/HighSchoolKernel.kt"),
  "utf8",
);
const highSchoolCatalog = readFileSync(
  resolve(root, "apps/android/game-core/src/main/kotlin/com/solkim/baseball/core/highschool/HighSchoolContentCatalog.kt"),
  "utf8",
);
const highSchoolCodec = readFileSync(
  resolve(root, "apps/android/game-core/src/main/kotlin/com/solkim/baseball/core/highschool/HighSchoolStateCodec.kt"),
  "utf8",
);
const presentationFactory = readFileSync(
  resolve(root, "apps/android/game-application/src/main/kotlin/com/solkim/baseball/application/PitchPresentationFactory.kt"),
  "utf8",
);
const wave6Kernel = readFileSync(
  resolve(root, "apps/android/game-core/src/main/kotlin/com/solkim/baseball/core/pro/ProJourneyKernel.kt"),
  "utf8",
);
const wave6Codec = readFileSync(
  resolve(root, "apps/android/game-core/src/main/kotlin/com/solkim/baseball/core/pro/ProJourneyStateCodec.kt"),
  "utf8",
);
const wave6CommandCodec = readFileSync(
  resolve(root, "apps/android/game-core/src/main/kotlin/com/solkim/baseball/core/pro/ProJourneyCommands.kt"),
  "utf8",
);
const wave6Application = readFileSync(
  resolve(root, "apps/android/game-application/src/main/kotlin/com/solkim/baseball/application/ProCareerJourneyApplication.kt"),
  "utf8",
);
const wave6Feature = readFileSync(
  resolve(root, "apps/android/feature-career/src/main/kotlin/com/solkim/baseball/feature/career/ProCareerJourneyScreens.kt"),
  "utf8",
);
const unityRuntimeFiles = [
  "apps/android-pitch-unity/Assets/PitchRuntime/Bridge/PitchBridgeReceiver.cs",
  "apps/android-pitch-unity/Assets/PitchRuntime/Bridge/PitchIpcWire.cs",
  "apps/android-pitch-unity/Assets/PitchRuntime/Rendering/PitchTrajectoryRenderer.cs",
].map((relativePath) => readFileSync(resolve(root, relativePath), "utf8"));

const productLabel = readFileSync(resolve(root, "apps/android/app/src/main/res/values/strings.xml"), "utf8");
if (!productLabel.includes(">야구 못하면 또 환생함<")) {
  errors.push("product application label is not the Play store name");
}
if (!manifest.includes('android:icon="@mipmap/ic_launcher"') || !manifest.includes("<compatible-screens>")) {
  errors.push("Play launcher icon or smartphone screen filter is missing");
}
if (!manifest.includes('android:resizeableActivity="false"')) {
  errors.push("portrait-only resizeableActivity=false is not declared");
}
if (!appGradle.includes('applicationId = "com.solkim.baseball.android"')) {
  errors.push("production application ID is not explicit");
}
if (!appGradle.includes('applicationIdSuffix = ".compose.dev"')) {
  errors.push("debug fixture application ID suffix is not isolated");
}
if (!appGradle.includes('NATIVE_AUTHORITY_MODE", "\\"nativeAuthoritative\\"')) {
  errors.push("release nativeAuthoritative mode is not explicit");
}
if (!appGradle.includes('NATIVE_AUTHORITY_MODE", "\\"nativeShadowReadOnly\\"')) {
  errors.push("debug nativeShadowReadOnly mode is not explicit");
}
if (!applicationRoot.includes('getExternalFilesDir(null)') || !applicationRoot.includes('resolve("save")')) {
  errors.push("production external save location is not explicit");
}
const legacyRepository = readFileSync(
  resolve(root, "apps/android/game-application/src/main/kotlin/com/solkim/baseball/application/CSharpLegacyGameStoreRepository.kt"),
  "utf8",
);
const legacyBridge = readFileSync(
  resolve(root, "apps/android/game-application/src/main/kotlin/com/solkim/baseball/application/CSharpLegacyAggregateBridge.kt"),
  "utf8",
);
if (!legacyRepository.includes("CSharpLegacyAggregateBridge.apply")) {
  errors.push("native-authoritative repository does not apply the C# command bridge");
}
if (legacyRepository.includes("legacy_command_not_ported")) {
  errors.push("native-authoritative repository still fail-closes unported career commands");
}
if (!legacyBridge.includes("HighSchoolPhase4CommandStore") || !legacyBridge.includes("CSharpHighSchoolSnapshotWire")) {
  errors.push("C# legacy aggregate bridge is missing HighSchool write-back");
}
if (!manifest.includes("PitchUnityActivity") || !manifest.includes("MainActivity")) {
  errors.push("both shell and pitch activities must be declared");
}
if (!manifest.includes('android:name="com.unity3d.player.UnityPlayerActivity" tools:node="remove"')) {
  errors.push("generated Unity launcher must be removed so Compose MainActivity is the sole product launcher");
}
for (const marker of [
  'SCHEMA: String = "baseball-pitch-ipc-v1"',
  "SCHEMA_VERSION: Int = 1",
  "messageId",
  "sessionId",
  "presentationSeed",
  "PitchTerminalResult",
  "UNITY_UNLOADED",
]) {
  if (!kotlinContract.includes(marker)) errors.push(`Kotlin IPC contract marker missing: ${marker}`);
}
for (const marker of [
  "public object ProJourneyKernel",
  "public fun applyInvestment",
  "public fun settle",
  "public fun migrateLegacy",
  "public fun retirementPreview",
]) {
  if (!wave6Kernel.includes(marker)) errors.push(`Wave 6 journey kernel marker missing: ${marker}`);
}
for (const marker of [
  'SCHEMA: String = "baseball-pro-career-journey-state-v2"',
  "public fun encode",
  "public fun decode",
  "migrateV1",
  "stateCommitment",
]) {
  if (!wave6Codec.includes(marker)) errors.push(`Wave 6 journey codec marker missing: ${marker}`);
}
for (const marker of [
  'COMMAND_SCHEMA: String = "baseball-pro-career-command-v2"',
  "ApplyMediaChoice",
  "public fun encode",
  "public fun decode",
  "ProJourneyCommandKernel",
]) {
  if (!wave6CommandCodec.includes(marker)) errors.push(`Wave 6 command marker missing: ${marker}`);
}
for (const marker of [
  "ProCareerJourneyOrchestrator",
  "ProCareerJourneyAnalyticsProjector",
  "FIXTURE_COMPLETE_BOUNDARY",
  "productionSurfaceEnabled",
]) {
  if (!wave6Application.includes(marker)) errors.push(`Wave 6 application marker missing: ${marker}`);
}
for (const marker of [
  "ProCareerJourneySurface",
  "ProContractMarketScreen",
  "ProSettlementScreen",
  "ProInvestmentScreen",
  "ProRetirementScreen",
]) {
  if (!wave6Feature.includes(marker)) errors.push(`Wave 6 Compose surface marker missing: ${marker}`);
}
for (const marker of [
  'Schema = "baseball-pitch-ipc-v1"',
  "SchemaVersion = 1",
  "messageId",
  "sessionId",
  "presentationSeed",
]) {
  if (!csharpContract.includes(marker)) errors.push(`C# IPC contract marker missing: ${marker}`);
}
if (!activity.includes("unityHost.close()") || !activity.includes("OnBackPressedCallback")) {
  errors.push("pitch Activity must own explicit close and back lifecycle");
}
if (!activity.includes("onNewIntent") || !activity.includes("FLAG_ACTIVITY_REORDER_TO_FRONT")) {
  errors.push("pitch Activity must retain the one-runtime re-entry route");
}
if (!activity.includes("KotlinPitchPresentationSession") || activity.includes("DemoPitchRequests")) {
  errors.push("pitch Activity must use the Kotlin authoritative presentation session");
}
for (const marker of [
  "public class PitchKernel",
  "public fun prepare",
  "public fun submitPitch",
  "public data class TrajectoryPresentationSnapshot",
  "PitchAbilityRules",
  "effectiveFatigue",
  "MAXIMUM_EXECUTED_VELOCITY_TENTHS_KPH",
  "resolveFielding",
]) {
  if (!pitchKernel.includes(marker)) errors.push(`Kotlin PitchKernel marker missing: ${marker}`);
}
for (const marker of [
  'SCHEMA: String = "baseball-committed-pitch-replay-v1"',
  "json.unknown_field",
  "schemaVersion.unsupported",
  "terminal_required",
  "duplicate_replay",
]) {
  if (!replayCodec.includes(marker)) errors.push(`committed replay marker missing: ${marker}`);
}
for (const marker of [
  "public class HighSchoolKernel",
  "public fun start",
  "public fun commitTraining",
  "public fun recordImportantGame",
  "public fun resolveDraft",
  "stateCommitment",
]) {
  if (!highSchoolKernel.includes(marker)) errors.push(`HighSchool kernel marker missing: ${marker}`);
}
for (const marker of [
  "public enum class HighSchoolPhase",
  "public val chapters",
  "public val awakeningNodes",
  "BALANCE_VERSION: Int = 4",
]) {
  if (!highSchoolCatalog.includes(marker)) errors.push(`HighSchool catalog marker missing: ${marker}`);
}
for (const marker of [
  'SCHEMA: String = "baseball-high-school-state-v1"',
  "public fun encode",
  "public fun decode",
  "schema.future",
  "requireExact",
  "validateSavedState",
]) {
  if (!highSchoolCodec.includes(marker)) errors.push(`HighSchool state codec marker missing: ${marker}`);
}
for (const marker of [
  "KotlinPitchPresentationSession",
  "PitchPresentationRequest",
  "trajectoryPresentation",
  "PitchKind.FOUR_SEAM",
  "PitchKind.SLIDER",
  "PitchKind.CURVEBALL",
  "PitchKind.CHANGEUP",
]) {
  if (!presentationFactory.includes(marker)) errors.push(`presentation factory marker missing: ${marker}`);
}

// Unity receives a presentation snapshot and may acknowledge lifecycle/terminal state, but it
// must not acquire a gameplay result generator. Keep this scan intentionally narrow so the IPC
// terminal acknowledgement vocabulary remains allowed.
for (const source of unityRuntimeFiles) {
  for (const forbidden of ["PitchKernel", "PitchKernelResult", "SubmitPitch", "ResolvePitch", "GenerateResult", "GenerateOutcome"]) {
    if (source.includes(forbidden)) errors.push(`Unity runtime contains Kotlin/gameplay authority marker: ${forbidden}`);
  }
}

// This is intentionally a narrow source scan. It catches accidental real-world league/team
// copy in the new migration surface without treating the oracle's historical fixtures as product
// content. The shared copy checker remains the authority for the existing game content.
const blockedWorldTerms = ["KBO", "LG 트윈스", "한화 이글스", "SSG 랜더스", "삼성 라이온즈", "롯데 자이언츠", "KIA 타이거즈", "두산 베어스", "KT 위즈", "NC 다이노스", "키움 히어로즈"];
// Avoid recursive directory traversal here; the repository-level check-copy command remains the
// source of truth for copy. The new files above are checked by the explicit source snippets.
for (const term of blockedWorldTerms) {
  if (manifest.includes(term) || appGradle.includes(term) || kotlinContract.includes(term) || csharpContract.includes(term)) {
    errors.push(`real-world baseball IP found in migration contract: ${term}`);
  }
}

if (errors.length > 0) {
  console.error(`android-compose check failed (${errors.length})`);
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}

console.log("android-compose static/reference check passed");
