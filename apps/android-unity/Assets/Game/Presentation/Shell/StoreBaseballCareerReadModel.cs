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
    /// <summary>Projects the last durably published aggregate into immutable screen contracts.</summary>
    public sealed partial class StoreBaseballCareerReadModel : IBaseballCareerReadModel
    {
        private readonly BaseballScreenTemplateReadModel _template;
        private readonly Func<GameSaveAggregate> _snapshot;
        private readonly Func<ShellRuntimeStatus> _status;
        private readonly Func<string> _statusMessage;
        private readonly Func<string> _setupPresetId;
        private readonly Func<string, string> _selectedChoice;
        private readonly Func<string, IReadOnlyList<string>> _selectedChoices;
        private readonly Func<bool> _reminderOptInAvailable;
        private readonly Func<DateTimeOffset> _now;
        private readonly Func<bool> _setupSeedInputValid;

        public StoreBaseballCareerReadModel(
            IKoreanUiCopyCatalog copy,
            Func<GameSaveAggregate> snapshot,
            Func<ShellRuntimeStatus> status,
            Func<string> statusMessage,
            Func<string> setupPresetId = null,
            Func<string, string> selectedChoice = null,
            Func<string, IReadOnlyList<string>> selectedChoices = null,
            Func<bool> reminderOptInAvailable = null,
            Func<DateTimeOffset> now = null,
            Func<bool> setupSeedInputValid = null)
        {
            _template = new BaseballScreenTemplateReadModel(copy ?? throw new ArgumentNullException(nameof(copy)));
            _snapshot = snapshot ?? throw new ArgumentNullException(nameof(snapshot));
            _status = status ?? throw new ArgumentNullException(nameof(status));
            _statusMessage = statusMessage ?? throw new ArgumentNullException(nameof(statusMessage));
            _setupPresetId = setupPresetId ?? (() => "power_prospect");
            _selectedChoice = selectedChoice ?? (_ => string.Empty);
            _selectedChoices = selectedChoices ?? (_ => Array.Empty<string>());
            _reminderOptInAvailable = reminderOptInAvailable ?? (() => false);
            _now = now ?? (() => DateTimeOffset.UtcNow);
            _setupSeedInputValid = setupSeedInputValid ?? (() => true);
        }

        public IReadOnlyList<ShellRoute> Routes => _template.Routes;

        public ShellRoute PreferredRoute => PreferredRouteFor(_snapshot());

        public BaseballScreenViewModel Read(ShellRoute route)
        {
            GameSaveAggregate state = _snapshot();
            if (route == ShellRoute.Daily) route = RetiredDailyFallbackFor(state);
            if (_status() != ShellRuntimeStatus.Ready || state == null)
                return RuntimeStatusScreen.Create(route, _status(), _statusMessage());

            BaseballScreenViewModel template = _template.Read(route);
            return new BaseballScreenViewModel(
                route,
                template.Feature,
                ProjectAppBarTitle(route, template, state),
                ProjectEyebrow(route, template, state),
                ProjectTitle(route, template, state),
                ProjectLead(template, state),
                ProjectSections(route, template.Sections, state),
                ProjectActions(route, template.Actions, state),
                template.ShowsBottomNavigation,
                KeyArtAddress(route, state, _setupPresetId()),
                ProjectChoiceGroups(route, state),
                PlayerPortraitAddress(route, state),
                PlayerPortraitLabel(route, state));
        }

        private static string ProjectAppBarTitle(
            ShellRoute route,
            BaseballScreenViewModel template,
            GameSaveAggregate state)
        {
            if (route == ShellRoute.Prologue)
            {
                return state.HighSchool?.Phase == HighSchoolPhase.SchoolSelection
                    ? "학교 선택"
                    : "첫날";
            }
            if (route == ShellRoute.HighSchoolOverview) return "고교 생활";
            return template.AppBarTitle;
        }

        private static string ProjectEyebrow(
            ShellRoute route,
            BaseballScreenViewModel template,
            GameSaveAggregate state)
        {
            if (route == ShellRoute.Prologue)
            {
                return state.HighSchool?.Phase == HighSchoolPhase.SchoolSelection
                    ? "3년을 보낼 학교"
                    : "새 선수의 시작";
            }
            if (route == ShellRoute.HighSchoolOverview && state.HighSchool != null)
            {
                ChapterProgressReadModel chapter = state.HighSchool.ChapterProgress;
                return state.HighSchool.SchoolYear + "학년" +
                    (chapter == null || string.IsNullOrWhiteSpace(chapter.Season)
                        ? " · " + state.HighSchool.ChapterNumber + "장"
                        : " · " + chapter.Season);
            }
            return template.Eyebrow;
        }

        private string ProjectTitle(
            ShellRoute route,
            BaseballScreenViewModel template,
            GameSaveAggregate state)
        {
            if (route == ShellRoute.Prologue && state.HighSchool != null)
            {
                return state.HighSchool.Phase == HighSchoolPhase.SchoolSelection
                    ? "어느 학교에서 3년을 보낼까요?"
                    : state.HighSchool.LifeNumber <= 1
                        ? "첫 번째 야구 인생"
                        : state.HighSchool.LifeNumber + "번째 선수의 첫날";
            }
            if (route == ShellRoute.HighSchoolOverview && state.HighSchool != null)
            {
                string school = string.IsNullOrWhiteSpace(state.HighSchool.SchoolName)
                    ? "고교 야구"
                    : state.HighSchool.SchoolName;
                string chapter = state.HighSchool.ChapterProgress?.Title;
                return string.IsNullOrWhiteSpace(chapter) ? school : school + " · " + chapter;
            }
            LifeArchiveRecord selectedLife = route == ShellRoute.LifeCard
                ? SelectedLifeRecord(state)
                : route == ShellRoute.RunRecap
                    ? CurrentLifeArchiveFor(state)
                    : null;
            if (route == ShellRoute.LifeCard && selectedLife != null)
                return selectedLife.LifeNumber + "번째 선수의 기록 · " + selectedLife.PlayerName;
            if (route == ShellRoute.RunRecap && selectedLife != null)
                return selectedLife.LifeNumber + "번째 선수 · 3년 돌아보기";
            string player = route == ShellRoute.LifeCard
                ? selectedLife?.PlayerName
                : state.Pro?.PlayerName ?? state.HighSchool?.PlayerName;
            return string.IsNullOrWhiteSpace(player) ? template.Title : template.Title + " · " + player;
        }

        private static string ProjectLead(BaseballScreenViewModel template, GameSaveAggregate state)
        {
            if (state.PendingPitchCompletion != null) return "저장된 경기 결과를 확인한 뒤 다음 일정으로 이동합니다.";
            if (state.PitchResume != null) return "마지막으로 저장된 타자 경계부터 이어 던집니다.";
            if (state.HighSchool?.Phase == HighSchoolPhase.Prologue)
                return "첫 불펜으로 손끝을 확인하거나, 바로 학교를 고를 수 있습니다.";
            if (state.HighSchool?.Phase == HighSchoolPhase.SchoolSelection)
                return "강점과 감수할 점, 3년을 함께할 감독과 포수를 비교하세요.";
            if (state.HighSchool != null && template.Route == ShellRoute.HighSchoolOverview &&
                state.HighSchool.ChapterProgress != null)
                return state.HighSchool.ChapterProgress.Goal;
            return template.Lead;
        }

        private IReadOnlyList<ScreenSectionViewModel> ProjectSections(
            ShellRoute route,
            IReadOnlyList<ScreenSectionViewModel> sections,
            GameSaveAggregate state)
        {
            var projected = sections.Select(section => new ScreenSectionViewModel(
                    section.Id,
                    section.Heading,
                    section.Tone,
                    section.Rows
                        .Select(row => ProjectRow(route, row, state))
                        .Where(row => row != null)
                        .ToArray()))
                .Where(section => section.Rows.Count > 0)
                .ToList();

            if (route == ShellRoute.HighSchoolOverview && state.HighSchool != null)
                projected.RemoveAll(section => string.Equals(section.Id, "status", StringComparison.Ordinal));

            if (state.PendingPitchCompletion?.Report != null)
            {
                PitchGameReport report = state.PendingPitchCompletion.Report;
                PitchPostgameContent postgame = PitchPostgameProjection.Project(
                    report,
                    state.PendingPitchCompletion.PitchLog,
                    state.Meta.PitchReleaseMastery);
                var postgameRows = new List<ScreenRowViewModel>
                {
                    new ScreenRowViewModel(
                        "pending-pitch-line",
                        "승부 기록",
                        postgame.Summary,
                        postgame.Analysis),
                    new ScreenRowViewModel(
                        "pending-pitch-growth",
                        "성장과 릴리스",
                        postgame.Growth,
                        "저장된 Core 경기 보고서와 공별 증거를 사용합니다.")
                };
                if (postgame.Pitches.Count == 0)
                {
                    postgameRows.Add(new ScreenRowViewModel(
                        "pending-pitch-log-unavailable",
                        "전체 투구 로그",
                        "공별 기록 없음",
                        "이전 저장 형식의 경기에는 공별 위치·구속 기록이 없을 수 있습니다."));
                }
                else
                {
                    for (int index = 0; index < postgame.Pitches.Count; index++)
                    {
                        PitchPostgameLine pitch = postgame.Pitches[index];
                        postgameRows.Add(new ScreenRowViewModel(
                            "pending-pitch-log-" + (index + 1),
                            "투구 " + (index + 1),
                            pitch.Title,
                            pitch.Detail));
                    }
                }
                projected.Insert(0, new ScreenSectionViewModel(
                    "pending-pitch-result",
                    state.PendingPitchCompletion.CareerKind == PitchCareerKind.Tutorial
                        ? "첫 불펜 결과"
                        : "저장된 경기 결과",
                    ScreenSectionTone.Milestone,
                    postgameRows));
            }

            if (route == ShellRoute.PitchHandoff && state.PitchResume != null)
            {
                PitchResumeState resume = state.PitchResume;
                projected.Insert(0, new ScreenSectionViewModel(
                    "saved-pitch-session",
                    resume.CareerKind == PitchCareerKind.Tutorial ? "저장된 첫 불펜" : "저장된 등판",
                    resume.CommittedPitch != null ? ScreenSectionTone.Milestone : ScreenSectionTone.Information,
                    new[]
                    {
                        new ScreenRowViewModel(
                            "saved-pitch-progress",
                            "타자 진행",
                            Math.Min(resume.CompletedBatters, resume.MaximumBatters) + "/" + resume.MaximumBatters,
                            resume.AwaitingCompletion
                                ? "마지막 결과를 확인할 준비가 끝났습니다."
                                : resume.CommittedPitch != null
                                    ? "저장된 한 구의 결과를 짧게 다시 보여 줍니다."
                                    : "마지막으로 저장된 타자 경계부터 이어 던집니다."),
                        new ScreenRowViewModel(
                            "saved-pitch-report",
                            "현재 경기 기록",
                            resume.AccumulatedReport == null
                                ? "아직 끝난 타자가 없습니다."
                                : resume.AccumulatedReport.Pitches + "구 · " +
                                  resume.AccumulatedReport.Outs + "아웃 · " +
                                  resume.AccumulatedReport.RunsAllowed + "실점")
                    }));
            }

            AddHighSchoolNarrative(projected, route, state.HighSchool);
            AddPlayerHeartline(projected, route, state.HighSchool);
            AddRunPledge(projected, route, state);
            AddNextRunIntent(projected, route, state);
            AddProDevelopment(projected, route, state.Pro);

            switch (route)
            {
                case ShellRoute.Opening:
                    NextActionReadModel next = CurrentStateNextAction(state);
                    projected.Insert(0, new ScreenSectionViewModel(
                        "next-action",
                        "이어갈 일정",
                        next.ResumesInterruption ? ScreenSectionTone.Warning : ScreenSectionTone.Information,
                        new[] { new ScreenRowViewModel("next-action-detail", next.Title, next.Action) }));
                    ReturnPlanState welcome = WelcomeReturnPlan(state, _now());
                    if (welcome != null)
                    {
                        projected.Insert(0, new ScreenSectionViewModel(
                            "return-plan",
                            welcome.Title,
                            ScreenSectionTone.Milestone,
                            new[]
                            {
                                new ScreenRowViewModel(
                                    "return-plan-promise",
                                    "다시 이어갈 한 가지",
                                    welcome.Body,
                                    ReturnPlanRules.ContinueTitle(welcome.Destination))
                            }));
                    }
                    break;
                case ShellRoute.HighSchoolOverview:
                    AddHighSchoolCompetition(projected, state.HighSchool);
                    if (ShouldShowReminderNudge(route, state))
                    {
                        projected.Insert(0, new ScreenSectionViewModel(
                            "reminder-opt-in",
                            "내일도 이어 던지기",
                            ScreenSectionTone.Milestone,
                            new[]
                            {
                                new ScreenRowViewModel(
                                    "reminder-opt-in-copy",
                                    "매일 저녁 7시 30분",
                                    "지금 키우는 선수의 다음 목표를 이어 할 수 있도록 알려 드립니다.",
                                    "며칠 동안 열지 않으면 알림은 저절로 멈춥니다.")
                            }));
                    }
                    break;
                case ShellRoute.ProContract:
                    projected = ProContractSections(state).ToList();
                    break;
                case ShellRoute.ProSeason:
                    projected = ProSeasonSections(state.Pro).ToList();
                    break;
                case ShellRoute.RunRecap:
                    LifeArchiveRecord recap = CurrentLifeArchiveFor(state);
                    if (recap != null) projected = RunRecapSections(state, recap).ToList();
                    break;
                case ShellRoute.Records:
                    projected = RecordSections(state).ToList();
                    break;
                case ShellRoute.League:
                    projected = LeagueSections(state).ToList();
                    break;
                case ShellRoute.Achievements:
                    projected = AchievementSections(state.Meta.Achievements).ToList();
                    break;
                case ShellRoute.LifeArchive:
                    projected = ArchiveSections(state.Meta.LifeArchive).ToList();
                    break;
                case ShellRoute.LifeCard:
                    projected = LifeCardSections(SelectedLifeRecord(state)).ToList();
                    break;
                case ShellRoute.Weekly:
                    projected = WeeklySections(state.Meta.Weekly).ToList();
                    break;
                case ShellRoute.Settings:
                    projected = SettingsSections(state).ToList();
                    break;
            }
            AddLatestPlayerLegacy(projected, route, state);
            return projected;
        }

        public bool ShouldShowReminderNudge(ShellRoute route, GameSaveAggregate state)
        {
            return route == ShellRoute.HighSchoolOverview &&
                state?.HighSchool?.IsChallengeRun != true &&
                (state?.HighSchool?.Performance?.ImportantGames ?? 0) >= 1 &&
                state?.Settings?.NotificationsEnabled != true &&
                _reminderOptInAvailable();
        }

        private static string KeyArtAddress(ShellRoute route, GameSaveAggregate state, string setupPresetId)
        {
            HighSchoolCareerReadModel highSchool = state?.HighSchool;
            ProCareerReadModel pro = state?.Pro;
            if (route == ShellRoute.ProContract && pro == null)
                return "baseball/pro/KeyArtMajorDebut";
            if (pro != null && (state.Stage == ApplicationStage.Pro ||
                                route == ShellRoute.ProContract ||
                                route == ShellRoute.ProWeek || route == ShellRoute.ProSeason ||
                                route == ShellRoute.ProRetirement))
            {
                if (pro.Phase == ProCareerPhase.Completed)
                    return "baseball/pro/KeyArtRetirement";
                bool major = string.Equals(pro.Level, "major", StringComparison.Ordinal);
                if (route == ShellRoute.ImportantGame && major)
                    return "baseball/pro/KeyArtProStadiumTunnel";
                return major
                    ? "baseball/pro/KeyArtMajorDebut"
                    : "baseball/highschool/KeyArtStadiumNight";
            }

            if (highSchool != null)
            {
                switch (highSchool.Phase)
                {
                    case HighSchoolPhase.Prologue:
                        return "baseball/highschool/KeyArtCareerIntro";
                    case HighSchoolPhase.SchoolSelection:
                        return "baseball/highschool/KeyArtSchoolCrossroads";
                    case HighSchoolPhase.Awakening:
                        return "baseball/highschool/KeyArtAwakening";
                    case HighSchoolPhase.Draft:
                        return "baseball/highschool/KeyArtDraftDay";
                    case HighSchoolPhase.Legacy:
                    case HighSchoolPhase.Completed:
                        return "baseball/highschool/KeyArtReincarnation";
                    default:
                        return "baseball/highschool/KeyArtStadiumNight";
                }
            }

            switch (route)
            {
                case ShellRoute.Opening: return "baseball/bootstrap/LaunchLogo";
                // Setup owns step-specific artwork inside its content, matching the iOS flow.
                // A route-level hero would show the preset before the player reaches that step.
                case ShellRoute.Setup: return string.Empty;
                case ShellRoute.Prologue: return "baseball/highschool/KeyArtCareerIntro";
                case ShellRoute.HighSchoolOverview:
                case ShellRoute.Training:
                case ShellRoute.Relationship:
                case ShellRoute.ImportantGame: return "baseball/highschool/KeyArtStadiumNight";
                case ShellRoute.Awakening: return "baseball/highschool/KeyArtAwakening";
                case ShellRoute.Draft: return "baseball/highschool/KeyArtDraftDay";
                case ShellRoute.ProContract: return "baseball/pro/KeyArtMajorDebut";
                case ShellRoute.ProWeek:
                case ShellRoute.ProSeason: return "baseball/highschool/KeyArtStadiumNight";
                case ShellRoute.ProRetirement: return "baseball/pro/KeyArtRetirement";
                case ShellRoute.RunRecap: return "baseball/highschool/KeyArtReincarnation";
                case ShellRoute.LifeCard: return "baseball/meta/LifeCardBackdrop";
                default: return string.Empty;
            }
        }

        private string PlayerPortraitAddress(ShellRoute route, GameSaveAggregate state)
        {
            LifeArchiveRecord archived = route == ShellRoute.LifeCard || route == ShellRoute.LifeArchive
                ? SelectedLifeRecord(state)
                : route == ShellRoute.RunRecap
                    ? CurrentLifeArchiveFor(state)
                    : null;
            if (archived != null)
            {
                return BaseballVisualContentCatalog.PlayerPortrait(
                    archived.PlayerName,
                    archived.Drafted ? PlayerPortraitStage.Pro : PlayerPortraitStage.Ace);
            }

            bool proSurface = state?.Pro != null &&
                (route == ShellRoute.ProContract || route == ShellRoute.ProWeek ||
                 route == ShellRoute.ProSeason || route == ShellRoute.ProRetirement ||
                 route == ShellRoute.ImportantGame || route == ShellRoute.Records);
            if (proSurface)
                return BaseballVisualContentCatalog.PlayerPortrait(
                    state.Pro.PlayerName,
                    PlayerPortraitStage.Pro);

            HighSchoolCareerReadModel highSchool = state?.HighSchool;
            if (highSchool == null) return string.Empty;
            bool highSchoolSurface = route == ShellRoute.Prologue ||
                route == ShellRoute.HighSchoolOverview || route == ShellRoute.Training ||
                route == ShellRoute.Relationship || route == ShellRoute.ImportantGame ||
                route == ShellRoute.Awakening || route == ShellRoute.Draft ||
                route == ShellRoute.RunRecap || route == ShellRoute.Records;
            if (!highSchoolSurface) return string.Empty;
            return BaseballVisualContentCatalog.PlayerPortrait(
                highSchool.PlayerName,
                highSchool.ChapterNumber <= 3
                    ? PlayerPortraitStage.Young
                    : PlayerPortraitStage.Ace);
        }

        private string PlayerPortraitLabel(ShellRoute route, GameSaveAggregate state)
        {
            LifeArchiveRecord archived = route == ShellRoute.LifeCard || route == ShellRoute.LifeArchive
                ? SelectedLifeRecord(state)
                : route == ShellRoute.RunRecap
                    ? CurrentLifeArchiveFor(state)
                    : null;
            string name = archived?.PlayerName ?? state?.Pro?.PlayerName ?? state?.HighSchool?.PlayerName;
            return string.IsNullOrWhiteSpace(name) ? string.Empty : name + " 선수 초상";
        }
    }
}
