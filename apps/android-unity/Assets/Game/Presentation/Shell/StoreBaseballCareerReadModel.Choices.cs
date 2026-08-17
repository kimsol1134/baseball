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

        private IReadOnlyList<ScreenChoiceGroupViewModel> ProjectChoiceGroups(
            ShellRoute route,
            GameSaveAggregate state)
        {
            HighSchoolCareerReadModel highSchool = state.HighSchool;
            ProCareerReadModel pro = state.Pro;
            switch (route)
            {
                case ShellRoute.Prologue when highSchool?.Phase == HighSchoolPhase.SchoolSelection:
                    RunPledgeCatalogReadModel pledge = RunPledgeRules.Project(state);
                    return pledge.CanChoose
                        ? Groups(
                            PledgeGroup(pledge),
                            Group("school", "학교 비교", "네 학교의 방향을 비교한 뒤 목표 선택 후 확정합니다.", highSchool.SchoolChoices))
                        : Groups(Group("school", "학교 비교", "네 학교의 방향을 비교한 뒤 아래 버튼으로 확정합니다.", highSchool.SchoolChoices));
                case ShellRoute.Training:
                    return string.Equals(_selectedChoice("training_focus"), "breaking_ball", StringComparison.Ordinal)
                        ? Groups(
                            Group("training_focus", "훈련 초점", "이번 훈련에서 집중할 능력입니다.", highSchool?.TrainingFocusChoices),
                            Group("training_intensity", "훈련 강도", "피로와 성장 폭을 함께 확인하세요.", highSchool?.TrainingIntensityChoices),
                            Group("training_pitch", "집중할 변화구", "변화구 훈련은 실제 보유 구종 가운데 하나를 골라야 합니다.", highSchool?.TrainingPitchChoices))
                        : Groups(
                            Group("training_focus", "훈련 초점", "이번 훈련에서 집중할 능력입니다.", highSchool?.TrainingFocusChoices),
                            Group("training_intensity", "훈련 강도", "피로와 성장 폭을 함께 확인하세요.", highSchool?.TrainingIntensityChoices));
                case ShellRoute.Relationship:
                    return Groups(Group("relationship", "대화 응답", "상대의 말에 어떻게 답할지 고릅니다.", highSchool?.RelationshipChoices));
                case ShellRoute.Awakening:
                    return Groups(Group("awakening", "사용 가능한 각성", "효과를 확인하고 한 가지를 확정합니다.", highSchool?.AwakeningChoices));
                case ShellRoute.RunRecap when highSchool?.Phase == HighSchoolPhase.Legacy:
                    return highSchool.LegacySelectionMode == LegacySelectionMode.SignatureLegacy
                        ? Groups(Group("legacy_signature", "대표 유산", "이번 인생을 대표할 유산을 한 가지 고릅니다.", highSchool.SignatureLegacyChoices))
                        : Groups(Group("legacy_memories", "남길 기억", "표시된 슬롯 수만큼 다음 인생에 보낼 기억을 고릅니다.", highSchool.LegacyMemoryChoices, Math.Max(1, highSchool.MemorySlots)));
                case ShellRoute.ProWeek when pro?.Phase == ProCareerPhase.WeeklyPlan:
                    return string.Equals(_selectedChoice("pro_week_plan"), "develop_movement", StringComparison.Ordinal)
                        ? Groups(
                            Group("pro_week_plan", "이번 주 계획", "구위와 결정구를 분리해 이번 선수의 성장 방향을 고릅니다.", pro.WeekPlanChoices),
                            Group("pro_development_pitch", "집중할 결정구", "결정구 완성은 실제 보유 변화구 하나를 골라야 합니다.", pro.DevelopmentPitchChoices))
                        : Groups(Group("pro_week_plan", "이번 주 계획", "구위와 결정구를 분리해 이번 선수의 성장 방향을 고릅니다.", pro.WeekPlanChoices));
                case ShellRoute.ProSeason when pro?.Phase == ProCareerPhase.SeasonDecision:
                    return Groups(Group(
                        "pro_season_decision",
                        pro.SeasonDecision?.Title ?? "시즌 결정",
                        pro.SeasonDecision?.Detail ?? "시즌 흐름을 바꿀 선택입니다.",
                        pro.SeasonDecision?.Choices));
                case ShellRoute.ProRetirement when pro?.Phase == ProCareerPhase.Offseason ||
                                                   pro?.Phase == ProCareerPhase.RetirementDecision:
                    return Groups(Group("pro_offseason", "오프시즌 선택", "계속 도전할지 역할을 바꿀지 선택합니다.", pro.OffseasonChoices));
                default:
                    return Array.Empty<ScreenChoiceGroupViewModel>();
            }
        }

        private static ReturnPlanState WelcomeReturnPlan(GameSaveAggregate state, DateTimeOffset now)
            => ReturnPlanPresentationPolicy.Welcome(state, now);

        private static NextActionReadModel CurrentStateNextAction(GameSaveAggregate state)
            => NextActionPlanner.ResolveCoreProgress(state);

        private static ScreenChoiceGroupViewModel Group(
            string id,
            string heading,
            string detail,
            IReadOnlyList<Baseball.Application.Commands.CareerChoiceReadModel> choices,
            int maximumSelections = 1)
        {
            return new ScreenChoiceGroupViewModel(
                id,
                heading,
                detail,
                (choices ?? Array.Empty<Baseball.Application.Commands.CareerChoiceReadModel>())
                    .Select(value =>
                    {
                        string primaryArtwork = string.Equals(id, "school", StringComparison.Ordinal)
                            ? BaseballVisualContentCatalog.SchoolCoachPortrait(value.Detail)
                            : BaseballVisualContentCatalog.Choice(id, value.Payload);
                        string secondaryArtwork = string.Equals(id, "school", StringComparison.Ordinal)
                            ? BaseballVisualContentCatalog.SchoolCatcherPortrait(value.Detail)
                            : string.Empty;
                        return new ScreenChoiceOptionViewModel(
                            value.Id,
                            value.Title,
                            value.Payload,
                            value.Detail,
                            value.EffectSummary,
                            value.Enabled,
                            value.DisabledReason,
                            primaryArtwork,
                            secondaryArtwork);
                    })
                    .ToArray(),
                maximumSelections);
        }

        private static ScreenChoiceGroupViewModel PledgeGroup(RunPledgeCatalogReadModel catalog)
        {
            return new ScreenChoiceGroupViewModel(
                "run_pledge",
                "고교 3년 목표",
                "목표 하나를 고르거나 목표 없이 시작할 수 있습니다. 달성하면 야구혼 보너스를 받습니다.",
                catalog.Choices.Select(value => new ScreenChoiceOptionViewModel(
                    "pledge-" + value.Id,
                    PledgeTierTitle(value.Tier) + " · " + value.Title,
                    value.Payload,
                    value.Detail + " " + value.Progress.Line,
                    (value.Carried ? "지난 인생 추천 · " : string.Empty) + value.AlignmentReason +
                    " · 달성 보너스 야구혼 +" + value.RewardPermille / 10 + "%"))
                    .ToArray());
        }

        private static IReadOnlyList<ScreenChoiceGroupViewModel> Groups(
            params ScreenChoiceGroupViewModel[] values) =>
            values.Where(value => value != null && value.Choices.Count > 0).ToArray();

        private bool HasSelected(
            string group,
            IReadOnlyList<Baseball.Application.Commands.CareerChoiceReadModel> choices)
        {
            string value = _selectedChoice(group);
            return choices != null && choices.Any(option => option.Enabled &&
                string.Equals(option.Payload, value, StringComparison.Ordinal));
        }

        private bool TrainingSelectionReady(HighSchoolCareerReadModel career)
        {
            if (career == null) return false;
            string focus = HasSelected("training_focus", career.TrainingFocusChoices)
                ? _selectedChoice("training_focus")
                : null;
            string intensity = HasSelected("training_intensity", career.TrainingIntensityChoices)
                ? _selectedChoice("training_intensity")
                : null;
            string target = HasSelected("training_pitch", career.TrainingPitchChoices)
                ? _selectedChoice("training_pitch")
                : null;
            return CareerActionSelectionPolicy.TrainingPayload(
                focus,
                intensity,
                target,
                career.TrainingPitchChoices.Count > 0) != null;
        }

        private string TrainingSelectionDisabledReason(HighSchoolCareerReadModel career)
        {
            if (!HasSelected("training_focus", career?.TrainingFocusChoices))
                return "훈련 초점을 먼저 선택하세요.";
            if (!HasSelected("training_intensity", career?.TrainingIntensityChoices))
                return "훈련 강도를 선택하세요.";
            if (string.Equals(_selectedChoice("training_focus"), "breaking_ball", StringComparison.Ordinal) &&
                career.TrainingPitchChoices.Count > 0 &&
                !HasSelected("training_pitch", career.TrainingPitchChoices))
                return "집중할 변화구를 선택하세요.";
            return "현재 저장 상태에서는 이 훈련을 시작할 수 없습니다.";
        }

        private bool ProWeekSelectionReady(ProCareerReadModel career)
        {
            if (career == null) return false;
            string plan = HasSelected("pro_week_plan", career.WeekPlanChoices)
                ? _selectedChoice("pro_week_plan")
                : null;
            string target = HasSelected("pro_development_pitch", career.DevelopmentPitchChoices)
                ? _selectedChoice("pro_development_pitch")
                : null;
            return CareerActionSelectionPolicy.ProWeekPayload(
                plan,
                target,
                career.DevelopmentPitchChoices.Count > 0) != null;
        }

        private string ProWeekSelectionDisabledReason(ProCareerReadModel career)
        {
            if (!HasSelected("pro_week_plan", career?.WeekPlanChoices))
                return "이번 주 계획을 먼저 선택하세요.";
            if (string.Equals(_selectedChoice("pro_week_plan"), "develop_movement", StringComparison.Ordinal) &&
                career.DevelopmentPitchChoices.Count > 0 &&
                !HasSelected("pro_development_pitch", career.DevelopmentPitchChoices))
                return "집중할 결정구를 선택하세요.";
            return "현재 저장 상태에서는 이 주간 계획을 진행할 수 없습니다.";
        }

        private bool HasSelectedPledge(RunPledgeCatalogReadModel catalog)
        {
            if (catalog?.CanChoose != true) return false;
            string selected = _selectedChoice("run_pledge");
            return catalog.Choices.Any(option => string.Equals(
                option.Payload,
                selected,
                StringComparison.Ordinal));
        }

        private bool LegacySelectionReady(HighSchoolCareerReadModel highSchool)
        {
            if (highSchool == null || highSchool.Phase != HighSchoolPhase.Legacy) return false;
            if (highSchool.LegacySelectionMode == LegacySelectionMode.SignatureLegacy)
            {
                string selected = _selectedChoice("legacy_signature");
                return highSchool.SignatureLegacyChoices.Any(option => option.Enabled && option.Payload == selected);
            }
            IReadOnlyList<string> selectedMemories = _selectedChoices("legacy_memories");
            return selectedMemories.Count == highSchool.MemorySlots &&
                selectedMemories.All(value => highSchool.LegacyMemoryChoices.Any(option =>
                    option.Enabled && option.Payload == value));
        }
    }
}
