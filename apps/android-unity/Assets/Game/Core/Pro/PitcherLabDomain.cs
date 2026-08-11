using System.Collections.Generic;
using System.Linq;
using Baseball.Core.Domain;
using Baseball.Core.HighSchool;

namespace Baseball.Core.Pro
{
    public enum TrainingReactionBand { Muted, Steady, Strong, Breakthrough }
    public enum PitcherLabPhase { Training, ImportantInning, Relationship, Awakening, Scouting, Reflection, Completed }
    public enum RelationshipChoice { TrustCatcher, AssertOwnPlan }
    public enum ScoutingGrade { Undrafted, Follow, Draftable, Elite }

    public sealed class PotentialRangeSnapshot
    {
        public PotentialRangeSnapshot(string metric, int current, int lowerBound, int upperBound, int confidence)
        { Metric = metric; Current = current; LowerBound = lowerBound; UpperBound = upperBound; Confidence = confidence; }
        public string Metric { get; }
        public int Current { get; }
        public int LowerBound { get; }
        public int UpperBound { get; }
        public int Confidence { get; }
    }

    public sealed class DevelopmentSignalsSnapshot
    {
        public DevelopmentSignalsSnapshot(int velocity = 0, int command = 0, int breakingBall = 0, int stamina = 0, int recovery = 0, int gamePlanning = 0)
        { Velocity = velocity; Command = command; BreakingBall = breakingBall; Stamina = stamina; Recovery = recovery; GamePlanning = gamePlanning; }
        public int Velocity { get; }
        public int Command { get; }
        public int BreakingBall { get; }
        public int Stamina { get; }
        public int Recovery { get; }
        public int GamePlanning { get; }
        public int Value(TrainingFocus focus)
        {
            switch (focus)
            {
                case TrainingFocus.Velocity: return Velocity;
                case TrainingFocus.Command: return Command;
                case TrainingFocus.BreakingBall: return BreakingBall;
                case TrainingFocus.Stamina: return Stamina;
                case TrainingFocus.Recovery: return Recovery;
                default: return GamePlanning;
            }
        }
        public DevelopmentSignalsSnapshot Replacing(TrainingFocus focus, int value)
        {
            return new DevelopmentSignalsSnapshot(
                focus == TrainingFocus.Velocity ? value : Velocity,
                focus == TrainingFocus.Command ? value : Command,
                focus == TrainingFocus.BreakingBall ? value : BreakingBall,
                focus == TrainingFocus.Stamina ? value : Stamina,
                focus == TrainingFocus.Recovery ? value : Recovery,
                focus == TrainingFocus.GamePlanning ? value : GamePlanning);
        }
    }

    public sealed class TrainingSessionSnapshot
    {
        public TrainingSessionSnapshot(int sessionNumber, TrainingFocus focus, TrainingIntensity intensity,
            TrainingReactionBand reaction, int signalGained, int ratingPointsGained, int readinessBefore,
            int readinessAfter, int fatigueBefore, int fatigueAfter, string observedClue, string shortFeedback,
            int? ratingBefore = null, int? ratingAfter = null, int? ratingPointsApplied = null)
        {
            SessionNumber = sessionNumber; Focus = focus; Intensity = intensity; Reaction = reaction;
            SignalGained = signalGained; RatingPointsGained = ratingPointsGained; RatingBefore = ratingBefore;
            RatingAfter = ratingAfter; RatingPointsApplied = ratingPointsApplied; ReadinessBefore = readinessBefore;
            ReadinessAfter = readinessAfter; FatigueBefore = fatigueBefore; FatigueAfter = fatigueAfter;
            ObservedClue = observedClue; ShortFeedback = shortFeedback;
        }
        public int SessionNumber { get; }
        public TrainingFocus Focus { get; }
        public TrainingIntensity Intensity { get; }
        public TrainingReactionBand Reaction { get; }
        public int SignalGained { get; }
        public int RatingPointsGained { get; }
        public int? RatingBefore { get; }
        public int? RatingAfter { get; }
        public int? RatingPointsApplied { get; }
        public int ReadinessBefore { get; }
        public int ReadinessAfter { get; }
        public int FatigueBefore { get; }
        public int FatigueAfter { get; }
        public string ObservedClue { get; }
        public string ShortFeedback { get; }
    }

    public sealed class LabPerformanceSnapshot
    {
        public LabPerformanceSnapshot(int importantInningsCompleted = 0, int pitches = 0, int strikeouts = 0, int walks = 0,
            int runsAllowed = 0, int expectedDamage = 0, int actualDamage = 0, int recommendationAccepted = 0)
        {
            ImportantInningsCompleted = importantInningsCompleted; Pitches = pitches; Strikeouts = strikeouts;
            Walks = walks; RunsAllowed = runsAllowed; ExpectedDamage = expectedDamage; ActualDamage = actualDamage;
            RecommendationAccepted = recommendationAccepted;
        }
        public int ImportantInningsCompleted { get; }
        public int Pitches { get; }
        public int Strikeouts { get; }
        public int Walks { get; }
        public int RunsAllowed { get; }
        public int ExpectedDamage { get; }
        public int ActualDamage { get; }
        public int RecommendationAccepted { get; }
        public LabPerformanceSnapshot Adding(ImportantInningReport report)
        {
            return new LabPerformanceSnapshot(ImportantInningsCompleted + 1, Pitches + report.Pitches,
                Strikeouts + report.Strikeouts, Walks + report.Walks, RunsAllowed + report.RunsAllowed,
                ExpectedDamage + report.ExpectedDamage, ActualDamage + report.ActualDamage,
                RecommendationAccepted + report.RecommendationAccepted);
        }
    }

    public sealed class ScoutingEvaluationSnapshot
    {
        public ScoutingEvaluationSnapshot(ScoutingGrade grade, int score, IReadOnlyList<string> strengths, IReadOnlyList<string> concerns, string summary)
        { Grade = grade; Score = score; Strengths = strengths.ToArray(); Concerns = concerns.ToArray(); Summary = summary; }
        public ScoutingGrade Grade { get; }
        public int Score { get; }
        public IReadOnlyList<string> Strengths { get; }
        public IReadOnlyList<string> Concerns { get; }
        public string Summary { get; }
    }

    public sealed class LegacySelectionSnapshot
    {
        public LegacySelectionSnapshot(SoulDomain soulDomain, MemoryCardId memoryCard, int soulPointsGranted, string unlockedSchoolId, string unlockedCoachId, string summary)
        { SoulDomain = soulDomain; MemoryCard = memoryCard; SoulPointsGranted = soulPointsGranted; UnlockedSchoolId = unlockedSchoolId; UnlockedCoachId = unlockedCoachId; Summary = summary; }
        public SoulDomain SoulDomain { get; }
        public MemoryCardId MemoryCard { get; }
        public int SoulPointsGranted { get; }
        public string UnlockedSchoolId { get; }
        public string UnlockedCoachId { get; }
        public string Summary { get; }
    }

    public sealed class PitcherLabSnapshot
    {
        public string RunId { get; internal set; }
        public ulong Revision { get; internal set; }
        public int LifeNumber { get; internal set; }
        public string PresetId { get; internal set; }
        public PitcherLabPhase Phase { get; internal set; }
        public PitcherSnapshot Pitcher { get; internal set; }
        public int TrainingSessionsCompleted { get; internal set; }
        public int RelationshipEventsCompleted { get; internal set; }
        public IReadOnlyList<AwakeningId> SelectedAwakenings { get; internal set; }
        public IReadOnlyList<AwakeningId> AwakeningOptions { get; internal set; }
        public int Readiness { get; internal set; }
        public int Fatigue { get; internal set; }
        public int CatcherTrust { get; internal set; }
        public DevelopmentSignalsSnapshot DevelopmentSignals { get; internal set; }
        public IReadOnlyList<PotentialRangeSnapshot> PotentialRanges { get; internal set; }
        public LabPerformanceSnapshot Performance { get; internal set; }
        public TrainingSessionSnapshot LastTraining { get; internal set; }
        public ScoutingEvaluationSnapshot ScoutingEvaluation { get; internal set; }
        public IReadOnlyList<MemoryCardId> LegacyOptions { get; internal set; }
        public LegacySelectionSnapshot LegacySelection { get; internal set; }
        public string StateCommitment { get; internal set; }
        public int? BalanceVersion { get; internal set; }
        public int? FocusStreak { get; internal set; }
        internal PitcherLabSnapshot Clone()
        {
            return new PitcherLabSnapshot
            {
                RunId = RunId, Revision = Revision, LifeNumber = LifeNumber, PresetId = PresetId, Phase = Phase,
                Pitcher = Pitcher, TrainingSessionsCompleted = TrainingSessionsCompleted,
                RelationshipEventsCompleted = RelationshipEventsCompleted,
                SelectedAwakenings = SelectedAwakenings.ToArray(), AwakeningOptions = AwakeningOptions.ToArray(),
                Readiness = Readiness, Fatigue = Fatigue, CatcherTrust = CatcherTrust,
                DevelopmentSignals = DevelopmentSignals, PotentialRanges = PotentialRanges.ToArray(), Performance = Performance,
                LastTraining = LastTraining, ScoutingEvaluation = ScoutingEvaluation, LegacyOptions = LegacyOptions.ToArray(),
                LegacySelection = LegacySelection, StateCommitment = StateCommitment, BalanceVersion = BalanceVersion,
                FocusStreak = FocusStreak
            };
        }
    }

    public sealed class StartPitcherLabParams
    {
        public StartPitcherLabParams(string seed, string presetId, string playerName = null, int lifeNumber = 1,
            int inheritedSoulPoints = 0, SoulDomain? inheritedSoulDomain = null, MemoryCardId? inheritedMemory = null,
            CreationAllocationSnapshot creationAllocation = null)
        { Seed = seed; PresetId = presetId; PlayerName = playerName; LifeNumber = lifeNumber; InheritedSoulPoints = inheritedSoulPoints; InheritedSoulDomain = inheritedSoulDomain; InheritedMemory = inheritedMemory; CreationAllocation = creationAllocation; }
        public string Seed { get; } public string PresetId { get; } public string PlayerName { get; } public int LifeNumber { get; }
        public int InheritedSoulPoints { get; } public SoulDomain? InheritedSoulDomain { get; } public MemoryCardId? InheritedMemory { get; }
        public CreationAllocationSnapshot CreationAllocation { get; }
    }
    public sealed class CommitTrainingParams
    {
        public CommitTrainingParams(string seed, PitcherLabSnapshot state, TrainingFocus focus, TrainingIntensity intensity)
        { Seed = seed; State = state; Focus = focus; Intensity = intensity; }
        public string Seed { get; } public PitcherLabSnapshot State { get; } public TrainingFocus Focus { get; } public TrainingIntensity Intensity { get; }
    }
    public sealed class RecordImportantInningParams
    {
        public RecordImportantInningParams(string seed, PitcherLabSnapshot state, ImportantInningReport report) { Seed = seed; State = state; Report = report; }
        public string Seed { get; } public PitcherLabSnapshot State { get; } public ImportantInningReport Report { get; }
    }
    public sealed class ChooseRelationshipParams
    {
        public ChooseRelationshipParams(string seed, PitcherLabSnapshot state, RelationshipChoice choice) { Seed = seed; State = state; Choice = choice; }
        public string Seed { get; } public PitcherLabSnapshot State { get; } public RelationshipChoice Choice { get; }
    }
    public sealed class ChooseAwakeningParams
    {
        public ChooseAwakeningParams(string seed, PitcherLabSnapshot state, AwakeningId awakening) { Seed = seed; State = state; Awakening = awakening; }
        public string Seed { get; } public PitcherLabSnapshot State { get; } public AwakeningId Awakening { get; }
    }
    public sealed class PitcherLabStateParams
    {
        public PitcherLabStateParams(string seed, PitcherLabSnapshot state) { Seed = seed; State = state; }
        public string Seed { get; } public PitcherLabSnapshot State { get; }
    }
    public sealed class FinalizeScoutingParams
    {
        public FinalizeScoutingParams(string seed, PitcherLabSnapshot state) { Seed = seed; State = state; }
        public string Seed { get; } public PitcherLabSnapshot State { get; }
    }
    public sealed class SelectLegacyParams
    {
        public SelectLegacyParams(string seed, PitcherLabSnapshot state, SoulDomain soulDomain, MemoryCardId memoryCard)
        { Seed = seed; State = state; SoulDomain = soulDomain; MemoryCard = memoryCard; }
        public string Seed { get; } public PitcherLabSnapshot State { get; } public SoulDomain SoulDomain { get; } public MemoryCardId MemoryCard { get; }
    }

    public sealed class PitcherLabEvent
    {
        public PitcherLabEvent(string eventType, int sequence, IReadOnlyList<string> reasonCodes = null,
            TrainingSessionSnapshot training = null, ImportantInningReport importantInning = null,
            RelationshipChoice? relationshipChoice = null, int? catcherTrustBefore = null, int? catcherTrustAfter = null,
            int? catcherTrustChangeApplied = null, AwakeningId? awakening = null,
            ScoutingEvaluationSnapshot scouting = null, LegacySelectionSnapshot legacy = null)
        {
            EventType = eventType; Sequence = sequence; ReasonCodes = reasonCodes == null ? new string[0] : reasonCodes.ToArray();
            Training = training; ImportantInning = importantInning; RelationshipChoice = relationshipChoice;
            CatcherTrustBefore = catcherTrustBefore; CatcherTrustAfter = catcherTrustAfter;
            CatcherTrustChangeApplied = catcherTrustChangeApplied; Awakening = awakening; Scouting = scouting; Legacy = legacy;
        }
        public string EventType { get; } public int Sequence { get; } public TrainingSessionSnapshot Training { get; }
        public ImportantInningReport ImportantInning { get; } public RelationshipChoice? RelationshipChoice { get; }
        public int? CatcherTrustBefore { get; } public int? CatcherTrustAfter { get; } public int? CatcherTrustChangeApplied { get; }
        public AwakeningId? Awakening { get; } public ScoutingEvaluationSnapshot Scouting { get; } public LegacySelectionSnapshot Legacy { get; }
        public IReadOnlyList<string> ReasonCodes { get; }
    }

    public sealed class PitcherLabResult
    {
        public PitcherLabResult(ulong revision, string nextSeed, IReadOnlyList<PitcherLabEvent> events, PitcherLabSnapshot snapshot, string eventHash)
        { Revision = revision; NextSeed = nextSeed; Events = events.ToArray(); Snapshot = snapshot; EventHash = eventHash; }
        public ulong Revision { get; } public string NextSeed { get; } public IReadOnlyList<PitcherLabEvent> Events { get; }
        public PitcherLabSnapshot Snapshot { get; } public string EventHash { get; }
    }
}
