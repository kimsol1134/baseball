using System;
using System.Collections.Generic;
using System.Linq;
using Baseball.Application.HighSchool;
using Baseball.Application.Pro;

namespace Baseball.Application.Meta
{
    /// <summary>Durable non-consumable setup values used by one-tap rebirth.</summary>
    public sealed class HighSchoolLastSetupState
    {
        public HighSchoolLastSetupState(
            string presetId,
            string playerName,
            string region,
            string difficulty = "standard",
            IReadOnlyList<string> karmas = null,
            string soulDomain = null)
        {
            PresetId = presetId;
            PlayerName = playerName;
            Region = region;
            Difficulty = string.IsNullOrWhiteSpace(difficulty) ? "standard" : difficulty;
            Karmas = (karmas ?? Array.Empty<string>()).ToArray();
            SoulDomain = soulDomain;
        }

        public string PresetId { get; }
        public string PlayerName { get; }
        public string Region { get; }
        public string Difficulty { get; }
        public IReadOnlyList<string> Karmas { get; }
        public string SoulDomain { get; }
    }

    public sealed class NextRunIntentState
    {
        public NextRunIntentState(
            string pledgeId,
            int sourceLifeNumber,
            string reason,
            string pledgeTitle = null,
            string pledgeTier = null,
            int? pledgeRewardPermille = null)
        {
            PledgeId = pledgeId;
            SourceLifeNumber = sourceLifeNumber;
            Reason = reason;
            PledgeTitle = pledgeTitle;
            PledgeTier = pledgeTier;
            PledgeRewardPermille = pledgeRewardPermille;
        }

        public string PledgeId { get; }
        public int SourceLifeNumber { get; }
        public string Reason { get; }
        public string PledgeTitle { get; }
        public string PledgeTier { get; }
        public int? PledgeRewardPermille { get; }
    }

    public sealed class ReturnPlanState
    {
        public ReturnPlanState(
            string route,
            string title,
            string nextAction,
            string createdDayKey,
            bool dismissed = false,
            string body = null,
            ReturnPlanDestination? destination = null,
            string reason = null,
            string experimentId = null,
            string receiptId = null,
            string savedDayKey = null,
            string experimentVariant = null,
            int? developmentRulesVersion = null)
        {
            Route = route;
            Title = title;
            NextAction = nextAction;
            CreatedDayKey = createdDayKey;
            Dismissed = dismissed;
            Body = body ?? nextAction;
            Destination = destination ?? ReturnPlanRules.DestinationForLegacyRoute(route);
            Reason = reason ?? "legacy";
            ExperimentId = experimentId;
            ReceiptId = receiptId;
            SavedDayKey = savedDayKey ?? createdDayKey;
            ExperimentVariant = experimentVariant;
            DevelopmentRulesVersion = developmentRulesVersion;
        }

        public string Route { get; }
        public string Title { get; }
        public string NextAction { get; }
        public string ContinueTitle => ReturnPlanRules.ContinueTitle(Destination);
        public string CreatedDayKey { get; }
        public bool Dismissed { get; }
        public string Body { get; }
        public ReturnPlanDestination Destination { get; }
        public string Reason { get; }
        public string ExperimentId { get; }
        public string ReceiptId { get; }
        public string SavedDayKey { get; }
        public string ExperimentVariant { get; }
        public int? DevelopmentRulesVersion { get; }

        public static ReturnPlanState Create(
            string title,
            string body,
            ReturnPlanDestination destination,
            string reason,
            string experimentId = null,
            string receiptId = null,
            string savedDayKey = null,
            string experimentVariant = null,
            int? developmentRulesVersion = null,
            bool dismissed = false)
        {
            return new ReturnPlanState(
                ReturnPlanRules.Route(destination),
                title,
                ReturnPlanRules.ContinueTitle(destination),
                savedDayKey,
                dismissed,
                body,
                destination,
                reason,
                experimentId,
                receiptId,
                savedDayKey,
                experimentVariant,
                developmentRulesVersion);
        }

        public ReturnPlanState WithDismissed(bool dismissed)
        {
            return new ReturnPlanState(
                Route,
                Title,
                NextAction,
                CreatedDayKey,
                dismissed,
                Body,
                Destination,
                Reason,
                ExperimentId,
                ReceiptId,
                SavedDayKey,
                ExperimentVariant,
                DevelopmentRulesVersion);
        }
    }

    public sealed class ReturnWelcomeHandledState
    {
        public ReturnWelcomeHandledState(
            string title,
            string body,
            ReturnPlanDestination destination,
            string reason,
            string dayKey)
        {
            Title = title;
            Body = body;
            Destination = destination;
            Reason = reason;
            DayKey = dayKey;
        }

        public string Title { get; }
        public string Body { get; }
        public ReturnPlanDestination Destination { get; }
        public string Reason { get; }
        public string DayKey { get; }
    }

    public sealed class LifeArchiveRecord
    {
        public LifeArchiveRecord(
            string lifeId,
            int lifeNumber,
            string playerName,
            string highSchoolCareerId,
            string proCareerId,
            string schoolId,
            string schoolName,
            bool drafted,
            int draftEvaluation,
            PitcherRatingsReadModel finalRatings,
            CareerPerformanceReadModel highSchoolPerformance,
            int proSeasons,
            int proStrikeouts,
            int proAwards,
            int hallOfFameScore,
            int soulEarned,
            IReadOnlyList<string> karmas = null,
            IReadOnlyList<string> awakenings = null,
            IReadOnlyList<string> memories = null,
            long completedAtUnixSeconds = 0,
            string pledgeId = null,
            string pledgeTitle = null,
            string pledgeTier = null,
            int? pledgeRewardPermille = null,
            bool? pledgeAchieved = null,
            int? pledgeProgressCurrent = null,
            int? pledgeProgressTarget = null,
            string pledgeProgressLine = null,
            int? pledgeProgressRatioPermille = null,
            int pledgeRulesVersion = 0,
            NextRunIntentState suggestedNextRunIntent = null,
            PlayerLegacyState playerLegacy = null,
            HighSchoolLifeDetailReadModel highSchoolDetail = null,
            SignatureLegacyReadModel signatureLegacy = null,
            IReadOnlyList<SignatureLegacyReadModel> signatureLegacyCandidates = null,
            int? pitches = null,
            int? outs = null,
            int? hits = null,
            string draftTeamName = null)
        {
            LifeId = lifeId;
            LifeNumber = lifeNumber;
            PlayerName = playerName;
            HighSchoolCareerId = highSchoolCareerId;
            ProCareerId = proCareerId;
            SchoolId = schoolId;
            SchoolName = schoolName;
            Drafted = drafted;
            DraftEvaluation = draftEvaluation;
            FinalRatings = finalRatings;
            HighSchoolPerformance = highSchoolPerformance;
            ProSeasons = proSeasons;
            ProStrikeouts = proStrikeouts;
            ProAwards = proAwards;
            HallOfFameScore = hallOfFameScore;
            SoulEarned = soulEarned;
            Karmas = (karmas ?? Array.Empty<string>()).ToArray();
            Awakenings = (awakenings ?? Array.Empty<string>()).ToArray();
            Memories = (memories ?? Array.Empty<string>()).ToArray();
            CompletedAtUnixSeconds = completedAtUnixSeconds;
            PledgeId = pledgeId;
            PledgeTitle = pledgeTitle;
            PledgeTier = pledgeTier;
            PledgeRewardPermille = pledgeRewardPermille;
            PledgeAchieved = pledgeAchieved;
            PledgeProgressCurrent = pledgeProgressCurrent;
            PledgeProgressTarget = pledgeProgressTarget;
            PledgeProgressLine = pledgeProgressLine;
            PledgeProgressRatioPermille = pledgeProgressRatioPermille;
            PledgeRulesVersion = pledgeRulesVersion;
            SuggestedNextRunIntent = suggestedNextRunIntent;
            PlayerLegacy = playerLegacy;
            HighSchoolDetail = highSchoolDetail;
            SignatureLegacy = signatureLegacy;
            SignatureLegacyCandidates =
                (signatureLegacyCandidates ?? Array.Empty<SignatureLegacyReadModel>()).ToArray();
            Pitches = pitches;
            Outs = outs;
            Hits = hits;
            DraftTeamName = draftTeamName;
        }

        public string LifeId { get; }
        public int LifeNumber { get; }
        public string PlayerName { get; }
        public string HighSchoolCareerId { get; }
        public string ProCareerId { get; }
        public string SchoolId { get; }
        public string SchoolName { get; }
        public bool Drafted { get; }
        public int DraftEvaluation { get; }
        public PitcherRatingsReadModel FinalRatings { get; }
        public CareerPerformanceReadModel HighSchoolPerformance { get; }
        public int ProSeasons { get; }
        public int ProStrikeouts { get; }
        public int ProAwards { get; }
        public int HallOfFameScore { get; }
        public int SoulEarned { get; }
        public IReadOnlyList<string> Karmas { get; }
        public IReadOnlyList<string> Awakenings { get; }
        public IReadOnlyList<string> Memories { get; }
        public long CompletedAtUnixSeconds { get; }
        /// <summary>Frozen pledge presentation and result; later catalog copy changes are irrelevant.</summary>
        public string PledgeId { get; }
        public string PledgeTitle { get; }
        public string PledgeTier { get; }
        public int? PledgeRewardPermille { get; }
        public bool? PledgeAchieved { get; }
        public int? PledgeProgressCurrent { get; }
        public int? PledgeProgressTarget { get; }
        public string PledgeProgressLine { get; }
        public int? PledgeProgressRatioPermille { get; }
        public int PledgeRulesVersion { get; }
        /// <summary>Frozen recap suggestion only; it is not the active next-run intent.</summary>
        public NextRunIntentState SuggestedNextRunIntent { get; }
        /// <summary>Frozen settlement copy; null only for saves created before this field existed.</summary>
        public PlayerLegacyState PlayerLegacy { get; }
        /// <summary>Frozen per-life people, voice, history, and starting ability.</summary>
        public HighSchoolLifeDetailReadModel HighSchoolDetail { get; }
        /// <summary>The exact offered legacy selected at settlement; never regenerated.</summary>
        public SignatureLegacyReadModel SignatureLegacy { get; }
        /// <summary>All three frozen offers belonging to this life.</summary>
        public IReadOnlyList<SignatureLegacyReadModel> SignatureLegacyCandidates { get; }
        public int? Pitches { get; }
        public int? Outs { get; }
        public int? Hits { get; }
        /// <summary>Frozen fictional club name from the high-school draft outcome.</summary>
        public string DraftTeamName { get; }
    }

    public sealed class MetaProgressState
    {
        public MetaProgressState(
            int lifeNumber = 1,
            int soulBalance = 0,
            int soulLifetimeEarned = 0,
            int automaticSoulEarned = 0,
            IReadOnlyList<string> inheritedMemories = null,
            IReadOnlyList<string> creditedRewardIds = null,
            IReadOnlyList<string> creditedProCareerIds = null,
            IReadOnlyList<LifeArchiveRecord> lifeArchive = null,
            DailyStreakState daily = null,
            WeeklyProgressState weekly = null,
            AchievementProgressState achievements = null,
            NextRunIntentState nextRunIntent = null,
            ReturnPlanState returnPlan = null,
            HighSchoolLastSetupState lastHighSchoolSetup = null,
            IReadOnlyList<string> unlockedSignatureLegacyIds = null,
            string equippedSignatureLegacyId = null,
            ReturnWelcomeHandledState returnWelcomeHandled = null,
            int completedGameCount = 0)
        {
            LifeNumber = lifeNumber;
            SoulBalance = soulBalance;
            SoulLifetimeEarned = soulLifetimeEarned;
            AutomaticSoulEarned = automaticSoulEarned;
            InheritedMemories = Normalize(inheritedMemories);
            CreditedRewardIds = Normalize(creditedRewardIds);
            CreditedProCareerIds = Normalize(creditedProCareerIds);
            LifeArchive = (lifeArchive ?? Array.Empty<LifeArchiveRecord>()).ToArray();
            Daily = daily ?? DailyStreakState.Empty;
            Weekly = weekly ?? WeeklyProgressState.Empty;
            Achievements = achievements ?? AchievementProgressState.Empty;
            NextRunIntent = nextRunIntent;
            ReturnPlan = returnPlan;
            LastHighSchoolSetup = lastHighSchoolSetup;
            UnlockedSignatureLegacyIds = Normalize(unlockedSignatureLegacyIds);
            EquippedSignatureLegacyId = equippedSignatureLegacyId;
            ReturnWelcomeHandled = returnWelcomeHandled;
            CompletedGameCount = completedGameCount;
        }

        public int LifeNumber { get; }
        public int SoulBalance { get; }
        public int SoulLifetimeEarned { get; }
        public int AutomaticSoulEarned { get; }
        public IReadOnlyList<string> InheritedMemories { get; }
        public IReadOnlyList<string> CreditedRewardIds { get; }
        public IReadOnlyList<string> CreditedProCareerIds { get; }
        public IReadOnlyList<LifeArchiveRecord> LifeArchive { get; }
        public DailyStreakState Daily { get; }
        public WeeklyProgressState Weekly { get; }
        public AchievementProgressState Achievements { get; }
        public NextRunIntentState NextRunIntent { get; }
        public ReturnPlanState ReturnPlan { get; }
        public HighSchoolLastSetupState LastHighSchoolSetup { get; }
        public IReadOnlyList<string> UnlockedSignatureLegacyIds { get; }
        public string EquippedSignatureLegacyId { get; }
        public ReturnWelcomeHandledState ReturnWelcomeHandled { get; }
        /// <summary>
        /// Monotonic number of official games durably completed on this installation. It is not
        /// derived from current/archive snapshots, so settlement and rebirth cannot double-count
        /// or decrease it.
        /// </summary>
        public int CompletedGameCount { get; }

        public static MetaProgressState Initial { get; } = new MetaProgressState();

        public MetaProgressState With(
            int? lifeNumber = null,
            int? soulBalance = null,
            int? soulLifetimeEarned = null,
            int? automaticSoulEarned = null,
            IReadOnlyList<string> inheritedMemories = null,
            IReadOnlyList<string> creditedRewardIds = null,
            IReadOnlyList<string> creditedProCareerIds = null,
            IReadOnlyList<LifeArchiveRecord> lifeArchive = null,
            DailyStreakState daily = null,
            WeeklyProgressState weekly = null,
            AchievementProgressState achievements = null,
            NextRunIntentState nextRunIntent = null,
            bool clearNextRunIntent = false,
            ReturnPlanState returnPlan = null,
            bool clearReturnPlan = false,
            HighSchoolLastSetupState lastHighSchoolSetup = null,
            bool clearLastHighSchoolSetup = false,
            IReadOnlyList<string> unlockedSignatureLegacyIds = null,
            string equippedSignatureLegacyId = null,
            bool clearEquippedSignatureLegacy = false,
            ReturnWelcomeHandledState returnWelcomeHandled = null,
            bool clearReturnWelcomeHandled = false,
            int? completedGameCount = null)
        {
            return new MetaProgressState(
                lifeNumber ?? LifeNumber,
                soulBalance ?? SoulBalance,
                soulLifetimeEarned ?? SoulLifetimeEarned,
                automaticSoulEarned ?? AutomaticSoulEarned,
                inheritedMemories ?? InheritedMemories,
                creditedRewardIds ?? CreditedRewardIds,
                creditedProCareerIds ?? CreditedProCareerIds,
                lifeArchive ?? LifeArchive,
                daily ?? Daily,
                weekly ?? Weekly,
                achievements ?? Achievements,
                clearNextRunIntent ? null : nextRunIntent ?? NextRunIntent,
                clearReturnPlan ? null : returnPlan ?? ReturnPlan,
                clearLastHighSchoolSetup ? null : lastHighSchoolSetup ?? LastHighSchoolSetup,
                unlockedSignatureLegacyIds ?? UnlockedSignatureLegacyIds,
                clearEquippedSignatureLegacy
                    ? null
                    : equippedSignatureLegacyId ?? EquippedSignatureLegacyId,
                clearReturnWelcomeHandled
                    ? null
                    : returnWelcomeHandled ?? ReturnWelcomeHandled,
                completedGameCount ?? CompletedGameCount);
        }

        public static int ProSoulBonus(ProCareerReadModel state)
        {
            return 20 + state.CareerSeasons.Count * 3 + state.CareerStrikeouts / 25 +
                state.Awards * 8 + state.HallOfFameScore / 2;
        }

        private static IReadOnlyList<string> Normalize(IReadOnlyList<string> values)
        {
            return (values ?? Array.Empty<string>())
                .Where(value => !string.IsNullOrWhiteSpace(value))
                .Distinct(StringComparer.Ordinal)
                .OrderBy(value => value, StringComparer.Ordinal)
                .ToArray();
        }
    }
}
