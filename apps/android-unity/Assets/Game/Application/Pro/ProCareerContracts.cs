using System;
using System.Collections.Generic;
using System.Linq;
using Baseball.Application.Commands;
using Baseball.Application.Persistence;
using Baseball.Application.HighSchool;

namespace Baseball.Application.Pro
{
    public enum ProCareerOrigin
    {
        HighSchool,
        Direct
    }

    public enum ProCareerPhase
    {
        ContractOffer,
        WeeklyPlan,
        SeasonDecision,
        ImportantGame,
        SeasonReview,
        Offseason,
        RetirementDecision,
        Completed
    }

    public sealed class ProContractOfferReadModel
    {
        public ProContractOfferReadModel(
            string teamId,
            string teamName,
            string role,
            int years,
            int annualSalary)
        {
            TeamId = teamId;
            TeamName = teamName;
            Role = role;
            Years = years;
            AnnualSalary = annualSalary;
        }

        public string TeamId { get; }
        public string TeamName { get; }
        public string Role { get; }
        public int Years { get; }
        public int AnnualSalary { get; }
    }

    public static class ProWeekActionPayload
    {
        public const string AdvanceWeekAction = "advance_week";
        public const string AdvanceSegmentAction = "advance_segment";

        public static string Encode(string planId, string targetPitchId = null)
        {
            if (string.IsNullOrWhiteSpace(planId))
                throw new ArgumentException("A plan ID is required.", nameof(planId));
            return string.IsNullOrWhiteSpace(targetPitchId)
                ? planId
                : planId + "|" + targetPitchId;
        }
    }

    public sealed class ProDevelopmentProgressReadModel
    {
        public ProDevelopmentProgressReadModel(int stuff = 0, int command = 0, int movement = 0, int stamina = 0)
        {
            Stuff = Math.Max(0, Math.Min(1, stuff));
            Command = Math.Max(0, Math.Min(1, command));
            Movement = Math.Max(0, Math.Min(1, movement));
            Stamina = Math.Max(0, Math.Min(1, stamina));
        }

        public int Stuff { get; }
        public int Command { get; }
        public int Movement { get; }
        public int Stamina { get; }

        public int Value(string planId)
        {
            switch (planId)
            {
                case "develop_stuff": return Stuff;
                case "refine_command": return Command;
                case "develop_movement": return Movement;
                case "build_stamina": return Stamina;
                case "develop_weapon": return Math.Min(Stuff, Movement);
                default: return 0;
            }
        }
    }

    public sealed class ProSegmentProgressReadModel
    {
        public ProSegmentProgressReadModel(
            int advancedWeeks,
            string startingSegment,
            string endingSegment,
            string stopReason,
            string plan,
            string targetPitch = null)
        {
            AdvancedWeeks = advancedWeeks;
            StartingSegment = startingSegment;
            EndingSegment = endingSegment;
            StopReason = stopReason;
            Plan = plan;
            TargetPitch = targetPitch;
        }

        public int AdvancedWeeks { get; }
        public string StartingSegment { get; }
        public string EndingSegment { get; }
        public string StopReason { get; }
        public string Plan { get; }
        public string TargetPitch { get; }
    }

    public sealed class ProSeasonLineReadModel
    {
        public ProSeasonLineReadModel(
            int season,
            string teamId,
            int games,
            int inningsOuts,
            int strikeouts,
            int walks,
            int runsAllowed,
            int awards = 0,
            int wins = 0,
            int losses = 0,
            int saves = 0,
            int? starts = null,
            int? hits = null,
            int? homeRuns = null,
            int? pitches = null,
            int? qualityStarts = null)
        {
            Season = season;
            TeamId = teamId;
            Games = games;
            InningsOuts = inningsOuts;
            Strikeouts = strikeouts;
            Walks = walks;
            RunsAllowed = runsAllowed;
            Awards = awards;
            Wins = wins;
            Losses = losses;
            Saves = saves;
            Starts = starts;
            Hits = hits;
            HomeRuns = homeRuns;
            Pitches = pitches;
            QualityStarts = qualityStarts;
        }

        public int Season { get; }
        public string TeamId { get; }
        public int Games { get; }
        public int InningsOuts { get; }
        public int Strikeouts { get; }
        public int Walks { get; }
        public int RunsAllowed { get; }
        public int Awards { get; }
        public int Wins { get; }
        public int Losses { get; }
        public int Saves { get; }
        public int? Starts { get; }
        public int? Hits { get; }
        public int? HomeRuns { get; }
        public int? Pitches { get; }
        public int? QualityStarts { get; }

        public PitchingRecordReadModel PitchingRecord => new PitchingRecordReadModel(
            Games,
            Starts ?? 0,
            InningsOuts,
            Strikeouts,
            Walks,
            RunsAllowed,
            Wins,
            Losses,
            Saves,
            Hits,
            HomeRuns,
            Pitches,
            QualityStarts);
    }

    public sealed class ProDecisionHistoryReadModel
    {
        public ProDecisionHistoryReadModel(
            string decisionId,
            string typeId,
            int season,
            int week,
            string choiceId,
            string choiceTitle,
            string effectSummary,
            int stuffDelta = 0,
            int commandDelta = 0,
            int movementDelta = 0,
            int staminaDelta = 0,
            int managerTrustDelta = 0,
            int catcherTrustDelta = 0,
            int fatigueDelta = 0,
            string roleTarget = null)
        {
            DecisionId = decisionId;
            TypeId = typeId;
            Season = season;
            Week = week;
            ChoiceId = choiceId;
            ChoiceTitle = choiceTitle;
            EffectSummary = effectSummary;
            StuffDelta = stuffDelta;
            CommandDelta = commandDelta;
            MovementDelta = movementDelta;
            StaminaDelta = staminaDelta;
            ManagerTrustDelta = managerTrustDelta;
            CatcherTrustDelta = catcherTrustDelta;
            FatigueDelta = fatigueDelta;
            RoleTarget = roleTarget;
        }

        public string DecisionId { get; }
        public string TypeId { get; }
        public int Season { get; }
        public int Week { get; }
        public string ChoiceId { get; }
        public string ChoiceTitle { get; }
        public string EffectSummary { get; }
        public int StuffDelta { get; }
        public int CommandDelta { get; }
        public int MovementDelta { get; }
        public int StaminaDelta { get; }
        public int ManagerTrustDelta { get; }
        public int CatcherTrustDelta { get; }
        public int FatigueDelta { get; }
        public string RoleTarget { get; }
    }

    /// <summary>
    /// Frozen, save-backed record surface for Record/League screens. A null record book on an
    /// older Application save means the projection has not yet been refreshed from Core; fields
    /// inside the book use null for individual source statistics that were never recorded.
    /// </summary>
    public sealed class ProRecordBookReadModel
    {
        public ProRecordBookReadModel(
            PitchingRecordReadModel currentSeason,
            IReadOnlyList<CareerGameLineReadModel> seasonGameLines,
            IReadOnlyList<ProSeasonLineReadModel> careerSeasons,
            IReadOnlyList<string> awardNames,
            IReadOnlyList<string> milestones,
            IReadOnlyList<ProDecisionHistoryReadModel> decisionHistory,
            int? hallOfFameScore = null,
            bool seasonGameLinesAvailable = false)
        {
            CurrentSeason = currentSeason;
            SeasonGameLines = (seasonGameLines ?? Array.Empty<CareerGameLineReadModel>()).ToArray();
            CareerSeasons = (careerSeasons ?? Array.Empty<ProSeasonLineReadModel>()).ToArray();
            AwardNames = (awardNames ?? Array.Empty<string>()).ToArray();
            Milestones = (milestones ?? Array.Empty<string>()).ToArray();
            DecisionHistory = (decisionHistory ?? Array.Empty<ProDecisionHistoryReadModel>()).ToArray();
            HallOfFameScore = hallOfFameScore;
            SeasonGameLinesAvailable = seasonGameLinesAvailable;
        }

        public PitchingRecordReadModel CurrentSeason { get; }
        public IReadOnlyList<CareerGameLineReadModel> SeasonGameLines { get; }
        public IReadOnlyList<ProSeasonLineReadModel> CareerSeasons { get; }
        public IReadOnlyList<string> AwardNames { get; }
        public IReadOnlyList<string> Milestones { get; }
        public IReadOnlyList<ProDecisionHistoryReadModel> DecisionHistory { get; }
        public int? HallOfFameScore { get; }
        /// <summary>
        /// False means an older Core snapshot did not preserve the complete current-season log;
        /// an empty list must not then be interpreted as a season with no appearances.
        /// </summary>
        public bool SeasonGameLinesAvailable { get; }
    }

    public sealed class ProSeasonDecisionReadModel
    {
        public ProSeasonDecisionReadModel(
            string id,
            string title,
            string detail,
            IReadOnlyList<CareerChoiceReadModel> choices)
        {
            Id = id;
            Title = title;
            Detail = detail;
            Choices = (choices ?? Array.Empty<CareerChoiceReadModel>()).ToArray();
        }

        public string Id { get; }
        public string Title { get; }
        public string Detail { get; }
        public IReadOnlyList<CareerChoiceReadModel> Choices { get; }
    }

    public sealed class LeagueStandingReadModel
    {
        public LeagueStandingReadModel(
            int rank,
            string teamId,
            string teamName,
            int wins,
            int losses,
            int draws,
            double gamesBehind,
            bool isPlayerTeam)
        {
            Rank = rank;
            TeamId = teamId;
            TeamName = teamName;
            Wins = wins;
            Losses = losses;
            Draws = draws;
            GamesBehind = gamesBehind;
            IsPlayerTeam = isPlayerTeam;
        }

        public int Rank { get; }
        public string TeamId { get; }
        public string TeamName { get; }
        public int Wins { get; }
        public int Losses { get; }
        public int Draws { get; }
        public double GamesBehind { get; }
        public bool IsPlayerTeam { get; }
    }

    public sealed class LeaguePitcherReadModel
    {
        public LeaguePitcherReadModel(
            int rank,
            string name,
            string teamName,
            int inningsOuts,
            int wins,
            int losses,
            int saves,
            int strikeouts,
            int walks,
            int? hits,
            int runsAllowed,
            bool isPlayer,
            int? homeRuns = null,
            int? recordedHits = null)
        {
            Rank = rank;
            Name = name;
            TeamName = teamName;
            InningsOuts = inningsOuts;
            Wins = wins;
            Losses = losses;
            Saves = saves;
            Strikeouts = strikeouts;
            Walks = walks;
            Hits = hits ?? 0;
            RecordedHits = recordedHits;
            RunsAllowed = runsAllowed;
            IsPlayer = isPlayer;
            HomeRuns = homeRuns;
        }

        public int Rank { get; }
        public string Name { get; }
        public string TeamName { get; }
        public int InningsOuts { get; }
        public int Wins { get; }
        public int Losses { get; }
        public int Saves { get; }
        public int Strikeouts { get; }
        public int Walks { get; }
        /// <summary>Legacy compatibility value. Use RecordedHits or PitchingRecord.</summary>
        public int Hits { get; }
        public int? RecordedHits { get; }
        public int? HomeRuns { get; }
        public int RunsAllowed { get; }
        public bool IsPlayer { get; }

        public PitchingRecordReadModel PitchingRecord => new PitchingRecordReadModel(
            0,
            0,
            InningsOuts,
            Strikeouts,
            Walks,
            RunsAllowed,
            Wins,
            Losses,
            Saves,
            RecordedHits,
            HomeRuns);
    }

    public sealed class ProCareerReadModel
    {
        public ProCareerReadModel(
            string proCareerId,
            ProCareerOrigin origin,
            ProCareerPhase phase,
            string nextSeed,
            ulong coreRevision,
            string playerId,
            string playerName,
            string teamId,
            string teamName,
            int season,
            int week,
            PitcherRatingsReadModel ratings,
            CareerPerformanceReadModel currentSeason,
            IReadOnlyList<ProSeasonLineReadModel> careerSeasons = null,
            string sourceHighSchoolCareerId = null,
            string coreStateJson = null,
            int hallOfFameScore = 0,
            int awards = 0,
            string level = null,
            string role = null,
            int managerTrust = 0,
            int catcherTrust = 0,
            int fatigue = 0,
            IReadOnlyList<CareerChoiceReadModel> weekPlanChoices = null,
            ProSeasonDecisionReadModel seasonDecision = null,
            IReadOnlyList<CareerChoiceReadModel> offseasonChoices = null,
            IReadOnlyList<LeagueStandingReadModel> leagueStandings = null,
            IReadOnlyList<LeaguePitcherReadModel> leaguePitchers = null,
            IReadOnlyList<CareerGameLineReadModel> recentGameLines = null,
            ProContractOfferReadModel contractOffer = null,
            string seasonSegment = null,
            string seasonSegmentTitle = null,
            ProDevelopmentProgressReadModel developmentProgress = null,
            IReadOnlyList<CareerChoiceReadModel> developmentPitchChoices = null,
            ProSegmentProgressReadModel lastSegmentProgress = null,
            int injuryWeeks = 0,
            ProRecordBookReadModel recordBook = null)
        {
            ProCareerId = proCareerId;
            Origin = origin;
            Phase = phase;
            NextSeed = nextSeed;
            CoreRevision = coreRevision;
            PlayerId = playerId;
            PlayerName = playerName;
            TeamId = teamId;
            TeamName = teamName;
            Season = season;
            Week = week;
            Ratings = ratings;
            CurrentSeason = currentSeason;
            CareerSeasons = (careerSeasons ?? Array.Empty<ProSeasonLineReadModel>()).ToArray();
            SourceHighSchoolCareerId = sourceHighSchoolCareerId;
            CoreStateJson = coreStateJson;
            HallOfFameScore = hallOfFameScore;
            Awards = awards;
            Level = level;
            Role = role;
            ManagerTrust = managerTrust;
            CatcherTrust = catcherTrust;
            Fatigue = fatigue;
            WeekPlanChoices = (weekPlanChoices ?? Array.Empty<CareerChoiceReadModel>()).ToArray();
            SeasonDecision = seasonDecision;
            OffseasonChoices = (offseasonChoices ?? Array.Empty<CareerChoiceReadModel>()).ToArray();
            LeagueStandings = (leagueStandings ?? Array.Empty<LeagueStandingReadModel>()).ToArray();
            LeaguePitchers = (leaguePitchers ?? Array.Empty<LeaguePitcherReadModel>()).ToArray();
            RecentGameLines = (recentGameLines ?? Array.Empty<CareerGameLineReadModel>()).ToArray();
            ContractOffer = contractOffer;
            SeasonSegment = seasonSegment;
            SeasonSegmentTitle = seasonSegmentTitle;
            DevelopmentProgress = developmentProgress ?? new ProDevelopmentProgressReadModel();
            DevelopmentPitchChoices = (developmentPitchChoices ?? Array.Empty<CareerChoiceReadModel>()).ToArray();
            LastSegmentProgress = lastSegmentProgress;
            InjuryWeeks = Math.Max(0, injuryWeeks);
            RecordBook = recordBook;
        }

        public string ProCareerId { get; }
        public ProCareerOrigin Origin { get; }
        public ProCareerPhase Phase { get; }
        public string NextSeed { get; }
        public ulong CoreRevision { get; }
        public string PlayerId { get; }
        public string PlayerName { get; }
        public string TeamId { get; }
        public string TeamName { get; }
        public int Season { get; }
        public int Week { get; }
        public PitcherRatingsReadModel Ratings { get; }
        public CareerPerformanceReadModel CurrentSeason { get; }
        public IReadOnlyList<ProSeasonLineReadModel> CareerSeasons { get; }
        public string SourceHighSchoolCareerId { get; }
        public string CoreStateJson { get; }
        public int HallOfFameScore { get; }
        public int Awards { get; }
        public string Level { get; }
        public string Role { get; }
        public int ManagerTrust { get; }
        public int CatcherTrust { get; }
        public int Fatigue { get; }
        public IReadOnlyList<CareerChoiceReadModel> WeekPlanChoices { get; }
        public ProSeasonDecisionReadModel SeasonDecision { get; }
        public IReadOnlyList<CareerChoiceReadModel> OffseasonChoices { get; }
        public IReadOnlyList<LeagueStandingReadModel> LeagueStandings { get; }
        public IReadOnlyList<LeaguePitcherReadModel> LeaguePitchers { get; }
        public IReadOnlyList<CareerGameLineReadModel> RecentGameLines { get; }
        public ProContractOfferReadModel ContractOffer { get; }
        public string SeasonSegment { get; }
        public string SeasonSegmentTitle { get; }
        public ProDevelopmentProgressReadModel DevelopmentProgress { get; }
        public IReadOnlyList<CareerChoiceReadModel> DevelopmentPitchChoices { get; }
        public ProSegmentProgressReadModel LastSegmentProgress { get; }
        public int InjuryWeeks { get; }
        /// <summary>
        /// Save-backed Record/League content. Null is an explicit unavailable marker for an old
        /// Application snapshot that has not yet passed through the current Core adapter.
        /// </summary>
        public ProRecordBookReadModel RecordBook { get; }

        public int CareerStrikeouts =>
            CurrentSeason.Strikeouts + CareerSeasons.Sum(line => line.Strikeouts);
    }

    public sealed class StartDirectProRequest
    {
        public StartDirectProRequest(
            string seed,
            string presetId,
            string playerName,
            string teamId)
        {
            Seed = seed;
            PresetId = presetId;
            PlayerName = playerName;
            TeamId = teamId;
        }

        public string Seed { get; }
        public string PresetId { get; }
        public string PlayerName { get; }
        public string TeamId { get; }
    }

    public sealed class ProCareerAction
    {
        public ProCareerAction(string kind, string value = null)
        {
            Kind = kind;
            Value = value;
        }

        public string Kind { get; }
        public string Value { get; }
    }

    public interface IProCareerPort
    {
        ProCareerReadModel StartFromDraft(HighSchoolCareerReadModel highSchoolCareer);

        ProCareerReadModel StartDirect(StartDirectProRequest request);

        ProCareerReadModel Apply(ProCareerReadModel current, ProCareerAction action);

        /// <summary>Consumes and advances the deterministic game seed before play is exposed.</summary>
        ProCareerReadModel ReservePitch(ProCareerReadModel current, string scenarioId);

        ProCareerReadModel ApplyPitchResult(
            ProCareerReadModel current,
            PitchGameReport report);
    }

    public interface IProPitchScenarioPort
    {
        PitchScenarioReadModel CreatePitchScenario(
            ProCareerReadModel current,
            string requestedScenarioId);
    }

    public interface IProCareerLegacyPort
    {
        IReadOnlyList<SignatureLegacyReadModel> CreateLegacyCandidates(
            HighSchoolCareerReadModel highSchool,
            ProCareerReadModel pro);
    }
}
