using Baseball.Application.HighSchool;
using Baseball.Application.Meta;
using Baseball.Presentation.Shell;
using NUnit.Framework;

namespace Baseball.Presentation.Tests.Screens
{
    public sealed class LifeCardShareCopyTests
    {
        [Test]
        public void MissingLegacyHighSchoolTotalsShareAsZeroWithoutThrowing()
        {
            string copy = LifeCardShareCopy.Build(
                2,
                "해온",
                highSchoolStrikeouts: null,
                proStrikeouts: 17,
                soulEarned: 8);

            Assert.That(copy, Does.Contain("2번째 인생 · 해온"));
            Assert.That(copy, Does.Contain("고교 탈삼진 0 · 프로 탈삼진 17"));
            Assert.That(copy, Does.Contain("야구혼 +8"));
        }

        [Test]
        public void FrozenDraftResultEvaluationAndChallengeCodeAreIncluded()
        {
            var record = new LifeArchiveRecord(
                "life-3",
                3,
                "해온",
                "career-20260811-life-3",
                "pro-3",
                "fictional-school",
                "별빛고",
                true,
                91,
                new PitcherRatingsReadModel(72, 70, 68, 71),
                new CareerPerformanceReadModel(strikeouts: 18),
                2,
                44,
                1,
                80,
                12,
                draftTeamName: "해오름");

            string copy = LifeCardShareCopy.Build(record);

            Assert.That(copy, Does.Contain("해오름 지명 · 스카우트 평가 91점"));
            Assert.That(copy, Does.Contain("같은 판에 도전: 20260811-3"));
            Assert.That(LifeCardShareCopy.ChallengeCode(record), Is.EqualTo("20260811-3"));
        }
    }
}
