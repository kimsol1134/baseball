using System;
using System.Threading;
using System.Threading.Tasks;
using Baseball.Application.Commands;

namespace Baseball.Application.Stores
{
    /// <summary>
    /// Serializes commands and exposes a new snapshot only after durable persistence succeeds.
    /// Reducers must return a new immutable snapshot with revision + 1 and the command receipt.
    /// </summary>
    public sealed class PersistentStore<TState, TCommand> : IDisposable
        where TState : class, IStoreSnapshot
    {
        private readonly IStateTransition<TState, TCommand> _transition;
        private readonly IStateSaver<TState> _saver;
        private readonly SemaphoreSlim _commandGate = new SemaphoreSlim(1, 1);
        private TState _current;
        private bool _disposed;
        private int _busy;

        public PersistentStore(
            TState initialState,
            IStateTransition<TState, TCommand> transition,
            IStateSaver<TState> saver)
        {
            _current = initialState ?? throw new ArgumentNullException(nameof(initialState));
            _transition = transition ?? throw new ArgumentNullException(nameof(transition));
            _saver = saver ?? throw new ArgumentNullException(nameof(saver));
        }

        public TState Current => Volatile.Read(ref _current);

        public bool IsBusy => Volatile.Read(ref _busy) != 0;

        public event Action<TState> StatePublished;

        public event Action<bool> BusyChanged;

        public async Task<DispatchResult<TState>> DispatchAsync(
            CommandEnvelope<TCommand> envelope,
            CancellationToken cancellationToken = default)
        {
            if (envelope == null)
            {
                throw new ArgumentNullException(nameof(envelope));
            }

            ThrowIfDisposed();
            try
            {
                await _commandGate.WaitAsync(cancellationToken);
            }
            catch (OperationCanceledException exception)
            {
                return DispatchResult<TState>.Create(
                    DispatchStatus.Cancelled,
                    Current,
                    "command.cancelled",
                    exception);
            }

            SetBusy(true);
            try
            {
                var current = Current;
                if (current.HasCommandReceipt(envelope.CommandId))
                {
                    return DispatchResult<TState>.Create(
                        DispatchStatus.AlreadyApplied,
                        current);
                }

                if (current.Revision != envelope.ExpectedRevision)
                {
                    return DispatchResult<TState>.Create(
                        DispatchStatus.StaleRevision,
                        current,
                        "command.stale_revision");
                }

                TransitionResult<TState> transition;
                try
                {
                    transition = _transition.Apply(current, envelope.Command, envelope.CommandId);
                }
                catch (Exception exception)
                {
                    return DispatchResult<TState>.Create(
                        DispatchStatus.DomainRejected,
                        current,
                        "command.transition_exception",
                        exception);
                }

                if (transition == null || !transition.IsSuccess)
                {
                    return DispatchResult<TState>.Create(
                        DispatchStatus.DomainRejected,
                        current,
                        transition?.ErrorCode ?? "command.transition_null");
                }

                var next = transition.NextState;
                if (!IsValidNextState(current, next, envelope.CommandId))
                {
                    return DispatchResult<TState>.Create(
                        DispatchStatus.InvalidTransition,
                        current,
                        "command.invalid_transition");
                }

                try
                {
                    // Preserve the caller synchronization context so UI-bound observers
                    // are published on the Unity main thread after background persistence.
                    await _saver.SaveAsync(next, cancellationToken);
                }
                catch (OperationCanceledException exception)
                {
                    return DispatchResult<TState>.Create(
                        DispatchStatus.Cancelled,
                        current,
                        "save.cancelled",
                        exception);
                }
                catch (Exception exception)
                {
                    return DispatchResult<TState>.Create(
                        DispatchStatus.PersistenceFailed,
                        current,
                        "save.failed",
                        exception);
                }

                Volatile.Write(ref _current, next);
                Notify(StatePublished, next);
                return DispatchResult<TState>.Create(DispatchStatus.Applied, next);
            }
            finally
            {
                SetBusy(false);
                _commandGate.Release();
            }
        }

        public void Dispose()
        {
            if (_disposed)
            {
                return;
            }

            _disposed = true;
            _commandGate.Dispose();
        }

        private static bool IsValidNextState(TState current, TState next, string commandId)
        {
            if (next == null || ReferenceEquals(current, next))
            {
                return false;
            }

            if (current.Revision == ulong.MaxValue || next.Revision != current.Revision + 1)
            {
                return false;
            }

            return next.HasCommandReceipt(commandId);
        }

        private void SetBusy(bool value)
        {
            Volatile.Write(ref _busy, value ? 1 : 0);
            Notify(BusyChanged, value);
        }

        private static void Notify<T>(Action<T> subscribers, T value)
        {
            if (subscribers == null)
            {
                return;
            }

            foreach (Action<T> subscriber in subscribers.GetInvocationList())
            {
                try
                {
                    subscriber(value);
                }
                catch (Exception)
                {
                    // UI/analytics observers are downstream of the durable transition.
                    // Their failures must not reclassify an already committed command.
                }
            }
        }

        private void ThrowIfDisposed()
        {
            if (_disposed)
            {
                throw new ObjectDisposedException(nameof(PersistentStore<TState, TCommand>));
            }
        }
    }
}
