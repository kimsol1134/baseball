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
            Distribution = NormalizeDistribution(distribution);
            SaveSchema = saveSchema;
            SaveRevision = saveRevision;
            AppPhase = NormalizeToken(appPhase);
            PitchStageLoaded = pitchStageLoaded;
            QualityTier = NormalizeQualityTier(qualityTier);
        }

        public string Distribution { get; }
        public int SaveSchema { get; }
        public ulong SaveRevision { get; }
        public string AppPhase { get; }
        public bool PitchStageLoaded { get; }
        public string QualityTier { get; }

        public CrashContext WithQualityTier(string qualityTier) => new CrashContext(
            Distribution,
            SaveSchema,
            SaveRevision,
            AppPhase,
            PitchStageLoaded,
            qualityTier);

        public CrashContext WithPitchStageLoaded(bool pitchStageLoaded) => new CrashContext(
            Distribution,
            SaveSchema,
            SaveRevision,
            AppPhase,
            pitchStageLoaded,
            QualityTier);

        private static string NormalizeDistribution(string value)
        {
            switch ((value ?? string.Empty).Trim().ToLowerInvariant())
            {
                case "editor":
                case "development":
                case "internal":
                case "closed":
                case "production":
                    return value.Trim().ToLowerInvariant();
                default:
                    return "unknown";
            }
        }

        private static string NormalizeQualityTier(string value)
        {
            string normalized = (value ?? string.Empty).Trim().ToLowerInvariant();
            return normalized == "high" || normalized == "low" ? normalized : "unknown";
        }

        private static string NormalizeToken(string value)
        {
            string normalized = (value ?? string.Empty).Trim().ToLowerInvariant();
            if (normalized.Length == 0 || normalized.Length > 32) return "unknown";
            for (int index = 0; index < normalized.Length; index++)
            {
                char character = normalized[index];
                if ((character >= 'a' && character <= 'z') ||
                    (character >= '0' && character <= '9') ||
                    character == '_' || character == '-')
                {
                    continue;
                }
                return "unknown";
            }
            return normalized;
        }
    }

    public sealed class NoOpCrashReporter : ICrashReporter
    {
        public bool IsReady => false;
        public void SetContext(CrashContext context) { }
        public void RecordUnexpected(Exception exception, string category) { }
    }
}
