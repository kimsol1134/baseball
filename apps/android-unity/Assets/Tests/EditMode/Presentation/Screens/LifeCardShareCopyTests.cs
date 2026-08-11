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
    }
}
