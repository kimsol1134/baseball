using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

namespace Baseball.Application.Persistence
{
    public sealed class AtomicSaveRepository<TPayload> : ISaveRepository<TPayload>, IDisposable
    {
        private readonly SaveFileLayout _layout;
        private readonly IAtomicFileSystem _fileSystem;
        private readonly SaveJsonCodec<TPayload> _codec;
        private readonly ISaveSemanticPriority<TPayload> _semanticPriority;
        private readonly IUtcClock _clock;
        private readonly ISaveFaultInjector _faultInjector;
        private readonly SemaphoreSlim _gate = new SemaphoreSlim(1, 1);
        private bool _disposed;

        public AtomicSaveRepository(
            SaveFileLayout layout,
            IAtomicFileSystem fileSystem,
            ISavePayloadValidator<TPayload> validator,
            ISaveSemanticPriority<TPayload> semanticPriority = null,
            IUtcClock clock = null,
            ISaveFaultInjector faultInjector = null)
        {
            _layout = layout ?? throw new ArgumentNullException(nameof(layout));
            _fileSystem = fileSystem ?? throw new ArgumentNullException(nameof(fileSystem));
            _codec = new SaveJsonCodec<TPayload>(
                validator ?? throw new ArgumentNullException(nameof(validator)));
            _semanticPriority = semanticPriority ?? new DefaultSaveSemanticPriority<TPayload>();
            _clock = clock ?? new SystemUtcClock();
            _faultInjector = faultInjector ?? NoSaveFaults.Instance;
        }

        public async Task<SaveWriteResult<TPayload>> SaveAsync(
            TPayload payload,
            ulong revision,
            CancellationToken cancellationToken = default)
        {
            ThrowIfDisposed();
            await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
            try
            {
                return await Task.Run(
                        () => SaveCore(payload, revision, cancellationToken),
                        cancellationToken)
                    .ConfigureAwait(false);
            }
            finally
            {
                _gate.Release();
            }
        }

        public async Task<SaveLoadResult<TPayload>> LoadAsync(
            CancellationToken cancellationToken = default)
        {
            ThrowIfDisposed();
            await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
            try
            {
                return await Task.Run(
                        () => LoadCore(cancellationToken),
                        cancellationToken)
                    .ConfigureAwait(false);
            }
            finally
            {
                _gate.Release();
            }
        }

        public async Task ResetAsync(CancellationToken cancellationToken = default)
        {
            ThrowIfDisposed();
            await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
            try
            {
                await Task.Run(() => ResetCore(cancellationToken), cancellationToken)
                    .ConfigureAwait(false);
            }
            finally
            {
                _gate.Release();
            }
        }

        public void Dispose()
        {
            if (_disposed)
            {
                return;
            }

            _disposed = true;
            _gate.Dispose();
        }

        private SaveWriteResult<TPayload> SaveCore(
            TPayload payload,
            ulong revision,
            CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();
            _fileSystem.CreateDirectory(_layout.SaveDirectory);
            _faultInjector.Checkpoint(SaveFaultPoint.BeforeCandidateValidation);

            var candidate = _codec.CreateCandidate(payload, revision, _clock.UtcNow);
            _faultInjector.Checkpoint(SaveFaultPoint.AfterCandidateValidation);

            byte[] originalCanonicalBytes = null;
            var canonicalExisted = _fileSystem.FileExists(_layout.CanonicalPath);
            var canonicalSwapAttempted = false;
            Exception failure = null;

            try
            {
                _fileSystem.DeleteFile(_layout.TempPath);
                _fileSystem.WriteAllBytesAndFlush(_layout.TempPath, candidate.Bytes);
                _faultInjector.Checkpoint(SaveFaultPoint.AfterTempWrite);

                var tempCandidate = ParsePath(_layout.TempPath);
                RequireSameCandidate(tempCandidate, candidate.Envelope, "temp");
                _faultInjector.Checkpoint(SaveFaultPoint.AfterTempValidation);

                ParsedSaveCandidate<TPayload> currentCandidate = null;
                if (canonicalExisted)
                {
                    originalCanonicalBytes = _fileSystem.ReadAllBytes(_layout.CanonicalPath);
                    currentCandidate = _codec.Parse(originalCanonicalBytes);
                    RefuseUnsupportedCanonicalOverwrite(currentCandidate);
                    if (currentCandidate.Kind == ParsedSaveKind.Valid)
                    {
                        var revisionDecision = CompareRevision(currentCandidate, candidate.Envelope);
                        if (revisionDecision == RevisionDecision.Idempotent)
                        {
                            return new SaveWriteResult<TPayload>(
                                currentCandidate.Envelope,
                                _layout.CanonicalPath);
                        }
                    }
                }

                if (currentCandidate?.Kind == ParsedSaveKind.Valid)
                {
                    RotateValidCanonicalIntoBackups();
                }
                else if (canonicalExisted)
                {
                    CopyToQuarantine(_layout.CanonicalPath, "canonical");
                }

                _faultInjector.Checkpoint(SaveFaultPoint.AfterBackupRotation);
                cancellationToken.ThrowIfCancellationRequested();
                _faultInjector.Checkpoint(SaveFaultPoint.BeforeCanonicalSwap);

                canonicalSwapAttempted = true;
                if (canonicalExisted)
                {
                    _fileSystem.ReplaceFile(_layout.TempPath, _layout.CanonicalPath);
                }
                else
                {
                    _fileSystem.MoveFile(_layout.TempPath, _layout.CanonicalPath);
                }

                _faultInjector.Checkpoint(SaveFaultPoint.AfterCanonicalSwap);
                _faultInjector.Checkpoint(SaveFaultPoint.BeforeCanonicalVerification);
                var committedCandidate = ParsePath(_layout.CanonicalPath);
                RequireSameCandidate(committedCandidate, candidate.Envelope, "canonical");
                _faultInjector.Checkpoint(SaveFaultPoint.AfterCanonicalVerification);

                return new SaveWriteResult<TPayload>(
                    committedCandidate.Envelope,
                    _layout.CanonicalPath);
            }
            catch (Exception exception)
            {
                failure = exception;
                if (canonicalSwapAttempted)
                {
                    try
                    {
                        RestoreOriginalCanonical(canonicalExisted, originalCanonicalBytes, candidate.Bytes);
                    }
                    catch (Exception rollbackException)
                    {
                        failure = new AggregateException(exception, rollbackException);
                    }
                }

                if (failure is OperationCanceledException)
                {
                    throw failure;
                }

                if (failure is SavePersistenceException saveException)
                {
                    throw saveException;
                }

                throw new SavePersistenceException(
                    SaveFailureCode.IoFailed,
                    "The save could not be committed atomically.",
                    failure);
            }
            finally
            {
                TryDelete(_layout.TempPath);
                TryDelete(RollbackTempPath);
            }
        }

        private SaveLoadResult<TPayload> LoadCore(CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();
            _fileSystem.CreateDirectory(_layout.SaveDirectory);

            var diagnostics = new List<string>();
            var canonical = ReadLocatedCandidate(_layout.CanonicalPath, "canonical", 0, diagnostics);
            if (canonical != null)
            {
                if (canonical.Parsed.Kind == ParsedSaveKind.Valid)
                {
                    return SaveLoadResult<TPayload>.Create(
                        SaveLoadStatus.LoadedCanonical,
                        canonical.Parsed.Envelope,
                        canonical.Path,
                        diagnostics: diagnostics);
                }

                if (canonical.Parsed.Kind == ParsedSaveKind.FutureVersion)
                {
                    return SaveLoadResult<TPayload>.Create(
                        SaveLoadStatus.FutureVersion,
                        sourcePath: canonical.Path,
                        diagnostics: diagnostics);
                }

                if (canonical.Parsed.Kind == ParsedSaveKind.MigrationRequired)
                {
                    return SaveLoadResult<TPayload>.Create(
                        SaveLoadStatus.MigrationRequired,
                        sourcePath: canonical.Path,
                        diagnostics: diagnostics);
                }
            }

            var backups = new List<LocatedCandidate<TPayload>>();
            for (var position = 1; position <= SaveSchema.BackupCount; position++)
            {
                cancellationToken.ThrowIfCancellationRequested();
                var backup = ReadLocatedCandidate(
                    _layout.BackupPath(position),
                    "bak" + position,
                    position,
                    diagnostics);
                if (backup != null)
                {
                    backups.Add(backup);
                }
            }

            var validBackup = backups
                .Where(candidate => candidate.Parsed.Kind == ParsedSaveKind.Valid)
                .OrderByDescending(candidate => candidate.Parsed.Envelope.Revision)
                .ThenByDescending(candidate => GetSemanticPriority(candidate.Parsed.Envelope.Payload))
                .ThenBy(candidate => candidate.Rank)
                .FirstOrDefault();

            if (validBackup != null)
            {
                var quarantined = new List<string>();
                if (canonical != null && canonical.Parsed.Kind == ParsedSaveKind.Invalid)
                {
                    quarantined.Add(CopyToQuarantine(canonical.Path, canonical.Origin));
                }

                InstallRecoveredCanonical(validBackup.Parsed.Bytes, canonical != null);
                var restored = ParsePath(_layout.CanonicalPath);
                RequireSameCandidate(restored, validBackup.Parsed.Envelope, "recovered canonical");
                return SaveLoadResult<TPayload>.Create(
                    SaveLoadStatus.RecoveredBackup,
                    restored.Envelope,
                    validBackup.Path,
                    quarantined,
                    diagnostics);
            }

            var allCandidates = new List<LocatedCandidate<TPayload>>();
            if (canonical != null)
            {
                allCandidates.Add(canonical);
            }

            allCandidates.AddRange(backups);
            var unsupported = allCandidates.FirstOrDefault(
                candidate => candidate.Parsed.Kind == ParsedSaveKind.FutureVersion);
            if (unsupported != null)
            {
                return SaveLoadResult<TPayload>.Create(
                    SaveLoadStatus.FutureVersion,
                    sourcePath: unsupported.Path,
                    diagnostics: diagnostics);
            }

            unsupported = allCandidates.FirstOrDefault(
                candidate => candidate.Parsed.Kind == ParsedSaveKind.MigrationRequired);
            if (unsupported != null)
            {
                return SaveLoadResult<TPayload>.Create(
                    SaveLoadStatus.MigrationRequired,
                    sourcePath: unsupported.Path,
                    diagnostics: diagnostics);
            }

            if (allCandidates.Count == 0)
            {
                return SaveLoadResult<TPayload>.Create(
                    SaveLoadStatus.NoSave,
                    diagnostics: diagnostics);
            }

            var quarantinedPaths = new List<string>();
            foreach (var corrupt in allCandidates.Where(
                         candidate => candidate.Parsed.Kind == ParsedSaveKind.Invalid))
            {
                quarantinedPaths.Add(MoveToQuarantine(corrupt.Path, corrupt.Origin));
            }

            return SaveLoadResult<TPayload>.Create(
                SaveLoadStatus.UnrecoverableCorruption,
                quarantinedPaths: quarantinedPaths,
                diagnostics: diagnostics);
        }

        private void ResetCore(CancellationToken cancellationToken)
        {
            _fileSystem.CreateDirectory(_layout.SaveDirectory);

            // Canonical is deleted last. A process death before that point leaves the
            // previous canonical authoritative instead of reviving a partially deleted
            // backup after reset reports success.
            _fileSystem.DeleteFile(_layout.TempPath);
            _fileSystem.DeleteFile(RollbackTempPath);
            for (var position = SaveSchema.BackupCount; position >= 1; position--)
            {
                cancellationToken.ThrowIfCancellationRequested();
                _fileSystem.DeleteFile(_layout.BackupPath(position));
            }

            foreach (var quarantinePath in _fileSystem.GetFiles(
                         _layout.SaveDirectory,
                         "save.corrupt.*.json"))
            {
                cancellationToken.ThrowIfCancellationRequested();
                _fileSystem.DeleteFile(quarantinePath);
            }

            cancellationToken.ThrowIfCancellationRequested();
            _fileSystem.DeleteFile(_layout.CanonicalPath);

            if (_fileSystem.FileExists(_layout.CanonicalPath) ||
                _fileSystem.FileExists(_layout.TempPath) ||
                Enumerable.Range(1, SaveSchema.BackupCount)
                    .Any(position => _fileSystem.FileExists(_layout.BackupPath(position))) ||
                _fileSystem.GetFiles(_layout.SaveDirectory, "save.corrupt.*.json").Count != 0)
            {
                throw new SavePersistenceException(
                    SaveFailureCode.IoFailed,
                    "Local save reset verification failed.");
            }
        }

        private string RollbackTempPath => _layout.TempPath + ".rollback";

        private ParsedSaveCandidate<TPayload> ParsePath(string path)
        {
            return _codec.Parse(_fileSystem.ReadAllBytes(path));
        }

        private LocatedCandidate<TPayload> ReadLocatedCandidate(
            string path,
            string origin,
            int rank,
            ICollection<string> diagnostics)
        {
            if (!_fileSystem.FileExists(path))
            {
                return null;
            }

            try
            {
                var parsed = ParsePath(path);
                if (!string.IsNullOrEmpty(parsed.Diagnostic))
                {
                    diagnostics.Add(origin + ":" + parsed.Diagnostic);
                }

                return new LocatedCandidate<TPayload>(path, origin, rank, parsed);
            }
            catch (Exception exception)
            {
                throw new SavePersistenceException(
                    SaveFailureCode.IoFailed,
                    "A save candidate could not be read.",
                    exception);
            }
        }

        private static void RefuseUnsupportedCanonicalOverwrite(ParsedSaveCandidate<TPayload> candidate)
        {
            if (candidate.Kind == ParsedSaveKind.FutureVersion)
            {
                throw new SavePersistenceException(
                    SaveFailureCode.FutureVersionWouldBeOverwritten,
                    "A future save schema must not be overwritten.");
            }

            if (candidate.Kind == ParsedSaveKind.MigrationRequired)
            {
                throw new SavePersistenceException(
                    SaveFailureCode.MigrationRequired,
                    "An older save schema requires an explicit migration.");
            }
        }

        private static RevisionDecision CompareRevision(
            ParsedSaveCandidate<TPayload> current,
            SaveEnvelope<TPayload> candidate)
        {
            if (candidate.Revision < current.Envelope.Revision)
            {
                throw new SavePersistenceException(
                    SaveFailureCode.RevisionRegression,
                    "A save revision must not move backwards.");
            }

            if (candidate.Revision > current.Envelope.Revision)
            {
                return RevisionDecision.Advance;
            }

            if (!string.Equals(
                    candidate.PayloadSha256,
                    current.Envelope.PayloadSha256,
                    StringComparison.OrdinalIgnoreCase))
            {
                throw new SavePersistenceException(
                    SaveFailureCode.RevisionConflict,
                    "The same save revision must not contain different state.");
            }

            return RevisionDecision.Idempotent;
        }

        private static void RequireSameCandidate(
            ParsedSaveCandidate<TPayload> actual,
            SaveEnvelope<TPayload> expected,
            string location)
        {
            if (actual.Kind != ParsedSaveKind.Valid ||
                actual.Envelope.Revision != expected.Revision ||
                !string.Equals(
                    actual.Envelope.PayloadSha256,
                    expected.PayloadSha256,
                    StringComparison.OrdinalIgnoreCase))
            {
                throw new SavePersistenceException(
                    SaveFailureCode.VerificationFailed,
                    "The " + location + " save verification failed.");
            }
        }

        private void RotateValidCanonicalIntoBackups()
        {
            var backup1 = _layout.BackupPath(1);
            var backup2 = _layout.BackupPath(2);
            var backup3 = _layout.BackupPath(3);

            if (_fileSystem.FileExists(backup2))
            {
                _fileSystem.CopyFile(backup2, backup3, true);
            }

            if (_fileSystem.FileExists(backup1))
            {
                _fileSystem.CopyFile(backup1, backup2, true);
            }

            _fileSystem.CopyFile(_layout.CanonicalPath, backup1, true);
        }

        private void InstallRecoveredCanonical(byte[] bytes, bool canonicalExists)
        {
            _fileSystem.DeleteFile(_layout.TempPath);
            _fileSystem.WriteAllBytesAndFlush(_layout.TempPath, bytes);
            var temp = _codec.Parse(_fileSystem.ReadAllBytes(_layout.TempPath));
            if (temp.Kind != ParsedSaveKind.Valid)
            {
                throw new SavePersistenceException(
                    SaveFailureCode.VerificationFailed,
                    "The backup recovery candidate failed verification.");
            }

            if (canonicalExists)
            {
                _fileSystem.ReplaceFile(_layout.TempPath, _layout.CanonicalPath);
            }
            else
            {
                _fileSystem.MoveFile(_layout.TempPath, _layout.CanonicalPath);
            }
        }

        private void RestoreOriginalCanonical(
            bool canonicalExisted,
            byte[] originalCanonicalBytes,
            byte[] attemptedCandidateBytes)
        {
            if (!canonicalExisted)
            {
                if (_fileSystem.FileExists(_layout.CanonicalPath) &&
                    _fileSystem.ReadAllBytes(_layout.CanonicalPath).SequenceEqual(attemptedCandidateBytes))
                {
                    _fileSystem.DeleteFile(_layout.CanonicalPath);
                }

                return;
            }

            if (originalCanonicalBytes == null)
            {
                throw new InvalidOperationException("Original canonical bytes were not captured.");
            }

            if (_fileSystem.FileExists(_layout.CanonicalPath) &&
                _fileSystem.ReadAllBytes(_layout.CanonicalPath).SequenceEqual(originalCanonicalBytes))
            {
                return;
            }

            _fileSystem.DeleteFile(RollbackTempPath);
            _fileSystem.WriteAllBytesAndFlush(RollbackTempPath, originalCanonicalBytes);
            if (_fileSystem.FileExists(_layout.CanonicalPath))
            {
                _fileSystem.ReplaceFile(RollbackTempPath, _layout.CanonicalPath);
            }
            else
            {
                _fileSystem.MoveFile(RollbackTempPath, _layout.CanonicalPath);
            }

            if (!_fileSystem.ReadAllBytes(_layout.CanonicalPath).SequenceEqual(originalCanonicalBytes))
            {
                throw new SavePersistenceException(
                    SaveFailureCode.VerificationFailed,
                    "The previous canonical save could not be restored.");
            }
        }

        private string CopyToQuarantine(string sourcePath, string origin)
        {
            var quarantinePath = NextQuarantinePath(origin);
            _fileSystem.CopyFile(sourcePath, quarantinePath, false);
            return quarantinePath;
        }

        private string MoveToQuarantine(string sourcePath, string origin)
        {
            var quarantinePath = NextQuarantinePath(origin);
            _fileSystem.MoveFile(sourcePath, quarantinePath);
            return quarantinePath;
        }

        private string NextQuarantinePath(string origin)
        {
            for (var collisionIndex = 0; collisionIndex < 1000; collisionIndex++)
            {
                var candidate = _layout.QuarantinePath(_clock.UtcNow, origin, collisionIndex);
                if (!_fileSystem.FileExists(candidate))
                {
                    return candidate;
                }
            }

            throw new IOException("No unique quarantine path was available.");
        }

        private int GetSemanticPriority(TPayload payload)
        {
            try
            {
                return _semanticPriority.GetPriority(payload);
            }
            catch (Exception exception)
            {
                throw new SavePersistenceException(
                    SaveFailureCode.CandidateInvalid,
                    "The save semantic priority could not be evaluated.",
                    exception);
            }
        }

        private void TryDelete(string path)
        {
            try
            {
                _fileSystem.DeleteFile(path);
            }
            catch (Exception)
            {
                // Cleanup must never hide the commit or rollback outcome.
            }
        }

        private void ThrowIfDisposed()
        {
            if (_disposed)
            {
                throw new ObjectDisposedException(nameof(AtomicSaveRepository<TPayload>));
            }
        }
    }

    internal sealed class LocatedCandidate<TPayload>
    {
        public LocatedCandidate(
            string path,
            string origin,
            int rank,
            ParsedSaveCandidate<TPayload> parsed)
        {
            Path = path;
            Origin = origin;
            Rank = rank;
            Parsed = parsed;
        }

        public string Path { get; }

        public string Origin { get; }

        public int Rank { get; }

        public ParsedSaveCandidate<TPayload> Parsed { get; }
    }

    internal enum RevisionDecision
    {
        Advance,
        Idempotent
    }
}
