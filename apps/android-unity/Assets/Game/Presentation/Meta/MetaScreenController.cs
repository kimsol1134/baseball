using Baseball.Presentation.Common;
using Baseball.Presentation.Shell;
using UnityEngine.UIElements;

namespace Baseball.Presentation.Meta
{
    public sealed class MetaScreenController : BaseballScreenControllerBase
    {
        public MetaScreenController(ShellRoute route) : base(route, "MetaScreen") { }

        protected override void AddCustomContent(VisualElement host, BaseballScreenViewModel viewModel, IShellNavigator navigator)
        {
            host.style.display = DisplayStyle.Flex;
            var choice = new SegmentedChoice("오늘과 이번 주", "screen-meta-segment", selected =>
            {
                navigator.Navigate(selected == "screen-meta-daily" ? ShellRoute.Daily : ShellRoute.Weekly);
            });
            choice.AddOption("screen-meta-daily", "오늘");
            choice.AddOption("screen-meta-weekly", "이번 주");
            choice.Select(viewModel.Route == ShellRoute.Daily ? "screen-meta-daily" : "screen-meta-weekly");
            host.Add(choice);
        }
    }
}
