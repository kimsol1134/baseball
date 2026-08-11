using System;
using UnityEngine.Accessibility;
using UnityEngine.UIElements;

namespace Baseball.Presentation.Common
{
    public enum BaseballFontScale
    {
        Percent100,
        Percent130,
        Percent160,
        Percent200,
    }

    public sealed class BaseballThemeController : IDisposable
    {
        public const string ThemeClass = "baseball-theme";
        public const string HighContrastClass = "baseball-high-contrast";
        public const string ReducedMotionClass = "baseball-reduced-motion";
        public const string BoldTextClass = "baseball-bold-text";

        private static readonly string[] FontScaleClasses =
        {
            "baseball-font-scale-100",
            "baseball-font-scale-130",
            "baseball-font-scale-160",
            "baseball-font-scale-200",
        };

        private readonly VisualElement _root;
        private bool _disposed;

        public BaseballThemeController(VisualElement root, bool highContrast = false, bool reducedMotion = false)
        {
            _root = root ?? throw new ArgumentNullException(nameof(root));
            _root.AddToClassList(ThemeClass);
            SetHighContrast(highContrast);
            SetReducedMotion(reducedMotion);
            ApplyFontScale(AccessibilitySettings.fontScale);
            ApplyBoldText(AccessibilitySettings.isBoldTextEnabled);
            AccessibilitySettings.fontScaleChanged += ApplyFontScale;
            AccessibilitySettings.boldTextStatusChanged += ApplyBoldText;
        }

        public void SetHighContrast(bool enabled)
        {
            _root.EnableInClassList(HighContrastClass, enabled);
        }

        public void SetReducedMotion(bool enabled)
        {
            _root.EnableInClassList(ReducedMotionClass, enabled);
        }

        public void ApplyFontScale(float systemScale)
        {
            BaseballFontScale scale = ResolveFontScale(systemScale);
            for (int index = 0; index < FontScaleClasses.Length; index++)
            {
                _root.EnableInClassList(FontScaleClasses[index], index == (int)scale);
            }
        }

        public void ApplyBoldText(bool enabled)
        {
            _root.EnableInClassList(BoldTextClass, enabled);
        }

        public static BaseballFontScale ResolveFontScale(float systemScale)
        {
            if (systemScale <= 0f || systemScale < 1.15f) return BaseballFontScale.Percent100;
            if (systemScale < 1.45f) return BaseballFontScale.Percent130;
            if (systemScale < 1.8f) return BaseballFontScale.Percent160;
            return BaseballFontScale.Percent200;
        }

        public static string FontScaleClass(BaseballFontScale scale)
        {
            return FontScaleClasses[(int)scale];
        }

        public void Dispose()
        {
            if (_disposed) return;
            AccessibilitySettings.fontScaleChanged -= ApplyFontScale;
            AccessibilitySettings.boldTextStatusChanged -= ApplyBoldText;
            _disposed = true;
        }
    }
}
