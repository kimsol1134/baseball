using System;
using Baseball.Core.Domain;

namespace Baseball.Presentation.Pitch
{
    /// <summary>Deterministic address selection for one authoritative presentation snapshot.</summary>
    public readonly struct PitchAudioSelection
    {
        public PitchAudioSelection(string primaryAddress, string crowdAddress)
        {
            PrimaryAddress = primaryAddress ?? string.Empty;
            CrowdAddress = crowdAddress ?? string.Empty;
        }

        public string PrimaryAddress { get; }
        public string CrowdAddress { get; }
    }

    public static class PitchAudioSelectionPolicy
    {
        public static PitchAudioSelection Select(PitchPresentationSnapshot presentation)
        {
            if (presentation == null) throw new ArgumentNullException(nameof(presentation));
            string primary = Variant(
                BaseAddress(presentation.AudioCue),
                presentation.PresentationSeed,
                HasVariants(presentation.AudioCue),
                0x415544494F505249UL);
            string crowd = CrowdBase(presentation);
            return new PitchAudioSelection(
                primary,
                Variant(crowd, presentation.PresentationSeed, !string.IsNullOrEmpty(crowd), 0x43524F5744524553UL));
        }

        private static string CrowdBase(PitchPresentationSnapshot presentation)
        {
            if (presentation.AudioCue == PitchAudioCue.UmpireStrikeout)
                return "baseball/audio/crowd-cheer";
            if (presentation.ScoreDelta.RunsAllowed > 0)
                return "baseball/audio/crowd-groan";
            switch (presentation.Call)
            {
                case PitchOutcome.InPlayOut: return "baseball/audio/crowd-cheer";
                case PitchOutcome.Single:
                case PitchOutcome.Double:
                case PitchOutcome.Triple:
                case PitchOutcome.HomeRun:
                case PitchOutcome.HitByPitch:
                    return "baseball/audio/crowd-groan";
                default: return string.Empty;
            }
        }

        private static string BaseAddress(PitchAudioCue cue)
        {
            switch (cue)
            {
                case PitchAudioCue.GloveCatch: return "baseball/audio/glove-catch";
                case PitchAudioCue.SwingMiss: return "baseball/audio/swing-miss";
                case PitchAudioCue.UmpireStrike: return "baseball/audio/umpire-strike";
                case PitchAudioCue.UmpireStrikeout: return "baseball/audio/umpire-strikeout";
                case PitchAudioCue.Foul: return "baseball/audio/bat-foul";
                case PitchAudioCue.WeakContact: return "baseball/audio/bat-contact-weak";
                case PitchAudioCue.HardContact: return "baseball/audio/bat-contact-hard";
                default: return string.Empty;
            }
        }

        private static bool HasVariants(PitchAudioCue cue) =>
            cue != PitchAudioCue.SwingMiss && cue != PitchAudioCue.UmpireStrikeout;

        private static string Variant(string address, ulong seed, bool hasVariants, ulong salt)
        {
            if (string.IsNullOrEmpty(address) || !hasVariants) return address ?? string.Empty;
            switch ((seed ^ salt) % 3UL)
            {
                case 1: return address + "-2";
                case 2: return address + "-3";
                default: return address;
            }
        }
    }
}
