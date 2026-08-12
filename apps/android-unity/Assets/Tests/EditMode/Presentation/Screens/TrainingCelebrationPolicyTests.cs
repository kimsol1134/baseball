using Baseball.Application.HighSchool;
using Baseball.Application.Persistence;
using Baseball.Presentation.Shell;
using NUnit.Framework;

namespace Baseball.Presentation.Tests.Screens
{
    public sealed class TrainingCelebrationPolicyTests
    {
        [Test]
        public void SavedSingleGrowthProjectsBeforeAfterNextStepAndJackpotOnce()
        {
            GameSaveAggregate before = State(Career());
            var result = new TrainingResultReadModel(
                1, "velocity", "intensive", 2, 15,
                "대성공! 구위 능력치가 2 올랐습니다.", 44, 46, true, true);
            GameSaveAggregate after = State(Career(lastTraining: result));

            TrainingCelebrationViewModel value = TrainingCelebrationPolicy.Project(
                "train", before, after);
            Assert.That(value, Is.Not.Null);
            Assert.That(value.Title, Is.EqualTo("대성공!"));
            Assert.That(value.AbilityTitle, Is.EqualTo("구위"));
            Assert.That(value.Before, Is.EqualTo(44));
            Assert.That(value.After, Is.EqualTo(46));
            Assert.That(value.NextStep, Is.EqualTo("다음 단계 ‘지역에서 손꼽는 재능’까지 1"));
            Assert.That(value.ReceiptId, Is.EqualTo("career:training:1-1"));
            Assert.That(TrainingCelebrationPolicy.Project("train", after, after), Is.Null,
                "restart/re-render of an already saved receipt must not celebrate again");
        }

        [Test]
        public void SavedBlockCombinesOnlyFreshSessionsAndZeroGrowthDoesNotCelebrate()
        {
            var first = new TrainingResultReadModel(
                1, "breaking_ball", "standard", 1, 8, "변화가 올랐습니다.", 42, 43, false, false, "slider");
            var second = new TrainingResultReadModel(
                2, "breaking_ball", "standard", 0, 8, "수치 변화 없음", 43, 43, false, false, "slider");
            var third = new TrainingResultReadModel(
                3, "breaking_ball", "standard", 1, 8, "변화가 올랐습니다.", 43, 44, false, false, "slider");
            var block = new TrainingBlockResultReadModel(
                3, 3, "breaking_ball", "standard", "slider", "maximum_sessions", 2, 24,
                new[] { first, second, third });
            TrainingCelebrationViewModel value = TrainingCelebrationPolicy.Project(
                "train_block",
                State(Career()),
                State(Career(lastTraining: third, lastTrainingBlock: block)));
            Assert.That(value.AbilityTitle, Is.EqualTo("변화"));
            Assert.That(value.Before, Is.EqualTo(42));
            Assert.That(value.After, Is.EqualTo(44));
            Assert.That(value.Growth, Is.EqualTo(2));
            Assert.That(value.Sessions, Is.EqualTo(3));
            Assert.That(value.Summary, Does.Contain("3회 연속 훈련"));

            var noGrowth = new TrainingResultReadModel(
                1, "command", "light", 0, 3, "수치 변화 없음", 50, 50, false, false);
            Assert.That(TrainingCelebrationPolicy.Project(
                "train", State(Career()), State(Career(lastTraining: noGrowth))), Is.Null);
        }

        [Test]
        public void CoreReportedTalentBloomBecomesTheCelebrationHeadline()
        {
            var bloom = new TrainingResultReadModel(
                4,
                "breaking_ball",
                "intensive",
                3,
                12,
                "변화구 재능의 상한이 열렸습니다.",
                49,
                52,
                true,
                false,
                "curveball",
                bloomedAbility: "movement",
                bloomedGrade: "a");
            TrainingCelebrationViewModel value = TrainingCelebrationPolicy.Project(
                "train",
                State(Career()),
                State(Career(lastTraining: bloom)));

            Assert.That(value.Title, Is.EqualTo("재능이 만개했습니다"));
            Assert.That(value.HasBloom, Is.True);
            Assert.That(value.BloomedAbilityTitle, Is.EqualTo("변화"));
            Assert.That(value.BloomedGrade, Is.EqualTo("A"));
        }

        private static GameSaveAggregate State(HighSchoolCareerReadModel career) =>
            GameSaveAggregate.Initial("install").Commit(
                "state",
                stage: ApplicationStage.HighSchool,
                highSchool: career);

        private static HighSchoolCareerReadModel Career(
            TrainingResultReadModel lastTraining = null,
            TrainingBlockResultReadModel lastTrainingBlock = null) =>
            new HighSchoolCareerReadModel(
                "career",
                1,
                HighSchoolPhase.Training,
                "seed",
                1,
                "player",
                "해온",
                "power_prospect",
                new PitcherRatingsReadModel(46, 45, 44, 43),
                new CareerPerformanceReadModel(),
                lastTraining: lastTraining,
                lastTrainingBlock: lastTrainingBlock);
    }
}
