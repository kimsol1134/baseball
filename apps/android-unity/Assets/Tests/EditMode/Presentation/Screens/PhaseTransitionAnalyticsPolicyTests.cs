using Baseball.Application.HighSchool;
using Baseball.Application.Persistence;
using Baseball.Presentation.Shell;
using NUnit.Framework;

namespace Baseball.Presentation.Tests.Screens
{
    public sealed class PhaseTransitionAnalyticsPolicyTests
    {
        [Test]
        public void InitialCareerCreationIsNotAPhaseEnteredEvent()
        {
            GameSaveAggregate before = GameSaveAggregate.Initial("install");
            GameSaveAggregate after = before.Commit(
                "start",
                stage: ApplicationStage.HighSchool,
                highSchool: Career(HighSchoolPhase.Prologue, 1));

            Assert.That(PhaseTransitionAnalyticsPolicy.IsEntered(before, after), Is.False);
        }

        [Test]
        public void SavedPhaseTransitionAndSamePhaseNewChapterEachEnter()
        {
            GameSaveAggregate initial = GameSaveAggregate.Initial("install").Commit(
                "career",
                stage: ApplicationStage.HighSchool,
                highSchool: Career(HighSchoolPhase.Training, 2));
            GameSaveAggregate relationship = initial.Commit(
                "relationship",
                highSchool: Career(HighSchoolPhase.Relationship, 2));
            GameSaveAggregate nextChapterTraining = relationship.Commit(
                "training-again",
                highSchool: Career(HighSchoolPhase.Relationship, 3));

            Assert.That(PhaseTransitionAnalyticsPolicy.IsEntered(initial, relationship), Is.True);
            Assert.That(PhaseTransitionAnalyticsPolicy.IsEntered(relationship, nextChapterTraining), Is.True,
                "the same phase in a later chapter is a new persisted entry");
            Assert.That(PhaseTransitionAnalyticsPolicy.IsEntered(
                nextChapterTraining,
                nextChapterTraining.Commit("unrelated")), Is.False);
        }

        [Test]
        public void ChallengeAndDifferentCareerTransitionsAreExcluded()
        {
            GameSaveAggregate before = GameSaveAggregate.Initial("install").Commit(
                "career",
                stage: ApplicationStage.HighSchool,
                highSchool: Career(HighSchoolPhase.Training, 2));
            GameSaveAggregate challenge = before.Commit(
                "challenge",
                highSchool: Career(HighSchoolPhase.Relationship, 2, "career", true));
            GameSaveAggregate replacement = before.Commit(
                "replacement",
                highSchool: Career(HighSchoolPhase.Relationship, 2, "other-career"));

            Assert.That(PhaseTransitionAnalyticsPolicy.IsEntered(before, challenge), Is.False);
            Assert.That(PhaseTransitionAnalyticsPolicy.IsEntered(before, replacement), Is.False);
        }

        private static HighSchoolCareerReadModel Career(
            HighSchoolPhase phase,
            int chapter,
            string careerId = "career",
            bool challenge = false) =>
            new HighSchoolCareerReadModel(
                careerId,
                1,
                phase,
                "seed",
                1,
                "player",
                "투수",
                "power_prospect",
                new PitcherRatingsReadModel(55, 53, 51, 54),
                new CareerPerformanceReadModel(),
                chapterNumber: chapter,
                isChallengeRun: challenge);
    }
}
