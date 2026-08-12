using System;
using System.Collections;
using Baseball.Platform.Identity;
using Unity.Notifications.Android;
using UnityEngine;

namespace Baseball.Platform.Notifications
{
    [DefaultExecutionOrder(-8700)]
    public sealed class AndroidReminderService : MonoBehaviour
    {
        public const string ChannelId = "return-reminder-v1";
        public const string SmallIconId = "baseball_notification_small";

        private static AndroidReminderService _instance;
        private ReminderOpenRequest _pendingOpenRequest;
        private readonly ReminderResetIntentGuard _resetIntentGuard =
            new ReminderResetIntentGuard();
        private Coroutine _permissionRoutine;
        private bool _enabled;
        private readonly ReminderEnablementPolicy _enablementPolicy = new ReminderEnablementPolicy();
        private AndroidReminderPlan _plan;
        private string _installId;
        private string _installEpoch;
        private string _askedKey;
        private string _capturedLaunchIntentEpoch;

        public static AndroidReminderService Instance => _instance;
        public bool IsEnabled => _enabled;
        public bool IsInstallBound => !string.IsNullOrWhiteSpace(_installEpoch);
        public bool ShouldOfferOptIn => PermissionUiState.ShouldOfferOptIn;
        public bool RequiresSystemSettings => PermissionUiState.RequiresSystemSettings;
        private ReminderPermissionUiState PermissionUiState
        {
            get
            {
                if (!IsInstallBound) return new ReminderPermissionUiState(false, false);
#if UNITY_ANDROID && !UNITY_EDITOR
                PermissionStatus status = AndroidNotificationCenter.UserPermissionToPost;
                ReminderPermissionAvailability permission = ReminderPermissionUiPolicy.Resolve(
                    status == PermissionStatus.Allowed,
                    status == PermissionStatus.RequestPending,
                    status == PermissionStatus.Denied ||
                    status == PermissionStatus.NotificationsBlockedForApp);
                return ReminderPermissionUiPolicy.Project(
                    _enabled,
                    permission,
                    PlayerPrefs.GetInt(AskedKey, 0) == 1);
#else
                bool asked = PlayerPrefs.GetInt(AskedKey, 0) == 1;
                return new ReminderPermissionUiState(!_enabled && !asked, false);
#endif
            }
        }
        public event Action<bool, string> EnablementChanged;
        public event Action ReminderOpenAvailable;

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
        private static void ResetStatics()
        {
            _instance = null;
        }

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
        private static void EnsureExists()
        {
            if (_instance == null) new GameObject("Android Reminder Service").AddComponent<AndroidReminderService>();
        }

        private void Awake()
        {
            if (_instance != null && _instance != this)
            {
                Destroy(gameObject);
                return;
            }

            _instance = this;
            DontDestroyOnLoad(gameObject);
#if UNITY_ANDROID
            RegisterKoreanChannel();
#endif
            // Identity acquisition belongs to the serialized store startup/retry boundary. This
            // service stays safely disabled until Presentation binds the aggregate's durable ID.
            TryReconcilePreparedResetBeforeStoreReady();
        }

        /// <summary>
        /// Binds notification-local state to the durable aggregate identity after store startup.
        /// A transient journal/filesystem failure leaves notifications disabled and can be retried
        /// by a later Ready/state publication or foreground resume without recreating this object.
        /// </summary>
        public bool BindInstall(string installId)
        {
            if (!AnonymousInstallIdentityPolicy.IsValid(installId))
            {
                ClearInstallBinding();
                return false;
            }

            try
            {
                InstallResetJournalReadResult reset = AnonymousInstallIdentity.ReadPreparedReset();
                if (reset.Status == InstallResetJournalStatus.Invalid)
                {
                    ClearInstallBinding();
                    return false;
                }
                if (reset.Status == InstallResetJournalStatus.Pending)
                {
                    if (!string.Equals(
                            reset.Record.CandidateInstallId,
                            installId,
                            StringComparison.OrdinalIgnoreCase))
                    {
                        ClearInstallBinding();
                        return false;
                    }
                    ResetLocalStateCore(reset, installId);
                }
                else BindInstallNamespace(installId);

#if UNITY_ANDROID
                if (!string.Equals(
                        _capturedLaunchIntentEpoch,
                        _installEpoch,
                        StringComparison.Ordinal))
                {
                    _capturedLaunchIntentEpoch = _installEpoch;
                    CaptureLaunchIntent();
                }
#endif
                return true;
            }
            catch (Exception)
            {
                ClearInstallBinding();
                return false;
            }
        }

        /// <summary>Applies the saved product setting without logging a user change.</summary>
        public void ApplySavedEnabled(bool enabled)
        {
            if (!IsInstallBound)
            {
                SetEffectiveEnabled(false);
                return;
            }
#if UNITY_ANDROID && !UNITY_EDITOR
            bool allowed = AndroidNotificationCenter.UserPermissionToPost == PermissionStatus.Allowed;
            if (enabled && allowed)
            {
                _enabled = true;
                _enablementPolicy.ShouldPublishPersistedDenial(true, true);
                ScheduleNext();
                return;
            }
            SetEffectiveEnabled(false);
            if (_enablementPolicy.ShouldPublishPersistedDenial(enabled, allowed))
                EnablementChanged?.Invoke(false, "system");
#else
            SetEffectiveEnabled(enabled);
#endif
        }

        /// <summary>
        /// Completes the saved-value correction handshake. A failed save releases the guard so a
        /// later resume can retry; only a durable save confirms the denial for this mismatch.
        /// </summary>
        public void ResolvePersistedDenial(bool saved) =>
            _enablementPolicy.ResolvePersistedDenial(saved);

        /// <summary>Requests an OS result; Presentation persists that result before analytics.</summary>
        public void RequestEnabled(bool enabled, string source = "settings")
        {
            if (!IsInstallBound) return;
            source = string.Equals(source, "after_first_game", StringComparison.Ordinal)
                ? "after_first_game"
                : "settings";
#if UNITY_ANDROID && !UNITY_EDITOR
            PermissionStatus status = AndroidNotificationCenter.UserPermissionToPost;
            ReminderPermissionAvailability permission = ReminderPermissionUiPolicy.Resolve(
                status == PermissionStatus.Allowed,
                status == PermissionStatus.RequestPending,
                status == PermissionStatus.Denied ||
                status == PermissionStatus.NotificationsBlockedForApp);
            ReminderRequestResolution resolution = ReminderEnablementPolicy.Request(enabled, permission);
            if (resolution.RequestsPermission)
            {
                if (_permissionRoutine != null) return;
                PlayerPrefs.SetInt(AskedKey, 1);
                PlayerPrefs.Save();
                _permissionRoutine = StartCoroutine(RequestPermission(source));
                return;
            }
            SetEffectiveEnabled(resolution.EffectiveEnabled);
            if (resolution.EffectiveEnabled)
                ScheduleNext();
            if (resolution.PublishesOutcome)
                EnablementChanged?.Invoke(resolution.EffectiveEnabled, source);
#else
            ReminderRequestResolution resolution = ReminderEnablementPolicy.Request(
                enabled,
                ReminderPermissionAvailability.Allowed);
            SetEffectiveEnabled(resolution.EffectiveEnabled);
            if (resolution.PublishesOutcome)
                EnablementChanged?.Invoke(resolution.EffectiveEnabled, source);
#endif
        }

        public void DeclineOptIn()
        {
            if (!IsInstallBound) return;
            PlayerPrefs.SetInt(AskedKey, 1);
            PlayerPrefs.Save();
            SetEffectiveEnabled(false);
            EnablementChanged?.Invoke(false, "declined");
        }

        private void SetEffectiveEnabled(bool enabled)
        {
            if (!enabled)
            {
                if (_permissionRoutine != null)
                {
                    StopCoroutine(_permissionRoutine);
                    _permissionRoutine = null;
                }
#if UNITY_ANDROID
                CancelAllReminders();
#endif
            }
            _enabled = enabled;
        }

        [Obsolete("Use ApplySavedEnabled for save projection or RequestEnabled for user intent.")]
        public void SetEnabled(bool enabled)
        {
            ApplySavedEnabled(enabled);
        }

        /// <summary>Clears resettable local permission history and all scheduled/displayed reminders.</summary>
        public void ResetLocalState()
        {
            try
            {
                InstallResetJournalReadResult prepared = AnonymousInstallIdentity.ReadPreparedReset();
                if (prepared.Status == InstallResetJournalStatus.Invalid)
                {
                    ClearInstallBinding();
                    return;
                }
                string currentInstallId = prepared.Status == InstallResetJournalStatus.Pending
                    ? prepared.Record.CandidateInstallId
                    : _installId;
                if (!AnonymousInstallIdentityPolicy.IsValid(currentInstallId))
                {
                    ClearInstallBinding();
                    return;
                }
                ResetLocalStateCore(prepared, currentInstallId);
            }
            catch (Exception)
            {
                ClearInstallBinding();
            }
        }

        private void ResetLocalStateCore(
            InstallResetJournalReadResult prepared,
            string currentInstallId)
        {
            string previousAskedKey = _askedKey;
            if (_permissionRoutine != null)
            {
                StopCoroutine(_permissionRoutine);
                _permissionRoutine = null;
            }
#if UNITY_ANDROID
            CancelAllReminders();
            TombstoneAndClearCurrentReminderIntent();
#else
            if (_pendingOpenRequest != null)
                _resetIntentGuard.Ignore(_pendingOpenRequest.StableTokenHash);
#endif
            string currentAskedKey = InstallScopedLocalStatePolicy.ReminderAskedKey(currentInstallId);
            if (!string.IsNullOrWhiteSpace(previousAskedKey))
                PlayerPrefs.DeleteKey(previousAskedKey);
            if (string.IsNullOrWhiteSpace(previousAskedKey) ||
                !string.Equals(previousAskedKey, currentAskedKey, StringComparison.Ordinal))
                PlayerPrefs.DeleteKey(currentAskedKey);
            if (prepared.Status == InstallResetJournalStatus.Pending)
            {
                PlayerPrefs.DeleteKey(InstallScopedLocalStatePolicy.ReminderAskedKey(
                    prepared.Record.PreviousInstallId));
                PlayerPrefs.DeleteKey(InstallScopedLocalStatePolicy.ReminderAskedKey(
                    prepared.Record.CandidateInstallId));
            }
            PlayerPrefs.Save();
            BindInstallNamespace(currentInstallId);
            _capturedLaunchIntentEpoch = null;
            _pendingOpenRequest = null;
            _plan = null;
            _enablementPolicy.Reset();
            SetEffectiveEnabled(false);
            if (prepared.Status == InstallResetJournalStatus.Pending)
            {
                AnonymousInstallIdentity.MarkPreparedResetStep(InstallResetStep.ReminderCleaned);
                AnonymousInstallIdentity.TryCompletePreparedReset();
            }
        }

        /// <summary>
        /// Cancels OS reminders only after a durable reset journal exists. From this point the
        /// reset intent is irrevocable and startup reconciliation owns any interrupted work.
        /// </summary>
        public void PrepareLocalReset()
        {
            if (AnonymousInstallIdentity.ReadPreparedReset().Status !=
                InstallResetJournalStatus.Pending)
                throw new InvalidOperationException("reset.journal_required_before_reminder_cleanup");
            if (_permissionRoutine != null)
            {
                StopCoroutine(_permissionRoutine);
                _permissionRoutine = null;
            }
#if UNITY_ANDROID
            CancelAllReminders();
            TombstoneAndClearCurrentReminderIntent();
#else
            if (_pendingOpenRequest != null)
                _resetIntentGuard.Ignore(_pendingOpenRequest.StableTokenHash);
#endif
            _pendingOpenRequest = null;
            _plan = null;
            _enabled = false;
        }

        public void ConfigurePlan(AndroidReminderPlan plan)
        {
            _plan = plan;
#if UNITY_ANDROID && !UNITY_EDITOR
            if (_enabled && AndroidNotificationCenter.UserPermissionToPost == PermissionStatus.Allowed)
            {
                if (_plan == null) CancelAllReminders();
                else ScheduleNext();
            }
#endif
        }

        /// <summary>Peeks without clearing so startup/save failures can retry after the store is ready.</summary>
        public bool TryPeekReminderOpen(out ReminderOpenRequest request)
        {
            request = _pendingOpenRequest;
            return request != null;
        }

        /// <summary>Clears only the exact request whose durable receipt was handled or already existed.</summary>
        public bool CompleteReminderOpen(string stableTokenHash)
        {
            if (_pendingOpenRequest == null ||
                !string.Equals(
                    _pendingOpenRequest.StableTokenHash,
                    stableTokenHash,
                    StringComparison.Ordinal)) return false;
            _pendingOpenRequest = null;
            return true;
        }

        public void OpenSystemSettings()
        {
#if UNITY_ANDROID && !UNITY_EDITOR
            AndroidNotificationCenter.OpenNotificationSettings(ChannelId);
#endif
        }

        private IEnumerator RequestPermission(string source)
        {
            var request = new PermissionRequest();
            while (request.Status == PermissionStatus.RequestPending) yield return null;
            _permissionRoutine = null;
            bool allowed = request.Status == PermissionStatus.Allowed;
            SetEffectiveEnabled(allowed);
            if (allowed) ScheduleNext();
            EnablementChanged?.Invoke(allowed, source);
        }

        private void ScheduleNext()
        {
            if (!IsInstallBound) return;
#if UNITY_ANDROID && !UNITY_EDITOR
            CancelAllReminders();
            if (_plan == null) return;
            foreach (SeoulReminderEntry entry in SeoulReminderSchedule.Upcoming(
                         DateTimeOffset.UtcNow,
                         Array.Empty<string>()))
            {
                var notification = new AndroidNotification
                {
                    Title = _plan.Title,
                    Text = _plan.Body,
                    FireTime = entry.FireUtc.UtcDateTime,
                    IntentData = _plan.IntentData(entry.DayKey, _installEpoch),
                    SmallIcon = SmallIconId,
                    ShouldAutoCancel = true
                };
                AndroidNotificationCenter.SendNotificationWithExplicitID(
                    notification,
                    ChannelId,
                    entry.NotificationId);
            }
#endif
        }

        private static void CancelAllReminders()
        {
#if UNITY_ANDROID
            for (int offset = 0; offset < SeoulReminderSchedule.HorizonDays; offset++)
            {
                int id = SeoulReminderSchedule.NotificationIdBase + offset;
                AndroidNotificationCenter.CancelScheduledNotification(id);
                AndroidNotificationCenter.CancelDisplayedNotification(id);
            }
#endif
        }

        private static void RegisterKoreanChannel()
        {
#if UNITY_ANDROID
            var channel = new AndroidNotificationChannel
            {
                Id = ChannelId,
                Name = "복귀 알림",
                Description = "진행 중인 야구 인생을 이어갈 시간을 알려드려요.",
                Importance = Importance.Default,
                EnableVibration = true,
                LockScreenVisibility = LockScreenVisibility.Private
            };
            AndroidNotificationCenter.RegisterNotificationChannel(channel);
#endif
        }

        private void OnApplicationPause(bool paused)
        {
#if UNITY_ANDROID
            if (!paused && IsInstallBound)
            {
                CaptureLaunchIntent();
#if !UNITY_EDITOR
                if (_enabled && AndroidNotificationCenter.UserPermissionToPost == PermissionStatus.Allowed)
                    ScheduleNext();
#endif
            }
#endif
        }

        private void CaptureLaunchIntent()
        {
            if (!IsInstallBound) return;
#if UNITY_ANDROID
            AndroidNotificationIntentData data = AndroidNotificationCenter.GetLastNotificationIntent();
            string token = data?.Notification.IntentData;
            if (string.IsNullOrWhiteSpace(token) ||
                !ReminderOpenPolicy.TryCreate(token, out ReminderOpenRequest request) ||
                !string.Equals(
                    request.Intent.InstallEpoch,
                    _installEpoch,
                    StringComparison.Ordinal) ||
                _resetIntentGuard.ShouldIgnore(request.StableTokenHash) ||
                string.Equals(
                    request.StableTokenHash,
                    _pendingOpenRequest?.StableTokenHash,
                    StringComparison.Ordinal)) return;
            _pendingOpenRequest = request;
            ReminderOpenAvailable?.Invoke();
#endif
        }

        private void TombstoneAndClearCurrentReminderIntent()
        {
#if UNITY_ANDROID
            if (_pendingOpenRequest != null)
                _resetIntentGuard.Ignore(_pendingOpenRequest.StableTokenHash);

            bool activityHasReminder = false;
            AndroidNotificationIntentData data = AndroidNotificationCenter.GetLastNotificationIntent();
            string token = data?.Notification.IntentData;
            if (!string.IsNullOrWhiteSpace(token) &&
                ReminderOpenPolicy.TryCreate(token, out ReminderOpenRequest request))
            {
                _resetIntentGuard.Ignore(request.StableTokenHash);
                activityHasReminder = true;
            }

#if !UNITY_EDITOR
            if (!activityHasReminder) return;
            try
            {
                using var player = new AndroidJavaClass("com.unity3d.player.UnityPlayer");
                using AndroidJavaObject activity =
                    player.GetStatic<AndroidJavaObject>("currentActivity");
                using var emptyIntent = new AndroidJavaObject("android.content.Intent");
                activity.Call("setIntent", emptyIntent);
            }
            catch (Exception)
            {
                // The process-local tombstone still suppresses this Activity's stale intent.
            }
#else
            _ = activityHasReminder;
#endif
#endif
        }

        private string AskedKey => _askedKey ??
            throw new InvalidOperationException("reminder.install_not_bound");

        private void BindInstallNamespace(string installId)
        {
            _installId = installId;
            _installEpoch = InstallScopedLocalStatePolicy.Epoch(installId);
            _askedKey = InstallScopedLocalStatePolicy.ReminderAskedKey(installId);
        }

        private void TryReconcilePreparedResetBeforeStoreReady()
        {
            try
            {
                InstallResetJournalReadResult reset = AnonymousInstallIdentity.ReadPreparedReset();
                if (reset.Status == InstallResetJournalStatus.Pending)
                    ResetLocalStateCore(reset, reset.Record.CandidateInstallId);
            }
            catch (Exception)
            {
                ClearInstallBinding();
            }
        }

        private void ClearInstallBinding()
        {
            if (_permissionRoutine != null)
            {
                StopCoroutine(_permissionRoutine);
                _permissionRoutine = null;
            }
#if UNITY_ANDROID
            CancelAllReminders();
#endif
            _installId = null;
            _installEpoch = null;
            _askedKey = null;
            _capturedLaunchIntentEpoch = null;
            _pendingOpenRequest = null;
            _plan = null;
            _enablementPolicy.Reset();
            _enabled = false;
        }

    }
}
