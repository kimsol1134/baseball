using System;
using Baseball.Application.HighSchool;
using Baseball.Application.Meta;
using Baseball.Application.Persistence;
using Baseball.Application.Pro;
using Baseball.Presentation.Shell;
using NUnit.Framework;

namespace Baseball.Presentation.Tests.Screens
{
    public sealed class ProRetirementAnalyticsPolicyTests
    {
        [Test]
        public void RetirementUsesRetiredProAndSoulDeltaWithoutReadingPreviousArchive()
        {
            GameSaveAggregate before = State();
            GameSaveAggregate after = before.Commit(
                "retired",
                clearPro: true,
                meta: before.Meta.With(
                    soulBalance: before.Meta.SoulBalance + 17,
                    creditedProCareerIds: new[] { "pro-current" }));

            Assert.That(ProRetirementAnalyticsPolicy.TryProject(before, after, out var value), Is.True);
            Assert.That(value.LifeNumber, Is.EqualTo(4));
            Assert.That(value.ProSeasons, Is.EqualTo(2));
            Assert.That(value.SoulBonus, Is.EqualTo(17));
            Assert.That(value.HasSignatureCandidates, Is.False);
        }

        [Test]
        public void ExistingCreditCannotEmitAgain()
        {
            GameSaveAggregate original = State();
            GameSaveAggregate before = original.Commit(
                "already-credited",
                meta: original.Meta.With(creditedProCareerIds: new[] { "pro-current" }));
            GameSaveAggregate after = before.Commit("unchanged-credit", clearPro: true);

            Assert.That(ProRetirementAnalyticsPolicy.TryProject(before, after, out _), Is.False);
        }

        private static GameSaveAggregate State()
        {
            var oldLife = new LifeArchiveRecord(
                "old-life",
                3,
                "이전 선수",
                "old-hs",
                "old-pro",
                "old-school",
                "별빛고",
                true,
                90,
                new PitcherRatingsReadModel(90, 90, 90, 90),
                new CareerPerformanceReadModel(),
                12,
                999,
                8,
                100,
                999);
            var pro = new ProCareerReadModel(
                "pro-current",
                ProCareerOrigin.Direct,
                ProCareerPhase.Completed,
                "seed",
                5,
                "player",
                "현재 선수",
                "fictional-club",
                "해오름",
                2,
                40,
                new PitcherRatingsReadModel(70, 68, 66, 65),
                new CareerPerformanceReadModel(),
                careerSeasons: new[]
                {
                    new ProSeasonLineReadModel(1, "fictional-club", 10, 60, 50, 12, 4),
                    new ProSeasonLineReadModel(2, "fictional-club", 12, 72, 66, 15, 6),
                });
            return GameSaveAggregate.Initial("install").Commit(
                "active-pro",
                stage: ApplicationStage.Pro,
                pro: pro,
                meta: new MetaProgressState(lifeNumber: 4, soulBalance: 10, lifeArchive: new[] { oldLife }));
        }
    }
}
