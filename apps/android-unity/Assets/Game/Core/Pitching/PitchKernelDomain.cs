using System;
using System.Collections.Generic;
using Baseball.Core.Domain;

namespace Baseball.Core.Pitching
{
    public enum ZoneIntent { Strike, Edge, Chase }
    public enum SelectionQuality { Poor, Risky, Good, Excellent }
    public enum PlateAppearanceResult { Strikeout, Walk, InPlayOut, Hit }

    public static class PitchingWire
    {
        public static string Value(this ZoneIntent value)
        {
            switch (value)
            {
                case ZoneIntent.Strike: return "strike";
                case ZoneIntent.Edge: return "edge";
                case ZoneIntent.Chase: return "chase";
                default: throw new ArgumentOutOfRangeException(nameof(value));
            }
        }

        public static string Value(this SelectionQuality value)
        {
            switch (value)
            {
                case SelectionQuality.Poor: return "poor";
                case SelectionQuality.Risky: return "risky";
                case SelectionQuality.Good: return "good";
                case SelectionQuality.Excellent: return "excellent";
                default: throw new ArgumentOutOfRangeException(nameof(value));
            }
        }

        public static string Value(this PlateAppearanceResult value)
        {
            switch (value)
            {
                case PlateAppearanceResult.Strikeout: return "strikeout";
                case PlateAppearanceResult.Walk: return "walk";
                case PlateAppearanceResult.InPlayOut: return "in_play_out";
                case PlateAppearanceResult.Hit: return "hit";
                default: throw new ArgumentOutOfRangeException(nameof(value));
            }
        }
    }

    public static class ZoneIntentRules
    {
        public static IReadOnlyList<ZoneIntent> Options(PitchZone zone)
        {
            return zone.Row == 1 && zone.Column == 1
                ? new[] { ZoneIntent.Strike, ZoneIntent.Chase }
                : new[] { ZoneIntent.Strike, ZoneIntent.Edge, ZoneIntent.Chase };
        }

        public static ZoneIntent Clamp(ZoneIntent intent, PitchZone zone)
        {
            return zone.Row == 1 && zone.Column == 1 && intent == ZoneIntent.Edge
                ? ZoneIntent.Strike
                : intent;
        }
    }

    public sealed class PitchCall : IEquatable<PitchCall>
    {
        public PitchCall(PitchType pitchType, PitchZone zone, ZoneIntent zoneIntent, PitchIntensity intensity)
        {
            PitchType = pitchType;
            Zone = zone;
            ZoneIntent = zoneIntent;
            Intensity = intensity;
        }

        public PitchType PitchType { get; }
        public PitchZone Zone { get; }
        public ZoneIntent ZoneIntent { get; }
        public PitchIntensity Intensity { get; }

        public bool Equals(PitchCall other)
        {
            return other != null && PitchType == other.PitchType && Zone == other.Zone &&
                   ZoneIntent == other.ZoneIntent && Intensity == other.Intensity;
        }

        public override bool Equals(object obj) => Equals(obj as PitchCall);
        public override int GetHashCode() => unchecked((((int)PitchType * 397) ^ Zone.GetHashCode()) * 397 ^ (int)ZoneIntent);
    }

    public sealed class BatterScoutingSnapshot
    {
        public BatterScoutingSnapshot(
            PitchZone hotZone,
            PitchZone coldZone,
            PitchType pitchStrength,
            PitchType pitchWeakness,
            int chaseTendency,
            int reliability = ScoutingEstimate.TrustedReliability)
        {
            HotZone = hotZone;
            ColdZone = coldZone;
            PitchStrength = pitchStrength;
            PitchWeakness = pitchWeakness;
            ChaseTendency = chaseTendency;
            Reliability = reliability;
        }

        public PitchZone HotZone { get; }
        public PitchZone ColdZone { get; }
        public PitchType PitchStrength { get; }
        public PitchType PitchWeakness { get; }
        public int ChaseTendency { get; }
        public int Reliability { get; }
    }

    public sealed class ScoutingReportSnapshot
    {
        public ScoutingReportSnapshot(
            int reliability,
            int observationCount,
            string band,
            PitchType estimatedWeakness,
            PitchZone estimatedColdZone,
            PitchType? estimatedStrength,
            PitchZone? estimatedHotZone,
            int estimatedChaseTendency,
            int chaseTendencyMargin)
        {
            Reliability = reliability;
            ObservationCount = observationCount;
            Band = band;
            EstimatedWeakness = estimatedWeakness;
            EstimatedColdZone = estimatedColdZone;
            EstimatedStrength = estimatedStrength;
            EstimatedHotZone = estimatedHotZone;
            EstimatedChaseTendency = estimatedChaseTendency;
            ChaseTendencyMargin = chaseTendencyMargin;
        }

        public int Reliability { get; }
        public int ObservationCount { get; }
        public string Band { get; }
        public PitchType EstimatedWeakness { get; }
        public PitchZone EstimatedColdZone { get; }
        public PitchType? EstimatedStrength { get; }
        public PitchZone? EstimatedHotZone { get; }
        public int EstimatedChaseTendency { get; }
        public int ChaseTendencyMargin { get; }
    }

    public sealed class PlateAppearanceContext
    {
        public PlateAppearanceContext(
            string plateAppearanceId,
            ulong revision,
            int inning,
            int outs,
            int balls,
            int strikes,
            int pitchNumber,
            int scoreDifferential,
            int leverage,
            int fatigue)
        {
            PlateAppearanceId = plateAppearanceId;
            Revision = revision;
            Inning = inning;
            Outs = outs;
            Balls = balls;
            Strikes = strikes;
            PitchNumber = pitchNumber;
            ScoreDifferential = scoreDifferential;
            Leverage = leverage;
            Fatigue = fatigue;
        }

        public string PlateAppearanceId { get; }
        public ulong Revision { get; }
        public int Inning { get; }
        public int Outs { get; }
        public int Balls { get; }
        public int Strikes { get; }
        public int PitchNumber { get; }
        public int ScoreDifferential { get; }
        public int Leverage { get; }
        public int Fatigue { get; }
    }

    public sealed class PreparePitchParams
    {
        public PreparePitchParams(
            string seed,
            PitcherSnapshot pitcher,
            BatterSnapshot batter,
            BatterScoutingSnapshot scouting,
            PlateAppearanceContext context,
            RivalMemorySnapshot rivalMemory = null,
            GameStateSnapshot gameState = null,
            GameLogSnapshot gameLog = null)
        {
            Seed = seed;
            Pitcher = pitcher;
            Batter = batter;
            Scouting = scouting;
            Context = context;
            RivalMemory = rivalMemory;
            GameState = gameState;
            GameLog = gameLog;
        }

        public string Seed { get; }
        public PitcherSnapshot Pitcher { get; }
        public BatterSnapshot Batter { get; }
        public BatterScoutingSnapshot Scouting { get; }
        public PlateAppearanceContext Context { get; }
        public RivalMemorySnapshot RivalMemory { get; }
        public GameStateSnapshot GameState { get; }
        public GameLogSnapshot GameLog { get; }
    }

    public sealed class SubmitPitchParams
    {
        public SubmitPitchParams(
            string seed,
            PitcherSnapshot pitcher,
            BatterSnapshot batter,
            BatterScoutingSnapshot scouting,
            PlateAppearanceContext context,
            string preparationToken,
            PitchCall call,
            RivalMemorySnapshot rivalMemory = null,
            GameStateSnapshot gameState = null,
            GameLogSnapshot gameLog = null,
            PersonalityTrait? trait = null)
        {
            Seed = seed;
            Pitcher = pitcher;
            Batter = batter;
            Scouting = scouting;
            Context = context;
            PreparationToken = preparationToken;
            Call = call;
            RivalMemory = rivalMemory;
            GameState = gameState;
            GameLog = gameLog;
            Trait = trait;
        }

        public string Seed { get; }
        public PitcherSnapshot Pitcher { get; }
        public BatterSnapshot Batter { get; }
        public BatterScoutingSnapshot Scouting { get; }
        public PlateAppearanceContext Context { get; }
        public string PreparationToken { get; }
        public PitchCall Call { get; }
        public RivalMemorySnapshot RivalMemory { get; }
        public GameStateSnapshot GameState { get; }
        public GameLogSnapshot GameLog { get; }
        public PersonalityTrait? Trait { get; }
    }

    public sealed class CatcherRecommendation
    {
        public CatcherRecommendation(PitchCall call, int confidence, IReadOnlyList<string> reasonCodes)
        {
            Call = call;
            Confidence = confidence;
            ReasonCodes = reasonCodes;
        }

        public PitchCall Call { get; }
        public int Confidence { get; }
        public IReadOnlyList<string> ReasonCodes { get; }
    }

    public sealed class CatcherRecommendationSnapshot
    {
        public CatcherRecommendationSnapshot(PitchCall call, int confidence, IReadOnlyList<string> reasonCodes, string shortReason)
        {
            Call = call;
            Confidence = confidence;
            ReasonCodes = reasonCodes;
            ShortReason = shortReason;
        }

        public PitchCall Call { get; }
        public int Confidence { get; }
        public IReadOnlyList<string> ReasonCodes { get; }
        public string ShortReason { get; }
    }

    public sealed class PitchPreparation
    {
        public PitchPreparation(
            string seed,
            ulong revision,
            int pitchNumber,
            string preparationToken,
            string planCommitment,
            CatcherRecommendationSnapshot primaryRecommendation,
            CatcherRecommendationSnapshot alternativeRecommendation,
            RivalAdaptationSnapshot rivalAdaptation,
            ScoutingReportSnapshot scoutingReport)
        {
            Seed = seed;
            Revision = revision;
            PitchNumber = pitchNumber;
            PreparationToken = preparationToken;
            PlanCommitment = planCommitment;
            PrimaryRecommendation = primaryRecommendation;
            AlternativeRecommendation = alternativeRecommendation;
            RivalAdaptation = rivalAdaptation;
            ScoutingReport = scoutingReport;
        }

        public string Seed { get; }
        public ulong Revision { get; }
        public int PitchNumber { get; }
        public string PreparationToken { get; }
        public string PlanCommitment { get; }
        public CatcherRecommendationSnapshot PrimaryRecommendation { get; }
        public CatcherRecommendationSnapshot AlternativeRecommendation { get; }
        public RivalAdaptationSnapshot RivalAdaptation { get; }
        public ScoutingReportSnapshot ScoutingReport { get; }
    }

    public sealed class PitchExecution
    {
        public PitchExecution(
            int targetX, int targetY, int actualX, int actualY, int velocityTenthsKph,
            int horizontalBreakTenthsCm, int verticalBreakTenthsCm, int executionQuality,
            int? flightTimeMilliseconds = null, int? trajectoryControlX = null,
            int? trajectoryControlY = null, IReadOnlyList<int> trajectorySeries = null)
        {
            TargetX = targetX;
            TargetY = targetY;
            ActualX = actualX;
            ActualY = actualY;
            VelocityTenthsKph = velocityTenthsKph;
            HorizontalBreakTenthsCm = horizontalBreakTenthsCm;
            VerticalBreakTenthsCm = verticalBreakTenthsCm;
            ExecutionQuality = executionQuality;
            FlightTimeMilliseconds = flightTimeMilliseconds;
            TrajectoryControlX = trajectoryControlX;
            TrajectoryControlY = trajectoryControlY;
            TrajectorySeries = trajectorySeries;
        }

        public int TargetX { get; }
        public int TargetY { get; }
        public int ActualX { get; }
        public int ActualY { get; }
        public int VelocityTenthsKph { get; }
        public int HorizontalBreakTenthsCm { get; }
        public int VerticalBreakTenthsCm { get; }
        public int ExecutionQuality { get; }
        public int? FlightTimeMilliseconds { get; }
        public int? TrajectoryControlX { get; }
        public int? TrajectoryControlY { get; }
        public IReadOnlyList<int> TrajectorySeries { get; }
    }

    public sealed class BattedBall
    {
        public BattedBall(int exitVelocityTenthsKph, int launchAngleTenthsDegrees, int directionTenthsDegrees, int contactQuality)
        {
            ExitVelocityTenthsKph = exitVelocityTenthsKph;
            LaunchAngleTenthsDegrees = launchAngleTenthsDegrees;
            DirectionTenthsDegrees = directionTenthsDegrees;
            ContactQuality = contactQuality;
        }

        public int ExitVelocityTenthsKph { get; }
        public int LaunchAngleTenthsDegrees { get; }
        public int DirectionTenthsDegrees { get; }
        public int ContactQuality { get; }
    }

    public sealed class PitchKernelEvent
    {
        public PitchKernelEvent(
            string eventType,
            int sequence,
            string planCommitment = null,
            CatcherRecommendation primaryRecommendation = null,
            CatcherRecommendation alternativeRecommendation = null,
            PitchCall call = null,
            PitchExecution execution = null,
            PitchOutcome? outcome = null,
            BattedBall battedBall = null,
            FieldingResolutionSnapshot fieldingResolution = null,
            BaserunnerAdvanceSnapshot baserunnerAdvance = null,
            StealAttemptSnapshot stealAttempt = null,
            InningTransitionSnapshot inningTransition = null,
            PlateAppearanceResult? plateAppearanceResult = null,
            RivalAdaptationSnapshot rivalAdaptation = null,
            PostgameAnalysisSnapshot postgameAnalysis = null,
            IReadOnlyList<string> reasonCodes = null)
        {
            EventType = eventType;
            Sequence = sequence;
            PlanCommitment = planCommitment;
            PrimaryRecommendation = primaryRecommendation;
            AlternativeRecommendation = alternativeRecommendation;
            Call = call;
            Execution = execution;
            Outcome = outcome;
            BattedBall = battedBall;
            FieldingResolution = fieldingResolution;
            BaserunnerAdvance = baserunnerAdvance;
            StealAttempt = stealAttempt;
            InningTransition = inningTransition;
            PlateAppearanceResult = plateAppearanceResult;
            RivalAdaptation = rivalAdaptation;
            PostgameAnalysis = postgameAnalysis;
            ReasonCodes = reasonCodes ?? Array.Empty<string>();
        }

        public string EventType { get; }
        public int Sequence { get; }
        public string PlanCommitment { get; }
        public CatcherRecommendation PrimaryRecommendation { get; }
        public CatcherRecommendation AlternativeRecommendation { get; }
        public PitchCall Call { get; }
        public PitchExecution Execution { get; }
        public PitchOutcome? Outcome { get; }
        public BattedBall BattedBall { get; }
        public FieldingResolutionSnapshot FieldingResolution { get; }
        public BaserunnerAdvanceSnapshot BaserunnerAdvance { get; }
        public StealAttemptSnapshot StealAttempt { get; }
        public InningTransitionSnapshot InningTransition { get; }
        public PlateAppearanceResult? PlateAppearanceResult { get; }
        public RivalAdaptationSnapshot RivalAdaptation { get; }
        public PostgameAnalysisSnapshot PostgameAnalysis { get; }
        public IReadOnlyList<string> ReasonCodes { get; }
    }

    public sealed class PlateAppearanceSnapshot
    {
        public PlateAppearanceSnapshot(
            ulong revision, int balls, int strikes, int pitchNumber, bool ended,
            PlateAppearanceResult? result, PitchOutcome outcome, SelectionQuality selectionQuality,
            bool recommendationAccepted, int fatigueAfterPitch, PitchExecution execution,
            BattedBall battedBall, FieldingResolutionSnapshot fieldingResolution,
            BaserunnerStateSnapshot runnersBefore, BaserunnerStateSnapshot runnersAfter,
            int runsScored, StealAttemptSnapshot stealAttempt, InningTransitionSnapshot inningTransition,
            IReadOnlyList<string> reasonCodes, string shortFeedback, string detailFeedback,
            string accessibilitySummary)
        {
            Revision = revision;
            Balls = balls;
            Strikes = strikes;
            PitchNumber = pitchNumber;
            Ended = ended;
            Result = result;
            Outcome = outcome;
            SelectionQuality = selectionQuality;
            RecommendationAccepted = recommendationAccepted;
            FatigueAfterPitch = fatigueAfterPitch;
            Execution = execution;
            BattedBall = battedBall;
            FieldingResolution = fieldingResolution;
            RunnersBefore = runnersBefore;
            RunnersAfter = runnersAfter;
            RunsScored = runsScored;
            StealAttempt = stealAttempt;
            InningTransition = inningTransition;
            ReasonCodes = reasonCodes;
            ShortFeedback = shortFeedback;
            DetailFeedback = detailFeedback;
            AccessibilitySummary = accessibilitySummary;
        }

        public ulong Revision { get; }
        public int Balls { get; }
        public int Strikes { get; }
        public int PitchNumber { get; }
        public bool Ended { get; }
        public PlateAppearanceResult? Result { get; }
        public PitchOutcome Outcome { get; }
        public SelectionQuality SelectionQuality { get; }
        public bool RecommendationAccepted { get; }
        public int FatigueAfterPitch { get; }
        public PitchExecution Execution { get; }
        public BattedBall BattedBall { get; }
        public FieldingResolutionSnapshot FieldingResolution { get; }
        public BaserunnerStateSnapshot RunnersBefore { get; }
        public BaserunnerStateSnapshot RunnersAfter { get; }
        public int RunsScored { get; }
        public StealAttemptSnapshot StealAttempt { get; }
        public InningTransitionSnapshot InningTransition { get; }
        public IReadOnlyList<string> ReasonCodes { get; }
        public string ShortFeedback { get; }
        public string DetailFeedback { get; }
        public string AccessibilitySummary { get; }
    }

    public sealed class PitchKernelResult
    {
        public PitchKernelResult(
            ulong revision,
            string nextSeed,
            PlateAppearanceSnapshot snapshot,
            PitchPreparation nextPreparation,
            RivalMemorySnapshot rivalMemory,
            RivalAdaptationSnapshot rivalAdaptation,
            GameStateSnapshot gameState,
            GameLogSnapshot gameLog,
            PostgameAnalysisSnapshot postgameAnalysis,
            string eventHash,
            IReadOnlyList<PitchKernelEvent> events)
        {
            Revision = revision;
            NextSeed = nextSeed;
            Snapshot = snapshot;
            NextPreparation = nextPreparation;
            RivalMemory = rivalMemory;
            RivalAdaptation = rivalAdaptation;
            GameState = gameState;
            GameLog = gameLog;
            PostgameAnalysis = postgameAnalysis;
            EventHash = eventHash;
            Events = events;
        }

        public ulong Revision { get; }
        public string NextSeed { get; }
        public PlateAppearanceSnapshot Snapshot { get; }
        public PitchPreparation NextPreparation { get; }
        public RivalMemorySnapshot RivalMemory { get; }
        public RivalAdaptationSnapshot RivalAdaptation { get; }
        public GameStateSnapshot GameState { get; }
        public GameLogSnapshot GameLog { get; }
        public PostgameAnalysisSnapshot PostgameAnalysis { get; }
        public string EventHash { get; }
        public IReadOnlyList<PitchKernelEvent> Events { get; }
        public IReadOnlyList<string> EventTypes
        {
            get
            {
                var values = new string[Events.Count];
                for (var index = 0; index < Events.Count; index++) values[index] = Events[index].EventType;
                return values;
            }
        }
    }
}
