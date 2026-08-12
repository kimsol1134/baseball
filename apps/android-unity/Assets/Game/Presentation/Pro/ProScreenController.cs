using System;
using System.Collections.Generic;
using System.Linq;
using Baseball.Application.Commands;
using Baseball.Application.HighSchool;
using Baseball.Presentation.Common;
using Baseball.Presentation.Shell;
using UnityEngine.Accessibility;
using UnityEngine.UIElements;

namespace Baseball.Presentation.Pro
{
    public sealed class ProScreenController : BaseballScreenControllerBase
    {
        public ProScreenController(ShellRoute route) : base(route, "ProScreen") { }

        protected override void AddCustomContent(VisualElement host, BaseballScreenViewModel viewModel, IShellNavigator navigator)
        {
            bool directSetup = viewModel.Route == ShellRoute.ProContract &&
                viewModel.Actions.Any(action => string.Equals(
                    action.Id,
                    "start_direct_pro",
                    StringComparison.Ordinal));
            if (viewModel.Route != ShellRoute.ProWeek && viewModel.ChoiceGroups.Count == 0 && !directSetup)
            {
                host.style.display = DisplayStyle.None;
                return;
            }
            host.style.display = DisplayStyle.Flex;
            if (directSetup) AddDirectProSetup(host, navigator);
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

        private static void AddDirectProSetup(VisualElement host, IShellNavigator navigator)
        {
            IBaseballSetupDraft draft = navigator as IBaseballSetupDraft;
            if (draft == null) return;
            IBaseballVisualAssetLoader artworkLoader =
                (navigator as IBaseballVisualAssets)?.VisualAssetLoader;

            var section = new BaseballSection("프로 선수 설정", "screen-direct-pro-setup");
            var name = new TextField("선수 이름") { value = draft.PlayerName ?? string.Empty };
            BaseballAccessibilityMetadata nameAccessibility = BaseballAccessibility.Configure(
                name,
                "screen-direct-pro-player-name",
                "프로 선수 이름",
                AccessibilityRole.TextField,
                value: name.value,
                hint: "비워두면 선택한 유형의 추천 이름을 사용합니다.");
            name.RegisterValueChangedCallback(change =>
            {
                draft.SetPlayerName(change.newValue);
                string stored = draft.PlayerName ?? string.Empty;
                if (!string.Equals(stored, change.newValue, StringComparison.Ordinal))
                    name.SetValueWithoutNotify(stored);
                nameAccessibility.Value = string.IsNullOrWhiteSpace(stored)
                    ? "추천 이름 사용"
                    : stored;
            });
            section.Content.Add(name);

            var hint = new Label(NameHint(draft.SuggestedPlayerName));
            hint.AddToClassList("screen-data-row__detail");
            section.Content.Add(hint);
            BaseballAccessibilityMetadata hintAccessibility = BaseballAccessibility.Configure(
                hint,
                "screen-direct-pro-name-suggestion",
                hint.text,
                AccessibilityRole.StaticText);
            UpdateNameHint(hint, hintAccessibility, draft.SuggestedPlayerName);

            var presetPreview = new Label(PresetPreviewText(draft.PresetId));
            presetPreview.AddToClassList("screen-data-row__detail");
            section.Content.Add(presetPreview);
            BaseballAccessibilityMetadata previewAccessibility = BaseballAccessibility.Configure(
                presetPreview,
                "screen-direct-pro-preset-result-preview",
                presetPreview.text,
                AccessibilityRole.StaticText);
            UpdatePresetPreview(presetPreview, previewAccessibility, draft.PresetId);

            var cards = new List<ChoiceCard>();
            foreach (CareerChoiceReadModel option in HighSchoolSetupCatalog.Presets)
            {
                ChoiceCard card = null;
                card = new ChoiceCard(
                    option.Title,
                    Join(Join(option.Detail, option.EffectSummary),
                        BaseballVisualContentCatalog.PresetResultPreview(option.Payload)),
                    "screen-direct-pro-preset-" + option.Id,
                    () =>
                    {
                        draft.SetPresetId(option.Payload);
                        foreach (ChoiceCard value in cards)
                            value.SetSelected(ReferenceEquals(value, card));
                        UpdateNameHint(hint, hintAccessibility, draft.SuggestedPlayerName);
                        UpdatePresetPreview(presetPreview, previewAccessibility, option.Payload);
                        navigator.Announce(option.Title + " 유형을 골랐습니다.");
                    });
                card.SetSelected(string.Equals(draft.PresetId, option.Payload, StringComparison.Ordinal));
                card.SetEnabled(option.Enabled);
                if (!option.Enabled) card.tooltip = option.DisabledReason;
                cards.Add(card);
                section.Content.Add(AddressableContentImage.WrapChoice(
                    card,
                    BaseballVisualContentCatalog.SetupPreset(option.Payload),
                    option.Title + " 프로 투수 유형 삽화",
                    "screen-direct-pro-preset-art-" + option.Id,
                    artworkLoader));
            }
            host.Add(section);
        }

        private static void UpdatePresetPreview(
            Label label,
            BaseballAccessibilityMetadata accessibility,
            string presetId)
        {
            label.text = PresetPreviewText(presetId);
            accessibility.Label = label.text;
        }

        private static string PresetPreviewText(string presetId)
        {
            string preview = BaseballVisualContentCatalog.PresetResultPreview(presetId);
            return string.IsNullOrWhiteSpace(preview)
                ? "선택한 투수 유형의 능력 미리보기를 확인할 수 없습니다."
                : "선택 결과 미리보기 · " + preview;
        }

        private static void UpdateNameHint(
            Label label,
            BaseballAccessibilityMetadata accessibility,
            string suggestedName)
        {
            label.text = NameHint(suggestedName);
            accessibility.Label = label.text;
        }

        private static string NameHint(string suggestedName) =>
            "비워두면 추천 이름 ‘" +
            (string.IsNullOrWhiteSpace(suggestedName) ? "민서준" : suggestedName) +
            "’으로 시작합니다.";

        private static string Join(string detail, string effect)
        {
            if (string.IsNullOrWhiteSpace(effect)) return detail ?? string.Empty;
            return string.IsNullOrWhiteSpace(detail) ? effect : detail + " " + effect;
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
