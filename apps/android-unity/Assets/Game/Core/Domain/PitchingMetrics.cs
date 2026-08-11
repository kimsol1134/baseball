using System;
using System.Collections.Generic;
using System.Globalization;

namespace Baseball.Core.Domain
{
    public static class PitchingMetrics
    {
        public const double LeagueRunsPer9 = 3.5;
        public const double FipConstant = 3.67;

        public static double Innings(int outs) => Math.Max(0, outs) / 3.0;

        public static string InningsText(int outs)
        {
            var safe = Math.Max(0, outs);
            return safe / 3 + (safe % 3 == 0 ? string.Empty : "." + safe % 3);
        }

        public static double? Per9(int count, int outs) => outs > 0 ? count * 27.0 / outs : (double?)null;
        public static double? RunsPer9(int runs, int outs) => Per9(runs, outs);
        public static double? Whip(int hits, int walks, int outs) => outs > 0 ? (hits + walks) * 3.0 / outs : (double?)null;
        public static double? StrikeoutToWalk(int strikeouts, int walks) => walks > 0 ? (double)strikeouts / walks : (double?)null;
        public static int BattersFaced(int outs, int hits, int walks) => Math.Max(0, outs) + Math.Max(0, hits) + Math.Max(0, walks);
        public static double? StrikeoutRate(int strikeouts, int battersFaced) => battersFaced > 0 ? (double)strikeouts / battersFaced : (double?)null;
        public static double? WalkRate(int walks, int battersFaced) => battersFaced > 0 ? (double)walks / battersFaced : (double?)null;

        public static double? Babip(int hits, int homeRuns, int strikeouts, int outs, int walks)
        {
            var ballsInPlay = BattersFaced(outs, hits, walks) - walks - strikeouts - homeRuns;
            return ballsInPlay > 0 ? (double)(hits - homeRuns) / ballsInPlay : (double?)null;
        }

        public static double? Fip(
            int homeRuns,
            int walks,
            int hitByPitch,
            int strikeouts,
            int outs,
            double leagueConstant = FipConstant)
        {
            if (outs <= 0) return null;
            var raw = (13.0 * homeRuns + 3.0 * (walks + hitByPitch) - 2.0 * strikeouts) / Innings(outs);
            return raw + leagueConstant;
        }

        public static bool IsQualityStart(bool started, int outs, int runsAllowed) =>
            started && outs >= 18 && runsAllowed <= 3;

        public static double? WinRate(int wins, int losses)
        {
            var decided = wins + losses;
            return decided > 0 ? (double)wins / decided : (double?)null;
        }

        public static string RateText(double? value)
        {
            if (!value.HasValue) return "-";
            var text = value.Value.ToString("0.000", CultureInfo.InvariantCulture);
            return text.StartsWith("0.", StringComparison.Ordinal) ? text.Substring(1) : text;
        }
    }
}
