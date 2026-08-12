using Baseball.Application.HighSchool;
using Baseball.Application.Persistence;
using Baseball.Application.Stores;
using Baseball.Presentation.Shell;
using NUnit.Framework;

namespace Baseball.Presentation.Tests.Screens
{
    public sealed class CareerShareCodePolicyTests
    {
        [TestCase(false, "고교")]
        [TestCase(true, "도전 중인 고교")]
        public void HighSchoolShareCodeIsStableAndContainsNoPlayerName(bool challenge, string mode)
        {
            GameSaveAggregate state = GameSaveAggregate.Initial("install").Commit(
                "test:start",
                stage: ApplicationStage.HighSchool,
                highSchool: new HighSchoolCareerReadModel(
                    "career-778899-life-3", 3, HighSchoolPhase.Training, "next", 0,
                    "player", "개인 이름", "balanced",
                    new PitcherRatingsReadModel(50, 50, 50, 50),
                    new CareerPerformanceReadModel(),
                    isChallengeRun: challenge));

            CareerShareCode code = CareerShareCodePolicy.Project(state);
            Assert.That(code.Code, Is.EqualTo("778899-3"));
            Assert.That(code.Mode, Is.EqualTo(mode));
            Assert.That(CareerShareCodePolicy.ShareText(code), Does.Contain("같은 판에 도전: 778899-3"));
            Assert.That(CareerShareCodePolicy.ShareText(code), Does.Not.Contain("개인 이름"));
        }

        [Test]
        public void NoActiveCareerHasNoSharePayload()
        {
            Assert.That(CareerShareCodePolicy.Project(GameSaveAggregate.Initial("install")), Is.Null);
            Assert.That(CareerShareCodePolicy.ShareText(null), Is.Empty);
        }
    }
}
