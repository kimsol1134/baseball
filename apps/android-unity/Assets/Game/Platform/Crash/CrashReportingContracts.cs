using System;

namespace Baseball.Platform.Crash
{
    public interface ICrashReporter
    {
        bool IsReady { get; }
        void SetContext(CrashContext context);
        void RecordUnexpected(Exception exception, string category);
    }

    public readonly struct CrashContext
    {
        public CrashContext(
            string distribution,
            int saveSchema,
            ulong saveRevision,
            string appPhase,
            bool pitchStageLoaded,
            string qualityTier)
        {
            Distribution = distribution ?? "unknown";
            SaveSchema = saveSchema;
            SaveRevision = saveRevision;
            AppPhase = appPhase ?? "unknown";
            PitchStageLoaded = pitchStageLoaded;
            QualityTier = qualityTier ?? "unknown";
        }

        public string Distribution { get; }
        public int SaveSchema { get; }
        public ulong SaveRevision { get; }
        public string AppPhase { get; }
        public bool PitchStageLoaded { get; }
        public string QualityTier { get; }
    }

    public sealed class NoOpCrashReporter : ICrashReporter
    {
        public bool IsReady => false;
        public void SetContext(CrashContext context) { }
        public void RecordUnexpected(Exception exception, string category) { }
    }
}
