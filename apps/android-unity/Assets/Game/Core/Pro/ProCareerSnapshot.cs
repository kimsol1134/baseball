using System.Collections.Generic;
using System.Linq;
using Baseball.Core.Domain;
using Baseball.Core.HighSchool;

namespace Baseball.Core.Pro
{
    public sealed class ProCareerSnapshot
    {
        public string ProCareerId { get; internal set; }
        public ulong Revision { get; internal set; }
        public ProCareerPhase Phase { get; internal set; }
        public PlayerIdentitySnapshot Identity { get; internal set; }
        public PitcherSnapshot Pitcher { get; internal set; }
        public DraftTeamSnapshot Team { get; internal set; }
        public ProEntitlementSnapshot Entitlement { get; internal set; }
        public int Age { get; internal set; }
        public int Season { get; internal set; }
        public int Week { get; internal set; }
        public ProLevel Level { get; internal set; }
        public ProRole Role { get; internal set; }
        public int ManagerTrust { get; internal set; }
        public int CatcherTrust { get; internal set; }
        public int Fatigue { get; internal set; }
        public int InjuryWeeks { get; internal set; }
        public int ServiceYears { get; internal set; }
        public bool MilitaryCompleted { get; internal set; }
        public ProContractSnapshot Contract { get; internal set; }
        public ProSeasonStats CurrentStats { get; internal set; }
        public IReadOnlyList<ProGameLine> GameLines { get; internal set; }
        public IReadOnlyList<ProSeasonStats> CareerStats { get; internal set; }
        public IReadOnlyList<string> Awards { get; internal set; }
        public IReadOnlyList<string> Milestones { get; internal set; }
        public IReadOnlyList<string> News { get; internal set; }
        public int? HallOfFameScore { get; internal set; }
        public string Commitment { get; internal set; }
        public int? BalanceVersion { get; internal set; }
        public ProSeasonSegment? SeasonSegment { get; internal set; }
        public ProSeasonTrigger? SeasonTrigger { get; internal set; }
        public ProRivalBatter CurrentRival { get; internal set; }
        public IReadOnlyList<ProSeasonTension> SeasonTensions { get; internal set; }
        public int? SeasonImportantGames { get; internal set; }
        public ProSeasonDecision PendingDecision { get; internal set; }
        public IReadOnlyList<ProDecisionRecord> DecisionHistory { get; internal set; }
        public ProDevelopmentProgress DevelopmentProgress { get; internal set; }

        internal ProCareerSnapshot Clone()
        {
            return new ProCareerSnapshot
            {
                ProCareerId = ProCareerId,
                Revision = Revision,
                Phase = Phase,
                Identity = Identity,
                Pitcher = Pitcher,
                Team = Team,
                Entitlement = Entitlement,
                Age = Age,
                Season = Season,
                Week = Week,
                Level = Level,
                Role = Role,
                ManagerTrust = ManagerTrust,
                CatcherTrust = CatcherTrust,
                Fatigue = Fatigue,
                InjuryWeeks = InjuryWeeks,
                ServiceYears = ServiceYears,
                MilitaryCompleted = MilitaryCompleted,
                Contract = Contract,
                CurrentStats = CurrentStats,
                GameLines = GameLines == null ? null : GameLines.ToArray(),
                CareerStats = CareerStats == null ? new ProSeasonStats[0] : CareerStats.ToArray(),
                Awards = Awards == null ? new string[0] : Awards.ToArray(),
                Milestones = Milestones == null ? new string[0] : Milestones.ToArray(),
                News = News == null ? new string[0] : News.ToArray(),
                HallOfFameScore = HallOfFameScore,
                Commitment = Commitment,
                BalanceVersion = BalanceVersion,
                SeasonSegment = SeasonSegment,
                SeasonTrigger = SeasonTrigger,
                CurrentRival = CurrentRival,
                SeasonTensions = SeasonTensions == null ? null : SeasonTensions.ToArray(),
                SeasonImportantGames = SeasonImportantGames,
                PendingDecision = PendingDecision,
                DecisionHistory = DecisionHistory == null ? null : DecisionHistory.ToArray(),
                DevelopmentProgress = DevelopmentProgress
            };
        }
    }
}
