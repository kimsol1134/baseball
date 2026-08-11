using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Baseball.Application.HighSchool;
using Baseball.Application.Meta;
using Baseball.Application.Persistence;
using Baseball.Application.Pro;
using Baseball.Application.Stores;
using Newtonsoft.Json.Linq;
using NUnit.Framework;
using CoreProCareerEngine = Baseball.Core.Pro.ProCareerEngine;

namespace Baseball.Application.Tests
{
    public sealed class ProRecordProjectionTests
    {
        [Test]
        public void PitchingRecord_UsesCoreMetricsAndKeepsMissingEvidenceUnavailable()
        {
            var known = PitchingRecordReadModel.FromGameLines(new[]
            {
                new CareerGameLineReadModel(
                    1, 1, 1, false, true,
                    27, 9, 3, 6, 2, 100, 4, 2, "win", 1, 6)
            });

            Assert.That(known.Games, Is.EqualTo(1));
            Assert.That(known.Starts, Is.EqualTo(1));
            Assert.That(known.Hits, Is.EqualTo(6));
            Assert.That(known.HomeRuns, Is.EqualTo(1));
            Assert.That(known.Pitches, Is.EqualTo(100));
            Assert.That(known.QualityStarts, Is.EqualTo(1));
            Assert.That(known.Innings, Is.EqualTo(9).Within(0.0001));
            Assert.That(known.RunsPerNine, Is.EqualTo(2).Within(0.0001));
            Assert.That(known.Whip, Is.EqualTo(1).Within(0.0001));
            Assert.That(known.StrikeoutsPerNine, Is.EqualTo(9).Within(0.0001));
            Assert.That(known.WalksPerNine, Is.EqualTo(3).Within(0.0001));
            Assert.That(known.StrikeoutToWalk, Is.EqualTo(3).Within(0.0001));
            Assert.That(known.HitsPerNine, Is.EqualTo(6).Within(0.0001));
            Assert.That(known.HomeRunsPerNine, Is.EqualTo(1).Within(0.0001));
            Assert.That(known.FieldingIndependentPitching,
                Is.EqualTo(4.1144444444).Within(0.0001));
            Assert.That(known.StrikeoutRate, Is.EqualTo(0.25).Within(0.0001));
            Assert.That(known.BattingAverageOnBallsInPlay,
                Is.EqualTo(5.0 / 23.0).Within(0.0001));

            var missing = PitchingRecordReadModel.FromGameLines(new[]
            {
                new CareerGameLineReadModel(
                    1, 2, 2, true, false,
                    6, 2, 1, null, 0, 18, 2, 0, "no_decision")
            });

            Assert.That(missing.Hits, Is.Null);
            Assert.That(missing.HomeRuns, Is.Null);
            Assert.That(missing.Whip, Is.Null);
            Assert.That(missing.HitsPerNine, Is.Null);
            Assert.That(missing.HomeRunsPerNine, Is.Null);
            Assert.That(missing.FieldingIndependentPitching, Is.Null);
            Assert.That(missing.StrikeoutRate, Is.Null);
            Assert.That(missing.BattingAverageOnBallsInPlay, Is.Null);
            Assert.That(missing.RunsPerNine, Is.Zero);
            Assert.That(missing.StrikeoutsPerNine, Is.EqualTo(9).Within(0.0001));
            Assert.That(missing.QualityStarts, Is.Zero);
        }

        [Test]
        public void LegacyCoreStatsWithoutAdditiveEvidence_RecoverFromCompleteGameLog()
        {
            var oldSeasonJson =
                "{\"season\":1,\"teamId\":\"seoul_comets\",\"games\":12," +
                "\"inningsOuts\":180,\"strikeouts\":70,\"walks\":20," +
                "\"runsAllowed\":24,\"awards\":0,\"wins\":5,\"losses\":3,\"saves\":0}";
            var oldSeason = Newtonsoft.Json.JsonConvert.DeserializeObject<ProSeasonLineReadModel>(
                oldSeasonJson);
            Assert.That(oldSeason.Starts, Is.Null);
            Assert.That(oldSeason.Hits, Is.Null);
            Assert.That(oldSeason.HomeRuns, Is.Null);
            Assert.That(oldSeason.Pitches, Is.Null);
            Assert.That(oldSeason.QualityStarts, Is.Null);
            Assert.That(oldSeason.PitchingRecord.Whip, Is.Null);
            Assert.That(oldSeason.PitchingRecord.FieldingIndependentPitching, Is.Null);

            var port = new CoreProCareerPort();
            var started = port.StartDirect(new StartDirectProRequest(
                "7", "power", "윤하람", CoreProCareerEngine.ProTeams[0].Id));
            var json = JObject.Parse(started.CoreStateJson);
            var stats = (JObject)json["CurrentStats"];
            stats.Remove("Hits");
            stats.Remove("HomeRuns");
            stats.Remove("Pitches");
            stats.Remove("QualityStarts");
            var legacy = WithCoreJson(started, json.ToString(Newtonsoft.Json.Formatting.None));
            Assert.That(legacy.RecordBook, Is.Null,
                "an old Application snapshot marks the new projection unavailable until remapped");

            var advanced = new CoreProCareerPort().Apply(
                legacy,
                new ProCareerAction("advance_week", "earn_trust"));

            Assert.That(advanced.RecordBook, Is.Not.Null);
            Assert.That(advanced.RecordBook.CurrentSeason.Hits, Is.Not.Null);
            Assert.That(advanced.RecordBook.CurrentSeason.HomeRuns, Is.Not.Null);
            Assert.That(advanced.RecordBook.CurrentSeason.Pitches, Is.Not.Null);
            Assert.That(advanced.RecordBook.CurrentSeason.QualityStarts, Is.Not.Null);
            Assert.That(advanced.RecordBook.SeasonGameLinesAvailable, Is.True);
            Assert.That(advanced.RecordBook.CurrentSeason.Hits,
                Is.EqualTo(advanced.RecordBook.SeasonGameLines.Sum(value => value.RecordedHits)));
            Assert.That(advanced.RecordBook.CurrentSeason.Pitches,
                Is.EqualTo(advanced.RecordBook.SeasonGameLines.Sum(value => value.Pitches)));
        }

        [Test]
        public async Task ActiveProRecordBook_RoundTripsAwardsMilestonesDecisionsAndSeasonEvidence()
        {
            var port = new CoreProCareerPort();
            var retired = PlayOneSeasonAndRetire(port);
            var book = retired.RecordBook;

            Assert.That(book, Is.Not.Null);
            Assert.That(book.AwardNames, Does.Contain("시즌 1 탈삼진상"));
            Assert.That(book.Milestones, Does.Contain("1시즌 완주"));
            Assert.That(book.DecisionHistory, Is.Not.Empty);
            Assert.That(book.DecisionHistory[0].DecisionId, Does.StartWith("season-1-week-"));
            Assert.That(book.DecisionHistory[0].TypeId, Is.Not.Empty);
            Assert.That(book.DecisionHistory[0].ChoiceId, Is.Not.Empty);
            Assert.That(book.DecisionHistory[0].ChoiceTitle, Is.Not.Empty);
            Assert.That(book.DecisionHistory[0].EffectSummary, Is.Not.Empty);
            Assert.That(book.HallOfFameScore, Is.Not.Null);
            Assert.That(book.SeasonGameLinesAvailable, Is.True);
            Assert.That(book.CareerSeasons, Has.Count.EqualTo(1));
            Assert.That(book.CareerSeasons[0].Hits, Is.EqualTo(book.CurrentSeason.Hits));
            Assert.That(book.CareerSeasons[0].HomeRuns, Is.EqualTo(book.CurrentSeason.HomeRuns));
            Assert.That(book.CareerSeasons[0].Pitches, Is.EqualTo(book.CurrentSeason.Pitches));
            Assert.That(book.CareerSeasons[0].QualityStarts,
                Is.EqualTo(book.CurrentSeason.QualityStarts));
            Assert.That(book.SeasonGameLines, Has.Count.EqualTo(book.CurrentSeason.Games));
            Assert.That(book.SeasonGameLines.All(value => value.RecordedHits.HasValue), Is.True);
            Assert.That(book.SeasonGameLines.All(value => value.HomeRuns.HasValue), Is.True);
            Assert.That(book.CurrentSeason.Pitches,
                Is.EqualTo(book.SeasonGameLines.Sum(value => value.Pitches)));
            var priorBookJson = JObject.Parse(
                Newtonsoft.Json.JsonConvert.SerializeObject(book));
            priorBookJson.Remove(nameof(ProRecordBookReadModel.SeasonGameLinesAvailable));
            var priorBook = Newtonsoft.Json.JsonConvert.DeserializeObject<ProRecordBookReadModel>(
                priorBookJson.ToString(Newtonsoft.Json.Formatting.None));
            Assert.That(priorBook.SeasonGameLines, Is.Not.Empty);
            Assert.That(priorBook.SeasonGameLinesAvailable, Is.False,
                "missing additive availability evidence must fail closed");

            var root = Path.Combine(
                Path.GetTempPath(),
                "BaseballProRecordBook",
                Guid.NewGuid().ToString("N"));
            try
            {
                var aggregate = new GameSaveAggregate(
                    GameSaveAggregate.CurrentAggregateVersion,
                    7,
                    "record-install",
                    ApplicationStage.Retirement,
                    null,
                    retired,
                    MetaProgressState.Initial,
                    null,
                    null,
                    Array.Empty<string>());
                using (var repository = Repository(root))
                {
                    await repository.SaveAsync(aggregate, aggregate.Revision);
                }

                using (var repository = Repository(root))
                using (var restarted = await GameApplicationStore.OpenAsync(
                           repository,
                           new CoreHighSchoolCareerPort(),
                           new CoreProCareerPort(),
                           "ignored"))
                {
                    var loaded = restarted.Current.Pro.RecordBook;
                    Assert.That(loaded, Is.Not.Null);
                    Assert.That(loaded.AwardNames, Is.EqualTo(book.AwardNames));
                    Assert.That(loaded.Milestones, Is.EqualTo(book.Milestones));
                    Assert.That(loaded.HallOfFameScore, Is.EqualTo(book.HallOfFameScore));
                    Assert.That(loaded.SeasonGameLinesAvailable, Is.True);
                    Assert.That(loaded.DecisionHistory.Select(value => value.DecisionId),
                        Is.EqualTo(book.DecisionHistory.Select(value => value.DecisionId)));
                    Assert.That(loaded.DecisionHistory.Select(value => value.EffectSummary),
                        Is.EqualTo(book.DecisionHistory.Select(value => value.EffectSummary)));
                    Assert.That(loaded.CurrentSeason.Hits, Is.EqualTo(book.CurrentSeason.Hits));
                    Assert.That(loaded.CurrentSeason.HomeRuns,
                        Is.EqualTo(book.CurrentSeason.HomeRuns));
                    Assert.That(loaded.CurrentSeason.Pitches, Is.EqualTo(book.CurrentSeason.Pitches));
                    Assert.That(loaded.CurrentSeason.QualityStarts,
                        Is.EqualTo(book.CurrentSeason.QualityStarts));
                    Assert.That(loaded.SeasonGameLines.Select(value => value.HomeRuns),
                        Is.EqualTo(book.SeasonGameLines.Select(value => value.HomeRuns)));
                }
            }
            finally
            {
                if (Directory.Exists(root)) Directory.Delete(root, true);
            }
        }

        private static ProCareerReadModel PlayOneSeasonAndRetire(CoreProCareerPort port)
        {
            var current = port.StartDirect(new StartDirectProRequest(
                "41", "power", "윤하람", CoreProCareerEngine.ProTeams[0].Id));
            for (var guard = 0; guard < 120 && current.Phase != ProCareerPhase.SeasonReview; guard++)
            {
                switch (current.Phase)
                {
                    case ProCareerPhase.WeeklyPlan:
                        current = port.Apply(current, new ProCareerAction("advance_week", "earn_trust"));
                        break;
                    case ProCareerPhase.SeasonDecision:
                        current = port.Apply(current, new ProCareerAction(
                            "season_decision",
                            current.SeasonDecision.Choices[0].Payload));
                        break;
                    case ProCareerPhase.ImportantGame:
                        current = port.ReservePitch(current, "record-important");
                        current = port.ApplyPitchResult(current, new PitchGameReport(
                            "record-important-" + guard,
                            24,
                            6,
                            6,
                            4,
                            1,
                            2,
                            1,
                            expectedDamage: 400,
                            actualDamage: 300,
                            recommendationAccepted: 16,
                            homeRuns: 0));
                        break;
                    default:
                        Assert.Fail("Unexpected pro phase before review: " + current.Phase);
                        break;
                }
            }
            Assert.That(current.Phase, Is.EqualTo(ProCareerPhase.SeasonReview));
            current = port.Apply(current, new ProCareerAction("review_season"));
            Assert.That(current.Phase, Is.EqualTo(ProCareerPhase.Offseason));
            return port.Apply(current, new ProCareerAction("retire"));
        }

        private static ProCareerReadModel WithCoreJson(ProCareerReadModel value, string coreStateJson)
        {
            return new ProCareerReadModel(
                value.ProCareerId,
                value.Origin,
                value.Phase,
                value.NextSeed,
                value.CoreRevision,
                value.PlayerId,
                value.PlayerName,
                value.TeamId,
                value.TeamName,
                value.Season,
                value.Week,
                value.Ratings,
                value.CurrentSeason,
                value.CareerSeasons,
                value.SourceHighSchoolCareerId,
                coreStateJson,
                value.HallOfFameScore,
                value.Awards,
                value.Level,
                value.Role,
                value.ManagerTrust,
                value.CatcherTrust,
                value.Fatigue,
                value.WeekPlanChoices,
                value.SeasonDecision,
                value.OffseasonChoices,
                value.LeagueStandings,
                value.LeaguePitchers,
                value.RecentGameLines,
                value.ContractOffer,
                value.SeasonSegment,
                value.SeasonSegmentTitle,
                value.DevelopmentProgress,
                value.DevelopmentPitchChoices,
                value.LastSegmentProgress,
                value.InjuryWeeks,
                null);
        }

        private static AtomicSaveRepository<GameSaveAggregate> Repository(string root)
        {
            return new AtomicSaveRepository<GameSaveAggregate>(
                new SaveFileLayout(Path.Combine(root, "save")),
                new SystemAtomicFileSystem(),
                new GameSaveValidator(),
                new GameSaveSemanticPriority());
        }
    }
}
