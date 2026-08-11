using System;
using System.Collections.Generic;

namespace Baseball.Presentation.Shell
{
    /// <summary>Pure viewport intersection and once-per-rendered-content policy.</summary>
    public sealed class ContentExposureGate
    {
        private bool _exposed;

        public bool TryExpose(
            bool attached,
            bool displayed,
            float targetLeft,
            float targetTop,
            float targetRight,
            float targetBottom,
            float viewportLeft,
            float viewportTop,
            float viewportRight,
            float viewportBottom)
        {
            if (_exposed || !attached || !displayed ||
                targetRight <= targetLeft || targetBottom <= targetTop ||
                viewportRight <= viewportLeft || viewportBottom <= viewportTop)
            {
                return false;
            }
            bool intersects = targetLeft < viewportRight && targetRight > viewportLeft &&
                targetTop < viewportBottom && targetBottom > viewportTop;
            if (!intersects) return false;
            _exposed = true;
            return true;
        }
    }

    public sealed class ContentExposureDeduplicator
    {
        private readonly HashSet<string> _keys = new HashSet<string>(StringComparer.Ordinal);

        public bool TryMark(string route, string contentId, string instanceId)
        {
            if (string.IsNullOrWhiteSpace(route) || string.IsNullOrWhiteSpace(contentId) ||
                string.IsNullOrWhiteSpace(instanceId)) return false;
            return _keys.Add(route + "|" + contentId + "|" + instanceId);
        }
    }
}
