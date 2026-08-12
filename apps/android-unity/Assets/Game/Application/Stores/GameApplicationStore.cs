using System;
using System.Threading;
using System.Threading.Tasks;
using Baseball.Application.Commands;
using Baseball.Application.HighSchool;
using Baseball.Application.Persistence;
using Baseball.Application.Pro;

namespace Baseball.Application.Stores
{
    public sealed class GameApplicationStore : IDisposable
    {
        private readonly ISaveRepository<GameSaveAggregate> _repository;
        private readonly IHighSchoolCareerPort _highSchool;
        private readonly IProCareerPort _pro;
        private readonly SemaphoreSlim _lifecycleGate = new SemaphoreSlim(1, 1);
        private PersistentStore<GameSaveAggregate, GameCommand> _store;
        private bool _disposed;
        private volatile bool _persistencePoisoned;

        private GameApplicationStore(
            ISaveRepository<GameSaveAggregate> repository,
            IHighSchoolCareerPort highSchool,
            IProCareerPort pro,
            GameSaveAggregate initial)
        {
            _repository = repository;
            _highSchool = highSchool;
            _pro = pro;
            ReplaceInner(initial);
        }

        public GameSaveAggregate Current => _store.Current;
        public bool IsBusy => _store.IsBusy;
        /// <summary>
        /// True after an irrevocable reset has started but could not publish its candidate state.
        /// Reads remain available for recovery UI; every operation that could touch the old
        /// repository is rejected until this store is disposed and startup reconciliation opens
        /// a fresh candidate-install store.
        /// </summary>
        public bool IsPersistencePoisoned => _persistencePoisoned;
        public SaveLoadStatus InitialLoadStatus { get; private set; }
        public bool WasMigrated { get; private set; }
        public bool RequiresRecoveryNotice => InitialLoadStatus == SaveLoadStatus.RecoveredBackup;

        public event Action<GameSaveAggregate> StatePublished;
        public event Action<bool> BusyChanged;

        public static async Task<GameApplicationStore> OpenAsync(
            ISaveRepository<GameSaveAggregate> repository,
            IHighSchoolCareerPort highSchool,
            IProCareerPort pro,
            string installId,
            CancellationToken cancellationToken = default)
        {
            if (repository == null) throw new ArgumentNullException(nameof(repository));
            if (highSchool == null) throw new ArgumentNullException(nameof(highSchool));
            if (pro == null) throw new ArgumentNullException(nameof(pro));
            if (string.IsNullOrWhiteSpace(installId))
                throw new ArgumentException("An install ID is required.", nameof(installId));

            var load = await repository.LoadAsync(cancellationToken).ConfigureAwait(false);
            GameSaveAggregate initial;
            var migrated = false;
            switch (load.Status)
            {
                case SaveLoadStatus.NoSave:
                    initial = GameSaveAggregate.Initial(installId);
                    break;
                case SaveLoadStatus.LoadedCanonical:
                case SaveLoadStatus.RecoveredBackup:
                    if (load.Envelope == null || load.Envelope.Payload == null)
                        throw new GameSaveLoadException("save.payload_missing", load.Status);
                    if (load.Envelope.Revision != load.Envelope.Payload.Revision)
                        throw new GameSaveLoadException("save.revision_mismatch", load.Status);
                    if (!string.Equals(
                        load.Envelope.Payload.InstallId,
                        installId,
                        StringComparison.Ordinal))
                        throw new GameSaveLoadException("save.install_id_mismatch", load.Status);
                    var migration = GameSaveMigration.Upgrade(load.Envelope.Payload);
                    initial = migration.Aggregate;
                    migrated = migration.Migrated;
                    if (migrated)
                    {
                        await repository.SaveAsync(initial, initial.Revision, cancellationToken)
                            .ConfigureAwait(false);
                    }
                    break;
                case SaveLoadStatus.FutureVersion:
                    throw new GameSaveLoadException("save.future_version", load.Status);
                case SaveLoadStatus.MigrationRequired:
                    throw new GameSaveLoadException("save.envelope_migration_required", load.Status);
                default:
                    throw new GameSaveLoadException("save.unrecoverable", load.Status);
            }

            var result = new GameApplicationStore(repository, highSchool, pro, initial)
            {
                InitialLoadStatus = load.Status,
                WasMigrated = migrated
            };
            return result;
        }

        public async Task<DispatchResult<GameSaveAggregate>> DispatchAsync(
            CommandEnvelope<GameCommand> command,
            CancellationToken cancellationToken = default)
        {
            ThrowIfPersistenceUnavailable();
            await _lifecycleGate.WaitAsync(cancellationToken);
            try
            {
                ThrowIfPersistenceUnavailable();
                return await _store.DispatchAsync(command, cancellationToken);
            }
            finally
            {
                _lifecycleGate.Release();
            }
        }

        /// <summary>
        /// Re-checks the canonical repository after a platform resume. Equal revision is a no-op;
        /// only a strictly newer, valid snapshot for the same installation is adopted. Rollback,
        /// missing-current-save, and unsupported states fail without replacing or publishing.
        /// </summary>
        public async Task<bool> ReconcilePersistedRevisionAsync(
            CancellationToken cancellationToken = default)
        {
            ThrowIfPersistenceUnavailable();
            await _lifecycleGate.WaitAsync(cancellationToken);
            try
            {
                ThrowIfPersistenceUnavailable();
                var before = Current;
                // Lifecycle reconciliation is entered through Bootstrap's captured Unity context.
                // Preserve it so replacing/publishing a newer snapshot remains main-thread safe.
                var load = await _repository.LoadAsync(cancellationToken);
                if (load.Status == SaveLoadStatus.NoSave)
                {
                    if (before.Revision == 0) return false;
                    throw new GameSaveReconcileException("save.resume_missing");
                }
                if (load.Status != SaveLoadStatus.LoadedCanonical &&
                    load.Status != SaveLoadStatus.RecoveredBackup)
                {
                    throw new GameSaveReconcileException("save.resume_unsupported:" + load.Status);
                }
                if (load.Envelope?.Payload == null)
                    throw new GameSaveReconcileException("save.resume_payload_missing");
                if (load.Envelope.Revision != load.Envelope.Payload.Revision)
                    throw new GameSaveReconcileException("save.resume_revision_mismatch");

                var migration = GameSaveMigration.Upgrade(load.Envelope.Payload);
                var candidate = migration.Aggregate;
                var validation = new GameSaveValidator().Validate(candidate);
                if (!validation.IsValid)
                    throw new GameSaveReconcileException(
                        "save.resume_invalid:" + string.Join(",", validation.Errors));
                if (!string.Equals(candidate.InstallId, before.InstallId, StringComparison.Ordinal))
                    throw new GameSaveReconcileException("save.resume_install_mismatch");
                if (candidate.Revision < before.Revision)
                    throw new GameSaveReconcileException("save.resume_revision_rollback");
                if (candidate.Revision == before.Revision) return false;

                if (migration.Migrated)
                {
                    await _repository.SaveAsync(candidate, candidate.Revision, cancellationToken);
                }
                ReplaceInner(candidate);
                StatePublished?.Invoke(candidate);
                return true;
            }
            finally
            {
                _lifecycleGate.Release();
            }
        }

        /// <summary>
        /// Explicit destructive reset. The in-memory initial snapshot is published only after all
        /// canonical, temp, backup, and quarantine files have been removed successfully.
        /// </summary>
        public async Task ResetAsync(string installId, CancellationToken cancellationToken = default)
        {
            await ResetCoreAsync(
                installId,
                null,
                rollbackOnIdentityCommitFailure: true,
                cancellationToken);
        }

        /// <summary>
        /// Resets save files before committing the no-backup identity candidate. Callers must not
        /// mutate the identity before entering this boundary. If identity commit fails, the prior
        /// aggregate is restored before the error is surfaced and nothing is published.
        /// </summary>
        public Task ResetAsync(
            string installId,
            Func<string, CancellationToken, Task> commitInstallIdentity,
            CancellationToken cancellationToken = default) =>
            ResetCoreAsync(
                installId,
                commitInstallIdentity,
                rollbackOnIdentityCommitFailure: true,
                cancellationToken);

        /// <summary>
        /// Reset boundary for an identity transition whose intent was durably journaled before
        /// entry. Once repository deletion succeeds, a later identity/receipt error must not
        /// restore the old save; startup reconciliation owns completion under the candidate ID.
        /// </summary>
        public Task ResetWithPreparedIdentityAsync(
            string installId,
            Func<string, CancellationToken, Task> commitInstallIdentity,
            CancellationToken cancellationToken = default) =>
            ResetCoreAsync(
                installId,
                commitInstallIdentity,
                rollbackOnIdentityCommitFailure: false,
                cancellationToken);

        private async Task ResetCoreAsync(
            string installId,
            Func<string, CancellationToken, Task> commitInstallIdentity,
            bool rollbackOnIdentityCommitFailure,
            CancellationToken cancellationToken)
        {
            if (string.IsNullOrWhiteSpace(installId))
                throw new ArgumentException("An install ID is required.", nameof(installId));
            ThrowIfPersistenceUnavailable();
            if (!rollbackOnIdentityCommitFailure) _persistencePoisoned = true;
            await _lifecycleGate.WaitAsync(cancellationToken);
            try
            {
                if (rollbackOnIdentityCommitFailure) ThrowIfPersistenceUnavailable();
                else ThrowIfDisposed();
                var prior = Current;
                try
                {
                    await _repository.ResetAsync(cancellationToken);
                }
                catch (Exception resetError)
                {
                    try
                    {
                        await _repository.SaveAsync(prior, prior.Revision, CancellationToken.None);
                    }
                    catch (Exception rollbackError)
                    {
                        throw new GameResetException(
                            "reset.repository_and_rollback_failed",
                            resetError,
                            rollbackError);
                    }
                    if (resetError is OperationCanceledException) throw;
                    throw new GameResetException("reset.repository_failed", resetError);
                }
                if (commitInstallIdentity != null)
                {
                    try
                    {
                        await commitInstallIdentity(installId, cancellationToken);
                    }
                    catch (Exception identityError)
                    {
                        if (!rollbackOnIdentityCommitFailure)
                        {
                            throw new GameResetException(
                                "reset.identity_commit_pending",
                                identityError,
                                resetCommitted: true);
                        }
                        try
                        {
                            await _repository.SaveAsync(prior, prior.Revision, CancellationToken.None);
                        }
                        catch (Exception rollbackError)
                        {
                            throw new GameResetException(
                                "reset.identity_commit_and_rollback_failed",
                                identityError,
                                rollbackError);
                        }
                        throw new GameResetException(
                            "reset.identity_commit_failed",
                            identityError);
                    }
                }
                var initial = GameSaveAggregate.Initial(installId);
                ReplaceInner(initial);
                _persistencePoisoned = false;
                StatePublished?.Invoke(initial);
            }
            finally
            {
                _lifecycleGate.Release();
            }
        }

        public void Dispose()
        {
            if (_disposed) return;
            _disposed = true;
            _store.Dispose();
            _lifecycleGate.Dispose();
            if (_repository is IDisposable disposable) disposable.Dispose();
        }

        private void ReplaceInner(GameSaveAggregate initial)
        {
            if (_store != null)
            {
                _store.StatePublished -= Publish;
                _store.BusyChanged -= PublishBusy;
                _store.Dispose();
            }
            _store = new PersistentStore<GameSaveAggregate, GameCommand>(
                initial,
                new GameCommandTransition(_highSchool, _pro),
                new AtomicSaveStateSaver<GameSaveAggregate>(_repository));
            _store.StatePublished += Publish;
            _store.BusyChanged += PublishBusy;
        }

        private void Publish(GameSaveAggregate state) => StatePublished?.Invoke(state);
        private void PublishBusy(bool busy) => BusyChanged?.Invoke(busy);

        private void ThrowIfDisposed()
        {
            if (_disposed) throw new ObjectDisposedException(nameof(GameApplicationStore));
        }

        private void ThrowIfPersistenceUnavailable()
        {
            ThrowIfDisposed();
            if (_persistencePoisoned)
                throw new GamePersistencePoisonedException();
        }
    }

    public sealed class GameResetException : Exception
    {
        public GameResetException(
            string errorCode,
            Exception innerException,
            Exception rollbackError = null,
            bool resetCommitted = false)
            : base(errorCode, innerException)
        {
            ErrorCode = errorCode;
            RollbackError = rollbackError;
            ResetCommitted = resetCommitted;
        }

        public string ErrorCode { get; }
        public Exception RollbackError { get; }
        public bool ResetCommitted { get; }
    }

    public sealed class GamePersistencePoisonedException : InvalidOperationException
    {
        public const string PersistenceErrorCode = "store.persistence_poisoned";

        public GamePersistencePoisonedException() : base(PersistenceErrorCode)
        {
        }

        public string ErrorCode => PersistenceErrorCode;
    }

    public sealed class GameSaveLoadException : Exception
    {
        public GameSaveLoadException(string errorCode, SaveLoadStatus status)
            : base(errorCode)
        {
            ErrorCode = errorCode;
            Status = status;
        }

        public string ErrorCode { get; }
        public SaveLoadStatus Status { get; }
    }

    public sealed class GameSaveReconcileException : Exception
    {
        public GameSaveReconcileException(string errorCode) : base(errorCode)
        {
            ErrorCode = errorCode;
        }

        public string ErrorCode { get; }
    }
}
