using Baseball.Application.Meta;
using Baseball.Presentation.Shell;
using NUnit.Framework;

namespace Baseball.Presentation.Tests.Screens
{
    public sealed class RunPledgeAnalyticsPolicyTests
    {
        [Test]
        public void ConsumedMatchingIntentStillMarksSelectionRecommendedAndApplied()
        {
            var before = new NextRunIntentState("control-master", 1, "missed_pledge");
            NextRunIntentState after = null;

            Assert.That(RunPledgeAnalyticsPolicy.WasRecommended(before, "control-master"), Is.True);
            Assert.That(after, Is.Null, "successful selection consumes the post-command intent");
            Assert.That(RunPledgeAnalyticsPolicy.WasRecommended(before, "power-route"), Is.False);
            Assert.That(RunPledgeAnalyticsPolicy.WasRecommended(before, null), Is.False);
        }
    }
}
