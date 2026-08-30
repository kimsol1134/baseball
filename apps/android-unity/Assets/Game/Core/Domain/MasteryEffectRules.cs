using System;
using Baseball.Core.Domain;

namespace Baseball.Core.Domain
{
    public static class MasteryEffectRules
    {
        public const int MaximumBonusPermille = 120;

        public static int BonusPermille(int level)
        {
            if (level <= 0) return 0;
            long safe = Math.Min(AbilityMasterySnapshot.TechnicalMaximum, (long)level);
            return (int)Math.Min(MaximumBonusPermille, (MaximumBonusPermille * safe) / (safe + 24));
        }

        public static int BonusForContribution(int contribution, int level)
        {
            if (contribution <= 0) return 0;
            return (int)(((long)contribution * BonusPermille(level) + 500) / 1000);
        }

        public static int AdjustedContribution(int contribution, int level)
        { return contribution + BonusForContribution(contribution, level); }

        public static int AdjustedRating(int value, int level)
        { return value <= 0 ? value : value + BonusForContribution(value, level); }

        public static string DisplayName(TalentAbility ability)
        {
            switch (ability)
            {
                case TalentAbility.Stuff: return "강속구 숙련";
                case TalentAbility.Command: return "코스 숙련";
                case TalentAbility.Movement: return "결정구 숙련";
                default: return "이닝 숙련";
            }
        }
    }
}
