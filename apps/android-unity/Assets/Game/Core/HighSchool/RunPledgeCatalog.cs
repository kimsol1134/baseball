using System;
using System.Collections.Generic;
using System.Linq;
using Baseball.Core.Random;

namespace Baseball.Core.HighSchool
{
    /// <summary>A pledge is immutable content plus deterministic evaluation behavior.</summary>
    public sealed class RunPledge : IEquatable<RunPledge>
    {
        private readonly Func<RunPledgeContext, bool> _eligibility;
        private readonly Func<RunPledgeContext, RunPledgeProgress> _progress;

        internal RunPledge(
            string id,
            RunPledgeTier tier,
            string title,
            string detail,
            int rewardPermille,
            Func<RunPledgeContext, bool> eligibility,
            Func<RunPledgeContext, RunPledgeProgress> progress)
        {
            Id = id;
            Tier = tier;
            Title = title;
            Detail = detail;
            RewardPermille = rewardPermille;
            _eligibility = eligibility;
            _progress = progress;
        }

        public string Id { get; }
        public RunPledgeTier Tier { get; }
        public string TierId => Tier.Value();
        public string TierTitle => Tier.Title();
        public string Title { get; }
        public string Detail { get; }
        public int RewardPermille { get; }

        public bool IsEligible(RunPledgeContext context)
        {
            if (context == null) throw new ArgumentNullException(nameof(context));
            return _eligibility(context);
        }

        public RunPledgeProgress Progress(RunPledgeContext context)
        {
            if (context == null) throw new ArgumentNullException(nameof(context));
            return _progress(context);
        }

        public bool Achieved(RunPledgeContext context) => Progress(context).Achieved;

        public string ProgressLine(RunPledgeContext context) => Progress(context).Line;

        public string AlignmentReason(RunPledgeContext context)
        {
            if (RunPledgeCatalog.BuildAlignedIds(context).Contains(Id))
            {
                switch (Id)
                {
                    case "iron_control":
                    case "iron_control_five":
                        return "제구가 가장 높은 능력이라 볼넷 억제에 잘 맞습니다.";
                    case "evaluation_sixty_five":
                        return "제구 강점을 전체 평가로 이어 가는 목표입니다.";
                    case "strikeout_master":
                    case "clean_games":
                    case "evaluation_seventy_five":
                        return "구위와 변화구 강점을 경기 결과로 바꾸는 목표입니다.";
                    case "relationship_sixty_five":
                    case "rival_three_strikeouts":
                        return "지금 가장 두터운 관계를 승부의 힘으로 잇는 목표입니다.";
                    case "healthy_finish":
                        return "현재 팔 부담을 관리하며 완주하는 데 맞춘 목표입니다.";
                    case "fan_sixty":
                        return "이미 모인 팬 관심을 더 큰 이야기로 잇는 목표입니다.";
                    default:
                        return "지금 키운 강점을 끝까지 증명하는 목표입니다.";
                }
            }

            switch (Tier)
            {
                case RunPledgeTier.Safe:
                    return "현재 능력 구성과 무관하게 완주를 노리는 안전 목표입니다.";
                case RunPledgeTier.Bold:
                    return "현재 강점과 다른 방향까지 넓혀 보는 도전 목표입니다.";
                case RunPledgeTier.Legendary:
                    return "현재 강점을 넘어 한계를 시험하는 전설 목표입니다.";
                default:
                    throw new ArgumentOutOfRangeException();
            }
        }

        public string AccessibilityLabel(
            string progressLine,
            bool carried = false,
            string status = null)
        {
            if (progressLine == null) throw new ArgumentNullException(nameof(progressLine));
            var prefix = carried ? "지난 고교 3년에서 이어진 " : string.Empty;
            var statusText = status == null ? string.Empty : ", " + status;
            return prefix + Tier.Title() + " 목표, " + Title + ", " + progressLine + statusText +
                ", 보상 야구혼 " + (RewardPermille / 10) + "퍼센트 추가";
        }

        public string AccessibilityLabel(
            RunPledgeProgress progress,
            bool carried = false,
            string status = null)
        {
            if (progress == null) throw new ArgumentNullException(nameof(progress));
            return AccessibilityLabel(progress.Line, carried, status);
        }

        public bool Equals(RunPledge other)
        {
            return other != null && string.Equals(Id, other.Id, StringComparison.Ordinal);
        }

        public override bool Equals(object obj) => Equals(obj as RunPledge);

        public override int GetHashCode() => StringComparer.Ordinal.GetHashCode(Id);
    }

    public static class RunPledgeCatalog
    {
        public const int LegacyRulesVersion = 1;
        public const int CurrentRulesVersion = 2;
        public const string RetryIntentReason = "지난 고교 3년에서 아쉽게 놓친 목표입니다.";

        private static readonly IReadOnlyList<RunPledge> Current = Array.AsReadOnly(new[]
        {
            Make("get_drafted", RunPledgeTier.Safe, "이름이 불린다", "드래프트에서 이름이 불린다.", context =>
            {
                var achieved = context.DraftOutcome == DraftOutcome.Drafted;
                return Progress(achieved ? 1 : 0, 1, achieved, achieved ? "지명 1/1" : "지명 0/1");
            }),
            Make("strikeout_master", RunPledgeTier.Bold, "시즌 5탈삼진", "직접 등판 통산 5탈삼진을 만든다.", context =>
                CountProgress("탈삼진", context.Strikeouts, 5)),
            Make("clean_games", RunPledgeTier.Bold, "무실점 등판 4회", "직접 던진 경기에서 무실점을 네 번 만든다.", context =>
                CountProgress("무실점 등판", context.CleanGames, 4)),
            Make("iron_control", RunPledgeTier.Bold, "무볼넷 4탈삼진", "직접 등판 4경기 이상, 볼넷 없이 통산 4탈삼진을 만든다.", context =>
                ControlProgress(context, 4)),
            Make("healthy_finish", RunPledgeTier.Safe, "팔을 지켜 완주", "고교 공식 경기 네 번을 치르고 피로를 78 이하로 남긴 채 팔 경고 없이 완주한다.", context =>
            {
                var games = context.ImportantGamesCompleted;
                var healthy = context.ArmRisk < 55 && context.InjuryRecovery == 0 && context.Fatigue <= 78;
                var armRatio = context.ArmRisk < 55
                    ? 1000
                    : Math.Max(0, (100 - context.ArmRisk) * 1000 / 46);
                var recoveryRatio = context.InjuryRecovery == 0
                    ? 1000
                    : 1000 / (context.InjuryRecovery + 1);
                var fatigueRatio = context.Fatigue <= 78
                    ? 1000
                    : Math.Max(0, (100 - context.Fatigue) * 1000 / 22);
                var condition = context.ArmRisk < 55 && context.InjuryRecovery == 0
                    ? "팔 상태 안정"
                    : context.InjuryRecovery > 0 ? "재활 중" : "팔 상태 경고";
                return Progress(
                    games,
                    4,
                    games >= 4 && healthy,
                    "고교 공식 경기 " + games + "/4 · 피로 " + context.Fatigue + "/78 이하 · " + condition,
                    Minimum(CountRatio(games, 4), armRatio, recoveryRatio, fatigueRatio));
            }),
            Make("awakening_three", RunPledgeTier.Bold, "세 번의 각성", "각성 세 번을 고르고 서로 다른 전략 계열 세 가지를 모은다.", context =>
            {
                var awakenings = context.SelectedAwakenings.Count;
                var families = context.SelectedAwakenings.Select(AwakeningFamily).Distinct().Count();
                return Progress(
                    families,
                    3,
                    awakenings >= 3 && families >= 3,
                    "각성 " + awakenings + "/3 · 전략 계열 " + families + "/3",
                    Math.Min(CountRatio(awakenings, 3), CountRatio(families, 3)));
            }),
            Make("fan_sixty", RunPledgeTier.Bold, "관중의 이름이 된다", "팬 관심을 25 이상으로 올린다.", context =>
                CountProgress("팬 관심", context.FanInterest, 25)),
            Make("evaluation_sixty_five", RunPledgeTier.Bold, "평가 64점", "드래프트 평가 64점 이상을 받는다.", context =>
                EvaluationProgress(context, 64)),
            Make("evaluation_seventy_five", RunPledgeTier.Legendary, "평가 67점", "드래프트 평가 67점 이상을 받는다.", context =>
                EvaluationProgress(context, 67)),
            Make("iron_control_five", RunPledgeTier.Legendary, "무볼넷 6탈삼진", "직접 등판 4경기 이상, 볼넷 없이 통산 6탈삼진을 만든다.", context =>
                ControlProgress(context, 6)),
            Make("rival_three_strikeouts", RunPledgeTier.Bold, "숙적에게 세 번 앞선다", "고교 3년 동안 숙적을 세 번 삼진으로 잡는다.", context =>
                CountProgress("숙적 상대 삼진", context.RivalStrikeouts, 3)),
            Make("relationship_sixty_five", RunPledgeTier.Safe, "한 사람의 전적인 믿음", "감독·포수·숙적 중 한 관계를 69 이상으로 만든다.", context =>
            {
                var value = Math.Max(
                    context.ManagerTrust ?? context.RelationshipTrust,
                    Math.Max(
                        context.CatcherTrust ?? context.RelationshipTrust,
                        context.RivalTrust ?? context.RelationshipTrust));
                return CountProgress("가장 높은 믿음", value, 69);
            })
        });

        private static readonly IReadOnlyList<RunPledge> Legacy = Array.AsReadOnly(new[]
        {
            Make("strikeout_master", RunPledgeTier.Bold, "시즌 40탈삼진", "3년 동안 직접 잡는 탈삼진 40개.", context =>
                CountProgress("탈삼진", context.Strikeouts, 40), 150),
            Make("clean_games", RunPledgeTier.Safe, "무실점 등판 2회", "직접 던진 경기에서 무실점을 두 번 만든다.", context =>
                CountProgress("무실점 등판", context.CleanGames, 2), 150),
            Make("get_drafted", RunPledgeTier.Safe, "지명받는다", "드래프트에서 이름이 불린다.", context =>
            {
                var achieved = context.DraftOutcome == DraftOutcome.Drafted;
                return Progress(achieved ? 1 : 0, 1, achieved, achieved ? "지명 1/1" : "지명 0/1");
            }, 150),
            Make("iron_control", RunPledgeTier.Safe, "볼넷 8개 이하", "시즌을 볼넷 8개 이하로 완주한다(4경기 이상).", context =>
            {
                var games = context.ImportantGamesCompleted;
                var walks = context.Walks;
                var achieved = games >= 4 && walks <= 8;
                var walkRatio = walks <= 8 ? 1000 : Math.Max(0, 8000 / Math.Max(1, walks));
                return Progress(
                    games,
                    4,
                    achieved,
                    "직접 등판 " + games + "/4 · 볼넷 " + walks + "/8 이하",
                    Math.Min(CountRatio(games, 4), walkRatio));
            }, 150)
        });

        public static IReadOnlyList<RunPledge> All => Current;
        public static IReadOnlyList<RunPledge> LegacyV1 => Legacy;

        public static RunPledge Resolve(
            string id,
            int rulesVersion = CurrentRulesVersion)
        {
            if (id == null) return null;
            var catalog = rulesVersion <= LegacyRulesVersion ? Legacy : Current;
            return catalog.FirstOrDefault(value => string.Equals(value.Id, id, StringComparison.Ordinal));
        }

        /// <summary>
        /// Returns exactly three stable choices. A valid carried intent is first, then the result
        /// covers safe, build-aligned, and bold/legendary goals whenever those slots are available.
        /// The intent is only ordered first; it never selects a pledge for the player.
        /// </summary>
        public static IReadOnlyList<RunPledge> Options(
            string careerId,
            RunPledgeContext context,
            NextRunIntent intent = null)
        {
            if (careerId == null) throw new ArgumentNullException(nameof(careerId));
            if (context == null) throw new ArgumentNullException(nameof(context));

            var ordered = Current
                .Where(value => value.IsEligible(context) &&
                    (context.LifeNumber > 1 || value.Tier != RunPledgeTier.Legendary))
                .OrderBy(value => OptionRank(careerId, value.Id))
                .ToArray();
            var selected = new List<RunPledge>();
            if (intent != null)
            {
                var carried = ordered.FirstOrDefault(value =>
                    string.Equals(value.Id, intent.PledgeId, StringComparison.Ordinal));
                if (carried != null) selected.Add(carried);
            }

            var aligned = new HashSet<string>(BuildAlignedIds(context), StringComparer.Ordinal);
            EnsureCoverage(selected, ordered, value => value.Tier == RunPledgeTier.Safe);
            EnsureCoverage(selected, ordered, value => aligned.Contains(value.Id));
            EnsureCoverage(selected, ordered, value =>
                value.Tier == RunPledgeTier.Legendary || value.Tier == RunPledgeTier.Bold);
            foreach (var candidate in ordered)
            {
                if (selected.Count >= 3) break;
                if (!selected.Contains(candidate)) selected.Add(candidate);
            }

            return Array.AsReadOnly(selected.Take(3).ToArray());
        }

        /// <summary>Frozen compatibility order used before the state-aware v2 catalog.</summary>
        public static IReadOnlyList<RunPledge> Options(string careerId)
        {
            if (careerId == null) throw new ArgumentNullException(nameof(careerId));
            var generator = new SplitMix64(StableHash.Fnv1A64Value(careerId + "|pledge-legacy-options"));
            var pool = Current.Take(4).ToArray();
            for (var index = pool.Length - 1; index > 0; index--)
            {
                var other = generator.NextInt(index + 1);
                var temporary = pool[index];
                pool[index] = pool[other];
                pool[other] = temporary;
            }

            return Array.AsReadOnly(pool.Take(3).ToArray());
        }

        public static IReadOnlyCollection<string> BuildAlignedIds(RunPledgeContext context)
        {
            if (context == null) throw new ArgumentNullException(nameof(context));

            var bestScore = context.Command;
            var ids = new HashSet<string>(new[]
            {
                "iron_control", "iron_control_five", "evaluation_sixty_five"
            }, StringComparer.Ordinal);

            var power = Math.Max(context.Stuff, context.Movement);
            if (power > bestScore)
            {
                bestScore = power;
                ids = new HashSet<string>(new[]
                {
                    "strikeout_master", "clean_games", "evaluation_seventy_five"
                }, StringComparer.Ordinal);
            }

            var relationship = Math.Max(
                context.ManagerTrust ?? 0,
                Math.Max(context.CatcherTrust ?? 0, context.RivalTrust ?? 0));
            if (relationship > bestScore)
            {
                ids = new HashSet<string>(new[]
                {
                    "relationship_sixty_five", "rival_three_strikeouts"
                }, StringComparer.Ordinal);
            }

            if (context.ArmRisk >= 35) ids.Add("healthy_finish");
            if (context.FanInterest >= 35) ids.Add("fan_sixty");
            return Array.AsReadOnly(ids.OrderBy(value => value, StringComparer.Ordinal).ToArray());
        }

        public static RunPledgeAwakeningFamily AwakeningFamily(AwakeningId awakening)
        {
            switch (awakening)
            {
                case AwakeningId.ExplosiveFastball:
                case AwakeningId.RisingFourSeam:
                case AwakeningId.IronArm:
                case AwakeningId.LateInningReserve:
                    return RunPledgeAwakeningFamily.Body;
                case AwakeningId.PinpointEdge:
                case AwakeningId.RepeatableRelease:
                case AwakeningId.FirstPitchStrike:
                case AwakeningId.CalmUnderPressure:
                case AwakeningId.ScoutComposure:
                    return RunPledgeAwakeningFamily.Command;
                case AwakeningId.DisappearingBreaker:
                case AwakeningId.SinkerTunnel:
                case AwakeningId.FrozenChangeup:
                case AwakeningId.SweepingSlider:
                case AwakeningId.CurveballClock:
                    return RunPledgeAwakeningFamily.Breaking;
                case AwakeningId.BatterySync:
                case AwakeningId.PickoffRhythm:
                case AwakeningId.TwoStrikePlan:
                case AwakeningId.TrafficController:
                    return RunPledgeAwakeningFamily.Game;
                default:
                    throw new ArgumentOutOfRangeException(nameof(awakening));
            }
        }

        private static RunPledge Make(
            string id,
            RunPledgeTier tier,
            string title,
            string detail,
            Func<RunPledgeContext, RunPledgeProgress> progress,
            int? rewardPermille = null,
            Func<RunPledgeContext, bool> eligibility = null)
        {
            return new RunPledge(
                id,
                tier,
                title,
                detail,
                rewardPermille ?? tier.RewardPermille(),
                eligibility ?? (_ => true),
                progress);
        }

        private static RunPledgeProgress EvaluationProgress(
            RunPledgeContext context,
            int target)
        {
            var value = context.DraftEvaluationScore ?? context.DraftForecastScore;
            return Progress(value, target, value >= target, "평가 " + value + "/" + target);
        }

        private static RunPledgeProgress ControlProgress(
            RunPledgeContext context,
            int strikeoutTarget)
        {
            var games = context.ImportantGamesCompleted;
            var walks = context.Walks;
            var strikeouts = context.Strikeouts;
            var achieved = games >= 4 && walks == 0 && strikeouts >= strikeoutTarget;
            var walkRatio = walks == 0 ? 1000 : 1000 / (walks + 1);
            return Progress(
                strikeouts,
                strikeoutTarget,
                achieved,
                "직접 등판 " + games + "/4 · 볼넷 " + walks + "/0 · 탈삼진 " +
                    strikeouts + "/" + strikeoutTarget,
                Minimum(
                    CountRatio(games, 4),
                    walkRatio,
                    CountRatio(strikeouts, strikeoutTarget)));
        }

        private static RunPledgeProgress CountProgress(string name, int current, int target)
        {
            return Progress(current, target, current >= target, name + " " + current + "/" + target);
        }

        private static int CountRatio(int current, int target)
        {
            if (target <= 0) return 0;
            return Math.Min(1000, Math.Max(0, current) * 1000 / target);
        }

        private static int Minimum(params int[] values) => values.Min();

        private static ulong OptionRank(string careerId, string pledgeId)
        {
            return StableHash.Fnv1A64Value(careerId + "|pledge-v2|" + pledgeId);
        }

        private static RunPledgeProgress Progress(
            int current,
            int target,
            bool achieved,
            string line,
            int? unachievedRatioPermille = null)
        {
            return new RunPledgeProgress(
                current,
                target,
                achieved,
                line,
                unachievedRatioPermille);
        }

        private static void EnsureCoverage(
            ICollection<RunPledge> selected,
            IEnumerable<RunPledge> ordered,
            Func<RunPledge, bool> predicate)
        {
            if (selected.Count >= 3 || selected.Any(predicate)) return;
            var choice = ordered.FirstOrDefault(value => predicate(value) && !selected.Contains(value));
            if (choice != null) selected.Add(choice);
        }
    }
}
