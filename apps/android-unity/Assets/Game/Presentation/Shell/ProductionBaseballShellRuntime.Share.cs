using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Baseball.Application.Commands;
using Baseball.Application.HighSchool;
using Baseball.Application.Meta;
using Baseball.Application.Persistence;
using Baseball.Application.Pro;
using Baseball.Application.Stores;
using Baseball.Bootstrap;
using Baseball.Core.Catalogs;
using Baseball.Platform.Analytics;
using Baseball.Platform.Configuration;
using Baseball.Platform.Crash;
using Baseball.Platform.Haptics;
using Baseball.Platform.Identity;
using Baseball.Platform.Notifications;
using Baseball.Platform.Review;
using Baseball.Platform.Share;
using Baseball.Presentation.Pitch;
using UnityEngine;

namespace Baseball.Presentation.Shell
{
    public sealed partial class ProductionBaseballShellRuntime
    {
        public Task<ShellActionResult> ShareLifeCardAsync(
            byte[] pngBytes,
            CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();
            LifeArchiveRecord life = SelectedLifeRecordForUi(_store.Current);
            string text = LifeCardShareCopy.Build(life);
            bool imageOpened = pngBytes != null && AndroidShareService.TrySharePng(
                "라이프 카드 공유",
                pngBytes,
                "life-card.png",
                text);
            bool textOpened = !imageOpened && AndroidShareService.TryShareText("라이프 카드 공유", text);
            if (imageOpened || textOpened)
            {
                SafeLog(
                    AnalyticsEvent.LifeCardShareTapped,
                    new Dictionary<string, object>(StringComparer.Ordinal)
                    {
                        ["life_number"] = life?.LifeNumber ?? _store.Current.Meta.LifeNumber,
                    });
            }
            return Task.FromResult(imageOpened || textOpened
                ? ShellActionResult.Success(null, imageOpened
                    ? "선수 카드 이미지 공유 화면을 열었습니다."
                    : "이미지를 만들지 못해 텍스트 공유 화면을 열었습니다.")
                : ShellActionResult.Failure("이 기기에서 공유 화면을 열지 못했습니다."));
        }

        private ShellActionResult ShareCareerCode(CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();
            CareerShareCode code = CareerShareCodePolicy.Project(_store?.Current);
            string text = CareerShareCodePolicy.ShareText(code);
            if (string.IsNullOrWhiteSpace(text))
                return ShellActionResult.Failure("공유할 현재 커리어 코드가 없습니다.");
            return AndroidShareService.TryShareText("현재 판 코드 공유", text)
                ? ShellActionResult.Success(null, "현재 판 코드 공유 화면을 열었습니다.")
                : ShellActionResult.Failure("이 기기에서 공유 화면을 열지 못했습니다.");
        }

        private LifeArchiveRecord SelectedLifeRecordForUi(GameSaveAggregate state)
        {
            IReadOnlyList<LifeArchiveRecord> archive = state?.Meta?.LifeArchive;
            if (archive == null || archive.Count == 0) return null;
            string selected = GetChoice("archive_life");
            if (int.TryParse(selected, out int lifeNumber))
            {
                LifeArchiveRecord exact = archive.FirstOrDefault(value =>
                    value != null && value.LifeNumber == lifeNumber);
                if (exact != null) return exact;
            }
            return archive.Where(value => value != null)
                .OrderByDescending(value => value.LifeNumber)
                .FirstOrDefault();
        }

        private static string StartupFailureMessage(Exception exception)
        {
            string code = exception?.Message ?? string.Empty;
            if (code.Contains("future_version")) return "더 최신 버전에서 만든 저장입니다. 앱을 업데이트한 뒤 다시 시도해 주세요.";
            if (code.Contains("migration")) return "저장 데이터를 변환하지 못했습니다. 앱을 다시 연 뒤 재시도해 주세요.";
            return "저장 데이터를 불러오지 못했습니다. 기존 파일은 보존되어 있으며 다시 시도할 수 있습니다.";
        }

        private static string KoreanFailure(DispatchResult<GameSaveAggregate> result)
        {
            switch (result.Status)
            {
                case DispatchStatus.StaleRevision: return "진행 상태가 바뀌었습니다. 화면을 확인한 뒤 다시 눌러 주세요.";
                case DispatchStatus.PersistenceFailed: return "기기에 저장하지 못했습니다. 이동하지 않았으니 다시 시도해 주세요.";
                case DispatchStatus.Cancelled: return "작업을 취소했습니다. 저장 상태는 바뀌지 않았습니다.";
                default: return "현재 진행 상태에서는 이 행동을 할 수 없습니다.";
            }
        }

        private async void UpdateSettings(
            UpdateGameSettingsCommand command,
            string label)
        {
            if (_store == null || _status != ShellRuntimeStatus.Ready)
            {
                _statusMessage = label + " 설정은 저장 데이터를 불러온 뒤 변경할 수 있습니다.";
                Changed?.Invoke();
                return;
            }
            if (_store.IsBusy)
            {
                _statusMessage = "다른 저장 작업이 끝난 뒤 " + label + " 설정을 다시 눌러 주세요.";
                Changed?.Invoke();
                return;
            }

            GameSaveAggregate before = _store.Current;
            string commandId = "settings:" + before.Revision + ":" + (++_commandSequence);
            try
            {
                DispatchResult<GameSaveAggregate> result = await _store.DispatchAsync(
                    new CommandEnvelope<GameCommand>(commandId, before.Revision, command),
                    CancellationToken.None);
                if (!result.IsSuccess)
                {
                    _statusMessage = label + " 설정을 저장하지 못했습니다. 이전 설정으로 되돌렸습니다.";
                    Changed?.Invoke();
                    return;
                }
                _statusMessage = label + " 설정을 저장했습니다.";
                Changed?.Invoke();
            }
            catch (Exception exception)
            {
                CrashReporting.RecordUnexpected(exception, "settings_update");
                _statusMessage = label + " 설정을 저장하지 못했습니다. 이전 설정으로 되돌렸습니다.";
                Changed?.Invoke();
            }
        }

        private void ApplyPersistedSettings(GameSaveAggregate state)
        {
            GameSettingsState settings = state?.Settings ?? GameSettingsState.Default;
            _pitchFeedback.SoundEnabled = settings.SoundEnabled;
            _pitchFeedback.MusicEnabled = settings.MusicEnabled;
            _haptics.IsEnabled = settings.HapticsEnabled && !settings.ReducedMotionEnabled;
            AndroidReminderService reminders = AndroidReminderService.Instance;
            if (reminders != null)
            {
                if (!reminders.BindInstall(state?.InstallId))
                {
                    reminders.ConfigurePlan(null);
                    reminders.ApplySavedEnabled(false);
                    return;
                }
                ReturnPlanState plan = state?.Meta?.ReturnPlan;
                ReturnPlanState personalized = ReturnPlanPresentationPolicy.PersonalizedNotification(plan);
                AndroidReminderPlan reminderPlan = personalized != null
                    ? new AndroidReminderPlan(
                        personalized.Title,
                        personalized.Body,
                        ReturnPlanRules.Wire(personalized.Destination),
                        personalized.Reason,
                        personalized.ReceiptId,
                        personalized.ExperimentId,
                        personalized.ExperimentVariant,
                        personalized.SavedDayKey,
                        personalized.DevelopmentRulesVersion ?? 0)
                    : null;
                reminders.ConfigurePlan(reminderPlan);
                reminders.ApplySavedEnabled(settings.NotificationsEnabled);
            }
        }

        private void UpdateSetupDraftProjection(GameSaveAggregate state, bool force)
        {
            if (state == null) return;
            int lifeNumber = state.Meta?.LifeNumber ?? 1;
            bool enteringSetup = _setupDraftLifecycle.Observe(
                state.Stage == ApplicationStage.Setup,
                state.InstallId,
                lifeNumber,
                force);
            if (enteringSetup)
            {
                HighSchoolSetupReadModel options = HighSchoolSetupCatalog.For(state.Meta);
                _setupStep = 0;
                _playerName = string.Empty;
                _region = HighSchoolSetupCatalog.Regions.FirstOrDefault()?.Payload ?? "서울";
                _presetId = HighSchoolSetupCatalog.Presets.FirstOrDefault()?.Payload ?? "power_prospect";
                _seedInput = string.Empty;
                _seedValidationMessage = string.Empty;
                _setupDifficulty = "standard";
                _setupKarmas.Clear();
                _setupSoulBoosts.Clear();
                _setupSoulDomain = options.AutomaticSoul > 0 ? "technique" : string.Empty;
                string equipped = state.Meta?.EquippedSignatureLegacyId;
                _setupSignatureLegacy = options.SignatureLegacies.Any(option =>
                    string.Equals(option.Payload, equipped, StringComparison.Ordinal))
                    ? equipped
                    : string.Empty;
            }
        }

        private void UpdateCareerChoiceDraftProjection(GameSaveAggregate state, bool force)
        {
            if (state == null) return;
            if (_careerChoiceDraftLifecycle.Observe(state, force))
            {
                _careerChoices.Clear();
                _careerMultiChoices.Clear();
            }

            HighSchoolCareerReadModel highSchool = state.HighSchool;
            if (state.Stage == ApplicationStage.HighSchool &&
                highSchool?.Phase == HighSchoolPhase.Training)
            {
                ReconcileChoice(
                    "training_focus",
                    highSchool.TrainingFocusChoices,
                    highSchool.LastTraining?.Focus,
                    "command");
                ReconcileChoice(
                    "training_intensity",
                    highSchool.TrainingIntensityChoices,
                    highSchool.LastTraining?.Intensity,
                    "standard");
                ReconcileChoice(
                    "training_pitch",
                    highSchool.TrainingPitchChoices,
                    highSchool.LastTraining?.TargetPitch);
            }

            ProCareerReadModel pro = state.Pro;
            if (state.Stage == ApplicationStage.Pro &&
                pro?.Phase == ProCareerPhase.WeeklyPlan)
            {
                ReconcileChoice("pro_week_plan", pro.WeekPlanChoices, "earn_trust");
                ReconcileChoice(
                    "pro_development_pitch",
                    pro.DevelopmentPitchChoices,
                    pro.LastSegmentProgress?.TargetPitch);
            }
        }

        private void ReconcileChoice(
            string group,
            IReadOnlyList<CareerChoiceReadModel> choices,
            params string[] preferred)
        {
            CareerChoiceReadModel[] enabled = (choices ?? Array.Empty<CareerChoiceReadModel>())
                .Where(option => option.Enabled && !string.IsNullOrWhiteSpace(option.Payload))
                .ToArray();
            if (enabled.Length == 0)
            {
                _careerChoices.Remove(group);
                return;
            }

            if (_careerChoices.TryGetValue(group, out string selected) &&
                enabled.Any(option => string.Equals(
                    option.Payload,
                    selected,
                    StringComparison.Ordinal)))
                return;

            string fallback = (preferred ?? Array.Empty<string>())
                .FirstOrDefault(value => !string.IsNullOrWhiteSpace(value) &&
                    enabled.Any(option => string.Equals(
                        option.Payload,
                        value,
                        StringComparison.Ordinal)));
            _careerChoices[group] = fallback ?? enabled[0].Payload;
        }

        private ShellRoute ReminderDestinationRoute(string destination)
        {
            switch ((destination ?? string.Empty).ToLowerInvariant())
            {
                case "setup": return ShellRoute.Setup;
                case "records": return ShellRoute.Records;
                case "high_school":
                case "pro": return StoreBaseballCareerReadModel.PreferredRouteFor(_store?.Current);
                case "daily_inning":
                    return RetiredDailyFallbackRoute;
                default: return StoreBaseballCareerReadModel.PreferredRouteFor(_store?.Current);
            }
        }

        private async void ClearRetiredDailyResume()
        {
            if (_retiredDailyCleanupInFlight || _store == null ||
                _status != ShellRuntimeStatus.Ready || _store.IsBusy) return;
            PitchResumeState resume = _store.Current.PitchResume;
            if (resume?.CareerKind != PitchCareerKind.Daily ||
                string.IsNullOrWhiteSpace(resume.GameId)) return;

            _retiredDailyCleanupInFlight = true;
            GameSaveAggregate before = _store.Current;
            try
            {
                DispatchResult<GameSaveAggregate> result = await _store.DispatchAsync(
                    new CommandEnvelope<GameCommand>(
                        "legacy-pitch-cleanup:" + before.Revision + ":" + (++_commandSequence),
                        before.Revision,
                        new AbandonPitchSessionCommand(resume.GameId)),
                    CancellationToken.None);
                if (!result.IsSuccess)
                    _statusMessage = "이전 버전의 경기 기록은 보존했지만 중단된 진행을 정리하지 못했습니다. 다음 실행에서 다시 확인합니다.";
            }
            catch (Exception exception)
            {
                CrashReporting.RecordUnexpected(exception, "legacy_pitch_cleanup");
                _statusMessage = "이전 버전의 중단된 경기 진행을 정리하지 못했습니다. 현재 커리어는 안전하게 열었습니다.";
            }
            finally
            {
                _retiredDailyCleanupInFlight = false;
                Changed?.Invoke();
            }
        }

        private async void ObserveWeeklyProgram()
        {
            if (_weeklyObserveInFlight || _store == null || _status != ShellRuntimeStatus.Ready || _store.IsBusy)
                return;
            if (_weeklyObservedRevision == _store.Current.Revision) return;
            _weeklyObservedRevision = _store.Current.Revision;
            ConfigureWeeklyProgramCommand command = WeeklyProgramCommandFactory.Observe(
                _store.Current,
                DateTimeOffset.UtcNow);
            if (command == null) return;

            _weeklyObserveInFlight = true;
            _statusMessage = "이번 주 과제를 안전하게 준비하고 있습니다.";
            Changed?.Invoke();
            GameSaveAggregate before = _store.Current;
            try
            {
                DispatchResult<GameSaveAggregate> result = await _store.DispatchAsync(
                    new CommandEnvelope<GameCommand>(
                        "weekly:observe:" + before.Revision + ":" + (++_commandSequence),
                        before.Revision,
                        command),
                    CancellationToken.None);
                _statusMessage = result.IsSuccess
                    ? "이번 주 과제를 준비했습니다."
                    : "이번 주 과제를 저장하지 못했습니다. 잠시 후 다시 열어 주세요.";
            }
            catch (Exception exception)
            {
                CrashReporting.RecordUnexpected(exception, "weekly_observe");
                _statusMessage = "이번 주 과제를 저장하지 못했습니다. 잠시 후 다시 열어 주세요.";
            }
            finally
            {
                _weeklyObserveInFlight = false;
                Changed?.Invoke();
            }
        }

        private static bool SafeLog(
            AnalyticsEvent analyticsEvent,
            IReadOnlyDictionary<string, object> properties)
        {
            try { return AnalyticsBootstrap.Log(analyticsEvent, properties); }
            catch { return false; /* Analytics never blocks durable game progress. */ }
        }
    }
    }
}
