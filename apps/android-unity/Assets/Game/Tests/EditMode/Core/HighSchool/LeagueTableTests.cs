using System.Linq;
using NUnit.Framework;

namespace Baseball.Core.HighSchool.Tests
{
    [TestFixture]
    public sealed class LeagueTableTests
    {
        [Test]
        public void StandingsAreDeterministicBalancedAndIncludeActualPlayerGames()
        {
            var actual = new[] { new LeagueTable.PlayerGameResult(4, 2), new LeagueTable.PlayerGameResult(1, 3), new LeagueTable.PlayerGameResult(2, 2) };
            var first = LeagueTable.Standings(1, "fixture", 36, "seoul_comets", actual);
            var replay = LeagueTable.Standings(1, "fixture", 36, "seoul_comets", actual);
            Assert.That(replay.Select(x => x.TeamId + ":" + x.Wins + ":" + x.Losses + ":" + x.Draws), Is.EqualTo(first.Select(x => x.TeamId + ":" + x.Wins + ":" + x.Losses + ":" + x.Draws)));
            Assert.That(first.Count, Is.EqualTo(10));
            Assert.That(first.Sum(x => x.Wins), Is.EqualTo(first.Sum(x => x.Losses)));
            Assert.That(first.All(x => x.Games == 36), Is.True);
        }

        [Test]
        public void PitcherLeaderboardUsesBaseballMetricsAndStableNames()
        {
            var rows = LeagueTable.Pitchers(2, "fixture", 72);
            Assert.That(rows.Count, Is.GreaterThan(0));
            Assert.That(rows.Select(x => x.Name).Distinct().Count(), Is.GreaterThan(10));
            Assert.That(rows, Is.Ordered.By("RunsPer9"));
            Assert.That(LeagueTable.GamesPlayed(24), Is.EqualTo(144));
        }
    }
}
