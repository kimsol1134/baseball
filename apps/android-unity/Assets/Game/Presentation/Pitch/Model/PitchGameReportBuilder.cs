using System;
using System.Linq;
using Baseball.Application.HighSchool;
using Baseball.Core.Pitching;

namespace Baseball.Presentation.Pitch
{
    /// <summary>Converts only the authoritative Core snapshot into the persisted application report.</summary>
    public static class PitchGameReportBuilder
    {
        public static PitchGameReport Build(string gameId, PitchKernelResult result)
        {
            return BuildPlate(gameId, result);
        }

        public static PitchGameReport BuildPlate(
            string gameId,
            PitchKernelResult result,
            Baseball.Application.Persistence.PitchSessionMetricsState metrics = null)
        {
            if (string.IsNullOrWhiteSpace(gameId)) throw new ArgumentException("A game ID is required.", nameof(gameId));
            if (result?.Snapshot == null) throw new ArgumentNullException(nameof(result));
            if (!result.Snapshot.Ended)
                throw new InvalidOperationException("pitch.authoritative_plate_appearance_incomplete");

            PlateAppearanceResult? plate = result.Snapshot.Result;
            int outs = result.Snapshot.InningTransition?.OutsRecorded ??
                (plate == PlateAppearanceResult.Strikeout || plate == PlateAppearanceResult.InPlayOut ? 1 : 0);
            int strikeouts = plate == PlateAppearanceResult.Strikeout ? 1 : 0;
            int walks = plate == PlateAppearanceResult.Walk ? 1 : 0;
            int hits = plate == PlateAppearanceResult.Hit ? 1 : 0;
            int pitches = Math.Max(1, result.Snapshot.PitchNumber);
            var recentEntries = (result.GameLog?.Entries ?? Array.Empty<PitchAnalysisEntry>())
                .Skip(Math.Max(0, (result.GameLog?.Entries?.Count ?? 0) - pitches))
                .ToArray();
            int accepted = recentEntries.Length > 0
                ? recentEntries.Count(entry => entry.RecommendationAccepted)
                : result.Snapshot.RecommendationAccepted ? 1 : 0;
            metrics = metrics ?? Baseball.Application.Persistence.PitchSessionMetricsState.Empty;
            return new PitchGameReport(
                gameId,
                pitches,
                1,
                outs,
                strikeouts,
                walks,
                hits,
                Math.Max(0, result.Snapshot.RunsScored),
                sequenceMasteryCount: metrics.SequenceMasteryCount,
                expectedDamage: Math.Max(0, recentEntries.Sum(entry => entry.ExpectedDamage)),
                actualDamage: Math.Max(0, recentEntries.Sum(entry => entry.ActualDamage)),
                recommendationAccepted: Math.Min(pitches, Math.Max(0, accepted)),
                directDeliveryCount: metrics.DirectDeliveryCount,
                deliveryScoreTotal: metrics.DeliveryScoreTotal,
                bestDeliveryScore: metrics.BestDeliveryScore,
                perfectDeliveryCount: metrics.PerfectDeliveryCount,
                abilityMomentCount: metrics.AbilityMomentCount,
                abilityMomentTypes: metrics.AbilityMomentTypes);
        }

        public static PitchGameReport Combine(
            string gameId,
            PitchGameReport accumulated,
            PitchGameReport plate)
        {
            if (plate == null) throw new ArgumentNullException(nameof(plate));
            if (!string.Equals(gameId, plate.GameId, StringComparison.Ordinal) ||
                (accumulated != null && !string.Equals(gameId, accumulated.GameId, StringComparison.Ordinal)))
            {
                throw new InvalidOperationException("pitch.report_game_mismatch");
            }
            if (accumulated == null) return plate;
            return new PitchGameReport(
                gameId,
                accumulated.Pitches + plate.Pitches,
                accumulated.Batters + plate.Batters,
                accumulated.Outs + plate.Outs,
                accumulated.Strikeouts + plate.Strikeouts,
                accumulated.Walks + plate.Walks,
                accumulated.Hits + plate.Hits,
                accumulated.RunsAllowed + plate.RunsAllowed,
                accumulated.SequenceMasteryCount + plate.SequenceMasteryCount,
                accumulated.ExpectedDamage + plate.ExpectedDamage,
                accumulated.ActualDamage + plate.ActualDamage,
                accumulated.RecommendationAccepted + plate.RecommendationAccepted,
                accumulated.DirectDeliveryCount + plate.DirectDeliveryCount,
                accumulated.DeliveryScoreTotal + plate.DeliveryScoreTotal,
                Math.Max(accumulated.BestDeliveryScore, plate.BestDeliveryScore),
                accumulated.PerfectDeliveryCount + plate.PerfectDeliveryCount,
                accumulated.RivalStrikeouts + plate.RivalStrikeouts,
                accumulated.AbilityMomentCount + plate.AbilityMomentCount,
                accumulated.AbilityMomentTypes.Concat(plate.AbilityMomentTypes).ToArray());
        }

        /// <summary>Copies authoritative gameplay totals while projecting durable session metrics.</summary>
        public static PitchGameReport WithMetrics(
            PitchGameReport report,
            Baseball.Application.Persistence.PitchSessionMetricsState metrics)
        {
            if (report == null) return null;
            metrics = metrics ?? Baseball.Application.Persistence.PitchSessionMetricsState.Empty;
            return new PitchGameReport(
                report.GameId,
                report.Pitches,
                report.Batters,
                report.Outs,
                report.Strikeouts,
                report.Walks,
                report.Hits,
                report.RunsAllowed,
                metrics.SequenceMasteryCount,
                report.ExpectedDamage,
                report.ActualDamage,
                report.RecommendationAccepted,
                metrics.DirectDeliveryCount,
                metrics.DeliveryScoreTotal,
                metrics.BestDeliveryScore,
                metrics.PerfectDeliveryCount,
                report.RivalStrikeouts,
                metrics.AbilityMomentCount,
                metrics.AbilityMomentTypes);
        }

        public static string CheckpointJson(PitchKernelResult result)
        {
            if (result?.Snapshot == null) throw new ArgumentNullException(nameof(result));
            string hash = (result.EventHash ?? string.Empty).Replace("\\", string.Empty).Replace("\"", string.Empty);
            return "{\"schema\":1,\"eventHash\":\"" + hash + "\",\"pitches\":" +
                Math.Max(1, result.GameLog?.TotalPitches ?? result.Snapshot.PitchNumber) + "}";
        }
    }
}
