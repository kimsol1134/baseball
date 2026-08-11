using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using Baseball.Core.Domain;
using Baseball.Core.Pitching;
using Baseball.Core.Random;

namespace Baseball.Core.Pro
{
    /// <summary>
    /// Simulates unattended outings by submitting every pitch to the authoritative pitch kernel.
    /// The same model is used by weekly pro games and can be reused by other career modes.
    /// </summary>
    public sealed class AutoOutingSimulator
    {
        public sealed class Line
        {
            public int Outs { get; internal set; }
            public int Strikeouts { get; internal set; }
            public int Walks { get; internal set; }
            public int RunsAllowed { get; internal set; }
            public int Pitches { get; internal set; }
            public int Hits { get; internal set; }
            public int HomeRuns { get; internal set; }
            public int Doubles { get; internal set; }
            public int Triples { get; internal set; }
        }

        public Line Simulate(
            PitcherSnapshot pitcher,
            int startingFatigue,
            int outsTarget,
            int pitchCap,
            ulong baseSeed,
            int batterOffset = 0)
        {
            var engine = new PitchKernelEngine();
            var rng = new SplitMix64(baseSeed);
            var line = new Line();
            var fielders = Enum.GetValues(typeof(FielderPosition)).Cast<FielderPosition>()
                .Select(position => new FielderSnapshot(
                    "week-" + FielderValue(position), FielderValue(position), position, 50, 50, 50))
                .ToArray();
            var inningState = new InningStateSnapshot(1, HalfInning.Top, 0);
            var runners = new BaserunnerStateSnapshot(false, false, false, 52);
            var runsOnBoard = 0;
            var carriedGameLog = new GameLogSnapshot("week-outing", 0, 0, new PitchAnalysisEntry[0]);
            var currentFatigue = Clamp(startingFatigue, 0, 95);
            RivalMemorySnapshot benchMemory = null;
            var memoryEngine = new RivalMemoryEngine();
            var plateAppearanceIndex = 0;

            while (line.Outs < outsTarget && line.Pitches < pitchCap && plateAppearanceIndex < 60)
            {
                plateAppearanceIndex++;
                var batter = new BatterSnapshot(
                    "week-batter-" + plateAppearanceIndex,
                    "상대 타선",
                    Clamp(50 + batterOffset + rng.NextInt(9) - 4, 20, 80),
                    Clamp(50 + batterOffset + rng.NextInt(7) - 3, 20, 80),
                    Clamp(50 + batterOffset + rng.NextInt(9) - 4, 20, 80),
                    rng.NextInt(100) < 32 ? BatSide.Left : BatSide.Right);
                var hotZone = new PitchZone(rng.NextInt(3), rng.NextInt(3));
                var symmetricColdZone = new PitchZone(2 - hotZone.Row, 2 - hotZone.Column);
                var coldZone = symmetricColdZone == hotZone ? new PitchZone(2, 0) : symmetricColdZone;
                var scouting = new BatterScoutingSnapshot(
                    hotZone,
                    coldZone,
                    PitchType.FourSeam,
                    rng.NextInt(2) == 0 ? PitchType.Slider : PitchType.Changeup,
                    Clamp(48 + rng.NextInt(9) - 4, 20, 80));
                var gameState = new GameStateSnapshot(
                    new DefenseSnapshot(50, 50, 50, fielders),
                    new ParkSnapshot("league-week-park", "리그 구장", 1000, 1000),
                    runners,
                    runsOnBoard,
                    inningState);
                var gameLog = carriedGameLog;
                var context = new PlateAppearanceContext(
                    "week-pa-" + plateAppearanceIndex, 0, inningState.Inning, inningState.Outs,
                    0, 0, 1, 0, 500, currentFatigue);
                var seed = Math.Max(1UL, rng.Next() >> 1).ToString(CultureInfo.InvariantCulture);
                if (benchMemory == null) benchMemory = memoryEngine.BenchMemory(pitcher, "outing");
                var plateAppearanceMemory = benchMemory;
                var preparation = engine.PreparePitch(new PreparePitchParams(
                    seed, pitcher, batter, scouting, context, plateAppearanceMemory, gameState, gameLog));
                var outsBefore = (inningState.Inning - 1) * 3 + inningState.Outs;

                while (true)
                {
                    var result = engine.SubmitPitch(new SubmitPitchParams(
                        seed, pitcher, batter, scouting, context, preparation.PreparationToken,
                        preparation.PrimaryRecommendation.Call, plateAppearanceMemory, gameState, gameLog));
                    plateAppearanceMemory = result.RivalMemory;
                    benchMemory = result.RivalMemory;
                    gameState = result.GameState;
                    gameLog = result.GameLog;
                    line.Pitches++;
                    currentFatigue = Clamp(result.Snapshot.FatigueAfterPitch, 0, 95);
                    if (result.Snapshot.Result.HasValue)
                    {
                        if (result.Snapshot.Result.Value == PlateAppearanceResult.Strikeout) line.Strikeouts++;
                        if (result.Snapshot.Result.Value == PlateAppearanceResult.Walk) line.Walks++;
                        if (result.Snapshot.Result.Value == PlateAppearanceResult.Hit)
                        {
                            line.Hits++;
                            if (result.Snapshot.Outcome == PitchOutcome.HomeRun) line.HomeRuns++;
                            else if (result.Snapshot.Outcome == PitchOutcome.Triple) line.Triples++;
                            else if (result.Snapshot.Outcome == PitchOutcome.Double) line.Doubles++;
                        }
                    }
                    if (result.Snapshot.Ended)
                    {
                        line.RunsAllowed += result.Snapshot.RunsScored;
                        runsOnBoard = result.GameState.RunsAllowed;
                        carriedGameLog = result.GameLog;
                        inningState = result.GameState.InningState ?? inningState;
                        runners = result.GameState.Runners;
                        var outsAfter = (inningState.Inning - 1) * 3 + inningState.Outs;
                        line.Outs += Math.Max(0, outsAfter - outsBefore);
                        break;
                    }
                    seed = result.NextSeed;
                    context = new PlateAppearanceContext(
                        context.PlateAppearanceId,
                        result.Revision,
                        result.GameState.InningState.HasValue ? result.GameState.InningState.Value.Inning : context.Inning,
                        result.GameState.InningState.HasValue ? result.GameState.InningState.Value.Outs : context.Outs,
                        result.Snapshot.Balls,
                        result.Snapshot.Strikes,
                        context.PitchNumber + 1,
                        context.ScoreDifferential,
                        context.Leverage,
                        currentFatigue);
                    if (result.NextPreparation == null) return line;
                    preparation = result.NextPreparation;
                }
            }
            return line;
        }

        private static string FielderValue(FielderPosition value)
        {
            switch (value)
            {
                case FielderPosition.Pitcher: return "pitcher";
                case FielderPosition.Catcher: return "catcher";
                case FielderPosition.FirstBase: return "first_base";
                case FielderPosition.SecondBase: return "second_base";
                case FielderPosition.ThirdBase: return "third_base";
                case FielderPosition.Shortstop: return "shortstop";
                case FielderPosition.LeftField: return "left_field";
                case FielderPosition.CenterField: return "center_field";
                default: return "right_field";
            }
        }

        private static int Clamp(int value, int lower, int upper)
        {
            return Math.Min(upper, Math.Max(lower, value));
        }
    }
}
