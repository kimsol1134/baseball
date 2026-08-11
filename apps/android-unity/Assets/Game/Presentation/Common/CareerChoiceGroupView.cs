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
            foreach (ScreenChoiceGroupViewModel group in viewModel.ChoiceGroups)
            {
                var section = new BaseballSection(group.Heading, "screen-choice-group-" + group.Id);
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
                        Detail(option),
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
                        });
                    bool selectedState = group.AllowsMultiple
                        ? draft.IsChoiceSelected(group.Id, option.Payload)
                        : string.Equals(selectedSingle, option.Payload, StringComparison.Ordinal);
                    card.SetSelected(selectedState);
                    card.SetEnabled(option.IsEnabled);
                    if (!option.IsEnabled) card.tooltip = option.DisabledReason;
                    cards.Add(card);
                    section.Content.Add(card);
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

        private static string Detail(ScreenChoiceOptionViewModel option)
        {
            if (string.IsNullOrWhiteSpace(option.EffectSummary)) return option.Detail;
            return string.IsNullOrWhiteSpace(option.Detail)
                ? option.EffectSummary
                : option.Detail + " " + option.EffectSummary;
        }
    }
}
