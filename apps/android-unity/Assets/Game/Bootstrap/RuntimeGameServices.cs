using System;
using Baseball.Application.Meta;
using Baseball.Application.Stores;

namespace Baseball.Bootstrap
{
    /// <summary>
    /// Process-wide read boundary for scene and presentation code. Publications are performed by
    /// RuntimeGameCoordinator on the captured Unity main thread. Reads remain safe from any thread.
    /// </summary>
    public static class RuntimeGameServices
    {
        private static readonly object Sync = new object();
        private static GameApplicationStore _store;

        public static event Action<GameApplicationStore> Ready;
        public static event Action<GameApplicationStore> StoreChanged;
        public static event Action BecameUnavailable;
        public static event Action<Exception> StartupFailed;
        /// <summary>
        /// Fired once for each successfully completed production pause. Eligible projections are
        /// published only after their return plan and analytics receipt are durably saved.
        /// </summary>
        public static event Action<SessionEndReturnReadModel> SessionEndPrepared;

        public static bool IsReady
        {
            get
            {
                lock (Sync)
                {
                    return _store != null;
                }
            }
        }

        /// <summary>Returns null until Ready has been published.</summary>
        public static GameApplicationStore Store
        {
            get
            {
                lock (Sync)
                {
                    return _store;
                }
            }
        }

        public static bool TryGetStore(out GameApplicationStore store)
        {
            lock (Sync)
            {
                store = _store;
                return store != null;
            }
        }

        internal static void PublishReady(
            GameApplicationStore store,
            IRuntimeGameMainThread mainThread)
        {
            if (store == null) throw new ArgumentNullException(nameof(store));
            RequireMainThread(mainThread);

            lock (Sync)
            {
                if (ReferenceEquals(_store, store)) return;
                if (_store != null)
                    throw new InvalidOperationException("runtime.store_already_published");
                _store = store;
            }

            InvokeSafely(Ready, store);
            InvokeSafely(StoreChanged, store);
        }

        internal static void PublishStartupFailure(
            Exception exception,
            IRuntimeGameMainThread mainThread)
        {
            if (exception == null) throw new ArgumentNullException(nameof(exception));
            RequireMainThread(mainThread);
            InvokeSafely(StartupFailed, exception);
        }

        internal static void PublishSessionEndPrepared(
            SessionEndReturnReadModel value,
            IRuntimeGameMainThread mainThread)
        {
            if (value == null) throw new ArgumentNullException(nameof(value));
            RequireMainThread(mainThread);
            InvokeSafely(SessionEndPrepared, value);
        }

        internal static void Clear(
            GameApplicationStore expectedStore,
            IRuntimeGameMainThread mainThread)
        {
            RequireMainThread(mainThread);
            lock (Sync)
            {
                if (!ReferenceEquals(_store, expectedStore)) return;
                _store = null;
            }

            InvokeSafely(StoreChanged, null);
            InvokeSafely(BecameUnavailable);
        }

        internal static void ResetForDomainReload()
        {
            lock (Sync)
            {
                _store = null;
                Ready = null;
                StoreChanged = null;
                BecameUnavailable = null;
                StartupFailed = null;
                SessionEndPrepared = null;
            }
        }

        private static void RequireMainThread(IRuntimeGameMainThread mainThread)
        {
            if (mainThread == null) throw new ArgumentNullException(nameof(mainThread));
            if (!mainThread.IsMainThread)
                throw new InvalidOperationException("runtime.main_thread_required");
        }

        private static void InvokeSafely(Action handlers)
        {
            if (handlers == null) return;
            foreach (Action handler in handlers.GetInvocationList())
            {
                try
                {
                    handler();
                }
                catch
                {
                    // A scene subscriber must not prevent other subscribers or corrupt readiness.
                }
            }
        }

        private static void InvokeSafely<T>(Action<T> handlers, T value)
        {
            if (handlers == null) return;
            foreach (Action<T> handler in handlers.GetInvocationList())
            {
                try
                {
                    handler(value);
                }
                catch
                {
                    // A scene subscriber must not prevent other subscribers or corrupt readiness.
                }
            }
        }
    }
}
