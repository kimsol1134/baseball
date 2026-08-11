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
using Baseball.Core.Pro;
using Baseball.Platform.Analytics;
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
    /// <summary>Production read/write adapter over the durably published application store.</summary>
    public sealed partial class ProductionBaseballShellRuntime : IBaseballShellRuntime,
        IBaseballSetupDraft, IBaseballAdvancedSetupDraft, IBaseballCareerChoiceDraft,
        IBaseballShellSettings, IBaseballVisualAssets, IBaseballShellRouteObserver,
        IBaseballPitchNavigation, IBaseballLifeCardShareRuntime, IBaseballExternalNavigation,
        IBaseballShellLifecycleObserver, IBaseballLifeArchiveInteraction, IPitchFeedbackBoundary,
        IBaseballOpeningPresentationGate, IBaseballContentExposure
    {
        private readonly StoreBaseballCareerReadModel _readModel;
        private readonly AndroidHapticsService _haptics = new AndroidHapticsService();
        private readonly IBaseballVisualAssetLoader _visualAssets = new AddressableVisualAssetLoader();
        private readonly AddressablePitchFeedbackBoundary _pitchFeedback;
        private GameApplicationStore _store;
        private ShellRuntimeStatus _status = ShellRuntimeStatus.Loading;
        private string _statusMessage = "안전하게 저장된 진행 상황을 확인하는 중입니다.";
        private string _playerName = string.Empty;
        private string _region = "서울";
        private string _presetId = "power_prospect";
        private string _seedInput = string.Empty;
        private string _seedValidationMessage = string.Empty;
        private string _setupDifficulty = "standard";
        private string _setupSoulDomain = string.Empty;
        private string _setupSignatureLegacy = string.Empty;
        private readonly HashSet<string> _setupKarmas = new HashSet<string>(StringComparer.Ordinal);
        private readonly HashSet<string> _setupSoulBoosts = new HashSet<string>(StringComparer.Ordinal);
        private readonly HashSet<string> _setupMemories = new HashSet<string>(StringComparer.Ordinal);
        private readonly Dictionary<string, string> _careerChoices =
            new Dictionary<string, string>(StringComparer.Ordinal);
        private readonly Dictionary<string, HashSet<string>> _careerMultiChoices =
            new Dictionary<string, HashSet<string>>(StringComparer.Ordinal);
        private int _commandSequence;
        private bool _weeklyObserveInFlight;
        private ulong? _weeklyObservedRevision;
        private bool? _pendingReminderEnabled;
        private string _pendingReminderSource;
        private bool _reminderSettingsInFlight;
        private bool _reminderOpenInFlight;
        private bool _reminderNavigationReceiptInFlight;
        private ShellRoute? _pitchReturnOverride;
        private ShellRoute? _externalRoute;
        private string _externalRouteReminderToken;
        private ShellRoute? _consumedExternalRoute;
        private string _consumedExternalRouteReminderToken;
        private bool _disposed;

        public ProductionBaseballShellRuntime(IKoreanUiCopyCatalog copy)
        {
            _pitchFeedback = new AddressablePitchFeedbackBoundary(_haptics);
            _pitchFeedback.SoundEnabled = SoundEnabled;
            _pitchFeedback.MusicEnabled = MusicEnabled;
            _readModel = new StoreBaseballCareerReadModel(
                copy,
                () => _store?.Current,
                () => _status,
                () => _statusMessage,
                () => _presetId,
                GetChoice,
                GetChoices,
                () => AndroidReminderService.Instance?.ShouldOfferOptIn == true);
            RuntimeGameServices.Ready += OnReady;
            RuntimeGameServices.StoreChanged += OnStoreChanged;
            RuntimeGameServices.BecameUnavailable += OnUnavailable;
            RuntimeGameServices.StartupFailed += OnStartupFailed;
            RuntimeGameServices.SessionEndPrepared += OnSessionEndPrepared;
            if (AndroidReminderService.Instance != null)
            {
                AndroidReminderService.Instance.EnablementChanged += OnReminderChanged;
                AndroidReminderService.Instance.ReminderOpenAvailable += OnReminderOpenAvailable;
            }
            if (RuntimeGameServices.TryGetStore(out GameApplicationStore ready)) OnReady(ready);
        }

        public event Action Changed;
        public ShellRuntimeStatus Status => _status;
        public ShellRoute PreferredRoute => _pitchReturnOverride ?? _readModel.PreferredRoute;
        public bool ShouldHoldOpeningForReturnPlan =>
            _status == ShellRuntimeStatus.Ready &&
            ReturnPlanPresentationPolicy.ShouldHoldOpening(_store?.Current, DateTimeOffset.UtcNow);
        public bool IsBusy => _store?.IsBusy == true;
        public string StatusMessage => _statusMessage;
        public IReadOnlyList<ShellRoute> Routes => _readModel.Routes;
        public string PlayerName => _playerName;
        public string SuggestedPlayerName => PitcherPresetCatalog.All.FirstOrDefault(value =>
            string.Equals(value.Id, _presetId, StringComparison.Ordinal))?.Pitcher?.Name ?? "민서준";
        public string Region => _region;
        public string PresetId => _presetId;
        public HighSchoolSetupReadModel SetupOptions =>
            HighSchoolSetupCatalog.For(_store?.Current?.Meta ?? MetaProgressState.Initial);
        public string SeedInput => _seedInput;
        public string SeedValidationMessage => _seedValidationMessage;
        public string SetupDifficulty => _setupDifficulty;
        public string SetupSoulDomain => _setupSoulDomain;
        public string SetupSignatureLegacy => _setupSignatureLegacy;
        public IReadOnlyList<string> SetupKarmas => _setupKarmas.OrderBy(value => value, StringComparer.Ordinal).ToArray();
        public IReadOnlyList<string> SetupSoulBoosts => _setupSoulBoosts.OrderBy(value => value, StringComparer.Ordinal).ToArray();
        public IReadOnlyList<string> SetupMemories => _setupMemories.OrderBy(value => value, StringComparer.Ordinal).ToArray();
        private GameSettingsState Settings => _store?.Current?.Settings ?? GameSettingsState.Default;
        public bool AutoRelease => Settings.AutoReleaseEnabled;
        public bool SoundEnabled => Settings.SoundEnabled;
        public bool MusicEnabled => Settings.MusicEnabled;
        public bool HapticsEnabled => Settings.HapticsEnabled;
        public bool NotificationsEnabled => Settings.NotificationsEnabled;
        public bool CanUseNotifications => AndroidReminderService.Instance != null;
        public bool NotificationSettingsRequired => AndroidReminderService.Instance?.RequiresSystemSettings == true;
        public string NotificationsUnavailableReason => CanUseNotifications
            ? string.Empty
            : "이 기기에서는 알림 서비스를 준비하지 못했습니다.";
        public bool HighContrast => Settings.HighContrastEnabled;
        public bool ReducedMotion => Settings.ReducedMotionEnabled;
        public IBaseballVisualAssetLoader VisualAssetLoader => _visualAssets;
        public PitchHandoffViewModel ResumeHandoff
        {
            get
            {
                PitchCareerKind? kind = _store?.Current?.PitchResume?.CareerKind;
                ShellRoute origin = kind == PitchCareerKind.Tutorial
                    ? ShellRoute.Prologue
                    : kind == PitchCareerKind.Daily
                    ? ShellRoute.Records
                    : kind == PitchCareerKind.Pro ? ShellRoute.ProWeek : ShellRoute.ImportantGame;
                ShellRoute destination = kind == PitchCareerKind.Tutorial
                    ? ShellRoute.Prologue
                    : kind == PitchCareerKind.Daily
                    ? ShellRoute.Records
                    : kind == PitchCareerKind.Pro ? ShellRoute.ProWeek : ShellRoute.Awakening;
                return new PitchHandoffViewModel(origin, destination);
            }
        }

        public BaseballScreenViewModel Read(ShellRoute route) => _readModel.Read(route);

        public bool TryConsumeExternalRoute(out ShellRoute route)
        {
            if (_externalRoute.HasValue)
            {
                route = _externalRoute.Value;
                _externalRoute = null;
                _consumedExternalRoute = route;
                _consumedExternalRouteReminderToken = _externalRouteReminderToken;
                _externalRouteReminderToken = null;
                return true;
            }
            route = default;
            return false;
        }

        public void AcknowledgeExternalRoute(ShellRoute renderedRoute)
        {
            if (!_consumedExternalRoute.HasValue || _consumedExternalRoute.Value != renderedRoute)
                return;
            string reminderToken = _consumedExternalRouteReminderToken;
            _consumedExternalRoute = null;
            _consumedExternalRouteReminderToken = null;
            if (!string.IsNullOrWhiteSpace(reminderToken))
                ConfirmReminderNavigation(reminderToken);
        }

        public async Task<ShellActionResult> ExecuteAsync(
            ShellRoute route,
            ScreenActionViewModel action,
            CancellationToken cancellationToken)
        {
            if (action == null) throw new ArgumentNullException(nameof(action));
            if (action.Id == "runtime_retry")
            {
                RetryStartup();
                return _status == ShellRuntimeStatus.Ready
                    ? ShellActionResult.Success(PreferredRoute, "저장 상태를 다시 불러왔습니다.")
                    : ShellActionResult.Failure(_statusMessage);
            }
            if (action.Id.StartsWith("navigate_", StringComparison.Ordinal))
            {
                return ShellActionResult.Success(action.Target);
            }
            if (_status != ShellRuntimeStatus.Ready || _store == null)
                return ShellActionResult.Failure("저장 데이터를 불러온 뒤 다시 시도해 주세요.");
            if (_store.IsBusy) return ShellActionResult.Failure("다른 저장 작업을 처리하고 있습니다.");

            if (action.Id == "share_life_card") return await ShareLifeCardAsync(null, cancellationToken);
            if (action.Id == "reset_save") return await ResetAsync(cancellationToken);
            if (action.Id == "enable_reminder_nudge")
            {
                AndroidReminderService reminders = AndroidReminderService.Instance;
                if (reminders == null) return ShellActionResult.Failure(NotificationsUnavailableReason);
                reminders.RequestEnabled(true);
                return ShellActionResult.Success(null, "Android 알림 권한 결과를 확인하고 있습니다.");
            }
            if (action.Id == "dismiss_reminder_nudge")
            {
                AndroidReminderService reminders = AndroidReminderService.Instance;
                if (reminders == null) return ShellActionResult.Failure(NotificationsUnavailableReason);
                reminders.DeclineOptIn();
                return ShellActionResult.Success(null, "복귀 알림 권유를 닫았습니다.");
            }

            GameSaveAggregate before = _store.Current;
            GameCommand command = CreateCommand(action.Id, before);
            if (command == null)
                return ShellActionResult.Failure("아직 실제 게임 명령과 연결되지 않은 기능입니다.");
            string commandId = "ui:" + action.Id + ":" + before.Revision + ":" + (++_commandSequence);
            var envelope = new CommandEnvelope<GameCommand>(commandId, before.Revision, command);
            DispatchResult<GameSaveAggregate> result = await _store.DispatchAsync(envelope, cancellationToken);
            if (!result.IsSuccess)
            {
                return ShellActionResult.Failure(KoreanFailure(result));
            }

            await LogSuccessfulActionAsync(action.Id, before, result.State, cancellationToken);
            return ShellActionResult.Success(DestinationAfterCommand(action), "저장했습니다.");
        }

        public void RetryStartup()
        {
            if (RuntimeGameServices.TryGetStore(out GameApplicationStore ready))
            {
                OnReady(ready);
                return;
            }
            _status = ShellRuntimeStatus.Loading;
            _statusMessage = "저장 상태를 다시 확인하고 있습니다. 잠시 후 한 번 더 눌러 주세요.";
            Changed?.Invoke();
        }

        public void SetPlayerName(string value)
        {
            if (SetupPlayerNamePolicy.TryUpdate(_playerName, value, out string next))
            {
                _playerName = next;
                Changed?.Invoke();
            }
        }

        public void SetRegion(string value)
        {
            if (HighSchoolSetupCatalog.Regions.Any(option =>
                    string.Equals(option.Payload, value, StringComparison.Ordinal)))
            {
                _region = value;
                Changed?.Invoke();
            }
        }

        public void SetPresetId(string value)
        {
            if (HighSchoolSetupCatalog.Presets.Any(option =>
                    string.Equals(option.Payload, value, StringComparison.Ordinal)))
            {
                _presetId = value;
                Changed?.Invoke();
            }
        }

        public void SetSeedInput(string value)
        {
            _seedInput = (value ?? string.Empty).Trim();
            _seedValidationMessage = HighSchoolSetupCatalog.TryParseSeedInput(
                _seedInput,
                out _,
                out _)
                ? string.Empty
                : "시드는 숫자, 도전 코드는 숫자-회차 형식으로 입력해 주세요.";
            Changed?.Invoke();
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
                    if (string.IsNullOrEmpty(value) || SetupOptions.SoulDomains.Any(option => option.Payload == value))
                        _setupSoulDomain = value;
                    break;
                case "signature":
                    if (string.IsNullOrEmpty(value) || SetupOptions.SignatureLegacies.Any(option => option.Payload == value))
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
                case "memory":
                    if (SetupOptions.CarriedMemories.Contains(payload)) ToggleBounded(_setupMemories, payload, null, 4);
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
                case "memory": return _setupMemories.Contains(payload);
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
            if (AndroidReminderService.Instance == null)
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

        public void OnRouteChanged(ShellRoute route, bool pitchStageLoaded)
        {
            GameSaveAggregate state = _store?.Current;
            CrashReporting.SetContext(new CrashContext(
                "runtime",
                state?.AggregateVersion ?? 0,
                state?.Revision ?? 0,
                route.ToString().ToLowerInvariant(),
                pitchStageLoaded,
                QualitySettings.names.Length == 0 ? "unknown" : QualitySettings.names[QualitySettings.GetQualityLevel()]));
            if (!pitchStageLoaded && _pitchReturnOverride == route) _pitchReturnOverride = null;
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
        }

        public void OnApplicationPause(bool paused)
        {
            if (paused) return;
            AndroidReminderService.Instance?.ApplySavedEnabled(NotificationsEnabled);
            DrainPendingReminderSetting();
            ObserveReturnPlanOpen("warm");
        }

        public void Dispose()
        {
            if (_disposed) return;
            RuntimeGameServices.Ready -= OnReady;
            RuntimeGameServices.StoreChanged -= OnStoreChanged;
            RuntimeGameServices.BecameUnavailable -= OnUnavailable;
            RuntimeGameServices.StartupFailed -= OnStartupFailed;
            RuntimeGameServices.SessionEndPrepared -= OnSessionEndPrepared;
            if (AndroidReminderService.Instance != null)
            {
                AndroidReminderService.Instance.EnablementChanged -= OnReminderChanged;
                AndroidReminderService.Instance.ReminderOpenAvailable -= OnReminderOpenAvailable;
            }
            DetachStore();
            _pitchFeedback.Dispose();
            _disposed = true;
        }

        void IPitchFeedbackBoundary.OnRelease(PitchHapticCue cue) => _pitchFeedback.OnRelease(cue);
        void IPitchFeedbackBoundary.OnSessionStarted() => _pitchFeedback.OnSessionStarted();
        void IPitchFeedbackBoundary.OnSessionEnded() => _pitchFeedback.OnSessionEnded();
        void IPitchFeedbackBoundary.OnResult(PitchAudioCue audioCue, PitchHapticCue hapticCue) =>
            _pitchFeedback.OnResult(audioCue, hapticCue);

        private void OnReady(GameApplicationStore store)
        {
            if (store == null) return;
            AttachStore(store);
            _status = ShellRuntimeStatus.Ready;
            _statusMessage = store.RequiresRecoveryNotice
                ? "백업 저장에서 안전하게 복구했습니다."
                : string.Empty;
            ApplyPersistedSettings(store.Current);
            DrainPendingReminderSetting();
            DrainPendingReminderOpen();
            if (!_coldStartAnalyticsObserved)
            {
                _coldStartAnalyticsObserved = true;
                ObserveReturnPlanOpen("cold");
            }
            Changed?.Invoke();
        }

        private void OnStoreChanged(GameApplicationStore store)
        {
            if (store == null)
            {
                OnUnavailable();
                return;
            }
            OnReady(store);
        }

        private void OnUnavailable()
        {
            DetachStore();
            _status = ShellRuntimeStatus.Unavailable;
            _statusMessage = "저장 서비스 연결이 끊겼습니다. 잠시 후 다시 시도해 주세요.";
            Changed?.Invoke();
        }

        private void OnStartupFailed(Exception exception)
        {
            DetachStore();
            _status = ShellRuntimeStatus.StartupFailed;
            _statusMessage = StartupFailureMessage(exception);
            CrashReporting.RecordUnexpected(exception, "presentation_startup");
            Changed?.Invoke();
        }

        private void AttachStore(GameApplicationStore store)
        {
            if (ReferenceEquals(_store, store)) return;
            DetachStore();
            _store = store;
            _store.StatePublished += OnStatePublished;
            _store.BusyChanged += OnBusyChanged;
        }

        private void DetachStore()
        {
            if (_store == null) return;
            _store.StatePublished -= OnStatePublished;
            _store.BusyChanged -= OnBusyChanged;
            _store = null;
        }

        private void OnStatePublished(GameSaveAggregate state)
        {
            ApplyPersistedSettings(state);
            Changed?.Invoke();
        }

        private void OnBusyChanged(bool busy)
        {
            if (!busy)
            {
                DrainPendingReminderSetting();
                DrainPendingReminderOpen();
            }
            Changed?.Invoke();
        }

        private void OnReminderChanged(bool enabled, string source)
        {
            _pendingReminderEnabled = enabled;
            _pendingReminderSource = string.IsNullOrWhiteSpace(source) ? "settings" : source;
            DrainPendingReminderSetting();
        }

        private async void DrainPendingReminderSetting()
        {
            if (_reminderSettingsInFlight || !_pendingReminderEnabled.HasValue ||
                _store == null || _status != ShellRuntimeStatus.Ready || _store.IsBusy) return;

            bool enabled = _pendingReminderEnabled.Value;
            string source = _pendingReminderSource ?? "settings";
            _pendingReminderEnabled = null;
            _pendingReminderSource = null;
            _reminderSettingsInFlight = true;
            GameSaveAggregate before = _store.Current;
            string commandId = "settings:reminder:" + before.Revision + ":" + (++_commandSequence);
            bool saved = false;
            try
            {
                DispatchResult<GameSaveAggregate> result = await _store.DispatchAsync(
                    new CommandEnvelope<GameCommand>(
                        commandId,
                        before.Revision,
                        new UpdateGameSettingsCommand(notificationsEnabled: enabled)),
                    CancellationToken.None);
                saved = result.IsSuccess;
                if (!saved)
                {
                    if (!string.Equals(source, "system", StringComparison.Ordinal))
                        AndroidReminderService.Instance?.ApplySavedEnabled(
                            before.Settings.NotificationsEnabled);
                    _statusMessage = "복귀 알림 설정을 저장하지 못했습니다. 이전 설정을 유지합니다.";
                }
                else
                {
                    _statusMessage = enabled
                        ? "복귀 알림 설정을 저장했습니다."
                        : source == "system"
                            ? "기기에서 알림 권한이 꺼져 복귀 알림도 해제했습니다."
                            : "복귀 알림 설정을 저장했습니다.";
                    SafeLog(
                        AnalyticsEvent.ReminderChanged,
                        new Dictionary<string, object>(StringComparer.Ordinal)
                        {
                            ["enabled"] = enabled,
                            ["source"] = source,
                        });
                }
            }
            catch (Exception exception)
            {
                if (!string.Equals(source, "system", StringComparison.Ordinal))
                    AndroidReminderService.Instance?.ApplySavedEnabled(
                        before.Settings.NotificationsEnabled);
                CrashReporting.RecordUnexpected(exception, "reminder_settings_update");
                _statusMessage = "복귀 알림 설정을 저장하지 못했습니다. 이전 설정을 유지합니다.";
            }
            finally
            {
                if (string.Equals(source, "system", StringComparison.Ordinal))
                    AndroidReminderService.Instance?.ResolvePersistedDenial(saved);
                _reminderSettingsInFlight = false;
                Changed?.Invoke();
                if (_pendingReminderEnabled.HasValue) DrainPendingReminderSetting();
            }
        }

        private void OnReminderOpenAvailable() => DrainPendingReminderOpen();

        private GameCommand CreateCommand(string actionId, GameSaveAggregate state)
        {
            DateTimeOffset now = DateTimeOffset.UtcNow;
            const string achievementPrefix = "ack_achievement:";
            if (actionId.StartsWith(achievementPrefix, StringComparison.Ordinal))
            {
                string achievementId = actionId.Substring(achievementPrefix.Length);
                return state.Meta.Achievements.Unacknowledged.Contains(achievementId, StringComparer.Ordinal)
                    ? new AcknowledgeAchievementCommand(achievementId)
                    : null;
            }
            switch (actionId)
            {
                case "enter_setup": return new EnterSetupCommand();
                case "start_high_school":
                    HighSchoolSetupCatalog.TryParseSeedInput(
                        _seedInput,
                        out HighSchoolSeedSelection seedSelection,
                        out _);
                    bool challenge = seedSelection?.IsChallenge == true;
                    return new StartHighSchoolCareerCommand(new StartHighSchoolCareerRequest(
                        seedSelection?.Seed ?? state.InstallId + ":life:" + state.Meta.LifeNumber,
                        _presetId,
                        EffectivePlayerName(),
                        _region,
                        state.Meta.LifeNumber,
                        challenge ? Array.Empty<string>() : SetupMemories,
                        challenge ? 0 : state.Meta.AutomaticSoulEarned,
                        challenge ? Array.Empty<string>() : SetupKarmas,
                        challenge ? null : EmptyToNull(_setupSoulDomain),
                        challenge ? Array.Empty<string>() : SetupSoulBoosts,
                        challenge ? "standard" : _setupDifficulty,
                        challenge ? null : EmptyToNull(_setupSignatureLegacy),
                        seedSelection?.ChallengeLifeNumber));
                case "quick_rebirth": return new StartQuickRebirthCommand("quick_rebirth", now);
                case "quick_rebirth_from_recap": return new StartQuickRebirthCommand("recap", now);
                case "end_challenge": return new EndChallengeRunCommand();
                case "start_direct_pro":
                    return new StartDirectProCommand(new StartDirectProRequest(
                        state.InstallId + ":direct:" + state.Revision,
                        _presetId,
                        EffectivePlayerName(),
                        ProCareerEngine.ProTeams[0].Id));
                case "skip_tutorial": return new SkipTutorialCommand();
                case "choose_pledge":
                    string pledge = GetChoice("run_pledge");
                    return RunPledgeRules.IsValidSelection(state, pledge) && !string.IsNullOrWhiteSpace(pledge)
                        ? new ChoosePledgeCommand(pledge, now)
                        : null;
                case "skip_pledge":
                    return RunPledgeRules.IsValidSelection(state, null)
                        ? new ChoosePledgeCommand(null, now)
                        : null;
                case "choose_school": return HighSchool("choose_school", Selected("school", state.HighSchool?.SchoolChoices), now);
                case "train":
                case "train_block":
                    string focus = Selected("training_focus", state.HighSchool?.TrainingFocusChoices);
                    string intensity = Selected("training_intensity", state.HighSchool?.TrainingIntensityChoices);
                    string trainingTarget = Selected("training_pitch", state.HighSchool?.TrainingPitchChoices);
                    string trainingPayload = CareerActionSelectionPolicy.TrainingPayload(
                        focus,
                        intensity,
                        trainingTarget,
                        state.HighSchool?.TrainingPitchChoices?.Count > 0);
                    return string.IsNullOrWhiteSpace(trainingPayload)
                        ? null
                        : HighSchool(
                            actionId == "train_block"
                                ? HighSchoolTrainingActionPayload.BlockAction
                                : HighSchoolTrainingActionPayload.SingleAction,
                            trainingPayload,
                            now);
                case "relationship": return HighSchool("relationship", Selected("relationship", state.HighSchool?.RelationshipChoices), now);
                case "awakening": return HighSchool("awakening", Selected("awakening", state.HighSchool?.AwakeningChoices), now);
                case "advance_chapter": return HighSchool("advance_chapter", null, now);
                case "resolve_draft": return HighSchool("resolve_draft", null, now);
                case "open_legacy": return HighSchool("open_legacy", null, now);
                case "enter_pro": return new EnterProFromDraftCommand();
                case "decline_pro": return new DeclineProCareerCommand();
                case "sign_pro_contract": return new SignProContractCommand();
                case "advance_pro_week":
                case "advance_pro_segment":
                    string proPlan = Selected("pro_week_plan", state.Pro?.WeekPlanChoices);
                    string developmentPitch = Selected("pro_development_pitch", state.Pro?.DevelopmentPitchChoices);
                    string proPayload = CareerActionSelectionPolicy.ProWeekPayload(
                        proPlan,
                        developmentPitch,
                        state.Pro?.DevelopmentPitchChoices?.Count > 0);
                    return string.IsNullOrWhiteSpace(proPayload)
                        ? null
                        : Pro(
                            actionId == "advance_pro_segment"
                                ? ProWeekActionPayload.AdvanceSegmentAction
                                : ProWeekActionPayload.AdvanceWeekAction,
                            proPayload,
                            now);
                case "resolve_pro_decision": return Pro("season_decision", Selected("pro_season_decision", state.Pro?.SeasonDecision?.Choices), now);
                case "review_season": return Pro("review_season", null, now);
                case "continue_pro_career": return Pro("offseason", Selected("pro_offseason", state.Pro?.OffseasonChoices), now);
                case "retire_pro": return new RetireProCareerCommand(now);
                case "finalize_high_school_legacy":
                    if (state.HighSchool?.LegacySelectionMode == LegacySelectionMode.SignatureLegacy)
                    {
                        string signature = Selected("legacy_signature", state.HighSchool.SignatureLegacyChoices);
                        return string.IsNullOrWhiteSpace(signature)
                            ? null
                            : new FinalizeHighSchoolLegacyCommand(Array.Empty<string>(), signature, now);
                    }
                    IReadOnlyList<string> memories = GetChoices("legacy_memories");
                    bool validMemories = state.HighSchool != null && memories.Count == state.HighSchool.MemorySlots &&
                        memories.All(value => state.HighSchool.LegacyMemoryChoices.Any(option =>
                            option.Enabled && option.Payload == value));
                    return validMemories
                        ? new FinalizeHighSchoolLegacyCommand(memories, null, now)
                        : null;
                case "begin_rebirth": return new BeginRebirthCommand(now);
                case "save_next_run_intent":
                    NextRunIntentState nextIntent = RunPledgeRules.SuggestedNextRunIntent(state.HighSchool);
                    return nextIntent == null ? null : new SetNextRunIntentCommand(nextIntent);
                case "claim_weekly": return new ClaimWeeklyRewardCommand(now);
                case "begin_pitch": return BeginPitch(state, false, now);
                case "begin_daily_pitch": return BeginPitch(state, true, now);
                case "begin_tutorial_pitch": return BeginTutorialPitch(state, now);
                case "acknowledge_pitch_result":
                    return string.IsNullOrWhiteSpace(state.PendingPitchCompletion?.CompletionId)
                        ? null
                        : new AcknowledgePitchResultCommand(state.PendingPitchCompletion.CompletionId);
                case "open_return_plan": return new CompleteReturnPlanInteractionCommand(false, now);
                case "dismiss_return_plan": return new CompleteReturnPlanInteractionCommand(true, now);
                default: return null;
            }
        }

        private static GameCommand HighSchool(string kind, string value, DateTimeOffset now) =>
            new AdvanceHighSchoolCommand(new HighSchoolAction(kind, value), now);

        private static GameCommand Pro(string kind, string value, DateTimeOffset now) =>
            new AdvanceProCommand(new ProCareerAction(kind, value), now);

        private static GameCommand BeginPitch(GameSaveAggregate state, bool daily, DateTimeOffset now)
        {
            PitchCareerKind kind = daily ? PitchCareerKind.Daily : state.Pro != null ? PitchCareerKind.Pro : PitchCareerKind.HighSchool;
            string gameId = "pitch:" + kind.ToString().ToLowerInvariant() + ":" + (state.Revision + 1);
            string scenario = daily
                ? DailyInningRules.Project(state.Meta, now).ScenarioId
                : kind == PitchCareerKind.Pro ? "pro-important" : "high-school-important";
            return new BeginPitchSessionCommand(gameId, kind, scenario, 6, now);
        }

        private static GameCommand BeginTutorialPitch(GameSaveAggregate state, DateTimeOffset now)
        {
            if (state.HighSchool?.Phase != HighSchoolPhase.Prologue) return null;
            string gameId = "pitch:tutorial:" + (state.Revision + 1);
            return new BeginPitchSessionCommand(
                gameId,
                PitchCareerKind.Tutorial,
                "tutorial",
                2,
                now);
        }

        private static string EmptyToNull(string value) =>
            string.IsNullOrWhiteSpace(value) ? null : value;

        private string EffectivePlayerName() =>
            SetupPlayerNamePolicy.Resolve(_playerName, SuggestedPlayerName);

        private string Selected(
            string group,
            IReadOnlyList<Baseball.Application.Commands.CareerChoiceReadModel> choices)
        {
            if (choices == null || choices.Count == 0) return null;
            string selected = GetChoice(group);
            Baseball.Application.Commands.CareerChoiceReadModel match = choices.FirstOrDefault(option =>
                option.Enabled && string.Equals(option.Payload, selected, StringComparison.Ordinal));
            return match?.Payload;
        }

        private ShellRoute DestinationAfterCommand(ScreenActionViewModel action)
        {
            switch (action.Id)
            {
                case "claim_weekly": return action.Target;
                case "acknowledge_pitch_result": return action.Target;
                case "begin_pitch":
                case "begin_daily_pitch": return ShellRoute.PitchHandoff;
                case "begin_tutorial_pitch": return ShellRoute.PitchHandoff;
                default: return PreferredRoute;
            }
        }

        private async Task<ShellActionResult> ResetAsync(CancellationToken cancellationToken)
        {
            string newInstallId = AnonymousInstallIdentity.CreateCandidate();
            try
            {
                await _store.ResetAsync(
                    newInstallId,
                    (installId, token) =>
                    {
                        token.ThrowIfCancellationRequested();
                        AnonymousInstallIdentity.Replace(installId);
                        return Task.CompletedTask;
                    },
                    cancellationToken);
            }
            catch (GameResetException exception) when (exception.RollbackError != null)
            {
                CrashReporting.RecordUnexpected(exception, "save_reset_rollback_failed");
                return ShellActionResult.Failure(
                    "초기화와 복구를 모두 마치지 못했습니다. 앱을 완전히 닫고 다시 열어 저장 복구 안내를 확인해 주세요.");
            }
            catch (Exception exception) when (!(exception is OperationCanceledException))
            {
                CrashReporting.RecordUnexpected(exception, "save_reset");
                return ShellActionResult.Failure("저장 데이터를 지우지 못했습니다. 기존 진행과 익명 식별자는 그대로 유지됩니다.");
            }

            try { AnalyticsBootstrap.ResetIdentityAndOnceFlags(newInstallId); }
            catch { /* Analytics identity reset must not invalidate the atomic save/identity reset. */ }
            _externalRoute = null;
            _externalRouteReminderToken = null;
            _consumedExternalRoute = null;
            _consumedExternalRouteReminderToken = null;
            AndroidReminderService.Instance?.ResetLocalState();
            PlayReviewPrompt.ResetLocalAttempt();
            AndroidShareService.ClearShareCache();
            ApplyPersistedSettings(_store.Current);
            return ShellActionResult.Success(ShellRoute.Opening, "저장 데이터와 익명 식별자를 함께 초기화했습니다.");
        }

        public Task<ShellActionResult> ShareLifeCardAsync(
            byte[] pngBytes,
            CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();
            LifeArchiveRecord life = SelectedLifeRecordForUi(_store.Current);
            string text = BuildLifeCardText(life);
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

        private static string BuildLifeCardText(LifeArchiveRecord life)
        {
            if (life == null) return "야구 못하면 또 환생함 · 아직 완성한 야구 인생이 없습니다.";
            return "야구 못하면 또 환생함\n" + life.LifeNumber + "번째 인생 · " + life.PlayerName +
                "\n고교 탈삼진 " + life.HighSchoolPerformance.Strikeouts + " · 프로 탈삼진 " + life.ProStrikeouts +
                "\n야구혼 +" + life.SoulEarned;
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
            _haptics.IsEnabled = settings.HapticsEnabled;
            AndroidReminderService reminders = AndroidReminderService.Instance;
            if (reminders != null)
            {
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
                reminders.ConfigurePlan(reminderPlan, Array.Empty<string>());
                reminders.ApplySavedEnabled(settings.NotificationsEnabled);
            }
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
                default: return StoreBaseballCareerReadModel.PreferredRouteFor(_store?.Current);
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

        private static void SafeLog(AnalyticsEvent analyticsEvent, IReadOnlyDictionary<string, object> properties)
        {
            try { AnalyticsBootstrap.Log(analyticsEvent, properties); }
            catch { /* Analytics never blocks durable game progress. */ }
        }
    }

    public static class ProductionBaseballShellComposition
    {
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
        private static void Register()
        {
            BaseballShellRuntimeComposition.Register(copy => new ProductionBaseballShellRuntime(copy));
        }
    }
}
