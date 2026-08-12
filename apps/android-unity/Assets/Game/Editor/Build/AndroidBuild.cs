using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.SceneManagement;

namespace Baseball.Editor
{
    public static class AndroidBuild
    {
        private const string ApplicationId = "com.solkim.baseball.android";
        private const string BootScenePath = "Assets/Game/Bootstrap/00_Bootstrap.unity";
        private const string InternalQaDefine = "BASEBALL_INTERNAL_QA";
        private const string PitchStageShaderPath =
            "Assets/Game/Presentation/Pitch/Resources/PitchStageUnlit.shader";
        private const string PitchStageShaderName = "Baseball/PitchStageUnlit";
        private const string DefaultVersion = "1.0.0";
        private const int DefaultVersionCode = 1;

        internal static bool IsLocalVerificationPostprocessActive { get; private set; }

        [MenuItem("Baseball/Build/Android/Release Candidate")]
        public static void BuildReleaseCandidate()
        {
            Build(BuildKind.ReleaseCandidate);
        }

        [MenuItem("Baseball/Build/Android/Local Verification")]
        public static void BuildLocalVerification()
        {
            Build(BuildKind.LocalVerification);
        }

        [MenuItem("Baseball/Build/Create Boot Scene")]
        public static void CreateBootScene()
        {
            EnsureBootScene();
            UnityEngine.Debug.Log($"Boot scene is ready: {BootScenePath}");
        }

        private static void Build(BuildKind kind)
        {
            string projectRoot = Directory.GetParent(Application.dataPath)?.FullName
                                 ?? throw new BuildFailedException("Unity project root could not be resolved.");
            string repositoryRoot = FindRepositoryRoot(projectRoot);

            EnsureBootScene();
            LocalAddressablesConfiguration.EnsureConfigured();
            string version = ReadVersion();
            int versionCode = ReadVersionCode();
            ConfigurePlayer();
            EnsurePitchStageShaderAlwaysIncluded();
            ValidatePitchStageShaderResource();
            AssetDatabase.SaveAssets();

            GitState git = ReadGitState(repositoryRoot);
            if (kind == BuildKind.ReleaseCandidate && git.IsDirty)
            {
                throw new BuildFailedException(
                    "Release candidate builds require a clean worktree. Commit or intentionally stash the current changes first.");
            }

            ValidateServiceConfiguration(projectRoot, kind);

            bool customSigningConfigured = false;
            string addressablesContentStatePath = Path.Combine(
                projectRoot,
                "Assets",
                "AddressableAssetsData",
                "Android",
                "addressables_content_state.bin");
            byte[] originalAddressablesContentState = File.Exists(addressablesContentStatePath)
                ? File.ReadAllBytes(addressablesContentStatePath)
                : null;
            string originalVersion = PlayerSettings.bundleVersion;
            int originalVersionCode = PlayerSettings.Android.bundleVersionCode;
            bool buildVersionApplied = false;
            string successMessage = null;
            try
            {
                ApplyBuildVersion(version, versionCode);
                buildVersionApplied = true;
                AssetDatabase.SaveAssets();

                if (kind == BuildKind.ReleaseCandidate)
                {
                    customSigningConfigured = true;
                    ConfigureReleaseSigning(repositoryRoot);
                }
                else
                {
                    PlayerSettings.Android.useCustomKeystore = false;
                }

                string distribution = kind == BuildKind.ReleaseCandidate ? "production" : "internal-verification";
                string artifactDirectory = Path.Combine(
                    repositoryRoot,
                    "artifacts",
                    "android",
                    $"{version}-{versionCode.ToString(CultureInfo.InvariantCulture)}");
                if (Directory.Exists(artifactDirectory) &&
                    Directory.EnumerateFileSystemEntries(artifactDirectory).Any())
                {
                    throw new BuildFailedException(
                        $"Android artifact directory must be empty before a build: {artifactDirectory}");
                }
                Directory.CreateDirectory(artifactDirectory);

                string suffix = kind == BuildKind.ReleaseCandidate ? string.Empty : "-debug-signed-verification";
                string bundlePath = Path.Combine(
                    artifactDirectory,
                    $"baseball-android-{version}-{versionCode.ToString(CultureInfo.InvariantCulture)}{suffix}.aab");

                EditorUserBuildSettings.SwitchActiveBuildTarget(BuildTargetGroup.Android, BuildTarget.Android);
                EditorUserBuildSettings.buildAppBundle = true;
#pragma warning disable 618
                EditorUserBuildSettings.androidCreateSymbols = AndroidCreateSymbols.Public;
#pragma warning restore 618

                BuildOptions playerBuildOptions = BuildOptions.CleanBuildCache;
                string[] extraScriptingDefines = Array.Empty<string>();
                if (kind == BuildKind.LocalVerification)
                {
                    playerBuildOptions |= BuildOptions.Development;
                    extraScriptingDefines = new[] { InternalQaDefine };
                }

                ValidateNoPersistentQaDefines();
                ValidateQaBuildBoundary(kind, playerBuildOptions, extraScriptingDefines);
                ValidateIl2CppCompilerConfiguration();
                var options = new BuildPlayerOptions
                {
                    scenes = new[] { BootScenePath },
                    locationPathName = bundlePath,
                    target = BuildTarget.Android,
                    targetGroup = BuildTargetGroup.Android,
                    options = playerBuildOptions,
                    extraScriptingDefines = extraScriptingDefines
                };

                IsLocalVerificationPostprocessActive = kind == BuildKind.LocalVerification;
                BuildReport report = BuildPipeline.BuildPlayer(options);
                if (report.summary.result != BuildResult.Succeeded || !File.Exists(bundlePath) ||
                    new FileInfo(bundlePath).Length == 0 || !HasZipSignature(bundlePath))
                {
                    throw new BuildFailedException(
                        $"Android build failed: {report.summary.result}; errors={report.summary.totalErrors}");
                }

                string bundleSha256 = ComputeSha256(bundlePath);
                string symbolArchive = FindSymbolArchive(artifactDirectory);
                if (kind == BuildKind.ReleaseCandidate &&
                    (string.IsNullOrEmpty(symbolArchive) || new FileInfo(symbolArchive).Length == 0 ||
                     !HasZipSignature(symbolArchive)))
                {
                    throw new BuildFailedException(
                        "Release candidate build completed without an IL2CPP public symbol archive.");
                }
                string symbolSha256 = string.IsNullOrEmpty(symbolArchive)
                    ? string.Empty
                    : ComputeSha256(symbolArchive);
                WriteBuildManifest(
                    projectRoot,
                    artifactDirectory,
                    bundlePath,
                    bundleSha256,
                    symbolArchive,
                    symbolSha256,
                    version,
                    versionCode,
                    distribution,
                    (playerBuildOptions & BuildOptions.Development) != 0,
                    extraScriptingDefines.Contains(InternalQaDefine, StringComparer.Ordinal),
                    git,
                    report);
                WriteChecksums(
                    artifactDirectory,
                    bundlePath,
                    bundleSha256,
                    symbolArchive,
                    symbolSha256);

                successMessage =
                    $"Android {distribution} build succeeded: {bundlePath} ({report.summary.totalSize} bytes)";
            }
            finally
            {
                IsLocalVerificationPostprocessActive = false;
                if (customSigningConfigured)
                {
                    ClearSigningSecrets();
                }
                if (buildVersionApplied)
                {
                    ApplyBuildVersion(originalVersion, originalVersionCode);
                    AssetDatabase.SaveAssets();
                }
                RestoreGeneratedFile(addressablesContentStatePath, originalAddressablesContentState);
            }

            if (kind == BuildKind.ReleaseCandidate && ReadGitState(repositoryRoot).IsDirty)
            {
                throw new BuildFailedException(
                    "Release candidate build changed tracked or untracked source after restoring its build-time version.");
            }
            UnityEngine.Debug.Log(successMessage);
        }

        private static void RestoreGeneratedFile(string path, byte[] originalBytes)
        {
            if (originalBytes == null)
            {
                if (File.Exists(path))
                {
                    File.Delete(path);
                }
                return;
            }

            if (!File.Exists(path) || !File.ReadAllBytes(path).SequenceEqual(originalBytes))
            {
                File.WriteAllBytes(path, originalBytes);
            }
        }

        private static void ValidateNoPersistentQaDefines()
        {
            string symbols = PlayerSettings.GetScriptingDefineSymbols(NamedBuildTarget.Android);
            string[] values = (symbols ?? string.Empty)
                .Split(new[] { ';' }, StringSplitOptions.RemoveEmptyEntries);
            if (values.Any(value =>
                    string.Equals(value.Trim(), InternalQaDefine, StringComparison.Ordinal) ||
                    string.Equals(value.Trim(), "BASEBALL_INTERNAL_QA_STATIC", StringComparison.Ordinal)))
            {
                throw new BuildFailedException(
                    "Internal QA symbols must be supplied only by the LocalVerification BuildPlayerOptions boundary.");
            }
        }

        private static void ValidateQaBuildBoundary(
            BuildKind kind,
            BuildOptions buildOptions,
            IReadOnlyCollection<string> extraScriptingDefines)
        {
            bool developmentBuild = (buildOptions & BuildOptions.Development) != 0;
            bool internalQaCompiled = extraScriptingDefines != null &&
                extraScriptingDefines.Contains(InternalQaDefine, StringComparer.Ordinal);
            if (kind == BuildKind.ReleaseCandidate && (developmentBuild || internalQaCompiled))
            {
                throw new BuildFailedException(
                    "Release candidate builds must exclude BuildOptions.Development and BASEBALL_INTERNAL_QA.");
            }
            if (kind == BuildKind.LocalVerification && (!developmentBuild || !internalQaCompiled))
            {
                throw new BuildFailedException(
                    "Local verification builds require both BuildOptions.Development and BASEBALL_INTERNAL_QA.");
            }
        }

        private static void ConfigurePlayer()
        {
            PlayerSettings.companyName = "SolKim";
            PlayerSettings.productName = "야구 못하면 또 환생함";
            PlayerSettings.SetApplicationIdentifier(NamedBuildTarget.Android, ApplicationId);
            PlayerSettings.defaultInterfaceOrientation = UIOrientation.Portrait;
            PlayerSettings.allowedAutorotateToPortrait = false;
            PlayerSettings.allowedAutorotateToPortraitUpsideDown = false;
            PlayerSettings.allowedAutorotateToLandscapeLeft = false;
            PlayerSettings.allowedAutorotateToLandscapeRight = false;
            PlayerSettings.colorSpace = ColorSpace.Linear;
            PlayerSettings.SetGraphicsAPIs(BuildTarget.Android, new[] { GraphicsDeviceType.OpenGLES3 });
            PlayerSettings.SetScriptingBackend(NamedBuildTarget.Android, ScriptingImplementation.IL2CPP);
            PlayerSettings.SetIl2CppCompilerConfiguration(
                NamedBuildTarget.Android,
                Il2CppCompilerConfiguration.Release);
            PlayerSettings.SetApiCompatibilityLevel(NamedBuildTarget.Android, ApiCompatibilityLevel.NET_Standard_2_0);
            PlayerSettings.SetManagedStrippingLevel(NamedBuildTarget.Android, ManagedStrippingLevel.Medium);

            PlayerSettings.Android.minSdkVersion = AndroidSdkVersions.AndroidApiLevel26;
            PlayerSettings.Android.targetSdkVersion = AndroidSdkVersions.AndroidApiLevel36;
            PlayerSettings.Android.targetArchitectures = AndroidArchitecture.ARM64;
            PlayerSettings.Android.forceInternetPermission = true;
            PlayerSettings.Android.forceSDCardPermission = false;
            PlayerSettings.Android.appCategory = "game";
            PlayerSettings.Android.androidTVCompatibility = false;
            PlayerSettings.Android.resizeableActivity = false;

            MobileRenderPipelineConfiguration.EnsureConfigured();
            AndroidIconConfiguration.ConfigurePlayerIcons();

            EditorUserBuildSettings.androidBuildSystem = AndroidBuildSystem.Gradle;
            EditorUserBuildSettings.androidBuildType = AndroidBuildType.Release;
            EditorUserBuildSettings.exportAsGoogleAndroidProject = false;
        }

        private static void EnsurePitchStageShaderAlwaysIncluded()
        {
            Shader shader = AssetDatabase.LoadAssetAtPath<Shader>(PitchStageShaderPath);
            if (shader == null ||
                !string.Equals(shader.name, PitchStageShaderName, StringComparison.Ordinal))
            {
                throw new BuildFailedException(
                    "The checked-in Resources pitch-stage shader is missing or invalid; " +
                    "the player build would be vulnerable to shader stripping.");
            }

            SerializedObject graphics = LoadGraphicsSettings();
            SerializedProperty included = graphics.FindProperty("m_AlwaysIncludedShaders");
            if (included == null || !included.isArray)
                throw new BuildFailedException("GraphicsSettings Always Included Shaders could not be read.");
            for (int index = 0; index < included.arraySize; index++)
                if (ReferenceEquals(included.GetArrayElementAtIndex(index).objectReferenceValue, shader))
                    return;
            included.InsertArrayElementAtIndex(included.arraySize);
            included.GetArrayElementAtIndex(included.arraySize - 1).objectReferenceValue = shader;
            graphics.ApplyModifiedPropertiesWithoutUndo();
        }

        private static void ValidatePitchStageShaderResource()
        {
            Shader shader = AssetDatabase.LoadAssetAtPath<Shader>(PitchStageShaderPath);
            SerializedProperty included = LoadGraphicsSettings().FindProperty("m_AlwaysIncludedShaders");
            bool preserved = included != null && included.isArray &&
                Enumerable.Range(0, included.arraySize).Any(index => ReferenceEquals(
                    included.GetArrayElementAtIndex(index).objectReferenceValue,
                    shader));
            if (shader == null ||
                !string.Equals(shader.name, PitchStageShaderName, StringComparison.Ordinal) ||
                !preserved)
            {
                throw new BuildFailedException(
                    "The checked-in pitch-stage shader is not present in GraphicsSettings.alwaysIncludedShaders; " +
                    "the player build would be vulnerable to shader variant stripping.");
            }
        }

        private static SerializedObject LoadGraphicsSettings()
        {
            UnityEngine.Object settings = AssetDatabase.LoadAllAssetsAtPath(
                    "ProjectSettings/GraphicsSettings.asset")
                .FirstOrDefault();
            if (settings == null)
                throw new BuildFailedException("ProjectSettings/GraphicsSettings.asset could not be loaded.");
            return new SerializedObject(settings);
        }

        private static void ApplyBuildVersion(string version, int versionCode)
        {
            PlayerSettings.bundleVersion = version;
            PlayerSettings.Android.bundleVersionCode = versionCode;
        }

        private static void ValidateIl2CppCompilerConfiguration()
        {
            Il2CppCompilerConfiguration configuration =
                PlayerSettings.GetIl2CppCompilerConfiguration(NamedBuildTarget.Android);
            if (configuration != Il2CppCompilerConfiguration.Release)
            {
                throw new BuildFailedException(
                    $"Android IL2CPP compiler configuration must be Release, not {configuration}.");
            }
        }

        private static void ConfigureReleaseSigning(string repositoryRoot)
        {
            string keystorePath = RequireEnvironment("BASEBALL_UPLOAD_KEYSTORE_PATH");
            string keystorePassword = RequireEnvironment("BASEBALL_UPLOAD_KEYSTORE_PASSWORD");
            string keyAlias = RequireEnvironment("BASEBALL_UPLOAD_KEY_ALIAS");
            string keyAliasPassword = RequireEnvironment("BASEBALL_UPLOAD_KEY_PASSWORD");

            if (!Path.IsPathRooted(keystorePath) || !File.Exists(keystorePath))
            {
                throw new BuildFailedException(
                    "BASEBALL_UPLOAD_KEYSTORE_PATH must be an existing absolute path outside the repository.");
            }
            string fullKeystorePath = Path.GetFullPath(keystorePath);
            string repositoryPrefix = Path.GetFullPath(repositoryRoot)
                .TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar)
                + Path.DirectorySeparatorChar;
            if (fullKeystorePath.StartsWith(repositoryPrefix, StringComparison.Ordinal))
            {
                throw new BuildFailedException(
                    "BASEBALL_UPLOAD_KEYSTORE_PATH must be outside the repository workspace.");
            }

            PlayerSettings.Android.useCustomKeystore = true;
            PlayerSettings.Android.keystoreName = fullKeystorePath;
            PlayerSettings.Android.keystorePass = keystorePassword;
            PlayerSettings.Android.keyaliasName = keyAlias;
            PlayerSettings.Android.keyaliasPass = keyAliasPassword;
        }

        private static void ValidateServiceConfiguration(string projectRoot, BuildKind kind)
        {
            string analyticsPath = Path.Combine(
                projectRoot,
                "Assets",
                "Game",
                "Resources",
                "analytics-config.generated.json");
            string googleServicesPath = Path.Combine(projectRoot, "Assets", "google-services.json");

            if (kind != BuildKind.ReleaseCandidate)
            {
                if (!File.Exists(analyticsPath)) return;
                AnalyticsBuildConfiguration local = JsonUtility.FromJson<AnalyticsBuildConfiguration>(
                    File.ReadAllText(analyticsPath));
                if (local != null
                    && string.Equals(local.distribution, "production", StringComparison.OrdinalIgnoreCase))
                {
                    throw new BuildFailedException(
                        "Local verification cannot use a production analytics configuration.");
                }
                return;
            }

            if (!File.Exists(analyticsPath) || !File.Exists(googleServicesPath))
            {
                throw new BuildFailedException(
                    "Production RC requires injected analytics-config.generated.json and google-services.json.");
            }

            AnalyticsBuildConfiguration analytics = JsonUtility.FromJson<AnalyticsBuildConfiguration>(
                File.ReadAllText(analyticsPath));
            if (analytics == null
                || !string.Equals(analytics.distribution, "production", StringComparison.Ordinal)
                || !analytics.firebaseEnabled
                || !analytics.crashlyticsEnabled
                || !analytics.amplitudeEnabled
                || string.IsNullOrWhiteSpace(analytics.amplitudeApiKey)
                || analytics.amplitudeApiKey.Trim().Length < 16)
            {
                throw new BuildFailedException(
                    "Production analytics configuration is incomplete or not marked production.");
            }

            GoogleServicesConfiguration google = JsonUtility.FromJson<GoogleServicesConfiguration>(
                File.ReadAllText(googleServicesPath));
            bool packageMatched = google?.client != null
                                  && google.client.Any(client => string.Equals(
                                      client?.client_info?.android_client_info?.package_name,
                                      ApplicationId,
                                      StringComparison.Ordinal));
            if (!packageMatched)
            {
                throw new BuildFailedException(
                    $"google-services.json does not contain the Android package {ApplicationId}.");
            }
        }

        private static void ClearSigningSecrets()
        {
            PlayerSettings.Android.keystorePass = string.Empty;
            PlayerSettings.Android.keyaliasPass = string.Empty;
            PlayerSettings.Android.keyaliasName = string.Empty;
            PlayerSettings.Android.keystoreName = string.Empty;
            PlayerSettings.Android.useCustomKeystore = false;
            AssetDatabase.SaveAssets();
        }

        private static void EnsureBootScene()
        {
            if (AssetDatabase.LoadAssetAtPath<SceneAsset>(BootScenePath) != null)
            {
                return;
            }

            Directory.CreateDirectory(Path.Combine(Application.dataPath, "Game", "Scenes"));
            Scene scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            scene.name = "00_Boot";
            if (!EditorSceneManager.SaveScene(scene, BootScenePath))
            {
                throw new BuildFailedException($"Could not create boot scene at {BootScenePath}.");
            }

            EditorBuildSettings.scenes = new[] { new EditorBuildSettingsScene(BootScenePath, true) };
            AssetDatabase.ImportAsset(BootScenePath, ImportAssetOptions.ForceSynchronousImport);
        }

        private static string ReadVersion()
        {
            string value = Environment.GetEnvironmentVariable("BASEBALL_VERSION_NAME");
            string version = string.IsNullOrWhiteSpace(value) ? DefaultVersion : value.Trim();
            if (version.Length > 32 || !System.Text.RegularExpressions.Regex.IsMatch(
                    version,
                    @"^[0-9]+(?:\.[0-9]+){2}$",
                    System.Text.RegularExpressions.RegexOptions.CultureInvariant))
            {
                throw new BuildFailedException(
                    "BASEBALL_VERSION_NAME must be a three-part numeric version such as 1.0.0.");
            }
            return version;
        }

        private static int ReadVersionCode()
        {
            string value = Environment.GetEnvironmentVariable("BASEBALL_VERSION_CODE");
            if (string.IsNullOrWhiteSpace(value))
            {
                return DefaultVersionCode;
            }

            if (!int.TryParse(value, NumberStyles.None, CultureInfo.InvariantCulture, out int code) || code <= 0)
            {
                throw new BuildFailedException("BASEBALL_VERSION_CODE must be a positive integer.");
            }

            return code;
        }

        private static string RequireEnvironment(string name)
        {
            string value = Environment.GetEnvironmentVariable(name);
            if (string.IsNullOrWhiteSpace(value))
            {
                throw new BuildFailedException($"Required release signing environment variable is missing: {name}");
            }

            return value;
        }

        private static string FindRepositoryRoot(string startPath)
        {
            var directory = new DirectoryInfo(startPath);
            while (directory != null)
            {
                if (Directory.Exists(Path.Combine(directory.FullName, ".git"))
                    || File.Exists(Path.Combine(directory.FullName, ".git")))
                {
                    return directory.FullName;
                }

                directory = directory.Parent;
            }

            throw new BuildFailedException("Git repository root could not be resolved.");
        }

        private static GitState ReadGitState(string repositoryRoot)
        {
            string commit = RunProcess(repositoryRoot, "git", "rev-parse HEAD").Trim();
            string status = RunProcess(repositoryRoot, "git", "status --porcelain --untracked-files=normal");
            return new GitState(commit, !string.IsNullOrWhiteSpace(status));
        }

        private static string RunProcess(string workingDirectory, string fileName, string arguments)
        {
            var startInfo = new ProcessStartInfo
            {
                FileName = fileName,
                Arguments = arguments,
                WorkingDirectory = workingDirectory,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };

            using var process = Process.Start(startInfo)
                                ?? throw new BuildFailedException($"Could not start {fileName}.");
            string stdout = process.StandardOutput.ReadToEnd();
            string stderr = process.StandardError.ReadToEnd();
            process.WaitForExit();
            if (process.ExitCode != 0)
            {
                throw new BuildFailedException(
                    $"{fileName} {arguments} failed with exit code {process.ExitCode}: {stderr.Trim()}");
            }

            return stdout;
        }

        private static string ComputeSha256(string path)
        {
            using var stream = File.OpenRead(path);
            using var hash = SHA256.Create();
            return string.Concat(hash.ComputeHash(stream).Select(value => value.ToString("x2", CultureInfo.InvariantCulture)));
        }

        private static string FindSymbolArchive(string artifactDirectory)
        {
            string[] matches = Directory.EnumerateFiles(artifactDirectory, "*.zip", SearchOption.TopDirectoryOnly)
                .Where(path => Path.GetFileName(path).IndexOf("symbol", StringComparison.OrdinalIgnoreCase) >= 0)
                .OrderBy(path => path, StringComparer.Ordinal)
                .ToArray();
            if (matches.Length > 1)
            {
                throw new BuildFailedException(
                    "Android build produced multiple symbol archives; artifact identity is ambiguous.");
            }
            return matches.FirstOrDefault();
        }

        private static bool HasZipSignature(string path)
        {
            using var stream = File.OpenRead(path);
            if (stream.Length < 4) return false;
            return stream.ReadByte() == 0x50 && stream.ReadByte() == 0x4B &&
                   stream.ReadByte() == 0x03 && stream.ReadByte() == 0x04;
        }

        private static void WriteBuildManifest(
            string projectRoot,
            string artifactDirectory,
            string bundlePath,
            string bundleSha256,
            string symbolArchive,
            string symbolSha256,
            string version,
            int versionCode,
            string distribution,
            bool developmentBuild,
            bool internalQaCompiled,
            GitState git,
            BuildReport report)
        {
            string packageLock = Path.Combine(projectRoot, "Packages", "packages-lock.json");
            string packageLockSha256 = File.Exists(packageLock) ? ComputeSha256(packageLock) : string.Empty;
            string json = "{\n"
                          + $"  \"schema\": \"baseball-android-build-manifest-v1\",\n"
                          + $"  \"gitCommit\": \"{EscapeJson(git.Commit)}\",\n"
                          + $"  \"gitDirty\": {(git.IsDirty ? "true" : "false")},\n"
                          + $"  \"unityVersion\": \"{EscapeJson(Application.unityVersion)}\",\n"
                          + $"  \"packageLockSha256\": \"{packageLockSha256}\",\n"
                          + $"  \"applicationId\": \"{ApplicationId}\",\n"
                          + $"  \"versionName\": \"{EscapeJson(version)}\",\n"
                          + $"  \"versionCode\": {versionCode.ToString(CultureInfo.InvariantCulture)},\n"
                          + "  \"minimumApi\": 26,\n"
                          + "  \"targetApi\": 36,\n"
                          + "  \"architecture\": \"ARM64\",\n"
                          + "  \"graphicsApi\": \"OpenGLES3\",\n"
                          + $"  \"il2cppCompilerConfiguration\": \"{PlayerSettings.GetIl2CppCompilerConfiguration(NamedBuildTarget.Android)}\",\n"
                          + $"  \"distribution\": \"{distribution}\",\n"
                          + $"  \"environment\": \"{distribution}\",\n"
                          + $"  \"developmentBuild\": {(developmentBuild ? "true" : "false")},\n"
                          + $"  \"internalQaCompiled\": {(internalQaCompiled ? "true" : "false")},\n"
                          + "  \"saveSchema\": 1,\n"
                          + "  \"eventSchema\": 2,\n"
                          + $"  \"buildUtc\": \"{DateTime.UtcNow:O}\",\n"
                          + $"  \"bundleFile\": \"{EscapeJson(Path.GetFileName(bundlePath))}\",\n"
                          + $"  \"bundleSha256\": \"{bundleSha256}\",\n"
                          + $"  \"bundleBytes\": {new FileInfo(bundlePath).Length.ToString(CultureInfo.InvariantCulture)},\n"
                          + $"  \"symbolFile\": \"{EscapeJson(string.IsNullOrEmpty(symbolArchive) ? string.Empty : Path.GetFileName(symbolArchive))}\",\n"
                          + $"  \"symbolSha256\": \"{symbolSha256}\"\n"
                          + "}\n";
            File.WriteAllText(Path.Combine(artifactDirectory, "build-manifest.json"), json, new UTF8Encoding(false));
        }

        private static void WriteChecksums(
            string artifactDirectory,
            string bundlePath,
            string bundleSha256,
            string symbolArchive,
            string symbolSha256)
        {
            string contents = $"{bundleSha256}  {Path.GetFileName(bundlePath)}\n";
            if (!string.IsNullOrEmpty(symbolArchive))
            {
                contents += $"{symbolSha256}  {Path.GetFileName(symbolArchive)}\n";
            }
            File.WriteAllText(
                Path.Combine(artifactDirectory, "checksums.sha256"),
                contents,
                new UTF8Encoding(false));
        }

        private static string EscapeJson(string value)
        {
            if (string.IsNullOrEmpty(value))
            {
                return string.Empty;
            }

            var builder = new StringBuilder(value.Length + 8);
            foreach (char character in value)
            {
                switch (character)
                {
                    case '\\': builder.Append("\\\\"); break;
                    case '"': builder.Append("\\\""); break;
                    case '\n': builder.Append("\\n"); break;
                    case '\r': builder.Append("\\r"); break;
                    case '\t': builder.Append("\\t"); break;
                    default: builder.Append(character); break;
                }
            }

            return builder.ToString();
        }

        private enum BuildKind
        {
            ReleaseCandidate,
            LocalVerification
        }

#pragma warning disable 0649 // JsonUtility populates injected build-only configuration DTOs.
        [Serializable]
        private sealed class AnalyticsBuildConfiguration
        {
            public string distribution;
            public bool firebaseEnabled;
            public bool crashlyticsEnabled;
            public bool amplitudeEnabled;
            public string amplitudeApiKey;
        }

        [Serializable]
        private sealed class GoogleServicesConfiguration
        {
            public GoogleServicesClient[] client;
        }

        [Serializable]
        private sealed class GoogleServicesClient
        {
            public GoogleServicesClientInfo client_info;
        }

        [Serializable]
        private sealed class GoogleServicesClientInfo
        {
            public GoogleServicesAndroidClientInfo android_client_info;
        }

        [Serializable]
        private sealed class GoogleServicesAndroidClientInfo
        {
            public string package_name;
        }
#pragma warning restore 0649

        private readonly struct GitState
        {
            public GitState(string commit, bool isDirty)
            {
                Commit = commit;
                IsDirty = isDirty;
            }

            public string Commit { get; }
            public bool IsDirty { get; }
        }
    }
}
