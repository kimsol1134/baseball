using System;
using System.Collections.Generic;

namespace Baseball.Application.Navigation
{
    /// <summary>
    /// Pure application-level Android Back policy. The UI owns confirmation copy and
    /// calls ConfirmPendingBack only after the user explicitly accepts it.
    /// </summary>
    public sealed class BackNavigationStack
    {
        private readonly List<NavigationRoute> _routes = new List<NavigationRoute>();
        private readonly Stack<string> _modals = new Stack<string>();
        private readonly TimeSpan _rootExitWindow;
        private DateTimeOffset? _rootExitPromptedAt;
        private NavigationRoute _pendingConfirmationRoute;
        private BackConfirmationKind _pendingConfirmationKind;

        public BackNavigationStack(NavigationRoute rootRoute, TimeSpan? rootExitWindow = null)
        {
            _routes.Add(rootRoute ?? throw new ArgumentNullException(nameof(rootRoute)));
            _rootExitWindow = rootExitWindow ?? TimeSpan.FromSeconds(2);
            if (_rootExitWindow <= TimeSpan.Zero)
            {
                throw new ArgumentOutOfRangeException(nameof(rootExitWindow));
            }
        }

        public NavigationRoute CurrentRoute => _routes[_routes.Count - 1];

        public int RouteCount => _routes.Count;

        public int ModalCount => _modals.Count;

        public void Push(NavigationRoute route)
        {
            _routes.Add(route ?? throw new ArgumentNullException(nameof(route)));
            ClearPending();
            _rootExitPromptedAt = null;
        }

        public void OpenModal(string modalId)
        {
            if (string.IsNullOrWhiteSpace(modalId))
            {
                throw new ArgumentException("A modal ID is required.", nameof(modalId));
            }

            _modals.Push(modalId);
            ClearPending();
        }

        public BackResult HandleBack(DateTimeOffset now)
        {
            if (_modals.Count > 0)
            {
                _modals.Pop();
                ClearPending();
                return new BackResult(BackAction.ModalClosed, CurrentRoute);
            }

            var current = CurrentRoute;
            if (current.IsDetail && _routes.Count > 1)
            {
                _routes.RemoveAt(_routes.Count - 1);
                ClearPending();
                return new BackResult(BackAction.DetailClosed, CurrentRoute);
            }

            if (current.BlocksBack)
            {
                ClearPending();
                return new BackResult(BackAction.BlockedIrreversible, current);
            }

            if (current.HasUncommittedSelection)
            {
                return RequireConfirmation(
                    current,
                    BackConfirmationKind.DiscardUncommittedSelection);
            }

            if (current.IsPitchSession)
            {
                return RequireConfirmation(current, BackConfirmationKind.LeavePitchSession);
            }

            if (_routes.Count > 1)
            {
                _routes.RemoveAt(_routes.Count - 1);
                ClearPending();
                return new BackResult(BackAction.PanelPopped, CurrentRoute);
            }

            ClearPending();
            if (_rootExitPromptedAt.HasValue &&
                now >= _rootExitPromptedAt.Value &&
                now - _rootExitPromptedAt.Value <= _rootExitWindow)
            {
                _rootExitPromptedAt = null;
                return new BackResult(BackAction.ExitApplication, current);
            }

            _rootExitPromptedAt = now;
            return new BackResult(BackAction.ExitPrompt, current);
        }

        public BackResult ConfirmPendingBack(bool confirmed)
        {
            if (_pendingConfirmationRoute == null ||
                !_pendingConfirmationRoute.Equals(CurrentRoute))
            {
                ClearPending();
                return new BackResult(BackAction.NoPendingConfirmation, CurrentRoute);
            }

            if (!confirmed)
            {
                ClearPending();
                return new BackResult(BackAction.NoPendingConfirmation, CurrentRoute);
            }

            if (_routes.Count <= 1)
            {
                ClearPending();
                return new BackResult(BackAction.ExitPrompt, CurrentRoute);
            }

            var wasDetail = CurrentRoute.IsDetail;
            _routes.RemoveAt(_routes.Count - 1);
            ClearPending();
            return new BackResult(
                wasDetail ? BackAction.DetailClosed : BackAction.PanelPopped,
                CurrentRoute);
        }

        private BackResult RequireConfirmation(
            NavigationRoute route,
            BackConfirmationKind confirmationKind)
        {
            _pendingConfirmationRoute = route;
            _pendingConfirmationKind = confirmationKind;
            return new BackResult(
                BackAction.ConfirmationRequired,
                route,
                _pendingConfirmationKind);
        }

        private void ClearPending()
        {
            _pendingConfirmationRoute = null;
            _pendingConfirmationKind = BackConfirmationKind.None;
        }
    }
}
