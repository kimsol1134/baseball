using System;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using Baseball.Application.Commands;
using UnityEngine;

namespace Baseball.Bootstrap
{
    [DefaultExecutionOrder(-10000)]
    public sealed class AppRoot : MonoBehaviour
    {
        private static AppRoot _instance;

        private readonly SemaphoreSlim _lifecycleGate = new SemaphoreSlim(1, 1);
        private CancellationTokenSource _lifetime;
        private IApplicationLifecycleCoordinator _coordinator;
        private bool _quitting;

        public static event Action<Exception> LifecycleFailed;

        /// <summary>
        /// Production presentation retry bridge. It uses the same gate as pause/resume so a retry
        /// can never race lifecycle work, and RuntimeGameCoordinator keeps concurrent retries
        /// idempotent after the first successful open.
        /// </summary>
        public static async Task RetryInitializationAsync(CancellationToken cancellationToken)
        {
            AppRoot instance = _instance;
            if (instance == null || instance._coordinator == null || instance._lifetime == null)
                throw new InvalidOperationException("runtime.app_root_unavailable");
            using (var linked = CancellationTokenSource.CreateLinkedTokenSource(
                       cancellationToken,
                       instance._lifetime.Token))
            {
                await instance.RunLifecycleAsync(
                    coordinator => coordinator.InitializeAsync(linked.Token),
                    linked.Token);
            }
        }

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
        private static void ResetStatics()
        {
            _instance = null;
            LifecycleFailed = null;
            RuntimeGameServices.ResetForDomainReload();
            BootstrapConfiguration.ResetForDomainReload();
        }

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
        private static void EnsureRootExists()
        {
            if (_instance != null)
            {
                return;
            }

            var gameObject = new GameObject("AppRoot");
            gameObject.AddComponent<AppRoot>();
        }

        private void Awake()
        {
            if (_instance != null && _instance != this)
            {
                Destroy(gameObject);
                return;
            }

            _instance = this;
            DontDestroyOnLoad(gameObject);
            _lifetime = new CancellationTokenSource();
            var saveDirectory = Path.Combine(UnityEngine.Application.persistentDataPath, "save");
            var mainThread = new SynchronizationContextRuntimeGameMainThread(
                SynchronizationContext.Current,
                Thread.CurrentThread.ManagedThreadId);
            _coordinator = BootstrapConfiguration.CreateCoordinator(saveDirectory, mainThread);
            UnityEngine.Application.lowMemory += HandleLowMemory;
            QueueLifecycle(coordinator => coordinator.InitializeAsync(_lifetime.Token));
        }

        private void OnApplicationPause(bool paused)
        {
            if (_coordinator == null || _quitting)
            {
                return;
            }

            if (paused)
            {
                QueueLifecycle(coordinator => coordinator.PauseAsync(_lifetime.Token));
            }
            else
            {
                QueueLifecycle(coordinator => coordinator.ResumeAsync(_lifetime.Token));
            }
        }

        private void HandleLowMemory()
        {
            if (_coordinator != null && !_quitting)
            {
                QueueLifecycle(coordinator => coordinator.LowMemoryAsync(_lifetime.Token));
            }
        }

        private void OnApplicationQuit()
        {
            _quitting = true;
        }

        private void OnDestroy()
        {
            if (_instance != this)
            {
                return;
            }

            UnityEngine.Application.lowMemory -= HandleLowMemory;
            _lifetime?.Cancel();
            DisposeAfterLifecycleDrains(_coordinator, _lifetime);
            _instance = null;
        }

        private async void QueueLifecycle(
            Func<IApplicationLifecycleCoordinator, Task> operation)
        {
            try
            {
                await RunLifecycleAsync(operation, _lifetime.Token);
            }
            catch (OperationCanceledException) when (_lifetime == null || _lifetime.IsCancellationRequested)
            {
            }
            catch (Exception exception)
            {
                Debug.LogException(exception);
                NotifyLifecycleFailed(exception);
            }
        }

        private async Task RunLifecycleAsync(
            Func<IApplicationLifecycleCoordinator, Task> operation,
            CancellationToken cancellationToken)
        {
            if (operation == null) throw new ArgumentNullException(nameof(operation));
            CancellationToken lifetimeToken = _lifetime?.Token ?? CancellationToken.None;
            using (var linked = CancellationTokenSource.CreateLinkedTokenSource(
                       cancellationToken,
                       lifetimeToken))
            {
                await _lifecycleGate.WaitAsync(linked.Token);
                try
                {
                    linked.Token.ThrowIfCancellationRequested();
                    await operation(_coordinator);
                }
                finally
                {
                    _lifecycleGate.Release();
                }
            }
        }

        private async void DisposeAfterLifecycleDrains(
            IApplicationLifecycleCoordinator coordinator,
            CancellationTokenSource lifetime)
        {
            try
            {
                await _lifecycleGate.WaitAsync();
                coordinator?.Dispose();
            }
            catch (Exception exception)
            {
                Debug.LogException(exception);
                NotifyLifecycleFailed(exception);
            }
            finally
            {
                _lifecycleGate.Dispose();
                lifetime?.Dispose();
            }
        }

        private static void NotifyLifecycleFailed(Exception exception)
        {
            var subscribers = LifecycleFailed;
            if (subscribers == null)
            {
                return;
            }

            foreach (Action<Exception> subscriber in subscribers.GetInvocationList())
            {
                try
                {
                    subscriber(exception);
                }
                catch (Exception subscriberException)
                {
                    Debug.LogException(subscriberException);
                }
            }
        }
    }
}
