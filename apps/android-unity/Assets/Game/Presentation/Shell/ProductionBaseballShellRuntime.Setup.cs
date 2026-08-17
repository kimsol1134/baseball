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
        public void RetryStartup()
        {
            _ = RetryStartupAsync(CancellationToken.None);
        }

        private async Task<ShellActionResult> RetryStartupAsync(
            CancellationToken cancellationToken)
        {
            if (RuntimeGameServices.TryGetStore(out GameApplicationStore ready))
            {
                OnReady(ready);
                return ShellActionResult.Success(PreferredRoute, "저장 상태를 다시 불러왔습니다.");
            }
            _status = ShellRuntimeStatus.Loading;
            _statusMessage = "저장 상태를 다시 확인하고 있습니다.";
            Changed?.Invoke();
            try
            {
                await AppRoot.RetryInitializationAsync(cancellationToken);
                if (!RuntimeGameServices.TryGetStore(out ready))
                    throw new InvalidOperationException("runtime.retry_completed_without_store");
                OnReady(ready);
                return ShellActionResult.Success(PreferredRoute, "저장 상태를 다시 불러왔습니다.");
            }
            catch (OperationCanceledException)
            {
                return ShellActionResult.Failure("재시도를 취소했습니다. 준비가 되면 다시 눌러 주세요.");
            }
            catch (Exception exception)
            {
                if (_status != ShellRuntimeStatus.StartupFailed)
                    OnStartupFailed(exception);
                return ShellActionResult.Failure(_statusMessage);
            }
        }

        public void SetPlayerName(string value)
        {
            if (SetupPlayerNamePolicy.TryUpdate(_playerName, value, out string next))
            {
                _playerName = next;
            }
        }

        public void SetSetupStep(int value)
        {
            int maximum = SetupOptions?.AdvancedOptionsVisible == true ? 3 : 2;
            int next = Math.Max(0, Math.Min(maximum, value));
            if (_setupStep == next) return;
            _setupStep = next;
            Changed?.Invoke();
        }

        public void DiscardTransientDraft(ShellRoute route)
        {
            GameSaveAggregate state = _store?.Current;
            if (state == null) return;
            if (route == ShellRoute.Setup)
                UpdateSetupDraftProjection(state, true);
            else
                UpdateCareerChoiceDraftProjection(state, true);
        }

        public bool TryTakeTrainingCelebration(out TrainingCelebrationViewModel celebration)
        {
            celebration = _pendingTrainingCelebration;
            _pendingTrainingCelebration = null;
            return celebration != null;
        }

        private void QueueTrainingCelebration(
            string actionId,
            GameSaveAggregate before,
            GameSaveAggregate after)
        {
            TrainingCelebrationViewModel celebration =
                TrainingCelebrationPolicy.Project(actionId, before, after);
            if (celebration == null) return;
            _pendingTrainingCelebration = celebration;
            _pitchFeedback.PlayMilestone();
            _haptics.Pulse(celebration.Jackpot
                ? HapticCue.CriticalMoment
                : HapticCue.Selection);
        }

        public void SetRegion(string value)
        {
            if (HighSchoolSetupCatalog.Regions.Any(option =>
                    string.Equals(option.Payload, value, StringComparison.Ordinal)))
            {
                _region = value;
            }
        }

        public void SetPresetId(string value)
        {
            if (HighSchoolSetupCatalog.Presets.Any(option =>
                    string.Equals(option.Payload, value, StringComparison.Ordinal)))
            {
                _presetId = value;
            }
        }

        public void SetSeedInput(string value)
        {
            _seedInput = (value ?? string.Empty).Trim();
            _seedValidationMessage = SetupSeedInputPolicy.ValidationMessage(_seedInput);
        }

        public void SetSetupSingle(string group, string payload)
        {
            string value = payload ?? string.Empty;
            switch (group)
            {
                case "difficulty":
                    if (SetupOptions.Difficulties.Any(option => option.Payload == value)) _setupDifficulty = value;
                    break;
                case "soul_domain":
                    if (SetupOptions.AutomaticSoul > 0 &&
                        SetupOptions.SoulDomains.Any(option => option.Payload == value))
                        _setupSoulDomain = value;
                    break;
                case "signature":
                    if (SetupOptions.SignatureLegacies.Any(option => option.Payload == value))
                        _setupSignatureLegacy = value;
                    break;
            }
            Changed?.Invoke();
        }

        public void ToggleSetupMulti(string group, string payload)
        {
            if (string.IsNullOrWhiteSpace(payload)) return;
            switch (group)
            {
                case "karma":
                    ToggleBounded(_setupKarmas, payload, SetupOptions.Karmas, 2);
                    break;
                case "soul_boost":
                    if (_setupSoulBoosts.Contains(payload)) _setupSoulBoosts.Remove(payload);
                    else if (SetupOptions.SoulBoosts.Any(option => option.Payload == payload))
                    {
                        var candidate = _setupSoulBoosts.Concat(new[] { payload }).ToArray();
                        if (HighSchoolSetupCatalog.SoulBoostCost(candidate) <= SetupOptions.SoulBalance)
                            _setupSoulBoosts.Add(payload);
                        else
                            _seedValidationMessage = "선택한 야구혼 강화의 합계가 보유 야구혼보다 큽니다.";
                    }
                    break;
            }
            Changed?.Invoke();
        }

        public bool IsSetupSelected(string group, string payload)
        {
            switch (group)
            {
                case "difficulty": return string.Equals(_setupDifficulty, payload, StringComparison.Ordinal);
                case "soul_domain": return string.Equals(_setupSoulDomain, payload, StringComparison.Ordinal);
                case "signature": return string.Equals(_setupSignatureLegacy, payload, StringComparison.Ordinal);
                case "karma": return _setupKarmas.Contains(payload);
                case "memory": return SetupMemories.Contains(payload, StringComparer.Ordinal);
                case "soul_boost": return _setupSoulBoosts.Contains(payload);
                default: return false;
            }
        }

        public string GetChoice(string group) =>
            _careerChoices.TryGetValue(group ?? string.Empty, out string value) ? value : string.Empty;

        public void SetChoice(string group, string payload)
        {
            if (string.IsNullOrWhiteSpace(group) || string.IsNullOrWhiteSpace(payload)) return;
            _careerChoices[group] = payload;
            Changed?.Invoke();
        }

        public IReadOnlyList<string> GetChoices(string group)
        {
            return _careerMultiChoices.TryGetValue(group ?? string.Empty, out HashSet<string> values)
                ? values.OrderBy(value => value, StringComparer.Ordinal).ToArray()
                : Array.Empty<string>();
        }

        public void ToggleChoice(string group, string payload, int maximumSelections)
        {
            if (string.IsNullOrWhiteSpace(group) || string.IsNullOrWhiteSpace(payload)) return;
            if (!_careerMultiChoices.TryGetValue(group, out HashSet<string> values))
            {
                values = new HashSet<string>(StringComparer.Ordinal);
                _careerMultiChoices[group] = values;
            }
            if (!values.Remove(payload) && (maximumSelections < 1 || values.Count < maximumSelections)) values.Add(payload);
            Changed?.Invoke();
        }

        public bool IsChoiceSelected(string group, string payload) =>
            _careerMultiChoices.TryGetValue(group ?? string.Empty, out HashSet<string> values) && values.Contains(payload);

        private static void ToggleBounded(
            HashSet<string> selected,
            string payload,
            IReadOnlyList<Baseball.Application.Commands.CareerChoiceReadModel> allowed,
            int maximum)
        {
            if (selected.Remove(payload)) return;
            if (selected.Count >= maximum) return;
            if (allowed == null || allowed.Any(option => option.Enabled && option.Payload == payload)) selected.Add(payload);
        }

        public void SetAutoRelease(bool enabled) =>
            UpdateSettings(new UpdateGameSettingsCommand(autoReleaseEnabled: enabled), "자동 릴리스");

        public void SetSoundEnabled(bool enabled)
        {
            UpdateSettings(new UpdateGameSettingsCommand(soundEnabled: enabled), "효과음");
        }

        public void SetMusicEnabled(bool enabled)
        {
            UpdateSettings(new UpdateGameSettingsCommand(musicEnabled: enabled), "음악");
        }

        public void SetHapticsEnabled(bool enabled)
        {
            UpdateSettings(new UpdateGameSettingsCommand(hapticsEnabled: enabled), "진동");
        }

        public void SetNotificationsEnabled(bool enabled)
        {
            if (AndroidReminderService.Instance?.IsInstallBound != true)
            {
                _statusMessage = NotificationsUnavailableReason;
                Changed?.Invoke();
                return;
            }
            _statusMessage = enabled
                ? "복귀 알림 권한을 확인하고 있습니다."
                : "복귀 알림을 끄고 있습니다.";
            Changed?.Invoke();
            AndroidReminderService.Instance.RequestEnabled(enabled);
        }

        public void OpenNotificationSettings()
        {
            AndroidReminderService.Instance?.OpenSystemSettings();
        }

        public void SetHighContrast(bool enabled) =>
            UpdateSettings(new UpdateGameSettingsCommand(highContrastEnabled: enabled), "고대비");
        public void SetReducedMotion(bool enabled) =>
            UpdateSettings(new UpdateGameSettingsCommand(reducedMotionEnabled: enabled), "동작 줄이기");

        public void OnRouteChanged(ShellRoute route)
        {
            GameSaveAggregate state = _store?.Current;
            CrashReporting.SetContext(new CrashContext(
                _crashDistribution,
                state?.AggregateVersion ?? 0,
                state?.Revision ?? 0,
                route.ToString().ToLowerInvariant(),
                CrashRuntimeDiagnostics.PitchStageLoaded,
                CurrentPitchQualityTier()));
            if (route == ShellRoute.Weekly)
            {
                ObserveWeeklyProgram();
                if (!WeeklyOpenAnalyticsPolicy.CanEmit(
                        _store?.Current?.Meta?.Weekly?.Program,
                        _weeklyObserveInFlight))
                {
                    return;
                }
                state = _store?.Current;
            }
            else _weeklyObservedRevision = null;
            ObserveRouteAnalytics(route, state);
            if (route == ShellRoute.ProContract &&
                ReviewMomentPolicy.ShouldRequestDraftedAtContract(state))
            {
                TryRequestReview(ReviewPromptReason.Drafted);
            }
        }
    }
}
