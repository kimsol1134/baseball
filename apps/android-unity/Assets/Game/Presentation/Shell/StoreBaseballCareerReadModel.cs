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
    public sealed class StoreBaseballCareerReadModel : IBaseballCareerReadModel
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

        public static ShellRoute PreferredRouteFor(GameSaveAggregate state)
        {
            if (state == null) return ShellRoute.Opening;
            if (state.PitchResume != null) return ShellRoute.PitchHandoff;
            if (state.PendingPitchCompletion != null) return CareerRouteWithoutInterruption(state);
            switch (state.Stage)
            {
                case ApplicationStage.Opening: return ShellRoute.Opening;
                case ApplicationStage.Setup:
                case ApplicationStage.BetweenLives: return ShellRoute.Setup;
                case ApplicationStage.HighSchool:
                case ApplicationStage.Draft: return HighSchoolRoute(state.HighSchool);
                case ApplicationStage.Pro: return ProRoute(state.Pro);
                case ApplicationStage.Retirement: return ShellRoute.ProRetirement;
                case ApplicationStage.Legacy: return ShellRoute.RunRecap;
                case ApplicationStage.Deleted: return ShellRoute.Opening;
                default: return ShellRoute.Opening;
            }
        }

        public static ShellRoute RetiredDailyFallbackFor(GameSaveAggregate state)
        {
            if (state?.PendingPitchCompletion != null)
                return CareerRouteWithoutInterruption(state);
            if (state?.Pro != null) return ProRoute(state.Pro);
            if (state?.HighSchool != null) return HighSchoolRoute(state.HighSchool);
            return ShellRoute.Opening;
        }

        private static ShellRoute CareerRouteWithoutInterruption(GameSaveAggregate state)
        {
            if (state.Pro != null) return ProRoute(state.Pro);
            if (state.HighSchool != null) return HighSchoolRoute(state.HighSchool);
            return ShellRoute.Records;
        }

        private static ShellRoute HighSchoolRoute(HighSchoolCareerReadModel career)
        {
            if (career == null) return ShellRoute.Setup;
            switch (career.Phase)
            {
                case HighSchoolPhase.Prologue:
                case HighSchoolPhase.SchoolSelection: return ShellRoute.Prologue;
                case HighSchoolPhase.Training: return ShellRoute.Training;
                case HighSchoolPhase.Relationship: return ShellRoute.Relationship;
                case HighSchoolPhase.ImportantGame: return ShellRoute.ImportantGame;
                case HighSchoolPhase.Awakening: return ShellRoute.Awakening;
                case HighSchoolPhase.Draft: return ShellRoute.Draft;
                case HighSchoolPhase.Legacy:
                case HighSchoolPhase.Completed: return ShellRoute.RunRecap;
                default: return ShellRoute.HighSchoolOverview;
            }
        }

        private static ShellRoute ProRoute(ProCareerReadModel career)
        {
            if (career == null) return ShellRoute.ProContract;
            switch (career.Phase)
            {
                case ProCareerPhase.ContractOffer: return ShellRoute.ProContract;
                case ProCareerPhase.WeeklyPlan: return ShellRoute.ProWeek;
                case ProCareerPhase.ImportantGame: return ShellRoute.ImportantGame;
                case ProCareerPhase.SeasonDecision:
                case ProCareerPhase.SeasonReview: return ShellRoute.ProSeason;
                case ProCareerPhase.Offseason: return ShellRoute.ProRetirement;
                case ProCareerPhase.RetirementDecision: return ShellRoute.ProRetirement;
                case ProCareerPhase.Completed: return ShellRoute.ProRetirement;
                default: return ShellRoute.ProWeek;
            }
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

        private static void AddPlayerHeartline(
            IList<ScreenSectionViewModel> sections,
            ShellRoute route,
            HighSchoolCareerReadModel career)
        {
            PlayerHeartlineViewModel heartline = PlayerHeartlinePresentationPolicy.Project(route, career);
            if (heartline == null) return;
            sections.Insert(0, new ScreenSectionViewModel(
                "hs-player-heartline",
                "선수의 속마음",
                ScreenSectionTone.Milestone,
                new[]
                {
                    new ScreenRowViewModel(
                        "hs-player-heartline-" + heartline.BranchId,
                        heartline.Mood,
                        "“" + heartline.Words + "”")
                }));
        }

        private static void AddLatestPlayerLegacy(
            IList<ScreenSectionViewModel> sections,
            ShellRoute route,
            GameSaveAggregate state)
        {
            IReadOnlyList<LifeArchiveRecord> archive = state?.Meta?.LifeArchive;
            if (archive == null || archive.Count == 0) return;
            LifeArchiveRecord record = route == ShellRoute.RunRecap
                ? CurrentLifeArchiveFor(state)
                : PreviousPlayerLegacyFor(route, state);
            if (record == null) return;
            sections.Insert(0, new ScreenSectionViewModel(
                "player-legacy-letter",
                route == ShellRoute.Prologue ? "이전 선수가 남긴 말" : "선수가 남긴 말",
                ScreenSectionTone.Milestone,
                new[] { PlayerLegacyRow("player-legacy-letter-copy", record) }));
        }

        public static LifeArchiveRecord PreviousPlayerLegacyFor(
            ShellRoute route,
            GameSaveAggregate state)
        {
            if (route != ShellRoute.Prologue || state?.HighSchool == null ||
                state.HighSchool.Phase != HighSchoolPhase.Prologue ||
                state.HighSchool.IsChallengeRun || state.Meta?.LifeArchive == null) return null;
            return state.Meta.LifeArchive
                .Where(value => value != null && value.LifeNumber < state.HighSchool.LifeNumber)
                .OrderByDescending(value => value.LifeNumber)
                .FirstOrDefault();
        }

        private static ScreenRowViewModel PlayerLegacyRow(string id, LifeArchiveRecord record)
        {
            PlayerLegacyState legacy = record.PlayerLegacy;
            if (legacy == null)
            {
                return new ScreenRowViewModel(
                    id,
                    "이전 버전의 선수 기록",
                    "이 회차에는 선수가 남긴 편지가 보관되지 않았습니다.",
                    "경기 기록과 성적은 인생 보관함에서 확인할 수 있습니다.");
            }
            return new ScreenRowViewModel(
                id,
                legacy.Title,
                legacy.DefiningMoment,
                "“" + legacy.Farewell + "”");
        }

        private void AddHighSchoolNarrative(
            IList<ScreenSectionViewModel> sections,
            ShellRoute route,
            HighSchoolCareerReadModel career)
        {
            if (career == null) return;
            bool prologue = route == ShellRoute.Prologue &&
                career.Phase == HighSchoolPhase.Prologue;
            if (prologue || route == ShellRoute.HighSchoolOverview)
            {
                CareerWind wind = CareerWind.For(career.CareerId, CareerRulesVersion.V2);
                sections.Insert(0, new ScreenSectionViewModel(
                    "hs-career-wind",
                    "이번 3년의 바람",
                    ScreenSectionTone.Milestone,
                    new[]
                    {
                        new ScreenRowViewModel(
                            "hs-career-wind-copy",
                            wind.Title,
                            wind.Detail,
                            wind.EffectDescriptions.Count == 0
                                ? "능력과 선택으로 길을 만듭니다."
                                : string.Join(" · ", wind.EffectDescriptions))
                    }));
            }
            if (route == ShellRoute.HighSchoolOverview &&
                career.ChapterProgress != null)
            {
                ChapterProgressReadModel chapter = career.ChapterProgress;
                sections.Insert(0, new ScreenSectionViewModel(
                    "hs-overview-metrics",
                    "지금의 선수",
                    ScreenSectionTone.Plain,
                    new[]
                    {
                        new ScreenRowViewModel(
                            "hs-overview-fatigue",
                            "피로",
                            career.Fatigue.ToString()),
                        new ScreenRowViewModel(
                            "hs-overview-trust",
                            "감독 믿음",
                            career.ManagerTrust.ToString()),
                        new ScreenRowViewModel(
                            "hs-overview-training",
                            "이번 장 훈련",
                            chapter.TrainingsCompleted + "/" + chapter.TrainingsRequired)
                    }));
                sections.Add(new ScreenSectionViewModel(
                    "hs-chapter-progress",
                    chapter.Title,
                    ScreenSectionTone.Information,
                    new[]
                    {
                        new ScreenRowViewModel(
                            "hs-chapter-season",
                            chapter.SchoolYear + "학년 · " + chapter.Season,
                            chapter.Goal,
                            "훈련 " + chapter.TrainingsCompleted + "/" + chapter.TrainingsRequired +
                            " · 일정 " + chapter.MilestoneIndex + "/" + chapter.MilestoneCount),
                        new ScreenRowViewModel(
                            "hs-chapter-result",
                            "최근 장면",
                            string.IsNullOrWhiteSpace(chapter.ResultLine) ? "아직 기록된 결과가 없습니다." : chapter.ResultLine)
                    }));
            }

            if (route == ShellRoute.Relationship && career.CurrentRelationshipEvent != null)
            {
                RelationshipEventReadModel scene = career.CurrentRelationshipEvent;
                sections.Insert(0, new ScreenSectionViewModel(
                    "hs-relationship-scene",
                    scene.Title,
                    ScreenSectionTone.Milestone,
                    new[]
                    {
                        new ScreenRowViewModel(
                            "hs-relationship-category",
                            "장면 유형",
                            scene.Category),
                        new ScreenRowViewModel(
                            "hs-relationship-speaker",
                            string.IsNullOrWhiteSpace(scene.Speaker) ? "상대" : scene.Speaker,
                            string.IsNullOrWhiteSpace(scene.Quote) ? scene.Summary : "“" + scene.Quote + "”",
                            scene.Summary),
                        new ScreenRowViewModel(
                            "hs-relationship-trust",
                            "현재 관계",
                            RelationshipTrustTitle(scene.TrustBand))
                    }));
            }

            if (route == ShellRoute.ImportantGame && career.CurrentGameScenario != null)
            {
                GameScenarioNarrativeReadModel game = career.CurrentGameScenario;
                sections.Insert(0, new ScreenSectionViewModel(
                    "hs-important-game-scenario",
                    game.Title,
                    ScreenSectionTone.Warning,
                    new[]
                    {
                        new ScreenRowViewModel(
                            "hs-important-game-narrative",
                            "마운드 상황",
                            game.Narrative,
                            game.Inning + "회 · " + game.Outs + "아웃 · " + ScoreDifferentialTitle(game.ScoreDifferential)),
                        new ScreenRowViewModel(
                            "hs-important-game-leverage",
                            "승부 압박",
                            LeverageTitle(game.Leverage))
                    }));
            }

            if (route == ShellRoute.Training)
            {
                TrainingOutlookReadModel outlook = HighSchoolTrainingOutlookProjection.Resolve(
                    career,
                    _selectedChoice("training_focus"),
                    _selectedChoice("training_intensity"));
                if (outlook != null)
                {
                    sections.Insert(0, new ScreenSectionViewModel(
                        "hs-training-outlook",
                        "선택한 훈련 전망",
                        ScreenSectionTone.Information,
                        new[]
                        {
                            new ScreenRowViewModel(
                                "hs-training-outlook-value",
                                outlook.Title,
                                outlook.Summary,
                                "선택한 초점과 강도를 현재 능력·피로·재능에 적용한 전망입니다.")
                        }));
                }
            }

            if ((route == ShellRoute.Training || route == ShellRoute.HighSchoolOverview) &&
                career.LastTraining != null && career.LastTrainingBlock == null)
            {
                TrainingResultReadModel training = career.LastTraining;
                sections.Add(new ScreenSectionViewModel(
                    "hs-last-training",
                    "최근 훈련 결과",
                    training.Jackpot ? ScreenSectionTone.Milestone : ScreenSectionTone.Positive,
                    new[]
                    {
                        new ScreenRowViewModel(
                            "hs-last-training-line",
                            TrainingFocusTitle(training.Focus) + " · " + TrainingIntensityTitle(training.Intensity),
                            training.Feedback,
                            "성장 +" + Math.Max(0, training.Growth) + " · 피로 " + Signed(training.FatigueChange)),
                        new ScreenRowViewModel(
                            "hs-last-training-metric",
                            "능력 변화",
                            training.MetricBefore.HasValue && training.MetricAfter.HasValue
                                ? training.MetricBefore + " → " + training.MetricAfter
                                : "수치 변화 없음",
                            training.OpportunityHit ? "오늘의 성장 기회를 살렸습니다." : "기본 훈련 결과입니다.")
                    }.Concat(TrainingBloomRows(
                        "hs-last-training-bloom",
                        training.BloomedAbility,
                        training.BloomedGrade)).ToArray()));
            }

            if ((route == ShellRoute.Training || route == ShellRoute.HighSchoolOverview) &&
                career.LastTrainingBlock != null)
            {
                TrainingBlockResultReadModel block = career.LastTrainingBlock;
                var rows = block.Sessions.Select(session => new ScreenRowViewModel(
                    "hs-training-block-session-" + session.Number,
                    session.Number + "회 · " + TrainingFocusTitle(session.Focus) + " · " +
                        TrainingIntensityTitle(session.Intensity),
                    string.IsNullOrWhiteSpace(session.TargetPitch)
                        ? session.Feedback
                        : PitchTitle(session.TargetPitch) + " · " + session.Feedback,
                    "성장 +" + Math.Max(0, session.Growth) + " · 피로 " + Signed(session.FatigueChange)))
                    .ToList();
                rows.Add(new ScreenRowViewModel(
                    "hs-training-block-stop",
                    "연속 훈련 종료",
                    block.CompletedSessions + "/" + block.MaximumSessions + "회 완료",
                    TrainingBlockStopTitle(block.StopReason) + " · 총 성장 +" + Math.Max(0, block.Growth) +
                    " · 총 피로 " + Signed(block.FatigueChange)));
                rows.AddRange(TrainingBloomRows(
                    "hs-training-block-bloom",
                    block.BloomedAbility,
                    block.BloomedGrade));
                sections.Add(new ScreenSectionViewModel(
                    "hs-last-training-block",
                    "연속 훈련 결과",
                    block.Growth > 0 ? ScreenSectionTone.Positive : ScreenSectionTone.Information,
                    rows));
            }

            if ((route == ShellRoute.Relationship || route == ShellRoute.HighSchoolOverview) &&
                career.LastRelationship != null)
            {
                RelationshipResultReadModel relation = career.LastRelationship;
                sections.Add(new ScreenSectionViewModel(
                    "hs-last-relationship",
                    "최근 관계 결과",
                    relation.TrustAfter >= relation.TrustBefore ? ScreenSectionTone.Positive : ScreenSectionTone.Warning,
                    new[]
                    {
                        new ScreenRowViewModel(
                            "hs-last-relationship-line",
                            relation.Title,
                            relation.Feedback,
                            "믿음 " + relation.TrustBefore + " → " + relation.TrustAfter +
                            " · 피로 " + relation.FatigueBefore + " → " + relation.FatigueAfter),
                        new ScreenRowViewModel(
                            "hs-last-relationship-response",
                            "내 응답",
                            RelationshipResponseTitle(relation.Response),
                            "팬 관심 " + relation.FanInterestBefore + " → " + relation.FanInterestAfter)
                    }));
            }

            if (route == ShellRoute.HighSchoolOverview && career.News.Count > 0)
            {
                sections.Add(new ScreenSectionViewModel(
                    "hs-news",
                    "최근 소식",
                    ScreenSectionTone.Plain,
                    career.News.Take(8).Select((line, index) => new ScreenRowViewModel(
                        "hs-news-" + index,
                        (index + 1) + "번째 소식",
                        line)).ToArray()));
            }
        }

        private static void AddRunPledge(
            IList<ScreenSectionViewModel> sections,
            ShellRoute route,
            GameSaveAggregate state)
        {
            if (route != ShellRoute.HighSchoolOverview && route != ShellRoute.RunRecap) return;
            RunPledgeReadModel pledge = RunPledgeRules.Project(state).Selected;
            if (pledge == null) return;
            sections.Add(new ScreenSectionViewModel(
                "run-pledge",
                route == ShellRoute.RunRecap ? "고교 3년 목표 결과" : "고교 3년 목표",
                pledge.Progress.Achieved ? ScreenSectionTone.Positive : ScreenSectionTone.Milestone,
                new[]
                {
                    new ScreenRowViewModel(
                        "run-pledge-progress",
                        PledgeTierTitle(pledge.Tier) + " · " + pledge.Title,
                        pledge.Progress.Line,
                        "진행 " + pledge.Progress.Current + "/" + pledge.Progress.Target +
                        " · 달성 보너스 야구혼 +" + pledge.RewardPermille / 10 + "%"),
                    new ScreenRowViewModel(
                        "run-pledge-result",
                        route == ShellRoute.RunRecap ? "최종 결과" : "현재 상태",
                        pledge.Progress.Achieved ? "달성" : "도전 중",
                        pledge.AlignmentReason)
                }));
        }

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

        private static string PledgeTierTitle(Baseball.Application.HighSchool.RunPledgeTier tier)
        {
            switch (tier)
            {
                case Baseball.Application.HighSchool.RunPledgeTier.Safe: return "안정 목표";
                case Baseball.Application.HighSchool.RunPledgeTier.Bold: return "도전 목표";
                case Baseball.Application.HighSchool.RunPledgeTier.Legendary: return "전설 목표";
                default: return "고교 목표";
            }
        }

        private static void AddNextRunIntent(
            IList<ScreenSectionViewModel> sections,
            ShellRoute route,
            GameSaveAggregate state)
        {
            if (route != ShellRoute.RunRecap || !HasCurrentLifeArchive(state)) return;
            NextRunIntentState suggestion = RunPledgeRules.SuggestedNextRunIntent(state.HighSchool);
            if (suggestion == null) return;
            bool saved = string.Equals(
                state.Meta.NextRunIntent?.PledgeId,
                suggestion.PledgeId,
                StringComparison.Ordinal);
            sections.Add(new ScreenSectionViewModel(
                "next-run-intent",
                "새 선수로 다시 도전",
                ScreenSectionTone.Milestone,
                new[]
                {
                    new ScreenRowViewModel(
                        "next-run-intent-pledge",
                        string.IsNullOrWhiteSpace(suggestion.PledgeTitle)
                            ? "추천 목표"
                            : suggestion.PledgeTitle,
                        saved ? "새 선수 목표로 저장됨" : "저장 전",
                        suggestion.Reason +
                        (suggestion.PledgeRewardPermille.HasValue
                            ? " · 달성 보너스 야구혼 +" + suggestion.PledgeRewardPermille.Value / 10 + "%"
                            : string.Empty))
                }));
        }

        private static string TrainingFocusTitle(string value)
        {
            switch ((value ?? string.Empty).ToLowerInvariant())
            {
                case "velocity": return "구속";
                case "command": return "제구";
                case "movement":
                case "breaking_ball": return "변화구";
                case "stamina": return "체력";
                case "recovery": return "회복";
                case "game_planning": return "경기 운영";
                default: return "훈련";
            }
        }

        private static IEnumerable<ScreenRowViewModel> TrainingBloomRows(
            string id,
            string ability,
            string grade)
        {
            if (string.IsNullOrWhiteSpace(ability) || string.IsNullOrWhiteSpace(grade))
                return Array.Empty<ScreenRowViewModel>();
            return new[]
            {
                new ScreenRowViewModel(
                    id,
                    "재능이 만개했습니다",
                    TalentAbilityTitle(ability) + " · " + grade.ToUpperInvariant() + "등급",
                    "훈련 결과에 저장된 재능 상한 성장입니다.")
            };
        }

        private static string TalentAbilityTitle(string value)
        {
            switch ((value ?? string.Empty).ToLowerInvariant())
            {
                case "stuff": return "구위";
                case "command": return "제구";
                case "movement": return "변화";
                case "stamina": return "체력";
                default: return "투수 재능";
            }
        }

        private static string TrainingBlockStopTitle(string value)
        {
            switch ((value ?? string.Empty).ToLowerInvariant())
            {
                case "maximum_sessions": return "선택한 최대 횟수를 마쳤습니다.";
                case "relationship": return "관계 일정이 열려 멈췄습니다.";
                case "awakening": return "각성 선택이 열려 멈췄습니다.";
                case "important_game": return "중요 경기가 열려 멈췄습니다.";
                case "talent_bloom": return "재능 성장 신호가 나타나 멈췄습니다.";
                case "fatigue": return "피로가 높아져 안전하게 멈췄습니다.";
                case "arm_health": return "팔 상태가 바뀌어 안전하게 멈췄습니다.";
                default: return "다음 일정이 열려 멈췄습니다.";
            }
        }

        private static string PitchTitle(string value)
        {
            switch ((value ?? string.Empty).ToLowerInvariant())
            {
                case "four_seam":
                case "four-seam":
                case "fourseam": return "포심";
                case "slider": return "슬라이더";
                case "curveball": return "커브";
                case "changeup": return "체인지업";
                default: return "선택 구종";
            }
        }

        private static string TrainingIntensityTitle(string value)
        {
            switch ((value ?? string.Empty).ToLowerInvariant())
            {
                case "light": return "가볍게";
                case "standard": return "표준";
                case "intensive": return "집중";
                default: return "강도 기록";
            }
        }

        private static string RelationshipResponseTitle(string value)
        {
            switch ((value ?? string.Empty).ToLowerInvariant())
            {
                case "listen": return "먼저 듣는다";
                case "explain": return "설명한다";
                case "challenge": return "결과로 답한다";
                default: return "선택한 응답";
            }
        }

        private static string RelationshipTrustTitle(string value)
        {
            switch ((value ?? string.Empty).ToLowerInvariant())
            {
                case "trusted": return "두터운 믿음";
                case "warm": return "가까워지는 중";
                case "strained": return "긴장된 관계";
                default: return "서로 알아가는 중";
            }
        }

        private static string LeverageTitle(int leverage) => leverage >= 850
            ? "한 공이 흐름을 바꾸는 순간"
            : leverage >= 650 ? "중요한 승부처" : "차분히 아웃을 쌓을 상황";

        private static string ScoreDifferentialTitle(int scoreDifferential) => scoreDifferential == 0
            ? "동점"
            : scoreDifferential > 0 ? scoreDifferential + "점 앞섬" : -scoreDifferential + "점 뒤짐";

        private static string Signed(int value) => value > 0 ? "+" + value : value.ToString();

        private static void AddHighSchoolCompetition(
            ICollection<ScreenSectionViewModel> sections,
            HighSchoolCareerReadModel career)
        {
            if (career == null) return;
            if (career.Tournament != null)
            {
                sections.Add(new ScreenSectionViewModel(
                    "hs-tournament",
                    career.Tournament.TournamentName,
                    ScreenSectionTone.Information,
                    new[]
                    {
                        new ScreenRowViewModel(
                            "hs-tournament-chapter",
                            "대회 장",
                            career.ChapterNumber.ToString()),
                        new ScreenRowViewModel("hs-tournament-round", "현재 라운드", career.Tournament.PlayerRound),
                        new ScreenRowViewModel(
                            "hs-tournament-schools",
                            "대진 학교",
                            string.Join(" · ", career.Tournament.Schools))
                    }));
            }
            if (career.ProspectRankings.Count > 0)
            {
                sections.Add(new ScreenSectionViewModel(
                    "hs-prospects",
                    "고교 유망주 순위",
                    ScreenSectionTone.Plain,
                    career.ProspectRankings.Select(entry => new ScreenRowViewModel(
                        "hs-prospect-" + entry.Rank,
                        entry.Rank + "위 · " + entry.Name,
                        entry.School,
                        entry.Tag + (entry.IsPlayer ? " · 내 선수" : string.Empty))).ToArray()));
            }
            if (career.GameLines.Count > 0)
            {
                sections.Add(new ScreenSectionViewModel(
                    "hs-game-lines",
                    "최근 경기",
                    ScreenSectionTone.Plain,
                    career.GameLines.Select((line, index) => GameLineRow("hs", line, index)).ToArray()));
            }
        }

        private static IReadOnlyList<ScreenSectionViewModel> RecordSections(GameSaveAggregate state)
        {
            var result = new List<ScreenSectionViewModel>();
            PitchReleaseMasteryState release = state.Meta?.PitchReleaseMastery;
            if (release != null && release.DirectPitches > 0)
            {
                int nextTarget = release.PersonalBest < 700 ? 700 :
                    release.PersonalBest < 800 ? 800 :
                    release.PersonalBest < 900 ? 900 :
                    release.PersonalBest < 950 ? 950 : 1000;
                result.Add(new ScreenSectionViewModel(
                    "records-release-mastery",
                    "직접 릴리스 숙련도",
                    ScreenSectionTone.Milestone,
                    new[]
                    {
                        new ScreenRowViewModel(
                            "records-release-personal-best",
                            "개인 최고",
                            release.PersonalBest + "점",
                            release.PersonalBest >= 1000
                                ? "최고 단계를 달성했습니다."
                                : "다음 목표 " + nextTarget + "점까지 " +
                                  (nextTarget - release.PersonalBest) + "점"),
                        new ScreenRowViewModel(
                            "records-release-lifetime",
                            "공식 경기 누적",
                            release.OfficialSessions + "경기 · 직접 투구 " +
                            release.DirectPitches + "구 · 평균 " + release.LifetimeAverage + "점",
                            "타이밍 " + release.LifetimeReleaseAverage +
                            " · 조준 " + release.LifetimeAimAverage)
                    }));
            }
            if (state.HighSchool != null)
            {
                CareerPerformanceReadModel performance = state.HighSchool.Performance ??
                    new CareerPerformanceReadModel();
                var rows = new List<ScreenRowViewModel>
                {
                    new ScreenRowViewModel(
                        "records-current-hs-ratings",
                        state.HighSchool.PlayerName + " · 현재 능력",
                        RatingLine(state.HighSchool.Ratings),
                        "팬 관심 " + state.HighSchool.FanInterest + " · 포수와의 호흡 " +
                        state.HighSchool.CatcherTrust + " · 지도자의 믿음 " + state.HighSchool.ManagerTrust),
                };
                bool highSchoolRecordAvailable = state.HighSchool.GameLines.Count > 0 ||
                    performance.ImportantGames == 0 && performance.Outs == 0 && performance.Pitches == 0;
                AddPitchingRecordRows(
                    rows,
                    "records-current-hs",
                    "고교 누적",
                    state.HighSchool.PitchingRecord,
                    highSchoolRecordAvailable,
                    "피로 " + state.HighSchool.Fatigue + " · 팔 위험 " + state.HighSchool.ArmRisk);
                if (state.HighSchool.News.Count > 0)
                    rows.Add(new ScreenRowViewModel(
                        "records-current-hs-news",
                        "최근 소식",
                        string.Join(" · ", state.HighSchool.News.Take(3))));
                HighSchoolLifeDetailReadModel activeDetail = state.HighSchool.LifeDetail;
                if (activeDetail != null &&
                    (!string.IsNullOrWhiteSpace(activeDetail.Personality) ||
                     !string.IsNullOrWhiteSpace(activeDetail.WindTitle)))
                    rows.Add(new ScreenRowViewModel(
                        "records-current-hs-identity",
                        "선수의 기질",
                        string.IsNullOrWhiteSpace(activeDetail.Personality)
                            ? state.HighSchool.PlayerName
                            : activeDetail.Personality,
                        string.IsNullOrWhiteSpace(activeDetail.WindTitle)
                            ? "선택과 경기에서 드러난 현재 모습입니다."
                            : "3년의 바람 · " + activeDetail.WindTitle));
                if (state.HighSchool.Awakenings.Count > 0)
                    rows.Add(new ScreenRowViewModel(
                        "records-current-hs-awakenings",
                        "현재 각성",
                        string.Join(" · ", state.HighSchool.Awakenings.Select(AwakeningArchiveTitle))));
                result.Add(new ScreenSectionViewModel(
                    "records-current-high-school",
                    "현재 고교 선수",
                    ScreenSectionTone.Information,
                    rows));
                if (state.HighSchool.ProspectRankings.Count > 0)
                    result.Add(new ScreenSectionViewModel(
                        "records-current-hs-prospects",
                        "현재 유망주 순위",
                        ScreenSectionTone.Plain,
                        state.HighSchool.ProspectRankings.Select(entry => new ScreenRowViewModel(
                            "records-current-hs-prospect-" + entry.Rank,
                            entry.Rank + "위 · " + entry.Name,
                            entry.School,
                            entry.Tag + (entry.IsPlayer ? " · 내 선수" : string.Empty))).ToArray()));
            }
            if (state.Pro != null)
            {
                var proRows = new List<ScreenRowViewModel>
                {
                    new ScreenRowViewModel(
                        "records-current-pro-ratings",
                        state.Pro.PlayerName + " · 현재 능력",
                        RatingLine(state.Pro.Ratings),
                        state.Pro.TeamName + " · " + state.Pro.Season + "시즌 " + state.Pro.Week + "주")
                };
                AddPitchingRecordRows(
                    proRows,
                    "records-current-pro",
                    "이번 시즌",
                    state.Pro.RecordBook?.CurrentSeason,
                    state.Pro.RecordBook?.CurrentSeason != null,
                    "지도자의 믿음 " + state.Pro.ManagerTrust + " · 포수와의 호흡 " +
                    state.Pro.CatcherTrust + " · 피로 " + state.Pro.Fatigue);
                result.Add(new ScreenSectionViewModel(
                    "records-current-pro",
                    "현재 프로 선수",
                    ScreenSectionTone.Information,
                    proRows));
                ProRecordBookReadModel recordBook = state.Pro.RecordBook;
                if (recordBook != null &&
                    (recordBook.AwardNames.Count > 0 || recordBook.Milestones.Count > 0 ||
                     recordBook.HallOfFameScore.HasValue))
                {
                    var achievementRows = new List<ScreenRowViewModel>();
                    if (recordBook.AwardNames.Count > 0)
                        achievementRows.Add(new ScreenRowViewModel(
                            "records-current-pro-awards",
                            "수상",
                            string.Join(" · ", recordBook.AwardNames)));
                    if (recordBook.Milestones.Count > 0)
                        achievementRows.Add(new ScreenRowViewModel(
                            "records-current-pro-milestones",
                            "이정표",
                            string.Join(" · ", recordBook.Milestones)));
                    if (recordBook.HallOfFameScore.HasValue)
                        achievementRows.Add(new ScreenRowViewModel(
                            "records-current-pro-hall-score",
                            "명예의 전당 점수",
                            recordBook.HallOfFameScore.Value.ToString(CultureInfo.InvariantCulture)));
                    result.Add(new ScreenSectionViewModel(
                        "records-current-pro-achievements",
                        "프로 성취",
                        ScreenSectionTone.Milestone,
                        achievementRows));
                }
                if (recordBook?.DecisionHistory?.Count > 0)
                    result.Add(new ScreenSectionViewModel(
                        "records-current-pro-decisions",
                        "커리어 선택 기록",
                        ScreenSectionTone.Plain,
                        recordBook.DecisionHistory.Select((decision, index) => new ScreenRowViewModel(
                            "records-current-pro-decision-" + index,
                            decision.Season + "시즌 " + decision.Week + "주 · " + decision.ChoiceTitle,
                            decision.EffectSummary,
                            ProDecisionDeltaLine(decision))).ToArray()));
                if (state.Pro.LeagueStandings.Count > 0)
                    result.Add(new ScreenSectionViewModel(
                        "records-current-pro-standings",
                        "현재 가상 프로 순위",
                        ScreenSectionTone.Plain,
                        state.Pro.LeagueStandings.Select(entry => new ScreenRowViewModel(
                            "records-current-pro-team-" + entry.Rank,
                            entry.Rank + "위 · " + entry.TeamName,
                            entry.Wins + "승 " + entry.Losses + "패 " + entry.Draws + "무",
                            (entry.Rank == 1
                                ? "선두"
                                : "선두와 " + entry.GamesBehind.ToString("0.0") + "경기 차") +
                            (entry.IsPlayerTeam ? " · 내 구단" : string.Empty))).ToArray()));
                if (state.Pro.LeaguePitchers.Count > 0)
                    result.Add(new ScreenSectionViewModel(
                        "records-current-pro-leaders",
                        "현재 투수 순위",
                        ScreenSectionTone.Plain,
                        state.Pro.LeaguePitchers.Select(entry => new ScreenRowViewModel(
                            "records-current-pro-pitcher-" + entry.Rank,
                            entry.Rank + "위 · " + entry.Name,
                            entry.TeamName + " · " + Innings(entry.InningsOuts) +
                            "이닝 · 탈삼진 " + entry.Strikeouts,
                            entry.Wins + "승 " + entry.Losses + "패 · 세이브 " + entry.Saves +
                            " · 볼넷 " + entry.Walks + " · 실점 " + entry.RunsAllowed +
                            " · " + AdvancedCompact(entry.PitchingRecord) +
                            (entry.IsPlayer ? " · 내 선수" : string.Empty))).ToArray()));
            }
            LifeArchiveRecord[] archive = (state.Meta?.LifeArchive ?? Array.Empty<LifeArchiveRecord>())
                .Where(record => record != null)
                .OrderByDescending(record => record.LifeNumber)
                .ToArray();
            if (archive.Length > 0)
            {
                int games = archive.Sum(record => record.HighSchoolPerformance?.ImportantGames ?? 0);
                int pitches = archive.Sum(record => record.Pitches ?? record.HighSchoolPerformance?.Pitches ?? 0);
                int outs = archive.Sum(record => record.Outs ?? record.HighSchoolPerformance?.Outs ?? 0);
                int highSchoolStrikeouts = archive.Sum(record =>
                    record.HighSchoolPerformance?.Strikeouts ?? 0);
                int proStrikeouts = archive.Sum(record => record.ProStrikeouts);
                int walks = archive.Sum(record => record.HighSchoolPerformance?.Walks ?? 0);
                int hits = archive.Sum(record => record.Hits ?? record.HighSchoolPerformance?.Hits ?? 0);
                int runs = archive.Sum(record => record.HighSchoolPerformance?.RunsAllowed ?? 0);
                result.Add(new ScreenSectionViewModel(
                    "records-archive-career",
                    "완주한 선수 통산",
                    ScreenSectionTone.Milestone,
                    new[]
                    {
                        new ScreenRowViewModel(
                            "records-archive-volume",
                            "등판과 이닝",
                            games + "경기 · " + Innings(outs) + "이닝 · " + pitches + "구",
                            archive.Length + "명 · 프로 " + archive.Sum(record => record.ProSeasons) + "시즌"),
                        new ScreenRowViewModel(
                            "records-archive-results",
                            "투구 결과",
                            "고교 탈삼진 " + highSchoolStrikeouts + " · 프로 탈삼진 " + proStrikeouts +
                            " · 볼넷 " + walks,
                            "고교 피안타 " + hits + " · 실점 " + runs + " · " +
                            PerNineLine(highSchoolStrikeouts, walks, runs, outs))
                    }));

                LifeArchiveRecord latest = archive[0];
                var latestRows = new List<ScreenRowViewModel>
                {
                    new ScreenRowViewModel(
                        "records-latest-life-summary",
                        latest.LifeNumber + "번째 선수 · " + latest.PlayerName,
                        (latest.SchoolName ?? "학교 기록 없음") + " · " +
                        (latest.Drafted ? "지명" : "미지명") + " · 평가 " + latest.DraftEvaluation,
                        "고교 탈삼진 " + (latest.HighSchoolPerformance?.Strikeouts ?? 0) +
                        " · 프로 탈삼진 " + latest.ProStrikeouts),
                };
                if (latest.FinalRatings != null)
                    latestRows.Add(new ScreenRowViewModel(
                        "records-latest-life-ratings",
                        "최종 능력",
                        RatingLine(latest.FinalRatings),
                        latest.HighSchoolDetail?.Talents?.Count > 0
                            ? string.Join(" · ", latest.HighSchoolDetail.Talents.Select(value =>
                                value.AbilityTitle + " " + value.GradeTitle))
                            : "저장된 네 능력의 최종 수치입니다."));
                if (latest.HighSchoolDetail != null)
                {
                    string[] story = latest.HighSchoolDetail.Chronicle
                        .Reverse()
                        .Take(3)
                        .Reverse()
                        .ToArray();
                    if (story.Length > 0)
                        latestRows.Add(new ScreenRowViewModel(
                            "records-latest-life-story",
                            "최근 연대기",
                            string.Join(" · ", story)));
                    if (latest.HighSchoolDetail.Nicknames.Count > 0 ||
                        !string.IsNullOrWhiteSpace(latest.HighSchoolDetail.Personality))
                        latestRows.Add(new ScreenRowViewModel(
                            "records-latest-life-identity",
                            "별명과 성격",
                            latest.HighSchoolDetail.Nicknames.Count > 0
                                ? string.Join(" · ", latest.HighSchoolDetail.Nicknames)
                                : latest.PlayerName,
                            string.IsNullOrWhiteSpace(latest.HighSchoolDetail.Personality)
                                ? "저장된 선수 이야기"
                                : latest.HighSchoolDetail.Personality));
                }
                if (latest.Awakenings.Count > 0)
                    latestRows.Add(new ScreenRowViewModel(
                        "records-latest-life-awakenings",
                        "각성",
                        string.Join(" · ", latest.Awakenings.Select(AwakeningArchiveTitle))));
                result.Add(new ScreenSectionViewModel(
                    "records-latest-life",
                    "최근 완주 기록",
                    ScreenSectionTone.Plain,
                    latestRows));

                result.Add(new ScreenSectionViewModel(
                    "records-life-log",
                    "회차 기록",
                    ScreenSectionTone.Plain,
                    archive.Select(record => new ScreenRowViewModel(
                        "records-life-" + record.LifeNumber,
                        record.LifeNumber + "번째 · " + record.PlayerName,
                        (record.HighSchoolPerformance?.ImportantGames ?? 0) + "경기 · " +
                        Innings(record.Outs ?? record.HighSchoolPerformance?.Outs ?? 0) + "이닝 · 탈삼진 " +
                        ((record.HighSchoolPerformance?.Strikeouts ?? 0) + record.ProStrikeouts),
                        record.PlayerLegacy?.Title ?? "이전 버전에서 보관한 선수 기록")).ToArray()));
            }
            if (state.HighSchool?.GameLines?.Count > 0)
                result.Add(new ScreenSectionViewModel("records-high-school", "고교 경기", ScreenSectionTone.Plain,
                    state.HighSchool.GameLines.Select((line, index) => GameLineRow("record-hs", line, index)).ToArray()));
            if (state.Pro?.RecordBook?.SeasonGameLinesAvailable == true)
                result.Add(new ScreenSectionViewModel(
                    "records-pro-games",
                    "프로 이번 시즌 전체 경기",
                    ScreenSectionTone.Plain,
                    state.Pro.RecordBook.SeasonGameLines.Count == 0
                        ? new[]
                        {
                            new ScreenRowViewModel(
                                "records-pro-games-empty",
                                "아직 등판 기록 없음",
                                "이번 시즌 첫 등판 뒤 경기 기록이 저장됩니다.")
                        }
                        : state.Pro.RecordBook.SeasonGameLines
                            .Select((line, index) => GameLineRow("record-pro", line, index))
                            .ToArray()));
            else if (state.Pro?.RecordBook != null)
                result.Add(new ScreenSectionViewModel(
                    "records-pro-games-unavailable",
                    "프로 경기 기록",
                    ScreenSectionTone.Information,
                    new[]
                    {
                        new ScreenRowViewModel(
                            "records-pro-games-unavailable-copy",
                            "전체 경기 기록을 불러올 수 없음",
                            "이전 저장에는 이번 시즌의 모든 경기선이 보관되지 않았습니다.")
                    }));
            if (state.Pro?.RecordBook?.CareerSeasons?.Count > 0)
                result.Add(new ScreenSectionViewModel("records-pro-seasons", "프로 시즌 기록", ScreenSectionTone.Milestone,
                    state.Pro.RecordBook.CareerSeasons.Select(line => new ScreenRowViewModel(
                        "record-season-" + line.Season,
                        line.Season + "시즌",
                        SeasonVolumeLine(line),
                        SeasonResultLine(line) + " · " + AdvancedCompact(line.PitchingRecord))).ToArray()));
            if (result.Count == 0 && state.Meta?.Weekly?.Program != null)
                result.AddRange(WeeklySections(state.Meta.Weekly));
            if (result.Count == 0)
                result.Add(EmptySection("records-empty", "경기 기록", "아직 저장된 경기 기록이 없습니다."));
            result.Insert(0, WeeklyRecordsEntrySection(state.Meta?.Weekly));
            return result;
        }

        private static ScreenSectionViewModel WeeklyRecordsEntrySection(WeeklyProgressState weekly)
        {
            WeeklyProgramState program = weekly?.Program;
            if (program == null)
            {
                return new ScreenSectionViewModel(
                    "records-weekly-note",
                    "주간 야구 노트",
                    ScreenSectionTone.Information,
                    new[]
                    {
                        new ScreenRowViewModel(
                            "records-weekly-note-open",
                            "이번 주 목표",
                            "노트를 열어 세 가지 과제를 확인하세요.",
                            "처음 열 때 현재 선수 생활에 맞는 주간 보드를 안전하게 저장합니다.")
                    });
            }

            string reward = program.Claimed
                ? "이번 주 도장을 이미 받았습니다."
                : program.RewardReady
                    ? "과제 두 개를 마쳐 도장 보상을 받을 수 있습니다."
                    : "과제 두 개를 마치면 도장 보상을 받을 수 있습니다.";
            return new ScreenSectionViewModel(
                "records-weekly-note",
                "주간 야구 노트",
                program.RewardReady ? ScreenSectionTone.Positive : ScreenSectionTone.Information,
                new[]
                {
                    new ScreenRowViewModel(
                        "records-weekly-note-progress",
                        program.WeekKey,
                        program.CompletedCount + "/" + program.Tasks.Count + "개 완료",
                        reward)
                });
        }

        private static string PerNineLine(int strikeouts, int walks, int runs, int outs)
        {
            if (outs <= 0) return "첫 아웃부터 비율 기록을 계산합니다.";
            double innings = outs / 3d;
            return "9이닝당 탈삼진 " + (strikeouts * 9d / innings).ToString("0.0") +
                " · 볼넷 " + (walks * 9d / innings).ToString("0.0") +
                " · 실점 " + (runs * 9d / innings).ToString("0.0");
        }

        private static void AddPitchingRecordRows(
            ICollection<ScreenRowViewModel> rows,
            string prefix,
            string heading,
            PitchingRecordReadModel record,
            bool available,
            string context)
        {
            if (!available || record == null)
            {
                rows.Add(new ScreenRowViewModel(
                    prefix + "-performance",
                    heading,
                    "상세 투구 기록을 불러올 수 없음",
                    "이전 저장에는 경기별 원자료가 모두 보관되지 않았습니다."));
                rows.Add(new ScreenRowViewModel(
                    prefix + "-advanced",
                    heading + " 고급 지표",
                    "계산 가능한 기록 없음",
                    context));
                return;
            }

            rows.Add(new ScreenRowViewModel(
                prefix + "-performance",
                heading,
                record.Games + "경기 · 선발 " + record.Starts + " · " + record.InningsText +
                "이닝 · " + NullableCount(record.Pitches, "투구"),
                "탈삼진 " + record.Strikeouts + " · 볼넷 " + record.Walks +
                " · 실점 " + record.RunsAllowed + " · " +
                NullableCount(record.Hits, "피안타") + " · " +
                NullableCount(record.HomeRuns, "피홈런")));
            rows.Add(new ScreenRowViewModel(
                prefix + "-decisions",
                "승패와 역할",
                record.Wins + "승 " + record.Losses + "패 · " + record.Saves + "세이브",
                record.QualityStarts.HasValue
                    ? "퀄리티 스타트 " + record.QualityStarts.Value
                    : "퀄리티 스타트는 이전 저장에서 집계되지 않았습니다."));
            rows.Add(new ScreenRowViewModel(
                prefix + "-advanced",
                heading + " 고급 지표",
                "9이닝당 실점 " + Metric(record.RunsPerNine) + " · WHIP " +
                Metric(record.Whip) + " · 탈삼진/볼넷 " + Metric(record.StrikeoutToWalk),
                "K/9 " + Metric(record.StrikeoutsPerNine) + " · BB/9 " +
                Metric(record.WalksPerNine) + " · H/9 " + Metric(record.HitsPerNine) +
                " · HR/9 " + Metric(record.HomeRunsPerNine) + " · FIP " +
                Metric(record.FieldingIndependentPitching) + " · 상대 타자 " +
                NullableCount(record.BattersFaced, string.Empty) + " · K% " +
                Percent(record.StrikeoutRate) + " · BABIP " + Babip(record.BattingAverageOnBallsInPlay) +
                ". " + context));
        }

        private static string NullableCount(int? value, string label) => value.HasValue
            ? (string.IsNullOrWhiteSpace(label)
                ? value.Value.ToString(CultureInfo.InvariantCulture)
                : label + " " + value.Value.ToString(CultureInfo.InvariantCulture))
            : (string.IsNullOrWhiteSpace(label) ? "기록 없음" : label + " 미기록");

        private static string Metric(double? value) => value.HasValue
            ? value.Value.ToString("0.00", CultureInfo.InvariantCulture)
            : "기록 없음";

        private static string Percent(double? value) => value.HasValue
            ? value.Value.ToString("0.0%", CultureInfo.InvariantCulture)
            : "기록 없음";

        private static string Babip(double? value) => value.HasValue
            ? value.Value.ToString("0.000", CultureInfo.InvariantCulture)
            : "기록 없음";

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

        private static bool HasCompletedLife(GameSaveAggregate state) =>
            state?.Meta?.LifeArchive?.Count > 0;

        private LifeArchiveRecord SelectedLifeRecord(GameSaveAggregate state)
        {
            IReadOnlyList<LifeArchiveRecord> archive = state?.Meta?.LifeArchive;
            if (archive == null || archive.Count == 0) return null;
            string selected = _selectedChoice("archive_life");
            if (int.TryParse(selected, out int lifeNumber))
            {
                LifeArchiveRecord exact = archive.FirstOrDefault(value =>
                    value != null && value.LifeNumber == lifeNumber);
                if (exact != null) return exact;
            }
            return archive
                .Where(value => value != null)
                .OrderByDescending(value => value.LifeNumber)
                .FirstOrDefault();
        }

        private static IReadOnlyList<ScreenSectionViewModel> LeagueSections(GameSaveAggregate state)
        {
            var result = new List<ScreenSectionViewModel>();
            if (state.Pro?.LeagueStandings?.Count > 0)
                result.Add(new ScreenSectionViewModel("league-standings", "가상 프로 리그 순위", ScreenSectionTone.Plain,
                    state.Pro.LeagueStandings.Select(entry => new ScreenRowViewModel(
                        "league-team-" + entry.Rank,
                        entry.Rank + "위 · " + entry.TeamName,
                        entry.Wins + "승 " + entry.Losses + "패 " + entry.Draws + "무",
                        (entry.Rank == 1 ? "선두" : "선두와 " + entry.GamesBehind.ToString("0.0") + "경기 차") +
                            (entry.IsPlayerTeam ? " · 내 구단" : string.Empty))).ToArray()));
            if (state.Pro?.LeaguePitchers?.Count > 0)
                result.Add(new ScreenSectionViewModel("league-pitchers", "투수 순위", ScreenSectionTone.Plain,
                    state.Pro.LeaguePitchers.Select(entry => new ScreenRowViewModel(
                        "league-pitcher-" + entry.Rank,
                        entry.Rank + "위 · " + entry.Name,
                        entry.TeamName + " · " + Innings(entry.InningsOuts) + "이닝 · 탈삼진 " + entry.Strikeouts,
                        entry.Wins + "승 " + entry.Losses + "패 · 세이브 " + entry.Saves +
                            (entry.IsPlayer ? " · 내 선수" : string.Empty))).ToArray()));
            if (result.Count == 0 && state.HighSchool != null)
            {
                AddHighSchoolCompetition(result, state.HighSchool);
            }
            if (result.Count == 0)
                result.Add(EmptySection("league-empty", "리그 정보", "커리어를 시작하면 실제 대회와 순위가 여기에 표시됩니다."));
            return result;
        }

        private static IReadOnlyList<ScreenSectionViewModel> AchievementSections(AchievementProgressState progress)
        {
            progress = progress ?? AchievementProgressState.Empty;
            string[] ids =
            {
                AchievementIds.FirstDraft, AchievementIds.FirstStrikeout, AchievementIds.CleanInning,
                AchievementIds.PerfectDelivery, AchievementIds.MajorDebut, AchievementIds.HundredStrikeouts,
                AchievementIds.ThirdLife, AchievementIds.FifthLife, AchievementIds.TenthLife,
                AchievementIds.KarmaRun, AchievementIds.DoubleKarma, AchievementIds.AwakenedThrice,
                AchievementIds.FourSchools, AchievementIds.FiveDrafts, AchievementIds.HallOfFame,
            };
            return new[]
            {
                new ScreenSectionViewModel("achievement-list", "업적 목록", ScreenSectionTone.Milestone,
                    ids.Select((id, index) =>
                    {
                        bool unlocked = progress.Unlocked.Contains(id, StringComparer.Ordinal);
                        bool fresh = progress.Unacknowledged.Contains(id, StringComparer.Ordinal);
                        return new ScreenRowViewModel(
                            "achievement-" + index,
                            AchievementTitle(id),
                            unlocked ? fresh ? "새로 달성" : "달성" : "잠김",
                            AchievementCondition(id));
                    }).ToArray())
            };
        }

        private static IReadOnlyList<ScreenSectionViewModel> ArchiveSections(
            IReadOnlyList<LifeArchiveRecord> archive)
        {
            if (archive == null || archive.Count == 0)
                return new[] { EmptySection("archive-empty", "인생 기록", "아직 완주한 야구 인생이 없습니다.") };
            LifeArchiveRecord[] ordered = archive
                .OrderByDescending(value => value.LifeNumber)
                .ToArray();
            int strikeouts = ordered.Sum(record =>
                (record.HighSchoolPerformance?.Strikeouts ?? 0) + record.ProStrikeouts);
            int nicknameCount = ordered
                .SelectMany(record => record.HighSchoolDetail?.Nicknames ?? Array.Empty<string>())
                .Distinct(StringComparer.Ordinal)
                .Count();
            var sections = new List<ScreenSectionViewModel>
            {
                new ScreenSectionViewModel(
                    "archive-overview",
                    "지금까지 키운 선수 " + ordered.Length + "명",
                    ScreenSectionTone.Milestone,
                    new[]
                    {
                        new ScreenRowViewModel(
                            "archive-career-totals",
                            "지난 선수 통산",
                            "지명 " + ordered.Count(record => record.Drafted) + "/" + ordered.Length +
                            " · 통산 탈삼진 " + strikeouts,
                            "최고 평가 " + ordered.Max(record => record.DraftEvaluation) +
                            " · 모은 야구혼 " + ordered.Sum(record => record.SoulEarned)),
                        new ScreenRowViewModel(
                            "archive-nickname-collection",
                            "별명 도감",
                            nicknameCount + "개 수집",
                            nicknameCount == 0
                                ? "완주한 선수의 별명이 생기면 이곳에 쌓입니다."
                                : "모든 선수의 별명과 기록은 회차별 상세에 보존됩니다.")
                    })
            };
            sections.AddRange(ordered.Select(ArchiveLifeSection));
            return sections;
        }

        private static IReadOnlyList<ScreenSectionViewModel> LifeCardSections(LifeArchiveRecord record)
        {
            if (record == null)
            {
                return new[]
                {
                    EmptySection(
                        "life-card-empty",
                        "선수 카드",
                        "완주한 회차를 인생 보관함에서 고르면 공유 카드를 만들 수 있습니다.")
                };
            }

            HighSchoolLifeDetailReadModel detail = record.HighSchoolDetail;
            CareerPerformanceReadModel performance = record.HighSchoolPerformance;
            var sections = new List<ScreenSectionViewModel>
            {
                new ScreenSectionViewModel(
                    "life-card-identity",
                    record.LifeNumber + "번째 선수",
                    ScreenSectionTone.Milestone,
                    new[]
                    {
                        new ScreenRowViewModel(
                            "life-card-player",
                            record.PlayerName,
                            (string.IsNullOrWhiteSpace(record.SchoolName) ? "학교 기록 없음" : record.SchoolName) +
                            (string.IsNullOrWhiteSpace(detail?.Personality)
                                ? string.Empty
                                : " · 성향 " + detail.Personality),
                            string.IsNullOrWhiteSpace(detail?.WindTitle)
                                ? "3년의 바람 기록 없음"
                                : "바람 · " + detail.WindTitle),
                        new ScreenRowViewModel(
                            "life-card-draft",
                            record.Drafted
                                ? (string.IsNullOrWhiteSpace(record.DraftTeamName)
                                    ? "지명 구단 기록 없음"
                                    : record.DraftTeamName + " 지명")
                                : "드래프트 미지명",
                            "스카우트 평가 " + record.DraftEvaluation + "점",
                            record.ProSeasons > 0
                                ? "프로 " + record.ProSeasons + "시즌 · 탈삼진 " + record.ProStrikeouts +
                                  " · 수상 " + record.ProAwards
                                : "고교 커리어 기록")
                    })
            };

            PitcherRatingsReadModel start = detail?.StartingRatings;
            PitcherRatingsReadModel final = record.FinalRatings;
            if (start != null && final != null)
            {
                sections.Add(new ScreenSectionViewModel(
                    "life-card-growth",
                    "3년 동안 키운 것",
                    ScreenSectionTone.Positive,
                    new[]
                    {
                        GrowthRow("life-card-rating-stuff", "구위", start.Stuff, final.Stuff),
                        GrowthRow("life-card-rating-command", "제구", start.Command, final.Command),
                        GrowthRow("life-card-rating-movement", "변화", start.Movement, final.Movement),
                        GrowthRow("life-card-rating-stamina", "체력", start.Stamina, final.Stamina),
                        new ScreenRowViewModel(
                            "life-card-rating-total",
                            "능력 총합",
                            start.Total + " → " + final.Total,
                            GrowthDelta(final.Total - start.Total))
                    }));
            }
            else
            {
                sections.Add(EmptySection(
                    "life-card-growth-unavailable",
                    "3년 동안 키운 것",
                    "이전 버전의 회차라 시작·최종 능력 기록이 없습니다."));
            }

            var pitchingRows = new List<ScreenRowViewModel>
            {
                new ScreenRowViewModel(
                    "life-card-record-counts",
                    "직접 등판 기록",
                    performance.ImportantGames + "경기 · 탈삼진 " + performance.Strikeouts +
                    " · 볼넷 " + performance.Walks + " · 실점 " + performance.RunsAllowed,
                    record.Hits.HasValue
                        ? "피안타 " + record.Hits.Value
                        : "이전 버전의 회차라 피안타 기록이 없습니다."),
                new ScreenRowViewModel(
                    "life-card-record-workload",
                    "이닝과 투구 수",
                    record.Outs.HasValue ? Innings(record.Outs.Value) + "이닝" : "이닝 기록 없음",
                    record.Pitches.HasValue ? record.Pitches.Value + "구" : "투구 수 기록 없음")
            };
            if (record.Outs.HasValue && record.Outs.Value > 0)
            {
                double innings = record.Outs.Value / 3d;
                string whip = record.Hits.HasValue
                    ? ((record.Hits.Value + performance.Walks) / innings)
                        .ToString("0.00", CultureInfo.InvariantCulture)
                    : "기록 없음";
                pitchingRows.Add(new ScreenRowViewModel(
                    "life-card-record-rates",
                    "세부 지표",
                    "방어율 " + (performance.RunsAllowed * 9d / innings)
                        .ToString("0.00", CultureInfo.InvariantCulture) +
                    " · WHIP " + whip,
                    "K/9 " + (performance.Strikeouts * 9d / innings)
                        .ToString("0.0", CultureInfo.InvariantCulture)));
            }
            else
            {
                pitchingRows.Add(new ScreenRowViewModel(
                    "life-card-record-rates-unavailable",
                    "세부 지표",
                    "기록 없음",
                    "이전 버전의 회차는 이닝 기록이 없어 방어율·WHIP·K/9을 계산하지 않습니다."));
            }
            sections.Add(new ScreenSectionViewModel(
                "life-card-record",
                "3년 성적",
                ScreenSectionTone.Plain,
                pitchingRows));

            var storyRows = new List<ScreenRowViewModel>();
            if (detail?.Nicknames?.Count > 0)
                storyRows.Add(new ScreenRowViewModel(
                    "life-card-nicknames",
                    "세상이 부른 이름",
                    string.Join(" · ", detail.Nicknames.Select(value => "'" + value + "'"))));
            if (record.SignatureLegacy != null)
                storyRows.Add(new ScreenRowViewModel(
                    "life-card-signature",
                    "대표 유산 · " + record.SignatureLegacy.Title,
                    record.SignatureLegacy.Detail,
                    record.SignatureLegacy.EvidenceSummary));
            string[] people = LifeCardPeople(detail);
            if (people.Length > 0)
                storyRows.Add(new ScreenRowViewModel(
                    "life-card-people",
                    "함께한 사람들",
                    string.Join(" · ", people)));
            string[] chronicle = LifeCardChronicle(detail?.Chronicle);
            if (chronicle.Length > 0)
                storyRows.Add(new ScreenRowViewModel(
                    "life-card-chronicle",
                    "선수의 연대기",
                    string.Join("\n", chronicle)));
            string challengeCode = LifeCardShareCopy.ChallengeCode(record);
            if (!string.IsNullOrWhiteSpace(challengeCode))
                storyRows.Add(new ScreenRowViewModel(
                    "life-card-challenge",
                    "같은 판에 도전",
                    challengeCode,
                    "설정 화면에서 이 코드를 입력하면 같은 시드와 회차로 기록 없는 도전을 시작합니다."));
            if (storyRows.Count == 0)
                storyRows.Add(new ScreenRowViewModel(
                    "life-card-story-unavailable",
                    "선수 이야기",
                    "기록 없음",
                    "이전 버전에서 완주한 회차라 이야기 기록이 보관되지 않았습니다."));
            sections.Add(new ScreenSectionViewModel(
                "life-card-story",
                "이 선수가 남긴 것",
                ScreenSectionTone.Information,
                storyRows));
            return sections;
        }

        private static IReadOnlyList<ScreenSectionViewModel> RunRecapSections(
            GameSaveAggregate state,
            LifeArchiveRecord record)
        {
            CareerPerformanceReadModel performance = record.HighSchoolPerformance;
            HighSchoolLifeDetailReadModel detail = record.HighSchoolDetail;
            var stamps = new List<ScreenRowViewModel>
            {
                new ScreenRowViewModel(
                    "recap-draft-stamp",
                    record.Drafted
                        ? (string.IsNullOrWhiteSpace(record.DraftTeamName)
                            ? "지명 구단 기록 없음"
                            : record.DraftTeamName + " 지명")
                        : "드래프트 미지명",
                    "스카우트 평가 " + record.DraftEvaluation + "점"),
                new ScreenRowViewModel(
                    "recap-game-stamp",
                    performance.ImportantGames + "등판 · 탈삼진 " + performance.Strikeouts,
                    "볼넷 " + performance.Walks + " · 실점 " + performance.RunsAllowed)
            };
            if (detail?.Nicknames?.Count > 0)
                stamps.Add(new ScreenRowViewModel(
                    "recap-nickname-stamp",
                    "세상이 부른 이름",
                    "'" + detail.Nicknames.Last() + "'"));
            if (!string.IsNullOrWhiteSpace(record.PledgeTitle))
                stamps.Add(new ScreenRowViewModel(
                    "recap-pledge-stamp",
                    record.PledgeAchieved == true ? "목표 달성" : "목표 미완",
                    record.PledgeTitle,
                    (record.PledgeProgressLine ?? "저장된 진행 기록") +
                    " · 보상 야구혼 +" + (record.PledgeRewardPermille ?? 0) / 10 + "%"));
            if (!string.IsNullOrWhiteSpace(detail?.RivalName))
                stamps.Add(new ScreenRowViewModel(
                    "recap-rival-stamp",
                    "숙적과 남긴 기록",
                    detail.RivalName,
                    "이 회차의 관계와 승부 기록에 함께 남았습니다."));

            var result = new List<ScreenSectionViewModel>
            {
                new ScreenSectionViewModel(
                    "recap-stamps",
                    record.PlayerName + "의 3년",
                    ScreenSectionTone.Milestone,
                    stamps)
            };

            PitcherRatingsReadModel start = detail?.StartingRatings;
            PitcherRatingsReadModel final = record.FinalRatings;
            if (start != null && final != null)
            {
                result.Add(new ScreenSectionViewModel(
                    "recap-growth",
                    "3년 동안 키운 것",
                    ScreenSectionTone.Positive,
                    new[]
                    {
                        GrowthRow("recap-rating-stuff", "구위", start.Stuff, final.Stuff),
                        GrowthRow("recap-rating-command", "제구", start.Command, final.Command),
                        GrowthRow("recap-rating-movement", "변화", start.Movement, final.Movement),
                        GrowthRow("recap-rating-stamina", "체력", start.Stamina, final.Stamina),
                    }));
            }
            else
            {
                result.Add(EmptySection(
                    "recap-growth-unavailable",
                    "3년 동안 키운 것",
                    "이전 버전의 회차라 시작·최종 능력 기록이 없습니다."));
            }

            if (record.SignatureLegacy != null)
            {
                result.Add(new ScreenSectionViewModel(
                    "recap-signature",
                    "새 선수에게 이어진 대표 유산",
                    ScreenSectionTone.Milestone,
                    new[]
                    {
                        new ScreenRowViewModel(
                            "recap-signature-selected",
                            record.SignatureLegacy.Title,
                            record.SignatureLegacy.Detail,
                            record.SignatureLegacy.EvidenceSummary),
                        new ScreenRowViewModel(
                            "recap-signature-candidates",
                            "함께 발견한 후보",
                            record.SignatureLegacyCandidates.Count == 0
                                ? "후보 기록 없음"
                                : string.Join(" · ", record.SignatureLegacyCandidates.Select(value => value.Title)),
                            "결산 당시 제시된 후보를 그대로 보관했습니다.")
                    }));
            }

            result.Add(new ScreenSectionViewModel(
                "recap-soul",
                "계승 포인트",
                ScreenSectionTone.Milestone,
                new[]
                {
                    new ScreenRowViewModel(
                        "recap-soul-earned",
                        "이번 선수 적립",
                        "+" + record.SoulEarned + "P",
                        "현재 잔액 " + state.Meta.SoulBalance + "P"),
                    new ScreenRowViewModel(
                        "recap-soul-automatic",
                        "자동 계승 총량",
                        state.Meta.AutomaticSoulEarned + "P",
                        state.Meta.AutomaticSoulEarned > 0
                            ? "새 선수 설정에서 계승 영역과 보너스를 고를 수 있습니다."
                            : "이번 저장에는 자동 계승 포인트가 없습니다.")
                }));

            NextRunIntentState intent = record.SuggestedNextRunIntent ?? state.Meta.NextRunIntent;
            if (intent != null)
            {
                result.Add(new ScreenSectionViewModel(
                    "recap-next-intent",
                    "새 선수로 다시 도전",
                    ScreenSectionTone.Information,
                    new[]
                    {
                        new ScreenRowViewModel(
                            "recap-next-intent-value",
                            string.IsNullOrWhiteSpace(intent.PledgeTitle) ? "추천 목표" : intent.PledgeTitle,
                            intent.Reason,
                            intent.PledgeRewardPermille.HasValue
                                ? "달성 보너스 야구혼 +" + intent.PledgeRewardPermille.Value / 10 + "%"
                                : "저장된 다음 회차 목표")
                    }));
            }
            return result;
        }

        private static ScreenRowViewModel GrowthRow(string id, string title, int start, int final)
        {
            return new ScreenRowViewModel(
                id,
                title,
                start + " → " + final,
                GrowthDelta(final - start));
        }

        private static string GrowthDelta(int delta) =>
            delta > 0 ? "+" + delta : delta == 0 ? "변화 없음" : delta.ToString();

        private static string[] LifeCardPeople(HighSchoolLifeDetailReadModel detail)
        {
            if (detail == null) return Array.Empty<string>();
            return new[]
                {
                    string.IsNullOrWhiteSpace(detail.CoachName) ? null : detail.CoachName + " 감독",
                    string.IsNullOrWhiteSpace(detail.CatcherName) ? null : detail.CatcherName + " 포수",
                    string.IsNullOrWhiteSpace(detail.RivalName) ? null : "숙적 " + detail.RivalName,
                }
                .Where(value => value != null)
                .ToArray();
        }

        private static string[] LifeCardChronicle(IReadOnlyList<string> chronicle)
        {
            if (chronicle == null || chronicle.Count == 0) return Array.Empty<string>();
            if (chronicle.Count <= 5) return chronicle.ToArray();
            return new[] { chronicle[0] }
                .Concat(chronicle.Skip(Math.Max(1, chronicle.Count - 4)))
                .ToArray();
        }

        private static ScreenSectionViewModel ArchiveLifeSection(LifeArchiveRecord record)
        {
            var rows = new List<ScreenRowViewModel>
            {
                new ScreenRowViewModel(
                    "archive-life-summary-" + record.LifeNumber,
                    record.LifeNumber + "번째 선수 · " + record.PlayerName,
                    (record.SchoolName ?? "학교 미정") + " · " +
                    (record.Drafted ? "지명" : "미지명") + " · 프로 " + record.ProSeasons + "시즌",
                    "고교 탈삼진 " + (record.HighSchoolPerformance?.Strikeouts ?? 0) +
                    " · 프로 탈삼진 " + record.ProStrikeouts + " · 야구혼 +" + record.SoulEarned)
            };

            HighSchoolLifeDetailReadModel detail = record.HighSchoolDetail;
            if (record.PlayerLegacy != null)
                rows.Add(PlayerLegacyRow("archive-player-legacy-" + record.LifeNumber, record));
            if (detail?.Chronicle?.Count > 0)
            {
                rows.AddRange(detail.Chronicle
                    .Select((line, index) => new ScreenRowViewModel(
                        "archive-chronicle-" + record.LifeNumber + "-" + index,
                        "연대기 " + (index + 1),
                        line)));
            }
            if (detail?.Nicknames?.Count > 0)
                rows.Add(new ScreenRowViewModel(
                    "archive-nicknames-" + record.LifeNumber,
                    "세상이 부른 이름",
                    string.Join(" · ", detail.Nicknames)));
            if (detail != null)
            {
                if (!string.IsNullOrWhiteSpace(detail.PresetTitle) ||
                    !string.IsNullOrWhiteSpace(detail.DifficultyTitle))
                {
                    string preset = string.IsNullOrWhiteSpace(detail.PresetTitle)
                        ? "기존 저장의 투수 유형"
                        : detail.PresetTitle;
                    string difficulty = string.IsNullOrWhiteSpace(detail.DifficultyTitle)
                        ? "기본 난이도"
                        : detail.DifficultyTitle;
                    rows.Add(new ScreenRowViewModel(
                        "archive-origin-" + record.LifeNumber,
                        "선수의 시작",
                        preset + " · " + difficulty,
                        string.IsNullOrWhiteSpace(record.DraftTeamName)
                            ? "드래프트 구단 기록 없음"
                            : "지명 구단 · " + record.DraftTeamName));
                }
                if (detail.Talents?.Count > 0)
                    rows.Add(new ScreenRowViewModel(
                        "archive-talents-" + record.LifeNumber,
                        "처음 발견한 재능",
                        string.Join(" · ", detail.Talents.Select(value =>
                            value.AbilityTitle + " " + value.GradeTitle))));
                var people = new[] { detail.CoachName, detail.CatcherName, detail.RivalName }
                    .Where(value => !string.IsNullOrWhiteSpace(value))
                    .ToArray();
                if (people.Length > 0)
                    rows.Add(new ScreenRowViewModel(
                        "archive-people-" + record.LifeNumber,
                        "함께한 사람들",
                        string.Join(" · ", people),
                        string.IsNullOrWhiteSpace(detail.Personality)
                            ? "선택과 관계가 이 선수의 이야기를 만들었습니다."
                            : "성향 · " + detail.Personality));
                RelationshipResponseTallyReadModel tally = detail.ResponseTally;
                if (tally != null && tally.Listen + tally.Explain + tally.Challenge > 0)
                    rows.Add(new ScreenRowViewModel(
                        "archive-relationship-choices-" + record.LifeNumber,
                        "관계에서 고른 답",
                        "먼저 듣기 " + tally.Listen + " · 설명하기 " + tally.Explain +
                        " · 결과로 답하기 " + tally.Challenge));
                if (!string.IsNullOrWhiteSpace(detail.WindTitle))
                    rows.Add(new ScreenRowViewModel(
                        "archive-wind-" + record.LifeNumber,
                        "3년의 바람",
                        detail.WindTitle,
                        string.IsNullOrWhiteSpace(detail.SchoolStrength)
                            ? "학교와 선수의 선택이 남긴 방향입니다."
                            : "학교 강점 · " + detail.SchoolStrength));
            }
            if (record.SignatureLegacy != null)
            {
                rows.Add(new ScreenRowViewModel(
                    "archive-signature-" + record.LifeNumber,
                    "대표 유산 · " + record.SignatureLegacy.Title,
                    record.SignatureLegacy.Detail,
                    record.SignatureLegacy.EvidenceSummary));
                string[] others = record.SignatureLegacyCandidates
                    .Where(value => value != null && !string.Equals(
                        value.Id,
                        record.SignatureLegacy.Id,
                        StringComparison.Ordinal))
                    .Select(value => value.Title)
                    .ToArray();
                if (others.Length > 0)
                    rows.Add(new ScreenRowViewModel(
                        "archive-signature-candidates-" + record.LifeNumber,
                        "함께 발견한 유산",
                        string.Join(" · ", others),
                        "결산 당시 제시된 세 후보를 그대로 보관했습니다."));
            }
            if (!string.IsNullOrWhiteSpace(record.PledgeTitle))
                rows.Add(new ScreenRowViewModel(
                    "archive-pledge-" + record.LifeNumber,
                    "고교 3년 목표 · " + record.PledgeTitle,
                    record.PledgeAchieved == true ? "달성" : "미달성",
                    (record.PledgeProgressLine ?? "저장된 진행 기록") +
                    " · 보상 야구혼 +" + (record.PledgeRewardPermille ?? 0) / 10 + "%"));

            PitcherRatingsReadModel start = detail?.StartingRatings;
            PitcherRatingsReadModel final = record.FinalRatings;
            if (start != null && final != null)
                rows.Add(new ScreenRowViewModel(
                    "archive-ratings-" + record.LifeNumber,
                    "시작 능력 → 최종 능력",
                    RatingLine(start) + " → " + RatingLine(final)));
            rows.Add(new ScreenRowViewModel(
                "archive-pitching-" + record.LifeNumber,
                "투구와 성적",
                (record.HighSchoolPerformance?.ImportantGames ?? 0) + "경기 · " +
                (record.Pitches ?? record.HighSchoolPerformance?.Pitches ?? 0) + "구 · " +
                (record.Outs ?? record.HighSchoolPerformance?.Outs ?? 0) + "아웃",
                "볼넷 " + (record.HighSchoolPerformance?.Walks ?? 0) + " · 피안타 " +
                (record.Hits ?? record.HighSchoolPerformance?.Hits ?? 0) + " · 실점 " +
                (record.HighSchoolPerformance?.RunsAllowed ?? 0)));

            AddArchivedChoiceRow(rows, "archive-awakenings-" + record.LifeNumber, "각성", record.Awakenings, AwakeningArchiveTitle);
            AddArchivedChoiceRow(rows, "archive-karmas-" + record.LifeNumber, "성향", record.Karmas, KarmaArchiveTitle);
            AddArchivedChoiceRow(rows, "archive-memories-" + record.LifeNumber, "가져간 기억", record.Memories, MemoryArchiveTitle);
            return new ScreenSectionViewModel(
                "archive-life-" + record.LifeNumber,
                record.LifeNumber + "번째 선수 · " + record.PlayerName,
                ScreenSectionTone.Plain,
                rows);
        }

        private static void AddArchivedChoiceRow(
            ICollection<ScreenRowViewModel> rows,
            string id,
            string label,
            IReadOnlyList<string> values,
            Func<string, string> title)
        {
            if (values == null || values.Count == 0) return;
            rows.Add(new ScreenRowViewModel(id, label, string.Join(" · ", values.Select(title))));
        }

        private static string RatingLine(PitcherRatingsReadModel value) =>
            "구위 " + value.Stuff + " · 제구 " + value.Command + " · 변화 " + value.Movement +
            " · 체력 " + value.Stamina;

        private static string KarmaArchiveTitle(string value)
        {
            switch (NormalizeArchiveId(value))
            {
                case "unknownland": return "낯선 지역";
                case "stubborncoach": return "완고한 지도";
                case "singleweapon": return "한 가지 무기";
                case "geniusgeneration": return "천재 세대";
                case "erasedmemory": return "흐릿한 기억";
                case "nolastchance": return "마지막 기회 없음";
                default: return "기록된 성향";
            }
        }

        private static string AwakeningArchiveTitle(string value)
        {
            switch (NormalizeArchiveId(value))
            {
                case "explosivefastball": return "폭발하는 포심";
                case "pinpointedge": return "바늘끝 제구";
                case "disappearingbreaker": return "사라지는 변화구";
                case "ironarm": return "강철 어깨";
                case "calmunderpressure": return "위기 속 평정";
                case "batterysync": return "배터리 호흡";
                case "risingfourseam": return "떠오르는 포심";
                case "sinkertunnel": return "싱커 터널";
                case "frozenchangeup": return "얼어붙는 체인지업";
                case "sweepingslider": return "가로지르는 슬라이더";
                case "curveballclock": return "커브 타이밍";
                case "repeatablerelease": return "한결같은 손끝";
                case "pickoffrhythm": return "견제 리듬";
                case "twostrikeplan": return "투 스트라이크 설계";
                case "firstpitchstrike": return "초구 스트라이크";
                case "trafficcontroller": return "주자 통제";
                case "lateinningreserve": return "후반의 여력";
                case "scoutcomposure": return "스카우트 앞 평정";
                default: return "기록된 각성";
            }
        }

        private static string MemoryArchiveTitle(string value)
        {
            switch (NormalizeArchiveId(value))
            {
                case "velocityblueprint": return "구속 설계도";
                case "fingertipmemory": return "손끝의 기억";
                case "catchernotebook": return "포수의 노트";
                case "rivalnotebook": return "라이벌 노트";
                case "recoveryroutine": return "회복 루틴";
                case "pressurerehearsal": return "압박 리허설";
                case "firstpitchmap": return "초구 지도";
                case "twostrikesequence": return "투 스트라이크 배합";
                case "fatiguediary": return "피로 일지";
                case "mechanicsvideo": return "투구 동작 영상";
                case "schoolplaybook": return "학교 작전 노트";
                case "coachletter": return "감독의 편지";
                case "draftreport": return "드래프트 보고서";
                case "stadiumecho": return "구장의 메아리";
                case "teamfirstpromise": return "팀 우선의 약속";
                case "failurescorebook": return "실패의 스코어북";
                case "winterprogram": return "겨울 프로그램";
                case "bullpencompass": return "불펜 나침반";
                default: return "기록된 기억";
            }
        }

        private static string NormalizeArchiveId(string value) =>
            (value ?? string.Empty).ToLowerInvariant().Replace("_", string.Empty).Replace("-", string.Empty);

        private static IReadOnlyList<ScreenSectionViewModel> WeeklySections(WeeklyProgressState weekly)
        {
            var result = new List<ScreenSectionViewModel>();
            WeeklyProgramState program = weekly?.Program;
            if (program != null)
                result.Add(new ScreenSectionViewModel("weekly-tasks", "이번 주 세 가지 과제", ScreenSectionTone.Information,
                    program.Tasks.Select((task, index) => new ScreenRowViewModel(
                        "weekly-task-" + index,
                        WeeklyTaskTitle(task.Kind),
                        Math.Min(task.Progress, task.Target) + "/" + task.Target,
                        task.IsCompleted ? "완료" : "진행 중")).ToArray()));
            if (weekly?.Stamps?.Count > 0)
                result.Add(new ScreenSectionViewModel("weekly-stamps", "주간 스탬프", ScreenSectionTone.Positive,
                    weekly.Stamps.Select((stamp, index) => new ScreenRowViewModel(
                        "weekly-stamp-" + index,
                        stamp.WeekKey,
                        stamp.CompletedTaskCount + "개 완료",
                        stamp.Perfect ? "완벽한 한 주" : "보상 획득")).ToArray()));
            if (result.Count == 0)
                result.Add(EmptySection("weekly-empty", "이번 주", "주간 과제를 준비하는 중입니다. 잠시 후 다시 열어 주세요."));
            return result;
        }

        private static IReadOnlyList<ScreenSectionViewModel> SettingsSections(GameSaveAggregate state)
        {
            var result = new List<ScreenSectionViewModel>();
            int archivedLife = state.Meta.LifeArchive.Count == 0
                ? 0
                : state.Meta.LifeArchive.Max(value => value?.LifeNumber ?? 0);
            int currentLife = state.HighSchool?.LifeNumber ?? state.Meta.LifeNumber;
            int nextLife = Math.Max(Math.Max(currentLife, archivedLife), state.Meta.LifeNumber) + 1;
            string memories = state.Meta.InheritedMemories.Count == 0
                ? "상속된 기억 없음"
                : string.Join(" · ", state.Meta.InheritedMemories.Select(MemoryArchiveTitle));
            string signature = string.IsNullOrWhiteSpace(state.Meta.EquippedSignatureLegacyId)
                ? "장착한 대표 유산 없음"
                : state.Meta.LifeArchive
                    .Select(value => value?.SignatureLegacy)
                    .FirstOrDefault(value => value != null && string.Equals(
                        value.Id,
                        state.Meta.EquippedSignatureLegacyId,
                        StringComparison.Ordinal))?.Title ?? "보관된 대표 유산 장착 중";
            result.Add(new ScreenSectionViewModel(
                "settings-inheritance",
                "다음 선수와 계승",
                ScreenSectionTone.Information,
                new[]
                {
                    new ScreenRowViewModel(
                        "settings-next-player",
                        "다음 선수",
                        nextLife + "번째 야구 인생",
                        state.Meta.NextRunIntent == null
                            ? "다음 회차 목표는 결산 화면에서 정할 수 있습니다."
                            : (state.Meta.NextRunIntent.PledgeTitle ?? "저장된 다음 회차 목표") +
                              " · " + state.Meta.NextRunIntent.Reason),
                    new ScreenRowViewModel(
                        "settings-inherited-memories",
                        "상속 기억",
                        memories,
                        "저장된 기억은 새 선수 만들기에서 자동으로 적용됩니다."),
                    new ScreenRowViewModel(
                        "settings-signature-legacy",
                        "대표 유산",
                        signature,
                        "잠금 해제하고 장착한 대표 유산만 다음 선수에게 이어집니다."),
                    new ScreenRowViewModel(
                        "settings-soul",
                        "야구혼",
                        "보유 " + state.Meta.SoulBalance + " · 누적 " + state.Meta.SoulLifetimeEarned,
                        "다음 시작 자동 계승 " + state.Meta.AutomaticSoulEarned)
                }));

            var progress = new List<ScreenRowViewModel>();
            if (state.HighSchool != null)
            {
                progress.Add(new ScreenRowViewModel(
                    "settings-high-school-progress",
                    "고교 커리어",
                    state.HighSchool.SchoolYear + "학년 · " + HighSchoolPhaseName(state.HighSchool.Phase),
                    state.HighSchool.SchoolName ?? "학교 선택 전"));
            }
            if (state.Pro != null)
            {
                progress.Add(new ScreenRowViewModel(
                    "settings-pro-progress",
                    "프로 커리어",
                    state.Pro.Season + "시즌 " + state.Pro.Week + "주 · " + ProRoleName(state.Pro.Role),
                    (state.Pro.TeamName ?? "가상 구단") + " · " + (state.Pro.SeasonSegmentTitle ?? "현재 일정")));
            }
            if (progress.Count == 0)
                progress.Add(new ScreenRowViewModel(
                    "settings-career-empty",
                    "현재 커리어",
                    "새 선수 시작 전",
                    "선수 만들기에서 첫 야구 인생을 시작할 수 있습니다."));
            result.Add(new ScreenSectionViewModel(
                "settings-progress",
                "현재 진행",
                ScreenSectionTone.Plain,
                progress));

            CareerShareCode code = CareerShareCodePolicy.Project(state);
            result.Add(new ScreenSectionViewModel(
                "settings-share-code",
                "현재 판 공유 코드",
                ScreenSectionTone.Milestone,
                new[]
                {
                    new ScreenRowViewModel(
                        "settings-share-code-value",
                        code == null ? "공유할 판 없음" : code.Mode,
                        code?.Code ?? "커리어를 시작하면 코드가 만들어집니다.",
                        code == null
                            ? "선수 이름이나 익명 설치 식별자는 공유하지 않습니다."
                            : "이 코드에는 선수 이름이나 익명 설치 식별자가 들어가지 않습니다.")
                }));
            result.Add(new ScreenSectionViewModel(
                "settings-reset",
                "저장 데이터 초기화",
                ScreenSectionTone.Warning,
                new[]
                {
                    new ScreenRowViewModel(
                        "settings-reset-detail",
                        "모든 야구 인생과 설정 삭제",
                        "초기화는 되돌릴 수 없습니다.",
                        "저장 삭제와 새 익명 식별자 교체가 함께 성공할 때만 적용됩니다.")
                }));
            return result;
        }

        private static string HighSchoolPhaseName(HighSchoolPhase phase)
        {
            switch (phase)
            {
                case HighSchoolPhase.Prologue: return "프롤로그";
                case HighSchoolPhase.SchoolSelection: return "학교 선택";
                case HighSchoolPhase.Training: return "훈련";
                case HighSchoolPhase.Relationship: return "관계 이야기";
                case HighSchoolPhase.ImportantGame: return "중요 경기";
                case HighSchoolPhase.Awakening: return "각성";
                case HighSchoolPhase.ChapterReview: return "장 결산";
                case HighSchoolPhase.Draft: return "드래프트";
                case HighSchoolPhase.Completed: return "고교 3년 완료";
                case HighSchoolPhase.Legacy: return "대표 유산 선택";
                default: return "현재 일정";
            }
        }

        private static ScreenRowViewModel GameLineRow(string prefix, CareerGameLineReadModel line, int index) =>
            new ScreenRowViewModel(
                prefix + "-game-" + index,
                line.Season + "시즌 " + line.Week + "주 · " + (line.Started ? "선발" : "구원"),
                line.Played
                    ? Innings(line.Outs) + "이닝 · 탈삼진 " + line.Strikeouts + " · 실점 " + line.RunsAllowed
                    : "등판 없음",
                line.Played
                    ? "투구 " + line.Pitches + " · 볼넷 " + line.Walks + " · 피안타 " + line.Hits +
                        " · 팀 " + line.TeamRuns + ":" + line.OpponentRuns
                    : "이번 일정에는 등판하지 않았습니다.");

        private static ScreenSectionViewModel EmptySection(string id, string heading, string message) =>
            new ScreenSectionViewModel(id, heading, ScreenSectionTone.Information,
                new[] { new ScreenRowViewModel(id + "-message", "안내", message) });

        private static string Innings(int outs) => (outs / 3) + "." + Math.Abs(outs % 3);

        private static string AchievementTitle(string id)
        {
            switch (id)
            {
                case AchievementIds.FirstDraft: return "첫 지명";
                case AchievementIds.FirstStrikeout: return "첫 탈삼진";
                case AchievementIds.CleanInning: return "무실점 이닝";
                case AchievementIds.PerfectDelivery: return "완벽한 릴리스";
                case AchievementIds.MajorDebut: return "프로 데뷔";
                case AchievementIds.HundredStrikeouts: return "시즌 100탈삼진";
                case AchievementIds.ThirdLife: return "세 번째 인생";
                case AchievementIds.FifthLife: return "다섯 번째 인생";
                case AchievementIds.TenthLife: return "열 번째 인생";
                case AchievementIds.KarmaRun: return "성향을 품은 삶";
                case AchievementIds.DoubleKarma: return "두 성향의 균형";
                case AchievementIds.AwakenedThrice: return "세 번의 각성";
                case AchievementIds.FourSchools: return "네 학교의 기억";
                case AchievementIds.FiveDrafts: return "다섯 번의 지명";
                case AchievementIds.HallOfFame: return "전설의 투수";
                default: return "숨겨진 업적";
            }
        }

        private static string AchievementCondition(string id)
        {
            switch (id)
            {
                case AchievementIds.FirstDraft: return "처음으로 드래프트 지명을 받으세요.";
                case AchievementIds.FirstStrikeout: return "직접 경기에서 탈삼진을 기록하세요.";
                case AchievementIds.CleanInning: return "한 경기 구간을 무실점으로 막으세요.";
                case AchievementIds.PerfectDelivery: return "직접 릴리스와 코스를 모두 정확히 맞히세요.";
                case AchievementIds.MajorDebut: return "가상 프로 리그에서 첫 시즌을 시작하세요.";
                case AchievementIds.HundredStrikeouts: return "한 시즌 100탈삼진을 기록하세요.";
                case AchievementIds.ThirdLife: return "세 번째 야구 인생을 시작하세요.";
                case AchievementIds.FifthLife: return "다섯 번째 야구 인생을 시작하세요.";
                case AchievementIds.TenthLife: return "열 번째 야구 인생을 시작하세요.";
                case AchievementIds.KarmaRun: return "성향을 지닌 인생을 완주하세요.";
                case AchievementIds.DoubleKarma: return "두 가지 성향을 지닌 인생을 완주하세요.";
                case AchievementIds.AwakenedThrice: return "한 인생에서 세 번 각성하세요.";
                case AchievementIds.FourSchools: return "서로 다른 네 학교의 삶을 기록하세요.";
                case AchievementIds.FiveDrafts: return "다섯 번 드래프트 지명을 받으세요.";
                case AchievementIds.HallOfFame: return "명예 점수 70을 달성하세요.";
                default: return "커리어를 이어가며 조건을 찾아보세요.";
            }
        }

        private static string WeeklyTaskTitle(string kind)
        {
            switch (kind)
            {
                case WeeklyTaskKinds.PlayedOnTwoDays: return "서로 다른 이틀에 플레이";
                case WeeklyTaskKinds.ImportantGamesCompleted: return "중요 경기 완료";
                case WeeklyTaskKinds.ChaptersAdvanced: return "고교 이야기 전진";
                case WeeklyTaskKinds.NextRunStarted: return "다음 인생 시작";
                case WeeklyTaskKinds.PledgeSelected: return "이번 인생의 다짐 선택";
                case WeeklyTaskKinds.DifferentSchoolSelected: return "다른 학교 선택";
                case WeeklyTaskKinds.SequenceMasteryTriggered: return "수싸움 성장 발동";
                case WeeklyTaskKinds.ProWeeksAdvanced: return "프로 주간 일정 진행";
                default: return "주간 과제";
            }
        }

        private static string ProRoleName(string role)
        {
            switch ((role ?? string.Empty).ToLowerInvariant())
            {
                case "starter": return "선발 투수";
                case "reliever": return "구원 투수";
                case "closer": return "마무리 투수";
                default: return "투수진 경쟁";
            }
        }

        private ScreenRowViewModel ProjectRow(
            ShellRoute route,
            ScreenRowViewModel row,
            GameSaveAggregate state)
        {
            LifeArchiveRecord latestLife = SelectedLifeRecord(state);
            PitcherRatingsReadModel ratings = state.Pro?.Ratings ?? state.HighSchool?.Ratings ?? latestLife?.FinalRatings;
            CareerPerformanceReadModel performance = state.Pro?.CurrentSeason ?? state.HighSchool?.Performance ?? latestLife?.HighSchoolPerformance;
            string value = row.Value;
            switch (row.Id)
            {
                case "fastball": value = ratings == null ? "능력 기록 없음" : ratings.Stuff.ToString(); break;
                case "control": value = ratings == null ? "능력 기록 없음" : ratings.Command.ToString(); break;
                case "movement": value = ratings == null ? "능력 기록 없음" : ratings.Movement.ToString(); break;
                case "stamina": value = ratings == null ? "능력 기록 없음" : ratings.Stamina.ToString(); break;
                case "games": value = performance == null ? "0" : performance.ImportantGames.ToString(); break;
                case "strikeouts": value = performance == null ? "0" : performance.Strikeouts.ToString(); break;
                case "walks": value = performance == null ? "0" : performance.Walks.ToString(); break;
                case "runs": value = performance == null ? "0" : performance.RunsAllowed.ToString(); break;
                case "chapter": value = state.HighSchool == null ? "고교 커리어 시작 전" : state.HighSchool.SchoolYear + "학년 · " + state.HighSchool.ChapterNumber + "장"; break;
                case "health":
                    if (state.HighSchool != null)
                    {
                        value = "피로 " + state.HighSchool.Fatigue + " · 팔 부담 " + state.HighSchool.ArmRisk;
                        return new ScreenRowViewModel(row.Id, row.Label, value,
                            state.HighSchool.InjuryRecovery > 0
                                ? "부상 회복까지 " + state.HighSchool.InjuryRecovery + " 일정"
                                : "현재 부상 회복 일정은 없습니다.");
                    }
                    if (state.Pro != null) value = "피로 " + state.Pro.Fatigue;
                    else value = "커리어 시작 전";
                    break;
                case "opportunity": value = state.HighSchool == null
                    ? "고교 일정 시작 전"
                    : "중요 경기 " + state.HighSchool.RemainingImportantGames + "회 · 장 진행 " +
                      state.HighSchool.RemainingChapterAdvances + "회"; break;
                case "school_choice": value = state.HighSchool?.SchoolName ?? "아직 선택하지 않음"; break;
                case "remaining": value = state.HighSchool == null ? "0" : state.HighSchool.RemainingImportantGames.ToString(); break;
                case "club": value = state.Pro?.TeamName ?? state.HighSchool?.Draft?.TeamName ?? "아직 정해지지 않음"; break;
                case "week": value = state.Pro == null ? "프로 커리어 시작 전" : state.Pro.Season + "시즌 " + state.Pro.Week + "주"; break;
                case "condition": value = state.Pro == null ? "프로 커리어 시작 전" : "피로 " + state.Pro.Fatigue; break;
                case "role": value = state.Pro == null ? "보직 미정" : ProRoleName(state.Pro.Role); break;
                case "recent_result":
                    CareerGameLineReadModel recent = state.Pro?.RecentGameLines.LastOrDefault(line => line.Played);
                    value = recent == null
                        ? "아직 이번 시즌 등판 기록이 없습니다."
                        : InningsTitle(recent.Outs) +
                          "이닝 · " + recent.Strikeouts + "탈삼진 · " + recent.RunsAllowed + "실점";
                    break;
                case "season_record": value = state.Pro == null
                    ? "시즌 기록 없음"
                    : state.Pro.CurrentSeason.ImportantGames + "경기 · " + state.Pro.CurrentSeason.Strikeouts +
                      "탈삼진 · " + state.Pro.CurrentSeason.RunsAllowed + "실점"; break;
                case "award": value = state.Pro == null ? "수상 기록 없음" : state.Pro.Awards + "회"; break;
                case "career_games": value = state.Pro == null
                    ? "0"
                    : (state.Pro.CurrentSeason.ImportantGames + state.Pro.CareerSeasons.Sum(line => line.Games)).ToString(); break;
                case "seasons": value = state.Pro == null ? "0" : state.Pro.CareerSeasons.Count.ToString(); break;
                case "career_strikeouts": value = state.Pro == null ? "0" : state.Pro.CareerStrikeouts.ToString(); break;
                case "career_record": value = state.Pro == null
                    ? "프로 기록 없음"
                    : state.Pro.CareerStrikeouts + "탈삼진 · " + state.Pro.Awards + "수상"; break;
                case "hall": value = state.Pro == null ? "0" : state.Pro.HallOfFameScore.ToString(); break;
                case "players": value = state.Meta.LifeArchive.Count.ToString(); break;
                case "legacies": value = state.Meta.InheritedMemories.Count.ToString(); break;
                case "unlocked": value = state.Meta.Achievements.Unlocked.Count.ToString(); break;
                case "player_name": value = latestLife?.PlayerName ?? "기록 없음"; break;
                case "soul": value = state.Meta.SoulBalance.ToString(); break;
                case "player": value = route == ShellRoute.LifeCard
                    ? latestLife?.PlayerName ?? "기록 없음"
                    : state.Pro?.PlayerName ?? state.HighSchool?.PlayerName ?? latestLife?.PlayerName ?? "기록 없음"; break;
                case "evaluation_detail": value = state.HighSchool?.Draft?.EvaluationScore.ToString() ?? "아직 평가 전"; break;
                case "forecast": value = state.HighSchool?.Draft?.Resolved == true
                    ? state.HighSchool.Draft.Drafted ? "지명" : "미지명"
                    : "결과 대기"; break;
                case "result_detail": value = state.HighSchool?.Draft?.Resolved == true
                    ? state.HighSchool.Draft.Drafted
                        ? (state.HighSchool.Draft.TeamName ?? "가상 구단") + " 지명"
                        : "미지명"
                    : "결과 대기"; break;
                case "record": value = performance == null
                    ? "기록 없음"
                    : "탈삼진 " + performance.Strikeouts + " · 볼넷 " + performance.Walks + " · 실점 " + performance.RunsAllowed; break;
                case "stamp_status": value = state.Meta.Weekly.Program == null
                    ? "프로그램 준비 전"
                    : state.Meta.Weekly.Program.CompletedCount + "/" + state.Meta.Weekly.Program.Tasks.Count; break;
                case "drafted": value = state.Meta.LifeArchive.Count(record => record.Drafted).ToString(); break;
                case "awakenings": value = state.HighSchool?.Awakenings.Count.ToString() ?? "0"; break;
                case "detail" when route == ShellRoute.Opening:
                    return row;
                default:
                    return null;
            }
            string detail = row.Detail;
            if (route == ShellRoute.Prologue && state.HighSchool?.Phase == HighSchoolPhase.Prologue)
            {
                string talentAbilityId = string.Equals(row.Id, "fastball", StringComparison.Ordinal)
                    ? "stuff"
                    : row.Id;
                TalentGradeReadModel talent = state.HighSchool.LifeDetail?.Talents?
                    .FirstOrDefault(candidate => string.Equals(candidate.AbilityId, talentAbilityId, StringComparison.Ordinal));
                if (talent != null) detail = "재능 " + talent.GradeTitle;
            }
            return new ScreenRowViewModel(row.Id, row.Label, value, detail);
        }

        private static string InningsTitle(int outs)
        {
            int safeOuts = Math.Max(0, outs);
            switch (safeOuts % 3)
            {
                case 1: return safeOuts / 3 + "⅓";
                case 2: return safeOuts / 3 + "⅔";
                default: return (safeOuts / 3).ToString();
            }
        }

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

        public static LifeArchiveRecord CurrentLifeArchiveFor(GameSaveAggregate state)
        {
            if (state?.Meta?.LifeArchive == null) return null;
            int lifeNumber = state.HighSchool?.LifeNumber ?? state.Meta.LifeNumber;
            return state.Meta.LifeArchive.FirstOrDefault(record =>
                record != null && record.LifeNumber == lifeNumber);
        }

        private static bool HasCurrentLifeArchive(GameSaveAggregate state) =>
            CurrentLifeArchiveFor(state) != null;

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

        private static ShellRoute RouteForPlanner(string route, ShellRoute fallback)
        {
            switch ((route ?? string.Empty).ToLowerInvariant())
            {
                case "opening": return ShellRoute.Opening;
                case "setup": return ShellRoute.Setup;
                case "high-school": return ShellRoute.HighSchoolOverview;
                case "pro": return ShellRoute.ProWeek;
                case "retirement": return ShellRoute.ProRetirement;
                case "legacy": return ShellRoute.RunRecap;
                case "pitch/resume":
                case "pitch/result": return ShellRoute.PitchHandoff;
                default: return fallback;
            }
        }

        private static IReadOnlyList<ScreenActionViewModel> Actions(params ScreenActionViewModel[] values) => values;
    }
}
