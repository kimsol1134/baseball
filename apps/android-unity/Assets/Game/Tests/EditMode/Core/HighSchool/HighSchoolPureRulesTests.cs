using System;
using System.Linq;
using Baseball.Core.Domain;
using NUnit.Framework;

namespace Baseball.Core.HighSchool.Tests
{
    [TestFixture]
    public sealed class HighSchoolPureRulesTests
    {
        [Test]
        public void ContentCatalogMatchesSwiftCardinalityAndFictionalRuntimeNames()
        {
            Assert.That(HighSchoolContentCatalog.Events.Count, Is.EqualTo(36));
            Assert.That(HighSchoolContentCatalog.RebirthEvents.Count, Is.EqualTo(12));
            Assert.That(HighSchoolContentCatalog.Scenarios.Count, Is.EqualTo(30));
            Assert.That(HighSchoolCareerEngine.Regions.Count, Is.EqualTo(19));
            Assert.That(HighSchoolCareerEngine.Regions.SelectMany(HighSchoolCareerEngine.Schools).Select(x => x.Name).Distinct().Count(), Is.EqualTo(76));
            Assert.That(HighSchoolCareerEngine.Teams.Count, Is.EqualTo(10));
        }

        [Test]
        public void AwakeningTreeContainsEveryNodeOnceAndUnlocksOneTierAtATime()
        {
            var all = Enum.GetValues(typeof(AwakeningId)).Cast<AwakeningId>().ToArray();
            Assert.That(AwakeningTree.Nodes.Select(x => x.Id).Distinct().Count(), Is.EqualTo(all.Length));
            Assert.That(AwakeningTree.Available(new AwakeningId[0], 0), Is.EquivalentTo(new[] { AwakeningId.ExplosiveFastball, AwakeningId.PinpointEdge, AwakeningId.DisappearingBreaker, AwakeningId.BatterySync }));
            Assert.That(AwakeningTree.Available(new[] { AwakeningId.ExplosiveFastball }, 0), Does.Contain(AwakeningId.IronArm));
            Assert.That(AwakeningTree.Available(new[] { AwakeningId.ExplosiveFastball }, 0), Does.Not.Contain(AwakeningId.LateInningReserve));
            Assert.That(AwakeningTree.Available(new[] { AwakeningId.ExplosiveFastball }, AwakeningTree.LeapSparks), Does.Contain(AwakeningId.LateInningReserve));
        }

        [TestCase("career-1-life-1", "monster_generation", 5, 5, 150)]
        [TestCase("career-2-life-1", "scout_frenzy", 0, 20, 0)]
        [TestCase("career-3-life-1", "calm", 0, 5, 0)]
        [TestCase("career-100-life-2", "quiet_season", -3, 0, 80)]
        [TestCase("legacy-fixed-seed", "monster_generation", 5, 5, 150)]
        public void SwiftV1WindGoldensMatch(string careerId, string id, int rival, int fans, int reward)
        {
            var wind = CareerWind.For(careerId);
            Assert.That(wind.Id, Is.EqualTo(id));
            Assert.That(wind.RivalBonus, Is.EqualTo(rival));
            Assert.That(wind.StartingFanInterest, Is.EqualTo(fans));
            Assert.That(wind.RewardBonusPermille, Is.EqualTo(reward));
        }

        [Test]
        public void DifficultyAndLeagueRulesRetainSwiftBoundaries()
        {
            Assert.That(DifficultyScale.HighSchool(1, 1), Is.Zero);
            Assert.That(DifficultyScale.HighSchool(8, 3), Is.EqualTo(7));
            Assert.That(DifficultyScale.Pro(20), Is.EqualTo(8));
            Assert.That(LeagueBaseline.TeamRunsPerGamePermille.Sum(), Is.EqualTo(1000));
            Assert.That(LeagueBaseline.HighSchoolRunsPerGamePermille.Sum(), Is.EqualTo(1000));
            Assert.That(DecisionRules.Decide(true, false, 12, 1, 5, 2), Is.EqualTo(PitchingDecision.NoDecision));
            Assert.That(DecisionRules.Decide(true, false, 15, 1, 5, 2), Is.EqualTo(PitchingDecision.Win));
        }

        [Test]
        public void NicknameFamiliesReturnOnlyHighestTier()
        {
            var names = NicknameRules.Earned(new CareerPerformanceSnapshot(5, 150, 50, 0, 0)).ToArray();
            Assert.That(names.Select(x => x.Id), Does.Contain("k-monster"));
            Assert.That(names.Select(x => x.Id), Does.Not.Contain("k-machine"));
            Assert.That(names.Select(x => x.Id), Does.Contain("iron-wall"));
            Assert.That(names.Select(x => x.Id), Does.Contain("flawless"));
        }
    }
}
