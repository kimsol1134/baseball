namespace Baseball.Presentation.Pitch
{
    public enum PitchQualityTier
    {
        High,
        Low
    }

    public readonly struct PitchQualitySignals
    {
        public PitchQualitySignals(
            int systemMemoryMegabytes,
            double p95FrameMilliseconds,
            int frameSampleCount,
            bool lowMemoryObserved)
        {
            SystemMemoryMegabytes = systemMemoryMegabytes;
            P95FrameMilliseconds = p95FrameMilliseconds;
            FrameSampleCount = frameSampleCount;
            LowMemoryObserved = lowMemoryObserved;
        }

        public int SystemMemoryMegabytes { get; }
        public double P95FrameMilliseconds { get; }
        public int FrameSampleCount { get; }
        public bool LowMemoryObserved { get; }
    }

    /// <summary>
    /// Fail-safe mobile pitch quality policy. Thermal state is unavailable in the current Android
    /// bridge, so memory, a bounded first-stage frame sample, and the OS low-memory signal are used.
    /// </summary>
    public static class PitchQualityPolicy
    {
        public const int HighMemoryFloorMegabytes = 6144;
        public const int MinimumFrameSamples = 60;
        public const double HighP95FrameBudgetMilliseconds = 28d;

        public static PitchQualityTier Select(PitchQualitySignals signals)
        {
            if (signals.LowMemoryObserved) return PitchQualityTier.Low;
            if (signals.SystemMemoryMegabytes < HighMemoryFloorMegabytes) return PitchQualityTier.Low;
            if (signals.FrameSampleCount >= MinimumFrameSamples &&
                signals.P95FrameMilliseconds > HighP95FrameBudgetMilliseconds)
            {
                return PitchQualityTier.Low;
            }
            return PitchQualityTier.High;
        }

        public static string Value(this PitchQualityTier tier) =>
            tier == PitchQualityTier.High ? "high" : "low";
    }
}
