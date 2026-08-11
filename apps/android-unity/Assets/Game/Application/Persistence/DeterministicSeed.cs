using System;
using System.Globalization;
using Baseball.Core.Random;

namespace Baseball.Application.Persistence
{
    /// <summary>Normalizes user/install-derived text into Core's positive decimal seed wire.</summary>
    public static class DeterministicSeed
    {
        public static string Normalize(string value)
        {
            var trimmed = value?.Trim();
            if (ulong.TryParse(trimmed, NumberStyles.None, CultureInfo.InvariantCulture, out var parsed) &&
                parsed > 0)
            {
                return parsed.ToString(CultureInfo.InvariantCulture);
            }

            var hash = StableHash.Fnv1A64Value(string.IsNullOrEmpty(trimmed) ? "baseball.seed" : trimmed);
            return Math.Max(1UL, hash >> 1).ToString(CultureInfo.InvariantCulture);
        }
    }
}
