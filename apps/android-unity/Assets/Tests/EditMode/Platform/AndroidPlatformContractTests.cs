using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Baseball.Platform.Notifications;
using Baseball.Platform.Review;
using Baseball.Platform.Share;
using Baseball.Platform.Identity;
using Baseball.Platform.Haptics;
using NUnit.Framework;

namespace Baseball.Platform.Tests
{
    public sealed class AndroidPlatformContractTests
    {
        [Test]
        public void HapticsRequireAppMotionSystemAndHardwarePermissionTogether()
        {
            Assert.That(HapticEnablementPolicy.Allows(true, false, true, true), Is.True);
            Assert.That(HapticEnablementPolicy.Allows(false, false, true, true), Is.False);
            Assert.That(HapticEnablementPolicy.Allows(true, true, true, true), Is.False);
            Assert.That(HapticEnablementPolicy.Allows(true, false, false, true), Is.False);
            Assert.That(HapticEnablementPolicy.Allows(true, false, true, false), Is.False);

            string source = File.ReadAllText(FindFromParents(Path.Combine(
                "apps", "android-unity", "Assets", "Game", "Platform", "Haptics",
                "AndroidHapticsService.cs")));
            Assert.That(source, Does.Contain("haptic_feedback_enabled"));
            Assert.That(source, Does.Contain("SystemHapticFeedbackEnabled()"));
            Assert.That(source.IndexOf("SystemHapticFeedbackEnabled()", StringComparison.Ordinal),
                Is.LessThan(source.IndexOf("GetVibrator()", StringComparison.Ordinal)),
                "system opt-out must be checked before acquiring or invoking the vibrator");
        }

        [Test]
        public void ReviewReasonsAreLifetimeOnceWithTwentyFourHourSpacing()
        {
            var first = new DateTimeOffset(2026, 8, 11, 0, 0, 0, TimeSpan.Zero);
            var empty = new ReviewPromptReceiptState();
            Assert.That(ReviewPromptPolicy.CanAttempt(
                empty, ReviewPromptReason.ThirdLife, first), Is.True);

            ReviewPromptReceiptState claimed = ReviewPromptPolicy.Claim(
                empty, ReviewPromptReason.ThirdLife, first);
            Assert.That(ReviewPromptPolicy.CanAttempt(
                claimed, ReviewPromptReason.ThirdLife, first.AddDays(10)), Is.False);
            Assert.That(ReviewPromptPolicy.CanAttempt(
                claimed, ReviewPromptReason.GoodRecap, first.AddHours(23)), Is.False);
            Assert.That(ReviewPromptPolicy.CanAttempt(
                claimed, ReviewPromptReason.GoodRecap, first.AddHours(24)), Is.True);
            Assert.That(ReviewPromptPolicy.CanAttempt(
                claimed, ReviewPromptReason.Drafted, first.AddMinutes(-1)), Is.False,
                "clock rollback must not bypass the interval");
        }

        [Test]
        public void ReviewReceiptSurvivesRestartAndResetClearsAllReasons()
        {
            string directory = Path.Combine(
                Path.GetTempPath(),
                "baseball-review-test-" + Guid.NewGuid().ToString("N"));
            string path = Path.Combine(directory, "receipts.state");
            try
            {
                var first = new DateTimeOffset(2026, 8, 11, 0, 0, 0, TimeSpan.Zero);
                var initial = new FileReviewAttemptGate(path);
                Assert.That(initial.TryClaim(ReviewPromptReason.ThirdLife, first), Is.True);
                Assert.That(initial.TryClaim(ReviewPromptReason.ThirdLife, first.AddDays(2)), Is.False);

                var restarted = new FileReviewAttemptGate(path);
                Assert.That(restarted.TryClaim(
                    ReviewPromptReason.ThirdLife, first.AddDays(2)), Is.False);
                Assert.That(restarted.TryClaim(
                    ReviewPromptReason.GoodRecap, first.AddHours(23)), Is.False);
                Assert.That(restarted.TryClaim(
                    ReviewPromptReason.GoodRecap, first.AddHours(24)), Is.True);

                restarted.Reset();
                var afterReset = new FileReviewAttemptGate(path);
                Assert.That(afterReset.TryClaim(
                    ReviewPromptReason.ThirdLife, first.AddHours(25)), Is.True);
            }
            finally
            {
                if (Directory.Exists(directory)) Directory.Delete(directory, true);
            }
        }

        [Test]
        public void ReviewReceiptNamespaceDoesNotCrossResetOrProcessRestart()
        {
            const string oldInstallId = "55555555555555555555555555555555";
            const string newInstallId = "66666666666666666666666666666666";
            string directory = Path.Combine(
                Path.GetTempPath(),
                "baseball-review-epoch-test-" + Guid.NewGuid().ToString("N"));
            try
            {
                var now = new DateTimeOffset(2026, 8, 12, 0, 0, 0, TimeSpan.Zero);
                string oldPath = InstallScopedLocalStatePolicy.ReviewReceiptPath(
                    directory,
                    oldInstallId);
                string newPath = InstallScopedLocalStatePolicy.ReviewReceiptPath(
                    directory,
                    newInstallId);
                Assert.That(new FileReviewAttemptGate(oldPath).TryClaim(
                    ReviewPromptReason.Drafted,
                    now), Is.True);

                Assert.That(new FileReviewAttemptGate(newPath).TryClaim(
                    ReviewPromptReason.Drafted,
                    now), Is.True,
                    "publishing a new install ID must select a fresh receipt file");
                Assert.That(new FileReviewAttemptGate(newPath).TryClaim(
                    ReviewPromptReason.Drafted,
                    now.AddDays(2)), Is.False,
                    "the new receipt must survive process restart");
                Assert.That(new FileReviewAttemptGate(oldPath).TryClaim(
                    ReviewPromptReason.Drafted,
                    now.AddDays(2)), Is.False,
                    "the old receipt remains isolated in its prior namespace");
            }
            finally
            {
                if (Directory.Exists(directory)) Directory.Delete(directory, true);
            }
        }

        [Test]
        public void PlayReviewRuntimeRebindsToCurrentInstallReceiptPath()
        {
            string source = File.ReadAllText(FindFromParents(Path.Combine(
                "apps", "android-unity", "Assets", "Game", "Platform", "Review",
                "PlayReviewPrompt.cs")));

            Assert.That(source, Does.Contain("InstallScopedLocalStatePolicy.ReviewReceiptPath"));
            Assert.That(source, Does.Contain("BindCurrentInstallNamespace();"));
            Assert.That(source, Does.Contain("_instance._attemptGate?.Reset();"));
            Assert.That(source, Does.Contain("_instance._attemptGate = replacement"));
            Assert.That(source, Does.Not.Contain(
                "Path.Combine(\n            AnonymousInstallIdentity.ResolveNoBackupDirectory(),\n            \"play-review-receipts-v2.state\")"));
        }

        [Test]
        public void ReviewReceiptWriteFailureDoesNotClaimOrThrow()
        {
            string parentFile = Path.Combine(
                Path.GetTempPath(),
                "baseball-review-parent-" + Guid.NewGuid().ToString("N"));
            File.WriteAllText(parentFile, "not a directory");
            try
            {
                var gate = new FileReviewAttemptGate(Path.Combine(parentFile, "receipt"));
                Assert.That(gate.TryClaim(
                    ReviewPromptReason.Drafted,
                    new DateTimeOffset(2026, 8, 11, 0, 0, 0, TimeSpan.Zero)), Is.False);
            }
            finally
            {
                if (File.Exists(parentFile)) File.Delete(parentFile);
            }
        }

        [Test]
        public void SeoulReminderUsesNext1930WithoutExactAlarmAssumption()
        {
            DateTimeOffset before = new DateTimeOffset(2026, 8, 11, 9, 0, 0, TimeSpan.Zero);
            DateTimeOffset after = new DateTimeOffset(2026, 8, 11, 11, 0, 0, TimeSpan.Zero);

            Assert.That(SeoulReminderSchedule.NextFireUtc(before),
                Is.EqualTo(new DateTimeOffset(2026, 8, 11, 10, 30, 0, TimeSpan.Zero)));
            Assert.That(SeoulReminderSchedule.NextFireUtc(after),
                Is.EqualTo(new DateTimeOffset(2026, 8, 12, 10, 30, 0, TimeSpan.Zero)));
        }

        [Test]
        public void SeoulReminderBuildsThreeExplicitNonRepeatingSlotsAndSkipsPastOrPlayedDays()
        {
            DateTimeOffset before = new DateTimeOffset(2026, 8, 11, 9, 0, 0, TimeSpan.Zero);
            DateTimeOffset after = new DateTimeOffset(2026, 8, 11, 11, 0, 0, TimeSpan.Zero);

            IReadOnlyList<SeoulReminderEntry> all = SeoulReminderSchedule.Upcoming(before);
            Assert.That(all.Count, Is.EqualTo(3));
            Assert.That(all[0].NotificationId, Is.EqualTo(1930));
            Assert.That(all[1].NotificationId, Is.EqualTo(1931));
            Assert.That(all[2].NotificationId, Is.EqualTo(1932));
            Assert.That(all[0].DayKey, Is.EqualTo("20260811"));

            IReadOnlyList<SeoulReminderEntry> future = SeoulReminderSchedule.Upcoming(after);
            Assert.That(future.Count, Is.EqualTo(2));
            Assert.That(future[0].NotificationId, Is.EqualTo(1931));

            IReadOnlyList<SeoulReminderEntry> unplayed = SeoulReminderSchedule.Upcoming(
                before,
                new[] { "20260811" });
            Assert.That(unplayed.Count, Is.EqualTo(2));
            Assert.That(unplayed[0].NotificationId, Is.EqualTo(1931));
        }

        [Test]
        public void ReminderIntentCarriesOnlyTypedLowCardinalityDestinationAndReason()
        {
            const string installId = "77777777777777777777777777777777";
            string installEpoch = InstallScopedLocalStatePolicy.Epoch(installId);
            var plan = new AndroidReminderPlan(
                "다시 마운드로",
                "다음 일정을 이어가세요.",
                "high_school",
                "return_plan",
                "20260811");

            string intent = plan.IntentData("20260812", installEpoch);
            Assert.That(AndroidReminderPlan.TryParseIntent(intent, out string destination, out string reason), Is.True);
            Assert.That(destination, Is.EqualTo("high_school"));
            Assert.That(reason, Is.EqualTo("return_plan"));
            Assert.That(intent, Does.Not.Contain("다시 마운드로"));
            Assert.That(intent, Does.Not.Contain("다음 일정을"));
            Assert.That(intent, Does.Contain("experiment_id="));
            Assert.That(intent, Does.Contain("saved_day_key="));
            Assert.That(intent, Does.Contain("development_rules_version="));
            Assert.That(intent, Does.Contain("install_epoch=" + installEpoch));
            Assert.That(intent, Does.Not.Contain(installId));
            Assert.That(AndroidReminderPlan.TryParseIntent(
                "baseball://reminder?source=return_reminder&destination=external&reason=return_plan",
                out _,
                out _), Is.False);
            Assert.That(AndroidReminderPlan.TryParseIntent(
                "baseball://reminder?source=return_reminder&destination=pro&reason=free_form",
                out _,
                out _), Is.False);

            Assert.That(ReminderOpenPolicy.TryCreate(intent, out ReminderOpenRequest first), Is.True);
            Assert.That(first.Intent.InstallEpoch, Is.EqualTo(installEpoch));
            Assert.That(ReminderOpenPolicy.TryCreate(intent, out ReminderOpenRequest repeated), Is.True);
            Assert.That(first.StableTokenHash, Is.EqualTo(repeated.StableTokenHash));
            Assert.That(first.StableTokenHash, Has.Length.EqualTo(16));
            Assert.That(first.StableTokenHash, Does.Not.Contain(plan.Receipt));
            Assert.That(ReminderOpenPolicy.TryCreate(
                plan.IntentData("20260813", installEpoch),
                out ReminderOpenRequest nextDay),
                Is.True);
            Assert.That(nextDay.StableTokenHash, Is.Not.EqualTo(first.StableTokenHash));
        }

        [Test]
        public void AndroidReminderSourceUsesExplicitIdsSmallIconAndNoRepeatInterval()
        {
            string relative = Path.Combine(
                "apps", "android-unity", "Assets", "Game", "Platform", "Notifications",
                "AndroidReminderService.cs");
            string source = File.ReadAllText(FindFromParents(relative));

            Assert.That(source, Does.Contain("SendNotificationWithExplicitID"));
            Assert.That(source, Does.Contain("SmallIcon = SmallIconId"));
            Assert.That(source, Does.Contain("CancelScheduledNotification(id)"));
            Assert.That(source, Does.Not.Contain("RepeatInterval"));
            Assert.That(source, Does.Not.Contain("_handledLaunchIntent"));
            Assert.That(source, Does.Not.Contain("_lastHandledIntentToken"));
            Assert.That(source, Does.Contain("TryPeekReminderOpen"));
            Assert.That(source, Does.Contain("CompleteReminderOpen"));
            Assert.That(source, Does.Contain("ReminderOpenAvailable"));
            Assert.That(source, Does.Not.Contain("AnalyticsBootstrap.Log"));
            Assert.That(source, Does.Not.Contain("AnalyticsEvent.ReminderOpened"));
            Assert.That(source, Does.Not.Contain("DestinationOpened"));
            Assert.That(source, Does.Contain("if (!paused && IsInstallBound)"));
            Assert.That(source, Does.Contain("ScheduleNext();"));
            Assert.That(source, Does.Contain("TombstoneAndClearCurrentReminderIntent()"));
            Assert.That(source, Does.Contain("_resetIntentGuard.ShouldIgnore(request.StableTokenHash)"));
            Assert.That(source, Does.Contain("_plan.IntentData(entry.DayKey, _installEpoch)"));
            Assert.That(source, Does.Contain("request.Intent.InstallEpoch"));
            Assert.That(source, Does.Contain("InstallScopedLocalStatePolicy.ReminderAskedKey"));
            Assert.That(source, Does.Contain("public bool BindInstall(string installId)"));
            Assert.That(source, Does.Contain("if (!IsInstallBound) return;"));
            Assert.That(source, Does.Contain("string previousAskedKey = _askedKey;"));
            Assert.That(source, Does.Contain("PlayerPrefs.DeleteKey(previousAskedKey);"));
            Assert.That(source, Does.Not.Contain("AnonymousInstallIdentity.GetOrCreate()"),
                "notification Awake must not create a second, non-retryable identity boundary");
            Assert.That(source, Does.Contain("activity.Call(\"setIntent\", emptyIntent)"));
            Assert.That(
                source.Split(new[] { "ReminderOpenAvailable?.Invoke();" }, StringSplitOptions.None).Length - 1,
                Is.EqualTo(1), "one Activity intent publishes one availability callback");

            string iconRelative = Path.Combine(
                "apps", "android-unity", "Assets", "Plugins", "Android",
                "BaseballManifest.androidlib", "res", "drawable",
                "baseball_notification_small.png");
            byte[] icon = File.ReadAllBytes(FindFromParents(iconRelative));
            Assert.That(icon, Has.Length.GreaterThan(26));
            Assert.That(icon[24], Is.EqualTo(8), "notification icon must use 8-bit channels");
            Assert.That(icon[25], Is.EqualTo(4), "notification icon must be grayscale + alpha PNG");
            Assert.That(source, Does.Contain("SmallIconId = \"baseball_notification_small\""));
        }

        [Test]
        public void ResetReminderTombstoneSuppressesSameIntentButAllowsNewInstallToken()
        {
            var currentProcess = new ReminderResetIntentGuard();
            currentProcess.Ignore("old-install-token");

            Assert.That(currentProcess.ShouldIgnore("old-install-token"), Is.True,
                "pause/resume in the resetting process must not recapture the Activity intent");
            Assert.That(currentProcess.ShouldIgnore("new-install-token"), Is.False,
                "a newly delivered reminder token remains eligible for durable handling");

            var restartedProcess = new ReminderResetIntentGuard();
            Assert.That(restartedProcess.ShouldIgnore("old-install-token"), Is.False,
                "tombstones do not cross process/install identity; reset clears the Activity intent instead");
        }

        [Test]
        public void ReminderDenialPublishesOneOsOutcomeAndRestartCorrectionIsDeduplicated()
        {
            ReminderRequestResolution denied = ReminderEnablementPolicy.Request(
                true,
                ReminderPermissionAvailability.Denied);
            Assert.That(denied.EffectiveEnabled, Is.False);
            Assert.That(denied.RequestsPermission, Is.False);
            Assert.That(denied.PublishesOutcome, Is.True);

            var policy = new ReminderEnablementPolicy();
            Assert.That(policy.ShouldPublishPersistedDenial(true, false), Is.True);
            Assert.That(policy.ShouldPublishPersistedDenial(true, false), Is.False,
                "repeated store/render callbacks cannot publish a second correction");
            policy.ResolvePersistedDenial(false);
            Assert.That(policy.ShouldPublishPersistedDenial(true, false), Is.True,
                "a failed save must retry on a later resume");
            policy.ResolvePersistedDenial(true);
            Assert.That(policy.ShouldPublishPersistedDenial(true, false), Is.False,
                "a durably handled mismatch cannot publish twice");
            Assert.That(policy.ShouldPublishPersistedDenial(false, false), Is.False,
                "the saved false aggregate clears the completed handshake");
            Assert.That(policy.ShouldPublishPersistedDenial(true, false), Is.True,
                "a later genuine saved mismatch is a new correction");

            string service = File.ReadAllText(FindFromParents(Path.Combine(
                "apps", "android-unity", "Assets", "Game", "Platform", "Notifications",
                "AndroidReminderService.cs")));
            string runtime = ProductionRuntimeSource();
            Assert.That(service, Does.Contain("public void RequestEnabled(bool enabled, string source = \"settings\")"));
            Assert.That(service, Does.Contain("EnablementChanged?.Invoke(allowed, source)"));
            Assert.That(service, Does.Contain("ResolvePersistedDenial(bool saved)"));
            Assert.That(service, Does.Not.Contain("AnalyticsEvent.ReminderChanged"));
            Assert.That(runtime, Does.Contain("AndroidReminderService.Instance.RequestEnabled(enabled)"));
            Assert.That(runtime, Does.Contain("reminders.RequestEnabled(true, \"after_first_game\")"));
            Assert.That(runtime, Does.Contain("DrainPendingReminderSetting()"));
            Assert.That(runtime, Does.Contain("if (!busy)"));
            Assert.That(runtime, Does.Contain("DrainPendingReminderOpen()"));
            Assert.That(runtime, Does.Contain("if (_store?.Current != null) ApplyPersistedSettings(_store.Current)"),
                "foreground resume must retry durable install binding before permission correction");
            Assert.That(runtime, Does.Contain("AnalyticsEvent.ReminderChanged"));
            Assert.That(runtime.IndexOf("await _store.DispatchAsync", StringComparison.Ordinal),
                Is.LessThan(runtime.IndexOf("AnalyticsEvent.ReminderChanged", StringComparison.Ordinal)));
            Assert.That(runtime.Split(new[] { "AnalyticsEvent.ReminderChanged" }, StringSplitOptions.None).Length - 1,
                Is.EqualTo(1), "notification analytics has one post-save emission site");
        }

        [Test]
        public void ExternallyRevokedPermissionQueuesOnceAndAFalseAggregateNeedsNoRestartCorrection()
        {
            var running = new ReminderEnablementPolicy();
            Assert.That(running.ShouldPublishPersistedDenial(true, false), Is.True,
                "resume observes the external OS revocation");
            Assert.That(running.ShouldPublishPersistedDenial(true, false), Is.False,
                "busy store projections do not enqueue a second correction");
            running.ResolvePersistedDenial(true);
            Assert.That(running.ShouldPublishPersistedDenial(false, false), Is.False,
                "the durably saved aggregate is now disabled");

            var restarted = new ReminderEnablementPolicy();
            Assert.That(restarted.ShouldPublishPersistedDenial(false, false), Is.False,
                "restart projects saved false without a phantom denial event");
        }

        [Test]
        public void ReminderOptInAppearsOnlyWhileOsPermissionCanActuallyBeRequested()
        {
            ReminderPermissionAvailability requestable = ReminderPermissionUiPolicy.Resolve(
                allowed: false,
                requestPending: false,
                blockedBySystem: false);
            ReminderPermissionUiState firstOffer = ReminderPermissionUiPolicy.Project(false, requestable);
            Assert.That(firstOffer.ShouldOfferOptIn, Is.True);
            Assert.That(firstOffer.RequiresSystemSettings, Is.False);

            ReminderPermissionUiState locallyDeclined = ReminderPermissionUiPolicy.Project(
                false,
                requestable,
                offerAlreadyHandled: true);
            Assert.That(locallyDeclined.ShouldOfferOptIn, Is.False,
                "declining the first-game nudge suppresses only that nudge");
            Assert.That(locallyDeclined.RequiresSystemSettings, Is.False,
                "a user who has not asked the OS can still enable reminders from Settings");
            Assert.That(ReminderEnablementPolicy.Request(true, requestable).RequestsPermission, Is.True);

            ReminderPermissionAvailability afterDeniedTap = ReminderPermissionUiPolicy.Resolve(
                allowed: false,
                requestPending: false,
                blockedBySystem: true);
            ReminderPermissionUiState denied = ReminderPermissionUiPolicy.Project(false, afterDeniedTap);
            Assert.That(denied.ShouldOfferOptIn, Is.False,
                "a denied permission tap must not produce another first-game CTA");
            Assert.That(denied.RequiresSystemSettings, Is.True);
            Assert.That(ReminderPermissionUiPolicy.Project(false, afterDeniedTap).ShouldOfferOptIn,
                Is.False, "repeated projections remain hidden");

            ReminderPermissionAvailability externallyRevoked = ReminderPermissionUiPolicy.Resolve(
                allowed: false,
                requestPending: false,
                blockedBySystem: true);
            ReminderPermissionUiState revoked = ReminderPermissionUiPolicy.Project(false, externallyRevoked);
            Assert.That(revoked.ShouldOfferOptIn, Is.False);
            Assert.That(revoked.RequiresSystemSettings, Is.True);

            ReminderPermissionAvailability resetLocalButOsStillBlocked = ReminderPermissionUiPolicy.Resolve(
                allowed: false,
                requestPending: false,
                blockedBySystem: true);
            ReminderPermissionUiState reset = ReminderPermissionUiPolicy.Project(
                false,
                resetLocalButOsStillBlocked);
            Assert.That(reset.ShouldOfferOptIn, Is.False,
                "clearing the local asked flag cannot override an OS-level block");
            Assert.That(reset.RequiresSystemSettings, Is.True);

            string service = File.ReadAllText(FindFromParents(Path.Combine(
                "apps", "android-unity", "Assets", "Game", "Platform", "Notifications",
                "AndroidReminderService.cs")));
            Assert.That(service, Does.Contain("status == PermissionStatus.Denied ||"),
                "clearing local history must not turn an OS denial back into a requestable CTA");
            Assert.That(service, Does.Contain("status == PermissionStatus.NotificationsBlockedForApp"));

            ReminderPermissionUiState pending = ReminderPermissionUiPolicy.Project(
                false,
                ReminderPermissionAvailability.Pending);
            Assert.That(pending.ShouldOfferOptIn, Is.False);
            Assert.That(pending.RequiresSystemSettings, Is.False);
        }

        [Test]
        public void SharePolicyAcceptsOnlyBoundedPngAndNeutralizesPaths()
        {
            byte[] png = { 137, 80, 78, 71, 13, 10, 26, 10, 0 };
            Assert.That(SharePayloadPolicy.IsValidPng(png), Is.True);
            Assert.That(SharePayloadPolicy.IsValidPng(new byte[] { 1, 2, 3 }), Is.False);
            Assert.That(SharePayloadPolicy.NormalizePngFileName("../../내 카드.png"), Is.EqualTo("baseball-life-card.png"));
            Assert.That(SharePayloadPolicy.NormalizePngFileName("life card #7.PNG"), Is.EqualTo("life-card-7.png"));
            Assert.That(
                SharePayloadPolicy.NormalizeShareText("야구 인생\u0000\n탈삼진 12"),
                Is.EqualTo("야구 인생\n탈삼진 12"));
            Assert.That(
                SharePayloadPolicy.NormalizeShareText(new string('가', 600)),
                Has.Length.EqualTo(SharePayloadPolicy.MaximumShareTextLength));
        }

        [Test]
        public void AndroidPngShareIncludesSanitizedKoreanTextInSameIntent()
        {
            string relative = Path.Combine(
                "apps", "android-unity", "Assets", "Game", "Platform", "Share",
                "AndroidShareService.cs");
            string source = File.ReadAllText(FindFromParents(relative));

            Assert.That(source, Does.Contain("SharePayloadPolicy.NormalizeShareText(shareText)"));
            Assert.That(source, Does.Contain("intentClass.GetStatic<string>(\"EXTRA_TEXT\")"));
            Assert.That(source, Does.Contain("intentClass.GetStatic<string>(\"EXTRA_STREAM\")"));
            Assert.That(source, Does.Contain("FLAG_GRANT_READ_URI_PERMISSION"));
            Assert.That(source, Does.Contain("setClipData"));
        }

        [Test]
        public void AnonymousIdentityCandidateIsValidAndDoesNotMutateStorage()
        {
            string candidate = AnonymousInstallIdentityPolicy.CreateCandidate();

            Assert.That(candidate, Has.Length.EqualTo(32));
            Assert.That(AnonymousInstallIdentityPolicy.IsValid(candidate), Is.True);
            Assert.That(AnonymousInstallIdentityPolicy.IsValid("not-an-install-id"), Is.False);
        }

        [Test]
        public void InstallLocalStateUsesOpaqueDistinctEpochPathsAndKeys()
        {
            const string oldInstallId = "88888888888888888888888888888888";
            const string newInstallId = "99999999999999999999999999999999";
            string oldEpoch = InstallScopedLocalStatePolicy.Epoch(oldInstallId);
            string newEpoch = InstallScopedLocalStatePolicy.Epoch(newInstallId);
            string oldAnalytics = InstallScopedLocalStatePolicy.AnalyticsOncePath(
                "/no-backup",
                oldInstallId);
            string newAnalytics = InstallScopedLocalStatePolicy.AnalyticsOncePath(
                "/no-backup",
                newInstallId);
            string oldReview = InstallScopedLocalStatePolicy.ReviewReceiptPath(
                "/no-backup",
                oldInstallId);
            string oldAsked = InstallScopedLocalStatePolicy.ReminderAskedKey(oldInstallId);
            string newAsked = InstallScopedLocalStatePolicy.ReminderAskedKey(newInstallId);

            Assert.That(oldEpoch, Has.Length.EqualTo(16));
            Assert.That(newEpoch, Is.Not.EqualTo(oldEpoch));
            Assert.That(oldAnalytics, Is.Not.EqualTo(newAnalytics));
            Assert.That(oldAnalytics, Does.Contain(InstallScopedLocalStatePolicy.DirectoryName));
            Assert.That(oldAnalytics, Does.EndWith(InstallScopedLocalStatePolicy.AnalyticsOnceFileName));
            Assert.That(oldReview, Does.EndWith(InstallScopedLocalStatePolicy.ReviewReceiptFileName));
            Assert.That(oldAsked, Does.StartWith(
                InstallScopedLocalStatePolicy.ReminderAskedKeyPrefix + "."));
            Assert.That(oldAsked, Is.Not.EqualTo(newAsked));
            Assert.That(oldAnalytics, Does.Not.Contain(oldInstallId));
            Assert.That(oldReview, Does.Not.Contain(oldInstallId));
            Assert.That(oldAsked, Does.Not.Contain(oldInstallId));
            Assert.That(InstallScopedLocalStatePolicy.MatchesEpoch(oldInstallId, oldEpoch), Is.True);
            Assert.That(InstallScopedLocalStatePolicy.MatchesEpoch(newInstallId, oldEpoch), Is.False,
                "an old scheduled reminder must be ignored after reset and process restart");
            Assert.Throws<ArgumentException>(() =>
                InstallScopedLocalStatePolicy.AnalyticsOncePath("/no-backup", "invalid"));
        }

        [Test]
        public void RestartAfterPublishedIdentityPhysicallyDeletesPriorInstallFiles()
        {
            const string oldInstallId = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
            const string newInstallId = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
            string root = Path.Combine(
                Path.GetTempPath(),
                "baseball-install-reconcile-" + Guid.NewGuid().ToString("N"));
            try
            {
                string oldAnalytics = InstallScopedLocalStatePolicy.AnalyticsOncePath(
                    root,
                    oldInstallId);
                string oldReview = InstallScopedLocalStatePolicy.ReviewReceiptPath(
                    root,
                    oldInstallId);
                string currentReview = InstallScopedLocalStatePolicy.ReviewReceiptPath(
                    root,
                    newInstallId);
                Directory.CreateDirectory(Path.GetDirectoryName(oldAnalytics));
                Directory.CreateDirectory(Path.GetDirectoryName(currentReview));
                File.WriteAllText(oldAnalytics, "event:first_pitch\n");
                File.WriteAllText(oldReview, "old-review\n");
                File.WriteAllText(currentReview, "current-review\n");
                string unrelated = Path.Combine(
                    root,
                    InstallScopedLocalStatePolicy.DirectoryName,
                    "do-not-delete");
                Directory.CreateDirectory(unrelated);
                File.WriteAllText(Path.Combine(unrelated, "owner.txt"), "foreign");

                bool reconciled = InstallScopedLocalStateReconciler.KeepOnlyCurrentInstall(
                    root,
                    newInstallId);

                Assert.That(reconciled, Is.True);
                Assert.That(File.Exists(oldAnalytics), Is.False,
                    "the old analytics once file must be physically removed on restart");
                Assert.That(File.Exists(oldReview), Is.False,
                    "the old Play Review receipt must be physically removed on restart");
                Assert.That(File.ReadAllText(currentReview), Is.EqualTo("current-review\n"));
                Assert.That(File.Exists(Path.Combine(unrelated, "owner.txt")), Is.True,
                    "cleanup must ignore directories outside the epoch naming policy");
            }
            finally
            {
                if (Directory.Exists(root)) Directory.Delete(root, true);
            }
        }

        [Test]
        public void ResetJournalSurvivesEveryCrashPointAndDeletesOnlyAfterAllReceipts()
        {
            const string previousInstallId = "cccccccccccccccccccccccccccccccc";
            const string candidateInstallId = "dddddddddddddddddddddddddddddddd";
            string root = Path.Combine(
                Path.GetTempPath(),
                "baseball-reset-journal-" + Guid.NewGuid().ToString("N"));
            string path = InstallScopedLocalStatePolicy.ResetJournalPath(root);
            try
            {
                var preparingProcess = new InstallResetJournal(path);
                preparingProcess.Prepare(previousInstallId, candidateInstallId);

                var afterPrepareCrash = new InstallResetJournal(path);
                InstallResetJournalReadResult prepared = afterPrepareCrash.Read();
                Assert.That(prepared.Status, Is.EqualTo(InstallResetJournalStatus.Pending));
                Assert.That(prepared.Record.PreviousInstallId, Is.EqualTo(previousInstallId));
                Assert.That(prepared.Record.CandidateInstallId, Is.EqualTo(candidateInstallId));
                Assert.That(prepared.Record.CompletedSteps, Is.EqualTo(InstallResetStep.None));

                Assert.That(afterPrepareCrash.Mark(InstallResetStep.ReminderCleaned), Is.True);
                Assert.That(afterPrepareCrash.Mark(InstallResetStep.AnalyticsCleaned), Is.True);
                Assert.That(afterPrepareCrash.Mark(InstallResetStep.ScopedFilesCleaned), Is.True);
                Assert.That(afterPrepareCrash.TryComplete(), Is.False,
                    "platform cleanup before repository completion must retain the journal");

                var afterRepositoryCrash = new InstallResetJournal(path);
                Assert.That(afterRepositoryCrash.Mark(InstallResetStep.RepositoryReset), Is.True);
                Assert.That(afterRepositoryCrash.TryComplete(), Is.False);
                Assert.That(afterRepositoryCrash.Mark(InstallResetStep.IdentityPublished), Is.True);
                Assert.That(afterRepositoryCrash.TryComplete(), Is.False,
                    "review cleanup is still outstanding");

                var finalProcess = new InstallResetJournal(path);
                Assert.That(finalProcess.Mark(InstallResetStep.ReviewCleaned), Is.True);
                Assert.That(finalProcess.Mark(InstallResetStep.ShareCacheCleaned), Is.True);
                Assert.That(finalProcess.Read().Record.IsComplete, Is.True);
                Assert.That(finalProcess.TryComplete(), Is.True);
                Assert.That(File.Exists(path), Is.False);
                Assert.That(new InstallResetJournal(path).Read().Status,
                    Is.EqualTo(InstallResetJournalStatus.None));
            }
            finally
            {
                if (Directory.Exists(root)) Directory.Delete(root, true);
            }
        }

        [Test]
        public void ResetShareCacheDeletesPngsButPreservesUnrelatedTemporaryFiles()
        {
            string root = Path.Combine(
                Path.GetTempPath(),
                "baseball-reset-share-" + Guid.NewGuid().ToString("N"));
            string share = Path.Combine(root, "share");
            try
            {
                Directory.CreateDirectory(share);
                string first = Path.Combine(share, "life-card.png");
                string second = Path.Combine(share, "career.png");
                string unrelated = Path.Combine(share, "keep.txt");
                File.WriteAllText(first, "old-image");
                File.WriteAllText(second, "old-image");
                File.WriteAllText(unrelated, "foreign");

                Assert.That(
                    InstallScopedLocalStateReconciler.ClearSharePngCache(root),
                    Is.True);
                Assert.That(File.Exists(first), Is.False);
                Assert.That(File.Exists(second), Is.False);
                Assert.That(File.ReadAllText(unrelated), Is.EqualTo("foreign"));
                Assert.That(
                    InstallScopedLocalStateReconciler.ClearSharePngCache(root),
                    Is.True,
                    "recovery cleanup must be idempotent");
            }
            finally
            {
                if (Directory.Exists(root)) Directory.Delete(root, true);
            }
        }

        [Test]
        public void RepositoryReceiptPreventsRestartFromDeletingNewPostResetProgress()
        {
            const string previousInstallId = "abababababababababababababababab";
            const string candidateInstallId = "cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd";
            string root = Path.Combine(
                Path.GetTempPath(),
                "baseball-reset-progress-" + Guid.NewGuid().ToString("N"));
            string path = InstallScopedLocalStatePolicy.ResetJournalPath(root);
            try
            {
                var journal = new InstallResetJournal(path);
                journal.Prepare(previousInstallId, candidateInstallId);
                var repositoryResetCount = 0;
                string canonicalProgress = "old-progress";

                InstallResetJournalRecord firstStartup = journal.Read().Record;
                Assert.That(firstStartup.RequiresRepositoryReset, Is.True);
                if (firstStartup.RequiresRepositoryReset)
                {
                    canonicalProgress = null;
                    repositoryResetCount++;
                    Assert.That(journal.Mark(InstallResetStep.RepositoryReset), Is.True);
                }
                Assert.That(journal.Mark(InstallResetStep.IdentityPublished), Is.True);

                canonicalProgress = "new-progress-after-reset-open";
                var restarted = new InstallResetJournal(path);
                InstallResetJournalRecord secondStartup = restarted.Read().Record;
                Assert.That(secondStartup.RequiresRepositoryReset, Is.False);
                if (secondStartup.RequiresRepositoryReset)
                {
                    canonicalProgress = null;
                    repositoryResetCount++;
                }

                Assert.That(repositoryResetCount, Is.EqualTo(1));
                Assert.That(canonicalProgress, Is.EqualTo("new-progress-after-reset-open"),
                    "pending analytics/review/reminder cleanup must not erase new progress");
            }
            finally
            {
                if (Directory.Exists(root)) Directory.Delete(root, true);
            }
        }

        [Test]
        public void ResetJournalFailsClosedOnTamperAndCannotBeReplacedAfterPrepare()
        {
            const string previousInstallId = "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee";
            const string candidateInstallId = "ffffffffffffffffffffffffffffffff";
            string root = Path.Combine(
                Path.GetTempPath(),
                "baseball-reset-journal-invalid-" + Guid.NewGuid().ToString("N"));
            string path = InstallScopedLocalStatePolicy.ResetJournalPath(root);
            try
            {
                var journal = new InstallResetJournal(path);
                journal.Prepare(previousInstallId, candidateInstallId);
                Assert.Throws<InvalidOperationException>(() => journal.Prepare(
                    previousInstallId,
                    "11111111111111111111111111111111"));
                Assert.That(journal.Read().Record.CandidateInstallId,
                    Is.EqualTo(candidateInstallId),
                    "a durable reset intent is irrevocable until every cleanup receipt completes");
                string tampered = File.ReadAllText(path).Replace("steps=0", "steps=1");
                File.WriteAllText(path, tampered);
                InstallResetJournalReadResult invalid = new InstallResetJournal(path).Read();
                Assert.That(invalid.Status, Is.EqualTo(InstallResetJournalStatus.Invalid));
                Assert.That(invalid.Diagnostic, Is.EqualTo("reset.journal_checksum"));
                Assert.Throws<InvalidDataException>(() =>
                    new InstallResetJournal(path).Mark(InstallResetStep.RepositoryReset));
            }
            finally
            {
                if (Directory.Exists(root)) Directory.Delete(root, true);
            }
        }

        [Test]
        public void AnonymousIdentityStartupAndPublishBothReconcileInstallDirectories()
        {
            string source = File.ReadAllText(FindFromParents(Path.Combine(
                "apps", "android-unity", "Assets", "Game", "Platform", "Identity",
                "AnonymousInstallIdentity.cs")));

            Assert.That(
                source.Split(new[] { "ReconcileInstallLocalState(" },
                    StringSplitOptions.None).Length - 1,
                Is.EqualTo(4),
                "pending-reset startup, existing-ID startup, and ID publication must reconcile stale epochs");
            Assert.That(source, Does.Contain(
                "InstallScopedLocalStateReconciler.KeepOnlyCurrentInstall("));
            Assert.That(source, Does.Contain("Cleanup is retried on the next GetOrCreate"));
            Assert.That(source, Does.Contain(
                "throw new InvalidDataException(\"install.identity_invalid\")"));
            Assert.That(source, Does.Not.Contain(
                "return Guid.NewGuid().ToString(\"N\")"),
                "a storage failure must reach the startup retry boundary instead of publishing an ephemeral ID");
        }

        [Test]
        public void ResetJournalProductionWiringConvergesBeforeStoreOpenAndFinalizesAfterCleanup()
        {
            string runtime = ProductionRuntimeSource();
            string factory = File.ReadAllText(FindFromParents(Path.Combine(
                "apps", "android-unity", "Assets", "Game", "Bootstrap",
                "RuntimeGameComposition.cs")));
            string analytics = File.ReadAllText(FindFromParents(Path.Combine(
                "apps", "android-unity", "Assets", "Game", "Platform", "Analytics",
                "AnalyticsBootstrap.cs")));
            string review = File.ReadAllText(FindFromParents(Path.Combine(
                "apps", "android-unity", "Assets", "Game", "Platform", "Review",
                "PlayReviewPrompt.cs")));
            string reminder = File.ReadAllText(FindFromParents(Path.Combine(
                "apps", "android-unity", "Assets", "Game", "Platform", "Notifications",
                "AndroidReminderService.cs")));

            int prepare = runtime.IndexOf(
                "AnonymousInstallIdentity.PrepareReset(previousInstallId, newInstallId)",
                StringComparison.Ordinal);
            int cancelOs = runtime.IndexOf("reminders?.PrepareLocalReset()", StringComparison.Ordinal);
            int resetSave = runtime.IndexOf(
                "await _store.ResetWithPreparedIdentityAsync(",
                prepare,
                StringComparison.Ordinal);
            int repositoryReceipt = runtime.IndexOf(
                "InstallResetStep.RepositoryReset",
                resetSave,
                StringComparison.Ordinal);
            int publishIdentity = runtime.IndexOf(
                "AnonymousInstallIdentity.PublishPreparedReset(installId)",
                StringComparison.Ordinal);
            int cleanup = runtime.IndexOf(
                "AnalyticsBootstrap.ResetIdentityAndOnceFlags(newInstallId)",
                StringComparison.Ordinal);
            int finish = runtime.IndexOf(
                "AnonymousInstallIdentity.TryCompletePreparedReset()",
                StringComparison.Ordinal);
            Assert.That(prepare, Is.GreaterThanOrEqualTo(0));
            Assert.That(cancelOs, Is.GreaterThan(prepare));
            Assert.That(resetSave, Is.GreaterThan(cancelOs));
            Assert.That(repositoryReceipt, Is.GreaterThan(resetSave));
            Assert.That(publishIdentity, Is.GreaterThan(repositoryReceipt));
            Assert.That(cleanup, Is.GreaterThan(publishIdentity));
            Assert.That(finish, Is.GreaterThan(cleanup));
            Assert.That(runtime, Does.Contain("ResetWithPreparedIdentityAsync"));
            Assert.That(runtime, Does.Contain("ResetRequiresRestart"));
            Assert.That(runtime, Does.Not.Contain("CancelPreparedResetAfterRollback("));

            int startupReset = factory.IndexOf(
                "await repository.ResetAsync(cancellationToken)",
                StringComparison.Ordinal);
            int startupPublish = factory.IndexOf(
                "AnonymousInstallIdentity.PublishPreparedReset(",
                StringComparison.Ordinal);
            int open = factory.IndexOf("GameApplicationStore.OpenAsync(", StringComparison.Ordinal);
            Assert.That(startupReset, Is.GreaterThanOrEqualTo(0));
            Assert.That(startupPublish, Is.GreaterThan(startupReset));
            Assert.That(open, Is.GreaterThan(startupPublish));
            Assert.That(factory, Does.Contain("reset.bootstrap_install_mismatch"));
            Assert.That(factory, Does.Contain("if (reset.Record.RequiresRepositoryReset)"));
            Assert.That(factory, Does.Contain("AndroidShareService.TryClearShareCache()"));
            Assert.That(factory, Does.Contain("InstallResetStep.ShareCacheCleaned"));

            string identity = File.ReadAllText(FindFromParents(Path.Combine(
                "apps", "android-unity", "Assets", "Game", "Platform", "Identity",
                "AnonymousInstallIdentity.cs")));
            Assert.That(identity, Does.Contain(
                "if (!MarkPreparedResetStep(InstallResetStep.IdentityPublished))"));
            Assert.That(identity, Does.Contain("reset.identity_receipt_failed"));

            Assert.That(analytics, Does.Contain("InstallResetStep.AnalyticsCleaned"));
            Assert.That(analytics, Does.Contain("TryReconcilePreparedLocalState()"));
            Assert.That(analytics, Does.Contain("finally\n            {\n                AcknowledgePreparedResetCleanup();"));
            Assert.That(review, Does.Contain("InstallResetStep.ReviewCleaned"));
            Assert.That(review, Does.Contain("TryReconcilePreparedLocalState()"));
            Assert.That(reminder, Does.Contain("InstallResetStep.ReminderCleaned"));
            Assert.That(reminder, Does.Contain("CancelAllReminders();"));
            Assert.That(reminder, Does.Contain("TombstoneAndClearCurrentReminderIntent();"));
        }

        [Test]
        public void PreparedResetFailurePoisonsOldStoreAndSuppressesLifecyclePersistence()
        {
            string store = File.ReadAllText(FindFromParents(Path.Combine(
                "apps", "android-unity", "Assets", "Game", "Application", "Stores",
                "GameApplicationStore.cs")));
            string lifecycle = File.ReadAllText(FindFromParents(Path.Combine(
                "apps", "android-unity", "Assets", "Game", "Bootstrap",
                "RuntimeGameCoordinator.cs")));

            Assert.That(store, Does.Contain("private volatile bool _persistencePoisoned"));
            Assert.That(store, Does.Contain("public bool IsPersistencePoisoned"));
            Assert.That(store, Does.Contain("GamePersistencePoisonedException"));
            Assert.That(store, Does.Contain(
                "if (!rollbackOnIdentityCommitFailure) _persistencePoisoned = true;"));
            Assert.That(store, Does.Contain("_persistencePoisoned = false;"));
            Assert.That(lifecycle, Does.Contain("if (store.IsPersistencePoisoned) return;"));
            Assert.That(lifecycle, Does.Contain(
                "if (store.IsPersistencePoisoned) return Task.CompletedTask;"));
        }

        [Test]
        public void ShareFileProviderRejectsEveryMutationIncludingDelete()
        {
            string projectRelative = Path.Combine(
                "Assets", "Plugins", "Android", "BaseballManifest.androidlib", "src", "main",
                "java", "com", "solkim", "baseball", "platform", "ShareFileProvider.java");
            string repositoryRelative = Path.Combine("apps", "android-unity", projectRelative);
            string path = File.Exists(projectRelative) ? projectRelative : FindFromParents(repositoryRelative);
            string source = File.ReadAllText(path);

            Assert.That(source, Does.Contain("Uri insert(Uri uri, ContentValues values)"));
            Assert.That(source, Does.Contain("int update(Uri uri, ContentValues values"));
            Assert.That(source, Does.Contain("int delete(Uri uri, String selection"));
            int deleteStart = source.IndexOf("int delete(Uri uri, String selection", StringComparison.Ordinal);
            int deleteEnd = source.IndexOf("private File resolveFile", deleteStart, StringComparison.Ordinal);
            string deleteBody = source.Substring(deleteStart, deleteEnd - deleteStart);
            Assert.That(deleteBody, Does.Contain("throw new UnsupportedOperationException"));
            Assert.That(deleteBody, Does.Not.Contain(".delete()"));
        }

        private static string ProductionRuntimeSource()
        {
            string sample = FindFromParents(Path.Combine(
                "apps", "android-unity", "Assets", "Game", "Presentation", "Shell",
                "ProductionBaseballShellRuntime.cs"));
            string directory = Path.GetDirectoryName(sample);
            return string.Join(
                "\n",
                Directory.GetFiles(directory, "ProductionBaseballShellRuntime*.cs")
                    .OrderBy(path => path, StringComparer.Ordinal)
                    .Select(File.ReadAllText));
        }

        private static string FindFromParents(string relativePath)
        {
            DirectoryInfo current = new DirectoryInfo(TestContext.CurrentContext.TestDirectory);
            while (current != null)
            {
                string candidate = Path.Combine(current.FullName, relativePath);
                if (File.Exists(candidate)) return candidate;
                current = current.Parent;
            }
            throw new FileNotFoundException("Repository contract source was not found.", relativePath);
        }
    }
}
