using System;
using System.Collections.Generic;
using System.Linq;
using Baseball.Application.Commands;

namespace Baseball.Application.HighSchool
{
    public sealed class HighSchoolCareerReadModel
    {
        public HighSchoolCareerReadModel(
            string careerId,
            int lifeNumber,
            HighSchoolPhase phase,
            string nextSeed,
            ulong coreRevision,
            string playerId,
            string playerName,
            string presetId,
            PitcherRatingsReadModel ratings,
            CareerPerformanceReadModel performance,
            string schoolId = null,
            string schoolName = null,
            int schoolYear = 1,
            int chapterNumber = 1,
            int remainingImportantGames = 0,
            int remainingChapterAdvances = 0,
            DraftReadModel draft = null,
            string coreStateJson = null,
            string pledgeId = null,
            bool pledgeDecided = false,
            IReadOnlyList<string> karmas = null,
            IReadOnlyList<string> awakenings = null,
            IReadOnlyList<CareerChoiceReadModel> schoolChoices = null,
            IReadOnlyList<CareerChoiceReadModel> trainingFocusChoices = null,
            IReadOnlyList<CareerChoiceReadModel> trainingIntensityChoices = null,
            IReadOnlyList<CareerChoiceReadModel> relationshipChoices = null,
            IReadOnlyList<CareerChoiceReadModel> awakeningChoices = null,
            IReadOnlyList<CareerChoiceReadModel> legacyMemoryChoices = null,
            int memorySlots = 0,
            TournamentBracketReadModel tournament = null,
            IReadOnlyList<ProspectEntryReadModel> prospectRankings = null,
            IReadOnlyList<CareerGameLineReadModel> gameLines = null,
            IReadOnlyList<CareerChoiceReadModel> signatureLegacyChoices = null,
            string equippedSignatureLegacyId = null,
            string selectedSignatureLegacyId = null,
            string difficulty = "standard",
            bool isChallengeRun = false,
            LegacySelectionMode legacySelectionMode = LegacySelectionMode.Memories,
            bool tutorialCompleted = false,
            int tutorialAttemptCount = 0,
            int pledgeRulesVersion = 0,
            int legacyRewardPermille = 1000,
            int rivalStrikeouts = 0,
            int fatigue = 0,
            int armRisk = 0,
            int injuryRecovery = 0,
            int managerTrust = 50,
            int catcherTrust = 50,
            int rivalTrust = 50,
            int fanInterest = 0,
            int draftForecastScore = 0,
            ChapterProgressReadModel chapterProgress = null,
            IReadOnlyList<CareerMilestoneReadModel> scheduleMilestones = null,
            RelationshipEventReadModel currentRelationshipEvent = null,
            GameScenarioNarrativeReadModel currentGameScenario = null,
            TrainingResultReadModel lastTraining = null,
            RelationshipResultReadModel lastRelationship = null,
            IReadOnlyList<string> news = null,
            IReadOnlyList<CareerChoiceReadModel> trainingPitchChoices = null,
            TrainingBlockResultReadModel lastTrainingBlock = null,
            int maximumTrainingBlockSessions = HighSchoolTrainingActionPayload.MaximumBlockSessions,
            IReadOnlyList<SignatureLegacyReadModel> frozenSignatureLegacyCandidates = null,
            SignatureLegacyReadModel selectedSignatureLegacy = null,
            HighSchoolLifeDetailReadModel lifeDetail = null,
            IReadOnlyList<TrainingOutlookReadModel> trainingOutlooks = null)
        {
            CareerId = careerId;
            LifeNumber = lifeNumber;
            Phase = phase;
            NextSeed = nextSeed;
            CoreRevision = coreRevision;
            PlayerId = playerId;
            PlayerName = playerName;
            PresetId = presetId;
            Ratings = ratings;
            Performance = performance;
            SchoolId = schoolId;
            SchoolName = schoolName;
            SchoolYear = schoolYear;
            ChapterNumber = chapterNumber;
            RemainingImportantGames = remainingImportantGames;
            RemainingChapterAdvances = remainingChapterAdvances;
            Draft = draft;
            CoreStateJson = coreStateJson;
            PledgeId = pledgeId;
            PledgeDecided = pledgeDecided;
            Karmas = (karmas ?? Array.Empty<string>()).ToArray();
            Awakenings = (awakenings ?? Array.Empty<string>()).ToArray();
            SchoolChoices = (schoolChoices ?? Array.Empty<CareerChoiceReadModel>()).ToArray();
            TrainingFocusChoices = (trainingFocusChoices ?? Array.Empty<CareerChoiceReadModel>()).ToArray();
            TrainingIntensityChoices = (trainingIntensityChoices ?? Array.Empty<CareerChoiceReadModel>()).ToArray();
            RelationshipChoices = (relationshipChoices ?? Array.Empty<CareerChoiceReadModel>()).ToArray();
            AwakeningChoices = (awakeningChoices ?? Array.Empty<CareerChoiceReadModel>()).ToArray();
            LegacyMemoryChoices = (legacyMemoryChoices ?? Array.Empty<CareerChoiceReadModel>()).ToArray();
            MemorySlots = memorySlots;
            Tournament = tournament;
            ProspectRankings = (prospectRankings ?? Array.Empty<ProspectEntryReadModel>()).ToArray();
            GameLines = (gameLines ?? Array.Empty<CareerGameLineReadModel>()).ToArray();
            SignatureLegacyChoices = (signatureLegacyChoices ?? Array.Empty<CareerChoiceReadModel>()).ToArray();
            EquippedSignatureLegacyId = equippedSignatureLegacyId;
            SelectedSignatureLegacyId = selectedSignatureLegacyId;
            Difficulty = difficulty;
            IsChallengeRun = isChallengeRun;
            LegacySelectionMode = legacySelectionMode;
            TutorialCompleted = tutorialCompleted;
            TutorialAttemptCount = tutorialAttemptCount;
            PledgeRulesVersion = pledgeRulesVersion;
            LegacyRewardPermille = Math.Max(1000, legacyRewardPermille);
            RivalStrikeouts = Math.Max(0, rivalStrikeouts);
            Fatigue = fatigue;
            ArmRisk = armRisk;
            InjuryRecovery = injuryRecovery;
            ManagerTrust = managerTrust;
            CatcherTrust = catcherTrust;
            RivalTrust = rivalTrust;
            FanInterest = fanInterest;
            DraftForecastScore = draftForecastScore;
            ChapterProgress = chapterProgress;
            ScheduleMilestones = (scheduleMilestones ?? Array.Empty<CareerMilestoneReadModel>()).ToArray();
            CurrentRelationshipEvent = currentRelationshipEvent;
            CurrentGameScenario = currentGameScenario;
            LastTraining = lastTraining;
            LastRelationship = lastRelationship;
            News = (news ?? Array.Empty<string>()).ToArray();
            TrainingPitchChoices = (trainingPitchChoices ?? Array.Empty<CareerChoiceReadModel>()).ToArray();
            LastTrainingBlock = lastTrainingBlock;
            MaximumTrainingBlockSessions = maximumTrainingBlockSessions;
            FrozenSignatureLegacyCandidates =
                (frozenSignatureLegacyCandidates ?? Array.Empty<SignatureLegacyReadModel>()).ToArray();
            SelectedSignatureLegacy = selectedSignatureLegacy;
            LifeDetail = lifeDetail;
            TrainingOutlooks = (trainingOutlooks ?? Array.Empty<TrainingOutlookReadModel>()).ToArray();
        }

        public string CareerId { get; }
        public int LifeNumber { get; }
        public HighSchoolPhase Phase { get; }
        public string NextSeed { get; }
        public ulong CoreRevision { get; }
        public string PlayerId { get; }
        public string PlayerName { get; }
        public string PresetId { get; }
        public PitcherRatingsReadModel Ratings { get; }
        public CareerPerformanceReadModel Performance { get; }
        public string SchoolId { get; }
        public string SchoolName { get; }
        public int SchoolYear { get; }
        public int ChapterNumber { get; }
        public int RemainingImportantGames { get; }
        public int RemainingChapterAdvances { get; }
        public DraftReadModel Draft { get; }
        public string CoreStateJson { get; }
        public string PledgeId { get; }
        public bool PledgeDecided { get; }
        public IReadOnlyList<string> Karmas { get; }
        public IReadOnlyList<string> Awakenings { get; }
        public IReadOnlyList<CareerChoiceReadModel> SchoolChoices { get; }
        public IReadOnlyList<CareerChoiceReadModel> TrainingFocusChoices { get; }
        public IReadOnlyList<CareerChoiceReadModel> TrainingIntensityChoices { get; }
        public IReadOnlyList<CareerChoiceReadModel> RelationshipChoices { get; }
        public IReadOnlyList<CareerChoiceReadModel> AwakeningChoices { get; }
        public IReadOnlyList<CareerChoiceReadModel> LegacyMemoryChoices { get; }
        public int MemorySlots { get; }
        public TournamentBracketReadModel Tournament { get; }
        public IReadOnlyList<ProspectEntryReadModel> ProspectRankings { get; }
        public IReadOnlyList<CareerGameLineReadModel> GameLines { get; }
        /// <summary>
        /// Full high-school game log projection, including simulated team games. Nullable
        /// advanced-stat inputs remain unavailable when any source line did not record them.
        /// </summary>
        public PitchingRecordReadModel PitchingRecord =>
            PitchingRecordReadModel.FromGameLines(GameLines);
        public IReadOnlyList<CareerChoiceReadModel> SignatureLegacyChoices { get; }
        public string EquippedSignatureLegacyId { get; }
        public string SelectedSignatureLegacyId { get; }
        public string Difficulty { get; }
        public bool IsChallengeRun { get; }
        public LegacySelectionMode LegacySelectionMode { get; }
        /// <summary>
        /// Per-career receipt for the non-progression bullpen. The tutorial may be replayed, but
        /// this durable receipt is required before the prologue can advance.
        /// </summary>
        public bool TutorialCompleted { get; }
        public int TutorialAttemptCount { get; }
        public int PledgeRulesVersion { get; }
        public int LegacyRewardPermille { get; }
        public int RivalStrikeouts { get; }
        public int Fatigue { get; }
        public int ArmRisk { get; }
        public int InjuryRecovery { get; }
        public int ManagerTrust { get; }
        public int CatcherTrust { get; }
        public int RivalTrust { get; }
        public int FanInterest { get; }
        public int DraftForecastScore { get; }
        public ChapterProgressReadModel ChapterProgress { get; }
        public IReadOnlyList<CareerMilestoneReadModel> ScheduleMilestones { get; }
        public RelationshipEventReadModel CurrentRelationshipEvent { get; }
        public GameScenarioNarrativeReadModel CurrentGameScenario { get; }
        public TrainingResultReadModel LastTraining { get; }
        public RelationshipResultReadModel LastRelationship { get; }
        public IReadOnlyList<string> News { get; }
        public IReadOnlyList<CareerChoiceReadModel> TrainingPitchChoices { get; }
        public TrainingBlockResultReadModel LastTrainingBlock { get; }
        public int MaximumTrainingBlockSessions { get; }
        public IReadOnlyList<SignatureLegacyReadModel> FrozenSignatureLegacyCandidates { get; }
        public SignatureLegacyReadModel SelectedSignatureLegacy { get; }
        public HighSchoolLifeDetailReadModel LifeDetail { get; }
        public IReadOnlyList<TrainingOutlookReadModel> TrainingOutlooks { get; }
    }
}
