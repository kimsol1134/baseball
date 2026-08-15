using System;
using System.Linq;
using Baseball.Presentation.Common;
using Baseball.Presentation.Shell;
using UnityEngine;
using UnityEngine.UIElements;

namespace Baseball.Presentation.HighSchool
{
    public sealed class HighSchoolScreenController : BaseballScreenControllerBase
    {
        public HighSchoolScreenController(ShellRoute route) : base(route, "HighSchoolScreen") { }

        protected override void AddCustomContent(VisualElement host, BaseballScreenViewModel viewModel, IShellNavigator navigator)
        {
            if (viewModel.Route == ShellRoute.Prologue)
            {
                AddPrologueContent(host, viewModel, navigator);
                return;
            }
            if (viewModel.Route == ShellRoute.Relationship)
            {
                AddRelationshipContent(host, viewModel, navigator);
                return;
            }
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

        protected override bool UsesStandardSections(BaseballScreenViewModel viewModel) =>
            viewModel.Route != ShellRoute.Prologue && viewModel.Route != ShellRoute.Relationship;

        protected override void OnMounted(
            VisualElement screenRoot,
            BaseballScreenViewModel viewModel,
            IShellNavigator navigator)
        {
            if (viewModel.Route == ShellRoute.Training)
            {
                screenRoot.AddToClassList("highschool-screen--training");
                ReorderTrainingContent(screenRoot);
                return;
            }
            if (viewModel.Route == ShellRoute.HighSchoolOverview)
            {
                screenRoot.AddToClassList("highschool-screen--overview");
                ReorderOverviewContent(screenRoot);
                return;
            }
            if (viewModel.Route == ShellRoute.Relationship)
            {
                screenRoot.AddToClassList("highschool-screen--relationship");
                return;
            }
            if (viewModel.Route != ShellRoute.Prologue) return;
            screenRoot.AddToClassList("highschool-screen--prologue");
            if (HasSchoolChoices(viewModel)) return;
            VisualElement custom = screenRoot.Q<VisualElement>("screen-custom");
            VisualElement actions = screenRoot.Q<VisualElement>("screen-actions");
            VisualElement ability = custom?.Q<VisualElement>("prologue-ability-card");
            if (custom == null || actions == null || ability == null) return;
            actions.RemoveFromHierarchy();
            int abilityIndex = custom.IndexOf(ability);
            custom.Insert(Math.Max(0, abilityIndex), actions);
        }

        private void AddPrologueContent(
            VisualElement host,
            BaseballScreenViewModel viewModel,
            IShellNavigator navigator)
        {
            host.style.display = DisplayStyle.Flex;
            if (HasSchoolChoices(viewModel))
            {
                var guide = new BaseballCallout(
                    "학교를 고르는 기준",
                    BaseballCalloutTone.Information,
                    "screen-prologue-school-guide");
                guide.Content.Add(new Label(
                    "학교의 철학과 성장 강점만큼, 3년을 함께할 감독과 포수도 중요합니다."));
                guide.AddToClassList("prologue-school-guide");
                host.Add(guide);
                CareerChoiceGroupView.AddTo(
                    host,
                    viewModel,
                    navigator,
                    (element, group) => TrackContentExposure(
                        element,
                        "choice:" + group.Id,
                        ChoiceExposureInstance(group),
                        navigator));
                return;
            }

            foreach (ScreenSectionViewModel section in viewModel.Sections.Where(section =>
                         string.Equals(section.Id, "player-legacy-letter", StringComparison.Ordinal) ||
                         string.Equals(section.Id, "hs-career-wind", StringComparison.Ordinal)))
            {
                host.Add(CreatePrologueNarrative(section));
            }

            ScreenSectionViewModel ability = viewModel.Sections.FirstOrDefault(section =>
                string.Equals(section.Id, "ability", StringComparison.Ordinal));
            if (ability == null) return;
            var abilityCard = new BaseballSection("지금의 선수", "prologue-ability-card")
            {
                name = "prologue-ability-card"
            };
            abilityCard.AddToClassList("prologue-ability-card");
            foreach (ScreenRowViewModel row in ability.Rows)
            {
                var rating = new VisualElement();
                rating.AddToClassList("prologue-ability-row");
                var heading = new VisualElement();
                heading.AddToClassList("prologue-ability-row__heading");
                var label = new Label(row.Label);
                label.AddToClassList("prologue-ability-row__label");
                var value = new Label(row.Value);
                value.AddToClassList("prologue-ability-row__value");
                heading.Add(label);
                heading.Add(value);
                rating.Add(heading);
                var gauge = new AbilityGauge(row.Label, "prologue-ability-" + row.Id);
                if (float.TryParse(row.Value, out float numeric)) gauge.SetValue(numeric, 100f);
                rating.Add(gauge);
                if (!string.IsNullOrWhiteSpace(row.Detail))
                {
                    var detail = new Label(row.Detail);
                    detail.AddToClassList("prologue-ability-row__detail");
                    rating.Add(detail);
                }
                abilityCard.Content.Add(rating);
            }
            var explanation = new Label("수치는 지금의 실력이고, 재능 등급은 앞으로 성장할 여지를 나타냅니다.");
            explanation.AddToClassList("prologue-ability-explanation");
            abilityCard.Content.Add(explanation);
            host.Add(abilityCard);
        }

        private void AddRelationshipContent(
            VisualElement host,
            BaseballScreenViewModel viewModel,
            IShellNavigator navigator)
        {
            host.style.display = DisplayStyle.Flex;
            ScreenSectionViewModel scene = viewModel.Sections.FirstOrDefault(section =>
                string.Equals(section.Id, "hs-relationship-scene", StringComparison.Ordinal));
            if (scene != null)
            {
                ScreenRowViewModel speaker = scene.Rows.FirstOrDefault(row =>
                    string.Equals(row.Id, "hs-relationship-speaker", StringComparison.Ordinal));
                ScreenRowViewModel category = scene.Rows.FirstOrDefault(row =>
                    string.Equals(row.Id, "hs-relationship-category", StringComparison.Ordinal));
                ScreenRowViewModel trust = scene.Rows.FirstOrDefault(row =>
                    string.Equals(row.Id, "hs-relationship-trust", StringComparison.Ordinal));
                var card = new BaseballSection(scene.Heading, "screen-relationship-scene-card");
                card.AddToClassList("relationship-scene-card");

                var identity = new VisualElement();
                identity.AddToClassList("relationship-scene-card__identity");
                string artwork = BaseballVisualContentCatalog.RelationshipArtwork(
                    category?.Value,
                    speaker?.Label);
                if (BaseballVisualContentCatalog.IsLocalOnlyAddress(artwork))
                {
                    var image = new AddressableContentImage(
                        artwork,
                        (speaker?.Label ?? "관계 인물") + " 장면 삽화",
                        "screen-relationship-scene-art",
                        (navigator as IBaseballVisualAssets)?.VisualAssetLoader,
                        compact: true);
                    image.AddToClassList("relationship-scene-card__art");
                    identity.Add(image);
                }
                var speakerCopy = new VisualElement();
                speakerCopy.AddToClassList("relationship-scene-card__speaker-copy");
                var role = new Label(RelationshipCategoryTitle(category?.Value));
                role.AddToClassList("relationship-scene-card__role");
                var name = new Label(string.IsNullOrWhiteSpace(speaker?.Label) ? "상대" : speaker.Label);
                name.AddToClassList("relationship-scene-card__name");
                speakerCopy.Add(role);
                speakerCopy.Add(name);
                identity.Add(speakerCopy);
                if (!string.IsNullOrWhiteSpace(trust?.Value))
                {
                    var trustBadge = new Label(trust.Value);
                    trustBadge.AddToClassList("relationship-scene-card__trust");
                    identity.Add(trustBadge);
                }
                card.Content.Add(identity);

                string visibleLine = !string.IsNullOrWhiteSpace(speaker?.Value)
                    ? speaker.Value
                    : speaker?.Detail;
                if (!string.IsNullOrWhiteSpace(visibleLine))
                {
                    var quote = new Label(visibleLine);
                    quote.AddToClassList("relationship-scene-card__quote");
                    card.Content.Add(quote);
                }
                BaseballAccessibility.Configure(
                    card,
                    "screen-relationship-scene-accessibility",
                    string.Join(". ", new[]
                    {
                        speaker?.Label,
                        scene.Heading,
                        visibleLine,
                        speaker?.Detail
                    }.Where(value => !string.IsNullOrWhiteSpace(value))),
                    UnityEngine.Accessibility.AccessibilityRole.StaticText,
                    focusable: true);
                host.Add(card);
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

        private static string RelationshipCategoryTitle(string category)
        {
            switch ((category ?? string.Empty).Trim().ToLowerInvariant())
            {
                case "coach": return "감독";
                case "catcher": return "포수";
                case "rival": return "숙적";
                case "health": return "몸 상태";
                case "media": return "취재";
                case "fan": return "팬";
                case "team": return "팀";
                case "life": return "가족";
                case "growth": return "훈련";
                default: return "사람들";
            }
        }

        private static VisualElement CreatePrologueNarrative(ScreenSectionViewModel section)
        {
            var card = new BaseballCallout(
                section.Heading,
                string.Equals(section.Id, "player-legacy-letter", StringComparison.Ordinal)
                    ? BaseballCalloutTone.Milestone
                    : BaseballCalloutTone.Information,
                "prologue-narrative-" + section.Id);
            card.AddToClassList("prologue-narrative-card");
            foreach (ScreenRowViewModel row in section.Rows)
            {
                var copy = new VisualElement();
                copy.AddToClassList("prologue-narrative-copy");
                var title = new Label(row.Label);
                title.AddToClassList("prologue-narrative-copy__title");
                copy.Add(title);
                if (!string.IsNullOrWhiteSpace(row.Value))
                {
                    var body = new Label(row.Value);
                    body.AddToClassList("prologue-narrative-copy__body");
                    copy.Add(body);
                }
                if (!string.IsNullOrWhiteSpace(row.Detail))
                {
                    var detail = new Label(row.Detail);
                    detail.AddToClassList("prologue-narrative-copy__detail");
                    copy.Add(detail);
                }
                card.Content.Add(copy);
            }
            return card;
        }

        private static bool HasSchoolChoices(BaseballScreenViewModel viewModel) =>
            viewModel?.ChoiceGroups?.Any(group =>
                string.Equals(group.Id, "school", StringComparison.Ordinal)) == true;

        private static void ReorderTrainingContent(VisualElement screenRoot)
        {
            VisualElement custom = screenRoot.Q<VisualElement>("screen-custom");
            VisualElement sections = screenRoot.Q<VisualElement>("screen-sections");
            if (custom == null || sections == null) return;

            VisualElement result = sections.Q<VisualElement>(className: "screen-section--hs-last-training") ??
                sections.Q<VisualElement>(className: "screen-section--hs-last-training-block");
            if (result != null)
            {
                result.RemoveFromHierarchy();
                custom.Insert(0, result);
            }

            VisualElement outlook = sections.Q<VisualElement>(className: "screen-section--hs-training-outlook");
            if (outlook != null)
            {
                outlook.RemoveFromHierarchy();
                custom.Add(outlook);
            }
        }

        private static void ReorderOverviewContent(VisualElement screenRoot)
        {
            VisualElement sections = screenRoot.Q<VisualElement>("screen-sections");
            if (sections == null) return;
            string[] order =
            {
                "hs-overview-metrics",
                "hs-chapter-progress",
                "run-pledge",
                "hs-career-wind",
                "next",
                "hs-tournament",
                "record",
                "hs-game-lines",
                "hs-prospects",
                "hs-news"
            };
            for (int index = order.Length - 1; index >= 0; index--)
            {
                VisualElement section = sections.Q<VisualElement>(
                    className: "screen-section--" + order[index]);
                if (section == null) continue;
                section.RemoveFromHierarchy();
                sections.Insert(0, section);
            }
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
