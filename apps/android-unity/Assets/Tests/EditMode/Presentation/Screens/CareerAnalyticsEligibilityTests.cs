using Baseball.Application.HighSchool;
using Baseball.Application.Persistence;
using Baseball.Presentation.Shell;
using NUnit.Framework;

namespace Baseball.Presentation.Tests.Screens
{
    public sealed class CareerAnalyticsEligibilityTests
    {
        [TestCase(PitchCareerKind.Tutorial)]
        [TestCase(PitchCareerKind.HighSchool)]
        public void ChallengePitchCannotConsumeCareerOrLifetimeEvents(PitchCareerKind kind)
        {
            GameSaveAggregate challenge = State(isChallenge: true);

            Assert.That(CareerAnalyticsEligibility.CountsPitchEvent(kind, challenge), Is.False);
            Assert.That(CareerAnalyticsEligibility.IsFirstPitchCompletion(kind, challenge), Is.False);
            Assert.That(CareerAnalyticsEligibility.CountsTowardHighSchoolProgress(challenge, challenge), Is.False);
        }

        [Test]
        public void OnlyNormalTutorialCompletionCanClaimFirstPitch()
        {
            GameSaveAggregate normal = State(isChallenge: false);

            Assert.That(CareerAnalyticsEligibility.IsFirstPitchCompletion(
                PitchCareerKind.Tutorial,
                normal), Is.True);
            Assert.That(CareerAnalyticsEligibility.IsFirstPitchCompletion(
                PitchCareerKind.HighSchool,
                normal), Is.False);
        }

        [Test]
        public void ChallengeBeforeStateStillBlocksCommandEventWhenAfterClearsCareer()
        {
            GameSaveAggregate challenge = State(isChallenge: true);
            GameSaveAggregate cleared = GameSaveAggregate.Initial("install");

            Assert.That(CareerAnalyticsEligibility.CountsTowardHighSchoolProgress(challenge, cleared), Is.False);
        }

        private static GameSaveAggregate State(bool isChallenge)
        {
            var career = new HighSchoolCareerReadModel(
                "career",
                1,
                HighSchoolPhase.Training,
                "seed",
                1,
                "player",
                "해온",
                "power_prospect",
                new PitcherRatingsReadModel(55, 53, 51, 54),
                new CareerPerformanceReadModel(),
                isChallengeRun: isChallenge);
            return GameSaveAggregate.Initial("install").Commit(
                "career",
                stage: ApplicationStage.HighSchool,
                highSchool: career);
        }
    }
}
