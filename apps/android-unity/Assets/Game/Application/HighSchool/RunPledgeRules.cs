using System;
using System.Collections.Generic;
using System.Linq;
using Baseball.Application.Meta;
using Baseball.Application.Persistence;
using Baseball.Core.HighSchool;
using CorePledge = Baseball.Core.HighSchool.RunPledge;
using CorePledgeContext = Baseball.Core.HighSchool.RunPledgeContext;
using CorePledgeTier = Baseball.Core.HighSchool.RunPledgeTier;

namespace Baseball.Application.HighSchool
{
    /// <summary>Application-facing wire enum. Rules and ordering remain Core-owned.</summary>
    public enum RunPledgeTier
    {
        Safe,
        Bold,
        Legendary
    }

    public sealed class RunPledgeProgressReadModel
    {
        public RunPledgeProgressReadModel(
            int current,
            int target,
            bool achieved,
            string line,
            int? unachievedRatioPermille,
            int ratioPermille)
        {
            Current = current;
            Target = target;
            Achieved = achieved;
            Line = line;
            UnachievedRatioPermille = unachievedRatioPermille;
            RatioPermille = ratioPermille;
        }

        public int Current { get; }
        public int Target { get; }
        public bool Achieved { get; }
        public string Line { get; }
        public int? UnachievedRatioPermille { get; }
        public int RatioPermille { get; }
    }

    public sealed class RunPledgeReadModel
    {
        public RunPledgeReadModel(
            string id,
            RunPledgeTier tier,
            string title,
            string detail,
            int rewardPermille,
            RunPledgeProgressReadModel progress,
            string alignmentReason,
            bool carried = false)
        {
            Id = id;
            Tier = tier;
            Title = title;
            Detail = detail;
            RewardPermille = rewardPermille;
            Progress = progress;
            AlignmentReason = alignmentReason;
            Carried = carried;
        }

        public string Id { get; }
        public string Payload => Id;
        public RunPledgeTier Tier { get; }
        public string TierId => Tier == RunPledgeTier.Safe
            ? "safe"
            : Tier == RunPledgeTier.Bold ? "bold" : "legendary";
        public string Title { get; }
        public string Detail { get; }
        public int RewardPermille { get; }
        public RunPledgeProgressReadModel Progress { get; }
        public string AlignmentReason { get; }
        public bool Carried { get; }
    }

    public sealed class RunPledgeCatalogReadModel
    {
        public RunPledgeCatalogReadModel(
            bool canChoose,
            bool decided,
            RunPledgeReadModel selected,
            IReadOnlyList<RunPledgeReadModel> choices,
            string carriedIntentId = null)
        {
            CanChoose = canChoose;
            Decided = decided;
            Selected = selected;
            Choices = (choices ?? Array.Empty<RunPledgeReadModel>()).ToArray();
            CarriedIntentId = carriedIntentId;
        }

        public bool CanChoose { get; }
        public bool Decided { get; }
        public RunPledgeReadModel Selected { get; }
        public IReadOnlyList<RunPledgeReadModel> Choices { get; }
        public string CarriedIntentId { get; }
    }

    /// <summary>
    /// Thin Application projection over the pure Core catalog. No eligibility, ordering, progress,
    /// reward, or copy rule is duplicated here.
    /// </summary>
    public static class RunPledgeRules
    {
        public const int LegacyRulesVersion = RunPledgeCatalog.LegacyRulesVersion;
        public const int CurrentRulesVersion = RunPledgeCatalog.CurrentRulesVersion;
        public const string RetryIntentReason = RunPledgeCatalog.RetryIntentReason;

        public static RunPledgeCatalogReadModel Project(GameSaveAggregate aggregate)
        {
            if (aggregate == null) throw new ArgumentNullException(nameof(aggregate));
            var state = aggregate.HighSchool;
            if (state == null)
                return new RunPledgeCatalogReadModel(false, true, null, Array.Empty<RunPledgeReadModel>());
            var intent = aggregate.Meta?.NextRunIntent;
            var canChoose = !state.IsChallengeRun && !state.PledgeDecided && aggregate.Pro == null &&
                (state.Phase == HighSchoolPhase.Prologue || state.Phase == HighSchoolPhase.SchoolSelection);
            var selected = string.IsNullOrWhiteSpace(state.PledgeId)
                ? null
                : Resolve(state.PledgeId, EffectiveRulesVersion(state), state);
            var choices = canChoose
                ? Options(state, intent)
                : Array.Empty<RunPledgeReadModel>();
            return new RunPledgeCatalogReadModel(
                canChoose,
                state.PledgeDecided,
                selected,
                choices,
                intent?.PledgeId);
        }

        public static bool IsValidSelection(GameSaveAggregate aggregate, string pledgeId)
        {
            var catalog = Project(aggregate);
            if (!catalog.CanChoose) return false;
            if (string.IsNullOrWhiteSpace(pledgeId)) return true;
            return catalog.Choices.Any(value =>
                string.Equals(value.Id, pledgeId, StringComparison.Ordinal));
        }

        public static RunPledgeReadModel Resolve(
            string pledgeId,
            int rulesVersion,
            HighSchoolCareerReadModel state)
        {
            var pledge = RunPledgeCatalog.Resolve(pledgeId, rulesVersion);
            return pledge == null || state == null
                ? null
                : ReadModel(pledge, Context(state), false);
        }

        public static IReadOnlyList<RunPledgeReadModel> Options(
            HighSchoolCareerReadModel state,
            NextRunIntentState intent = null)
        {
            if (state == null) return Array.Empty<RunPledgeReadModel>();
            var coreContext = Context(state);
            var coreIntent = intent == null
                ? null
                : new NextRunIntent(intent.PledgeId, intent.SourceLifeNumber, intent.Reason);
            return RunPledgeCatalog.Options(state.CareerId, coreContext, coreIntent)
                .Select(value => ReadModel(
                    value,
                    coreContext,
                    intent != null && string.Equals(
                        intent.PledgeId, value.Id, StringComparison.Ordinal)))
                .ToArray();
        }

        public static ISet<string> BuildAlignedIds(HighSchoolCareerReadModel state) =>
            new HashSet<string>(RunPledgeCatalog.BuildAlignedIds(Context(state)), StringComparer.Ordinal);

        public static int EffectiveRulesVersion(HighSchoolCareerReadModel state)
        {
            if (state?.PledgeRulesVersion > 0) return state.PledgeRulesVersion;
            return string.IsNullOrWhiteSpace(state?.PledgeId)
                ? CurrentRulesVersion
                : LegacyRulesVersion;
        }

        public static bool IsKnownCurrentId(string pledgeId) =>
            !string.IsNullOrWhiteSpace(pledgeId) && RunPledgeCatalog.All.Any(value =>
                string.Equals(value.Id, pledgeId, StringComparison.Ordinal));

        /// <summary>
        /// Recap-only suggestion. The caller must dispatch SetNextRunIntentCommand after the
        /// player explicitly chooses to carry it; computing this value never mutates Meta.
        /// </summary>
        public static NextRunIntentState SuggestedNextRunIntent(HighSchoolCareerReadModel state)
        {
            if (state == null) return null;
            var settled = string.IsNullOrWhiteSpace(state.PledgeId)
                ? null
                : Resolve(state.PledgeId, EffectiveRulesVersion(state), state);
            RunPledgeReadModel candidate;
            string reason;
            if (settled != null && settled.Progress?.Achieved != true)
            {
                candidate = settled;
                reason = RetryIntentReason;
            }
            else
            {
                candidate = Options(state).FirstOrDefault(value =>
                    !string.Equals(value.Id, settled?.Id, StringComparison.Ordinal) &&
                    value.Progress?.Achieved != true);
                reason = "아카이브에 아직 완주하지 않은 목표입니다.";
            }
            return candidate == null
                ? null
                : new NextRunIntentState(
                    candidate.Id,
                    state.LifeNumber,
                    reason,
                    candidate.Title,
                    candidate.TierId,
                    candidate.RewardPermille);
        }

        public static CorePledgeContext Context(HighSchoolCareerReadModel state)
        {
            if (state == null) throw new ArgumentNullException(nameof(state));
            var awakenings = (state.Awakenings ?? Array.Empty<string>())
                .Select(ParseAwakening)
                .Where(value => value.HasValue)
                .Select(value => value.Value)
                .ToArray();
            DraftOutcome? outcome = null;
            if (state.Draft?.Resolved == true)
                outcome = state.Draft.Drafted ? DraftOutcome.Drafted : DraftOutcome.Undrafted;
            return new CorePledgeContext(
                state.LifeNumber,
                state.Ratings.Stuff,
                state.Ratings.Command,
                state.Ratings.Movement,
                state.Performance.ImportantGames,
                state.Performance.Strikeouts,
                state.Performance.Walks,
                state.GameLines.Count(value => value.Played && value.RunsAllowed == 0),
                awakenings,
                state.Fatigue,
                state.ArmRisk,
                state.InjuryRecovery,
                state.FanInterest,
                Math.Max(state.ManagerTrust, Math.Max(state.CatcherTrust, state.RivalTrust)),
                state.ManagerTrust,
                state.CatcherTrust,
                state.RivalTrust,
                outcome,
                state.Draft?.Resolved == true ? state.Draft.EvaluationScore : (int?)null,
                state.DraftForecastScore,
                state.RivalStrikeouts);
        }

        private static RunPledgeReadModel ReadModel(
            CorePledge pledge,
            CorePledgeContext context,
            bool carried)
        {
            var progress = pledge.Progress(context);
            return new RunPledgeReadModel(
                pledge.Id,
                Map(pledge.Tier),
                pledge.Title,
                pledge.Detail,
                pledge.RewardPermille,
                new RunPledgeProgressReadModel(
                    progress.Current,
                    progress.Target,
                    progress.Achieved,
                    progress.Line,
                    progress.UnachievedRatioPermille,
                    progress.RatioPermille),
                pledge.AlignmentReason(context),
                carried);
        }

        private static RunPledgeTier Map(CorePledgeTier value)
        {
            switch (value)
            {
                case CorePledgeTier.Safe: return RunPledgeTier.Safe;
                case CorePledgeTier.Bold: return RunPledgeTier.Bold;
                case CorePledgeTier.Legendary: return RunPledgeTier.Legendary;
                default: throw new ArgumentOutOfRangeException(nameof(value));
            }
        }

        private static AwakeningId? ParseAwakening(string value)
        {
            foreach (AwakeningId candidate in Enum.GetValues(typeof(AwakeningId)))
            {
                if (string.Equals(candidate.Value(), value, StringComparison.Ordinal))
                    return candidate;
            }
            return null;
        }
    }
}
