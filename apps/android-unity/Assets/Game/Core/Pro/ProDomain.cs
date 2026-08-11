using System;
using System.Collections.Generic;
using System.Linq;
using Baseball.Core.Domain;
using Baseball.Core.HighSchool;

namespace Baseball.Core.Pro
{
    public enum EntitlementStatus { Locked, Active }
    public enum EntitlementSource { Purchase, Restore, OfflineCache, Development }
    public enum ProCareerPhase { ContractOffer, WeeklyPlan, SeasonDecision, ImportantGame, SeasonReview, OffseasonDecision, RetirementDecision, Completed }
    public enum ProLevel { Minor, Major }
    public enum ProRole { Starter, LongRelief, Setup, Closer }
    // Keep the first five numeric values stable for legacy Newtonsoft snapshots. DevelopWeapon is
    // compatibility-only; new choice surfaces expose DevelopStuff and DevelopMovement separately.
    public enum ProWeekPlan { DevelopWeapon, RefineCommand, BuildStamina, Recover, EarnTrust, DevelopStuff, DevelopMovement }
    public enum OffseasonDecision { ContinueCareer, MilitaryService, FreeAgency, Retire }
    public enum ProSeasonDecisionType { ExtraBullpen, CatcherGamePlan, RoleMeeting, RecordChase, RivalAnalysis, SeasonFinale }
    public enum ProSeasonSegment { SpringCamp, Opening, FirstHalf, AllStarBreak, PennantRace, SeasonFinale }
    public enum ProSeasonTrigger { OpeningStatement, CallUpAudition, MajorDebut, RecordChase, RoleShowdown, StandingsRace }

    public static class ProWire
    {
        public static string Value(this ProCareerPhase value)
        {
            switch (value)
            {
                case ProCareerPhase.ContractOffer: return "contract_offer";
                case ProCareerPhase.WeeklyPlan: return "weekly_plan";
                case ProCareerPhase.SeasonDecision: return "season_decision";
                case ProCareerPhase.ImportantGame: return "important_game";
                case ProCareerPhase.SeasonReview: return "season_review";
                case ProCareerPhase.OffseasonDecision: return "offseason_decision";
                case ProCareerPhase.RetirementDecision: return "retirement_decision";
                default: return "completed";
            }
        }

        public static string Value(this ProLevel value) { return value == ProLevel.Major ? "major" : "minor"; }
        public static string Value(this ProRole value)
        {
            switch (value)
            {
                case ProRole.Starter: return "starter";
                case ProRole.LongRelief: return "long_relief";
                case ProRole.Setup: return "setup";
                default: return "closer";
            }
        }
        public static string Value(this ProWeekPlan value)
        {
            switch (value)
            {
                case ProWeekPlan.DevelopWeapon: return "develop_weapon";
                case ProWeekPlan.DevelopStuff: return "develop_stuff";
                case ProWeekPlan.DevelopMovement: return "develop_movement";
                case ProWeekPlan.RefineCommand: return "refine_command";
                case ProWeekPlan.BuildStamina: return "build_stamina";
                case ProWeekPlan.Recover: return "recover";
                default: return "earn_trust";
            }
        }
        public static string Value(this ProSeasonDecisionType value)
        {
            switch (value)
            {
                case ProSeasonDecisionType.ExtraBullpen: return "extra_bullpen";
                case ProSeasonDecisionType.CatcherGamePlan: return "catcher_game_plan";
                case ProSeasonDecisionType.RoleMeeting: return "role_meeting";
                case ProSeasonDecisionType.RecordChase: return "record_chase";
                case ProSeasonDecisionType.RivalAnalysis: return "rival_analysis";
                default: return "season_finale";
            }
        }
        public static string Value(this ProSeasonSegment value)
        {
            switch (value)
            {
                case ProSeasonSegment.SpringCamp: return "spring_camp";
                case ProSeasonSegment.Opening: return "opening";
                case ProSeasonSegment.FirstHalf: return "first_half";
                case ProSeasonSegment.AllStarBreak: return "all_star_break";
                case ProSeasonSegment.PennantRace: return "pennant_race";
                default: return "season_finale";
            }
        }
        public static string Value(this ProSeasonTrigger value)
        {
            switch (value)
            {
                case ProSeasonTrigger.OpeningStatement: return "opening_statement";
                case ProSeasonTrigger.CallUpAudition: return "call_up_audition";
                case ProSeasonTrigger.MajorDebut: return "major_debut";
                case ProSeasonTrigger.RecordChase: return "record_chase";
                case ProSeasonTrigger.RoleShowdown: return "role_showdown";
                default: return "standings_race";
            }
        }
    }

    public sealed class ProWeekRecommendation
    {
        public ProWeekRecommendation(ProWeekPlan plan, string reason) { Plan = plan; Reason = reason; }
        public ProWeekPlan Plan { get; }
        public string Reason { get; }
    }

    /// <summary>Pure projection of the iOS weekly recommendation precedence.</summary>
    public static class ProWeekRecommendationRules
    {
        public static ProWeekRecommendation Resolve(
            int fatigue,
            ProLevel level,
            int managerTrust,
            PitcherSnapshot pitcher)
        {
            if (fatigue >= 68) return new ProWeekRecommendation(ProWeekPlan.Recover, "부상 예방");
            if (level == ProLevel.Minor && managerTrust < 60)
                return new ProWeekRecommendation(ProWeekPlan.EarnTrust, "콜업 우선");
            switch (PitcherBuildRules.Identity(pitcher))
            {
                case PitcherBuildIdentity.Command:
                    return new ProWeekRecommendation(ProWeekPlan.RefineCommand, "제구형 강화");
                case PitcherBuildIdentity.Movement:
                    return new ProWeekRecommendation(ProWeekPlan.DevelopMovement, "변화구형 강화");
                case PitcherBuildIdentity.Stamina:
                    return new ProWeekRecommendation(ProWeekPlan.BuildStamina, "이닝형 강화");
                default:
                    return new ProWeekRecommendation(ProWeekPlan.DevelopStuff, "강속구형 강화");
            }
        }
    }

    public sealed class ProDevelopmentProgress
    {
        public ProDevelopmentProgress(int stuff = 0, int command = 0, int movement = 0, int stamina = 0)
        {
            Stuff = Clamp(stuff);
            Command = Clamp(command);
            Movement = Clamp(movement);
            Stamina = Clamp(stamina);
        }

        public int Stuff { get; }
        public int Command { get; }
        public int Movement { get; }
        public int Stamina { get; }

        public int Value(ProWeekPlan plan)
        {
            switch (plan)
            {
                case ProWeekPlan.DevelopStuff: return Stuff;
                case ProWeekPlan.RefineCommand: return Command;
                case ProWeekPlan.DevelopMovement: return Movement;
                case ProWeekPlan.BuildStamina: return Stamina;
                case ProWeekPlan.DevelopWeapon: return Math.Min(Stuff, Movement);
                default: return 0;
            }
        }

        private static int Clamp(int value) { return Math.Min(1, Math.Max(0, value)); }
    }

    public enum ProSegmentStopReason
    {
        SegmentChanged,
        PhaseChanged,
        RoleChanged,
        LevelChanged,
        Injury,
        MaximumWeeks
    }

    public sealed class ProSegmentProgressSnapshot
    {
        public ProSegmentProgressSnapshot(
            int advancedWeeks,
            ProSeasonSegment startingSegment,
            ProSeasonSegment endingSegment,
            ProSegmentStopReason stopReason,
            ProWeekPlan plan,
            PitchType? targetPitch)
        {
            AdvancedWeeks = advancedWeeks;
            StartingSegment = startingSegment;
            EndingSegment = endingSegment;
            StopReason = stopReason;
            Plan = plan;
            TargetPitch = targetPitch;
        }

        public int AdvancedWeeks { get; }
        public ProSeasonSegment StartingSegment { get; }
        public ProSeasonSegment EndingSegment { get; }
        public ProSegmentStopReason StopReason { get; }
        public ProWeekPlan Plan { get; }
        public PitchType? TargetPitch { get; }
    }

    public sealed class ProEntitlementSnapshot
    {
        public ProEntitlementSnapshot(
            EntitlementStatus status,
            EntitlementSource source,
            string verifiedAt,
            string offlineValidUntil = null,
            string productId = "baseball_pro_career")
        {
            ProductId = productId;
            Status = status;
            Source = source;
            VerifiedAt = verifiedAt;
            OfflineValidUntil = offlineValidUntil;
        }
        public string ProductId { get; }
        public EntitlementStatus Status { get; }
        public EntitlementSource Source { get; }
        public string VerifiedAt { get; }
        public string OfflineValidUntil { get; }
    }

    public sealed class ProDecisionEffect
    {
        public ProDecisionEffect(
            int stuffDelta = 0,
            int commandDelta = 0,
            int movementDelta = 0,
            int staminaDelta = 0,
            int managerTrustDelta = 0,
            int catcherTrustDelta = 0,
            int fatigueDelta = 0,
            ProRole? roleTarget = null)
        {
            StuffDelta = stuffDelta;
            CommandDelta = commandDelta;
            MovementDelta = movementDelta;
            StaminaDelta = staminaDelta;
            ManagerTrustDelta = managerTrustDelta;
            CatcherTrustDelta = catcherTrustDelta;
            FatigueDelta = fatigueDelta;
            RoleTarget = roleTarget;
        }
        public int StuffDelta { get; }
        public int CommandDelta { get; }
        public int MovementDelta { get; }
        public int StaminaDelta { get; }
        public int ManagerTrustDelta { get; }
        public int CatcherTrustDelta { get; }
        public int FatigueDelta { get; }
        public ProRole? RoleTarget { get; }
        public string Summary
        {
            get
            {
                var values = new List<string>();
                Append(StuffDelta, "구위", values);
                Append(CommandDelta, "제구", values);
                Append(MovementDelta, "변화구", values);
                Append(StaminaDelta, "체력", values);
                Append(ManagerTrustDelta, "감독의 믿음", values);
                Append(CatcherTrustDelta, "포수와의 호흡", values);
                Append(FatigueDelta, "피로", values);
                if (RoleTarget.HasValue) values.Add("역할 → " + RoleLabel(RoleTarget.Value));
                return string.Join(" · ", values);
            }
        }
        private static void Append(int value, string label, ICollection<string> values)
        {
            if (value != 0) values.Add(label + " " + (value > 0 ? "+" : string.Empty) + value);
        }
        internal static string RoleLabel(ProRole role)
        {
            return role == ProRole.Starter ? "선발" : role == ProRole.LongRelief ? "긴 이닝 구원" : role == ProRole.Setup ? "필승조" : "마무리";
        }
    }

    public sealed class ProSeasonDecisionChoice
    {
        public ProSeasonDecisionChoice(string id, string title, string detail, ProDecisionEffect effect)
        { Id = id; Title = title; Detail = detail; Effect = effect; }
        public string Id { get; }
        public string Title { get; }
        public string Detail { get; }
        public ProDecisionEffect Effect { get; }
    }

    public sealed class ProSeasonDecision
    {
        public ProSeasonDecision(string id, ProSeasonDecisionType type, int season, int week, string title, string detail, IReadOnlyList<ProSeasonDecisionChoice> choices)
        { Id = id; Type = type; Season = season; Week = week; Title = title; Detail = detail; Choices = choices.ToArray(); }
        public string Id { get; }
        public ProSeasonDecisionType Type { get; }
        public int Season { get; }
        public int Week { get; }
        public string Title { get; }
        public string Detail { get; }
        public IReadOnlyList<ProSeasonDecisionChoice> Choices { get; }
    }

    public sealed class ProDecisionRecord
    {
        public ProDecisionRecord(string decisionId, ProSeasonDecisionType type, int season, int week, string choiceId, string choiceTitle, ProDecisionEffect effect)
        { DecisionId = decisionId; Type = type; Season = season; Week = week; ChoiceId = choiceId; ChoiceTitle = choiceTitle; Effect = effect; }
        public string Id { get { return DecisionId; } }
        public string DecisionId { get; }
        public ProSeasonDecisionType Type { get; }
        public int Season { get; }
        public int Week { get; }
        public string ChoiceId { get; }
        public string ChoiceTitle { get; }
        public ProDecisionEffect Effect { get; }
    }

    public sealed class ProRivalBatter
    {
        public ProRivalBatter(string id, string name, string archetype, string teamId, string teamName, string record, string profile)
        { Id = id; Name = name; Archetype = archetype; TeamId = teamId; TeamName = teamName; Record = record; Profile = profile; }
        public string Id { get; }
        public string Name { get; }
        public string Archetype { get; }
        public string TeamId { get; }
        public string TeamName { get; }
        public string Record { get; }
        public string Profile { get; }
    }

    public sealed class ProSeasonTension
    {
        public ProSeasonTension(string kind, string title, string detail) { Kind = kind; Title = title; Detail = detail; }
        public string Kind { get; }
        public string Title { get; }
        public string Detail { get; }
    }

    public sealed class ProSeasonStats
    {
        public ProSeasonStats(
            int season,
            string teamId,
            int games = 0,
            int starts = 0,
            int inningsOuts = 0,
            int strikeouts = 0,
            int walks = 0,
            int runsAllowed = 0,
            int wins = 0,
            int losses = 0,
            int saves = 0,
            int? hits = null,
            int? homeRuns = null,
            int? pitches = null,
            int? qualityStarts = null)
        {
            Season = season; TeamId = teamId; Games = games; Starts = starts; InningsOuts = inningsOuts;
            Strikeouts = strikeouts; Walks = walks; RunsAllowed = runsAllowed; Wins = wins; Losses = losses; Saves = saves;
            Hits = hits; HomeRuns = homeRuns; Pitches = pitches; QualityStarts = qualityStarts;
        }
        public int Season { get; }
        public string TeamId { get; }
        public int Games { get; }
        public int Starts { get; }
        public int InningsOuts { get; }
        public int Strikeouts { get; }
        public int Walks { get; }
        public int RunsAllowed { get; }
        public int Wins { get; }
        public int Losses { get; }
        public int Saves { get; }
        /// <summary>Null means an older or direct-play result did not record this total.</summary>
        public int? Hits { get; }
        /// <summary>Null means an older or direct-play result did not record this total.</summary>
        public int? HomeRuns { get; }
        /// <summary>Null means an older save did not preserve the season pitch total.</summary>
        public int? Pitches { get; }
        /// <summary>Null means an older save did not preserve quality-start evidence.</summary>
        public int? QualityStarts { get; }
    }

    public sealed class ProContractSnapshot
    {
        public ProContractSnapshot(int yearsRemaining, int annualSalary, ProRole rolePromise)
        { YearsRemaining = yearsRemaining; AnnualSalary = annualSalary; RolePromise = rolePromise; }
        public int YearsRemaining { get; }
        public int AnnualSalary { get; }
        public ProRole RolePromise { get; }
    }

    /// <summary>Compatibility boundary: pro and high-school logs share the original public ProGameLine.</summary>
    public static class ProGameLineAdapter
    {
        public static ProGameLine Create(
            int season, int week, int outingNumber, bool started, int outs, int strikeouts, int walks,
            int runsAllowed, int pitches, int teamRuns, int opponentRuns, PitchingDecision decision,
            bool played, int? hits = null, int? homeRuns = null)
        {
            return new ProGameLine(season, week, outingNumber, started, outs, strikeouts, walks, runsAllowed,
                pitches, teamRuns, opponentRuns, decision, played, hits, homeRuns);
        }
    }

    public sealed class StartProCareerParams
    {
        public StartProCareerParams(string seed, PlayerIdentitySnapshot identity, PitcherSnapshot pitcher, DraftResultSnapshot draftResult, ProEntitlementSnapshot entitlement)
        { Seed = seed; Identity = identity; Pitcher = pitcher; DraftResult = draftResult; Entitlement = entitlement; }
        public string Seed { get; }
        public PlayerIdentitySnapshot Identity { get; }
        public PitcherSnapshot Pitcher { get; }
        public DraftResultSnapshot DraftResult { get; }
        public ProEntitlementSnapshot Entitlement { get; }
    }
    public sealed class StartDirectProParams
    {
        public StartDirectProParams(string seed, string presetId, string playerName, string teamId)
        { Seed = seed; PresetId = presetId; PlayerName = playerName; TeamId = teamId; }
        public string Seed { get; }
        public string PresetId { get; }
        public string PlayerName { get; }
        public string TeamId { get; }
    }
    public sealed class ProStateParams
    {
        public ProStateParams(string seed, ProCareerSnapshot state) { Seed = seed; State = state; }
        public string Seed { get; } public ProCareerSnapshot State { get; }
    }
    public sealed class PlanProWeekParams
    {
        public PlanProWeekParams(string seed, ProCareerSnapshot state, ProWeekPlan plan, PitchType? targetPitch = null) { Seed = seed; State = state; Plan = plan; TargetPitch = targetPitch; }
        public string Seed { get; } public ProCareerSnapshot State { get; } public ProWeekPlan Plan { get; } public PitchType? TargetPitch { get; }
    }
    public sealed class AdvanceProSegmentParams
    {
        public AdvanceProSegmentParams(string seed, ProCareerSnapshot state, ProWeekPlan plan, PitchType? targetPitch = null, int maximumWeeks = 24)
        { Seed = seed; State = state; Plan = plan; TargetPitch = targetPitch; MaximumWeeks = maximumWeeks; }
        public string Seed { get; } public ProCareerSnapshot State { get; } public ProWeekPlan Plan { get; } public PitchType? TargetPitch { get; } public int MaximumWeeks { get; }
    }
    public sealed class ResolveProGameParams
    {
        public ResolveProGameParams(string seed, ProCareerSnapshot state, ImportantInningReport report) { Seed = seed; State = state; Report = report; }
        public string Seed { get; } public ProCareerSnapshot State { get; } public ImportantInningReport Report { get; }
    }
    public sealed class ApplyProSeasonDecisionParams
    {
        public ApplyProSeasonDecisionParams(string seed, ProCareerSnapshot state, string decisionId, string choiceId)
        { Seed = seed; State = state; DecisionId = decisionId; ChoiceId = choiceId; }
        public string Seed { get; } public ProCareerSnapshot State { get; } public string DecisionId { get; } public string ChoiceId { get; }
    }
    public sealed class ProOffseasonParams
    {
        public ProOffseasonParams(string seed, ProCareerSnapshot state, OffseasonDecision decision) { Seed = seed; State = state; Decision = decision; }
        public string Seed { get; } public ProCareerSnapshot State { get; } public OffseasonDecision Decision { get; }
    }

    public sealed class ProCareerResult
    {
        public ProCareerResult(ProCareerSnapshot snapshot, string nextSeed, IReadOnlyList<string> events)
        { Snapshot = snapshot; NextSeed = nextSeed; Events = events.ToArray(); }
        public ProCareerSnapshot Snapshot { get; }
        public string NextSeed { get; }
        public IReadOnlyList<string> Events { get; }
    }

    public sealed class ProSegmentAdvanceResult
    {
        public ProSegmentAdvanceResult(ProCareerResult career, ProSegmentProgressSnapshot progress)
        { Career = career; Progress = progress; }
        public ProCareerResult Career { get; }
        public ProSegmentProgressSnapshot Progress { get; }
    }
}
