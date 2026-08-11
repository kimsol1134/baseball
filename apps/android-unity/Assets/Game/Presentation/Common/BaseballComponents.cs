using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.Accessibility;
using UnityEngine.UIElements;

namespace Baseball.Presentation.Common
{
    public enum BaseballCalloutTone
    {
        Milestone,
        Positive,
        Warning,
        Negative,
        Information,
    }

    public abstract class BaseballActionButton : Button
    {
        protected readonly BaseballAccessibilityMetadata Accessibility;

        protected BaseballActionButton(string title, string stableId, Action onClick, string styleClass, string accessibilityLabel = null)
            : base(onClick)
        {
            text = title ?? string.Empty;
            AddToClassList("baseball-button");
            AddToClassList(styleClass);
            Accessibility = BaseballAccessibility.Configure(
                this,
                stableId,
                accessibilityLabel ?? title,
                AccessibilityRole.Button,
                invoke: () =>
                {
                    if (!enabledSelf) return false;
                    onClick?.Invoke();
                    return true;
                });
        }

        public void SetInteractionEnabled(bool enabled)
        {
            SetEnabled(enabled);
            Accessibility.State = enabled ? AccessibilityState.None : AccessibilityState.Disabled;
        }
    }

    public sealed class PrimaryPill : BaseballActionButton
    {
        public PrimaryPill(string title, string stableId, Action onClick)
            : base(title, stableId, onClick, "baseball-primary-pill") { }
    }

    public sealed class SecondaryButton : BaseballActionButton
    {
        public SecondaryButton(string title, string stableId, Action onClick)
            : base(title, stableId, onClick, "baseball-secondary-button") { }
    }

    public sealed class DestructiveButton : BaseballActionButton
    {
        public DestructiveButton(string title, string stableId, Action onClick)
            : base(title, stableId, onClick, "baseball-destructive-button") { }
    }

    public sealed class IconButton : BaseballActionButton
    {
        public IconButton(string glyph, string accessibilityLabel, string stableId, Action onClick)
            : base(glyph, stableId, onClick, "baseball-icon-button", accessibilityLabel) { }
    }

    public sealed class BackButton : BaseballActionButton
    {
        public BackButton(string stableId, Action onClick, string accessibilityLabel = "뒤로")
            : base("‹", stableId, onClick, "baseball-back-button", accessibilityLabel) { }
    }

    public sealed class BaseballSection : VisualElement
    {
        public Label Eyebrow { get; }
        public VisualElement Content { get; }

        public BaseballSection(string title, string stableId = null, bool informationTone = false)
        {
            AddToClassList("baseball-section");
            if (informationTone) AddToClassList("baseball-section--information");
            Eyebrow = new Label(title);
            Eyebrow.AddToClassList("baseball-eyebrow");
            Content = new VisualElement();
            Content.AddToClassList("baseball-section__content");
            Add(Eyebrow);
            Add(Content);
            var hairline = new VisualElement();
            hairline.AddToClassList("baseball-section__hairline");
            BaseballAccessibility.HideDecoration(hairline);
            Add(hairline);
            if (!string.IsNullOrEmpty(stableId))
            {
                BaseballAccessibility.Configure(Eyebrow, stableId, title, AccessibilityRole.Header, focusable: true);
            }
        }
    }

    public sealed class BaseballCallout : VisualElement
    {
        public Label Eyebrow { get; }
        public VisualElement Content { get; }

        public BaseballCallout(string title, BaseballCalloutTone tone, string stableId = null)
        {
            AddToClassList("baseball-callout");
            AddToClassList($"baseball-callout--{ToneClass(tone)}");
            Eyebrow = new Label(title);
            Eyebrow.AddToClassList("baseball-eyebrow");
            Content = new VisualElement();
            Content.AddToClassList("baseball-callout__content");
            Add(Eyebrow);
            Add(Content);
            if (!string.IsNullOrEmpty(stableId))
            {
                BaseballAccessibility.Configure(this, stableId, title, AccessibilityRole.Container, focusable: false);
            }
        }

        private static string ToneClass(BaseballCalloutTone tone)
        {
            return tone.ToString().ToLowerInvariant();
        }
    }

    public sealed class StatTile : VisualElement
    {
        private readonly Label _valueLabel;
        private readonly Label _captionLabel;
        private readonly BaseballAccessibilityMetadata _accessibility;
        private string _label;
        private string _value;
        private string _previousValue;
        private string _caption;

        public StatTile(string label, string value, string stableId, string previousValue = null, string caption = null)
        {
            AddToClassList("baseball-stat-tile");
            var eyebrow = new Label(label);
            eyebrow.AddToClassList("baseball-eyebrow");
            _valueLabel = new Label();
            _valueLabel.AddToClassList("baseball-stat-tile__value");
            _captionLabel = new Label();
            _captionLabel.AddToClassList("baseball-stat-tile__caption");
            Add(eyebrow);
            Add(_valueLabel);
            Add(_captionLabel);
            _accessibility = BaseballAccessibility.Configure(this, stableId, label, AccessibilityRole.StaticText, focusable: true);
            SetValue(label, value, previousValue, caption);
        }

        public void SetValue(string label, string value, string previousValue = null, string caption = null)
        {
            _label = label ?? string.Empty;
            _value = value ?? string.Empty;
            _previousValue = previousValue;
            _caption = caption;
            _valueLabel.text = string.IsNullOrEmpty(previousValue) ? _value : $"{previousValue}  →  {_value}";
            _captionLabel.text = caption ?? string.Empty;
            _captionLabel.style.display = string.IsNullOrEmpty(caption) ? DisplayStyle.None : DisplayStyle.Flex;
            _accessibility.Label = AccessibilitySummary();
        }

        private string AccessibilitySummary()
        {
            string summary = string.IsNullOrEmpty(_previousValue)
                ? $"{_label} {_value}"
                : $"{_label} {_previousValue}에서 {_value}로 상승";
            return string.IsNullOrEmpty(_caption) ? summary : $"{summary}. {_caption}";
        }
    }

    public sealed class AbilityGauge : VisualElement
    {
        private readonly VisualElement _fill;
        private readonly BaseballAccessibilityMetadata _accessibility;
        private readonly string _label;

        public AbilityGauge(string label, string stableId)
        {
            _label = label ?? string.Empty;
            AddToClassList("baseball-ability-gauge");
            var track = new VisualElement();
            track.AddToClassList("baseball-ability-gauge__track");
            _fill = new VisualElement();
            _fill.AddToClassList("baseball-ability-gauge__fill");
            track.Add(_fill);
            Add(track);
            _accessibility = BaseballAccessibility.Configure(this, stableId, _label, AccessibilityRole.StaticText, focusable: true);
            SetValue(0f, 100f);
        }

        public void SetValue(float value, float maximum, float? previousValue = null)
        {
            float safeMaximum = Mathf.Max(1f, maximum);
            float safeValue = Mathf.Clamp(value, 0f, safeMaximum);
            _fill.style.width = Length.Percent(safeValue / safeMaximum * 100f);
            EnableInClassList("baseball-ability-gauge--gain", previousValue.HasValue && safeValue > previousValue.Value);
            _accessibility.Value = previousValue.HasValue
                ? $"{Format(previousValue.Value)}에서 {Format(safeValue)}, 최대 {Format(safeMaximum)}"
                : $"{Format(safeValue)}, 최대 {Format(safeMaximum)}";
        }

        private static string Format(float value)
        {
            return Mathf.Approximately(value, Mathf.Round(value)) ? Mathf.RoundToInt(value).ToString() : value.ToString("0.#");
        }
    }

    public sealed class ScoreboardRow : VisualElement
    {
        private readonly Label _homeValue;
        private readonly Label _awayValue;
        private readonly BaseballAccessibilityMetadata _accessibility;
        private readonly string _homeLabel;
        private readonly string _awayLabel;

        public ScoreboardRow(string homeLabel, string awayLabel, string homeValue, string awayValue, string stableId)
        {
            _homeLabel = homeLabel;
            _awayLabel = awayLabel;
            AddToClassList("baseball-scoreboard-row");
            Add(ScoreLabel(homeLabel));
            _homeValue = ScoreValue(homeValue);
            Add(_homeValue);
            Add(ScoreLabel(awayLabel));
            _awayValue = ScoreValue(awayValue);
            Add(_awayValue);
            _accessibility = BaseballAccessibility.Configure(this, stableId, "점수", AccessibilityRole.StaticText, focusable: true);
            SetValues(homeValue, awayValue);
        }

        public void SetValues(string homeValue, string awayValue)
        {
            _homeValue.text = homeValue;
            _awayValue.text = awayValue;
            _accessibility.Label = $"{_homeLabel} {homeValue}, {_awayLabel} {awayValue}";
        }

        private static Label ScoreLabel(string value)
        {
            var label = new Label(value);
            label.AddToClassList("baseball-scoreboard-row__label");
            return label;
        }

        private static Label ScoreValue(string value)
        {
            var label = new Label(value);
            label.AddToClassList("baseball-scoreboard-row__value");
            return label;
        }
    }

    public sealed class ChoiceCard : Button
    {
        private readonly BaseballAccessibilityMetadata _accessibility;
        private readonly string _title;
        private readonly string _description;

        public ChoiceCard(string title, string description, string stableId, Action onClick)
            : base(onClick)
        {
            _title = title ?? string.Empty;
            _description = description ?? string.Empty;
            text = string.IsNullOrEmpty(_description) ? _title : $"{_title}\n{_description}";
            AddToClassList("baseball-choice-card");
            _accessibility = BaseballAccessibility.Configure(
                this,
                stableId,
                string.IsNullOrEmpty(_description) ? _title : $"{_title}. {_description}",
                AccessibilityRole.Button,
                invoke: () =>
                {
                    if (!enabledSelf) return false;
                    onClick?.Invoke();
                    return true;
                });
        }

        public void SetSelected(bool selected)
        {
            EnableInClassList("baseball-choice-card--selected", selected);
            _accessibility.State = selected ? AccessibilityState.Selected : AccessibilityState.None;
        }
    }

    public sealed class CharacterProfile : VisualElement
    {
        public VisualElement Portrait { get; }
        public Label NameLabel { get; }
        public Label DetailLabel { get; }

        public CharacterProfile(string characterName, string detail, string stableId, Texture2D portrait = null)
        {
            AddToClassList("baseball-character-profile");
            Portrait = new VisualElement();
            Portrait.AddToClassList("baseball-character-profile__portrait");
            if (portrait != null) Portrait.style.backgroundImage = new StyleBackground(portrait);
            BaseballAccessibility.HideDecoration(Portrait);
            NameLabel = new Label(characterName);
            NameLabel.AddToClassList("baseball-character-profile__name");
            DetailLabel = new Label(detail);
            DetailLabel.AddToClassList("baseball-character-profile__detail");
            Add(Portrait);
            Add(NameLabel);
            Add(DetailLabel);
            BaseballAccessibility.Configure(this, stableId, $"{characterName}. {detail}", AccessibilityRole.StaticText, focusable: true);
        }
    }

    public sealed class KeyArtHeader : VisualElement
    {
        public VisualElement Artwork { get; }
        public Label Eyebrow { get; }
        public Label Title { get; }

        public KeyArtHeader(Texture2D artwork, string eyebrow, string title, string stableId)
        {
            AddToClassList("baseball-key-art-header");
            Artwork = new VisualElement();
            Artwork.AddToClassList("baseball-key-art-header__image");
            if (artwork != null) Artwork.style.backgroundImage = new StyleBackground(artwork);
            BaseballAccessibility.HideDecoration(Artwork);
            var copy = new VisualElement();
            copy.AddToClassList("baseball-key-art-header__copy");
            Eyebrow = new Label(eyebrow);
            Eyebrow.AddToClassList("baseball-eyebrow");
            Title = new Label(title);
            Title.AddToClassList("baseball-display");
            copy.Add(Eyebrow);
            copy.Add(Title);
            Add(Artwork);
            Add(copy);
            BaseballAccessibility.Configure(this, stableId, $"{eyebrow}. {title}", AccessibilityRole.Header, focusable: true);
        }
    }

    public class ModalSheet : VisualElement
    {
        public VisualElement Scrim { get; }
        public VisualElement Sheet { get; }
        public VisualElement Content { get; }
        public Label Title { get; }

        public ModalSheet(string title, string stableId)
        {
            AddToClassList("baseball-modal");
            Scrim = new VisualElement();
            Scrim.AddToClassList("baseball-modal__scrim");
            BaseballAccessibility.HideDecoration(Scrim);
            Sheet = new VisualElement();
            Sheet.AddToClassList("baseball-modal__sheet");
            Title = new Label(title);
            Title.AddToClassList("baseball-section-title");
            Content = new VisualElement();
            Content.AddToClassList("baseball-modal__content");
            Sheet.Add(Title);
            Sheet.Add(Content);
            Add(Scrim);
            Add(Sheet);
            BaseballAccessibility.Configure(Sheet, stableId, title, AccessibilityRole.Container, focusable: true);
        }

        public void FocusFirstControl()
        {
            VisualElement first = Content.Query<VisualElement>(classes: "baseball-accessible").ToList().FirstOrDefault();
            (first ?? Sheet).Focus();
        }
    }

    public sealed class ConfirmationDialog : ModalSheet
    {
        public ConfirmationDialog(
            string title,
            string message,
            string confirmTitle,
            string cancelTitle,
            string stableId,
            Action confirm,
            Action cancel,
            bool destructive = false)
            : base(title, stableId)
        {
            var copy = new Label(message);
            copy.AddToClassList("baseball-modal__message");
            Content.Add(copy);
            var actions = new VisualElement();
            actions.AddToClassList("baseball-modal__actions");
            actions.Add(new SecondaryButton(cancelTitle, $"{stableId}-cancel", cancel));
            actions.Add(destructive
                ? (VisualElement)new DestructiveButton(confirmTitle, $"{stableId}-confirm", confirm)
                : new PrimaryPill(confirmTitle, $"{stableId}-confirm", confirm));
            Content.Add(actions);
        }
    }

    public sealed class Toast : VisualElement
    {
        public Toast(string message, string stableId, BaseballCalloutTone tone = BaseballCalloutTone.Information)
        {
            AddToClassList("baseball-toast");
            AddToClassList($"baseball-toast--{tone.ToString().ToLowerInvariant()}");
            Add(new Label(message));
            BaseballAccessibility.Configure(this, stableId, message, AccessibilityRole.StaticText, focusable: false);
        }
    }

    public sealed class InlineError : VisualElement
    {
        private readonly Label _label;
        private readonly BaseballAccessibilityMetadata _accessibility;

        public InlineError(string message, string stableId)
        {
            AddToClassList("baseball-inline-error");
            _label = new Label(message);
            Add(_label);
            _accessibility = BaseballAccessibility.Configure(this, stableId, message, AccessibilityRole.StaticText, focusable: true);
        }

        public void SetMessage(string message)
        {
            _label.text = message;
            _accessibility.Label = message;
        }
    }

    public sealed class LoadingOverlay : VisualElement
    {
        public LoadingOverlay(string message, string stableId)
        {
            AddToClassList("baseball-loading-overlay");
            var spinner = new VisualElement();
            spinner.AddToClassList("baseball-loading-overlay__spinner");
            BaseballAccessibility.HideDecoration(spinner);
            Add(spinner);
            Add(new Label(message));
            BaseballAccessibility.Configure(this, stableId, message, AccessibilityRole.StaticText, value: "진행 중", focusable: true);
        }
    }

    public sealed class TopAppBar : VisualElement
    {
        public Label Title { get; }
        public VisualElement Actions { get; }

        public TopAppBar(string title, string stableId, BackButton backButton = null)
        {
            AddToClassList("baseball-top-app-bar");
            if (backButton != null) Add(backButton);
            Title = new Label(title);
            Title.AddToClassList("baseball-top-app-bar__title");
            Actions = new VisualElement();
            Actions.AddToClassList("baseball-top-app-bar__actions");
            Add(Title);
            Add(Actions);
            BaseballAccessibility.Configure(Title, stableId, title, AccessibilityRole.Header, focusable: true);
        }
    }

    public sealed class BottomNavigation : VisualElement
    {
        private readonly Dictionary<string, NavigationItem> _items = new Dictionary<string, NavigationItem>();

        public BottomNavigation(string stableId)
        {
            AddToClassList("baseball-bottom-navigation");
            BaseballAccessibility.Configure(this, stableId, "하단 탐색", AccessibilityRole.TabBar, focusable: false);
        }

        public void AddItem(string itemId, string label, Action onClick)
        {
            if (_items.ContainsKey(itemId)) throw new ArgumentException($"Duplicate navigation item: {itemId}", nameof(itemId));
            var button = new Button(onClick) { text = label };
            button.AddToClassList("baseball-bottom-navigation__item");
            BaseballAccessibilityMetadata accessibility = BaseballAccessibility.Configure(
                button,
                itemId,
                label,
                AccessibilityRole.TabButton,
                invoke: () =>
                {
                    onClick?.Invoke();
                    return true;
                });
            _items.Add(itemId, new NavigationItem(button, accessibility));
            Add(button);
        }

        public void Select(string itemId)
        {
            foreach (KeyValuePair<string, NavigationItem> pair in _items)
            {
                bool selected = pair.Key == itemId;
                pair.Value.Button.EnableInClassList("baseball-bottom-navigation__item--selected", selected);
                pair.Value.Accessibility.State = selected ? AccessibilityState.Selected : AccessibilityState.None;
            }
        }

        private sealed class NavigationItem
        {
            public readonly Button Button;
            public readonly BaseballAccessibilityMetadata Accessibility;

            public NavigationItem(Button button, BaseballAccessibilityMetadata accessibility)
            {
                Button = button;
                Accessibility = accessibility;
            }
        }
    }

    public sealed class AccessibleToggle : Toggle
    {
        private readonly BaseballAccessibilityMetadata _accessibility;

        public AccessibleToggle(string label, string stableId, bool initialValue, Action<bool> onChanged = null)
            : base(label)
        {
            AddToClassList("baseball-toggle");
            value = initialValue;
            _accessibility = BaseballAccessibility.Configure(this, stableId, label, AccessibilityRole.Toggle, value: StateValue(initialValue));
            _accessibility.State = initialValue ? AccessibilityState.Selected : AccessibilityState.None;
            _accessibility.Invoke = () =>
            {
                if (!enabledSelf) return false;
                value = !value;
                return true;
            };
            INotifyValueChangedExtensions.RegisterValueChangedCallback(this, change =>
            {
                _accessibility.Value = StateValue(change.newValue);
                _accessibility.State = change.newValue ? AccessibilityState.Selected : AccessibilityState.None;
                onChanged?.Invoke(change.newValue);
            });
        }

        public void SetInteractionEnabled(bool enabled)
        {
            SetEnabled(enabled);
            _accessibility.State = enabled
                ? value ? AccessibilityState.Selected : AccessibilityState.None
                : AccessibilityState.Disabled;
        }

        private static string StateValue(bool enabled) => enabled ? "켬" : "끔";
    }

    public sealed class AccessibleSlider : Slider
    {
        private readonly BaseballAccessibilityMetadata _accessibility;
        private readonly Func<float, string> _formatter;
        private readonly float _step;

        public AccessibleSlider(
            string label,
            string stableId,
            float minimum,
            float maximum,
            float initialValue,
            float step,
            Action<float> onChanged = null,
            Func<float, string> formatter = null)
            : base(minimum, maximum)
        {
            AddToClassList("baseball-slider");
            _formatter = formatter ?? (current => current.ToString("0.#"));
            _step = Mathf.Max(0.0001f, step);
            value = Mathf.Clamp(initialValue, minimum, maximum);
            _accessibility = BaseballAccessibility.Configure(this, stableId, label, AccessibilityRole.Slider, value: _formatter(value));
            _accessibility.AllowsDirectInteraction = true;
            _accessibility.Increment = () => this.value = Mathf.Min(highValue, this.value + _step);
            _accessibility.Decrement = () => this.value = Mathf.Max(lowValue, this.value - _step);
            INotifyValueChangedExtensions.RegisterValueChangedCallback(this, change =>
            {
                _accessibility.Value = _formatter(change.newValue);
                onChanged?.Invoke(change.newValue);
            });
        }

        public void SetInteractionEnabled(bool enabled)
        {
            SetEnabled(enabled);
            _accessibility.State = enabled ? AccessibilityState.None : AccessibilityState.Disabled;
        }
    }

    public sealed class SegmentedChoice : VisualElement
    {
        private readonly List<Segment> _segments = new List<Segment>();
        private readonly Action<string> _onSelected;
        private readonly string _label;

        public SegmentedChoice(string label, string stableId, Action<string> onSelected)
        {
            _label = label;
            _onSelected = onSelected;
            AddToClassList("baseball-segmented-choice");
            BaseballAccessibility.Configure(this, stableId, label, AccessibilityRole.Container, focusable: false);
        }

        public void AddOption(string optionId, string label)
        {
            if (_segments.Any(segment => segment.Id == optionId)) throw new ArgumentException($"Duplicate segment: {optionId}", nameof(optionId));
            var button = new Button(() => Select(optionId)) { text = label };
            button.AddToClassList("baseball-segmented-choice__item");
            BaseballAccessibilityMetadata accessibility = BaseballAccessibility.Configure(
                button,
                optionId,
                $"{_label}, {label}",
                AccessibilityRole.Button,
                invoke: () =>
                {
                    Select(optionId);
                    return true;
                });
            _segments.Add(new Segment(optionId, button, accessibility));
            Add(button);
        }

        public void Select(string optionId)
        {
            bool found = false;
            foreach (Segment segment in _segments)
            {
                bool selected = segment.Id == optionId;
                found |= selected;
                segment.Button.EnableInClassList("baseball-segmented-choice__item--selected", selected);
                segment.Accessibility.State = selected ? AccessibilityState.Selected : AccessibilityState.None;
            }
            if (!found) throw new ArgumentException($"Unknown segment: {optionId}", nameof(optionId));
            _onSelected?.Invoke(optionId);
        }

        private sealed class Segment
        {
            public readonly string Id;
            public readonly Button Button;
            public readonly BaseballAccessibilityMetadata Accessibility;

            public Segment(string id, Button button, BaseballAccessibilityMetadata accessibility)
            {
                Id = id;
                Button = button;
                Accessibility = accessibility;
            }
        }
    }
}
