using System;
using System.Linq;
using Baseball.Application.Persistence;
using Baseball.Presentation.Shell;
using NUnit.Framework;

namespace Baseball.Presentation.Tests.Screens
{
    public sealed class DailyRewardAnalyticsPolicyTests
    {
        private static readonly DateTimeOffset CompletedAt =
            new DateTimeOffset(2026, 8, 11, 12, 0, 0, TimeSpan.Zero);

        [Test]
        public void FirstDurableSeoulDayCreditEmitsActualSoulDelta()
        {
            GameSaveAggregate before = GameSaveAggregate.Initial("install");
            string rewardId = DailyRewardAnalyticsPolicy.RewardId(CompletedAt);
            GameSaveAggregate after = before.Commit(
                "daily-first",
                meta: before.Meta.With(
                    soulBalance: before.Meta.SoulBalance + 5,
                    soulLifetimeEarned: before.Meta.SoulLifetimeEarned + 5,
                    creditedRewardIds: before.Meta.CreditedRewardIds.Concat(new[] { rewardId }).ToArray()));

            bool emit = DailyRewardAnalyticsPolicy.TryProject(
                before,
                after,
                CompletedAt,
                out int soulPoints);

            Assert.That(emit, Is.True);
            Assert.That(soulPoints, Is.EqualTo(5));
        }

        [Test]
        public void SameDayRetryDoesNotEmitAZeroPointRewardOrCreateAnotherEventScope()
        {
            string rewardId = DailyRewardAnalyticsPolicy.RewardId(CompletedAt);
            GameSaveAggregate credited = GameSaveAggregate.Initial("install").Commit(
                "daily-first",
                meta: GameSaveAggregate.Initial("unused").Meta.With(
                    soulBalance: 5,
                    soulLifetimeEarned: 5,
                    creditedRewardIds: new[] { rewardId }));
            GameSaveAggregate retry = credited.Commit("daily-retry", meta: credited.Meta);

            bool emit = DailyRewardAnalyticsPolicy.TryProject(
                credited,
                retry,
                CompletedAt,
                out int soulPoints);

            Assert.That(emit, Is.False);
            Assert.That(soulPoints, Is.Zero);
            Assert.That(DailyRewardAnalyticsPolicy.RewardId(CompletedAt), Is.EqualTo(rewardId));
        }

        [Test]
        public void ReceiptWithoutPositiveSavedDeltaFailsClosed()
        {
            GameSaveAggregate before = GameSaveAggregate.Initial("install");
            string rewardId = DailyRewardAnalyticsPolicy.RewardId(CompletedAt);
            GameSaveAggregate after = before.Commit(
                "invalid-credit",
                meta: before.Meta.With(creditedRewardIds: new[] { rewardId }));

            Assert.That(DailyRewardAnalyticsPolicy.TryProject(
                before,
                after,
                CompletedAt,
                out int soulPoints), Is.False);
            Assert.That(soulPoints, Is.Zero);
        }
    }
}
