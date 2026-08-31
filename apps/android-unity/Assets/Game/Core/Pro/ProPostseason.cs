using System.Linq;
using Baseball.Core.HighSchool;

namespace Baseball.Core.Pro
{
    public enum ProAutumnRound { WildCard, Semifinal, Final, Playoff }
    public enum ProPostseasonResult { InProgress, Eliminated, Champion, RunnerUp, DidNotQualify, Unavailable }

    public sealed class ProPostseasonState
    {
        public ProPostseasonState(int seed, ProAutumnRound? currentRound, ProPostseasonResult result, int gamesPlayed)
        {
            Seed = seed;
            CurrentRound = currentRound;
            Result = result;
            GamesPlayed = gamesPlayed;
        }

        public int Seed { get; }
        public ProAutumnRound? CurrentRound { get; }
        public ProPostseasonResult Result { get; }
        public int GamesPlayed { get; }
    }

    public static class ProPostseasonRules
    {
        public const int QualificationCut = 5;
        public const int MaximumPlayerPathGames = 5;

        public static ProSeasonTrigger Trigger(ProAutumnRound round)
        {
            switch (round)
            {
                case ProAutumnRound.WildCard: return ProSeasonTrigger.AutumnWildCard;
                case ProAutumnRound.Semifinal: return ProSeasonTrigger.AutumnSemifinal;
                case ProAutumnRound.Playoff: return ProSeasonTrigger.AutumnPlayoff;
                default: return ProSeasonTrigger.AutumnFinal;
            }
        }

        public static bool IsAutumn(ProSeasonTrigger? trigger)
        {
            return trigger == ProSeasonTrigger.AutumnWildCard
                || trigger == ProSeasonTrigger.AutumnSemifinal
                || trigger == ProSeasonTrigger.AutumnPlayoff
                || trigger == ProSeasonTrigger.AutumnFinal;
        }

        public static ProAutumnRound FirstRound(int seed)
        {
            if (seed == 1) return ProAutumnRound.Final;
            if (seed == 2) return ProAutumnRound.Playoff;
            if (seed == 3) return ProAutumnRound.Semifinal;
            return ProAutumnRound.WildCard;
        }

        public static ProAutumnRound? NextRound(ProAutumnRound round)
        {
            switch (round)
            {
                case ProAutumnRound.WildCard: return ProAutumnRound.Semifinal;
                case ProAutumnRound.Semifinal: return ProAutumnRound.Playoff;
                case ProAutumnRound.Playoff: return ProAutumnRound.Final;
                default: return null;
            }
        }

        public static int ExtraOffset(ProAutumnRound round)
        {
            switch (round)
            {
                case ProAutumnRound.WildCard: return 3;
                case ProAutumnRound.Semifinal: return 4;
                case ProAutumnRound.Playoff: return 5;
                default: return 6;
            }
        }

        public static int MaximumBatters(ProAutumnRound round)
        {
            switch (round)
            {
                case ProAutumnRound.WildCard: return 4;
                case ProAutumnRound.Semifinal: return 5;
                case ProAutumnRound.Playoff: return 6;
                default: return 7;
            }
        }

        public static string QualificationNews(int seed)
        {
            switch (seed)
            {
                case 1: return "정규시즌 1위입니다. 우승 결정전 한 판이 남았습니다.";
                case 2: return "정규시즌 2위입니다. 플레이오프 한 판부터 올라갑니다.";
                case 3: return "정규시즌 3위입니다. 준플레이오프 한 판부터 시작합니다.";
                case 4: return "정규시즌 4위입니다. 와일드카드에서 한 승이면 올라갑니다.";
                case 5: return "정규시즌 5위입니다. 와일드카드에서 두 번을 이겨야 합니다.";
                default: return "플레이오프가 열립니다.";
            }
        }

        public static bool CanPitchAutumn(ProLevel level, int injuryWeeks)
        {
            return level == ProLevel.Major && injuryWeeks <= 0;
        }

        public static ProPostseasonState PlayerPath(ProPostseasonState evaluated, ProLevel level, int injuryWeeks)
        {
            if (evaluated == null || evaluated.Result != ProPostseasonResult.InProgress) return evaluated;
            if (CanPitchAutumn(level, injuryWeeks)) return evaluated;
            return new ProPostseasonState(evaluated.Seed, null, ProPostseasonResult.Unavailable, 0);
        }

        public static string UnavailableNews(ProLevel level)
        {
            return level == ProLevel.Minor
                ? "구단은 가을에 올랐지만 2군이라 마운드에 서지 못했습니다."
                : "구단은 가을에 올랐지만 부상으로 마운드에 서지 못했습니다.";
        }

        public static string EliminationNews(ProAutumnRound? round)
        {
            if (round == ProAutumnRound.WildCard) return "와일드카드에서 탈락했습니다.";
            if (round == ProAutumnRound.Semifinal) return "준플레이오프에서 탈락했습니다.";
            return "플레이오프에서 탈락했습니다.";
        }

        public static ProPostseasonState EvaluateEndOfSeason(ProCareerSnapshot state)
        {
            var games = LeagueTable.GamesPlayed(LeagueTable.WeeksPerSeason);
            var results = (state.GameLines ?? new ProGameLine[0])
                .Select(line => new LeagueTable.PlayerGameResult(line.TeamRuns, line.OpponentRuns))
                .ToArray();
            var rows = LeagueTable.Standings(state.Season, state.ProCareerId, games, state.Team.Id, results);
            var rank = rows.Select((row, index) => new { row, index })
                .FirstOrDefault(item => item.row.TeamId == state.Team.Id);
            var place = rank == null ? 10 : rank.index + 1;
            if (place > QualificationCut)
                return new ProPostseasonState(0, null, ProPostseasonResult.DidNotQualify, 0);
            var round = FirstRound(place);
            return new ProPostseasonState(place, round, ProPostseasonResult.InProgress, 0);
        }

        public static ProPostseasonState Resolving(ProPostseasonState state, bool won)
        {
            var played = state.GamesPlayed + 1;
            if (!state.CurrentRound.HasValue)
                return new ProPostseasonState(state.Seed, null, ProPostseasonResult.Eliminated, played);
            if (state.CurrentRound == ProAutumnRound.WildCard)
                return ResolvingWildCard(state, won, played);
            if (won)
            {
                var next = NextRound(state.CurrentRound.Value);
                if (next.HasValue)
                    return new ProPostseasonState(state.Seed, next, ProPostseasonResult.InProgress, played);
                return new ProPostseasonState(state.Seed, ProAutumnRound.Final, ProPostseasonResult.Champion, played);
            }
            var result = state.CurrentRound == ProAutumnRound.Final
                ? ProPostseasonResult.RunnerUp
                : ProPostseasonResult.Eliminated;
            return new ProPostseasonState(state.Seed, state.CurrentRound, result, played);
        }

        private static ProPostseasonState ResolvingWildCard(ProPostseasonState state, bool won, int played)
        {
            var advance = new ProPostseasonState(state.Seed, ProAutumnRound.Semifinal, ProPostseasonResult.InProgress, played);
            var stay = new ProPostseasonState(state.Seed, ProAutumnRound.WildCard, ProPostseasonResult.InProgress, played);
            var eliminated = new ProPostseasonState(state.Seed, ProAutumnRound.WildCard, ProPostseasonResult.Eliminated, played);
            if (state.Seed == 4)
            {
                if (won) return advance;
                return played == 1 ? stay : eliminated;
            }
            if (!won) return eliminated;
            return played == 1 ? stay : advance;
        }

        public static int HofBonus(ProPostseasonResult result)
        {
            switch (result)
            {
                case ProPostseasonResult.Champion: return 4;
                case ProPostseasonResult.RunnerUp: return 2;
                case ProPostseasonResult.Eliminated: return 1;
                default: return 0;
            }
        }
    }
}
