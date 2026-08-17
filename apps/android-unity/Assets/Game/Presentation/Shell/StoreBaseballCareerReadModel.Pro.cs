using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using Baseball.Application.HighSchool;
using Baseball.Application.Meta;
using Baseball.Application.Persistence;
using Baseball.Application.Pro;
using Baseball.Core.HighSchool;
using Baseball.Presentation.Common;
using Baseball.Presentation.Pitch;

namespace Baseball.Presentation.Shell
{
    public sealed partial class StoreBaseballCareerReadModel
    {

        private static void AddProDevelopment(
            IList<ScreenSectionViewModel> sections,
            ShellRoute route,
            ProCareerReadModel career)
        {
            if (route != ShellRoute.ProWeek || career == null) return;
            ProDevelopmentProgressReadModel progress = career.DevelopmentProgress;
            sections.Insert(0, new ScreenSectionViewModel(
                "pro-development-status",
                career.Season + "시즌 · " + (career.SeasonSegmentTitle ?? "현재 구간"),
                career.InjuryWeeks > 0 ? ScreenSectionTone.Warning : ScreenSectionTone.Information,
                new[]
                {
                    new ScreenRowViewModel(
                        "pro-development-progress",
                        "성장 준비도",
                        "구위 " + progress.Stuff + "/2 · 변화구 " + progress.Movement +
                        "/2 · 제구 " + progress.Command + "/2 · 체력 " + progress.Stamina + "/2",
                        "같은 성장 계획을 두 번 채우면 해당 능력이 오릅니다."),
                    new ScreenRowViewModel(
                        "pro-development-condition",
                        "현재 상태",
                        career.Week + "주 · 피로 " + career.Fatigue + " · 감독의 믿음 " + career.ManagerTrust,
                        career.InjuryWeeks > 0
                            ? "부상 회복까지 " + career.InjuryWeeks + "주 남았습니다."
                            : "부상 없이 선택한 일정을 진행 중입니다.")
                }));

            if (career.LastSegmentProgress == null) return;
            ProSegmentProgressReadModel segment = career.LastSegmentProgress;
            sections.Add(new ScreenSectionViewModel(
                "pro-last-segment-progress",
                "최근 구간 자동 진행",
                segment.StopReason == "injury" ? ScreenSectionTone.Warning : ScreenSectionTone.Positive,
                new[]
                {
                    new ScreenRowViewModel(
                        "pro-last-segment-weeks",
                        segment.AdvancedWeeks + "주 진행",
                        ProSegmentTitle(segment.StartingSegment) + " → " + ProSegmentTitle(segment.EndingSegment),
                        ProSegmentStopTitle(segment.StopReason)),
                    new ScreenRowViewModel(
                        "pro-last-segment-plan",
                        "적용한 계획",
                        ProPlanTitle(segment.Plan),
                        string.IsNullOrWhiteSpace(segment.TargetPitch)
                            ? "선택한 계획을 모든 주에 동일하게 적용했습니다."
                            : "집중 구종 · " + PitchTitle(segment.TargetPitch))
                }));
        }

        private static string ProPlanTitle(string value)
        {
            switch ((value ?? string.Empty).ToLowerInvariant())
            {
                case "develop_stuff": return "구위 강화";
                case "develop_movement": return "결정구 완성";
                case "refine_command": return "코스 제구 훈련";
                case "build_stamina": return "체력 루틴";
                case "recover": return "회복";
                case "earn_trust": return "신뢰 쌓기";
                default: return "주간 계획";
            }
        }

        private static string ProSegmentTitle(string value)
        {
            switch ((value ?? string.Empty).ToLowerInvariant())
            {
                case "spring_camp": return "스프링캠프";
                case "opening": return "개막";
                case "first_half": return "전반기";
                case "all_star_break": return "올스타 브레이크";
                case "pennant_race": return "페넌트레이스";
                case "season_finale": return "시즌 막바지";
                default: return "현재 구간";
            }
        }

        private static string ProSegmentStopTitle(string value)
        {
            switch ((value ?? string.Empty).ToLowerInvariant())
            {
                case "segment_changed": return "다음 시즌 구간이 열려 멈췄습니다.";
                case "phase_changed": return "직접 결정할 일정이 열려 멈췄습니다.";
                case "role_changed": return "투수 역할이 바뀌어 멈췄습니다.";
                case "level_changed": return "승격 또는 이동이 생겨 멈췄습니다.";
                case "injury": return "부상이 생겨 안전하게 멈췄습니다.";
                default: return "현재 구간의 자동 진행 상한에서 멈췄습니다.";
            }
        }

        private IReadOnlyList<ScreenSectionViewModel> ProSeasonSections(
            ProCareerReadModel career)
        {
            if (career == null)
            {
                return new[]
                {
                    new ScreenSectionViewModel(
                        "pro-season-unavailable",
                        "프로 시즌",
                        ScreenSectionTone.Warning,
                        new[]
                        {
                            new ScreenRowViewModel(
                                "pro-season-unavailable-copy",
                                "시즌 기록을 불러올 수 없음",
                                "저장된 프로 커리어가 없습니다.",
                                "현재 저장 상태를 다시 확인해 주세요.")
                        })
                };
            }

            var sections = new List<ScreenSectionViewModel>();
            var personalRows = new List<ScreenRowViewModel>();
            AddPitchingRecordRows(
                personalRows,
                "pro-season-personal",
                career.Season + "시즌 개인 기록",
                career.RecordBook?.CurrentSeason,
                career.RecordBook?.CurrentSeason != null,
                career.TeamName + " · " + RoleTitle(career.Role));
            sections.Add(new ScreenSectionViewModel(
                "pro-season-personal",
                career.Season + "시즌 · 개인 기록",
                ScreenSectionTone.Milestone,
                personalRows));

            IReadOnlyList<LeagueStandingReadModel> standings = career.LeagueStandings ??
                Array.Empty<LeagueStandingReadModel>();
            ScreenRowViewModel[] teamRows = standings.Count == 0
                ? new[]
                {
                    new ScreenRowViewModel(
                        "pro-season-team-unavailable",
                        career.TeamName,
                        "팀 순위를 불러올 수 없음",
                        "이전 저장에는 현재 시즌 순위표가 보관되지 않았습니다.")
                }
                : standings.OrderBy(value => value.Rank).Select(value => new ScreenRowViewModel(
                    "pro-season-team-" + value.Rank,
                    value.Rank + "위 · " + value.TeamName,
                    value.Wins + "승 " + value.Losses + "패 " + value.Draws + "무",
                    (value.Rank == 1
                        ? "현재 선두"
                        : "선두와 " + value.GamesBehind.ToString("0.0", CultureInfo.InvariantCulture) +
                          "경기 차") +
                    (value.IsPlayerTeam ? " · 내 구단" : string.Empty))).ToArray();
            sections.Add(new ScreenSectionViewModel(
                "pro-season-team",
                "팀 결과",
                ScreenSectionTone.Information,
                teamRows));

            ProDevelopmentProgressReadModel progress = career.DevelopmentProgress ??
                new ProDevelopmentProgressReadModel();
            var growthRows = new List<ScreenRowViewModel>
            {
                new ScreenRowViewModel(
                    "pro-season-ratings",
                    "현재 네 능력",
                    RatingLine(career.Ratings),
                    "지도자의 믿음 " + career.ManagerTrust + " · 포수와의 호흡 " +
                    career.CatcherTrust + " · 피로 " + career.Fatigue),
                new ScreenRowViewModel(
                    "pro-season-development",
                    "다음 성장까지",
                    "구위 " + progress.Stuff + "/2 · 제구 " + progress.Command +
                    "/2 · 변화 " + progress.Movement + "/2 · 체력 " +
                    progress.Stamina + "/2",
                    "같은 성장 계획을 두 번 채우면 해당 능력이 오릅니다.")
            };
            if (career.LastSegmentProgress != null)
            {
                ProSegmentProgressReadModel segment = career.LastSegmentProgress;
                growthRows.Add(new ScreenRowViewModel(
                    "pro-season-last-segment",
                    "최근 성장 일정",
                    ProPlanTitle(segment.Plan) + " · " + segment.AdvancedWeeks + "주",
                    ProSegmentTitle(segment.StartingSegment) + " → " +
                    ProSegmentTitle(segment.EndingSegment) + " · " +
                    ProSegmentStopTitle(segment.StopReason)));
            }
            sections.Add(new ScreenSectionViewModel(
                "pro-season-growth",
                "시즌 성장",
                ScreenSectionTone.Positive,
                growthRows));

            IReadOnlyList<ProDecisionHistoryReadModel> history = career.RecordBook?.DecisionHistory ??
                Array.Empty<ProDecisionHistoryReadModel>();
            ProDecisionHistoryReadModel[] seasonHistory = history
                .Where(value => value.Season == career.Season)
                .OrderBy(value => value.Week)
                .ToArray();
            if (seasonHistory.Length > 0)
            {
                sections.Add(new ScreenSectionViewModel(
                    "pro-season-decisions",
                    "이번 시즌 선택과 변화",
                    ScreenSectionTone.Plain,
                    seasonHistory.Select((decision, index) => new ScreenRowViewModel(
                        "pro-season-decision-" + index,
                        decision.Week + "주 · " + decision.ChoiceTitle,
                        decision.EffectSummary,
                        ProDecisionDeltaLine(decision))).ToArray()));
            }

            ProRecordBookReadModel recordBook = career.RecordBook;
            if (recordBook != null &&
                (recordBook.AwardNames.Count > 0 || recordBook.Milestones.Count > 0))
            {
                var achievementRows = new List<ScreenRowViewModel>();
                if (recordBook.AwardNames.Count > 0)
                    achievementRows.Add(new ScreenRowViewModel(
                        "pro-season-awards",
                        "수상",
                        string.Join(" · ", recordBook.AwardNames)));
                if (recordBook.Milestones.Count > 0)
                    achievementRows.Add(new ScreenRowViewModel(
                        "pro-season-milestones",
                        "이정표",
                        string.Join(" · ", recordBook.Milestones)));
                sections.Add(new ScreenSectionViewModel(
                    "pro-season-achievements",
                    "시즌 성취",
                    ScreenSectionTone.Milestone,
                    achievementRows));
            }

            sections.Add(ProSeasonNextSection(career));
            return sections;
        }

        private ScreenSectionViewModel ProSeasonNextSection(ProCareerReadModel career)
        {
            if (career.Phase == ProCareerPhase.SeasonDecision && career.SeasonDecision != null)
            {
                ProSeasonDecisionReadModel decision = career.SeasonDecision;
                string selectedPayload = _selectedChoice("pro_season_decision");
                Baseball.Application.Commands.CareerChoiceReadModel selected = decision.Choices
                    .FirstOrDefault(value => value.Enabled && string.Equals(
                        value.Payload,
                        selectedPayload,
                        StringComparison.Ordinal));
                var rows = new List<ScreenRowViewModel>
                {
                    new ScreenRowViewModel(
                        "pro-season-next-context",
                        decision.Title,
                        decision.Detail,
                        "선택 효과와 현재 팀·개인 기록을 함께 확인하세요.")
                };
                rows.Add(selected == null
                    ? new ScreenRowViewModel(
                        "pro-season-next-selection",
                        "다음 선택",
                        "선택 대기",
                        "아래 선택지에서 한 가지를 고르면 확정 버튼이 열립니다.")
                    : new ScreenRowViewModel(
                        "pro-season-next-selection",
                        "선택 근거 · " + selected.Title,
                        string.IsNullOrWhiteSpace(selected.EffectSummary)
                            ? selected.Detail
                            : selected.EffectSummary,
                        DecisionChoiceDetail(selected)));
                return new ScreenSectionViewModel(
                    "pro-season-next",
                    "다음 선택",
                    selected == null ? ScreenSectionTone.Warning : ScreenSectionTone.Information,
                    rows);
            }

            return new ScreenSectionViewModel(
                "pro-season-next",
                "다음 선택",
                ScreenSectionTone.Information,
                new[]
                {
                    new ScreenRowViewModel(
                        "pro-season-next-review",
                        career.Phase == ProCareerPhase.SeasonReview
                            ? "시즌 결산 저장"
                            : "다음 프로 일정 확인",
                        career.Phase == ProCareerPhase.SeasonReview
                            ? "개인 기록과 팀 결과를 확인했습니다."
                            : "현재 시즌 상태를 저장했습니다.",
                        career.Phase == ProCareerPhase.SeasonReview
                            ? "결산을 저장하면 수상·이정표가 확정되고 오프시즌 선택 또는 은퇴 결정으로 이어집니다."
                            : "저장된 프로 단계에 맞는 다음 화면으로 이동합니다.")
                });
        }

        private static string DecisionChoiceDetail(
            Baseball.Application.Commands.CareerChoiceReadModel choice)
        {
            var parts = new List<string>();
            if (!string.IsNullOrWhiteSpace(choice.Detail)) parts.Add(choice.Detail);
            if (!string.IsNullOrWhiteSpace(choice.EffectSummary) &&
                !string.Equals(choice.EffectSummary, choice.Detail, StringComparison.Ordinal))
                parts.Add(choice.EffectSummary);
            if (choice.Recommended && !string.IsNullOrWhiteSpace(choice.RecommendationReason))
                parts.Add("추천 근거 · " + choice.RecommendationReason);
            return parts.Count == 0 ? "선택 효과는 저장 후 적용됩니다." : string.Join(" · ", parts);
        }

        private static string RoleTitle(string value)
        {
            switch ((value ?? string.Empty).ToLowerInvariant())
            {
                case "ace": return "에이스";
                case "starter": return "선발";
                case "long_relief": return "롱 릴리프";
                case "setup": return "셋업";
                case "closer": return "마무리";
                default: return "현재 역할";
            }
        }

        private static string SeasonVolumeLine(ProSeasonLineReadModel line) =>
            line.Games + "경기 · " +
            (line.Starts.HasValue ? "선발 " + line.Starts.Value : "선발 미기록") + " · " +
            Innings(line.InningsOuts) + "이닝 · " + NullableCount(line.Pitches, "투구");

        private static string SeasonResultLine(ProSeasonLineReadModel line) =>
            line.Wins + "승 " + line.Losses + "패 · " + line.Saves + "세이브 · 탈삼진 " +
            line.Strikeouts + " · 볼넷 " + line.Walks + " · 실점 " + line.RunsAllowed +
            " · " + NullableCount(line.Hits, "피안타") + " · " +
            NullableCount(line.HomeRuns, "피홈런");

        private static string AdvancedCompact(PitchingRecordReadModel record) =>
            "9이닝당 실점 " + Metric(record?.RunsPerNine) + " · WHIP " +
            Metric(record?.Whip) + " · K/9 " + Metric(record?.StrikeoutsPerNine) +
            " · FIP " + Metric(record?.FieldingIndependentPitching);

        private static string ProDecisionDeltaLine(ProDecisionHistoryReadModel decision)
        {
            var parts = new List<string>();
            AddDelta(parts, "구위", decision.StuffDelta);
            AddDelta(parts, "제구", decision.CommandDelta);
            AddDelta(parts, "변화", decision.MovementDelta);
            AddDelta(parts, "체력", decision.StaminaDelta);
            AddDelta(parts, "지도자 믿음", decision.ManagerTrustDelta);
            AddDelta(parts, "포수 호흡", decision.CatcherTrustDelta);
            AddDelta(parts, "피로", decision.FatigueDelta);
            if (!string.IsNullOrWhiteSpace(decision.RoleTarget))
                parts.Add("역할 " + decision.RoleTarget);
            return parts.Count == 0 ? "선택 결과가 저장되었습니다." : string.Join(" · ", parts);
        }

        private static void AddDelta(ICollection<string> parts, string label, int delta)
        {
            if (delta != 0) parts.Add(label + " " + Signed(delta));
        }

        private static IReadOnlyList<ScreenSectionViewModel> ProContractSections(GameSaveAggregate state)
        {
            ProCareerReadModel career = state?.Pro;
            ProContractOfferReadModel offer = career?.ContractOffer;
            if (offer == null)
            {
                bool unlocked = HasCompletedLife(state);
                string detail = unlocked
                    ? state?.HighSchool == null
                        ? "선택한 이름과 투수 유형으로 프로부터 시작할 수 있습니다."
                        : "진행 중인 고교 선수는 보존되며, 프로 은퇴 뒤 현재 고교 일정으로 돌아옵니다."
                    : "고교 3년을 한 번 마치면 고교를 건너뛰는 길도 열립니다.";
                return new[]
                {
                    new ScreenSectionViewModel(
                        "direct-pro-entry",
                        "고교 드래프트에서 지명을 받으면 열립니다",
                        unlocked ? ScreenSectionTone.Milestone : ScreenSectionTone.Information,
                        new[]
                        {
                            new ScreenRowViewModel(
                                "direct-pro-regular-path",
                                "정규 경로",
                                "고교 3년을 보내고 드래프트를 통과하면 성장한 능력을 그대로 이어갑니다.",
                                detail),
                            new ScreenRowViewModel(
                                "direct-pro-skip-rule",
                                unlocked ? "프로부터 시작 가능" : "프로부터 시작 잠김",
                                unlocked
                                    ? "고교 3년의 성장과 기억 없이 별도의 프로 커리어를 시작합니다."
                                    : "첫 번째 고교 인생을 완주해 잠금을 해제하세요.")
                        })
                };
            }
            return new[]
            {
                new ScreenSectionViewModel("contract-offer", "가상 구단 계약 제안", ScreenSectionTone.Milestone,
                    new[]
                    {
                        new ScreenRowViewModel("contract-team", "구단", offer.TeamName),
                        new ScreenRowViewModel("contract-role", "약속된 역할", ProRoleName(offer.Role)),
                        new ScreenRowViewModel("contract-years", "계약 기간", offer.Years + "년"),
                        new ScreenRowViewModel("contract-salary", "연봉", offer.AnnualSalary.ToString("N0") + "원"),
                    })
            };
        }
    }
}
