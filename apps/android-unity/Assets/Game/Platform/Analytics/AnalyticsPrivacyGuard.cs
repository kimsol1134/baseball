using System;
using System.Collections.Generic;
using System.Text.RegularExpressions;

namespace Baseball.Platform.Analytics
{
    public static class AnalyticsPrivacyGuard
    {
        private const int MaximumPropertyCount = 24;
        private const int MaximumStringLength = 64;
        private static readonly Regex KeyPattern = new Regex("^[a-z][a-z0-9_]{0,47}$", RegexOptions.CultureInvariant);
        private static readonly HashSet<string> ReservedKeys = new HashSet<string>(StringComparer.Ordinal)
        {
            "app_version", "build", "distribution", "environment", "platform",
            "event_schema_version", "ingestion_origin"
        };
        private static readonly HashSet<string> ForbiddenKeys = new HashSet<string>(StringComparer.Ordinal)
        {
            "name", "player_name", "user_name", "seed", "raw_seed", "career_id", "save",
            "save_json", "free_text", "message", "file_name", "filename", "path", "email",
            "phone", "latitude", "longitude", "location", "android_id", "advertising_id",
            "ad_id", "idfa", "image", "share_image"
        };

        public static Dictionary<string, object> ValidateAndCopy(IReadOnlyDictionary<string, object> properties)
        {
            var result = new Dictionary<string, object>(StringComparer.Ordinal);
            if (properties == null) return result;
            if (properties.Count > MaximumPropertyCount)
            {
                throw new ArgumentException($"Analytics events support at most {MaximumPropertyCount} product properties.");
            }

            foreach (KeyValuePair<string, object> pair in properties)
            {
                if (string.IsNullOrEmpty(pair.Key) || !KeyPattern.IsMatch(pair.Key))
                {
                    throw new ArgumentException($"Analytics property key is not low-cardinality snake_case: {pair.Key}");
                }
                if (ReservedKeys.Contains(pair.Key))
                {
                    throw new ArgumentException($"Analytics context key is reserved: {pair.Key}");
                }
                if (ForbiddenKeys.Contains(pair.Key))
                {
                    throw new ArgumentException($"Analytics property is forbidden by the privacy contract: {pair.Key}");
                }

                result[pair.Key] = ValidateValue(pair.Key, pair.Value);
            }
            return result;
        }

        private static object ValidateValue(string key, object value)
        {
            if (value == null) throw new ArgumentException($"Analytics property cannot be null: {key}");
            if (value is bool) return value;
            if (value is byte || value is sbyte || value is short || value is ushort || value is int || value is uint || value is long)
            {
                return Convert.ToInt64(value);
            }
            if (value is float || value is double || value is decimal)
            {
                return Convert.ToDouble(value);
            }
            if (value is string text)
            {
                if (text.Length > MaximumStringLength)
                {
                    throw new ArgumentException($"Analytics string property is too long: {key}");
                }
                return text;
            }
            if (value.GetType().IsEnum) return value.ToString().ToLowerInvariant();
            throw new ArgumentException($"Unsupported analytics property type for {key}: {value.GetType().Name}");
        }
    }
}
