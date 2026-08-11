using System.Linq;
using Baseball.Core.Domain;
using NUnit.Framework;

namespace Baseball.Core.HighSchool.Tests
{
    [TestFixture]
    public sealed class HighSchoolCareerFlowTests
    {
        [Test]
        public void ThreeYearCareerCanReachDraftWithoutSkippingARequiredPhase()
        {
            var engine = new HighSchoolCareerEngine();
            var result = engine.Start(new StartHighSchoolCareerParams("20260811", "precision_commander"));
            result = engine.CompletePrologue(new AdvanceCareerChapterParams(result.NextSeed, result.Snapshot));
            result = engine.ChooseSchool(new ChooseSchoolParams(result.NextSeed, result.Snapshot, SchoolId.MiraeAnalytics));
            var guard = 0;
            while (result.Snapshot.Phase != HighSchoolCareerPhase.Completed && guard++ < 100)
            {
                switch (result.Snapshot.Phase)
                {
                    case HighSchoolCareerPhase.Training:
                        result = engine.CommitTraining(new CommitCareerTrainingParams(result.NextSeed, result.Snapshot, TrainingFocus.Command, TrainingIntensity.Standard));
                        break;
                    case HighSchoolCareerPhase.Relationship:
                        result = engine.ResolveRelationship(new ResolveCareerRelationshipParams(result.NextSeed, result.Snapshot, RelationshipResponse.Listen));
                        break;
                    case HighSchoolCareerPhase.ImportantGame:
                        var game = result.Snapshot.Performance.ImportantGamesCompleted + 1;
                        result = engine.RecordImportantGame(new RecordCareerGameParams(result.NextSeed, result.Snapshot, new ImportantInningReport(game, 18, 3, 1, 1, 700, 540, 9, 3, hits: 2)));
                        break;
                    case HighSchoolCareerPhase.Awakening:
                        result = engine.ChooseAwakening(new ChooseCareerAwakeningParams(result.NextSeed, result.Snapshot, result.Snapshot.AwakeningOptions.First()));
                        break;
                    case HighSchoolCareerPhase.ChapterReview:
                        result = engine.AdvanceChapter(new AdvanceCareerChapterParams(result.NextSeed, result.Snapshot));
                        break;
                    case HighSchoolCareerPhase.Draft:
                        result = engine.ResolveDraft(new ResolveDraftParams(result.NextSeed, result.Snapshot));
                        break;
                    case HighSchoolCareerPhase.Legacy:
                        result = engine.SelectLegacy(new SelectCareerLegacyParams(result.NextSeed, result.Snapshot, result.Snapshot.LegacyOptions.Take(result.Snapshot.MemorySlots).ToArray()));
                        break;
                    default:
                        Assert.Fail("Unexpected phase " + result.Snapshot.Phase);
                        break;
                }
            }
            Assert.That(guard, Is.LessThan(100));
            Assert.That(result.Snapshot.Phase, Is.EqualTo(HighSchoolCareerPhase.Completed));
            Assert.That(result.Snapshot.Chapter.Number, Is.EqualTo(8));
            Assert.That(result.Snapshot.TotalTrainingsCompleted, Is.InRange(12, 16));
            Assert.That(result.Snapshot.Performance.ImportantGamesCompleted, Is.InRange(4, 6));
            Assert.That(result.Snapshot.SelectedAwakenings.Count, Is.EqualTo(3));
            Assert.That(result.Snapshot.DraftResult, Is.Not.Null);
        }

        [Test]
        public void TamperingWithSignedStateIsRejected()
        {
            var engine = new HighSchoolCareerEngine();
            var started = engine.Start(new StartHighSchoolCareerParams("42", "power_prospect"));
            var property = typeof(HighSchoolCareerSnapshot).GetProperty("StateCommitment");
            property.GetSetMethod(true).Invoke(started.Snapshot, new object[] { "tampered" });
            Assert.Throws<SimulationException>(() => engine.CompletePrologue(new AdvanceCareerChapterParams(started.NextSeed, started.Snapshot)));
        }

        [Test]
        public void BreakingBallTrainingTargetsOnlyTheSelectedOwnedPitch()
        {
            var engine = new HighSchoolCareerEngine();
            var result = StartTraining(engine, "911", "breaking_ball_artist");
            var beforeSlider = result.Snapshot.Pitcher.Profile(PitchType.Slider);
            var beforeCurve = result.Snapshot.Pitcher.Profile(PitchType.Curveball);

            result = engine.CommitTraining(new CommitCareerTrainingParams(
                result.NextSeed,
                result.Snapshot,
                TrainingFocus.BreakingBall,
                TrainingIntensity.Standard,
                PitchType.Slider));

            var afterSlider = result.Snapshot.Pitcher.Profile(PitchType.Slider);
            var afterCurve = result.Snapshot.Pitcher.Profile(PitchType.Curveball);
            Assert.That(result.Snapshot.LastTraining.TargetPitch, Is.EqualTo(PitchType.Slider));
            Assert.That(afterSlider.Movement, Is.EqualTo(beforeSlider.Movement + 2));
            Assert.That(afterSlider.Whiff, Is.EqualTo(beforeSlider.Whiff + 1));
            Assert.That(afterCurve.Movement, Is.EqualTo(beforeCurve.Movement));
            Assert.That(afterCurve.Whiff, Is.EqualTo(beforeCurve.Whiff));
        }

        [TestCase(1)]
        [TestCase(2)]
        [TestCase(3)]
        public void TrainingBlockCompletesOnlyAvailableSessionsAndKeepsEveryReceipt(int available)
        {
            var engine = new HighSchoolCareerEngine();
            HighSchoolCareerResult result = null;
            for (var seed = 1; seed < 10000; seed++)
            {
                var candidate = StartTraining(engine, seed.ToString(), "precision_commander");
                if (candidate.Snapshot.Schedule.TrainingsByChapter[0] == available)
                {
                    result = candidate;
                    break;
                }
            }
            Assert.That(result, Is.Not.Null, "fixture seed for requested chapter training count");

            var block = engine.CommitTrainingBlock(new CommitCareerTrainingBlockParams(
                result.NextSeed,
                result.Snapshot,
                TrainingFocus.Command,
                TrainingIntensity.Standard));

            Assert.That(block.Block.CompletedSessions, Is.EqualTo(available));
            Assert.That(block.Block.Sessions.Count, Is.EqualTo(available));
            Assert.That(block.Block.Sessions.Select(value => value.Number),
                Is.EqualTo(Enumerable.Range(1, available)));
            Assert.That(block.Career.Snapshot.Revision,
                Is.EqualTo(result.Snapshot.Revision + (ulong)available));
            Assert.That(block.Career.Snapshot.Phase, Is.Not.EqualTo(HighSchoolCareerPhase.Training));
        }

        [Test]
        public void TrainingBlockRejectsIllegalStartingPhase()
        {
            var engine = new HighSchoolCareerEngine();
            var started = engine.Start(new StartHighSchoolCareerParams("912", "precision_commander"));
            Assert.Throws<SimulationException>(() => engine.CommitTrainingBlock(
                new CommitCareerTrainingBlockParams(
                    started.NextSeed,
                    started.Snapshot,
                    TrainingFocus.Command,
                    TrainingIntensity.Standard)));
        }

        private static HighSchoolCareerResult StartTraining(
            HighSchoolCareerEngine engine,
            string seed,
            string preset)
        {
            var result = engine.Start(new StartHighSchoolCareerParams(seed, preset));
            result = engine.CompletePrologue(new AdvanceCareerChapterParams(result.NextSeed, result.Snapshot));
            return engine.ChooseSchool(new ChooseSchoolParams(result.NextSeed, result.Snapshot, SchoolId.CheongamDevelopment));
        }
    }
}
