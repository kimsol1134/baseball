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
        public const string PitchExtra = "baseball.qa.pitch";
        public const string DefaultSeed = "20260811";

        private static readonly HashSet<string> Commands = new HashSet<string>(StringComparer.Ordinal)
        {
            "ping",
            "save-inspect",
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
            "school_selection",
            "training",
            "overview",
            "relationship",
            "tutorial_checkpoint"
        };

        private InternalQaRequest(
            string command,
            string seed,
            string phase,
            PitchQualityTier quality,
            PitchType pitchType)
        {
            Command = command;
            Seed = seed;
            Phase = phase;
            Quality = quality;
            PitchType = pitchType;
        }

        public string Command { get; }
        public string Seed { get; }
        public string Phase { get; }
        public PitchQualityTier Quality { get; }
        public PitchType PitchType { get; }

        public static bool TryCreate(
            string command,
            string seed,
            string phase,
            string quality,
            out InternalQaRequest request,
            out string errorCode)
        {
            return TryCreate(command, seed, phase, quality, null, out request, out errorCode);
        }

        public static bool TryCreate(
            string command,
            string seed,
            string phase,
            string quality,
            string pitch,
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

            PitchType pitchType;
            switch ((pitch ?? "four_seam").Trim().ToLowerInvariant())
            {
                case "four_seam": pitchType = PitchType.FourSeam; break;
                case "slider": pitchType = PitchType.Slider; break;
                case "curveball": pitchType = PitchType.Curveball; break;
                case "changeup": pitchType = PitchType.Changeup; break;
                default:
                    errorCode = "pitch_not_allowed";
                    return false;
            }

            if (normalizedCommand == "tutorial-checkpoint") normalizedPhase = "tutorial_checkpoint";
            request = new InternalQaRequest(normalizedCommand, normalizedSeed, normalizedPhase, tier, pitchType);
            return true;
        }
    }

    public static class InternalQaPitchFixture
    {
        public static PitchPresentationSnapshot Create(string seed) => Create(seed, PitchType.FourSeam);

        public static PitchPresentationSnapshot Create(string seed, PitchType pitchType)
        {
            ulong presentationSeed = ulong.TryParse(seed, out ulong numeric)
                ? numeric
                : StableHash.Fnv1A64Value(seed ?? string.Empty);
            IReadOnlyList<TrajectoryPoint> trajectory = Trajectory(pitchType);
            double velocity = pitchType == PitchType.FourSeam ? 146.2d :
                pitchType == PitchType.Slider ? 133.4d :
                pitchType == PitchType.Curveball ? 121.8d : 128.6d;
            return new PitchPresentationSnapshot(
                "internal-qa-pitch-" + pitchType.Value() + "-" + presentationSeed,
                pitchType,
                trajectory[trajectory.Count - 1].XMeters,
                trajectory[trajectory.Count - 1].YMeters,
                velocity,
                0.48d,
                trajectory,
                PitchOutcome.CalledStrike,
                SwingPresentation.Take,
                null,
                null,
                new ScoreDelta(0),
                PitchAudioCue.GloveCatch,
                PitchHapticCue.Catch,
                presentationSeed,
                "내부 QA " + pitchType.Value() + " 궤적");
        }

        private static IReadOnlyList<TrajectoryPoint> Trajectory(PitchType pitchType)
        {
            switch (pitchType)
            {
                case PitchType.Slider:
                    return new[]
                    {
                        Point(0d, 0d, 1.85d, 18.44d), Point(.25d, -.01d, 1.66d, 13.83d),
                        Point(.5d, -.06d, 1.43d, 9.22d), Point(.75d, -.18d, 1.18d, 4.61d),
                        Point(1d, -.38d, .92d, 0d)
                    };
                case PitchType.Curveball:
                    return new[]
                    {
                        Point(0d, 0d, 1.85d, 18.44d), Point(.25d, -.01d, 1.78d, 13.83d),
                        Point(.5d, -.04d, 1.60d, 9.22d), Point(.75d, -.10d, 1.28d, 4.61d),
                        Point(1d, -.18d, .78d, 0d)
                    };
                case PitchType.Changeup:
                    return new[]
                    {
                        Point(0d, 0d, 1.85d, 18.44d), Point(.25d, .01d, 1.68d, 13.83d),
                        Point(.5d, .05d, 1.46d, 9.22d), Point(.75d, .14d, 1.18d, 4.61d),
                        Point(1d, .28d, .86d, 0d)
                    };
                default:
                    return new[]
                    {
                        Point(0d, 0d, 1.85d, 18.44d), Point(.25d, .01d, 1.67d, 13.83d),
                        Point(.5d, .02d, 1.45d, 9.22d), Point(.75d, .04d, 1.20d, 4.61d),
                        Point(1d, .07d, .94d, 0d)
                    };
            }
        }

        private static TrajectoryPoint Point(double t, double x, double y, double z) =>
            new TrajectoryPoint(t, x, y, z);
    }
}
#endif
