using System;
using System.Collections.Generic;
using System.Linq;
using Baseball.Application.HighSchool;
using Baseball.Core.Domain;
using Baseball.Core.HighSchool;
using Baseball.Core.Pitching;
using Baseball.Core.Pro;
using Baseball.Core.Random;

namespace Baseball.Application.Persistence
{
    /// <summary>
    /// Exact, deterministic inputs for a reserved multi-batter pitch session. Saving this snapshot
    /// prevents Presentation from substituting demo batters or losing the inning situation.
    /// </summary>
    public sealed class PitchScenarioReadModel
    {
        public const int CurrentSchemaVersion = 1;

        public PitchScenarioReadModel(
            int schemaVersion,
            string scenarioId,
            string headline,
            string detail,
            PitcherSnapshot pitcher,
            IReadOnlyList<BatterSnapshot> lineup,
            BatterScoutingSnapshot scouting,
            int catcherTrust,
            GameStateSnapshot gameState,
            int scoreDifferential,
            int leverage,
            int fatigue,
            int maximumBatters,
            int? maximumPitches = null,
            int developmentRulesVersion = 1)
        {
            SchemaVersion = schemaVersion;
            ScenarioId = scenarioId;
            Headline = headline;
            Detail = detail;
            Pitcher = pitcher;
            Lineup = (lineup ?? Array.Empty<BatterSnapshot>()).ToArray();
            Scouting = scouting;
            CatcherTrust = catcherTrust;
            GameState = gameState;
            ScoreDifferential = scoreDifferential;
            Leverage = leverage;
            Fatigue = fatigue;
            MaximumBatters = maximumBatters;
            MaximumPitches = maximumPitches;
            DevelopmentRulesVersion = developmentRulesVersion;
        }

        public int SchemaVersion { get; }
        public string ScenarioId { get; }
        public string Headline { get; }
        public string Detail { get; }
        public PitcherSnapshot Pitcher { get; }
        public IReadOnlyList<BatterSnapshot> Lineup { get; }
        public BatterScoutingSnapshot Scouting { get; }
        public int CatcherTrust { get; }
        public GameStateSnapshot GameState { get; }
        public int ScoreDifferential { get; }
        public int Leverage { get; }
        public int Fatigue { get; }
        public int MaximumBatters { get; }
        public int? MaximumPitches { get; }
        public int DevelopmentRulesVersion { get; }
    }

    /// <summary>
    /// A Core result committed before its animation begins. It remains pending across process death
    /// until Presentation consumes this exact result; the same pitch can never be submitted twice.
    /// </summary>
    public sealed class CommittedPitchResultState
    {
        public CommittedPitchResultState(
            string pitchId,
            int batterIndex,
            string eventHash,
            string kernelResultJson,
            string presentationJson,
            long committedAtUnixMilliseconds,
            PitchSequencePitch sequencePitch = null,
            PitchSequenceTag? sequenceTag = null,
            PitchDeliveryMetricState delivery = null,
            string abilityMomentType = null)
        {
            PitchId = pitchId;
            BatterIndex = batterIndex;
            EventHash = eventHash;
            KernelResultJson = kernelResultJson;
            PresentationJson = presentationJson;
            CommittedAtUnixMilliseconds = committedAtUnixMilliseconds;
            SequencePitch = sequencePitch;
            SequenceTag = sequenceTag;
            Delivery = delivery;
            AbilityMomentType = abilityMomentType;
        }

        public string PitchId { get; }
        public int BatterIndex { get; }
        public string EventHash { get; }
        public string KernelResultJson { get; }
        public string PresentationJson { get; }
        public long CommittedAtUnixMilliseconds { get; }
        public PitchSequencePitch SequencePitch { get; }
        public PitchSequenceTag? SequenceTag { get; }
        public PitchDeliveryMetricState Delivery { get; }
        /// <summary>Stable Core PitchAbilityKind wire value, or null when this pitch has no moment.</summary>
        public string AbilityMomentType { get; }
    }

    /// <summary>Delivery evidence for one committed pitch; automatic release sets WasDirect false.</summary>
    public sealed class PitchDeliveryMetricState
    {
        public PitchDeliveryMetricState(int releaseAccuracy, int aimAccuracy, bool wasDirect)
        {
            ReleaseAccuracy = releaseAccuracy;
            AimAccuracy = aimAccuracy;
            WasDirect = wasDirect;
        }

        public int ReleaseAccuracy { get; }
        public int AimAccuracy { get; }
        public bool WasDirect { get; }
        public int Score => (ReleaseAccuracy + AimAccuracy) / 2;
        public bool IsPerfect => WasDirect && ReleaseAccuracy >= 900 && AimAccuracy >= 900;
    }

    /// <summary>Durable evaluator history and session totals, updated only when a commit is consumed.</summary>
    public sealed class PitchSessionMetricsState
    {
        public PitchSessionMetricsState(
            IReadOnlyList<PitchSequencePitch> recentSequencePitches = null,
            IReadOnlyList<PitchSequenceTag> sequenceMasteryTags = null,
            int directDeliveryCount = 0,
            int deliveryScoreTotal = 0,
            int bestDeliveryScore = 0,
            int perfectDeliveryCount = 0,
            int abilityMomentCount = 0,
            IReadOnlyList<string> abilityMomentTypes = null)
        {
            RecentSequencePitches = (recentSequencePitches ?? Array.Empty<PitchSequencePitch>())
                .TakeLast(3)
                .ToArray();
            SequenceMasteryTags = (sequenceMasteryTags ?? Array.Empty<PitchSequenceTag>()).ToArray();
            DirectDeliveryCount = directDeliveryCount;
            DeliveryScoreTotal = deliveryScoreTotal;
            BestDeliveryScore = bestDeliveryScore;
            PerfectDeliveryCount = perfectDeliveryCount;
            AbilityMomentCount = abilityMomentCount;
            AbilityMomentTypes = (abilityMomentTypes ?? Array.Empty<string>())
                .Distinct(StringComparer.Ordinal)
                .OrderBy(value => value, StringComparer.Ordinal)
                .ToArray();
        }

        public IReadOnlyList<PitchSequencePitch> RecentSequencePitches { get; }
        public IReadOnlyList<PitchSequenceTag> SequenceMasteryTags { get; }
        public int SequenceMasteryCount => SequenceMasteryTags.Count;
        public int DirectDeliveryCount { get; }
        public int DeliveryScoreTotal { get; }
        public int BestDeliveryScore { get; }
        public int PerfectDeliveryCount { get; }
        public int AbilityMomentCount { get; }
        public IReadOnlyList<string> AbilityMomentTypes { get; }
        public int? AverageDeliveryScore => DirectDeliveryCount == 0
            ? (int?)null
            : DeliveryScoreTotal / DirectDeliveryCount;

        public static PitchSessionMetricsState Empty { get; } = new PitchSessionMetricsState();

        public PitchSessionMetricsState Consuming(
            CommittedPitchResultState committed,
            bool plateAppearanceEnded)
        {
            if (committed == null) throw new ArgumentNullException(nameof(committed));
            var recent = RecentSequencePitches;
            if (committed.SequencePitch != null)
            {
                recent = RecentSequencePitches
                    .Concat(new[] { committed.SequencePitch })
                    .TakeLast(3)
                    .ToArray();
            }
            if (plateAppearanceEnded) recent = Array.Empty<PitchSequencePitch>();

            var tags = committed.SequenceTag.HasValue
                ? SequenceMasteryTags.Concat(new[] { committed.SequenceTag.Value }).ToArray()
                : SequenceMasteryTags;
            var direct = committed.Delivery?.WasDirect == true;
            var score = direct ? committed.Delivery.Score : 0;
            var hasAbilityMoment = !string.IsNullOrWhiteSpace(committed.AbilityMomentType);
            var abilityTypes = hasAbilityMoment
                ? AbilityMomentTypes.Concat(new[] { committed.AbilityMomentType }).ToArray()
                : AbilityMomentTypes;
            return new PitchSessionMetricsState(
                recent,
                tags,
                DirectDeliveryCount + (direct ? 1 : 0),
                DeliveryScoreTotal + score,
                direct ? Math.Max(BestDeliveryScore, score) : BestDeliveryScore,
                PerfectDeliveryCount + (committed.Delivery?.IsPerfect == true ? 1 : 0),
                AbilityMomentCount + (hasAbilityMoment ? 1 : 0),
                abilityTypes);
        }
    }

    public static class PitchScenarioFactory
    {
        public static PitchScenarioReadModel Tutorial(HighSchoolCareerSnapshot state)
        {
            if (state == null) throw new ArgumentNullException(nameof(state));
            if (state.Phase != HighSchoolCareerPhase.Prologue)
                throw new InvalidOperationException("pitch.tutorial_not_ready");
            return TutorialScenario(
                state.CareerId,
                state.Pitcher,
                state.BalanceVersion ?? 1);
        }

        public static PitchScenarioReadModel TutorialFallback(
            string careerId,
            PitcherRatingsReadModel ratings,
            string playerName)
        {
            var pitcher = Fallback(
                "tutorial-fallback",
                ratings,
                playerName,
                2).Pitcher;
            return TutorialScenario(careerId, pitcher, 1);
        }

        private static PitchScenarioReadModel TutorialScenario(
            string careerId,
            PitcherSnapshot pitcher,
            int developmentRulesVersion)
        {
            var lineup = new[]
            {
                new BatterSnapshot(
                    "bullpen-batter", "연습 타자", 42, 40, 40),
                new BatterSnapshot(
                    "bullpen-batter-2", "연습 타자 B", 46, 44, 42)
            };
            return new PitchScenarioReadModel(
                PitchScenarioReadModel.CurrentSchemaVersion,
                "hs-bullpen-" + careerId,
                "첫 불펜",
                "기록에 남지 않는 연습 한 타석입니다. 마음껏 던져 보세요.",
                pitcher,
                lineup,
                new BatterScoutingSnapshot(
                    new PitchZone(1, 1),
                    new PitchZone(2, 0),
                    PitchType.FourSeam,
                    PitchType.Curveball,
                    45,
                    100),
                50,
                new GameStateSnapshot(
                    new DefenseSnapshot(44, 42, 45),
                    new ParkSnapshot("bullpen", "학교 불펜", 1000, 1000),
                    BaserunnerStateSnapshot.Empty,
                    0,
                    new InningStateSnapshot(1, HalfInning.Top, 0)),
                0,
                200,
                0,
                2,
                maximumPitches: 8,
                developmentRulesVersion: developmentRulesVersion);
        }

        public static PitchScenarioReadModel HighSchool(HighSchoolCareerSnapshot state)
        {
            if (state == null) throw new ArgumentNullException(nameof(state));
            if (state.Phase != HighSchoolCareerPhase.ImportantGame)
                throw new InvalidOperationException("pitch.high_school_not_ready");
            var content = state.CurrentGameScenario;
            var rival = state.Rival ?? throw new InvalidOperationException("pitch.high_school_rival_missing");
            var scale = DifficultyScale.HighSchool(state.Chapter.Number, state.LifeNumber);
            var first = Scale(new BatterSnapshot(
                rival.Id,
                rival.Name,
                rival.Contact,
                rival.Discipline,
                rival.Power), scale);
            var lineup = new[] { first }.Concat(FollowUpBatters(
                state.CareerId + "|" + state.Performance.ImportantGamesCompleted,
                5,
                scale)).ToArray();
            var catcherTrust = Clamp(state.CatcherTrust ?? state.RelationshipTrust, 0, 100);
            var outs = content?.Outs ?? 0;
            var inning = content?.Inning ?? 5;
            var runners = content?.Runners ?? BaserunnerStateSnapshot.Empty;
            var leverage = content?.Leverage ?? 500;
            var maximum = HighSchoolMaximumBatters(
                outs,
                leverage,
                state.Chapter.Number,
                state.BalanceVersion);
            return new PitchScenarioReadModel(
                PitchScenarioReadModel.CurrentSchemaVersion,
                "hs-" + state.CareerId + "-" + state.Performance.ImportantGamesCompleted,
                content?.Title ?? "고교 공식 경기",
                content?.Narrative ?? "이 이닝을 막아야 합니다.",
                state.Pitcher,
                lineup,
                new BatterScoutingSnapshot(
                    new PitchZone(1, 1),
                    new PitchZone(2, 0),
                    PitchType.FourSeam,
                    PitchType.Slider,
                    50,
                    Clamp(60 + (catcherTrust - 50) / 2, 0, 100)),
                catcherTrust,
                new GameStateSnapshot(
                    Defense(state.School?.Id.ToString()),
                    new ParkSnapshot("hs-park", "고교 구장", 1000, 1000),
                    runners,
                    0,
                    new InningStateSnapshot(inning, HalfInning.Top, outs)),
                content?.ScoreDifferential ?? 1,
                leverage,
                Clamp(state.Fatigue, 0, 100),
                maximum,
                maximumPitches: maximum * 12,
                developmentRulesVersion: state.BalanceVersion ?? 1);
        }

        public static PitchScenarioReadModel Pro(ProCareerSnapshot state)
        {
            if (state == null) throw new ArgumentNullException(nameof(state));
            if (state.Phase != Baseball.Core.Pro.ProCareerPhase.ImportantGame)
                throw new InvalidOperationException("pitch.pro_not_ready");
            var situation = ProSituation.For(state.SeasonTrigger, state.Season, state.Week);
            var scale = DifficultyScale.Pro(state.Season);
            var rival = state.CurrentRival;
            var first = Scale(new BatterSnapshot(
                rival?.Id ?? "pro-rival-" + state.Season,
                rival?.Name ?? "상대 중심 타자",
                54,
                53,
                57), scale);
            var lineup = new[] { first }.Concat(FollowUpBatters(
                state.ProCareerId + "|" + state.Season + "|" + state.Week,
                5,
                scale)).ToArray();
            var catcherTrust = Clamp(state.CatcherTrust, 0, 100);
            return new PitchScenarioReadModel(
                PitchScenarioReadModel.CurrentSchemaVersion,
                "pa-" + state.ProCareerId + "-" + state.Season + "-" + state.Week,
                situation.Headline,
                situation.Detail,
                state.Pitcher,
                lineup,
                new BatterScoutingSnapshot(
                    new PitchZone(1, 1),
                    new PitchZone(2, 0),
                    PitchType.FourSeam,
                    PitchType.Slider,
                    52,
                    Clamp(60 + (catcherTrust - 50) / 2, 0, 100)),
                catcherTrust,
                new GameStateSnapshot(
                    Defense(state.Team.Id),
                    new ParkSnapshot(state.Team.Id, state.Team.Name + " 홈 구장", 1000, 1000),
                    situation.Runners,
                    0,
                    new InningStateSnapshot(situation.Inning, HalfInning.Top, situation.Outs)),
                situation.ScoreDifferential,
                situation.Leverage,
                Clamp(state.Fatigue, 0, 100),
                4,
                maximumPitches: 48,
                developmentRulesVersion: state.BalanceVersion ?? 1);
        }

        public static PitchScenarioReadModel Fallback(
            string scenarioId,
            PitcherRatingsReadModel ratings,
            string playerName,
            int maximumBatters)
        {
            var pitcher = FallbackPitcher();
            if (ratings != null)
            {
                pitcher = new PitcherSnapshot(
                    "fallback-pitcher",
                    playerName ?? "투수",
                    ratings.Stuff,
                    ratings.Command,
                    ratings.Movement,
                    ratings.Stamina,
                    pitcher.PitchProfiles);
            }
            return new PitchScenarioReadModel(
                PitchScenarioReadModel.CurrentSchemaVersion,
                scenarioId,
                "중요 승부",
                "저장된 경기 상황에서 이어 던집니다.",
                pitcher,
                FollowUpBatters(scenarioId, Math.Max(1, maximumBatters), 0),
                new BatterScoutingSnapshot(new PitchZone(1, 1), new PitchZone(2, 0), PitchType.FourSeam, PitchType.Slider, 50),
                50,
                GameStateSnapshot.Standard,
                0,
                500,
                20,
                Math.Max(1, maximumBatters),
                maximumPitches: Math.Max(1, maximumBatters) * 12);
        }

        private static int HighSchoolMaximumBatters(int outs, int leverage, int chapter, int? balanceVersion)
        {
            if ((balanceVersion ?? 1) < 4) return 4;
            if (outs >= 2) return 2;
            if (leverage >= 900 || chapter == 8) return 6;
            return chapter >= 5 ? 5 : 4;
        }

        private static IReadOnlyList<BatterSnapshot> FollowUpBatters(string seedText, int count, int scale)
        {
            var rng = new SplitMix64(StableHash.Fnv1A64Value("lineup|" + seedText));
            var surnames = new[] { "강", "권", "김", "문", "박", "서", "신", "유", "이", "정", "최", "한" };
            var given = new[] { "도현", "민재", "서준", "시우", "지호", "건우", "태윤", "재민", "우진", "석현" };
            var result = new List<BatterSnapshot>();
            for (var index = 0; index < count; index++)
            {
                result.Add(Scale(new BatterSnapshot(
                    "lineup-" + index + "-" + rng.Next(),
                    surnames[rng.NextInt(surnames.Length)] + given[rng.NextInt(given.Length)],
                    45 + rng.NextInt(16),
                    43 + rng.NextInt(16),
                    44 + rng.NextInt(18),
                    rng.NextInt(2) == 0 ? BatSide.Right : BatSide.Left), scale));
            }
            return result;
        }

        private static BatterSnapshot Scale(BatterSnapshot value, int scale)
        {
            return new BatterSnapshot(
                value.Id,
                value.Name,
                Clamp(value.Contact + scale, 20, 80),
                Clamp(value.Discipline + scale, 20, 80),
                Clamp(value.Power + scale, 20, 80),
                value.BatSide);
        }

        private static DefenseSnapshot Defense(string seed)
        {
            var rng = new SplitMix64(StableHash.Fnv1A64Value("defense|" + seed));
            return new DefenseSnapshot(45 + rng.NextInt(16), 45 + rng.NextInt(16), 45 + rng.NextInt(16));
        }

        private static PitcherSnapshot FallbackPitcher()
        {
            return new PitcherSnapshot(
                "fallback-pitcher",
                "투수",
                56,
                56,
                56,
                60,
                new[]
                {
                    Profile(PitchType.FourSeam, PitchUsageRole.Primary, 1430, 56, 56, 48, 52, 50, 2),
                    Profile(PitchType.Slider, PitchUsageRole.Secondary, 1290, 52, 52, 58, 58, 52, 2),
                    Profile(PitchType.Curveball, PitchUsageRole.Secondary, 1170, 50, 50, 60, 56, 54, 2),
                    Profile(PitchType.Changeup, PitchUsageRole.Secondary, 1270, 52, 54, 54, 54, 56, 2)
                });
        }

        private static PitchProfileSnapshot Profile(
            PitchType type,
            PitchUsageRole role,
            int velocity,
            int control,
            int command,
            int movement,
            int whiff,
            int weakContact,
            int fatigueCost)
        {
            return new PitchProfileSnapshot(type, role, velocity, control, command, movement, whiff, weakContact, fatigueCost);
        }

        private static int Clamp(int value, int minimum, int maximum) =>
            Math.Min(maximum, Math.Max(minimum, value));

        private sealed class ProSituation
        {
            private ProSituation(int inning, int outs, BaserunnerStateSnapshot runners, int scoreDifferential, int leverage, string headline, string detail)
            { Inning=inning;Outs=outs;Runners=runners;ScoreDifferential=scoreDifferential;Leverage=leverage;Headline=headline;Detail=detail; }
            public int Inning { get; }
            public int Outs { get; }
            public BaserunnerStateSnapshot Runners { get; }
            public int ScoreDifferential { get; }
            public int Leverage { get; }
            public string Headline { get; }
            public string Detail { get; }

            public static ProSituation For(ProSeasonTrigger? trigger, int season, int week)
            {
                var second = new BaserunnerStateSnapshot(false, true, false, 52);
                var first = new BaserunnerStateSnapshot(true, false, false, 54);
                var corners = new BaserunnerStateSnapshot(true, true, false, 56);
                var leading = (season + week) % 2 == 0;
                switch (trigger)
                {
                    case ProSeasonTrigger.MajorDebut: return new ProSituation(6, 0, second, 0, 780, "1군 데뷔 등판", "동점 · 무사 2루");
                    case ProSeasonTrigger.CallUpAudition: return new ProSituation(7, 0, second, -1, 820, "콜업을 결정할 등판", "한 점 뒤짐 · 무사 2루");
                    case ProSeasonTrigger.RoleShowdown: return new ProSituation(8, 0, first, 1, 900, "보직을 가를 등판", "한 점 앞섬 · 무사 1루");
                    case ProSeasonTrigger.RecordChase: return new ProSituation(7, 0, first, leading ? 2 : -2, 700, "기록이 걸린 등판", leading ? "두 점 앞섬 · 무사 1루" : "두 점 뒤짐 · 무사 1루");
                    case ProSeasonTrigger.StandingsRace: return new ProSituation(9, 0, corners, leading ? 1 : -1, 950, "순위 싸움의 마지막 이닝", leading ? "한 점 앞섬 · 무사 1·2루" : "한 점 뒤짐 · 무사 1·2루");
                    default: return new ProSituation(5, 0, second, 1, 720, "시즌 첫 승부처", "한 점 앞섬 · 무사 2루");
                }
            }
        }
    }
}
