using System;
using System.Threading.Tasks;
using Firebase;
using Firebase.Crashlytics;

namespace Baseball.Platform.Crash
{
    public sealed class FirebaseCrashReporter : ICrashReporter
    {
        public bool IsReady { get; private set; }

        public async Task InitializeAsync()
        {
            try
            {
                DependencyStatus status = await FirebaseApp.CheckAndFixDependenciesAsync();
                IsReady = status == DependencyStatus.Available;
                if (IsReady) Crashlytics.IsCrashlyticsCollectionEnabled = true;
            }
            catch (Exception)
            {
                IsReady = false;
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
