using Baseball.Presentation.Common;
using NUnit.Framework;

namespace Baseball.Presentation.Tests
{
    public sealed class KoreanCopyTests
    {
        [TestCase("서울", "로")]
        [TestCase("한빛고", "로")]
        [TestCase("청암", "으로")]
        [TestCase("17", "로")]
        [TestCase("16", "으로")]
        public void RoSelectsTheNaturalParticle(string word, string expected)
        {
            Assert.That(KoreanCopy.Ro(word), Is.EqualTo(expected));
        }

        [TestCase("투수", "은", "는", "는")]
        [TestCase("감독", "은", "는", "은")]
        [TestCase("22", "을", "를", "를")]
        [TestCase("21", "을", "를", "을")]
        public void ParticleChecksHangulAndNumericFinalConsonants(string word, string withFinal, string withoutFinal, string expected)
        {
            Assert.That(KoreanCopy.Particle(word, withFinal, withoutFinal), Is.EqualTo(expected));
        }

        [TestCase(22, "를")]
        [TestCase(21, "을")]
        [TestCase(18, "을")]
        public void NumericObjectParticleMatchesKoreanReading(int number, string expected)
        {
            Assert.That(KoreanCopy.ObjectParticle(number), Is.EqualTo(expected));
        }

        [TestCase(120_000_000, "1억 2,000만 원")]
        [TestCase(100_000_000, "1억 원")]
        [TestCase(44_000_000, "4,400만 원")]
        public void MoneyUsesEokAndManUnits(int won, string expected)
        {
            Assert.That(KoreanCopy.Money(won), Is.EqualTo(expected));
        }
    }
}
