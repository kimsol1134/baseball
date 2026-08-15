using System;
using System.Collections.Generic;
using Baseball.Presentation.Shell;
using UnityEngine.UIElements;

namespace Baseball.Presentation.Common
{
    public static class CareerChoiceGroupView
    {
        public static void AddTo(
            VisualElement host,
            BaseballScreenViewModel viewModel,
            IShellNavigator navigator,
            Action<VisualElement, ScreenChoiceGroupViewModel> onGroupAdded = null)
        {
            IBaseballCareerChoiceDraft draft = navigator as IBaseballCareerChoiceDraft;
            if (draft == null || viewModel?.ChoiceGroups == null) return;
            IBaseballVisualAssetLoader loader =
                (navigator as IBaseballVisualAssets)?.VisualAssetLoader;
            foreach (ScreenChoiceGroupViewModel group in viewModel.ChoiceGroups)
            {
                var section = new BaseballSection(group.Heading, "screen-choice-group-" + group.Id);
                section.AddToClassList("baseball-choice-group--" + group.Id.Replace('_', '-'));
                if (!string.IsNullOrWhiteSpace(group.Detail))
                {
                    var detail = new Label(group.Detail);
                    detail.AddToClassList("screen-data-row__detail");
                    section.Content.Add(detail);
                }
                var cards = new List<ChoiceCard>();
                string selectedSingle = draft.GetChoice(group.Id);
                for (var index = 0; index < group.Choices.Count; index++)
                {
                    ScreenChoiceOptionViewModel option = group.Choices[index];
                    ChoiceCard card = null;
                    card = new ChoiceCard(
                        option.Title,
                        Detail(group.Id, option),
                        "screen-choice-" + group.Id + "-" + option.Id,
                        () =>
                        {
                            if (group.AllowsMultiple)
                            {
                                draft.ToggleChoice(group.Id, option.Payload, group.MaximumSelections);
                                bool selected = draft.IsChoiceSelected(group.Id, option.Payload);
                                card.SetSelected(selected);
                                navigator.Announce(option.Title + (selected ? " 선택" : " 선택 해제"));
                                return;
                            }
                            draft.SetChoice(group.Id, option.Payload);
                            foreach (ChoiceCard value in cards) value.SetSelected(ReferenceEquals(value, card));
                            navigator.Announce(option.Title + " 선택을 확정했습니다.");
                        },
                        showDescription: !string.Equals(
                            group.Id,
                            "relationship",
                            StringComparison.Ordinal));
                    bool selectedState = group.AllowsMultiple
                        ? draft.IsChoiceSelected(group.Id, option.Payload)
                        : string.Equals(selectedSingle, option.Payload, StringComparison.Ordinal);
                    card.SetSelected(selectedState);
                    card.SetEnabled(option.IsEnabled);
                    if (!option.IsEnabled) card.tooltip = option.DisabledReason;
                    cards.Add(card);
                    VisualElement choiceElement = !string.IsNullOrWhiteSpace(option.SecondaryArtworkAddress)
                        ? AddressableContentImage.WrapChoiceGallery(
                            card,
                            option.ArtworkAddress,
                            option.Title + " 감독 초상",
                            option.SecondaryArtworkAddress,
                            option.Title + " 포수 초상",
                            "screen-choice-art-" + group.Id + "-" + option.Id,
                            loader)
                        : string.IsNullOrWhiteSpace(option.ArtworkAddress)
                            ? (VisualElement)card
                            : AddressableContentImage.WrapChoice(
                            card,
                            option.ArtworkAddress,
                            option.Title + " 선택지 삽화",
                            "screen-choice-art-" + group.Id + "-" + option.Id,
                            loader);
                    choiceElement.AddToClassList("baseball-visual-choice--" + group.Id.Replace('_', '-'));
                    section.Content.Add(choiceElement);
                }
                if (group.AllowsMultiple)
                {
                    var remaining = new Label(string.Empty);
                    remaining.text = "최대 " + group.MaximumSelections + "개 선택";
                    remaining.AddToClassList("screen-data-row__detail");
                    section.Content.Add(remaining);
                }
                host.Add(section);
                onGroupAdded?.Invoke(section, group);
            }
        }

        private static string Detail(string groupId, ScreenChoiceOptionViewModel option)
        {
            if (string.Equals(groupId, "school", StringComparison.Ordinal))
            {
                string[] parts = (option.Detail ?? string.Empty)
                    .Split(new[] { " · " }, StringSplitOptions.RemoveEmptyEntries);
                string philosophy = parts.Length > 0 ? parts[0] : option.Detail;
                string people = parts.Length > 1
                    ? "3년을 함께할 사람 · " + string.Join(" · ", parts, 1, parts.Length - 1)
                    : string.Empty;
                string result = philosophy ?? string.Empty;
                if (!string.IsNullOrWhiteSpace(option.EffectSummary))
                    result += (result.Length == 0 ? string.Empty : "\n") + option.EffectSummary;
                if (!string.IsNullOrWhiteSpace(people))
                    result += (result.Length == 0 ? string.Empty : "\n") + people;
                return result;
            }
            if (string.IsNullOrWhiteSpace(option.EffectSummary)) return option.Detail;
            return string.IsNullOrWhiteSpace(option.Detail)
                ? option.EffectSummary
                : option.Detail + " " + option.EffectSummary;
        }
    }
}
