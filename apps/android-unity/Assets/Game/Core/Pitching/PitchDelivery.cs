namespace Baseball.Core.Pitching
{
    /// <summary>Normalized player release input. 500/500 is the exact legacy identity.</summary>
    public struct PitchDelivery
    {
        public const int PerfectReleaseThreshold = 950;

        public PitchDelivery(int releaseAccuracy, int aimAccuracy)
        {
            ReleaseAccuracy = releaseAccuracy;
            AimAccuracy = aimAccuracy;
        }

        public int ReleaseAccuracy { get; }
        public int AimAccuracy { get; }
        public bool IsNeutral => ReleaseAccuracy == 500 && AimAccuracy == 500;
        public bool IsPerfectRelease => ReleaseAccuracy >= PerfectReleaseThreshold;
        public static PitchDelivery Neutral => new PitchDelivery(500, 500);
    }
}
