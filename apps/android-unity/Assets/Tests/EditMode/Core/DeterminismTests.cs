using NUnit.Framework;
using Baseball.Core.Random;

namespace Baseball.Tests.EditMode.Core
{
    public sealed class DeterminismTests
    {
        [TestCase(0UL, new ulong[] { 16294208416658607535UL, 7960286522194355700UL, 487617019471545679UL, 17909611376780542444UL, 1961750202426094747UL })]
        [TestCase(1UL, new ulong[] { 10451216379200822465UL, 13757245211066428519UL, 17911839290282890590UL, 8196980753821780235UL, 8195237237126968761UL })]
        [TestCase(ulong.MaxValue, new ulong[] { 16490336266968443936UL, 16834447057089888969UL, 4048727598324417001UL, 7862637804313477842UL, 13015481187462834606UL })]
        public void SplitMix64MatchesSwiftVectors(ulong seed, ulong[] expected)
        {
            var generator = new SplitMix64(seed);
            foreach (var value in expected) Assert.That(generator.Next(), Is.EqualTo(value));
        }

        [TestCase("", "cbf29ce484222325")]
        [TestCase("a", "af63dc4c8601ec8c")]
        [TestCase("FourSeam", "7303f86d3e687b93")]
        [TestCase("야구", "e43442a27180caf1")]
        [TestCase("⚾️", "765e83d3e7e11743")]
        public void StableHashMatchesSwiftUtf8Vectors(string input, string expected)
        {
            Assert.That(StableHash.Fnv1A64(input), Is.EqualTo(expected));
        }
    }
}
