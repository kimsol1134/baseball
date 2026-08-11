using System;
using Baseball.Application.Meta;
using Baseball.Application.Persistence;

namespace Baseball.Presentation.Shell
{
    public static class ReturnPlanPresentationPolicy
    {
        public static ReturnPlanState Welcome(GameSaveAggregate state, DateTimeOffset now)
        {
            if (state?.Meta == null) return null;
            return Welcome(
                state.Meta.ReturnPlan,
                ReturnPlanRules.CurrentPlan(state),
                state.Meta.ReturnWelcomeHandled,
                now);
        }

        public static ReturnPlanState Welcome(
            ReturnPlanState previous,
            ReturnPlanState current,
            ReturnWelcomeHandledState handled,
            DateTimeOffset now) =>
            ReturnPlanRules.WelcomePlan(previous, current, handled, now);

        public static bool ShouldHoldOpening(GameSaveAggregate state, DateTimeOffset now) =>
            Welcome(state, now) != null;

        public static bool ShouldHoldOpening(
            ReturnPlanState previous,
            ReturnPlanState current,
            ReturnWelcomeHandledState handled,
            DateTimeOffset now) =>
            Welcome(previous, current, handled, now) != null;

        public static ReturnPlanState PersonalizedNotification(ReturnPlanState plan)
        {
            return plan != null && !plan.Dismissed &&
                plan.Destination != ReturnPlanDestination.DailyInning &&
                string.Equals(plan.ExperimentVariant, "guided", StringComparison.Ordinal)
                ? plan
                : null;
        }
    }
}
