using System;
using System.Collections.Generic;
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
        public static bool Log(
            AnalyticsEvent analyticsEvent,
            IReadOnlyDictionary<string, object> properties = null)
        {
            IReadOnlyDictionary<string, object> validated;
            try { validated = AnalyticsPrivacyGuard.ValidateAndCopy(properties); }
            catch (Exception) { return false; }

            AnalyticsService service;
            lock (ServiceGate)
            {
                service = Service;
                if (service == null)
                {
                    StartupBuffer.Enqueue(analyticsEvent, validated);
                    return true;
                }
            }
            try
            {
                service.Log(analyticsEvent, validated);
                return true;
            }
            catch (Exception)
            {
                // Analytics never blocks game progress, but callers coordinating a process-local
                // exposure guard may release it and retry the SDK handoff on a later appearance.
                return false;
            }
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
            finally { AcknowledgePreparedResetCleanup(); }
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
            try
            {
                AnalyticsRuntimeConfiguration config = AnalyticsRuntimeConfiguration.Load();
                var destinations = new List<IAnalyticsDestination>();
                if (config.firebaseEnabled)
                {
                    var firebase = new FirebaseAnalyticsDestination();
                    await firebase.InitializeAsync();
                    if (firebase.IsReady) destinations.Add(firebase);
                }
                if (config.amplitudeEnabled && !string.IsNullOrWhiteSpace(config.amplitudeApiKey))
                {
                    destinations.Add(new AmplitudeAnalyticsDestination(config.amplitudeApiKey));
                }
                if (destinations.Count == 0) destinations.Add(new NoOpAnalyticsDestination());

                AnalyticsDistribution distribution = config.ResolveDistribution();
                string installId = AnonymousInstallIdentity.GetOrCreate();
                string noBackupDirectory = AnonymousInstallIdentity.ResolveNoBackupDirectory();
                Func<string, IAnalyticsOnceStore> onceStoreForInstall = value =>
                    new FileAnalyticsOnceStore(
                        InstallScopedLocalStatePolicy.AnalyticsOncePath(noBackupDirectory, value));
                var service = new AnalyticsService(
                    new AnalyticsContext(UnityEngine.Application.version, GetBuildVersion(), distribution),
                    destinations,
                    onceStoreForInstall(installId),
                    installId,
                    onceStoreForInstall);
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
            catch (Exception)
            {
                // Analytics initialization is fail-open. The candidate install namespace was
                // already selected by the reset journal, so no previous receipt can leak through.
            }
            finally
            {
                AcknowledgePreparedResetCleanup();
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

        private static void AcknowledgePreparedResetCleanup()
        {
            if (!AnonymousInstallIdentity.TryReconcilePreparedLocalState()) return;
            if (!AnonymousInstallIdentity.MarkPreparedResetStep(
                    InstallResetStep.AnalyticsCleaned)) return;
            AnonymousInstallIdentity.TryCompletePreparedReset();
        }

    }
}
