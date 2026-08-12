using System;
using System.Threading;
using System.Threading.Tasks;
using Baseball.Application.HighSchool;
using Baseball.Application.Persistence;
using Baseball.Application.Pro;
using Baseball.Application.Stores;
using Baseball.Platform.Identity;
using Baseball.Platform.Share;

namespace Baseball.Bootstrap
{
    public static class RuntimeGameComposition
    {
        public static RuntimeGameCoordinator Create(
            string saveDirectory,
            IRuntimeGameMainThread mainThread)
        {
            return Create(
                new AtomicRuntimeGameStoreFactory(
                    saveDirectory,
                    AnonymousInstallIdentity.GetOrCreate),
                mainThread);
        }

        public static RuntimeGameCoordinator Create(
            string saveDirectory,
            string installId,
            IRuntimeGameMainThread mainThread)
        {
            return Create(
                new AtomicRuntimeGameStoreFactory(saveDirectory, installId),
                mainThread);
        }

        private static RuntimeGameCoordinator Create(
            IRuntimeGameStoreFactory storeFactory,
            IRuntimeGameMainThread mainThread)
        {
            return new RuntimeGameCoordinator(
                storeFactory,
                new DurableRuntimeGameLifecycleHooks(
                    publishSessionEndPrepared: (value, cancellationToken) =>
                        mainThread.RunAsync(
                            () => RuntimeGameServices.PublishSessionEndPrepared(value, mainThread),
                            cancellationToken)),
                mainThread);
        }
    }

    public sealed class AtomicRuntimeGameStoreFactory : IRuntimeGameStoreFactory
    {
        private readonly string _saveDirectory;
        private readonly Func<string> _installIdResolver;

        public AtomicRuntimeGameStoreFactory(string saveDirectory, string installId)
            : this(saveDirectory, FixedInstallIdResolver(installId))
        {
        }

        public AtomicRuntimeGameStoreFactory(
            string saveDirectory,
            Func<string> installIdResolver)
        {
            if (string.IsNullOrWhiteSpace(saveDirectory))
                throw new ArgumentException("A save directory is required.", nameof(saveDirectory));
            if (installIdResolver == null)
                throw new ArgumentNullException(nameof(installIdResolver));
            _saveDirectory = saveDirectory;
            _installIdResolver = installIdResolver;
        }

        private static Func<string> FixedInstallIdResolver(string installId)
        {
            if (string.IsNullOrWhiteSpace(installId))
                throw new ArgumentException("An install ID is required.", nameof(installId));
            return () => installId;
        }

        public async Task<GameApplicationStore> OpenAsync(CancellationToken cancellationToken)
        {
            var repository = new AtomicSaveRepository<GameSaveAggregate>(
                new SaveFileLayout(_saveDirectory),
                new SystemAtomicFileSystem(),
                new GameSaveValidator(),
                new GameSaveSemanticPriority());
            try
            {
                string resolvedInstallId = _installIdResolver();
                if (string.IsNullOrWhiteSpace(resolvedInstallId))
                    throw new InvalidOperationException("runtime.install_id_missing");
                string effectiveInstallId = resolvedInstallId;
                InstallResetJournalReadResult reset =
                    AnonymousInstallIdentity.ReadPreparedReset();
                if (reset.Status == InstallResetJournalStatus.Invalid)
                    throw new InvalidOperationException(reset.Diagnostic);
                if (reset.Status == InstallResetJournalStatus.Pending)
                {
                    if (!string.Equals(
                            resolvedInstallId,
                            reset.Record.PreviousInstallId,
                            StringComparison.OrdinalIgnoreCase) &&
                        !string.Equals(
                            resolvedInstallId,
                            reset.Record.CandidateInstallId,
                            StringComparison.OrdinalIgnoreCase))
                        throw new InvalidOperationException("reset.bootstrap_install_mismatch");
                    if (reset.Record.RequiresRepositoryReset)
                    {
                        await repository.ResetAsync(cancellationToken).ConfigureAwait(false);
                        if (!AnonymousInstallIdentity.MarkPreparedResetStep(
                                InstallResetStep.RepositoryReset))
                            throw new InvalidOperationException("reset.repository_receipt_failed");
                    }
                    AnonymousInstallIdentity.PublishPreparedReset(
                        reset.Record.CandidateInstallId);
                    effectiveInstallId = reset.Record.CandidateInstallId;
                    AnonymousInstallIdentity.TryReconcilePreparedLocalState();
                    if (AndroidShareService.TryClearShareCache())
                    {
                        AnonymousInstallIdentity.MarkPreparedResetStep(
                            InstallResetStep.ShareCacheCleaned);
                    }
                    AnonymousInstallIdentity.TryCompletePreparedReset();
                }
                return await GameApplicationStore.OpenAsync(
                        repository,
                        new CoreHighSchoolCareerPort(),
                        new CoreProCareerPort(),
                        effectiveInstallId,
                        cancellationToken)
                    .ConfigureAwait(false);
            }
            catch
            {
                repository.Dispose();
                throw;
            }
        }
    }
}
