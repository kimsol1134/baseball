using System;
using Baseball.Application.Meta;
using Baseball.Presentation.Shell;
using NUnit.Framework;

namespace Baseball.Tests.EditMode.Presentation.Screens
{
    public sealed class ReturnPlanPresentationPolicyTests
    {
        private static readonly DateTimeOffset Now =
            new DateTimeOffset(2026, 8, 11, 12, 0, 0, TimeSpan.Zero);

        [Test]
        public void HoldoutGetsNeitherWelcomeCardNorPersonalizedNotification()
        {
            ReturnPlanState plan = Plan("holdout");

            Assert.That(ReturnPlanPresentationPolicy.Welcome(plan, plan, null, Now), Is.Null);
            Assert.That(ReturnPlanPresentationPolicy.PersonalizedNotification(plan), Is.Null);
            Assert.That(ReturnPlanPresentationPolicy.ShouldHoldOpening(plan, plan, null, Now), Is.False);
        }

        [Test]
        public void GuidedGetsBothUntilSameDayWelcomeIsHandled()
        {
            ReturnPlanState plan = Plan("guided");
            ReturnPlanState visible = ReturnPlanPresentationPolicy.Welcome(plan, plan, null, Now);
            Assert.That(visible, Is.Not.Null);
            Assert.That(ReturnPlanPresentationPolicy.PersonalizedNotification(plan), Is.SameAs(plan));
            Assert.That(ReturnPlanPresentationPolicy.ShouldHoldOpening(plan, plan, null, Now), Is.True);

            ReturnWelcomeHandledState handled = ReturnPlanRules.MarkWelcomeHandled(plan, Now);
            Assert.That(ReturnPlanPresentationPolicy.Welcome(plan, plan, handled, Now), Is.Null);
            Assert.That(ReturnPlanPresentationPolicy.ShouldHoldOpening(plan, plan, handled, Now), Is.False);
        }

        private static ReturnPlanState Plan(string variant) => ReturnPlanState.Create(
            "이번 선수의 목표가 남아 있습니다",
            "다음 일정을 이어서 완성해 보세요.",
            ReturnPlanDestination.HighSchool,
            "high_school_phase",
            ReturnPlanRules.ReturnExperimentId,
            "0123456789abcdef",
            "2026-08-11",
            variant,
            ReturnPlanRules.CurrentDevelopmentRulesVersion);
    }
}
