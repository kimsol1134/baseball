import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(new URL("..", import.meta.url).pathname);
const errors = [];
const read = (relative) => {
  const path = resolve(root, relative);
  if (!existsSync(path)) {
    errors.push(`${relative} is missing`);
    return "";
  }
  return readFileSync(path, "utf8");
};
const appGradle = read("apps/android/app/build.gradle.kts");
const platformGradle = read("apps/android/platform/build.gradle.kts");
const versionCatalog = read("apps/android/gradle/libs.versions.toml");
const manifest = read("apps/android/app/src/main/AndroidManifest.xml");
const lock = read("apps/android/app/gradle.lockfile");
const phase8Model = read("apps/android/game-application/src/main/kotlin/com/solkim/baseball/application/Phase8ScreenModels.kt");
const phase8Ui = read("apps/android/app/src/main/java/com/solkim/baseball/android/Phase9ComposePlatform.kt");
const phase8Screens = read("apps/android/app/src/main/java/com/solkim/baseball/android/Phase8Screens.kt");
const mainActivity = read("apps/android/app/src/main/java/com/solkim/baseball/android/MainActivity.kt");
const applicationRoot = read("apps/android/app/src/main/java/com/solkim/baseball/android/BaseballApplication.kt");
const analyticsProjector = read("apps/android/game-application/src/main/kotlin/com/solkim/baseball/application/Phase9AnalyticsProjector.kt");
const platformContracts = read("apps/android/platform/src/main/kotlin/com/solkim/baseball/platform/Phase9PlatformContracts.kt");
const highSchoolPhase4Kernel = read("apps/android/game-core/src/main/kotlin/com/solkim/baseball/core/highschool/HighSchoolPhase4Kernel.kt");
const highSchoolPhase4Codec = read("apps/android/game-core/src/main/kotlin/com/solkim/baseball/core/highschool/HighSchoolPhase4StateCodec.kt");
const generatedUnityGradle = read("artifacts/android-compose/unity-export/current/unityLibrary/build.gradle");
const generatedUnityManifest = read("artifacts/android-compose/unity-export/current/unityLibrary/src/main/AndroidManifest.xml");

if (!appGradle.includes('implementation(project(":platform"))')) errors.push("app does not own the native platform module");
if ((!platformGradle.includes("libs.firebase.analytics") && !platformGradle.includes("firebase-analytics")) ||
    (!platformGradle.includes("libs.firebase.crashlytics") && !platformGradle.includes("firebase-crashlytics")) ||
    (!platformGradle.includes("libs.amplitude.android") && !platformGradle.includes("amplitude-android")) ||
    (!platformGradle.includes("libs.play.review") && !platformGradle.includes("play-review")) ||
    !versionCatalog.includes("com.google.firebase:firebase-analytics") ||
    !versionCatalog.includes("com.google.firebase:firebase-crashlytics") ||
    !versionCatalog.includes("com.amplitude:android-sdk") ||
    !versionCatalog.includes("com.google.android.play:review")) errors.push("platform native SDK declarations are incomplete");
for (const forbidden of ["firebase-analytics-unity", "firebase-app-unity", "firebase-crashlytics-unity", "amplitude-unity", "com.amplitude.unityplugin", "com.unity.mobile.notifications", "com.google.play.review"]) {
  if (appGradle.includes(forbidden) || platformGradle.includes(forbidden) || generatedUnityGradle.includes(forbidden) || generatedUnityManifest.includes(forbidden)) {
    errors.push(`Compose runtime contains forbidden Unity platform dependency: ${forbidden}`);
  }
}
for (const required of [
  "com.google.firebase:firebase-analytics:23.2.0",
  "com.google.firebase:firebase-crashlytics:20.1.0",
  "com.amplitude:android-sdk:2.40.1",
  "com.google.android.play:review:2.0.2",
]) {
  if (!lock.includes(required)) errors.push(`dependency lock is missing ${required}`);
}
if (lock.includes("firebase-analytics-unity") || lock.includes("firebase-crashlytics-unity") || lock.includes("amplitude-unity")) errors.push("dependency lock contains a Unity platform wrapper");
if (!manifest.includes('android:name="androidx.core.content.FileProvider"') || !manifest.includes('android:exported="false"')) errors.push("share provider is not explicitly non-exported");
if (!manifest.includes("POST_NOTIFICATIONS") || !manifest.includes("VIBRATE")) errors.push("native notification/haptic permissions are not declared");
for (const forbiddenPermission of [
  "android.permission.WAKE_LOCK",
  "com.google.android.gms.permission.AD_ID",
  "com.google.android.finsky.permission.BIND_GET_INSTALL_REFERRER_SERVICE",
  "android.permission.ACCESS_ADSERVICES_ATTRIBUTION",
  "android.permission.ACCESS_ADSERVICES_AD_ID",
]) {
  if (!manifest.includes(`android:name="${forbiddenPermission}" tools:node="remove"`)) {
    errors.push(`final Compose manifest does not remove SDK permission: ${forbiddenPermission}`);
  }
}
if (appGradle.includes("google-services.json") || appGradle.includes("phase9AmplitudeApiKey = \"")) errors.push("production credentials are checked into the app build");
for (const forbiddenCopy of ["P-001", "nativeShadowReadOnly", "다음 업데이트에서 제공", "개발자 브라우저"]) {
  if (phase8Ui.includes(forbiddenCopy)) errors.push(`product platform UI leaks internal copy: ${forbiddenCopy}`);
}
if (phase8Model.includes("enableNotifications") || phase8Model.includes("다음 업데이트에서 제공")) errors.push("Phase 8 projection still exposes a fake platform action");
if (phase8Model.includes("P-023") || phase8Ui.includes("P-023")) errors.push("retired P-023 is exposed in product platform sources");
if (!phase8Ui.includes("PlatformActionCodec.decode") && !phase8Ui.includes("PlatformActionPayload")) errors.push("Compose platform actions do not carry typed captured payloads");

const semanticProductionSources = [
  phase8Model,
  phase8Ui,
  phase8Screens,
  mainActivity,
  applicationRoot,
  analyticsProjector,
  platformContracts,
  highSchoolPhase4Kernel,
  highSchoolPhase4Codec,
].join("\n");
for (const forbidden of ["permission_result", "resume_external_revoke", "settings_os_truth", "frozen_archive"]) {
  if (semanticProductionSources.includes(forbidden)) errors.push(`retired semantic caller remains: ${forbidden}`);
}
for (const line of semanticProductionSources.split("\n")) {
  if ((line.includes("entry_point") || line.includes("entry_path")) && line.includes('"recap"')) {
    errors.push("rebirth/recap entry payload still uses the retired recap sentinel");
  }
}

if (!applicationRoot.includes("fromStrings(") || !applicationRoot.includes("receiptId = receipt.receiptId")) {
  errors.push("BaseballApplication does not bind analytics parsing to receipt/event/key schema");
}
for (const marker of [
  "propertyKinds",
  "allowedTextValues",
  "fromStrings(receiptId: String, eventName: String",
  "parseStringValue(eventName, key, value)",
]) {
  if (!analyticsProjector.includes(marker) && !platformContracts.includes(marker)) {
    errors.push(`typed analytics boundary marker missing: ${marker}`);
  }
}
for (const marker of [
  "HighSchoolTrainingEvidence",
  "trainingEvidence",
  "commitTrainingBlock",
  "if (run.phase != HighSchoolPhase.TRAINING) break",
  "phase4.training_evidence_career",
]) {
  if (!highSchoolPhase4Kernel.includes(marker)) errors.push(`training evidence authority marker missing: ${marker}`);
}
if (!highSchoolPhase4Codec.includes("SCHEMA_VERSION: Int = 7") || !highSchoolPhase4Codec.includes("readTrainingEvidence")) {
  errors.push("training evidence codec is not versioned at schema 7");
}

if (!analyticsProjector.includes("current.trainingEvidence") || !analyticsProjector.includes('"career_training_completed"')) {
  errors.push("training analytics is not projected from the persisted evidence ledger");
}
const completePitchBranch = analyticsProjector.match(/is GameCommand\.CompletePitch[^\n]*/)?.[0] ?? "";
if (completePitchBranch.includes("first_pitch")) errors.push("generic CompletePitch remains a first_pitch caller");
if (!analyticsProjector.includes("previous?.challenge?.active != true") || !analyticsProjector.includes("current.challenge.active != true")) {
  errors.push("first_pitch challenge guard is incomplete");
}
const proLegacyBranchStart = analyticsProjector.indexOf("is ProCommand.SelectLegacy -> add(");
const proLegacyBranchEnd = analyticsProjector.indexOf("is ProCommand.FinishImportantGame", proLegacyBranchStart);
if (proLegacyBranchStart >= 0 && analyticsProjector.slice(proLegacyBranchStart, proLegacyBranchEnd).includes('"soul_bonus"')) {
  errors.push("pro_legacy_recorded fabricates soul_bonus without authoritative evidence");
}
const highSchoolGameReportStart = analyticsProjector.indexOf('"game_finished", "game:${before.pitch?.gameId');
const highSchoolGameReportEnd = analyticsProjector.indexOf("is ProCommand.StartLinked", highSchoolGameReportStart);
if (highSchoolGameReportStart >= 0 && analyticsProjector.slice(highSchoolGameReportStart, highSchoolGameReportEnd).match(/put\("(?:target_batters|batters)"/)) {
  errors.push("game_finished fabricates optional batter fields");
}

const p030Model = phase8Model.match(/Phase8ScreenId\.P030_REVIEW -> \{([\s\S]*?)\n            \}\n        \}/)?.[1] ?? "";
if (p030Model.includes("addAction(") || p030Model.includes("REQUEST_REVIEW")) {
  errors.push("P030 still exposes a generic/manual review product action");
}
const reviewSurfaceStart = phase8Ui.indexOf("private fun Phase9ReviewSurface");
const reviewSurface = reviewSurfaceStart >= 0 ? phase8Ui.slice(reviewSurfaceStart) : "";
if (reviewSurface.includes("Button(") || reviewSurface.includes("REQUEST_REVIEW")) {
  errors.push("P030 Compose surface still contains a review button/caller");
}
if (!mainActivity.includes("Phase8ScreenId.P014_RUN_RECAP.wire") || !mainActivity.includes("Phase8ScreenId.P015_REBIRTH.wire") ||
    !mainActivity.includes('"quickRebirth"') || !mainActivity.includes('"customizeRebirth"')) {
  errors.push("review caller is not limited to exact recap/rebirth product moments");
}

if (!phase8Screens.includes("selectedLifeCardId") || !phase8Screens.includes("Phase9LifeCardProjection.selected(state, selectedLifeCardCareerId)")) {
  errors.push("LifeCard legacy viewport is not bound to the chooser-selected archive record");
}
if (!analyticsProjector.includes('"player_legacy_seen" to "visible finalized recap/archive/next-life frozen record intersection"')) {
  errors.push("player_legacy_seen source contract is not exact");
}
if (!phase8Ui.includes("ReminderOfferPolicy.shouldShow") || !phase8Ui.includes("offerDeclined")) {
  errors.push("reminder offer UI is not gated by durable product dismissal truth");
}
if (!mainActivity.includes('"after_first_game"') || !mainActivity.includes('"settings"') || !mainActivity.includes('"system"')) {
  errors.push("reminder_changed does not have all three explicit source callers");
}

if (errors.length) {
  console.error(`android Phase 9 dependency/source check failed (${errors.length})`);
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}
console.log("android Phase 9 dependency/source check passed");
