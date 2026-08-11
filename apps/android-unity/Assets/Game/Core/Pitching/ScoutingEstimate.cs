using System;
using System.Collections.Generic;
using Baseball.Core.Domain;
using Baseball.Core.Random;

namespace Baseball.Core.Pitching
{
    public static class ScoutingEstimate
    {
        public const int TrustedReliability = 60;
        private const int ObservationPitchGain = 5;
        private const int ObservationRematchGain = 12;
        private const int ObservationBonusCap = 100;
        private const int ConfidencePenaltyPerPoint = 6;
        private const int ConfidenceFloor = 180;
        private const int ChaseUncertaintyScale = 12;
        private const int DevelopingReliability = 40;

        public static int EffectiveReliability(int baseline, RivalMemorySnapshot memory)
        {
            var pitchesSeen = memory == null ? 0 : memory.TotalPitchesSeen;
            var rematches = memory == null ? 0 : memory.PlateAppearancesSeen;
            var bonus = Math.Min(ObservationBonusCap,
                pitchesSeen * ObservationPitchGain + rematches * ObservationRematchGain);
            return Clamp(baseline + bonus, 0, 100);
        }

        public static int ConfidencePenalty(int reliability) =>
            Math.Max(0, TrustedReliability - reliability) * ConfidencePenaltyPerPoint;

        public static int AdjustedConfidence(int raw, int reliability) =>
            Math.Min(raw, Math.Max(ConfidenceFloor, raw - ConfidencePenalty(reliability)));

        public static ulong MatchupSeed(string pitcherId, string batterId) =>
            StableHash.Fnv1A64Value(pitcherId + "|" + batterId + "|scouting");

        public static BatterScoutingSnapshot EstimatedScouting(
            BatterScoutingSnapshot truth,
            int reliability,
            ulong matchupSeed)
        {
            if (reliability >= TrustedReliability) return truth;
            var generator = new SplitMix64(matchupSeed);
            var weaknessThreshold = 30 + generator.NextInt(29);
            var coldZoneThreshold = 24 + generator.NextInt(35);
            var hotZoneThreshold = 24 + generator.NextInt(35);
            var decoyWeakness = PitchDecoy(truth.PitchWeakness, ref generator);
            var decoyColdZone = ZoneDecoy(truth.ColdZone, ref generator);
            var decoyHotZone = ZoneDecoy(truth.HotZone, ref generator);
            var chaseMagnitude = 6 + generator.NextInt(9);
            var chaseOffset = generator.NextInt(2) == 0 ? -chaseMagnitude : chaseMagnitude;
            var gap = Math.Max(0, TrustedReliability - reliability);
            return new BatterScoutingSnapshot(
                reliability >= hotZoneThreshold ? truth.HotZone : decoyHotZone,
                reliability >= coldZoneThreshold ? truth.ColdZone : decoyColdZone,
                truth.PitchStrength,
                reliability >= weaknessThreshold ? truth.PitchWeakness : decoyWeakness,
                Clamp(truth.ChaseTendency + chaseOffset * gap / TrustedReliability, 20, 80),
                reliability);
        }

        public static ScoutingReportSnapshot Report(
            BatterScoutingSnapshot estimate,
            int effectiveReliability,
            int observationCount)
        {
            var band = effectiveReliability >= TrustedReliability
                ? "trusted"
                : effectiveReliability >= DevelopingReliability ? "developing" : "low";
            var margin = Math.Max(0, TrustedReliability - effectiveReliability) *
                         ChaseUncertaintyScale / TrustedReliability;
            return new ScoutingReportSnapshot(
                effectiveReliability,
                observationCount,
                band,
                estimate.PitchWeakness,
                estimate.ColdZone,
                estimate.PitchStrength,
                estimate.HotZone,
                estimate.ChaseTendency,
                margin);
        }

        private static PitchType PitchDecoy(PitchType truth, ref SplitMix64 generator)
        {
            var options = new List<PitchType>(3);
            foreach (var type in DomainWire.PitchTypes)
            {
                if (type != truth) options.Add(type);
            }

            return options[generator.NextInt(options.Count)];
        }

        private static PitchZone ZoneDecoy(PitchZone truth, ref SplitMix64 generator)
        {
            var candidates = new List<PitchZone>(8);
            for (var deltaRow = -1; deltaRow <= 1; deltaRow++)
            {
                for (var deltaColumn = -1; deltaColumn <= 1; deltaColumn++)
                {
                    if (deltaRow == 0 && deltaColumn == 0) continue;
                    var row = truth.Row + deltaRow;
                    var column = truth.Column + deltaColumn;
                    if (row >= 0 && row <= 2 && column >= 0 && column <= 2)
                    {
                        candidates.Add(new PitchZone(row, column));
                    }
                }
            }

            return candidates[generator.NextInt(candidates.Count)];
        }

        private static int Clamp(int value, int lower, int upper) => Math.Min(Math.Max(value, lower), upper);
    }
}
