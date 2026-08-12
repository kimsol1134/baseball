using System;
using Baseball.Application.Commands;

namespace Baseball.Bootstrap
{
    public static class BootstrapConfiguration
    {
        private static Func<string, IApplicationLifecycleCoordinator> _coordinatorFactory;

        public static void Configure(
            Func<string, IApplicationLifecycleCoordinator> coordinatorFactory)
        {
            _coordinatorFactory = coordinatorFactory ??
                                  throw new ArgumentNullException(nameof(coordinatorFactory));
        }

        internal static IApplicationLifecycleCoordinator CreateCoordinator(
            string saveDirectory,
            IRuntimeGameMainThread mainThread)
        {
            return _coordinatorFactory?.Invoke(saveDirectory) ??
                   RuntimeGameComposition.Create(saveDirectory, mainThread);
        }

        internal static void ResetForDomainReload()
        {
            _coordinatorFactory = null;
        }
    }
}
