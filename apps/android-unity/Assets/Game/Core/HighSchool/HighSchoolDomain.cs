using System;
using System.Collections.Generic;
using System.Linq;
using Baseball.Core.Domain;

namespace Baseball.Core.HighSchool
{
    public enum HighSchoolCareerPhase { Prologue, SchoolSelection, Training, Relationship, ImportantGame, Awakening, ChapterReview, Draft, Legacy, Completed }
    public enum BodyType { Compact, Balanced, Tall }
    public enum DifficultyLevel { Relaxed, Standard, Challenging }
    public enum InterventionAssist { Full, Standard, Minimal }
    public enum SchoolId { HanbitTraditional, MiraeAnalytics, HaedongPower, CheongamDevelopment }
    public enum RelationshipTarget { Coach, Catcher, Rival }
    public enum RelationshipResponse { Listen, Explain, Challenge }
    public enum DraftOutcome { Drafted, Undrafted }
    public enum ArmHealthState { Normal, Caution, Warning, Recovering }
    public enum TrainingIntensity { Light, Standard, Intensive }
    public enum TrainingBlockStopReason
    {
        MaximumSessions,
        Relationship,
        Awakening,
        ImportantGame,
        TalentBloom,
        Fatigue,
        ArmHealth,
        PhaseChanged
    }
    public enum SoulDomain { Body, Technique, Game }
    public enum PitchingDecision { Win, Loss, Save, NoDecision }

    public enum KarmaId
    {
        UnknownLand, StubbornCoach, SingleWeapon, GeniusGeneration, ErasedMemory, NoLastChance
    }

    public static class KarmaRules
    {
        public static int RewardPermille(this KarmaId value)
        {
            switch (value)
            {
                case KarmaId.UnknownLand:
                case KarmaId.StubbornCoach: return 150;
                case KarmaId.SingleWeapon: return 200;
                case KarmaId.GeniusGeneration:
                case KarmaId.ErasedMemory: return 250;
                case KarmaId.NoLastChance: return 350;
                default: throw new ArgumentOutOfRangeException(nameof(value));
            }
        }
    }

    public enum AwakeningId
    {
        ExplosiveFastball, PinpointEdge, DisappearingBreaker, IronArm, CalmUnderPressure,
        BatterySync, RisingFourSeam, SinkerTunnel, FrozenChangeup, SweepingSlider,
        CurveballClock, RepeatableRelease, PickoffRhythm, TwoStrikePlan, FirstPitchStrike,
        TrafficController, LateInningReserve, ScoutComposure
    }

    public enum MemoryCardId
    {
        VelocityBlueprint, FingertipMemory, CatcherNotebook, RivalNotebook, RecoveryRoutine,
        PressureRehearsal, FirstPitchMap, TwoStrikeSequence, FatigueDiary, MechanicsVideo,
        SchoolPlaybook, CoachLetter, DraftReport, StadiumEcho, TeamFirstPromise,
        FailureScorebook, WinterProgram, BullpenCompass
    }

    public enum SoulBoostId { TalentBreak, ExtraMemory, HeadStart, TrainingRhythm }
    public enum SoulInheritanceRulesVersion { V1 = 1, V2 = 2 }

    public static class HighSchoolWire
    {
        public static string Value(this HighSchoolCareerPhase value)
        {
            switch (value)
            {
                case HighSchoolCareerPhase.Prologue: return "prologue";
                case HighSchoolCareerPhase.SchoolSelection: return "school_selection";
                case HighSchoolCareerPhase.Training: return "training";
                case HighSchoolCareerPhase.Relationship: return "relationship";
                case HighSchoolCareerPhase.ImportantGame: return "important_game";
                case HighSchoolCareerPhase.Awakening: return "awakening";
                case HighSchoolCareerPhase.ChapterReview: return "chapter_review";
                case HighSchoolCareerPhase.Draft: return "draft";
                case HighSchoolCareerPhase.Legacy: return "legacy";
                case HighSchoolCareerPhase.Completed: return "completed";
                default: throw new ArgumentOutOfRangeException(nameof(value));
            }
        }

        public static string Value(this TrainingFocus value)
        {
            switch (value)
            {
                case TrainingFocus.Velocity: return "velocity";
                case TrainingFocus.Command: return "command";
                case TrainingFocus.BreakingBall: return "breaking_ball";
                case TrainingFocus.Stamina: return "stamina";
                case TrainingFocus.Recovery: return "recovery";
                case TrainingFocus.GamePlanning: return "game_planning";
                default: throw new ArgumentOutOfRangeException(nameof(value));
            }
        }

        public static string Value(this TrainingBlockStopReason value)
        {
            switch (value)
            {
                case TrainingBlockStopReason.MaximumSessions: return "maximum_sessions";
                case TrainingBlockStopReason.Relationship: return "relationship";
                case TrainingBlockStopReason.Awakening: return "awakening";
                case TrainingBlockStopReason.ImportantGame: return "important_game";
                case TrainingBlockStopReason.TalentBloom: return "talent_bloom";
                case TrainingBlockStopReason.Fatigue: return "fatigue";
                case TrainingBlockStopReason.ArmHealth: return "arm_health";
                default: return "phase_changed";
            }
        }

        public static string Value(this AwakeningId value)
        {
            var values = new[] { "explosive_fastball", "pinpoint_edge", "disappearing_breaker", "iron_arm", "calm_under_pressure", "battery_sync", "rising_four_seam", "sinker_tunnel", "frozen_changeup", "sweeping_slider", "curveball_clock", "repeatable_release", "pickoff_rhythm", "two_strike_plan", "first_pitch_strike", "traffic_controller", "late_inning_reserve", "scout_composure" };
            return values[(int)value];
        }

        public static string Value(this MemoryCardId value)
        {
            var values = new[] { "velocity_blueprint", "fingertip_memory", "catcher_notebook", "rival_notebook", "recovery_routine", "pressure_rehearsal", "first_pitch_map", "two_strike_sequence", "fatigue_diary", "mechanics_video", "school_playbook", "coach_letter", "draft_report", "stadium_echo", "team_first_promise", "failure_scorebook", "winter_program", "bullpen_compass" };
            return values[(int)value];
        }

        public static int Cost(this SoulBoostId value)
        {
            switch (value)
            {
                case SoulBoostId.TalentBreak: return 240;
                case SoulBoostId.ExtraMemory: return 160;
                case SoulBoostId.HeadStart: return 120;
                case SoulBoostId.TrainingRhythm: return 90;
                default: throw new ArgumentOutOfRangeException(nameof(value));
            }
        }
    }

    public sealed class CareerDifficultySnapshot
    {
        public CareerDifficultySnapshot(DifficultyLevel careerHarshness = DifficultyLevel.Standard, DifficultyLevel informationClarity = DifficultyLevel.Standard, DifficultyLevel simulationDifficulty = DifficultyLevel.Standard, InterventionAssist interventionAssist = InterventionAssist.Standard)
        { CareerHarshness = careerHarshness; InformationClarity = informationClarity; SimulationDifficulty = simulationDifficulty; InterventionAssist = interventionAssist; }
        public DifficultyLevel CareerHarshness { get; }
        public DifficultyLevel InformationClarity { get; }
        public DifficultyLevel SimulationDifficulty { get; }
        public InterventionAssist InterventionAssist { get; }
        public static CareerDifficultySnapshot Standard { get; } = new CareerDifficultySnapshot();
    }

    public sealed class PlayerIdentitySnapshot
    {
        public PlayerIdentitySnapshot(string name, ThrowingHand throwingHand, BodyType bodyType, string region)
        { Name = name; ThrowingHand = throwingHand; BodyType = bodyType; Region = region; }
        public string Name { get; }
        public ThrowingHand ThrowingHand { get; }
        public BodyType BodyType { get; }
        public string Region { get; }
        public static PlayerIdentitySnapshot DefaultPitcher { get; } = new PlayerIdentitySnapshot("민서준", ThrowingHand.Right, BodyType.Balanced, "서울");
    }

    public sealed class SchoolSnapshot
    {
        public SchoolSnapshot(SchoolId id, string name, string philosophy, string coachName, string coachArchetype, string catcherName, string catcherArchetype, TrainingFocus strength, string tradeoff, string coachPersonality = null, string coachRecord = null, string catcherPersonality = null, string catcherRecord = null)
        { Id = id; Name = name; Philosophy = philosophy; CoachName = coachName; CoachArchetype = coachArchetype; CatcherName = catcherName; CatcherArchetype = catcherArchetype; Strength = strength; Tradeoff = tradeoff; CoachPersonality = coachPersonality; CoachRecord = coachRecord; CatcherPersonality = catcherPersonality; CatcherRecord = catcherRecord; }
        public SchoolId Id { get; } public string Name { get; } public string Philosophy { get; }
        public string CoachName { get; } public string CoachArchetype { get; } public string CatcherName { get; } public string CatcherArchetype { get; }
        public string CoachPersonality { get; } public string CoachRecord { get; } public string CatcherPersonality { get; } public string CatcherRecord { get; }
        public TrainingFocus Strength { get; } public string Tradeoff { get; }
    }

    public sealed class RivalSnapshot
    {
        public RivalSnapshot(string id, string name, string archetype, int contact, int discipline, int power, string personality = null, string signatureRecord = null)
        { Id = id; Name = name; Archetype = archetype; Contact = contact; Discipline = discipline; Power = power; Personality = personality; SignatureRecord = signatureRecord; }
        public string Id { get; } public string Name { get; } public string Archetype { get; }
        public int Contact { get; } public int Discipline { get; } public int Power { get; }
        public string Personality { get; } public string SignatureRecord { get; }
    }

    public sealed class CareerChapterSnapshot
    {
        public CareerChapterSnapshot(int number, string title, int schoolYear, string season, string theme)
        { Number = number; Title = title; SchoolYear = schoolYear; Season = season; Theme = theme; }
        public int Number { get; } public string Title { get; } public int SchoolYear { get; } public string Season { get; } public string Theme { get; }
    }

    public sealed class ImportantInningReport
    {
        public ImportantInningReport(int scenarioNumber, int pitches, int strikeouts, int walks, int runsAllowed, int expectedDamage, int actualDamage, int recommendationAccepted, int? outs = null, int? teamRuns = null, int? scoreDifferentialAtEntry = null, int? sequenceMasteryCount = null, int? hits = null, int? homeRuns = null)
        { ScenarioNumber = scenarioNumber; Pitches = pitches; Strikeouts = strikeouts; Walks = walks; RunsAllowed = runsAllowed; ExpectedDamage = expectedDamage; ActualDamage = actualDamage; RecommendationAccepted = recommendationAccepted; Outs = outs; TeamRuns = teamRuns; ScoreDifferentialAtEntry = scoreDifferentialAtEntry; SequenceMasteryCount = sequenceMasteryCount; Hits = hits; HomeRuns = homeRuns; }
        public int ScenarioNumber { get; } public int Pitches { get; } public int Strikeouts { get; } public int Walks { get; } public int RunsAllowed { get; }
        public int ExpectedDamage { get; } public int ActualDamage { get; } public int RecommendationAccepted { get; }
        public int? Outs { get; } public int? TeamRuns { get; } public int? ScoreDifferentialAtEntry { get; } public int? SequenceMasteryCount { get; } public int? Hits { get; } public int? HomeRuns { get; }
    }

    public sealed class CareerPerformanceSnapshot
    {
        public CareerPerformanceSnapshot(int importantGamesCompleted = 0, int pitches = 0, int strikeouts = 0, int walks = 0, int runsAllowed = 0, int expectedDamage = 0, int actualDamage = 0, int? outs = null, int? hits = null)
        { ImportantGamesCompleted = importantGamesCompleted; Pitches = pitches; Strikeouts = strikeouts; Walks = walks; RunsAllowed = runsAllowed; ExpectedDamage = expectedDamage; ActualDamage = actualDamage; Outs = outs; Hits = hits; }
        public int ImportantGamesCompleted { get; } public int Pitches { get; } public int Strikeouts { get; } public int Walks { get; }
        public int RunsAllowed { get; } public int ExpectedDamage { get; } public int ActualDamage { get; } public int? Outs { get; } public int? Hits { get; }
        public CareerPerformanceSnapshot Adding(ImportantInningReport report) => new CareerPerformanceSnapshot(ImportantGamesCompleted + 1, Pitches + report.Pitches, Strikeouts + report.Strikeouts, Walks + report.Walks, RunsAllowed + report.RunsAllowed, ExpectedDamage + report.ExpectedDamage, ActualDamage + report.ActualDamage, (Outs ?? 0) + (report.Outs ?? 0), (Hits ?? 0) + (report.Hits ?? 0));
    }

    public sealed class CreationAllocationSnapshot
    {
        public CreationAllocationSnapshot(int stuff, int command, int movement, int stamina) { Stuff = stuff; Command = command; Movement = movement; Stamina = stamina; }
        public int Stuff { get; } public int Command { get; } public int Movement { get; } public int Stamina { get; }
        public int Total => Stuff + Command + Movement + Stamina;
        public static CreationAllocationSnapshot Balanced { get; } = new CreationAllocationSnapshot(2, 1, 1, 1);
    }

    public sealed class TrainingOpportunitySnapshot
    {
        public TrainingOpportunitySnapshot(TrainingFocus focus, string reason) { Focus = focus; Reason = reason; }
        public TrainingFocus Focus { get; } public string Reason { get; }
    }

    public sealed class CareerTrainingSnapshot
    {
        public CareerTrainingSnapshot(int number, TrainingFocus focus, TrainingIntensity intensity, int growth, int fatigueChange, string feedback, int? metricBefore = null, int? metricAfter = null, int? fatigueBefore = null, int? fatigueAfter = null, bool? opportunityHit = null, TalentAbility? bloomedAbility = null, TalentGrade? bloomedGrade = null, bool? jackpot = null, PitchType? targetPitch = null)
        { Number = number; Focus = focus; Intensity = intensity; Growth = growth; FatigueChange = fatigueChange; Feedback = feedback; MetricBefore = metricBefore; MetricAfter = metricAfter; FatigueBefore = fatigueBefore; FatigueAfter = fatigueAfter; OpportunityHit = opportunityHit; BloomedAbility = bloomedAbility; BloomedGrade = bloomedGrade; Jackpot = jackpot; TargetPitch = targetPitch; }
        public int Number { get; } public TrainingFocus Focus { get; } public TrainingIntensity Intensity { get; } public int Growth { get; } public int FatigueChange { get; } public string Feedback { get; }
        public int? MetricBefore { get; } public int? MetricAfter { get; } public int? FatigueBefore { get; } public int? FatigueAfter { get; } public bool? OpportunityHit { get; }
        public TalentAbility? BloomedAbility { get; } public TalentGrade? BloomedGrade { get; } public bool? Jackpot { get; } public PitchType? TargetPitch { get; }
    }

    public sealed class CareerTrainingBlockSnapshot
    {
        public CareerTrainingBlockSnapshot(
            int maximumSessions,
            int completedSessions,
            TrainingFocus focus,
            TrainingIntensity intensity,
            PitchType? targetPitch,
            TrainingBlockStopReason stopReason,
            int growth,
            int fatigueChange,
            IReadOnlyList<CareerTrainingSnapshot> sessions = null)
        {
            MaximumSessions = maximumSessions;
            CompletedSessions = completedSessions;
            Focus = focus;
            Intensity = intensity;
            TargetPitch = targetPitch;
            StopReason = stopReason;
            Growth = growth;
            FatigueChange = fatigueChange;
            Sessions = (sessions ?? Array.Empty<CareerTrainingSnapshot>()).ToArray();
        }

        public int MaximumSessions { get; }
        public int CompletedSessions { get; }
        public TrainingFocus Focus { get; }
        public TrainingIntensity Intensity { get; }
        public PitchType? TargetPitch { get; }
        public TrainingBlockStopReason StopReason { get; }
        public int Growth { get; }
        public int FatigueChange { get; }
        public IReadOnlyList<CareerTrainingSnapshot> Sessions { get; }
    }

    public sealed class CareerRelationshipResultSnapshot
    {
        public CareerRelationshipResultSnapshot(int number, string category, string title, RelationshipResponse response, int trustBefore, int trustAfter, int fatigueBefore, int fatigueAfter, int fanInterestBefore, int fanInterestAfter, TrainingFocus? growthFocus, int? abilityBefore, int? abilityAfter, string feedback)
        { Number = number; Category = category; Title = title; Response = response; TrustBefore = trustBefore; TrustAfter = trustAfter; FatigueBefore = fatigueBefore; FatigueAfter = fatigueAfter; FanInterestBefore = fanInterestBefore; FanInterestAfter = fanInterestAfter; GrowthFocus = growthFocus; AbilityBefore = abilityBefore; AbilityAfter = abilityAfter; Feedback = feedback; }
        public int Number { get; } public string Category { get; } public string Title { get; } public RelationshipResponse Response { get; }
        public int TrustBefore { get; } public int TrustAfter { get; } public int FatigueBefore { get; } public int FatigueAfter { get; }
        public int FanInterestBefore { get; } public int FanInterestAfter { get; } public TrainingFocus? GrowthFocus { get; }
        public int? AbilityBefore { get; } public int? AbilityAfter { get; } public string Feedback { get; }
    }

    public sealed class CareerScheduleSnapshot
    {
        public CareerScheduleSnapshot(IReadOnlyList<int> trainingsByChapter, IReadOnlyList<IReadOnlyList<HighSchoolCareerPhase>> milestonesByChapter)
        { TrainingsByChapter = trainingsByChapter.ToArray(); MilestonesByChapter = milestonesByChapter.Select(x => (IReadOnlyList<HighSchoolCareerPhase>)x.ToArray()).ToArray(); }
        public IReadOnlyList<int> TrainingsByChapter { get; }
        public IReadOnlyList<IReadOnlyList<HighSchoolCareerPhase>> MilestonesByChapter { get; }
        public int TrainingTotal => TrainingsByChapter.Sum();
        public int RelationshipTotal => Count(HighSchoolCareerPhase.Relationship);
        public int ImportantGameTotal => Count(HighSchoolCareerPhase.ImportantGame);
        public int AwakeningTotal => Count(HighSchoolCareerPhase.Awakening);
        public bool HasImportantGame(int chapterNumber) => chapterNumber >= 1 && chapterNumber <= MilestonesByChapter.Count && MilestonesByChapter[chapterNumber - 1].Contains(HighSchoolCareerPhase.ImportantGame);
        public string CommitmentToken => string.Join(",", TrainingsByChapter) + "|" + string.Join(";", MilestonesByChapter.Select(x => string.Join(",", x.Select(y => y.Value()))));
        private int Count(HighSchoolCareerPhase phase) => MilestonesByChapter.Sum(x => x.Count(y => y == phase));
        public static CareerScheduleSnapshot FixedDefault { get; } = new CareerScheduleSnapshot(
            new[] { 2, 2, 2, 2, 2, 2, 2, 2 },
            new IReadOnlyList<HighSchoolCareerPhase>[] {
                new[]{HighSchoolCareerPhase.Relationship}, new[]{HighSchoolCareerPhase.Relationship,HighSchoolCareerPhase.ImportantGame},
                new[]{HighSchoolCareerPhase.Awakening,HighSchoolCareerPhase.ImportantGame}, new[]{HighSchoolCareerPhase.Relationship,HighSchoolCareerPhase.ImportantGame},
                new[]{HighSchoolCareerPhase.Relationship}, new[]{HighSchoolCareerPhase.Awakening,HighSchoolCareerPhase.ImportantGame},
                new[]{HighSchoolCareerPhase.Relationship}, new[]{HighSchoolCareerPhase.Awakening,HighSchoolCareerPhase.ImportantGame} });
    }

    public sealed class DraftTeamSnapshot
    {
        public DraftTeamSnapshot(string id, string name, TrainingFocus need, int demand, string developmentPlan, string positionCompetitor, string proCoach, string competitorProfile = null, string competitorRecord = null, string coachProfile = null, string coachRecord = null)
        { Id=id;Name=name;Need=need;Demand=demand;DevelopmentPlan=developmentPlan;PositionCompetitor=positionCompetitor;ProCoach=proCoach;CompetitorProfile=competitorProfile;CompetitorRecord=competitorRecord;CoachProfile=coachProfile;CoachRecord=coachRecord; }
        public string Id {get;} public string Name {get;} public TrainingFocus Need {get;} public int Demand {get;} public string DevelopmentPlan {get;} public string PositionCompetitor {get;} public string ProCoach {get;} public string CompetitorProfile {get;} public string CompetitorRecord {get;} public string CoachProfile {get;} public string CoachRecord {get;}
    }

    public sealed class DraftResultSnapshot
    {
        public DraftResultSnapshot(DraftOutcome outcome, int evaluationScore, string projectedRange, DraftTeamSnapshot team, int? round, int? overallPick, int? signingBonus, string firstSeasonGoal, IReadOnlyList<string> evaluationBreakdown, string summary)
        { Outcome=outcome;EvaluationScore=evaluationScore;ProjectedRange=projectedRange;Team=team;Round=round;OverallPick=overallPick;SigningBonus=signingBonus;FirstSeasonGoal=firstSeasonGoal;EvaluationBreakdown=evaluationBreakdown;Summary=summary; }
        public DraftOutcome Outcome{get;} public int EvaluationScore{get;} public string ProjectedRange{get;} public DraftTeamSnapshot Team{get;} public int? Round{get;} public int? OverallPick{get;} public int? SigningBonus{get;} public string FirstSeasonGoal{get;} public IReadOnlyList<string> EvaluationBreakdown{get;} public string Summary{get;}
    }
}
