using Baseball.Application.Meta;
using Baseball.Presentation.Shell;
using NUnit.Framework;

namespace Baseball.Presentation.Tests.Screens
{
    public sealed class WeeklyOpenAnalyticsPolicyTests
    {
        [Test]
        public void DelayedObserveCannotEmitBeforePersistedProgramExists()
        {
            Assert.That(WeeklyOpenAnalyticsPolicy.CanEmit(null, observeInFlight: true), Is.False);
            Assert.That(WeeklyOpenAnalyticsPolicy.CanEmit(null, observeInFlight: false), Is.False);
        }

        [Test]
        public void SaveFailureKeepsWeeklyOpenSuppressed()
        {
            WeeklyProgramState before = null;
            WeeklyProgramState afterFailedSave = before;

            Assert.That(WeeklyOpenAnalyticsPolicy.CanEmit(afterFailedSave, observeInFlight: false), Is.False);
        }

        [Test]
        public void PersistedProgramCanEmitAfterObserveCompletes()
        {
            var program = new WeeklyProgramState(
                "2026-W33",
                System.Array.Empty<WeeklyTaskState>(),
                System.Array.Empty<string>(),
                claimed: false);

            Assert.That(WeeklyOpenAnalyticsPolicy.CanEmit(program, observeInFlight: true), Is.False);
            Assert.That(WeeklyOpenAnalyticsPolicy.CanEmit(program, observeInFlight: false), Is.True);
        }
    }
}
