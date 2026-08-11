using System;
using System.Globalization;

namespace Baseball.Platform.Analytics
{
    /// <summary>
    /// Maps the validated product schema onto Firebase Unity's long/double/string Parameter
    /// overloads. Logical values remain bool everywhere else and use 1/0 only at this SDK edge.
    /// </summary>
    public static class FirebaseAnalyticsValueAdapter
    {
        public static object Normalize(object value)
        {
            if (value == null) throw new ArgumentNullException(nameof(value));
            if (value is bool logical) return logical ? 1L : 0L;
            if (value is byte || value is sbyte || value is short || value is ushort ||
                value is int || value is uint || value is long)
            {
                return Convert.ToInt64(value, CultureInfo.InvariantCulture);
            }
            if (value is float || value is double || value is decimal)
            {
                return Convert.ToDouble(value, CultureInfo.InvariantCulture);
            }
            return Convert.ToString(value, CultureInfo.InvariantCulture);
        }
    }
}
