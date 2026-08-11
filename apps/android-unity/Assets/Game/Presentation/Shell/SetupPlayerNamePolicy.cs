using System;

namespace Baseball.Presentation.Shell
{
    public static class SetupPlayerNamePolicy
    {
        public const int MaximumLength = 12;

        public static bool TryUpdate(string current, string input, out string next)
        {
            string candidate = (input ?? string.Empty).Trim();
            if (candidate.Length > MaximumLength)
            {
                next = current ?? string.Empty;
                return false;
            }
            next = candidate;
            return true;
        }

        public static string Resolve(string draft, string suggested)
        {
            string entered = (draft ?? string.Empty).Trim();
            if (entered.Length > 0) return entered;
            string fallback = (suggested ?? string.Empty).Trim();
            return fallback.Length > 0 ? fallback : "민서준";
        }
    }
}
