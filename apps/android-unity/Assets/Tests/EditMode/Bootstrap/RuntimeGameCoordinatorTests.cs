using System;
using System.Collections.Concurrent;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Baseball.Application.Commands;
using Baseball.Application.HighSchool;
using Baseball.Application.Meta;
using Baseball.Application.Persistence;
using Baseball.Application.Pro;
using Baseball.Application.Stores;
using NUnit.Framework;

namespace Baseball.Bootstrap.Tests
{
    public sealed class RuntimeGameCoordinatorTests
    {
        [SetUp]
        public void SetUp()
        {
            RuntimeGameServices.ResetForDomainReload();
        }

        [TearDown]
        public void TearDown()
        {
            RuntimeGameServices.ResetForDomainReload();
        }

        [Test]
        public async Task Initialize_OpensOnceAndPublishesReadyOnConfiguredMainThread()
        {
            using (var mainThread = new DedicatedMainThread())
            {
                var factory = new RecordingStoreFactory();
                var hooks = new RecordingLifecycleHooks();
                var coordinator = new RuntimeGameCoordinator(factory, hooks, mainThread);
                var publishedThread = -1;
                var readyCount = 0;
                RuntimeGameServices.Ready += _ =>
                {
                    publishedThread = Thread.CurrentThread.ManagedThreadId;
                    readyCount++;
                };

                await Task.WhenAll(
                    coordinator.InitializeAsync(CancellationToken.None),
                    coordinator.InitializeAsync(CancellationToken.None),
                    coordinator.InitializeAsync(CancellationToken.None));

                Assert.That(factory.OpenCount, Is.EqualTo(1));
                Assert.That(readyCount, Is.EqualTo(1));
                Assert.That(publishedThread, Is.EqualTo(mainThread.ThreadId));
                Assert.That(RuntimeGameServices.IsReady, Is.True);
                Assert.That(RuntimeGameServices.TryGetStore(out var store), Is.True);
                Assert.That(store, Is.SameAs(RuntimeGameServices.Store));
                Assert.That(coordinator.State, Is.EqualTo(RuntimeGameLifecycleState.Running));

                coordinator.Dispose();
            }
        }

        [Test]
        public async Task AtomicFactory_ResolvesInstallIdentityInsideEverySerializedRetry()
        {
            string saveDirectory = Path.Combine(
                Path.GetTempPath(),
                "baseball-bootstrap-identity-retry-" + Guid.NewGuid().ToString("N"));
            RuntimeGameCoordinator coordinator = null;
            var resolutions = 0;
            try
            {
                var mainThread = new DedicatedMainThread();
                try
                {
                    var factory = new AtomicRuntimeGameStoreFactory(
                        saveDirectory,
                        () =>
                        {
                            resolutions++;
                            if (resolutions == 1)
                                throw new IOException("simulated identity storage failure");
                            return "install-identity-retry";
                        });
                    coordinator = new RuntimeGameCoordinator(
                        factory,
                        new DurableRuntimeGameLifecycleHooks(),
                        mainThread);

                    await AssertThrowsAsync<IOException>(() =>
                        coordinator.InitializeAsync(CancellationToken.None));
                    Assert.That(RuntimeGameServices.IsReady, Is.False);
                    Assert.That(coordinator.State, Is.EqualTo(RuntimeGameLifecycleState.Created));

                    await coordinator.InitializeAsync(CancellationToken.None);

                    Assert.That(resolutions, Is.EqualTo(2));
                    Assert.That(RuntimeGameServices.Store.Current.InstallId,
                        Is.EqualTo("install-identity-retry"));
                    coordinator.Dispose();
                    coordinator = null;
                }
                finally
                {
                    coordinator?.Dispose();
                    coordinator = null;
                    mainThread.Dispose();
                }
            }
            finally
            {
                coordinator?.Dispose();
                if (Directory.Exists(saveDirectory)) Directory.Delete(saveDirectory, true);
            }
        }

        [Test]
        public async Task Lifecycle_DeduplicatesPauseResumeAndLowMemory()
        {
            using (var mainThread = new DedicatedMainThread())
            {
                var hooks = new RecordingLifecycleHooks();
                var coordinator = new RuntimeGameCoordinator(
                    new RecordingStoreFactory(), hooks, mainThread);
                await coordinator.InitializeAsync(CancellationToken.None);

                await coordinator.PauseAsync(CancellationToken.None);
                await coordinator.PauseAsync(CancellationToken.None);
                await coordinator.LowMemoryAsync(CancellationToken.None);
                await coordinator.LowMemoryAsync(CancellationToken.None);
                await coordinator.ResumeAsync(CancellationToken.None);
                await coordinator.ResumeAsync(CancellationToken.None);
                await coordinator.LowMemoryAsync(CancellationToken.None);

                Assert.That(hooks.PauseCount, Is.EqualTo(1));
                Assert.That(hooks.ResumeCount, Is.EqualTo(1));
                Assert.That(hooks.LowMemoryCount, Is.EqualTo(2));
                Assert.That(coordinator.State, Is.EqualTo(RuntimeGameLifecycleState.Running));
                coordinator.Dispose();
            }
        }

        [Test]
        public async Task FailedLifecycleHook_DoesNotAdvanceStateAndCanBeRetried()
        {
            using (var mainThread = new DedicatedMainThread())
            {
                var hooks = new RecordingLifecycleHooks { PauseFailuresRemaining = 1 };
                var coordinator = new RuntimeGameCoordinator(
                    new RecordingStoreFactory(), hooks, mainThread);
                await coordinator.InitializeAsync(CancellationToken.None);

                await AssertThrowsAsync<InvalidOperationException>(() =>
                    coordinator.PauseAsync(CancellationToken.None));
                Assert.That(coordinator.State, Is.EqualTo(RuntimeGameLifecycleState.Running));

                await coordinator.PauseAsync(CancellationToken.None);
                Assert.That(hooks.PauseCount, Is.EqualTo(2));
                Assert.That(coordinator.State, Is.EqualTo(RuntimeGameLifecycleState.Paused));
                coordinator.Dispose();
            }
        }

        [Test]
        public async Task FailedResumeAndLowMemory_RemainRetryableWithoutLosingReadyStore()
        {
            using (var mainThread = new DedicatedMainThread())
            {
                var hooks = new RecordingLifecycleHooks
                {
                    ResumeFailuresRemaining = 1,
                    LowMemoryFailuresRemaining = 1
                };
                var coordinator = new RuntimeGameCoordinator(
                    new RecordingStoreFactory(), hooks, mainThread);
                await coordinator.InitializeAsync(CancellationToken.None);

                await AssertThrowsAsync<InvalidOperationException>(() =>
                    coordinator.LowMemoryAsync(CancellationToken.None));
                await coordinator.LowMemoryAsync(CancellationToken.None);
                Assert.That(hooks.LowMemoryCount, Is.EqualTo(2));
                Assert.That(RuntimeGameServices.IsReady, Is.True);

                await coordinator.PauseAsync(CancellationToken.None);
                await AssertThrowsAsync<InvalidOperationException>(() =>
                    coordinator.ResumeAsync(CancellationToken.None));
                Assert.That(coordinator.State, Is.EqualTo(RuntimeGameLifecycleState.Paused));
                await coordinator.ResumeAsync(CancellationToken.None);

                Assert.That(hooks.ResumeCount, Is.EqualTo(2));
                Assert.That(coordinator.State, Is.EqualTo(RuntimeGameLifecycleState.Running));
                Assert.That(RuntimeGameServices.IsReady, Is.True);
                coordinator.Dispose();
            }
        }

        [Test]
        public async Task FailedInitialization_NotifiesSafelyAndCanBeRetried()
        {
            using (var mainThread = new DedicatedMainThread())
            {
                var factory = new RecordingStoreFactory { OpenFailuresRemaining = 1 };
                var coordinator = new RuntimeGameCoordinator(
                    factory, new RecordingLifecycleHooks(), mainThread);
                var failureNotifications = 0;
                RuntimeGameServices.StartupFailed += _ => throw new Exception("subscriber failed");
                RuntimeGameServices.StartupFailed += _ => failureNotifications++;

                await AssertThrowsAsync<InvalidOperationException>(() =>
                    coordinator.InitializeAsync(CancellationToken.None));
                Assert.That(failureNotifications, Is.EqualTo(1));
                Assert.That(RuntimeGameServices.IsReady, Is.False);
                Assert.That(coordinator.State, Is.EqualTo(RuntimeGameLifecycleState.Created));

                await coordinator.InitializeAsync(CancellationToken.None);
                Assert.That(factory.OpenCount, Is.EqualTo(2));
                Assert.That(RuntimeGameServices.IsReady, Is.True);
                coordinator.Dispose();
            }
        }

        [Test]
        public async Task ReadySubscriberFailure_DoesNotBlockOtherSubscribersOrPublication()
        {
            using (var mainThread = new DedicatedMainThread())
            {
                var coordinator = new RuntimeGameCoordinator(
                    new RecordingStoreFactory(), new RecordingLifecycleHooks(), mainThread);
                var observed = 0;
                RuntimeGameServices.Ready += _ => throw new Exception("scene disappeared");
                RuntimeGameServices.Ready += _ => observed++;

                await coordinator.InitializeAsync(CancellationToken.None);

                Assert.That(observed, Is.EqualTo(1));
                Assert.That(RuntimeGameServices.IsReady, Is.True);
                coordinator.Dispose();
            }
        }

        [Test]
        public async Task Dispose_IsIdempotentClearsReadyAndRejectsFurtherCallbacks()
        {
            using (var mainThread = new DedicatedMainThread())
            {
                var factory = new RecordingStoreFactory();
                var coordinator = new RuntimeGameCoordinator(
                    factory, new RecordingLifecycleHooks(), mainThread);
                var unavailableCount = 0;
                var unavailableThread = -1;
                RuntimeGameServices.BecameUnavailable += () =>
                {
                    unavailableCount++;
                    unavailableThread = Thread.CurrentThread.ManagedThreadId;
                };
                await coordinator.InitializeAsync(CancellationToken.None);

                coordinator.Dispose();
                coordinator.Dispose();

                Assert.That(coordinator.State, Is.EqualTo(RuntimeGameLifecycleState.Disposed));
                Assert.That(RuntimeGameServices.IsReady, Is.False);
                Assert.That(unavailableCount, Is.EqualTo(1));
                Assert.That(unavailableThread, Is.EqualTo(mainThread.ThreadId));
                Assert.That(factory.LastRepository.DisposeCount, Is.EqualTo(1));
                await AssertThrowsAsync<ObjectDisposedException>(() =>
                    coordinator.ResumeAsync(CancellationToken.None));
            }
        }

        [Test]
        public async Task DisposeFailure_StillClearsAndAttemptsEveryOwnedResource()
        {
            using (var mainThread = new DedicatedMainThread())
            {
                var factory = new ThrowingDisposableStoreFactory();
                var hooks = new ThrowingDisposableLifecycleHooks();
                var coordinator = new RuntimeGameCoordinator(factory, hooks, mainThread);
                await coordinator.InitializeAsync(CancellationToken.None);

                var failure = Assert.Throws<AggregateException>(() => coordinator.Dispose());

                Assert.That(failure.InnerExceptions.Count, Is.EqualTo(2));
                Assert.That(coordinator.State, Is.EqualTo(RuntimeGameLifecycleState.Disposed));
                Assert.That(RuntimeGameServices.IsReady, Is.False);
                Assert.That(factory.LastRepository.DisposeCount, Is.EqualTo(1));
                Assert.That(factory.DisposeCount, Is.EqualTo(1));
                Assert.That(hooks.DisposeCount, Is.EqualTo(1));
                Assert.DoesNotThrow(() => coordinator.Dispose());
            }
        }

        [Test]
        public async Task AtomicFactory_OpensAggregateAndPersistsFirstCommandBeforePublish()
        {
            var saveDirectory = Path.Combine(
                Path.GetTempPath(),
                "baseball-bootstrap-" + Guid.NewGuid().ToString("N"));
            RuntimeGameCoordinator coordinator = null;
            try
            {
                var seeded = GameSaveAggregate.Initial("install-return");
                using (var seedRepository = new AtomicSaveRepository<GameSaveAggregate>(
                           new SaveFileLayout(saveDirectory),
                           new SystemAtomicFileSystem(),
                           new GameSaveValidator(),
                           new GameSaveSemanticPriority()))
                {
                    await seedRepository.SaveAsync(seeded, seeded.Revision);
                }
                var mainThread = new DedicatedMainThread();
                try
                {
                    coordinator = new RuntimeGameCoordinator(
                        new AtomicRuntimeGameStoreFactory(saveDirectory, "install-return"),
                        new DurableRuntimeGameLifecycleHooks(),
                        mainThread);
                    await coordinator.InitializeAsync(CancellationToken.None);
                    Assert.That(RuntimeGameServices.Store.Current.Revision, Is.Zero);

                    var result = await RuntimeGameServices.Store.DispatchAsync(
                        new CommandEnvelope<GameCommand>(
                            "enter-setup",
                            0,
                            new EnterSetupCommand()));

                    Assert.That(result.Status, Is.EqualTo(DispatchStatus.Applied));
                    Assert.That(RuntimeGameServices.Store.Current.Revision, Is.EqualTo(1));
                    var canonical = Path.Combine(saveDirectory, "save.json");
                    Assert.That(File.Exists(canonical), Is.True);
                    Assert.That(File.ReadAllText(canonical), Does.Contain("android-unity-save-v1"));
                    coordinator.Dispose();
                    coordinator = null;
                }
                finally
                {
                    coordinator?.Dispose();
                    coordinator = null;
                    mainThread.Dispose();
                }
            }
            finally
            {
                coordinator?.Dispose();
                if (Directory.Exists(saveDirectory)) Directory.Delete(saveDirectory, true);
            }
        }

        [Test]
        public async Task DurableHooks_PrepareEligiblePlanOnceAndReserveWarmColdAnalyticsAfterSave()
        {
            var saveDirectory = Path.Combine(
                Path.GetTempPath(),
                "baseball-bootstrap-return-" + Guid.NewGuid().ToString("N"));
            var pauseAt = new DateTimeOffset(2026, 8, 9, 1, 0, 0, TimeSpan.Zero);
            var runtimeNow = pauseAt.AddMinutes(-7);
            RuntimeGameCoordinator coordinator = null;
            try
            {
                HighSchoolCareerReadModel seededHighSchool = new CoreHighSchoolCareerPort().Start(
                    new StartHighSchoolCareerRequest(
                        "return-seed", "power_prospect", "민서준", "서울", 1));
                GameSaveAggregate seeded = GameSaveAggregate.Initial("install-return").Commit(
                    "seed-official-game-count",
                    stage: ApplicationStage.HighSchool,
                    highSchool: seededHighSchool,
                    meta: MetaProgressState.Initial.With(completedGameCount: 1));
                using (var seedRepository = new AtomicSaveRepository<GameSaveAggregate>(
                           new SaveFileLayout(saveDirectory),
                           new SystemAtomicFileSystem(),
                           new GameSaveValidator(),
                           new GameSaveSemanticPriority()))
                {
                    await seedRepository.SaveAsync(seeded, seeded.Revision);
                }
                var mainThread = new DedicatedMainThread();
                try
                {
                    var sessionEndCount = 0;
                    var sessionEndThread = -1;
                    SessionEndReturnReadModel lastSessionEnd = null;
                    var sessionEnds = new System.Collections.Generic.List<SessionEndReturnReadModel>();
                    var statePublishedThreads = new System.Collections.Generic.List<int>();
                    var busyChangedThreads = new System.Collections.Generic.List<int>();
                    RuntimeGameServices.SessionEndPrepared += value =>
                    {
                        sessionEndCount++;
                        sessionEndThread = Thread.CurrentThread.ManagedThreadId;
                        lastSessionEnd = value;
                        sessionEnds.Add(value);
                    };
                    coordinator = new RuntimeGameCoordinator(
                        new AtomicRuntimeGameStoreFactory(saveDirectory, "install-return"),
                        new DurableRuntimeGameLifecycleHooks(
                            () => runtimeNow,
                            publishSessionEndPrepared: (value, cancellationToken) =>
                                mainThread.RunAsync(
                                    () => RuntimeGameServices.PublishSessionEndPrepared(
                                        value,
                                        mainThread),
                                    cancellationToken)),
                        mainThread);
                    await coordinator.InitializeAsync(CancellationToken.None);
                    var store = RuntimeGameServices.Store;
                    Assert.That(store.Current.Meta.CompletedGameCount, Is.EqualTo(1));
                    store.StatePublished += _ =>
                        statePublishedThreads.Add(Thread.CurrentThread.ManagedThreadId);
                    store.BusyChanged += _ =>
                        busyChangedThreads.Add(Thread.CurrentThread.ManagedThreadId);

                    runtimeNow = pauseAt;
                    await coordinator.PauseAsync(CancellationToken.None);
                    var preparedRevision = store.Current.Revision;
                    Assert.That(store.Current.Meta.ReturnPlan, Is.Not.Null);
                    Assert.That(store.Current.Meta.ReturnPlan.SavedDayKey, Is.EqualTo("20260809"));
                    var eligibleReceipt = ReturnPlanRules.EligibleReceiptScope(
                        store.Current.Meta.ReturnPlan);
                    Assert.That(store.Current.AnalyticsReceipts.Contains(eligibleReceipt), Is.True);
                    Assert.That(sessionEndCount, Is.EqualTo(1));
                    Assert.That(sessionEndThread, Is.EqualTo(mainThread.ThreadId));
                    Assert.That(lastSessionEnd.ReturnEligible, Is.True);
                    Assert.That(lastSessionEnd.ShouldEmitReturnEligible, Is.True);
                    Assert.That(lastSessionEnd.Minutes, Is.EqualTo(7));
                    Assert.That(lastSessionEnd.Games, Is.Zero,
                        "the persisted lifetime count is the session baseline, not a session game");
                    Assert.That(lastSessionEnd.LifeNumber, Is.EqualTo(1));
                    Assert.That(lastSessionEnd.ImportantGamesTotal, Is.Zero);
                    Assert.That(lastSessionEnd.Phase, Is.EqualTo("prologue"));
                    Assert.That(lastSessionEnd.ActNumber, Is.EqualTo(1));
                    Assert.That(lastSessionEnd.LivesFinished, Is.Zero);
                    Assert.That(lastSessionEnd.SavedDayKey, Is.EqualTo("20260809"));
                    Assert.That(lastSessionEnd.ReturnDayKey, Is.EqualTo("20260809"));
                    Assert.That(lastSessionEnd.DayGap, Is.Zero);
                    Assert.That(statePublishedThreads, Is.Not.Empty);
                    Assert.That(busyChangedThreads, Is.Not.Empty);
                    Assert.That(statePublishedThreads.All(value => value == mainThread.ThreadId), Is.True);
                    Assert.That(busyChangedThreads.All(value => value == mainThread.ThreadId), Is.True);
                    Assert.That(lastSessionEnd.PlanReceipt,
                        Is.EqualTo(store.Current.Meta.ReturnPlan.ReceiptId));
                    Assert.That(File.ReadAllText(Path.Combine(saveDirectory, "save.json")),
                        Does.Contain(store.Current.Meta.ReturnPlan.ReceiptId));

                    await coordinator.ResumeAsync(CancellationToken.None);
                    runtimeNow = pauseAt.AddMinutes(3);
                    await coordinator.PauseAsync(CancellationToken.None);
                    Assert.That(store.Current.Revision, Is.EqualTo(preparedRevision),
                        "same-day resume/pause must carry the existing receipt without another write");
                    Assert.That(sessionEndCount, Is.EqualTo(2),
                        "each completed pause publishes even when its durable plan needs no write");
                    Assert.That(lastSessionEnd.PlanReceipt,
                        Is.EqualTo(store.Current.Meta.ReturnPlan.ReceiptId));
                    Assert.That(lastSessionEnd.ShouldEmitReturnEligible, Is.False);
                    Assert.That(lastSessionEnd.Minutes, Is.EqualTo(3));
                    Assert.That(lastSessionEnd.Games, Is.Zero,
                        "resume resets the completed-game session baseline");
                    Assert.That(sessionEnds.Select(value => value.Games), Is.EqualTo(new[] { 0, 0 }));

                    var nextDay = pauseAt.AddDays(1);
                    var cold = await RuntimeReturnPlanAnalytics.ReserveNextDayOpenAsync(
                        store, "cold", nextDay);
                    var afterCold = store.Current.Revision;
                    var warm = await RuntimeReturnPlanAnalytics.ReserveNextDayOpenAsync(
                        store, "warm", nextDay.AddHours(4));
                    Assert.That(cold, Is.Not.Null);
                    Assert.That(cold.DayGap, Is.EqualTo(1));
                    Assert.That(warm, Is.Null,
                        "cold and warm openings share one durable receipt scope");
                    Assert.That(store.Current.Revision, Is.EqualTo(afterCold));
                    coordinator.Dispose();
                    coordinator = null;
                }
                finally
                {
                    coordinator?.Dispose();
                    coordinator = null;
                    mainThread.Dispose();
                }
            }
            finally
            {
                coordinator?.Dispose();
                if (Directory.Exists(saveDirectory)) Directory.Delete(saveDirectory, true);
            }
        }

        [Test]
        public async Task DurableResume_AdoptsExternalHigherRevisionAndPublishesOnMainThread()
        {
            var saveDirectory = Path.Combine(
                Path.GetTempPath(),
                "baseball-bootstrap-resume-" + Guid.NewGuid().ToString("N"));
            RuntimeGameCoordinator coordinator = null;
            try
            {
                using (var mainThread = new DedicatedMainThread())
                {
                    coordinator = RuntimeGameComposition.Create(
                        saveDirectory,
                        "install-resume",
                        mainThread);
                    await coordinator.InitializeAsync(CancellationToken.None);
                    var store = RuntimeGameServices.Store;
                    await coordinator.PauseAsync(CancellationToken.None);

                    var external = store.Current.Commit(
                        "external-settings",
                        settings: store.Current.Settings.With(reducedMotionEnabled: true));
                    using (var writer = new AtomicSaveRepository<GameSaveAggregate>(
                               new SaveFileLayout(saveDirectory),
                               new SystemAtomicFileSystem(),
                               new GameSaveValidator(),
                               new GameSaveSemanticPriority()))
                    {
                        await writer.SaveAsync(external, external.Revision);
                    }

                    var publicationThread = -1;
                    var publications = 0;
                    store.StatePublished += _ =>
                    {
                        publicationThread = Thread.CurrentThread.ManagedThreadId;
                        publications++;
                    };

                    await coordinator.ResumeAsync(CancellationToken.None);

                    Assert.That(store.Current.Revision, Is.EqualTo(external.Revision));
                    Assert.That(store.Current.Settings.ReducedMotionEnabled, Is.True);
                    Assert.That(publications, Is.EqualTo(1));
                    Assert.That(publicationThread, Is.EqualTo(mainThread.ThreadId));
                    coordinator.Dispose();
                    coordinator = null;
                }
            }
            finally
            {
                coordinator?.Dispose();
                if (Directory.Exists(saveDirectory)) Directory.Delete(saveDirectory, true);
            }
        }

        [Test]
        public async Task DurablePause_ContendedStaleRetryKeepsCommittedPublicationOnMainThread()
        {
            var saveDirectory = Path.Combine(
                Path.GetTempPath(),
                "baseball-bootstrap-stale-" + Guid.NewGuid().ToString("N"));
            RuntimeGameCoordinator coordinator = null;
            try
            {
                using (var mainThread = new DedicatedMainThread())
                using (var fault = new BlockingSaveFaultInjector())
                {
                    var repository = new AtomicSaveRepository<GameSaveAggregate>(
                        new SaveFileLayout(saveDirectory),
                        new SystemAtomicFileSystem(),
                        new GameSaveValidator(),
                        new GameSaveSemanticPriority(),
                        faultInjector: fault);
                    var seededHighSchool = new CoreHighSchoolCareerPort().Start(
                        new StartHighSchoolCareerRequest(
                            "seed", "power_prospect", "민서준", "서울", 1));
                    var seeded = GameSaveAggregate.Initial("install-stale").Commit(
                        "seed-official-game-count",
                        stage: ApplicationStage.HighSchool,
                        highSchool: seededHighSchool,
                        meta: MetaProgressState.Initial.With(completedGameCount: 1));
                    await repository.SaveAsync(seeded, seeded.Revision);
                    var store = await GameApplicationStore.OpenAsync(
                        repository,
                        new UnusedHighSchoolPort(),
                        new UnusedProPort(),
                        "install-stale");
                    coordinator = new RuntimeGameCoordinator(
                        new ExistingStoreFactory(store),
                        new DurableRuntimeGameLifecycleHooks(
                            () => new DateTimeOffset(2026, 8, 11, 1, 0, 0, TimeSpan.Zero)),
                        mainThread);
                    await coordinator.InitializeAsync(CancellationToken.None);
                    Assert.That(store.Current.Meta.CompletedGameCount, Is.EqualTo(1));

                    fault.BlockNextSave();
                    var concurrent = Task.Run(() => store.DispatchAsync(
                        new CommandEnvelope<GameCommand>(
                            "concurrent-settings",
                            store.Current.Revision,
                            new UpdateGameSettingsCommand(reducedMotionEnabled: true))));
                    Assert.That(fault.WaitUntilBlocked(TimeSpan.FromSeconds(3)), Is.True);

                    var planPublicationThread = -1;
                    store.StatePublished += state =>
                    {
                        if (state.Meta.ReturnPlan != null)
                            planPublicationThread = Thread.CurrentThread.ManagedThreadId;
                    };
                    var pause = mainThread.RunAsync(
                        () => coordinator.PauseAsync(CancellationToken.None));
                    // This marker is queued after Pause enters its first, stale dispatch wait.
                    await mainThread.RunAsync(() => { });
                    fault.ReleaseSave();

                    var concurrentResult = await concurrent;
                    await pause;

                    Assert.That(concurrentResult.Status, Is.EqualTo(DispatchStatus.Applied));
                    Assert.That(store.Current.Settings.ReducedMotionEnabled, Is.True);
                    Assert.That(store.Current.Meta.ReturnPlan, Is.Not.Null);
                    Assert.That(planPublicationThread, Is.EqualTo(mainThread.ThreadId));
                    coordinator.Dispose();
                    coordinator = null;
                }
            }
            finally
            {
                coordinator?.Dispose();
                if (Directory.Exists(saveDirectory)) Directory.Delete(saveDirectory, true);
            }
        }

        [Test]
        public async Task PreparedResetFailureSuppressesPauseRewriteAndCandidateRestartsCleanly()
        {
            string saveDirectory = Path.Combine(
                Path.GetTempPath(),
                "baseball-bootstrap-reset-poison-" + Guid.NewGuid().ToString("N"));
            GameApplicationStore oldStore = null;
            try
            {
                var repository = new AtomicSaveRepository<GameSaveAggregate>(
                    new SaveFileLayout(saveDirectory),
                    new SystemAtomicFileSystem(),
                    new GameSaveValidator(),
                    new GameSaveSemanticPriority());
                HighSchoolCareerReadModel highSchool = new CoreHighSchoolCareerPort().Start(
                    new StartHighSchoolCareerRequest(
                        "reset-seed", "power_prospect", "민서준", "서울", 1));
                GameSaveAggregate seeded = GameSaveAggregate.Initial("install-old").Commit(
                    "seed-completed-game",
                    stage: ApplicationStage.HighSchool,
                    highSchool: highSchool,
                    meta: MetaProgressState.Initial.With(completedGameCount: 1));
                await repository.SaveAsync(seeded, seeded.Revision);
                oldStore = await GameApplicationStore.OpenAsync(
                    repository,
                    new UnusedHighSchoolPort(),
                    new UnusedProPort(),
                    "install-old");

                GameResetException failure = await AssertThrowsAsync<GameResetException>(() =>
                    oldStore.ResetWithPreparedIdentityAsync(
                        "install-candidate",
                        (_, __) => Task.FromException(
                            new IOException("identity receipt unavailable"))));
                Assert.That(failure.ResetCommitted, Is.True);
                Assert.That(oldStore.IsPersistencePoisoned, Is.True);

                var hooks = new DurableRuntimeGameLifecycleHooks(
                    () => new DateTimeOffset(2026, 8, 12, 2, 0, 0, TimeSpan.Zero));
                await hooks.PauseAsync(oldStore, CancellationToken.None);
                SaveLoadResult<GameSaveAggregate> afterPause = await repository.LoadAsync();
                Assert.That(afterPause.Status, Is.EqualTo(SaveLoadStatus.NoSave),
                    "pause must not recreate the deleted old-install aggregate");

                oldStore.Dispose();
                oldStore = null;
                using (var restartedRepository = new AtomicSaveRepository<GameSaveAggregate>(
                           new SaveFileLayout(saveDirectory),
                           new SystemAtomicFileSystem(),
                           new GameSaveValidator(),
                           new GameSaveSemanticPriority()))
                using (var restarted = await GameApplicationStore.OpenAsync(
                           restartedRepository,
                           new UnusedHighSchoolPort(),
                           new UnusedProPort(),
                           "install-candidate"))
                {
                    Assert.That(restarted.Current.InstallId, Is.EqualTo("install-candidate"));
                    Assert.That(restarted.Current.Revision, Is.Zero);
                    Assert.That(restarted.IsPersistencePoisoned, Is.False);
                }
            }
            finally
            {
                oldStore?.Dispose();
                if (Directory.Exists(saveDirectory)) Directory.Delete(saveDirectory, true);
            }
        }

        private static async Task<TException> AssertThrowsAsync<TException>(Func<Task> action)
            where TException : Exception
        {
            try
            {
                await action();
            }
            catch (TException exception)
            {
                return exception;
            }
            catch (Exception exception)
            {
                Assert.Fail("Expected " + typeof(TException).Name + " but caught " +
                    exception.GetType().Name + ": " + exception.Message);
            }
            Assert.Fail("Expected " + typeof(TException).Name + " but no exception was thrown.");
            return null;
        }

        private sealed class RecordingStoreFactory : IRuntimeGameStoreFactory
        {
            public int OpenCount { get; private set; }
            public int OpenFailuresRemaining { get; set; }
            public RecordingRepository LastRepository { get; private set; }

            public async Task<GameApplicationStore> OpenAsync(CancellationToken cancellationToken)
            {
                OpenCount++;
                if (OpenFailuresRemaining > 0)
                {
                    OpenFailuresRemaining--;
                    throw new InvalidOperationException("open failed");
                }
                LastRepository = new RecordingRepository();
                return await GameApplicationStore.OpenAsync(
                    LastRepository,
                    new UnusedHighSchoolPort(),
                    new UnusedProPort(),
                    "install-test",
                    cancellationToken);
            }
        }

        private sealed class ExistingStoreFactory : IRuntimeGameStoreFactory
        {
            private readonly GameApplicationStore _store;

            public ExistingStoreFactory(GameApplicationStore store)
            {
                _store = store;
            }

            public Task<GameApplicationStore> OpenAsync(CancellationToken cancellationToken)
            {
                cancellationToken.ThrowIfCancellationRequested();
                return Task.FromResult(_store);
            }
        }

        private sealed class BlockingSaveFaultInjector : ISaveFaultInjector, IDisposable
        {
            private readonly ManualResetEventSlim _blocked = new ManualResetEventSlim();
            private readonly ManualResetEventSlim _released = new ManualResetEventSlim();
            private int _blockNext;

            public void BlockNextSave()
            {
                _blocked.Reset();
                _released.Reset();
                Interlocked.Exchange(ref _blockNext, 1);
            }

            public bool WaitUntilBlocked(TimeSpan timeout) => _blocked.Wait(timeout);

            public void ReleaseSave() => _released.Set();

            public void Checkpoint(SaveFaultPoint point)
            {
                if (point != SaveFaultPoint.BeforeCanonicalSwap ||
                    Interlocked.Exchange(ref _blockNext, 0) != 1)
                {
                    return;
                }
                _blocked.Set();
                _released.Wait();
            }

            public void Dispose()
            {
                _released.Set();
                _blocked.Dispose();
                _released.Dispose();
            }
        }

        private sealed class RecordingLifecycleHooks : IRuntimeGameLifecycleHooks
        {
            public int PauseCount { get; private set; }
            public int ResumeCount { get; private set; }
            public int LowMemoryCount { get; private set; }
            public int PauseFailuresRemaining { get; set; }
            public int ResumeFailuresRemaining { get; set; }
            public int LowMemoryFailuresRemaining { get; set; }

            public Task PauseAsync(GameApplicationStore store, CancellationToken cancellationToken)
            {
                PauseCount++;
                if (PauseFailuresRemaining > 0)
                {
                    PauseFailuresRemaining--;
                    throw new InvalidOperationException("pause failed");
                }
                return Task.CompletedTask;
            }

            public Task ResumeAsync(GameApplicationStore store, CancellationToken cancellationToken)
            {
                ResumeCount++;
                if (ResumeFailuresRemaining > 0)
                {
                    ResumeFailuresRemaining--;
                    throw new InvalidOperationException("resume failed");
                }
                return Task.CompletedTask;
            }

            public Task LowMemoryAsync(GameApplicationStore store, CancellationToken cancellationToken)
            {
                LowMemoryCount++;
                if (LowMemoryFailuresRemaining > 0)
                {
                    LowMemoryFailuresRemaining--;
                    throw new InvalidOperationException("low memory failed");
                }
                return Task.CompletedTask;
            }
        }

        private sealed class ThrowingDisposableStoreFactory : IRuntimeGameStoreFactory, IDisposable
        {
            public int DisposeCount { get; private set; }
            public RecordingRepository LastRepository { get; private set; }

            public async Task<GameApplicationStore> OpenAsync(CancellationToken cancellationToken)
            {
                LastRepository = new RecordingRepository();
                return await GameApplicationStore.OpenAsync(
                    LastRepository,
                    new UnusedHighSchoolPort(),
                    new UnusedProPort(),
                    "install-dispose",
                    cancellationToken);
            }

            public void Dispose()
            {
                DisposeCount++;
                throw new InvalidOperationException("factory dispose failed");
            }
        }

        private sealed class ThrowingDisposableLifecycleHooks : IRuntimeGameLifecycleHooks, IDisposable
        {
            public int DisposeCount { get; private set; }
            public Task PauseAsync(GameApplicationStore store, CancellationToken cancellationToken) =>
                Task.CompletedTask;
            public Task ResumeAsync(GameApplicationStore store, CancellationToken cancellationToken) =>
                Task.CompletedTask;
            public Task LowMemoryAsync(GameApplicationStore store, CancellationToken cancellationToken) =>
                Task.CompletedTask;

            public void Dispose()
            {
                DisposeCount++;
                throw new InvalidOperationException("hook dispose failed");
            }
        }

        private sealed class RecordingRepository : ISaveRepository<GameSaveAggregate>, IDisposable
        {
            public int DisposeCount { get; private set; }

            public Task<SaveWriteResult<GameSaveAggregate>> SaveAsync(
                GameSaveAggregate payload,
                ulong revision,
                CancellationToken cancellationToken = default)
            {
                throw new AssertionException("No command should be saved by this test.");
            }

            public Task<SaveLoadResult<GameSaveAggregate>> LoadAsync(
                CancellationToken cancellationToken = default)
            {
                return Task.FromResult(SaveLoadResult<GameSaveAggregate>.Create(
                    SaveLoadStatus.NoSave));
            }

            public Task ResetAsync(CancellationToken cancellationToken = default)
            {
                return Task.CompletedTask;
            }

            public void Dispose()
            {
                DisposeCount++;
            }
        }

        private sealed class UnusedHighSchoolPort : IHighSchoolCareerPort
        {
            public HighSchoolCareerReadModel Start(StartHighSchoolCareerRequest request) =>
                throw new NotSupportedException();
            public HighSchoolCareerReadModel Apply(
                HighSchoolCareerReadModel current, HighSchoolAction action) =>
                throw new NotSupportedException();
            public HighSchoolCareerReadModel ReservePitch(
                HighSchoolCareerReadModel current, string scenarioId) =>
                throw new NotSupportedException();
            public HighSchoolCareerReadModel ApplyPitchResult(
                HighSchoolCareerReadModel current, PitchGameReport report) =>
                throw new NotSupportedException();
        }

        private sealed class UnusedProPort : IProCareerPort
        {
            public ProCareerReadModel StartFromDraft(HighSchoolCareerReadModel highSchoolCareer) =>
                throw new NotSupportedException();
            public ProCareerReadModel StartDirect(StartDirectProRequest request) =>
                throw new NotSupportedException();
            public ProCareerReadModel Apply(ProCareerReadModel current, ProCareerAction action) =>
                throw new NotSupportedException();
            public ProCareerReadModel ReservePitch(ProCareerReadModel current, string scenarioId) =>
                throw new NotSupportedException();
            public ProCareerReadModel ApplyPitchResult(
                ProCareerReadModel current, PitchGameReport report) =>
                throw new NotSupportedException();
        }

        private sealed class DedicatedMainThread : IRuntimeGameMainThread, IDisposable
        {
            private readonly BlockingCollection<Action> _queue = new BlockingCollection<Action>();
            private readonly Thread _thread;
            private readonly ManualResetEventSlim _started = new ManualResetEventSlim();

            public DedicatedMainThread()
            {
                _thread = new Thread(Pump) { IsBackground = true, Name = "runtime-test-main" };
                _thread.Start();
                _started.Wait();
            }

            public int ThreadId { get; private set; }
            public bool IsMainThread => Thread.CurrentThread.ManagedThreadId == ThreadId;

            public Task RunAsync(Action action, CancellationToken cancellationToken = default)
            {
                if (IsMainThread)
                {
                    action();
                    return Task.CompletedTask;
                }
                var completion = new TaskCompletionSource<bool>(
                    TaskCreationOptions.RunContinuationsAsynchronously);
                _queue.Add(() =>
                {
                    if (cancellationToken.IsCancellationRequested)
                    {
                        completion.TrySetCanceled(cancellationToken);
                        return;
                    }
                    try
                    {
                        action();
                        completion.TrySetResult(true);
                    }
                    catch (Exception exception)
                    {
                        completion.TrySetException(exception);
                    }
                });
                return completion.Task;
            }

            public Task RunAsync(Func<Task> action, CancellationToken cancellationToken = default)
            {
                if (action == null) throw new ArgumentNullException(nameof(action));
                cancellationToken.ThrowIfCancellationRequested();
                if (IsMainThread)
                {
                    try
                    {
                        return action() ?? Task.FromException(
                            new InvalidOperationException("runtime.main_thread_task_missing"));
                    }
                    catch (Exception exception)
                    {
                        return Task.FromException(exception);
                    }
                }
                var completion = new TaskCompletionSource<bool>(
                    TaskCreationOptions.RunContinuationsAsynchronously);
                _queue.Add(async () =>
                {
                    try
                    {
                        var operation = action();
                        if (operation == null)
                            throw new InvalidOperationException("runtime.main_thread_task_missing");
                        await operation;
                        completion.TrySetResult(true);
                    }
                    catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
                    {
                        completion.TrySetCanceled(cancellationToken);
                    }
                    catch (Exception exception)
                    {
                        completion.TrySetException(exception);
                    }
                });
                return completion.Task;
            }

            public void Run(Action action)
            {
                if (IsMainThread)
                {
                    action();
                    return;
                }
                RunAsync(action).GetAwaiter().GetResult();
            }

            public void Dispose()
            {
                _queue.CompleteAdding();
                _thread.Join();
                _started.Dispose();
                _queue.Dispose();
            }

            private void Pump()
            {
                ThreadId = Thread.CurrentThread.ManagedThreadId;
                SynchronizationContext.SetSynchronizationContext(
                    new QueueSynchronizationContext(_queue));
                _started.Set();
                foreach (var action in _queue.GetConsumingEnumerable()) action();
            }

            private sealed class QueueSynchronizationContext : SynchronizationContext
            {
                private readonly BlockingCollection<Action> _queue;

                public QueueSynchronizationContext(BlockingCollection<Action> queue)
                {
                    _queue = queue;
                }

                public override void Post(SendOrPostCallback callback, object state)
                {
                    _queue.Add(() => callback(state));
                }
            }
        }
    }
}
