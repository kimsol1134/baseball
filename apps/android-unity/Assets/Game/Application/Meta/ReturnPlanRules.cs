using System;
using System.Globalization;
using System.Linq;
using Baseball.Application.HighSchool;
using Baseball.Application.Persistence;
using Baseball.Application.Pro;
using Baseball.Core.HighSchool;
using Baseball.Core.Random;
using Baseball.Core.Catalogs;

namespace Baseball.Application.Meta
{
    public enum ReturnPlanDestination
    {
        DailyInning = 0,
        HighSchool = 1,
        Pro = 2
    }

    public enum ReturnExperimentVariant
    {
        Holdout = 0,
        Guided = 1
    }

    /// <summary>Low-cardinality, PII-free return instrumentation projection.</summary>
    public sealed class ReturnPlanAnalyticsReadModel
    {
        public ReturnPlanAnalyticsReadModel(
            string destination,
            string reason,
            string planReceipt,
            string experimentId,
            string variant,
            string savedDayKey,
            string returnDayKey,
            int dayGap,
            int developmentRulesVersion,
            string launchType = null)
        {
            Destination = destination;
            Reason = reason;
            PlanReceipt = planReceipt;
            ExperimentId = experimentId;
            Variant = variant;
            SavedDayKey = savedDayKey;
            ReturnDayKey = returnDayKey;
            DayGap = dayGap;
            DevelopmentRulesVersion = developmentRulesVersion;
            LaunchType = launchType;
        }

        public string Destination { get; }
        public string Reason { get; }
        public string PlanReceipt { get; }
        public string ExperimentId { get; }
        public string Variant { get; }
        public string SavedDayKey { get; }
        public string ReturnDayKey { get; }
        public int DayGap { get; }
        public int DevelopmentRulesVersion { get; }
        public string LaunchType { get; }
    }

    public sealed class SessionEndReturnReadModel
    {
        public SessionEndReturnReadModel(
            bool returnEligible,
            bool shouldEmitReturnEligible,
            string returnDestination,
            string returnReason,
            string planReceipt,
            string experimentId,
            string variant,
            int developmentRulesVersion,
            int minutes = 0,
            int lifeNumber = 1,
            int games = 0,
            int importantGamesTotal = 0,
            string phase = "none",
            int actNumber = 0,
            int livesFinished = 0,
            string savedDayKey = "none",
            string returnDayKey = "none",
            int dayGap = -1)
        {
            ReturnEligible = returnEligible;
            ShouldEmitReturnEligible = shouldEmitReturnEligible;
            ReturnDestination = returnDestination;
            ReturnReason = returnReason;
            PlanReceipt = planReceipt;
            ExperimentId = experimentId;
            Variant = variant;
            DevelopmentRulesVersion = developmentRulesVersion;
            Minutes = Math.Max(0, minutes);
            LifeNumber = Math.Max(1, lifeNumber);
            Games = Math.Max(0, games);
            ImportantGamesTotal = Math.Max(0, importantGamesTotal);
            Phase = string.IsNullOrWhiteSpace(phase) ? "none" : phase;
            ActNumber = Math.Max(0, actNumber);
            LivesFinished = Math.Max(0, livesFinished);
            SavedDayKey = string.IsNullOrWhiteSpace(savedDayKey) ? "none" : savedDayKey;
            ReturnDayKey = string.IsNullOrWhiteSpace(returnDayKey) ? "none" : returnDayKey;
            DayGap = dayGap;
        }

        public bool ReturnEligible { get; }
        /// <summary>
        /// True only when this pause durably created the one-shot eligible receipt. Consumers may
        /// emit return_plan_eligible only when this is true; session_ended remains per-pause.
        /// </summary>
        public bool ShouldEmitReturnEligible { get; }
        public string ReturnDestination { get; }
        public string ReturnReason { get; }
        public string PlanReceipt { get; }
        public string ExperimentId { get; }
        public string Variant { get; }
        public int DevelopmentRulesVersion { get; }
        public int Minutes { get; }
        public int LifeNumber { get; }
        public int Games { get; }
        public int ImportantGamesTotal { get; }
        public string Phase { get; }
        public int ActNumber { get; }
        public int LivesFinished { get; }
        public string SavedDayKey { get; }
        public string ReturnDayKey { get; }
        public int DayGap { get; }
    }

    public static class CompletedGameCountRules
    {
        public static MetaProgressState Record(MetaProgressState current, int amount)
        {
            if (current == null) throw new ArgumentNullException(nameof(current));
            if (current.CompletedGameCount < 0)
                throw new InvalidOperationException("completed_game_count.invalid");
            if (amount < 0) throw new ArgumentOutOfRangeException(nameof(amount));
            if (amount == 0) return current;
            if (current.CompletedGameCount > int.MaxValue - amount)
                throw new InvalidOperationException("completed_game_count.exhausted");
            return current.With(completedGameCount: current.CompletedGameCount + amount);
        }

        /// <summary>
        /// One-time lower bound for saves written before the monotonic counter existed. Retired
        /// Daily receipts are deliberately ignored. Archived Pro records do not contain games, so
        /// they also contribute zero rather than a synthetic estimate.
        /// </summary>
        public static int ConservativeMigrationLowerBound(GameSaveAggregate aggregate)
        {
            if (aggregate == null) return 0;
            var archive = aggregate.Meta?.LifeArchive ?? Array.Empty<LifeArchiveRecord>();
            var archivedHighSchoolGames = archive
                .Select((record, index) => new
                {
                    Key = record?.HighSchoolCareerId ?? record?.LifeId ?? "archive:" + index,
                    Games = Math.Max(0, record?.HighSchoolPerformance?.ImportantGames ?? 0)
                })
                .GroupBy(value => value.Key, StringComparer.Ordinal)
                .Sum(group => group.Max(value => value.Games));

            var activeHighSchoolGames = 0;
            var highSchool = aggregate.HighSchool;
            if (highSchool != null && !archive.Any(record => record != null &&
                    !string.IsNullOrWhiteSpace(highSchool.CareerId) &&
                    string.Equals(
                        record.HighSchoolCareerId,
                        highSchool.CareerId,
                        StringComparison.Ordinal)))
            {
                activeHighSchoolGames = Math.Max(0, highSchool.Performance?.ImportantGames ?? 0);
            }

            // Pro season totals contain auto-simulated outings, while old Application saves do
            // not carry a complete lifetime ledger of interactive Pro game receipts. Even a
            // current-season Played line would under-represent prior seasons, so v3 migration
            // deliberately contributes zero rather than publishing a non-monotonic estimate.
            var lowerBound = (long)archivedHighSchoolGames + activeHighSchoolGames;
            return lowerBound >= int.MaxValue ? int.MaxValue : (int)lowerBound;
        }
    }

    public static class ReturnPlanRules
    {
        public const string LegacyReturnExperimentId = "next_action_v1";
        public const string ReturnExperimentId = "next_action_v2";
        public const int CurrentDevelopmentRulesVersion = PitcherPresetCatalog.BalanceVersion;

        public static bool IsEligible(int completedGameCount) => completedGameCount > 0;

        public static int CompletedGameCount(GameSaveAggregate aggregate)
        {
            return Math.Max(0, aggregate?.Meta?.CompletedGameCount ?? 0);
        }

        public static ReturnExperimentVariant ExperimentVariant(string stableId)
        {
            if (string.IsNullOrWhiteSpace(stableId))
                throw new ArgumentException("return_plan.stable_id_invalid", nameof(stableId));
            return StableHash.Fnv1A64Value(ReturnExperimentId + "|" + stableId) % 2UL == 0UL
                ? ReturnExperimentVariant.Holdout
                : ReturnExperimentVariant.Guided;
        }

        public static ReturnPlanState PrepareForNextReturn(
            GameSaveAggregate aggregate,
            string stableId,
            int developmentRulesVersion,
            DateTimeOffset now)
        {
            if (aggregate == null) throw new ArgumentNullException(nameof(aggregate));
            if (!IsEligible(CompletedGameCount(aggregate))) return null;
            var plan = CurrentPlan(aggregate);
            if (plan == null) return null;
            return PrepareForNextReturn(plan, stableId, developmentRulesVersion, now);
        }

        public static ReturnPlanState PrepareForNextReturn(
            ReturnPlanState plan,
            string stableId,
            int developmentRulesVersion,
            DateTimeOffset now)
        {
            if (!IsValidPromise(plan))
                throw new ArgumentException("return_plan.invalid", nameof(plan));
            if (IsRetiredDailyPlan(plan))
                throw new ArgumentException("daily.retired", nameof(plan));
            if (developmentRulesVersion <= 0)
                throw new ArgumentOutOfRangeException(nameof(developmentRulesVersion));
            var dayKey = SeoulGameCalendar.DayKey(now);
            var scope = ReturnExperimentId + "|" + stableId + "|" + dayKey + "|" +
                Wire(plan.Destination) + "|" + plan.Reason + "|v" + developmentRulesVersion;
            return ReturnPlanState.Create(
                plan.Title,
                plan.Body,
                plan.Destination,
                plan.Reason,
                ReturnExperimentId,
                StableHash.Fnv1A64Value(scope).ToString("x", CultureInfo.InvariantCulture),
                dayKey,
                VariantWire(ExperimentVariant(stableId)),
                developmentRulesVersion);
        }

        public static ReturnPlanState CarryingReceipt(
            ReturnPlanState current,
            ReturnPlanState previous)
        {
            if (current == null || previous == null || !SamePromise(current, previous))
                return current;
            return ReturnPlanState.Create(
                current.Title,
                current.Body,
                current.Destination,
                current.Reason,
                current.ExperimentId ?? previous.ExperimentId,
                current.ReceiptId ?? previous.ReceiptId,
                current.SavedDayKey ?? previous.SavedDayKey,
                current.ExperimentVariant ?? previous.ExperimentVariant,
                current.DevelopmentRulesVersion ?? previous.DevelopmentRulesVersion,
                current.Dismissed);
        }

        public static ReturnPlanState CarryingExperiment(
            ReturnPlanState current,
            ReturnPlanState previous)
        {
            if (current == null || previous == null) return current;
            return ReturnPlanState.Create(
                current.Title,
                current.Body,
                current.Destination,
                current.Reason,
                current.ExperimentId ?? previous.ExperimentId,
                current.ReceiptId ?? previous.ReceiptId,
                current.SavedDayKey ?? previous.SavedDayKey,
                current.ExperimentVariant ?? previous.ExperimentVariant,
                current.DevelopmentRulesVersion ?? previous.DevelopmentRulesVersion,
                current.Dismissed);
        }

        public static ReturnPlanState WelcomePlan(
            ReturnPlanState previous,
            ReturnPlanState current,
            ReturnWelcomeHandledState handled,
            DateTimeOffset now)
        {
            if (previous == null || current == null || current.Dismissed ||
                IsRetiredDailyPlan(previous) || IsRetiredDailyPlan(current)) return null;
            var candidate = CarryingExperiment(current, previous);
            if (!string.Equals(candidate.ExperimentVariant, "guided", StringComparison.Ordinal))
                return null;
            if (handled != null && WelcomeMatches(handled, candidate) &&
                string.Equals(handled.DayKey, SeoulGameCalendar.DayKey(now), StringComparison.Ordinal))
            {
                return null;
            }
            return candidate;
        }

        public static ReturnWelcomeHandledState MarkWelcomeHandled(
            ReturnPlanState plan,
            DateTimeOffset now)
        {
            if (!IsValidPromise(plan))
                throw new ArgumentException("return_plan.invalid", nameof(plan));
            return new ReturnWelcomeHandledState(
                plan.Title,
                plan.Body,
                plan.Destination,
                plan.Reason,
                SeoulGameCalendar.DayKey(now));
        }

        public static ReturnPlanAnalyticsReadModel Analytics(
            ReturnPlanState plan,
            DateTimeOffset now,
            string launchType = null)
        {
            if (plan == null || IsRetiredDailyPlan(plan)) return null;
            var gap = DayGap(plan.SavedDayKey, SeoulGameCalendar.DayKey(now));
            return new ReturnPlanAnalyticsReadModel(
                Wire(plan.Destination),
                plan.Reason,
                plan.ReceiptId ?? "legacy",
                plan.ExperimentId ?? LegacyReturnExperimentId,
                plan.ExperimentVariant ?? "legacy",
                plan.SavedDayKey ?? "legacy",
                SeoulGameCalendar.DayKey(now),
                gap ?? -1,
                plan.DevelopmentRulesVersion ?? 0,
                launchType);
        }

        public static ReturnPlanAnalyticsReadModel NextDayOpen(
            ReturnPlanState plan,
            string launchType,
            DateTimeOffset now)
        {
            if (!string.Equals(launchType, "cold", StringComparison.Ordinal) &&
                !string.Equals(launchType, "warm", StringComparison.Ordinal))
            {
                return null;
            }
            if (plan == null || string.IsNullOrWhiteSpace(plan.ReceiptId) ||
                IsRetiredDailyPlan(plan) ||
                !(string.Equals(plan.ExperimentVariant, "holdout", StringComparison.Ordinal) ||
                  string.Equals(plan.ExperimentVariant, "guided", StringComparison.Ordinal)))
            {
                return null;
            }
            var gap = DayGap(plan.SavedDayKey, SeoulGameCalendar.DayKey(now));
            return !gap.HasValue || gap.Value < 1 ? null : Analytics(plan, now, launchType);
        }

        public static string NextDayOpenReceiptScope(ReturnPlanAnalyticsReadModel value)
        {
            if (value == null || string.IsNullOrWhiteSpace(value.PlanReceipt) ||
                string.IsNullOrWhiteSpace(value.ReturnDayKey))
            {
                return null;
            }
            return AnalyticsReceiptRules.Scope(
                "return_plan_next_day_open",
                value.ExperimentId,
                value.PlanReceipt,
                value.ReturnDayKey);
        }

        public static string EligibleReceiptScope(ReturnPlanState plan)
        {
            return plan == null || IsRetiredDailyPlan(plan) ||
                string.IsNullOrWhiteSpace(plan.ReceiptId)
                ? null
                : AnalyticsReceiptRules.Scope(
                    "return_plan_eligible",
                    plan.ExperimentId ?? LegacyReturnExperimentId,
                    plan.ReceiptId);
        }

        public static SessionEndReturnReadModel SessionEnd(
            GameSaveAggregate aggregate,
            ReturnPlanState plan,
            DateTimeOffset sessionStartedAt,
            int sessionStartedGameCount,
            DateTimeOffset endedAt,
            bool shouldEmitReturnEligible = false)
        {
            if (aggregate == null) throw new ArgumentNullException(nameof(aggregate));
            var completedGameCount = CompletedGameCount(aggregate);
            var highSchool = aggregate.HighSchool;
            var phase = highSchool == null ? "none" : PhaseWire(highSchool.Phase);
            var actNumber = highSchool == null
                ? 0
                : Math.Min(4, Math.Max(1, (highSchool.ChapterNumber + 1) / 2));
            var minutes = endedAt <= sessionStartedAt
                ? 0
                : (int)Math.Floor((endedAt - sessionStartedAt).TotalMinutes);
            var lifeNumber = highSchool?.LifeNumber ?? aggregate.Meta?.LifeNumber ?? 1;
            var importantGames = highSchool?.Performance?.ImportantGames ?? 0;
            var livesFinished = aggregate.Meta?.LifeArchive?.Count ?? 0;
            var returnDayKey = SeoulGameCalendar.DayKey(endedAt);
            if (!IsEligible(completedGameCount) || plan == null ||
                IsRetiredDailyPlan(plan))
            {
                return new SessionEndReturnReadModel(
                    false, false, "none", "ineligible", "none", "none", "ineligible", 0,
                    minutes, lifeNumber,
                    Math.Max(0, completedGameCount - sessionStartedGameCount),
                    importantGames, phase, actNumber, livesFinished,
                    "none", returnDayKey, -1);
            }
            return new SessionEndReturnReadModel(
                true,
                shouldEmitReturnEligible,
                Wire(plan.Destination),
                plan.Reason,
                plan.ReceiptId ?? "legacy",
                plan.ExperimentId ?? LegacyReturnExperimentId,
                plan.ExperimentVariant ?? "legacy",
                plan.DevelopmentRulesVersion ?? 0,
                minutes, lifeNumber,
                Math.Max(0, completedGameCount - sessionStartedGameCount),
                importantGames, phase, actNumber, livesFinished,
                plan.SavedDayKey ?? "legacy",
                returnDayKey,
                DayGap(plan.SavedDayKey, returnDayKey) ?? -1);
        }

        public static string PhaseWire(HighSchoolPhase phase)
        {
            switch (phase)
            {
                case HighSchoolPhase.Prologue: return "prologue";
                case HighSchoolPhase.SchoolSelection: return "school_selection";
                case HighSchoolPhase.Training: return "training";
                case HighSchoolPhase.Relationship: return "relationship";
                case HighSchoolPhase.ImportantGame: return "important_game";
                case HighSchoolPhase.Awakening: return "awakening";
                case HighSchoolPhase.ChapterReview: return "chapter_review";
                case HighSchoolPhase.Draft: return "draft";
                case HighSchoolPhase.Legacy: return "legacy";
                case HighSchoolPhase.Completed: return "completed";
                default: throw new ArgumentOutOfRangeException(nameof(phase));
            }
        }

        public static ReturnPlanState CurrentPlan(GameSaveAggregate aggregate)
        {
            if (aggregate == null) return null;
            var pro = aggregate.Pro;
            if (pro != null && pro.Phase != ProCareerPhase.Completed)
            {
                string detail;
                switch (pro.Phase)
                {
                    case ProCareerPhase.SeasonDecision:
                        detail = "이번 시즌의 중요한 선택을 직접 결정할 차례입니다.";
                        break;
                    case ProCareerPhase.ImportantGame:
                        detail = "중요한 경기의 다음 타자를 이어서 상대하세요.";
                        break;
                    case ProCareerPhase.RetirementDecision:
                        detail = "이 선수의 마지막 결정을 직접 내려 주세요.";
                        break;
                    default:
                        detail = "프로 시즌의 다음 주를 이어서 보내세요.";
                        break;
                }
                return ReturnPlanState.Create(
                    "프로 시즌의 다음 선택", detail, ReturnPlanDestination.Pro, "pro_phase");
            }

            var highSchool = aggregate.HighSchool;
            if (highSchool?.IsChallengeRun == true) return null;
            if (highSchool != null)
            {
                var pledge = RunPledgeRules.Project(aggregate).Selected;
                if (highSchool.Draft == null && pledge != null)
                {
                    return ReturnPlanState.Create(
                        "이번 선수의 목표가 남아 있습니다",
                        pledge.Title + " · " + pledge.Progress.Line + " — 이어서 완성해 보세요.",
                        ReturnPlanDestination.HighSchool,
                        "run_pledge");
                }
                if ((highSchool.Phase == HighSchoolPhase.Legacy ||
                     highSchool.Phase == HighSchoolPhase.Completed) &&
                    aggregate.Meta.NextRunIntent != null)
                {
                    return NextIntentPlan(aggregate.Meta.NextRunIntent);
                }
                return ReturnPlanState.Create(
                    "이번 선수의 3년을 이어가세요",
                    HighSchoolDetail(highSchool.Phase),
                    ReturnPlanDestination.HighSchool,
                    "high_school_phase");
            }
            return aggregate.Meta?.NextRunIntent == null
                ? null
                : NextIntentPlan(aggregate.Meta.NextRunIntent);
        }

        public static bool IsValid(ReturnPlanState plan)
        {
            if (!IsValidPromise(plan) || !Enum.IsDefined(typeof(ReturnPlanDestination), plan.Destination) ||
                !Token(plan.Reason, 48) || plan.SavedDayKey != null && !DayKey(plan.SavedDayKey) ||
                plan.ExperimentId != null && !Token(plan.ExperimentId, 48) ||
                plan.ReceiptId != null && !Hex(plan.ReceiptId, 32) ||
                plan.ExperimentVariant != null &&
                    !string.Equals(plan.ExperimentVariant, "holdout", StringComparison.Ordinal) &&
                    !string.Equals(plan.ExperimentVariant, "guided", StringComparison.Ordinal) ||
                plan.DevelopmentRulesVersion.HasValue && plan.DevelopmentRulesVersion.Value <= 0)
            {
                return false;
            }
            return true;
        }

        public static bool IsValid(ReturnWelcomeHandledState handled)
        {
            return handled != null && !string.IsNullOrWhiteSpace(handled.Title) &&
                !string.IsNullOrWhiteSpace(handled.Body) &&
                Enum.IsDefined(typeof(ReturnPlanDestination), handled.Destination) &&
                Token(handled.Reason, 48) && DayKey(handled.DayKey);
        }

        public static ReturnPlanDestination DestinationForLegacyRoute(string route)
        {
            if (!string.IsNullOrWhiteSpace(route) &&
                route.IndexOf("pro", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return ReturnPlanDestination.Pro;
            }
            if (!string.IsNullOrWhiteSpace(route) &&
                (route.IndexOf("high", StringComparison.OrdinalIgnoreCase) >= 0 ||
                 route.IndexOf("setup", StringComparison.OrdinalIgnoreCase) >= 0 ||
                 route.IndexOf("legacy", StringComparison.OrdinalIgnoreCase) >= 0))
            {
                return ReturnPlanDestination.HighSchool;
            }
            return ReturnPlanDestination.HighSchool;
        }

        /// <summary>
        /// Recognizes both the typed prototype destination and older raw route spellings without
        /// rejecting their persisted payloads. Product navigation and analytics must fall back to
        /// the current career instead of reviving the retired mode.
        /// </summary>
        public static bool IsRetiredDailyPlan(ReturnPlanState plan)
        {
            return plan != null &&
                (plan.Destination == ReturnPlanDestination.DailyInning ||
                 string.Equals(plan.Route, "daily-inning", StringComparison.OrdinalIgnoreCase) ||
                 string.Equals(plan.Route, "daily_inning", StringComparison.OrdinalIgnoreCase));
        }

        public static string Route(ReturnPlanDestination destination)
        {
            switch (destination)
            {
                case ReturnPlanDestination.DailyInning: return "daily-inning";
                case ReturnPlanDestination.HighSchool: return "high-school";
                case ReturnPlanDestination.Pro: return "pro";
                default: throw new ArgumentOutOfRangeException(nameof(destination));
            }
        }

        public static string Wire(ReturnPlanDestination destination)
        {
            switch (destination)
            {
                case ReturnPlanDestination.DailyInning: return "daily_inning";
                case ReturnPlanDestination.HighSchool: return "high_school";
                case ReturnPlanDestination.Pro: return "pro";
                default: throw new ArgumentOutOfRangeException(nameof(destination));
            }
        }

        public static string ContinueTitle(ReturnPlanDestination destination)
        {
            switch (destination)
            {
                case ReturnPlanDestination.DailyInning: return "게임으로 돌아가기";
                case ReturnPlanDestination.HighSchool: return "이 선수 이어서 키우기";
                case ReturnPlanDestination.Pro: return "프로 시즌 이어가기";
                default: throw new ArgumentOutOfRangeException(nameof(destination));
            }
        }

        private static ReturnPlanState NextIntentPlan(NextRunIntentState intent)
        {
            var title = RunPledgeCatalog.Resolve(intent.PledgeId)?.Title ?? "지난 고교 3년의 목표";
            return ReturnPlanState.Create(
                "다음 선수의 목표가 기다립니다",
                title + " — 지난 3년의 아쉬움을 새 선수로 이어 보세요.",
                ReturnPlanDestination.HighSchool,
                "next_run_intent");
        }

        private static string HighSchoolDetail(HighSchoolPhase phase)
        {
            switch (phase)
            {
                case HighSchoolPhase.Prologue:
                    return "감독이 기다립니다. 불펜에서 첫 공을 던질 차례입니다.";
                case HighSchoolPhase.SchoolSelection:
                    return "새 선수의 학교와 성장 방향을 정할 차례입니다.";
                case HighSchoolPhase.Training:
                    return "다음 훈련으로 직접 키운 능력을 한 단계 더 올려 보세요.";
                case HighSchoolPhase.Relationship:
                    return "다음 선택이 선수의 관계와 성장 방향을 바꿉니다.";
                case HighSchoolPhase.ImportantGame:
                    return "고교 공식 경기의 다음 타자를 이어서 상대하세요.";
                case HighSchoolPhase.Awakening:
                    return "새 능력을 직접 고를 중요한 순간이 기다립니다.";
                case HighSchoolPhase.ChapterReview:
                    return "이번 학기의 성장 결과와 다음 목표를 확인하세요.";
                case HighSchoolPhase.Draft:
                    return "직접 키운 선수의 드래프트 결과를 확인할 차례입니다.";
                case HighSchoolPhase.Legacy:
                    return "지난 선수가 남긴 대표 능력을 다음 선수에게 이어 주세요.";
                case HighSchoolPhase.Completed:
                    return "지난 선수의 유산을 안고 새 선수를 시작해 보세요.";
                default:
                    throw new ArgumentOutOfRangeException(nameof(phase));
            }
        }

        private static bool SamePromise(ReturnPlanState left, ReturnPlanState right)
        {
            return left != null && right != null &&
                string.Equals(left.Title, right.Title, StringComparison.Ordinal) &&
                string.Equals(left.Body, right.Body, StringComparison.Ordinal) &&
                left.Destination == right.Destination &&
                string.Equals(left.Reason, right.Reason, StringComparison.Ordinal);
        }

        private static bool WelcomeMatches(ReturnWelcomeHandledState handled, ReturnPlanState plan)
        {
            return string.Equals(handled.Title, plan.Title, StringComparison.Ordinal) &&
                string.Equals(handled.Body, plan.Body, StringComparison.Ordinal) &&
                handled.Destination == plan.Destination &&
                string.Equals(handled.Reason, plan.Reason, StringComparison.Ordinal);
        }

        private static string VariantWire(ReturnExperimentVariant value) =>
            value == ReturnExperimentVariant.Holdout ? "holdout" : "guided";

        private static int? DayGap(string savedDayKey, string returnDayKey)
        {
            if (!DayKey(savedDayKey) || !DayKey(returnDayKey)) return null;
            var saved = DateTime.ParseExact(
                savedDayKey, "yyyyMMdd", CultureInfo.InvariantCulture, DateTimeStyles.None);
            var returned = DateTime.ParseExact(
                returnDayKey, "yyyyMMdd", CultureInfo.InvariantCulture, DateTimeStyles.None);
            return (int)(returned - saved).TotalDays;
        }

        private static bool IsValidPromise(ReturnPlanState plan) =>
            plan != null && !string.IsNullOrWhiteSpace(plan.Title) && plan.Title.Length <= 100 &&
            !string.IsNullOrWhiteSpace(plan.Body) && plan.Body.Length <= 240 &&
            Enum.IsDefined(typeof(ReturnPlanDestination), plan.Destination) &&
            Token(plan.Reason, 48);

        private static bool DayKey(string value)
        {
            DateTime parsed;
            return value != null && value.Length == 8 && DateTime.TryParseExact(
                value,
                "yyyyMMdd",
                CultureInfo.InvariantCulture,
                DateTimeStyles.None,
                out parsed);
        }

        private static bool Hex(string value, int maximum)
        {
            if (string.IsNullOrWhiteSpace(value) || value.Length > maximum) return false;
            return value.All(character =>
                character >= '0' && character <= '9' || character >= 'a' && character <= 'f');
        }

        private static bool Token(string value, int maximum)
        {
            if (string.IsNullOrWhiteSpace(value) || value.Length > maximum) return false;
            return value.All(character =>
                character >= 'a' && character <= 'z' ||
                character >= '0' && character <= '9' ||
                character == '_' || character == '-');
        }
    }
}
