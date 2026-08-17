using System;
using System.Collections.Generic;
using System.Linq;
using Baseball.Application.Commands;
using Baseball.Application.HighSchool;
using Baseball.Application.Meta;
using Baseball.Application.Persistence;
using Baseball.Application.Pro;
using Baseball.Core.Domain;
using Baseball.Core.Pitching;

namespace Baseball.Application.Stores
{
    public sealed partial class GameCommandTransition
    {

        private static TransitionResult<GameSaveAggregate> ConfigureWeekly(
            GameSaveAggregate current,
            ConfigureWeeklyProgramCommand command,
            string commandId)
        {
            var weekly = WeeklyProgramRules.Configure(
                current.Meta.Weekly,
                command.Eligibility,
                current.InstallId,
                command.ObservedAt);
            return Success(current.Commit(commandId, meta: current.Meta.With(weekly: weekly)));
        }

        private static TransitionResult<GameSaveAggregate> RecordWeekly(
            GameSaveAggregate current,
            RecordWeeklyProgressCommand command,
            string commandId)
        {
            if (!WeeklyTaskKinds.All.Contains(command.Kind, StringComparer.Ordinal) ||
                command.Amount <= 0 || string.IsNullOrWhiteSpace(command.ReceiptId))
            {
                return Failure("weekly.progress_invalid");
            }
            if (string.Equals(
                    command.Kind,
                    WeeklyTaskKinds.DailyInningCompleted,
                    StringComparison.Ordinal))
            {
                return Failure("daily.retired");
            }
            var weekly = WeeklyProgramRules.Record(
                current.Meta.Weekly,
                command.Kind,
                command.Amount,
                command.ReceiptId,
                command.OccurredAt);
            var daily = command.CountsAsBaseball
                ? DailyStreakRules.RecordBaseball(current.Meta.Daily, command.OccurredAt)
                : current.Meta.Daily;
            return Success(current.Commit(
                commandId,
                meta: current.Meta.With(weekly: weekly, daily: daily)));
        }

        private static TransitionResult<GameSaveAggregate> ClaimWeekly(
            GameSaveAggregate current,
            ClaimWeeklyRewardCommand command,
            string commandId)
        {
            var program = current.Meta.Weekly.Program;
            if (program == null || !program.RewardReady) return Failure("weekly.reward_not_ready");
            var rewardId = "weekly-" + program.WeekKey;
            var alreadyCredited = current.Meta.CreditedRewardIds.Contains(rewardId, StringComparer.Ordinal);
            var weekly = WeeklyProgramRules.Claim(current.Meta.Weekly, command.ClaimedAt);
            if (ReferenceEquals(weekly, current.Meta.Weekly)) return Failure("weekly.reward_not_ready");
            var meta = current.Meta.With(
                soulBalance: alreadyCredited
                    ? current.Meta.SoulBalance
                    : current.Meta.SoulBalance + WeeklyProgramRules.RewardSoul,
                soulLifetimeEarned: alreadyCredited
                    ? current.Meta.SoulLifetimeEarned
                    : current.Meta.SoulLifetimeEarned + WeeklyProgramRules.RewardSoul,
                automaticSoulEarned: alreadyCredited
                    ? current.Meta.AutomaticSoulEarned
                    : current.Meta.AutomaticSoulEarned + WeeklyProgramRules.RewardSoul,
                creditedRewardIds: alreadyCredited
                    ? current.Meta.CreditedRewardIds
                    : current.Meta.CreditedRewardIds.Concat(new[] { rewardId }).ToArray(),
                weekly: weekly);
            return Success(current.Commit(commandId, meta: meta));
        }

        private static TransitionResult<GameSaveAggregate> UnlockAchievements(
            GameSaveAggregate current,
            UnlockAchievementsCommand command,
            string commandId)
        {
            var achievements = AchievementRules.Unlock(
                current.Meta.Achievements,
                command.AchievementIds);
            return Success(current.Commit(
                commandId,
                meta: current.Meta.With(achievements: achievements)));
        }

        private static TransitionResult<GameSaveAggregate> AcknowledgeAchievement(
            GameSaveAggregate current,
            AcknowledgeAchievementCommand command,
            string commandId)
        {
            if (string.IsNullOrWhiteSpace(command.AchievementId))
                return Failure("achievement.id_invalid");
            var achievements = AchievementRules.Acknowledge(
                current.Meta.Achievements,
                command.AchievementId);
            return Success(current.Commit(
                commandId,
                meta: current.Meta.With(achievements: achievements)));
        }

        private static TransitionResult<GameSaveAggregate> MarkAnalyticsReceipt(
            GameSaveAggregate current,
            MarkAnalyticsReceiptCommand command,
            string commandId)
        {
            if (!AnalyticsReceiptRules.IsValidScope(command.ScopeId))
                return Failure("analytics.scope_invalid");
            if (!Enum.IsDefined(typeof(AnalyticsReceiptRetention), command.Retention))
                return Failure("analytics.retention_invalid");
            if (current.AnalyticsReceipts.Contains(command.ScopeId))
                return Failure("analytics.already_marked");
            if (command.Retention == AnalyticsReceiptRetention.Lifetime &&
                current.AnalyticsReceipts.Records.Count(value =>
                    value.Retention == AnalyticsReceiptRetention.Lifetime) >=
                AnalyticsReceiptState.MaximumLifetimeReceipts)
            {
                return Failure("analytics.lifetime_capacity");
            }
            var receipts = AnalyticsReceiptRules.Mark(
                current.AnalyticsReceipts,
                command.ScopeId,
                command.RecordedAt,
                command.Retention);
            return Success(current.Commit(
                commandId,
                analyticsReceipts: receipts));
        }

        private static TransitionResult<GameSaveAggregate> SetNextRunIntent(
            GameSaveAggregate current,
            SetNextRunIntentCommand command,
            string commandId)
        {
            if (string.IsNullOrWhiteSpace(command.Intent.PledgeId) ||
                !RunPledgeRules.IsKnownCurrentId(command.Intent.PledgeId) ||
                command.Intent.SourceLifeNumber <= 0 ||
                command.Intent.SourceLifeNumber > current.Meta.LifeNumber ||
                string.IsNullOrWhiteSpace(command.Intent.Reason))
            {
                return Failure("next_run_intent.invalid");
            }
            return Success(current.Commit(
                commandId,
                meta: current.Meta.With(nextRunIntent: command.Intent)));
        }

        private static TransitionResult<GameSaveAggregate> SetReturnPlan(
            GameSaveAggregate current,
            SetReturnPlanCommand command,
            string commandId)
        {
            if (ReturnPlanRules.IsRetiredDailyPlan(command.Plan))
            {
                return Failure("daily.retired");
            }
            if (!ReturnPlanRules.IsValid(command.Plan))
            {
                return Failure("return_plan.invalid");
            }
            var plan = ReturnPlanRules.CarryingReceipt(
                command.Plan,
                current.Meta.ReturnPlan);
            return Success(current.Commit(
                commandId,
                meta: current.Meta.With(returnPlan: plan)));
        }

        private static TransitionResult<GameSaveAggregate> PrepareReturnPlan(
            GameSaveAggregate current,
            PrepareReturnPlanCommand command,
            string commandId)
        {
            if (command.DevelopmentRulesVersion <= 0)
                return Failure("return_plan.rules_version_invalid");
            var plan = ReturnPlanRules.PrepareForNextReturn(
                current,
                current.InstallId,
                command.DevelopmentRulesVersion,
                command.PreparedAt);
            if (plan == null) return Failure("return_plan.ineligible");
            var receipts = current.AnalyticsReceipts;
            var receiptScope = ReturnPlanRules.EligibleReceiptScope(plan);
            if (receiptScope != null && !receipts.Contains(receiptScope))
            {
                receipts = AnalyticsReceiptRules.Mark(
                    receipts,
                    receiptScope,
                    command.PreparedAt,
                    AnalyticsReceiptRetention.Scoped);
            }
            return Success(current.Commit(
                commandId,
                meta: current.Meta.With(returnPlan: plan),
                analyticsReceipts: receipts));
        }

        private static TransitionResult<GameSaveAggregate> CompleteReturnPlanInteraction(
            GameSaveAggregate current,
            CompleteReturnPlanInteractionCommand command,
            string commandId)
        {
            var plan = current.Meta.ReturnPlan;
            if (plan == null) return Failure("return_plan.missing");
            var handled = ReturnPlanRules.MarkWelcomeHandled(plan, command.HandledAt);
            return Success(current.Commit(
                commandId,
                meta: current.Meta.With(
                    returnPlan: plan.WithDismissed(command.Dismissed),
                    returnWelcomeHandled: handled)));
        }

        private static TransitionResult<GameSaveAggregate> DismissReturnPlan(
            GameSaveAggregate current,
            DismissReturnPlanCommand command,
            string commandId)
        {
            var currentPlan = current.Meta.ReturnPlan;
            if (currentPlan == null) return Failure("return_plan.missing");
            var dismissed = currentPlan.WithDismissed(true);
            var handled = command.HandledAt.HasValue
                ? ReturnPlanRules.MarkWelcomeHandled(currentPlan, command.HandledAt.Value)
                : current.Meta.ReturnWelcomeHandled;
            return Success(current.Commit(
                commandId,
                meta: current.Meta.With(
                    returnPlan: dismissed,
                    returnWelcomeHandled: handled)));
        }
    }
}
