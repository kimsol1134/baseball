namespace Baseball.Application.Persistence
{
    /// <summary>
    /// Product preferences are part of the authoritative save. Platform-only permission prompts
    /// may remain local, but the player's requested notification enablement lives here.
    /// </summary>
    public sealed class GameSettingsState
    {
        public const int CurrentSchemaVersion = 1;

        public GameSettingsState(
            int schemaVersion = CurrentSchemaVersion,
            bool autoReleaseEnabled = false,
            bool soundEnabled = true,
            bool musicEnabled = true,
            bool hapticsEnabled = true,
            bool notificationsEnabled = false,
            bool highContrastEnabled = false,
            bool reducedMotionEnabled = false)
        {
            SchemaVersion = schemaVersion;
            AutoReleaseEnabled = autoReleaseEnabled;
            SoundEnabled = soundEnabled;
            MusicEnabled = musicEnabled;
            HapticsEnabled = hapticsEnabled;
            NotificationsEnabled = notificationsEnabled;
            HighContrastEnabled = highContrastEnabled;
            ReducedMotionEnabled = reducedMotionEnabled;
        }

        public int SchemaVersion { get; }
        public bool AutoReleaseEnabled { get; }
        public bool SoundEnabled { get; }
        public bool MusicEnabled { get; }
        public bool HapticsEnabled { get; }
        public bool NotificationsEnabled { get; }
        public bool HighContrastEnabled { get; }
        public bool ReducedMotionEnabled { get; }

        public static GameSettingsState Default { get; } = new GameSettingsState();

        public GameSettingsState With(
            bool? autoReleaseEnabled = null,
            bool? soundEnabled = null,
            bool? musicEnabled = null,
            bool? hapticsEnabled = null,
            bool? notificationsEnabled = null,
            bool? highContrastEnabled = null,
            bool? reducedMotionEnabled = null)
        {
            return new GameSettingsState(
                CurrentSchemaVersion,
                autoReleaseEnabled ?? AutoReleaseEnabled,
                soundEnabled ?? SoundEnabled,
                musicEnabled ?? MusicEnabled,
                hapticsEnabled ?? HapticsEnabled,
                notificationsEnabled ?? NotificationsEnabled,
                highContrastEnabled ?? HighContrastEnabled,
                reducedMotionEnabled ?? ReducedMotionEnabled);
        }
    }
}
