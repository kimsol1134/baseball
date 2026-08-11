using System;
using System.Threading;
using System.Threading.Tasks;
using Baseball.Application.Stores;

namespace Baseball.Application.Persistence
{
    public sealed class AtomicSaveStateSaver<TState> : IStateSaver<TState>
        where TState : class, IStoreSnapshot
    {
        private readonly ISaveRepository<TState> _repository;

        public AtomicSaveStateSaver(ISaveRepository<TState> repository)
        {
            _repository = repository ?? throw new ArgumentNullException(nameof(repository));
        }

        public async Task SaveAsync(TState state, CancellationToken cancellationToken)
        {
            if (state == null)
            {
                throw new ArgumentNullException(nameof(state));
            }

            await _repository.SaveAsync(state, state.Revision, cancellationToken).ConfigureAwait(false);
        }
    }
}
