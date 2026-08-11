using Baseball.Presentation.Common;
using Baseball.Presentation.Shell;
using UnityEngine.UIElements;

namespace Baseball.Presentation.HighSchool
{
    public sealed class HighSchoolScreenController : BaseballScreenControllerBase
    {
        public HighSchoolScreenController(ShellRoute route) : base(route, "HighSchoolScreen") { }

        protected override void AddCustomContent(VisualElement host, BaseballScreenViewModel viewModel, IShellNavigator navigator)
        {
            bool hasChoices = viewModel.ChoiceGroups.Count > 0;
            if (!hasChoices)
            {
                host.style.display = DisplayStyle.None;
                return;
            }
            host.style.display = DisplayStyle.Flex;
            CareerChoiceGroupView.AddTo(
                host,
                viewModel,
                navigator,
                (element, group) => TrackContentExposure(
                    element,
                    "choice:" + group.Id,
                    ChoiceExposureInstance(group),
                    navigator));
        }

        private static string ChoiceExposureInstance(ScreenChoiceGroupViewModel group)
        {
            string instance = group.Id;
            foreach (ScreenChoiceOptionViewModel option in group.Choices)
                instance += "|" + option.Id + "|" + option.Title + "|" + option.IsEnabled;
            return instance;
        }
    }
}
