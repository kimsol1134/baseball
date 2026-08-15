using System;
using System.Collections.Generic;
using System.Linq;
using Baseball.Application.Commands;
using Baseball.Application.HighSchool;
using Baseball.Core.Catalogs;
using Baseball.Core.Domain;
using Baseball.Presentation.Common;
using Baseball.Presentation.Shell;
using UnityEngine.Accessibility;
using UnityEngine.UIElements;

namespace Baseball.Presentation.Setup
{
    /// <summary>
    /// Mirrors the iOS player-creation flow: one decision per step rather than one very long form.
    /// The step is transient presentation state; the authoritative career command remains atomic.
    /// </summary>
    public sealed class SetupScreenController : BaseballScreenControllerBase
    {
        private IBaseballSetupDraft _draft;
        private IBaseballAdvancedSetupDraft _advanced;
        private BaseballScreenViewModel _viewModel;
        private IShellNavigator _navigator;
        private IBaseballVisualAssetLoader _artworkLoader;
        private int _step;
        private int _stepCount;

        public SetupScreenController() : base(ShellRoute.Setup, "SetupScreen") { }

        protected override bool UsesStandardSections(BaseballScreenViewModel viewModel) => false;

        protected override void AddCustomContent(
            VisualElement host,
            BaseballScreenViewModel viewModel,
            IShellNavigator navigator)
        {
            host.style.display = DisplayStyle.Flex;
            host.AddToClassList("setup-step-content");
            _draft = navigator as IBaseballSetupDraft;
            _advanced = navigator as IBaseballAdvancedSetupDraft;
            _viewModel = viewModel;
            _navigator = navigator;
            _artworkLoader = (navigator as IBaseballVisualAssets)?.VisualAssetLoader;
            bool rebirth = _advanced?.SetupOptions?.AdvancedOptionsVisible == true;
            _stepCount = rebirth ? 4 : 3;
            _step = Math.Max(0, Math.Min(_stepCount - 1, _draft?.SetupStep ?? 0));

            host.Add(ProgressHeader(rebirth));
            switch (_step)
            {
                case 0: AddNameStep(host, rebirth); break;
                case 1: AddRegionStep(host); break;
                case 2: AddPresetStep(host); break;
                default: AddHandicapStep(host); break;
            }
        }

        protected override void OnMounted(
            VisualElement screenRoot,
            BaseballScreenViewModel viewModel,
            IShellNavigator navigator)
        {
            ScrollView scroll = screenRoot.Q<ScrollView>("screen-scroll");
            if (scroll != null)
            {
                // Touch remains active, but the desktop-style arrow tracks are not part of the
                // iOS mobile presentation and consume valuable horizontal space on Android.
                scroll.verticalScrollerVisibility = ScrollerVisibility.Hidden;
                scroll.horizontalScrollerVisibility = ScrollerVisibility.Hidden;
                scroll.verticalScroller.style.display = DisplayStyle.None;
                scroll.horizontalScroller.style.display = DisplayStyle.None;
            }
            VisualElement actions = screenRoot.Q<VisualElement>("screen-actions");
            if (actions == null) return;
            actions.Clear();
            actions.AddToClassList("setup-step-footer__actions");

            if (_step == _stepCount - 1)
            {
                ScreenActionViewModel start = viewModel.Actions.FirstOrDefault(value =>
                    string.Equals(value.Id, "start_high_school", StringComparison.Ordinal));
                if (start != null) actions.Add(ActionButton(start));
                ScreenActionViewModel directPro = viewModel.Actions.FirstOrDefault(value =>
                    string.Equals(value.Id, "navigate_direct_pro_entry", StringComparison.Ordinal));
                if (directPro != null) actions.Add(ActionButton(directPro));
            }
            else
            {
                actions.Add(new PrimaryPill(
                    "다음",
                    "screen-setup-step-next",
                    () => _draft?.SetSetupStep(_step + 1)));
            }

            if (_step > 0)
            {
                actions.Add(new SecondaryButton(
                    "뒤로",
                    "screen-setup-step-back",
                    () => _draft?.SetSetupStep(_step - 1)));
            }
        }

        private VisualElement ProgressHeader(bool rebirth)
        {
            var header = new VisualElement();
            header.AddToClassList("setup-progress");
            string progress = rebirth
                ? (_advanced?.SetupOptions?.LifeNumber ?? 2) + "번째 선수 · " + (_step + 1) + " / " + _stepCount
                : "선수 만들기 · " + (_step + 1) + " / " + _stepCount;
            var label = new Label(progress);
            label.AddToClassList("baseball-eyebrow");
            BaseballAccessibility.Configure(
                label,
                "screen-setup-progress",
                progress,
                AccessibilityRole.StaticText);
            header.Add(label);
            var track = new VisualElement();
            track.AddToClassList("setup-progress__track");
            for (var index = 0; index < _stepCount; index++)
            {
                var segment = new VisualElement();
                segment.AddToClassList("setup-progress__segment");
                if (index <= _step) segment.AddToClassList("setup-progress__segment--complete");
                track.Add(segment);
            }
            BaseballAccessibility.HideDecoration(track);
            header.Add(track);
            return header;
        }

        private void AddNameStep(VisualElement host, bool rebirth)
        {
            host.Add(StepHeading(
                rebirth ? "다시 태어날 이름을 정하세요" : "선수의 이름을 정하세요",
                "고교 3년 동안 이 이름으로 불립니다."));

            var fieldCard = new VisualElement();
            fieldCard.AddToClassList("setup-name-card");
            var name = new TextField { value = _draft?.PlayerName ?? string.Empty };
            name.AddToClassList("setup-name-field");
            BaseballAccessibilityMetadata nameAccessibility = BaseballAccessibility.Configure(
                name,
                "screen-setup-player-name",
                "선수 이름",
                AccessibilityRole.TextField,
                value: name.value,
                hint: "비워두면 추천 이름 " + (_draft?.SuggestedPlayerName ?? "민서준") + "을 사용합니다.");
            name.RegisterValueChangedCallback(change =>
            {
                _draft?.SetPlayerName(change.newValue);
                string stored = _draft?.PlayerName ?? change.newValue;
                if (stored != change.newValue)
                {
                    name.SetValueWithoutNotify(stored);
                    _navigator.Announce("선수 이름은 12자까지 입력할 수 있습니다.");
                }
                nameAccessibility.Value = string.IsNullOrWhiteSpace(stored) ? "추천 이름 사용" : stored;
            });
            fieldCard.Add(name);
            host.Add(fieldCard);

            string suggestion = _draft?.SuggestedPlayerName ?? "민서준";
            host.Add(new SecondaryButton(
                suggestion + " 쓰기",
                "screen-setup-player-name-suggestion",
                () =>
                {
                    _draft?.SetPlayerName(string.Empty);
                    // Display the localized suggestion while keeping the stored draft empty;
                    // the career engine still owns the semantic default name.
                    name.SetValueWithoutNotify(suggestion);
                    nameAccessibility.Value = "추천 이름 " + suggestion + " 사용";
                    _navigator.Announce(suggestion + " 이름을 사용합니다.");
                }));

            var seed = new TextField("시드 또는 도전 코드 (선택)")
            {
                value = _advanced?.SeedInput ?? string.Empty
            };
            seed.AddToClassList("setup-seed-field");
            BaseballAccessibilityMetadata seedAccessibility = BaseballAccessibility.Configure(
                seed,
                "screen-setup-seed",
                "시드 또는 도전 코드",
                AccessibilityRole.TextField,
                value: seed.value,
                hint: "숫자는 같은 조건을, 숫자-회차는 계승 없는 도전을 시작합니다.");
            seed.RegisterValueChangedCallback(change =>
            {
                seedAccessibility.Value = change.newValue;
                _advanced?.SetSeedInput(change.newValue);
            });
            host.Add(seed);
            var seedError = new InlineError(
                string.IsNullOrWhiteSpace(_advanced?.SeedValidationMessage)
                    ? SetupSeedInputPolicy.InvalidMessage
                    : _advanced.SeedValidationMessage,
                "screen-setup-seed-error");
            seedError.style.display = string.IsNullOrWhiteSpace(_advanced?.SeedValidationMessage)
                ? DisplayStyle.None
                : DisplayStyle.Flex;
            seed.RegisterValueChangedCallback(change =>
            {
                string message = SetupSeedInputPolicy.ValidationMessage(change.newValue);
                seedError.SetMessage(string.IsNullOrWhiteSpace(message)
                    ? SetupSeedInputPolicy.InvalidMessage
                    : message);
                seedError.style.display = string.IsNullOrWhiteSpace(message)
                    ? DisplayStyle.None
                    : DisplayStyle.Flex;
            });
            host.Add(seedError);

            host.Add(new AddressableContentImage(
                rebirth
                    ? "baseball/highschool/KeyArtReincarnation"
                    : "baseball/highschool/KeyArtStadiumNight",
                rebirth ? "새 인생을 기다리는 야구장" : "고교 3년을 보낼 야구장",
                "screen-setup-name-stage-art",
                _artworkLoader));

            ScreenActionViewModel quick = _viewModel.Actions.FirstOrDefault(value =>
                string.Equals(value.Id, "quick_rebirth", StringComparison.Ordinal));
            if (quick != null)
            {
                var section = new BaseballCallout(
                    "바로 환생",
                    BaseballCalloutTone.Milestone,
                    "screen-setup-quick-rebirth");
                section.Content.Add(new Label("지난 선수와 같은 이름·지역·유형·난이도로 즉시 시작합니다."));
                section.Content.Add(ActionButton(quick));
                host.Add(section);
            }
        }

        private void AddRegionStep(VisualElement host)
        {
            host.Add(StepHeading(
                "어느 지역에서 시작할까요?",
                "중학교 마지막 대회를 치른 지역입니다. 이 지역의 네 고교가 손을 내밉니다."));
            var grid = new VisualElement();
            grid.AddToClassList("setup-region-grid");
            VisualElement row = null;
            var cards = new List<ChoiceCard>();
            string selected = string.IsNullOrWhiteSpace(_draft?.Region) ? "서울" : _draft.Region;
            for (var index = 0; index < HighSchoolSetupCatalog.Regions.Count; index++)
            {
                CareerChoiceReadModel option = HighSchoolSetupCatalog.Regions[index];
                ChoiceCard card = null;
                card = new ChoiceCard(
                    option.Title,
                    option.Detail,
                    "screen-setup-region-" + index.ToString("00"),
                    () =>
                    {
                        selected = option.Payload;
                        _draft?.SetRegion(option.Payload);
                        foreach (ChoiceCard value in cards) value.SetSelected(ReferenceEquals(value, card));
                        _navigator.Announce(option.Title + " 지역을 골랐습니다.");
                    });
                card.AddToClassList("setup-region-card");
                card.SetSelected(string.Equals(option.Payload, selected, StringComparison.Ordinal));
                card.SetEnabled(option.Enabled);
                cards.Add(card);
                if (index % 2 == 0)
                {
                    row = new VisualElement();
                    row.AddToClassList("setup-region-row");
                    grid.Add(row);
                }
                row.Add(card);
            }
            if (HighSchoolSetupCatalog.Regions.Count % 2 != 0 && row != null)
            {
                var spacer = new VisualElement();
                spacer.AddToClassList("setup-region-spacer");
                BaseballAccessibility.HideDecoration(spacer);
                row.Add(spacer);
            }
            host.Add(grid);
        }

        private void AddPresetStep(VisualElement host)
        {
            host.Add(StepHeading(
                "어떤 공을 던지는 투수인가요?",
                "시작 능력치만 다릅니다. 3년 동안의 훈련으로 얼마든지 바뀝니다."));
            var roots = new List<VisualElement>();
            var cards = new List<ChoiceCard>();
            var payloads = new List<string>();
            string selected = string.IsNullOrWhiteSpace(_draft?.PresetId)
                ? HighSchoolSetupCatalog.Presets.First().Payload
                : _draft.PresetId;
            foreach (CareerChoiceReadModel option in HighSchoolSetupCatalog.Presets)
            {
                ChoiceCard card = null;
                VisualElement root = null;
                card = new ChoiceCard(
                    option.Title,
                    option.Detail,
                    "screen-setup-preset-" + option.Id,
                    () =>
                    {
                        selected = option.Payload;
                        _draft?.SetPresetId(option.Payload);
                        for (var index = 0; index < cards.Count; index++)
                        {
                            bool active = string.Equals(payloads[index], selected, StringComparison.Ordinal);
                            cards[index].SetSelected(active);
                            roots[index].EnableInClassList("setup-preset-card--selected", active);
                        }
                        _navigator.Announce(option.Title + " 유형을 골랐습니다.");
                    });
                card.AddToClassList("setup-preset-card__choice");
                card.SetSelected(string.Equals(option.Payload, selected, StringComparison.Ordinal));
                root = PresetCard(option, card);
                root.EnableInClassList(
                    "setup-preset-card--selected",
                    string.Equals(option.Payload, selected, StringComparison.Ordinal));
                roots.Add(root);
                cards.Add(card);
                payloads.Add(option.Payload);
                host.Add(root);
            }
        }

        private VisualElement PresetCard(CareerChoiceReadModel option, ChoiceCard card)
        {
            var root = new VisualElement();
            root.AddToClassList("setup-preset-card");
            root.Add(new AddressableContentImage(
                BaseballVisualContentCatalog.SetupPreset(option.Payload),
                option.Title + " 투수 유형 삽화",
                "screen-setup-preset-art-" + option.Id,
                _artworkLoader));
            root.Add(card);
            PitcherPresetSnapshot preset = PitcherPresetCatalog.All.FirstOrDefault(value =>
                string.Equals(value.Id, option.Payload, StringComparison.Ordinal));
            if (preset?.Pitcher != null)
            {
                root.Add(AbilityRow("구위", preset.Pitcher.Stuff, option.Id + "-stuff"));
                root.Add(AbilityRow("제구", preset.Pitcher.Command, option.Id + "-command"));
                root.Add(AbilityRow("변화", preset.Pitcher.Movement, option.Id + "-movement"));
                root.Add(AbilityRow("체력", preset.Pitcher.Stamina, option.Id + "-stamina"));
            }
            if (!string.IsNullOrWhiteSpace(option.EffectSummary))
            {
                var effect = new Label(option.EffectSummary);
                effect.AddToClassList("setup-preset-card__effect");
                root.Add(effect);
            }
            return root;
        }

        private static VisualElement AbilityRow(string label, int value, string stableId)
        {
            var root = new VisualElement();
            root.AddToClassList("setup-ability-row");
            var heading = new VisualElement();
            heading.AddToClassList("setup-ability-row__heading");
            heading.Add(new Label(label));
            var number = new Label(value.ToString());
            number.AddToClassList("setup-ability-row__value");
            heading.Add(number);
            root.Add(heading);
            var gauge = new AbilityGauge(label, "screen-setup-preset-gauge-" + stableId);
            gauge.SetValue(value, 100f);
            root.Add(gauge);
            return root;
        }

        private void AddHandicapStep(VisualElement host)
        {
            HighSchoolSetupReadModel options = _advanced?.SetupOptions;
            if (options == null) return;
            host.Add(StepHeading(
                "이번 인생의 조건을 정하세요",
                options.LifeNumber + "번째 선수 · 자동 계승 야구혼 " + options.AutomaticSoul +
                " · 배분 가능한 야구혼 " + options.SoulBalance));
            AddSingleChoice(host, "난이도", "한 가지를 선택합니다.", "difficulty",
                options.Difficulties, _advanced.SetupDifficulty, _advanced.SetSetupSingle);

            bool challenge = HighSchoolSetupCatalog.TryParseSeedInput(
                _advanced.SeedInput,
                out HighSchoolSeedSelection seedSelection,
                out _) && seedSelection?.IsChallenge == true;
            if (challenge)
            {
                var notice = new BaseballCallout(
                    "기록 없는 도전",
                    BaseballCalloutTone.Milestone,
                    "screen-setup-challenge");
                notice.Content.Add(new Label(
                    seedSelection.ChallengeLifeNumber +
                    "번째 선수와 같은 조건을 계승 도움 없이 시작합니다. 기록·야구혼·유산에는 반영되지 않습니다."));
                host.Add(notice);
                return;
            }

            AddMultiChoice(host, "카르마", "최대 2개 · 위험이 커질수록 다음 계승 보상이 커집니다.",
                "karma", options.Karmas);
            if (options.AutomaticSoul > 0)
                AddSingleChoice(host, "자동 계승 야구혼 성향", "어느 성장축에 먼저 반영할지 고릅니다.",
                    "soul_domain", options.SoulDomains, _advanced.SetupSoulDomain, _advanced.SetSetupSingle);
            AddMultiChoice(host, "야구혼 강화", "보유 야구혼 안에서 여러 개를 고를 수 있습니다.",
                "soul_boost", options.SoulBoosts);

            var memories = options.CarriedMemories.Select((value, index) => new CareerChoiceReadModel(
                "memory-" + index,
                MemoryTitle(value),
                "지난 인생에서 확정된 기억입니다.",
                payload: value)).ToArray();
            AddReadOnlyMemories(host, memories);
            AddSingleChoice(host, "대표 유산", "현재 장착한 유산을 기본으로 사용합니다.",
                "signature", options.SignatureLegacies, _advanced.SetupSignatureLegacy, _advanced.SetSetupSingle);
        }

        private void AddSingleChoice(
            VisualElement host,
            string title,
            string detail,
            string group,
            IReadOnlyList<CareerChoiceReadModel> choices,
            string selected,
            Action<string, string> select)
        {
            if (choices == null || choices.Count == 0) return;
            host.Add(ChoiceHeading(title, detail));
            var cards = new List<ChoiceCard>();
            foreach (CareerChoiceReadModel option in choices)
            {
                ChoiceCard card = null;
                card = new ChoiceCard(option.Title, JoinDetail(option),
                    "screen-setup-" + group + "-" + option.Id, () =>
                    {
                        select(group, option.Payload);
                        foreach (ChoiceCard value in cards) value.SetSelected(ReferenceEquals(value, card));
                        _navigator.Announce(option.Title + " 선택을 확정했습니다.");
                    });
                card.SetSelected(string.Equals(selected ?? string.Empty, option.Payload ?? string.Empty, StringComparison.Ordinal));
                card.SetEnabled(option.Enabled);
                cards.Add(card);
                string artwork = BaseballVisualContentCatalog.Choice(group, option.Payload);
                host.Add(string.IsNullOrWhiteSpace(artwork)
                    ? (VisualElement)card
                    : AddressableContentImage.WrapChoice(card, artwork, option.Title + " 선택지 삽화",
                        "screen-setup-" + group + "-art-" + option.Id, _artworkLoader));
            }
        }

        private void AddMultiChoice(
            VisualElement host,
            string title,
            string detail,
            string group,
            IReadOnlyList<CareerChoiceReadModel> choices)
        {
            if (choices == null || choices.Count == 0) return;
            host.Add(ChoiceHeading(title, detail));
            foreach (CareerChoiceReadModel option in choices)
            {
                ChoiceCard card = null;
                card = new ChoiceCard(option.Title, JoinDetail(option),
                    "screen-setup-" + group + "-" + option.Id, () =>
                    {
                        _advanced.ToggleSetupMulti(group, option.Payload);
                        bool active = _advanced.IsSetupSelected(group, option.Payload);
                        card.SetSelected(active);
                        _navigator.Announce(option.Title + (active ? " 선택" : " 선택 해제"));
                    });
                card.SetSelected(_advanced.IsSetupSelected(group, option.Payload));
                card.SetEnabled(option.Enabled);
                host.Add(card);
            }
        }

        private void AddReadOnlyMemories(
            VisualElement host,
            IReadOnlyList<CareerChoiceReadModel> memories)
        {
            if (memories == null || memories.Count == 0) return;
            host.Add(ChoiceHeading("상속 기억", "지난 인생에서 확정된 기억은 자동으로 이어집니다."));
            foreach (CareerChoiceReadModel memory in memories)
            {
                var card = new ChoiceCard(memory.Title, "자동 계승 · " + memory.Detail,
                    "screen-setup-memory-" + memory.Id, null);
                card.SetEnabled(false);
                host.Add(AddressableContentImage.WrapChoice(
                    card,
                    BaseballVisualContentCatalog.Memory(memory.Payload),
                    memory.Title + " 상속 기억 삽화",
                    "screen-setup-memory-art-" + memory.Id,
                    _artworkLoader));
            }
        }

        private VisualElement ActionButton(ScreenActionViewModel action)
        {
            Action invoke = () =>
            {
                if (!action.IsEnabled) _navigator.Announce(action.DisabledReason);
                else if (action.RequiresConfirmation) _navigator.ShowConfirmation(action);
                else _navigator.Execute(action);
            };
            VisualElement button = action.Style == ScreenActionStyle.Primary
                ? (VisualElement)new PrimaryPill(action.Label, "screen-setup-action-" + action.Id, invoke)
                : action.Style == ScreenActionStyle.Destructive
                    ? new DestructiveButton(action.Label, "screen-setup-action-" + action.Id, invoke)
                    : new SecondaryButton(action.Label, "screen-setup-action-" + action.Id, invoke);
            button.SetEnabled(action.IsEnabled);
            button.tooltip = string.IsNullOrWhiteSpace(action.Hint) ? action.Label : action.Hint;
            return button;
        }

        private static VisualElement StepHeading(string title, string detail)
        {
            var root = new VisualElement();
            root.AddToClassList("setup-step-heading");
            var heading = new Label(title);
            heading.AddToClassList("setup-step-title");
            root.Add(heading);
            var lead = new Label(detail);
            lead.AddToClassList("setup-step-lead");
            root.Add(lead);
            return root;
        }

        private static VisualElement ChoiceHeading(string title, string detail)
        {
            var section = new BaseballSection(title);
            var label = new Label(detail);
            label.AddToClassList("screen-data-row__detail");
            section.Content.Add(label);
            return section;
        }

        private static string JoinDetail(CareerChoiceReadModel option)
        {
            if (string.IsNullOrWhiteSpace(option?.EffectSummary)) return option?.Detail ?? string.Empty;
            return string.IsNullOrWhiteSpace(option.Detail)
                ? option.EffectSummary
                : option.Detail + "\n" + option.EffectSummary;
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
    }
}
