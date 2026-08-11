using Baseball.Presentation.Common;
using Baseball.Presentation.Shell;
using UnityEngine.UIElements;

namespace Baseball.Presentation.Opening
{
    public sealed class OpeningScreenController : BaseballScreenControllerBase
    {
        public OpeningScreenController() : base(ShellRoute.Opening, "OpeningScreen") { }

        protected override void OnMounted(VisualElement screenRoot, BaseballScreenViewModel viewModel, IShellNavigator navigator)
        {
            VisualElement art = screenRoot.Q<VisualElement>("opening-art");
            if (art != null) BaseballAccessibility.HideDecoration(art);
        }
    }
}
