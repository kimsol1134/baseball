using System.Linq;
using System.Collections.Generic;
using System.Text;
using NUnit.Framework;
using Baseball.Core.Domain;
using Baseball.Core.Pitching;
using Baseball.Core.Random;

namespace Baseball.Tests.EditMode.Core
{
    public sealed class PitchKernelTranslationTests
    {
        private readonly PitchKernelEngine engine = new PitchKernelEngine();

        [Test]
        public void PrepareAndSubmitMatchSwiftTranslationFixture()
        {
            var input = FixtureInput("20260721");
            var preparation = engine.PreparePitch(input);
            Assert.That(preparation.PlanCommitment, Is.EqualTo("72ea34d33adb0a70"));
            Assert.That(preparation.PreparationToken, Is.EqualTo("05e4befbb37d8ee7"));
            Assert.That(preparation.PrimaryRecommendation.Call.PitchType, Is.EqualTo(PitchType.Slider));
            Assert.That(preparation.PrimaryRecommendation.Call.Zone, Is.EqualTo(new PitchZone(2, 0)));
            Assert.That(preparation.PrimaryRecommendation.Call.ZoneIntent, Is.EqualTo(ZoneIntent.Edge));
            Assert.That(preparation.PrimaryRecommendation.Call.Intensity, Is.EqualTo(PitchIntensity.Normal));

            var result = engine.SubmitPitch(Submit(input, preparation));
            Assert.That(result.Snapshot.Outcome, Is.EqualTo(PitchOutcome.Ball));
            Assert.That(result.Snapshot.Execution.TargetX, Is.EqualTo(-330));
            Assert.That(result.Snapshot.Execution.TargetY, Is.EqualTo(-330));
            Assert.That(result.Snapshot.Execution.ActualX, Is.EqualTo(-406));
            Assert.That(result.Snapshot.Execution.ActualY, Is.EqualTo(-586));
            Assert.That(result.Snapshot.Execution.VelocityTenthsKph, Is.EqualTo(1313));
            Assert.That(result.Snapshot.Execution.ExecutionQuality, Is.EqualTo(771));
            Assert.That(result.NextSeed, Is.EqualTo("11400714819343459206"));
            Assert.That(result.EventHash, Is.EqualTo("14bec83d0eef1c2d"));
            Assert.That(result.EventTypes, Is.EqualTo(new[]
            {
                "batter_plan_committed", "catcher_recommendations_generated", "pitch_call_committed",
                "pitch_executed", "pitch_resolved", "rival_memory_updated", "game_analysis_updated"
            }));
        }

        [TestCase("1", PitchOutcome.CalledStrike, -242, -331, 1309, "7557917c50bc65a1")]
        [TestCase("2", PitchOutcome.Single, -437, -456, 1320, "bdf79c53c2eef97a")]
        [TestCase("3", PitchOutcome.CalledStrike, -118, -392, 1311, "bfabed5db8c76917")]
        [TestCase("4", PitchOutcome.InPlayOut, -148, -578, 1312, "c48ca036315f8709")]
        [TestCase("5", PitchOutcome.Ball, -326, -531, 1310, "86e4a15ab3bd79db")]
        [TestCase("6", PitchOutcome.Ball, -515, -183, 1319, "1c517cfc8d2bf136")]
        [TestCase("7", PitchOutcome.SwingingStrike, -132, -485, 1320, "40bb12d444493e36")]
        [TestCase("8", PitchOutcome.SwingingStrike, -421, -357, 1310, "797f63087f402e17")]
        [TestCase("9", PitchOutcome.Foul, -80, -146, 1307, "2e105169ca866caf")]
        [TestCase("10", PitchOutcome.CalledStrike, -194, -468, 1308, "a19692a19bc6ba8c")]
        [TestCase("11", PitchOutcome.CalledStrike, -430, -127, 1319, "6fbbcb04c7568371")]
        [TestCase("12", PitchOutcome.Ball, -468, -507, 1311, "c6f99e7391e58aac")]
        [TestCase("13", PitchOutcome.Ball, -588, -184, 1311, "d1d0c8c5ad99c407")]
        [TestCase("14", PitchOutcome.SwingingStrike, -446, -303, 1307, "cd23c601ac8c52c0")]
        [TestCase("15", PitchOutcome.Ball, -571, -107, 1310, "6a0f22a3118ff3b3")]
        [TestCase("16", PitchOutcome.Ball, -564, -148, 1318, "0b2544b405a216a7")]
        [TestCase("17", PitchOutcome.CalledStrike, -362, -482, 1305, "244eacb49affc0e4")]
        [TestCase("18", PitchOutcome.CalledStrike, -361, -116, 1303, "937270b1f31ced37")]
        [TestCase("19", PitchOutcome.CalledStrike, -109, -108, 1309, "205b3038759b1147")]
        [TestCase("20", PitchOutcome.Foul, -328, -111, 1306, "7c77fe55c0568238")]
        public void SeedGridMatchesSwiftOutcomeExecutionAndEventHash(
            string seed, PitchOutcome outcome, int actualX, int actualY, int velocity, string eventHash)
        {
            var input = FixtureInput(seed);
            var preparation = engine.PreparePitch(input);
            var result = engine.SubmitPitch(Submit(input, preparation));
            Assert.That(result.Snapshot.Outcome, Is.EqualTo(outcome));
            Assert.That(result.Snapshot.Execution.ActualX, Is.EqualTo(actualX));
            Assert.That(result.Snapshot.Execution.ActualY, Is.EqualTo(actualY));
            Assert.That(result.Snapshot.Execution.VelocityTenthsKph, Is.EqualTo(velocity));
            Assert.That(result.EventHash, Is.EqualTo(eventHash));
        }

        [Test]
        public void SwiftOracleMatches128ExactPitchesAndTenThousandRunDistribution()
        {
            var first128 = new StringBuilder(6000);
            var outcomes = new Dictionary<PitchOutcome, int>();
            for (var seed = 1; seed <= 10000; seed++)
            {
                var input = FixtureInput(seed.ToString());
                var preparation = engine.PreparePitch(input);
                var result = engine.SubmitPitch(Submit(input, preparation));
                int count;
                outcomes.TryGetValue(result.Snapshot.Outcome, out count);
                outcomes[result.Snapshot.Outcome] = count + 1;

                if (seed <= 128)
                {
                    PitchExecution execution = result.Snapshot.Execution;
                    first128
                        .Append(seed).Append('|')
                        .Append(result.Snapshot.Outcome.Value()).Append('|')
                        .Append(execution.ActualX).Append('|')
                        .Append(execution.ActualY).Append('|')
                        .Append(execution.VelocityTenthsKph).Append('|')
                        .Append(result.EventHash).Append('\n');
                }
            }

            Assert.That(StableHash.Fnv1A64(first128.ToString()), Is.EqualTo("56b7c99922f1d66d"));
            AssertOutcomeCount(outcomes, PitchOutcome.Ball, 2552);
            AssertOutcomeCount(outcomes, PitchOutcome.CalledStrike, 2458);
            AssertOutcomeCount(outcomes, PitchOutcome.SwingingStrike, 2755);
            AssertOutcomeCount(outcomes, PitchOutcome.Foul, 1060);
            AssertOutcomeCount(outcomes, PitchOutcome.InPlayOut, 871);
            AssertOutcomeCount(outcomes, PitchOutcome.Single, 226);
            AssertOutcomeCount(outcomes, PitchOutcome.Double, 59);
            AssertOutcomeCount(outcomes, PitchOutcome.Triple, 4);
            AssertOutcomeCount(outcomes, PitchOutcome.HomeRun, 14);
            AssertOutcomeCount(outcomes, PitchOutcome.HitByPitch, 1);
            Assert.That(outcomes.Values.Sum(), Is.EqualTo(10000));
        }

        [Test]
        public void StaleOrForeignPreparationTokenIsRejected()
        {
            var input = FixtureInput("20260721");
            var preparation = engine.PreparePitch(input);
            var foreign = new SubmitPitchParams(input.Seed, input.Pitcher, input.Batter, input.Scouting,
                input.Context, preparation.PreparationToken + "-stale", preparation.PrimaryRecommendation.Call);
            var error = Assert.Throws<SimulationException>(() => engine.SubmitPitch(foreign));
            Assert.That(error.Code, Is.EqualTo(SimulationErrorCode.InvalidPreparationToken));
        }

        [Test]
        public void OmittedAndNeutralDeliveryHaveIdenticalPhysicsAndJudgment()
        {
            var input = FixtureInput("777");
            var preparation = engine.PreparePitch(input);
            var command = Submit(input, preparation);
            var omitted = engine.SubmitPitch(command);
            var neutral = engine.SubmitPitch(command, PitchDelivery.Neutral);
            Assert.That(neutral.Snapshot.Outcome, Is.EqualTo(omitted.Snapshot.Outcome));
            AssertExecution(neutral.Snapshot.Execution, omitted.Snapshot.Execution);
        }

        [Test]
        public void PerfectReleaseImprovesExecutionWithoutChangingThePreparedPlan()
        {
            var input = FixtureInput("42");
            var preparation = engine.PreparePitch(input);
            var command = Submit(input, preparation);
            var neutral = engine.SubmitPitch(command, PitchDelivery.Neutral);
            var perfect = engine.SubmitPitch(command, new PitchDelivery(1000, 1000));
            Assert.That(perfect.Snapshot.Execution.ExecutionQuality,
                Is.GreaterThanOrEqualTo(neutral.Snapshot.Execution.ExecutionQuality));
            Assert.That(TargetMiss(perfect.Snapshot.Execution),
                Is.LessThanOrEqualTo(TargetMiss(neutral.Snapshot.Execution)));
            Assert.That(perfect.Snapshot.Execution.VelocityTenthsKph,
                Is.GreaterThan(neutral.Snapshot.Execution.VelocityTenthsKph));
        }

        [Test]
        public void PreparationIsDeterministicAndCannotReadThePlayerCall()
        {
            var input = FixtureInput("99");
            var first = engine.PreparePitch(input);
            var second = engine.PreparePitch(input);
            Assert.That(second.PreparationToken, Is.EqualTo(first.PreparationToken));
            Assert.That(second.PlanCommitment, Is.EqualTo(first.PlanCommitment));
        }

        private static PreparePitchParams FixtureInput(string seed)
        {
            return new PreparePitchParams(seed,
                new PitcherSnapshot("pitcher-1", "테스트투수", 62, 54, 58, 60),
                new BatterSnapshot("batter-1", "이준호", 56, 52, 58),
                new BatterScoutingSnapshot(new PitchZone(1, 1), new PitchZone(2, 0),
                    PitchType.FourSeam, PitchType.Slider, 48),
                new PlateAppearanceContext("pa-1", 0, 7, 0, 1, 1, 1, 0, 600, 12));
        }

        private static SubmitPitchParams Submit(PreparePitchParams input, PitchPreparation preparation)
        {
            return new SubmitPitchParams(input.Seed, input.Pitcher, input.Batter, input.Scouting,
                input.Context, preparation.PreparationToken, preparation.PrimaryRecommendation.Call);
        }

        private static void AssertExecution(PitchExecution actual, PitchExecution expected)
        {
            Assert.That(actual.TargetX, Is.EqualTo(expected.TargetX));
            Assert.That(actual.TargetY, Is.EqualTo(expected.TargetY));
            Assert.That(actual.ActualX, Is.EqualTo(expected.ActualX));
            Assert.That(actual.ActualY, Is.EqualTo(expected.ActualY));
            Assert.That(actual.VelocityTenthsKph, Is.EqualTo(expected.VelocityTenthsKph));
            Assert.That(actual.ExecutionQuality, Is.EqualTo(expected.ExecutionQuality));
            Assert.That(actual.TrajectorySeries, Is.EqualTo(expected.TrajectorySeries));
        }

        private static int TargetMiss(PitchExecution execution)
        {
            return System.Math.Abs(execution.ActualX - execution.TargetX) +
                   System.Math.Abs(execution.ActualY - execution.TargetY);
        }

        private static void AssertOutcomeCount(
            IReadOnlyDictionary<PitchOutcome, int> outcomes,
            PitchOutcome outcome,
            int expected)
        {
            int actual;
            outcomes.TryGetValue(outcome, out actual);
            Assert.That(actual, Is.EqualTo(expected), outcome.Value());
        }
    }
}
