using System;
using System.Collections.Generic;
using System.Linq;
using Baseball.Core.Domain;
using Baseball.Core.HighSchool;

namespace Baseball.Core.Pro
{
    public sealed class ProCareerLegacyEvidence
    {
        public ProCareerLegacyEvidence(PitcherSnapshot finalPitcher, int seasons, int games, int starts,
            int inningsOuts, int strikeouts, int walks, IReadOnlyList<string> awards, string summary)
        {
            FinalPitcher = finalPitcher; Seasons = seasons; Games = games; Starts = starts;
            InningsOuts = inningsOuts; Strikeouts = strikeouts; Walks = walks;
            Awards = awards.ToArray(); Summary = summary;
        }
        public PitcherSnapshot FinalPitcher { get; }
        public int Seasons { get; }
        public int Games { get; }
        public int Starts { get; }
        public int InningsOuts { get; }
        public int Strikeouts { get; }
        public int Walks { get; }
        public IReadOnlyList<string> Awards { get; }
        public string Summary { get; }
    }

    public sealed class ProCareerLegacyCandidate
    {
        public ProCareerLegacyCandidate(CareerSignatureLegacy legacy, int score, ProCareerLegacyEvidence evidence)
        { Legacy = legacy; Score = score; Evidence = evidence; }
        public CareerSignatureLegacy Legacy { get; }
        public int Score { get; }
        public ProCareerLegacyEvidence Evidence { get; }
    }

    /// <summary>Extends the frozen high-school signature rules with signed pro retirement records.</summary>
    public static class ProCareerLegacy
    {
        public static IReadOnlyList<ProCareerLegacyCandidate> Candidates(
            PitcherSnapshot startingPitcher,
            HighSchoolCareerSnapshot highSchool,
            ProCareerSnapshot proCareer)
        {
            var seasons = proCareer.CareerStats.ToList();
            if (seasons.Count == 0 || seasons[seasons.Count - 1].Season != proCareer.CurrentStats.Season)
                seasons.Add(proCareer.CurrentStats);
            var games = seasons.Sum(value => Math.Max(0, value.Games));
            var starts = seasons.Sum(value => Math.Max(0, value.Starts));
            var outs = seasons.Sum(value => Math.Max(0, value.InningsOuts));
            var strikeouts = seasons.Sum(value => Math.Max(0, value.Strikeouts));
            var walks = seasons.Sum(value => Math.Max(0, value.Walks));
            return Enum.GetValues(typeof(CareerSignatureLegacyId)).Cast<CareerSignatureLegacyId>()
                .Select(id =>
                {
                    var legacy = CareerSignatureLegacy.Definition(id);
                    var score = HighSchoolScore(legacy.Family, startingPitcher, highSchool) +
                        ProScore(legacy.Family, highSchool.Pitcher, proCareer, games, starts, outs, strikeouts, walks);
                    var awards = proCareer.Awards.Count == 0 ? "수상 없음" : "수상 " + proCareer.Awards.Count + "회 · " + string.Join(" / ", proCareer.Awards);
                    var summary = "프로 통산 " + games + "경기 " + Innings(outs) + ", " + strikeouts + "탈삼진 " + walks + "볼넷 · 프로 최종 " +
                        RatingSummary(legacy.Family, proCareer.Pitcher) + " · " + awards;
                    return new ProCareerLegacyCandidate(legacy, score,
                        new ProCareerLegacyEvidence(proCareer.Pitcher, seasons.Count, games, starts, outs, strikeouts, walks, proCareer.Awards, summary));
                })
                .OrderByDescending(value => value.Score)
                .ThenBy(value => value.Legacy.Id.Value())
                .Take(3)
                .ToArray();
        }

        private static int HighSchoolScore(CareerSignatureLegacyFamily family, PitcherSnapshot starting, HighSchoolCareerSnapshot state)
        {
            var growth = new[] { Math.Max(0, state.Pitcher.Stuff - starting.Stuff), Math.Max(0, state.Pitcher.Command - starting.Command),
                Math.Max(0, state.Pitcher.Movement - starting.Movement), Math.Max(0, state.Pitcher.Stamina - starting.Stamina) };
            var performance = state.Performance;
            var games = performance.ImportantGamesCompleted;
            var coach = state.ManagerTrust ?? state.RelationshipTrust;
            var catcher = state.CatcherTrust ?? state.RelationshipTrust;
            var rival = state.RivalTrust ?? state.RelationshipTrust;
            var matched = MatchedCount(family, state.SelectedAwakenings);
            switch (family)
            {
                case CareerSignatureLegacyFamily.Power: return growth[0] * 120 + performance.Strikeouts * 12 + matched * 80 + rival;
                case CareerSignatureLegacyFamily.Command: return growth[1] * 120 + Math.Max(0, games * 3 - performance.Walks) * 18 + matched * 80 + coach;
                case CareerSignatureLegacyFamily.Breaking: return growth[2] * 120 + performance.Strikeouts * 9 + matched * 80 + catcher;
                case CareerSignatureLegacyFamily.Endurance: return growth[3] * 120 + performance.Pitches / 2 + matched * 80 + coach;
                case CareerSignatureLegacyFamily.Gamecraft: return (growth[1] + growth[2]) * 60 + Math.Max(0, performance.ExpectedDamage - performance.ActualDamage) / 20 + matched * 80 + Math.Max(coach, Math.Max(catcher, rival));
                default: return growth[1] * 60 + Math.Max(0, games * 3 - performance.Walks) * 12 + matched * 100 + catcher * 2;
            }
        }

        private static int MatchedCount(CareerSignatureLegacyFamily family, IReadOnlyList<AwakeningId> selected)
        {
            AwakeningId[] values;
            switch (family)
            {
                case CareerSignatureLegacyFamily.Power: values = new[] { AwakeningId.ExplosiveFastball, AwakeningId.RisingFourSeam }; break;
                case CareerSignatureLegacyFamily.Command: values = new[] { AwakeningId.PinpointEdge, AwakeningId.RepeatableRelease, AwakeningId.FirstPitchStrike, AwakeningId.ScoutComposure }; break;
                case CareerSignatureLegacyFamily.Breaking: values = new[] { AwakeningId.DisappearingBreaker, AwakeningId.SinkerTunnel, AwakeningId.FrozenChangeup, AwakeningId.SweepingSlider, AwakeningId.CurveballClock }; break;
                case CareerSignatureLegacyFamily.Endurance: values = new[] { AwakeningId.IronArm, AwakeningId.LateInningReserve }; break;
                case CareerSignatureLegacyFamily.Gamecraft: values = new[] { AwakeningId.CalmUnderPressure, AwakeningId.PickoffRhythm, AwakeningId.TwoStrikePlan, AwakeningId.TrafficController, AwakeningId.ScoutComposure }; break;
                default: values = new[] { AwakeningId.BatterySync, AwakeningId.PickoffRhythm, AwakeningId.TrafficController }; break;
            }
            return selected.Count(values.Contains);
        }

        private static int ProScore(CareerSignatureLegacyFamily family, PitcherSnapshot highSchoolPitcher,
            ProCareerSnapshot career, int games, int starts, int outs, int strikeouts, int walks)
        {
            var growth = new[] { Math.Max(0, career.Pitcher.Stuff - highSchoolPitcher.Stuff), Math.Max(0, career.Pitcher.Command - highSchoolPitcher.Command),
                Math.Max(0, career.Pitcher.Movement - highSchoolPitcher.Movement), Math.Max(0, career.Pitcher.Stamina - highSchoolPitcher.Stamina) };
            var award = AwardScore(family, career.Awards);
            switch (family)
            {
                case CareerSignatureLegacyFamily.Power: return growth[0] * 140 + career.Pitcher.Stuff * 8 + strikeouts * 2 + award;
                case CareerSignatureLegacyFamily.Command: return growth[1] * 140 + career.Pitcher.Command * 8 + Math.Max(0, games * 2 - walks) * 2 + career.ManagerTrust * 2 + award;
                case CareerSignatureLegacyFamily.Breaking: return growth[2] * 140 + career.Pitcher.Movement * 8 + strikeouts * 3 / 2 + award;
                case CareerSignatureLegacyFamily.Endurance: return growth[3] * 140 + career.Pitcher.Stamina * 8 + outs / 2 + starts + award;
                case CareerSignatureLegacyFamily.Gamecraft: return (growth[1] + growth[2]) * 70 + (career.Pitcher.Command + career.Pitcher.Movement) * 4 + Math.Max(0, strikeouts - walks) + games + Math.Max(career.ManagerTrust, career.CatcherTrust) * 2 + award;
                default: return (growth[1] + growth[3]) * 70 + (career.Pitcher.Command + career.Pitcher.Stamina) * 4 + Math.Max(0, games * 2 - walks) + games + career.CatcherTrust * 3 + award;
            }
        }

        private static int AwardScore(CareerSignatureLegacyFamily family, IReadOnlyList<string> awards)
        {
            var keywords = family == CareerSignatureLegacyFamily.Power || family == CareerSignatureLegacyFamily.Breaking ? new[] { "탈삼진" } :
                family == CareerSignatureLegacyFamily.Endurance ? new[] { "이닝", "완투" } : new[] { "최소 실점", "무실점" };
            return awards.Count * 30 + awards.Count(award => keywords.Any(award.Contains)) * 120;
        }
        private static string RatingSummary(CareerSignatureLegacyFamily family, PitcherSnapshot pitcher)
        {
            if (family == CareerSignatureLegacyFamily.Power) return "구위 " + pitcher.Stuff;
            if (family == CareerSignatureLegacyFamily.Command) return "제구 " + pitcher.Command;
            if (family == CareerSignatureLegacyFamily.Breaking) return "변화구 " + pitcher.Movement;
            if (family == CareerSignatureLegacyFamily.Endurance) return "체력 " + pitcher.Stamina;
            if (family == CareerSignatureLegacyFamily.Gamecraft) return "제구 " + pitcher.Command + "·변화구 " + pitcher.Movement;
            return "제구 " + pitcher.Command + "·체력 " + pitcher.Stamina;
        }
        private static string Innings(int outs)
        { var safe = Math.Max(0, outs); return safe / 3 + (safe % 3 == 1 ? "⅓이닝" : safe % 3 == 2 ? "⅔이닝" : "이닝"); }
    }
}
