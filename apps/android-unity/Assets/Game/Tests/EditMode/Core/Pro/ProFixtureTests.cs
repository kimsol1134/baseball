using System;
using System.Linq;
using Baseball.Core.Domain;
using Baseball.Core.HighSchool;
using NUnit.Framework;

namespace Baseball.Core.Pro.Tests
{
    [TestFixture]
    public sealed class ProFixtureTests
    {
        [Test]
        public void SwiftSeedSevenMatchesStartContractAndFirstSeasonWeekExactly()
        {
            var engine = new ProCareerEngine();
            var started = engine.Start(StartParams("7"));
            Assert.That(started.NextSeed, Is.EqualTo("7191089600892374487"));
            Assert.That(started.Snapshot.ProCareerId, Is.EqualTo("pro-b0f5bce9acca4d1c"));
            Assert.That(started.Snapshot.Commitment, Is.EqualTo("4890b72919a1864a"));
            Assert.That(started.Events, Is.EqualTo(new[] { "pro_career_started" }));

            var signed = engine.SignContract(new ProStateParams(started.NextSeed, started.Snapshot));
            Assert.That(signed.NextSeed, Is.EqualTo("13309476754707697221"));
            Assert.That(signed.Snapshot.Commitment, Is.EqualTo("78457c92f6ea5e61"));
            Assert.That(signed.Snapshot.Contract.AnnualSalary, Is.EqualTo(58000000));
            Assert.That(signed.Snapshot.SeasonTensions.Select(value => value.Title), Is.EqualTo(new[]
            {
                "차윤호와의 자리 싸움", "시즌 84탈삼진", "백건우 맞대결"
            }));

            var week = engine.PlanWeek(new PlanProWeekParams(signed.NextSeed, signed.Snapshot, ProWeekPlan.EarnTrust));
            Assert.That(week.NextSeed, Is.EqualTo("9553384876045577950"));
            // Swift StableHash oracle over the existing seed-7 state plus the additive
            // development:0:0:0:0 commitment block.
            Assert.That(week.Snapshot.Commitment, Is.EqualTo("f1f1c63a6da1d343"));
            Assert.That(week.Snapshot.Phase, Is.EqualTo(ProCareerPhase.WeeklyPlan));
            Assert.That(week.Snapshot.Week, Is.EqualTo(1));
            Assert.That(week.Snapshot.Level, Is.EqualTo(ProLevel.Minor));
            Assert.That(week.Snapshot.Role, Is.EqualTo(ProRole.LongRelief));
            Assert.That(week.Snapshot.ManagerTrust, Is.EqualTo(47));
            Assert.That(week.Snapshot.Fatigue, Is.EqualTo(10));
            Assert.That(week.Snapshot.InjuryWeeks, Is.Zero);
            AssertStats(week.Snapshot.CurrentStats, 1, 1, 17, 12, 0, 0, 1, 0, 0);
            Assert.That(week.Snapshot.CurrentStats.Hits, Is.EqualTo(1));
            Assert.That(week.Snapshot.CurrentStats.HomeRuns, Is.Zero);
            Assert.That(week.Snapshot.CurrentStats.Pitches, Is.EqualTo(99));
            Assert.That(week.Snapshot.CurrentStats.QualityStarts, Is.Zero);
            var line = week.Snapshot.GameLines.Single();
            Assert.That(new[] { line.Outs, line.Strikeouts, line.Walks, line.RunsAllowed, line.Pitches, line.TeamRuns, line.OpponentRuns, line.Hits ?? -1, line.HomeRuns ?? -1 },
                Is.EqualTo(new[] { 17, 12, 0, 0, 99, 11, 1, 1, 0 }));
            Assert.That(line.Decision, Is.EqualTo(PitchingDecision.Win));
            Assert.That(week.Events, Is.EqualTo(new[] { "pro_week_resolved", "weekly_progress" }));
        }

        [Test]
        public void DirectStartUsesStablePresetTeamAndSignsTheRookieContract()
        {
            var engine = new ProCareerEngine();
            var first = engine.StartDirect(new StartDirectProParams("81", "precision_commander", "윤서진", "jeju_storm"));
            var replay = engine.StartDirect(new StartDirectProParams("81", "precision_commander", "윤서진", "jeju_storm"));
            Assert.That(first.Snapshot.Phase, Is.EqualTo(ProCareerPhase.WeeklyPlan));
            Assert.That(first.Snapshot.Team.Id, Is.EqualTo("jeju_storm"));
            Assert.That(first.Snapshot.Pitcher.Name, Is.EqualTo("윤서진"));
            Assert.That(replay.NextSeed, Is.EqualTo(first.NextSeed));
            Assert.That(replay.Snapshot.Commitment, Is.EqualTo(first.Snapshot.Commitment));
        }

        internal static StartProCareerParams StartParams(string seed)
        {
            var pitcher = new PitcherSnapshot("p-1", "테스트투수", 58, 55, 56, 57);
            var team = ProCareerEngine.ProTeams[0];
            var draft = new DraftResultSnapshot(DraftOutcome.Drafted, 72, "2~3라운드", team, 2, 18,
                120000000, "2군 선발", Array.Empty<string>(), "지명");
            var entitlement = new ProEntitlementSnapshot(EntitlementStatus.Active, EntitlementSource.Development,
                "2026-07-22", "2026-08-22");
            return new StartProCareerParams(seed, PlayerIdentitySnapshot.DefaultPitcher, pitcher, draft, entitlement);
        }

        private static void AssertStats(ProSeasonStats stats, int games, int starts, int outs, int strikeouts,
            int walks, int runs, int wins, int losses, int saves)
        {
            Assert.That(stats.Games, Is.EqualTo(games)); Assert.That(stats.Starts, Is.EqualTo(starts));
            Assert.That(stats.InningsOuts, Is.EqualTo(outs)); Assert.That(stats.Strikeouts, Is.EqualTo(strikeouts));
            Assert.That(stats.Walks, Is.EqualTo(walks)); Assert.That(stats.RunsAllowed, Is.EqualTo(runs));
            Assert.That(stats.Wins, Is.EqualTo(wins)); Assert.That(stats.Losses, Is.EqualTo(losses)); Assert.That(stats.Saves, Is.EqualTo(saves));
        }
    }
}
