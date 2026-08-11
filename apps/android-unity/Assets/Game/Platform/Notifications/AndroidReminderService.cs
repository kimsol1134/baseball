using System;
using System.Collections;
using System.Collections.Generic;
using Unity.Notifications.Android;
using UnityEngine;

namespace Baseball.Platform.Notifications
{
    [DefaultExecutionOrder(-8700)]
    public sealed class AndroidReminderService : MonoBehaviour
    {
        public const string ChannelId = "return-reminder-v1";
        public const string SmallIconId = "baseball_notification_small";

        private const string AskedKey = "baseball.reminder.permission-asked.v1";
        private static AndroidReminderService _instance;
        private ReminderOpenRequest _pendingOpenRequest;
        private Coroutine _permissionRoutine;
        private bool _enabled;
        private readonly ReminderEnablementPolicy _enablementPolicy = new ReminderEnablementPolicy();
        private AndroidReminderPlan _plan;
        private IReadOnlyCollection<string> _playedDayKeys = Array.Empty<string>();

        public static AndroidReminderService Instance => _instance;
        public bool IsEnabled => _enabled;
        public bool ShouldOfferOptIn => !_enabled && PlayerPrefs.GetInt(AskedKey, 0) == 0;
        public bool RequiresSystemSettings
        {
            get
            {
#if UNITY_ANDROID && !UNITY_EDITOR
                PermissionStatus status = AndroidNotificationCenter.UserPermissionToPost;
                return status == PermissionStatus.NotificationsBlockedForApp ||
                    (PlayerPrefs.GetInt(AskedKey, 0) == 1 && status != PermissionStatus.Allowed);
#else
                return false;
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
            CaptureLaunchIntent();
#endif
        }

        /// <summary>Applies the saved product setting without logging a user change.</summary>
        public void ApplySavedEnabled(bool enabled)
        {
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
        public void RequestEnabled(bool enabled)
        {
#if UNITY_ANDROID && !UNITY_EDITOR
            PermissionStatus status = AndroidNotificationCenter.UserPermissionToPost;
            ReminderPermissionAvailability permission = status == PermissionStatus.Allowed
                ? ReminderPermissionAvailability.Allowed
                : PlayerPrefs.GetInt(AskedKey, 0) == 1 ||
                    status == PermissionStatus.NotificationsBlockedForApp
                    ? ReminderPermissionAvailability.Denied
                    : ReminderPermissionAvailability.Requestable;
            ReminderRequestResolution resolution = ReminderEnablementPolicy.Request(enabled, permission);
            if (resolution.RequestsPermission)
            {
                if (_permissionRoutine != null) return;
                PlayerPrefs.SetInt(AskedKey, 1);
                PlayerPrefs.Save();
                _permissionRoutine = StartCoroutine(RequestPermission());
                return;
            }
            SetEffectiveEnabled(resolution.EffectiveEnabled);
            if (resolution.EffectiveEnabled)
                ScheduleNext();
            if (resolution.PublishesOutcome)
                EnablementChanged?.Invoke(resolution.EffectiveEnabled, "settings");
#else
            ReminderRequestResolution resolution = ReminderEnablementPolicy.Request(
                enabled,
                ReminderPermissionAvailability.Allowed);
            SetEffectiveEnabled(resolution.EffectiveEnabled);
            if (resolution.PublishesOutcome)
                EnablementChanged?.Invoke(resolution.EffectiveEnabled, "settings");
#endif
        }

        public void DeclineOptIn()
        {
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
            if (_permissionRoutine != null)
            {
                StopCoroutine(_permissionRoutine);
                _permissionRoutine = null;
            }
#if UNITY_ANDROID
            CancelAllReminders();
#endif
            PlayerPrefs.DeleteKey(AskedKey);
            PlayerPrefs.Save();
            _pendingOpenRequest = null;
            _plan = null;
            _playedDayKeys = Array.Empty<string>();
            _enablementPolicy.Reset();
            SetEffectiveEnabled(false);
        }

        public void ConfigurePlan(AndroidReminderPlan plan, IReadOnlyCollection<string> playedDayKeys)
        {
            _plan = plan;
            _playedDayKeys = playedDayKeys ?? Array.Empty<string>();
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

        private IEnumerator RequestPermission()
        {
            var request = new PermissionRequest();
            while (request.Status == PermissionStatus.RequestPending) yield return null;
            _permissionRoutine = null;
            bool allowed = request.Status == PermissionStatus.Allowed;
            SetEffectiveEnabled(allowed);
            if (allowed) ScheduleNext();
            EnablementChanged?.Invoke(allowed, "settings");
        }

        private void ScheduleNext()
        {
#if UNITY_ANDROID && !UNITY_EDITOR
            CancelAllReminders();
            if (_plan == null) return;
            foreach (SeoulReminderEntry entry in SeoulReminderSchedule.Upcoming(
                         DateTimeOffset.UtcNow,
                         _plan.Destination == "daily_inning" ? _playedDayKeys : Array.Empty<string>()))
            {
                var notification = new AndroidNotification
                {
                    Title = _plan.Title,
                    Text = _plan.Body,
                    FireTime = entry.FireUtc.UtcDateTime,
                    IntentData = _plan.IntentData(entry.DayKey),
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
            if (!paused)
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
#if UNITY_ANDROID
            AndroidNotificationIntentData data = AndroidNotificationCenter.GetLastNotificationIntent();
            string token = data?.Notification.IntentData;
            if (string.IsNullOrWhiteSpace(token) ||
                !ReminderOpenPolicy.TryCreate(token, out ReminderOpenRequest request) ||
                string.Equals(
                    request.StableTokenHash,
                    _pendingOpenRequest?.StableTokenHash,
                    StringComparison.Ordinal)) return;
            _pendingOpenRequest = request;
            ReminderOpenAvailable?.Invoke();
#endif
        }

    }
}
