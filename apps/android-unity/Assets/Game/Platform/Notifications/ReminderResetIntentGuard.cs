using System;
using System.Collections.Generic;

namespace Baseball.Platform.Notifications
{
    /// <summary>
    /// Process-local tombstones for reminder intents that belonged to the identity erased by
    /// reset-all. The Android Activity intent is cleared as the durable boundary; this guard
    /// closes the same-process pause/resume race while allowing a newly delivered token.
    /// </summary>
    public sealed class ReminderResetIntentGuard
    {
        private const int MaximumTombstones = 8;
        private readonly HashSet<string> _ignored =
            new HashSet<string>(StringComparer.Ordinal);
        private readonly Queue<string> _order = new Queue<string>();

        public void Ignore(string stableTokenHash)
        {
            if (string.IsNullOrWhiteSpace(stableTokenHash) || !_ignored.Add(stableTokenHash)) return;
            _order.Enqueue(stableTokenHash);
            while (_order.Count > MaximumTombstones)
            {
                _ignored.Remove(_order.Dequeue());
            }
        }

        public bool ShouldIgnore(string stableTokenHash) =>
            !string.IsNullOrWhiteSpace(stableTokenHash) && _ignored.Contains(stableTokenHash);
    }
}
