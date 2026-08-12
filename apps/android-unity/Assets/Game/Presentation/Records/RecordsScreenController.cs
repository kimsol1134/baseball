using System;
using System.Collections.Generic;
using System.Linq;
using Baseball.Presentation.Common;
using Baseball.Presentation.Shell;
using UnityEngine.Accessibility;
using UnityEngine.UIElements;

namespace Baseball.Presentation.Records
{
    public sealed class RecordsScreenController : BaseballScreenControllerBase
    {
        private const string ArchiveSectionPrefix = "archive-life-";
        public RecordsScreenController(ShellRoute route) : base(route, "RecordsScreen") { }

        protected override bool UsesStandardSections(BaseballScreenViewModel viewModel) =>
            viewModel.Route != ShellRoute.LifeArchive;

        protected override void AddCustomContent(VisualElement host, BaseballScreenViewModel viewModel, IShellNavigator navigator)
        {
            if (viewModel.Route == ShellRoute.LifeCard)
            {
                BuildLifeCard(host, viewModel, navigator);
                return;
            }
            if (viewModel.Route == ShellRoute.LifeArchive)
            {
                BuildLifeArchive(host, viewModel, navigator);
                return;
            }
            // Records/league/archive rows are projected from the authoritative save into the
            // common scrollable sections. No fabricated scoreboard is shown when data is absent.
            host.style.display = DisplayStyle.None;
        }

        protected override void OnMounted(
            VisualElement screenRoot,
            BaseballScreenViewModel viewModel,
            IShellNavigator navigator)
        {
            if (viewModel.Route != ShellRoute.LifeCard) return;
            VisualElement hero = screenRoot.Q<VisualElement>(className: "screen-hero");
            VisualElement sections = screenRoot.Q<VisualElement>("screen-sections");
            if (hero != null) hero.style.display = DisplayStyle.None;
            if (sections != null) sections.style.display = DisplayStyle.None;
        }

        private void BuildLifeArchive(
            VisualElement host,
            BaseballScreenViewModel viewModel,
            IShellNavigator navigator)
        {
            host.style.display = DisplayStyle.Flex;
            ScreenSectionViewModel overview = viewModel.Sections.FirstOrDefault(section =>
                string.Equals(section.Id, "archive-overview", StringComparison.Ordinal));
            List<ScreenSectionViewModel> lives = viewModel.Sections
                .Where(section => section.Id.StartsWith(ArchiveSectionPrefix, StringComparison.Ordinal))
                .ToList();

            if (overview != null) host.Add(BuildArchiveSection(overview, viewModel.Route));
            if (lives.Count == 0)
            {
                ScreenSectionViewModel empty = viewModel.Sections.FirstOrDefault();
                if (empty != null && !ReferenceEquals(empty, overview))
                    host.Add(BuildArchiveSection(empty, viewModel.Route));
                return;
            }

            IBaseballCareerChoiceDraft draft = navigator as IBaseballCareerChoiceDraft;
            string selectedLife = draft?.GetChoice("archive_life");
            int selectedIndex = lives.FindIndex(section => string.Equals(
                LifeNumber(section), selectedLife, StringComparison.Ordinal));
            if (selectedIndex < 0) selectedIndex = 0;

            var listSection = new BaseballSection(
                "회차별 선수",
                StableId(viewModel.Route, "archive-list-section"));
            var list = new ListView
            {
                itemsSource = lives,
                makeItem = () => new ArchiveLifeListItem(),
                bindItem = (element, index) =>
                {
                    ScreenSectionViewModel section = lives[index];
                    string lifeNumber = LifeNumber(section);
                    ((ArchiveLifeListItem)element).Bind(
                        section,
                        string.Equals(lifeNumber, LifeNumber(lives[selectedIndex]), StringComparison.Ordinal),
                        () =>
                        {
                            if (draft == null) return;
                            draft.SetChoice("archive_life", lifeNumber);
                            navigator.Announce(section.Heading + " 기록을 펼쳤습니다.");
                        });
                },
                name = StableId(viewModel.Route, "archive-list"),
                virtualizationMethod = CollectionVirtualizationMethod.DynamicHeight,
                selectionType = SelectionType.None,
            };
            list.AddToClassList("life-archive-list");
            BaseballAccessibility.Configure(
                list,
                list.name,
                "완주한 선수 " + lives.Count + "명의 가상화 목록",
                AccessibilityRole.StaticText,
                focusable: false);
            listSection.Content.Add(list);
            host.Add(listSection);

            ScreenSectionViewModel selected = lives[selectedIndex];
            if (!string.IsNullOrWhiteSpace(viewModel.PlayerPortraitAddress))
            {
                host.Add(new AddressableContentImage(
                    viewModel.PlayerPortraitAddress,
                    viewModel.PlayerPortraitLabel,
                    "screen-lifearchive-selected-player-portrait",
                    (navigator as IBaseballVisualAssets)?.VisualAssetLoader,
                    compact: true));
            }
            VisualElement detail = BuildArchiveSection(selected, viewModel.Route);
            detail.AddToClassList("life-archive-detail");
            host.Add(detail);
            TrackContentExposure(
                detail,
                selected.Id,
                SectionExposureInstance(selected),
                navigator);
        }

        private static VisualElement BuildArchiveSection(ScreenSectionViewModel section, ShellRoute route)
        {
            var container = new BaseballSection(
                section.Heading,
                StableId(route, "section-" + section.Id));
            foreach (ScreenRowViewModel row in section.Rows)
            {
                var root = new VisualElement();
                root.AddToClassList("screen-data-row");
                var copy = new VisualElement();
                copy.AddToClassList("screen-data-row__copy");
                var label = new Label(row.Label);
                label.AddToClassList("screen-data-row__label");
                copy.Add(label);
                if (!string.IsNullOrWhiteSpace(row.Detail))
                {
                    var detail = new Label(row.Detail);
                    detail.AddToClassList("screen-data-row__detail");
                    copy.Add(detail);
                }
                root.Add(copy);
                if (!string.IsNullOrWhiteSpace(row.Value))
                {
                    var value = new Label(row.Value);
                    value.AddToClassList("screen-data-row__value");
                    root.Add(value);
                }
                BaseballAccessibility.Configure(
                    root,
                    StableId(route, "row-" + row.Id),
                    RowSummary(row),
                    AccessibilityRole.StaticText,
                    focusable: true);
                container.Content.Add(root);
            }
            return container;
        }

        private static string LifeNumber(ScreenSectionViewModel section) =>
            section.Id.Substring(ArchiveSectionPrefix.Length);

        private static string RowSummary(ScreenRowViewModel row)
        {
            string result = row.Label;
            if (!string.IsNullOrWhiteSpace(row.Value)) result += ", " + row.Value;
            if (!string.IsNullOrWhiteSpace(row.Detail)) result += ". " + row.Detail;
            return result;
        }

        private sealed class ArchiveLifeListItem : VisualElement
        {
            private readonly Button _button;
            private readonly Label _title;
            private readonly Label _summary;
            private Action _activate;

            public ArchiveLifeListItem()
            {
                AddToClassList("life-archive-list-item");
                _button = new Button(() => _activate?.Invoke());
                _button.AddToClassList("life-archive-list-item__button");
                _title = new Label();
                _title.AddToClassList("life-archive-list-item__title");
                _summary = new Label();
                _summary.AddToClassList("life-archive-list-item__summary");
                _button.Add(_title);
                _button.Add(_summary);
                Add(_button);
            }

            public void Bind(ScreenSectionViewModel section, bool selected, Action activate)
            {
                _activate = activate;
                ScreenRowViewModel summary = section.Rows.FirstOrDefault();
                _title.text = section.Heading;
                _summary.text = summary == null
                    ? "저장된 선수 기록"
                    : string.Join(" · ", new[] { summary.Value, summary.Detail }
                        .Where(value => !string.IsNullOrWhiteSpace(value)));
                _button.EnableInClassList("is-selected", selected);
                _button.name = "screen-lifearchive-life-" + LifeNumber(section);
                BaseballAccessibility.Configure(
                    _button,
                    _button.name,
                    section.Heading + ". " + _summary.text + (selected ? ". 펼침" : ". 접힘"),
                    AccessibilityRole.Button,
                    hint: selected ? "현재 상세 기록입니다." : "두 번 탭해 이 회차 기록을 펼칩니다.",
                    focusable: true);
            }
        }

        private static void BuildLifeCard(
            VisualElement host,
            BaseballScreenViewModel viewModel,
            IShellNavigator navigator)
        {
            host.style.display = DisplayStyle.Flex;
            var card = new VisualElement { name = "life-card-capture" };
            card.AddToClassList("life-card-capture");
            var artHost = new VisualElement { name = "screen-key-art-host" };
            artHost.AddToClassList("life-card-capture__backdrop");
            card.Add(artHost);

            var content = new VisualElement();
            content.AddToClassList("life-card-capture__content");
            if (!string.IsNullOrWhiteSpace(viewModel.PlayerPortraitAddress))
            {
                var portrait = new AddressableContentImage(
                    viewModel.PlayerPortraitAddress,
                    viewModel.PlayerPortraitLabel,
                    "screen-lifecard-player-portrait",
                    (navigator as IBaseballVisualAssets)?.VisualAssetLoader,
                    compact: true);
                portrait.AddToClassList("life-card-capture__portrait");
                content.Add(portrait);
            }
            var eyebrow = new Label("회차 선수 카드");
            eyebrow.AddToClassList("baseball-eyebrow");
            content.Add(eyebrow);
            var title = new Label(viewModel.Title);
            title.AddToClassList("life-card-capture__title");
            content.Add(title);
            if (!string.IsNullOrWhiteSpace(viewModel.Lead))
            {
                var lead = new Label(viewModel.Lead);
                lead.AddToClassList("life-card-capture__lead");
                content.Add(lead);
            }

            var sections = new VisualElement();
            sections.AddToClassList("life-card-capture__sections");
            foreach (ScreenSectionViewModel section in viewModel.Sections)
            {
                var sectionRoot = new VisualElement();
                sectionRoot.AddToClassList("life-card-capture__section");
                var heading = new Label(section.Heading);
                heading.AddToClassList("life-card-capture__section-title");
                sectionRoot.Add(heading);
                var rows = new VisualElement();
                rows.AddToClassList("life-card-capture__rows");
                foreach (ScreenRowViewModel row in section.Rows)
                {
                    var rowRoot = new VisualElement();
                    rowRoot.AddToClassList("life-card-capture__row");
                    if (IsNarrativeRow(row.Id))
                        rowRoot.AddToClassList("life-card-capture__row--narrative");
                    var label = new Label(row.Label);
                    label.AddToClassList("life-card-capture__row-label");
                    rowRoot.Add(label);
                    if (!string.IsNullOrWhiteSpace(row.Value))
                    {
                        var value = new Label(row.Value);
                        value.AddToClassList("life-card-capture__row-value");
                        rowRoot.Add(value);
                    }
                    if (!string.IsNullOrWhiteSpace(row.Detail))
                    {
                        var detail = new Label(row.Detail);
                        detail.AddToClassList("life-card-capture__row-detail");
                        rowRoot.Add(detail);
                    }
                    BaseballAccessibility.Configure(
                        rowRoot,
                        StableId(viewModel.Route, "card-row-" + row.Id),
                        RowSummary(row),
                        AccessibilityRole.StaticText,
                        focusable: true);
                    rows.Add(rowRoot);
                }
                sectionRoot.Add(rows);
                sections.Add(sectionRoot);
            }
            content.Add(sections);
            var footer = new Label("야구 못하면 또 환생함");
            footer.AddToClassList("life-card-capture__footer");
            content.Add(footer);
            card.Add(content);
            host.Add(card);
            BaseballAccessibility.Configure(
                card,
                "screen-lifecard-card",
                viewModel.Title + ". 저장된 선수 기록 카드",
                AccessibilityRole.Image,
                focusable: true);
        }

        private static bool IsNarrativeRow(string rowId)
        {
            return rowId != null &&
                (rowId.Contains("chronicle") || rowId.Contains("signature") ||
                 rowId.Contains("people") || rowId.Contains("challenge") ||
                 rowId.Contains("player"));
        }
    }
}
