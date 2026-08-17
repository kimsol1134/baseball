using System;
using System.Collections.Generic;
using System.Linq;
using Baseball.Core.Domain;

namespace Baseball.Application.HighSchool
{
    public sealed class PitcherRatingsReadModel
    {
        public PitcherRatingsReadModel(int stuff, int command, int movement, int stamina)
        {
            Stuff = stuff;
            Command = command;
            Movement = movement;
            Stamina = stamina;
        }

        public int Stuff { get; }
        public int Command { get; }
        public int Movement { get; }
        public int Stamina { get; }
        public int Total => Stuff + Command + Movement + Stamina;
    }


    public sealed class CareerPerformanceReadModel
    {
        public CareerPerformanceReadModel(
            int importantGames = 0,
            int pitches = 0,
            int outs = 0,
            int strikeouts = 0,
            int walks = 0,
            int hits = 0,
            int runsAllowed = 0)
        {
            ImportantGames = importantGames;
            Pitches = pitches;
            Outs = outs;
            Strikeouts = strikeouts;
            Walks = walks;
            Hits = hits;
            RunsAllowed = runsAllowed;
        }

        public int ImportantGames { get; }
        public int Pitches { get; }
        public int Outs { get; }
        public int Strikeouts { get; }
        public int Walks { get; }
        public int Hits { get; }
        public int RunsAllowed { get; }
    }


    public sealed class CareerGameLineReadModel
    {
        public CareerGameLineReadModel(
            int season,
            int week,
            int outingNumber,
            bool played,
            bool started,
            int outs,
            int strikeouts,
            int walks,
            int? hits,
            int runsAllowed,
            int pitches,
            int teamRuns,
            int opponentRuns,
            string decision,
            int? homeRuns = null,
            int? recordedHits = null)
        {
            Season = season;
            Week = week;
            OutingNumber = outingNumber;
            Played = played;
            Started = started;
            Outs = outs;
            Strikeouts = strikeouts;
            Walks = walks;
            Hits = hits ?? 0;
            RecordedHits = recordedHits;
            RunsAllowed = runsAllowed;
            Pitches = pitches;
            TeamRuns = teamRuns;
            OpponentRuns = opponentRuns;
            Decision = decision;
            HomeRuns = homeRuns;
        }

        public int Season { get; }
        public int Week { get; }
        public int OutingNumber { get; }
        public bool Played { get; }
        public bool Started { get; }
        public int Outs { get; }
        public int Strikeouts { get; }
        public int Walks { get; }
        /// <summary>Legacy compatibility value. Use RecordedHits for record/league surfaces.</summary>
        public int Hits { get; }
        /// <summary>
        /// Null means the source result did not record hits. It must not be rendered as zero.
        /// </summary>
        public int? RecordedHits { get; }
        /// <summary>
        /// Null means the source result did not record home runs. It must not be rendered as zero.
        /// </summary>
        public int? HomeRuns { get; }
        public int RunsAllowed { get; }
        public int Pitches { get; }
        public int TeamRuns { get; }
        public int OpponentRuns { get; }
        public string Decision { get; }
        public bool IsQualityStart => PitchingMetrics.IsQualityStart(Started, Outs, RunsAllowed);
    }


    /// <summary>
    /// Authoritative raw pitching totals plus Core-calculated modern pitching metrics. Nullable
    /// totals are deliberately unavailable: an old or direct-play result that did not record a
    /// hit/home-run count is never silently converted to a zero.
    /// </summary>
    public sealed class PitchingRecordReadModel
    {
        public PitchingRecordReadModel(
            int games,
            int starts,
            int outs,
            int strikeouts,
            int walks,
            int runsAllowed,
            int wins = 0,
            int losses = 0,
            int saves = 0,
            int? hits = null,
            int? homeRuns = null,
            int? pitches = null,
            int? qualityStarts = null)
        {
            Games = games;
            Starts = starts;
            Outs = outs;
            Strikeouts = strikeouts;
            Walks = walks;
            RunsAllowed = runsAllowed;
            Wins = wins;
            Losses = losses;
            Saves = saves;
            Hits = hits;
            HomeRuns = homeRuns;
            Pitches = pitches;
            QualityStarts = qualityStarts;
        }

        public int Games { get; }
        public int Starts { get; }
        public int Outs { get; }
        public int Strikeouts { get; }
        public int Walks { get; }
        public int RunsAllowed { get; }
        public int Wins { get; }
        public int Losses { get; }
        public int Saves { get; }
        public int? Hits { get; }
        public int? HomeRuns { get; }
        public int? Pitches { get; }
        public int? QualityStarts { get; }

        public double Innings => PitchingMetrics.Innings(Outs);
        public string InningsText => PitchingMetrics.InningsText(Outs);
        public double? RunsPerNine => PitchingMetrics.RunsPer9(RunsAllowed, Outs);
        public double? StrikeoutsPerNine => PitchingMetrics.Per9(Strikeouts, Outs);
        public double? WalksPerNine => PitchingMetrics.Per9(Walks, Outs);
        public double? StrikeoutToWalk => PitchingMetrics.StrikeoutToWalk(Strikeouts, Walks);
        public double? Whip => Hits.HasValue
            ? PitchingMetrics.Whip(Hits.Value, Walks, Outs)
            : null;
        public double? HitsPerNine => Hits.HasValue
            ? PitchingMetrics.Per9(Hits.Value, Outs)
            : null;
        public double? HomeRunsPerNine => HomeRuns.HasValue
            ? PitchingMetrics.Per9(HomeRuns.Value, Outs)
            : null;
        public double? FieldingIndependentPitching => HomeRuns.HasValue
            ? PitchingMetrics.Fip(HomeRuns.Value, Walks, 0, Strikeouts, Outs)
            : null;
        public int? BattersFaced => Hits.HasValue
            ? PitchingMetrics.BattersFaced(Outs, Hits.Value, Walks)
            : null;
        public double? StrikeoutRate => BattersFaced.HasValue
            ? PitchingMetrics.StrikeoutRate(Strikeouts, BattersFaced.Value)
            : null;
        public double? BattingAverageOnBallsInPlay => Hits.HasValue && HomeRuns.HasValue
            ? PitchingMetrics.Babip(Hits.Value, HomeRuns.Value, Strikeouts, Outs, Walks)
            : null;

        public static PitchingRecordReadModel FromGameLines(
            IReadOnlyList<CareerGameLineReadModel> gameLines)
        {
            var lines = (gameLines ?? Array.Empty<CareerGameLineReadModel>()).ToArray();
            var hits = KnownSum(lines.Select(value => value.RecordedHits));
            var homeRuns = KnownSum(lines.Select(value => value.HomeRuns));
            return new PitchingRecordReadModel(
                lines.Length,
                lines.Count(value => value.Started),
                lines.Sum(value => value.Outs),
                lines.Sum(value => value.Strikeouts),
                lines.Sum(value => value.Walks),
                lines.Sum(value => value.RunsAllowed),
                lines.Count(value => string.Equals(value.Decision, "win", StringComparison.Ordinal)),
                lines.Count(value => string.Equals(value.Decision, "loss", StringComparison.Ordinal)),
                lines.Count(value => string.Equals(value.Decision, "save", StringComparison.Ordinal)),
                hits,
                homeRuns,
                lines.Sum(value => value.Pitches),
                lines.Count(value => value.IsQualityStart));
        }

        private static int? KnownSum(IEnumerable<int?> values)
        {
            var items = values.ToArray();
            return items.All(value => value.HasValue)
                ? items.Sum(value => value.Value)
                : (int?)null;
        }
    }
}
