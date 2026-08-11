using System;
using System.Threading;
using System.Threading.Tasks;

namespace Baseball.Bootstrap
{
    public interface IRuntimeGameMainThread
    {
        bool IsMainThread { get; }

        Task RunAsync(Action action, CancellationToken cancellationToken = default);

        Task RunAsync(Func<Task> action, CancellationToken cancellationToken = default);

        void Run(Action action);
    }

    /// <summary>Marshals completion from save I/O back to Unity's captured main-thread context.</summary>
    public sealed class SynchronizationContextRuntimeGameMainThread : IRuntimeGameMainThread
    {
        private readonly SynchronizationContext _context;
        private readonly int _threadId;

        public SynchronizationContextRuntimeGameMainThread(
            SynchronizationContext context,
            int threadId)
        {
            _context = context;
            _threadId = threadId;
        }

        public bool IsMainThread => Thread.CurrentThread.ManagedThreadId == _threadId;

        public Task RunAsync(Action action, CancellationToken cancellationToken = default)
        {
            if (action == null) throw new ArgumentNullException(nameof(action));
            cancellationToken.ThrowIfCancellationRequested();
            if (IsMainThread)
            {
                action();
                return Task.CompletedTask;
            }
            if (_context == null)
            {
                return Task.FromException(
                    new InvalidOperationException("runtime.main_thread_context_missing"));
            }

            var completion = new TaskCompletionSource<bool>(
                TaskCreationOptions.RunContinuationsAsynchronously);
            _context.Post(
                _ =>
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
                },
                null);
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
            if (_context == null)
            {
                return Task.FromException(
                    new InvalidOperationException("runtime.main_thread_context_missing"));
            }

            var completion = new TaskCompletionSource<bool>(
                TaskCreationOptions.RunContinuationsAsynchronously);
            _context.Post(
                async _ =>
                {
                    if (cancellationToken.IsCancellationRequested)
                    {
                        completion.TrySetCanceled(cancellationToken);
                        return;
                    }
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
                },
                null);
            return completion.Task;
        }

        public void Run(Action action)
        {
            if (action == null) throw new ArgumentNullException(nameof(action));
            if (IsMainThread)
            {
                action();
                return;
            }
            if (_context == null)
                throw new InvalidOperationException("runtime.main_thread_context_missing");

            Exception failure = null;
            _context.Send(
                _ =>
                {
                    try
                    {
                        action();
                    }
                    catch (Exception exception)
                    {
                        failure = exception;
                    }
                },
                null);
            if (failure != null) throw failure;
        }
    }
}
