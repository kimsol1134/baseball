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
        private readonly HashSet<string> _pending = new HashSet<string>(StringComparer.Ordinal);
        private readonly HashSet<string> _completed = new HashSet<string>(StringComparer.Ordinal);

        /// <summary>
        /// Reserves one exposure attempt. A caller must Complete only after its durable receipt and
        /// analytics enqueue succeed, or Release on any save/cancellation failure so re-entry can
        /// retry in the same process.
        /// </summary>
        public bool TryBegin(string route, string contentId, string instanceId)
        {
            string key = Key(route, contentId, instanceId);
            if (key == null || _pending.Contains(key) || _completed.Contains(key)) return false;
            return _pending.Add(key);
        }

        public void Complete(string route, string contentId, string instanceId)
        {
            string key = Key(route, contentId, instanceId);
            if (key == null || !_pending.Remove(key)) return;
            _completed.Add(key);
        }

        public void Release(string route, string contentId, string instanceId)
        {
            string key = Key(route, contentId, instanceId);
            if (key != null) _pending.Remove(key);
        }

        private static string Key(string route, string contentId, string instanceId)
        {
            if (string.IsNullOrWhiteSpace(route) || string.IsNullOrWhiteSpace(contentId) ||
                string.IsNullOrWhiteSpace(instanceId)) return null;
            return route + "|" + contentId + "|" + instanceId;
        }
    }
}
