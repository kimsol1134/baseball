// The Unity install used by this gate provides UnityEditor/Android/URP reference DLLs but does not
// materialize the project's UPM Addressables package without opening the project. These minimal
// compile-only shapes keep the Editor source closure checked; a licensed Unity batch compile remains
// the authoritative Addressables API/asmdef/import proof.
using System;
using System.Collections.Generic;
using UnityEngine;

namespace UnityEditor.AddressableAssets
{
    using UnityEditor.AddressableAssets.Settings;

    public static class AddressableAssetSettingsDefaultObject
    {
        public static AddressableAssetSettings GetSettings(bool create) => null;
    }
}

namespace UnityEditor.AddressableAssets.Settings
{
    public sealed class AddressableAssetSettings : ScriptableObject
    {
        public enum PlayerBuildOption { BuildWithPlayer }
        public const string kLocalBuildPath = "LocalBuildPath";
        public const string kLocalLoadPath = "LocalLoadPath";
        public bool BuildRemoteCatalog { get; set; }
        public PlayerBuildOption BuildAddressablesWithPlayerBuild { get; set; }
        public AddressableAssetGroup FindGroup(string name) => null;
        public AddressableAssetGroup CreateGroup(
            string name,
            bool setAsDefaultGroup,
            bool readOnly,
            bool postEvent,
            object schemasToCopy,
            params Type[] schemaTypes) => null;
        public AddressableAssetEntry CreateOrMoveEntry(
            string guid,
            AddressableAssetGroup group,
            bool readOnly,
            bool postEvent) => null;
        public void RemoveAssetEntry(string guid, bool postEvent) { }
    }

    public sealed class AddressableAssetGroup : ScriptableObject
    {
        public List<AddressableAssetEntry> entries { get; } = new List<AddressableAssetEntry>();
        public T GetSchema<T>() where T : ScriptableObject => null;
        public ScriptableObject AddSchema(Type type, bool postEvent) => null;
    }

    public sealed class AddressableAssetEntry
    {
        public string guid { get; set; }
        public string address { get; set; }
        public HashSet<string> labels { get; } = new HashSet<string>(StringComparer.Ordinal);
        public void SetLabel(string label, bool enable, bool force, bool postEvent) { }
    }
}

namespace UnityEditor.AddressableAssets.Settings.GroupSchemas
{
    using UnityEditor.AddressableAssets.Settings;

    public sealed class ProfileValueReference
    {
        public void SetVariableByName(AddressableAssetSettings settings, string variableName) { }
        public string GetName(AddressableAssetSettings settings) => string.Empty;
    }

    public sealed class BundledAssetGroupSchema : ScriptableObject
    {
        public enum BundlePackingMode { PackTogetherByLabel }
        public enum BundleCompressionMode { LZ4 }
        public ProfileValueReference BuildPath { get; } = new ProfileValueReference();
        public ProfileValueReference LoadPath { get; } = new ProfileValueReference();
        public BundlePackingMode BundleMode { get; set; }
        public BundleCompressionMode Compression { get; set; }
        public bool IncludeInBuild { get; set; }
        public bool UseAssetBundleCrc { get; set; }
        public bool UseAssetBundleCrcForCachedBundles { get; set; }
        public bool UseUnityWebRequestForLocalBundles { get; set; }
        public bool StripDownloadOptions { get; set; }
    }

    public sealed class ContentUpdateGroupSchema : ScriptableObject
    {
        public bool StaticContent { get; set; }
    }
}
