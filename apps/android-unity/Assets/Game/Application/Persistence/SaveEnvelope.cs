using System;
using System.Collections.Generic;

namespace Baseball.Application.Persistence
{
    public sealed class SaveEnvelope<TPayload>
    {
        public SaveEnvelope(
            string schema,
            int schemaVersion,
            ulong revision,
            DateTimeOffset writtenAtUtc,
            string payloadSha256,
            TPayload payload)
        {
            Schema = schema ?? throw new ArgumentNullException(nameof(schema));
            SchemaVersion = schemaVersion;
            Revision = revision;
            WrittenAtUtc = writtenAtUtc;
            PayloadSha256 = payloadSha256 ?? throw new ArgumentNullException(nameof(payloadSha256));
            Payload = payload ?? throw new ArgumentNullException(nameof(payload));
        }

        public string Schema { get; }

        public int SchemaVersion { get; }

        public ulong Revision { get; }

        public DateTimeOffset WrittenAtUtc { get; }

        public string PayloadSha256 { get; }

        public TPayload Payload { get; }
    }

    public sealed class SaveWriteResult<TPayload>
    {
        public SaveWriteResult(SaveEnvelope<TPayload> envelope, string canonicalPath)
        {
            Envelope = envelope ?? throw new ArgumentNullException(nameof(envelope));
            CanonicalPath = canonicalPath ?? throw new ArgumentNullException(nameof(canonicalPath));
        }

        public SaveEnvelope<TPayload> Envelope { get; }

        public string CanonicalPath { get; }
    }

    public enum SaveLoadStatus
    {
        NoSave,
        LoadedCanonical,
        RecoveredBackup,
        UnrecoverableCorruption,
        FutureVersion,
        MigrationRequired
    }

    public sealed class SaveLoadResult<TPayload>
    {
        private SaveLoadResult(
            SaveLoadStatus status,
            SaveEnvelope<TPayload> envelope,
            string sourcePath,
            IReadOnlyList<string> quarantinedPaths,
            IReadOnlyList<string> diagnostics)
        {
            Status = status;
            Envelope = envelope;
            SourcePath = sourcePath;
            QuarantinedPaths = quarantinedPaths ?? Array.Empty<string>();
            Diagnostics = diagnostics ?? Array.Empty<string>();
        }

        public SaveLoadStatus Status { get; }

        public SaveEnvelope<TPayload> Envelope { get; }

        public string SourcePath { get; }

        public IReadOnlyList<string> QuarantinedPaths { get; }

        public IReadOnlyList<string> Diagnostics { get; }

        public bool HasPayload => Envelope != null;

        public bool RequiresRecoveryNotice => Status == SaveLoadStatus.RecoveredBackup;

        public static SaveLoadResult<TPayload> Create(
            SaveLoadStatus status,
            SaveEnvelope<TPayload> envelope = null,
            string sourcePath = null,
            IReadOnlyList<string> quarantinedPaths = null,
            IReadOnlyList<string> diagnostics = null)
        {
            return new SaveLoadResult<TPayload>(
                status,
                envelope,
                sourcePath,
                quarantinedPaths,
                diagnostics);
        }
    }
}
