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

        private IReadOnlyList<ScreenActionViewModel> ProjectActions(
            ShellRoute route,
            IReadOnlyList<ScreenActionViewModel> template,
            GameSaveAggregate state)
        {
            if (state.PendingPitchCompletion != null)
            {
                return Actions(Command(
                    "acknowledge_pitch_result",
                    "저장된 경기 결과 확인",
                    CareerRouteWithoutInterruption(state),
                    "결과 확인을 저장한 뒤 다음 일정으로 이동합니다."));
            }
            switch (route)
            {
                case ShellRoute.Opening:
                    ReturnPlanState welcome = WelcomeReturnPlan(state, _now());
                    if (welcome != null)
                    {
                        ShellRoute returnRoute = RouteForPlanner(
                            welcome.Route,
                            PreferredRouteFor(state));
                        return Actions(
                            Command(
                                "open_return_plan",
                                ReturnPlanRules.ContinueTitle(welcome.Destination),
                                returnRoute,
                                "복귀 안내 확인을 저장한 뒤 해당 일정으로 이동합니다."),
                            Command(
                                "dismiss_return_plan",
                                "복귀 카드 닫기",
                                ShellRoute.Opening,
                                "이 안내를 닫은 상태를 저장합니다.",
                                ScreenActionStyle.Secondary));
                    }
                    return state.Stage == ApplicationStage.Opening
                        ? Actions(Command("enter_setup", "새 인생 시작", ShellRoute.Setup, "저장한 뒤 선수 만들기로 이동합니다."))
                        : Actions(Navigate("continue", "이어하기", PreferredRouteFor(state)));
                case ShellRoute.Setup:
                    HighSchoolSetupReadModel setup = HighSchoolSetupCatalog.For(state.Meta);
                    bool validSeedInput = _setupSeedInputValid();
                    string startHint = validSeedInput
                        ? "선수 정보와 계승 선택을 저장하고 시작합니다."
                        : SetupSeedInputPolicy.InvalidMessage;
                    if (setup.CanQuickRebirth)
                    {
                        var setupActions = new List<ScreenActionViewModel>
                        {
                            Command("quick_rebirth", "지난 설정으로 빠른 환생", ShellRoute.Prologue, "마지막 이름·지역·유형·난이도·카르마로 즉시 시작합니다."),
                            Command("start_high_school", "선택한 설정으로 시작", ShellRoute.Prologue, startHint,
                                enabled: validSeedInput),
                        };
                        if (HasCompletedLife(state))
                            setupActions.Add(Navigate(
                                "navigate_direct_pro_entry",
                                "프로부터 시작하는 길",
                                ShellRoute.ProContract,
                                "프로 화면에서 건너뛰기 조건과 선수 설정을 확인합니다."));
                        return setupActions;
                    }
                    var firstSetupActions = new List<ScreenActionViewModel>
                    {
                        Command(
                            "start_high_school",
                            "고교 커리어 시작",
                            ShellRoute.Prologue,
                            validSeedInput
                                ? "선수 정보를 저장하고 시작합니다."
                                : SetupSeedInputPolicy.InvalidMessage,
                            enabled: validSeedInput)
                    };
                    if (HasCompletedLife(state))
                        firstSetupActions.Add(Navigate(
                            "navigate_direct_pro_entry",
                            "프로부터 시작하는 길",
                            ShellRoute.ProContract,
                            "프로 화면에서 건너뛰기 조건과 선수 설정을 확인합니다."));
                    return firstSetupActions;
                case ShellRoute.Prologue:
                    if (state.HighSchool?.Phase == HighSchoolPhase.Prologue)
                    {
                        return Actions(
                            Command(
                                "begin_tutorial_pitch",
                                "첫 공을 던진다",
                                ShellRoute.PitchHandoff,
                                state.HighSchool.TutorialCompleted
                                    ? "첫 불펜을 다시 던집니다. 연습 결과는 성장 기록에 반영되지 않습니다."
                                    : "저장형 첫 불펜을 시작합니다. 결과는 성장 기록에 반영되지 않습니다."),
                            Command(
                                "skip_tutorial",
                                "바로 학교 고르기",
                                ShellRoute.Prologue,
                                "투구 연습 없이 학교 후보 선택으로 이동합니다.",
                                ScreenActionStyle.Secondary));
                    }
                    if (state.HighSchool?.Phase == HighSchoolPhase.SchoolSelection)
                    {
                        RunPledgeCatalogReadModel pledge = RunPledgeRules.Project(state);
                        if (pledge.CanChoose)
                        {
                            return Actions(
                                Command(
                                    "choose_pledge",
                                    "선택한 목표로 시작",
                                    ShellRoute.Prologue,
                                    "고교 3년 목표를 저장합니다.",
                                    enabled: HasSelectedPledge(pledge)),
                                Command(
                                    "skip_pledge",
                                    "목표 없이 시작",
                                    ShellRoute.Prologue,
                                    "목표를 건너뛴 상태를 저장합니다.",
                                    ScreenActionStyle.Secondary));
                        }
                        return Actions(Command(
                            "choose_school", "학교 선택 확정", ShellRoute.Training,
                            "가상 학교를 선택하고 저장합니다.",
                            confirm: true,
                            enabled: HasSelected("school", state.HighSchool.SchoolChoices)));
                    }
                    break;
                case ShellRoute.PitchHandoff:
                    if (state.PitchResume?.AwaitingCompletion == true)
                    {
                        return Actions(
                            Navigate(
                                "navigate_retry_pitch_completion",
                                "저장된 결과 다시 완료",
                                ShellRoute.PitchHandoff,
                                "마지막 타자까지 저장된 경기 결과를 다시 완료합니다."),
                            Navigate(
                                "navigate_leave_saved_pitch",
                                "나중에 다시 시도",
                                CareerRouteWithoutInterruption(state),
                                "투구 결과를 지우지 않고 현재 커리어 화면으로 돌아갑니다."));
                    }
                    break;
                case ShellRoute.Training:
                    bool trainingReady = TrainingSelectionReady(state.HighSchool);
                    string trainingHint = trainingReady
                        ? "선택한 초점·강도·구종으로 한 번 훈련하고 저장합니다."
                        : TrainingSelectionDisabledReason(state.HighSchool);
                    return Actions(
                        Command(
                            "train", "한 번 훈련", ShellRoute.Training,
                            trainingHint,
                            enabled: trainingReady),
                        Command(
                            "train_block",
                            "최대 " + Math.Max(2, state.HighSchool?.MaximumTrainingBlockSessions ?? 3) + "회 연속 훈련",
                            ShellRoute.Training,
                            trainingReady
                                ? "관계·각성·공식 경기·피로·팔 상태 변화가 생기면 즉시 멈추고 회차별 결과를 저장합니다."
                                : trainingHint,
                            ScreenActionStyle.Secondary,
                            enabled: trainingReady));
                case ShellRoute.Relationship:
                    return Actions(Command(
                        "relationship", "대화 선택 확정", ShellRoute.ImportantGame,
                        "응답을 하나 선택해야 합니다.",
                        enabled: HasSelected("relationship", state.HighSchool?.RelationshipChoices)));
                case ShellRoute.ImportantGame:
                    if (state.HighSchool?.Phase == HighSchoolPhase.ImportantGame || state.Pro?.Phase == ProCareerPhase.ImportantGame)
                        return Actions(Command("begin_pitch", "마운드에 오른다", ShellRoute.PitchHandoff, "경기 시드 예약을 저장한 뒤 투구합니다."));
                    break;
                case ShellRoute.Awakening:
                    return Actions(Command(
                        "awakening", "각성 선택 확정", ShellRoute.HighSchoolOverview,
                        "사용 가능한 각성을 하나 선택해야 합니다.",
                        enabled: HasSelected("awakening", state.HighSchool?.AwakeningChoices)));
                case ShellRoute.HighSchoolOverview:
                    var overviewActions = new List<ScreenActionViewModel>();
                    if (state.HighSchool?.Phase == HighSchoolPhase.ChapterReview)
                        overviewActions.Add(Command("advance_chapter", "다음 장으로", HighSchoolRoute(state.HighSchool)));
                    else
                        overviewActions.Add(Navigate("navigate_next_high_school", "현재 일정으로", HighSchoolRoute(state.HighSchool)));
                    if (ShouldShowReminderNudge(route, state))
                    {
                        overviewActions.Add(Command(
                            "enable_reminder_nudge",
                            "알림 켜기",
                            ShellRoute.HighSchoolOverview,
                            "Android 알림 권한 결과를 확인한 뒤 설정을 저장합니다.",
                            ScreenActionStyle.Secondary));
                        overviewActions.Add(Command(
                            "dismiss_reminder_nudge",
                            "괜찮습니다",
                            ShellRoute.HighSchoolOverview,
                            "이 권유를 다시 표시하지 않습니다.",
                            ScreenActionStyle.Secondary));
                    }
                    if (HasCompletedLife(state) && state.Pro == null)
                    {
                        overviewActions.Add(Navigate(
                            "navigate_direct_pro_entry",
                            "프로부터 시작하는 길",
                            ShellRoute.ProContract,
                            "진행 중인 고교 선수는 보존됩니다. 프로 은퇴 뒤 이 일정으로 돌아옵니다."));
                    }
                    return overviewActions;
                case ShellRoute.Draft:
                    if (state.HighSchool?.Draft?.Resolved != true)
                        return Actions(Command("resolve_draft", "드래프트 결과 확인", ShellRoute.Draft));
                    if (state.HighSchool.Draft.Drafted)
                        return Actions(Command("enter_pro", "계속 · 프로 계약으로", ShellRoute.ProContract));
                    return Actions(Command("open_legacy", "이번 삶 정리", ShellRoute.RunRecap));
                case ShellRoute.RunRecap:
                    if (state.HighSchool?.IsChallengeRun == true)
                        return Actions(Command("end_challenge", "도전을 닫는다", ShellRoute.Opening, "도전 결과는 기록·계승에 반영되지 않습니다.", ScreenActionStyle.Secondary, true));
                    if ((state.Stage == ApplicationStage.Legacy || state.Stage == ApplicationStage.Retirement) &&
                        HasCurrentLifeArchive(state))
                    {
                        NextRunIntentState suggestion = RunPledgeRules.SuggestedNextRunIntent(state.HighSchool);
                        bool saved = suggestion != null && string.Equals(
                            state.Meta.NextRunIntent?.PledgeId,
                            suggestion.PledgeId,
                            StringComparison.Ordinal);
                        var actions = new List<ScreenActionViewModel>();
                        if (suggestion != null)
                            actions.Add(Command(
                                "save_next_run_intent",
                                saved ? "새 선수 목표로 저장됨" : "새 선수 목표로 저장",
                                ShellRoute.RunRecap,
                                saved ? "이미 저장한 목표입니다." : suggestion.Reason,
                                ScreenActionStyle.Secondary,
                                false,
                                !saved));
                        LifeArchiveRecord completedLife = state.Meta.LifeArchive
                            .OrderByDescending(record => record.LifeNumber)
                            .First();
                        bool canQuickStart = state.Meta.LastHighSchoolSetup != null;
                        actions.Add(Command(
                            "quick_rebirth_from_recap",
                            (completedLife.LifeNumber + 1) + "번째 선수 바로 시작",
                            ShellRoute.Prologue,
                            canQuickStart
                                ? "지난 선수의 설정으로 새 인생을 한 번에 저장하고 시작합니다."
                                : "이전 버전 기록에는 빠른 시작 설정이 없어 설정을 다시 골라야 합니다.",
                            enabled: canQuickStart));
                        actions.Add(Command(
                            "begin_rebirth",
                            "설정을 바꿔서 시작",
                            ShellRoute.Setup,
                            "지역·투수 유형·계승 항목을 다시 고릅니다.",
                            ScreenActionStyle.Secondary));
                        actions.Add(Navigate("life_card", "라이프 카드", ShellRoute.LifeCard));
                        return actions;
                    }
                    if (state.HighSchool?.Phase == HighSchoolPhase.Completed && state.Pro == null)
                    {
                        if (state.HighSchool.Draft?.Drafted == true)
                        {
                            return Actions(
                                Command(
                                    "enter_pro",
                                    "프로 커리어 시작",
                                    ShellRoute.ProContract,
                                    "드래프트 지명을 받아 가상 구단의 계약 제안을 확인합니다."),
                                Command(
                                    "decline_pro",
                                    "프로 진출 포기",
                                    ShellRoute.RunRecap,
                                    "프로 진출을 포기하고 이번 삶의 대표 유산을 고릅니다.",
                                    ScreenActionStyle.Destructive,
                                    true));
                        }
                        return Actions(Command(
                            "open_legacy",
                            "이번 삶 정리",
                            ShellRoute.RunRecap,
                            "이번 삶의 기록과 유산 선택으로 이동합니다."));
                    }
                    if (state.HighSchool?.Phase == HighSchoolPhase.Legacy)
                    {
                        bool legacyReady = LegacySelectionReady(state.HighSchool);
                        return Actions(Command(
                            "finalize_high_school_legacy",
                            "선택한 유산으로 이번 삶 기록",
                            ShellRoute.RunRecap,
                            legacyReady
                                ? "선택한 유산과 인생 기록을 한 번에 저장합니다."
                                : "제시된 유산을 필요한 수만큼 선택해야 합니다.",
                            enabled: legacyReady));
                    }
                    break;
                case ShellRoute.ProContract:
                    if (state.Pro?.Phase == ProCareerPhase.ContractOffer && state.Pro.ContractOffer != null)
                        return Actions(Command("sign_pro_contract", "계약 확정", ShellRoute.ProWeek,
                            "가상 구단의 계약 조건을 저장하고 프로 커리어를 시작합니다."));
                    if (state.HighSchool?.Draft?.Drafted == true && state.Pro == null)
                        return Actions(Command("enter_pro", "계약 제안 확인", ShellRoute.ProContract));
                    if (state.Pro == null && HasCompletedLife(state))
                        return Actions(Command(
                            "start_direct_pro",
                            "고교를 건너뛰고 바로 프로 시작",
                            ShellRoute.ProWeek,
                            state.HighSchool == null
                                ? "선택한 이름과 투수 유형으로 가상 프로 커리어를 시작합니다."
                                : "진행 중인 고교 선수는 그대로 보존하고 별도의 가상 프로 커리어를 시작합니다."));
                    break;
                case ShellRoute.ProWeek:
                    if (state.Pro?.Phase == ProCareerPhase.WeeklyPlan)
                    {
                        bool weekReady = ProWeekSelectionReady(state.Pro);
                        string weekHint = weekReady
                            ? "선택한 계획을 한 주 적용하고 저장합니다."
                            : ProWeekSelectionDisabledReason(state.Pro);
                        return Actions(Command(
                            "advance_pro_week", "1주 진행", ShellRoute.ProWeek,
                            weekHint,
                            enabled: weekReady),
                            Command(
                                "advance_pro_segment",
                                (state.Pro.SeasonSegmentTitle ?? "현재 구간") + " 끝까지 진행",
                                ShellRoute.ProWeek,
                                weekReady
                                    ? "승부처 경기·역할 변화·승격·부상이 생기면 그 자리에서 멈추고 저장합니다."
                                    : weekHint,
                                ScreenActionStyle.Secondary,
                                enabled: weekReady),
                            Navigate("league", "리그 보기", ShellRoute.League));
                    }
                    if (state.Pro?.Phase == ProCareerPhase.ImportantGame)
                        return Actions(Command("begin_pitch", "직접 등판", ShellRoute.PitchHandoff));
                    break;
                case ShellRoute.ProSeason:
                    if (state.Pro?.Phase == ProCareerPhase.SeasonDecision)
                        return Actions(Command(
                            "resolve_pro_decision", "시즌 선택 확정", ShellRoute.ProSeason,
                            "선택 결과를 저장한 뒤 시즌을 이어갑니다.",
                            enabled: HasSelected("pro_season_decision", state.Pro.SeasonDecision?.Choices)));
                    if (state.Pro?.Phase == ProCareerPhase.SeasonReview)
                        return Actions(Command("review_season", "시즌 결산", ShellRoute.ProRetirement));
                    break;
                case ShellRoute.ProRetirement:
                    if (state.Pro?.Phase == ProCareerPhase.Offseason || state.Pro?.Phase == ProCareerPhase.RetirementDecision)
                        return Actions(Command(
                            "continue_pro_career", "오프시즌 선택 확정", ShellRoute.ProWeek,
                            "선택을 저장한 뒤 다음 시즌 또는 은퇴 단계로 이동합니다.",
                            enabled: HasSelected("pro_offseason", state.Pro.OffseasonChoices)));
                    if (state.Pro?.Phase == ProCareerPhase.Completed)
                        return Actions(Command("retire_pro", "은퇴 확정", ShellRoute.RunRecap, "프로 기록을 유산에 저장합니다.", ScreenActionStyle.Destructive, true));
                    break;
                case ShellRoute.Records:
                    return Actions(
                        Navigate(
                            "navigate_weekly",
                            "주간 야구 노트",
                            ShellRoute.Weekly,
                            "이번 주 세 가지 과제와 도장 보상을 확인합니다."),
                        Navigate("navigate_league", "리그 순위", ShellRoute.League),
                        Navigate("navigate_achievements", "업적", ShellRoute.Achievements),
                        Navigate("navigate_archive", "인생 보관함", ShellRoute.LifeArchive));
                case ShellRoute.Weekly:
                    bool rewardReady = state.Meta.Weekly.Program?.RewardReady == true;
                    return Actions(
                        Command("claim_weekly", "주간 보상 받기", ShellRoute.Weekly, rewardReady ? "보상을 저장합니다." : "목표 2개를 완료하면 받을 수 있습니다.", ScreenActionStyle.Secondary, false, rewardReady));
                case ShellRoute.LifeCard:
                    return Actions(Command("share_life_card", "라이프 카드 공유", ShellRoute.LifeCard, "Android 공유 화면을 엽니다.", ScreenActionStyle.Secondary), Navigate("archive", "기록 보관함", ShellRoute.LifeArchive));
                case ShellRoute.Achievements:
                    ScreenActionViewModel[] acknowledgement = state.Meta.Achievements.Unacknowledged
                        .Select(id => Command(
                            "ack_achievement:" + id,
                            "확인 · " + AchievementTitle(id),
                            ShellRoute.Achievements,
                            "새 업적 표시를 확인 처리해 저장합니다.",
                            ScreenActionStyle.Secondary))
                        .ToArray();
                    return acknowledgement.Length > 0
                        ? acknowledgement
                        : Actions(Navigate("records", "기록으로 돌아가기", ShellRoute.Records));
                case ShellRoute.Settings:
                    var settingsActions = new List<ScreenActionViewModel>();
                    if (CareerShareCodePolicy.Project(state) != null)
                        settingsActions.Add(Command(
                            "share_career_code",
                            "현재 판 코드 공유",
                            ShellRoute.Settings,
                            "선수 이름이 없는 도전 코드를 Android 공유 화면으로 보냅니다.",
                            ScreenActionStyle.Secondary));
                    settingsActions.Add(Command(
                        "reset_save",
                        "저장 데이터 초기화",
                        ShellRoute.Opening,
                        "모든 진행을 삭제합니다.",
                        ScreenActionStyle.Destructive,
                        true));
                    return settingsActions;
            }

            return template.Select(action => Navigate("navigate_" + action.Id, action.Label, action.Target, action.Hint)).ToArray();
        }

        private static ScreenActionViewModel Command(
            string id,
            string label,
            ShellRoute target,
            string hint = null,
            ScreenActionStyle style = ScreenActionStyle.Primary,
            bool confirm = false,
            bool enabled = true)
        {
            return new ScreenActionViewModel(id, label, target, style, hint, confirm, enabled,
                enabled ? null : hint);
        }

        private static ScreenActionViewModel Navigate(string id, string label, ShellRoute target, string hint = null) =>
            new ScreenActionViewModel(
                id.StartsWith("navigate_", StringComparison.Ordinal) ? id : "navigate_" + id,
                label,
                target,
                ScreenActionStyle.Secondary,
                hint);

        private static IReadOnlyList<ScreenActionViewModel> Actions(params ScreenActionViewModel[] values) => values;
    }
}
