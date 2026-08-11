using Baseball.Presentation.Shell;
using NUnit.Framework;

namespace Baseball.Presentation.Tests.Screens
{
    public sealed class CareerActionSelectionPolicyTests
    {
        [Test]
        public void HighSchoolBreakingBallRequiresTargetAndDropsStaleTargetForOtherFocus()
        {
            Assert.That(CareerActionSelectionPolicy.TrainingPayload(
                "breaking_ball", "standard", null, true), Is.Null);
            Assert.That(CareerActionSelectionPolicy.TrainingPayload(
                "breaking_ball", "standard", "slider", true),
                Is.EqualTo("breaking_ball:standard:slider"));
            Assert.That(CareerActionSelectionPolicy.TrainingPayload(
                "velocity", "standard", "stale-slider", true),
                Is.EqualTo("velocity:standard"));
        }

        [Test]
        public void ProMovementPlanRequiresTargetAndDropsStaleTargetForOtherPlan()
        {
            Assert.That(CareerActionSelectionPolicy.ProWeekPayload(
                "develop_movement", null, true), Is.Null);
            Assert.That(CareerActionSelectionPolicy.ProWeekPayload(
                "develop_movement", "curveball", true),
                Is.EqualTo("develop_movement|curveball"));
            Assert.That(CareerActionSelectionPolicy.ProWeekPayload(
                "develop_stuff", "stale-curveball", true),
                Is.EqualTo("develop_stuff"));
        }
    }
}
