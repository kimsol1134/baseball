using System.Collections.Generic;
using System.Linq;
using Baseball.Application.Commands;
using Baseball.Application.HighSchool;
using Baseball.Presentation.Common;
using Baseball.Presentation.Shell;
using UnityEngine.Accessibility;
using UnityEngine.UIElements;

namespace Baseball.Presentation.Setup
{
    public sealed class SetupScreenController : BaseballScreenControllerBase
    {
        public SetupScreenController() : base(ShellRoute.Setup, "SetupScreen") { }

        protected override void AddCustomContent(VisualElement host, BaseballScreenViewModel viewModel, IShellNavigator navigator)
        {
            host.style.display = DisplayStyle.Flex;
            host.AddToClassList("screen-control-stack");
            IBaseballSetupDraft draft = navigator as IBaseballSetupDraft;
            IBaseballVisualAssetLoader artworkLoader =
                (navigator as IBaseballVisualAssets)?.VisualAssetLoader;
            var name = new TextField("선수 이름") { value = draft?.PlayerName ?? string.Empty };
            name.AddToClassList("setup-name-field");
            BaseballAccessibilityMetadata nameAccessibility = BaseballAccessibility.Configure(
                name,
                "screen-setup-player-name",
                "선수 이름",
                AccessibilityRole.TextField,
                value: name.value,
                hint: "비워두면 선택한 유형의 추천 이름 " + (draft?.SuggestedPlayerName ?? "민서준") + "을 사용합니다.");
            name.RegisterValueChangedCallback(change =>
            {
                draft?.SetPlayerName(change.newValue);
                string stored = draft?.PlayerName ?? change.newValue;
                if (stored != change.newValue)
                {
                    name.SetValueWithoutNotify(stored);
                    if ((change.newValue ?? string.Empty).Trim().Length > SetupPlayerNamePolicy.MaximumLength)
                        navigator.Announce("선수 이름은 12자까지 입력할 수 있습니다.");
                }
                nameAccessibility.Value = string.IsNullOrWhiteSpace(stored)
                    ? "추천 이름 사용"
                    : stored;
            });
            host.Add(name);
            var suggestedName = new Label(
                "비워두면 선택한 유형의 추천 이름 ‘" + (draft?.SuggestedPlayerName ?? "민서준") + "’으로 시작합니다.");
            suggestedName.AddToClassList("screen-data-row__detail");
            BaseballAccessibilityMetadata suggestionAccessibility = BaseballAccessibility.Configure(
                suggestedName,
                "screen-setup-player-name-suggestion",
                suggestedName.text,
                AccessibilityRole.StaticText);
            host.Add(suggestedName);

            host.Add(ChoiceHeading("시작 지역", "중학교 마지막 대회를 치른 지역입니다. 이 지역의 네 고교가 손을 내밉니다."));
            var regionCards = new List<ChoiceCard>();
            string selectedRegion = string.IsNullOrWhiteSpace(draft?.Region) ? "서울" : draft.Region;
            for (var index = 0; index < HighSchoolSetupCatalog.Regions.Count; index++)
            {
                CareerChoiceReadModel option = HighSchoolSetupCatalog.Regions[index];
                ChoiceCard card = null;
                card = new ChoiceCard(option.Title, option.Detail, "screen-setup-region-" + index.ToString("00"), () =>
                {
                    selectedRegion = option.Payload;
                    draft?.SetRegion(option.Payload);
                    foreach (ChoiceCard value in regionCards) value.SetSelected(ReferenceEquals(value, card));
                    navigator.Announce(option.Title + " 지역을 골랐습니다.");
                });
                card.SetSelected(option.Payload == selectedRegion);
                card.SetEnabled(option.Enabled);
                if (!option.Enabled) card.tooltip = option.DisabledReason;
                regionCards.Add(card);
                host.Add(AddressableContentImage.WrapChoice(
                    card,
                    BaseballVisualContentCatalog.SetupRegion(option.Payload),
                    option.Title + " 지역 야구 분위기 삽화",
                    "screen-setup-region-art-" + index.ToString("00"),
                    artworkLoader));
            }

            host.Add(ChoiceHeading("투수 유형", "시작 능력과 구종 구성만 정합니다. 이후 성장으로 달라집니다."));
            var presetCards = new List<ChoiceCard>();
            string selectedPreset = string.IsNullOrWhiteSpace(draft?.PresetId) ? "power_prospect" : draft.PresetId;
            var presetPreview = new Label(PresetPreviewText(selectedPreset));
            presetPreview.AddToClassList("screen-data-row__detail");
            BaseballAccessibilityMetadata presetPreviewAccessibility = BaseballAccessibility.Configure(
                presetPreview,
                "screen-setup-preset-result-preview",
                presetPreview.text,
                AccessibilityRole.StaticText);
            UpdatePresetPreview(presetPreview, presetPreviewAccessibility, selectedPreset);
            foreach (CareerChoiceReadModel option in HighSchoolSetupCatalog.Presets)
            {
                ChoiceCard card = null;
                card = new ChoiceCard(option.Title, option.Detail + " " + option.EffectSummary + " " +
                    BaseballVisualContentCatalog.PresetResultPreview(option.Payload), "screen-setup-preset-" + option.Id, () =>
                {
                    selectedPreset = option.Payload;
                    draft?.SetPresetId(option.Payload);
                    suggestedName.text = "비워두면 선택한 유형의 추천 이름 ‘" +
                        (draft?.SuggestedPlayerName ?? "민서준") + "’으로 시작합니다.";
                    suggestionAccessibility.Label = suggestedName.text;
                    nameAccessibility.Hint = "비워두면 선택한 유형의 추천 이름 " +
                        (draft?.SuggestedPlayerName ?? "민서준") + "을 사용합니다.";
                    UpdatePresetPreview(presetPreview, presetPreviewAccessibility, option.Payload);
                    foreach (ChoiceCard value in presetCards) value.SetSelected(ReferenceEquals(value, card));
                    navigator.Announce(option.Title + " 유형을 골랐습니다.");
                });
                card.SetSelected(option.Payload == selectedPreset);
                card.SetEnabled(option.Enabled);
                if (!option.Enabled) card.tooltip = option.DisabledReason;
                presetCards.Add(card);
                host.Add(AddressableContentImage.WrapChoice(
                    card,
                    BaseballVisualContentCatalog.SetupPreset(option.Payload),
                    option.Title + " 투수 유형 삽화",
                    "screen-setup-preset-art-" + option.Id,
                    artworkLoader));
            }
            host.Add(presetPreview);

            IBaseballAdvancedSetupDraft advanced = navigator as IBaseballAdvancedSetupDraft;
            HighSchoolSetupReadModel options = advanced?.SetupOptions;
            if (options?.AdvancedOptionsVisible != true) return;

            host.Add(ChoiceHeading(
                "환생 설정",
                options.LifeNumber + "번째 인생 · 자동 계승 야구혼 " + options.AutomaticSoul +
                " · 배분 가능한 야구혼 " + options.SoulBalance));
            var seed = new TextField("시드 또는 도전 코드 (선택)") { value = advanced.SeedInput };
            BaseballAccessibilityMetadata seedAccessibility = BaseballAccessibility.Configure(
                seed,
                "screen-setup-seed",
                "시드 또는 도전 코드",
                AccessibilityRole.TextField,
                value: seed.value,
                hint: "숫자는 같은 조건의 인생을, 숫자-회차는 계승 없는 도전을 시작합니다.");
            seed.RegisterValueChangedCallback(change =>
            {
                seedAccessibility.Value = change.newValue;
                advanced.SetSeedInput(change.newValue);
            });
            host.Add(seed);
            if (!string.IsNullOrWhiteSpace(advanced.SeedValidationMessage))
            {
                var error = new Label(advanced.SeedValidationMessage);
                error.AddToClassList("screen-inline-error");
                BaseballAccessibility.Configure(
                    error,
                    "screen-setup-seed-error",
                    advanced.SeedValidationMessage,
                    AccessibilityRole.StaticText);
                host.Add(error);
            }

            bool challenge = HighSchoolSetupCatalog.TryParseSeedInput(
                advanced.SeedInput,
                out HighSchoolSeedSelection seedSelection,
                out _) && seedSelection?.IsChallenge == true;
            AddSingleChoice(host, navigator, "난이도", "한 가지를 선택합니다.", "difficulty",
                options.Difficulties, advanced.SetupDifficulty, advanced.SetSetupSingle, artworkLoader);
            if (challenge)
            {
                var notice = ChoiceHeading(
                    "기록 없는 도전",
                    seedSelection.ChallengeLifeNumber + "번째 선수와 같은 조건을 계승 도움 없이 시작합니다. 기록·야구혼·유산에는 반영되지 않습니다.");
                notice.AddToClassList("screen-section--warning");
                host.Add(notice);
                return;
            }

            AddMultiChoice(host, navigator, "카르마", "최대 2개 · 위험이 커질수록 다음 계승 보상이 커집니다.", "karma",
                options.Karmas, advanced.IsSetupSelected, advanced.ToggleSetupMulti);
            if (options.AutomaticSoul > 0)
            {
                AddSingleChoice(host, navigator, "자동 계승 야구혼 성향", "자동 계승 수치를 어느 성장축에 먼저 반영할지 고릅니다.", "soul_domain",
                    options.SoulDomains, advanced.SetupSoulDomain, advanced.SetSetupSingle, artworkLoader);
            }
            AddMultiChoice(host, navigator, "야구혼 강화", "보유 야구혼 안에서 여러 개를 선택할 수 있습니다.", "soul_boost",
                options.SoulBoosts, advanced.IsSetupSelected, advanced.ToggleSetupMulti);

            var memories = options.CarriedMemories.Select((value, index) => new CareerChoiceReadModel(
                "memory-" + index,
                MemoryTitle(value),
                "지난 인생에서 남긴 기억입니다.",
                payload: value)).ToArray();
            AddReadOnlyMemories(host, memories, artworkLoader);
            AddSingleChoice(host, navigator, "대표 유산", "현재 장착한 유산을 기본으로 사용하며, 다른 해금 유산을 고를 수 있습니다.", "signature",
                options.SignatureLegacies, advanced.SetupSignatureLegacy, advanced.SetSetupSingle, artworkLoader);
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

        private static void AddReadOnlyMemories(
            VisualElement host,
            IReadOnlyList<CareerChoiceReadModel> memories,
            IBaseballVisualAssetLoader artworkLoader)
        {
            if (memories == null || memories.Count == 0) return;
            var section = new BaseballSection("상속 기억");
            var detail = new Label("지난 인생에서 확정된 기억은 이번 인생에 자동으로 이어집니다.");
            detail.AddToClassList("screen-data-row__detail");
            section.Content.Add(detail);
            foreach (CareerChoiceReadModel memory in memories)
            {
                section.Content.Add(AddressableContentImage.WrapChoice(
                    ReadOnlyChoice(memory),
                    BaseballVisualContentCatalog.Memory(memory.Payload),
                    memory.Title + " 상속 기억 삽화",
                    "screen-setup-memory-art-" + memory.Id,
                    artworkLoader));
            }
            host.Add(section);
        }

        private static ChoiceCard ReadOnlyChoice(CareerChoiceReadModel memory)
        {
            var card = new ChoiceCard(
                memory.Title,
                "자동 계승 · " + memory.Detail,
                "screen-setup-memory-" + memory.Id,
                null);
            card.SetEnabled(false);
            return card;
        }

        private static void AddSingleChoice(
            VisualElement host,
            IShellNavigator navigator,
            string title,
            string detail,
            string group,
            IReadOnlyList<CareerChoiceReadModel> choices,
            string selected,
            System.Action<string, string> select,
            IBaseballVisualAssetLoader artworkLoader)
        {
            if (choices == null || choices.Count == 0) return;
            host.Add(ChoiceHeading(title, detail));
            var cards = new List<ChoiceCard>();
            foreach (CareerChoiceReadModel option in choices)
            {
                ChoiceCard card = null;
                card = new ChoiceCard(
                    option.Title,
                    JoinDetail(option),
                    "screen-setup-" + group + "-" + option.Id,
                    () =>
                    {
                        select(group, option.Payload);
                        foreach (ChoiceCard value in cards) value.SetSelected(ReferenceEquals(value, card));
                        navigator.Announce(option.Title + " 선택을 확정했습니다.");
                    });
                card.SetSelected(string.Equals(selected ?? string.Empty, option.Payload ?? string.Empty, System.StringComparison.Ordinal));
                card.SetEnabled(option.Enabled);
                if (!option.Enabled) card.tooltip = option.DisabledReason;
                cards.Add(card);
                string artwork = BaseballVisualContentCatalog.Choice(group, option.Payload);
                host.Add(string.IsNullOrWhiteSpace(artwork)
                    ? (VisualElement)card
                    : AddressableContentImage.WrapChoice(
                        card,
                        artwork,
                        option.Title + " 선택지 삽화",
                        "screen-setup-" + group + "-art-" + option.Id,
                        artworkLoader));
            }
        }

        private static void AddMultiChoice(
            VisualElement host,
            IShellNavigator navigator,
            string title,
            string detail,
            string group,
            IReadOnlyList<CareerChoiceReadModel> choices,
            System.Func<string, string, bool> selected,
            System.Action<string, string> toggle)
        {
            if (choices == null || choices.Count == 0) return;
            host.Add(ChoiceHeading(title, detail));
            foreach (CareerChoiceReadModel option in choices)
            {
                ChoiceCard card = null;
                card = new ChoiceCard(
                    option.Title,
                    JoinDetail(option),
                    "screen-setup-" + group + "-" + option.Id,
                    () =>
                    {
                        toggle(group, option.Payload);
                        bool isSelected = selected(group, option.Payload);
                        card.SetSelected(isSelected);
                        navigator.Announce(option.Title + (isSelected ? " 선택" : " 선택 해제"));
                    });
                card.SetSelected(selected(group, option.Payload));
                card.SetEnabled(option.Enabled);
                if (!option.Enabled) card.tooltip = option.DisabledReason;
                host.Add(card);
            }
        }

        private static string JoinDetail(CareerChoiceReadModel option)
        {
            if (string.IsNullOrWhiteSpace(option.EffectSummary)) return option.Detail;
            return string.IsNullOrWhiteSpace(option.Detail)
                ? option.EffectSummary
                : option.Detail + " " + option.EffectSummary;
        }

        private static string MemoryTitle(string value)
        {
            switch (value)
            {
                case "VelocityBlueprint": return "구속 설계도";
                case "FingertipMemory": return "손끝의 기억";
                case "CatcherNotebook": return "포수의 노트";
                case "RivalNotebook": return "라이벌 분석장";
                case "RecoveryRoutine": return "회복 루틴";
                case "PressureRehearsal": return "압박 예행연습";
                case "FirstPitchMap": return "초구 지도";
                case "TwoStrikeSequence": return "투 스트라이크 수싸움";
                case "FatigueDiary": return "피로 일지";
                case "MechanicsVideo": return "투구폼 영상";
                case "SchoolPlaybook": return "학교 작전집";
                case "CoachLetter": return "감독의 편지";
                case "DraftReport": return "드래프트 보고서";
                case "StadiumEcho": return "구장의 메아리";
                case "TeamFirstPromise": return "팀 우선의 약속";
                case "FailureScorebook": return "실패의 기록지";
                case "WinterProgram": return "겨울 프로그램";
                default: return "불펜 나침반";
            }
        }

        private static VisualElement ChoiceHeading(string title, string detail)
        {
            var section = new BaseballSection(title);
            var label = new Label(detail);
            label.AddToClassList("screen-data-row__detail");
            section.Content.Add(label);
            return section;
        }

    }
}
