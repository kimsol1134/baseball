using System;
using Baseball.Presentation.Shell;
using UnityEngine;
using UnityEngine.UIElements;

namespace Baseball.Presentation.Common
{
    /// <summary>Fires once only after the target intersects its real ScrollView viewport.</summary>
    internal sealed class ViewportExposureObserver : IDisposable
    {
        private readonly VisualElement _target;
        private readonly ScrollView _scroll;
        private readonly VisualElement _viewport;
        private readonly ContentExposureGate _gate = new ContentExposureGate();
        private Action _onVisible;
        private bool _disposed;

        public ViewportExposureObserver(
            VisualElement target,
            ScrollView scroll,
            Action onVisible)
        {
            _target = target ?? throw new ArgumentNullException(nameof(target));
            _scroll = scroll;
            _viewport = scroll?.contentViewport;
            _onVisible = onVisible ?? throw new ArgumentNullException(nameof(onVisible));
            _target.RegisterCallback<AttachToPanelEvent>(OnAttach);
            _target.RegisterCallback<GeometryChangedEvent>(OnGeometryChanged);
            _viewport?.RegisterCallback<GeometryChangedEvent>(OnGeometryChanged);
            if (_scroll?.verticalScroller != null)
                _scroll.verticalScroller.valueChanged += OnScrollChanged;
            if (_scroll?.horizontalScroller != null)
                _scroll.horizontalScroller.valueChanged += OnScrollChanged;
            _target.schedule.Execute(CheckVisibility);
        }

        public void Dispose()
        {
            if (_disposed) return;
            _target.UnregisterCallback<AttachToPanelEvent>(OnAttach);
            _target.UnregisterCallback<GeometryChangedEvent>(OnGeometryChanged);
            _viewport?.UnregisterCallback<GeometryChangedEvent>(OnGeometryChanged);
            if (_scroll?.verticalScroller != null)
                _scroll.verticalScroller.valueChanged -= OnScrollChanged;
            if (_scroll?.horizontalScroller != null)
                _scroll.horizontalScroller.valueChanged -= OnScrollChanged;
            _onVisible = null;
            _disposed = true;
        }

        private void OnAttach(AttachToPanelEvent _) =>
            _target.schedule.Execute(CheckVisibility);

        private void OnGeometryChanged(GeometryChangedEvent _) => CheckVisibility();

        private void OnScrollChanged(float _) => CheckVisibility();

        private void CheckVisibility()
        {
            if (_disposed) return;
            VisualElement viewport = _viewport ?? _target.panel?.visualTree;
            if (viewport == null) return;
            Rect targetBounds = _target.worldBound;
            Rect viewportBounds = viewport.worldBound;
            bool displayed = _target.resolvedStyle.display != DisplayStyle.None &&
                _target.resolvedStyle.visibility == Visibility.Visible &&
                _target.resolvedStyle.opacity > 0.001f;
            if (!_gate.TryExpose(
                    _target.panel != null,
                    displayed,
                    targetBounds.xMin,
                    targetBounds.yMin,
                    targetBounds.xMax,
                    targetBounds.yMax,
                    viewportBounds.xMin,
                    viewportBounds.yMin,
                    viewportBounds.xMax,
                    viewportBounds.yMax)) return;
            Action callback = _onVisible;
            Dispose();
            callback?.Invoke();
        }
    }
}
