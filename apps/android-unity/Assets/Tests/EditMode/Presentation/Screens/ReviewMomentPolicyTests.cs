using System;
using Baseball.Application.HighSchool;
using Baseball.Application.Meta;
using Baseball.Application.Persistence;
using Baseball.Application.Pro;
using Baseball.Platform.Review;
using Baseball.Presentation.Shell;
using NUnit.Framework;

namespace Baseball.Presentation.Tests.Screens
{
    public sealed class ReviewMomentPolicyTests
    {
        [Test]
        public void ThirdLifeRequiresANewNonChallengeCareer()
        {
            GameSaveAggregate before = GameSaveAggregate.Initial("install").Commit(
                "setup",
                stage: ApplicationStage.Setup,
                meta: new MetaProgressState(lifeNumber: 3));
            GameSaveAggregate after = before.Commit(
                "start",
                stage: ApplicationStage.HighSchool,
                highSchool: Career("career-3", 3, false));
            Assert.That(ReviewMomentPolicy.ReasonAfter(
                "start_high_school", before, after), Is.EqualTo(ReviewPromptReason.ThirdLife));

            Assert.That(ReviewMomentPolicy.ReasonAfter(
                "start_high_school", after, after), Is.Null,
                "a re-render or duplicate observation is not a new review moment");
            GameSaveAggregate challenge = before.Commit(
                "challenge",
                stage: ApplicationStage.HighSchool,
                highSchool: Career("challenge-3", 3, true));
            Assert.That(ReviewMomentPolicy.ReasonAfter(
                "start_high_school", before, challenge), Is.Null);
        }

        [Test]
        public void DraftReviewWaitsForTheLinkedContractSurface()
        {
            GameSaveAggregate before = GameSaveAggregate.Initial("install").Commit(
                "before",
                stage: ApplicationStage.Draft,
                highSchool: Career("career", 1, false, new DraftReadModel(false, false, 82)));
            GameSaveAggregate drafted = before.Commit(
                "drafted",
                highSchool: Career("career", 1, false,
                    new DraftReadModel(true, true, 82, "club", "해오름", 2, 10)));
            Assert.That(ReviewMomentPolicy.ReasonAfter(
                "resolve_draft", drafted, drafted), Is.Null);

            var contract = new ProCareerReadModel(
                "pro", ProCareerOrigin.HighSchool, ProCareerPhase.ContractOffer,
                "next", 1, "player", "해온", "club", "해오름", 1, 1,
                new PitcherRatingsReadModel(55, 53, 51, 54),
                new CareerPerformanceReadModel(),
                sourceHighSchoolCareerId: "career",
                contractOffer: new ProContractOfferReadModel("club", "해오름", "신인", 2, 3000));
            GameSaveAggregate visibleContract = drafted.Commit(
                "contract",
                stage: ApplicationStage.Pro,
                pro: contract);
            Assert.That(ReviewMomentPolicy.ShouldRequestDraftedAtContract(visibleContract), Is.True);
            Assert.That(ReviewMomentPolicy.ShouldRequestDraftedAtContract(drafted), Is.False,
                "saving the reveal must not open Play Review before the result CTA is tapped");

            var direct = new ProCareerReadModel(
                "direct", ProCareerOrigin.Direct, ProCareerPhase.ContractOffer,
                "next", 1, "player", "해온", "club", "해오름", 1, 1,
                new PitcherRatingsReadModel(55, 53, 51, 54),
                new CareerPerformanceReadModel(),
                contractOffer: new ProContractOfferReadModel("club", "해오름", "신인", 2, 3000));
            Assert.That(ReviewMomentPolicy.ShouldRequestDraftedAtContract(
                drafted.Commit("direct", stage: ApplicationStage.Pro, pro: direct)), Is.False);
        }

        [Test]
        public void GoodRecapUsesFrozenPositiveEvidenceAndRejectsAWeakRecap()
        {
            LifeArchiveRecord previous = Record("old", 1, 70);
            LifeArchiveRecord improved = Record("new", 2, 71);
            LifeArchiveRecord weak = Record("weak", 2, 60);
            Assert.That(ReviewMomentPolicy.DeservesGoodRecap(
                improved, new[] { previous }), Is.True);
            Assert.That(ReviewMomentPolicy.DeservesGoodRecap(
                weak, new[] { previous }), Is.False);

            LifeArchiveRecord pledge = Record("pledge", 2, 60, pledgeAchieved: true);
            Assert.That(ReviewMomentPolicy.DeservesGoodRecap(
                pledge, new[] { previous }), Is.True);
        }

        private static HighSchoolCareerReadModel Career(
            string id,
            int life,
            bool challenge,
            DraftReadModel draft = null) =>
            new HighSchoolCareerReadModel(
                id,
                life,
                HighSchoolPhase.Draft,
                "seed",
                1,
                "player",
                "해온",
                "power_prospect",
                new PitcherRatingsReadModel(55, 53, 51, 54),
                new CareerPerformanceReadModel(),
                draft: draft,
                isChallengeRun: challenge);

        private static LifeArchiveRecord Record(
            string id,
            int life,
            int evaluation,
            bool pledgeAchieved = false) =>
            new LifeArchiveRecord(
                id,
                life,
                "해온",
                "career-" + life,
                null,
                "school",
                "별빛고",
                false,
                evaluation,
                new PitcherRatingsReadModel(60, 60, 60, 60),
                new CareerPerformanceReadModel(),
                0,
                0,
                0,
                0,
                10,
                pledgeAchieved: pledgeAchieved);
    }
}
