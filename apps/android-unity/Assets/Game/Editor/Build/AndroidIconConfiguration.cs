using System;
using System.Collections.Generic;
using System.IO;
using System.Xml;
using UnityEditor;
using UnityEditor.Android;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEngine;

namespace Baseball.Editor
{
    /// <summary>
    /// Keeps launcher icons deterministic across Unity PlayerSettings and the generated Gradle project.
    /// Unity 6000.3 exposes Android adaptive background/foreground layers, but not Android 13's
    /// optional monochrome layer, so the postprocessor adds that standards-defined third layer.
    /// </summary>
    public static class AndroidIconConfiguration
    {
        internal const string AdaptiveBackgroundPath =
            "Assets/Game/Art/PlatformIcons/AndroidAdaptiveBackground.png";
        internal const string AdaptiveForegroundPath =
            "Assets/Game/Art/PlatformIcons/AndroidAdaptiveForeground.png";
        internal const string MonochromeIconPath =
            "Assets/Game/Art/PlatformIcons/AndroidMonochrome.png";

        public static void ConfigurePlayerIcons()
        {
            Texture2D background = LoadSquareTexture(AdaptiveBackgroundPath);
            Texture2D foreground = LoadSquareTexture(AdaptiveForegroundPath);
            LoadSquareTexture(MonochromeIconPath);

            NamedBuildTarget target = NamedBuildTarget.Android;
            PlatformIcon[] adaptiveIcons = PlayerSettings.GetPlatformIcons(
                target,
                AndroidPlatformIconKind.Adaptive);
            if (adaptiveIcons == null || adaptiveIcons.Length == 0)
            {
                throw new BuildFailedException("Unity returned no Android adaptive icon slots.");
            }

            foreach (PlatformIcon icon in adaptiveIcons)
            {
                if (icon.maxLayerCount < 2)
                {
                    throw new BuildFailedException(
                        $"Android adaptive icon slot {icon.width}x{icon.height} does not support two layers.");
                }

                // AndroidPlatformIconKind declares layers in Background, Foreground order.
                icon.SetTextures(new[] { background, foreground });
            }

            PlayerSettings.SetPlatformIcons(target, AndroidPlatformIconKind.Adaptive, adaptiveIcons);
        }

        private static Texture2D LoadSquareTexture(string assetPath)
        {
            Texture2D texture = AssetDatabase.LoadAssetAtPath<Texture2D>(assetPath);
            if (texture == null)
            {
                throw new BuildFailedException($"Required Android icon asset is missing: {assetPath}");
            }

            if (texture.width != texture.height || texture.width < 432)
            {
                throw new BuildFailedException(
                    $"Android icon must be square and at least 432px: {assetPath} " +
                    $"({texture.width}x{texture.height})");
            }

            return texture;
        }
    }

    public sealed class AndroidThemedIconPostprocessor : IPostGenerateGradleAndroidProject
    {
        private const string AndroidNamespace = "http://schemas.android.com/apk/res/android";
        private const string MonochromeResourceName = "baseball_android_monochrome";

        public int callbackOrder => 1000;

        public void OnPostGenerateGradleAndroidProject(string path)
        {
            if (string.IsNullOrWhiteSpace(path) || !Directory.Exists(path))
            {
                throw new BuildFailedException("Generated Android Gradle project path is unavailable.");
            }

            string source = Path.Combine(
                Application.dataPath,
                AndroidIconConfiguration.MonochromeIconPath.Substring("Assets/".Length));
            if (!File.Exists(source))
            {
                throw new BuildFailedException($"Android monochrome icon source is missing: {source}");
            }

            var patchedResources = new HashSet<string>(StringComparer.Ordinal);
            foreach (string xmlPath in Directory.EnumerateFiles(path, "*.xml", SearchOption.AllDirectories))
            {
                if (!IsAdaptiveIconResource(xmlPath))
                {
                    continue;
                }

                XmlDocument document = new XmlDocument { PreserveWhitespace = true };
                document.Load(xmlPath);
                XmlElement root = document.DocumentElement;
                if (root == null || !string.Equals(root.LocalName, "adaptive-icon", StringComparison.Ordinal))
                {
                    continue;
                }

                if (root.SelectSingleNode("*[local-name()='background']") == null
                    || root.SelectSingleNode("*[local-name()='foreground']") == null)
                {
                    continue;
                }

                if (root.SelectSingleNode("*[local-name()='monochrome']") == null)
                {
                    XmlElement monochrome = document.CreateElement("monochrome");
                    monochrome.SetAttribute(
                        "drawable",
                        AndroidNamespace,
                        $"@drawable/{MonochromeResourceName}");
                    root.AppendChild(monochrome);
                    document.Save(xmlPath);
                }

                string densityDirectory = Path.GetDirectoryName(xmlPath)
                                          ?? throw new BuildFailedException(
                                              $"Could not resolve icon resource directory: {xmlPath}");
                string resourceDirectory = Directory.GetParent(densityDirectory)?.FullName
                                           ?? throw new BuildFailedException(
                                               $"Could not resolve Android res directory: {xmlPath}");
                patchedResources.Add(resourceDirectory);
            }

            if (patchedResources.Count == 0)
            {
                throw new BuildFailedException(
                    "No generated adaptive launcher icon XML was found; themed icon support cannot be verified.");
            }

            foreach (string resourceDirectory in patchedResources)
            {
                string drawableDirectory = Path.Combine(resourceDirectory, "drawable-nodpi");
                Directory.CreateDirectory(drawableDirectory);
                File.Copy(
                    source,
                    Path.Combine(drawableDirectory, MonochromeResourceName + ".png"),
                    true);
            }
        }

        private static bool IsAdaptiveIconResource(string path)
        {
            string directory = Path.GetDirectoryName(path) ?? string.Empty;
            string directoryName = Path.GetFileName(directory);
            return directoryName.StartsWith("mipmap-anydpi-v", StringComparison.Ordinal);
        }
    }
}
