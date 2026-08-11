using System;
using Baseball.Application.Navigation;
using NUnit.Framework;

namespace Baseball.Application.Tests
{
    public sealed class BackNavigationStackTests
    {
        private static readonly DateTimeOffset Now =
            new DateTimeOffset(2026, 8, 11, 12, 0, 0, TimeSpan.Zero);

        [Test]
        public void Back_ClosesModalBeforeDetail()
        {
            var stack = new BackNavigationStack(new NavigationRoute("root"));
            stack.Push(new NavigationRoute("record-detail", isDetail: true));
            stack.OpenModal("filter");

            Assert.That(stack.HandleBack(Now).Action, Is.EqualTo(BackAction.ModalClosed));
            Assert.That(stack.CurrentRoute.Id, Is.EqualTo("record-detail"));
            Assert.That(stack.HandleBack(Now).Action, Is.EqualTo(BackAction.DetailClosed));
            Assert.That(stack.CurrentRoute.Id, Is.EqualTo("root"));
        }

        [Test]
        public void Back_UncommittedSelection_RequiresExplicitConfirmation()
        {
            var stack = new BackNavigationStack(new NavigationRoute("root"));
            stack.Push(new NavigationRoute("school-choice", hasUncommittedSelection: true));

            var request = stack.HandleBack(Now);
            Assert.That(request.Action, Is.EqualTo(BackAction.ConfirmationRequired));
            Assert.That(
                request.ConfirmationKind,
                Is.EqualTo(BackConfirmationKind.DiscardUncommittedSelection));
            Assert.That(stack.RouteCount, Is.EqualTo(2));

            Assert.That(stack.ConfirmPendingBack(false).Action, Is.EqualTo(BackAction.NoPendingConfirmation));
            Assert.That(stack.RouteCount, Is.EqualTo(2));

            stack.HandleBack(Now);
            Assert.That(stack.ConfirmPendingBack(true).Action, Is.EqualTo(BackAction.PanelPopped));
            Assert.That(stack.CurrentRoute.Id, Is.EqualTo("root"));
        }

        [Test]
        public void Back_PitchSession_UsesPitchConfirmation()
        {
            var stack = new BackNavigationStack(new NavigationRoute("root"));
            stack.Push(new NavigationRoute("pitch", isPitchSession: true));

            var result = stack.HandleBack(Now);

            Assert.That(result.Action, Is.EqualTo(BackAction.ConfirmationRequired));
            Assert.That(result.ConfirmationKind, Is.EqualTo(BackConfirmationKind.LeavePitchSession));
        }

        [Test]
        public void Back_IrreversiblePhase_DoesNotPop()
        {
            var stack = new BackNavigationStack(new NavigationRoute("root"));
            stack.Push(new NavigationRoute("legacy-result", blocksBack: true));

            Assert.That(stack.HandleBack(Now).Action, Is.EqualTo(BackAction.BlockedIrreversible));
            Assert.That(stack.CurrentRoute.Id, Is.EqualTo("legacy-result"));
        }

        [Test]
        public void Back_RootSecondPressWithinWindow_Exits()
        {
            var stack = new BackNavigationStack(
                new NavigationRoute("root"),
                TimeSpan.FromSeconds(2));

            Assert.That(stack.HandleBack(Now).Action, Is.EqualTo(BackAction.ExitPrompt));
            Assert.That(
                stack.HandleBack(Now.AddSeconds(1)).Action,
                Is.EqualTo(BackAction.ExitApplication));
        }

        [Test]
        public void Back_RootPressAfterWindow_PromptsAgain()
        {
            var stack = new BackNavigationStack(
                new NavigationRoute("root"),
                TimeSpan.FromSeconds(2));

            Assert.That(stack.HandleBack(Now).Action, Is.EqualTo(BackAction.ExitPrompt));
            Assert.That(stack.HandleBack(Now.AddSeconds(3)).Action, Is.EqualTo(BackAction.ExitPrompt));
        }
    }
}
