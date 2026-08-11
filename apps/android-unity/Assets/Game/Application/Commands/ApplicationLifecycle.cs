using System;
using System.Threading;
using System.Threading.Tasks;

namespace Baseball.Application.Commands
{
    public interface IApplicationLifecycleCoordinator : IDisposable
    {
        Task InitializeAsync(CancellationToken cancellationToken);

        Task PauseAsync(CancellationToken cancellationToken);

        Task ResumeAsync(CancellationToken cancellationToken);

        Task LowMemoryAsync(CancellationToken cancellationToken);
    }

    public sealed class NullApplicationLifecycleCoordinator : IApplicationLifecycleCoordinator
    {
        public Task InitializeAsync(CancellationToken cancellationToken) => Task.CompletedTask;

        public Task PauseAsync(CancellationToken cancellationToken) => Task.CompletedTask;

        public Task ResumeAsync(CancellationToken cancellationToken) => Task.CompletedTask;

        public Task LowMemoryAsync(CancellationToken cancellationToken) => Task.CompletedTask;

        public void Dispose()
        {
        }
    }
}
