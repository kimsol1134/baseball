using System;
using System.Collections.Generic;
using System.Linq;
using Baseball.Core.Domain;

namespace Baseball.Core.Pitching
{
    public enum RivalAdaptationBand { NoData, Watching, Learning, LockedOn }

    public sealed class RivalPitchObservation
    {
        public RivalPitchObservation(
            PitchType pitchType, PitchZone zone, ZoneIntent zoneIntent,
            int balls, int strikes, PitchOutcome outcome)
        {
            PitchType = pitchType;
            Zone = zone;
            ZoneIntent = zoneIntent;
            Balls = balls;
            Strikes = strikes;
            Outcome = outcome;
        }

        public PitchType PitchType { get; }
        public PitchZone Zone { get; }
        public ZoneIntent ZoneIntent { get; }
        public int Balls { get; }
        public int Strikes { get; }
        public PitchOutcome Outcome { get; }
    }

    public sealed class RivalMemorySnapshot
    {
        public RivalMemorySnapshot(
            string matchupId, ulong revision, int plateAppearancesSeen,
            int totalPitchesSeen, IReadOnlyList<RivalPitchObservation> recentObservations)
        {
            MatchupId = matchupId;
            Revision = revision;
            PlateAppearancesSeen = plateAppearancesSeen;
            TotalPitchesSeen = totalPitchesSeen;
            RecentObservations = recentObservations;
        }

        public string MatchupId { get; }
        public ulong Revision { get; }
        public int PlateAppearancesSeen { get; }
        public int TotalPitchesSeen { get; }
        public IReadOnlyList<RivalPitchObservation> RecentObservations { get; }
    }

    public sealed class RivalAdaptationSnapshot
    {
        public RivalAdaptationSnapshot(
            int level, RivalAdaptationBand band, int evidenceCount,
            PitchType? detectedPitch, PitchZone? detectedZone,
            PitchType leanPitch, PitchZone leanZone,
            int pitchReadStrength, int zoneReadStrength, int confidence, string warning)
        {
            Level = level;
            Band = band;
            EvidenceCount = evidenceCount;
            DetectedPitch = detectedPitch;
            DetectedZone = detectedZone;
            LeanPitch = leanPitch;
            LeanZone = leanZone;
            PitchReadStrength = pitchReadStrength;
            ZoneReadStrength = zoneReadStrength;
            Confidence = confidence;
            Warning = warning;
        }

        public int Level { get; }
        public RivalAdaptationBand Band { get; }
        public int EvidenceCount { get; }
        public PitchType? DetectedPitch { get; }
        public PitchZone? DetectedZone { get; }
        public PitchType LeanPitch { get; }
        public PitchZone LeanZone { get; }
        public int PitchReadStrength { get; }
        public int ZoneReadStrength { get; }
        public int Confidence { get; }
        public string Warning { get; }
    }

    public sealed class RivalMemoryEngine
    {
        public const int MaximumObservations = 24;
        internal const int ResolveDamageCap = 420;
        private const int ReadSampleFloor = 3;
        private const int ReadSampleSaturation = 18;
        private const int PitchReadBaseline = 260;
        private const int ZoneReadBaseline = 150;
        private const int PitchFamiliarityFloor = 60;
        private const int ZoneFamiliarityFloor = 40;
        private const int PitchReadCap = 300;
        private const int ZoneReadCap = 250;

        public RivalMemorySnapshot EmptyMemory(PitcherSnapshot pitcher, BatterSnapshot batter)
        {
            return new RivalMemorySnapshot(pitcher.Id + ":" + batter.Id, 0, 0, 0,
                Array.Empty<RivalPitchObservation>());
        }

        public RivalMemorySnapshot BenchMemory(PitcherSnapshot pitcher, string benchId)
        {
            return new RivalMemorySnapshot(BenchMatchupId(pitcher.Id, benchId), 0, 0, 0,
                Array.Empty<RivalPitchObservation>());
        }

        public static string BenchMatchupId(string pitcherId, string benchId) =>
            pitcherId + ":bench:" + benchId;

        public void Validate(RivalMemorySnapshot memory, PitcherSnapshot pitcher, BatterSnapshot batter)
        {
            if (memory == null) return;
            var direct = pitcher.Id + ":" + batter.Id;
            var benchPrefix = pitcher.Id + ":bench:";
            if (memory.MatchupId != direct && !memory.MatchupId.StartsWith(benchPrefix, StringComparison.Ordinal))
            {
                throw new SimulationException(SimulationErrorCode.InvalidRivalMemory,
                    "matchupID does not match pitcher and batter");
            }

            if (memory.PlateAppearancesSeen < 0 ||
                memory.TotalPitchesSeen < memory.RecentObservations.Count ||
                memory.RecentObservations.Count > MaximumObservations)
            {
                throw new SimulationException(SimulationErrorCode.InvalidRivalMemory,
                    "counters or observation count are invalid");
            }

            foreach (var observation in memory.RecentObservations)
            {
                if (observation.Zone.Row < 0 || observation.Zone.Row > 2 ||
                    observation.Zone.Column < 0 || observation.Zone.Column > 2 ||
                    observation.Balls < 0 || observation.Balls > 3 ||
                    observation.Strikes < 0 || observation.Strikes > 2)
                {
                    throw new SimulationException(SimulationErrorCode.InvalidRivalMemory,
                        "an observation is outside the valid range");
                }
            }
        }

        public RivalAdaptationSnapshot Analyze(RivalMemorySnapshot memory, PlateAppearanceContext context)
        {
            if (memory == null || memory.RecentObservations.Count == 0)
            {
                return new RivalAdaptationSnapshot(
                    0, RivalAdaptationBand.NoData, 0, null, null,
                    PitchType.FourSeam, new PitchZone(1, 1), 0, 0, 0,
                    "아직 이 투수의 공을 충분히 보지 못했습니다.");
            }

            var matching = memory.RecentObservations.Where(observation =>
                (observation.Strikes == 2) == (context.Strikes == 2) &&
                (observation.Balls == 3) == (context.Balls == 3)).ToList();
            var evidence = matching.Count >= 3 ? matching : memory.RecentObservations.ToList();
            var effectiveCount = Math.Max(1, evidence.Sum(ObservationWeight) / 2);
            var topPitch = MostFrequentPitch(evidence);
            var topZone = MostFrequentZone(evidence);
            var pitchShare = topPitch.Count * 1000 / evidence.Count;
            var zoneShare = topZone.Count * 1000 / evidence.Count;
            var sampleSignal = Math.Max(0, effectiveCount - 2) * 15;
            var pitchSignal = Math.Max(0, pitchShare - 400) / 2;
            var zoneSignal = Math.Max(0, zoneShare - 350) / 4;
            var rematchSignal = Math.Min(memory.PlateAppearancesSeen * 80, 240);
            var level = Math.Min(900, sampleSignal + pitchSignal + zoneSignal + rematchSignal);
            if (memory.PlateAppearancesSeen == 0) level = Math.Min(level, 420);

            var sampleWeight = Math.Min(effectiveCount, ReadSampleSaturation);
            var patternSample = Math.Max(0, sampleWeight - ReadSampleFloor);
            var patternSpan = ReadSampleSaturation - ReadSampleFloor;
            var pitchExcess = Math.Max(0, pitchShare - PitchReadBaseline);
            var zoneExcess = Math.Max(0, zoneShare - ZoneReadBaseline);
            var pitchReadStrength = Math.Min(PitchReadCap,
                pitchExcess * patternSample / patternSpan +
                patternSample * PitchFamiliarityFloor / patternSpan);
            var zoneReadStrength = Math.Min(ZoneReadCap,
                zoneExcess * patternSample / patternSpan +
                patternSample * ZoneFamiliarityFloor / patternSpan);
            PitchType? detectedPitch = evidence.Count >= 4 && pitchShare >= 500 ? topPitch.Type : (PitchType?)null;
            PitchZone? detectedZone = evidence.Count >= 4 && zoneShare >= 500 ? topZone.Zone : (PitchZone?)null;
            var confidence = Math.Min(950, evidence.Count * 28 + Math.Max(pitchShare, zoneShare) / 2);
            var band = level == 0 ? RivalAdaptationBand.NoData :
                level < 250 ? RivalAdaptationBand.Watching :
                level < 600 ? RivalAdaptationBand.Learning : RivalAdaptationBand.LockedOn;

            string warning;
            if (detectedPitch.HasValue && detectedZone.HasValue)
            {
                warning = PitchName(detectedPitch.Value) + "과 " + ZoneName(detectedZone.Value) +
                          " 반복을 함께 읽고 있습니다.";
            }
            else if (detectedPitch.HasValue)
            {
                warning = PitchName(detectedPitch.Value) + " 사용 비중이 읽히기 시작했습니다.";
            }
            else if (detectedZone.HasValue)
            {
                warning = ZoneName(detectedZone.Value) + " 코스 반복이 읽히기 시작했습니다.";
            }
            else
            {
                warning = "아직 확정적인 패턴은 없지만 투구 기록을 쌓고 있습니다.";
            }

            return new RivalAdaptationSnapshot(
                level, band, evidence.Count, detectedPitch, detectedZone,
                topPitch.Type, topZone.Zone, pitchReadStrength, zoneReadStrength,
                confidence, warning);
        }

        public RivalMemorySnapshot Record(
            RivalMemorySnapshot memory,
            PitcherSnapshot pitcher,
            BatterSnapshot batter,
            PlateAppearanceContext context,
            PitchCall call,
            PitchOutcome outcome,
            bool plateAppearanceEnded)
        {
            var current = memory ?? EmptyMemory(pitcher, batter);
            var observations = current.RecentObservations.Concat(new[]
            {
                new RivalPitchObservation(call.PitchType, call.Zone, call.ZoneIntent,
                    context.Balls, context.Strikes, outcome)
            }).ToList();
            if (observations.Count > MaximumObservations)
            {
                observations = observations.Skip(observations.Count - MaximumObservations).ToList();
            }

            return new RivalMemorySnapshot(
                current.MatchupId,
                unchecked(current.Revision + 1),
                current.PlateAppearancesSeen + (plateAppearanceEnded ? 1 : 0),
                current.TotalPitchesSeen + 1,
                observations);
        }

        private static int ObservationWeight(RivalPitchObservation observation)
        {
            switch (observation.Outcome)
            {
                case PitchOutcome.Single:
                case PitchOutcome.Double:
                case PitchOutcome.Triple:
                case PitchOutcome.HomeRun: return 6;
                case PitchOutcome.Foul:
                case PitchOutcome.InPlayOut: return 4;
                case PitchOutcome.Ball:
                case PitchOutcome.CalledStrike:
                case PitchOutcome.HitByPitch: return 2;
                case PitchOutcome.SwingingStrike: return 1;
                default: return 2;
            }
        }

        private static (PitchType Type, int Count) MostFrequentPitch(IReadOnlyList<RivalPitchObservation> observations)
        {
            var bestType = PitchType.FourSeam;
            var bestCount = -1;
            var totalWeight = Math.Max(1, observations.Sum(ObservationWeight));
            foreach (var pitchType in DomainWire.PitchTypes)
            {
                var weight = observations.Where(item => item.PitchType == pitchType).Sum(ObservationWeight);
                var count = weight * observations.Count / totalWeight;
                if (count > bestCount)
                {
                    bestType = pitchType;
                    bestCount = count;
                }
            }

            return (bestType, bestCount);
        }

        private static (PitchZone Zone, int Count) MostFrequentZone(IReadOnlyList<RivalPitchObservation> observations)
        {
            var bestZone = new PitchZone(0, 0);
            var bestCount = -1;
            var totalWeight = Math.Max(1, observations.Sum(ObservationWeight));
            for (var index = 0; index < 9; index++)
            {
                var zone = new PitchZone(index / 3, index % 3);
                var weight = observations.Where(item => item.Zone == zone).Sum(ObservationWeight);
                var count = weight * observations.Count / totalWeight;
                if (count > bestCount)
                {
                    bestZone = zone;
                    bestCount = count;
                }
            }

            return (bestZone, bestCount);
        }

        private static string PitchName(PitchType type)
        {
            switch (type)
            {
                case PitchType.FourSeam: return "포심";
                case PitchType.Slider: return "슬라이더";
                case PitchType.Curveball: return "커브";
                case PitchType.Changeup: return "체인지업";
                default: return string.Empty;
            }
        }

        private static string ZoneName(PitchZone zone)
        {
            var vertical = new[] { "높은", "가운데", "낮은" }[zone.Row];
            var horizontal = new[] { "몸쪽", "가운데", "바깥쪽" }[zone.Column];
            return vertical == "가운데" && horizontal == "가운데"
                ? "가운데"
                : vertical + " " + horizontal;
        }
    }
}
