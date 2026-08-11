using System;
using System.Collections.Generic;
using System.Linq;
using Baseball.Core.Random;

namespace Baseball.Application.Meta
{
    public enum AnalyticsReceiptRetention
    {
        Lifetime = 0,
        Scoped = 1
    }

    /// <summary>
    /// A durable, PII-free proof that a one-shot analytics event may no longer be emitted.
    /// Product code must persist this receipt before handing the matching event to the SDK.
    /// </summary>
    public sealed class AnalyticsReceiptRecord
    {
        public AnalyticsReceiptRecord(
            string scopeId,
            long recordedAtUnixSeconds,
            AnalyticsReceiptRetention retention = AnalyticsReceiptRetention.Lifetime)
        {
            ScopeId = scopeId;
            RecordedAtUnixSeconds = recordedAtUnixSeconds;
            Retention = retention;
        }

        public string ScopeId { get; }
        public long RecordedAtUnixSeconds { get; }
        public AnalyticsReceiptRetention Retention { get; }
    }

    public sealed class AnalyticsReceiptState
    {
        public const int CurrentSchemaVersion = 1;
        public const int MaximumLifetimeReceipts = 128;
        public const int MaximumScopedReceipts = 512;
        public const int MaximumReceipts = MaximumLifetimeReceipts + MaximumScopedReceipts;

        public AnalyticsReceiptState(
            int schemaVersion = CurrentSchemaVersion,
            IReadOnlyList<AnalyticsReceiptRecord> records = null)
        {
            SchemaVersion = schemaVersion;
            Records = (records ?? Array.Empty<AnalyticsReceiptRecord>()).ToArray();
        }

        public int SchemaVersion { get; }
        public IReadOnlyList<AnalyticsReceiptRecord> Records { get; }

        public bool Contains(string scopeId) =>
            !string.IsNullOrWhiteSpace(scopeId) && Records.Any(value =>
                value != null && string.Equals(value.ScopeId, scopeId, StringComparison.Ordinal));

        public static AnalyticsReceiptState Empty { get; } = new AnalyticsReceiptState();
    }

    public static class AnalyticsReceiptRules
    {
        /// <summary>
        /// Derives a stable opaque scope without persisting raw career, experiment, or receipt
        /// identifiers. eventId is a controlled product token; stableScopeParts are hash input only.
        /// </summary>
        public static string Scope(string eventId, params string[] stableScopeParts)
        {
            if (!ValidEventId(eventId))
                throw new ArgumentException("analytics.event_id_invalid", nameof(eventId));
            if (stableScopeParts == null || stableScopeParts.Length == 0 ||
                stableScopeParts.Any(string.IsNullOrWhiteSpace))
            {
                throw new ArgumentException("analytics.scope_parts_invalid", nameof(stableScopeParts));
            }

            var material = eventId + "|" + string.Join("|", stableScopeParts);
            return "once:" + eventId + ":" + StableHash.Fnv1A64Value(material).ToString("x16");
        }

        public static bool IsValidScope(string scopeId)
        {
            if (string.IsNullOrWhiteSpace(scopeId) || scopeId.Length > 96 ||
                !scopeId.StartsWith("once:", StringComparison.Ordinal))
            {
                return false;
            }
            for (var index = 0; index < scopeId.Length; index++)
            {
                var character = scopeId[index];
                if (!(character >= 'a' && character <= 'z') &&
                    !(character >= '0' && character <= '9') &&
                    character != ':' && character != '_' && character != '-' && character != '.')
                {
                    return false;
                }
            }
            return true;
        }

        public static AnalyticsReceiptState Mark(
            AnalyticsReceiptState current,
            string scopeId,
            DateTimeOffset recordedAt,
            AnalyticsReceiptRetention retention = AnalyticsReceiptRetention.Lifetime)
        {
            if (!IsValidScope(scopeId))
                throw new ArgumentException("analytics.scope_invalid", nameof(scopeId));
            if (!Enum.IsDefined(typeof(AnalyticsReceiptRetention), retention))
                throw new ArgumentOutOfRangeException(nameof(retention));
            current = current ?? AnalyticsReceiptState.Empty;
            if (current.Contains(scopeId)) return current;
            if (retention == AnalyticsReceiptRetention.Lifetime &&
                current.Records.Count(value =>
                    value?.Retention == AnalyticsReceiptRetention.Lifetime) >=
                AnalyticsReceiptState.MaximumLifetimeReceipts)
            {
                throw new InvalidOperationException("analytics.lifetime_capacity");
            }

            var distinct = current.Records
                .Where(value => value != null && IsValidScope(value.ScopeId))
                .Concat(new[]
                {
                    new AnalyticsReceiptRecord(scopeId, recordedAt.ToUnixTimeSeconds(), retention)
                })
                .GroupBy(value => value.ScopeId, StringComparer.Ordinal)
                .Select(group => group
                    .OrderByDescending(value => value.RecordedAtUnixSeconds)
                    .First())
                .ToArray();
            var lifetime = distinct
                .Where(value => value.Retention == AnalyticsReceiptRetention.Lifetime);
            var scoped = distinct
                .Where(value => value.Retention == AnalyticsReceiptRetention.Scoped)
                .OrderByDescending(value => value.RecordedAtUnixSeconds)
                .ThenBy(value => value.ScopeId, StringComparer.Ordinal)
                .Take(AnalyticsReceiptState.MaximumScopedReceipts);
            var records = lifetime.Concat(scoped)
                .OrderByDescending(value => value.RecordedAtUnixSeconds)
                .ThenBy(value => value.ScopeId, StringComparer.Ordinal)
                .ToArray();
            return new AnalyticsReceiptState(AnalyticsReceiptState.CurrentSchemaVersion, records);
        }

        public static bool IsValid(AnalyticsReceiptState state)
        {
            return state != null &&
                state.SchemaVersion == AnalyticsReceiptState.CurrentSchemaVersion &&
                state.Records != null &&
                state.Records.Count <= AnalyticsReceiptState.MaximumReceipts &&
                state.Records.Count(value =>
                    value?.Retention == AnalyticsReceiptRetention.Lifetime) <=
                    AnalyticsReceiptState.MaximumLifetimeReceipts &&
                state.Records.Count(value =>
                    value?.Retention == AnalyticsReceiptRetention.Scoped) <=
                    AnalyticsReceiptState.MaximumScopedReceipts &&
                state.Records.All(value => value != null &&
                    IsValidScope(value.ScopeId) && value.RecordedAtUnixSeconds >= 0 &&
                    Enum.IsDefined(typeof(AnalyticsReceiptRetention), value.Retention)) &&
                state.Records.Select(value => value.ScopeId)
                    .Distinct(StringComparer.Ordinal).Count() == state.Records.Count;
        }

        private static bool ValidEventId(string eventId)
        {
            if (string.IsNullOrWhiteSpace(eventId) || eventId.Length > 48) return false;
            for (var index = 0; index < eventId.Length; index++)
            {
                var character = eventId[index];
                if (!(character >= 'a' && character <= 'z') &&
                    !(character >= '0' && character <= '9') &&
                    character != '_' && character != '-')
                {
                    return false;
                }
            }
            return true;
        }
    }
}
