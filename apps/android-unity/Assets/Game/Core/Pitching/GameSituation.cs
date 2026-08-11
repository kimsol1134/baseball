using System;
using System.Collections.Generic;
using System.Linq;
using Baseball.Core.Domain;
using Baseball.Core.Random;

namespace Baseball.Core.Pitching
{
    public enum FieldingSector { Infield, Outfield, Fence }
    public enum DefenseImpact { HelpedPitcher, Neutral, HurtPitcher }
    public enum AnalysisConfidenceBand { Low, Developing, Reliable }
    public enum FielderPosition
    {
        Pitcher, Catcher, FirstBase, SecondBase, ThirdBase, Shortstop, LeftField, CenterField, RightField
    }
    public enum HalfInning { Top, Bottom }

    public static class BattedBallBands
    {
        public const int SingleFloor = 500;
        public const int DoubleFloor = 620;
        public const int HomeRunFloor = 775;

        public static PitchOutcome Outcome(int quality)
        {
            if (quality < SingleFloor) return PitchOutcome.InPlayOut;
            if (quality < DoubleFloor) return PitchOutcome.Single;
            if (quality < HomeRunFloor) return PitchOutcome.Double;
            return PitchOutcome.HomeRun;
        }
    }

    public sealed class FielderSnapshot
    {
        public FielderSnapshot(string id, string name, FielderPosition position, int range, int glove, int arm)
        {
            Id = id; Name = name; Position = position; Range = range; Glove = glove; Arm = arm;
        }
        public string Id { get; }
        public string Name { get; }
        public FielderPosition Position { get; }
        public int Range { get; }
        public int Glove { get; }
        public int Arm { get; }
    }

    public sealed class DefenseSnapshot
    {
        public DefenseSnapshot(int infield, int outfield, int arm, IReadOnlyList<FielderSnapshot> fielders = null)
        {
            Infield = infield; Outfield = outfield; Arm = arm; Fielders = fielders;
        }
        public int Infield { get; }
        public int Outfield { get; }
        public int Arm { get; }
        public IReadOnlyList<FielderSnapshot> Fielders { get; }
        public FielderSnapshot Fielder(FielderPosition position) =>
            Fielders == null ? null : Fielders.FirstOrDefault(item => item.Position == position);
    }

    public sealed class ParkSnapshot
    {
        public ParkSnapshot(string id, string name, int hitFactor, int homeRunFactor)
        {
            Id = id; Name = name; HitFactor = hitFactor; HomeRunFactor = homeRunFactor;
        }
        public string Id { get; }
        public string Name { get; }
        public int HitFactor { get; }
        public int HomeRunFactor { get; }
    }

    public struct BaserunnerStateSnapshot : IEquatable<BaserunnerStateSnapshot>
    {
        public BaserunnerStateSnapshot(bool firstOccupied, bool secondOccupied, bool thirdOccupied, int leadRunnerSpeed)
        {
            FirstOccupied = firstOccupied; SecondOccupied = secondOccupied;
            ThirdOccupied = thirdOccupied; LeadRunnerSpeed = leadRunnerSpeed;
        }
        public bool FirstOccupied { get; }
        public bool SecondOccupied { get; }
        public bool ThirdOccupied { get; }
        public int LeadRunnerSpeed { get; }
        public int OccupiedCount => (FirstOccupied ? 1 : 0) + (SecondOccupied ? 1 : 0) + (ThirdOccupied ? 1 : 0);
        public static BaserunnerStateSnapshot Empty => new BaserunnerStateSnapshot(false, false, false, 50);
        public bool Equals(BaserunnerStateSnapshot other) => FirstOccupied == other.FirstOccupied &&
            SecondOccupied == other.SecondOccupied && ThirdOccupied == other.ThirdOccupied &&
            LeadRunnerSpeed == other.LeadRunnerSpeed;
        public override bool Equals(object obj) => obj is BaserunnerStateSnapshot other && Equals(other);
        public override int GetHashCode() => unchecked((((FirstOccupied ? 1 : 0) * 397 + (SecondOccupied ? 1 : 0)) * 397 + (ThirdOccupied ? 1 : 0)) * 397 + LeadRunnerSpeed);
        public static bool operator ==(BaserunnerStateSnapshot left, BaserunnerStateSnapshot right) => left.Equals(right);
        public static bool operator !=(BaserunnerStateSnapshot left, BaserunnerStateSnapshot right) => !left.Equals(right);
    }

    public struct InningStateSnapshot
    {
        public InningStateSnapshot(int inning, HalfInning half, int outs)
        {
            Inning = inning; Half = half; Outs = outs;
        }
        public int Inning { get; }
        public HalfInning Half { get; }
        public int Outs { get; }
    }

    public sealed class GameStateSnapshot
    {
        public GameStateSnapshot(
            DefenseSnapshot defense, ParkSnapshot park, BaserunnerStateSnapshot runners,
            int runsAllowed, InningStateSnapshot? inningState = null)
        {
            Defense = defense; Park = park; Runners = runners; RunsAllowed = runsAllowed; InningState = inningState;
        }
        public DefenseSnapshot Defense { get; }
        public ParkSnapshot Park { get; }
        public BaserunnerStateSnapshot Runners { get; }
        public int RunsAllowed { get; }
        public InningStateSnapshot? InningState { get; }
        public static GameStateSnapshot Standard => new GameStateSnapshot(
            new DefenseSnapshot(50, 50, 50),
            new ParkSnapshot("neutral-park", "중립 구장", 1000, 1000),
            BaserunnerStateSnapshot.Empty, 0);
    }

    public sealed class FieldingResolutionSnapshot
    {
        public FieldingResolutionSnapshot(
            PitchOutcome neutralOutcome, PitchOutcome finalOutcome, FieldingSector sector,
            int difficulty, int defenseRating, int defenseAdjustment, int parkAdjustment,
            DefenseImpact impact, FielderPosition? fielderPosition, string fielderName,
            int? landingDistanceTenthsMeters, int? hangTimeMilliseconds,
            int? apexHeightTenthsMeters, IReadOnlyList<int> ballFlightSeries, string shortExplanation)
        {
            NeutralOutcome = neutralOutcome; FinalOutcome = finalOutcome; Sector = sector;
            Difficulty = difficulty; DefenseRating = defenseRating; DefenseAdjustment = defenseAdjustment;
            ParkAdjustment = parkAdjustment; Impact = impact; FielderPosition = fielderPosition;
            FielderName = fielderName; LandingDistanceTenthsMeters = landingDistanceTenthsMeters;
            HangTimeMilliseconds = hangTimeMilliseconds; ApexHeightTenthsMeters = apexHeightTenthsMeters;
            BallFlightSeries = ballFlightSeries; ShortExplanation = shortExplanation;
        }
        public PitchOutcome NeutralOutcome { get; }
        public PitchOutcome FinalOutcome { get; }
        public FieldingSector Sector { get; }
        public int Difficulty { get; }
        public int DefenseRating { get; }
        public int DefenseAdjustment { get; }
        public int ParkAdjustment { get; }
        public DefenseImpact Impact { get; }
        public FielderPosition? FielderPosition { get; }
        public string FielderName { get; }
        public int? LandingDistanceTenthsMeters { get; }
        public int? HangTimeMilliseconds { get; }
        public int? ApexHeightTenthsMeters { get; }
        public IReadOnlyList<int> BallFlightSeries { get; }
        public string ShortExplanation { get; }
    }

    public sealed class StealAttemptSnapshot
    {
        public StealAttemptSnapshot(int fromBase, int toBase, int runnerSpeed, int catcherArm, bool succeeded, string explanation)
        {
            FromBase = fromBase; ToBase = toBase; RunnerSpeed = runnerSpeed;
            CatcherArm = catcherArm; Succeeded = succeeded; ShortExplanation = explanation;
        }
        public int FromBase { get; }
        public int ToBase { get; }
        public int RunnerSpeed { get; }
        public int CatcherArm { get; }
        public bool Succeeded { get; }
        public string ShortExplanation { get; }
    }

    public sealed class InningTransitionSnapshot
    {
        public InningTransitionSnapshot(InningStateSnapshot before, InningStateSnapshot after,
            int outsRecorded, bool doublePlayCompleted, bool inningEnded, string explanation)
        {
            Before = before; After = after; OutsRecorded = outsRecorded;
            DoublePlayCompleted = doublePlayCompleted; InningEnded = inningEnded; ShortExplanation = explanation;
        }
        public InningStateSnapshot Before { get; }
        public InningStateSnapshot After { get; }
        public int OutsRecorded { get; }
        public bool DoublePlayCompleted { get; }
        public bool InningEnded { get; }
        public string ShortExplanation { get; }
    }

    public sealed class BaserunnerAdvanceSnapshot
    {
        public BaserunnerAdvanceSnapshot(BaserunnerStateSnapshot before, BaserunnerStateSnapshot after, int runsScored, string explanation)
        {
            Before = before; After = after; RunsScored = runsScored; ShortExplanation = explanation;
        }
        public BaserunnerStateSnapshot Before { get; }
        public BaserunnerStateSnapshot After { get; }
        public int RunsScored { get; }
        public string ShortExplanation { get; }
    }

    public sealed class PitchAnalysisEntry
    {
        public PitchAnalysisEntry(PitchType pitchType, bool wasInZone, bool batterSwung, PitchOutcome outcome,
            SelectionQuality selectionQuality, int executionQuality, int? contactQuality,
            int expectedDamage, int actualDamage, bool recommendationAccepted, int? velocityTenthsKph = null)
        {
            PitchType = pitchType; WasInZone = wasInZone; BatterSwung = batterSwung; Outcome = outcome;
            SelectionQuality = selectionQuality; ExecutionQuality = executionQuality; ContactQuality = contactQuality;
            ExpectedDamage = expectedDamage; ActualDamage = actualDamage;
            RecommendationAccepted = recommendationAccepted; VelocityTenthsKph = velocityTenthsKph;
        }
        public PitchType PitchType { get; }
        public bool WasInZone { get; }
        public bool BatterSwung { get; }
        public PitchOutcome Outcome { get; }
        public SelectionQuality SelectionQuality { get; }
        public int ExecutionQuality { get; }
        public int? ContactQuality { get; }
        public int ExpectedDamage { get; }
        public int ActualDamage { get; }
        public bool RecommendationAccepted { get; }
        public int? VelocityTenthsKph { get; }
    }

    public sealed class GameLogSnapshot
    {
        public GameLogSnapshot(string gameId, ulong revision, int totalPitches, IReadOnlyList<PitchAnalysisEntry> entries)
        {
            GameId = gameId; Revision = revision; TotalPitches = totalPitches; Entries = entries;
        }
        public string GameId { get; }
        public ulong Revision { get; }
        public int TotalPitches { get; }
        public IReadOnlyList<PitchAnalysisEntry> Entries { get; }
    }

    public sealed class PitchAnalysisBreakdown
    {
        public PitchAnalysisBreakdown(PitchType pitchType, int pitches, int zoneRate, int whiffRate, int hardHitRate, int expectedDamage)
        {
            PitchType = pitchType; Pitches = pitches; ZoneRate = zoneRate;
            WhiffRate = whiffRate; HardHitRate = hardHitRate; ExpectedDamage = expectedDamage;
        }
        public PitchType PitchType { get; }
        public int Pitches { get; }
        public int ZoneRate { get; }
        public int WhiffRate { get; }
        public int HardHitRate { get; }
        public int ExpectedDamage { get; }
    }

    public sealed class PostgameAnalysisSnapshot
    {
        public PostgameAnalysisSnapshot(int sampleSize, AnalysisConfidenceBand confidence,
            int zoneRate, int whiffRate, int hardHitRate, int averageSelectionQuality,
            int averageExecutionQuality, int expectedDamage, int actualDamage,
            IReadOnlyList<PitchAnalysisBreakdown> pitchBreakdowns, string patternWarning, string growthSignal)
        {
            SampleSize = sampleSize; Confidence = confidence; ZoneRate = zoneRate; WhiffRate = whiffRate;
            HardHitRate = hardHitRate; AverageSelectionQuality = averageSelectionQuality;
            AverageExecutionQuality = averageExecutionQuality; ExpectedDamage = expectedDamage;
            ActualDamage = actualDamage; PitchBreakdowns = pitchBreakdowns;
            PatternWarning = patternWarning; GrowthSignal = growthSignal;
        }
        public int SampleSize { get; }
        public AnalysisConfidenceBand Confidence { get; }
        public int ZoneRate { get; }
        public int WhiffRate { get; }
        public int HardHitRate { get; }
        public int AverageSelectionQuality { get; }
        public int AverageExecutionQuality { get; }
        public int ExpectedDamage { get; }
        public int ActualDamage { get; }
        public IReadOnlyList<PitchAnalysisBreakdown> PitchBreakdowns { get; }
        public string PatternWarning { get; }
        public string GrowthSignal { get; }
    }

    public sealed class BallInPlayEngine
    {
        private const int TripleChance = 245;

        public FieldingResolutionSnapshot Resolve(BattedBall battedBall, GameStateSnapshot gameState, ulong seed, int ordinal)
        {
            var neutral = BattedBallBands.Outcome(battedBall.ContactQuality);
            var flight = Flight(battedBall);
            FieldingSector sector;
            if (battedBall.LaunchAngleTenthsDegrees < 90) sector = FieldingSector.Infield;
            else if (neutral == PitchOutcome.HomeRun || (battedBall.ContactQuality >= 700 &&
                     battedBall.LaunchAngleTenthsDegrees >= 150 && battedBall.LaunchAngleTenthsDegrees <= 350)) sector = FieldingSector.Fence;
            else sector = flight.DistanceTenthsMeters < 500 ? FieldingSector.Infield : FieldingSector.Outfield;

            var position = Position(sector, battedBall.DirectionTenthsDegrees);
            var fielder = gameState.Defense.Fielder(position);
            var aggregate = sector == FieldingSector.Infield ? gameState.Defense.Infield : gameState.Defense.Outfield;
            var defenseRating = fielder == null ? aggregate : (fielder.Range * 6 + fielder.Glove * 4) / 10;
            var defenseAdjustment = -(defenseRating - 50) * (sector == FieldingSector.Fence ? 1 : 4);
            var hitAdjustment = (gameState.Park.HitFactor - 1000) / 3;
            var homeRunAdjustment = neutral == PitchOutcome.HomeRun || battedBall.ContactQuality >= 720
                ? (gameState.Park.HomeRunFactor - 1000) / 2 : 0;
            var parkAdjustment = hitAdjustment + homeRunAdjustment;
            var generator = new SplitMix64(unchecked(seed ^ 0x4649454C44UL ^ ((ulong)ordinal * 0x9E3779B9UL)));
            var randomRange = sector == FieldingSector.Fence ? 81 : 241;
            var randomAdjustment = generator.NextInt(randomRange) - randomRange / 2;
            var adjusted = Clamp(battedBall.ContactQuality + defenseAdjustment + parkAdjustment + randomAdjustment, 0, 1000);
            var final = BattedBallBands.Outcome(adjusted);
            if (sector == FieldingSector.Infield && (final == PitchOutcome.Double || final == PitchOutcome.HomeRun)) final = PitchOutcome.Single;
            else if (sector == FieldingSector.Outfield && final == PitchOutcome.HomeRun) final = PitchOutcome.Double;
            if (final == PitchOutcome.Double && sector != FieldingSector.Infield && IsTripleShape(battedBall) && generator.NextInt(1000) < TripleChance)
                final = PitchOutcome.Triple;
            var impact = OutcomeValue(final) < OutcomeValue(neutral) ? DefenseImpact.HelpedPitcher :
                OutcomeValue(final) > OutcomeValue(neutral) ? DefenseImpact.HurtPitcher : DefenseImpact.Neutral;
            var explanation = impact == DefenseImpact.HelpedPitcher ? "수비 위치와 첫발이 안타성 타구의 결과를 낮췄습니다." :
                impact == DefenseImpact.HurtPitcher ? "수비 범위를 벗어난 타구가 더 큰 결과로 이어졌습니다." :
                "타구 강도에 걸맞은 결과가 나왔습니다.";
            return new FieldingResolutionSnapshot(neutral, final, sector,
                Clamp(1000 - battedBall.ContactQuality + Math.Abs(randomAdjustment), 0, 1000),
                defenseRating, defenseAdjustment, parkAdjustment, impact, position, fielder == null ? null : fielder.Name,
                SectorDistance(flight.DistanceTenthsMeters, sector), flight.HangMilliseconds, flight.ApexTenthsMeters,
                null, explanation);
        }

        private static bool IsTripleShape(BattedBall ball) => Math.Abs(ball.DirectionTenthsDegrees) >= 250 &&
            ball.LaunchAngleTenthsDegrees >= 120 && ball.LaunchAngleTenthsDegrees <= 280;
        private static int OutcomeValue(PitchOutcome outcome) => outcome == PitchOutcome.Single ? 1 : outcome == PitchOutcome.Double ? 2 :
            outcome == PitchOutcome.Triple ? 3 : outcome == PitchOutcome.HomeRun ? 4 : 0;
        private static int SectorDistance(int raw, FieldingSector sector) => sector == FieldingSector.Infield ? Clamp(raw, 120, 420) :
            sector == FieldingSector.Outfield ? Clamp(raw, 480, 1040) : Clamp(raw, 1050, 1400);

        private static (int DistanceTenthsMeters, int HangMilliseconds, int ApexTenthsMeters) Flight(BattedBall ball)
        {
            var speed = ball.ExitVelocityTenthsKph / 36.0;
            var degrees = ball.LaunchAngleTenthsDegrees / 10.0;
            var radians = Math.Max(-8.0, Math.Min(48.0, degrees)) * Math.PI / 180.0;
            const double mass = 0.145, radius = 0.0369, airDensity = 1.225, dragCoefficient = 0.30, step = 0.005;
            var crossSection = Math.PI * radius * radius;
            var liftCoefficient = Math.Min(0.20, Math.Max(0.12, 0.15 + (24.0 - degrees) * 0.0015));
            var drag = 0.5 * airDensity * crossSection * dragCoefficient / mass;
            var lift = 0.5 * airDensity * crossSection * liftCoefficient / mass;
            var elapsed = 0.0; var forward = 0.0; var height = 1.0;
            var forwardVelocity = speed * Math.Cos(radians); var verticalVelocity = speed * Math.Sin(radians);
            var apex = height;
            while (elapsed < 6.5)
            {
                var previousHeight = height; var previousForward = forward;
                var magnitude = Math.Sqrt(forwardVelocity * forwardVelocity + verticalVelocity * verticalVelocity);
                var forwardAcceleration = -drag * magnitude * forwardVelocity - lift * magnitude * verticalVelocity;
                var verticalAcceleration = -9.81 - drag * magnitude * verticalVelocity + lift * magnitude * forwardVelocity;
                var nextForwardVelocity = Math.Max(0, forwardVelocity + forwardAcceleration * step);
                var nextVerticalVelocity = verticalVelocity + verticalAcceleration * step;
                var nextForward = forward + (forwardVelocity + nextForwardVelocity) * 0.5 * step;
                var nextHeight = height + (verticalVelocity + nextVerticalVelocity) * 0.5 * step;
                if (nextHeight <= 0 && elapsed + step > 0.05)
                {
                    var ratio = previousHeight / Math.Max(0.000001, previousHeight - nextHeight);
                    elapsed += step * ratio; forward = previousForward + (nextForward - previousForward) * ratio;
                    break;
                }
                elapsed += step; forward = nextForward; height = nextHeight;
                forwardVelocity = nextForwardVelocity; verticalVelocity = nextVerticalVelocity; apex = Math.Max(apex, height);
            }
            return ((int)Math.Round(Math.Max(1.0, forward) * 10.0, MidpointRounding.AwayFromZero),
                (int)Math.Round(elapsed * 1000.0, MidpointRounding.AwayFromZero),
                (int)Math.Round(apex * 10.0, MidpointRounding.AwayFromZero));
        }

        private static FielderPosition Position(FieldingSector sector, int direction)
        {
            if (sector == FieldingSector.Infield)
                return direction < -180 ? FielderPosition.ThirdBase : direction < 0 ? FielderPosition.Shortstop :
                    direction < 180 ? FielderPosition.SecondBase : FielderPosition.FirstBase;
            return direction < -150 ? FielderPosition.LeftField : direction < 150 ? FielderPosition.CenterField : FielderPosition.RightField;
        }
        private static int Clamp(int value, int lower, int upper) => Math.Min(Math.Max(value, lower), upper);
    }

    public sealed class StealResolution
    {
        public StealResolution(StealAttemptSnapshot attempt, BaserunnerStateSnapshot runnersAfter, int outsRecorded)
        { Attempt = attempt; RunnersAfter = runnersAfter; OutsRecorded = outsRecorded; }
        public StealAttemptSnapshot Attempt { get; }
        public BaserunnerStateSnapshot RunnersAfter { get; }
        public int OutsRecorded { get; }
    }

    public sealed class BaserunnerEngine
    {
        public const int SacrificeFlyThirdScoreDistance = 620;
        public const int SacrificeFlySecondAdvanceDistance = 900;

        public BaserunnerAdvanceSnapshot Advance(BaserunnerStateSnapshot runners, PitchOutcome outcome,
            PlateAppearanceResult result, DefenseSnapshot defense, ulong seed, bool doublePlayCompleted = false,
            BattedBall battedBall = null, FieldingResolutionSnapshot fielding = null, bool inningEnded = false)
        {
            var after = runners; var runs = 0; var generator = new SplitMix64(seed ^ 0x52554E4E4552UL);
            if (result == PlateAppearanceResult.InPlayOut)
            {
                int? distance = fielding == null ? null : fielding.LandingDistanceTenthsMeters;
                var sacrificeFly = !inningEnded && !doublePlayCompleted && runners.ThirdOccupied &&
                    battedBall != null && battedBall.LaunchAngleTenthsDegrees >= 90 && fielding != null &&
                    (fielding.Sector == FieldingSector.Outfield || fielding.Sector == FieldingSector.Fence) &&
                    distance.HasValue && distance.Value >= SacrificeFlyThirdScoreDistance;
                if (sacrificeFly)
                {
                    var secondTags = runners.SecondOccupied &&
                        distance.Value >= SacrificeFlySecondAdvanceDistance;
                    after = new BaserunnerStateSnapshot(
                        runners.FirstOccupied,
                        runners.SecondOccupied && !secondTags,
                        secondTags,
                        runners.LeadRunnerSpeed);
                    runs = 1;
                }
                else if (doublePlayCompleted)
                {
                    after = new BaserunnerStateSnapshot(
                        false,
                        runners.SecondOccupied,
                        runners.ThirdOccupied,
                        runners.LeadRunnerSpeed);
                }
            }
            else if (result == PlateAppearanceResult.Walk)
            {
                runs = runners.FirstOccupied && runners.SecondOccupied && runners.ThirdOccupied ? 1 : 0;
                after = new BaserunnerStateSnapshot(true, runners.SecondOccupied || runners.FirstOccupied,
                    runners.ThirdOccupied || (runners.FirstOccupied && runners.SecondOccupied), runners.LeadRunnerSpeed);
            }
            else if (result == PlateAppearanceResult.Hit)
            {
                if (outcome == PitchOutcome.Single)
                {
                    var secondScores = runners.SecondOccupied && ExtraBase(runners.LeadRunnerSpeed, defense.Arm, generator.NextInt(1000), 500);
                    var firstTakesThird = runners.FirstOccupied && !runners.SecondOccupied && ExtraBase(runners.LeadRunnerSpeed, defense.Arm, generator.NextInt(1000), 650);
                    after = new BaserunnerStateSnapshot(true, runners.FirstOccupied && !firstTakesThird,
                        (runners.SecondOccupied && !secondScores) || firstTakesThird, 50);
                    runs = (runners.ThirdOccupied ? 1 : 0) + (secondScores ? 1 : 0);
                }
                else if (outcome == PitchOutcome.Double)
                {
                    var firstScores = runners.FirstOccupied && ExtraBase(runners.LeadRunnerSpeed, defense.Arm, generator.NextInt(1000), 540);
                    after = new BaserunnerStateSnapshot(false, true, runners.FirstOccupied && !firstScores, 50);
                    runs = (runners.SecondOccupied ? 1 : 0) + (runners.ThirdOccupied ? 1 : 0) + (firstScores ? 1 : 0);
                }
                else if (outcome == PitchOutcome.Triple) { after = new BaserunnerStateSnapshot(false, false, true, 50); runs = runners.OccupiedCount; }
                else if (outcome == PitchOutcome.HomeRun) { after = BaserunnerStateSnapshot.Empty; runs = runners.OccupiedCount + 1; }
            }
            var explanation = runs > 0 ? "주자 진루로 " + runs + "점을 허용했습니다." : after != runners ?
                "타석 결과에 따라 주자 배치가 바뀌었습니다." : "주자 배치는 유지됐습니다.";
            return new BaserunnerAdvanceSnapshot(runners, after, runs, explanation);
        }

        public StealResolution ResolveSteal(BaserunnerStateSnapshot runners, DefenseSnapshot defense,
            PlateAppearanceContext context, ulong seed)
        {
            if (context.Outs > 1) return new StealResolution(null, runners, 0);
            int from, to;
            if (runners.SecondOccupied && !runners.ThirdOccupied) { from = 2; to = 3; }
            else if (runners.FirstOccupied && !runners.SecondOccupied) { from = 1; to = 2; }
            else return new StealResolution(null, runners, 0);
            var catcher = defense.Fielder(FielderPosition.Catcher); var arm = catcher == null ? defense.Arm : catcher.Arm;
            var generator = new SplitMix64(unchecked(seed ^ 0x535445414CUL ^ ((ulong)context.PitchNumber * 0x9E3779B9UL)));
            var attemptChance = Clamp(55 + (runners.LeadRunnerSpeed - 50) * 3 + context.Leverage / 20, 20, 260);
            if (generator.NextInt(1000) >= attemptChance) return new StealResolution(null, runners, 0);
            var succeeded = generator.NextInt(1000) < Clamp(650 + (runners.LeadRunnerSpeed - arm) * 7, 280, 900);
            var after = from == 1
                ? new BaserunnerStateSnapshot(false, succeeded, runners.ThirdOccupied, runners.LeadRunnerSpeed)
                : new BaserunnerStateSnapshot(runners.FirstOccupied, false, succeeded, runners.LeadRunnerSpeed);
            var explanation = succeeded ? from + "루 주자가 스타트를 끊어 " + to + "루 도루에 성공했습니다." :
                "포수가 빠른 송구로 " + from + "루 주자의 도루를 저지했습니다.";
            return new StealResolution(new StealAttemptSnapshot(from, to, runners.LeadRunnerSpeed, arm, succeeded, explanation), after, succeeded ? 0 : 1);
        }
        private static bool ExtraBase(int speed, int arm, int roll, int threshold) => roll + (speed - arm) * 8 >= threshold;
        private static int Clamp(int value, int low, int high) => Math.Min(Math.Max(value, low), high);
    }

    public sealed class InningStateEngine
    {
        public InningTransitionSnapshot Resolve(PlateAppearanceContext context, GameStateSnapshot gameState,
            PlateAppearanceResult? result, BattedBall battedBall, FieldingResolutionSnapshot fielding,
            BaserunnerStateSnapshot runners, int stealOuts, ulong seed)
        {
            var before = gameState.InningState ?? new InningStateSnapshot(context.Inning, HalfInning.Bottom, context.Outs);
            var ordinaryOut = result == PlateAppearanceResult.Strikeout || result == PlateAppearanceResult.InPlayOut;
            var doublePlay = false;
            if (result == PlateAppearanceResult.InPlayOut && battedBall != null && battedBall.LaunchAngleTenthsDegrees < 90 &&
                runners.FirstOccupied && before.Outs + stealOuts <= 1)
            {
                var chance = Clamp(470 + (gameState.Defense.Infield - 50) * 5 + (gameState.Defense.Arm - 50) * 3 -
                    Math.Max(0, battedBall.ContactQuality - 450) / 2, 180, 820);
                var generator = new SplitMix64(seed ^ 0x444F55424C45UL); doublePlay = generator.NextInt(1000) < chance;
            }
            var outsRecorded = Math.Min(3 - before.Outs, stealOuts + (ordinaryOut ? 1 + (doublePlay ? 1 : 0) : 0));
            var ended = before.Outs + outsRecorded >= 3;
            var after = ended ? (before.Half == HalfInning.Top ? new InningStateSnapshot(before.Inning, HalfInning.Bottom, 0) :
                new InningStateSnapshot(before.Inning + 1, HalfInning.Top, 0)) :
                new InningStateSnapshot(before.Inning, before.Half, before.Outs + outsRecorded);
            var explanation = doublePlay && ended ? "땅볼 병살로 아웃 두 개를 잡아 공수를 전환했습니다." :
                doublePlay ? "내야진이 땅볼을 병살로 연결해 아웃 두 개를 기록했습니다." :
                ended ? "세 번째 아웃을 잡아 공수가 전환됐습니다." : outsRecorded > 0 ?
                "이번 플레이에서 " + outsRecorded + "아웃을 기록했습니다." : "아웃카운트는 유지됐습니다.";
            return new InningTransitionSnapshot(before, after, outsRecorded, doublePlay, ended, explanation);
        }
        private static int Clamp(int value, int low, int high) => Math.Min(Math.Max(value, low), high);
    }

    public sealed class GameAnalysisEngine
    {
        public const int MaximumEntries = 120;
        public void Validate(GameLogSnapshot log)
        {
            if (log == null) return;
            if (string.IsNullOrEmpty(log.GameId) || log.TotalPitches < log.Entries.Count || log.Entries.Count > MaximumEntries)
                throw new SimulationException(SimulationErrorCode.InvalidGameLog, "game log metadata is inconsistent");
        }

        public GameLogSnapshot Record(GameLogSnapshot log, string gameId, PitchType pitchType, bool wasInZone,
            bool batterSwung, PitchOutcome outcome, PlateAppearanceResult? result, SelectionQuality quality,
            int executionQuality, BattedBall battedBall, FieldingResolutionSnapshot fielding,
            bool recommendationAccepted, int? velocityTenthsKph)
        {
            var current = log ?? new GameLogSnapshot(gameId, 0, 0, Array.Empty<PitchAnalysisEntry>());
            var entry = new PitchAnalysisEntry(pitchType, wasInZone, batterSwung, outcome, quality, executionQuality,
                battedBall == null ? (int?)null : battedBall.ContactQuality,
                Damage(fielding == null ? outcome : fielding.NeutralOutcome, result), Damage(outcome, result),
                recommendationAccepted, velocityTenthsKph);
            var entries = current.Entries.Concat(new[] { entry }).ToList();
            if (entries.Count > MaximumEntries) entries = entries.Skip(entries.Count - MaximumEntries).ToList();
            return new GameLogSnapshot(current.GameId, unchecked(current.Revision + 1), current.TotalPitches + 1, entries);
        }

        public PostgameAnalysisSnapshot Analyze(GameLogSnapshot log)
        {
            var entries = log.Entries; var swings = entries.Count(item => item.BatterSwung);
            var contacts = entries.Where(item => item.ContactQuality.HasValue).ToList();
            var breakdowns = new List<PitchAnalysisBreakdown>();
            foreach (var type in DomainWire.PitchTypes)
            {
                var matching = entries.Where(item => item.PitchType == type).ToList(); if (matching.Count == 0) continue;
                var matchingSwings = matching.Count(item => item.BatterSwung); var matchingContacts = matching.Where(item => item.ContactQuality.HasValue).ToList();
                breakdowns.Add(new PitchAnalysisBreakdown(type, matching.Count, Rate(matching.Count(item => item.WasInZone), matching.Count),
                    Rate(matching.Count(item => item.Outcome == PitchOutcome.SwingingStrike), matchingSwings),
                    Rate(matchingContacts.Count(item => item.ContactQuality.Value >= 650), matchingContacts.Count),
                    matching.Sum(item => item.ExpectedDamage)));
            }
            var hardHitRate = Rate(contacts.Count(item => item.ContactQuality.Value >= 650), contacts.Count);
            var avgSelection = entries.Count == 0 ? 0 : entries.Sum(item => SelectionScore(item.SelectionQuality)) / entries.Count;
            var avgExecution = entries.Count == 0 ? 0 : entries.Sum(item => item.ExecutionQuality) / entries.Count;
            var confidence = entries.Count < 8 ? AnalysisConfidenceBand.Low : entries.Count < 20 ? AnalysisConfidenceBand.Developing : AnalysisConfidenceBand.Reliable;
            return new PostgameAnalysisSnapshot(entries.Count, confidence, Rate(entries.Count(item => item.WasInZone), entries.Count),
                Rate(entries.Count(item => item.Outcome == PitchOutcome.SwingingStrike), swings), hardHitRate,
                avgSelection, avgExecution, entries.Sum(item => item.ExpectedDamage), entries.Sum(item => item.ActualDamage),
                breakdowns, entries.Count < 6 ? "아직 던진 공이 적습니다. 6구 이상부터 자주 쓰는 구종과 코스를 알려 줍니다." :
                "구종 사용이 한쪽으로 치우치지 않았습니다.", avgExecution < 600 ?
                "추천 훈련: 투구 동작을 일정하게 만들고 원하는 코스에 던지기" :
                "현재처럼 상황에 맞는 구종을 고르고 원하는 코스에 던지면 됩니다.");
        }
        private static int Damage(PitchOutcome outcome, PlateAppearanceResult? result) => result == PlateAppearanceResult.Walk ? 330 :
            outcome == PitchOutcome.Single ? 470 : outcome == PitchOutcome.Double ? 780 :
            outcome == PitchOutcome.Triple ? 1050 : outcome == PitchOutcome.HomeRun ? 1400 : 0;
        private static int SelectionScore(SelectionQuality q) => q == SelectionQuality.Poor ? 250 : q == SelectionQuality.Risky ? 450 : q == SelectionQuality.Good ? 700 : 900;
        private static int Rate(int numerator, int denominator) => denominator == 0 ? 0 : numerator * 1000 / denominator;
    }
}
