using System;
using System.Collections.Generic;
using Baseball.Core.Random;

namespace Baseball.Platform.Analytics
{
    public sealed class AnalyticsService
    {
        private readonly AnalyticsContext _context;
        private readonly IReadOnlyList<IAnalyticsDestination> _destinations;
        private readonly IAnalyticsOnceStore _onceStore;

        public AnalyticsService(
            AnalyticsContext context,
            IReadOnlyList<IAnalyticsDestination> destinations,
            IAnalyticsOnceStore onceStore,
            string anonymousInstallId)
        {
            _context = context ?? throw new ArgumentNullException(nameof(context));
            _destinations = destinations ?? throw new ArgumentNullException(nameof(destinations));
            _onceStore = onceStore ?? throw new ArgumentNullException(nameof(onceStore));

            foreach (IAnalyticsDestination destination in _destinations)
            {
                Try(() => destination.SetAnonymousInstallId(anonymousInstallId));
            }
        }

        public void Log(AnalyticsEvent analyticsEvent, IReadOnlyDictionary<string, object> properties = null)
        {
            Dictionary<string, object> product = AnalyticsPrivacyGuard.ValidateAndCopy(properties);
            foreach (IAnalyticsDestination destination in _destinations)
            {
                if (!destination.IsReady) continue;
                Dictionary<string, object> payload = PayloadFor(destination.Kind, product);
                Try(() => destination.Log(analyticsEvent.Value(), payload));
            }
        }

        public bool LogOnce(AnalyticsEvent analyticsEvent, IReadOnlyDictionary<string, object> properties = null)
        {
            if (!_onceStore.TryMark("event:" + analyticsEvent.Value())) return false;
            Log(analyticsEvent, properties);
            return true;
        }

        public bool LogOnce(
            AnalyticsEvent analyticsEvent,
            string localScope,
            IReadOnlyDictionary<string, object> properties = null)
        {
            string scopeHash = StableHash.Fnv1A64(localScope ?? string.Empty);
            if (!_onceStore.TryMark("scope:" + analyticsEvent.Value() + ":" + scopeHash)) return false;
            Log(analyticsEvent, properties);
            return true;
        }

        public void Flush()
        {
            foreach (IAnalyticsDestination destination in _destinations)
            {
                if (destination.IsReady) Try(destination.Flush);
            }
        }

        public void ResetIdentityAndOnceFlags()
        {
            _onceStore.Clear();
        }

        public void ResetIdentityAndOnceFlags(string anonymousInstallId)
        {
            if (string.IsNullOrWhiteSpace(anonymousInstallId))
                throw new ArgumentException("An anonymous install ID is required.", nameof(anonymousInstallId));
            _onceStore.Clear();
            foreach (IAnalyticsDestination destination in _destinations)
            {
                Try(() => destination.SetAnonymousInstallId(anonymousInstallId));
            }
        }

        private Dictionary<string, object> PayloadFor(
            AnalyticsDestinationKind destination,
            IReadOnlyDictionary<string, object> product)
        {
            var payload = new Dictionary<string, object>(StringComparer.Ordinal);
            foreach (KeyValuePair<string, object> pair in product) payload[pair.Key] = pair.Value;
            foreach (KeyValuePair<string, object> pair in _context.Properties()) payload[pair.Key] = pair.Value;
            if (destination == AnalyticsDestinationKind.Amplitude)
            {
                payload["ingestion_origin"] = "android_unity_direct";
            }
            return payload;
        }

        private static void Try(Action action)
        {
            try { action(); }
            catch (Exception) { /* Analytics must always fail open. */ }
        }
    }
}
