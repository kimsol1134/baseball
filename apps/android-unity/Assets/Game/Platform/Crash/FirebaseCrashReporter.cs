using System;
using System.Threading.Tasks;
using Firebase;
using Firebase.Crashlytics;

namespace Baseball.Platform.Crash
{
    public sealed class FirebaseCrashReporter : ICrashReporter
    {
        private static readonly TimeSpan DependencyTimeout = TimeSpan.FromSeconds(10);
        private const int DefaultAppPollAttempts = 100;
        private const int DefaultAppPollDelayMilliseconds = 100;

        public bool IsReady { get; private set; }

        public async Task InitializeAsync()
        {
            try
            {
                for (int attempt = 0; attempt < DefaultAppPollAttempts; attempt++)
                {
                    if (TryBindDefaultApp()) return;
                    await Task.Delay(DefaultAppPollDelayMilliseconds);
                }

                Task<DependencyStatus> dependencyCheck = FirebaseApp.CheckAndFixDependenciesAsync();
                Task completed = await Task.WhenAny(dependencyCheck, Task.Delay(DependencyTimeout));
                if (completed == dependencyCheck)
                {
                    if (await dependencyCheck == DependencyStatus.Available)
                    {
                        TryBindDefaultApp();
                    }
                }
                else
                {
                    // Firebase's Android content provider can finish creating the default app even
                    // when the Unity dependency Task does not resume. A bounded fallback avoids
                    // leaving Crashlytics permanently behind the NoOp reporter in that state.
                    TryBindDefaultApp();
                }
            }
            catch (Exception)
            {
                IsReady = false;
            }
        }

        private bool TryBindDefaultApp()
        {
            try
            {
                if (FirebaseApp.DefaultInstance == null) return false;
                Crashlytics.IsCrashlyticsCollectionEnabled = true;
                IsReady = true;
                return true;
            }
            catch (Exception)
            {
                IsReady = false;
                return false;
            }
        }

        public void SetContext(CrashContext context)
        {
            if (!IsReady) return;
            Crashlytics.SetCustomKey("distribution", Limit(context.Distribution));
            Crashlytics.SetCustomKey("save_schema", context.SaveSchema.ToString());
            Crashlytics.SetCustomKey("save_revision", context.SaveRevision.ToString());
            Crashlytics.SetCustomKey("app_phase", Limit(context.AppPhase));
            Crashlytics.SetCustomKey("pitch_stage_loaded", context.PitchStageLoaded ? "true" : "false");
            Crashlytics.SetCustomKey("quality_tier", Limit(context.QualityTier));
        }

        public void RecordUnexpected(Exception exception, string category)
        {
            if (!IsReady || exception == null) return;
            Crashlytics.SetCustomKey("unexpected_category", Limit(category));
            Crashlytics.LogException(exception);
        }

        private static string Limit(string value)
        {
            string safe = string.IsNullOrWhiteSpace(value) ? "unknown" : value.Trim();
            return safe.Length <= 32 ? safe : safe.Substring(0, 32);
        }
    }
}
