using System;
using System.Linq;
using System.Threading.Tasks;
using Baseball.Application.Commands;
using Baseball.Application.HighSchool;
using Baseball.Application.Meta;
using Baseball.Application.Persistence;
using Baseball.Application.Pro;
using Baseball.Application.Stores;
using Baseball.Core.Domain;
using Baseball.Core.Pitching;
using NUnit.Framework;

namespace Baseball.Application.Tests
{
    public sealed class ProductionCareerVerticalTests
    {
        private int _commandNumber;

        [Test]
        public async Task OpeningThroughEightChaptersTwelveProSeasonsAndRebirth_HasNoDeadEnd()
        {
            var now = new DateTimeOffset(2026, 8, 11, 1, 0, 0, TimeSpan.Zero);
            _commandNumber = 0;
            using (var store = await GameApplicationStore.OpenAsync(
                       new RecordingGameRepository(),
                       new CoreHighSchoolCareerPort(),
                       new CoreProCareerPort(),
                       "production-install"))
            {
                await Applied(store, Next("setup"), new EnterSetupCommand());
                await Applied(store, Next("start"),
                    new StartHighSchoolCareerCommand(new StartHighSchoolCareerRequest(
                        "12345", "power_prospect", "민서준", "서울", 1)));

                var weekly = WeeklyProgramCommandFactory.Observe(store.Current, now);
                Assert.That(weekly, Is.Not.Null);
                await Applied(store, Next("weekly"), weekly);

                var sawTournament = false;
                var sawProspects = false;
                var rejectedRetiredDaily = false;
                for (var guard = 0; guard < 240 && store.Current.HighSchool.Phase != HighSchoolPhase.Draft; guard++)
                {
                    var highSchool = store.Current.HighSchool;
                    sawTournament |= highSchool.Tournament != null && highSchool.Tournament.Schools.Count > 0;
                    sawProspects |= highSchool.ProspectRankings.Count > 0;
                    switch (highSchool.Phase)
                    {
                        case HighSchoolPhase.Prologue:
                            if (!highSchool.TutorialCompleted)
                            {
                                var performanceBeforeTutorial = highSchool.Performance;
                                var dailyBeforeTutorial = store.Current.Meta.Daily;
                                await CompletePitch(
                                    store,
                                    PitchCareerKind.Tutorial,
                                    "tutorial-" + highSchool.CareerId,
                                    now);
                                Assert.That(store.Current.HighSchool.TutorialCompleted, Is.True);
                                Assert.That(store.Current.HighSchool.Performance.ImportantGames,
                                    Is.EqualTo(performanceBeforeTutorial.ImportantGames));
                                Assert.That(store.Current.HighSchool.Performance.Pitches,
                                    Is.EqualTo(performanceBeforeTutorial.Pitches));
                                Assert.That(store.Current.HighSchool.Performance.Outs,
                                    Is.EqualTo(performanceBeforeTutorial.Outs));
                                Assert.That(store.Current.Meta.Daily, Is.SameAs(dailyBeforeTutorial));
                            }
                            else
                            {
                                await AdvanceHighSchool(store, "complete_prologue", null, now);
                            }
                            break;
                        case HighSchoolPhase.SchoolSelection:
                            Assert.That(highSchool.SchoolChoices, Has.Count.EqualTo(4));
                            await AdvanceHighSchool(store, "choose_school",
                                highSchool.SchoolChoices[0].Payload, now);
                            break;
                        case HighSchoolPhase.Training:
                            Assert.That(highSchool.TrainingFocusChoices, Is.Not.Empty);
                            Assert.That(highSchool.TrainingIntensityChoices, Is.Not.Empty);
                            var intensity = highSchool.TrainingIntensityChoices.First(value =>
                                string.Equals(value.Id, "standard", StringComparison.Ordinal));
                            await AdvanceHighSchool(store, "train",
                                highSchool.TrainingFocusChoices[0].Payload + ":" + intensity.Payload,
                                now);
                            break;
                        case HighSchoolPhase.Relationship:
                            Assert.That(highSchool.RelationshipChoices, Is.Not.Empty);
                            await AdvanceHighSchool(store, "relationship",
                                highSchool.RelationshipChoices[0].Payload, now);
                            break;
                        case HighSchoolPhase.ImportantGame:
                            await CompletePitch(store, PitchCareerKind.HighSchool,
                                "hs-game-" + highSchool.Performance.ImportantGames, now);
                            if (!rejectedRetiredDaily)
                            {
                                var reconcile = WeeklyProgramCommandFactory.Observe(
                                    store.Current, now.AddMinutes(1));
                                if (reconcile != null)
                                {
                                    await Applied(store, Next("weekly-reconcile"), reconcile);
                                }
                                var revision = store.Current.Revision;
                                var retired = await store.DispatchAsync(
                                    new CommandEnvelope<GameCommand>(
                                        Next("retired-daily"),
                                        revision,
                                        new BeginPitchSessionCommand(
                                            "daily-20260811",
                                            PitchCareerKind.Daily,
                                            "daily",
                                            1,
                                            now.AddMinutes(2))));
                                Assert.That(retired.Status, Is.EqualTo(DispatchStatus.DomainRejected));
                                Assert.That(retired.ErrorCode, Is.EqualTo("daily.retired"));
                                Assert.That(store.Current.Revision, Is.EqualTo(revision));
                                rejectedRetiredDaily = true;
                            }
                            break;
                        case HighSchoolPhase.Awakening:
                            Assert.That(highSchool.AwakeningChoices, Is.Not.Empty);
                            await AdvanceHighSchool(store, "awakening",
                                highSchool.AwakeningChoices[0].Payload, now);
                            break;
                        case HighSchoolPhase.ChapterReview:
                            Assert.That(highSchool.ChapterNumber, Is.LessThan(8));
                            await AdvanceHighSchool(store, "advance_chapter", null, now);
                            break;
                        default:
                            Assert.Fail("Unexpected high-school phase: " + highSchool.Phase);
                            break;
                    }
                }

                Assert.That(store.Current.HighSchool.Phase, Is.EqualTo(HighSchoolPhase.Draft));
                Assert.That(store.Current.HighSchool.ChapterNumber, Is.EqualTo(8));
                Assert.That(store.Current.HighSchool.SchoolYear, Is.EqualTo(3));
                Assert.That(store.Current.HighSchool.Performance.ImportantGames, Is.GreaterThanOrEqualTo(4));
                Assert.That(store.Current.Meta.CompletedGameCount,
                    Is.EqualTo(store.Current.HighSchool.Performance.ImportantGames));
                Assert.That(sawTournament, Is.True);
                Assert.That(sawProspects, Is.True);
                Assert.That(rejectedRetiredDaily, Is.True);
                Assert.That(store.Current.Meta.Daily.LastDailyInningDayKey, Is.Null);

                await AdvanceHighSchool(store, "resolve_draft", null, now);
                Assert.That(store.Current.HighSchool.Draft.Resolved, Is.True);
                Assert.That(store.Current.HighSchool.Draft.Drafted, Is.True,
                    "The fixed production seed must exercise the drafted vertical.");
                var highSchoolFinalRatings = store.Current.HighSchool.Ratings;
                await Applied(store, Next("enter-pro"),
                    new EnterProFromDraftCommand());
                Assert.That(store.Current.Pro.Phase, Is.EqualTo(ProCareerPhase.ContractOffer));
                Assert.That(store.Current.Pro.ContractOffer, Is.Not.Null);
                Assert.That(store.Current.Pro.ContractOffer.TeamId,
                    Is.EqualTo(store.Current.HighSchool.Draft.TeamId));
                Assert.That(store.Current.Pro.ContractOffer.Years, Is.EqualTo(3));
                Assert.That(store.Current.Pro.ContractOffer.AnnualSalary, Is.GreaterThan(0));
                await Applied(store, Next("sign-contract"), new SignProContractCommand());
                Assert.That(store.Current.Pro.Phase, Is.EqualTo(ProCareerPhase.WeeklyPlan));
                Assert.That(store.Current.Pro.ContractOffer, Is.Null);

                var sawSeasonDecision = false;
                var sawOffseason = false;
                var sawProImportantGame = false;
                for (var guard = 0; guard < 900 &&
                    store.Current.Pro.Phase != ProCareerPhase.RetirementDecision; guard++)
                {
                    var pro = store.Current.Pro;
                    Assert.That(pro.LeagueStandings, Has.Count.EqualTo(10));
                    Assert.That(pro.LeaguePitchers, Is.Not.Empty);
                    switch (pro.Phase)
                    {
                        case ProCareerPhase.WeeklyPlan:
                            Assert.That(pro.WeekPlanChoices, Is.Not.Empty);
                            var plan = pro.WeekPlanChoices.First(value =>
                                string.Equals(value.Id, "earn_trust", StringComparison.Ordinal));
                            await AdvancePro(store, "advance_week", plan.Payload, now);
                            break;
                        case ProCareerPhase.SeasonDecision:
                            sawSeasonDecision = true;
                            Assert.That(pro.SeasonDecision, Is.Not.Null);
                            Assert.That(pro.SeasonDecision.Choices, Is.Not.Empty);
                            await AdvancePro(store, "season_decision",
                                pro.SeasonDecision.Choices[0].Payload, now);
                            Assert.That(store.Current.Pro.Phase, Is.EqualTo(ProCareerPhase.WeeklyPlan));
                            break;
                        case ProCareerPhase.ImportantGame:
                            sawProImportantGame = true;
                            await CompletePitch(store, PitchCareerKind.Pro,
                                "pro-game-" + pro.Season + "-" + pro.Week, now);
                            break;
                        case ProCareerPhase.SeasonReview:
                            await AdvancePro(store, "review_season", null, now);
                            break;
                        case ProCareerPhase.Offseason:
                            sawOffseason = true;
                            var continueChoice = pro.OffseasonChoices.First(value =>
                                string.Equals(value.Id, "continue_career", StringComparison.Ordinal));
                            Assert.That(continueChoice.Enabled, Is.True);
                            await AdvancePro(store, "offseason", continueChoice.Payload, now);
                            break;
                        default:
                            Assert.Fail("Unexpected pro phase: " + pro.Phase);
                            break;
                    }
                }

                Assert.That(store.Current.Pro.Phase, Is.EqualTo(ProCareerPhase.RetirementDecision));
                Assert.That(store.Current.Stage, Is.EqualTo(ApplicationStage.Retirement));
                Assert.That(store.Current.Pro.Season, Is.EqualTo(12));
                Assert.That(store.Current.Pro.CareerSeasons, Has.Count.EqualTo(12));
                Assert.That(store.Current.Pro.OffseasonChoices.Single(value =>
                    string.Equals(value.Id, "continue_career", StringComparison.Ordinal)).Enabled, Is.False);
                Assert.That(sawSeasonDecision, Is.True);
                Assert.That(sawOffseason, Is.True);
                Assert.That(sawProImportantGame, Is.True);
                var completedGamesBeforeSettlement = store.Current.Meta.CompletedGameCount;
                Assert.That(completedGamesBeforeSettlement,
                    Is.GreaterThan(store.Current.HighSchool.Performance.ImportantGames));

                await Applied(store, Next("retire"),
                    new RetireProCareerCommand(now.AddHours(1)));
                Assert.That(store.Current.Meta.CompletedGameCount,
                    Is.EqualTo(completedGamesBeforeSettlement));
                Assert.That(store.Current.Stage, Is.EqualTo(ApplicationStage.Legacy));
                Assert.That(store.Current.Pro.Phase, Is.EqualTo(ProCareerPhase.Completed));
                Assert.That(store.Current.Meta.LifeArchive, Is.Empty);
                Assert.That(store.Current.HighSchool.FrozenSignatureLegacyCandidates,
                    Has.Count.EqualTo(3));
                Assert.That(store.Current.HighSchool.FrozenSignatureLegacyCandidates
                    .Select(value => value.Id).Distinct().Count(), Is.EqualTo(3));
                Assert.That(store.Current.HighSchool.FrozenSignatureLegacyCandidates,
                    Has.All.Matches<SignatureLegacyReadModel>(value =>
                        value.Score.HasValue && value.EvidenceSummary.Contains("프로 통산")));
                var signature = store.Current.HighSchool.FrozenSignatureLegacyCandidates[0];
                await Applied(store, Next("finalize-legacy"),
                    new FinalizeHighSchoolLegacyCommand(
                        Array.Empty<string>(), signature.Id, now.AddHours(1).AddMinutes(1)));
                Assert.That(store.Current.Meta.CompletedGameCount,
                    Is.EqualTo(completedGamesBeforeSettlement));
                Assert.That(store.Current.Meta.LifeArchive, Has.Count.EqualTo(1));
                var archived = store.Current.Meta.LifeArchive[0];
                Assert.That(archived.ProSeasons, Is.EqualTo(12));
                Assert.That(archived.SignatureLegacy.Id, Is.EqualTo(signature.Id));
                Assert.That(archived.SignatureLegacy.EvidenceSummary,
                    Is.EqualTo(signature.EvidenceSummary));
                Assert.That(archived.SignatureLegacyCandidates, Has.Count.EqualTo(3));
                Assert.That(archived.PlayerLegacy.DefiningMoment,
                    Is.EqualTo(signature.EvidenceSummary));
                Assert.That(archived.HighSchoolDetail, Is.Not.Null);
                Assert.That(archived.HighSchoolDetail.StartingRatings, Is.Not.Null);
                Assert.That(archived.HighSchoolDetail.CoachName, Is.Not.Empty);
                Assert.That(archived.HighSchoolDetail.CatcherName, Is.Not.Empty);
                Assert.That(archived.HighSchoolDetail.RivalName, Is.Not.Empty);
                Assert.That(archived.HighSchoolDetail.Personality, Is.Not.Empty);
                Assert.That(archived.HighSchoolDetail.WindId, Is.Not.Empty);
                Assert.That(archived.HighSchoolDetail.WindTitle, Is.Not.Empty);
                Assert.That(archived.HighSchoolDetail.PresetId, Is.EqualTo("power_prospect"));
                Assert.That(archived.HighSchoolDetail.PresetTitle, Is.EqualTo("강속구 원석"));
                Assert.That(archived.HighSchoolDetail.DifficultyId, Is.EqualTo("standard"));
                Assert.That(archived.HighSchoolDetail.DifficultyTitle, Is.EqualTo("표준"));
                Assert.That(archived.HighSchoolDetail.Talents, Has.Count.EqualTo(4));
                Assert.That(archived.HighSchoolDetail.Talents.Select(value => value.AbilityId),
                    Is.EquivalentTo(new[] { "stuff", "command", "movement", "stamina" }));
                Assert.That(archived.FinalRatings.Stuff, Is.EqualTo(highSchoolFinalRatings.Stuff));
                Assert.That(archived.FinalRatings.Command, Is.EqualTo(highSchoolFinalRatings.Command));
                Assert.That(archived.FinalRatings.Movement, Is.EqualTo(highSchoolFinalRatings.Movement));
                Assert.That(archived.FinalRatings.Stamina, Is.EqualTo(highSchoolFinalRatings.Stamina));
                Assert.That(archived.FinalRatings.Total,
                    Is.GreaterThanOrEqualTo(archived.HighSchoolDetail.StartingRatings.Total));
                Assert.That(archived.Pitches, Is.EqualTo(archived.HighSchoolPerformance.Pitches));
                Assert.That(archived.Outs, Is.EqualTo(archived.HighSchoolPerformance.Outs));
                Assert.That(archived.Hits, Is.EqualTo(archived.HighSchoolPerformance.Hits));

                await Applied(store, Next("rebirth"),
                    new BeginRebirthCommand(now.AddHours(2)));
                Assert.That(store.Current.Meta.CompletedGameCount,
                    Is.EqualTo(completedGamesBeforeSettlement));
                Assert.That(store.Current.Stage, Is.EqualTo(ApplicationStage.BetweenLives));
                Assert.That(store.Current.Meta.LifeNumber, Is.EqualTo(2));
                Assert.That(store.Current.Meta.LifeArchive[0].SignatureLegacy.EvidenceSummary,
                    Is.EqualTo(signature.EvidenceSummary));
                Assert.That(store.Current.HighSchool, Is.Null);
                Assert.That(store.Current.Pro, Is.Null);
                Assert.That(store.Current.Meta.Weekly.Program, Is.Not.Null);
                Assert.That(store.Current.Meta.Weekly.ProcessedReceiptIds, Is.Not.Empty);
            }
        }

        private async Task AdvanceHighSchool(
            GameApplicationStore store,
            string kind,
            string value,
            DateTimeOffset instant)
        {
            await Applied(store, Next("hs-" + kind),
                new AdvanceHighSchoolCommand(new HighSchoolAction(kind, value), instant));
        }

        private async Task AdvancePro(
            GameApplicationStore store,
            string kind,
            string value,
            DateTimeOffset instant)
        {
            var completedBefore = store.Current.Meta.CompletedGameCount;
            await Applied(store, Next("pro-" + kind),
                new AdvanceProCommand(new ProCareerAction(kind, value), instant));
            Assert.That(store.Current.Meta.CompletedGameCount,
                Is.EqualTo(completedBefore),
                "Only a completed interactive important-game pitch session may change the counter.");
        }

        private async Task CompletePitch(
            GameApplicationStore store,
            PitchCareerKind kind,
            string gameId,
            DateTimeOffset instant)
        {
            var completedBefore = store.Current.Meta.CompletedGameCount;
            await Applied(store, Next("pitch-begin"),
                new BeginPitchSessionCommand(gameId, kind, "production", 18, instant));
            var resume = store.Current.PitchResume;
            var initialOuts = resume.Scenario.GameState.InningState?.Outs ?? 0;
            var batters = Math.Min(resume.MaximumBatters, Math.Max(1, 3 - initialOuts));
            PitchGameReport report = null;
            for (var batter = 0; batter < batters; batter++)
            {
                var pitchId = gameId + "-pitch-" + batter;
                await Applied(store, Next("pitch-commit"),
                    new CommitPitchResultCommand(
                        gameId, pitchId, batter, "hash-" + pitchId,
                        "{\"outcome\":\"strikeout\"}",
                        "{\"cue\":\"strikeout\"}", instant.AddSeconds(batter),
                        abilityMomentEvidence: new PitchAbilityMomentEvidence(
                            new PitchCall(
                                PitchType.FourSeam,
                                new PitchZone(1, 1),
                                ZoneIntent.Strike,
                                PitchIntensity.Normal),
                            new PlateAppearanceContext(
                                gameId + "-pa-" + batter, 0, 9, batter, 0, 0, 1, 0, 900, 20),
                            PitchOutcome.Ball,
                            new PitchExecution(0, 0, 0, 0, 1430, 0, 0, 500))));
                report = new PitchGameReport(
                    gameId,
                    (batter + 1) * 5,
                    batter + 1,
                    batter + 1,
                    batter + 1,
                    0,
                    0,
                    0,
                    expectedDamage: (batter + 1) * 100,
                    actualDamage: 0,
                    recommendationAccepted: (batter + 1) * 5);
                await Applied(store, Next("pitch-consume"),
                    new ConsumeCommittedPitchResultCommand(
                        gameId, pitchId, batter + 1,
                        "{\"completedBatters\":" + (batter + 1) + "}",
                        report,
                        sessionCompleted: batter + 1 == batters));
            }

            Assert.That(store.Current.PitchResume.AwaitingCompletion, Is.True);
            await Applied(store, Next("pitch-complete"),
                new CompletePitchSessionCommand(report, instant.AddMinutes(1)));
            var expectedDelta = kind == PitchCareerKind.HighSchool || kind == PitchCareerKind.Pro
                ? 1
                : 0;
            Assert.That(store.Current.Meta.CompletedGameCount,
                Is.EqualTo(completedBefore + expectedDelta));
            var completionId = store.Current.PendingPitchCompletion.CompletionId;
            await Applied(store, Next("pitch-ack"),
                new AcknowledgePitchResultCommand(completionId));
        }

        private static async Task Applied(
            GameApplicationStore store,
            string id,
            GameCommand command)
        {
            var result = await store.DispatchAsync(new CommandEnvelope<GameCommand>(
                id, store.Current.Revision, command));
            Assert.That(result.Status, Is.EqualTo(DispatchStatus.Applied),
                id + ":" + result.ErrorCode);
        }

        private string Next(string prefix)
        {
            _commandNumber++;
            return prefix + "-" + _commandNumber;
        }
    }
}
