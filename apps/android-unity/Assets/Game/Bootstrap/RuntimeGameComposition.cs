using System;
using System.Threading;
using System.Threading.Tasks;
using Baseball.Application.HighSchool;
using Baseball.Application.Persistence;
using Baseball.Application.Pro;
using Baseball.Application.Stores;

namespace Baseball.Bootstrap
{
    public static class RuntimeGameComposition
    {
        public static RuntimeGameCoordinator Create(
            string saveDirectory,
            string installId,
            IRuntimeGameMainThread mainThread)
        {
            return new RuntimeGameCoordinator(
                new AtomicRuntimeGameStoreFactory(saveDirectory, installId),
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
        private readonly string _installId;

        public AtomicRuntimeGameStoreFactory(string saveDirectory, string installId)
        {
            if (string.IsNullOrWhiteSpace(saveDirectory))
                throw new ArgumentException("A save directory is required.", nameof(saveDirectory));
            if (string.IsNullOrWhiteSpace(installId))
                throw new ArgumentException("An install ID is required.", nameof(installId));
            _saveDirectory = saveDirectory;
            _installId = installId;
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
                return await GameApplicationStore.OpenAsync(
                        repository,
                        new CoreHighSchoolCareerPort(),
                        new CoreProCareerPort(),
                        _installId,
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
