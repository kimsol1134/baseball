using System.Linq;
using Baseball.Core.Catalogs;
using NUnit.Framework;

namespace Baseball.Core.Pro.Tests
{
    [TestFixture]
    public sealed class AutoOutingTests
    {
        [Test]
        public void SameSeedProducesSameKernelLineAndValidCountingStats()
        {
            var simulator = new AutoOutingSimulator();
            var pitcher = PitcherPresetCatalog.All[0].Pitcher;
            var first = simulator.Simulate(pitcher, 12, 18, 96, 4242);
            var replay = simulator.Simulate(pitcher, 12, 18, 96, 4242);
            Assert.That(Line(replay), Is.EqualTo(Line(first)));
            Assert.That(first.Outs, Is.InRange(0, 18));
            Assert.That(first.Pitches, Is.GreaterThan(0));
            Assert.That(first.Pitches, Is.LessThanOrEqualTo(110));
            Assert.That(first.HomeRuns + first.Doubles + first.Triples, Is.LessThanOrEqualTo(first.Hits));
            Assert.That(new[] { first.Strikeouts, first.Walks, first.RunsAllowed, first.Hits }.All(value => value >= 0), Is.True);
        }

        [Test]
        public void HigherFatigueWorsensAggregateBurden()
        {
            var simulator = new AutoOutingSimulator();
            var pitcher = PitcherPresetCatalog.All[0].Pitcher;
            var seeds = new ulong[] { 991, 7, 42, 123, 500, 1001, 2026, 31337, 555, 808, 4444, 90210 };
            var fresh = 0;
            var tired = 0;
            foreach (var seed in seeds)
            {
                var a = simulator.Simulate(pitcher, 5, 18, 96, seed);
                var b = simulator.Simulate(pitcher, 85, 18, 96, seed);
                fresh += a.RunsAllowed * 2 + a.Walks;
                tired += b.RunsAllowed * 2 + b.Walks;
            }
            Assert.That(tired, Is.GreaterThan(fresh));
        }

        private static int[] Line(AutoOutingSimulator.Line value)
        { return new[] { value.Outs, value.Strikeouts, value.Walks, value.RunsAllowed, value.Pitches, value.Hits, value.HomeRuns, value.Doubles, value.Triples }; }
    }
}
