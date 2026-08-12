using System;

namespace Baseball.Platform.Crash
{
    public static class CrashReporting
    {
        private static readonly object Gate = new object();
        private static ICrashReporter _reporter = new NoOpCrashReporter();
        private static CrashContext? _lastContext;

        public static ICrashReporter Reporter
        {
            get
            {
                lock (Gate) return _reporter;
            }
        }

        public static void Configure(ICrashReporter reporter)
        {
            ICrashReporter configured = reporter ?? new NoOpCrashReporter();
            CrashContext? lastContext;
            lock (Gate)
            {
                _reporter = configured;
                lastContext = _lastContext;
            }
            if (lastContext.HasValue)
            {
                Try(() => configured.SetContext(lastContext.Value));
            }
        }

        public static void Reset()
        {
            lock (Gate)
            {
                _reporter = new NoOpCrashReporter();
                _lastContext = null;
            }
            CrashRuntimeDiagnostics.Reset();
        }

        public static void SetContext(CrashContext context)
        {
            ICrashReporter reporter;
            lock (Gate)
            {
                _lastContext = context;
                reporter = _reporter;
            }
            Try(() => reporter.SetContext(context));
        }

        public static void RecordUnexpected(Exception exception, string category)
        {
            ICrashReporter reporter;
            lock (Gate) reporter = _reporter;
            Try(() => reporter.RecordUnexpected(exception, category));
        }

        internal static void UpdateQualityTier(string qualityTier)
        {
            ICrashReporter reporter;
            CrashContext updated;
            lock (Gate)
            {
                if (!_lastContext.HasValue) return;
                updated = _lastContext.Value.WithQualityTier(qualityTier);
                _lastContext = updated;
                reporter = _reporter;
            }
            Try(() => reporter.SetContext(updated));
        }

        internal static void UpdatePitchStageLoaded(bool pitchStageLoaded)
        {
            ICrashReporter reporter;
            CrashContext updated;
            lock (Gate)
            {
                if (!_lastContext.HasValue) return;
                updated = _lastContext.Value.WithPitchStageLoaded(pitchStageLoaded);
                _lastContext = updated;
                reporter = _reporter;
            }
            Try(() => reporter.SetContext(updated));
        }

        private static void Try(Action operation)
        {
            try { operation(); }
            catch (Exception) { /* Crash reporting must never cause a second failure. */ }
        }
    }

    /// <summary>
    /// Privacy-safe, process-local projection of adaptive pitch quality and the actually loaded
    /// presentation stage. Only low-cardinality high/low and boolean values reach Crashlytics.
    /// </summary>
    public static class CrashRuntimeDiagnostics
    {
        private static readonly object Gate = new object();
        private static string _currentTier = "unknown";
        private static bool _pitchStageLoaded;

        public static string CurrentQualityTier
        {
            get
            {
                lock (Gate) return _currentTier;
            }
        }

        public static bool InitializeQualityTier(string qualityTier)
        {
            string normalized = Normalize(qualityTier);
            if (normalized == null) return false;
            lock (Gate)
            {
                if (!string.Equals(_currentTier, "unknown", StringComparison.Ordinal)) return false;
                _currentTier = normalized;
            }
            CrashReporting.UpdateQualityTier(normalized);
            return true;
        }

        public static bool PublishQualityTier(string qualityTier)
        {
            string normalized = Normalize(qualityTier);
            if (normalized == null) return false;
            bool changed;
            lock (Gate)
            {
                changed = !string.Equals(_currentTier, normalized, StringComparison.Ordinal);
                _currentTier = normalized;
            }
            if (changed) CrashReporting.UpdateQualityTier(normalized);
            return true;
        }

        public static bool PitchStageLoaded
        {
            get
            {
                lock (Gate) return _pitchStageLoaded;
            }
        }

        public static void PublishPitchStageLoaded(bool loaded)
        {
            bool changed;
            lock (Gate)
            {
                changed = _pitchStageLoaded != loaded;
                _pitchStageLoaded = loaded;
            }
            if (changed) CrashReporting.UpdatePitchStageLoaded(loaded);
        }

        internal static void Reset()
        {
            lock (Gate)
            {
                _currentTier = "unknown";
                _pitchStageLoaded = false;
            }
        }

        private static string Normalize(string qualityTier)
        {
            string normalized = (qualityTier ?? string.Empty).Trim().ToLowerInvariant();
            return normalized == "high" || normalized == "low" ? normalized : null;
        }
    }
}
