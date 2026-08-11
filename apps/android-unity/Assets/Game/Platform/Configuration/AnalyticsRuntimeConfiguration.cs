using System;
using UnityEngine;

namespace Baseball.Platform.Configuration
{
    [Serializable]
    public sealed class AnalyticsRuntimeConfiguration
    {
        public string distribution = "development";
        public bool firebaseEnabled;
        public bool crashlyticsEnabled;
        public bool amplitudeEnabled;
        public string amplitudeApiKey = string.Empty;

        public static AnalyticsRuntimeConfiguration Load()
        {
            TextAsset asset = Resources.Load<TextAsset>("analytics-config.generated");
            if (asset == null) return new AnalyticsRuntimeConfiguration();
            AnalyticsRuntimeConfiguration parsed = JsonUtility.FromJson<AnalyticsRuntimeConfiguration>(asset.text);
            return parsed ?? new AnalyticsRuntimeConfiguration();
        }
    }
}
