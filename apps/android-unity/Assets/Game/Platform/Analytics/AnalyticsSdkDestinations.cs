using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Firebase;
using Firebase.Analytics;

namespace Baseball.Platform.Analytics
{
    public sealed class FirebaseAnalyticsDestination : IAnalyticsDestination
    {
        public AnalyticsDestinationKind Kind => AnalyticsDestinationKind.Firebase;
        public bool IsReady { get; private set; }

        public async Task InitializeAsync()
        {
            try
            {
                DependencyStatus status = await FirebaseApp.CheckAndFixDependenciesAsync();
                IsReady = status == DependencyStatus.Available;
                if (IsReady) FirebaseAnalytics.SetAnalyticsCollectionEnabled(true);
            }
            catch (Exception)
            {
                IsReady = false;
            }
        }

        public void SetAnonymousInstallId(string installId)
        {
            if (IsReady) FirebaseAnalytics.SetUserId(installId);
        }

        public void Log(string eventName, IReadOnlyDictionary<string, object> properties)
        {
            if (!IsReady) return;
            Parameter[] parameters = properties.Select(ToParameter).ToArray();
            FirebaseAnalytics.LogEvent(eventName, parameters);
        }

        public void Flush() { }

        private static Parameter ToParameter(KeyValuePair<string, object> pair)
        {
            object value = FirebaseAnalyticsValueAdapter.Normalize(pair.Value);
            if (value is long integer) return new Parameter(pair.Key, integer);
            if (value is double number) return new Parameter(pair.Key, number);
            return new Parameter(pair.Key, (string)value);
        }
    }

    public sealed class AmplitudeAnalyticsDestination : IAnalyticsDestination
    {
        private readonly Amplitude _amplitude;
        public AnalyticsDestinationKind Kind => AnalyticsDestinationKind.Amplitude;
        public bool IsReady { get; private set; }

        public AmplitudeAnalyticsDestination(string apiKey)
        {
            _amplitude = Amplitude.getInstance("baseball-production");
            var disabledTracking = new Dictionary<string, bool>(StringComparer.Ordinal)
            {
                // These keys are the exact Amplitude Unity 2.8 Android bridge contract.
                ["disableADID"] = true,
                ["disableAppSetId"] = true,
                ["disableCarrier"] = true,
                ["disableCity"] = true,
                ["disableCountry"] = true,
                ["disableDMA"] = true,
                ["disableIPAddress"] = true,
                ["disableLatLng"] = true,
                ["disableRegion"] = true
            };
            _amplitude.setTrackingOptions(disabledTracking);
            _amplitude.init(apiKey);
            IsReady = !string.IsNullOrWhiteSpace(apiKey);
        }

        public void SetAnonymousInstallId(string installId)
        {
            if (!IsReady) return;
            _amplitude.setDeviceId(installId);
            _amplitude.setUserId(installId);
        }

        public void Log(string eventName, IReadOnlyDictionary<string, object> properties)
        {
            if (!IsReady) return;
            var payload = new Dictionary<string, object>(StringComparer.Ordinal);
            foreach (KeyValuePair<string, object> pair in properties) payload[pair.Key] = pair.Value;
            _amplitude.logEvent(eventName, payload);
        }

        public void Flush()
        {
            if (IsReady) _amplitude.uploadEvents();
        }
    }
}
