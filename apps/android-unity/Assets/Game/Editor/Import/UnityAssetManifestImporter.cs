using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEngine;

namespace Baseball.Editor.Import
{
    public sealed class UnityAssetManifestImporter : AssetPostprocessor
    {
        private const string ManifestAssetPath = "Assets/Game/Content/Manifests/asset-manifest.json";
        private static Dictionary<string, ManifestEntry> _entries;
        private static DateTime _manifestWriteTimeUtc;

        private void OnPreprocessTexture()
        {
            if (!(assetImporter is TextureImporter importer)) return;
            if (!TryGetEntry(assetPath, out ManifestEntry entry)) return;
            ApplyTexturePreset(importer, entry);
        }

        private void OnPreprocessAudio()
        {
            if (!(assetImporter is AudioImporter importer)) return;
            if (!TryGetEntry(assetPath, out ManifestEntry entry)) return;
            ApplyAudioPreset(importer, entry);
        }

        private static void OnPostprocessAllAssets(
            string[] importedAssets,
            string[] deletedAssets,
            string[] movedAssets,
            string[] movedFromAssetPaths)
        {
            if (importedAssets.Contains(ManifestAssetPath)
                || deletedAssets.Contains(ManifestAssetPath)
                || movedAssets.Contains(ManifestAssetPath)
                || movedFromAssetPaths.Contains(ManifestAssetPath))
            {
                _entries = null;
            }
        }

        [MenuItem("Baseball/Assets/Reimport Managed Assets")]
        public static void ReimportManagedAssets()
        {
            EnsureManifestLoaded();
            foreach (string managedAssetPath in _entries.Keys.OrderBy(value => value, StringComparer.Ordinal))
            {
                AssetDatabase.ImportAsset(managedAssetPath, ImportAssetOptions.ForceUpdate);
            }
            Debug.Log($"Reimported {_entries.Count} assets from {ManifestAssetPath}.");
        }

        private static void ApplyTexturePreset(TextureImporter importer, ManifestEntry entry)
        {
            bool platformIcon = entry.importPreset == "platform-icon";
            bool billboard = entry.importPreset == "billboard-sprite";
            bool alpha = string.Equals(Path.GetExtension(entry.targetPath), ".png", StringComparison.OrdinalIgnoreCase);
            int maximumSize = platformIcon || entry.importPreset == "key-art-sprite" || billboard ? 2048 : 1024;

            importer.textureType = platformIcon ? TextureImporterType.Default : TextureImporterType.Sprite;
            importer.spriteImportMode = SpriteImportMode.Single;
            importer.spritePixelsPerUnit = 100f;
            importer.mipmapEnabled = billboard;
            importer.alphaIsTransparency = alpha;
            importer.sRGBTexture = true;
            importer.npotScale = TextureImporterNPOTScale.None;
            importer.wrapMode = TextureWrapMode.Clamp;
            importer.filterMode = FilterMode.Bilinear;
            importer.textureCompression = platformIcon ? TextureImporterCompression.Uncompressed : TextureImporterCompression.Compressed;
            importer.maxTextureSize = maximumSize;

            var android = importer.GetPlatformTextureSettings("Android");
            android.name = "Android";
            android.overridden = true;
            android.maxTextureSize = maximumSize;
            android.resizeAlgorithm = TextureResizeAlgorithm.Mitchell;
            android.format = platformIcon
                ? TextureImporterFormat.RGBA32
                : alpha ? TextureImporterFormat.ETC2_RGBA8 : TextureImporterFormat.ETC2_RGB4;
            android.compressionQuality = 75;
            importer.SetPlatformTextureSettings(android);
        }

        private static void ApplyAudioPreset(AudioImporter importer, ManifestEntry entry)
        {
            bool streamingLoop = entry.importPreset == "audio-stream-loop";
            importer.forceToMono = !streamingLoop;
            importer.ambisonic = false;
            importer.loadInBackground = streamingLoop;

            AudioImporterSampleSettings settings = importer.defaultSampleSettings;
            settings.loadType = streamingLoop ? AudioClipLoadType.Streaming : AudioClipLoadType.DecompressOnLoad;
            settings.compressionFormat = streamingLoop ? AudioCompressionFormat.Vorbis : AudioCompressionFormat.ADPCM;
            settings.preloadAudioData = !streamingLoop;
            settings.quality = streamingLoop ? 0.7f : 1f;
            settings.sampleRateSetting = AudioSampleRateSetting.PreserveSampleRate;
            importer.defaultSampleSettings = settings;
        }

        private static bool TryGetEntry(string unityAssetPath, out ManifestEntry entry)
        {
            EnsureManifestLoaded();
            return _entries.TryGetValue(unityAssetPath, out entry);
        }

        private static void EnsureManifestLoaded()
        {
            string absoluteManifestPath = Path.Combine(Directory.GetParent(Application.dataPath).FullName, ManifestAssetPath);
            if (!File.Exists(absoluteManifestPath))
            {
                _entries = new Dictionary<string, ManifestEntry>(StringComparer.OrdinalIgnoreCase);
                return;
            }

            DateTime writeTimeUtc = File.GetLastWriteTimeUtc(absoluteManifestPath);
            if (_entries != null && writeTimeUtc == _manifestWriteTimeUtc) return;

            AssetManifest manifest = JsonUtility.FromJson<AssetManifest>(File.ReadAllText(absoluteManifestPath));
            if (manifest == null || manifest.schema != "baseball-unity-asset-manifest-v1" || manifest.entries == null)
            {
                throw new InvalidDataException($"Unsupported or incomplete asset manifest: {ManifestAssetPath}");
            }

            _entries = manifest.entries.ToDictionary(
                entry => ToUnityAssetPath(entry.targetPath),
                entry => entry,
                StringComparer.OrdinalIgnoreCase);
            _manifestWriteTimeUtc = writeTimeUtc;
        }

        private static string ToUnityAssetPath(string repositoryRelativePath)
        {
            const string marker = "apps/android-unity/";
            if (string.IsNullOrEmpty(repositoryRelativePath) || !repositoryRelativePath.StartsWith(marker, StringComparison.Ordinal))
            {
                throw new InvalidDataException($"Managed target is outside the Unity project: {repositoryRelativePath}");
            }
            string unityPath = repositoryRelativePath.Substring(marker.Length);
            if (!unityPath.StartsWith("Assets/", StringComparison.Ordinal))
            {
                throw new InvalidDataException($"Managed target is not under Assets: {repositoryRelativePath}");
            }
            return unityPath;
        }

        #pragma warning disable 0649 // Populated by JsonUtility from the generated manifest.
        [Serializable]
        private sealed class AssetManifest
        {
            public string schema;
            public ManifestEntry[] entries;
        }

        [Serializable]
        private sealed class ManifestEntry
        {
            public string targetPath;
            public string importPreset;
        }
        #pragma warning restore 0649
    }
}
