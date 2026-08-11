using System;
using UnityEngine;
using UnityEngine.UIElements;

namespace Baseball.Presentation.Common
{
    public readonly struct BaseballSafeAreaInsets
    {
        public readonly float Left;
        public readonly float Top;
        public readonly float Right;
        public readonly float Bottom;

        public BaseballSafeAreaInsets(float left, float top, float right, float bottom)
        {
            Left = Mathf.Max(0f, left);
            Top = Mathf.Max(0f, top);
            Right = Mathf.Max(0f, right);
            Bottom = Mathf.Max(0f, bottom);
        }
    }

    /// <summary>Maps Android cutout and system-bar insets into UI Toolkit panel points.</summary>
    public sealed class BaseballSafeAreaController : IDisposable
    {
        private readonly VisualElement _root;
        private readonly Func<Rect> _safeArea;
        private readonly Func<Vector2> _screenSize;

        public BaseballSafeAreaController(
            VisualElement root,
            Func<Rect> safeArea = null,
            Func<Vector2> screenSize = null)
        {
            _root = root ?? throw new ArgumentNullException(nameof(root));
            _safeArea = safeArea ?? (() => Screen.safeArea);
            _screenSize = screenSize ?? (() => new Vector2(Screen.width, Screen.height));
            _root.AddToClassList("baseball-safe-area");
            _root.RegisterCallback<GeometryChangedEvent>(OnGeometryChanged);
            Refresh();
        }

        public BaseballSafeAreaInsets Refresh()
        {
            Rect layout = _root.contentRect;
            Vector2 screen = _screenSize();
            BaseballSafeAreaInsets insets = Calculate(_safeArea(), screen, new Vector2(layout.width, layout.height));
            _root.style.paddingLeft = insets.Left;
            _root.style.paddingTop = insets.Top;
            _root.style.paddingRight = insets.Right;
            _root.style.paddingBottom = insets.Bottom;
            return insets;
        }

        public static BaseballSafeAreaInsets Calculate(Rect safeArea, Vector2 screenSize, Vector2 panelSize)
        {
            if (screenSize.x <= 0f || screenSize.y <= 0f || panelSize.x <= 0f || panelSize.y <= 0f)
            {
                return new BaseballSafeAreaInsets(0f, 0f, 0f, 0f);
            }
            float horizontalScale = panelSize.x / screenSize.x;
            float verticalScale = panelSize.y / screenSize.y;
            return new BaseballSafeAreaInsets(
                safeArea.xMin * horizontalScale,
                (screenSize.y - safeArea.yMax) * verticalScale,
                (screenSize.x - safeArea.xMax) * horizontalScale,
                safeArea.yMin * verticalScale);
        }

        public void Dispose()
        {
            _root.UnregisterCallback<GeometryChangedEvent>(OnGeometryChanged);
        }

        private void OnGeometryChanged(GeometryChangedEvent change)
        {
            Refresh();
        }
    }
}
