using System;
using System.Collections.Generic;
using Baseball.Core.Domain;
using Baseball.Core.Pitching;
using Baseball.Core.Random;

namespace Baseball.Presentation.Pitch
{
    public static class PitchPresentationBuilder
    {
        private const double MoundDistanceMeters = 18.44;

        public static PitchPresentationSnapshot FromResult(
            string plateAppearanceId,
            PitchCall call,
            PitchKernelResult result,
            bool holdsCall = false)
        {
            if (string.IsNullOrWhiteSpace(plateAppearanceId))
            {
                throw new ArgumentException("A stable plate appearance id is required.", nameof(plateAppearanceId));
            }
            if (call == null) throw new ArgumentNullException(nameof(call));
            if (result?.Snapshot?.Execution == null)
            {
                throw new ArgumentException("A committed pitch result with execution data is required.", nameof(result));
            }

            PlateAppearanceSnapshot snapshot = result.Snapshot;
            PitchExecution execution = snapshot.Execution;
            double duration = Math.Max(0.33, Math.Min(0.62, (execution.FlightTimeMilliseconds ?? 470) / 1000.0));
            IReadOnlyList<TrajectoryPoint> trajectory = BuildTrajectory(execution, duration);
            ContactPresentation contact = BuildContact(snapshot.BattedBall);
            FieldingPresentation fielding = BuildFielding(snapshot.FieldingResolution);
            SwingPresentation swing = SwingFor(snapshot.Outcome, contact != null);
            string pitchId = $"{plateAppearanceId}:{snapshot.Revision}:{snapshot.PitchNumber}";
            ulong presentationSeed = StableHash.Fnv1A64Value(result.EventHash + "|presentation-v1");

            return new PitchPresentationSnapshot(
                pitchId,
                call.PitchType,
                execution.ActualX / 500.0,
                execution.ActualY / 500.0,
                execution.VelocityTenthsKph / 10.0,
                duration,
                trajectory,
                snapshot.Outcome,
                swing,
                contact,
                fielding,
                new ScoreDelta(snapshot.RunsScored),
                AudioFor(snapshot.Outcome, contact, snapshot.Ended, snapshot.Result),
                HapticFor(snapshot.Outcome, contact, snapshot.Ended),
                presentationSeed,
                snapshot.AccessibilitySummary,
                call,
                holdsCall);
        }

        private static IReadOnlyList<TrajectoryPoint> BuildTrajectory(PitchExecution execution, double duration)
        {
            IReadOnlyList<int> series = execution.TrajectorySeries;
            if (series != null && series.Count >= 8 && series.Count % 4 == 0)
            {
                var points = new List<TrajectoryPoint>(series.Count / 4);
                int durationMilliseconds = Math.Max(1, execution.FlightTimeMilliseconds ?? series[series.Count - 4]);
                for (int index = 0; index < series.Count; index += 4)
                {
                    points.Add(new TrajectoryPoint(
                        Math.Max(0.0, Math.Min(1.0, series[index] / (double)durationMilliseconds)),
                        series[index + 1] / 1000.0,
                        series[index + 3] / 1000.0,
                        series[index + 2] / 1000.0));
                }
                return points;
            }

            double plateX = execution.ActualX * 0.432 / 500.0;
            double plateY = 0.75 + execution.ActualY * 0.25 / 500.0;
            double controlX = execution.TrajectoryControlX.HasValue
                ? execution.TrajectoryControlX.Value * 0.432 / 500.0
                : plateX - execution.HorizontalBreakTenthsCm / 1000.0;
            double controlY = execution.TrajectoryControlY.HasValue
                ? 0.75 + execution.TrajectoryControlY.Value * 0.25 / 500.0
                : (1.85 + plateY) * 0.5 - execution.VerticalBreakTenthsCm / 1000.0;
            const int sampleCount = 25;
            var fallback = new List<TrajectoryPoint>(sampleCount);
            for (int index = 0; index < sampleCount; index++)
            {
                double t = index / (double)(sampleCount - 1);
                double inverse = 1.0 - t;
                double x = inverse * inverse * 0.0 + 2.0 * inverse * t * controlX + t * t * plateX;
                double y = inverse * inverse * 1.85 + 2.0 * inverse * t * controlY + t * t * plateY;
                double z = MoundDistanceMeters * inverse;
                fallback.Add(new TrajectoryPoint(t, x, y, z));
            }
            return fallback;
        }

        private static ContactPresentation BuildContact(BattedBall ball)
        {
            return ball == null
                ? null
                : new ContactPresentation(
                    ball.ExitVelocityTenthsKph / 10.0,
                    ball.LaunchAngleTenthsDegrees / 10.0,
                    ball.DirectionTenthsDegrees / 10.0,
                    ball.ContactQuality);
        }

        private static FieldingPresentation BuildFielding(FieldingResolutionSnapshot fielding)
        {
            return fielding == null
                ? null
                : new FieldingPresentation(
                    fielding.Sector,
                    fielding.FinalOutcome,
                    (fielding.LandingDistanceTenthsMeters ?? 0) / 10.0,
                    (fielding.HangTimeMilliseconds ?? 0) / 1000.0,
                    (fielding.ApexHeightTenthsMeters ?? 0) / 10.0,
                    fielding.ShortExplanation);
        }

        private static SwingPresentation SwingFor(PitchOutcome outcome, bool hasContact)
        {
            if (hasContact) return SwingPresentation.Contact;
            if (outcome == PitchOutcome.SwingingStrike) return SwingPresentation.Miss;
            if (outcome == PitchOutcome.Foul) return SwingPresentation.Foul;
            return SwingPresentation.Take;
        }

        private static PitchAudioCue AudioFor(
            PitchOutcome outcome,
            ContactPresentation contact,
            bool ended,
            PlateAppearanceResult? result)
        {
            if (contact != null) return contact.ContactQuality >= 700 ? PitchAudioCue.HardContact : PitchAudioCue.WeakContact;
            if (ended && result == PlateAppearanceResult.Strikeout)
                return PitchAudioCue.UmpireStrikeout;
            if (outcome == PitchOutcome.Foul) return PitchAudioCue.Foul;
            if (outcome == PitchOutcome.SwingingStrike) return PitchAudioCue.SwingMiss;
            if (outcome == PitchOutcome.CalledStrike) return PitchAudioCue.UmpireStrike;
            return PitchAudioCue.GloveCatch;
        }

        private static PitchHapticCue HapticFor(PitchOutcome outcome, ContactPresentation contact, bool ended)
        {
            if (ended && (outcome == PitchOutcome.SwingingStrike || outcome == PitchOutcome.CalledStrike))
            {
                return PitchHapticCue.ImportantResult;
            }
            if (contact != null) return PitchHapticCue.Contact;
            if (outcome == PitchOutcome.Foul) return PitchHapticCue.Foul;
            return PitchHapticCue.Catch;
        }
    }
}
