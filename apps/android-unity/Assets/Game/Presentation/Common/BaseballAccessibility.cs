using System;
using System.Collections.Generic;
using System.Runtime.CompilerServices;
using UnityEngine;
using UnityEngine.Accessibility;
using UnityEngine.UIElements;

namespace Baseball.Presentation.Common
{
    public sealed class BaseballAccessibilityMetadata
    {
        public string StableId { get; internal set; }
        public string Label { get; set; }
        public string Hint { get; set; }
        public string Value { get; set; }
        public AccessibilityRole Role { get; set; }
        public AccessibilityState State { get; set; }
        public bool IsActive { get; set; } = true;
        public bool AllowsDirectInteraction { get; set; }
        public Func<bool> Invoke { get; set; }
        public Action Increment { get; set; }
        public Action Decrement { get; set; }
    }

    /// <summary>
    /// Stores screen-reader semantics beside UI Toolkit elements. The metadata remains available in
    /// EditMode even when the platform accessibility bridge is inactive, which makes missing hooks testable.
    /// </summary>
    public static class BaseballAccessibility
    {
        private static readonly ConditionalWeakTable<VisualElement, BaseballAccessibilityMetadata> Metadata =
            new ConditionalWeakTable<VisualElement, BaseballAccessibilityMetadata>();

        public static BaseballAccessibilityMetadata Configure(
            VisualElement element,
            string stableId,
            string label,
            AccessibilityRole role,
            string value = null,
            string hint = null,
            Func<bool> invoke = null,
            bool focusable = true)
        {
            if (element == null) throw new ArgumentNullException(nameof(element));
            if (string.IsNullOrWhiteSpace(stableId)) throw new ArgumentException("A stable accessibility/debug ID is required.", nameof(stableId));
            if (string.IsNullOrWhiteSpace(label)) throw new ArgumentException("An accessibility label is required.", nameof(label));

            var metadata = new BaseballAccessibilityMetadata
            {
                StableId = stableId,
                Label = label,
                Hint = hint,
                Value = value,
                Role = role,
                Invoke = invoke,
            };
            Metadata.Remove(element);
            Metadata.Add(element, metadata);
            element.name = stableId;
            element.tooltip = hint ?? label;
            element.focusable = focusable;
            element.AddToClassList("baseball-accessible");
            return metadata;
        }

        public static bool TryGet(VisualElement element, out BaseballAccessibilityMetadata metadata)
        {
            if (element == null)
            {
                metadata = null;
                return false;
            }
            return Metadata.TryGetValue(element, out metadata);
        }

        public static void HideDecoration(VisualElement element)
        {
            if (element == null) return;
            Metadata.Remove(element);
            element.focusable = false;
            element.AddToClassList("baseball-decoration");
        }
    }

    /// <summary>Builds Unity's native mobile accessibility hierarchy in visual-tree order.</summary>
    public sealed class BaseballAccessibilitySession : IDisposable
    {
        private readonly VisualElement _root;
        private readonly List<NodeBinding> _bindings = new List<NodeBinding>();
        private bool _disposed;

        public AccessibilityHierarchy Hierarchy { get; private set; }

        public BaseballAccessibilitySession(VisualElement root, bool activateImmediately = true)
        {
            _root = root ?? throw new ArgumentNullException(nameof(root));
            Rebuild(activateImmediately);
        }

        public void Rebuild(bool activate = true)
        {
            var hierarchy = new AccessibilityHierarchy();
            _bindings.Clear();
            AddConfiguredDescendants(_root, null, hierarchy);
            Hierarchy = hierarchy;
            if (activate) AssistiveSupport.activeHierarchy = hierarchy;
        }

        public void RefreshValues()
        {
            foreach (NodeBinding binding in _bindings)
            {
                ApplyMetadata(binding.Node, binding.Metadata);
            }
            Hierarchy.RefreshNodeFrames();
        }

        public void Announce(string message)
        {
            if (!string.IsNullOrWhiteSpace(message)) AssistiveSupport.notificationDispatcher.SendAnnouncement(message);
        }

        public bool FocusScreen(VisualElement titleElement)
        {
            foreach (NodeBinding binding in _bindings)
            {
                if (ReferenceEquals(binding.Element, titleElement))
                {
                    AssistiveSupport.notificationDispatcher.SendScreenChanged(binding.Node);
                    return true;
                }
            }
            return false;
        }

        public void Dispose()
        {
            if (_disposed) return;
            if (ReferenceEquals(AssistiveSupport.activeHierarchy, Hierarchy)) AssistiveSupport.activeHierarchy = null;
            _bindings.Clear();
            _disposed = true;
        }

        private void AddConfiguredDescendants(
            VisualElement element,
            AccessibilityNode accessibleParent,
            AccessibilityHierarchy hierarchy)
        {
            AccessibilityNode nextParent = accessibleParent;
            if (BaseballAccessibility.TryGet(element, out BaseballAccessibilityMetadata metadata))
            {
                AccessibilityNode node = hierarchy.AddNode(metadata.Label, accessibleParent);
                ApplyMetadata(node, metadata);
                node.frameGetter = () => ScreenRect(element);
                if (metadata.Invoke != null) node.invoked += metadata.Invoke;
                if (metadata.Increment != null) node.incremented += metadata.Increment;
                if (metadata.Decrement != null) node.decremented += metadata.Decrement;
                _bindings.Add(new NodeBinding(element, node, metadata));
                nextParent = node;
            }

            foreach (VisualElement child in element.Children()) AddConfiguredDescendants(child, nextParent, hierarchy);
        }

        private static void ApplyMetadata(AccessibilityNode node, BaseballAccessibilityMetadata metadata)
        {
            node.label = metadata.Label;
            node.hint = metadata.Hint;
            node.value = metadata.Value;
            node.role = metadata.Role;
            node.state = metadata.State;
            node.isActive = metadata.IsActive;
            node.allowsDirectInteraction = metadata.AllowsDirectInteraction;
        }

        private static Rect ScreenRect(VisualElement element)
        {
            Rect bounds = element.worldBound;
            return new Rect(bounds.xMin, Screen.height - bounds.yMax, bounds.width, bounds.height);
        }

        private sealed class NodeBinding
        {
            public readonly VisualElement Element;
            public readonly AccessibilityNode Node;
            public readonly BaseballAccessibilityMetadata Metadata;

            public NodeBinding(VisualElement element, AccessibilityNode node, BaseballAccessibilityMetadata metadata)
            {
                Element = element;
                Node = node;
                Metadata = metadata;
            }
        }
    }
}
