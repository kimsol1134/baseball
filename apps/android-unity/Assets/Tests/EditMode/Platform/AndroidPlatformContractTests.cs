using System;
using System.Collections.Generic;
using System.IO;
using Baseball.Platform.Notifications;
using Baseball.Platform.Review;
using Baseball.Platform.Share;
using Baseball.Platform.Identity;
using NUnit.Framework;

namespace Baseball.Platform.Tests
{
    public sealed class AndroidPlatformContractTests
    {
        [Test]
        public void ReviewRequiresOnboardingEnoughPlayAndMeaningfulProgress()
        {
            Assert.That(ReviewPromptPolicy.IsEligible(new ReviewEligibilityContext(
                true, 3, 0, TimeSpan.FromMinutes(30))), Is.True);
            Assert.That(ReviewPromptPolicy.IsEligible(new ReviewEligibilityContext(
                true, 1, 1, TimeSpan.FromMinutes(30))), Is.True);
            Assert.That(ReviewPromptPolicy.IsEligible(new ReviewEligibilityContext(
                false, 10, 3, TimeSpan.FromHours(2))), Is.False);
            Assert.That(ReviewPromptPolicy.IsEligible(new ReviewEligibilityContext(
                true, 3, 0, TimeSpan.FromMinutes(29))), Is.False);
            Assert.That(ReviewPromptPolicy.IsEligible(new ReviewEligibilityContext(
                true, 2, 0, TimeSpan.FromHours(2))), Is.False);
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
            Assert.That(all, Has.Count.EqualTo(3));
            Assert.That(all[0].NotificationId, Is.EqualTo(1930));
            Assert.That(all[1].NotificationId, Is.EqualTo(1931));
            Assert.That(all[2].NotificationId, Is.EqualTo(1932));
            Assert.That(all[0].DayKey, Is.EqualTo("20260811"));

            IReadOnlyList<SeoulReminderEntry> future = SeoulReminderSchedule.Upcoming(after);
            Assert.That(future, Has.Count.EqualTo(2));
            Assert.That(future[0].NotificationId, Is.EqualTo(1931));

            IReadOnlyList<SeoulReminderEntry> unplayed = SeoulReminderSchedule.Upcoming(
                before,
                new[] { "20260811" });
            Assert.That(unplayed, Has.Count.EqualTo(2));
            Assert.That(unplayed[0].NotificationId, Is.EqualTo(1931));
        }

        [Test]
        public void ReminderIntentCarriesOnlyTypedLowCardinalityDestinationAndReason()
        {
            var plan = new AndroidReminderPlan(
                "다시 마운드로",
                "다음 일정을 이어가세요.",
                "high_school",
                "return_plan",
                "20260811");

            string intent = plan.IntentData("20260812");
            Assert.That(AndroidReminderPlan.TryParseIntent(intent, out string destination, out string reason), Is.True);
            Assert.That(destination, Is.EqualTo("high_school"));
            Assert.That(reason, Is.EqualTo("return_plan"));
            Assert.That(intent, Does.Not.Contain("다시 마운드로"));
            Assert.That(intent, Does.Not.Contain("다음 일정을"));
            Assert.That(intent, Does.Contain("experiment_id="));
            Assert.That(intent, Does.Contain("saved_day_key="));
            Assert.That(intent, Does.Contain("development_rules_version="));
            Assert.That(AndroidReminderPlan.TryParseIntent(
                "baseball://reminder?source=return_reminder&destination=external&reason=return_plan",
                out _,
                out _), Is.False);
            Assert.That(AndroidReminderPlan.TryParseIntent(
                "baseball://reminder?source=return_reminder&destination=pro&reason=free_form",
                out _,
                out _), Is.False);

            Assert.That(ReminderOpenPolicy.TryCreate(intent, out ReminderOpenRequest first), Is.True);
            Assert.That(ReminderOpenPolicy.TryCreate(intent, out ReminderOpenRequest repeated), Is.True);
            Assert.That(first.StableTokenHash, Is.EqualTo(repeated.StableTokenHash));
            Assert.That(first.StableTokenHash, Has.Length.EqualTo(16));
            Assert.That(first.StableTokenHash, Does.Not.Contain(plan.Receipt));
            Assert.That(ReminderOpenPolicy.TryCreate(plan.IntentData("20260813"), out ReminderOpenRequest nextDay),
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
            Assert.That(source, Does.Contain("if (!paused)"));
            Assert.That(source, Does.Contain("ScheduleNext();"));

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
            string runtime = File.ReadAllText(FindFromParents(Path.Combine(
                "apps", "android-unity", "Assets", "Game", "Presentation", "Shell",
                "ProductionBaseballShellRuntime.cs")));
            Assert.That(service, Does.Contain("public void RequestEnabled(bool enabled, string source = \"settings\")"));
            Assert.That(service, Does.Contain("EnablementChanged?.Invoke(allowed, source)"));
            Assert.That(service, Does.Contain("ResolvePersistedDenial(bool saved)"));
            Assert.That(service, Does.Not.Contain("AnalyticsEvent.ReminderChanged"));
            Assert.That(runtime, Does.Contain("AndroidReminderService.Instance.RequestEnabled(enabled)"));
            Assert.That(runtime, Does.Contain("reminders.RequestEnabled(true, \"after_first_game\")"));
            Assert.That(runtime, Does.Contain("DrainPendingReminderSetting()"));
            Assert.That(runtime, Does.Contain("if (!busy)"));
            Assert.That(runtime, Does.Contain("DrainPendingReminderOpen()"));
            Assert.That(runtime, Does.Contain("AndroidReminderService.Instance?.ApplySavedEnabled(NotificationsEnabled)"));
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
