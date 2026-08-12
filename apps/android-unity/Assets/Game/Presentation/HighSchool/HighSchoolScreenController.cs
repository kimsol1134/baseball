using System;
using System.Linq;
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
            bool hasArtwork = TryContextArtwork(
                viewModel,
                out string address,
                out string label,
                out string stableId);
            if (!hasChoices && !hasArtwork)
            {
                host.style.display = DisplayStyle.None;
                return;
            }
            host.style.display = DisplayStyle.Flex;
            if (hasArtwork)
            {
                host.Add(new AddressableContentImage(
                    address,
                    label,
                    stableId,
                    (navigator as IBaseballVisualAssets)?.VisualAssetLoader));
            }
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

        private static bool TryContextArtwork(
            BaseballScreenViewModel viewModel,
            out string address,
            out string label,
            out string stableId)
        {
            address = string.Empty;
            label = string.Empty;
            stableId = "screen-highschool-context-art";
            if (viewModel == null) return false;

            ScreenSectionViewModel relationship = viewModel.Sections.FirstOrDefault(section =>
                string.Equals(section.Id, "hs-relationship-scene", StringComparison.Ordinal));
            if (relationship != null)
            {
                string speaker = relationship.Rows.FirstOrDefault(row =>
                    string.Equals(row.Id, "hs-relationship-speaker", StringComparison.Ordinal))?.Label;
                string category = relationship.Rows.FirstOrDefault(row =>
                    string.Equals(row.Id, "hs-relationship-category", StringComparison.Ordinal))?.Value;
                address = BaseballVisualContentCatalog.RelationshipArtwork(category, speaker);
                label = (string.IsNullOrWhiteSpace(speaker) ? "관계" : speaker) + " 장면 삽화";
                stableId = "screen-relationship-portrait";
                return BaseballVisualContentCatalog.IsLocalOnlyAddress(address);
            }

            ScreenSectionViewModel tournament = viewModel.Sections.FirstOrDefault(section =>
                string.Equals(section.Id, "hs-tournament", StringComparison.Ordinal));
            if (tournament != null)
            {
                string round = tournament.Rows.FirstOrDefault(row =>
                    string.Equals(row.Id, "hs-tournament-round", StringComparison.Ordinal))?.Value;
                string chapterValue = tournament.Rows.FirstOrDefault(row =>
                    string.Equals(row.Id, "hs-tournament-chapter", StringComparison.Ordinal))?.Value;
                int.TryParse(chapterValue, out int chapterNumber);
                address = BaseballVisualContentCatalog.TournamentBanner(chapterNumber);
                label = tournament.Heading + " " + (round ?? string.Empty) + " 대회 배너";
                stableId = "screen-highschool-tournament-banner";
                return BaseballVisualContentCatalog.IsLocalOnlyAddress(address);
            }

            if (viewModel.Route == ShellRoute.ImportantGame && viewModel.Sections.Any(section =>
                    string.Equals(section.Id, "hs-important-game-scenario", StringComparison.Ordinal)))
            {
                address = BaseballVisualContentCatalog.ImportantGameScene();
                label = "중요 경기 마운드 상황 삽화";
                stableId = "screen-importantgame-scene-art";
                return true;
            }
            return false;
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
