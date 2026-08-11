using System;
using System.Collections.Generic;
using System.IO;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;
using Baseball.Presentation.Records;
using Baseball.Presentation.Shell;
using NUnit.Framework;
using UnityEditor;
using UnityEngine.UIElements;

namespace Baseball.Presentation.Tests.Screens
{
    public sealed class ScreenToolkitAssetTests
    {
        private static readonly string[] TemplatePaths =
        {
            "Assets/Game/Presentation/Opening/Resources/OpeningScreen.uxml",
            "Assets/Game/Presentation/Setup/Resources/SetupScreen.uxml",
            "Assets/Game/Presentation/HighSchool/Resources/HighSchoolScreen.uxml",
            "Assets/Game/Presentation/Pro/Resources/ProScreen.uxml",
            "Assets/Game/Presentation/Records/Resources/RecordsScreen.uxml",
            "Assets/Game/Presentation/Meta/Resources/MetaScreen.uxml",
            "Assets/Game/Presentation/Settings/Resources/SettingsScreen.uxml",
        };

        [TestCaseSource(nameof(TemplatePaths))]
        public void FeatureTemplateContainsRequiredBindingSlots(string assetPath)
        {
            VisualTreeAsset template = AssetDatabase.LoadAssetAtPath<VisualTreeAsset>(assetPath);
            Assert.That(template, Is.Not.Null, assetPath);
            TemplateContainer tree = template.CloneTree();
            Assert.That(tree.Q<Label>("screen-title"), Is.Not.Null, assetPath);
            Assert.That(tree.Q<Label>("screen-lead"), Is.Not.Null, assetPath);
            Assert.That(tree.Q<VisualElement>("screen-custom"), Is.Not.Null, assetPath);
            Assert.That(tree.Q<VisualElement>("screen-sections"), Is.Not.Null, assetPath);
            Assert.That(tree.Q<VisualElement>("screen-actions"), Is.Not.Null, assetPath);
        }

        [Test]
        public void ShellTemplateContainsNavigationSafeAreaAndOverlayHosts()
        {
            const string assetPath = "Assets/Game/Presentation/Shell/Resources/BaseballShell.uxml";
            VisualTreeAsset template = AssetDatabase.LoadAssetAtPath<VisualTreeAsset>(assetPath);
            Assert.That(template, Is.Not.Null);
            TemplateContainer tree = template.CloneTree();
            Assert.That(tree.Q<VisualElement>("shell-root"), Is.Not.Null);
            Assert.That(tree.Q<VisualElement>("shell-topbar"), Is.Not.Null);
            Assert.That(tree.Q<VisualElement>("shell-screen"), Is.Not.Null);
            Assert.That(tree.Q<VisualElement>("shell-bottom"), Is.Not.Null);
            Assert.That(tree.Q<VisualElement>("shell-overlay"), Is.Not.Null);
        }

        [Test]
        public void FeatureStylesUseThemeTokensInsteadOfRawColors()
        {
            string[] roots =
            {
                "Opening", "Setup", "HighSchool", "Pro", "Records", "Meta", "Settings", "Shell",
            };
            var rawColor = new Regex("#[0-9a-fA-F]{3,8}", RegexOptions.CultureInvariant);
            foreach (string root in roots)
            {
                string[] files = Directory.GetFiles(
                    "Assets/Game/Presentation/" + root,
                    "*.uss",
                    SearchOption.AllDirectories);
                foreach (string file in files)
                {
                    Assert.That(rawColor.IsMatch(File.ReadAllText(file)), Is.False, file);
                }
            }
        }

        [Test]
        public void LargeTextLayoutHasExplicitTwoHundredPercentReflow()
        {
            string style = File.ReadAllText("Assets/Game/Presentation/Shell/Resources/ScreenLayout.uss");
            StringAssert.Contains(".baseball-font-scale-200 .screen-data-row", style);
            StringAssert.Contains("flex-direction: column", style);
            StringAssert.Contains("max-width: 100%", style);
        }

        [Test]
        public void RuntimeShellWiresTalkBackBackAndSafeAreaHooks()
        {
            string controller = File.ReadAllText("Assets/Game/Presentation/Shell/BaseballShellController.cs");
            string host = File.ReadAllText("Assets/Game/Presentation/Shell/BaseballShellHost.cs");
            StringAssert.Contains("BaseballAccessibilitySession", controller);
            StringAssert.Contains("BaseballSafeAreaController", controller);
            StringAssert.Contains("NavigationCancelEvent", controller);
            StringAssert.Contains("KeyCode.Escape", host);
            StringAssert.Contains("Keyboard.current?.escapeKey.wasPressedThisFrame", host);
            StringAssert.Contains("_runtime.PreferredRoute", controller);
            StringAssert.DoesNotContain("new MockBaseballCareerReadModel", host);
        }

        [Test]
        public void ProductionSettingsAndPitchUseImportedAudioWithoutDisabledPlaceholders()
        {
            string settings = File.ReadAllText("Assets/Game/Presentation/Settings/SettingsScreenController.cs");
            string feedback = File.ReadAllText("Assets/Game/Presentation/Pitch/Runtime/AddressablePitchFeedbackBoundary.cs");
            StringAssert.Contains("SetSoundEnabled", settings);
            StringAssert.Contains("SetMusicEnabled", settings);
            StringAssert.Contains("baseball/audio/crowd-loop", feedback);
            StringAssert.Contains("OnApplicationPause", feedback);
            StringAssert.Contains("AndroidAudioFocusService", feedback);
            StringAssert.DoesNotContain("sound.SetEnabled(false)", settings);
            StringAssert.DoesNotContain("music.SetEnabled(false)", settings);
            StringAssert.Contains("NotificationSettingsRequired", settings);
            StringAssert.Contains("OpenNotificationSettings", settings);
        }

        [Test]
        public void LifeCardShareCapturesCardOnlyPngAndDoesNotClaimChooserCompletion()
        {
            string controller = File.ReadAllText("Assets/Game/Presentation/Shell/BaseballShellController.cs");
            string runtime = File.ReadAllText("Assets/Game/Presentation/Shell/ProductionBaseballShellRuntime.cs");
            string capture = File.ReadAllText("Assets/Game/Presentation/Records/ScreenLifeCardPngCapture.cs");
            StringAssert.Contains("life-card-capture", controller);
            StringAssert.Contains("CaptureScreenshotAsTexture", capture);
            StringAssert.Contains("EncodeToPNG", capture);
            StringAssert.Contains("TrySharePng", runtime);
            StringAssert.Contains("TryShareText", runtime);
            StringAssert.DoesNotContain("AnalyticsEvent.LifeCardShareCompleted", runtime);
            StringAssert.DoesNotContain("AnalyticsEvent.LifeCardShared", runtime);
        }

        [Test]
        public void SaveResetPublishesAnonymousIdentityOnlyAfterDurableReset()
        {
            string runtime = File.ReadAllText("Assets/Game/Presentation/Shell/ProductionBaseballShellRuntime.cs");
            int reset = runtime.IndexOf("await _store.ResetAsync(", System.StringComparison.Ordinal);
            int replace = runtime.IndexOf("AnonymousInstallIdentity.Replace(installId)", System.StringComparison.Ordinal);
            Assert.That(reset, Is.GreaterThanOrEqualTo(0));
            Assert.That(replace, Is.GreaterThan(reset));
            StringAssert.Contains("GameResetException", runtime);
            StringAssert.Contains("기존 진행과 익명 식별자는 그대로 유지됩니다", runtime);
            StringAssert.Contains("ResetIdentityAndOnceFlags", runtime);
            StringAssert.Contains("ResetLocalState", runtime);
            StringAssert.Contains("ClearShareCache", runtime);
        }

        [Test]
        public void ProductSettingsUseAtomicGameSaveCommandsInsteadOfPlayerPrefs()
        {
            string runtime = File.ReadAllText("Assets/Game/Presentation/Shell/ProductionBaseballShellRuntime.cs");
            StringAssert.Contains("GameSettingsState Settings", runtime);
            StringAssert.Contains("UpdateGameSettingsCommand", runtime);
            StringAssert.Contains("await _store.DispatchAsync", runtime);
            StringAssert.Contains("이전 설정으로 되돌렸습니다", runtime);
            StringAssert.DoesNotContain("baseball.presentation.auto-release", runtime);
            StringAssert.DoesNotContain("PlayerPrefs.GetInt", runtime);
            StringAssert.DoesNotContain("PlayerPrefs.SetInt", runtime);
        }

        [Test]
        public void ProductionPitchHasNoDemoFallbackAndPersistsBeforePlayback()
        {
            string coordinator = File.ReadAllText("Assets/Game/Presentation/Pitch/Runtime/PitchShellFlowCoordinator.cs");
            string persistence = File.ReadAllText("Assets/Game/Presentation/Shell/ProductionPitchSessionPersistence.cs");
            int commit = coordinator.IndexOf("await _persistence.CommitAsync", System.StringComparison.Ordinal);
            int play = coordinator.IndexOf("_stage.Play(commit.Presentation)", commit, System.StringComparison.Ordinal);
            Assert.That(commit, Is.GreaterThanOrEqualTo(0));
            Assert.That(play, Is.GreaterThan(commit));
            StringAssert.Contains("PlayRecoveredSummary", coordinator);
            StringAssert.Contains("PitchCommitMetrics.Evaluate", persistence);
            StringAssert.Contains("new PitchAbilityMomentEvidence", persistence);
            StringAssert.Contains("PitchSequenceEvaluator", File.ReadAllText(
                "Assets/Game/Presentation/Pitch/Model/PitchCommitMetrics.cs"));
            StringAssert.Contains("PitchAbilityRules.Moment", File.ReadAllText(
                "Assets/Game/Presentation/Pitch/Model/PitchCommitMetrics.cs"));
            StringAssert.DoesNotContain("PitchDemoRequestFactory", coordinator);
            StringAssert.DoesNotContain("PitchDemoRequestFactory", persistence);
            Assert.That(File.Exists("Assets/Game/Presentation/Pitch/Model/PitchDemoRequestFactory.cs"), Is.False);
            Assert.That(File.Exists("Assets/Tests/EditMode/Presentation/PitchDemoRequestFactory.cs"), Is.True);
        }

        [Test]
        public void FirstBullpenUsesDurableTutorialKindAndCannotExposeAbortUi()
        {
            string model = File.ReadAllText("Assets/Game/Presentation/Shell/StoreBaseballCareerReadModel.cs");
            string runtime = File.ReadAllText("Assets/Game/Presentation/Shell/ProductionBaseballShellRuntime.cs");
            string persistence = File.ReadAllText("Assets/Game/Presentation/Shell/ProductionPitchSessionPersistence.cs");
            string hud = File.ReadAllText("Assets/Game/Presentation/Pitch/Runtime/PitchHudController.cs");
            StringAssert.Contains("첫 공을 던진다", model);
            StringAssert.Contains("바로 학교 고르기", model);
            StringAssert.Contains("SkipTutorialCommand", runtime);
            StringAssert.Contains("PitchCareerKind.Tutorial", runtime);
            StringAssert.Contains("ShellRoute.Prologue", runtime);
            StringAssert.Contains("loaded.IsTutorial", File.ReadAllText(
                "Assets/Game/Presentation/Pitch/Runtime/PitchShellFlowCoordinator.cs"));
            string coordinator = File.ReadAllText(
                "Assets/Game/Presentation/Pitch/Runtime/PitchShellFlowCoordinator.cs");
            StringAssert.Contains("ShowTutorialDecision", coordinator);
            StringAssert.Contains("RetryTutorialAsync", coordinator);
            StringAssert.Contains("AcceptTutorialResult", coordinator);
            StringAssert.Contains("RetryTutorialPitchCommand", persistence);
            string decision = File.ReadAllText(
                "Assets/Game/Presentation/Pitch/Resources/PitchTutorialDecision.uxml");
            StringAssert.Contains("pitch-tutorial-retry", File.ReadAllText(
                "Assets/Game/Presentation/Pitch/Runtime/PitchTutorialDecisionController.cs"));
            StringAssert.Contains("pitch-tutorial-actions", decision);
            StringAssert.Contains("if (_tutorial)", hud);
            StringAssert.Contains("backSlot.style.display = DisplayStyle.None", hud);
            StringAssert.Contains("before.PitchResume?.CareerKind == PitchCareerKind.Tutorial", persistence);
            StringAssert.Contains("completedKind == PitchCareerKind.HighSchool || completedKind == PitchCareerKind.Pro", persistence);
            StringAssert.Contains("pending-pitch-result", model);
            StringAssert.Contains("state.PendingPitchCompletion.CareerKind == PitchCareerKind.Tutorial", model);
        }

        [Test]
        public void ProductionProjectionRendersSavedRowsAndActualChoicePayloads()
        {
            string model = File.ReadAllText("Assets/Game/Presentation/Shell/StoreBaseballCareerReadModel.cs");
            string runtime = File.ReadAllText("Assets/Game/Presentation/Shell/ProductionBaseballShellRuntime.cs");
            StringAssert.Contains("Tournament", model);
            StringAssert.Contains("ProspectRankings", model);
            StringAssert.Contains("GameLines", model);
            StringAssert.Contains("LeagueStandings", model);
            StringAssert.Contains("LeaguePitchers", model);
            StringAssert.Contains("LifeArchive", model);
            StringAssert.Contains("AchievementTitle", model);
            StringAssert.Contains("WeeklyTaskTitle", model);
            StringAssert.Contains("CurrentRelationshipEvent", model);
            StringAssert.Contains("CurrentGameScenario", model);
            StringAssert.Contains("LastTraining", model);
            StringAssert.Contains("LastRelationship", model);
            StringAssert.Contains("career.News", model);
            StringAssert.DoesNotContain("gauge.SetValue(viewModel.Route == ShellRoute.Training ? 64 : 76", File.ReadAllText(
                "Assets/Game/Presentation/HighSchool/HighSchoolScreenController.cs"));
            StringAssert.Contains("SignProContractCommand", runtime);
            StringAssert.Contains("DeclineProCareerCommand", runtime);
            StringAssert.Contains("SkipTutorialCommand", runtime);
            StringAssert.Contains("FinalizeHighSchoolLegacyCommand", runtime);
            StringAssert.Contains("Selected(\"pro_week_plan\"", runtime);
            StringAssert.Contains("Selected(\"pro_season_decision\"", runtime);
            StringAssert.Contains("Selected(\"pro_offseason\"", runtime);
            StringAssert.Contains("pro?.Phase == ProCareerPhase.RetirementDecision", model);
            StringAssert.DoesNotContain("현재 저장 상태에 기록되지 않는 항목입니다.", model);
            StringAssert.DoesNotContain("value = \"—\"", model);
        }

        [Test]
        public void LifeArchiveUsesDynamicVirtualizationAndOnlyBuildsSelectedDetail()
        {
            var sections = new[]
            {
                new ScreenSectionViewModel(
                    "archive-overview",
                    "두 선수의 기록",
                    ScreenSectionTone.Milestone,
                    new[] { new ScreenRowViewModel("overview", "완주", "2명") }),
                new ScreenSectionViewModel(
                    "archive-life-2",
                    "2번째 선수 · 새봄",
                    ScreenSectionTone.Plain,
                    new[] { new ScreenRowViewModel("summary-2", "새봄", "푸른솔고", "10탈삼진") }),
                new ScreenSectionViewModel(
                    "archive-life-1",
                    "1번째 선수 · 해온",
                    ScreenSectionTone.Plain,
                    new[] { new ScreenRowViewModel("summary-1", "해온", "별빛고", "8탈삼진") }),
            };
            var viewModel = new BaseballScreenViewModel(
                ShellRoute.LifeArchive,
                "records",
                "기록",
                "보관함",
                "선수 기록 보관함",
                "완주한 회차를 고릅니다.",
                sections,
                Array.Empty<ScreenActionViewModel>());
            var navigator = new ArchiveNavigator("1");
            var host = new VisualElement();
            using var controller = new RecordsScreenController(ShellRoute.LifeArchive);

            controller.Mount(host, viewModel, navigator);

            ListView list = host.Q<ListView>("screen-lifearchive-archive-list");
            Assert.That(list, Is.Not.Null);
            Assert.That(list.virtualizationMethod, Is.EqualTo(CollectionVirtualizationMethod.DynamicHeight));
            Assert.That(host.Q<VisualElement>("screen-lifearchive-section-archive-life-1"), Is.Not.Null);
            Assert.That(host.Q<VisualElement>("screen-lifearchive-section-archive-life-2"), Is.Null,
                "선택하지 않은 회차의 긴 상세 행은 만들지 않아야 합니다.");
            Assert.That(navigator.VisibleLife, Is.Null,
                "패널에 붙지 않은 상세는 노출로 기록하면 안 됩니다.");

            string source = File.ReadAllText(
                "Assets/Game/Presentation/Records/RecordsScreenController.cs");
            StringAssert.Contains("CollectionVirtualizationMethod.DynamicHeight", source);
            StringAssert.DoesNotContain("fixedItemHeight =", source);
            StringAssert.Contains("TrackContentExposure", source);
            StringAssert.DoesNotContain("?.OnLifeArchiveVisible(visibleLife)", source);
            StringAssert.Contains("SetChoice(\"archive_life\"", source);
        }

        [Test]
        public void ReadyRoutingKeepsGuidedWelcomeOnOpeningButSkipsItForHoldout()
        {
            IKoreanUiCopyCatalog copy = KoreanUiCopyCatalog.LoadDefault();
            var guided = new RoutingRuntime();
            using (var controller = new BaseballShellController(
                new VisualElement(), guided, copy, ShellRoute.Opening))
            {
                guided.PublishReady(ShellRoute.Training, shouldHoldOpening: true);
                Assert.That(controller.CurrentRoute, Is.EqualTo(ShellRoute.Opening));
                Assert.That(guided.LastObservedRoute, Is.EqualTo(ShellRoute.Opening));
            }

            var holdout = new RoutingRuntime();
            using (var controller = new BaseballShellController(
                new VisualElement(), holdout, copy, ShellRoute.Opening))
            {
                holdout.PublishReady(ShellRoute.Training, shouldHoldOpening: false);
                Assert.That(controller.CurrentRoute, Is.EqualTo(ShellRoute.Training));
                Assert.That(holdout.LastObservedRoute, Is.EqualTo(ShellRoute.Training));
            }

            guided.PublishReady(ShellRoute.Relationship, shouldHoldOpening: true);
            holdout.PublishReady(ShellRoute.Relationship, shouldHoldOpening: false);
            Assert.That(BaseballShellController.ResolveInitialRoute(guided), Is.EqualTo(ShellRoute.Opening));
            Assert.That(BaseballShellController.ResolveInitialRoute(holdout), Is.EqualTo(ShellRoute.Relationship));
        }

        [Test]
        public void ReminderPlanIsProjectedFromSaveAndConsumedByShellNavigation()
        {
            string runtime = File.ReadAllText("Assets/Game/Presentation/Shell/ProductionBaseballShellRuntime.cs");
            string shell = File.ReadAllText("Assets/Game/Presentation/Shell/BaseballShellController.cs");
            string reminder = File.ReadAllText("Assets/Game/Platform/Notifications/AndroidReminderService.cs");
            StringAssert.Contains("reminders.ConfigurePlan", runtime);
            StringAssert.Contains("plan.CreatedDayKey", runtime);
            StringAssert.Contains("LastDailyInningDayKey", runtime);
            StringAssert.Contains("ReminderOpenAvailable += OnReminderOpenAvailable", runtime);
            StringAssert.Contains("DrainPendingReminderOpen", runtime);
            StringAssert.Contains("ConfirmReminderNavigation", runtime);
            StringAssert.Contains("IBaseballExternalNavigation", shell);
            StringAssert.Contains("TryConsumeExternalRoute", shell);
            StringAssert.Contains("TryPeekReminderOpen", reminder);
            StringAssert.DoesNotContain("AnalyticsBootstrap.Log", reminder);
            StringAssert.DoesNotContain("RepeatInterval", reminder);
            StringAssert.Contains("SmallIcon = SmallIconId", reminder);
        }

        [Test]
        public void PendingReminderDestinationWinsInitialRouteAndIsConsumedOnce()
        {
            var runtime = new RoutingRuntime();
            runtime.PublishReady(ShellRoute.Training, shouldHoldOpening: true);
            runtime.QueueExternalRoute(ShellRoute.Daily);

            ShellRoute initial = BaseballShellController.ResolveInitialRoute(runtime);
            Assert.That(initial, Is.EqualTo(ShellRoute.Daily));
            Assert.That(runtime.ExternalRouteConsumptionCount, Is.EqualTo(1));
            using (var controller = new BaseballShellController(
                new VisualElement(), runtime, KoreanUiCopyCatalog.LoadDefault(), initial))
            {
                Assert.That(controller.CurrentRoute, Is.EqualTo(ShellRoute.Daily));
                Assert.That(runtime.ExternalRouteAcknowledgementCount, Is.EqualTo(1));
            }
            Assert.That(BaseballShellController.ResolveInitialRoute(runtime), Is.EqualTo(ShellRoute.Opening));
            Assert.That(runtime.ExternalRouteConsumptionCount, Is.EqualTo(1));
        }

        private sealed class ArchiveNavigator : IShellNavigator, IBaseballCareerChoiceDraft,
            IBaseballLifeArchiveInteraction, IBaseballContentExposure
        {
            private string _selectedLife;

            public ArchiveNavigator(string selectedLife)
            {
                _selectedLife = selectedLife;
            }

            public ShellRoute CurrentRoute => ShellRoute.LifeArchive;
            public bool CanGoBack => true;
            public string VisibleLife { get; private set; }
            public void Navigate(ShellRoute route) { }
            public bool TryGoBack() => true;
            public void ShowConfirmation(ScreenActionViewModel action) { }
            public void Execute(ScreenActionViewModel action) { }
            public void Announce(string message) { }
            public string GetChoice(string group) => group == "archive_life" ? _selectedLife : string.Empty;
            public void SetChoice(string group, string payload)
            {
                if (group == "archive_life") _selectedLife = payload;
            }
            public IReadOnlyList<string> GetChoices(string group) => Array.Empty<string>();
            public void ToggleChoice(string group, string payload, int maximumSelections) { }
            public bool IsChoiceSelected(string group, string payload) => false;
            public void OnLifeArchiveVisible(string lifeNumber) => VisibleLife = lifeNumber;
            public void OnContentVisible(ShellRoute route, string contentId, string instanceId)
            {
                if (route == ShellRoute.LifeArchive &&
                    contentId.StartsWith("archive-life-", StringComparison.Ordinal))
                {
                    VisibleLife = contentId.Substring("archive-life-".Length);
                }
            }
        }

        private sealed class RoutingRuntime : IBaseballShellRuntime,
            IBaseballOpeningPresentationGate, IBaseballShellRouteObserver,
            IBaseballExternalNavigation
        {
            private ShellRoute? _externalRoute;
            public event Action Changed;
            public ShellRuntimeStatus Status { get; private set; } = ShellRuntimeStatus.Loading;
            public ShellRoute PreferredRoute { get; private set; } = ShellRoute.Opening;
            public bool ShouldHoldOpeningForReturnPlan { get; private set; }
            public bool IsBusy => false;
            public string StatusMessage => string.Empty;
            public IReadOnlyList<ShellRoute> Routes =>
                Array.AsReadOnly((ShellRoute[])Enum.GetValues(typeof(ShellRoute)));
            public ShellRoute? LastObservedRoute { get; private set; }
            public int ExternalRouteConsumptionCount { get; private set; }
            public int ExternalRouteAcknowledgementCount { get; private set; }

            public BaseballScreenViewModel Read(ShellRoute route) => new BaseballScreenViewModel(
                route,
                "routing-test",
                "테스트",
                "복귀",
                "저장된 화면",
                "실제 노출 경로를 확인합니다.",
                Array.Empty<ScreenSectionViewModel>(),
                Array.Empty<ScreenActionViewModel>(),
                showsBottomNavigation: false);

            public Task<ShellActionResult> ExecuteAsync(
                ShellRoute route,
                ScreenActionViewModel action,
                CancellationToken cancellationToken) =>
                Task.FromResult(ShellActionResult.Success());

            public void PublishReady(ShellRoute preferred, bool shouldHoldOpening)
            {
                PreferredRoute = preferred;
                ShouldHoldOpeningForReturnPlan = shouldHoldOpening;
                Status = ShellRuntimeStatus.Ready;
                LastObservedRoute = null;
                Changed?.Invoke();
            }

            public void OnRouteChanged(ShellRoute route, bool pitchStageLoaded) =>
                LastObservedRoute = route;
            public void QueueExternalRoute(ShellRoute route) => _externalRoute = route;
            public bool TryConsumeExternalRoute(out ShellRoute route)
            {
                if (_externalRoute.HasValue)
                {
                    route = _externalRoute.Value;
                    _externalRoute = null;
                    ExternalRouteConsumptionCount++;
                    return true;
                }
                route = default;
                return false;
            }
            public void AcknowledgeExternalRoute(ShellRoute renderedRoute) =>
                ExternalRouteAcknowledgementCount++;
            public void RetryStartup() { }
            public void Dispose() { }
        }
    }
}
