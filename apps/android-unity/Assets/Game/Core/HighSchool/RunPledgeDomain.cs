using System;
using System.Collections.Generic;
using System.Linq;

namespace Baseball.Core.HighSchool
{
    public enum RunPledgeTier
    {
        Safe,
        Bold,
        Legendary
    }

    public enum RunPledgeAwakeningFamily
    {
        Body,
        Command,
        Breaking,
        Game
    }

    public static class RunPledgeWire
    {
        public static string Value(this RunPledgeTier value)
        {
            switch (value)
            {
                case RunPledgeTier.Safe: return "safe";
                case RunPledgeTier.Bold: return "bold";
                case RunPledgeTier.Legendary: return "legendary";
                default: throw new ArgumentOutOfRangeException(nameof(value));
            }
        }

        public static int RewardPermille(this RunPledgeTier value)
        {
            switch (value)
            {
                case RunPledgeTier.Safe: return 100;
                case RunPledgeTier.Bold: return 200;
                case RunPledgeTier.Legendary: return 350;
                default: throw new ArgumentOutOfRangeException(nameof(value));
            }
        }

        public static string Title(this RunPledgeTier value)
        {
            switch (value)
            {
                case RunPledgeTier.Safe: return "안전";
                case RunPledgeTier.Bold: return "도전";
                case RunPledgeTier.Legendary: return "전설";
                default: throw new ArgumentOutOfRangeException(nameof(value));
            }
        }

        public static string Value(this RunPledgeAwakeningFamily value)
        {
            switch (value)
            {
                case RunPledgeAwakeningFamily.Body: return "body";
                case RunPledgeAwakeningFamily.Command: return "command";
                case RunPledgeAwakeningFamily.Breaking: return "breaking";
                case RunPledgeAwakeningFamily.Game: return "game";
                default: throw new ArgumentOutOfRangeException(nameof(value));
            }
        }

        public static string Title(this RunPledgeAwakeningFamily value)
        {
            switch (value)
            {
                case RunPledgeAwakeningFamily.Body: return "힘·체력";
                case RunPledgeAwakeningFamily.Command: return "제구";
                case RunPledgeAwakeningFamily.Breaking: return "변화구";
                case RunPledgeAwakeningFamily.Game: return "경기 운영";
                default: throw new ArgumentOutOfRangeException(nameof(value));
            }
        }
    }

    public sealed class RunPledgeProgress : IEquatable<RunPledgeProgress>
    {
        public RunPledgeProgress(
            int current,
            int target,
            bool achieved,
            string line,
            int? unachievedRatioPermille = null)
        {
            Current = current;
            Target = target;
            Achieved = achieved;
            Line = line ?? throw new ArgumentNullException(nameof(line));
            UnachievedRatioPermille = unachievedRatioPermille;
        }

        public int Current { get; }
        public int Target { get; }
        public bool Achieved { get; }
        public string Line { get; }
        public int? UnachievedRatioPermille { get; }

        public int RatioPermille
        {
            get
            {
                if (Target <= 0) return Achieved ? 1000 : 0;
                if (Achieved) return 1000;
                if (UnachievedRatioPermille.HasValue)
                    return Math.Min(999, Math.Max(0, UnachievedRatioPermille.Value));
                return Math.Min(999, Math.Max(0, Current) * 1000 / Target);
            }
        }

        public double Ratio => RatioPermille / 1000.0;

        public bool Equals(RunPledgeProgress other)
        {
            return other != null &&
                Current == other.Current &&
                Target == other.Target &&
                Achieved == other.Achieved &&
                string.Equals(Line, other.Line, StringComparison.Ordinal) &&
                UnachievedRatioPermille == other.UnachievedRatioPermille;
        }

        public override bool Equals(object obj) => Equals(obj as RunPledgeProgress);

        public override int GetHashCode()
        {
            unchecked
            {
                var hash = Current;
                hash = (hash * 397) ^ Target;
                hash = (hash * 397) ^ Achieved.GetHashCode();
                hash = (hash * 397) ^ StringComparer.Ordinal.GetHashCode(Line);
                hash = (hash * 397) ^ UnachievedRatioPermille.GetHashCode();
                return hash;
            }
        }
    }

    public sealed class NextRunIntent : IEquatable<NextRunIntent>
    {
        public NextRunIntent(string pledgeId, int sourceLifeNumber, string reason)
        {
            PledgeId = pledgeId ?? throw new ArgumentNullException(nameof(pledgeId));
            SourceLifeNumber = sourceLifeNumber;
            Reason = reason ?? throw new ArgumentNullException(nameof(reason));
        }

        public string PledgeId { get; }
        public int SourceLifeNumber { get; }
        public string Reason { get; }

        public bool Equals(NextRunIntent other)
        {
            return other != null &&
                string.Equals(PledgeId, other.PledgeId, StringComparison.Ordinal) &&
                SourceLifeNumber == other.SourceLifeNumber &&
                string.Equals(Reason, other.Reason, StringComparison.Ordinal);
        }

        public override bool Equals(object obj) => Equals(obj as NextRunIntent);

        public override int GetHashCode()
        {
            unchecked
            {
                var hash = StringComparer.Ordinal.GetHashCode(PledgeId);
                hash = (hash * 397) ^ SourceLifeNumber;
                hash = (hash * 397) ^ StringComparer.Ordinal.GetHashCode(Reason);
                return hash;
            }
        }
    }

    /// <summary>
    /// Immutable pledge-evaluation input. Application adapters can construct it without exposing
    /// their persistence models; <see cref="FromSnapshot"/> is the canonical Core projection.
    /// </summary>
    public sealed class RunPledgeContext
    {
        public RunPledgeContext(
            int lifeNumber,
            int stuff,
            int command,
            int movement,
            int importantGamesCompleted = 0,
            int strikeouts = 0,
            int walks = 0,
            int cleanGames = 0,
            IReadOnlyList<AwakeningId> selectedAwakenings = null,
            int fatigue = 0,
            int armRisk = 0,
            int injuryRecovery = 0,
            int fanInterest = 0,
            int relationshipTrust = 0,
            int? managerTrust = null,
            int? catcherTrust = null,
            int? rivalTrust = null,
            DraftOutcome? draftOutcome = null,
            int? draftEvaluationScore = null,
            int draftForecastScore = 0,
            int rivalStrikeouts = 0)
        {
            LifeNumber = lifeNumber;
            Stuff = stuff;
            Command = command;
            Movement = movement;
            ImportantGamesCompleted = importantGamesCompleted;
            Strikeouts = strikeouts;
            Walks = walks;
            CleanGames = cleanGames;
            SelectedAwakenings = (selectedAwakenings ?? Array.Empty<AwakeningId>()).ToArray();
            Fatigue = fatigue;
            ArmRisk = armRisk;
            InjuryRecovery = injuryRecovery;
            FanInterest = fanInterest;
            RelationshipTrust = relationshipTrust;
            ManagerTrust = managerTrust;
            CatcherTrust = catcherTrust;
            RivalTrust = rivalTrust;
            DraftOutcome = draftOutcome;
            DraftEvaluationScore = draftEvaluationScore;
            DraftForecastScore = draftForecastScore;
            RivalStrikeouts = rivalStrikeouts;
        }

        public int LifeNumber { get; }
        public int Stuff { get; }
        public int Command { get; }
        public int Movement { get; }
        public int ImportantGamesCompleted { get; }
        public int Strikeouts { get; }
        public int Walks { get; }
        public int CleanGames { get; }
        public IReadOnlyList<AwakeningId> SelectedAwakenings { get; }
        public int Fatigue { get; }
        public int ArmRisk { get; }
        public int InjuryRecovery { get; }
        public int FanInterest { get; }
        public int RelationshipTrust { get; }
        public int? ManagerTrust { get; }
        public int? CatcherTrust { get; }
        public int? RivalTrust { get; }
        public DraftOutcome? DraftOutcome { get; }
        public int? DraftEvaluationScore { get; }
        public int DraftForecastScore { get; }
        public int RivalStrikeouts { get; }

        public static RunPledgeContext FromSnapshot(
            HighSchoolCareerSnapshot state,
            int rivalStrikeouts = 0)
        {
            if (state == null) throw new ArgumentNullException(nameof(state));
            if (state.Pitcher == null) throw new ArgumentException("Pitcher is required.", nameof(state));
            if (state.Performance == null) throw new ArgumentException("Performance is required.", nameof(state));

            var lines = state.SeasonLog ?? Array.Empty<ProGameLine>();
            var forecastScore = state.DraftResult == null
                ? HighSchoolCareerEngine.DraftForecast(state).Score
                : state.DraftResult.EvaluationScore;
            return new RunPledgeContext(
                state.LifeNumber,
                state.Pitcher.Stuff,
                state.Pitcher.Command,
                state.Pitcher.Movement,
                state.Performance.ImportantGamesCompleted,
                state.Performance.Strikeouts,
                state.Performance.Walks,
                lines.Count(value => value.Played && value.RunsAllowed == 0),
                state.SelectedAwakenings,
                state.Fatigue,
                state.ArmRisk ?? 0,
                state.InjuryRecovery ?? 0,
                state.FanInterest,
                state.RelationshipTrust,
                state.ManagerTrust,
                state.CatcherTrust,
                state.RivalTrust,
                state.DraftResult?.Outcome,
                state.DraftResult?.EvaluationScore,
                forecastScore,
                rivalStrikeouts);
        }
    }
}
