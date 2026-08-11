using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Baseball.Application.Commands;
using Baseball.Application.HighSchool;
using Baseball.Application.Persistence;
using Baseball.Application.Pro;
using Baseball.Application.Stores;
using Baseball.Bootstrap;
using Baseball.Platform.Performance;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.TestTools;

namespace Baseball.PlayMode.Tests
{
    [TestFixture]
    public sealed class AppRootPlayModeTests
    {
        [Test]
        public void RuntimeFramePacingTargetsSixtyFramesForTwoDimensionalShell()
        {
            AppFramePacing.Configure();

            Assert.That(UnityEngine.Application.targetFrameRate, Is.EqualTo(60));
            Assert.That(QualitySettings.vSyncCount, Is.Zero);
            Assert.That(UnityEngine.Rendering.OnDemandRendering.renderFrameInterval, Is.EqualTo(1));
        }

        private RecordingLifecycleCoordinator _coordinator;
        private Action<GameApplicationStore> _readyHandler;
        private Action<Exception> _lifecycleFailureHandler;

        [UnitySetUp]
        public IEnumerator SetUp()
        {
            foreach (AppRoot root in UnityEngine.Object.FindObjectsByType<AppRoot>(FindObjectsSortMode.None))
            {
                UnityEngine.Object.Destroy(root.gameObject);
            }
            yield return null;
            if (RuntimeGameServices.IsReady)
            {
                yield return PlayModeDeadline.Until(
                    () => !RuntimeGameServices.IsReady,
                    "이전 AppRoot의 runtime store가 해제되지 않았습니다.");
            }
            BootstrapConfiguration.Configure(_ => new NullApplicationLifecycleCoordinator());
        }

        [UnityTearDown]
        public IEnumerator TearDown()
        {
            foreach (AppRoot root in UnityEngine.Object.FindObjectsByType<AppRoot>(FindObjectsSortMode.None))
            {
                UnityEngine.Object.Destroy(root.gameObject);
            }
            yield return null;

            if (RuntimeGameServices.IsReady)
            {
                yield return PlayModeDeadline.Until(
                    () => !RuntimeGameServices.IsReady,
                    "AppRoot 제거 뒤 runtime store가 해제되지 않았습니다.");
            }
            if (_coordinator != null)
            {
                yield return PlayModeDeadline.Until(
                    () => _coordinator.DisposeCalls == 1,
                    "AppRoot가 coordinator를 정리하지 않았습니다.");
            }
            if (_readyHandler != null) RuntimeGameServices.Ready -= _readyHandler;
            if (_lifecycleFailureHandler != null) AppRoot.LifecycleFailed -= _lifecycleFailureHandler;
            BootstrapConfiguration.Configure(_ => new NullApplicationLifecycleCoordinator());
            _coordinator = null;
            _readyHandler = null;
            _lifecycleFailureHandler = null;
        }

        [UnityTest]
        public IEnumerator InjectedRuntimeCoordinatorPublishesReadyStoreOnUnityMainThread()
        {
            var readyCount = 0;
            GameApplicationStore published = null;
            _readyHandler = store =>
            {
                readyCount++;
                published = store;
            };
            RuntimeGameServices.Ready += _readyHandler;
            BootstrapConfiguration.Configure(_ => new RuntimeGameCoordinator(
                new NoSaveStoreFactory(),
                new DurableRuntimeGameLifecycleHooks(),
                new SynchronizationContextRuntimeGameMainThread(
                    SynchronizationContext.Current,
                    Thread.CurrentThread.ManagedThreadId)));

            var rootObject = new GameObject("Ready AppRoot");
            rootObject.AddComponent<AppRoot>();
            yield return PlayModeDeadline.Until(
                () => RuntimeGameServices.IsReady,
                "RuntimeGameServices가 ready store를 게시하지 않았습니다.");

            Assert.That(readyCount, Is.EqualTo(1));
            Assert.That(RuntimeGameServices.TryGetStore(out GameApplicationStore current), Is.True);
            Assert.That(current, Is.SameAs(published));
            Assert.That(current.Current.Revision, Is.Zero);
        }

        [UnityTest]
        public IEnumerator InjectedCoordinatorBecomesReadyAndAppRootRemainsSingleton()
        {
            _coordinator = new RecordingLifecycleCoordinator();
            string suppliedDirectory = null;
            BootstrapConfiguration.Configure(directory =>
            {
                suppliedDirectory = directory;
                return _coordinator;
            });

            var primary = new GameObject("PlayMode AppRoot");
            primary.AddComponent<AppRoot>();
            yield return PlayModeDeadline.Until(
                () => _coordinator.IsReady,
                "주입한 coordinator가 초기화 완료 상태가 되지 않았습니다.");

            var duplicate = new GameObject("Duplicate AppRoot");
            duplicate.AddComponent<AppRoot>();
            yield return null;

            AppRoot[] roots = UnityEngine.Object.FindObjectsByType<AppRoot>(FindObjectsSortMode.None);
            Assert.That(roots, Has.Length.EqualTo(1));
            Assert.That(roots[0].gameObject, Is.SameAs(primary));
            Assert.That(_coordinator.InitializeCalls, Is.EqualTo(1));
            Assert.That(suppliedDirectory, Does.EndWith("save"));
        }

        [UnityTest]
        public IEnumerator PauseResumeAndLowMemoryAreSerializedAndRemainStable()
        {
            _coordinator = new RecordingLifecycleCoordinator();
            BootstrapConfiguration.Configure(_ => _coordinator);
            Exception lifecycleFailure = null;
            _lifecycleFailureHandler = exception => lifecycleFailure = exception;
            AppRoot.LifecycleFailed += _lifecycleFailureHandler;

            var rootObject = new GameObject("Lifecycle AppRoot");
            rootObject.AddComponent<AppRoot>();
            yield return PlayModeDeadline.Until(
                () => _coordinator.IsReady,
                "AppRoot 초기화가 완료되지 않았습니다.");

            rootObject.SendMessage("OnApplicationPause", true, SendMessageOptions.RequireReceiver);
            rootObject.SendMessage("OnApplicationPause", false, SendMessageOptions.RequireReceiver);
            rootObject.SendMessage("HandleLowMemory", SendMessageOptions.RequireReceiver);

            yield return PlayModeDeadline.Until(
                () => _coordinator.LowMemoryCalls == 1,
                "pause/resume/low-memory callback이 제한 시간 안에 끝나지 않았습니다.");

            Assert.That(_coordinator.Calls, Is.EqualTo(new[] { "initialize", "pause", "resume", "low-memory" }));
            Assert.That(_coordinator.PauseCalls, Is.EqualTo(1));
            Assert.That(_coordinator.ResumeCalls, Is.EqualTo(1));
            Assert.That(lifecycleFailure, Is.Null);
        }

        private sealed class RecordingLifecycleCoordinator : IApplicationLifecycleCoordinator
        {
            private readonly object _gate = new object();
            private readonly List<string> _calls = new List<string>();
            private int _disposeCalls;

            public IReadOnlyList<string> Calls
            {
                get
                {
                    lock (_gate)
                    {
                        return _calls.ToArray();
                    }
                }
            }

            public int InitializeCalls => Count("initialize");
            public int PauseCalls => Count("pause");
            public int ResumeCalls => Count("resume");
            public int LowMemoryCalls => Count("low-memory");
            public int DisposeCalls => Volatile.Read(ref _disposeCalls);
            public bool IsReady => InitializeCalls == 1;

            public Task InitializeAsync(CancellationToken cancellationToken) => RecordAsync("initialize", cancellationToken);
            public Task PauseAsync(CancellationToken cancellationToken) => RecordAsync("pause", cancellationToken);
            public Task ResumeAsync(CancellationToken cancellationToken) => RecordAsync("resume", cancellationToken);
            public Task LowMemoryAsync(CancellationToken cancellationToken) => RecordAsync("low-memory", cancellationToken);

            public void Dispose()
            {
                Interlocked.Increment(ref _disposeCalls);
            }

            private int Count(string operation)
            {
                lock (_gate)
                {
                    return _calls.Count(value => value == operation);
                }
            }

            private async Task RecordAsync(string operation, CancellationToken cancellationToken)
            {
                cancellationToken.ThrowIfCancellationRequested();
                await Task.Yield();
                cancellationToken.ThrowIfCancellationRequested();
                lock (_gate)
                {
                    _calls.Add(operation);
                }
            }
        }

        private sealed class NoSaveStoreFactory : IRuntimeGameStoreFactory
        {
            public Task<GameApplicationStore> OpenAsync(CancellationToken cancellationToken)
            {
                return GameApplicationStore.OpenAsync(
                    new NoSaveRepository(),
                    new CoreHighSchoolCareerPort(),
                    new CoreProCareerPort(),
                    "playmode-install",
                    cancellationToken);
            }
        }

        private sealed class NoSaveRepository : ISaveRepository<GameSaveAggregate>, IDisposable
        {
            public Task<SaveWriteResult<GameSaveAggregate>> SaveAsync(
                GameSaveAggregate payload,
                ulong revision,
                CancellationToken cancellationToken = default)
            {
                throw new InvalidOperationException("PlayMode bootstrap test must not write a save.");
            }

            public Task<SaveLoadResult<GameSaveAggregate>> LoadAsync(
                CancellationToken cancellationToken = default)
            {
                cancellationToken.ThrowIfCancellationRequested();
                return Task.FromResult(SaveLoadResult<GameSaveAggregate>.Create(SaveLoadStatus.NoSave));
            }

            public Task ResetAsync(CancellationToken cancellationToken = default)
            {
                cancellationToken.ThrowIfCancellationRequested();
                return Task.CompletedTask;
            }

            public void Dispose()
            {
            }
        }
    }
}
