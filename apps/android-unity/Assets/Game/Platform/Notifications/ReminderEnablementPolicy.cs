namespace Baseball.Platform.Notifications
{
    public enum ReminderPermissionAvailability
    {
        Allowed,
        Requestable,
        Denied,
    }

    public readonly struct ReminderRequestResolution
    {
        public ReminderRequestResolution(
            bool effectiveEnabled,
            bool requestsPermission,
            bool publishesOutcome)
        {
            EffectiveEnabled = effectiveEnabled;
            RequestsPermission = requestsPermission;
            PublishesOutcome = publishesOutcome;
        }

        public bool EffectiveEnabled { get; }
        public bool RequestsPermission { get; }
        public bool PublishesOutcome { get; }
    }

    /// <summary>
    /// Pure permission/result policy. Product settings are updated only from a published OS
    /// outcome; applying an already-saved value never pretends that permission was granted.
    /// </summary>
    public sealed class ReminderEnablementPolicy
    {
        private bool _persistedDenialPending;
        private bool _persistedDenialConfirmed;

        public static ReminderRequestResolution Request(
            bool requestedEnabled,
            ReminderPermissionAvailability permission)
        {
            if (!requestedEnabled)
                return new ReminderRequestResolution(false, false, true);
            if (permission == ReminderPermissionAvailability.Allowed)
                return new ReminderRequestResolution(true, false, true);
            if (permission == ReminderPermissionAvailability.Requestable)
                return new ReminderRequestResolution(false, true, false);
            return new ReminderRequestResolution(false, false, true);
        }

        /// <summary>
        /// Returns true once while a persisted enabled value no longer has OS permission. The
        /// caller must resolve the attempt after the aggregate save; a failed/busy save becomes
        /// retryable without allowing repeated render callbacks to enqueue duplicates.
        /// </summary>
        public bool ShouldPublishPersistedDenial(bool persistedEnabled, bool permissionAllowed)
        {
            if (!persistedEnabled || permissionAllowed)
            {
                _persistedDenialPending = false;
                _persistedDenialConfirmed = false;
                return false;
            }
            if (_persistedDenialPending || _persistedDenialConfirmed) return false;
            _persistedDenialPending = true;
            return true;
        }

        public void ResolvePersistedDenial(bool saved)
        {
            if (!_persistedDenialPending) return;
            _persistedDenialPending = false;
            _persistedDenialConfirmed = saved;
        }

        public void Reset()
        {
            _persistedDenialPending = false;
            _persistedDenialConfirmed = false;
        }
    }
}
