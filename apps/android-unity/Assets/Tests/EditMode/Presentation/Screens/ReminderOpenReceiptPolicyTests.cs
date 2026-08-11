using Baseball.Presentation.Shell;
using NUnit.Framework;

namespace Baseball.Presentation.Tests.Screens
{
    public sealed class ReminderOpenReceiptPolicyTests
    {
        [Test]
        public void StartupWaitsForReadyStoreBeforePersisting()
        {
            Assert.That(ReminderOpenReceiptPolicy.BeforeDispatch(false, false, false, false),
                Is.EqualTo(ReminderOpenReceiptAction.Wait));
            Assert.That(ReminderOpenReceiptPolicy.BeforeDispatch(true, true, false, false),
                Is.EqualTo(ReminderOpenReceiptAction.Wait));
            Assert.That(ReminderOpenReceiptPolicy.BeforeDispatch(true, false, false, false),
                Is.EqualTo(ReminderOpenReceiptAction.PersistAnalytics));
        }

        [Test]
        public void SaveFailurePreservesPendingRequestAndHasNoSideEffect()
        {
            Assert.That(ReminderOpenReceiptPolicy.AfterAnalyticsDispatch(false, false, false),
                Is.EqualTo(ReminderOpenReceiptAction.Wait));
            Assert.That(ReminderOpenReceiptPolicy.CanCompletePlatformRequest(false), Is.False);
        }

        [Test]
        public void AppliedAnalyticsReceiptPresentsNavigationButDoesNotCompleteRequestYet()
        {
            Assert.That(ReminderOpenReceiptPolicy.AfterAnalyticsDispatch(true, true, false),
                Is.EqualTo(ReminderOpenReceiptAction.PresentNavigation));
            Assert.That(ReminderOpenReceiptPolicy.CanCompletePlatformRequest(false), Is.False);
        }

        [Test]
        public void ProcessDeathAfterAnalyticsReceiptRecoversRouteWithoutAnotherSdkEvent()
        {
            Assert.That(ReminderOpenReceiptPolicy.BeforeDispatch(true, false, true, false),
                Is.EqualTo(ReminderOpenReceiptAction.PresentNavigation));
            Assert.That(ReminderOpenReceiptPolicy.AfterAnalyticsDispatch(false, true, false),
                Is.EqualTo(ReminderOpenReceiptAction.PresentNavigation));
        }

        [Test]
        public void RepeatedOsIntentAfterNavigationReceiptDoesNothingAndCanBeCleared()
        {
            Assert.That(ReminderOpenReceiptPolicy.BeforeDispatch(true, false, true, true),
                Is.EqualTo(ReminderOpenReceiptAction.CompleteHandled));
            Assert.That(ReminderOpenReceiptPolicy.AfterAnalyticsDispatch(false, true, true),
                Is.EqualTo(ReminderOpenReceiptAction.CompleteHandled));
            Assert.That(ReminderOpenReceiptPolicy.CanCompletePlatformRequest(true), Is.True);
        }
    }
}
