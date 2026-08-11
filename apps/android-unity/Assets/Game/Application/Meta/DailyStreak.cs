using System;
using System.Globalization;
using System.Linq;
using Baseball.Application.HighSchool;
using Baseball.Core.Random;

namespace Baseball.Application.Meta
{
    public sealed class DailyStreakState
    {
        public DailyStreakState(
            string lastBaseballDayKey = null,
            string lastDailyInningDayKey = null,
            int currentStreak = 0,
            int bestStreak = 0,
            DailyInningDayState dailyInning = null)
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
        /// <summary>Latest day-scoped attempt and best-report snapshot; absent in older saves.</summary>
        public DailyInningDayState DailyInning { get; }

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

        public static DailyStreakState RecordDailyInning(
            DailyStreakState current,
            DateTimeOffset instant)
        {
            return DailyInningRules.RecordCompletion(current, null, instant);
        }
    }

    /// <summary>Durable state for the latest Seoul-day daily challenge.</summary>
    public sealed class DailyInningDayState
    {
        public DailyInningDayState(
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
            ScenarioId = scenarioId ?? DailyInningRules.ScenarioId(dayKey);
            SessionSeed = sessionSeed ?? DailyInningRules.SessionSeed(dayKey);
        }

        public string DayKey { get; }
        /// <summary>Consumed at session reservation, so abandoning an attempt does not refund it.</summary>
        public int AttemptCount { get; }
        public int BestScore { get; }
        public PitchGameReport BestReport { get; }
        public string ScenarioId { get; }
        public string SessionSeed { get; }
    }

    /// <summary>UI projection for the current Seoul day.</summary>
    public sealed class DailyInningReadModel
    {
        public DailyInningReadModel(
            string dayKey,
            int attemptCount,
            int attemptLimit,
            int bestScore,
            PitchGameReport bestReport,
            string scenarioId,
            string sessionSeed,
            bool rewardCredited)
        {
            DayKey = dayKey;
            AttemptCount = attemptCount;
            AttemptLimit = attemptLimit;
            BestScore = bestScore;
            BestReport = bestReport;
            ScenarioId = scenarioId;
            SessionSeed = sessionSeed;
            RewardCredited = rewardCredited;
        }

        public string DayKey { get; }
        public int AttemptCount { get; }
        public int AttemptLimit { get; }
        public int RemainingAttempts => Math.Max(0, AttemptLimit - AttemptCount);
        public bool CanStart => RemainingAttempts > 0;
        public int BestScore { get; }
        public PitchGameReport BestReport { get; }
        public bool HasCompletedAttempt => BestReport != null;
        public string ScenarioId { get; }
        public string SessionSeed { get; }
        public bool RewardCredited { get; }
    }

    public static class DailyInningRules
    {
        public const int AttemptLimit = 3;

        public static string ScenarioId(string dayKey)
        {
            return "daily-" + dayKey;
        }

        /// <summary>Exact PitchScenario.swift FNV-1a wire; all three attempts reuse it.</summary>
        public static string SessionSeed(string dayKey)
        {
            return StableHash.Fnv1A64Value("daily-session-" + dayKey)
                .ToString(CultureInfo.InvariantCulture);
        }

        public static string RewardId(string dayKey)
        {
            return "daily-inning:" + dayKey;
        }

        public static int Score(PitchGameReport report)
        {
            if (report == null) throw new ArgumentNullException(nameof(report));
            var score = (long)report.Strikeouts * 300L + report.Outs * 100L -
                report.Walks * 50L - report.RunsAllowed * 250L +
                (report.RunsAllowed == 0 && report.Outs >= 3 ? 300L : 0L);
            return (int)Math.Min(int.MaxValue, Math.Max(0L, score));
        }

        public static DailyInningDayState ForDay(DailyStreakState current, string dayKey)
        {
            current = current ?? DailyStreakState.Empty;
            if (current.DailyInning != null && string.Equals(
                    current.DailyInning.DayKey, dayKey, StringComparison.Ordinal))
            {
                return current.DailyInning;
            }

            // Saves written before this additive state only recorded that the day was completed.
            // Preserve that consumed attempt without inventing a historical score or report.
            var legacyAttempt = string.Equals(
                current.LastDailyInningDayKey, dayKey, StringComparison.Ordinal) ? 1 : 0;
            return new DailyInningDayState(dayKey, legacyAttempt);
        }

        public static DailyStreakState ReserveAttempt(
            DailyStreakState current,
            DateTimeOffset startedAt)
        {
            current = current ?? DailyStreakState.Empty;
            var dayKey = SeoulGameCalendar.DayKey(startedAt);
            var day = ForDay(current, dayKey);
            if (day.AttemptCount >= AttemptLimit)
                throw new InvalidOperationException("daily.attempts_exhausted");
            var reserved = new DailyInningDayState(
                dayKey,
                day.AttemptCount + 1,
                day.BestScore,
                day.BestReport,
                day.ScenarioId,
                day.SessionSeed);
            return new DailyStreakState(
                current.LastBaseballDayKey,
                current.LastDailyInningDayKey,
                current.CurrentStreak,
                current.BestStreak,
                reserved);
        }

        public static DailyStreakState RecordCompletion(
            DailyStreakState current,
            PitchGameReport report,
            DateTimeOffset completedAt)
        {
            current = current ?? DailyStreakState.Empty;
            var dayKey = SeoulGameCalendar.DayKey(completedAt);
            if (current.LastBaseballDayKey != null &&
                SeoulGameCalendar.CompareDayKeys(dayKey, current.LastBaseballDayKey) < 0 ||
                current.LastDailyInningDayKey != null &&
                SeoulGameCalendar.CompareDayKeys(dayKey, current.LastDailyInningDayKey) < 0 ||
                current.DailyInning != null &&
                SeoulGameCalendar.CompareDayKeys(dayKey, current.DailyInning.DayKey) < 0)
            {
                return current;
            }

            var withBaseball = DailyStreakRules.RecordBaseball(current, completedAt);
            var day = ForDay(withBaseball, dayKey);
            var attempts = Math.Max(1, day.AttemptCount);
            var bestScore = day.BestScore;
            var bestReport = day.BestReport;
            if (report != null)
            {
                var score = Score(report);
                if (bestReport == null || score > bestScore)
                {
                    bestScore = score;
                    bestReport = report;
                }
            }
            return new DailyStreakState(
                withBaseball.LastBaseballDayKey,
                dayKey,
                withBaseball.CurrentStreak,
                withBaseball.BestStreak,
                new DailyInningDayState(
                    dayKey,
                    attempts,
                    bestScore,
                    bestReport,
                    day.ScenarioId,
                    day.SessionSeed));
        }

        public static DailyInningReadModel Project(
            MetaProgressState meta,
            DateTimeOffset instant)
        {
            meta = meta ?? MetaProgressState.Initial;
            var dayKey = SeoulGameCalendar.DayKey(instant);
            var day = ForDay(meta.Daily, dayKey);
            return new DailyInningReadModel(
                dayKey,
                day.AttemptCount,
                AttemptLimit,
                day.BestScore,
                day.BestReport,
                day.ScenarioId,
                day.SessionSeed,
                meta.CreditedRewardIds.Contains(RewardId(dayKey), StringComparer.Ordinal));
        }

        public static bool IsValid(DailyStreakState value)
        {
            if (value == null) return false;
            var day = value.DailyInning;
            if (day == null) return true;
            if (!ValidDayKey(day.DayKey) || day.AttemptCount < 0 ||
                day.AttemptCount > AttemptLimit || day.BestScore < 0 ||
                !string.Equals(day.ScenarioId, ScenarioId(day.DayKey), StringComparison.Ordinal) ||
                !string.Equals(day.SessionSeed, SessionSeed(day.DayKey), StringComparison.Ordinal))
            {
                return false;
            }
            if (day.BestReport == null) return day.BestScore == 0;
            return day.AttemptCount > 0 && day.BestReport.Pitches > 0 &&
                day.BestReport.Batters >= 0 && day.BestReport.Outs >= 0 &&
                day.BestReport.Strikeouts >= 0 && day.BestReport.Walks >= 0 &&
                day.BestReport.Hits >= 0 && day.BestReport.RunsAllowed >= 0 &&
                (!day.BestReport.HomeRuns.HasValue ||
                 day.BestReport.HomeRuns.Value >= 0 &&
                 day.BestReport.HomeRuns.Value <= day.BestReport.Hits) &&
                day.BestScore == Score(day.BestReport) &&
                string.Equals(value.LastDailyInningDayKey, day.DayKey, StringComparison.Ordinal);
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
