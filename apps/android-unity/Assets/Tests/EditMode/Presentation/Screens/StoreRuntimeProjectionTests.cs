using System.Threading;
using System.Threading.Tasks;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using Baseball.Application.Commands;
using Baseball.Application.Persistence;
using Baseball.Application.HighSchool;
using Baseball.Application.Meta;
using Baseball.Application.Pro;
using Baseball.Application.Stores;
using Baseball.Presentation.Common;
using Baseball.Presentation.Shell;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.UIElements;

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
        public void SetupProjectionDisablesInvalidStartAndFirstStepHidesFinalAction()
        {
            GameSaveAggregate state = SetupState("setup-projection-install");
            var valid = true;
            var model = new StoreBaseballCareerReadModel(
                KoreanUiCopyCatalog.LoadDefault(),
                () => state,
                () => ShellRuntimeStatus.Ready,
                () => string.Empty,
                setupSeedInputValid: () => valid);

            Assert.That(model.Read(ShellRoute.Setup).Actions.Single(action =>
                action.Id == "start_high_school").IsEnabled, Is.True);

            valid = false;
            BaseballScreenViewModel invalid = model.Read(ShellRoute.Setup);
            ScreenActionViewModel action = invalid.Actions.Single(value =>
                value.Id == "start_high_school");
            Assert.That(action.IsEnabled, Is.False);
            Assert.That(action.DisabledReason, Is.EqualTo(SetupSeedInputPolicy.InvalidMessage));

            var root = new VisualElement();
            using (var controller = new BaseballShellController(
                       root,
                       model,
                       KoreanUiCopyCatalog.LoadDefault(),
                       ShellRoute.Setup))
            {
                Assert.That(root.Q<VisualElement>("screen-setup-step-next"), Is.Not.Null,
                    "iOS parity requires the first setup screen to show only the next-step action");
                Assert.That(root.Q<VisualElement>("screen-setup-action-start_high_school"), Is.Null,
                    "the final start action must not compete with the name decision on step one");
            }
        }

        [Test]
        public async Task ProductionRuntimeRejectsStaleValidActionAfterSeedBecomesInvalid()
        {
            using (GameApplicationStore store = await OpenSetupStore("stale-seed-install"))
            using (var runtime = ReadyProductionRuntime(store))
            {
                runtime.SetSeedInput("12345-2");
                ScreenActionViewModel staleEnabled = runtime.Read(ShellRoute.Setup).Actions
                    .Single(action => action.Id == "start_high_school");
                Assert.That(staleEnabled.IsEnabled, Is.True);

                runtime.SetSeedInput("12345--2");
                ScreenActionViewModel current = runtime.Read(ShellRoute.Setup).Actions
                    .Single(action => action.Id == "start_high_school");
                Assert.That(current.IsEnabled, Is.False);
                Assert.That(runtime.SeedValidationMessage,
                    Is.EqualTo(SetupSeedInputPolicy.InvalidMessage));

                ulong revision = store.Current.Revision;
                ShellActionResult rejected = await runtime.ExecuteAsync(
                    ShellRoute.Setup,
                    staleEnabled,
                    CancellationToken.None);

                Assert.That(rejected.Succeeded, Is.False);
                Assert.That(rejected.Message, Is.EqualTo(SetupSeedInputPolicy.InvalidMessage));
                Assert.That(store.Current.Revision, Is.EqualTo(revision));
                Assert.That(store.Current.Stage, Is.EqualTo(ApplicationStage.Setup));
            }
        }

        [TestCase("18446744073709551616")]
        [TestCase("12--2")]
        public async Task ProductionRuntimeInvalidSeedNeverDispatchesDefaultSeed(string input)
        {
            using (GameApplicationStore store = await OpenSetupStore("invalid-seed-install"))
            using (var runtime = ReadyProductionRuntime(store))
            {
                runtime.SetSeedInput(input);
                ScreenActionViewModel action = runtime.Read(ShellRoute.Setup).Actions
                    .Single(value => value.Id == "start_high_school");
                ulong revision = store.Current.Revision;

                ShellActionResult rejected = await runtime.ExecuteAsync(
                    ShellRoute.Setup,
                    action,
                    CancellationToken.None);

                Assert.That(action.IsEnabled, Is.False);
                Assert.That(rejected.Succeeded, Is.False);
                Assert.That(rejected.Message, Is.EqualTo(SetupSeedInputPolicy.InvalidMessage));
                Assert.That(store.Current.Revision, Is.EqualTo(revision));
                Assert.That(store.Current.HighSchool, Is.Null);
            }
        }

        [Test]
        public async Task ProductionRuntimeDispatchesValidChallengeAndEmptyDefaultSeed()
        {
            using (GameApplicationStore challengeStore = await OpenSetupStore("challenge-install"))
            using (var challengeRuntime = ReadyProductionRuntime(challengeStore))
            {
                challengeRuntime.SetSeedInput("도전 67890-4");
                ScreenActionViewModel action = challengeRuntime.Read(ShellRoute.Setup).Actions
                    .Single(value => value.Id == "start_high_school");
                ShellActionResult result = await challengeRuntime.ExecuteAsync(
                    ShellRoute.Setup,
                    action,
                    CancellationToken.None);

                Assert.That(result.Succeeded, Is.True);
                Assert.That(challengeStore.Current.HighSchool.IsChallengeRun, Is.True);
                Assert.That(challengeStore.Current.HighSchool.LifeNumber, Is.EqualTo(4));
            }

            using (GameApplicationStore emptyStore = await OpenSetupStore("empty-seed-install"))
            using (var emptyRuntime = ReadyProductionRuntime(emptyStore))
            {
                emptyRuntime.SetSeedInput(string.Empty);
                ScreenActionViewModel action = emptyRuntime.Read(ShellRoute.Setup).Actions
                    .Single(value => value.Id == "start_high_school");
                ShellActionResult result = await emptyRuntime.ExecuteAsync(
                    ShellRoute.Setup,
                    action,
                    CancellationToken.None);

                Assert.That(action.IsEnabled, Is.True);
                Assert.That(result.Succeeded, Is.True);
                Assert.That(emptyStore.Current.HighSchool.IsChallengeRun, Is.False);
                Assert.That(emptyStore.Current.HighSchool.LifeNumber, Is.EqualTo(2));
            }
        }

        [Test]
        public async Task ProductionTrainingDraftSeedsLastChoiceAndReplacesStalePitchTarget()
        {
            var focusChoices = new[]
            {
                Choice("command", "제구"),
                Choice("breaking_ball", "변화구"),
            };
            var intensityChoices = new[]
            {
                Choice("standard", "보통"),
                Choice("intensive", "강하게"),
            };
            var pitchChoices = new[]
            {
                Choice("slider", "슬라이더"),
                Choice("changeup", "체인지업"),
            };
            var career = new HighSchoolCareerReadModel(
                "training-career",
                2,
                HighSchoolPhase.Training,
                "seed",
                1,
                "player",
                "해온",
                "power_prospect",
                new PitcherRatingsReadModel(55, 53, 51, 54),
                new CareerPerformanceReadModel(),
                trainingFocusChoices: focusChoices,
                trainingIntensityChoices: intensityChoices,
                trainingPitchChoices: pitchChoices,
                lastTraining: new TrainingResultReadModel(
                    3, "breaking_ball", "intensive", 1, 4, "완료", 50, 51,
                    false, false, "removed_curve"));
            GameSaveAggregate state = GameSaveAggregate.Initial("training-install").Commit(
                "training",
                stage: ApplicationStage.HighSchool,
                highSchool: career,
                meta: new MetaProgressState(lifeNumber: 2));

            using (GameApplicationStore store = await OpenStore(state))
            using (var runtime = ReadyProductionRuntime(store))
            {
                Assert.That(runtime.GetChoice("training_focus"), Is.EqualTo("breaking_ball"));
                Assert.That(runtime.GetChoice("training_intensity"), Is.EqualTo("intensive"));
                Assert.That(runtime.GetChoice("training_pitch"), Is.EqualTo("slider"),
                    "a removed saved target must be replaced by a currently enabled pitch");

                ScreenActionViewModel action = runtime.Read(ShellRoute.Training).Actions
                    .Single(value => value.Id == "train");
                Assert.That(action.IsEnabled, Is.True);
                var command = (AdvanceHighSchoolCommand)ProductionCommand(
                    runtime,
                    "train",
                    state);
                Assert.That(command.Action.Value,
                    Is.EqualTo("breaking_ball:intensive:slider"));

                runtime.SetChoice("training_pitch", "removed_curve");
                Assert.That(runtime.Read(ShellRoute.Training).Actions.Single(value =>
                    value.Id == "train").IsEnabled, Is.False);
                Assert.That(ProductionCommand(runtime, "train", state), Is.Null,
                    "an injected stale target must fail closed instead of leaking into a command");
            }
        }

        [Test]
        public async Task ProductionProDraftDefaultsToEarnTrustAndPreservesSamePhaseSelectionOnly()
        {
            var plans = new[]
            {
                Choice("develop_movement", "결정구 완성"),
                Choice("earn_trust", "신뢰 쌓기"),
            };
            var pitches = new[]
            {
                Choice("slider", "슬라이더"),
                Choice("changeup", "체인지업"),
            };
            var pro = new ProCareerReadModel(
                "pro-choice-career",
                ProCareerOrigin.Direct,
                ProCareerPhase.WeeklyPlan,
                "seed",
                1,
                "player",
                "해온",
                "fictional-club",
                "해오름",
                1,
                1,
                new PitcherRatingsReadModel(65, 63, 61, 64),
                new CareerPerformanceReadModel(),
                weekPlanChoices: plans,
                developmentPitchChoices: pitches,
                lastSegmentProgress: new ProSegmentProgressReadModel(
                    2, "spring", "spring", "user_stop", "develop_movement", "changeup"));
            GameSaveAggregate state = GameSaveAggregate.Initial("pro-choice-install").Commit(
                "pro-week",
                stage: ApplicationStage.Pro,
                pro: pro,
                meta: new MetaProgressState(lifeNumber: 2));

            using (GameApplicationStore store = await OpenStore(state))
            using (var runtime = ReadyProductionRuntime(store))
            {
                Assert.That(runtime.GetChoice("pro_week_plan"), Is.EqualTo("earn_trust"));
                Assert.That(runtime.GetChoice("pro_development_pitch"), Is.EqualTo("changeup"));
                ScreenActionViewModel defaultAction = runtime.Read(ShellRoute.ProWeek).Actions
                    .Single(value => value.Id == "advance_pro_week");
                Assert.That(defaultAction.IsEnabled, Is.True);
                Assert.That(((AdvanceProCommand)ProductionCommand(
                    runtime, "advance_pro_week", state)).Action.Value,
                    Is.EqualTo("earn_trust"));

                runtime.SetChoice("pro_week_plan", "develop_movement");
                Assert.That(((AdvanceProCommand)ProductionCommand(
                    runtime, "advance_pro_week", state)).Action.Value,
                    Is.EqualTo("develop_movement|changeup"));

                InvokeOnReady(runtime, store);
                Assert.That(runtime.GetChoice("pro_week_plan"), Is.EqualTo("develop_movement"),
                    "same-phase publications and route round-trips preserve the draft");

                runtime.SetChoice("pro_development_pitch", "removed_curve");
                Assert.That(runtime.Read(ShellRoute.ProWeek).Actions.Single(value =>
                    value.Id == "advance_pro_week").IsEnabled, Is.False);
                Assert.That(ProductionCommand(runtime, "advance_pro_week", state), Is.Null);
            }

            using (GameApplicationStore restartedStore = await OpenStore(state))
            using (var restarted = ReadyProductionRuntime(restartedStore))
            {
                Assert.That(restarted.GetChoice("pro_week_plan"), Is.EqualTo("earn_trust"),
                    "restart re-seeds from the frozen Pro default rather than process memory");
                Assert.That(restarted.GetChoice("pro_development_pitch"), Is.EqualTo("changeup"));
            }
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
            Assert.That(screen.Title, Is.EqualTo("첫 번째 야구 인생"));
            Assert.That(screen.Lead, Does.Contain("첫 불펜"));
            Assert.That(screen.Sections.Single(section => section.Id == "ability").Rows
                .Select(row => row.Id),
                Is.EqualTo(new[] { "fastball", "control", "movement", "stamina" }));
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
                gameLines: new[]
                {
                    new CareerGameLineReadModel(
                        1, 1, 1, true, true, 9, 12, 6, 4, 1, 52, 3, 1, "win",
                        homeRuns: 1, recordedHits: 4),
                    new CareerGameLineReadModel(
                        1, 2, 2, true, true, 6, 9, 8, 3, 2, 38, 2, 3, "loss",
                        homeRuns: 0, recordedHits: 3),
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
                    new LeaguePitcherReadModel(1, "해온", "해오름", 63, 5, 1, 0, 51, 12, 18, 7, true,
                        homeRuns: 2, recordedHits: 18),
                    new LeaguePitcherReadModel(2, "지후", "푸른물결", 60, 4, 2, 1, 46, 14, 20, 9, false,
                        homeRuns: 3, recordedHits: 20),
                },
                recordBook: new ProRecordBookReadModel(
                    new PitchingRecordReadModel(
                        1, 1, 18, 9, 2, 1, 1, 0, 0, 5, 1, 76, 1),
                    new[]
                    {
                        new CareerGameLineReadModel(
                            3, 11, 1, true, true, 18, 9, 2, 5, 1, 76, 4, 1, "win",
                            homeRuns: 1, recordedHits: 5)
                    },
                    new[]
                    {
                        new ProSeasonLineReadModel(
                            2, "fictional-club", 10, 90, 62, 18, 12, 1, 6, 2, 0,
                            starts: 8, hits: 30, homeRuns: 4, pitches: 410, qualityStarts: 5)
                    },
                    new[] { "신인상" },
                    new[] { "프로 통산 100탈삼진" },
                    new[]
                    {
                        new ProDecisionHistoryReadModel(
                            "decision-1", "role", 3, 8, "starter", "선발 경쟁",
                            "선발 로테이션 기회를 얻었습니다.", managerTrustDelta: 4,
                            roleTarget: "starter")
                    },
                    hallOfFameScore: 321,
                    seasonGameLinesAvailable: true));
            GameSaveAggregate state = GameSaveAggregate.Initial("install").Commit(
                "active-records",
                stage: ApplicationStage.Pro,
                highSchool: highSchool,
                pro: pro,
                meta: MetaProgressState.Initial.With(
                    pitchReleaseMastery: new PitchReleaseMasteryState(
                        officialSessions: 3,
                        directPitches: 8,
                        deliveryScoreTotal: 6800,
                        releaseAccuracyTotal: 7040,
                        aimAccuracyTotal: 6560,
                        personalBest: 920,
                        lastGameId: "records-game",
                        lastSessionAverage: 870,
                        lastSessionBest: 920,
                        previousPersonalBest: 890,
                        lastReleaseAverage: 900,
                        lastAimAverage: 840)));

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
            ScreenSectionViewModel releaseMastery = records.Sections
                .Single(section => section.Id == "records-release-mastery");

            Assert.That(hsRatings.Value, Is.EqualTo("구위 71 · 제구 79 · 변화 68 · 체력 73"));
            Assert.That(hsRatings.Detail, Is.EqualTo("팬 관심 88 · 포수와의 호흡 81 · 지도자의 믿음 74"));
            Assert.That(hsAdvanced.Value,
                Is.EqualTo("9이닝당 실점 5.40 · WHIP 4.20 · 탈삼진/볼넷 1.50"));
            Assert.That(hsAdvanced.Detail, Does.Contain("FIP"));
            Assert.That(records.Sections.Single(section =>
                    section.Id == "records-current-high-school").Rows
                .Single(row => row.Id == "records-current-hs-identity").Value,
                Is.EqualTo("차분한 승부사"));
            Assert.That(records.Sections.Single(section =>
                    section.Id == "records-current-hs-prospects").Rows[0].Detail,
                Is.EqualTo("제구형 · 내 선수"));
            Assert.That(proRatings.Value, Is.EqualTo("구위 83 · 제구 76 · 변화 81 · 체력 78"));
            Assert.That(releaseMastery.Rows[0].Value, Is.EqualTo("920점"));
            Assert.That(releaseMastery.Rows[0].Detail, Is.EqualTo("다음 목표 950점까지 30점"));
            Assert.That(releaseMastery.Rows[1].Value,
                Is.EqualTo("3경기 · 직접 투구 8구 · 평균 850점"));
            Assert.That(releaseMastery.Rows[1].Detail, Is.EqualTo("타이밍 880 · 조준 820"));
            Assert.That(records.Sections.Single(section =>
                    section.Id == "records-current-pro-standings").Rows[0].Detail,
                Is.EqualTo("선두 · 내 구단"));
            Assert.That(records.Sections.Single(section =>
                    section.Id == "records-current-pro-leaders").Rows[0].Value,
                Is.EqualTo("해오름 · 21.0이닝 · 탈삼진 51"));
            Assert.That(records.Sections.Single(section =>
                    section.Id == "records-current-pro-leaders").Rows[0].Detail,
                Does.Contain("내 선수"));
            Assert.That(records.Sections.SelectMany(section => section.Rows)
                .Single(row => row.Id == "records-current-hs-news").Value,
                Is.EqualTo("새봄이 다음 경기 선발로 예고됐다."));
            Assert.That(records.Sections.SelectMany(section => section.Rows)
                .Single(row => row.Id == "records-current-hs-awakenings").Value,
                Is.EqualTo("바늘끝 제구"));
            Assert.That(records.Sections.SelectMany(section => section.Rows)
                .Single(row => row.Id == "records-current-pro-awards").Value,
                Is.EqualTo("신인상"));
            Assert.That(records.Sections.SelectMany(section => section.Rows)
                .Single(row => row.Id == "records-current-pro-milestones").Value,
                Is.EqualTo("프로 통산 100탈삼진"));
            Assert.That(records.Sections.SelectMany(section => section.Rows)
                .Single(row => row.Id == "records-current-pro-decision-0").Detail,
                Does.Contain("지도자 믿음 +4"));
            Assert.That(records.Sections.Single(section => section.Id == "records-pro-games").Rows.Count, Is.EqualTo(1));
        }

        [Test]
        public void RecordsFailsClosedWhenLegacyProSnapshotHasNoRecordBook()
        {
            var pro = new ProCareerReadModel(
                "legacy-pro", ProCareerOrigin.Direct, ProCareerPhase.WeeklyPlan, "seed", 1,
                "player", "해온", "fictional-club", "해오름", 2, 4,
                new PitcherRatingsReadModel(70, 68, 66, 72),
                new CareerPerformanceReadModel(9, 81, 22, 18, 8, 11, 5));
            GameSaveAggregate state = GameSaveAggregate.Initial("install").Commit(
                "legacy-pro", stage: ApplicationStage.Pro, pro: pro);

            BaseballScreenViewModel records = ReadyModel(() => state).Read(ShellRoute.Records);
            ScreenRowViewModel unavailable = records.Sections
                .Single(section => section.Id == "records-current-pro").Rows
                .Single(row => row.Id == "records-current-pro-performance");

            Assert.That(unavailable.Value, Is.EqualTo("상세 투구 기록을 불러올 수 없음"));
            Assert.That(unavailable.Detail, Does.Contain("이전 저장"));
            Assert.That(records.Sections.Any(section => section.Id == "records-pro-games"), Is.False);
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
        public void AuthoritativeCareerPhaseProjectsExactKeyArtPortraitsAndSchoolStaffArtwork()
        {
            HighSchoolCareerReadModel HighSchool(
                HighSchoolPhase phase,
                int chapter = 1,
                IReadOnlyList<CareerChoiceReadModel> schools = null) =>
                new HighSchoolCareerReadModel(
                    "art-career",
                    1,
                    phase,
                    "seed",
                    1,
                    "player",
                    "해온",
                    "power_prospect",
                    new PitcherRatingsReadModel(55, 53, 51, 54),
                    new CareerPerformanceReadModel(),
                    chapterNumber: chapter,
                    schoolChoices: schools);

            GameSaveAggregate state = GameSaveAggregate.Initial("art-install").Commit(
                "art-prologue",
                stage: ApplicationStage.HighSchool,
                highSchool: HighSchool(HighSchoolPhase.Prologue));
            StoreBaseballCareerReadModel model = ReadyModel(() => state);

            Assert.That(model.Read(ShellRoute.Prologue).KeyArtAddress,
                Is.EqualTo("baseball/highschool/KeyArtCareerIntro"));
            Assert.That(model.Read(ShellRoute.Prologue).PlayerPortraitAddress,
                Does.StartWith("baseball/highschool/PortraitPlayerYoung"));

            var schools = new[]
            {
                new CareerChoiceReadModel(
                    "school-starlight",
                    "별빛고",
                    "점유율을 높이는 야구 · 감독 조범석 · 포수 정우빈",
                    "강점 제구 · 체력 성장 완만",
                    payload: "starlight_control")
            };
            state = GameSaveAggregate.Initial("art-install").Commit(
                "art-school",
                stage: ApplicationStage.HighSchool,
                highSchool: HighSchool(HighSchoolPhase.SchoolSelection, schools: schools));
            BaseballScreenViewModel selection = model.Read(ShellRoute.Prologue);
            ScreenChoiceOptionViewModel school = selection.ChoiceGroups
                .Single(group => group.Id == "school").Choices.Single();
            Assert.That(selection.KeyArtAddress,
                Is.EqualTo("baseball/highschool/KeyArtSchoolCrossroads"));
            Assert.That(selection.Title, Is.EqualTo("어느 학교에서 3년을 보낼까요?"));
            Assert.That(selection.Lead, Does.Contain("감독과 포수"));
            Assert.That(selection.Sections.Any(section => section.Id == "hs-career-wind"), Is.False,
                "school comparison must not repeat the prologue wind card");
            Assert.That(school.ArtworkAddress,
                Is.EqualTo("baseball/highschool/PortraitCoach1"));
            Assert.That(school.SecondaryArtworkAddress,
                Is.EqualTo("baseball/highschool/PortraitCatcher1"));

            state = GameSaveAggregate.Initial("art-install").Commit(
                "art-awakening",
                stage: ApplicationStage.HighSchool,
                highSchool: HighSchool(HighSchoolPhase.Awakening, chapter: 6));
            BaseballScreenViewModel awakening = model.Read(ShellRoute.Awakening);
            Assert.That(awakening.KeyArtAddress,
                Is.EqualTo("baseball/highschool/KeyArtAwakening"));
            Assert.That(awakening.PlayerPortraitAddress,
                Does.StartWith("baseball/highschool/PortraitPlayer"));
            Assert.That(awakening.PlayerPortraitAddress,
                Does.Not.StartWith("baseball/highschool/PortraitPlayerYoung"));

            state = GameSaveAggregate.Initial("art-install").Commit(
                "art-draft",
                stage: ApplicationStage.Draft,
                highSchool: HighSchool(HighSchoolPhase.Draft, chapter: 8));
            Assert.That(model.Read(ShellRoute.Draft).KeyArtAddress,
                Is.EqualTo("baseball/highschool/KeyArtDraftDay"));

            state = GameSaveAggregate.Initial("art-install").Commit(
                "art-legacy",
                stage: ApplicationStage.Legacy,
                highSchool: HighSchool(HighSchoolPhase.Legacy, chapter: 8));
            Assert.That(model.Read(ShellRoute.RunRecap).KeyArtAddress,
                Is.EqualTo("baseball/highschool/KeyArtReincarnation"));
        }

        [Test]
        public void RelationshipAndTournamentArtworkUseAuthoritativeCategoryAndChapterEvidence()
        {
            var relationship = new RelationshipEventReadModel(
                "evt-loss-interview",
                "패배 뒤 인터뷰",
                "media",
                "기자가 마지막 승부를 묻습니다.",
                "기자",
                "mid",
                "왜 그 공을 골랐나요?");
            var tournament = new TournamentBracketReadModel(
                "전국 청춘 대회",
                new[] { "별빛고", "푸른솔고" },
                "8강");
            var highSchool = new HighSchoolCareerReadModel(
                "context-art-career",
                1,
                HighSchoolPhase.Relationship,
                "seed",
                1,
                "player",
                "해온",
                "power_prospect",
                new PitcherRatingsReadModel(55, 53, 51, 54),
                new CareerPerformanceReadModel(),
                chapterNumber: 2,
                tournament: tournament,
                currentRelationshipEvent: relationship);
            GameSaveAggregate state = GameSaveAggregate.Initial("context-art-install").Commit(
                "context-art",
                stage: ApplicationStage.HighSchool,
                highSchool: highSchool);
            StoreBaseballCareerReadModel model = ReadyModel(() => state);

            ScreenSectionViewModel scene = model.Read(ShellRoute.Relationship).Sections
                .Single(section => section.Id == "hs-relationship-scene");
            Assert.That(scene.Rows.Single(row => row.Id == "hs-relationship-category").Value,
                Is.EqualTo("media"));
            Assert.That(BaseballVisualContentCatalog.RelationshipArtwork(
                    scene.Rows.Single(row => row.Id == "hs-relationship-category").Value,
                    scene.Rows.Single(row => row.Id == "hs-relationship-speaker").Label),
                Is.EqualTo("baseball/meta/SceneArt-media"));

            ScreenSectionViewModel bracket = model.Read(ShellRoute.HighSchoolOverview).Sections
                .Single(section => section.Id == "hs-tournament");
            Assert.That(bracket.Rows.Single(row => row.Id == "hs-tournament-chapter").Value,
                Is.EqualTo("2"));
            Assert.That(BaseballVisualContentCatalog.TournamentBanner(2),
                Is.EqualTo("baseball/highschool/TournamentBanner2"));
        }

        [Test]
        public void ProLevelProjectsItsOwnHeaderAndPlayerPortraitCatalog()
        {
            ProCareerReadModel Career(ProCareerPhase phase, string level) => new ProCareerReadModel(
                "pro-art-career",
                ProCareerOrigin.Direct,
                phase,
                "seed",
                1,
                "player",
                "해온",
                "fictional-club",
                "해오름",
                1,
                1,
                new PitcherRatingsReadModel(65, 63, 61, 64),
                new CareerPerformanceReadModel(),
                level: level);

            GameSaveAggregate state = GameSaveAggregate.Initial("pro-art-install").Commit(
                "pro-art-major",
                stage: ApplicationStage.Pro,
                pro: Career(ProCareerPhase.WeeklyPlan, "major"));
            StoreBaseballCareerReadModel model = ReadyModel(() => state);
            Assert.That(model.Read(ShellRoute.ProWeek).KeyArtAddress,
                Is.EqualTo("baseball/pro/KeyArtMajorDebut"));
            Assert.That(model.Read(ShellRoute.ImportantGame).KeyArtAddress,
                Is.EqualTo("baseball/pro/KeyArtProStadiumTunnel"));
            Assert.That(model.Read(ShellRoute.ProWeek).PlayerPortraitAddress,
                Does.StartWith("baseball/pro/PortraitPlayerPro"));

            state = GameSaveAggregate.Initial("pro-art-install").Commit(
                "pro-art-minor",
                stage: ApplicationStage.Pro,
                pro: Career(ProCareerPhase.WeeklyPlan, "minor"));
            Assert.That(model.Read(ShellRoute.ProWeek).KeyArtAddress,
                Is.EqualTo("baseball/highschool/KeyArtStadiumNight"));
            Assert.That(model.Read(ShellRoute.ImportantGame).KeyArtAddress,
                Is.EqualTo("baseball/highschool/KeyArtStadiumNight"));

            state = GameSaveAggregate.Initial("pro-art-install").Commit(
                "pro-art-retirement",
                stage: ApplicationStage.Retirement,
                pro: Career(ProCareerPhase.Completed, "major"));
            Assert.That(model.Read(ShellRoute.ProRetirement).KeyArtAddress,
                Is.EqualTo("baseball/pro/KeyArtRetirement"));
        }

        [Test]
        public void PendingLegacyDailyResultRedirectsToRecordsWithoutRenderingARetiredScreen()
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
            Assert.That(screen.Route, Is.EqualTo(ShellRoute.Records));
            Assert.That(screen.Actions.Count, Is.EqualTo(1));
            Assert.That(screen.Actions[0].Id, Is.EqualTo("acknowledge_pitch_result"));
            Assert.That(screen.Actions[0].Target, Is.EqualTo(ShellRoute.Records));
        }

        [TestCase(ShellRoute.Awakening, ShellRoute.Awakening)]
        [TestCase(ShellRoute.ProWeek, ShellRoute.ProWeek)]
        [TestCase(ShellRoute.Daily, ShellRoute.Awakening)]
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
                maximumTrainingBlockSessions: 3,
                trainingOutlooks: new[]
                {
                    new TrainingOutlookReadModel(
                        "breaking_ball",
                        "standard",
                        "steady_growth",
                        "안정적인 성장",
                        "변화 성장 1 예상 · 피로 +8")
                });
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
            ScreenRowViewModel outlook = missingTarget.Sections
                .Single(section => section.Id == "hs-training-outlook").Rows.Single();
            Assert.That(outlook.Label, Is.EqualTo("안정적인 성장"));
            Assert.That(outlook.Value, Is.EqualTo("변화 성장 1 예상 · 피로 +8"));

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
        public void ProSeasonProjectsPersonalTeamGrowthAndPhaseSpecificNextChoice()
        {
            var recordBook = new ProRecordBookReadModel(
                new PitchingRecordReadModel(
                    18, 15, 321, 127, 29, 31, 11, 5, 0, 83, 9, 1540, 12),
                Array.Empty<CareerGameLineReadModel>(),
                Array.Empty<ProSeasonLineReadModel>(),
                new[] { "4월 월간 투수상" },
                new[] { "프로 통산 500탈삼진" },
                new[]
                {
                    new ProDecisionHistoryReadModel(
                        "season-4-week-9",
                        "role_meeting",
                        4,
                        9,
                        "challenge_starter",
                        "선발에 도전한다",
                        "긴 이닝 준비와 경쟁 부담을 받아들였습니다.",
                        staminaDelta: 1,
                        managerTrustDelta: -3,
                        fatigueDelta: 10,
                        roleTarget: "starter")
                },
                hallOfFameScore: 480,
                seasonGameLinesAvailable: false);
            var standings = new[]
            {
                new LeagueStandingReadModel(1, "club-a", "해오름", 72, 48, 2, 0, true),
                new LeagueStandingReadModel(2, "club-b", "푸른물결", 69, 51, 2, 3.0, false),
            };
            ProCareerReadModel Career(
                ProCareerPhase phase,
                ProSeasonDecisionReadModel decision = null) => new ProCareerReadModel(
                "pro-season-career",
                ProCareerOrigin.HighSchool,
                phase,
                "next-seed",
                44,
                "player",
                "해온",
                "club-a",
                "해오름",
                4,
                24,
                new PitcherRatingsReadModel(78, 75, 73, 80),
                new CareerPerformanceReadModel(18, 1540, 321, 127, 29, 83, 31),
                level: "major",
                role: "starter",
                managerTrust: 76,
                catcherTrust: 81,
                fatigue: 34,
                seasonDecision: decision,
                leagueStandings: standings,
                seasonSegment: "season_finale",
                seasonSegmentTitle: "시즌 막바지",
                developmentProgress: new ProDevelopmentProgressReadModel(1, 0, 1, 0),
                lastSegmentProgress: new ProSegmentProgressReadModel(
                    4, "pennant_race", "season_finale", "phase_changed", "develop_stuff"),
                recordBook: recordBook);

            GameSaveAggregate state = GameSaveAggregate.Initial("pro-season-install").Commit(
                "season-review",
                stage: ApplicationStage.Pro,
                pro: Career(ProCareerPhase.SeasonReview));
            string selected = string.Empty;
            var model = new StoreBaseballCareerReadModel(
                KoreanUiCopyCatalog.LoadDefault(),
                () => state,
                () => ShellRuntimeStatus.Ready,
                () => string.Empty,
                selectedChoice: group => group == "pro_season_decision" ? selected : string.Empty);

            BaseballScreenViewModel review = model.Read(ShellRoute.ProSeason);
            Assert.That(review.Sections.Select(section => section.Id), Is.EqualTo(new[]
            {
                "pro-season-personal",
                "pro-season-team",
                "pro-season-growth",
                "pro-season-decisions",
                "pro-season-achievements",
                "pro-season-next",
            }));
            Assert.That(review.Sections.Single(section => section.Id == "pro-season-personal")
                .Rows.Single(row => row.Id == "pro-season-personal-performance").Value,
                Is.EqualTo("18경기 · 선발 15 · 107이닝 · 투구 1540"));
            Assert.That(review.Sections.Single(section => section.Id == "pro-season-team")
                .Rows[0].Detail, Is.EqualTo("현재 선두 · 내 구단"));
            Assert.That(review.Sections.Single(section => section.Id == "pro-season-growth")
                .Rows.Single(row => row.Id == "pro-season-ratings").Value,
                Is.EqualTo("구위 78 · 제구 75 · 변화 73 · 체력 80"));
            Assert.That(review.Sections.Single(section => section.Id == "pro-season-growth")
                .Rows.Single(row => row.Id == "pro-season-development").Value,
                Is.EqualTo("구위 1/2 · 제구 0/2 · 변화 1/2 · 체력 0/2"));
            Assert.That(review.Sections.Single(section => section.Id == "pro-season-decisions")
                .Rows.Single().Detail, Does.Contain("체력 +1"));
            Assert.That(review.Sections.Single(section => section.Id == "pro-season-next")
                .Rows.Single().Detail, Does.Contain("오프시즌 선택 또는 은퇴 결정"));

            var choices = new[]
            {
                new CareerChoiceReadModel(
                    "run_prevention",
                    "실점 억제를 택한다",
                    "제구와 배터리 운영을 다듬습니다.",
                    "제구 +1 · 포수 호흡 +4 · 피로 +7",
                    payload: "season-4-week-12|run_prevention",
                    recommended: true,
                    recommendationReason: "현재 포수 호흡과 팀 순위에 맞습니다."),
                new CareerChoiceReadModel(
                    "body_management",
                    "몸을 관리한다",
                    "긴 시즌을 버틸 체력과 회복을 택합니다.",
                    "체력 +1 · 피로 -12",
                    payload: "season-4-week-12|body_management")
            };
            state = state.Commit(
                "season-decision",
                stage: ApplicationStage.Pro,
                pro: Career(
                    ProCareerPhase.SeasonDecision,
                    new ProSeasonDecisionReadModel(
                        "season-4-week-12",
                        "기록 추격",
                        "개인 기록과 팀에 필요한 투구 사이에서 방향을 고릅니다.",
                        choices)));

            BaseballScreenViewModel waiting = model.Read(ShellRoute.ProSeason);
            Assert.That(waiting.Sections.Single(section => section.Id == "pro-season-next")
                .Rows.Single(row => row.Id == "pro-season-next-selection").Value,
                Is.EqualTo("선택 대기"));
            Assert.That(waiting.Actions.Single(action => action.Id == "resolve_pro_decision").IsEnabled,
                Is.False);

            selected = "season-4-week-12|run_prevention";
            BaseballScreenViewModel decided = model.Read(ShellRoute.ProSeason);
            ScreenRowViewModel rationale = decided.Sections
                .Single(section => section.Id == "pro-season-next")
                .Rows.Single(row => row.Id == "pro-season-next-selection");
            Assert.That(rationale.Label, Is.EqualTo("선택 근거 · 실점 억제를 택한다"));
            Assert.That(rationale.Value, Is.EqualTo("제구 +1 · 포수 호흡 +4 · 피로 +7"));
            Assert.That(rationale.Detail, Does.Contain("추천 근거"));
            Assert.That(decided.Actions.Single(action => action.Id == "resolve_pro_decision").IsEnabled,
                Is.True);
            Assert.That(decided.Sections.SelectMany(section => section.Rows)
                .All(row => row.Value != "—" && !row.Detail.Contains("현재 저장 상태에 기록되지 않는 항목")),
                Is.True,
                "the scroll-backed generic rows stay meaningful when the 200% font reflow stacks value text");
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
            GameSaveAggregate nextLifeState = GameSaveAggregate.Initial("install").Commit(
                "archived-life",
                stage: ApplicationStage.HighSchool,
                highSchool: highSchool,
                meta: new MetaProgressState(lifeNumber: 2, lifeArchive: new[] { record }));
            var nextLifeModel = new StoreBaseballCareerReadModel(
                KoreanUiCopyCatalog.LoadDefault(),
                () => nextLifeState,
                () => ShellRuntimeStatus.Ready,
                () => string.Empty);

            ScreenRowViewModel previousPlayer = nextLifeModel.Read(ShellRoute.Prologue).Sections
                .SelectMany(section => section.Rows)
                .Single(value => value.Id == "player-legacy-letter-copy");
            Assert.That(previousPlayer.Label, Is.EqualTo(frozen.Title));
            Assert.That(previousPlayer.Value, Is.EqualTo(frozen.DefiningMoment));
            Assert.That(previousPlayer.Detail, Is.EqualTo("“" + frozen.Farewell + "”"));

            GameSaveAggregate recapState = GameSaveAggregate.Initial("recap-install").Commit(
                "finalized-life",
                stage: ApplicationStage.Legacy,
                meta: new MetaProgressState(lifeNumber: 1, lifeArchive: new[] { record }));
            var recapModel = new StoreBaseballCareerReadModel(
                KoreanUiCopyCatalog.LoadDefault(),
                () => recapState,
                () => ShellRuntimeStatus.Ready,
                () => string.Empty);
            ScreenRowViewModel recap = recapModel.Read(ShellRoute.RunRecap).Sections
                .SelectMany(section => section.Rows)
                .Single(value => value.Id == "player-legacy-letter-copy");
            Assert.That(recap.Label, Is.EqualTo(frozen.Title));
            Assert.That(recap.Value, Is.EqualTo(frozen.DefiningMoment));
            Assert.That(recap.Detail, Is.EqualTo("“" + frozen.Farewell + "”"));

            ScreenRowViewModel archived = recapModel.Read(ShellRoute.LifeArchive).Sections
                .SelectMany(section => section.Rows)
                .Single(value => value.Id == "archive-player-legacy-1");
            Assert.That(archived.Label, Is.EqualTo(frozen.Title));
            Assert.That(archived.Value, Is.EqualTo(frozen.DefiningMoment));
            Assert.That(archived.Detail, Is.EqualTo("“" + frozen.Farewell + "”"));
            Assert.That(nextLifeModel.Read(ShellRoute.Opening).Sections.Select(section => section.Id),
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
                .Single(row => row.Id == "life-card-player").Label, Is.EqualTo("해온"));
        }

        [Test]
        public void LifeCardUsesSelectedFrozenRecordForEveryFieldWhileAnotherCareerIsActive()
        {
            var detail = new HighSchoolLifeDetailReadModel(
                new PitcherRatingsReadModel(42, 43, 44, 45),
                new[] { "끝내주는 투수" },
                new[] { "별빛고에 입학했다.", "마지막 타자를 삼진으로 돌려세웠다." },
                "도윤",
                "서준",
                "지후",
                "차분한 승부사",
                windTitle: "흔들리지 않는 바람");
            var selected = new LifeArchiveRecord(
                "life-1",
                1,
                "해온",
                "career-4242-life-1",
                "pro-1",
                "school-1",
                "별빛고",
                true,
                88,
                new PitcherRatingsReadModel(70, 66, 64, 68),
                new CareerPerformanceReadModel(4, 80, 18, 13, 4, 5, 2),
                3,
                117,
                1,
                76,
                14,
                highSchoolDetail: detail,
                signatureLegacy: new SignatureLegacyReadModel(
                    "legacy-command", "흔들리지 않는 손끝", "제구 성장", "볼넷 억제"),
                pitches: 80,
                outs: 18,
                hits: 5,
                draftTeamName: "해오름");
            var active = new HighSchoolCareerReadModel(
                "career-new-life-2",
                2,
                HighSchoolPhase.Training,
                "seed",
                1,
                "player-new",
                "새봄",
                "innings_eater",
                new PitcherRatingsReadModel(99, 98, 97, 96),
                new CareerPerformanceReadModel(9, 999, 27, 25, 0, 0, 0));
            GameSaveAggregate state = GameSaveAggregate.Initial("install").Commit(
                "active-next-life",
                stage: ApplicationStage.HighSchool,
                highSchool: active,
                meta: new MetaProgressState(lifeNumber: 2, lifeArchive: new[] { selected }));
            var model = new StoreBaseballCareerReadModel(
                KoreanUiCopyCatalog.LoadDefault(),
                () => state,
                () => ShellRuntimeStatus.Ready,
                () => string.Empty,
                selectedChoice: group => group == "archive_life" ? "1" : string.Empty);

            BaseballScreenViewModel card = model.Read(ShellRoute.LifeCard);
            ScreenRowViewModel[] rows = card.Sections.SelectMany(section => section.Rows).ToArray();

            Assert.That(card.Title, Is.EqualTo("1번째 선수의 기록 · 해온"));
            Assert.That(rows.Single(row => row.Id == "life-card-rating-stuff").Value,
                Is.EqualTo("42 → 70"));
            Assert.That(rows.Single(row => row.Id == "life-card-rating-movement").Value,
                Is.EqualTo("44 → 64"));
            Assert.That(rows.Single(row => row.Id == "life-card-record-counts").Value,
                Does.Contain("탈삼진 13"));
            Assert.That(rows.Single(row => row.Id == "life-card-draft").Label,
                Is.EqualTo("해오름 지명"));
            Assert.That(rows.Single(row => row.Id == "life-card-challenge").Value,
                Is.EqualTo("4242-1"));
            Assert.That(string.Join(" ", rows.SelectMany(row => new[] { row.Value, row.Detail })),
                Does.Not.Contain("99"));
            Assert.That(string.Join(" ", rows.SelectMany(row => new[] { row.Value, row.Detail })),
                Does.Not.Contain("999"));
        }

        [Test]
        public void RunRecapNeverUsesPriorLifeBeforeCurrentSettlementAndCardAppearsAfterFinalize()
        {
            LifeArchiveRecord prior = ArchivedLife(new PlayerLegacyState("이전 제목", "이전 순간", "이전 작별"));
            var currentCareer = new HighSchoolCareerReadModel(
                "career-20260811-life-2",
                2,
                HighSchoolPhase.Legacy,
                "seed",
                12,
                "player-2",
                "새봄",
                "precision_commander",
                new PitcherRatingsReadModel(68, 72, 65, 64),
                new CareerPerformanceReadModel(5, 60, 15, 10, 3, 4, 1),
                legacySelectionMode: LegacySelectionMode.SignatureLegacy,
                signatureLegacyChoices: new[]
                {
                    new CareerChoiceReadModel("legacy-command", "흔들리지 않는 손끝", "제구", "근거")
                });
            GameSaveAggregate before = GameSaveAggregate.Initial("install").Commit(
                "before-finalize",
                stage: ApplicationStage.Legacy,
                highSchool: currentCareer,
                meta: new MetaProgressState(lifeNumber: 2, lifeArchive: new[] { prior }));
            var selected = new Dictionary<string, string>(StringComparer.Ordinal)
            {
                ["legacy_signature"] = "legacy-command"
            };
            StoreBaseballCareerReadModel beforeModel = new StoreBaseballCareerReadModel(
                KoreanUiCopyCatalog.LoadDefault(),
                () => before,
                () => ShellRuntimeStatus.Ready,
                () => string.Empty,
                selectedChoice: group => selected.TryGetValue(group, out string value) ? value : string.Empty);

            BaseballScreenViewModel preFinalize = beforeModel.Read(ShellRoute.RunRecap);
            Assert.That(preFinalize.Sections.Select(section => section.Id),
                Does.Not.Contain("player-legacy-letter"));
            Assert.That(preFinalize.Actions.Select(action => action.Id), Does.Not.Contain("navigate_life_card"));
            Assert.That(StoreBaseballCareerReadModel.CurrentLifeArchiveFor(before), Is.Null);

            var current = new LifeArchiveRecord(
                "life-2",
                2,
                "새봄",
                currentCareer.CareerId,
                null,
                "school-2",
                "푸른솔고",
                false,
                73,
                currentCareer.Ratings,
                currentCareer.Performance,
                0,
                0,
                0,
                0,
                9,
                playerLegacy: new PlayerLegacyState("자기 공을 남긴 투수", "마지막 승부", "다음 공도 믿어."));
            GameSaveAggregate after = before.Commit(
                "after-finalize",
                meta: new MetaProgressState(lifeNumber: 2, lifeArchive: new[] { current, prior }));
            BaseballScreenViewModel finalized = ReadyModel(() => after).Read(ShellRoute.RunRecap);

            Assert.That(StoreBaseballCareerReadModel.CurrentLifeArchiveFor(after), Is.SameAs(current));
            Assert.That(finalized.Sections.Select(section => section.Id), Does.Contain("recap-stamps"));
            Assert.That(finalized.Sections.Select(section => section.Id), Does.Contain("player-legacy-letter"));
            Assert.That(finalized.Actions.Select(action => action.Id), Does.Contain("navigate_life_card"));
        }

        [Test]
        public void WeeklyOnlySaveStillProjectsAValidRecordsBoard()
        {
            var program = new WeeklyProgramState(
                "2026-W33",
                new[]
                {
                    new WeeklyTaskState("chapters", WeeklyTaskKinds.ChaptersAdvanced, 1, 1),
                    new WeeklyTaskState("games", WeeklyTaskKinds.ImportantGamesCompleted, 2, 1),
                    new WeeklyTaskState("days", WeeklyTaskKinds.PlayedOnTwoDays, 2, 1),
                },
                new[] { "chapters", "games" },
                false);
            GameSaveAggregate state = GameSaveAggregate.Initial("install").Commit(
                "weekly-only",
                meta: new MetaProgressState(
                    weekly: new WeeklyProgressState(program, null, "20260810")));

            BaseballScreenViewModel records = ReadyModel(() => state).Read(ShellRoute.Records);

            Assert.That(records.Sections.Select(section => section.Id),
                Does.Not.Contain("records-empty"));
            Assert.That(records.Sections.Select(section => section.Id),
                Does.Contain("records-weekly-note"));
            Assert.That(records.Sections.SelectMany(section => section.Rows)
                .Any(row => row.Value.Contains("1/1") || row.Value.Contains("1/2")), Is.True);
            ScreenActionViewModel weekly = records.Actions.Single(action =>
                action.Id == "navigate_weekly");
            Assert.That(weekly.Target, Is.EqualTo(ShellRoute.Weekly));

            BaseballScreenViewModel board = ReadyModel(() => state).Read(ShellRoute.Weekly);
            Assert.That(board.Sections.Select(section => section.Id), Does.Contain("weekly-tasks"));
            Assert.That(board.Actions.Single().Id, Is.EqualTo("claim_weekly"));
            Assert.That(board.Actions.Single().IsEnabled, Is.True,
                "과제 두 개를 완료한 저장 상태에서는 실제 보상 command를 실행할 수 있어야 합니다.");
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
                stage: ApplicationStage.Legacy,
                meta: new MetaProgressState(lifeNumber: 1, lifeArchive: new[] { record }));
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
        public void RetiredDailyRouteRedirectsHomeWithoutAnyDailySurface()
        {
            GameSaveAggregate state = GameSaveAggregate.Initial("install");
            var model = new StoreBaseballCareerReadModel(
                KoreanUiCopyCatalog.LoadDefault(),
                () => state,
                () => ShellRuntimeStatus.Ready,
                () => string.Empty);

            BaseballScreenViewModel retired = model.Read(ShellRoute.Daily);
            Assert.That(model.Routes.Any(route => route == ShellRoute.Daily), Is.False);
            Assert.That(retired.Route, Is.EqualTo(ShellRoute.Opening));
            Assert.That(string.Join(" ", retired.Sections.SelectMany(section => section.Rows)
                    .SelectMany(row => new[] { row.Label, row.Value, row.Detail })),
                Does.Not.Contain("일일"));
        }

        [Test]
        public void RetiredDailyLinksPreferActiveProThenHighSchoolThenOpening()
        {
            var highSchool = new HighSchoolCareerReadModel(
                "hs-career", 1, HighSchoolPhase.Training, "seed", 1, "player", "해온",
                "power_prospect", new PitcherRatingsReadModel(60, 60, 60, 60),
                new CareerPerformanceReadModel());
            var pro = new ProCareerReadModel(
                "pro-career", ProCareerOrigin.Direct, ProCareerPhase.WeeklyPlan, "pro-seed", 2,
                "pro-player", "새봄", "fictional-club", "해오름", 1, 1,
                new PitcherRatingsReadModel(70, 70, 70, 70), new CareerPerformanceReadModel());
            GameSaveAggregate initial = GameSaveAggregate.Initial("install");
            GameSaveAggregate highSchoolOnly = initial.Commit(
                "hs", stage: ApplicationStage.HighSchool, highSchool: highSchool);
            GameSaveAggregate withPro = highSchoolOnly.Commit(
                "pro", stage: ApplicationStage.Pro, pro: pro);

            Assert.That(StoreBaseballCareerReadModel.RetiredDailyFallbackFor(withPro),
                Is.EqualTo(ShellRoute.ProWeek));
            Assert.That(StoreBaseballCareerReadModel.RetiredDailyFallbackFor(highSchoolOnly),
                Is.EqualTo(ShellRoute.Training));
            Assert.That(StoreBaseballCareerReadModel.RetiredDailyFallbackFor(initial),
                Is.EqualTo(ShellRoute.Opening));
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

        private static GameSaveAggregate SetupState(string installId) =>
            GameSaveAggregate.Initial(installId).Commit(
                "setup-life-two",
                stage: ApplicationStage.Setup,
                meta: new MetaProgressState(lifeNumber: 2));

        private static async Task<GameApplicationStore> OpenSetupStore(string installId)
        {
            GameSaveAggregate state = SetupState(installId);
            var repository = new InMemoryGameRepository
            {
                LoadResult = SaveLoadResult<GameSaveAggregate>.Create(
                    SaveLoadStatus.LoadedCanonical,
                    new SaveEnvelope<GameSaveAggregate>(
                        SaveSchema.Name,
                        SaveSchema.Version,
                        state.Revision,
                        new DateTimeOffset(2026, 8, 11, 0, 0, 0, TimeSpan.Zero),
                        new string('a', 64),
                        state))
            };
            return await GameApplicationStore.OpenAsync(
                repository,
                new CoreHighSchoolCareerPort(),
                new CoreProCareerPort(),
                installId,
                CancellationToken.None);
        }

        private static Task<GameApplicationStore> OpenStore(GameSaveAggregate state)
        {
            var repository = new InMemoryGameRepository
            {
                LoadResult = SaveLoadResult<GameSaveAggregate>.Create(
                    SaveLoadStatus.LoadedCanonical,
                    new SaveEnvelope<GameSaveAggregate>(
                        SaveSchema.Name,
                        SaveSchema.Version,
                        state.Revision,
                        new DateTimeOffset(2026, 8, 11, 0, 0, 0, TimeSpan.Zero),
                        new string('c', 64),
                        state))
            };
            return GameApplicationStore.OpenAsync(
                repository,
                new CoreHighSchoolCareerPort(),
                new CoreProCareerPort(),
                state.InstallId,
                CancellationToken.None);
        }

        private static ProductionBaseballShellRuntime ReadyProductionRuntime(
            GameApplicationStore store)
        {
            var runtime = new ProductionBaseballShellRuntime(KoreanUiCopyCatalog.LoadDefault());
            InvokeOnReady(runtime, store);
            return runtime;
        }

        private static void InvokeOnReady(
            ProductionBaseballShellRuntime runtime,
            GameApplicationStore store)
        {
            MethodInfo onReady = typeof(ProductionBaseballShellRuntime).GetMethod(
                "OnReady",
                BindingFlags.Instance | BindingFlags.NonPublic);
            Assert.That(onReady, Is.Not.Null);
            onReady.Invoke(runtime, new object[] { store });
        }

        private static GameCommand ProductionCommand(
            ProductionBaseballShellRuntime runtime,
            string actionId,
            GameSaveAggregate state)
        {
            MethodInfo create = typeof(ProductionBaseballShellRuntime).GetMethod(
                "CreateCommand",
                BindingFlags.Instance | BindingFlags.NonPublic);
            Assert.That(create, Is.Not.Null);
            return (GameCommand)create.Invoke(runtime, new object[] { actionId, state });
        }

        private static CareerChoiceReadModel Choice(string payload, string title) =>
            new CareerChoiceReadModel(payload, title, title, payload: payload);

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

        private sealed class InMemoryGameRepository : ISaveRepository<GameSaveAggregate>
        {
            public SaveLoadResult<GameSaveAggregate> LoadResult { get; set; } =
                SaveLoadResult<GameSaveAggregate>.Create(SaveLoadStatus.NoSave);

            public Task<SaveWriteResult<GameSaveAggregate>> SaveAsync(
                GameSaveAggregate payload,
                ulong revision,
                CancellationToken cancellationToken = default)
            {
                LoadResult = SaveLoadResult<GameSaveAggregate>.Create(
                    SaveLoadStatus.LoadedCanonical,
                    new SaveEnvelope<GameSaveAggregate>(
                        SaveSchema.Name,
                        SaveSchema.Version,
                        revision,
                        DateTimeOffset.UtcNow,
                        new string('b', 64),
                        payload));
                return Task.FromResult<SaveWriteResult<GameSaveAggregate>>(null);
            }

            public Task<SaveLoadResult<GameSaveAggregate>> LoadAsync(
                CancellationToken cancellationToken = default) =>
                Task.FromResult(LoadResult);

            public Task ResetAsync(CancellationToken cancellationToken = default)
            {
                LoadResult = SaveLoadResult<GameSaveAggregate>.Create(SaveLoadStatus.NoSave);
                return Task.CompletedTask;
            }
        }
    }
}
