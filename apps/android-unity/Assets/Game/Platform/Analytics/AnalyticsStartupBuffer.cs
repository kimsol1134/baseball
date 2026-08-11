using System;
using System.Collections.Generic;

namespace Baseball.Platform.Analytics
{
    /// <summary>
    /// Bounded FIFO used only while analytics destinations are initializing. Product receipts are
    /// durable before they reach this boundary, so startup must retain ordering without blocking UI.
    /// </summary>
    internal sealed class AnalyticsStartupBuffer
    {
        internal const int ProductionCapacity = 128;
        private readonly int _capacity;
        private readonly Queue<AnalyticsStartupEvent> _events;

        public AnalyticsStartupBuffer(int capacity)
        {
            if (capacity <= 0) throw new ArgumentOutOfRangeException(nameof(capacity));
            _capacity = capacity;
            _events = new Queue<AnalyticsStartupEvent>(capacity);
        }

        public int Count => _events.Count;

        public void Enqueue(
            AnalyticsEvent analyticsEvent,
            IReadOnlyDictionary<string, object> validatedProperties)
        {
            // A startup burst larger than the documented ceiling retains the most recent events;
            // the oldest event is discarded deterministically.
            if (_events.Count == _capacity) _events.Dequeue();
            _events.Enqueue(new AnalyticsStartupEvent(analyticsEvent, validatedProperties));
        }

        public AnalyticsStartupEvent[] Drain()
        {
            AnalyticsStartupEvent[] result = _events.ToArray();
            _events.Clear();
            return result;
        }

        public void Clear() => _events.Clear();
    }

    internal readonly struct AnalyticsStartupEvent
    {
        public AnalyticsStartupEvent(
            AnalyticsEvent analyticsEvent,
            IReadOnlyDictionary<string, object> properties)
        {
            Event = analyticsEvent;
            Properties = properties;
        }

        public AnalyticsEvent Event { get; }
        public IReadOnlyDictionary<string, object> Properties { get; }
    }
}
