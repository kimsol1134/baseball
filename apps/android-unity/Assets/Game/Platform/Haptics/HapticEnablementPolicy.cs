namespace Baseball.Platform.Haptics
{
    public static class HapticEnablementPolicy
    {
        public static bool Allows(
            bool appEnabled,
            bool reducedMotion,
            bool systemEnabled,
            bool vibratorAvailable) =>
            appEnabled && !reducedMotion && systemEnabled && vibratorAvailable;
    }
}
