using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Baseball.Application.Commands;
using Baseball.Application.Meta;
using Baseball.Application.Persistence;
using Baseball.Application.Stores;

namespace Baseball.Bootstrap
{
    public enum RuntimeGameLifecycleState
    {
        Created,
        Running,
        Paused,
        Disposed
    }

    public interface IRuntimeGameStoreFactory
    {
        Task<GameApplicationStore> OpenAsync(CancellationToken cancellationToken);
    }

    public interface IRuntimeGameLifecycleHooks
    {
        Task PauseAsync(GameApplicationStore store, CancellationToken cancellationToken);

        Task ResumeAsync(GameApplicationStore store, CancellationToken cancellationToken);

        Task LowMemoryAsync(GameApplicationStore store, CancellationToken cancellationToken);
    }

    /// <summary>Optional hook used to establish session-depth analytics at first readiness.</summary>
    public interface IRuntimeGameSessionLifecycleHooks
    {
        void BeginSession(GameApplicationStore store);
    }

    /// <summary>
    /// Serializes lifecycle callbacks independently of MonoBehaviour callback order. State is
    /// changed only after a hook succeeds, making a failed callback safe to retry.
    /// </summary>
    public sealed class RuntimeGameCoordinator : IApplicationLifecycleCoordinator
    {
        private readonly object _sync = new object();
        private readonly SemaphoreSlim _operationGate = new SemaphoreSlim(1, 1);
        private readonly IRuntimeGameStoreFactory _storeFactory;
        private readonly IRuntimeGameLifecycleHooks _hooks;
        private readonly IRuntimeGameMainThread _mainThread;
        private GameApplicationStore _store;
        private RuntimeGameLifecycleState _state = RuntimeGameLifecycleState.Created;
        private bool _lowMemoryHandledSinceResume;
        private bool _disposeSignaled;

        public RuntimeGameCoordinator(
            IRuntimeGameStoreFactory storeFactory,
            IRuntimeGameLifecycleHooks hooks,
            IRuntimeGameMainThread mainThread)
        {
            _storeFactory = storeFactory ?? throw new ArgumentNullException(nameof(storeFactory));
            _hooks = hooks ?? throw new ArgumentNullException(nameof(hooks));
            _mainThread = mainThread ?? throw new ArgumentNullException(nameof(mainThread));
        }

        public RuntimeGameLifecycleState State
        {
            get
            {
                lock (_sync)
                {
                    return _state;
                }
            }
        }

        public Task InitializeAsync(CancellationToken cancellationToken)
        {
            return SerializedAsync(EnsureInitializedAsync, cancellationToken);
        }

        public Task PauseAsync(CancellationToken cancellationToken)
        {
            return SerializedAsync(PauseCoreAsync, cancellationToken);
        }

        public Task ResumeAsync(CancellationToken cancellationToken)
        {
            return SerializedAsync(ResumeCoreAsync, cancellationToken);
        }

        public Task LowMemoryAsync(CancellationToken cancellationToken)
        {
            return SerializedAsync(LowMemoryCoreAsync, cancellationToken);
        }

        public void Dispose()
        {
            GameApplicationStore store;
            lock (_sync)
            {
                if (_disposeSignaled) return;
                _disposeSignaled = true;
                _state = RuntimeGameLifecycleState.Disposed;
                store = _store;
                _store = null;
            }

            // AppRoot drains its lifecycle gate before disposal. Run still makes direct off-thread
            // disposal safe for tests, editor shutdown, and future non-MonoBehaviour owners.
            var failures = new List<Exception>();
            if (store != null)
            {
                TryCleanup(
                    () => _mainThread.Run(() => RuntimeGameServices.Clear(store, _mainThread)),
                    failures);
            }
            TryCleanup(() => store?.Dispose(), failures);
            if (_hooks is IDisposable disposableHooks)
                TryCleanup(disposableHooks.Dispose, failures);
            if (_storeFactory is IDisposable disposableFactory)
                TryCleanup(disposableFactory.Dispose, failures);
            if (failures.Count > 0)
                throw new AggregateException("runtime.dispose_failed", failures);
        }

        private async Task SerializedAsync(
            Func<CancellationToken, Task> operation,
            CancellationToken cancellationToken)
        {
            ThrowIfDisposed();
            await _operationGate.WaitAsync(cancellationToken).ConfigureAwait(false);
            try
            {
                ThrowIfDisposed();
                await operation(cancellationToken).ConfigureAwait(false);
            }
            finally
            {
                _operationGate.Release();
            }
        }

        private async Task EnsureInitializedAsync(CancellationToken cancellationToken)
        {
            lock (_sync)
            {
                if (_store != null) return;
            }

            GameApplicationStore opened = null;
            var published = false;
            try
            {
                opened = await _storeFactory.OpenAsync(cancellationToken).ConfigureAwait(false);
                if (opened == null)
                    throw new InvalidOperationException("runtime.store_factory_returned_null");
                ThrowIfDisposed();
                if (_hooks is IRuntimeGameSessionLifecycleHooks sessionHooks)
                    sessionHooks.BeginSession(opened);
                await _mainThread.RunAsync(
                        () => RuntimeGameServices.PublishReady(opened, _mainThread),
                        cancellationToken)
                    .ConfigureAwait(false);
                published = true;

                lock (_sync)
                {
                    ThrowIfDisposedLocked();
                    _store = opened;
                    _state = RuntimeGameLifecycleState.Running;
                    _lowMemoryHandledSinceResume = false;
                }
                opened = null;
            }
            catch (Exception exception)
            {
                if (published)
                {
                    await _mainThread.RunAsync(
                            () => RuntimeGameServices.Clear(opened, _mainThread),
                            CancellationToken.None)
                        .ConfigureAwait(false);
                }
                opened?.Dispose();
                if (!(exception is OperationCanceledException))
                {
                    await _mainThread.RunAsync(
                            () => RuntimeGameServices.PublishStartupFailure(exception, _mainThread),
                            CancellationToken.None)
                        .ConfigureAwait(false);
                }
                throw;
            }
        }

        private async Task PauseCoreAsync(CancellationToken cancellationToken)
        {
            await EnsureInitializedAsync(cancellationToken).ConfigureAwait(false);
            GameApplicationStore store;
            lock (_sync)
            {
                if (_state == RuntimeGameLifecycleState.Paused) return;
                ThrowIfDisposedLocked();
                store = _store;
            }
            await _mainThread.RunAsync(
                    () => _hooks.PauseAsync(store, cancellationToken),
                    cancellationToken)
                .ConfigureAwait(false);
            lock (_sync)
            {
                ThrowIfDisposedLocked();
                _state = RuntimeGameLifecycleState.Paused;
            }
        }

        private async Task ResumeCoreAsync(CancellationToken cancellationToken)
        {
            await EnsureInitializedAsync(cancellationToken).ConfigureAwait(false);
            GameApplicationStore store;
            lock (_sync)
            {
                if (_state == RuntimeGameLifecycleState.Running) return;
                ThrowIfDisposedLocked();
                store = _store;
            }
            await _mainThread.RunAsync(
                    () => _hooks.ResumeAsync(store, cancellationToken),
                    cancellationToken)
                .ConfigureAwait(false);
            lock (_sync)
            {
                ThrowIfDisposedLocked();
                _state = RuntimeGameLifecycleState.Running;
                _lowMemoryHandledSinceResume = false;
            }
        }

        private async Task LowMemoryCoreAsync(CancellationToken cancellationToken)
        {
            await EnsureInitializedAsync(cancellationToken).ConfigureAwait(false);
            GameApplicationStore store;
            lock (_sync)
            {
                if (_lowMemoryHandledSinceResume) return;
                ThrowIfDisposedLocked();
                store = _store;
            }
            await _mainThread.RunAsync(
                    () => _hooks.LowMemoryAsync(store, cancellationToken),
                    cancellationToken)
                .ConfigureAwait(false);
            lock (_sync)
            {
                ThrowIfDisposedLocked();
                _lowMemoryHandledSinceResume = true;
            }
        }

        private void ThrowIfDisposed()
        {
            lock (_sync)
            {
                ThrowIfDisposedLocked();
            }
        }

        private void ThrowIfDisposedLocked()
        {
            if (_disposeSignaled)
                throw new ObjectDisposedException(nameof(RuntimeGameCoordinator));
        }

        private static void TryCleanup(Action action, ICollection<Exception> failures)
        {
            try
            {
                action();
            }
            catch (Exception exception)
            {
                failures.Add(exception);
            }
        }
    }

    /// <summary>
    /// Commands commit through AtomicSaveRepository before GameApplicationStore publishes state,
    /// so there is no dirty memory buffer to flush during platform lifecycle callbacks.
    /// </summary>
    public sealed class DurableRuntimeGameLifecycleHooks :
        IRuntimeGameLifecycleHooks,
        IRuntimeGameSessionLifecycleHooks
    {
        private readonly object _sessionSync = new object();
        private readonly Func<DateTimeOffset> _clock;
        private readonly int _developmentRulesVersion;
        private readonly Func<SessionEndReturnReadModel, CancellationToken, Task>
            _publishSessionEndPrepared;
        private DateTimeOffset _sessionStartedAt;
        private int _sessionStartedGameCount;
        private bool _sessionStarted;

        public DurableRuntimeGameLifecycleHooks(
            Func<DateTimeOffset> clock = null,
            int developmentRulesVersion = ReturnPlanRules.CurrentDevelopmentRulesVersion,
            Func<SessionEndReturnReadModel, CancellationToken, Task>
                publishSessionEndPrepared = null)
        {
            _clock = clock ?? (() => DateTimeOffset.UtcNow);
            if (developmentRulesVersion <= 0)
                throw new ArgumentOutOfRangeException(nameof(developmentRulesVersion));
            _developmentRulesVersion = developmentRulesVersion;
            _publishSessionEndPrepared = publishSessionEndPrepared ??
                ((_, __) => Task.CompletedTask);
        }

        public void BeginSession(GameApplicationStore store)
        {
            if (store == null) throw new ArgumentNullException(nameof(store));
            lock (_sessionSync)
            {
                _sessionStartedAt = _clock();
                _sessionStartedGameCount = ReturnPlanRules.CompletedGameCount(store.Current);
                _sessionStarted = true;
            }
        }

        public async Task PauseAsync(GameApplicationStore store, CancellationToken cancellationToken)
        {
            if (store == null) throw new ArgumentNullException(nameof(store));
            cancellationToken.ThrowIfCancellationRequested();
            for (var attempt = 0; attempt < 2; attempt++)
            {
                var current = store.Current;
                var now = _clock();
                EnsureSessionStarted(current, now);
                var candidate = ReturnPlanRules.PrepareForNextReturn(
                    current,
                    current.InstallId,
                    _developmentRulesVersion,
                    now);
                if (candidate == null)
                {
                    await PublishSessionEndAsync(current, null, false, cancellationToken);
                    return;
                }
                var eligibleReceiptScope = ReturnPlanRules.EligibleReceiptScope(candidate);
                if (string.Equals(
                    current.Meta.ReturnPlan?.ReceiptId,
                    candidate.ReceiptId,
                    StringComparison.Ordinal))
                {
                    var eligibleReceiptApplied = false;
                    if (!current.AnalyticsReceipts.Contains(eligibleReceiptScope))
                    {
                        var receiptResult = await store.DispatchAsync(
                                new CommandEnvelope<GameCommand>(
                                    "lifecycle:return-plan-eligible:" + candidate.ReceiptId,
                                    current.Revision,
                                    new MarkAnalyticsReceiptCommand(
                                        eligibleReceiptScope,
                                        now,
                                        AnalyticsReceiptRetention.Scoped)),
                                cancellationToken);
                        if (receiptResult.Status == DispatchStatus.StaleRevision) continue;
                        if (receiptResult.Status != DispatchStatus.Applied &&
                            receiptResult.Status != DispatchStatus.AlreadyApplied &&
                            !(receiptResult.Status == DispatchStatus.DomainRejected &&
                              string.Equals(
                                  receiptResult.ErrorCode,
                                  "analytics.already_marked",
                                  StringComparison.Ordinal)))
                        {
                            throw new InvalidOperationException(
                                receiptResult.ErrorCode ?? "return_plan.receipt_save_failed");
                        }
                        eligibleReceiptApplied = receiptResult.Status == DispatchStatus.Applied;
                        if (!store.Current.AnalyticsReceipts.Contains(eligibleReceiptScope))
                            throw new InvalidOperationException("return_plan.atomic_receipt_missing");
                    }
                    await PublishSessionEndAsync(
                            store.Current,
                            store.Current.Meta.ReturnPlan,
                            eligibleReceiptApplied,
                            cancellationToken);
                    return;
                }
                var result = await store.DispatchAsync(
                        new CommandEnvelope<GameCommand>(
                            "lifecycle:return-plan:" + candidate.ReceiptId,
                            current.Revision,
                            new PrepareReturnPlanCommand(now, _developmentRulesVersion)),
                        cancellationToken);
                if (result.Status == DispatchStatus.Applied ||
                    result.Status == DispatchStatus.AlreadyApplied)
                {
                    var persisted = store.Current;
                    var persistedPlan = persisted.Meta.ReturnPlan;
                    var persistedScope = ReturnPlanRules.EligibleReceiptScope(persistedPlan);
                    if (persistedPlan == null ||
                        !string.Equals(
                            persistedPlan.ReceiptId,
                            candidate.ReceiptId,
                            StringComparison.Ordinal) ||
                        !persisted.AnalyticsReceipts.Contains(persistedScope))
                    {
                        throw new InvalidOperationException("return_plan.atomic_receipt_missing");
                    }
                    await PublishSessionEndAsync(
                            persisted,
                            persistedPlan,
                            result.Status == DispatchStatus.Applied &&
                            !current.AnalyticsReceipts.Contains(persistedScope),
                            cancellationToken);
                    return;
                }
                if (result.Status == DispatchStatus.DomainRejected &&
                    string.Equals(result.ErrorCode, "return_plan.ineligible", StringComparison.Ordinal))
                {
                    await PublishSessionEndAsync(store.Current, null, false, cancellationToken);
                    return;
                }
                if (result.Status != DispatchStatus.StaleRevision)
                    throw new InvalidOperationException(result.ErrorCode ?? "return_plan.pause_save_failed");
            }
            throw new InvalidOperationException("return_plan.pause_revision_conflict");
        }

        private Task PublishSessionEndAsync(
            GameSaveAggregate aggregate,
            ReturnPlanState plan,
            bool shouldEmitReturnEligible,
            CancellationToken cancellationToken)
        {
            return _publishSessionEndPrepared(
                ReturnPlanRules.SessionEnd(
                    aggregate,
                    plan,
                    SessionStartedAt(),
                    SessionStartedGameCount(),
                    _clock(),
                    shouldEmitReturnEligible),
                cancellationToken);
        }

        public async Task ResumeAsync(GameApplicationStore store, CancellationToken cancellationToken)
        {
            if (store == null) throw new ArgumentNullException(nameof(store));
            cancellationToken.ThrowIfCancellationRequested();
            await store.ReconcilePersistedRevisionAsync(cancellationToken);
            BeginSession(store);
        }

        public Task LowMemoryAsync(GameApplicationStore store, CancellationToken cancellationToken)
        {
            if (store == null) throw new ArgumentNullException(nameof(store));
            cancellationToken.ThrowIfCancellationRequested();
            return Task.CompletedTask;
        }

        private void EnsureSessionStarted(GameSaveAggregate aggregate, DateTimeOffset now)
        {
            lock (_sessionSync)
            {
                if (_sessionStarted) return;
                _sessionStartedAt = now;
                _sessionStartedGameCount = ReturnPlanRules.CompletedGameCount(aggregate);
                _sessionStarted = true;
            }
        }

        private DateTimeOffset SessionStartedAt()
        {
            lock (_sessionSync) return _sessionStartedAt;
        }

        private int SessionStartedGameCount()
        {
            lock (_sessionSync) return _sessionStartedGameCount;
        }
    }

    /// <summary>
    /// Cold/warm return analytics boundary. A non-null result means its one-shot receipt was
    /// durably saved and the caller may now emit exactly this PII-free projection.
    /// </summary>
    public static class RuntimeReturnPlanAnalytics
    {
        public static async Task<ReturnPlanAnalyticsReadModel> ReserveNextDayOpenAsync(
            GameApplicationStore store,
            string launchType,
            DateTimeOffset now,
            CancellationToken cancellationToken = default)
        {
            if (store == null) throw new ArgumentNullException(nameof(store));
            for (var attempt = 0; attempt < 2; attempt++)
            {
                var current = store.Current;
                var properties = ReturnPlanRules.NextDayOpen(
                    current.Meta.ReturnPlan,
                    launchType,
                    now);
                var scope = ReturnPlanRules.NextDayOpenReceiptScope(properties);
                if (scope == null || current.AnalyticsReceipts.Contains(scope)) return null;
                var result = await store.DispatchAsync(
                        new CommandEnvelope<GameCommand>(
                            "analytics:return-plan-open:" + scope,
                            current.Revision,
                            new MarkAnalyticsReceiptCommand(
                                scope,
                                now,
                                AnalyticsReceiptRetention.Scoped)),
                        cancellationToken)
                    .ConfigureAwait(false);
                if (result.Status == DispatchStatus.Applied) return properties;
                if (result.Status == DispatchStatus.AlreadyApplied ||
                    result.Status == DispatchStatus.DomainRejected &&
                    string.Equals(result.ErrorCode, "analytics.already_marked", StringComparison.Ordinal))
                {
                    return null;
                }
                if (result.Status != DispatchStatus.StaleRevision)
                    throw new InvalidOperationException(result.ErrorCode ?? "return_plan.analytics_save_failed");
            }
            throw new InvalidOperationException("return_plan.analytics_revision_conflict");
        }
    }
}
