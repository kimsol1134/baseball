using System;

namespace Baseball.Platform.Crash
{
    public static class CrashReporting
    {
        private static ICrashReporter _reporter = new NoOpCrashReporter();

        public static ICrashReporter Reporter => _reporter;

        public static void Configure(ICrashReporter reporter)
        {
            _reporter = reporter ?? new NoOpCrashReporter();
        }

        public static void SetContext(CrashContext context)
        {
            Try(() => _reporter.SetContext(context));
        }

        public static void RecordUnexpected(Exception exception, string category)
        {
            Try(() => _reporter.RecordUnexpected(exception, category));
        }

        private static void Try(Action operation)
        {
            try { operation(); }
            catch (Exception) { /* Crash reporting must never cause a second failure. */ }
        }
    }
}
