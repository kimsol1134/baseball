using System;
using System.Threading.Tasks;
using Baseball.Platform.Analytics;
using Baseball.Platform.Configuration;
using UnityEngine;

namespace Baseball.Platform.Crash
{
    [DefaultExecutionOrder(-8900)]
    public sealed class CrashReportingBootstrap : MonoBehaviour
    {
        private static CrashReportingBootstrap _instance;

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
        private static void ResetStatics()
        {
            _instance = null;
            CrashReporting.Reset();
        }

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
        private static void EnsureExists()
        {
            if (_instance == null) new GameObject("Crash Reporting Bootstrap").AddComponent<CrashReportingBootstrap>();
        }

        private async void Awake()
        {
            if (_instance != null && _instance != this)
            {
                Destroy(gameObject);
                return;
            }
            _instance = this;
            DontDestroyOnLoad(gameObject);

            AnalyticsRuntimeConfiguration config = AnalyticsRuntimeConfiguration.Load();
            if (config.crashlyticsEnabled)
            {
                var firebase = new FirebaseCrashReporter();
                await firebase.InitializeAsync();
                if (firebase.IsReady) CrashReporting.Configure(firebase);
            }
            AppDomain.CurrentDomain.UnhandledException += HandleUnhandledException;
            TaskScheduler.UnobservedTaskException += HandleUnobservedTaskException;
        }

        private void OnDestroy()
        {
            if (_instance != this) return;
            AppDomain.CurrentDomain.UnhandledException -= HandleUnhandledException;
            TaskScheduler.UnobservedTaskException -= HandleUnobservedTaskException;
            _instance = null;
        }

        private static void HandleUnhandledException(object sender, UnhandledExceptionEventArgs args)
        {
            if (args.ExceptionObject is Exception exception)
            {
                CrashReporting.RecordUnexpected(exception, "unhandled");
            }
        }

        private static void HandleUnobservedTaskException(object sender, UnobservedTaskExceptionEventArgs args)
        {
            CrashReporting.RecordUnexpected(args.Exception, "unobserved_task");
        }

#if DEVELOPMENT_BUILD || UNITY_EDITOR
        public static void TriggerTestCrashForInternalBuildOnly()
        {
            throw new InvalidOperationException("Crash reporting internal verification crash");
        }
#endif
    }
}
