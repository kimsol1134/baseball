using System;
using System.Linq;
using Baseball.Application.Persistence;

namespace Baseball.Presentation.Shell
{
    public sealed class ProRetirementAnalyticsReadModel
    {
        public ProRetirementAnalyticsReadModel(
            int lifeNumber,
            int proSeasons,
            int soulBonus,
            bool hasSignatureCandidates)
        {
            LifeNumber = lifeNumber;
            ProSeasons = proSeasons;
            SoulBonus = soulBonus;
            HasSignatureCandidates = hasSignatureCandidates;
        }

        public int LifeNumber { get; }
        public int ProSeasons { get; }
        public int SoulBonus { get; }
        public bool HasSignatureCandidates { get; }
    }

    public static class ProRetirementAnalyticsPolicy
    {
        public static bool TryProject(
            GameSaveAggregate before,
            GameSaveAggregate after,
            out ProRetirementAnalyticsReadModel projection)
        {
            projection = null;
            string proCareerId = before?.Pro?.ProCareerId;
            if (string.IsNullOrWhiteSpace(proCareerId) || after?.Meta == null) return false;
            bool creditedBefore = before.Meta.CreditedProCareerIds.Contains(
                proCareerId,
                StringComparer.Ordinal);
            bool creditedAfter = after.Meta.CreditedProCareerIds.Contains(
                proCareerId,
                StringComparer.Ordinal);
            if (creditedBefore || !creditedAfter) return false;

            projection = new ProRetirementAnalyticsReadModel(
                before.HighSchool?.LifeNumber ?? before.Meta.LifeNumber,
                before.Pro.CareerSeasons?.Count ?? 0,
                Math.Max(0, after.Meta.SoulBalance - before.Meta.SoulBalance),
                after.HighSchool?.FrozenSignatureLegacyCandidates?.Count == 3);
            return true;
        }
    }
}
