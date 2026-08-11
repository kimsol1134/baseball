#if UNITY_EDITOR || (DEVELOPMENT_BUILD && BASEBALL_INTERNAL_QA)
using System;
using System.Collections.Generic;
using Baseball.Core.Domain;
using Baseball.Core.Pitching;
using Baseball.Core.Random;
using Baseball.Presentation.Pitch;

namespace Baseball.Platform.InternalQa
{
    /// <summary>Stable internal-only Android intent contract. This type is absent from RC IL.</summary>
    public sealed class InternalQaRequest
    {
        public const string CommandExtra = "baseball.qa.command";
        public const string SeedExtra = "baseball.qa.seed";
        public const string PhaseExtra = "baseball.qa.phase";
        public const string QualityExtra = "baseball.qa.quality";
        public const string DefaultSeed = "20260811";

        private static readonly HashSet<string> Commands = new HashSet<string>(StringComparer.Ordinal)
        {
            "ping",
            "fixture",
            "tutorial-checkpoint",
            "pitch-sample",
            "nonfatal",
            "crash",
            "save-corruption",
            "save-fault",
            "save-failure",
            "analytics-fake"
        };

        private static readonly HashSet<string> Phases = new HashSet<string>(StringComparer.Ordinal)
        {
            "opening",
            "setup",
            "prologue",
            "tutorial_checkpoint"
        };

        private InternalQaRequest(string command, string seed, string phase, PitchQualityTier quality)
        {
            Command = command;
            Seed = seed;
            Phase = phase;
            Quality = quality;
        }

        public string Command { get; }
        public string Seed { get; }
        public string Phase { get; }
        public PitchQualityTier Quality { get; }

        public static bool TryCreate(
            string command,
            string seed,
            string phase,
            string quality,
            out InternalQaRequest request,
            out string errorCode)
        {
            request = null;
            errorCode = null;
            string normalizedCommand = (command ?? string.Empty).Trim().ToLowerInvariant();
            if (!Commands.Contains(normalizedCommand))
            {
                errorCode = "command_not_allowed";
                return false;
            }

            string normalizedSeed = string.IsNullOrWhiteSpace(seed) ? DefaultSeed : seed.Trim();
            if (!ulong.TryParse(normalizedSeed, out _))
            {
                errorCode = "seed_invalid";
                return false;
            }

            string normalizedPhase = string.IsNullOrWhiteSpace(phase)
                ? "prologue"
                : phase.Trim().ToLowerInvariant();
            if (!Phases.Contains(normalizedPhase))
            {
                errorCode = "phase_not_allowed";
                return false;
            }

            string normalizedQuality = string.IsNullOrWhiteSpace(quality)
                ? "high"
                : quality.Trim().ToLowerInvariant();
            PitchQualityTier tier;
            switch (normalizedQuality)
            {
                case "high": tier = PitchQualityTier.High; break;
                case "low": tier = PitchQualityTier.Low; break;
                default:
                    errorCode = "quality_not_allowed";
                    return false;
            }

            if (normalizedCommand == "tutorial-checkpoint") normalizedPhase = "tutorial_checkpoint";
            request = new InternalQaRequest(normalizedCommand, normalizedSeed, normalizedPhase, tier);
            return true;
        }
    }

    public static class InternalQaPitchFixture
    {
        public static PitchPresentationSnapshot Create(string seed)
        {
            ulong presentationSeed = ulong.TryParse(seed, out ulong numeric)
                ? numeric
                : StableHash.Fnv1A64Value(seed ?? string.Empty);
            return new PitchPresentationSnapshot(
                "internal-qa-pitch-" + presentationSeed,
                PitchType.FourSeam,
                0.08d,
                0.12d,
                146.2d,
                0.18d,
                new[]
                {
                    new TrajectoryPoint(0d, 0d, 1.85d, 18.44d),
                    new TrajectoryPoint(0.5d, 0.03d, 1.24d, 9.2d),
                    new TrajectoryPoint(1d, 0.08d, 0.82d, 0d)
                },
                PitchOutcome.Double,
                SwingPresentation.Contact,
                new ContactPresentation(156d, 24d, 12d, 830),
                new FieldingPresentation(
                    FieldingSector.Outfield,
                    PitchOutcome.Double,
                    34d,
                    1.2d,
                    7d,
                    "결정된 내부 QA 외야 타구"),
                new ScoreDelta(0),
                PitchAudioCue.HardContact,
                PitchHapticCue.Contact,
                presentationSeed,
                "내부 QA 우중간 2루타");
        }
    }
}
#endif
