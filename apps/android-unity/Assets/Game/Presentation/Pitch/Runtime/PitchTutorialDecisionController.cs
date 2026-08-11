using System;
using Baseball.Application.HighSchool;
using Baseball.Presentation.Common;
using UnityEngine.Accessibility;
using UnityEngine.UIElements;

namespace Baseball.Presentation.Pitch
{
    /// <summary>Process-death-safe first-bullpen result choice shown before career progression.</summary>
    public sealed class PitchTutorialDecisionController : IDisposable
    {
        private readonly VisualElement _root;
        private readonly Label _status;
        private readonly Button _accept;
        private readonly Button _retry;
        private readonly BaseballThemeController _theme;
        private readonly BaseballSafeAreaController _safeArea;
        private readonly BaseballAccessibilitySession _accessibility;
        private bool _disposed;

        public PitchTutorialDecisionController(
            VisualElement documentRoot,
            PitchGameReport report,
            bool highContrast,
            bool reducedMotion)
        {
            if (documentRoot == null) throw new ArgumentNullException(nameof(documentRoot));
            if (report == null) throw new ArgumentNullException(nameof(report));
            VisualTreeAsset template = UnityEngine.Resources.Load<VisualTreeAsset>("PitchTutorialDecision");
            if (template == null) throw new InvalidOperationException("첫 불펜 결과 UI 템플릿을 찾을 수 없습니다.");
            template.CloneTree(documentRoot);
            _root = documentRoot.Q<VisualElement>("pitch-tutorial-decision-root") ??
                throw new InvalidOperationException("첫 불펜 결과 UI 루트가 없습니다.");
            _root.BringToFront();
            _theme = new BaseballThemeController(_root, highContrast, reducedMotion);
            _safeArea = new BaseballSafeAreaController(_root);

            Label summary = Require<Label>("pitch-tutorial-summary");
            Label detail = Require<Label>("pitch-tutorial-detail");
            _status = Require<Label>("pitch-tutorial-status");
            summary.text = report.Batters + "타자 · " + report.Pitches + "구 · " +
                report.Strikeouts + "탈삼진 · " + report.RunsAllowed + "실점";
            detail.text = "직접 릴리스 " + report.DirectDeliveryCount + "회 · 완벽 " +
                report.PerfectDeliveryCount + "회 · 수싸움 성장 " + report.SequenceMasteryCount + "회";
            BaseballAccessibility.Configure(summary, "pitch-tutorial-result-summary", "첫 불펜 결과",
                AccessibilityRole.Header, value: summary.text, focusable: true);
            BaseballAccessibility.Configure(detail, "pitch-tutorial-result-detail", "첫 불펜 성장 기록",
                AccessibilityRole.StaticText, value: detail.text, focusable: true);
            BaseballAccessibility.Configure(_status, "pitch-tutorial-result-status", "진행 안내",
                AccessibilityRole.StaticText, value: _status.text, focusable: true);

            _retry = new SecondaryButton(
                "다시 던지기",
                "pitch-tutorial-retry",
                () => RetryRequested?.Invoke());
            _accept = new PrimaryPill(
                "학교 후보로",
                "pitch-tutorial-accept",
                () => AcceptRequested?.Invoke());
            Require<VisualElement>("pitch-tutorial-actions").Add(_retry);
            Require<VisualElement>("pitch-tutorial-actions").Add(_accept);
            _accessibility = new BaseballAccessibilitySession(_root);
            _accessibility.FocusScreen(summary);
        }

        public event Action AcceptRequested;
        public event Action RetryRequested;

        public bool TryHandleBack()
        {
            _accessibility.Announce("첫 불펜 결과에서 학교 후보로 이동하거나 다시 던지기를 선택해 주세요.");
            return true;
        }

        public void SetBusy(bool busy, string message, bool allowRetry = true)
        {
            _accept.SetEnabled(!busy);
            _retry.SetEnabled(!busy && allowRetry);
            if (!string.IsNullOrWhiteSpace(message))
            {
                _status.text = message;
                if (BaseballAccessibility.TryGet(_status, out BaseballAccessibilityMetadata metadata))
                    metadata.Value = message;
                _accessibility.Announce(message);
            }
        }

        public void SetPendingAcknowledgement()
        {
            _retry.SetEnabled(false);
            _accept.text = "학교 후보로 이동";
        }

        public void Dispose()
        {
            if (_disposed) return;
            _accessibility.Dispose();
            _safeArea.Dispose();
            _theme.Dispose();
            _root.RemoveFromHierarchy();
            _disposed = true;
        }

        private T Require<T>(string name) where T : VisualElement
        {
            T element = _root.Q<T>(name);
            return element ?? throw new InvalidOperationException("첫 불펜 결과 UI 요소가 없습니다: " + name);
        }
    }
}
