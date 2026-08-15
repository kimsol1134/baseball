using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;
using Baseball.Presentation.Common;
using Baseball.Presentation.Records;
using Baseball.Presentation.Shell;
using NUnit.Framework;
using UnityEditor;
using UnityEngine;
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
            StringAssert.Contains(".screen-scroll .unity-scroll-view__content-container > *", style);
            StringAssert.Contains(".screen-hero > *", style);
            StringAssert.Contains(".screen-control-stack > *", style);
            Assert.That(Regex.Matches(style, "flex-shrink: 0").Count, Is.GreaterThanOrEqualTo(3));
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
            StringAssert.DoesNotContain("Keyboard.current", host);
            StringAssert.Contains("ENABLE_LEGACY_INPUT_MANAGER", host);
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
            StringAssert.Contains(
                "settings.HapticsEnabled && !settings.ReducedMotionEnabled",
                File.ReadAllText("Assets/Game/Presentation/Shell/ProductionBaseballShellRuntime.cs"));
            StringAssert.DoesNotContain("sound.SetEnabled(false)", settings);
            StringAssert.DoesNotContain("music.SetEnabled(false)", settings);
            StringAssert.Contains("NotificationSettingsRequired", settings);
            StringAssert.Contains("OpenNotificationSettings", settings);
            StringAssert.Contains("Android 시스템의 글자 크기 설정을 자동으로 따릅니다", settings);
            StringAssert.DoesNotContain("AccessibleSlider", settings);
            StringAssert.DoesNotContain("ApplySystemFontScaleForTesting", settings);
            StringAssert.DoesNotContain("ApplySystemFontScaleForTesting", File.ReadAllText(
                "Assets/Game/Presentation/Shell/BaseballShellController.cs"));
        }

        [Test]
        public void LifeCardShareCapturesCardOnlyPngAndDoesNotClaimChooserCompletion()
        {
            string controller = File.ReadAllText("Assets/Game/Presentation/Shell/BaseballShellController.cs");
            string runtime = File.ReadAllText("Assets/Game/Presentation/Shell/ProductionBaseballShellRuntime.cs");
            string capture = File.ReadAllText("Assets/Game/Presentation/Records/ScreenLifeCardPngCapture.cs");
            string card = File.ReadAllText("Assets/Game/Presentation/Records/RecordsScreenController.cs");
            string style = File.ReadAllText("Assets/Game/Presentation/Records/Resources/RecordsScreen.uss");
            StringAssert.Contains("life-card-capture", controller);
            StringAssert.Contains("CaptureScreenshotAsTexture", capture);
            StringAssert.Contains("FullCardCaptureSession", capture);
            StringAssert.Contains("LifeCardCaptureGeometry.NextPixelTop", capture);
            StringAssert.Contains("LifeCardCaptureGeometry.TryPlanOutput", capture);
            StringAssert.Contains("SystemInfo.maxTextureSize", capture);
            StringAssert.Contains("LifeCardCaptureGeometry.CanUseColor32Buffer", capture);
            StringAssert.Contains("GetPixels32", capture);
            StringAssert.Contains("SetPixels32", capture);
            StringAssert.Contains("RunScheduled", capture);
            StringAssert.Contains("Finish(null)", capture);
            StringAssert.Contains("_scroll.verticalScroller.value = _originalScroll", capture);
            StringAssert.DoesNotContain("CaptureVisibleCard", capture);
            StringAssert.Contains("EncodeToPNG", capture);
            StringAssert.Contains("foreach (ScreenSectionViewModel section in viewModel.Sections)", card);
            StringAssert.DoesNotContain("string[] rowIds", card);
            StringAssert.Contains("life-card-capture__row--narrative", card);
            StringAssert.Contains(".baseball-font-scale-200 .life-card-capture__row", style);
            StringAssert.Contains("TrySharePng", runtime);
            StringAssert.Contains("TryShareText", runtime);
            StringAssert.DoesNotContain("AnalyticsEvent.LifeCardShareCompleted", runtime);
            StringAssert.DoesNotContain("AnalyticsEvent.LifeCardShared", runtime);
        }

        [Test]
        public void LifeCardCaptureFailureFallsBackToTextAndNeverLeavesShellDisabled()
        {
            var runtime = new RoutingRuntime();
            runtime.EnableLifeCardShare();
            runtime.PublishReady(ShellRoute.LifeCard, shouldHoldOpening: false);
            var capture = new ThrowingLifeCardCapture();
            var root = new VisualElement();
            using var controller = new BaseballShellController(
                root,
                runtime,
                KoreanUiCopyCatalog.LoadDefault(),
                ShellRoute.LifeCard,
                lifeCardPngCapture: capture);
            ScreenActionViewModel share = runtime.Read(ShellRoute.LifeCard).Actions.Single();

            Assert.That(root.Q<VisualElement>(className: "life-card-capture"), Is.Not.Null,
                "the production LifeCard controller must mount a capturable full-card surface");
            controller.Execute(share);

            Assert.That(capture.Attempts, Is.EqualTo(1));
            Assert.That(runtime.LifeCardShareAttempts, Is.EqualTo(1));
            Assert.That(runtime.LastLifeCardShareHadPng, Is.False);
            Assert.That(root.Q<VisualElement>("shell-root").enabledInHierarchy, Is.True);

            controller.Execute(share);

            Assert.That(capture.Attempts, Is.EqualTo(2),
                "a failed initialization must not latch the action-in-flight guard");
            Assert.That(runtime.LifeCardShareAttempts, Is.EqualTo(2));
            Assert.That(root.Q<VisualElement>("shell-root").enabledInHierarchy, Is.True);
        }

        [Test]
        public void StartupRetryActionAwaitsSerializedAppRootCoordinatorBridge()
        {
            string runtime = File.ReadAllText(
                "Assets/Game/Presentation/Shell/ProductionBaseballShellRuntime.cs");
            string appRoot = File.ReadAllText("Assets/Game/Bootstrap/AppRoot.cs");
            string bootstrap = File.ReadAllText("Assets/Game/Bootstrap/BootstrapConfiguration.cs");
            string composition = File.ReadAllText("Assets/Game/Bootstrap/RuntimeGameComposition.cs");
            string action = Slice(
                runtime,
                "if (action.Id == \"runtime_retry\")",
                "if (action.Id.StartsWith");
            string retry = Slice(
                runtime,
                "private async Task<ShellActionResult> RetryStartupAsync",
                "public void SetPlayerName");

            StringAssert.Contains("await RetryStartupAsync(cancellationToken)", action);
            StringAssert.Contains("await AppRoot.RetryInitializationAsync(cancellationToken)", retry);
            StringAssert.Contains("RuntimeGameServices.TryGetStore", retry);
            StringAssert.Contains("_status = ShellRuntimeStatus.Loading", retry);
            StringAssert.Contains("_lifecycleGate.WaitAsync", appRoot);
            StringAssert.Contains("coordinator.InitializeAsync(linked.Token)", appRoot);
            StringAssert.DoesNotContain("AnonymousInstallIdentity.GetOrCreate", bootstrap);
            StringAssert.Contains("AnonymousInstallIdentity.GetOrCreate", composition);
            StringAssert.Contains("string resolvedInstallId = _installIdResolver()", composition);
            StringAssert.DoesNotContain("잠시 후 한 번 더 눌러", retry);
        }

        [Test]
        public void AddressableChoiceArtworkLoadsLocallyDisposesLeaseAndPreservesSelection()
        {
            var texture = new Texture2D(2, 2);
            Sprite sprite = Sprite.Create(texture, new Rect(0, 0, 2, 2), Vector2.zero);
            var loader = new ImmediateVisualLoader(sprite);
            int selected = 0;
            var card = new ChoiceCard(
                "서울",
                "스카우트가 자주 오는 무대",
                "screen-test-region",
                () => selected++);
            VisualElement wrapper = AddressableContentImage.WrapChoice(
                card,
                BaseballVisualContentCatalog.SetupRegion("서울"),
                "서울 지역 야구 분위기 삽화",
                "screen-test-region-art",
                loader);

            Assert.That(loader.LastAddress, Is.EqualTo("baseball/meta/SceneArt-media"));
            Assert.That(wrapper.Q<Image>("screen-test-region-art-art-image").sprite, Is.SameAs(sprite));
            Assert.That(BaseballAccessibility.TryGet(card, out BaseballAccessibilityMetadata metadata), Is.True);
            Assert.That(metadata.Invoke(), Is.True);
            Assert.That(selected, Is.EqualTo(1), "art loading must never replace the choice payload callback");

            ((AddressableContentImage)wrapper[0]).Dispose();
            Assert.That(loader.LeaseDisposed, Is.True);
            UnityEngine.Object.DestroyImmediate(sprite);
            UnityEngine.Object.DestroyImmediate(texture);
        }

        [Test]
        public void MissingArtworkShowsExplicitFallbackWithoutDisablingChoice()
        {
            int selected = 0;
            var card = new ChoiceCard("대표 유산", "저장된 효과", "screen-test-legacy", () => selected++);
            VisualElement wrapper = AddressableContentImage.WrapChoice(
                card,
                "baseball/meta/MemoryArt-missing",
                "대표 유산 삽화",
                "screen-test-legacy-art",
                loader: null);

            Label fallback = wrapper.Q<Label>("screen-test-legacy-art-art-fallback");
            Assert.That(fallback.text, Does.Contain("선택과 저장 상태는 그대로 유지"));
            Assert.That(card.enabledSelf, Is.True);
            Assert.That(BaseballAccessibility.TryGet(card, out BaseballAccessibilityMetadata metadata), Is.True);
            Assert.That(metadata.Invoke(), Is.True);
            Assert.That(selected, Is.EqualTo(1));
        }

        [Test]
        public void ProductScreensCallImportedChoiceAndNarrativeArtworkLoaders()
        {
            string setup = File.ReadAllText("Assets/Game/Presentation/Setup/SetupScreenController.cs");
            string choices = File.ReadAllText("Assets/Game/Presentation/Common/CareerChoiceGroupView.cs");
            string highSchool = File.ReadAllText("Assets/Game/Presentation/HighSchool/HighSchoolScreenController.cs");
            string image = File.ReadAllText("Assets/Game/Presentation/Common/AddressableContentImage.cs");
            StringAssert.Contains("BaseballVisualContentCatalog.SetupRegion", setup);
            StringAssert.Contains("BaseballVisualContentCatalog.SetupPreset", setup);
            StringAssert.Contains("BaseballVisualContentCatalog.Memory", setup);
            StringAssert.Contains("option.ArtworkAddress", choices);
            StringAssert.Contains("RelationshipArtwork", highSchool);
            StringAssert.Contains("TournamentBanner", highSchool);
            StringAssert.Contains("ImportantGameScene", highSchool);
            StringAssert.Contains("lease?.Dispose()", image);
            StringAssert.Contains("RegisterCallback<DetachFromPanelEvent>", image);
            StringAssert.Contains("선택과 저장 상태는 그대로 유지", image);
        }

        [Test]
        public void SaveResetPublishesAnonymousIdentityOnlyAfterDurableReset()
        {
            string runtime = File.ReadAllText("Assets/Game/Presentation/Shell/ProductionBaseballShellRuntime.cs");
            int prepare = runtime.IndexOf("AnonymousInstallIdentity.PrepareReset(", System.StringComparison.Ordinal);
            int reset = runtime.IndexOf("await _store.ResetWithPreparedIdentityAsync(", System.StringComparison.Ordinal);
            int replace = runtime.IndexOf("AnonymousInstallIdentity.PublishPreparedReset(installId)", System.StringComparison.Ordinal);
            Assert.That(prepare, Is.GreaterThanOrEqualTo(0));
            Assert.That(reset, Is.GreaterThan(prepare));
            Assert.That(reset, Is.GreaterThanOrEqualTo(0));
            Assert.That(replace, Is.GreaterThan(reset));
            StringAssert.Contains("InstallResetStep.RepositoryReset", runtime);
            StringAssert.Contains("AnonymousInstallIdentity.TryCompletePreparedReset()", runtime);
            StringAssert.Contains("GameResetException", runtime);
            StringAssert.Contains("초기화 요청을 안전하게 기록했습니다", runtime);
            StringAssert.Contains("ResetIdentityAndOnceFlags", runtime);
            StringAssert.Contains("ResetLocalState", runtime);
            StringAssert.Contains("TryClearShareCache", runtime);
            StringAssert.DoesNotContain("CancelPreparedResetAfterRollback", runtime);
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
            StringAssert.Contains("recommendationAccepted: commit.Result.Snapshot.RecommendationAccepted", persistence);
            StringAssert.Contains("PitchSessionPostgameSnapshot ReadPostgame", persistence);
            StringAssert.Contains("ShowPostgameSummary", coordinator);
            string terminal = Slice(coordinator,
                "private void ApplyConsumedState(",
                "private void ShowTutorialDecision()");
            StringAssert.Contains("_hud?.ShowPostgameSummary(postgame)", terminal);
            StringAssert.DoesNotContain("PersistSessionCompletion();", terminal);
            string hud = File.ReadAllText("Assets/Game/Presentation/Pitch/Runtime/PitchHudController.cs");
            StringAssert.Contains("pitch-postgame-log-", hud);
            StringAssert.Contains("결과 저장/계속", hud);
            StringAssert.Contains("release.clicked +=", hud);
            StringAssert.Contains("_presenter.SubmitNeutralRelease()", hud);
            StringAssert.Contains("bool motionFocus = state.Phase == PitchPlayPhase.Presenting", hud);
            StringAssert.Contains("_topCard.style.display = showDecisionContext", hud);
            StringAssert.Contains("_contextPanel.style.display = showDecisionContext", hud);
            StringAssert.Contains("_presentingPanel.style.display = DisplayStyle.None", hud);
            StringAssert.Contains("SetAccessibilityActive(_presentingPanel, false)", hud);
            StringAssert.DoesNotContain("PitchDemoRequestFactory", coordinator);
            StringAssert.DoesNotContain("PitchDemoRequestFactory", persistence);
            Assert.That(File.Exists("Assets/Game/Presentation/Pitch/Model/PitchDemoRequestFactory.cs"), Is.False);
            Assert.That(File.Exists("Assets/Tests/EditMode/Presentation/PitchDemoRequestFactory.cs"), Is.True);
        }

        [Test]
        public void PitchBackSuspendsExactResumeWhileExplicitAbandonRemainsDestructive()
        {
            string hud = File.ReadAllText(
                "Assets/Game/Presentation/Pitch/Runtime/PitchHudController.cs");
            string coordinator = File.ReadAllText(
                "Assets/Game/Presentation/Pitch/Runtime/PitchShellFlowCoordinator.cs");
            string persistence = File.ReadAllText(
                "Assets/Game/Presentation/Shell/ProductionPitchSessionPersistence.cs");
            string uxml = File.ReadAllText(
                "Assets/Game/Presentation/Pitch/Resources/PitchPlay.uxml");

            string exitConfirmation = Slice(hud,
                "private void ShowExitConfirmation()",
                "private void CloseExitConfirmation()");
            StringAssert.Contains("SuspendRequested?.Invoke()", exitConfirmation);
            StringAssert.DoesNotContain("AbortRequested?.Invoke()", exitConfirmation);
            StringAssert.Contains("pitch-abandon-inning", hud);
            StringAssert.Contains("pitch-abandon-confirmation", hud);
            StringAssert.Contains("pitch-abandon-slot", uxml);

            string suspend = Slice(coordinator,
                "private async void Suspend()",
                "private void DetachPresenter()");
            StringAssert.Contains("await _persistence.SuspendAsync", suspend);
            StringAssert.DoesNotContain("AbandonAsync", suspend);
            StringAssert.DoesNotContain("_presenter?.Abort()", suspend);
            StringAssert.Contains("_hud?.SetExitStatus(false", suspend);
            StringAssert.Contains("if (!_shell.TryGoBack()) _shell.CompletePitchHandoff();", suspend);

            string abandon = Slice(coordinator,
                "private async void Abort()",
                "private async void Suspend()");
            int durableAbandon = abandon.IndexOf("await _persistence.AbandonAsync", StringComparison.Ordinal);
            int presenterAbort = abandon.IndexOf("_presenter?.Abort()", StringComparison.Ordinal);
            Assert.That(durableAbandon, Is.GreaterThanOrEqualTo(0));
            Assert.That(presenterAbort, Is.GreaterThan(durableAbandon));

            string suspendPersistence = Slice(persistence,
                "public Task<ShellActionResult> SuspendAsync",
                "private async Task<ShellActionResult> DispatchPitchAsync");
            StringAssert.Contains("new SuspendPitchSessionCommand(gameId)", suspendPersistence);
            StringAssert.DoesNotContain("GameAbandoned", suspendPersistence);
        }

        [Test]
        public void RecoveredCompletionFailureRestoresShellAndKeepsExplicitRetryAndBackPaths()
        {
            string coordinator = File.ReadAllText(
                "Assets/Game/Presentation/Pitch/Runtime/PitchShellFlowCoordinator.cs");
            string model = File.ReadAllText(
                "Assets/Game/Presentation/Shell/StoreBaseballCareerReadModel.cs");
            string shell = File.ReadAllText(
                "Assets/Game/Presentation/Shell/BaseballShellController.cs");
            int method = coordinator.IndexOf(
                "private async void FinishRecoveredSession", StringComparison.Ordinal);
            int complete = coordinator.IndexOf("private async void Complete()", method, StringComparison.Ordinal);
            string recovery = coordinator.Substring(method, complete - method);

            StringAssert.Contains("if (!completed.Succeeded)", recovery);
            Assert.That(recovery.Split(new[] { "CloseActive();" }, StringSplitOptions.None).Length - 1,
                Is.GreaterThanOrEqualTo(3),
                "missing report, save failure, exception, and success paths must all restore the shell");
            StringAssert.Contains("_recoveredCompletionActive", coordinator);
            StringAssert.Contains("저장된 결과 다시 완료", model);
            StringAssert.Contains("나중에 다시 시도", model);
            StringAssert.Contains("ResumePitchIfNeeded();", shell);
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
            StringAssert.Contains("CareerAnalyticsEligibility.IsFirstPitchCompletion(completedKind, before)", persistence);
            StringAssert.Contains("completedKind != PitchCareerKind.Tutorial && countsPitchEvent", persistence);
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
        public void ProWeekHasNoNoOpSegmentedAffordance()
        {
            string controller = File.ReadAllText(
                "Assets/Game/Presentation/Pro/ProScreenController.cs");
            StringAssert.DoesNotContain("new SegmentedChoice", controller);
            StringAssert.DoesNotContain("_ => { }", controller);
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
        public void RecordsWeeklyActionReachesBoardAndDispatchesClaimThroughRuntime()
        {
            var runtime = new RoutingRuntime();
            runtime.EnableWeeklyBoardActions();
            runtime.PublishReady(ShellRoute.Records, shouldHoldOpening: false);
            using var controller = new BaseballShellController(
                new VisualElement(),
                runtime,
                KoreanUiCopyCatalog.LoadDefault(),
                ShellRoute.Records);

            ScreenActionViewModel open = runtime.Read(ShellRoute.Records).Actions.Single();
            controller.Execute(open);

            Assert.That(runtime.LastExecutedActionId, Is.EqualTo("navigate_weekly"));
            Assert.That(controller.CurrentRoute, Is.EqualTo(ShellRoute.Weekly));

            ScreenActionViewModel claim = runtime.Read(ShellRoute.Weekly).Actions.Single();
            controller.Execute(claim);

            Assert.That(runtime.LastExecutedActionId, Is.EqualTo("claim_weekly"));
            Assert.That(runtime.ExecutedActionCount, Is.EqualTo(2));
            Assert.That(controller.CurrentRoute, Is.EqualTo(ShellRoute.Weekly));
        }

        [Test]
        public void RootHardwareBackRequiresASecondPressInsideTheExitWindow()
        {
            var runtime = new RoutingRuntime();
            runtime.PublishReady(ShellRoute.Opening, shouldHoldOpening: false);
            var exit = new ExitBoundary();
            DateTimeOffset now = new DateTimeOffset(2026, 8, 12, 4, 0, 0, TimeSpan.Zero);
            using var controller = new BaseballShellController(
                new VisualElement(),
                runtime,
                KoreanUiCopyCatalog.LoadDefault(),
                ShellRoute.Opening,
                applicationExit: exit,
                now: () => now);

            controller.HandleHardwareBack();
            Assert.That(exit.Count, Is.Zero);
            now = now.AddSeconds(1);
            controller.HandleHardwareBack();
            Assert.That(exit.Count, Is.EqualTo(1));

            controller.HandleHardwareBack();
            now = now.AddSeconds(3);
            controller.HandleHardwareBack();
            Assert.That(exit.Count, Is.EqualTo(1), "an expired first press must only re-arm the prompt");
        }

        [Test]
        public void SavedAuthoritativeTransitionPrunesHistoryAndDraftNavigationRequiresDiscard()
        {
            var runtime = new RoutingRuntime();
            runtime.PublishReady(ShellRoute.Setup, shouldHoldOpening: false);
            using var controller = new BaseballShellController(
                new VisualElement(), runtime, KoreanUiCopyCatalog.LoadDefault(), ShellRoute.Setup);

            controller.SetPlayerName("해온");
            controller.Navigate(ShellRoute.Training);
            Assert.That(controller.CurrentRoute, Is.EqualTo(ShellRoute.Setup));
            VisualElement confirm = controllerRoot(controller).Q<VisualElement>("shell-discard-draft");
            Assert.That(confirm, Is.Not.Null);
            VisualElement confirmButton = confirm.Q<VisualElement>("shell-discard-draft-confirm");
            Assert.That(BaseballAccessibility.TryGet(confirmButton, out BaseballAccessibilityMetadata metadata), Is.True);
            Assert.That(metadata.Invoke(), Is.True);
            Assert.That(runtime.DiscardCount, Is.EqualTo(1));
            Assert.That(controller.CurrentRoute, Is.EqualTo(ShellRoute.Training));

            runtime.AuthoritativeDestination = ShellRoute.Relationship;
            controller.Execute(new ScreenActionViewModel(
                "advance_phase",
                "다음 단계",
                ShellRoute.Relationship,
                ScreenActionStyle.Primary));
            Assert.That(controller.CurrentRoute, Is.EqualTo(ShellRoute.Relationship));
            Assert.That(controller.CanGoBack, Is.False,
                "a saved phase transition must not render its irreversible predecessor on Back");
        }

        [Test]
        public void ArchiveLifeExpansionIsViewStateAndNeverTriggersDraftDiscardConfirmation()
        {
            var runtime = new RoutingRuntime();
            runtime.PublishReady(ShellRoute.LifeArchive, shouldHoldOpening: false);
            using var controller = new BaseballShellController(
                new VisualElement(), runtime, KoreanUiCopyCatalog.LoadDefault(), ShellRoute.LifeArchive);

            controller.SetChoice("archive_life", "2");
            controller.Navigate(ShellRoute.Records);

            Assert.That(runtime.SelectedArchiveLife, Is.EqualTo("2"));
            Assert.That(controller.CurrentRoute, Is.EqualTo(ShellRoute.Records));
            Assert.That(controllerRoot(controller).Q<VisualElement>("shell-discard-draft"), Is.Null);
            Assert.That(runtime.DiscardCount, Is.Zero);
        }

        private static VisualElement controllerRoot(BaseballShellController controller)
        {
            var field = typeof(BaseballShellController).GetField(
                "_documentRoot",
                System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic);
            return (VisualElement)field.GetValue(controller);
        }

        [Test]
        public void ReminderPlanIsProjectedFromSaveAndConsumedByShellNavigation()
        {
            string runtime = File.ReadAllText("Assets/Game/Presentation/Shell/ProductionBaseballShellRuntime.cs");
            string shell = File.ReadAllText("Assets/Game/Presentation/Shell/BaseballShellController.cs");
            string reminder = File.ReadAllText("Assets/Game/Platform/Notifications/AndroidReminderService.cs");
            StringAssert.Contains("reminders.ConfigurePlan", runtime);
            StringAssert.Contains("reminders.BindInstall(state?.InstallId)", runtime);
            StringAssert.Contains("personalized.SavedDayKey", runtime);
            StringAssert.DoesNotContain("LastDailyInningDayKey", runtime);
            StringAssert.Contains("ReminderOpenAvailable += OnReminderOpenAvailable", runtime);
            StringAssert.Contains("DrainPendingReminderOpen", runtime);
            StringAssert.Contains("ConfirmReminderNavigation", runtime);
            StringAssert.Contains("IBaseballExternalNavigation", shell);
            StringAssert.Contains("TryConsumeExternalRoute", shell);
            StringAssert.Contains("TryPeekReminderOpen", reminder);
            StringAssert.DoesNotContain("AnonymousInstallIdentity.GetOrCreate()", reminder);
            StringAssert.DoesNotContain("AnalyticsBootstrap.Log", reminder);
            StringAssert.DoesNotContain("RepeatInterval", reminder);
            StringAssert.Contains("SmallIcon = SmallIconId", reminder);
        }

        [Test]
        public void RetiredDailyRouteHasNoMetaNavigationEntryPoint()
        {
            string meta = File.ReadAllText(
                "Assets/Game/Presentation/Meta/MetaScreenController.cs");
            string shell = File.ReadAllText(
                "Assets/Game/Presentation/Shell/BaseballShellController.cs");
            string template = File.ReadAllText(
                "Assets/Game/Presentation/Shell/BaseballScreenTemplateReadModel.cs");
            string model = File.ReadAllText(
                "Assets/Game/Presentation/Shell/StoreBaseballCareerReadModel.cs");
            string factory = File.ReadAllText(
                "Assets/Game/Presentation/Shell/BaseballScreenControllerFactory.cs");
            string pitch = File.ReadAllText(
                "Assets/Game/Presentation/Shell/ProductionPitchSessionPersistence.cs");
            string copy = File.ReadAllText(
                "Assets/Game/Content/ko-KR/Resources/ui-copy-ko-KR.json");
            StringAssert.DoesNotContain("screen-meta-daily", meta);
            StringAssert.DoesNotContain("ShellRoute.Daily", meta);
            StringAssert.Contains("NormalizeRetiredDailyRoute", shell);
            StringAssert.DoesNotContain("screens.Add(ShellRoute.Daily", template);
            StringAssert.DoesNotContain("case ShellRoute.Daily:", model);
            StringAssert.DoesNotContain("case ShellRoute.Daily:", factory);
            StringAssert.DoesNotContain("PitchCareerKind.Daily", pitch);
            StringAssert.DoesNotContain("DailyScore", pitch);
            StringAssert.DoesNotContain("Meta?.Daily", pitch);
            StringAssert.DoesNotContain("\"daily.", copy);
            StringAssert.DoesNotContain("일일 도전", copy);
            string runtime = File.ReadAllText(
                "Assets/Game/Presentation/Shell/ProductionBaseballShellRuntime.cs");
            StringAssert.Contains("ClearRetiredDailyResume", runtime);
            StringAssert.Contains("new AbandonPitchSessionCommand(resume.GameId)", runtime);
            StringAssert.DoesNotContain("begin_daily_pitch", runtime);
        }

        [Test]
        public void PendingReminderDestinationWinsInitialRouteAndIsConsumedOnce()
        {
            var runtime = new RoutingRuntime();
            runtime.PublishReady(ShellRoute.Training, shouldHoldOpening: true);
            runtime.QueueExternalRoute(ShellRoute.Daily);

            ShellRoute initial = BaseballShellController.ResolveInitialRoute(runtime);
            Assert.That(initial, Is.EqualTo(ShellRoute.Training));
            Assert.That(runtime.ExternalRouteConsumptionCount, Is.EqualTo(1));
            using (var controller = new BaseballShellController(
                new VisualElement(), runtime, KoreanUiCopyCatalog.LoadDefault(), initial))
            {
                Assert.That(controller.CurrentRoute, Is.EqualTo(ShellRoute.Training));
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
            public Task<bool> OnContentVisibleAsync(
                ShellRoute route,
                string contentId,
                string instanceId,
                CancellationToken cancellationToken)
            {
                if (route == ShellRoute.LifeArchive &&
                    contentId.StartsWith("archive-life-", StringComparison.Ordinal))
                {
                    VisibleLife = contentId.Substring("archive-life-".Length);
                }
                return Task.FromResult(true);
            }
        }

        private sealed class RoutingRuntime : IBaseballShellRuntime,
            IBaseballOpeningPresentationGate, IBaseballShellRouteObserver,
            IBaseballExternalNavigation, IBaseballRetiredDailyRouteFallback,
            IBaseballTransientDraftDiscard, IBaseballCareerChoiceDraft,
            IBaseballLifeCardShareRuntime
        {
            private ShellRoute? _externalRoute;
            private bool _weeklyBoardActions;
            private bool _lifeCardShareAction;
            public event Action Changed;
            public ShellRuntimeStatus Status { get; private set; } = ShellRuntimeStatus.Loading;
            public ShellRoute PreferredRoute { get; private set; } = ShellRoute.Opening;
            public ShellRoute RetiredDailyFallbackRoute =>
                PreferredRoute == ShellRoute.Daily || PreferredRoute == ShellRoute.PitchHandoff
                    ? ShellRoute.Opening
                    : PreferredRoute;
            public bool ShouldHoldOpeningForReturnPlan { get; private set; }
            public bool IsBusy => false;
            public string StatusMessage => string.Empty;
            public IReadOnlyList<ShellRoute> Routes =>
                Array.AsReadOnly((ShellRoute[])Enum.GetValues(typeof(ShellRoute)));
            public ShellRoute? LastObservedRoute { get; private set; }
            public int ExternalRouteConsumptionCount { get; private set; }
            public int ExternalRouteAcknowledgementCount { get; private set; }
            public int ExecutedActionCount { get; private set; }
            public string LastExecutedActionId { get; private set; }
            public ShellRoute? AuthoritativeDestination { get; set; }
            public int DiscardCount { get; private set; }
            public string SelectedArchiveLife { get; private set; }
            public int LifeCardShareAttempts { get; private set; }
            public bool LastLifeCardShareHadPng { get; private set; }

            public BaseballScreenViewModel Read(ShellRoute route)
            {
                IReadOnlyList<ScreenActionViewModel> actions = Array.Empty<ScreenActionViewModel>();
                if (_weeklyBoardActions && route == ShellRoute.Records)
                    actions = new[]
                    {
                        new ScreenActionViewModel(
                            "navigate_weekly",
                            "주간 야구 노트",
                            ShellRoute.Weekly,
                            ScreenActionStyle.Secondary)
                    };
                else if (_weeklyBoardActions && route == ShellRoute.Weekly)
                    actions = new[]
                    {
                        new ScreenActionViewModel(
                            "claim_weekly",
                            "주간 보상 받기",
                            ShellRoute.Weekly,
                            ScreenActionStyle.Secondary)
                    };
                else if (_lifeCardShareAction && route == ShellRoute.LifeCard)
                    actions = new[]
                    {
                        new ScreenActionViewModel(
                            "share_life_card",
                            "라이프 카드 공유",
                            ShellRoute.LifeCard,
                            ScreenActionStyle.Secondary)
                    };
                IReadOnlyList<ScreenSectionViewModel> sections =
                    _lifeCardShareAction && route == ShellRoute.LifeCard
                        ? new[]
                        {
                            new ScreenSectionViewModel(
                                "life-card-test",
                                "선수 기록",
                                ScreenSectionTone.Information,
                                new[]
                                {
                                    new ScreenRowViewModel(
                                        "life-card-player",
                                        "선수",
                                        "해온")
                                })
                        }
                        : Array.Empty<ScreenSectionViewModel>();
                return new BaseballScreenViewModel(
                    route,
                    "routing-test",
                    "테스트",
                    "복귀",
                    "저장된 화면",
                    "실제 노출 경로를 확인합니다.",
                    sections,
                    actions,
                    showsBottomNavigation: false);
            }

            public Task<ShellActionResult> ExecuteAsync(
                ShellRoute route,
                ScreenActionViewModel action,
                CancellationToken cancellationToken)
            {
                ExecutedActionCount++;
                LastExecutedActionId = action?.Id;
                if (AuthoritativeDestination.HasValue)
                    PreferredRoute = AuthoritativeDestination.Value;
                return Task.FromResult(ShellActionResult.Success(action?.Target));
            }

            public void EnableWeeklyBoardActions() => _weeklyBoardActions = true;
            public void EnableLifeCardShare() => _lifeCardShareAction = true;

            public Task<ShellActionResult> ShareLifeCardAsync(
                byte[] pngBytes,
                CancellationToken cancellationToken)
            {
                cancellationToken.ThrowIfCancellationRequested();
                LifeCardShareAttempts++;
                LastLifeCardShareHadPng = pngBytes != null;
                return Task.FromResult(ShellActionResult.Success(
                    null,
                    pngBytes == null ? "텍스트 공유" : "이미지 공유"));
            }

            public void PublishReady(ShellRoute preferred, bool shouldHoldOpening)
            {
                PreferredRoute = preferred;
                ShouldHoldOpeningForReturnPlan = shouldHoldOpening;
                Status = ShellRuntimeStatus.Ready;
                LastObservedRoute = null;
                Changed?.Invoke();
            }

            public void OnRouteChanged(ShellRoute route) =>
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
            public void DiscardTransientDraft(ShellRoute route) => DiscardCount++;
            public string GetChoice(string group) =>
                group == "archive_life" ? SelectedArchiveLife ?? string.Empty : string.Empty;
            public void SetChoice(string group, string payload)
            {
                if (group == "archive_life") SelectedArchiveLife = payload;
            }
            public IReadOnlyList<string> GetChoices(string group) => Array.Empty<string>();
            public void ToggleChoice(string group, string payload, int maximumSelections) { }
            public bool IsChoiceSelected(string group, string payload) => false;
            public void RetryStartup() { }
            public void Dispose() { }
        }

        private static string Slice(string source, string start, string end)
        {
            int startIndex = source.IndexOf(start, StringComparison.Ordinal);
            Assert.That(startIndex, Is.GreaterThanOrEqualTo(0), start);
            int endIndex = source.IndexOf(end, startIndex + start.Length, StringComparison.Ordinal);
            Assert.That(endIndex, Is.GreaterThan(startIndex), end);
            return source.Substring(startIndex, endIndex - startIndex);
        }

        private sealed class ExitBoundary : IBaseballApplicationExit
        {
            public int Count { get; private set; }
            public void ExitApplication() => Count++;
        }

        private sealed class ThrowingLifeCardCapture : IBaseballLifeCardPngCapture
        {
            public int Attempts { get; private set; }

            public Task<byte[]> CaptureAsync(
                VisualElement card,
                CancellationToken cancellationToken)
            {
                Attempts++;
                throw new InvalidOperationException("simulated Texture2D allocation failure");
            }
        }

        private sealed class ImmediateVisualLoader : IBaseballVisualAssetLoader
        {
            private readonly Sprite _sprite;

            public ImmediateVisualLoader(Sprite sprite)
            {
                _sprite = sprite;
            }

            public string LastAddress { get; private set; }
            public bool LeaseDisposed { get; private set; }

            public Task<IBaseballVisualAssetLease> LoadSpriteAsync(
                string address,
                CancellationToken cancellationToken)
            {
                cancellationToken.ThrowIfCancellationRequested();
                LastAddress = address;
                return Task.FromResult<IBaseballVisualAssetLease>(new ImmediateVisualLease(
                    _sprite,
                    () => LeaseDisposed = true));
            }
        }

        private sealed class ImmediateVisualLease : IBaseballVisualAssetLease
        {
            private readonly Action _dispose;

            public ImmediateVisualLease(Sprite sprite, Action dispose)
            {
                Sprite = sprite;
                _dispose = dispose;
            }

            public Sprite Sprite { get; }
            public void Dispose() => _dispose();
        }
    }
}
