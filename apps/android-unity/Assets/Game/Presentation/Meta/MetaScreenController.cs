using Baseball.Presentation.Shell;
using UnityEngine.UIElements;

namespace Baseball.Presentation.Meta
{
    public sealed class MetaScreenController : BaseballScreenControllerBase
    {
        public MetaScreenController(ShellRoute route) : base(route, "MetaScreen") { }

        protected override void AddCustomContent(VisualElement host, BaseballScreenViewModel viewModel, IShellNavigator navigator)
        {
            // The retired daily route remains decode-only for old links. No product surface may
            // offer a new entry point; the weekly screen renders its saved board directly.
            host.style.display = DisplayStyle.None;
        }
    }
}
