using System;
using System.Collections.Generic;
using System.Linq;
using Baseball.Core.Catalogs;
using Baseball.Core.Domain;
using Baseball.Core.Pitching;
using NUnit.Framework;

namespace Baseball.Core.Pro.Tests
{
    [TestFixture]
    public sealed class SimulationAndContentTests
    {
        [Test]
        public void LegacySimulationFacadeReturnsAuthoritativeKernelEvents()
        {
            var pitcher = PitcherPresetCatalog.All[0].Pitcher;
            var batter = new BatterSnapshot("b-1", "가상 타자", 50, 50, 50);
            var parameters = new SimulatePitchParams("900", pitcher, batter, new CountState(1, 1), 10,
                new PitchSelection(PitchType.FourSeam, new PitchZone(0, 0), PitchIntensity.Normal));
            var first = new SimulationEngine().SimulatePitch(parameters);
            var replay = new SimulationEngine().SimulatePitch(parameters);
            Assert.That(first.EventTypes, Does.Contain("pitch_resolved"));
            Assert.That(first.EventHash, Is.EqualTo(replay.EventHash));
            Assert.That(first.NextSeed, Is.EqualTo(replay.NextSeed));
            Assert.That(first.Snapshot.Outcome, Is.EqualTo(replay.Snapshot.Outcome));
        }

        [Test]
        public void PitchSeedReservationIsPositiveStableAndDoesNotUseWallClock()
        {
            Assert.That(ProSeedReservation.Advance("123"), Is.EqualTo(ProSeedReservation.Advance("123")));
            Assert.That(ulong.Parse(ProSeedReservation.Advance("0")), Is.GreaterThan(0));
            Assert.That(ProSeedReservation.Advance("legacy-numeric-fallback"), Is.EqualTo(ProSeedReservation.Advance("another-invalid-value")));
        }

        [Test]
        public void RuntimeCatalogContainsOnlyFictionalClubContent()
        {
            var text = new List<string>();
            foreach (var team in ProCareerEngine.ProTeams)
            {
                text.AddRange(new[] { team.Id, team.Name, team.DevelopmentPlan, team.PositionCompetitor, team.ProCoach,
                    team.CompetitorProfile, team.CompetitorRecord, team.CoachProfile, team.CoachRecord });
            }
            foreach (var rival in ProCareerEngine.RivalBatterCatalog)
                text.AddRange(new[] { rival.Id, rival.Name, rival.Archetype, rival.TeamId, rival.TeamName, rival.Record, rival.Profile });
            var engine = new ProCareerEngine();
            var started = engine.Start(ProFixtureTests.StartParams("610"));
            var state = engine.SignContract(new ProStateParams(started.NextSeed, started.Snapshot)).Snapshot;
            foreach (var week in ProCareerEngine.SeasonDecisionWeeks)
            {
                var decision = engine.SeasonDecision(state, week);
                text.AddRange(new[] { decision.Id, decision.Title, decision.Detail });
                foreach (var choice in decision.Choices) text.AddRange(new[] { choice.Id, choice.Title, choice.Detail, choice.Effect.Summary });
            }
            var runtime = string.Join("\n", text.Where(value => value != null));
            foreach (var forbiddenParts in new[]
            {
                new[] { "K", "B", "O" },
                new[] { "L", "G ", "트윈스" },
                new[] { "두산 ", "베어스" },
                new[] { "키움 ", "히어로즈" },
                new[] { "S", "S", "G ", "랜더스" },
                new[] { "한화 ", "이글스" },
                new[] { "K", "I", "A ", "타이거즈" },
                new[] { "삼성 ", "라이온즈" },
                new[] { "롯데 ", "자이언츠" },
                new[] { "N", "C ", "다이노스" },
                new[] { "K", "T ", "위즈" }
            }) Assert.That(runtime, Does.Not.Contain(string.Concat(forbiddenParts)));
        }
    }
}
