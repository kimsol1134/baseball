using System;
using System.Collections.Generic;
using System.IO;
using Baseball.Platform.Configuration;
using Baseball.Platform.Identity;
using UnityEngine;

namespace Baseball.Platform.Analytics
{
    [DefaultExecutionOrder(-9000)]
    public sealed class AnalyticsBootstrap : MonoBehaviour
    {
        private static readonly object ServiceGate = new object();
        private static readonly AnalyticsStartupBuffer StartupBuffer =
            new AnalyticsStartupBuffer(AnalyticsStartupBuffer.ProductionCapacity);
        private static AnalyticsBootstrap _instance;
        public static AnalyticsService Service { get; private set; }

        /// <summary>
        /// Fail-open logging boundary that preserves privacy-validated events while SDK setup is
        /// awaiting Firebase dependency resolution.
        /// </summary>
        public static void Log(
            AnalyticsEvent analyticsEvent,
            IReadOnlyDictionary<string, object> properties = null)
        {
            IReadOnlyDictionary<string, object> validated;
            try { validated = AnalyticsPrivacyGuard.ValidateAndCopy(properties); }
            catch (Exception) { return; }

            AnalyticsService service;
            lock (ServiceGate)
            {
                service = Service;
                if (service == null)
                {
                    StartupBuffer.Enqueue(analyticsEvent, validated);
                    return;
                }
            }
            try { service.Log(analyticsEvent, validated); }
            catch (Exception) { /* Analytics never blocks game progress. */ }
        }

        public static void ResetIdentityAndOnceFlags(string anonymousInstallId)
        {
            AnalyticsService service;
            lock (ServiceGate)
            {
                // Queued events belong to the previous anonymous identity and must never cross a
                // successful reset-all boundary.
                StartupBuffer.Clear();
                service = Service;
            }
            try { service?.ResetIdentityAndOnceFlags(anonymousInstallId); }
            catch (Exception) { /* Analytics reset remains fail-open after durable save reset. */ }
        }

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
        private static void ResetStatics()
        {
            lock (ServiceGate)
            {
                _instance = null;
                Service = null;
                StartupBuffer.Clear();
            }
        }

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
        private static void EnsureExists()
        {
            if (_instance == null) new GameObject("Analytics Bootstrap").AddComponent<AnalyticsBootstrap>();
        }

        private async void Awake()
        {
            await System.Threading.Tasks.Task.CompletedTask;
            if (_instance != null && _instance != this)
            {
                Destroy(gameObject);
                return;
            }
            _instance = this;
            DontDestroyOnLoad(gameObject);

            AnalyticsRuntimeConfiguration config = AnalyticsRuntimeConfiguration.Load();
            var destinations = new List<IAnalyticsDestination>();
            if (config.firebaseEnabled)
            {
                var firebase = new FirebaseAnalyticsDestination();
                await firebase.InitializeAsync();
                if (firebase.IsReady) destinations.Add(firebase);
            }
            else
            {
                try { Firebase.Analytics.FirebaseAnalytics.SetAnalyticsCollectionEnabled(false); }
                catch (Exception) { /* The disabled SDK must not affect offline startup. */ }
            }
            if (config.amplitudeEnabled && !string.IsNullOrWhiteSpace(config.amplitudeApiKey))
            {
                destinations.Add(new AmplitudeAnalyticsDestination(config.amplitudeApiKey));
            }
            if (destinations.Count == 0) destinations.Add(new NoOpAnalyticsDestination());

            AnalyticsDistribution distribution = ParseDistribution(config.distribution);
#if UNITY_EDITOR
            distribution = AnalyticsDistribution.Editor;
#endif
            string oncePath = Path.Combine(AnonymousInstallIdentity.ResolveNoBackupDirectory(), "analytics-once-v1.txt");
            var service = new AnalyticsService(
                new AnalyticsContext(UnityEngine.Application.version, GetBuildVersion(), distribution),
                destinations,
                new FileAnalyticsOnceStore(oncePath),
                AnonymousInstallIdentity.GetOrCreate());
            AnalyticsStartupEvent[] pending;
            lock (ServiceGate)
            {
                Service = service;
                pending = StartupBuffer.Drain();
            }
            foreach (AnalyticsStartupEvent item in pending)
            {
                try { service.Log(item.Event, item.Properties); }
                catch (Exception) { /* One SDK failure must not stop draining later events. */ }
            }
        }

        private void OnApplicationPause(bool paused)
        {
            if (paused) Service?.Flush();
        }

        private void OnApplicationQuit()
        {
            Service?.Flush();
        }

        private static string GetBuildVersion()
        {
#if UNITY_ANDROID && !UNITY_EDITOR
            try
            {
                using var player = new AndroidJavaClass("com.unity3d.player.UnityPlayer");
                using AndroidJavaObject activity = player.GetStatic<AndroidJavaObject>("currentActivity");
                using AndroidJavaObject packageManager = activity.Call<AndroidJavaObject>("getPackageManager");
                string packageName = activity.Call<string>("getPackageName");
                using AndroidJavaObject packageInfo = packageManager.Call<AndroidJavaObject>("getPackageInfo", packageName, 0);
                return packageInfo.Get<int>("versionCode").ToString();
            }
            catch (Exception) { return "unknown"; }
#else
            return "editor";
#endif
        }

        private static AnalyticsDistribution ParseDistribution(string value)
        {
            switch ((value ?? string.Empty).Trim().ToLowerInvariant())
            {
                case "production": return AnalyticsDistribution.Production;
                case "closed": return AnalyticsDistribution.Closed;
                case "internal": return AnalyticsDistribution.Internal;
                case "editor": return AnalyticsDistribution.Editor;
                default: return AnalyticsDistribution.Development;
            }
        }
    }
}
