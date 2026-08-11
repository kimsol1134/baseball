using System;
using System.Collections.Generic;
using System.Globalization;

namespace Baseball.Platform.Notifications
{
    public sealed class AndroidReminderIntent
    {
        public AndroidReminderIntent(
            string destination,
            string reason,
            string receipt,
            string experimentId,
            string variant,
            string savedDayKey,
            string notificationDayKey,
            int developmentRulesVersion)
        {
            Destination = destination;
            Reason = reason;
            Receipt = receipt;
            ExperimentId = experimentId;
            Variant = variant;
            SavedDayKey = savedDayKey;
            NotificationDayKey = notificationDayKey;
            DevelopmentRulesVersion = developmentRulesVersion;
        }

        public string Destination { get; }
        public string Reason { get; }
        public string Receipt { get; }
        public string ExperimentId { get; }
        public string Variant { get; }
        public string SavedDayKey { get; }
        public string NotificationDayKey { get; }
        public int DevelopmentRulesVersion { get; }
    }

    /// <summary>
    /// Parsed, allow-listed notification open waiting for a durable Application receipt. The
    /// stable token is an opaque hash of normalized low-cardinality intent fields, never raw URI
    /// text or player data.
    /// </summary>
    public sealed class ReminderOpenRequest
    {
        public ReminderOpenRequest(AndroidReminderIntent intent, string stableTokenHash)
        {
            Intent = intent ?? throw new ArgumentNullException(nameof(intent));
            StableTokenHash = stableTokenHash ?? throw new ArgumentNullException(nameof(stableTokenHash));
        }

        public AndroidReminderIntent Intent { get; }
        public string StableTokenHash { get; }
    }

    public static class ReminderOpenPolicy
    {
        public static bool TryCreate(string intentData, out ReminderOpenRequest request)
        {
            request = null;
            if (!AndroidReminderPlan.TryParseIntent(intentData, out AndroidReminderIntent intent))
                return false;
            string canonical = string.Join("|", new[]
            {
                intent.Destination,
                intent.Reason,
                intent.Receipt,
                intent.ExperimentId,
                intent.Variant,
                intent.SavedDayKey,
                intent.NotificationDayKey,
                intent.DevelopmentRulesVersion.ToString(CultureInfo.InvariantCulture),
            });
            request = new ReminderOpenRequest(intent, Fnv1A64(canonical).ToString("x16"));
            return true;
        }

        private static ulong Fnv1A64(string value)
        {
            const ulong offset = 14695981039346656037UL;
            const ulong prime = 1099511628211UL;
            ulong hash = offset;
            foreach (char character in value)
            {
                hash ^= (byte)character;
                hash *= prime;
            }
            return hash;
        }
    }

    public sealed class AndroidReminderPlan
    {
        public AndroidReminderPlan(
            string title,
            string body,
            string destination,
            string reason,
            string receipt,
            string experimentId = null,
            string variant = null,
            string savedDayKey = null,
            int developmentRulesVersion = 0)
        {
            Title = string.IsNullOrWhiteSpace(title) ? "오늘도 마운드가 기다려요" : title;
            Body = string.IsNullOrWhiteSpace(body) ? "짧게 한 경기만 이어서 던져볼까요?" : body;
            Destination = TryNormalizeDestination(destination, out string normalizedDestination)
                ? normalizedDestination
                : "high_school";
            Reason = TryNormalizeReason(reason, out string normalizedReason)
                ? normalizedReason
                : "return_plan";
            Receipt = TokenOrNone(receipt, 32);
            ExperimentId = TokenOrNone(experimentId, 48);
            Variant = NormalizeVariant(variant);
            SavedDayKey = DayKeyOrNone(savedDayKey);
            DevelopmentRulesVersion = Math.Max(0, developmentRulesVersion);
        }

        public string Title { get; }
        public string Body { get; }
        public string Destination { get; }
        public string Reason { get; }
        public string Receipt { get; }
        public string ExperimentId { get; }
        public string Variant { get; }
        public string SavedDayKey { get; }
        public int DevelopmentRulesVersion { get; }

        public static AndroidReminderPlan Daily { get; } = new AndroidReminderPlan(
            "진행 중인 선수가 기다려요",
            "현재 커리어의 다음 일정으로 돌아가세요.",
            "daily_inning",
            "daily_inning",
            "none",
            "none",
            "legacy");

        public string IntentData(string dayKey)
        {
            return "baseball://reminder?source=return_reminder&destination=" +
                Uri.EscapeDataString(Destination) + "&reason=" + Uri.EscapeDataString(Reason) +
                "&receipt=" + Uri.EscapeDataString(Receipt) +
                "&experiment_id=" + Uri.EscapeDataString(ExperimentId) +
                "&variant=" + Uri.EscapeDataString(Variant) +
                "&saved_day_key=" + Uri.EscapeDataString(SavedDayKey) +
                "&development_rules_version=" + DevelopmentRulesVersion.ToString(CultureInfo.InvariantCulture) +
                "&day=" + Uri.EscapeDataString(DayKeyOrNone(dayKey));
        }

        public static bool TryParseIntent(string intentData, out string destination, out string reason)
        {
            bool parsed = TryParseIntent(intentData, out AndroidReminderIntent value);
            destination = value?.Destination;
            reason = value?.Reason;
            return parsed;
        }

        public static bool TryParseIntent(string intentData, out AndroidReminderIntent value)
        {
            value = null;
            if (!Uri.TryCreate(intentData, UriKind.Absolute, out Uri uri) ||
                !string.Equals(uri.Scheme, "baseball", StringComparison.Ordinal) ||
                !string.Equals(uri.Host, "reminder", StringComparison.Ordinal)) return false;
            var values = new Dictionary<string, string>(StringComparer.Ordinal);
            string query = uri.Query.TrimStart('?');
            foreach (string field in query.Split('&'))
            {
                int separator = field.IndexOf('=');
                if (separator <= 0) continue;
                string key = Uri.UnescapeDataString(field.Substring(0, separator));
                string item = Uri.UnescapeDataString(field.Substring(separator + 1));
                values[key] = item;
            }
            if (!values.TryGetValue("source", out string source) || source != "return_reminder" ||
                !values.TryGetValue("destination", out string rawDestination) ||
                !TryNormalizeDestination(rawDestination, out string destination) ||
                !values.TryGetValue("reason", out string rawReason) ||
                !TryNormalizeReason(rawReason, out string reason)) return false;
            int.TryParse(
                Value(values, "development_rules_version"),
                NumberStyles.None,
                CultureInfo.InvariantCulture,
                out int rulesVersion);
            value = new AndroidReminderIntent(
                destination,
                reason,
                TokenOrNone(Value(values, "receipt"), 32),
                TokenOrNone(Value(values, "experiment_id"), 48),
                NormalizeVariant(Value(values, "variant")),
                DayKeyOrNone(Value(values, "saved_day_key")),
                DayKeyOrNone(Value(values, "day")),
                Math.Max(0, rulesVersion));
            return true;
        }

        private static bool TryNormalizeDestination(string value, out string normalized)
        {
            switch ((value ?? string.Empty).ToLowerInvariant())
            {
                case "high_school": normalized = "high_school"; return true;
                case "pro": normalized = "pro"; return true;
                case "setup": normalized = "setup"; return true;
                case "records": normalized = "records"; return true;
                case "daily":
                case "daily_inning": normalized = "daily_inning"; return true;
                default: normalized = null; return false;
            }
        }

        private static bool TryNormalizeReason(string value, out string normalized)
        {
            switch ((value ?? string.Empty).ToLowerInvariant())
            {
                case "daily":
                case "daily_inning": normalized = "daily_inning"; return true;
                case "return_plan": normalized = "return_plan"; return true;
                case "pro_phase": normalized = "pro_phase"; return true;
                case "run_pledge": normalized = "run_pledge"; return true;
                case "high_school_phase": normalized = "high_school_phase"; return true;
                case "next_run_intent": normalized = "next_run_intent"; return true;
                default: normalized = null; return false;
            }
        }

        private static string NormalizeVariant(string value)
        {
            switch ((value ?? string.Empty).ToLowerInvariant())
            {
                case "holdout": return "holdout";
                case "guided": return "guided";
                case "legacy": return "legacy";
                default: return "none";
            }
        }

        private static string DayKeyOrNone(string value)
        {
            if (value?.Length != 8) return "none";
            foreach (char character in value)
                if (!char.IsDigit(character)) return "none";
            return value;
        }

        private static string TokenOrNone(string value, int maximumLength)
        {
            if (string.IsNullOrWhiteSpace(value) || value.Length > maximumLength) return "none";
            foreach (char character in value)
                if (character > 127 ||
                    !char.IsLetterOrDigit(character) && character != '_' && character != '-' && character != '.')
                    return "none";
            return value;
        }

        private static string Value(IReadOnlyDictionary<string, string> values, string key) =>
            values.TryGetValue(key, out string value) ? value : null;
    }
}
