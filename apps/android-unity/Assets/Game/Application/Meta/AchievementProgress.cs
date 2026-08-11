using System;
using System.Collections.Generic;
using System.Linq;
using Baseball.Application.HighSchool;
using Baseball.Application.Pro;

namespace Baseball.Application.Meta
{
    public static class AchievementIds
    {
        public const string FirstDraft = "first_draft";
        public const string FirstStrikeout = "first_strikeout";
        public const string CleanInning = "clean_inning";
        public const string PerfectDelivery = "perfect_delivery";
        public const string MajorDebut = "major_debut";
        public const string HundredStrikeouts = "hundred_strikeouts";
        public const string ThirdLife = "third_life";
        public const string FifthLife = "fifth_life";
        public const string TenthLife = "tenth_life";
        public const string KarmaRun = "karma_run";
        public const string DoubleKarma = "double_karma";
        public const string AwakenedThrice = "awakened_thrice";
        public const string FourSchools = "four_schools";
        public const string FiveDrafts = "five_drafts";
        public const string HallOfFame = "hall_of_fame";
    }

    public sealed class AchievementProgressState
    {
        public AchievementProgressState(
            IReadOnlyList<string> unlocked = null,
            IReadOnlyList<string> unacknowledged = null)
        {
            Unlocked = Normalize(unlocked);
            Unacknowledged = Normalize(unacknowledged)
                .Where(Unlocked.Contains)
                .ToArray();
        }

        public IReadOnlyList<string> Unlocked { get; }
        public IReadOnlyList<string> Unacknowledged { get; }

        public static AchievementProgressState Empty { get; } =
            new AchievementProgressState();

        private static IReadOnlyList<string> Normalize(IReadOnlyList<string> values)
        {
            return (values ?? Array.Empty<string>())
                .Where(value => !string.IsNullOrWhiteSpace(value))
                .Distinct(StringComparer.Ordinal)
                .OrderBy(value => value, StringComparer.Ordinal)
                .ToArray();
        }
    }

    public static class AchievementRules
    {
        public static AchievementProgressState Unlock(
            AchievementProgressState current,
            IEnumerable<string> earned)
        {
            current = current ?? AchievementProgressState.Empty;
            var candidates = (earned ?? Array.Empty<string>())
                .Where(value => !string.IsNullOrWhiteSpace(value))
                .Distinct(StringComparer.Ordinal)
                .ToArray();
            var fresh = candidates.Where(value =>
                !current.Unlocked.Contains(value, StringComparer.Ordinal)).ToArray();
            return fresh.Length == 0
                ? current
                : new AchievementProgressState(
                    current.Unlocked.Concat(fresh).ToArray(),
                    current.Unacknowledged.Concat(fresh).ToArray());
        }

        public static AchievementProgressState Acknowledge(
            AchievementProgressState current,
            string achievementId)
        {
            current = current ?? AchievementProgressState.Empty;
            return new AchievementProgressState(
                current.Unlocked,
                current.Unacknowledged.Where(value =>
                    !string.Equals(value, achievementId, StringComparison.Ordinal)).ToArray());
        }

        public static IReadOnlyList<string> FromHighSchool(HighSchoolCareerReadModel state)
        {
            var earned = new List<string>();
            if (state?.Draft?.Drafted == true) earned.Add(AchievementIds.FirstDraft);
            if (state?.Performance?.Strikeouts >= 1) earned.Add(AchievementIds.FirstStrikeout);
            if (state?.Awakenings?.Count >= 3) earned.Add(AchievementIds.AwakenedThrice);
            if (state?.Draft?.Resolved == true && state.Karmas.Count >= 1) earned.Add(AchievementIds.KarmaRun);
            if (state?.Draft?.Resolved == true && state.Karmas.Count >= 2) earned.Add(AchievementIds.DoubleKarma);
            return earned;
        }

        public static IReadOnlyList<string> FromPro(ProCareerReadModel state)
        {
            var earned = new List<string>();
            if (state == null) return earned;
            if (state.Season >= 1) earned.Add(AchievementIds.MajorDebut);
            if (state.CurrentSeason.Strikeouts >= 100 ||
                state.CareerSeasons.Any(season => season.Strikeouts >= 100))
            {
                earned.Add(AchievementIds.HundredStrikeouts);
            }
            if (state.HallOfFameScore >= 70) earned.Add(AchievementIds.HallOfFame);
            return earned;
        }

        public static IReadOnlyList<string> FromPitch(PitchGameReport report)
        {
            var earned = new List<string>();
            if (report.Strikeouts >= 1) earned.Add(AchievementIds.FirstStrikeout);
            if (report.Pitches > 0 && report.RunsAllowed == 0) earned.Add(AchievementIds.CleanInning);
            if (report.PerfectDeliveryCount > 0) earned.Add(AchievementIds.PerfectDelivery);
            return earned;
        }

        public static IReadOnlyList<string> FromArchive(
            IReadOnlyList<LifeArchiveRecord> archive)
        {
            archive = archive ?? Array.Empty<LifeArchiveRecord>();
            var earned = new List<string>();
            if (archive.Select(value => value.SchoolId)
                .Where(value => !string.IsNullOrWhiteSpace(value))
                .Distinct(StringComparer.Ordinal).Count() >= 4)
            {
                earned.Add(AchievementIds.FourSchools);
            }
            if (archive.Count(value => value.Drafted) >= 5) earned.Add(AchievementIds.FiveDrafts);
            return earned;
        }

        public static IReadOnlyList<string> FromLifeNumber(int lifeNumber)
        {
            var earned = new List<string>();
            if (lifeNumber >= 3) earned.Add(AchievementIds.ThirdLife);
            if (lifeNumber >= 5) earned.Add(AchievementIds.FifthLife);
            if (lifeNumber >= 10) earned.Add(AchievementIds.TenthLife);
            return earned;
        }
    }
}
