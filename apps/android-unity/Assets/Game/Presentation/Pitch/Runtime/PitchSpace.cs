using UnityEngine;

namespace Baseball.Presentation.Pitch
{
    public static class PitchSpace
    {
        public static readonly Vector3 PlateCenter = Vector3.zero;
        public static readonly Vector3 ReleasePoint = new Vector3(0f, 1.85f, 18.44f);
        public const float StrikeZoneHalfWidthMeters = 0.216f;
        public const float StrikeZoneBottomMeters = 0.50f;
        public const float StrikeZoneTopMeters = 1.00f;

        public static Vector3 ToWorld(TrajectoryPoint point)
        {
            return new Vector3((float)point.XMeters, (float)point.YMeters, (float)point.ZMeters);
        }

        public static Vector3 PlateCrossing(double normalizedX, double normalizedY)
        {
            return new Vector3(
                (float)(normalizedX * StrikeZoneHalfWidthMeters * 2.0),
                (float)(0.75 + normalizedY * 0.25),
                0f);
        }
    }
}
