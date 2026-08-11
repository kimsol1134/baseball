using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.AddressableAssets;
using UnityEditor.AddressableAssets.Settings;
using UnityEditor.AddressableAssets.Settings.GroupSchemas;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEngine;

namespace Baseball.Editor
{
    /// <summary>
    /// Materializes the generated asset manifest as one local-only Addressables group. Running it
    /// repeatedly is idempotent; manifest removal also removes stale explicit entries.
    /// </summary>
    public static class LocalAddressablesConfiguration
    {
        private const string ManifestPath = "Assets/Game/Content/Manifests/asset-manifest.json";
        private const string GroupName = "Baseball Local Content";
        private const string ManifestSchema = "baseball-unity-asset-manifest-v1";
        private const string AddressPrefix = "baseball";

        private static readonly string[] AllowedLabels =
        {
            "bootstrap",
            "setup",
            "highschool",
            "pro",
            "pitch",
            "meta",
            "audio"
        };

        [MenuItem("Baseball/Assets/Synchronize Local Addressables")]
        public static void SynchronizeFromMenu()
        {
            EnsureConfigured();
            AssetDatabase.SaveAssets();
            Debug.Log($"Local Addressables synchronized from {ManifestPath}.");
        }

        public static void EnsureConfigured()
        {
            AssetManifest manifest = LoadManifest();
            AddressableAssetSettings settings = AddressableAssetSettingsDefaultObject.GetSettings(true);
            if (settings == null)
            {
                throw new BuildFailedException("Addressables settings could not be created.");
            }

            settings.BuildRemoteCatalog = false;
            settings.BuildAddressablesWithPlayerBuild =
                AddressableAssetSettings.PlayerBuildOption.BuildWithPlayer;

            AddressableAssetGroup group = settings.FindGroup(GroupName) ?? settings.CreateGroup(
                GroupName,
                false,
                false,
                false,
                null,
                typeof(BundledAssetGroupSchema),
                typeof(ContentUpdateGroupSchema));

            ConfigureLocalSchemas(settings, group);
            var expectedGuids = new HashSet<string>(StringComparer.Ordinal);
            var expectedAddresses = new HashSet<string>(StringComparer.Ordinal);

            foreach (ManifestEntry item in manifest.entries
                         .Where(entry => !string.IsNullOrWhiteSpace(entry.addressableLabel))
                         .OrderBy(entry => entry.targetPath, StringComparer.Ordinal))
            {
                ValidateManifestEntry(item);
                string assetPath = ToUnityAssetPath(item.targetPath);
                string guid = AssetDatabase.AssetPathToGUID(assetPath);
                if (string.IsNullOrEmpty(guid))
                {
                    throw new BuildFailedException($"Addressable asset is not imported: {assetPath}");
                }

                string address = $"{AddressPrefix}/{item.addressableLabel}/{item.logicalName}";
                if (!expectedAddresses.Add(address))
                {
                    throw new BuildFailedException($"Duplicate Addressables address: {address}");
                }

                expectedGuids.Add(guid);
                AddressableAssetEntry entry = settings.CreateOrMoveEntry(guid, group, false, false);
                if (entry == null)
                {
                    throw new BuildFailedException($"Could not create Addressables entry: {assetPath}");
                }

                entry.address = address;
                foreach (string label in AllowedLabels)
                {
                    entry.SetLabel(label, label == item.addressableLabel, true, false);
                }
            }

            foreach (AddressableAssetEntry stale in group.entries
                         .Where(entry => !expectedGuids.Contains(entry.guid))
                         .ToArray())
            {
                settings.RemoveAssetEntry(stale.guid, false);
            }

            EditorUtility.SetDirty(settings);
            EditorUtility.SetDirty(group);
            ValidateConfiguration(settings, group, expectedGuids.Count);
        }

        private static void ConfigureLocalSchemas(
            AddressableAssetSettings settings,
            AddressableAssetGroup group)
        {
            BundledAssetGroupSchema bundled = group.GetSchema<BundledAssetGroupSchema>()
                                               ?? (BundledAssetGroupSchema)group.AddSchema(
                                                   typeof(BundledAssetGroupSchema),
                                                   false);
            ContentUpdateGroupSchema content = group.GetSchema<ContentUpdateGroupSchema>()
                                               ?? (ContentUpdateGroupSchema)group.AddSchema(
                                                   typeof(ContentUpdateGroupSchema),
                                                   false);
            if (bundled == null || content == null)
            {
                throw new BuildFailedException("Local Addressables schemas could not be created.");
            }

            bundled.BuildPath.SetVariableByName(settings, AddressableAssetSettings.kLocalBuildPath);
            bundled.LoadPath.SetVariableByName(settings, AddressableAssetSettings.kLocalLoadPath);
            bundled.BundleMode = BundledAssetGroupSchema.BundlePackingMode.PackTogetherByLabel;
            bundled.Compression = BundledAssetGroupSchema.BundleCompressionMode.LZ4;
            bundled.IncludeInBuild = true;
            bundled.UseAssetBundleCrc = true;
            bundled.UseAssetBundleCrcForCachedBundles = true;
            bundled.UseUnityWebRequestForLocalBundles = false;
            bundled.StripDownloadOptions = true;
            content.StaticContent = true;
            EditorUtility.SetDirty(bundled);
            EditorUtility.SetDirty(content);
        }

        private static void ValidateConfiguration(
            AddressableAssetSettings settings,
            AddressableAssetGroup group,
            int expectedCount)
        {
            if (settings.BuildRemoteCatalog)
            {
                throw new BuildFailedException("Remote Addressables catalogs are forbidden for v1.");
            }

            if (settings.BuildAddressablesWithPlayerBuild
                != AddressableAssetSettings.PlayerBuildOption.BuildWithPlayer)
            {
                throw new BuildFailedException("Addressables must be rebuilt with every Android player.");
            }

            BundledAssetGroupSchema bundled = group.GetSchema<BundledAssetGroupSchema>();
            if (bundled == null
                || bundled.BuildPath.GetName(settings) != AddressableAssetSettings.kLocalBuildPath
                || bundled.LoadPath.GetName(settings) != AddressableAssetSettings.kLocalLoadPath
                || !bundled.IncludeInBuild)
            {
                throw new BuildFailedException("Addressables group is not locked to local build/load paths.");
            }

            if (group.entries.Count != expectedCount)
            {
                throw new BuildFailedException(
                    $"Addressables entry count mismatch: {group.entries.Count}, expected {expectedCount}.");
            }

            foreach (AddressableAssetEntry entry in group.entries)
            {
                int labelCount = AllowedLabels.Count(label => entry.labels.Contains(label));
                if (!entry.address.StartsWith(AddressPrefix + "/", StringComparison.Ordinal)
                    || labelCount != 1)
                {
                    throw new BuildFailedException(
                        $"Addressables entry has an invalid address/label contract: {entry.address}");
                }
            }
        }

        private static AssetManifest LoadManifest()
        {
            string projectRoot = Directory.GetParent(Application.dataPath)?.FullName
                                 ?? throw new BuildFailedException("Unity project root is unavailable.");
            string absolutePath = Path.Combine(projectRoot, ManifestPath);
            if (!File.Exists(absolutePath))
            {
                throw new BuildFailedException($"Asset manifest is missing: {ManifestPath}");
            }

            AssetManifest manifest = JsonUtility.FromJson<AssetManifest>(File.ReadAllText(absolutePath));
            if (manifest == null
                || !string.Equals(manifest.schema, ManifestSchema, StringComparison.Ordinal)
                || manifest.entries == null)
            {
                throw new BuildFailedException($"Asset manifest is invalid: {ManifestPath}");
            }
            return manifest;
        }

        private static void ValidateManifestEntry(ManifestEntry entry)
        {
            if (string.IsNullOrWhiteSpace(entry.logicalName)
                || string.IsNullOrWhiteSpace(entry.targetPath)
                || !AllowedLabels.Contains(entry.addressableLabel, StringComparer.Ordinal))
            {
                throw new BuildFailedException(
                    $"Manifest has an invalid runtime Addressables entry: {entry.logicalName}");
            }
        }

        private static string ToUnityAssetPath(string repositoryRelativePath)
        {
            const string marker = "apps/android-unity/";
            if (string.IsNullOrEmpty(repositoryRelativePath)
                || !repositoryRelativePath.StartsWith(marker, StringComparison.Ordinal))
            {
                throw new BuildFailedException(
                    $"Managed Addressables target is outside the Unity project: {repositoryRelativePath}");
            }

            string assetPath = repositoryRelativePath.Substring(marker.Length);
            if (!assetPath.StartsWith("Assets/", StringComparison.Ordinal))
            {
                throw new BuildFailedException(
                    $"Managed Addressables target is outside Assets: {repositoryRelativePath}");
            }
            return assetPath;
        }

#pragma warning disable 0649 // JsonUtility populates the generated manifest DTOs.
        [Serializable]
        private sealed class AssetManifest
        {
            public string schema;
            public ManifestEntry[] entries;
        }

        [Serializable]
        private sealed class ManifestEntry
        {
            public string logicalName;
            public string targetPath;
            public string addressableLabel;
        }
#pragma warning restore 0649
    }
}
