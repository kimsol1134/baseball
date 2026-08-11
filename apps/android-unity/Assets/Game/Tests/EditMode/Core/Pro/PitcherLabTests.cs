using System.Linq;
using Baseball.Core.Domain;
using Baseball.Core.HighSchool;
using NUnit.Framework;

namespace Baseball.Core.Pro.Tests
{
    [TestFixture]
    public sealed class PitcherLabTests
    {
        [Test]
        public void SixSessionLifeCompletesAllRequiredPhasesDeterministically()
        {
            var first = CompleteLife("314159");
            var replay = CompleteLife("314159");
            Assert.That(first.Snapshot.Phase, Is.EqualTo(PitcherLabPhase.Completed));
            Assert.That(first.Snapshot.TrainingSessionsCompleted, Is.EqualTo(6));
            Assert.That(first.Snapshot.RelationshipEventsCompleted, Is.EqualTo(2));
            Assert.That(first.Snapshot.Performance.ImportantInningsCompleted, Is.EqualTo(3));
            Assert.That(first.Snapshot.SelectedAwakenings.Count, Is.EqualTo(2));
            Assert.That(first.Snapshot.ScoutingEvaluation, Is.Not.Null);
            Assert.That(first.Snapshot.LegacySelection, Is.Not.Null);
            Assert.That(replay.NextSeed, Is.EqualTo(first.NextSeed));
            Assert.That(replay.EventHash, Is.EqualTo(first.EventHash));
            Assert.That(replay.Snapshot.StateCommitment, Is.EqualTo(first.Snapshot.StateCommitment));
        }

        [Test]
        public void RepeatingOneFocusEventuallyReceivesAntiSpamPenalty()
        {
            var engine = new PitcherLabEngine();
            var result = engine.Start(new StartPitcherLabParams("88", "precision_commander"));
            var signals = new System.Collections.Generic.List<int>();
            while (signals.Count < 3)
            {
                if (result.Snapshot.Phase == PitcherLabPhase.Training)
                {
                    result = engine.CommitTraining(new CommitTrainingParams(result.NextSeed, result.Snapshot, TrainingFocus.Command, TrainingIntensity.Standard));
                    signals.Add(result.Snapshot.LastTraining.SignalGained);
                }
                else if (result.Snapshot.Phase == PitcherLabPhase.ImportantInning)
                {
                    var number = result.Snapshot.Performance.ImportantInningsCompleted + 1;
                    result = engine.RecordImportantInning(new RecordImportantInningParams(result.NextSeed, result.Snapshot,
                        new ImportantInningReport(number, 15, 2, 0, 0, 400, 250, 10)));
                }
                else if (result.Snapshot.Phase == PitcherLabPhase.Relationship)
                    result = engine.ChooseRelationship(new ChooseRelationshipParams(result.NextSeed, result.Snapshot, RelationshipChoice.TrustCatcher));
                else Assert.Fail("Third training was not reachable");
            }
            Assert.That(result.Snapshot.FocusStreak, Is.EqualTo(3));
            Assert.That(signals[2], Is.LessThan(signals[1] + 80));
        }

        private static PitcherLabResult CompleteLife(string seed)
        {
            var engine = new PitcherLabEngine();
            var result = engine.Start(new StartPitcherLabParams(seed, "precision_commander", "김하람"));
            var guard = 0;
            while (result.Snapshot.Phase != PitcherLabPhase.Completed && guard++ < 40)
            {
                switch (result.Snapshot.Phase)
                {
                    case PitcherLabPhase.Training:
                        result = engine.CommitTraining(new CommitTrainingParams(result.NextSeed, result.Snapshot, TrainingFocus.Command, TrainingIntensity.Standard));
                        break;
                    case PitcherLabPhase.ImportantInning:
                        var number = result.Snapshot.Performance.ImportantInningsCompleted + 1;
                        result = engine.RecordImportantInning(new RecordImportantInningParams(result.NextSeed, result.Snapshot,
                            new ImportantInningReport(number, 18, 3, 1, 0, 500, 280, 12)));
                        break;
                    case PitcherLabPhase.Relationship:
                        result = engine.ChooseRelationship(new ChooseRelationshipParams(result.NextSeed, result.Snapshot, RelationshipChoice.TrustCatcher));
                        break;
                    case PitcherLabPhase.Awakening:
                        result = engine.ChooseAwakening(new ChooseAwakeningParams(result.NextSeed, result.Snapshot, result.Snapshot.AwakeningOptions.First()));
                        break;
                    case PitcherLabPhase.Scouting:
                        result = engine.FinalizeScouting(new FinalizeScoutingParams(result.NextSeed, result.Snapshot));
                        break;
                    case PitcherLabPhase.Reflection:
                        result = engine.SelectLegacy(new SelectLegacyParams(result.NextSeed, result.Snapshot, SoulDomain.Technique, result.Snapshot.LegacyOptions.First()));
                        break;
                }
            }
            Assert.That(guard, Is.LessThan(40));
            return result;
        }
    }
}
