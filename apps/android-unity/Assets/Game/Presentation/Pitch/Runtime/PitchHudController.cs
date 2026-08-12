using System;
using System.Collections.Generic;
using Baseball.Core.Domain;
using Baseball.Core.Pitching;
using Baseball.Presentation.Common;
using Baseball.Presentation.Shell;
using UnityEngine;
using UnityEngine.Accessibility;
using UnityEngine.UIElements;

namespace Baseball.Presentation.Pitch
{
    public sealed class PitchHudController : IDisposable
    {
        private readonly PitchPlayPresenter _presenter;
        private readonly VisualElement _documentRoot;
        private readonly Dictionary<PitchType, Button> _pitchButtons = new Dictionary<PitchType, Button>();
        private readonly Dictionary<PitchZone, Button> _zoneButtons = new Dictionary<PitchZone, Button>();
        private readonly Dictionary<PitchType, BaseballAccessibilityMetadata> _pitchAccessibility = new Dictionary<PitchType, BaseballAccessibilityMetadata>();
        private readonly Dictionary<PitchZone, BaseballAccessibilityMetadata> _zoneAccessibility = new Dictionary<PitchZone, BaseballAccessibilityMetadata>();
        private readonly bool _autoRelease;
        private readonly bool _tutorial;
        private readonly PitchPointerCaptureState _pointerCapture = new PitchPointerCaptureState();
        private VisualElement _root;
        private VisualElement _inputPanel;
        private VisualElement _timingPanel;
        private VisualElement _presentingPanel;
        private VisualElement _resultPanel;
        private VisualElement _aimSurface;
        private VisualElement _aimMarker;
        private VisualElement _meterFill;
        private VisualElement _releaseSlot;
        private VisualElement _abandonSlot;
        private VisualElement _resultSkipSlot;
        private Label _inningLabel;
        private Label _countLabel;
        private Label _batterLabel;
        private Label _recommendationLabel;
        private Label _situationDetailLabel;
        private Label _batterDetailLabel;
        private Label _scoutingDetailLabel;
        private Label _rivalDetailLabel;
        private Label _pitcherDetailLabel;
        private Label _tutorialCoachLabel;
        private Label _releaseLabel;
        private Label _presentingLabel;
        private Label _resultTitle;
        private Label _resultDetail;
        private Label _resultStats;
        private VisualElement _postgameSummary;
        private Label _postgameAnalysis;
        private Label _postgameGrowth;
        private VisualElement _postgameLog;
        private Label _postgameStatus;
        private SegmentedChoice _intentChoice;
        private SegmentedChoice _intensityChoice;
        private BaseballThemeController _theme;
        private BaseballSafeAreaController _safeArea;
        private BaseballAccessibilitySession _accessibility;
        private BaseballAccessibilityMetadata _inningAccessibility;
        private BaseballAccessibilityMetadata _countAccessibility;
        private BaseballAccessibilityMetadata _batterAccessibility;
        private BaseballAccessibilityMetadata _aimAccessibility;
        private BaseballAccessibilityMetadata _recommendationAccessibility;
        private BaseballAccessibilityMetadata _situationDetailAccessibility;
        private BaseballAccessibilityMetadata _batterDetailAccessibility;
        private BaseballAccessibilityMetadata _scoutingDetailAccessibility;
        private BaseballAccessibilityMetadata _rivalDetailAccessibility;
        private BaseballAccessibilityMetadata _pitcherDetailAccessibility;
        private BaseballAccessibilityMetadata _resultAccessibility;
        private Button _finishButton;
        private Button _releaseButton;
        private Button _catcherSignButton;
        private Button _backButton;
        private Button _abandonButton;
        private Label _exitStatusLabel;
        private ConfirmationDialog _exitConfirmation;
        private ConfirmationDialog _abandonConfirmation;
        private string _committedMetricFeedback = string.Empty;
        private bool _synchronizingChoices;
        private bool _exitBusy;
        private bool _postgameVisible;
        private bool _disposed;

        public PitchHudController(
            VisualElement documentRoot,
            PitchPlayPresenter presenter,
            bool highContrast,
            bool reducedMotion,
            IBaseballVisualAssetLoader visualAssetLoader = null,
            bool autoRelease = false,
            bool tutorial = false)
        {
            _documentRoot = documentRoot ?? throw new ArgumentNullException(nameof(documentRoot));
            _presenter = presenter ?? throw new ArgumentNullException(nameof(presenter));
            _autoRelease = autoRelease;
            _tutorial = tutorial;
            Mount(highContrast, reducedMotion);
            _presenter.ViewChanged += Render;
        }

        public event Action SkipRequested;
        public event Action ExitRequested;
        public event Action SuspendRequested;
        public event Action AbortRequested;

        public void SetExitStatus(bool busy, string message)
        {
            _exitBusy = busy;
            _backButton?.SetEnabled(!busy);
            _abandonButton?.SetEnabled(!busy);
            if (_exitStatusLabel != null)
            {
                _exitStatusLabel.text = message ?? string.Empty;
                _exitStatusLabel.style.display = string.IsNullOrWhiteSpace(message)
                    ? DisplayStyle.None
                    : DisplayStyle.Flex;
            }
            if (!string.IsNullOrWhiteSpace(message)) _accessibility?.Announce(message);
        }

        public void SetPersistenceStatus(bool busy, bool succeeded, string message)
        {
            if (_finishButton == null) return;
            _finishButton.SetEnabled(!busy);
            _finishButton.text = busy ? "경기 결과 저장 중…" : _postgameVisible
                ? succeeded ? "결과 확인하고 계속" : "결과 저장 다시 시도"
                : succeeded ? "승부 마무리" : "저장 다시 시도";
            if (!busy && !succeeded)
                Require<VisualElement>("pitch-result-action").style.display = DisplayStyle.Flex;
            if (!string.IsNullOrWhiteSpace(message))
            {
                if (_postgameVisible)
                    _postgameStatus.text = message;
                else
                    _resultDetail.text = message;
                _resultAccessibility.Value = _postgameVisible
                    ? _resultDetail.text + ". " + message
                    : message;
                _accessibility?.Announce(message);
            }
        }

        public void ShowPostgameSummary(PitchSessionPostgameSnapshot snapshot)
        {
            if (snapshot?.Report == null) return;
            PitchPostgameContent content = PitchPostgameProjection.Project(
                snapshot.Report,
                snapshot.PitchLog,
                snapshot.ReleaseMastery);
            _postgameVisible = true;
            _resultTitle.text = "이닝 정산";
            _resultDetail.text = content.Summary;
            _resultStats.text = string.Empty;
            _postgameAnalysis.text = content.Analysis;
            _postgameGrowth.text = content.Growth;
            _postgameStatus.text = "결과를 확인한 뒤 저장하고 계속해 주세요.";
            _postgameLog.Clear();
            foreach (PitchPostgameLine line in content.Pitches)
            {
                var row = new VisualElement();
                row.AddToClassList("pitch-postgame-log__row");
                var title = new Label(line.Title);
                title.AddToClassList("pitch-postgame-log__title");
                row.Add(title);
                var detail = new Label(line.Detail);
                detail.AddToClassList("pitch-postgame-log__detail");
                row.Add(detail);
                BaseballAccessibility.Configure(
                    row,
                    "pitch-postgame-log-" + _postgameLog.childCount,
                    line.Title,
                    AccessibilityRole.StaticText,
                    hint: line.Detail,
                    focusable: true);
                _postgameLog.Add(row);
            }
            _postgameSummary.style.display = DisplayStyle.Flex;
            _resultSkipSlot.style.display = DisplayStyle.None;
            Require<VisualElement>("pitch-result-action").style.display = DisplayStyle.Flex;
            _finishButton.text = "결과 저장/계속";
            _resultAccessibility.Label = "이닝 정산";
            _resultAccessibility.Value = content.Summary + ". " + content.Analysis + ". " + content.Growth;
            RebuildAccessibility();
            _accessibility.FocusScreen(_resultTitle);
        }

        public void SetCommittedMetricFeedback(PitchCommitMetricEvidence evidence)
        {
            if (evidence == null)
            {
                _committedMetricFeedback = string.Empty;
                return;
            }
            var parts = new List<string>();
            string ability = PitchKoreanCopy.AbilityMomentName(evidence.AbilityMomentType);
            if (!string.IsNullOrWhiteSpace(ability)) parts.Add(ability);
            if (evidence.Moment != null) parts.Add("수싸움 · " + evidence.Moment.Headline);
            if (evidence.Delivery.WasDirect)
                parts.Add("직접 릴리스 " + evidence.Delivery.Score / 10 + "%");
            _committedMetricFeedback = string.Join(" · ", parts);
        }

        public void Tick(double unscaledDeltaSeconds)
        {
            _presenter.AdvanceRelease(unscaledDeltaSeconds);
            if (_presenter.Phase != PitchPlayPhase.Timing) return;
            PitchPlayViewState state = _presenter.State;
            _meterFill.style.width = Length.Percent((float)(state.ReleasePhase * 100.0));
            int accuracy = PitchReleaseMeter.AccuracyAt(state.ReleasePhase);
            _releaseLabel.text = accuracy >= PitchDelivery.PerfectReleaseThreshold
                ? "지금 놓으면 완벽합니다"
                : accuracy >= 750 ? "좋은 릴리스 구간입니다" : "초록 지점에 맞춰 놓으세요";
        }

        public bool TryHandleBack()
        {
            if (_exitBusy)
            {
                _accessibility?.Announce("경기 진행을 저장하고 있습니다.");
                return true;
            }
            switch (PitchBackPolicy.Resolve(
                _presenter.Phase,
                _tutorial,
                _exitConfirmation != null || _abandonConfirmation != null))
            {
                case PitchBackAction.BlockTutorial:
                    _accessibility?.Announce("첫 불펜은 승부를 마친 뒤 학교 선택으로 이어집니다.");
                    break;
                case PitchBackAction.CloseConfirmation:
                    CloseActiveConfirmation();
                    _accessibility?.Announce("경기를 계속합니다.");
                    break;
                case PitchBackAction.CancelRelease:
                    _presenter.CancelRelease();
                    break;
                case PitchBackAction.SkipPresentation:
                    SkipRequested?.Invoke();
                    break;
                case PitchBackAction.CompleteResult:
                    ExitRequested?.Invoke();
                    break;
                case PitchBackAction.ShowExitConfirmation:
                    ShowExitConfirmation();
                    break;
            }
            return true;
        }

        private void ShowExitConfirmation()
        {
            if (_exitConfirmation != null) return;
            const string stableId = "pitch-exit-confirmation";
            _exitConfirmation = new ConfirmationDialog(
                "진행 중인 경기에서 나갈까요?",
                "경기를 나가면 현재 타자 시작 지점에서 이어집니다.",
                "경기 나가기",
                "계속 던지기",
                stableId,
                () =>
                {
                    CloseExitConfirmation();
                    SuspendRequested?.Invoke();
                },
                CloseExitConfirmation,
                false);
            _root.Add(_exitConfirmation);
            _exitConfirmation.BringToFront();
            RebuildAccessibility();
            _exitConfirmation.schedule.Execute(_exitConfirmation.FocusFirstControl);
            _accessibility?.Announce("진행 중인 경기에서 나갈까요? 경기를 나가면 현재 타자 시작 지점에서 이어집니다.");
        }

        private void CloseExitConfirmation()
        {
            if (_exitConfirmation == null) return;
            _exitConfirmation.RemoveFromHierarchy();
            _exitConfirmation = null;
            RebuildAccessibility();
        }

        private void ShowAbandonConfirmation()
        {
            if (_tutorial || _exitBusy || _abandonConfirmation != null) return;
            CloseExitConfirmation();
            const string stableId = "pitch-abandon-confirmation";
            _abandonConfirmation = new ConfirmationDialog(
                "이 이닝을 포기할까요?",
                "저장된 경기 진행과 이번 이닝 기록이 삭제됩니다. 이어 던질 수 없습니다.",
                "이닝 포기",
                "계속 던지기",
                stableId,
                () =>
                {
                    CloseAbandonConfirmation();
                    AbortRequested?.Invoke();
                },
                CloseAbandonConfirmation,
                true);
            _root.Add(_abandonConfirmation);
            _abandonConfirmation.BringToFront();
            RebuildAccessibility();
            _abandonConfirmation.schedule.Execute(_abandonConfirmation.FocusFirstControl);
            _accessibility?.Announce("이 이닝을 포기할까요? 저장된 경기 진행과 이번 이닝 기록이 삭제됩니다.");
        }

        private void CloseAbandonConfirmation()
        {
            if (_abandonConfirmation == null) return;
            _abandonConfirmation.RemoveFromHierarchy();
            _abandonConfirmation = null;
            RebuildAccessibility();
        }

        private void CloseActiveConfirmation()
        {
            if (_exitConfirmation != null) CloseExitConfirmation();
            else CloseAbandonConfirmation();
        }

        public void Dispose()
        {
            if (_disposed) return;
            _presenter.ViewChanged -= Render;
            CloseExitConfirmation();
            CloseAbandonConfirmation();
            _root.UnregisterCallback<NavigationCancelEvent>(OnNavigationCancel);
            _root.UnregisterCallback<BlurEvent>(OnRootBlur);
            _root.UnregisterCallback<DetachFromPanelEvent>(OnDetachFromPanel);
            _accessibility?.Dispose();
            _safeArea?.Dispose();
            _theme?.Dispose();
            _root.RemoveFromHierarchy();
            _disposed = true;
        }

        private void Mount(bool highContrast, bool reducedMotion)
        {
            VisualTreeAsset template = Resources.Load<VisualTreeAsset>("PitchPlay");
            if (template == null) throw new InvalidOperationException("투구 UI 템플릿을 찾을 수 없습니다: PitchPlay");
            template.CloneTree(_documentRoot);
            _root = _documentRoot.Q<VisualElement>("pitch-play-root");
            if (_root == null) throw new InvalidOperationException("투구 UI 루트가 없습니다.");
            _root.BringToFront();
            _theme = new BaseballThemeController(_root, highContrast, reducedMotion);
            _safeArea = new BaseballSafeAreaController(_root);

            _inputPanel = Require<VisualElement>("pitch-input-panel");
            _timingPanel = Require<VisualElement>("pitch-timing-panel");
            _presentingPanel = Require<VisualElement>("pitch-presenting-panel");
            _resultPanel = Require<VisualElement>("pitch-result-panel");
            _aimSurface = Require<VisualElement>("pitch-aim-surface");
            _aimMarker = Require<VisualElement>("pitch-aim-marker");
            _meterFill = Require<VisualElement>("pitch-release-meter-fill");
            _releaseSlot = Require<VisualElement>("pitch-release-slot");
            _abandonSlot = Require<VisualElement>("pitch-abandon-slot");
            _resultSkipSlot = Require<VisualElement>("pitch-result-skip-slot");
            _inningLabel = Require<Label>("pitch-inning");
            _countLabel = Require<Label>("pitch-count");
            _batterLabel = Require<Label>("pitch-batter");
            _recommendationLabel = Require<Label>("pitch-recommendation");
            _situationDetailLabel = Require<Label>("pitch-situation-detail");
            _batterDetailLabel = Require<Label>("pitch-batter-detail");
            _scoutingDetailLabel = Require<Label>("pitch-scouting-detail");
            _rivalDetailLabel = Require<Label>("pitch-rival-detail");
            _pitcherDetailLabel = Require<Label>("pitch-pitcher-detail");
            _tutorialCoachLabel = Require<Label>("pitch-tutorial-coach");
            _releaseLabel = Require<Label>("pitch-release-label");
            _presentingLabel = Require<Label>("pitch-presenting-label");
            _resultTitle = Require<Label>("pitch-result-title");
            _resultDetail = Require<Label>("pitch-result-detail");
            _resultStats = Require<Label>("pitch-result-stats");
            _postgameSummary = Require<VisualElement>("pitch-postgame-summary");
            _postgameAnalysis = Require<Label>("pitch-postgame-analysis");
            _postgameGrowth = Require<Label>("pitch-postgame-growth");
            _postgameLog = Require<VisualElement>("pitch-postgame-log");
            _postgameStatus = Require<Label>("pitch-postgame-status");

            VisualElement backSlot = Require<VisualElement>("pitch-back-slot");
            if (_tutorial)
                backSlot.style.display = DisplayStyle.None;
            else
            {
                _backButton = new BackButton("pitch-back", () => TryHandleBack(), "투구 화면 닫기");
                backSlot.Add(_backButton);
            }
            BuildPitchTypeButtons();
            BuildZoneGrid();
            BuildChoices();
            BuildCatcherSignControl();
            BuildReleaseControl();
            BuildAbandonControl();
            BuildPresentationControls();
            ConfigureAimSurface();
            ConfigureStaticAccessibility();
            _root.RegisterCallback<NavigationCancelEvent>(OnNavigationCancel);
            _root.RegisterCallback<BlurEvent>(OnRootBlur);
            _root.RegisterCallback<DetachFromPanelEvent>(OnDetachFromPanel);
        }

        private void BuildPitchTypeButtons()
        {
            VisualElement host = Require<VisualElement>("pitch-type-options");
            foreach (PitchType pitchType in _presenter.AvailablePitchTypes)
            {
                PitchType captured = pitchType;
                var button = new Button(() => _presenter.SelectPitchType(captured))
                {
                    text = PitchKoreanCopy.PitchTypeName(captured),
                };
                button.AddToClassList("pitch-option-button");
                BaseballAccessibilityMetadata accessibility = BaseballAccessibility.Configure(
                    button,
                    "pitch-type-" + captured.Value(),
                    PitchKoreanCopy.PitchTypeName(captured),
                    AccessibilityRole.Button,
                    invoke: () =>
                    {
                        _presenter.SelectPitchType(captured);
                        return true;
                    });
                _pitchAccessibility.Add(captured, accessibility);
                _pitchButtons.Add(captured, button);
                host.Add(button);
            }
        }

        private void BuildZoneGrid()
        {
            VisualElement host = Require<VisualElement>("pitch-zone-grid");
            for (int row = 0; row < 3; row++)
            {
                var rowElement = new VisualElement();
                rowElement.AddToClassList("pitch-zone-row");
                for (int column = 0; column < 3; column++)
                {
                    var zone = new PitchZone(row, column);
                    PitchZone captured = zone;
                    var button = new Button(() => _presenter.SelectZone(captured)) { text = PitchKoreanCopy.ZoneName(captured) };
                    button.AddToClassList("pitch-zone-cell");
                    BaseballAccessibilityMetadata accessibility = BaseballAccessibility.Configure(
                        button,
                        $"pitch-zone-{row}-{column}",
                        "코스 " + PitchKoreanCopy.ZoneName(captured),
                        AccessibilityRole.Button,
                        invoke: () =>
                        {
                            _presenter.SelectZone(captured);
                            return true;
                        });
                    _zoneAccessibility.Add(zone, accessibility);
                    _zoneButtons.Add(zone, button);
                    rowElement.Add(button);
                }
                host.Add(rowElement);
            }
        }

        private void BuildChoices()
        {
            _intentChoice = new SegmentedChoice("투구 의도", "pitch-intent", selected =>
            {
                if (_synchronizingChoices) return;
                if (selected == "pitch-intent-edge") _presenter.SelectIntent(ZoneIntent.Edge);
                else if (selected == "pitch-intent-chase") _presenter.SelectIntent(ZoneIntent.Chase);
                else _presenter.SelectIntent(ZoneIntent.Strike);
            });
            _intentChoice.AddOption("pitch-intent-strike", "스트라이크");
            _intentChoice.AddOption("pitch-intent-edge", "경계");
            _intentChoice.AddOption("pitch-intent-chase", "유인구");
            Require<VisualElement>("pitch-intent-slot").Add(_intentChoice);

            _intensityChoice = new SegmentedChoice("힘 조절", "pitch-intensity", selected =>
            {
                if (_synchronizingChoices) return;
                if (selected == "pitch-intensity-controlled") _presenter.SelectIntensity(PitchIntensity.Controlled);
                else if (selected == "pitch-intensity-max") _presenter.SelectIntensity(PitchIntensity.MaxEffort);
                else _presenter.SelectIntensity(PitchIntensity.Normal);
            });
            _intensityChoice.AddOption("pitch-intensity-controlled", "힘 조절");
            _intensityChoice.AddOption("pitch-intensity-normal", "보통");
            _intensityChoice.AddOption("pitch-intensity-max", "전력");
            Require<VisualElement>("pitch-intensity-slot").Add(_intensityChoice);
        }

        private void BuildReleaseControl()
        {
            var release = new Button { text = _autoRelease ? "탭 한 번으로 던지기" : "누르고 있다가 놓기" };
            _releaseButton = release;
            release.AddToClassList("baseball-button");
            release.AddToClassList("baseball-primary-pill");
            release.AddToClassList("pitch-release-control");
            BaseballAccessibility.Configure(
                release,
                "pitch-release-control",
                "릴리스 타이밍",
                AccessibilityRole.Button,
                hint: _autoRelease
                    ? "한 번 탭하면 중립 릴리스로 던집니다. 화면 읽기 기능의 실행 동작은 직접 완벽 릴리스입니다."
                    : "누르고 있다가 초록 지점에서 놓으세요. 화면 읽기 기능에서는 실행하면 직접 완벽 릴리스로 던집니다.",
                invoke: () =>
                {
                    if (_presenter.Phase != PitchPlayPhase.Selecting) return false;
                    _presenter.BeginRelease();
                    _presenter.AdvanceRelease(PitchReleaseMeter.PerfectPhase * PitchReleaseMeter.SweepSeconds);
                    _presenter.SubmitRelease();
                    return true;
                });
            release.RegisterCallback<PointerDownEvent>(evt =>
            {
                if (evt.button != 0 || _presenter.Phase != PitchPlayPhase.Selecting) return;
                if (_autoRelease)
                {
                    _presenter.SubmitNeutralRelease();
                    evt.StopPropagation();
                    return;
                }
                if (!_pointerCapture.TryBeginRelease(evt.pointerId)) return;
                _presenter.BeginRelease();
                release.CapturePointer(evt.pointerId);
                evt.StopPropagation();
            });
            release.clicked += () =>
            {
                // Android accessibility services and shell-driven device smoke can
                // deliver a semantic click without a matching pointer-up event.
                // Keep the ordinary press/hold interaction, but make that click a
                // deterministic neutral release instead of a dead control.
                if (_presenter.Phase == PitchPlayPhase.Selecting)
                    _presenter.SubmitNeutralRelease();
            };
            release.RegisterCallback<PointerUpEvent>(evt =>
            {
                if (!_pointerCapture.EndRelease(evt.pointerId)) return;
                if (release.HasPointerCapture(evt.pointerId)) release.ReleasePointer(evt.pointerId);
                if (_presenter.Phase == PitchPlayPhase.Timing) _presenter.SubmitRelease();
                evt.StopPropagation();
            });
            release.RegisterCallback<PointerCancelEvent>(evt => CancelReleasePointer(release, evt.pointerId));
            release.RegisterCallback<PointerCaptureOutEvent>(evt => CancelReleasePointer(release, evt.pointerId));
            _releaseSlot.Add(release);
        }

        private void BuildCatcherSignControl()
        {
            _catcherSignButton = new SecondaryButton(
                "포수 사인 수락",
                "pitch-accept-catcher-sign",
                () => _presenter.AcceptCatcherSign());
            Require<VisualElement>("pitch-catcher-sign-slot").Add(_catcherSignButton);
        }

        private void BuildAbandonControl()
        {
            _exitStatusLabel = new Label();
            _exitStatusLabel.AddToClassList("pitch-exit-status");
            _exitStatusLabel.style.display = DisplayStyle.None;
            _abandonSlot.Add(_exitStatusLabel);
            if (_tutorial)
            {
                _abandonSlot.style.display = DisplayStyle.None;
                return;
            }
            _abandonButton = new DestructiveButton(
                "이닝 포기",
                "pitch-abandon-inning",
                ShowAbandonConfirmation);
            _abandonSlot.Add(_abandonButton);
        }

        private void BuildPresentationControls()
        {
            Require<VisualElement>("pitch-skip-slot").Add(new SecondaryButton(
                "결과 바로 보기",
                "pitch-skip-result",
                () => SkipRequested?.Invoke()));
            Require<VisualElement>("pitch-result-skip-slot").Add(new SecondaryButton(
                "결과 연출 건너뛰기",
                "pitch-skip-result-detail",
                () => SkipRequested?.Invoke()));
            _finishButton = new PrimaryPill(
                "승부 마무리",
                "pitch-finish",
                () => ExitRequested?.Invoke());
            Require<VisualElement>("pitch-result-action").Add(_finishButton);
        }

        private void ConfigureAimSurface()
        {
            _aimSurface.RegisterCallback<PointerDownEvent>(evt =>
            {
                if (evt.button != 0 || _presenter.Phase != PitchPlayPhase.Selecting ||
                    !_pointerCapture.TryBeginAim(evt.pointerId)) return;
                UpdateContinuousAim(evt.position);
                _aimSurface.CapturePointer(evt.pointerId);
                evt.StopPropagation();
            });
            _aimSurface.RegisterCallback<PointerMoveEvent>(evt =>
            {
                if (!_pointerCapture.OwnsAim(evt.pointerId) ||
                    !_aimSurface.HasPointerCapture(evt.pointerId) ||
                    _presenter.Phase != PitchPlayPhase.Selecting) return;
                UpdateContinuousAim(evt.position);
                evt.StopPropagation();
            });
            _aimSurface.RegisterCallback<PointerUpEvent>(evt =>
            {
                if (!_pointerCapture.EndAim(evt.pointerId)) return;
                if (_aimSurface.HasPointerCapture(evt.pointerId)) _aimSurface.ReleasePointer(evt.pointerId);
                evt.StopPropagation();
            });
            _aimSurface.RegisterCallback<PointerCancelEvent>(evt => CancelAimPointer(evt.pointerId));
            _aimSurface.RegisterCallback<PointerCaptureOutEvent>(evt => CancelAimPointer(evt.pointerId));
        }

        private void ConfigureStaticAccessibility()
        {
            _inningAccessibility = BaseballAccessibility.Configure(_inningLabel, "pitch-inning", "이닝", AccessibilityRole.StaticText, focusable: true);
            _countAccessibility = BaseballAccessibility.Configure(_countLabel, "pitch-count", "볼과 스트라이크", AccessibilityRole.StaticText, focusable: true);
            _batterAccessibility = BaseballAccessibility.Configure(_batterLabel, "pitch-batter", "타자", AccessibilityRole.Header, focusable: true);
            _recommendationAccessibility = BaseballAccessibility.Configure(
                _recommendationLabel,
                "pitch-catcher-recommendation",
                "포수 제안",
                AccessibilityRole.StaticText,
                focusable: true);
            _situationDetailAccessibility = ConfigureDetailAccessibility(
                _situationDetailLabel, "pitch-situation-detail", "경기 상황");
            _batterDetailAccessibility = ConfigureDetailAccessibility(
                _batterDetailLabel, "pitch-batter-detail", "타자 정보");
            _scoutingDetailAccessibility = ConfigureDetailAccessibility(
                _scoutingDetailLabel, "pitch-scouting-detail", "스카우팅 정보");
            _rivalDetailAccessibility = ConfigureDetailAccessibility(
                _rivalDetailLabel, "pitch-rival-detail", "라이벌 대응");
            _pitcherDetailAccessibility = ConfigureDetailAccessibility(
                _pitcherDetailLabel, "pitch-pitcher-detail", "투수 육성 능력");
            _aimAccessibility = BaseballAccessibility.Configure(
                _aimSurface,
                "pitch-continuous-aim",
                "연속 코스 선택",
                AccessibilityRole.Container,
                hint: "손가락으로 포수 미트 위치를 옮기거나 위의 아홉 칸을 선택하세요.",
                focusable: false);
            _resultAccessibility = BaseballAccessibility.Configure(
                _resultTitle,
                "pitch-result-summary",
                "투구 결과",
                AccessibilityRole.Header,
                focusable: true);
        }

        private void Render(PitchPlayViewState state)
        {
            PlateAppearanceSnapshot result = state.Result == null ? null : state.Result.Snapshot;
            _inningLabel.text = state.Context.Inning + "회 · " + state.Context.Outs + "아웃";
            int balls = result == null ? state.Context.Balls : result.Balls;
            int strikes = result == null ? state.Context.Strikes : result.Strikes;
            _countLabel.text = "볼 " + balls + " · 스트라이크 " + strikes;
            _batterLabel.text = "타자 " + state.Batter.Name;
            _inningAccessibility.Value = _inningLabel.text;
            _countAccessibility.Value = _countLabel.text;
            _batterAccessibility.Label = _batterLabel.text;
            PitchHudContent content = PitchHudProjection.Project(state);
            SetDetail(_situationDetailLabel, _situationDetailAccessibility, "경기 상황 · " + content.Situation);
            SetDetail(_batterDetailLabel, _batterDetailAccessibility, "타자 · " + content.Batter);
            SetDetail(_scoutingDetailLabel, _scoutingDetailAccessibility, "스카우팅 · " + content.Scouting);
            SetDetail(_rivalDetailLabel, _rivalDetailAccessibility, content.Rival);
            SetDetail(_pitcherDetailLabel, _pitcherDetailAccessibility, "육성 능력 · " + content.Pitcher);
            _tutorialCoachLabel.style.display = _tutorial ? DisplayStyle.Flex : DisplayStyle.None;
            if (_tutorial)
                _tutorialCoachLabel.text = PitchTutorialCoachCopy.For(state.Context.PitchNumber, strikes);
            _recommendationLabel.text = content.Recommendation;
            _recommendationAccessibility.Label = _recommendationLabel.text;
            if (_catcherSignButton != null)
            {
                _catcherSignButton.SetEnabled(state.Phase == PitchPlayPhase.Selecting && state.HoldsCall);
                _catcherSignButton.text = state.HoldsCall ? "포수 사인 수락" : "포수 사인 사용 중";
            }

            foreach (KeyValuePair<PitchType, Button> pair in _pitchButtons)
            {
                pair.Value.EnableInClassList("pitch-option-button--selected", pair.Key == state.PitchType);
                _pitchAccessibility[pair.Key].State = pair.Key == state.PitchType ? AccessibilityState.Selected : AccessibilityState.None;
            }
            foreach (KeyValuePair<PitchZone, Button> pair in _zoneButtons)
            {
                pair.Value.EnableInClassList("pitch-zone-cell--selected", pair.Key == state.Zone);
                _zoneAccessibility[pair.Key].State = pair.Key == state.Zone ? AccessibilityState.Selected : AccessibilityState.None;
            }
            _aimAccessibility.Value = PitchKoreanCopy.ZoneName(state.Zone) +
                ", 가로 " + Math.Round(state.NormalizedAimX, 2) + ", 세로 " + Math.Round(state.NormalizedAimY, 2);
            _synchronizingChoices = true;
            _intentChoice.Select(IntentId(state.Intent));
            _intensityChoice.Select(IntensityId(state.Intensity));
            _synchronizingChoices = false;
            PositionAimMarker(state.NormalizedAimX, state.NormalizedAimY);

            _inputPanel.style.display = state.Phase == PitchPlayPhase.Selecting ? DisplayStyle.Flex : DisplayStyle.None;
            _timingPanel.style.display = state.Phase == PitchPlayPhase.Timing ? DisplayStyle.Flex : DisplayStyle.None;
            _releaseSlot.style.display = state.Phase == PitchPlayPhase.Selecting || state.Phase == PitchPlayPhase.Timing
                ? DisplayStyle.Flex : DisplayStyle.None;
            _abandonSlot.style.display = !_tutorial && state.Phase == PitchPlayPhase.Selecting
                ? DisplayStyle.Flex : DisplayStyle.None;
            _presentingPanel.style.display = state.Phase == PitchPlayPhase.Presenting ? DisplayStyle.Flex : DisplayStyle.None;
            _resultPanel.style.display = state.Phase == PitchPlayPhase.Result || state.Phase == PitchPlayPhase.Completed
                ? DisplayStyle.Flex : DisplayStyle.None;
            _resultSkipSlot.style.display = state.Phase == PitchPlayPhase.Result ? DisplayStyle.Flex : DisplayStyle.None;
            SetAccessibilityActive(_inputPanel, state.Phase == PitchPlayPhase.Selecting);
            SetAccessibilityActive(_timingPanel, state.Phase == PitchPlayPhase.Timing);
            SetAccessibilityActive(_releaseSlot, state.Phase == PitchPlayPhase.Selecting || state.Phase == PitchPlayPhase.Timing);
            SetAccessibilityActive(_abandonSlot, !_tutorial && state.Phase == PitchPlayPhase.Selecting);
            SetAccessibilityActive(_presentingPanel, state.Phase == PitchPlayPhase.Presenting);
            SetAccessibilityActive(_resultPanel, state.Phase == PitchPlayPhase.Result || state.Phase == PitchPlayPhase.Completed);
            SetAccessibilityActive(_resultSkipSlot, state.Phase == PitchPlayPhase.Result);

            if (state.Phase == PitchPlayPhase.Presenting)
            {
                _presentingLabel.text = PitchKoreanCopy.PitchTypeName(state.PitchType) + "가 포수 미트로 향합니다";
            }
            if (!_postgameVisible && result != null &&
                (state.Phase == PitchPlayPhase.Result || state.Phase == PitchPlayPhase.Completed))
            {
                _resultTitle.text = PitchKoreanCopy.OutcomeName(result.Outcome);
                _resultDetail.text = result.ShortFeedback + "\n" + result.DetailFeedback +
                    (string.IsNullOrWhiteSpace(_committedMetricFeedback)
                        ? string.Empty
                        : "\n" + _committedMetricFeedback);
                _resultStats.text = result.Execution.VelocityTenthsKph / 10.0 + "km/h · 제구 결과 " + result.Execution.ExecutionQuality +
                    " · " + result.Balls + "볼 " + result.Strikes + "스트라이크";
                _resultAccessibility.Label = _resultTitle.text;
                _resultAccessibility.Value = _resultDetail.text + ". " + _resultStats.text;
                Require<VisualElement>("pitch-result-action").style.display = state.Phase == PitchPlayPhase.Completed
                    ? DisplayStyle.Flex : DisplayStyle.None;
            }
            RebuildAccessibility();
            if (state.Phase == PitchPlayPhase.Result) _accessibility.FocusScreen(_resultTitle);
        }

        private void UpdateContinuousAim(Vector3 worldPosition)
        {
            Vector2 local = _aimSurface.WorldToLocal(new Vector2(worldPosition.x, worldPosition.y));
            Rect rect = _aimSurface.contentRect;
            if (rect.width <= 0f || rect.height <= 0f) return;
            double x = local.x / rect.width * 2.0 - 1.0;
            double y = 1.0 - local.y / rect.height * 2.0;
            _presenter.SelectContinuousAim(x, y);
        }

        private void PositionAimMarker(double normalizedX, double normalizedY)
        {
            _aimMarker.style.left = Length.Percent((float)((normalizedX + 1.0) * 50.0));
            _aimMarker.style.top = Length.Percent((float)((1.0 - normalizedY) * 50.0));
        }

        private void RebuildAccessibility()
        {
            _accessibility?.Dispose();
            _accessibility = new BaseballAccessibilitySession(_root);
        }

        private static void SetAccessibilityActive(VisualElement element, bool active)
        {
            if (BaseballAccessibility.TryGet(element, out BaseballAccessibilityMetadata metadata)) metadata.IsActive = active;
            foreach (VisualElement child in element.Children()) SetAccessibilityActive(child, active);
        }

        private static BaseballAccessibilityMetadata ConfigureDetailAccessibility(
            Label label,
            string stableId,
            string accessibilityLabel) =>
            BaseballAccessibility.Configure(
                label,
                stableId,
                accessibilityLabel,
                AccessibilityRole.StaticText,
                focusable: true);

        private static void SetDetail(
            Label label,
            BaseballAccessibilityMetadata accessibility,
            string value)
        {
            label.text = value;
            accessibility.Value = value;
        }

        private void OnNavigationCancel(NavigationCancelEvent evt)
        {
            if (TryHandleBack()) evt.StopPropagation();
        }

        private void OnRootBlur(BlurEvent evt) => CancelActivePointers();

        private void OnDetachFromPanel(DetachFromPanelEvent evt) => CancelActivePointers();

        private void CancelAimPointer(int pointerId)
        {
            if (!_pointerCapture.CancelAim(pointerId)) return;
            if (_aimSurface.HasPointerCapture(pointerId)) _aimSurface.ReleasePointer(pointerId);
        }

        private void CancelReleasePointer(VisualElement release, int pointerId)
        {
            if (!_pointerCapture.CancelRelease(pointerId)) return;
            if (release.HasPointerCapture(pointerId)) release.ReleasePointer(pointerId);
            _presenter.CancelRelease();
        }

        private void CancelActivePointers()
        {
            int? aimPointer = _pointerCapture.AimPointerId;
            int? releasePointer = _pointerCapture.ReleasePointerId;
            bool releaseWasActive = _pointerCapture.CancelAll();
            if (aimPointer.HasValue && _aimSurface?.HasPointerCapture(aimPointer.Value) == true)
                _aimSurface.ReleasePointer(aimPointer.Value);
            if (releasePointer.HasValue && _releaseButton?.HasPointerCapture(releasePointer.Value) == true)
                _releaseButton.ReleasePointer(releasePointer.Value);
            if (releaseWasActive) _presenter.CancelRelease();
        }

        private T Require<T>(string name) where T : VisualElement
        {
            T element = _root.Q<T>(name);
            if (element == null) throw new InvalidOperationException("투구 UI 요소가 없습니다: " + name);
            return element;
        }

        private static string IntentId(ZoneIntent intent)
        {
            if (intent == ZoneIntent.Edge) return "pitch-intent-edge";
            return intent == ZoneIntent.Chase ? "pitch-intent-chase" : "pitch-intent-strike";
        }

        private static string IntensityId(PitchIntensity intensity)
        {
            if (intensity == PitchIntensity.Controlled) return "pitch-intensity-controlled";
            return intensity == PitchIntensity.MaxEffort ? "pitch-intensity-max" : "pitch-intensity-normal";
        }
    }
}
