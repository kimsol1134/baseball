import { createHash } from "node:crypto";
import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const projectRoot = path.join(repoRoot, "apps", "android-unity");

function fail(message) {
  throw new Error(`Android Unity release contract: ${message}`);
}

function requireCondition(condition, message) {
  if (!condition) fail(message);
}

function text(relativePath) {
  const absolutePath = path.join(repoRoot, relativePath);
  requireCondition(existsSync(absolutePath), `missing ${relativePath}`);
  return readFileSync(absolutePath, "utf8");
}

function bytes(relativePath) {
  const absolutePath = path.join(repoRoot, relativePath);
  requireCondition(existsSync(absolutePath), `missing ${relativePath}`);
  return readFileSync(absolutePath);
}

function sha256(relativePath) {
  return createHash("sha256").update(bytes(relativePath)).digest("hex");
}

function readPngContract(relativePath) {
  const png = bytes(relativePath);
  const signature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  requireCondition(png.length >= 33 && png.subarray(0, 8).equals(signature), `${relativePath} is not a PNG`);
  requireCondition(png.toString("ascii", 12, 16) === "IHDR", `${relativePath} has no leading IHDR`);
  return {
    width: png.readUInt32BE(16),
    height: png.readUInt32BE(20),
    bitDepth: png[24],
    colorType: png[25],
  };
}

function walk(directory) {
  if (!existsSync(directory)) return [];
  const result = [];
  for (const entry of readdirSync(directory)) {
    const absolutePath = path.join(directory, entry);
    result.push(absolutePath);
    if (statSync(absolutePath).isDirectory()) result.push(...walk(absolutePath));
  }
  return result;
}

const packageManifestPath = "apps/android-unity/Packages/manifest.json";
const packageLockPath = "apps/android-unity/Packages/packages-lock.json";
const packageManifest = JSON.parse(text(packageManifestPath));
const packageLock = JSON.parse(text(packageLockPath));
const exactPackages = {
  "com.google.play.common": "file:com.google.play.common",
  "com.google.play.core": "file:com.google.play.core",
  "com.google.play.review": "file:com.google.play.review",
  "com.unity.addressables": "2.9.1",
  "com.unity.inputsystem": "1.19.0",
  "com.unity.mobile.notifications": "2.4.3",
  "com.unity.modules.accessibility": "1.0.0",
  "com.unity.modules.audio": "1.0.0",
  "com.unity.modules.particlesystem": "1.0.0",
  "com.unity.modules.physics": "1.0.0",
  "com.unity.modules.screencapture": "1.0.0",
  "com.unity.nuget.newtonsoft-json": "3.2.2",
  "com.unity.render-pipelines.universal": "17.3.0",
  "com.unity.test-framework": "1.6.0",
};
requireCondition(
  JSON.stringify(packageManifest.dependencies) === JSON.stringify(exactPackages),
  `${packageManifestPath} must contain only the approved exact dependencies in stable order`,
);
for (const [name, version] of Object.entries(exactPackages)) {
  const locked = packageLock.dependencies[name];
  requireCondition(locked, `${name} is absent from packages-lock.json`);
  requireCondition(locked.version === version, `${name} lock is ${locked.version}, expected ${version}`);
}
const managedLinkerContract = text(
  "apps/android-unity/Assets/Game/Application/Persistence/link.xml",
);
for (const contract of [
  '<assembly fullname="UnityEngine.PhysicsModule">',
  '<type fullname="UnityEngine.SphereCollider" preserve="all" />',
]) {
  requireCondition(
    managedLinkerContract.includes(contract),
    `pitch primitive IL2CPP preservation contract missing '${contract}'`,
  );
}
for (const prohibited of ["ads", "analytics", "iap", "authentication", "gameservices"]) {
  requireCondition(
    !Object.keys(packageManifest.dependencies).some((name) => name.toLowerCase().includes(prohibited)),
    `prohibited Unity service package contains '${prohibited}'`,
  );
}

const androidManifestPath =
  "apps/android-unity/Assets/Plugins/Android/BaseballManifest.androidlib/AndroidManifest.xml";
const androidManifest = text(androidManifestPath);
const activePermissions = [];
const removedPermissions = [];
for (const match of androidManifest.matchAll(/<uses-permission\b([^>]*?)\/?\s*>/gs)) {
  const attributes = match[1];
  const name = attributes.match(/android:name="([^"]+)"/)?.[1];
  requireCondition(name, "uses-permission without android:name");
  if (/tools:node="remove"/.test(attributes)) removedPermissions.push(name);
  else activePermissions.push(name);
}
const expectedPermissions = [
  "android.permission.ACCESS_NETWORK_STATE",
  "android.permission.INTERNET",
  "android.permission.POST_NOTIFICATIONS",
  "android.permission.VIBRATE",
];
requireCondition(
  JSON.stringify(activePermissions.sort()) === JSON.stringify(expectedPermissions.sort()),
  `active permissions differ: ${activePermissions.join(", ")}`,
);
for (const removed of [
  "android.permission.ACCESS_COARSE_LOCATION",
  "android.permission.ACCESS_FINE_LOCATION",
  "com.google.android.gms.permission.AD_ID",
]) {
  requireCondition(removedPermissions.includes(removed), `${removed} must be explicitly removed`);
}
requireCondition(!androidManifest.includes("<queries"), "broad package visibility is forbidden");
const expectedScreenPairs = ["small", "normal"].flatMap((size) =>
  ["ldpi", "mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi"].map(
    (density) => `${size}:${density}`,
  ),
).sort();
const screenPairs = [...androidManifest.matchAll(/<screen\b([^>]*?)\/?\s*>/gs)]
  .map((match) => {
    const size = match[1].match(/android:screenSize="([^"]+)"/)?.[1];
    const density = match[1].match(/android:screenDensity="([^"]+)"/)?.[1];
    requireCondition(size && density, "compatible screen entry is missing size or density");
    return `${size}:${density}`;
  })
  .sort();
requireCondition(
  JSON.stringify(screenPairs) === JSON.stringify(expectedScreenPairs),
  `compatible-screens must exactly match smartphone size/density pairs: ${screenPairs.join(", ")}`,
);
requireCondition(
  /android:name="com\.solkim\.baseball\.platform\.ShareFileProvider"/.test(androidManifest)
    && /android:authorities="\$\{applicationId\}\.baseball\.share"/.test(androidManifest)
    && /android:exported="false"/.test(androidManifest),
  "cache share provider must be non-exported and application-scoped",
);
requireCondition(/android:allowBackup="false"/.test(androidManifest), "Android backup must be disabled");
requireCondition(/android:usesCleartextTraffic="false"/.test(androidManifest), "cleartext traffic must be disabled");
for (const disabledCollection of [
  "firebase_analytics_collection_enabled",
  "firebase_crashlytics_collection_enabled",
]) {
  requireCondition(
    new RegExp(`android:name="${disabledCollection}"[\\s\\S]*?android:value="false"`).test(androidManifest),
    `${disabledCollection} must default to false before runtime production opt-in`,
  );
}

const buildSource = text("apps/android-unity/Assets/Game/Editor/Build/AndroidBuild.cs");
for (const contract of [
  'ApplicationId = "com.solkim.baseball.android"',
  'BootScenePath = "Assets/Game/Bootstrap/00_Bootstrap.unity"',
  "AndroidApiLevel26",
  "AndroidApiLevel36",
  "AndroidArchitecture.ARM64",
  "ScriptingImplementation.IL2CPP",
  "GraphicsDeviceType.OpenGLES3",
  "buildAppBundle = true",
  "androidCreateSymbols = AndroidCreateSymbols.Public",
  '\\"eventSchema\\": 2',
  '\\"environment\\":',
  "Android artifact directory must be empty before a build",
  "must be outside the repository workspace",
  "HasZipSignature",
  'InternalQaDefine = "BASEBALL_INTERNAL_QA"',
  "BuildOptions.Development",
  "extraScriptingDefines = extraScriptingDefines",
  "ValidateQaBuildBoundary",
  "ValidateNoPersistentQaDefines",
  "Internal QA symbols must be supplied only by the LocalVerification BuildPlayerOptions boundary.",
  '\\"developmentBuild\\"',
  '\\"internalQaCompiled\\"',
]) {
  requireCondition(buildSource.includes(contract), `build contract missing '${contract}'`);
}
const shellHostSource = text(
  "apps/android-unity/Assets/Game/Presentation/Shell/BaseballShellHost.cs",
);
const pitchFlowSource = text(
  "apps/android-unity/Assets/Game/Presentation/Pitch/Runtime/PitchShellFlowCoordinator.cs",
);
const pitchStageSource = text(
  "apps/android-unity/Assets/Game/Presentation/Pitch/Runtime/PitchStageController.cs",
);
const pitchStageShaderPath =
  "apps/android-unity/Assets/Game/Presentation/Pitch/Resources/PitchStageUnlit.shader";
const pitchStageShaderMetaPath = `${pitchStageShaderPath}.meta`;
const graphicsSettingsPath = "apps/android-unity/ProjectSettings/GraphicsSettings.asset";
requireCondition(
  existsSync(path.join(repoRoot, pitchStageShaderPath)),
  `missing checked-in pitch stage shader ${pitchStageShaderPath}`,
);
requireCondition(
  existsSync(path.join(repoRoot, pitchStageShaderMetaPath)),
  `missing checked-in pitch stage shader metadata ${pitchStageShaderMetaPath}`,
);
const pitchStageShader = text(pitchStageShaderPath);
const pitchStageShaderMeta = text(pitchStageShaderMetaPath);
const graphicsSettings = text(graphicsSettingsPath);
for (const contract of [
  'Shader "Baseball/PitchStageUnlit"',
  '"RenderPipeline" = "UniversalPipeline"',
]) {
  requireCondition(pitchStageShader.includes(contract), `pitch stage shader contract missing '${contract}'`);
}
for (const contract of [
  "Resources.Load<Shader>",
  "PitchStageVisualPolicy.ShaderUnavailableError",
  "BASEBALL_PITCH_STAGE_SHADER_READY schema=1 status=passed",
]) {
  requireCondition(pitchStageSource.includes(contract), `pitch shader runtime contract missing '${contract}'`);
}
requireCondition(
  !pitchStageSource.includes("Shader.Find("),
  "pitch stage must not depend on a strip-prone runtime Shader.Find lookup",
);
for (const contract of [
  "EnsurePitchStageShaderAlwaysIncluded();",
  "ValidatePitchStageShaderResource();",
  "m_AlwaysIncludedShaders",
  "SerializedObject",
  "PitchStageUnlit.shader",
  "vulnerable to shader stripping",
]) {
  requireCondition(buildSource.includes(contract), `pitch shader build contract missing '${contract}'`);
}
const pitchStageShaderGuid = "79f07846e39b46c986657c06a0d5cc1a";
requireCondition(
  pitchStageShaderMeta.includes(`guid: ${pitchStageShaderGuid}`),
  "pitch stage shader metadata GUID is missing or stale",
);
requireCondition(
  graphicsSettings.includes(`{fileID: 4800000, guid: ${pitchStageShaderGuid}, type: 3}`),
  "pitch stage shader must be checked into GraphicsSettings Always Included Shaders",
);
for (const contract of [
  "Object.DontDestroyOnLoad(root)",
  'new GameObject("Pitch Presentation Stage")',
  "await _stage.PrepareVisualsAsync",
  "DestroyStage();",
  "_stadiumLease?.Dispose()",
  "_batterLease?.Dispose()",
  "_catcherLease?.Dispose()",
]) {
  requireCondition(
    shellHostSource.includes(contract) || pitchFlowSource.includes(contract) || pitchStageSource.includes(contract),
    `single-scene presentation lifecycle contract missing '${contract}'`,
  );
}

const iconConfiguration = text(
  "apps/android-unity/Assets/Game/Editor/Build/AndroidIconConfiguration.cs",
);
for (const iconPath of [
  "apps/android-unity/Assets/Game/Art/PlatformIcons/AppIcon.png",
  "apps/android-unity/Assets/Game/Art/PlatformIcons/AndroidAdaptiveBackground.png",
  "apps/android-unity/Assets/Game/Art/PlatformIcons/AndroidAdaptiveForeground.png",
  "apps/android-unity/Assets/Game/Art/PlatformIcons/AndroidMonochrome.png",
]) {
  requireCondition(existsSync(path.join(repoRoot, iconPath)), `missing Android icon source ${iconPath}`);
}
for (const contract of [
  "AndroidPlatformIconKind.Adaptive",
  "icon.SetTextures(new[] { background, foreground })",
  "IPostGenerateGradleAndroidProject",
  "baseball_android_monochrome",
  "No generated adaptive launcher icon XML was found",
]) {
  requireCondition(iconConfiguration.includes(contract), `Android icon contract missing '${contract}'`);
}
requireCondition(
  buildSource.includes("AndroidIconConfiguration.ConfigurePlayerIcons()"),
  "Android build must configure launcher icons before Gradle generation",
);
requireCondition(
  buildSource.includes("PlayerSettings.SetIl2CppCompilerConfiguration(")
    && buildSource.includes("Il2CppCompilerConfiguration.Release")
    && buildSource.includes("ValidateIl2CppCompilerConfiguration()")
    && buildSource.includes("PlayerSettings.GetIl2CppCompilerConfiguration(NamedBuildTarget.Android)"),
  "Android build must compile generated IL2CPP C++ with Release optimizations",
);
const projectSettings = text("apps/android-unity/ProjectSettings/ProjectSettings.asset");
requireCondition(
  /il2cppCompilerConfiguration:\s*\n\s+Android:\s+1\b/.test(projectSettings),
  "Android ProjectSettings must default to the IL2CPP Release compiler configuration",
);

const storeAssetManifestPath = "apps/android-unity/StoreAssets/manifest.json";
const storeAssetManifest = JSON.parse(text(storeAssetManifestPath));
requireCondition(
  storeAssetManifest.schema === "baseball-android-store-assets-v1",
  `${storeAssetManifestPath} has an unsupported schema`,
);
requireCondition(storeAssetManifest.locale === "ko-KR", "store assets must be scoped to ko-KR");
const storeAssetContracts = new Map([
  ["feature-graphic", { path: "apps/android-unity/StoreAssets/FeatureGraphic-1024x500.png", width: 1024, height: 500 }],
  ["store-icon", { path: "apps/android-unity/StoreAssets/StoreIcon-512x512.png", width: 512, height: 512 }],
]);
requireCondition(
  Array.isArray(storeAssetManifest.entries)
    && storeAssetManifest.entries.length === storeAssetContracts.size,
  "store asset manifest must contain exactly the feature graphic and store icon",
);
const declaredStoreImages = new Set();
for (const entry of storeAssetManifest.entries ?? []) {
  const contract = storeAssetContracts.get(entry.kind);
  requireCondition(contract, `unknown store asset kind ${entry.kind ?? "<missing>"}`);
  requireCondition(entry.path === contract.path, `${entry.kind} path differs from the release contract`);
  requireCondition(
    entry.width === contract.width && entry.height === contract.height,
    `${entry.path} declares ${entry.width}x${entry.height}, expected ${contract.width}x${contract.height}`,
  );
  requireCondition(entry.pngColorType === 2, `${entry.path} must declare an RGB PNG`);
  requireCondition(sha256(entry.path) === entry.sha256, `${entry.path} checksum differs from its manifest`);
  const png = readPngContract(entry.path);
  requireCondition(
    png.width === entry.width && png.height === entry.height,
    `${entry.path} is ${png.width}x${png.height}, expected ${entry.width}x${entry.height}`,
  );
  requireCondition(
    png.bitDepth === 8 && png.colorType === entry.pngColorType,
    `${entry.path} must be an 8-bit RGB PNG without alpha`,
  );
  requireCondition(
    typeof entry.provenance === "string" && entry.provenance.length > 20,
    `${entry.path} has no useful provenance record`,
  );
  requireCondition(
    Array.isArray(entry.sourceReferences) && entry.sourceReferences.length > 0,
    `${entry.path} has no source references`,
  );
  for (const source of entry.sourceReferences ?? []) {
    requireCondition(sha256(source.path) === source.sha256, `${source.path} source checksum drifted`);
  }
  declaredStoreImages.add(entry.path);
}
const actualStoreImages = walk(path.join(projectRoot, "StoreAssets"))
  .filter((absolutePath) => statSync(absolutePath).isFile() && absolutePath.toLowerCase().endsWith(".png"))
  .map((absolutePath) => path.relative(repoRoot, absolutePath).split(path.sep).join("/"));
requireCondition(
  actualStoreImages.every((relativePath) => declaredStoreImages.has(relativePath)),
  "StoreAssets contains an unmanifested PNG",
);
requireCondition(
  storeAssetManifest.releaseScreenshots?.status === "requires-signed-build-and-physical-device-evidence"
    && storeAssetManifest.releaseScreenshots?.orientation === "portrait"
    && storeAssetManifest.releaseScreenshots?.formFactor === "phone",
  "release screenshots must remain a portrait-phone signed-build evidence gate",
);
for (const contract of ["OpenAI imagegen", "실존 구단명", "프로덕션 서명 AAB", "npm run check:android:unity"]) {
  requireCondition(
    text("apps/android-unity/StoreAssets/README.md").includes(contract),
    `store asset documentation missing '${contract}'`,
  );
}

const addressablesConfiguration = text(
  "apps/android-unity/Assets/Game/Editor/Build/LocalAddressablesConfiguration.cs",
);
for (const contract of [
  'GroupName = "Baseball Local Content"',
  "BuildRemoteCatalog = false",
  "PlayerBuildOption.BuildWithPlayer",
  "AddressableAssetSettings.kLocalBuildPath",
  "AddressableAssetSettings.kLocalLoadPath",
  "BundlePackingMode.PackTogetherByLabel",
  "BundleCompressionMode.LZ4",
  "UseAssetBundleCrc = true",
  "Remote Addressables catalogs are forbidden",
]) {
  requireCondition(
    addressablesConfiguration.includes(contract),
    `local Addressables contract missing '${contract}'`,
  );
}
requireCondition(
  buildSource.includes("LocalAddressablesConfiguration.EnsureConfigured()"),
  "Android build must synchronize local Addressables before checking release cleanliness",
);

const renderPipelineConfiguration = text(
  "apps/android-unity/Assets/Game/Editor/Build/MobileRenderPipelineConfiguration.cs",
);
for (const contract of [
  "UniversalRenderPipelineAsset.Create()",
  "GraphicsSettings.defaultRenderPipeline = pipeline",
  "QualitySettings.renderPipeline = pipeline",
  "pipeline.supportsHDR = false",
  "pipeline.shadowDistance = 0f",
  "pipeline.maxAdditionalLightsCount = 0",
]) {
  requireCondition(
    renderPipelineConfiguration.includes(contract),
    `mobile URP contract missing '${contract}'`,
  );
}
requireCondition(
  buildSource.includes("MobileRenderPipelineConfiguration.EnsureConfigured()"),
  "Android player configuration must assign the mobile URP asset",
);

const startupMarker = text(
  "apps/android-unity/Assets/Game/Platform/InternalQa/StartupEvidence/FirstInteractiveMarker.cs",
);
requireCondition(
  text("apps/android-unity/Assets/Game/Platform/InternalQa/StartupEvidence/StartupEvidenceAssemblyInfo.cs")
    .includes("[assembly: AlwaysLinkAssembly]"),
  "first-interactive evidence assembly must survive managed stripping",
);
for (const contract of [
  "BASEBALL_FIRST_INTERACTIVE schema=1 status=passed",
  "RuntimeGameServices.IsReady",
  'Q<VisualElement>("shell-root")',
  "HasInteractiveButton",
  "TimeoutSeconds = 60f",
  "[Preserve]",
]) {
  requireCondition(startupMarker.includes(contract), `first-interactive contract missing '${contract}'`);
}
for (const forbidden of ["AndroidJavaObject", "baseball.qa.command", "ResetAsync(", "ForceCrash"])
  requireCondition(!startupMarker.includes(forbidden), `production marker exposes '${forbidden}'`);

const internalQaContractsPath =
  "apps/android-unity/Assets/Game/Platform/InternalQa/Development/InternalQaContracts.cs";
const internalQaBridgePath =
  "apps/android-unity/Assets/Game/Platform/InternalQa/Development/InternalQaBridge.cs";
const internalQaContracts = text(internalQaContractsPath);
const internalQaBridge = text(internalQaBridgePath);
for (const [relativePath, source] of [
  [internalQaContractsPath, internalQaContracts],
  [internalQaBridgePath, internalQaBridge],
]) {
  requireCondition(
    source.startsWith("#if UNITY_EDITOR || (DEVELOPMENT_BUILD && BASEBALL_INTERNAL_QA)\n"),
    `${relativePath} must be absent unless Editor or both development guards are active`,
  );
  requireCondition(source.trimEnd().endsWith("#endif"), `${relativePath} must close its outer QA guard`);
}
const unityStaticProject = text("tools/unity-static-tests/Baseball.UnityStatic.Tests.csproj");
for (const contract of [
  "<DefineConstants>UNITY_EDITOR</DefineConstants>",
  "InternalQaContracts.cs",
  "InternalQaContractTests.cs",
]) {
  requireCondition(
    unityStaticProject.includes(contract),
    `standalone internal QA test gate missing '${contract}'`,
  );
}
for (const contract of [
  'CommandExtra = "baseball.qa.command"',
  'SeedExtra = "baseball.qa.seed"',
  'PhaseExtra = "baseball.qa.phase"',
  'QualityExtra = "baseball.qa.quality"',
  '"tutorial-checkpoint"',
  '"pitch-sample"',
  '"save-corruption"',
  '"save-fault"',
  '"save-failure"',
  '"analytics-fake"',
]) {
  requireCondition(internalQaContracts.includes(contract), `internal QA request contract missing '${contract}'`);
}
for (const contract of [
  "RuntimeGameServices.TryGetStore",
  "StartHighSchoolCareerCommand",
  "BeginPitchSessionCommand",
  "PitchCareerKind.Tutorial",
  "PitchStageController",
  "AddressableVisualAssetLoader",
  "PrepareVisualsAsync",
  'SendMessage("ApplyQuality"',
  "CrashReporting.RecordUnexpected",
  "ForcedCrashCategory.Abort",
  "SaveLoadStatus.RecoveredBackup",
  "SaveFaultPoint.AfterCanonicalSwap",
  "ENOSPC simulated by internal QA",
  'Path.Combine(UnityEngine.Application.persistentDataPath, "internal-qa")',
  "AnalyticsDestinationKind.Test",
  "tutorial_checkpoint_restored",
  'intent.Call("removeExtra", key)',
]) {
  requireCondition(internalQaBridge.includes(contract), `internal QA bridge contract missing '${contract}'`);
}
requireCondition(
  !internalQaBridge.includes('Call<AndroidJavaObject>("removeExtra"'),
  "internal QA intent cleanup must use Android Intent.removeExtra(String)'s void JNI signature",
);
requireCondition(
  buildSource.includes(
    "Release candidate builds must exclude BuildOptions.Development and BASEBALL_INTERNAL_QA.",
  ),
  "release candidate build must fail closed when an internal QA guard is present",
);
requireCondition(
  buildSource.indexOf("ConfigurePlayer()") <
    buildSource.indexOf("GitState git = ReadGitState(repositoryRoot)")
    && buildSource.indexOf("ApplyBuildVersion(version, versionCode)") >
      buildSource.indexOf("GitState git = ReadGitState(repositoryRoot)"),
  "generated settings must pass the clean gate before the temporary build version is applied",
);
requireCondition(
  buildSource.includes("ApplyBuildVersion(originalVersion, originalVersionCode)")
    && buildSource.includes("Release candidate build changed tracked or untracked source after restoring its build-time version."),
  "Android builds must restore the project version and recheck RC source cleanliness",
);
const editorAssembly = JSON.parse(text("apps/android-unity/Assets/Game/Editor/Baseball.Editor.asmdef"));
for (const reference of [
  "Unity.Addressables.Editor",
  "Unity.RenderPipelines.Core.Runtime",
  "Unity.RenderPipelines.Universal.Runtime",
]) {
  requireCondition(
    editorAssembly.references.includes(reference),
    `Baseball.Editor asmdef must reference ${reference}`,
  );
}
const referenceCompileRunner = text("tools/unity-reference-compile.sh");
for (const contract of [
  "build_runtime_closure production false",
  "build_runtime_closure internal-qa true",
  "Baseball.UnityEditorReferenceCompile.csproj",
  "UnityEditor.Android.Extensions.dll",
  "Unity 6000.3 Android Editor reference compile",
]) {
  requireCondition(
    referenceCompileRunner.includes(contract),
    `Unity reference compile gate missing '${contract}'`,
  );
}
const editorReferenceProject = text(
  "tools/unity-reference-compile/Baseball.UnityEditorReferenceCompile.csproj",
);
const runtimeReferenceProject = text(
  "tools/unity-reference-compile/Baseball.UnityReferenceCompile.csproj",
);
requireCondition(
  runtimeReferenceProject.includes(
    "UNITY_ANDROID;UNITY_6000_0_OR_NEWER;ENABLE_INPUT_SYSTEM;DEVELOPMENT_BUILD;BASEBALL_INTERNAL_QA",
  ) && !runtimeReferenceProject.includes(
    "UNITY_ANDROID;UNITY_EDITOR;UNITY_6000_0_OR_NEWER;ENABLE_INPUT_SYSTEM;DEVELOPMENT_BUILD",
  ),
  "internal QA reference compile must exercise Android player branches without UNITY_EDITOR",
);
for (const contract of [
  "Assets/Game/Editor/**/*.cs",
  "TreatWarningsAsErrors>true",
  "$(UnityAndroidEditorDll)",
  "$(UnityUrpDll)",
]) {
  requireCondition(
    editorReferenceProject.includes(contract),
    `Unity Editor reference project missing '${contract}'`,
  );
}

for (const contract of [
  "ValidateServiceConfiguration(projectRoot, kind)",
  "Production RC requires injected analytics-config.generated.json and google-services.json",
  "google-services.json does not contain the Android package",
  "Local verification cannot use a production analytics configuration",
  "IsLocalVerificationPostprocessActive",
]) {
  requireCondition(buildSource.includes(contract), `service build contract missing '${contract}'`);
}
requireCondition(
  text("apps/android-unity/Assets/Game/Editor/Build/AndroidIconConfiguration.cs").includes(
    "com.google.firebase.provider.FirebaseInitProvider",
  ),
  "local verification manifest must remove FirebaseInitProvider",
);

for (const relativePath of [
  "apps/android-unity/Assets/Game/Platform/Analytics/AnalyticsSdkDestinations.cs",
  "apps/android-unity/Assets/Game/Platform/Analytics/AnalyticsBootstrap.cs",
  "apps/android-unity/Assets/Game/Platform/Crash/FirebaseCrashReporter.cs",
  "apps/android-unity/Assets/Game/Platform/Crash/CrashReportingBootstrap.cs",
]) {
  const source = text(relativePath);
  requireCondition(
    !source.includes("BASEBALL_FIREBASE_") && !source.includes("BASEBALL_AMPLITUDE_SDK"),
    `${relativePath} must compile SDK destinations independently of build symbols`,
  );
}

const analyticsDestinations = text(
  "apps/android-unity/Assets/Game/Platform/Analytics/AnalyticsSdkDestinations.cs",
);
for (const disabledField of [
  "disableADID",
  "disableAppSetId",
  "disableCarrier",
  "disableCity",
  "disableCountry",
  "disableDMA",
  "disableIPAddress",
  "disableLatLng",
  "disableRegion",
]) {
  requireCondition(
    analyticsDestinations.includes(`["${disabledField}"] = true`),
    `Amplitude tracking field ${disabledField} must be disabled with the exact bridge key`,
  );
}

const androidWorkflow = text(".github/workflows/unity-android.yml");
requireCondition(
  !/^\s*- uses:\s+actions\/[^@\s]+@v\d+/m.test(androidWorkflow),
  "secret-bearing Android workflow actions must be pinned to full commit SHAs",
);
for (const contract of [
  "BASEBALL_FIREBASE_SERVICE_ACCOUNT_B64",
  "BASEBALL_UPLOAD_CERT_SHA256",
  "GOOGLE_APPLICATION_CREDENTIALS",
  "firebase-tools@15.26.0",
  "crashlytics:symbols:upload",
  "Install locked Firebase CLI before exposing credentials",
  "firebase-symbol-upload.log",
  "firebase-symbol-upload.json",
]) {
  requireCondition(androidWorkflow.includes(contract), `Android CI workflow missing '${contract}'`);
}
for (const contract of [
  'tools/android-unity-smoke/**',
  'apps/ios/Sources/**',
  'packages/simulation-core/**',
  "github.event_name != 'workflow_dispatch' || inputs.run_unity",
  "Remove injected signing and service credentials",
  "Signed production candidate (device gate pending)",
  "BASEBALL_REQUIRE_UNITY_META=1",
]) {
  requireCondition(androidWorkflow.includes(contract), `Android CI workflow missing '${contract}'`);
}

const unityTestRunner = text("tools/unity-android-test.sh");
for (const contract of [
  "test result XML is missing or empty",
  "did not execute any tests",
  "failures !== 0",
  "No valid Unity Editor license",
  '-assemblyNames "$assembly_names"',
  "editmode_assemblies=(",
  "Baseball.Core.Tests",
  "bootstrap_tests=(",
  "PreparedResetFailureSuppressesPauseRewriteAndCandidateRestartsCleanly",
  "persistence_tests=(",
  "OneHundredSaveReloadCycles_PreserveStateHashInputs",
  "BASEBALL_UNITY_TEST_PROCESS_TIMEOUT_SECONDS",
  "BASEBALL_UNITY_COMPLETED_SHUTDOWN_GRACE_SECONDS",
  "Test run completed. Exiting with code 0 (Ok). Run completed.",
  'kill -TERM "$unity_pid"',
  'kill -KILL "$unity_pid"',
  'run_tests EditMode "$evidence_name"',
  "run_tests PlayMode playmode Baseball.PlayMode.Tests",
]) {
  requireCondition(unityTestRunner.includes(contract), `Unity test fail-closed contract missing '${contract}'`);
}
requireCondition(
  !unityTestRunner.includes("    -quit \\\n"),
  "Unity test runner must let -runTests own shutdown so result XML is written",
);
const unityBuildRunner = text("tools/unity-android-build.sh");
for (const contract of [
  "Android build evidence invalid",
  "AAB SHA-256 mismatch",
  "IL2CPP symbol SHA-256 mismatch",
  "jarsigner -verify -certs",
  "jar verified.",
  "BASEBALL_UPLOAD_CERT_SHA256",
  "aab-signing-cert.sha256",
  "PAGE_ALIGNMENT_16K",
  "dump manifest",
  "merged-manifest.xml",
  "Merged Android manifest invalid",
  "active permissions differ",
  "normalizedScreenOrientation",
  'value === "1" ? "portrait"',
  '"200": "small", "300": "normal"',
  "com.solkim.baseball.android.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION",
  "AndroidX dynamic receiver permission protectionLevel",
  "apkanalyzer",
  "apk-permissions.txt",
  "--mode=universal",
  "universal.apk",
  '"$zipalign_bin" -c -P 16 -v 4',
  '"$llvm_readelf" -lW',
  "elf-alignment.txt",
  "minimum_load_alignment=16384",
  "developmentBuild does not match build mode",
  "internalQaCompiled does not match build mode",
  "No valid Unity Editor license",
]) {
  requireCondition(unityBuildRunner.includes(contract), `Unity build fail-closed contract missing '${contract}'`);
}
requireCondition(
  unityBuildRunner.includes(".filter((line) => /^(?:android|com)\\.[A-Za-z0-9_.]+$/.test(line))"),
  "Unity build APK permission parser must preserve app-defined permission identifiers",
);
requireCondition(
  text("docs/android-unity/THIRD_PARTY_LOCK.md").includes("Firebase CLI (CI symbols upload only) | 15.26.0"),
  "Firebase CLI symbol uploader must be version-locked in THIRD_PARTY_LOCK.md",
);

const smokeRunner = text("tools/android-unity-smoke/run.sh");
for (const contract of [
  "bundletool",
  "jarsigner -verify -certs",
  "jar verified.",
  "airplane-mode enable",
  "POST_NOTIFICATIONS",
  "screenshot-dimensions.txt",
  "foreground_resumed=passed",
  "aab_16k_alignment=passed",
  "getconf PAGE_SIZE",
  "native_16k_execution=",
  "apk_16k_zipalign=passed",
  "arm64_elf_alignment=passed",
  "apk-permissions.txt",
  "com.solkim.baseball.android.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION",
  "apk-build-mode.txt",
  "manifest debuggable",
  'expected_debuggable="false"',
  '[[ "$smoke_mode" == "internal" ]] && expected_debuggable="true"',
  '[[ "$sdk_level" -ge 26 ]]',
  "notification_denial_result=\"not_applicable_api_lt_33\"",
  "background_resume_same_process=passed",
  "landscape_request_blocked=passed",
  "font_200_percent_launch=passed",
  "low_memory_callback=passed",
  "RUNNING_LOW",
  '"$height" -gt "$width"',
  "BASEBALL_SMOKE_MODE",
  'smoke_mode="${BASEBALL_SMOKE_MODE:-production}"',
  "BASEBALL_BUILD_MANIFEST",
  "BASEBALL_BUILD_CHECKSUMS",
  "BASEBALL_UPLOAD_CERT_SHA256",
  "build-evidence-link.txt",
  "AAB SHA-256 mismatch",
  "Git commit/dirty state mismatch",
  "aab-signing-cert.sha256",
  "BASEBALL_FIRST_INTERACTIVE schema=1 status=passed",
  "BASEBALL_PITCH_PRESENTATION_COMPLETED schema=1 status=passed",
  "production_pitch_on_16k=",
  "rc_build_evidence=",
  "wait_for_app_marker",
  "expected_marker=",
  "baseball.qa.command",
  '[[ "$smoke_mode" == "internal" ]]',
  "tutorial_checkpoint_restored",
  "save_failure_proxy",
  "low_storage_real=not_tested",
  "storage-data-df.txt",
  "storage-diskstats.txt",
  "crash_anr_scan=passed",
  "pii_scan=passed",
  "runtime_bridge_scan=passed",
  "pitch.stage_shader_unavailable",
  "StrictMode",
  "Firebase.*(initialization failed",
  "Default FirebaseApp failed to initialize",
  "Failed to read Firebase options",
  "Amplitude.*(initialization failed",
]) {
  requireCondition(smokeRunner.includes(contract), `Android device smoke contract missing '${contract}'`);
}
requireCondition(
  smokeRunner.includes(".filter((line) => /^(?:android|com)\\.[A-Za-z0-9_.]+$/.test(line))"),
  "Android smoke APK permission parser must preserve app-defined permission identifiers",
);
const smokeReadme = text("tools/android-unity-smoke/README.md");
for (const contract of [
  "`production`이 기본 모드",
  "BuildOptions.Development",
  "BASEBALL_INTERNAL_QA",
  "production_pitch_on_16k=passed",
  "build-manifest.json",
  "BASEBALL_UPLOAD_CERT_SHA256",
  "onboarding→tutorial pitch checkpoint",
  "low_storage_real=not_tested",
  "실기기 통과 증거가 아닙니다",
]) {
  requireCondition(smokeReadme.includes(contract), `Android smoke documentation missing '${contract}'`);
}
requireCondition(
  JSON.parse(text("package.json")).scripts["smoke:android:unity"] ===
    "bash tools/android-unity-smoke/run.sh",
  "package.json must expose the Android Unity device smoke runner",
);

const dependencyContracts = [
  ["apps/android-unity/Assets/Firebase/Editor/AnalyticsDependencies.xml", "com.google.firebase:firebase-analytics:23.2.0"],
  ["apps/android-unity/Assets/Firebase/Editor/AppDependencies.xml", "com.google.firebase:firebase-common:22.1.0"],
  ["apps/android-unity/Assets/Firebase/Editor/CrashlyticsDependencies.xml", "com.google.firebase:firebase-crashlytics-ndk:20.1.0"],
  ["apps/android-unity/Assets/Editor/AmplitudeDependencies.xml", "com.amplitude:android-sdk:2.40.1"],
  ["apps/android-unity/Assets/Editor/AmplitudeDependencies.xml", "com.squareup.okhttp3:okhttp:4.2.2"],
  ["apps/android-unity/Packages/com.google.play.review/Editor/Dependencies.xml", "com.google.android.play:review:2.0.2"],
  ["apps/android-unity/Packages/com.google.play.core/Editor/Dependencies.xml", "com.google.android.play:core-common:2.0.4"],
];
for (const [relativePath, artifact] of dependencyContracts) {
  requireCondition(text(relativePath).includes(artifact), `${relativePath} does not pin ${artifact}`);
}
requireCondition(
  !text("apps/android-unity/Assets/Editor/AmplitudeDependencies.xml").includes("2.40.+"),
  "Amplitude Maven version must not float",
);

for (const licensePath of [
  "apps/android-unity/Assets/Firebase/LICENSE",
  "apps/android-unity/Assets/Amplitude/LICENSE.md",
  "apps/android-unity/Assets/ExternalDependencyManager/Editor/LICENSE",
  "apps/android-unity/Packages/com.google.play.review/LICENSE.md",
  "apps/android-unity/Packages/com.google.play.common/LICENSE.md",
  "apps/android-unity/Packages/com.google.play.core/LICENSE.md",
  "docs/android-unity/THIRD_PARTY_LOCK.md",
]) {
  text(licensePath);
}

for (const forbiddenPath of [
  "apps/android-unity/Assets/google-services.json",
  "apps/android-unity/Assets/Game/Resources/analytics-config.generated.json",
  "apps/android-unity/Assets/Firebase/Plugins/iOS",
  "apps/android-unity/Assets/Firebase/Plugins/x86_64",
  "apps/android-unity/Assets/Plugins/iOS/Firebase",
  "apps/android-unity/Assets/Plugins/tvOS/Firebase",
  "apps/android-unity/Assets/Plugins/Android/res",
]) {
  requireCondition(!existsSync(path.join(repoRoot, forbiddenPath)), `${forbiddenPath} must be injected or omitted`);
}

const assets = walk(path.join(projectRoot, "Assets"));
for (const absolutePath of assets) {
  const relativePath = path.relative(repoRoot, absolutePath).split(path.sep).join("/");
  requireCondition(!/(^|\/)(bin|obj)(\/|$)/.test(relativePath), `generated build directory under Assets: ${relativePath}`);
  requireCondition(!/\.(csproj|sln)$/i.test(relativePath), `generated project file under Assets: ${relativePath}`);
}

const missingMeta = assets
  .filter((absolutePath) => !absolutePath.endsWith(".meta"))
  // Unity imports an .androidlib as one opaque Gradle plug-in. Its root needs a
  // .meta file, while adding Unity sidecars inside its Android resource/source
  // tree is neither required nor desirable.
  .filter((absolutePath) => !path.relative(projectRoot, absolutePath)
    .split(path.sep).join("/").includes(".androidlib/"))
  .filter((absolutePath) => !existsSync(`${absolutePath}.meta`));
const requiredGeneratedUnityArtifacts = [
  path.join(projectRoot, "Assets", "AddressableAssetsData", "AddressableAssetSettings.asset"),
  path.join(projectRoot, "Assets", "Game", "Rendering", "BaseballMobileURP.asset"),
];
const missingGeneratedUnityArtifacts = requiredGeneratedUnityArtifacts
  .filter((absolutePath) => !existsSync(absolutePath));
if (process.env.BASEBALL_REQUIRE_UNITY_META === "1") {
  requireCondition(
    missingMeta.length === 0,
    `${missingMeta.length} Unity Assets files/directories still need .meta import`,
  );
  requireCondition(
    missingGeneratedUnityArtifacts.length === 0,
    `Unity import/build configuration still needs ${missingGeneratedUnityArtifacts.length} generated assets`,
  );
}

console.log(
  `Android Unity source contract passed; NOT production RC evidence. Missing Unity-generated .meta entries: ${missingMeta.length}.`,
);
console.log(
  `Missing reviewed Unity-generated Addressables/URP assets: ${missingGeneratedUnityArtifacts.length}.`,
);
console.log(
  "A signed AAB, verified certificate, 16KB BundleConfig/device execution, merged manifest/dependency evidence, symbol-upload receipt, Play targeted-device export, and physical-device smoke remain separately required.",
);
