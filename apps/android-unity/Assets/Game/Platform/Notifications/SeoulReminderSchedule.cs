using System;
using System.Collections.Generic;
using System.Globalization;

namespace Baseball.Platform.Notifications
{
    public readonly struct SeoulReminderEntry
    {
        public SeoulReminderEntry(int notificationId, string dayKey, DateTimeOffset fireUtc)
        {
            NotificationId = notificationId;
            DayKey = dayKey;
            FireUtc = fireUtc;
        }

        public int NotificationId { get; }
        public string DayKey { get; }
        public DateTimeOffset FireUtc { get; }
    }

    /// <summary>Pure non-repeating KST horizon used by Android local notification scheduling.</summary>
    public static class SeoulReminderSchedule
    {
        public const int DefaultHour = 19;
        public const int DefaultMinute = 30;
        public const int HorizonDays = 3;
        public const int NotificationIdBase = 1930;

        public static IReadOnlyList<SeoulReminderEntry> Upcoming(
            DateTimeOffset nowUtc,
            IReadOnlyCollection<string> playedDayKeys = null,
            int horizonDays = HorizonDays,
            int hour = DefaultHour,
            int minute = DefaultMinute)
        {
            if (horizonDays < 0) throw new ArgumentOutOfRangeException(nameof(horizonDays));
            if (hour < 0 || hour > 23) throw new ArgumentOutOfRangeException(nameof(hour));
            if (minute < 0 || minute > 59) throw new ArgumentOutOfRangeException(nameof(minute));
            var played = playedDayKeys == null
                ? new HashSet<string>(StringComparer.Ordinal)
                : new HashSet<string>(playedDayKeys, StringComparer.Ordinal);
            DateTimeOffset utc = nowUtc.ToUniversalTime();
            TimeZoneInfo seoul = ResolveSeoulTimeZone();
            DateTimeOffset localNow = TimeZoneInfo.ConvertTime(utc, seoul);
            var result = new List<SeoulReminderEntry>();
            for (int offset = 0; offset < horizonDays; offset++)
            {
                DateTime localDay = localNow.Date.AddDays(offset);
                var localFire = new DateTime(
                    localDay.Year,
                    localDay.Month,
                    localDay.Day,
                    hour,
                    minute,
                    0,
                    DateTimeKind.Unspecified);
                var fire = new DateTimeOffset(localFire, seoul.GetUtcOffset(localFire));
                string dayKey = localDay.ToString("yyyyMMdd", CultureInfo.InvariantCulture);
                if (fire <= localNow || played.Contains(dayKey)) continue;
                result.Add(new SeoulReminderEntry(
                    NotificationIdBase + offset,
                    dayKey,
                    fire.ToUniversalTime()));
            }
            return result;
        }

        public static DateTimeOffset NextFireUtc(
            DateTimeOffset nowUtc,
            int hour = DefaultHour,
            int minute = DefaultMinute)
        {
            IReadOnlyList<SeoulReminderEntry> upcoming = Upcoming(
                nowUtc,
                horizonDays: 2,
                hour: hour,
                minute: minute);
            if (upcoming.Count > 0) return upcoming[0].FireUtc;
            throw new InvalidOperationException("No reminder fire time exists in the requested horizon.");
        }

        private static TimeZoneInfo ResolveSeoulTimeZone()
        {
            try { return TimeZoneInfo.FindSystemTimeZoneById("Asia/Seoul"); }
            catch (TimeZoneNotFoundException)
            {
                return TimeZoneInfo.FindSystemTimeZoneById("Korea Standard Time");
            }
        }
    }
}
