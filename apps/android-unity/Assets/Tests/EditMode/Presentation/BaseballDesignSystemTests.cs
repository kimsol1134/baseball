using System;
using Baseball.Presentation.Common;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.Accessibility;
using UnityEngine.UIElements;

namespace Baseball.Presentation.Tests
{
    public sealed class BaseballDesignSystemTests
    {
        [TestCase(BaseballColorToken.Canvas, false, "#080D0B")]
        [TestCase(BaseballColorToken.Canvas, true, "#020503")]
        [TestCase(BaseballColorToken.Action, false, "#B7F36B")]
        [TestCase(BaseballColorToken.ActionInk, true, "#000000")]
        [TestCase(BaseballColorToken.Negative, false, "#EF746A")]
        [TestCase(BaseballColorToken.FieldDirt, true, "#C7A87E")]
        public void PaletteMatchesDesignSystemSwift(BaseballColorToken token, bool highContrast, string expected)
        {
            Assert.That(BaseballTheme.ToHex(BaseballTheme.Resolve(token, highContrast)), Is.EqualTo(expected));
        }

        [Test]
        public void TeamAndAvatarColorsStaySeparateFromSemanticState()
        {
            Assert.That(BaseballTheme.ToHex(BaseballTheme.TeamDecoration("busan_marines")), Is.EqualTo("#D3A64C"));
            Assert.That(BaseballTheme.ToHex(BaseballTheme.TeamDecoration("unknown")), Is.EqualTo("#5D8FD7"));
            Assert.That(BaseballTheme.ToHex(BaseballTheme.ResolveAvatar(BaseballAvatarColorToken.Skin1)), Is.EqualTo("#F2CFA5"));
        }

        [Test]
        public void AndroidMetricsPreserveDesignGridAndRaiseTapTarget()
        {
            Assert.That(BaseballMetrics.Gutter, Is.EqualTo(16f));
            Assert.That(BaseballMetrics.StackSpacing, Is.EqualTo(14f));
            Assert.That(BaseballMetrics.TightSpacing, Is.EqualTo(8f));
            Assert.That(BaseballMetrics.CardRadius, Is.EqualTo(14f));
            Assert.That(BaseballMetrics.ControlRadius, Is.EqualTo(10f));
            Assert.That(BaseballMetrics.MinimumTapTarget, Is.EqualTo(48f));
            Assert.That(BaseballMetrics.KeyArtHeight, Is.EqualTo(190f));
            Assert.That(BaseballMetrics.FloatingBottomNavigationClearance, Is.EqualTo(96f));
        }

        [TestCase(1f, BaseballFontScale.Percent100)]
        [TestCase(1.3f, BaseballFontScale.Percent130)]
        [TestCase(1.6f, BaseballFontScale.Percent160)]
        [TestCase(2f, BaseballFontScale.Percent200)]
        public void FontScaleUsesSupportedAccessibilityBuckets(float systemScale, BaseballFontScale expected)
        {
            Assert.That(BaseballThemeController.ResolveFontScale(systemScale), Is.EqualTo(expected));
        }

        [Test]
        public void ThemeControllerAppliesContrastMotionAndFontClasses()
        {
            var root = new VisualElement();
            using (var theme = new BaseballThemeController(root, highContrast: true, reducedMotion: true))
            {
                theme.ApplyFontScale(2f);
                Assert.That(root.ClassListContains(BaseballThemeController.ThemeClass), Is.True);
                Assert.That(root.ClassListContains(BaseballThemeController.HighContrastClass), Is.True);
                Assert.That(root.ClassListContains(BaseballThemeController.ReducedMotionClass), Is.True);
                Assert.That(root.ClassListContains("baseball-font-scale-200"), Is.True);
                Assert.That(root.ClassListContains("baseball-font-scale-100"), Is.False);
            }
        }

        [Test]
        public void SafeAreaMapsScreenPixelsToPanelPoints()
        {
            BaseballSafeAreaInsets insets = BaseballSafeAreaController.Calculate(
                new Rect(0f, 96f, 1080f, 2208f),
                new Vector2(1080f, 2400f),
                new Vector2(360f, 800f));
            Assert.That(insets.Left, Is.EqualTo(0f));
            Assert.That(insets.Right, Is.EqualTo(0f));
            Assert.That(insets.Top, Is.EqualTo(32f).Within(0.001f));
            Assert.That(insets.Bottom, Is.EqualTo(32f).Within(0.001f));
        }

        [Test]
        public void PrimaryActionHasStableTalkBackHook()
        {
            int invocationCount = 0;
            var button = new PrimaryPill("다음", "setup-next", () => invocationCount++);

            Assert.That(button.ClassListContains("baseball-primary-pill"), Is.True);
            Assert.That(BaseballAccessibility.TryGet(button, out BaseballAccessibilityMetadata metadata), Is.True);
            Assert.That(metadata.StableId, Is.EqualTo("setup-next"));
            Assert.That(metadata.Label, Is.EqualTo("다음"));
            Assert.That(metadata.Role, Is.EqualTo(AccessibilityRole.Button));
            Assert.That(metadata.Invoke(), Is.True);
            Assert.That(invocationCount, Is.EqualTo(1));
        }

        [Test]
        public void DisabledPrimaryActionReportsDisabledState()
        {
            var button = new PrimaryPill("선택 필요", "setup-submit", () => { });
            button.SetInteractionEnabled(false);
            Assert.That(BaseballAccessibility.TryGet(button, out BaseballAccessibilityMetadata metadata), Is.True);
            Assert.That(metadata.State, Is.EqualTo(AccessibilityState.Disabled));
            Assert.That(metadata.Invoke(), Is.False);
        }

        [Test]
        public void StatTileIsOneMeaningfulAnnouncement()
        {
            var tile = new StatTile("제구", "42", "control-stat", "35", "훈련 결과");
            Assert.That(BaseballAccessibility.TryGet(tile, out BaseballAccessibilityMetadata metadata), Is.True);
            Assert.That(metadata.Label, Is.EqualTo("제구 35에서 42로 상승. 훈련 결과"));
            Assert.That(metadata.Role, Is.EqualTo(AccessibilityRole.StaticText));
        }

        [Test]
        public void ChoiceAndToggleExposeSelectedStateAndValue()
        {
            var choice = new ChoiceCard("정밀 지휘관", "제구 중심", "preset-precision", () => { });
            choice.SetSelected(true);
            Assert.That(BaseballAccessibility.TryGet(choice, out BaseballAccessibilityMetadata choiceMetadata), Is.True);
            Assert.That(choiceMetadata.State, Is.EqualTo(AccessibilityState.Selected));

            var toggle = new AccessibleToggle("고대비", "settings-high-contrast", true);
            Assert.That(BaseballAccessibility.TryGet(toggle, out BaseballAccessibilityMetadata toggleMetadata), Is.True);
            Assert.That(toggleMetadata.Value, Is.EqualTo("켬"));
            Assert.That(toggleMetadata.State, Is.EqualTo(AccessibilityState.Selected));
            Assert.That(toggleMetadata.Invoke(), Is.True);
            Assert.That(toggle.value, Is.False);
        }

        [Test]
        public void DecorativeArtworkIsNotRegisteredAsTalkBackContent()
        {
            var header = new KeyArtHeader(null, "새로운 시작", "다시 마운드로", "opening-title");
            Assert.That(BaseballAccessibility.TryGet(header, out BaseballAccessibilityMetadata headerMetadata), Is.True);
            Assert.That(headerMetadata.Role, Is.EqualTo(AccessibilityRole.Header));
            Assert.That(BaseballAccessibility.TryGet(header.Artwork, out _), Is.False);
            Assert.That(header.Artwork.ClassListContains("baseball-decoration"), Is.True);
        }

        [Test]
        public void StableAccessibilityIdAndLabelAreRequired()
        {
            Assert.Throws<ArgumentException>(() =>
                BaseballAccessibility.Configure(new VisualElement(), "", "다음", AccessibilityRole.Button));
            Assert.Throws<ArgumentException>(() =>
                BaseballAccessibility.Configure(new VisualElement(), "next", "", AccessibilityRole.Button));
        }
    }
}
