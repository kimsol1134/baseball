using System.Linq;
using NUnit.Framework;
using Baseball.Core.Domain;
using Baseball.Core.Pitching;

namespace Baseball.Tests.EditMode.Core
{
    public sealed class PitchSituationTests
    {
        [Test]
        public void RivalMemoryKeepsStableTieBreakOrderAndBoundedWindow()
        {
            var engine = new RivalMemoryEngine();
            var pitcher = new PitcherSnapshot("p", "투수", 50, 50, 50, 50);
            var batter = new BatterSnapshot("b", "타자", 50, 50, 50);
            RivalMemorySnapshot memory = null;
            for (var index = 0; index < 30; index++)
            {
                var context = new PlateAppearanceContext("pa", (ulong)index, 1, 0, 0, 0, index + 1, 0, 500, 0);
                memory = engine.Record(memory, pitcher, batter, context,
                    new PitchCall(index % 2 == 0 ? PitchType.FourSeam : PitchType.Slider,
                        new PitchZone(1, 1), ZoneIntent.Edge, PitchIntensity.Normal),
                    PitchOutcome.Foul, false);
            }
            Assert.That(memory.RecentObservations.Count, Is.EqualTo(RivalMemoryEngine.MaximumObservations));
            Assert.That(memory.TotalPitchesSeen, Is.EqualTo(30));
            var read = engine.Analyze(memory, new PlateAppearanceContext("pa", 30, 1, 0, 0, 0, 31, 0, 500, 0));
            Assert.That(read.PitchReadStrength, Is.InRange(0, 300));
            Assert.That(read.ZoneReadStrength, Is.InRange(0, 250));
        }

        [Test]
        public void TwoStrikeChaseWhiffGetsTheSpecificSequenceMoment()
        {
            var context = new PlateAppearanceContext("pa", 0, 7, 1, 1, 2, 5, 0, 800, 20);
            var moment = PitchSequenceEvaluator.Evaluate(new PitchSequencePitch[0], context,
                new PitchSequencePitch(PitchType.Slider, new PitchZone(2, 0), ZoneIntent.Chase, 126, PitchOutcome.SwingingStrike), null);
            Assert.That(moment.Tag, Is.EqualTo(PitchSequenceTag.ExpandAfterTwoStrikes));
        }

        [Test]
        public void IntentionalCrossMixBuildsMoreMasteryThanRepeatedAutomaticCalls()
        {
            var intentional = SequenceProgress.Empty();
            var automatic = SequenceProgress.Empty();
            for (var index = 0; index < 6; index++)
            {
                intentional = RecordCrossMix(intentional, index);
                automatic = RecordAutomatic(automatic, index);
            }

            Assert.That(intentional.MasteryCount, Is.EqualTo(5));
            Assert.That(intentional.Tags, Is.EqualTo(new[]
            {
                PitchSequenceTag.SpeedLadder,
                PitchSequenceTag.InsideOutside,
                PitchSequenceTag.SpeedLadder,
                PitchSequenceTag.InsideOutside,
                PitchSequenceTag.SpeedLadder
            }));
            Assert.That(automatic.MasteryCount, Is.Zero);
            Assert.That(intentional.MasteryCount, Is.GreaterThan(automatic.MasteryCount));
        }

        [Test]
        public void RehydratedAccumulatorContinuesIdenticallyAndKeepsBoundedCanonicalState()
        {
            var uninterrupted = SequenceProgress.Empty();
            for (var index = 0; index < 5; index++)
            {
                uninterrupted = RecordCrossMix(uninterrupted, index);
            }

            var restored = new SequenceProgress(
                uninterrupted.Recent.ToArray(),
                uninterrupted.MasteryCount,
                uninterrupted.Tags.ToArray());

            for (var index = 5; index < 14; index++)
            {
                uninterrupted = RecordCrossMix(uninterrupted, index);
                restored = RecordCrossMix(restored, index);
            }

            Assert.That(restored.MasteryCount, Is.EqualTo(uninterrupted.MasteryCount));
            Assert.That(restored.Tags, Is.EqualTo(uninterrupted.Tags));
            Assert.That(restored.Recent.Count, Is.EqualTo(3));
            for (var index = 0; index < restored.Recent.Count; index++)
            {
                Assert.That(restored.Recent[index].PitchType,
                    Is.EqualTo(uninterrupted.Recent[index].PitchType));
                Assert.That(restored.Recent[index].Zone,
                    Is.EqualTo(uninterrupted.Recent[index].Zone));
                Assert.That(restored.Recent[index].ExpectedVelocityKph,
                    Is.EqualTo(uninterrupted.Recent[index].ExpectedVelocityKph));
                Assert.That(restored.Recent[index].Outcome,
                    Is.EqualTo(uninterrupted.Recent[index].Outcome));
            }
        }

        [Test]
        public void PullDirectionMirrorsForBatSide()
        {
            Assert.That(PitchKernelEngine.PullShift(BatSide.Right, 0), Is.LessThan(0));
            Assert.That(PitchKernelEngine.PullShift(BatSide.Left, 0), Is.GreaterThan(0));
            Assert.That(PitchKernelEngine.PullShift(BatSide.Right, 1), Is.Zero);
        }

        [Test]
        public void BattedBallBandsHaveOneCanonicalBoundaryTable()
        {
            Assert.That(BattedBallBands.Outcome(499), Is.EqualTo(PitchOutcome.InPlayOut));
            Assert.That(BattedBallBands.Outcome(500), Is.EqualTo(PitchOutcome.Single));
            Assert.That(BattedBallBands.Outcome(620), Is.EqualTo(PitchOutcome.Double));
            Assert.That(BattedBallBands.Outcome(775), Is.EqualTo(PitchOutcome.HomeRun));
        }

        [Test]
        public void DeepCaughtFlyScoresThirdAndLetsSecondTagWhileThirdOutDoesNotCount()
        {
            var engine = new BaserunnerEngine();
            var runners = new BaserunnerStateSnapshot(false, true, true, 55);
            var fly = new BattedBall(1360, 300, 60, 520);
            var fielding = Fielding(FieldingSector.Outfield, 950);
            var defense = new DefenseSnapshot(50, 50, 50);

            BaserunnerAdvanceSnapshot advance = engine.Advance(
                runners,
                PitchOutcome.InPlayOut,
                PlateAppearanceResult.InPlayOut,
                defense,
                1UL,
                battedBall: fly,
                fielding: fielding,
                inningEnded: false);

            Assert.That(advance.RunsScored, Is.EqualTo(1));
            Assert.That(advance.After.SecondOccupied, Is.False);
            Assert.That(advance.After.ThirdOccupied, Is.True, "2루 주자가 태그업해 3루를 채워야 합니다.");

            BaserunnerAdvanceSnapshot thirdOut = engine.Advance(
                runners,
                PitchOutcome.InPlayOut,
                PlateAppearanceResult.InPlayOut,
                defense,
                1UL,
                battedBall: fly,
                fielding: fielding,
                inningEnded: true);
            Assert.That(thirdOut.RunsScored, Is.Zero);
            Assert.That(thirdOut.After, Is.EqualTo(runners));
        }

        [Test]
        public void ShallowOrGroundBallCannotBecomeSacrificeFly()
        {
            var engine = new BaserunnerEngine();
            var runners = new BaserunnerStateSnapshot(false, false, true, 55);
            var defense = new DefenseSnapshot(50, 50, 50);
            var shallow = engine.Advance(
                runners,
                PitchOutcome.InPlayOut,
                PlateAppearanceResult.InPlayOut,
                defense,
                7UL,
                battedBall: new BattedBall(1180, 300, 40, 430),
                fielding: Fielding(FieldingSector.Outfield, 520));
            var grounder = engine.Advance(
                runners,
                PitchOutcome.InPlayOut,
                PlateAppearanceResult.InPlayOut,
                defense,
                7UL,
                battedBall: new BattedBall(1180, 80, 40, 430),
                fielding: Fielding(FieldingSector.Outfield, 950));

            Assert.That(shallow.RunsScored, Is.Zero);
            Assert.That(grounder.RunsScored, Is.Zero);
            Assert.That(shallow.After, Is.EqualTo(runners));
            Assert.That(grounder.After, Is.EqualTo(runners));
        }

        private static FieldingResolutionSnapshot Fielding(FieldingSector sector, int distance)
        {
            return new FieldingResolutionSnapshot(
                PitchOutcome.InPlayOut,
                PitchOutcome.InPlayOut,
                sector,
                500,
                50,
                0,
                0,
                DefenseImpact.Neutral,
                FielderPosition.CenterField,
                "중견수",
                distance,
                3000,
                180,
                null,
                "뜬공을 잡았습니다.");
        }

        private static SequenceProgress RecordCrossMix(
            SequenceProgress state,
            int index)
        {
            bool even = index % 2 == 0;
            return Record(
                state,
                Context(index + 1),
                new PitchSequencePitch(
                    even ? PitchType.FourSeam : PitchType.Changeup,
                    even ? new PitchZone(0, 0) : new PitchZone(2, 2),
                    ZoneIntent.Edge,
                    even ? 150 : 128,
                    even ? PitchOutcome.CalledStrike : PitchOutcome.SwingingStrike));
        }

        private static SequenceProgress RecordAutomatic(
            SequenceProgress state,
            int index)
        {
            return Record(
                state,
                Context(index + 1),
                new PitchSequencePitch(
                    PitchType.FourSeam,
                    new PitchZone(1, 1),
                    ZoneIntent.Strike,
                    145,
                    PitchOutcome.CalledStrike));
        }

        private static SequenceProgress Record(
            SequenceProgress state,
            PlateAppearanceContext context,
            PitchSequencePitch current)
        {
            PitchSequenceMoment moment = PitchSequenceEvaluator.Evaluate(
                state.Recent,
                context,
                current,
                null);
            var recent = state.Recent
                .Concat(new[] { current })
                .Skip(System.Math.Max(0, state.Recent.Count + 1 - 3))
                .ToArray();
            var tags = moment == null
                ? state.Tags.ToArray()
                : state.Tags.Concat(new[] { moment.Tag }).ToArray();
            return new SequenceProgress(
                recent,
                state.MasteryCount + (moment == null ? 0 : 1),
                tags);
        }

        private static PlateAppearanceContext Context(int pitchNumber) =>
            new PlateAppearanceContext(
                "sequence-pa",
                (ulong)(pitchNumber - 1),
                7,
                1,
                0,
                0,
                pitchNumber,
                0,
                800,
                20);

        private sealed class SequenceProgress
        {
            public SequenceProgress(
                System.Collections.Generic.IReadOnlyList<PitchSequencePitch> recent,
                int masteryCount,
                System.Collections.Generic.IReadOnlyList<PitchSequenceTag> tags)
            {
                Recent = recent;
                MasteryCount = masteryCount;
                Tags = tags;
            }

            public System.Collections.Generic.IReadOnlyList<PitchSequencePitch> Recent { get; }
            public int MasteryCount { get; }
            public System.Collections.Generic.IReadOnlyList<PitchSequenceTag> Tags { get; }

            public static SequenceProgress Empty() => new SequenceProgress(
                new PitchSequencePitch[0],
                0,
                new PitchSequenceTag[0]);
        }
    }
}
