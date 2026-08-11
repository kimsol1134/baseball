using System;
using System.Globalization;
using Baseball.Application.HighSchool;

namespace Baseball.Application.Meta
{
    public sealed class DailyStreakState
    {
        public DailyStreakState(
            string lastBaseballDayKey = null,
            string lastDailyInningDayKey = null,
            int currentStreak = 0,
            int bestStreak = 0,
            LegacyDailyInningData dailyInning = null)
        {
            LastBaseballDayKey = lastBaseballDayKey;
            LastDailyInningDayKey = lastDailyInningDayKey;
            CurrentStreak = currentStreak;
            BestStreak = bestStreak;
            DailyInning = dailyInning;
        }

        public string LastBaseballDayKey { get; }
        public string LastDailyInningDayKey { get; }
        public int CurrentStreak { get; }
        public int BestStreak { get; }
        /// <summary>
        /// Read-only wire compatibility for saves written while Daily Inning was enabled.
        /// Production code must not derive a scenario, seed, score, reward, or new attempt from it.
        /// </summary>
        public LegacyDailyInningData DailyInning { get; }

        public static DailyStreakState Empty { get; } = new DailyStreakState();
    }

    public static class SeoulGameCalendar
    {
        private static readonly TimeSpan SeoulOffset = TimeSpan.FromHours(9);

        public static string DayKey(DateTimeOffset instant)
        {
            return instant.ToUniversalTime().Add(SeoulOffset)
                .ToString("yyyyMMdd", CultureInfo.InvariantCulture);
        }

        public static string WeekKey(DateTimeOffset instant)
        {
            var localDate = instant.ToUniversalTime().Add(SeoulOffset).Date;
            var isoDay = ((int)localDate.DayOfWeek + 6) % 7 + 1;
            var thursday = localDate.AddDays(4 - isoDay);
            var weekYear = thursday.Year;
            var januaryFourth = new DateTime(weekYear, 1, 4);
            var januaryFourthIsoDay = ((int)januaryFourth.DayOfWeek + 6) % 7 + 1;
            var firstThursday = januaryFourth.AddDays(4 - januaryFourthIsoDay);
            var week = 1 + (int)((thursday - firstThursday).TotalDays / 7);
            return string.Format(CultureInfo.InvariantCulture, "{0:0000}-W{1:00}", weekYear, week);
        }

        public static string WeekStartDayKey(DateTimeOffset instant)
        {
            var localDate = instant.ToUniversalTime().Add(SeoulOffset).Date;
            var daysFromMonday = ((int)localDate.DayOfWeek + 6) % 7;
            return localDate.AddDays(-daysFromMonday)
                .ToString("yyyyMMdd", CultureInfo.InvariantCulture);
        }

        public static int CompareDayKeys(string left, string right)
        {
            return string.CompareOrdinal(left, right);
        }

        public static string PreviousDayKey(string dayKey)
        {
            var day = DateTime.ParseExact(
                dayKey,
                "yyyyMMdd",
                CultureInfo.InvariantCulture,
                DateTimeStyles.None);
            return day.AddDays(-1).ToString("yyyyMMdd", CultureInfo.InvariantCulture);
        }
    }

    public static class DailyStreakRules
    {
        public static DailyStreakState RecordBaseball(
            DailyStreakState current,
            DateTimeOffset instant)
        {
            current = current ?? DailyStreakState.Empty;
            var dayKey = SeoulGameCalendar.DayKey(instant);
            if (current.LastBaseballDayKey != null &&
                SeoulGameCalendar.CompareDayKeys(dayKey, current.LastBaseballDayKey) < 0)
            {
                return current;
            }

            if (string.Equals(current.LastBaseballDayKey, dayKey, StringComparison.Ordinal))
            {
                return current;
            }

            var continues = current.LastBaseballDayKey != null &&
                string.Equals(
                    current.LastBaseballDayKey,
                    SeoulGameCalendar.PreviousDayKey(dayKey),
                    StringComparison.Ordinal);
            var streak = continues ? Math.Min(366, current.CurrentStreak + 1) : 1;
            return new DailyStreakState(
                dayKey,
                current.LastDailyInningDayKey,
                streak,
                Math.Max(current.BestStreak, streak),
                current.DailyInning);
        }
    }

    /// <summary>
    /// Raw legacy wire data. It is intentionally not an executable read model: all fields are
    /// preserved exactly and no current scenario, seed, score, reward, or eligibility is derived.
    /// </summary>
    public sealed class LegacyDailyInningData
    {
        public LegacyDailyInningData(
            string dayKey,
            int attemptCount,
            int bestScore = 0,
            PitchGameReport bestReport = null,
            string scenarioId = null,
            string sessionSeed = null)
        {
            DayKey = dayKey;
            AttemptCount = attemptCount;
            BestScore = bestScore;
            BestReport = bestReport;
            ScenarioId = scenarioId;
            SessionSeed = sessionSeed;
        }

        public string DayKey { get; }
        public int AttemptCount { get; }
        public int BestScore { get; }
        public PitchGameReport BestReport { get; }
        public string ScenarioId { get; }
        public string SessionSeed { get; }
    }

    public static class LegacyDailyInningCompatibility
    {
        public static bool IsValid(DailyStreakState value)
        {
            if (value == null) return false;
            if (value.CurrentStreak < 0 || value.BestStreak < 0 ||
                value.LastBaseballDayKey != null && !ValidDayKey(value.LastBaseballDayKey) ||
                value.LastDailyInningDayKey != null && !ValidDayKey(value.LastDailyInningDayKey))
            {
                return false;
            }
            var day = value.DailyInning;
            if (day == null) return true;
            if (!ValidDayKey(day.DayKey) || day.AttemptCount < 0 || day.BestScore < 0)
            {
                return false;
            }
            if (day.BestReport == null) return true;
            return day.AttemptCount > 0 && day.BestReport.Pitches > 0 &&
                day.BestReport.Batters >= 0 && day.BestReport.Outs >= 0 &&
                day.BestReport.Strikeouts >= 0 && day.BestReport.Walks >= 0 &&
                day.BestReport.Hits >= 0 && day.BestReport.RunsAllowed >= 0 &&
                (!day.BestReport.HomeRuns.HasValue ||
                 day.BestReport.HomeRuns.Value >= 0 &&
                 day.BestReport.HomeRuns.Value <= day.BestReport.Hits);
        }

        private static bool ValidDayKey(string value)
        {
            return value != null && value.Length == 8 && DateTime.TryParseExact(
                value,
                "yyyyMMdd",
                CultureInfo.InvariantCulture,
                DateTimeStyles.None,
                out _);
        }
    }
}
