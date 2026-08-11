using System;

namespace Baseball.Application.Navigation
{
    public sealed class NavigationRoute : IEquatable<NavigationRoute>
    {
        public NavigationRoute(
            string id,
            bool isDetail = false,
            bool hasUncommittedSelection = false,
            bool isPitchSession = false,
            bool blocksBack = false)
        {
            if (string.IsNullOrWhiteSpace(id))
            {
                throw new ArgumentException("A route ID is required.", nameof(id));
            }

            Id = id;
            IsDetail = isDetail;
            HasUncommittedSelection = hasUncommittedSelection;
            IsPitchSession = isPitchSession;
            BlocksBack = blocksBack;
        }

        public string Id { get; }

        public bool IsDetail { get; }

        public bool HasUncommittedSelection { get; }

        public bool IsPitchSession { get; }

        public bool BlocksBack { get; }

        public bool Equals(NavigationRoute other)
        {
            return other != null && string.Equals(Id, other.Id, StringComparison.Ordinal);
        }

        public override bool Equals(object obj) => Equals(obj as NavigationRoute);

        public override int GetHashCode() => StringComparer.Ordinal.GetHashCode(Id);
    }

    public enum BackAction
    {
        ModalClosed,
        DetailClosed,
        PanelPopped,
        ConfirmationRequired,
        BlockedIrreversible,
        ExitPrompt,
        ExitApplication,
        NoPendingConfirmation
    }

    public enum BackConfirmationKind
    {
        None,
        DiscardUncommittedSelection,
        LeavePitchSession
    }

    public sealed class BackResult
    {
        public BackResult(
            BackAction action,
            NavigationRoute currentRoute,
            BackConfirmationKind confirmationKind = BackConfirmationKind.None)
        {
            Action = action;
            CurrentRoute = currentRoute;
            ConfirmationKind = confirmationKind;
        }

        public BackAction Action { get; }

        public NavigationRoute CurrentRoute { get; }

        public BackConfirmationKind ConfirmationKind { get; }
    }
}
