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

        [TestCase("daily-inning")]
        [TestCase("daily_inning")]
        public void GuidedLegacyDailyRouteNeverCreatesPersonalizedNotification(string route)
        {
            var plan = new ReturnPlanState(
                route,
                "이전 일일 도전",
                "오늘 기록 열기",
                "2026-08-11",
                body: "종료된 화면의 저장 데이터입니다.",
                reason: "legacy",
                experimentId: ReturnPlanRules.ReturnExperimentId,
                receiptId: "legacy-daily-receipt",
                savedDayKey: "2026-08-11",
                experimentVariant: "guided",
                developmentRulesVersion: ReturnPlanRules.CurrentDevelopmentRulesVersion);

            Assert.That(plan.Destination, Is.EqualTo(ReturnPlanDestination.HighSchool),
                "legacy route constructor mapping must not hide the raw retired route");
            Assert.That(ReturnPlanRules.IsRetiredDailyPlan(plan), Is.True);
            Assert.That(ReturnPlanPresentationPolicy.PersonalizedNotification(plan), Is.Null);
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
