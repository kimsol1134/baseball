using System;
using System.Collections.Generic;
using Baseball.Core.Domain;
using Baseball.Core.Pitching;

namespace Baseball.Presentation.Pitch
{
    public enum SwingPresentation
    {
        Take,
        Miss,
        Foul,
        Contact
    }

    public enum PitchAudioCue
    {
        GloveCatch,
        SwingMiss,
        UmpireStrike,
        UmpireStrikeout,
        Foul,
        WeakContact,
        HardContact
    }

    public enum PitchHapticCue
    {
        None,
        Release,
        Catch,
        Foul,
        Contact,
        ImportantResult
    }

    public readonly struct TrajectoryPoint
    {
        public TrajectoryPoint(double normalizedTime, double xMeters, double yMeters, double zMeters)
        {
            NormalizedTime = normalizedTime;
            XMeters = xMeters;
            YMeters = yMeters;
            ZMeters = zMeters;
        }

        public double NormalizedTime { get; }
        public double XMeters { get; }
        public double YMeters { get; }
        public double ZMeters { get; }
    }

    public sealed class ContactPresentation
    {
        public ContactPresentation(
            double exitVelocityKph,
            double launchAngleDegrees,
            double directionDegrees,
            int contactQuality)
        {
            ExitVelocityKph = exitVelocityKph;
            LaunchAngleDegrees = launchAngleDegrees;
            DirectionDegrees = directionDegrees;
            ContactQuality = contactQuality;
        }

        public double ExitVelocityKph { get; }
        public double LaunchAngleDegrees { get; }
        public double DirectionDegrees { get; }
        public int ContactQuality { get; }
    }

    public sealed class FieldingPresentation
    {
        public FieldingPresentation(
            FieldingSector sector,
            PitchOutcome finalOutcome,
            double landingDistanceMeters,
            double hangTimeSeconds,
            double apexHeightMeters,
            string explanation)
        {
            Sector = sector;
            FinalOutcome = finalOutcome;
            LandingDistanceMeters = landingDistanceMeters;
            HangTimeSeconds = hangTimeSeconds;
            ApexHeightMeters = apexHeightMeters;
            Explanation = explanation;
        }

        public FieldingSector Sector { get; }
        public PitchOutcome FinalOutcome { get; }
        public double LandingDistanceMeters { get; }
        public double HangTimeSeconds { get; }
        public double ApexHeightMeters { get; }
        public string Explanation { get; }
    }

    public readonly struct ScoreDelta
    {
        public ScoreDelta(int runsAllowed)
        {
            RunsAllowed = runsAllowed;
        }

        public int RunsAllowed { get; }
    }

    /// <summary>
    /// Immutable visual contract made only after the authoritative pitch result is committed.
    /// Presentation code may never mutate or re-resolve these values.
    /// </summary>
    public sealed class PitchPresentationSnapshot
    {
        public PitchPresentationSnapshot(
            string pitchId,
            PitchType pitchType,
            double actualPlateX,
            double actualPlateY,
            double velocityKph,
            double flightDurationSeconds,
            IReadOnlyList<TrajectoryPoint> trajectory,
            PitchOutcome call,
            SwingPresentation swing,
            ContactPresentation contact,
            FieldingPresentation fielding,
            ScoreDelta scoreDelta,
            PitchAudioCue audioCue,
            PitchHapticCue hapticCue,
            ulong presentationSeed,
            string accessibilitySummary,
            PitchCall selectedCall = null,
            bool holdsCall = false)
        {
            PitchId = pitchId ?? throw new ArgumentNullException(nameof(pitchId));
            PitchType = pitchType;
            ActualPlateX = actualPlateX;
            ActualPlateY = actualPlateY;
            VelocityKph = velocityKph;
            FlightDurationSeconds = flightDurationSeconds;
            Trajectory = trajectory ?? throw new ArgumentNullException(nameof(trajectory));
            Call = call;
            Swing = swing;
            Contact = contact;
            Fielding = fielding;
            ScoreDelta = scoreDelta;
            AudioCue = audioCue;
            HapticCue = hapticCue;
            PresentationSeed = presentationSeed;
            AccessibilitySummary = accessibilitySummary ?? string.Empty;
            SelectedCall = selectedCall;
            HoldsCall = selectedCall != null && holdsCall;
        }

        public string PitchId { get; }
        public PitchType PitchType { get; }
        public double ActualPlateX { get; }
        public double ActualPlateY { get; }
        public double VelocityKph { get; }
        public double FlightDurationSeconds { get; }
        public IReadOnlyList<TrajectoryPoint> Trajectory { get; }
        public PitchOutcome Call { get; }
        public SwingPresentation Swing { get; }
        public ContactPresentation Contact { get; }
        public FieldingPresentation Fielding { get; }
        public ScoreDelta ScoreDelta { get; }
        public PitchAudioCue AudioCue { get; }
        public PitchHapticCue HapticCue { get; }
        public ulong PresentationSeed { get; }
        public string AccessibilitySummary { get; }
        /// <summary>Durable UI selection only; it never changes the already committed result.</summary>
        public PitchCall SelectedCall { get; }
        public bool HoldsCall { get; }
    }
}
