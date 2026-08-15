#if UNITY_EDITOR
using System;
using System.IO;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace BaseballPitch.Editor
{
    /** Builds the standalone pitch-only Unity project as a generated Android library. */
    public static class ExportPitchLibrary
    {
        private const string ScenePath = "Assets/Scenes/PitchRuntime.unity";
        private const string ApplicationId = "com.solkim.baseball.android.compose.dev";

        public static void ExportAndroidLibrary()
        {
            var output = Environment.GetEnvironmentVariable("PITCH_UNITY_EXPORT_PATH");
            if (string.IsNullOrWhiteSpace(output))
                throw new BuildFailedException("PITCH_UNITY_EXPORT_PATH is required.");

            output = Path.GetFullPath(output);
            Directory.CreateDirectory(Path.GetDirectoryName(output));
            EnsureScene();
            ConfigurePlayer();
            EditorUserBuildSettings.SwitchActiveBuildTarget(BuildTargetGroup.Android, BuildTarget.Android);
            EditorUserBuildSettings.androidBuildSystem = AndroidBuildSystem.Gradle;
            EditorUserBuildSettings.androidBuildType = AndroidBuildType.Release;
            EditorUserBuildSettings.buildAppBundle = false;
            EditorUserBuildSettings.exportAsGoogleAndroidProject = true;

            var report = BuildPipeline.BuildPlayer(new BuildPlayerOptions
            {
                scenes = new[] { ScenePath },
                locationPathName = output,
                target = BuildTarget.Android,
                targetGroup = BuildTargetGroup.Android,
                options = BuildOptions.AcceptExternalModificationsToPlayer | BuildOptions.StrictMode
            });

            if (report.summary.result != BuildResult.Succeeded)
                throw new BuildFailedException(
                    $"Pitch Unity library export failed: {report.summary.result}; errors={report.summary.totalErrors}");
            if (!Directory.Exists(Path.Combine(output, "unityLibrary")))
                throw new BuildFailedException("Pitch Unity export did not contain unityLibrary.");
        }

        private static void EnsureScene()
        {
            Directory.CreateDirectory(Path.Combine(Application.dataPath, "Scenes"));
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);

            var runtimeRoot = new GameObject("PitchRuntimeRoot");
            runtimeRoot.AddComponent<Baseball.PitchRuntime.PitchRuntimePersistence>();

            var cameraObject = new GameObject("PitchCamera");
            var camera = cameraObject.AddComponent<Camera>();
            camera.clearFlags = CameraClearFlags.SolidColor;
            camera.backgroundColor = new Color(0.035f, 0.055f, 0.075f, 1f);
            camera.fieldOfView = 42f;
            camera.nearClipPlane = 0.05f;
            camera.farClipPlane = 100f;
            camera.transform.position = new Vector3(0f, 1.15f, -20f);
            camera.transform.LookAt(new Vector3(0f, 1f, -1f));
            cameraObject.transform.SetParent(runtimeRoot.transform, false);

            var lightObject = new GameObject("PitchLight");
            var light = lightObject.AddComponent<Light>();
            light.type = LightType.Directional;
            light.intensity = 1.1f;
            light.color = new Color(0.86f, 0.91f, 1f);
            light.transform.rotation = Quaternion.Euler(35f, -25f, 0f);
            lightObject.transform.SetParent(runtimeRoot.transform, false);

            var receiverObject = new GameObject("PitchBridgeReceiver");
            receiverObject.AddComponent<Baseball.PitchRuntime.PitchBridgeReceiver>();
            receiverObject.AddComponent<Baseball.PitchRuntime.PitchTrajectoryRenderer>();
            receiverObject.transform.SetParent(runtimeRoot.transform, false);

            RenderSettings.ambientLight = new Color(0.12f, 0.16f, 0.22f);
            RenderSettings.fog = false;
            Application.targetFrameRate = 60;
            QualitySettings.vSyncCount = 0;
            EditorSceneManager.SaveScene(scene, ScenePath);
        }

        private static void ConfigurePlayer()
        {
            PlayerSettings.companyName = "BaseballRuntime";
            PlayerSettings.productName = "PitchVisualRuntime";
            PlayerSettings.SetApplicationIdentifier(NamedBuildTarget.Android, ApplicationId);
            PlayerSettings.defaultInterfaceOrientation = UIOrientation.Portrait;
            PlayerSettings.allowedAutorotateToPortrait = false;
            PlayerSettings.allowedAutorotateToPortraitUpsideDown = false;
            PlayerSettings.allowedAutorotateToLandscapeLeft = false;
            PlayerSettings.allowedAutorotateToLandscapeRight = false;
            PlayerSettings.colorSpace = ColorSpace.Linear;
            PlayerSettings.SetGraphicsAPIs(BuildTarget.Android, new[] { UnityEngine.Rendering.GraphicsDeviceType.OpenGLES3 });
            PlayerSettings.SetScriptingBackend(NamedBuildTarget.Android, ScriptingImplementation.IL2CPP);
            PlayerSettings.SetIl2CppCompilerConfiguration(
                NamedBuildTarget.Android,
                Il2CppCompilerConfiguration.Release);
            PlayerSettings.SetApiCompatibilityLevel(
                NamedBuildTarget.Android,
                ApiCompatibilityLevel.NET_Standard_2_0);
            PlayerSettings.SetManagedStrippingLevel(
                NamedBuildTarget.Android,
                ManagedStrippingLevel.Medium);

            PlayerSettings.Android.minSdkVersion = AndroidSdkVersions.AndroidApiLevel26;
            PlayerSettings.Android.targetSdkVersion = AndroidSdkVersions.AndroidApiLevel36;
            PlayerSettings.Android.targetArchitectures = AndroidArchitecture.ARM64;
            PlayerSettings.Android.forceInternetPermission = false;
            PlayerSettings.Android.forceSDCardPermission = false;
            PlayerSettings.Android.resizeableActivity = false;
        }
    }
}
#endif
