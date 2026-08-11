using System.Collections.Generic;

namespace Baseball.Platform.Analytics
{
    public sealed class NoOpAnalyticsDestination : IAnalyticsDestination
    {
        public AnalyticsDestinationKind Kind => AnalyticsDestinationKind.Test;
        public bool IsReady => false;
        public void SetAnonymousInstallId(string installId) { }
        public void Log(string eventName, IReadOnlyDictionary<string, object> properties) { }
        public void Flush() { }
    }
}
