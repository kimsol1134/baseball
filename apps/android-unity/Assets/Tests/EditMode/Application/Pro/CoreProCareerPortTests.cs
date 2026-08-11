using Baseball.Application.HighSchool;
using Baseball.Application.Pro;
using System.Linq;
using NUnit.Framework;
using CoreProCareerEngine = Baseball.Core.Pro.ProCareerEngine;

namespace Baseball.Application.Tests
{
    public sealed class CoreProCareerPortTests
    {
        [Test]
        public void DirectStart_RoundTripsOpaqueSnapshotAcrossAdapterInstances()
        {
            var teamId = CoreProCareerEngine.ProTeams[0].Id;
            var started = new CoreProCareerPort().StartDirect(
                new StartDirectProRequest("7", "power", "윤하람", teamId));

            var advanced = new CoreProCareerPort().Apply(
                started,
                new ProCareerAction("advance_week", "earn_trust"));

            Assert.That(started.Phase, Is.EqualTo(ProCareerPhase.WeeklyPlan));
            Assert.That(started.CoreStateJson, Is.Not.Empty);
            Assert.That(advanced.ProCareerId, Is.EqualTo(started.ProCareerId));
            Assert.That(advanced.CoreRevision, Is.GreaterThan(started.CoreRevision));
            Assert.That(advanced.Week, Is.EqualTo(1));
            Assert.That(advanced.NextSeed, Is.Not.EqualTo(started.NextSeed));
        }

        [Test]
        public void ReservedImportantGame_ConsumesSeedThenAppliesAuthoritativeReport()
        {
            var port = new CoreProCareerPort();
            var current = port.StartDirect(new StartDirectProRequest(
                "11", "precision_commander", "박이든", CoreProCareerEngine.ProTeams[1].Id));
            for (var attempt = 0; attempt < 40 && current.Phase != ProCareerPhase.ImportantGame; attempt++)
            {
                try
                {
                    current = port.Apply(current, new ProCareerAction("advance_week", "earn_trust"));
                }
                catch (System.InvalidOperationException)
                {
                    Assert.That(current.Phase, Is.EqualTo(ProCareerPhase.SeasonDecision));
                    Assert.That(current.SeasonDecision, Is.Not.Null);
                    Assert.That(current.SeasonDecision.Choices, Is.Not.Empty);
                    current = port.Apply(current, new ProCareerAction(
                        "season_decision",
                        current.SeasonDecision.Choices[0].Payload));
                }
            }
            Assert.That(current.Phase, Is.EqualTo(ProCareerPhase.ImportantGame));

            var beforeSeed = current.NextSeed;
            var beforeStrikeouts = current.CurrentSeason.Strikeouts;
            var reserved = port.ReservePitch(current, "opening-statement");
            var completed = new CoreProCareerPort().ApplyPitchResult(
                reserved,
                new PitchGameReport(
                    "pro-important-1", 18, 5, 3, 3, 1, 1, 0,
                    sequenceMasteryCount: 2,
                    expectedDamage: 400,
                    actualDamage: 300,
                    recommendationAccepted: 12));

            Assert.That(reserved.NextSeed, Is.Not.EqualTo(beforeSeed));
            Assert.That(reserved.CoreRevision, Is.EqualTo(current.CoreRevision));
            Assert.That(completed.CoreRevision, Is.GreaterThan(reserved.CoreRevision));
            Assert.That(completed.CurrentSeason.Strikeouts, Is.EqualTo(beforeStrikeouts + 3));
            Assert.That(completed.Phase, Is.EqualTo(ProCareerPhase.WeeklyPlan));
            Assert.That(completed.RecordBook.CurrentSeason.Hits, Is.Not.Null);
            Assert.That(completed.RecordBook.CurrentSeason.HomeRuns, Is.Null,
                "the direct result did not classify home runs and must not synthesize zero");
            Assert.That(completed.RecordBook.CurrentSeason.HomeRunsPerNine, Is.Null);
            Assert.That(completed.RecordBook.CurrentSeason.FieldingIndependentPitching, Is.Null);
        }

        [Test]
        public void TamperedOpaqueSnapshot_IsRejectedBeforeCoreCommand()
        {
            var port = new CoreProCareerPort();
            var started = port.StartDirect(new StartDirectProRequest(
                "13", "innings_eater", "최도윤", CoreProCareerEngine.ProTeams[2].Id));
            var tampered = new ProCareerReadModel(
                started.ProCareerId,
                started.Origin,
                started.Phase,
                started.NextSeed,
                started.CoreRevision,
                started.PlayerId,
                started.PlayerName,
                started.TeamId,
                started.TeamName,
                started.Season,
                started.Week,
                started.Ratings,
                started.CurrentSeason,
                started.CareerSeasons,
                started.SourceHighSchoolCareerId,
                started.CoreStateJson.Replace("\"ManagerTrust\":42", "\"ManagerTrust\":99"),
                started.HallOfFameScore,
                started.Awards);

            Assert.Throws<System.InvalidOperationException>(() =>
                port.Apply(tampered, new ProCareerAction("advance_week")));
        }

        [Test]
        public void WeeklyChoicesExposeSplitDevelopmentTargetAndSingleExactRecommendation()
        {
            var started = new CoreProCareerPort().StartDirect(new StartDirectProRequest(
                "7", "breaking_ball_artist", "윤하람", CoreProCareerEngine.ProTeams[0].Id));

            Assert.That(started.WeekPlanChoices.Select(value => value.Id), Is.EquivalentTo(new[]
            {
                "develop_stuff", "develop_movement", "refine_command",
                "build_stamina", "recover", "earn_trust"
            }));
            Assert.That(started.WeekPlanChoices.Select(value => value.Id),
                Does.Not.Contain("develop_weapon"));
            Assert.That(started.DevelopmentPitchChoices, Is.Not.Empty);
            var recommendation = started.WeekPlanChoices.Single(value => value.Recommended);
            Assert.That(recommendation.Id, Is.EqualTo("earn_trust"));
            Assert.That(recommendation.RecommendationReason, Is.EqualTo("콜업 우선"));
        }
    }
}
