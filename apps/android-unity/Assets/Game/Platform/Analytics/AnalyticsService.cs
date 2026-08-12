using System;
using System.Collections.Generic;
using Baseball.Core.Random;

namespace Baseball.Platform.Analytics
{
    public sealed class AnalyticsService
    {
        private readonly object _stateGate = new object();
        private readonly AnalyticsContext _context;
        private readonly IReadOnlyList<IAnalyticsDestination> _destinations;
        private readonly Func<string, IAnalyticsOnceStore> _onceStoreForInstall;
        private IAnalyticsOnceStore _onceStore;

        public AnalyticsService(
            AnalyticsContext context,
            IReadOnlyList<IAnalyticsDestination> destinations,
            IAnalyticsOnceStore onceStore,
            string anonymousInstallId,
            Func<string, IAnalyticsOnceStore> onceStoreForInstall = null)
        {
            _context = context ?? throw new ArgumentNullException(nameof(context));
            _destinations = destinations ?? throw new ArgumentNullException(nameof(destinations));
            _onceStore = onceStore ?? throw new ArgumentNullException(nameof(onceStore));
            _onceStoreForInstall = onceStoreForInstall;

            foreach (IAnalyticsDestination destination in _destinations)
            {
                Try(() => destination.SetAnonymousInstallId(anonymousInstallId));
            }
        }

        public void Log(AnalyticsEvent analyticsEvent, IReadOnlyDictionary<string, object> properties = null)
        {
            Dictionary<string, object> product = AnalyticsPrivacyGuard.ValidateAndCopy(properties);
            lock (_stateGate)
            {
                LogValidated(analyticsEvent, product);
            }
        }

        public bool LogOnce(AnalyticsEvent analyticsEvent, IReadOnlyDictionary<string, object> properties = null)
        {
            Dictionary<string, object> product = AnalyticsPrivacyGuard.ValidateAndCopy(properties);
            lock (_stateGate)
            {
                if (!_onceStore.TryMark("event:" + analyticsEvent.Value())) return false;
                LogValidated(analyticsEvent, product);
                return true;
            }
        }

        public bool LogOnce(
            AnalyticsEvent analyticsEvent,
            string localScope,
            IReadOnlyDictionary<string, object> properties = null)
        {
            Dictionary<string, object> product = AnalyticsPrivacyGuard.ValidateAndCopy(properties);
            string scopeHash = StableHash.Fnv1A64(localScope ?? string.Empty);
            lock (_stateGate)
            {
                if (!_onceStore.TryMark("scope:" + analyticsEvent.Value() + ":" + scopeHash)) return false;
                LogValidated(analyticsEvent, product);
                return true;
            }
        }

        public void Flush()
        {
            lock (_stateGate)
            {
                foreach (IAnalyticsDestination destination in _destinations)
                {
                    if (destination.IsReady) Try(destination.Flush);
                }
            }
        }

        public void ResetIdentityAndOnceFlags()
        {
            lock (_stateGate)
            {
                Try(_onceStore.Clear);
            }
        }

        public void ResetIdentityAndOnceFlags(string anonymousInstallId)
        {
            if (string.IsNullOrWhiteSpace(anonymousInstallId))
                throw new ArgumentException("An anonymous install ID is required.", nameof(anonymousInstallId));
            lock (_stateGate)
            {
                IAnalyticsOnceStore previous = _onceStore;
                IAnalyticsOnceStore replacement = _onceStoreForInstall == null
                    ? previous
                    : _onceStoreForInstall(anonymousInstallId) ??
                      throw new InvalidOperationException("analytics.once_store_factory_returned_null");
                Try(previous.Clear);
                if (!ReferenceEquals(previous, replacement)) Try(replacement.Clear);
                _onceStore = replacement;
                foreach (IAnalyticsDestination destination in _destinations)
                {
                    Try(() => destination.SetAnonymousInstallId(anonymousInstallId));
                }
            }
        }

        private void LogValidated(
            AnalyticsEvent analyticsEvent,
            IReadOnlyDictionary<string, object> product)
        {
            foreach (IAnalyticsDestination destination in _destinations)
            {
                if (!destination.IsReady) continue;
                Dictionary<string, object> payload = PayloadFor(destination.Kind, product);
                Try(() => destination.Log(analyticsEvent.Value(), payload));
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
