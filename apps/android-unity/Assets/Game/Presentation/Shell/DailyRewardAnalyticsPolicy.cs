using System;
using System.Linq;
using Baseball.Application.Meta;
using Baseball.Application.Persistence;

namespace Baseball.Presentation.Shell
{
    /// <summary>
    /// Projects only the first durably credited Seoul-day reward into analytics. A replay or a
    /// second daily inning may complete successfully, but it must not fabricate a zero-point
    /// reward event.
    /// </summary>
    public static class DailyRewardAnalyticsPolicy
    {
        public static string RewardId(DateTimeOffset completedAt) =>
            DailyInningRules.RewardId(SeoulGameCalendar.DayKey(completedAt));

        public static bool TryProject(
            GameSaveAggregate before,
            GameSaveAggregate after,
            DateTimeOffset completedAt,
            out int soulPoints)
        {
            soulPoints = Math.Max(
                0,
                (after?.Meta?.SoulBalance ?? 0) - (before?.Meta?.SoulBalance ?? 0));
            if (before?.Meta == null || after?.Meta == null || soulPoints <= 0) return false;

            string rewardId = RewardId(completedAt);
            bool wasCredited = before.Meta.CreditedRewardIds.Contains(
                rewardId,
                StringComparer.Ordinal);
            bool isCredited = after.Meta.CreditedRewardIds.Contains(
                rewardId,
                StringComparer.Ordinal);
            return !wasCredited && isCredited;
        }
    }
}
