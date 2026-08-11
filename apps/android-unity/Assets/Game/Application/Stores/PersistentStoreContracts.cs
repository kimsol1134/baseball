using System;
using System.Threading;
using System.Threading.Tasks;

namespace Baseball.Application.Stores
{
    public interface IStoreSnapshot
    {
        ulong Revision { get; }

        bool HasCommandReceipt(string commandId);
    }

    public interface IStateSaver<in TState>
    {
        Task SaveAsync(TState state, CancellationToken cancellationToken);
    }

    public interface IStateTransition<TState, in TCommand>
        where TState : class, IStoreSnapshot
    {
        TransitionResult<TState> Apply(TState currentState, TCommand command, string commandId);
    }

    public sealed class TransitionResult<TState>
    {
        private TransitionResult(bool isSuccess, TState nextState, string errorCode)
        {
            IsSuccess = isSuccess;
            NextState = nextState;
            ErrorCode = errorCode;
        }

        public bool IsSuccess { get; }

        public TState NextState { get; }

        public string ErrorCode { get; }

        public static TransitionResult<TState> Success(TState nextState)
        {
            return new TransitionResult<TState>(
                true,
                nextState ?? throw new ArgumentNullException(nameof(nextState)),
                null);
        }

        public static TransitionResult<TState> Failure(string errorCode)
        {
            if (string.IsNullOrWhiteSpace(errorCode))
            {
                throw new ArgumentException("A stable error code is required.", nameof(errorCode));
            }

            return new TransitionResult<TState>(false, default, errorCode);
        }
    }

    public enum DispatchStatus
    {
        Applied,
        AlreadyApplied,
        StaleRevision,
        DomainRejected,
        PersistenceFailed,
        InvalidTransition,
        Cancelled
    }

    public sealed class DispatchResult<TState>
    {
        private DispatchResult(DispatchStatus status, TState state, string errorCode, Exception exception)
        {
            Status = status;
            State = state;
            ErrorCode = errorCode;
            Exception = exception;
        }

        public DispatchStatus Status { get; }

        public TState State { get; }

        public string ErrorCode { get; }

        public Exception Exception { get; }

        public bool IsSuccess =>
            Status == DispatchStatus.Applied || Status == DispatchStatus.AlreadyApplied;

        public static DispatchResult<TState> Create(
            DispatchStatus status,
            TState state,
            string errorCode = null,
            Exception exception = null)
        {
            return new DispatchResult<TState>(status, state, errorCode, exception);
        }
    }
}
