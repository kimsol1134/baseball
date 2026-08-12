using System;
using System.Linq;
using Baseball.Core.Catalogs;
using Baseball.Core.Domain;
using Baseball.Core.HighSchool;
using NUnit.Framework;

namespace Baseball.Core.Pro.Tests
{
    [TestFixture]
    public sealed class ProCareerFlowTests
    {
        [TestCase(1UL, "gwangju_phoenix")]
        [TestCase(7UL, "changwon_meteors")]
        [TestCase(42UL, "daegu_forge")]
        [TestCase(777UL, "daejeon_rockets")]
        [TestCase(20260725UL, "jeju_storm")]
        public void DirectTeamSelection_MatchesSwiftSplitMixFixture(
            ulong seed,
            string expectedTeamId)
        {
            Assert.That(DirectProCareerFactory.TeamForSeed(seed).Id,
                Is.EqualTo(expectedTeamId));
        }

        [Test]
        public void OneSeasonKeepsBaseballStatsInPlausibleKernelBands()
        {
            var engine = new ProCareerEngine();
            var fixture = ProFixtureTests.StartParams("77");
            var started = engine.Start(new StartProCareerParams(fixture.Seed, fixture.Identity,
                PitcherPresetCatalog.All[0].Pitcher, fixture.DraftResult, fixture.Entitlement));
            var result = PlaySeason(engine.SignContract(new ProStateParams(started.NextSeed, started.Snapshot)));
            Assert.That(result.Snapshot.Phase, Is.EqualTo(ProCareerPhase.OffseasonDecision));
            var stats = result.Snapshot.CareerStats.Single();
            var strikeoutsPerNine = stats.Strikeouts * 27 / Math.Max(1, stats.InningsOuts);
            var runsPerNine = stats.RunsAllowed * 27 / Math.Max(1, stats.InningsOuts);
            Assert.That(stats.InningsOuts, Is.GreaterThanOrEqualTo(210));
            Assert.That(strikeoutsPerNine, Is.InRange(4, 13));
            Assert.That(runsPerNine, Is.InRange(1, 9));
            Assert.That(result.Snapshot.GameLines.All(line => line.Outs >= 0 && line.Pitches > 0), Is.True);
        }

        [Test]
        public void SeasonDecisionsAreStableUniqueAndApplyOnceWithoutConsumingSeed()
        {
            var engine = new ProCareerEngine();
            var signed = StartSigned("611");
            var catalog = ProCareerEngine.SeasonDecisionWeeks.Select(week => engine.SeasonDecision(signed.Snapshot, week)).ToArray();
            Assert.That(catalog.Length, Is.EqualTo(7));
            Assert.That(catalog.Select(value => value.Type).Distinct().Count(), Is.EqualTo(6));
            Assert.That(catalog.All(value => value.Choices.Count == 3 && value.Choices.Select(choice => choice.Id).Distinct().Count() == 3), Is.True);

            var pending = FindDecision(signed);
            var decision = pending.Snapshot.PendingDecision;
            var choice = decision.Choices.OrderBy(value => value.Effect.FatigueDelta).ThenBy(value => value.Id).First();
            var applied = engine.ApplySeasonDecision(new ApplyProSeasonDecisionParams(pending.NextSeed, pending.Snapshot, decision.Id, choice.Id));
            Assert.That(applied.NextSeed, Is.EqualTo(pending.NextSeed));
            Assert.That(applied.Snapshot.PendingDecision, Is.Null);
            Assert.That(applied.Snapshot.DecisionHistory.Last().ChoiceId, Is.EqualTo(choice.Id));
            Assert.Throws<Baseball.Core.Domain.SimulationException>(() => engine.ApplySeasonDecision(
                new ApplyProSeasonDecisionParams(applied.NextSeed, applied.Snapshot, decision.Id, choice.Id)));
        }

        [Test]
        public void TwelveSeasonCareerReachesRetirementWithBoundedResourcesAndRecords()
        {
            var engine = new ProCareerEngine();
            var result = StartSigned("100");
            for (var season = 1; season <= 12; season++)
            {
                result = PlaySeason(result, preferRecovery: true);
                if (result.Snapshot.Phase == ProCareerPhase.RetirementDecision) break;
                result = engine.ChooseOffseason(new ProOffseasonParams(result.NextSeed, result.Snapshot, OffseasonDecision.ContinueCareer));
            }
            result = engine.ChooseOffseason(new ProOffseasonParams(result.NextSeed, result.Snapshot, OffseasonDecision.Retire));
            Assert.That(result.Snapshot.Phase, Is.EqualTo(ProCareerPhase.Completed));
            Assert.That(result.Snapshot.CareerStats.Count, Is.EqualTo(12));
            Assert.That(result.Snapshot.HallOfFameScore, Is.InRange(0, 100));
            Assert.That(result.Snapshot.Fatigue, Is.InRange(0, 100));
            Assert.That(result.Snapshot.DecisionHistory.GroupBy(value => value.Season).All(group => group.Count() <= 7), Is.True);
            Assert.That(result.Snapshot.News.Last(), Is.Not.Empty);
        }

        [Test]
        public void DynamicImportantGamesExposeOpponentRivalsAndStayWithinSeasonCap()
        {
            var engine = new ProCareerEngine(); var result = StartSigned("77");
            var count = 0; var triggers = new System.Collections.Generic.HashSet<ProSeasonTrigger>();
            while (result.Snapshot.Phase != ProCareerPhase.SeasonReview)
            {
                if (result.Snapshot.Phase == ProCareerPhase.ImportantGame)
                {
                    count++; triggers.Add(result.Snapshot.SeasonTrigger.Value);
                    Assert.That(result.Snapshot.CurrentRival.TeamId, Is.Not.EqualTo(result.Snapshot.Team.Id));
                    result = engine.ResolveImportantGame(new ResolveProGameParams(result.NextSeed, result.Snapshot,
                        new ImportantInningReport(result.Snapshot.Week, 18, 2, 0, 0, 380, 240, 12)));
                }
                else if (result.Snapshot.Phase == ProCareerPhase.SeasonDecision)
                {
                    var decision = result.Snapshot.PendingDecision;
                    var choice = decision.Choices.OrderBy(value => value.Effect.FatigueDelta).ThenBy(value => value.Id).First();
                    result = engine.ApplySeasonDecision(new ApplyProSeasonDecisionParams(result.NextSeed, result.Snapshot, decision.Id, choice.Id));
                }
                else result = engine.PlanWeek(new PlanProWeekParams(result.NextSeed, result.Snapshot, ProWeekPlan.EarnTrust));
            }
            Assert.That(count, Is.InRange(4, 6));
            Assert.That(triggers.Count, Is.GreaterThanOrEqualTo(2));
            Assert.That(result.Snapshot.SeasonImportantGames, Is.EqualTo(count));
        }

        [Test]
        public void OverloadInjuryRequiresDeterministicRecoveryWeeks()
        {
            var engine = new ProCareerEngine(); var result = StartSigned("9091");
            for (var guard = 0; guard < 80 && result.Snapshot.InjuryWeeks == 0; guard++)
            {
                if (result.Snapshot.Phase == ProCareerPhase.ImportantGame)
                    result = engine.ResolveImportantGame(new ResolveProGameParams(result.NextSeed, result.Snapshot,
                        new ImportantInningReport(result.Snapshot.Week, 20, 0, 3, 5, 1200, 3000, 0)));
                else if (result.Snapshot.Phase == ProCareerPhase.SeasonDecision)
                {
                    var decision = result.Snapshot.PendingDecision; var choice = decision.Choices.OrderByDescending(value => value.Effect.FatigueDelta).First();
                    result = engine.ApplySeasonDecision(new ApplyProSeasonDecisionParams(result.NextSeed, result.Snapshot, decision.Id, choice.Id));
                }
                else if (result.Snapshot.Phase == ProCareerPhase.SeasonReview)
                {
                    result = engine.ReviewSeason(new ProStateParams(result.NextSeed, result.Snapshot));
                    result = engine.ChooseOffseason(new ProOffseasonParams(result.NextSeed, result.Snapshot, OffseasonDecision.ContinueCareer));
                }
                else result = engine.PlanWeek(new PlanProWeekParams(result.NextSeed, result.Snapshot, ProWeekPlan.DevelopWeapon));
            }
            Assert.That(result.Snapshot.InjuryWeeks, Is.GreaterThan(0));
            var injuryWeeks = result.Snapshot.InjuryWeeks;
            var fatigue = result.Snapshot.Fatigue;
            result = engine.PlanWeek(new PlanProWeekParams(result.NextSeed, result.Snapshot, ProWeekPlan.Recover));
            Assert.That(result.Snapshot.InjuryWeeks, Is.EqualTo(injuryWeeks - 1));
            Assert.That(result.Snapshot.Fatigue, Is.LessThan(fatigue));
            Assert.That(result.Snapshot.CurrentStats.Games, Is.EqualTo(result.Snapshot.GameLines.Count));
        }

        [Test]
        public void LockedAndUndraftedStartsAreRejected()
        {
            var valid = ProFixtureTests.StartParams("1");
            var locked = new StartProCareerParams(valid.Seed, valid.Identity, valid.Pitcher, valid.DraftResult,
                new ProEntitlementSnapshot(EntitlementStatus.Locked, EntitlementSource.Development, "fixture"));
            Assert.Throws<Baseball.Core.Domain.SimulationException>(() => new ProCareerEngine().Start(locked));
            var undrafted = new DraftResultSnapshot(DraftOutcome.Undrafted, 40, "미지명", null, null, null, null, null, Array.Empty<string>(), "");
            Assert.Throws<Baseball.Core.Domain.SimulationException>(() => new ProCareerEngine().Start(
                new StartProCareerParams("1", valid.Identity, valid.Pitcher, undrafted, valid.Entitlement)));
        }

        [Test]
        public void ProRecordsExtendSignatureLegacyWithoutChangingHighSchoolContract()
        {
            var highSchool = new HighSchoolCareerEngine().Start(
                new StartHighSchoolCareerParams("55", "precision_commander")).Snapshot;
            var pro = StartSigned("55").Snapshot;
            var first = ProCareerLegacy.Candidates(highSchool.Pitcher, highSchool, pro);
            var replay = ProCareerLegacy.Candidates(highSchool.Pitcher, highSchool, pro);
            Assert.That(first.Count, Is.EqualTo(3));
            Assert.That(first.Select(value => value.Legacy.Id), Is.EqualTo(replay.Select(value => value.Legacy.Id)));
            Assert.That(first.All(value => value.Evidence.Summary.Contains("프로 통산")), Is.True);
            Assert.That(first.Select(value => value.Legacy.Id).Distinct().Count(), Is.EqualTo(3));
        }

        [Test]
        public void StuffAndMovementUseIndependentTwoWeekProgressAndMovementTargetsOnePitch()
        {
            var engine = new ProCareerEngine();
            ProCareerResult stuffStart = null;
            ProCareerResult stuffFirst = null;
            for (var seed = 1000; seed < 3000 && stuffStart == null; seed++)
            {
                var candidate = engine.StartDirect(new StartDirectProParams(
                    seed.ToString(), "breaking_ball_artist", "서하준", ProCareerEngine.ProTeams[0].Id));
                var first = engine.PlanWeek(new PlanProWeekParams(
                    candidate.NextSeed, candidate.Snapshot, ProWeekPlan.DevelopStuff));
                if (first.Snapshot.Phase == ProCareerPhase.WeeklyPlan)
                {
                    stuffStart = candidate;
                    stuffFirst = first;
                }
            }
            Assert.That(stuffStart, Is.Not.Null);
            Assert.That(stuffFirst.Snapshot.DevelopmentProgress.Stuff, Is.EqualTo(1));
            Assert.That(stuffFirst.Snapshot.Pitcher.Stuff, Is.EqualTo(stuffStart.Snapshot.Pitcher.Stuff));
            var stuffSecond = engine.PlanWeek(new PlanProWeekParams(
                stuffFirst.NextSeed, stuffFirst.Snapshot, ProWeekPlan.DevelopStuff));
            Assert.That(stuffSecond.Snapshot.DevelopmentProgress.Stuff, Is.Zero);
            Assert.That(stuffSecond.Snapshot.Pitcher.Stuff, Is.EqualTo(stuffStart.Snapshot.Pitcher.Stuff + 1));
            Assert.That(stuffSecond.Snapshot.DevelopmentProgress.Movement, Is.Zero);

            ProCareerResult movementStart = null;
            ProCareerResult movementFirst = null;
            for (var seed = 3000; seed < 5000 && movementStart == null; seed++)
            {
                var candidate = engine.StartDirect(new StartDirectProParams(
                    seed.ToString(), "breaking_ball_artist", "서하준", ProCareerEngine.ProTeams[0].Id));
                var first = engine.PlanWeek(new PlanProWeekParams(
                    candidate.NextSeed, candidate.Snapshot, ProWeekPlan.DevelopMovement, PitchType.Slider));
                if (first.Snapshot.Phase == ProCareerPhase.WeeklyPlan)
                {
                    movementStart = candidate;
                    movementFirst = first;
                }
            }
            Assert.That(movementStart, Is.Not.Null);
            var sliderBefore = movementStart.Snapshot.Pitcher.Profile(PitchType.Slider);
            var curveBefore = movementStart.Snapshot.Pitcher.Profile(PitchType.Curveball);
            var movementSecond = engine.PlanWeek(new PlanProWeekParams(
                movementFirst.NextSeed, movementFirst.Snapshot, ProWeekPlan.DevelopMovement, PitchType.Slider));
            Assert.That(movementSecond.Snapshot.DevelopmentProgress.Movement, Is.Zero);
            Assert.That(movementSecond.Snapshot.Pitcher.Movement, Is.EqualTo(movementStart.Snapshot.Pitcher.Movement + 1));
            Assert.That(movementSecond.Snapshot.Pitcher.Profile(PitchType.Slider).Movement, Is.EqualTo(sliderBefore.Movement + 2));
            Assert.That(movementSecond.Snapshot.Pitcher.Profile(PitchType.Slider).Whiff, Is.EqualTo(sliderBefore.Whiff + 1));
            Assert.That(movementSecond.Snapshot.Pitcher.Profile(PitchType.Curveball).Movement, Is.EqualTo(curveBefore.Movement));
        }

        [Test]
        public void LegacyDevelopWeaponWireRemainsStableAndAdvancesBothNewGauges()
        {
            var engine = new ProCareerEngine();
            var result = StartSigned("3901");
            result = engine.PlanWeek(new PlanProWeekParams(
                result.NextSeed, result.Snapshot, ProWeekPlan.DevelopWeapon));
            Assert.That(ProWeekPlan.DevelopWeapon.Value(), Is.EqualTo("develop_weapon"));
            Assert.That(result.Snapshot.DevelopmentProgress.Stuff, Is.EqualTo(1));
            Assert.That(result.Snapshot.DevelopmentProgress.Movement, Is.EqualTo(1));
        }

        [Test]
        public void SegmentAdvanceStopsAtFirstSegmentOrDecisionBoundary()
        {
            var engine = new ProCareerEngine();
            var result = StartSigned("4021");
            var first = engine.AdvanceSegment(new AdvanceProSegmentParams(
                result.NextSeed, result.Snapshot, ProWeekPlan.Recover));
            Assert.That(first.Progress.AdvancedWeeks, Is.EqualTo(1));
            Assert.That(first.Progress.StopReason, Is.EqualTo(ProSegmentStopReason.SegmentChanged));
            Assert.That(first.Career.Snapshot.Week, Is.EqualTo(1));

            if (first.Career.Snapshot.Phase == ProCareerPhase.WeeklyPlan)
            {
                var next = engine.AdvanceSegment(new AdvanceProSegmentParams(
                    first.Career.NextSeed, first.Career.Snapshot, ProWeekPlan.Recover));
                Assert.That(next.Progress.AdvancedWeeks, Is.InRange(1, 4));
                Assert.That(next.Career.Snapshot.Phase != ProCareerPhase.WeeklyPlan ||
                            next.Progress.EndingSegment != next.Progress.StartingSegment,
                    Is.True);
            }
        }

        [Test]
        public void WeeklyRecommendationUsesFatigueCallupThenStablePitcherIdentityPrecedence()
        {
            var pitcher = new PitcherSnapshot("p", "투수", 60, 60, 60, 60);
            var fatigue = ProWeekRecommendationRules.Resolve(68, ProLevel.Major, 80, pitcher);
            Assert.That(fatigue.Plan, Is.EqualTo(ProWeekPlan.Recover));
            Assert.That(fatigue.Reason, Is.EqualTo("부상 예방"));

            var callup = ProWeekRecommendationRules.Resolve(67, ProLevel.Minor, 59, pitcher);
            Assert.That(callup.Plan, Is.EqualTo(ProWeekPlan.EarnTrust));
            Assert.That(callup.Reason, Is.EqualTo("콜업 우선"));

            var identity = ProWeekRecommendationRules.Resolve(0, ProLevel.Major, 80, pitcher);
            Assert.That(PitcherBuildRules.Identity(pitcher), Is.EqualTo(PitcherBuildIdentity.Power));
            Assert.That(identity.Plan, Is.EqualTo(ProWeekPlan.DevelopStuff));
            Assert.That(identity.Reason, Is.EqualTo("강속구형 강화"));
        }

        private static ProCareerResult StartSigned(string seed)
        {
            var engine = new ProCareerEngine();
            var result = engine.Start(ProFixtureTests.StartParams(seed));
            return engine.SignContract(new ProStateParams(result.NextSeed, result.Snapshot));
        }

        private static ProCareerResult PlaySeason(ProCareerResult initial, bool preferRecovery = false)
        {
            var engine = new ProCareerEngine();
            var result = initial;
            var guard = 0;
            while (result.Snapshot.Phase != ProCareerPhase.SeasonReview && guard++ < 160)
            {
                if (result.Snapshot.Phase == ProCareerPhase.ImportantGame)
                {
                    var report = new ImportantInningReport(result.Snapshot.Week, 18, 2, 0, 0, 380, 240, 12, outs: 3, hits: 1);
                    result = engine.ResolveImportantGame(new ResolveProGameParams(result.NextSeed, result.Snapshot, report));
                }
                else if (result.Snapshot.Phase == ProCareerPhase.SeasonDecision)
                {
                    var pending = result.Snapshot.PendingDecision;
                    var choice = pending.Choices.OrderBy(value => value.Effect.FatigueDelta).ThenBy(value => value.Id).First();
                    result = engine.ApplySeasonDecision(new ApplyProSeasonDecisionParams(result.NextSeed, result.Snapshot, pending.Id, choice.Id));
                }
                else
                {
                    var plan = preferRecovery ? ProWeekPlan.Recover : result.Snapshot.Fatigue > 72 ? ProWeekPlan.Recover : result.Snapshot.ManagerTrust < 62 ? ProWeekPlan.EarnTrust : ProWeekPlan.RefineCommand;
                    result = engine.PlanWeek(new PlanProWeekParams(result.NextSeed, result.Snapshot, plan));
                }
            }
            Assert.That(guard, Is.LessThan(160));
            return engine.ReviewSeason(new ProStateParams(result.NextSeed, result.Snapshot));
        }

        private static ProCareerResult FindDecision(ProCareerResult initial)
        {
            var engine = new ProCareerEngine(); var result = initial;
            for (var guard = 0; guard < 120 && result.Snapshot.Phase != ProCareerPhase.SeasonDecision; guard++)
            {
                if (result.Snapshot.Phase == ProCareerPhase.ImportantGame)
                    result = engine.ResolveImportantGame(new ResolveProGameParams(result.NextSeed, result.Snapshot,
                        new ImportantInningReport(result.Snapshot.Week, 18, 2, 0, 0, 380, 240, 12)));
                else result = engine.PlanWeek(new PlanProWeekParams(result.NextSeed, result.Snapshot, ProWeekPlan.Recover));
            }
            Assert.That(result.Snapshot.Phase, Is.EqualTo(ProCareerPhase.SeasonDecision));
            return result;
        }
    }
}
