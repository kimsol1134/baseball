using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using Baseball.Platform.Analytics;
using NUnit.Framework;

namespace Baseball.Presentation.Tests.Screens
{
    public sealed class ProductionAnalyticsSourceContractTests
    {
        [Test]
        public void EveryProductEventHasAProductionCallerExceptChooserCompletionExceptions()
        {
            string source = ProductionSource();
            foreach (AnalyticsEvent analyticsEvent in Enum.GetValues(typeof(AnalyticsEvent)))
            {
                bool intentionalZeroCaller = analyticsEvent == AnalyticsEvent.LifeCardShared ||
                    analyticsEvent == AnalyticsEvent.LifeCardShareCompleted ||
                    analyticsEvent == AnalyticsEvent.DailyInningOpened ||
                    analyticsEvent == AnalyticsEvent.DailyInningRewarded;
                int references = Count(source, "AnalyticsEvent." + analyticsEvent);
                Assert.That(
                    references,
                    intentionalZeroCaller ? Is.Zero : Is.GreaterThan(0),
                    analyticsEvent.ToString());
            }
        }

        [Test]
        public void CommandAndPitchEventsUseEventSpecificPropertiesAndExactDurableTriggers()
        {
            string receipts = Read("apps/android-unity/Assets/Game/Presentation/Shell/ProductionAnalyticsReceipts.cs");
            string pitch = Read("apps/android-unity/Assets/Game/Presentation/Shell/ProductionPitchSessionPersistence.cs");
            string runtime = ProductionRuntimeSource();

            Assert.That(receipts, Does.Not.Contain("repeatedEvent"));
            Assert.That(receipts, Does.Not.Contain("[\"action\"]"));
            Assert.That(receipts, Does.Not.Contain("[\"status\"]"));
            Assert.That(receipts, Does.Contain("case \"start_high_school\":"));
            Assert.That(receipts, Does.Contain("after?.HighSchool?.IsChallengeRun == true"));
            Assert.That(receipts, Does.Contain("case \"sign_pro_contract\":"));
            Assert.That(receipts, Does.Not.Contain("case \"enter_pro\":\n                case \"start_direct_pro\":"));
            Assert.That(receipts, Does.Contain("[\"focus_id\"]"));
            Assert.That(receipts, Does.Contain("[\"intensity_id\"]"));
            Assert.That(receipts, Does.Contain("case \"train_block\":"));
            Assert.That(receipts, Does.Contain("LastTrainingBlock?.Sessions"));
            Assert.That(receipts, Does.Contain("\"training-\" + training.Number"));
            Assert.That(receipts, Does.Contain("training.TargetPitch"));
            Assert.That(receipts, Does.Contain("[\"pledge_id\"]"));
            Assert.That(receipts, Does.Contain("RunPledgeAnalyticsPolicy.WasRecommended"));
            Assert.That(receipts, Does.Contain("[\"recommended\"] = recommended"));
            Assert.That(receipts, Does.Not.Contain("[\"recommended\"] = pledge?.Carried"));
            Assert.That(receipts, Does.Contain("[\"option_ids\"]"));
            Assert.That(receipts, Does.Contain("[\"trainings\"]"));
            Assert.That(receipts, Does.Contain("\"season-\" + Math.Max"));
            Assert.That(receipts, Does.Contain("decisionId);"));
            Assert.That(receipts, Does.Contain("CommandPayload(committedCommand)"));
            Assert.That(receipts, Does.Not.Contain("GetChoice(\"pro_season_decision\")"));
            Assert.That(runtime, Does.Contain("action.Id,\n                command,"));
            Assert.That(receipts, Does.Contain("ProRetirementAnalyticsPolicy.TryProject"));
            Assert.That(receipts, Does.Not.Contain("goto case \"finalize_high_school_legacy\""));
            Assert.That(receipts, Does.Contain("after?.Pro?.ProCareerId"));
            Assert.That(receipts, Does.Contain("? after.Pro.ProCareerId"));
            Assert.That(receipts, Does.Contain("RecapContinueProperties(before, \"quick_rebirth\")"));
            Assert.That(receipts, Does.Contain("RecapContinueProperties(before, \"customize\")"));
            Assert.That(receipts, Does.Contain("? \"recap\""));
            Assert.That(runtime, Does.Contain("new StartQuickRebirthCommand(\"recap\", now)"));
            Assert.That(receipts, Does.Contain("[\"has_frozen_legacy\"] = record.PlayerLegacy != null"));
            Assert.That(receipts, Does.Not.Contain("[\"has_frozen_legacy\"] = false"));
            Assert.That(receipts, Does.Contain("[\"source\"] = \"next_life\""));
            Assert.That(receipts, Does.Contain("PreviousPlayerLegacyFor(route, state)"));
            Assert.That(receipts, Does.Contain("PhaseTransitionAnalyticsPolicy.IsEntered(before, after)"));
            Assert.That(receipts, Does.Contain("\"transition-\" + after.Revision"));
            Assert.That(runtime, Does.Not.Contain("ObservePhaseAnalytics(state)"));

            int completeStart = pitch.IndexOf("public async Task<ShellActionResult> CompleteAsync", StringComparison.Ordinal);
            int retryStart = pitch.IndexOf("public async Task<PitchSessionLoadResult> RetryTutorialAsync", StringComparison.Ordinal);
            string complete = pitch.Substring(completeStart, retryStart - completeStart);
            Assert.That(complete, Does.Contain("AnalyticsEvent.FirstPitch"));
            Assert.That(pitch.Substring(retryStart), Does.Not.Contain("AnalyticsEvent.FirstPitch"));
            Assert.That(pitch, Does.Contain("[\"mode\"]"));
            Assert.That(pitch, Does.Not.Contain("[\"result\"] = \"completed\""));
            Assert.That(pitch, Does.Contain("[\"reason_id\"]"));
            Assert.That(pitch, Does.Contain("[\"ability_moment_count\"] = report.AbilityMomentCount"));
            Assert.That(pitch, Does.Contain("[\"ability_moment_types\"] = string.Join"));
            Assert.That(pitch, Does.Contain("new PitchAbilityMomentEvidence"));
            Assert.That(pitch, Does.Not.Contain("DailyRewardAnalyticsPolicy.TryProject"));
            Assert.That(pitch, Does.Not.Contain("AnalyticsEvent.DailyInningRewarded,\n                    new Dictionary<string, object>(StringComparer.Ordinal)\n                    {\n                        [\"soul_points\"] = Math.Max"));
            Assert.That(runtime, Does.Not.Contain("SafeLog(AnalyticsEvent.GameAbandoned"));
            Assert.That(pitch, Does.Not.Contain("SafeLog(AnalyticsEvent.PhaseEntered"));
            Assert.That(runtime, Does.Contain("AndroidReminderService.Instance.RequestEnabled(enabled)"));
            Assert.That(runtime, Does.Contain("reminders.RequestEnabled(true, \"after_first_game\")"));
            Assert.That(runtime, Does.Contain("AnalyticsEvent.ReminderChanged"));
            Assert.That(runtime, Does.Not.Contain("begin_daily_pitch"));
            Assert.That(receipts, Does.Not.Contain("route == ShellRoute.Daily"));
            Assert.That(receipts, Does.Contain("_readModel.ShouldShowReminderNudge(route, state)"));
            Assert.That(receipts, Does.Not.Contain("route == ShellRoute.Settings &&\n                    !state.Settings.NotificationsEnabled"));
        }

        [Test]
        public void SessionAndReturnEventsUseSeparateExactPropertyDictionaries()
        {
            string source = Read("apps/android-unity/Assets/Game/Presentation/Shell/ProductionAnalyticsReceipts.cs");
            Assert.That(source, Does.Contain("if (value.ShouldEmitReturnEligible)"));
            Assert.That(source, Does.Not.Contain("if (value.ReturnEligible) SafeLog(AnalyticsEvent.ReturnPlanEligible"));
            foreach (string key in new[]
            {
                "minutes", "life_number", "games", "important_games_total", "phase",
                "act_number", "lives_finished", "return_eligible", "return_destination",
                "return_reason", "plan_receipt", "experiment_id", "variant",
                "development_rules_version"
            }) Assert.That(source, Does.Contain("[\"" + key + "\"]"), key);
            foreach (string key in new[]
            {
                "destination", "reason", "saved_day_key", "return_day_key", "day_gap"
            }) Assert.That(source, Does.Contain("[\"" + key + "\"]"), key);
        }

        [Test]
        public void ReturnPlanExposureUsesRenderedRouteAndNeverSyntheticPublishRoute()
        {
            string runtime = ProductionRuntimeSource();
            string controller = Read("apps/android-unity/Assets/Game/Presentation/Shell/BaseballShellController.cs");
            string receipts = Read("apps/android-unity/Assets/Game/Presentation/Shell/ProductionAnalyticsReceipts.cs");
            int publishStart = runtime.IndexOf("private void OnStatePublished", StringComparison.Ordinal);
            int busyStart = runtime.IndexOf("private void OnBusyChanged", publishStart, StringComparison.Ordinal);
            string publish = runtime.Substring(publishStart, busyStart - publishStart);

            Assert.That(publish, Does.Not.Contain("OnRouteChanged"));
            Assert.That(controller, Does.Contain("IBaseballOpeningPresentationGate"));
            Assert.That(controller, Does.Contain("ShouldHoldOpeningForReturnPlan"));
            Assert.That(receipts, Does.Contain("if (route == ShellRoute.Opening)"));
            Assert.That(receipts, Does.Contain("AnalyticsEvent.ReturnPlanShown"));
            Assert.That(receipts, Does.Contain("WelcomeReturnPlan(state"));
        }

        [Test]
        public void ContentAnalyticsWaitForViewportExposureInsteadOfRoutePublication()
        {
            string receipts = Read(
                "apps/android-unity/Assets/Game/Presentation/Shell/ProductionAnalyticsReceipts.cs");
            string controller = Read(
                "apps/android-unity/Assets/Game/Presentation/Shell/BaseballScreenControllerBase.cs");
            string shellController = Read(
                "apps/android-unity/Assets/Game/Presentation/Shell/BaseballShellController.cs");
            string analyticsBootstrap = Read(
                "apps/android-unity/Assets/Game/Platform/Analytics/AnalyticsBootstrap.cs");
            string archive = Read(
                "apps/android-unity/Assets/Game/Presentation/Records/RecordsScreenController.cs");
            int routeStart = receipts.IndexOf(
                "private async void ObserveRouteAnalytics", StringComparison.Ordinal);
            int exposureStart = receipts.IndexOf(
                "public async Task<bool> OnContentVisibleAsync", routeStart, StringComparison.Ordinal);
            string routeObserver = receipts.Substring(routeStart, exposureStart - routeStart);
            string exposureObserver = receipts.Substring(exposureStart);

            foreach (string analyticsEvent in new[]
            {
                "CareerWindSeen", "PlayerHeartlineSeen", "PlayerLegacySeen",
                "SignatureLegacyOptionsSeen", "ReminderOfferShown"
            })
            {
                Assert.That(routeObserver, Does.Not.Contain("AnalyticsEvent." + analyticsEvent), analyticsEvent);
                Assert.That(exposureObserver, Does.Contain("AnalyticsEvent." + analyticsEvent), analyticsEvent);
            }
            Assert.That(controller, Does.Contain("ViewportExposureObserver"));
            Assert.That(controller, Does.Contain("OnContentVisibleAsync("));
            Assert.That(shellController, Does.Contain("_contentExposure.TryBegin("));
            Assert.That(shellController, Does.Contain("_contentExposure.Complete("));
            Assert.That(shellController, Does.Contain("_contentExposure.Release("));
            Assert.That(exposureObserver, Does.Contain("EmitExposureOnceAsync("));
            Assert.That(exposureObserver, Does.Contain("EmitDurableOnceDetailedAsync("));
            Assert.That(receipts, Does.Contain("_analyticsReceiptsAwaitingEnqueue"));
            Assert.That(receipts, Does.Contain("if (SafeLog(analyticsEvent, properties))"));
            Assert.That(analyticsBootstrap, Does.Contain("public static bool Log("));
            Assert.That(analyticsBootstrap, Does.Contain("StartupBuffer.Enqueue(analyticsEvent, validated);"));
            Assert.That(analyticsBootstrap, Does.Contain("return true;"));
            Assert.That(archive, Does.Contain("TrackContentExposure("));
            Assert.That(archive, Does.Not.Contain("?.OnLifeArchiveVisible(visibleLife)"));
        }

        [Test]
        public void ReminderOpenUsesDurableAnalyticsAndNavigationReceiptsOutsidePlatform()
        {
            string platform = Read(
                "apps/android-unity/Assets/Game/Platform/Notifications/AndroidReminderService.cs");
            string runtime = ProductionRuntimeSource();
            string receipts = Read(
                "apps/android-unity/Assets/Game/Presentation/Shell/ProductionAnalyticsReceipts.cs");

            Assert.That(platform, Does.Contain("TryPeekReminderOpen"));
            Assert.That(platform, Does.Contain("CompleteReminderOpen"));
            Assert.That(platform, Does.Not.Contain("AnalyticsBootstrap"));
            Assert.That(platform, Does.Not.Contain("DestinationOpened"));
            Assert.That(receipts, Does.Contain("AnalyticsEvent.ReminderOpened"));
            Assert.That(receipts, Does.Contain("NavigationReceiptEventId"));
            Assert.That(receipts, Does.Contain("PresentReminderNavigation"));
            Assert.That(receipts, Does.Contain("EnsureDurableReceiptAsync"));
            Assert.That(runtime, Does.Contain("AcknowledgeExternalRoute"));
            Assert.That(runtime, Does.Contain("ConfirmReminderNavigation(reminderToken)"));
            Assert.That(runtime, Does.Contain("_externalRouteReminderToken = null"));
        }

        [Test]
        public void ShareChooserLogsTappedOnlyAndPngCarriesKoreanText()
        {
            string runtime = ProductionRuntimeSource();
            string share = Read("apps/android-unity/Assets/Game/Platform/Share/AndroidShareService.cs");
            Assert.That(runtime, Does.Contain("if (imageOpened || textOpened)"));
            Assert.That(runtime, Does.Contain("AnalyticsEvent.LifeCardShareTapped"));
            Assert.That(runtime, Does.Not.Contain("AnalyticsEvent.LifeCardShared"));
            Assert.That(runtime, Does.Not.Contain("AnalyticsEvent.LifeCardShareCompleted"));
            Assert.That(share, Does.Contain("NormalizeShareText(shareText)"));
            Assert.That(share, Does.Contain("EXTRA_TEXT"));
            Assert.That(share, Does.Contain("EXTRA_STREAM"));
        }

        [Test]
        public void EveryProjectedCommandActionHasAProductionDispatchPath()
        {
            string projection = StoreCareerReadModelSource();
            string runtime = ProductionRuntimeSource();
            string[] actionIds = Regex.Matches(
                    projection,
                    @"Command\(\s*""([^""]+)""",
                    RegexOptions.CultureInvariant)
                .Cast<Match>()
                .Select(match => match.Groups[1].Value)
                .Distinct(StringComparer.Ordinal)
                .OrderBy(value => value, StringComparer.Ordinal)
                .ToArray();

            Assert.That(actionIds, Does.Contain("train_block"));
            Assert.That(actionIds, Does.Contain("advance_pro_segment"));
            foreach (string actionId in actionIds)
            {
                bool handled = actionId.EndsWith(":", StringComparison.Ordinal)
                    ? runtime.Contains("achievementPrefix", StringComparison.Ordinal)
                    : runtime.Contains("\"" + actionId + "\"", StringComparison.Ordinal);
                Assert.That(handled, Is.True, actionId);
            }
            Assert.That(projection, Does.Contain("navigate_next_high_school"));
            Assert.That(runtime, Does.Contain("StartsWith(\"navigate_\""));
        }

        [Test]
        public void WeeklyBoardIsReachableFromRecordsAndClaimUsesSavedCommandBoundary()
        {
            string template = Read(
                "apps/android-unity/Assets/Game/Presentation/Shell/BaseballScreenTemplateReadModel.cs");
            string projection = StoreCareerReadModelSource();
            string runtime = ProductionRuntimeSource();
            string meta = Read(
                "apps/android-unity/Assets/Game/Presentation/Meta/MetaScreenController.cs");

            Assert.That(template, Does.Contain("Secondary(\"weekly\", ShellRoute.Weekly)"));
            Assert.That(projection, Does.Contain("\"records-weekly-note\""));
            Assert.That(projection, Does.Contain("\"navigate_weekly\""));
            Assert.That(projection, Does.Contain("\"claim_weekly\""));
            Assert.That(runtime, Does.Contain(
                "case \"claim_weekly\": return new ClaimWeeklyRewardCommand(now);"));
            Assert.That(runtime, Does.Contain("if (route == ShellRoute.Weekly)"));
            Assert.That(meta, Does.Not.Contain("ShellRoute.Daily"));
        }

        [Test]
        public void RetiredDailyHasNoProductScreenCopyActionOrPitchScoringPath()
        {
            string template = Read(
                "apps/android-unity/Assets/Game/Presentation/Shell/BaseballScreenTemplateReadModel.cs");
            string projection = StoreCareerReadModelSource();
            string factory = Read(
                "apps/android-unity/Assets/Game/Presentation/Shell/BaseballScreenControllerFactory.cs");
            string runtime = ProductionRuntimeSource();
            string pitch = Read(
                "apps/android-unity/Assets/Game/Presentation/Shell/ProductionPitchSessionPersistence.cs");
            string copy = Read(
                "apps/android-unity/Assets/Game/Content/ko-KR/Resources/ui-copy-ko-KR.json");
            string reminder = Read(
                "apps/android-unity/Assets/Game/Platform/Notifications/AndroidReminderPlan.cs");

            Assert.That(template, Does.Not.Contain("screens.Add(ShellRoute.Daily"));
            Assert.That(template, Does.Contain("if (route == ShellRoute.Daily) continue;"));
            Assert.That(projection, Does.Not.Contain("case ShellRoute.Daily:"));
            Assert.That(projection, Does.Contain("if (route == ShellRoute.Daily) route = RetiredDailyFallbackFor(state);"));
            Assert.That(factory, Does.Not.Contain("case ShellRoute.Daily:"));
            Assert.That(runtime, Does.Not.Contain("begin_daily_pitch"));
            Assert.That(pitch, Does.Not.Contain("PitchCareerKind.Daily"));
            Assert.That(pitch, Does.Not.Contain("DailyScore"));
            Assert.That(copy, Does.Not.Contain("\"daily."));
            Assert.That(copy, Does.Not.Contain("일일 도전"));
            Assert.That(reminder, Does.Not.Contain("AndroidReminderPlan Daily"));
        }

        [Test]
        public void RebirthSetupUsesPersistedInheritanceAndChallengeDifficultyWithoutNoneChoices()
        {
            string setup = Read(
                "apps/android-unity/Assets/Game/Presentation/Setup/SetupScreenController.cs");
            string runtime = ProductionRuntimeSource();

            Assert.That(setup, Does.Contain("AddReadOnlyMemories(host, memories)"));
            Assert.That(setup, Does.Contain("자동으로 이어집니다"));
            Assert.That(setup, Does.Not.Contain("장착하지 않음"));
            Assert.That(setup, Does.Not.Contain("WithNone(options.SignatureLegacies"));
            Assert.That(setup, Does.Not.Contain("WithNone(options.SoulDomains"));
            Assert.That(setup, Does.Contain("if (options.AutomaticSoul > 0)"));
            int difficulty = setup.IndexOf(
                "AddSingleChoice(host, \"난이도\"", StringComparison.Ordinal);
            int challengeReturn = setup.IndexOf("if (challenge)", difficulty, StringComparison.Ordinal);
            Assert.That(difficulty, Is.GreaterThanOrEqualTo(0));
            Assert.That(challengeReturn, Is.GreaterThan(difficulty),
                "challenge setup must render difficulty before hiding inheritance controls");

            Assert.That(runtime, Does.Contain("_setupSoulDomain = \"technique\""));
            Assert.That(runtime, Does.Contain("options.AutomaticSoul > 0 ? \"technique\" : string.Empty"));
            Assert.That(runtime, Does.Contain("state.Meta?.EquippedSignatureLegacyId"));
            Assert.That(runtime, Does.Contain("SetupOptions?.CarriedMemories?.ToArray()"));
            Assert.That(runtime, Does.Not.Contain("_setupMemories"));
            Assert.That(runtime, Does.Contain("challenge ? Array.Empty<string>() : SetupMemories"));
            Assert.That(runtime, Does.Contain("challenge ? null : EmptyToNull(SetupSignatureLegacy)"));
            Assert.That(runtime, Does.Not.Contain("challenge ? \"standard\" : _setupDifficulty"));
            Assert.That(runtime, Does.Contain("_setupDraftLifecycle.Observe("));
            Assert.That(runtime, Does.Contain("_seedInput = string.Empty;"));
            Assert.That(runtime, Does.Contain("_seedValidationMessage = string.Empty;"));
            Assert.That(runtime, Does.Contain("_setupDifficulty = \"standard\";"));
            Assert.That(runtime, Does.Contain("_setupKarmas.Clear();"));
            Assert.That(runtime, Does.Contain("_setupSoulBoosts.Clear();"));
            Assert.That(runtime, Does.Contain("HighSchoolSetupCatalog.Regions.FirstOrDefault()?.Payload"));
            Assert.That(runtime, Does.Contain("HighSchoolSetupCatalog.Presets.FirstOrDefault()?.Payload"));
        }

        [Test]
        public void SetupPresentsOneIosDecisionPerStepAndOnlyStartsOnTheFinalStep()
        {
            string setup = Read(
                "apps/android-unity/Assets/Game/Presentation/Setup/SetupScreenController.cs");
            string uxml = Read(
                "apps/android-unity/Assets/Game/Presentation/Setup/Resources/SetupScreen.uxml");
            string style = Read(
                "apps/android-unity/Assets/Game/Presentation/Setup/Resources/SetupScreen.uss");

            Assert.That(setup, Does.Contain("case 0: AddNameStep(host, rebirth)"));
            Assert.That(setup, Does.Contain("case 1: AddRegionStep(host)"));
            Assert.That(setup, Does.Contain("case 2: AddPresetStep(host)"));
            Assert.That(setup, Does.Contain("default: AddHandicapStep(host)"));
            Assert.That(setup, Does.Contain("if (_step == _stepCount - 1)"));
            Assert.That(setup, Does.Contain("screen-setup-step-next"));
            Assert.That(setup, Does.Contain("screen-setup-step-back"));
            Assert.That(setup, Does.Contain("new AbilityGauge"));
            Assert.That(uxml, Does.Contain("class=\"setup-step-footer\""));
            Assert.That(style, Does.Contain(".setup-region-grid"));
            Assert.That(style, Does.Contain(".setup-preset-card--selected"));
            Assert.That(style, Does.Contain(".unity-base-text-field__input"));
            Assert.That(setup, Does.Contain("verticalScrollerVisibility = ScrollerVisibility.Hidden"));
            Assert.That(setup, Does.Contain("scroll.verticalScroller.style.display = DisplayStyle.None"));
        }

        [Test]
        public void DirectProStartUsesAuthoritativeSeededTeamFactory()
        {
            string runtime = ProductionRuntimeSource();
            Assert.That(runtime, Does.Contain(
                "new StartDirectProCommand(DirectProStartRequestFactory.Create("));
            Assert.That(runtime, Does.Contain("state,\n                        _presetId,\n                        EffectivePlayerName()"));
            Assert.That(runtime, Does.Not.Contain("ProCareerEngine.ProTeams[0]"));
            Assert.That(runtime, Does.Not.Contain("new StartDirectProRequest("));
        }

        [Test]
        public void LifeCardShareUsesNullSafeFrozenArchiveProjection()
        {
            string runtime = ProductionRuntimeSource();
            string copy = Read(
                "apps/android-unity/Assets/Game/Presentation/Shell/LifeCardShareCopy.cs");

            Assert.That(runtime, Does.Contain("LifeCardShareCopy.Build(life)"));
            Assert.That(runtime, Does.Not.Contain("HighSchoolPerformance.Strikeouts"));
            Assert.That(copy, Does.Contain("life.HighSchoolPerformance?.Strikeouts"));
            Assert.That(copy, Does.Contain("highSchoolStrikeouts ?? 0"));
        }

        private static string ProductionSource()
        {
            return string.Join(
                "\n",
                new[]
                {
                    ProductionRuntimeSource(),
                    Read("apps/android-unity/Assets/Game/Presentation/Shell/ProductionAnalyticsReceipts.cs"),
                    Read("apps/android-unity/Assets/Game/Presentation/Shell/ProductionPitchSessionPersistence.cs"),
                    Read("apps/android-unity/Assets/Game/Platform/Notifications/AndroidReminderService.cs"),
                });
        }

        private static int Count(string source, string pattern)
        {
            int count = 0;
            for (int index = 0; (index = source.IndexOf(pattern, index, StringComparison.Ordinal)) >= 0;
                 index += pattern.Length) count++;
            return count;
        }

        private static string StoreCareerReadModelSource()
        {
            string sample = FindFromParents(
                "apps/android-unity/Assets/Game/Presentation/Shell/StoreBaseballCareerReadModel.cs");
            string directory = Path.GetDirectoryName(sample);
            return string.Join(
                "\n",
                Directory.GetFiles(directory, "StoreBaseballCareer*.cs")
                    .OrderBy(path => path, StringComparer.Ordinal)
                    .Select(File.ReadAllText));
        }

        private static string ProductionRuntimeSource()
        {
            string sample = FindFromParents(
                "apps/android-unity/Assets/Game/Presentation/Shell/ProductionBaseballShellRuntime.cs");
            string directory = Path.GetDirectoryName(sample);
            return string.Join(
                "\n",
                Directory.GetFiles(directory, "ProductionBaseballShellRuntime*.cs")
                    .OrderBy(path => path, StringComparer.Ordinal)
                    .Select(File.ReadAllText));
        }

        private static string Read(string relativePath) =>
            File.ReadAllText(FindFromParents(relativePath));

        private static string FindFromParents(string relativePath)
        {
            DirectoryInfo current = new DirectoryInfo(TestContext.CurrentContext.TestDirectory);
            while (current != null)
            {
                string candidate = Path.Combine(current.FullName, relativePath);
                if (File.Exists(candidate)) return candidate;
                current = current.Parent;
            }
            throw new FileNotFoundException("Repository source was not found.", relativePath);
        }
    }
}
