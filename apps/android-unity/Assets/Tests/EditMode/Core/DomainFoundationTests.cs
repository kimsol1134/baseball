using System.Linq;
using NUnit.Framework;
using Baseball.Core.Catalogs;
using Baseball.Core.Domain;

namespace Baseball.Tests.EditMode.Core
{
    public sealed class DomainFoundationTests
    {
        [Test]
        public void BalanceV4PresetsShareOneStartingBudgetAndCompleteRepertoires()
        {
            Assert.That(PitcherPresetCatalog.BalanceVersion, Is.EqualTo(4));
            Assert.That(PitcherPresetCatalog.All.Count, Is.EqualTo(4));
            foreach (var preset in PitcherPresetCatalog.All)
            {
                var pitcher = preset.Pitcher;
                Assert.That(pitcher.Stuff + pitcher.Command + pitcher.Movement + pitcher.Stamina, Is.EqualTo(150), preset.Id);
                Assert.That(pitcher.PitchProfiles.Select(profile => profile.PitchType).Distinct().Count(), Is.EqualTo(4), preset.Id);
                Assert.That(pitcher.PitchProfiles.All(profile => profile.VelocityTenthsKph >= 1000 && profile.VelocityTenthsKph <= 1700), Is.True);
            }
        }

        [Test]
        public void TalentGenerationAlwaysContainsAPlayableStrengthAndABloomTarget()
        {
            for (var index = 0; index < 500; index++)
            {
                var talent = TalentRules.Make("career-" + index);
                var grades = new[] { talent.Stuff, talent.Command, talent.Movement, talent.Stamina };
                Assert.That(grades.Any(grade => grade >= TalentGrade.B), Is.True);
                Assert.That(grades.Any(grade => grade <= TalentGrade.C), Is.True);
            }
        }

        [Test]
        public void CeilingPressureBloomsWithoutGrantingHiddenExtraPoints()
        {
            var talent = new TalentSnapshot(TalentGrade.D, TalentGrade.S, TalentGrade.S, TalentGrade.S);
            var first = TalentRules.Apply(talent, TalentAbility.Stuff, 52, 3);
            Assert.That(first.Allowed, Is.Zero);
            Assert.That(first.Talent.StuffPressure, Is.EqualTo(1));
            Assert.That(first.Bloomed, Is.Null);
            var second = TalentRules.Apply(first.Talent, TalentAbility.Stuff, 52, 3);
            Assert.That(second.Allowed, Is.Zero);
            Assert.That(second.Bloomed, Is.EqualTo(TalentAbility.Stuff));
            Assert.That(second.Talent.Stuff, Is.EqualTo(TalentGrade.C));
        }

        [Test]
        public void PitchingMetricsUseOutsAsTheCanonicalInningsUnit()
        {
            Assert.That(PitchingMetrics.InningsText(19), Is.EqualTo("6.1"));
            Assert.That(PitchingMetrics.Per9(9, 27), Is.EqualTo(9.0));
            Assert.That(PitchingMetrics.Whip(6, 3, 27), Is.EqualTo(1.0));
            Assert.That(PitchingMetrics.IsQualityStart(true, 18, 3), Is.True);
            Assert.That(PitchingMetrics.RateText(0.532), Is.EqualTo(".532"));
        }
    }
}
