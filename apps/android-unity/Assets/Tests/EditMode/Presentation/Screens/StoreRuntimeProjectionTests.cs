using System.Threading;
using System.Threading.Tasks;
using System;
using System.Collections.Generic;
using System.Linq;
using Baseball.Application.Commands;
using Baseball.Application.Persistence;
using Baseball.Application.HighSchool;
using Baseball.Application.Meta;
using Baseball.Application.Pro;
using Baseball.Presentation.Shell;
using NUnit.Framework;
using UnityEngine;

namespace Baseball.Presentation.Tests
{
    public sealed class StoreRuntimeProjectionTests
    {
        [Test]
        public void LoadingProjectionIsKoreanAndHasNoFalseSuccessAction()
        {
            IKoreanUiCopyCatalog copy = KoreanUiCopyCatalog.LoadDefault();
            GameSaveAggregate state = null;
            var model = new StoreBaseballCareerReadModel(
                copy,
                () => state,
                () => ShellRuntimeStatus.Loading,
                () => "안전하게 저장된 진행 상황을 확인하는 중입니다.");

            BaseballScreenViewModel screen = model.Read(ShellRoute.Opening);

            Assert.That(screen.Title, Does.Contain("준비"));
            Assert.That(screen.Lead, Does.Contain("저장"));
            Assert.That(screen.Actions, Is.Empty);
        }

        [Test]
        public void ReadyProjectionUsesStoredStageAndManifestAddress()
        {
            IKoreanUiCopyCatalog copy = KoreanUiCopyCatalog.LoadDefault();
            GameSaveAggregate state = GameSaveAggregate.Initial("installation");
            var model = new StoreBaseballCareerReadModel(
                copy,
                () => state,
                () => ShellRuntimeStatus.Ready,
                () => string.Empty);

            BaseballScreenViewModel screen = model.Read(ShellRoute.Opening);

            Assert.That(model.PreferredRoute, Is.EqualTo(ShellRoute.Opening));
            Assert.That(screen.KeyArtAddress, Is.EqualTo("baseball/bootstrap/LaunchLogo"));
            Assert.That(screen.Actions[0].Id, Is.EqualTo("enter_setup"));
            Assert.That(screen.Actions[0].IsEnabled, Is.True);
        }

        [Test]
        public void PrologueAlwaysOffersTutorialPitchAndExplicitSchoolSelectionSkip()
        {
            var highSchool = new HighSchoolCareerReadModel(
                "career",
                1,
                HighSchoolPhase.Prologue,
                "seed",
                1,
                "player",
                "해온",
                "power_prospect",
                new PitcherRatingsReadModel(55, 53, 51, 54),
                new CareerPerformanceReadModel());
            GameSaveAggregate state = GameSaveAggregate.Initial("install").Commit(
                "prologue",
                stage: ApplicationStage.HighSchool,
                highSchool: highSchool);
            var model = ReadyModel(() => state);

            BaseballScreenViewModel screen = model.Read(ShellRoute.Prologue);

            Assert.That(screen.Actions.Select(action => action.Id),
                Is.EqualTo(new[] { "begin_tutorial_pitch", "skip_tutorial" }));
            Assert.That(screen.Actions[0].Label, Is.EqualTo("첫 공을 던진다"));
            Assert.That(screen.Actions[0].Style, Is.EqualTo(ScreenActionStyle.Primary));
            Assert.That(screen.Actions[1].Label, Is.EqualTo("바로 학교 고르기"));
            Assert.That(screen.Actions[1].Style, Is.EqualTo(ScreenActionStyle.Secondary));
        }

        [Test]
        public void DraftedCompletedRecapRequiresExplicitProStartOrConfirmedDecline()
        {
            var highSchool = new HighSchoolCareerReadModel(
                "career",
                1,
                HighSchoolPhase.Completed,
                "seed",
                9,
                "player",
                "해온",
                "power_prospect",
                new PitcherRatingsReadModel(70, 66, 64, 68),
                new CareerPerformanceReadModel(4, 28, 6, 3),
                "fictional-school",
                "별빛고",
                draft: new DraftReadModel(true, true, 84, "fictional-club", "해오름", 2, 17));
            GameSaveAggregate state = GameSaveAggregate.Initial("install").Commit(
                "drafted-completed",
                stage: ApplicationStage.Draft,
                highSchool: highSchool);
            var model = ReadyModel(() => state);

            BaseballScreenViewModel recap = model.Read(ShellRoute.RunRecap);
            ScreenActionViewModel start = recap.Actions.Single(action => action.Id == "enter_pro");
            ScreenActionViewModel decline = recap.Actions.Single(action => action.Id == "decline_pro");

            Assert.That(model.PreferredRoute, Is.EqualTo(ShellRoute.RunRecap));
            Assert.That(start.Label, Is.EqualTo("프로 커리어 시작"));
            Assert.That(start.Target, Is.EqualTo(ShellRoute.ProContract));
            Assert.That(start.Style, Is.EqualTo(ScreenActionStyle.Primary));
            Assert.That(decline.Label, Is.EqualTo("프로 진출 포기"));
            Assert.That(decline.Style, Is.EqualTo(ScreenActionStyle.Destructive));
            Assert.That(decline.RequiresConfirmation, Is.True);
            Assert.That(recap.Actions.Select(action => action.Id),
                Does.Not.Contain("finalize_high_school_legacy"));
        }

        [Test]
        public void LinkedProRetirementRequiresOneOfThreeFrozenLegacyChoices()
        {
            var frozen = new[]
            {
                new SignatureLegacyReadModel("legacy-a", "첫 번째 유산", "설명 A", "근거 A", 90),
                new SignatureLegacyReadModel("legacy-b", "두 번째 유산", "설명 B", "근거 B", 80),
                new SignatureLegacyReadModel("legacy-c", "세 번째 유산", "설명 C", "근거 C", 70),
            };
            var highSchool = new HighSchoolCareerReadModel(
                "career",
                1,
                HighSchoolPhase.Legacy,
                "seed",
                11,
                "player",
                "해온",
                "power_prospect",
                new PitcherRatingsReadModel(70, 66, 64, 68),
                new CareerPerformanceReadModel(4, 28, 6, 3),
                signatureLegacyChoices: frozen.Select(value => new CareerChoiceReadModel(
                    value.Id, value.Title, value.Detail, value.EvidenceSummary)).ToArray(),
                legacySelectionMode: LegacySelectionMode.SignatureLegacy,
                frozenSignatureLegacyCandidates: frozen);
            var pro = new ProCareerReadModel(
                "pro-career",
                ProCareerOrigin.HighSchool,
                ProCareerPhase.Completed,
                "pro-seed",
                20,
                "player",
                "해온",
                "fictional-club",
                "해오름",
                12,
                24,
                new PitcherRatingsReadModel(82, 78, 76, 74),
                new CareerPerformanceReadModel());
            GameSaveAggregate state = GameSaveAggregate.Initial("install").Commit(
                "linked-pro-retired",
                stage: ApplicationStage.Legacy,
                highSchool: highSchool,
                pro: pro);
            var selected = string.Empty;
            var model = new StoreBaseballCareerReadModel(
                KoreanUiCopyCatalog.LoadDefault(),
                () => state,
                () => ShellRuntimeStatus.Ready,
                () => string.Empty,
                selectedChoice: group => group == "legacy_signature" ? selected : string.Empty);

            BaseballScreenViewModel missing = model.Read(ShellRoute.RunRecap);
            ScreenChoiceGroupViewModel group = missing.ChoiceGroups.Single(value =>
                value.Id == "legacy_signature");
            Assert.That(group.Choices.Select(value => value.Title),
                Is.EqualTo(new[] { "첫 번째 유산", "두 번째 유산", "세 번째 유산" }));
            Assert.That(group.Choices.Select(value => value.Detail),
                Is.EqualTo(new[] { "설명 A", "설명 B", "설명 C" }));
            Assert.That(missing.Actions.Single(action =>
                action.Id == "finalize_high_school_legacy").IsEnabled, Is.False);

            selected = "legacy-b";
            BaseballScreenViewModel ready = model.Read(ShellRoute.RunRecap);
            Assert.That(ready.Actions.Single(action =>
                action.Id == "finalize_high_school_legacy").IsEnabled, Is.True);
        }

        [Test]
        public void RecordsProjectsAuthoritativeActiveHighSchoolAndProDepthOnTheSameScreen()
        {
            var highSchool = new HighSchoolCareerReadModel(
                "career",
                2,
                HighSchoolPhase.Training,
                "seed",
                13,
                "player",
                "새봄",
                "precision_commander",
                new PitcherRatingsReadModel(71, 79, 68, 73),
                new CareerPerformanceReadModel(5, 90, 21, 14, 6, 7, 3),
                schoolName: "별빛고",
                awakenings: new[] { "pinpoint_edge" },
                prospectRankings: new[]
                {
                    new ProspectEntryReadModel(1, "새봄", "별빛고", "제구형", true),
                    new ProspectEntryReadModel(2, "도윤", "푸른솔고", "강속구형", false),
                },
                fatigue: 17,
                armRisk: 9,
                managerTrust: 74,
                catcherTrust: 81,
                fanInterest: 88,
                news: new[] { "새봄이 다음 경기 선발로 예고됐다." },
                lifeDetail: new HighSchoolLifeDetailReadModel(
                    personality: "차분한 승부사",
                    windTitle: "끝까지 낮게 던지는 바람"));
            var pro = new ProCareerReadModel(
                "pro-career",
                ProCareerOrigin.Direct,
                ProCareerPhase.WeeklyPlan,
                "pro-seed",
                21,
                "pro-player",
                "해온",
                "fictional-club",
                "해오름",
                3,
                11,
                new PitcherRatingsReadModel(83, 76, 81, 78),
                new CareerPerformanceReadModel(8, 120, 30, 24, 7, 9, 4),
                managerTrust: 72,
                catcherTrust: 69,
                fatigue: 22,
                leagueStandings: new[]
                {
                    new LeagueStandingReadModel(1, "club-a", "해오름", 18, 9, 1, 0, true),
                    new LeagueStandingReadModel(2, "club-b", "푸른물결", 16, 11, 1, 2.0, false),
                },
                leaguePitchers: new[]
                {
                    new LeaguePitcherReadModel(1, "해온", "해오름", 63, 5, 1, 0, 51, 12, 18, 7, true),
                    new LeaguePitcherReadModel(2, "지후", "푸른물결", 60, 4, 2, 1, 46, 14, 20, 9, false),
                });
            GameSaveAggregate state = GameSaveAggregate.Initial("install").Commit(
                "active-records",
                stage: ApplicationStage.Pro,
                highSchool: highSchool,
                pro: pro);

            BaseballScreenViewModel records = ReadyModel(() => state).Read(ShellRoute.Records);
            ScreenRowViewModel hsRatings = records.Sections
                .Single(section => section.Id == "records-current-high-school").Rows
                .Single(row => row.Id == "records-current-hs-ratings");
            ScreenRowViewModel hsAdvanced = records.Sections
                .Single(section => section.Id == "records-current-high-school").Rows
                .Single(row => row.Id == "records-current-hs-advanced");
            ScreenRowViewModel proRatings = records.Sections
                .Single(section => section.Id == "records-current-pro").Rows
                .Single(row => row.Id == "records-current-pro-ratings");

            Assert.That(hsRatings.Value, Is.EqualTo("구위 71 · 제구 79 · 변화 68 · 체력 73"));
            Assert.That(hsRatings.Detail, Is.EqualTo("팬 관심 88 · 포수와의 호흡 81 · 지도자의 믿음 74"));
            Assert.That(hsAdvanced.Value,
                Is.EqualTo("9이닝당 탈삼진 18.0 · 볼넷 7.7 · 실점 3.9"));
            Assert.That(records.Sections.Single(section =>
                    section.Id == "records-current-high-school").Rows
                .Single(row => row.Id == "records-current-hs-identity").Value,
                Is.EqualTo("차분한 승부사"));
            Assert.That(records.Sections.Single(section =>
                    section.Id == "records-current-hs-prospects").Rows[0].Detail,
                Is.EqualTo("제구형 · 내 선수"));
            Assert.That(proRatings.Value, Is.EqualTo("구위 83 · 제구 76 · 변화 81 · 체력 78"));
            Assert.That(records.Sections.Single(section =>
                    section.Id == "records-current-pro-standings").Rows[0].Detail,
                Is.EqualTo("선두 · 내 구단"));
            Assert.That(records.Sections.Single(section =>
                    section.Id == "records-current-pro-leaders").Rows[0].Value,
                Is.EqualTo("해오름 · 21이닝 · 탈삼진 51"));
            Assert.That(records.Sections.Single(section =>
                    section.Id == "records-current-pro-leaders").Rows[0].Detail,
                Does.Contain("내 선수"));
            Assert.That(records.Sections.SelectMany(section => section.Rows)
                .Single(row => row.Id == "records-current-hs-news").Value,
                Is.EqualTo("새봄이 다음 경기 선발로 예고됐다."));
            Assert.That(records.Sections.SelectMany(section => section.Rows)
                .Single(row => row.Id == "records-current-hs-awakenings").Value,
                Is.EqualTo("바늘끝 제구"));
        }

        [Test]
        public void DirectProIsHiddenOnFirstLifeAndUnlockedOnDedicatedSurfaceAfterArchive()
        {
            GameSaveAggregate state = GameSaveAggregate.Initial("install").Commit(
                "setup",
                stage: ApplicationStage.Setup);
            var model = ReadyModel(() => state);

            Assert.That(model.Read(ShellRoute.Setup).Actions.Select(action => action.Id),
                Does.Not.Contain("start_direct_pro"));
            Assert.That(model.Read(ShellRoute.Setup).Actions.Select(action => action.Id),
                Does.Not.Contain("navigate_direct_pro_entry"));
            Assert.That(model.Read(ShellRoute.ProContract).Actions.Select(action => action.Id),
                Does.Not.Contain("start_direct_pro"));

            state = state.Commit(
                "first-life-archived",
                meta: new MetaProgressState(lifeNumber: 2, lifeArchive: new[] { ArchivedLife(null) }));
            Assert.That(model.Read(ShellRoute.Setup).Actions.Select(action => action.Id),
                Does.Contain("navigate_direct_pro_entry"));
            ScreenActionViewModel direct = model.Read(ShellRoute.ProContract).Actions
                .Single(action => action.Id == "start_direct_pro");
            Assert.That(direct.Label, Is.EqualTo("고교를 건너뛰고 바로 프로 시작"));
            Assert.That(direct.Target, Is.EqualTo(ShellRoute.ProWeek));
        }

        [Test]
        public void LaterLifeHighSchoolCanOpenDirectProSurfaceWithoutChangingCareerRoute()
        {
            var highSchool = new HighSchoolCareerReadModel(
                "active-career",
                2,
                HighSchoolPhase.Training,
                "seed",
                3,
                "player",
                "새봄",
                "power_prospect",
                new PitcherRatingsReadModel(55, 53, 51, 54),
                new CareerPerformanceReadModel());
            GameSaveAggregate state = GameSaveAggregate.Initial("install").Commit(
                "later-life",
                stage: ApplicationStage.HighSchool,
                highSchool: highSchool,
                meta: new MetaProgressState(lifeNumber: 2, lifeArchive: new[] { ArchivedLife(null) }));
            var model = ReadyModel(() => state);

            ScreenActionViewModel entry = model.Read(ShellRoute.HighSchoolOverview).Actions
                .Single(action => action.Id == "navigate_direct_pro_entry");
            ScreenActionViewModel direct = model.Read(ShellRoute.ProContract).Actions
                .Single(action => action.Id == "start_direct_pro");

            Assert.That(entry.Target, Is.EqualTo(ShellRoute.ProContract));
            Assert.That(direct.Hint, Does.Contain("고교 선수는 그대로 보존"));
            Assert.That(model.PreferredRoute, Is.EqualTo(ShellRoute.Training));
        }

        [Test]
        public async Task VisualAssetBoundaryCanBeReplacedByDeterministicFake()
        {
            var fake = new FakeVisualLoader();
            using IBaseballVisualAssetLease lease = await fake.LoadSpriteAsync(
                "baseball/highschool/KeyArtAwakening",
                CancellationToken.None);

            Assert.That(fake.LastAddress, Is.EqualTo("baseball/highschool/KeyArtAwakening"));
            Assert.That(lease.Sprite, Is.Null);
        }

        [Test]
        public void PendingLegacyDailyResultReturnsToRecordsAndRequiresSavedAcknowledgement()
        {
            GameSaveAggregate state = GameSaveAggregate.Initial("installation").Commit(
                "pitch-complete",
                pendingPitchCompletion: new PendingPitchCompletion(
                    "completion",
                    PitchCareerKind.Daily,
                    "daily:20260811",
                    new PitchGameReport("daily-game", 3, 1, 1, 1, 0, 0, 0),
                    1));
            var model = new StoreBaseballCareerReadModel(
                KoreanUiCopyCatalog.LoadDefault(),
                () => state,
                () => ShellRuntimeStatus.Ready,
                () => string.Empty);

            BaseballScreenViewModel screen = model.Read(ShellRoute.Daily);

            Assert.That(model.PreferredRoute, Is.EqualTo(ShellRoute.Records));
            Assert.That(screen.Actions, Has.Count.EqualTo(1));
            Assert.That(screen.Actions[0].Id, Is.EqualTo("acknowledge_pitch_result"));
            Assert.That(screen.Actions[0].Target, Is.EqualTo(ShellRoute.Records));
        }

        [TestCase(ShellRoute.Awakening, ShellRoute.Awakening)]
        [TestCase(ShellRoute.ProWeek, ShellRoute.ProWeek)]
        [TestCase(ShellRoute.Daily, ShellRoute.Records)]
        public void CompletedPitchUsesSavedCareerRouteInsteadOfLegacyFallback(
            ShellRoute preferredRoute,
            ShellRoute expected)
        {
            ShellRoute destination = BaseballShellController.ResolvePitchReturnRoute(
                ShellRuntimeStatus.Ready,
                preferredRoute,
                ShellRoute.Awakening);

            Assert.That(destination, Is.EqualTo(expected));
        }

        [Test]
        public void ProSavedStateAfterAcknowledgementReturnsToWeeklyPlan()
        {
            var pro = new ProCareerReadModel(
                "pro-career",
                ProCareerOrigin.Direct,
                ProCareerPhase.WeeklyPlan,
                "next-seed",
                3,
                "player",
                "투수",
                "fictional-club",
                "해오름",
                1,
                4,
                new PitcherRatingsReadModel(60, 58, 57, 55),
                new CareerPerformanceReadModel());
            GameSaveAggregate state = GameSaveAggregate.Initial("installation").Commit(
                "pro-result-acknowledged",
                stage: ApplicationStage.Pro,
                pro: pro,
                clearPendingPitchCompletion: true);

            Assert.That(StoreBaseballCareerReadModel.PreferredRouteFor(state), Is.EqualTo(ShellRoute.ProWeek));
        }

        [Test]
        public void HighSchoolSavedStateAfterAcknowledgementReturnsToAwakening()
        {
            var highSchool = new HighSchoolCareerReadModel(
                "high-school-career",
                1,
                HighSchoolPhase.Awakening,
                "next-seed",
                3,
                "player",
                "투수",
                "power_prospect",
                new PitcherRatingsReadModel(55, 53, 51, 54),
                new CareerPerformanceReadModel(),
                "fictional-school",
                "한빛전통고");
            GameSaveAggregate state = GameSaveAggregate.Initial("installation").Commit(
                "high-school-result-acknowledged",
                stage: ApplicationStage.HighSchool,
                highSchool: highSchool,
                clearPendingPitchCompletion: true);

            Assert.That(StoreBaseballCareerReadModel.PreferredRouteFor(state), Is.EqualTo(ShellRoute.Awakening));
        }

        [Test]
        public void UnavailableRuntimeFallsBackToOriginalPitchReturnRoute()
        {
            ShellRoute destination = BaseballShellController.ResolvePitchReturnRoute(
                ShellRuntimeStatus.Unavailable,
                ShellRoute.ProWeek,
                ShellRoute.ImportantGame);

            Assert.That(destination, Is.EqualTo(ShellRoute.ImportantGame));
        }

        [Test]
        public void EveryProductionRouteOmitsUnprojectedTemplateValuesAndPlaceholderCopy()
        {
            var highSchool = new HighSchoolCareerReadModel(
                "high-school-career",
                1,
                HighSchoolPhase.Training,
                "next-seed",
                2,
                "player",
                "한결",
                "power_prospect",
                new PitcherRatingsReadModel(61, 57, 55, 58),
                new CareerPerformanceReadModel(2, 7, 2, 1),
                "fictional-school",
                "해솔고",
                remainingImportantGames: 2,
                remainingChapterAdvances: 1,
                fatigue: 18,
                armRisk: 9);
            var pro = new ProCareerReadModel(
                "pro-career",
                ProCareerOrigin.Direct,
                ProCareerPhase.WeeklyPlan,
                "next-pro-seed",
                3,
                "player",
                "한결",
                "fictional-club",
                "해오름",
                1,
                4,
                new PitcherRatingsReadModel(67, 61, 59, 63),
                new CareerPerformanceReadModel(3, 11, 3, 2),
                role: "starter",
                fatigue: 14);
            GameSaveAggregate state = GameSaveAggregate.Initial("installation").Commit(
                "populated-routes",
                stage: ApplicationStage.Pro,
                highSchool: highSchool,
                pro: pro);
            var model = new StoreBaseballCareerReadModel(
                KoreanUiCopyCatalog.LoadDefault(),
                () => state,
                () => ShellRuntimeStatus.Ready,
                () => string.Empty);

            foreach (ShellRoute route in Enum.GetValues(typeof(ShellRoute)))
            {
                BaseballScreenViewModel screen = model.Read(route);
                foreach (ScreenRowViewModel row in screen.Sections.SelectMany(section => section.Rows))
                {
                    Assert.That(row.Value, Is.Not.EqualTo("—"), route + ":" + row.Id);
                    Assert.That(row.Detail, Does.Not.Contain("현재 저장 상태에 기록되지 않는 항목"), route + ":" + row.Id);
                    Assert.That(row.Value, Does.Not.Contain("placeholder").IgnoreCase, route + ":" + row.Id);
                    Assert.That(row.Detail, Does.Not.Contain("placeholder").IgnoreCase, route + ":" + row.Id);
                }
            }
        }

        [Test]
        public void ConditionalCareerPayloadsRequirePitchOnlyForBreakingBallAndMovementPlan()
        {
            Assert.That(CareerActionSelectionPolicy.TrainingPayload(
                "breaking_ball", "standard", null, true), Is.Null);
            Assert.That(CareerActionSelectionPolicy.TrainingPayload(
                "breaking_ball", "standard", "slider", true),
                Is.EqualTo("breaking_ball:standard:slider"));
            Assert.That(CareerActionSelectionPolicy.TrainingPayload(
                "velocity", "standard", "stale-slider", true),
                Is.EqualTo("velocity:standard"));

            Assert.That(CareerActionSelectionPolicy.ProWeekPayload(
                "develop_movement", null, true), Is.Null);
            Assert.That(CareerActionSelectionPolicy.ProWeekPayload(
                "develop_movement", "curveball", true),
                Is.EqualTo("develop_movement|curveball"));
            Assert.That(CareerActionSelectionPolicy.ProWeekPayload(
                "develop_stuff", "stale-curveball", true),
                Is.EqualTo("develop_stuff"));
        }

        [Test]
        public void ReminderNudgeAppearsOnlyAfterOfficialGameAndBeforePermissionDecision()
        {
            var highSchool = new HighSchoolCareerReadModel(
                "career",
                1,
                HighSchoolPhase.ChapterReview,
                "seed",
                3,
                "player",
                "투수",
                "power_prospect",
                new PitcherRatingsReadModel(55, 53, 51, 54),
                new CareerPerformanceReadModel(importantGames: 1),
                "fictional-school",
                "해솔고");
            GameSaveAggregate state = GameSaveAggregate.Initial("install").Commit(
                "first-game",
                stage: ApplicationStage.HighSchool,
                highSchool: highSchool);
            bool offerAvailable = true;
            var model = new StoreBaseballCareerReadModel(
                KoreanUiCopyCatalog.LoadDefault(),
                () => state,
                () => ShellRuntimeStatus.Ready,
                () => string.Empty,
                reminderOptInAvailable: () => offerAvailable);

            BaseballScreenViewModel offered = model.Read(ShellRoute.HighSchoolOverview);
            Assert.That(offered.Sections.Select(section => section.Id), Does.Contain("reminder-opt-in"));
            Assert.That(offered.Actions.Select(action => action.Id), Does.Contain("enable_reminder_nudge"));
            Assert.That(offered.Actions.Select(action => action.Id), Does.Contain("dismiss_reminder_nudge"));
            Assert.That(model.Read(ShellRoute.Settings).Sections.Select(section => section.Id),
                Does.Not.Contain("reminder-opt-in"));

            offerAvailable = false;
            BaseballScreenViewModel decided = model.Read(ShellRoute.HighSchoolOverview);
            Assert.That(decided.Sections.Select(section => section.Id), Does.Not.Contain("reminder-opt-in"));
            Assert.That(decided.Actions.Select(action => action.Id), Does.Not.Contain("enable_reminder_nudge"));
        }

        [Test]
        public void TrainingProjectionRequiresTargetAndOffersSingleOrThreeSessionBlock()
        {
            var selected = new Dictionary<string, string>(StringComparer.Ordinal)
            {
                ["training_focus"] = "breaking_ball",
                ["training_intensity"] = "standard",
            };
            var highSchool = new HighSchoolCareerReadModel(
                "career",
                1,
                HighSchoolPhase.Training,
                "seed",
                3,
                "player",
                "투수",
                "power_prospect",
                new PitcherRatingsReadModel(55, 53, 51, 54),
                new CareerPerformanceReadModel(),
                "school",
                "별빛고",
                trainingFocusChoices: new[]
                {
                    new CareerChoiceReadModel("breaking_ball", "변화구", "변화구 집중")
                },
                trainingIntensityChoices: new[]
                {
                    new CareerChoiceReadModel("standard", "표준", "표준 강도")
                },
                trainingPitchChoices: new[]
                {
                    new CareerChoiceReadModel("slider", "슬라이더", "슬라이더 집중")
                },
                maximumTrainingBlockSessions: 3);
            GameSaveAggregate state = GameSaveAggregate.Initial("install").Commit(
                "training",
                stage: ApplicationStage.HighSchool,
                highSchool: highSchool);
            var model = new StoreBaseballCareerReadModel(
                KoreanUiCopyCatalog.LoadDefault(),
                () => state,
                () => ShellRuntimeStatus.Ready,
                () => string.Empty,
                selectedChoice: group => selected.TryGetValue(group, out string value) ? value : string.Empty);

            BaseballScreenViewModel missingTarget = model.Read(ShellRoute.Training);
            Assert.That(missingTarget.ChoiceGroups.Select(group => group.Id), Does.Contain("training_pitch"));
            Assert.That(missingTarget.Actions.Select(action => action.Id),
                Is.EquivalentTo(new[] { "train", "train_block" }));
            Assert.That(missingTarget.Actions.All(action => !action.IsEnabled), Is.True);
            Assert.That(missingTarget.Actions[0].DisabledReason, Does.Contain("변화구"));

            selected["training_pitch"] = "slider";
            BaseballScreenViewModel ready = model.Read(ShellRoute.Training);
            Assert.That(ready.Actions.All(action => action.IsEnabled), Is.True);
            Assert.That(ready.Actions[1].Label, Does.Contain("3회"));
        }

        [Test]
        public void ProProjectionRequiresDecisionPitchAndOffersSegmentAdvance()
        {
            var selected = new Dictionary<string, string>(StringComparer.Ordinal)
            {
                ["pro_week_plan"] = "develop_movement",
            };
            var pro = new ProCareerReadModel(
                "pro",
                ProCareerOrigin.Direct,
                ProCareerPhase.WeeklyPlan,
                "seed",
                4,
                "player",
                "투수",
                "fictional-club",
                "해오름",
                2,
                6,
                new PitcherRatingsReadModel(61, 59, 58, 57),
                new CareerPerformanceReadModel(),
                weekPlanChoices: new[]
                {
                    new CareerChoiceReadModel("develop_stuff", "강속구 불펜", "구위 성장"),
                    new CareerChoiceReadModel("develop_movement", "결정구 완성", "변화구 성장")
                },
                seasonSegment: "first_half",
                seasonSegmentTitle: "전반기",
                developmentProgress: new ProDevelopmentProgressReadModel(1, 0, 1, 0),
                developmentPitchChoices: new[]
                {
                    new CareerChoiceReadModel("curveball", "커브", "커브 집중")
                });
            GameSaveAggregate state = GameSaveAggregate.Initial("install").Commit(
                "pro-week",
                stage: ApplicationStage.Pro,
                pro: pro);
            var model = new StoreBaseballCareerReadModel(
                KoreanUiCopyCatalog.LoadDefault(),
                () => state,
                () => ShellRuntimeStatus.Ready,
                () => string.Empty,
                selectedChoice: group => selected.TryGetValue(group, out string value) ? value : string.Empty);

            BaseballScreenViewModel missingTarget = model.Read(ShellRoute.ProWeek);
            Assert.That(missingTarget.ChoiceGroups.Select(group => group.Id),
                Does.Contain("pro_development_pitch"));
            Assert.That(missingTarget.Actions.Select(action => action.Id),
                Does.Contain("advance_pro_segment"));
            Assert.That(missingTarget.Actions.Where(action => action.Id.StartsWith("advance_pro", StringComparison.Ordinal))
                .All(action => !action.IsEnabled), Is.True);

            selected["pro_development_pitch"] = "curveball";
            BaseballScreenViewModel ready = model.Read(ShellRoute.ProWeek);
            Assert.That(ready.Actions.Where(action => action.Id.StartsWith("advance_pro", StringComparison.Ordinal))
                .All(action => action.IsEnabled), Is.True);
            Assert.That(ready.Sections.SelectMany(section => section.Rows)
                .Any(row => row.Id == "pro-development-progress" && row.Value.Contains("변화구 1/2")), Is.True);
        }

        [Test]
        public void FrozenPlayerLegacyIsRenderedVerbatimAcrossRecapArchiveAndNextLifePrologue()
        {
            var frozen = new PlayerLegacyState(
                "자기 공을 남긴 투수",
                "낙차 큰 커브로 마지막 타자를 돌려세웠다.",
                "다음 마운드에서도 네 공을 믿어.");
            LifeArchiveRecord record = ArchivedLife(frozen);
            var highSchool = new HighSchoolCareerReadModel(
                "next-career",
                2,
                HighSchoolPhase.Prologue,
                "seed",
                3,
                "player",
                "새봄",
                "power_prospect",
                new PitcherRatingsReadModel(55, 53, 51, 54),
                new CareerPerformanceReadModel());
            GameSaveAggregate state = GameSaveAggregate.Initial("install").Commit(
                "archived-life",
                stage: ApplicationStage.HighSchool,
                highSchool: highSchool,
                meta: new MetaProgressState(lifeNumber: 2, lifeArchive: new[] { record }));
            var model = new StoreBaseballCareerReadModel(
                KoreanUiCopyCatalog.LoadDefault(),
                () => state,
                () => ShellRuntimeStatus.Ready,
                () => string.Empty);

            foreach (ShellRoute route in new[] { ShellRoute.Prologue, ShellRoute.RunRecap })
            {
                ScreenRowViewModel row = model.Read(route).Sections
                    .SelectMany(section => section.Rows)
                    .Single(value => value.Id == "player-legacy-letter-copy");
                Assert.That(row.Label, Is.EqualTo(frozen.Title), route.ToString());
                Assert.That(row.Value, Is.EqualTo(frozen.DefiningMoment), route.ToString());
                Assert.That(row.Detail, Is.EqualTo("“" + frozen.Farewell + "”"), route.ToString());
            }

            ScreenRowViewModel archived = model.Read(ShellRoute.LifeArchive).Sections
                .SelectMany(section => section.Rows)
                .Single(value => value.Id == "archive-player-legacy-1");
            Assert.That(archived.Label, Is.EqualTo(frozen.Title));
            Assert.That(archived.Value, Is.EqualTo(frozen.DefiningMoment));
            Assert.That(archived.Detail, Is.EqualTo("“" + frozen.Farewell + "”"));
            Assert.That(model.Read(ShellRoute.Opening).Sections.Select(section => section.Id),
                Does.Not.Contain("player-legacy-letter"));
        }

        [Test]
        public void ArchivedRecapOffersAtomicQuickStartAndExplicitCustomization()
        {
            LifeArchiveRecord record = ArchivedLife(new PlayerLegacyState("제목", "순간", "작별"));
            var completed = new HighSchoolCareerReadModel(
                "career-1",
                1,
                HighSchoolPhase.Completed,
                "seed",
                9,
                "player",
                "해온",
                "power_prospect",
                new PitcherRatingsReadModel(70, 66, 64, 68),
                new CareerPerformanceReadModel(4, 28, 6, 3));
            GameSaveAggregate state = GameSaveAggregate.Initial("install").Commit(
                "archived-recap",
                stage: ApplicationStage.Legacy,
                highSchool: completed,
                meta: new MetaProgressState(
                    lifeNumber: 1,
                    lifeArchive: new[] { record },
                    lastHighSchoolSetup: new HighSchoolLastSetupState(
                        "power_prospect", "해온", "서울", "standard")));

            BaseballScreenViewModel recap = ReadyModel(() => state).Read(ShellRoute.RunRecap);
            ScreenActionViewModel quick = recap.Actions.Single(action =>
                action.Id == "quick_rebirth_from_recap");
            ScreenActionViewModel customize = recap.Actions.Single(action =>
                action.Id == "begin_rebirth");

            Assert.That(quick.Label, Is.EqualTo("2번째 선수 바로 시작"));
            Assert.That(quick.Target, Is.EqualTo(ShellRoute.Prologue));
            Assert.That(quick.Style, Is.EqualTo(ScreenActionStyle.Primary));
            Assert.That(quick.IsEnabled, Is.True);
            Assert.That(customize.Label, Is.EqualTo("설정을 바꿔서 시작"));
            Assert.That(customize.Target, Is.EqualTo(ShellRoute.Setup));
            Assert.That(customize.Style, Is.EqualTo(ScreenActionStyle.Secondary));
        }

        [Test]
        public void ArchiveProjectsEveryFrozenChronicleAndKoreanDetailWithoutRawIds()
        {
            var signature = new SignatureLegacyReadModel(
                "legacy-command",
                "흔들리지 않는 손끝",
                "끝까지 같은 릴리스 포인트를 지켰다.",
                "프로 통산 볼넷 억제");
            var detail = new HighSchoolLifeDetailReadModel(
                new PitcherRatingsReadModel(50, 48, 46, 52),
                new[] { "밤의 제구사", "마지막 이닝의 사람" },
                Enumerable.Range(1, 15).Select(index => "저장된 장면 " + index).ToArray(),
                "도윤 감독",
                "서준 포수",
                "지후 라이벌",
                "차분한 승부사",
                "steady_wind",
                "흔들리지 않는 바람",
                "수비와 제구",
                new RelationshipResponseTallyReadModel(2, 3, 1),
                new[]
                {
                    new TalentGradeReadModel("stuff", "구위", "b", "B"),
                    new TalentGradeReadModel("command", "제구", "a", "A"),
                    new TalentGradeReadModel("movement", "변화", "b", "B"),
                    new TalentGradeReadModel("stamina", "체력", "c", "C"),
                },
                "precision_commander",
                "제구 설계자",
                "challenging",
                "도전");
            var record = new LifeArchiveRecord(
                "life-2",
                2,
                "새봄",
                "high-school-2",
                "pro-2",
                "fictional-school",
                "별빛고",
                true,
                91,
                new PitcherRatingsReadModel(72, 78, 69, 67),
                new CareerPerformanceReadModel(6, 84, 18, 13, 4, 5, 2),
                5,
                244,
                2,
                88,
                21,
                karmas: new[] { "unknown_land" },
                awakenings: new[] { "explosive_fastball" },
                memories: new[] { "catcher_notebook" },
                playerLegacy: new PlayerLegacyState("자기 공을 남긴 투수", "결정구로 끝냈다.", "다음 공도 믿어."),
                highSchoolDetail: detail,
                signatureLegacy: signature,
                signatureLegacyCandidates: new[]
                {
                    signature,
                    new SignatureLegacyReadModel("legacy-power", "마운드의 불꽃", "구위", "탈삼진"),
                    new SignatureLegacyReadModel("legacy-stamina", "끝까지 남은 팔", "체력", "이닝"),
                },
                pitches: 84,
                outs: 18,
                hits: 5,
                draftTeamName: "해오름");
            GameSaveAggregate state = GameSaveAggregate.Initial("install").Commit(
                "archive-detail",
                stage: ApplicationStage.BetweenLives,
                meta: new MetaProgressState(lifeNumber: 3, lifeArchive: new[] { record }));
            var model = ReadyModel(() => state);

            ScreenRowViewModel[] archiveRows = model.Read(ShellRoute.LifeArchive).Sections
                .Single(section => section.Id == "archive-life-2").Rows.ToArray();
            Assert.That(archiveRows.Count(row => row.Id.StartsWith("archive-chronicle-2-", StringComparison.Ordinal)),
                Is.EqualTo(15));
            Assert.That(archiveRows.Single(row => row.Id == "archive-origin-2").Value,
                Is.EqualTo("제구 설계자 · 도전"));
            Assert.That(archiveRows.Single(row => row.Id == "archive-origin-2").Detail,
                Does.Contain("해오름"));
            Assert.That(archiveRows.Single(row => row.Id == "archive-talents-2").Value,
                Is.EqualTo("구위 B · 제구 A · 변화 B · 체력 C"));
            Assert.That(archiveRows.Single(row => row.Id == "archive-memories-2").Value,
                Is.EqualTo("포수의 노트"));
            Assert.That(string.Join(" ", archiveRows.SelectMany(row =>
                    new[] { row.Label, row.Value, row.Detail })),
                Does.Not.Contain("catcher_notebook"));

            BaseballScreenViewModel records = model.Read(ShellRoute.Records);
            Assert.That(records.Sections.Select(section => section.Id),
                Does.Contain("records-archive-career"));
            Assert.That(records.Sections.Select(section => section.Id),
                Does.Contain("records-latest-life"));
            Assert.That(records.Sections.Select(section => section.Id),
                Does.Contain("records-life-log"));
            Assert.That(records.Sections.SelectMany(section => section.Rows)
                .Any(row => row.Value.Contains("구위 72") && row.Value.Contains("제구 78")), Is.True);
        }

        [Test]
        public void SelectedArchiveLifeDrivesLifeCardInsteadOfAlwaysUsingLatest()
        {
            LifeArchiveRecord first = ArchivedLife(new PlayerLegacyState("첫 제목", "첫 순간", "첫 작별"));
            var second = new LifeArchiveRecord(
                "life-2", 2, "새봄", "high-school-2", null, "school-2", "푸른솔고",
                false, 72, new PitcherRatingsReadModel(61, 63, 58, 65),
                new CareerPerformanceReadModel(3, 20, 5, 2), 0, 0, 0, 0, 8);
            GameSaveAggregate state = GameSaveAggregate.Initial("install").Commit(
                "two-lives",
                stage: ApplicationStage.BetweenLives,
                meta: new MetaProgressState(lifeNumber: 3, lifeArchive: new[] { first, second }));
            var model = new StoreBaseballCareerReadModel(
                KoreanUiCopyCatalog.LoadDefault(),
                () => state,
                () => ShellRuntimeStatus.Ready,
                () => string.Empty,
                selectedChoice: group => group == "archive_life" ? "1" : string.Empty);

            BaseballScreenViewModel card = model.Read(ShellRoute.LifeCard);
            Assert.That(card.Title, Does.Contain("해온"));
            Assert.That(card.Title, Does.Not.Contain("새봄"));
            Assert.That(card.Sections.SelectMany(section => section.Rows)
                .Single(row => row.Id == "player").Value, Is.EqualTo("해온"));
        }

        [Test]
        public void WeeklyOnlySaveStillProjectsAValidRecordsBoard()
        {
            var program = new WeeklyProgramState(
                "2026-W33",
                new[]
                {
                    new WeeklyTaskState("daily", WeeklyTaskKinds.DailyInningCompleted, 1, 1),
                    new WeeklyTaskState("games", WeeklyTaskKinds.ImportantGamesCompleted, 2, 1),
                    new WeeklyTaskState("days", WeeklyTaskKinds.PlayedOnTwoDays, 2, 1),
                },
                new[] { "daily" },
                false);
            GameSaveAggregate state = GameSaveAggregate.Initial("install").Commit(
                "weekly-only",
                meta: new MetaProgressState(
                    weekly: new WeeklyProgressState(program, null, "20260810")));

            BaseballScreenViewModel records = ReadyModel(() => state).Read(ShellRoute.Records);

            Assert.That(records.Sections.Select(section => section.Id),
                Does.Not.Contain("records-empty"));
            Assert.That(records.Sections.SelectMany(section => section.Rows)
                .Any(row => row.Value.Contains("1/1") || row.Value.Contains("1/2")), Is.True);
        }

        [Test]
        public void PreviousPlayerLetterIsHiddenForChallengeAndSameLifePrologue()
        {
            LifeArchiveRecord record = ArchivedLife(new PlayerLegacyState("제목", "순간", "작별"));
            HighSchoolCareerReadModel sameLife = new HighSchoolCareerReadModel(
                "same-career",
                1,
                HighSchoolPhase.Prologue,
                "seed",
                3,
                "player",
                "한결",
                "power_prospect",
                new PitcherRatingsReadModel(55, 53, 51, 54),
                new CareerPerformanceReadModel());
            GameSaveAggregate sameState = GameSaveAggregate.Initial("install").Commit(
                "same-life",
                stage: ApplicationStage.HighSchool,
                highSchool: sameLife,
                meta: new MetaProgressState(lifeNumber: 1, lifeArchive: new[] { record }));

            Assert.That(StoreBaseballCareerReadModel.PreviousPlayerLegacyFor(
                ShellRoute.Prologue,
                sameState), Is.Null);

            HighSchoolCareerReadModel challenge = new HighSchoolCareerReadModel(
                "challenge-career",
                2,
                HighSchoolPhase.Prologue,
                "seed",
                3,
                "player",
                "한결",
                "power_prospect",
                new PitcherRatingsReadModel(55, 53, 51, 54),
                new CareerPerformanceReadModel(),
                isChallengeRun: true);
            GameSaveAggregate challengeState = sameState.Commit(
                "challenge-life",
                highSchool: challenge,
                meta: new MetaProgressState(lifeNumber: 2, lifeArchive: new[] { record }));
            Assert.That(StoreBaseballCareerReadModel.PreviousPlayerLegacyFor(
                ShellRoute.Prologue,
                challengeState), Is.Null);
        }

        [Test]
        public void PreLegacyArchiveUsesExplicitCompatibilityCopyWithoutSynthesizingALetter()
        {
            LifeArchiveRecord record = ArchivedLife(null);
            GameSaveAggregate state = GameSaveAggregate.Initial("install").Commit(
                "legacy-save",
                stage: ApplicationStage.BetweenLives,
                meta: new MetaProgressState(lifeNumber: 2, lifeArchive: new[] { record }));
            var model = new StoreBaseballCareerReadModel(
                KoreanUiCopyCatalog.LoadDefault(),
                () => state,
                () => ShellRuntimeStatus.Ready,
                () => string.Empty);

            ScreenRowViewModel row = model.Read(ShellRoute.RunRecap).Sections
                .SelectMany(section => section.Rows)
                .Single(value => value.Id == "player-legacy-letter-copy");
            Assert.That(row.Label, Is.EqualTo("이전 버전의 선수 기록"));
            Assert.That(row.Value, Does.Contain("편지가 보관되지 않았습니다"));
            Assert.That(row.Value, Does.Not.Contain("탈삼진"));
            Assert.That(row.Detail, Does.Not.Contain("다음 마운드의 시작"));
        }

        [Test]
        public void DailyRouteProjectsSavedThreeAttemptLimitBestAndDisabledFourthAttempt()
        {
            var instant = new DateTimeOffset(2026, 8, 11, 12, 0, 0, TimeSpan.Zero);
            string dayKey = SeoulGameCalendar.DayKey(instant);
            var best = new PitchGameReport("daily-best", 3, 1, 3, 2, 0, 0, 0);
            GameSaveAggregate initial = GameSaveAggregate.Initial("install");
            GameSaveAggregate state = initial.Commit(
                "daily-fixture",
                meta: initial.Meta.With(
                    daily: new DailyStreakState(
                        lastDailyInningDayKey: dayKey,
                        dailyInning: new DailyInningDayState(dayKey, 3, 1200, best)),
                    creditedRewardIds: new[] { DailyInningRules.RewardId(dayKey) }));
            var model = new StoreBaseballCareerReadModel(
                KoreanUiCopyCatalog.LoadDefault(),
                () => state,
                () => ShellRuntimeStatus.Ready,
                () => string.Empty,
                now: () => instant);

            BaseballScreenViewModel daily = model.Read(ShellRoute.Daily);
            Assert.That(daily.Title, Is.EqualTo("오늘의 이닝 · " + dayKey));
            Assert.That(daily.Lead, Is.EqualTo("전국이 같은 타순을 상대합니다"));
            Assert.That(daily.Sections.SelectMany(section => section.Rows)
                .Single(row => row.Id == "daily-attempts").Value, Is.EqualTo("0 / 3"));
            Assert.That(daily.Sections.SelectMany(section => section.Rows)
                .Single(row => row.Id == "daily-best").Value, Is.EqualTo("1200점"));
            Assert.That(daily.Sections.SelectMany(section => section.Rows)
                .Single(row => row.Id == "daily-reward").Value, Is.EqualTo("지급 완료"));
            ScreenActionViewModel play = daily.Actions.Single(action => action.Id == "begin_daily_pitch");
            Assert.That(play.IsEnabled, Is.False);
            Assert.That(play.Hint, Does.Contain("내일"));
            Assert.That(daily.Actions.Any(action => action.Target == ShellRoute.Weekly), Is.True);
        }

        private static LifeArchiveRecord ArchivedLife(PlayerLegacyState playerLegacy)
        {
            return new LifeArchiveRecord(
                "life-1",
                1,
                "해온",
                "high-school-career",
                "pro-career",
                "fictional-school",
                "별빛고",
                true,
                84,
                new PitcherRatingsReadModel(70, 66, 64, 68),
                new CareerPerformanceReadModel(4, 28, 6, 3),
                3,
                117,
                1,
                76,
                14,
                playerLegacy: playerLegacy);
        }

        private static StoreBaseballCareerReadModel ReadyModel(Func<GameSaveAggregate> state) =>
            new StoreBaseballCareerReadModel(
                KoreanUiCopyCatalog.LoadDefault(),
                state,
                () => ShellRuntimeStatus.Ready,
                () => string.Empty);

        private sealed class FakeVisualLoader : IBaseballVisualAssetLoader
        {
            public string LastAddress { get; private set; }

            public Task<IBaseballVisualAssetLease> LoadSpriteAsync(string address, CancellationToken cancellationToken)
            {
                cancellationToken.ThrowIfCancellationRequested();
                LastAddress = address;
                return Task.FromResult<IBaseballVisualAssetLease>(new FakeLease());
            }
        }

        private sealed class FakeLease : IBaseballVisualAssetLease
        {
            public Sprite Sprite => null;
            public void Dispose() { }
        }
    }
}
