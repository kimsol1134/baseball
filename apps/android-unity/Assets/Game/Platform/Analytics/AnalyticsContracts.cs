using System;
using System.Collections.Generic;

namespace Baseball.Platform.Analytics
{
    public enum AnalyticsDestinationKind
    {
        Firebase,
        Amplitude,
        Test
    }

    public enum AnalyticsDistribution
    {
        Editor,
        Development,
        Internal,
        Closed,
        Production
    }

    public sealed class AnalyticsContext
    {
        public AnalyticsContext(string appVersion, string build, AnalyticsDistribution distribution)
        {
            AppVersion = string.IsNullOrWhiteSpace(appVersion) ? "unknown" : appVersion;
            Build = string.IsNullOrWhiteSpace(build) ? "unknown" : build;
            Distribution = distribution;
        }

        public string AppVersion { get; }
        public string Build { get; }
        public AnalyticsDistribution Distribution { get; }
        public string Environment => Distribution == AnalyticsDistribution.Production ? "production" : "development";

        public IReadOnlyDictionary<string, object> Properties()
        {
            return new Dictionary<string, object>(StringComparer.Ordinal)
            {
                ["app_version"] = AppVersion,
                ["build"] = Build,
                ["distribution"] = DistributionValue(Distribution),
                ["environment"] = Environment,
                ["platform"] = "android",
                ["event_schema_version"] = 2L
            };
        }

        public static string DistributionValue(AnalyticsDistribution value)
        {
            switch (value)
            {
                case AnalyticsDistribution.Editor: return "editor";
                case AnalyticsDistribution.Development: return "development";
                case AnalyticsDistribution.Internal: return "internal";
                case AnalyticsDistribution.Closed: return "closed";
                case AnalyticsDistribution.Production: return "production";
                default: throw new ArgumentOutOfRangeException(nameof(value), value, null);
            }
        }
    }

    public interface IAnalyticsDestination
    {
        AnalyticsDestinationKind Kind { get; }
        bool IsReady { get; }
        void SetAnonymousInstallId(string installId);
        void Log(string eventName, IReadOnlyDictionary<string, object> properties);
        void Flush();
    }

    public interface IAnalyticsOnceStore
    {
        bool TryMark(string key);
        void Clear();
    }
}
