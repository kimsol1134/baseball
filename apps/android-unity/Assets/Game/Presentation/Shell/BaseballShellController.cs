using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Baseball.Application.HighSchool;
using Baseball.Presentation.Common;
using Baseball.Presentation.Records;
using UnityEngine;
using UnityEngine.UIElements;

namespace Baseball.Presentation.Shell
{
    public interface IBaseballShellPreferences
    {
        bool HighContrast { get; }
        bool ReducedMotion { get; }
        void SetHighContrast(bool enabled);
        void SetReducedMotion(bool enabled);
    }

    public sealed class BaseballShellController : IShellNavigator, IBaseballShellPreferences,
        IBaseballShellSettings, IBaseballSetupDraft, IBaseballAdvancedSetupDraft,
        IBaseballCareerChoiceDraft, IBaseballVisualAssets, IBaseballLifeArchiveInteraction,
        IBaseballContentExposure, IDisposable
    {
        private readonly VisualElement _documentRoot;
        private readonly IBaseballCareerReadModel _readModel;
        private readonly IKoreanUiCopyCatalog _copy;
        private readonly IBaseballShellRuntime _runtime;
        private readonly Stack<ShellRoute> _history = new Stack<ShellRoute>();
        private readonly CancellationTokenSource _lifetime = new CancellationTokenSource();
        private readonly IBaseballLifeCardPngCapture _lifeCardPngCapture;
        private readonly ContentExposureDeduplicator _contentExposure =
            new ContentExposureDeduplicator();
        private VisualElement _shellRoot;
        private VisualElement _topBarHost;
        private VisualElement _screenHost;
        private VisualElement _bottomHost;
        private VisualElement _overlayHost;
        private BaseballThemeController _theme;
        private BaseballSafeAreaController _safeArea;
        private BaseballAccessibilitySession _accessibility;
        private IBaseballScreenController _screenController;
        private ModalSheet _activeModal;
        private ShellRoute _careerRoute = ShellRoute.Opening;
        private ShellRoute _pitchOrigin = ShellRoute.ImportantGame;
        private ShellRoute _pitchReturnRoute = ShellRoute.Awakening;
        private bool _disposed;
        private bool _actionInFlight;

        public ShellRoute CurrentRoute { get; private set; }
        public bool CanGoBack => _activeModal != null || _history.Count > 0;
        public bool HighContrast { get; private set; }
        public bool ReducedMotion { get; private set; }
        public bool AutoRelease => (_runtime as IBaseballShellSettings)?.AutoRelease ?? false;
        public bool SoundEnabled => (_runtime as IBaseballShellSettings)?.SoundEnabled ?? true;
        public bool MusicEnabled => (_runtime as IBaseballShellSettings)?.MusicEnabled ?? true;
        public bool HapticsEnabled => (_runtime as IBaseballShellSettings)?.HapticsEnabled ?? false;
        public bool NotificationsEnabled => (_runtime as IBaseballShellSettings)?.NotificationsEnabled ?? false;
        public bool CanUseNotifications => (_runtime as IBaseballShellSettings)?.CanUseNotifications ?? false;
        public bool NotificationSettingsRequired =>
            (_runtime as IBaseballShellSettings)?.NotificationSettingsRequired ?? false;
        public string NotificationsUnavailableReason =>
            (_runtime as IBaseballShellSettings)?.NotificationsUnavailableReason ?? "알림 서비스를 사용할 수 없습니다.";
        public string PlayerName => (_runtime as IBaseballSetupDraft)?.PlayerName ?? "한결";
        public string SuggestedPlayerName =>
            (_runtime as IBaseballSetupDraft)?.SuggestedPlayerName ?? "민서준";
        public string Region => (_runtime as IBaseballSetupDraft)?.Region ?? "서울";
        public string PresetId => (_runtime as IBaseballSetupDraft)?.PresetId ?? "power_prospect";
        public HighSchoolSetupReadModel SetupOptions =>
            (_runtime as IBaseballAdvancedSetupDraft)?.SetupOptions;
        public string SeedInput => (_runtime as IBaseballAdvancedSetupDraft)?.SeedInput ?? string.Empty;
        public string SeedValidationMessage =>
            (_runtime as IBaseballAdvancedSetupDraft)?.SeedValidationMessage ?? string.Empty;
        public string SetupDifficulty =>
            (_runtime as IBaseballAdvancedSetupDraft)?.SetupDifficulty ?? "standard";
        public string SetupSoulDomain =>
            (_runtime as IBaseballAdvancedSetupDraft)?.SetupSoulDomain ?? string.Empty;
        public string SetupSignatureLegacy =>
            (_runtime as IBaseballAdvancedSetupDraft)?.SetupSignatureLegacy ?? string.Empty;
        public IReadOnlyList<string> SetupKarmas =>
            (_runtime as IBaseballAdvancedSetupDraft)?.SetupKarmas ?? Array.Empty<string>();
        public IReadOnlyList<string> SetupSoulBoosts =>
            (_runtime as IBaseballAdvancedSetupDraft)?.SetupSoulBoosts ?? Array.Empty<string>();
        public IReadOnlyList<string> SetupMemories =>
            (_runtime as IBaseballAdvancedSetupDraft)?.SetupMemories ?? Array.Empty<string>();
        public IBaseballVisualAssetLoader VisualAssetLoader =>
            (_runtime as IBaseballVisualAssets)?.VisualAssetLoader;
        public event Action<PitchHandoffViewModel> PitchRequested;

        public BaseballShellController(
            VisualElement documentRoot,
            IBaseballCareerReadModel readModel,
            IKoreanUiCopyCatalog copy,
            ShellRoute initialRoute = ShellRoute.Opening,
            IBaseballLifeCardPngCapture lifeCardPngCapture = null)
        {
            _documentRoot = documentRoot ?? throw new ArgumentNullException(nameof(documentRoot));
            _readModel = readModel ?? throw new ArgumentNullException(nameof(readModel));
            _copy = copy ?? throw new ArgumentNullException(nameof(copy));
            _runtime = readModel as IBaseballShellRuntime;
            _lifeCardPngCapture = lifeCardPngCapture ?? new ScreenLifeCardPngCapture();
            if (_runtime != null) _runtime.Changed += OnRuntimeChanged;
            IBaseballShellSettings settings = _runtime as IBaseballShellSettings;
            HighContrast = settings?.HighContrast ?? false;
            ReducedMotion = settings?.ReducedMotion ?? false;
            CurrentRoute = NormalizeRetiredDailyRoute(initialRoute, _runtime);
            BuildShell();
            _theme.SetHighContrast(HighContrast);
            _theme.SetReducedMotion(ReducedMotion);
            Render();
            (_runtime as IBaseballExternalNavigation)?.AcknowledgeExternalRoute(CurrentRoute);
        }

        public void Navigate(ShellRoute route)
        {
            CloseModal();
            route = NormalizeRetiredDailyRoute(route, _runtime);
            if (CurrentRoute == ShellRoute.PitchHandoff && route == ShellRoute.Awakening)
            {
                route = _pitchReturnRoute;
            }
            if (route == CurrentRoute)
            {
                if (route == ShellRoute.PitchHandoff)
                {
                    ResumePitchIfNeeded();
                    return;
                }
                Announce(_copy.Get("shell.already_here"));
                return;
            }
            if (route == ShellRoute.PitchHandoff)
            {
                _pitchOrigin = CurrentRoute;
                _pitchReturnRoute = CurrentRoute == ShellRoute.Daily
                    ? NormalizeRetiredDailyRoute(CurrentRoute, _runtime)
                    : ShellRoute.Awakening;
            }
            _history.Push(CurrentRoute);
            CurrentRoute = route;
            RememberCareerRoute(route);
            Render();
            if (CurrentRoute == ShellRoute.PitchHandoff)
            {
                PitchRequested?.Invoke(new PitchHandoffViewModel(_pitchOrigin, _pitchReturnRoute));
            }
        }

        public void CompletePitchHandoff()
        {
            if (CurrentRoute != ShellRoute.PitchHandoff) return;
            Navigate(ResolvePitchReturnRoute(
                _runtime?.Status ?? ShellRuntimeStatus.Unavailable,
                _runtime?.PreferredRoute ?? ShellRoute.PitchHandoff,
                _pitchReturnRoute));
        }

        public static ShellRoute ResolvePitchReturnRoute(
            ShellRuntimeStatus runtimeStatus,
            ShellRoute preferredRoute,
            ShellRoute fallbackRoute)
        {
            ShellRoute resolved = runtimeStatus == ShellRuntimeStatus.Ready && preferredRoute != ShellRoute.PitchHandoff
                ? preferredRoute
                : fallbackRoute;
            return resolved == ShellRoute.Daily
                ? fallbackRoute == ShellRoute.Daily ? ShellRoute.Opening : fallbackRoute
                : resolved;
        }

        public static ShellRoute ResolveInitialRoute(IBaseballShellRuntime runtime)
        {
            if (runtime == null) return ShellRoute.Opening;
            if (runtime is IBaseballExternalNavigation external &&
                external.TryConsumeExternalRoute(out ShellRoute externalRoute))
            {
                return NormalizeRetiredDailyRoute(externalRoute, runtime);
            }
            return ShouldHoldOpening(runtime)
                ? ShellRoute.Opening
                : NormalizeRetiredDailyRoute(runtime.PreferredRoute, runtime);
        }

        public static ShellRoute NormalizeRetiredDailyRoute(
            ShellRoute route,
            IBaseballShellRuntime runtime)
        {
            if (route != ShellRoute.Daily) return route;
            ShellRoute fallback =
                (runtime as IBaseballRetiredDailyRouteFallback)?.RetiredDailyFallbackRoute ??
                ShellRoute.Opening;
            return fallback == ShellRoute.Daily || fallback == ShellRoute.PitchHandoff
                ? ShellRoute.Opening
                : fallback;
        }

        public void ResumePitchIfNeeded()
        {
            if (CurrentRoute != ShellRoute.PitchHandoff) return;
            PitchHandoffViewModel handoff = (_runtime as IBaseballPitchNavigation)?.ResumeHandoff ??
                new PitchHandoffViewModel(_pitchOrigin, _pitchReturnRoute);
            _pitchOrigin = handoff.Origin;
            _pitchReturnRoute = handoff.ReturnRoute;
            PitchRequested?.Invoke(handoff);
        }

        public void SetPitchPresentationActive(bool active)
        {
            _shellRoot.style.display = active ? DisplayStyle.None : DisplayStyle.Flex;
        }

        public bool TryGoBack()
        {
            if (_activeModal != null)
            {
                CloseModal();
                Announce(_copy.Get("shell.dialog_closed"));
                return true;
            }
            if (_history.Count == 0) return false;
            CurrentRoute = _history.Pop();
            RememberCareerRoute(CurrentRoute);
            Render();
            return true;
        }

        public void ShowConfirmation(ScreenActionViewModel action)
        {
            if (action == null) throw new ArgumentNullException(nameof(action));
            CloseModal();
            string stableId = "shell-confirm-" + action.Id;
            var dialog = new ConfirmationDialog(
                _copy.Get("shell.confirm.title"),
                action.Hint.Length > 0 ? action.Hint : _copy.Get("shell.confirm.message"),
                action.Label,
                _copy.Get("shell.confirm.cancel"),
                stableId,
                () =>
                {
                    CloseModal();
                    Execute(action);
                },
                CloseModal,
                action.Style == ScreenActionStyle.Destructive);
            _activeModal = dialog;
            _overlayHost.style.display = DisplayStyle.Flex;
            _overlayHost.Add(dialog);
            RebuildAccessibility();
            dialog.schedule.Execute(dialog.FocusFirstControl);
        }

        public async void Execute(ScreenActionViewModel action)
        {
            if (action == null) throw new ArgumentNullException(nameof(action));
            if (_actionInFlight)
            {
                Announce("처리 중입니다. 잠시만 기다려 주세요.");
                return;
            }
            if (!action.IsEnabled)
            {
                ShowStatus(string.IsNullOrWhiteSpace(action.DisabledReason) ? action.Hint : action.DisabledReason, true);
                return;
            }
            if (_runtime == null)
            {
                Navigate(action.Target);
                return;
            }

            _actionInFlight = true;
            _shellRoot.SetEnabled(false);
            ShowStatus("저장하는 중입니다…", false);
            try
            {
                ShellActionResult result;
                if (action.Id == "share_life_card" && _runtime is IBaseballLifeCardShareRuntime shareRuntime)
                {
                    byte[] pngBytes = null;
                    VisualElement card = _screenHost.Q<VisualElement>("life-card-capture");
                    if (card != null)
                    {
                        try { pngBytes = await _lifeCardPngCapture.CaptureAsync(card, _lifetime.Token); }
                        catch (OperationCanceledException) when (_lifetime.IsCancellationRequested) { throw; }
                        catch { /* The runtime falls back to text when capture is unavailable. */ }
                    }
                    result = await shareRuntime.ShareLifeCardAsync(pngBytes, _lifetime.Token);
                }
                else
                {
                    result = await _runtime.ExecuteAsync(CurrentRoute, action, _lifetime.Token);
                }
                if (_disposed) return;
                if (!result.Succeeded)
                {
                    ShowStatus(string.IsNullOrWhiteSpace(result.Message) ? "저장하지 못했습니다. 다시 시도해 주세요." : result.Message, true);
                    return;
                }
                if (!string.IsNullOrWhiteSpace(result.Message)) Announce(result.Message);
                if (result.Destination.HasValue) Navigate(result.Destination.Value);
                else Render();
            }
            catch (OperationCanceledException) when (_lifetime.IsCancellationRequested)
            {
            }
            catch (Exception)
            {
                if (!_disposed) ShowStatus("처리 중 문제가 생겼습니다. 저장 상태를 확인한 뒤 다시 시도해 주세요.", true);
            }
            finally
            {
                _actionInFlight = false;
                if (!_disposed) _shellRoot.SetEnabled(true);
            }
        }

        public void Announce(string message)
        {
            _accessibility?.Announce(message);
        }

        public void SetHighContrast(bool enabled)
        {
            HighContrast = enabled;
            (_runtime as IBaseballShellSettings)?.SetHighContrast(enabled);
            _theme.SetHighContrast(enabled);
            Announce(enabled ? _copy.Get("settings.enabled") : _copy.Get("settings.disabled"));
        }

        public void SetReducedMotion(bool enabled)
        {
            ReducedMotion = enabled;
            (_runtime as IBaseballShellSettings)?.SetReducedMotion(enabled);
            _theme.SetReducedMotion(enabled);
            Announce(enabled ? _copy.Get("settings.enabled") : _copy.Get("settings.disabled"));
        }

        public void ApplySystemFontScaleForTesting(float scale)
        {
            _theme.ApplyFontScale(scale);
        }

        public void SetAutoRelease(bool enabled) =>
            (_runtime as IBaseballShellSettings)?.SetAutoRelease(enabled);

        public void SetSoundEnabled(bool enabled) =>
            (_runtime as IBaseballShellSettings)?.SetSoundEnabled(enabled);

        public void SetMusicEnabled(bool enabled) =>
            (_runtime as IBaseballShellSettings)?.SetMusicEnabled(enabled);

        public void SetHapticsEnabled(bool enabled) =>
            (_runtime as IBaseballShellSettings)?.SetHapticsEnabled(enabled);

        public void SetNotificationsEnabled(bool enabled) =>
            (_runtime as IBaseballShellSettings)?.SetNotificationsEnabled(enabled);

        public void OpenNotificationSettings() =>
            (_runtime as IBaseballShellSettings)?.OpenNotificationSettings();

        public void SetPlayerName(string value) =>
            (_runtime as IBaseballSetupDraft)?.SetPlayerName(value);

        public void SetRegion(string value) =>
            (_runtime as IBaseballSetupDraft)?.SetRegion(value);

        public void SetPresetId(string value) =>
            (_runtime as IBaseballSetupDraft)?.SetPresetId(value);

        public void SetSeedInput(string value) =>
            (_runtime as IBaseballAdvancedSetupDraft)?.SetSeedInput(value);

        public void SetSetupSingle(string group, string payload) =>
            (_runtime as IBaseballAdvancedSetupDraft)?.SetSetupSingle(group, payload);

        public void ToggleSetupMulti(string group, string payload) =>
            (_runtime as IBaseballAdvancedSetupDraft)?.ToggleSetupMulti(group, payload);

        public bool IsSetupSelected(string group, string payload) =>
            (_runtime as IBaseballAdvancedSetupDraft)?.IsSetupSelected(group, payload) == true;

        public string GetChoice(string group) =>
            (_runtime as IBaseballCareerChoiceDraft)?.GetChoice(group) ?? string.Empty;

        public void SetChoice(string group, string payload) =>
            (_runtime as IBaseballCareerChoiceDraft)?.SetChoice(group, payload);

        public IReadOnlyList<string> GetChoices(string group) =>
            (_runtime as IBaseballCareerChoiceDraft)?.GetChoices(group) ?? Array.Empty<string>();

        public void ToggleChoice(string group, string payload, int maximumSelections) =>
            (_runtime as IBaseballCareerChoiceDraft)?.ToggleChoice(group, payload, maximumSelections);

        public bool IsChoiceSelected(string group, string payload) =>
            (_runtime as IBaseballCareerChoiceDraft)?.IsChoiceSelected(group, payload) == true;

        public void OnLifeArchiveVisible(string lifeNumber) =>
            (_runtime as IBaseballLifeArchiveInteraction)?.OnLifeArchiveVisible(lifeNumber);

        public void OnContentVisible(ShellRoute route, string contentId, string instanceId)
        {
            if (!_contentExposure.TryMark(route.ToString(), contentId, instanceId)) return;
            (_runtime as IBaseballContentExposure)?.OnContentVisible(route, contentId, instanceId);
        }

        public void HandleHardwareBack()
        {
            TryGoBack();
        }

        public void Dispose()
        {
            if (_disposed) return;
            _lifetime.Cancel();
            if (_runtime != null) _runtime.Changed -= OnRuntimeChanged;
            _documentRoot.UnregisterCallback<NavigationCancelEvent>(OnNavigationCancel);
            _screenController?.Dispose();
            _accessibility?.Dispose();
            _safeArea?.Dispose();
            _theme?.Dispose();
            PitchRequested = null;
            _lifetime.Dispose();
            _disposed = true;
        }

        private void BuildShell()
        {
            _documentRoot.Clear();
            VisualTreeAsset template = Resources.Load<VisualTreeAsset>("BaseballShell");
            if (template == null) throw new InvalidOperationException("UI Toolkit shell 템플릿을 찾을 수 없습니다: BaseballShell");
            template.CloneTree(_documentRoot);
            _shellRoot = Require<VisualElement>(_documentRoot, "shell-root");
            _topBarHost = Require<VisualElement>(_documentRoot, "shell-topbar");
            _screenHost = Require<VisualElement>(_documentRoot, "shell-screen");
            _bottomHost = Require<VisualElement>(_documentRoot, "shell-bottom");
            _overlayHost = Require<VisualElement>(_documentRoot, "shell-overlay");
            _overlayHost.style.display = DisplayStyle.None;
            _theme = new BaseballThemeController(_shellRoot);
            _safeArea = new BaseballSafeAreaController(_shellRoot);
            _documentRoot.RegisterCallback<NavigationCancelEvent>(OnNavigationCancel);
        }

        private void Render()
        {
            BaseballScreenViewModel viewModel = _readModel.Read(CurrentRoute);
            _screenController?.Dispose();
            _topBarHost.Clear();
            _screenHost.Clear();
            _bottomHost.Clear();

            var topBar = new TopAppBar(
                viewModel.AppBarTitle,
                "shell-appbar-title",
                CanGoBack ? new BackButton("shell-back", () => TryGoBack()) : null);
            _topBarHost.Add(topBar);

            _screenController = BaseballScreenControllerFactory.Create(CurrentRoute);
            _screenController.Mount(_screenHost, viewModel, this);

            if (viewModel.ShowsBottomNavigation)
            {
                BottomNavigation bottom = BuildBottomNavigation();
                _bottomHost.Add(bottom);
                _bottomHost.style.display = DisplayStyle.Flex;
            }
            else
            {
                _bottomHost.style.display = DisplayStyle.None;
            }
            RebuildAccessibility();
            _accessibility.FocusScreen(_screenHost.Q<Label>("screen-title"));
            (_runtime as IBaseballShellRouteObserver)?.OnRouteChanged(
                CurrentRoute,
                CurrentRoute == ShellRoute.PitchHandoff);
        }

        private void OnRuntimeChanged()
        {
            if (_disposed) return;
            IBaseballShellSettings settings = _runtime as IBaseballShellSettings;
            if (settings != null)
            {
                HighContrast = settings.HighContrast;
                ReducedMotion = settings.ReducedMotion;
                _theme.SetHighContrast(HighContrast);
                _theme.SetReducedMotion(ReducedMotion);
            }
            bool resumePitch = false;
            bool consumedExternalRoute = false;
            IBaseballExternalNavigation externalNavigation = null;
            if (!_actionInFlight && _runtime != null && _runtime.Status == ShellRuntimeStatus.Ready &&
                _runtime is IBaseballExternalNavigation external &&
                external.TryConsumeExternalRoute(out ShellRoute externalRoute))
            {
                externalNavigation = external;
                consumedExternalRoute = true;
                _history.Clear();
                CurrentRoute = externalRoute;
                RememberCareerRoute(externalRoute);
                resumePitch = externalRoute == ShellRoute.PitchHandoff;
            }
            if (!consumedExternalRoute && !_actionInFlight && _runtime != null &&
                _runtime.Status == ShellRuntimeStatus.Ready &&
                (CurrentRoute == ShellRoute.Opening || CurrentRoute == ShellRoute.Setup))
            {
                bool holdOpening = ShouldHoldOpening(_runtime);
                ShellRoute preferred = holdOpening ? ShellRoute.Opening : _runtime.PreferredRoute;
                if (preferred != CurrentRoute)
                {
                    _history.Clear();
                    CurrentRoute = preferred;
                    resumePitch = preferred == ShellRoute.PitchHandoff;
                }
            }
            Render();
            externalNavigation?.AcknowledgeExternalRoute(CurrentRoute);
            if (resumePitch) ResumePitchIfNeeded();
            if (_runtime != null && !string.IsNullOrWhiteSpace(_runtime.StatusMessage))
                Announce(_runtime.StatusMessage);
        }

        private static bool ShouldHoldOpening(IBaseballShellRuntime runtime) =>
            runtime is IBaseballOpeningPresentationGate gate &&
            gate.ShouldHoldOpeningForReturnPlan;

        private void ShowStatus(string message, bool warning)
        {
            if (string.IsNullOrWhiteSpace(message)) return;
            VisualElement previous = _screenHost.Q<VisualElement>("shell-action-status");
            previous?.RemoveFromHierarchy();
            var callout = new BaseballCallout(
                warning ? "처리하지 못했어요" : "진행 중",
                warning ? BaseballCalloutTone.Warning : BaseballCalloutTone.Information,
                "shell-action-status");
            callout.Content.Add(new Label(message));
            _screenHost.Insert(0, callout);
            Announce(message);
        }

        private BottomNavigation BuildBottomNavigation()
        {
            var bottom = new BottomNavigation("shell-bottom-navigation");
            bottom.AddItem("shell-nav-career", _copy.Get("shell.nav.career"), () => Navigate(_careerRoute));
            bottom.AddItem("shell-nav-records", _copy.Get("shell.nav.records"), () => Navigate(ShellRoute.Records));
            bottom.AddItem("shell-nav-settings", _copy.Get("shell.nav.settings"), () => Navigate(ShellRoute.Settings));
            switch (_readModel.Read(CurrentRoute).Feature)
            {
                case "meta": bottom.Select("shell-nav-records"); break;
                case "records": bottom.Select("shell-nav-records"); break;
                case "settings": bottom.Select("shell-nav-settings"); break;
                default: bottom.Select("shell-nav-career"); break;
            }
            return bottom;
        }

        private void RememberCareerRoute(ShellRoute route)
        {
            string feature = _readModel.Read(route).Feature;
            if (feature == "opening" || feature == "setup" || feature == "highschool" || feature == "pro") _careerRoute = route;
        }

        private void CloseModal()
        {
            if (_activeModal == null) return;
            _activeModal.RemoveFromHierarchy();
            _activeModal = null;
            _overlayHost.style.display = DisplayStyle.None;
            RebuildAccessibility();
        }

        private void RebuildAccessibility()
        {
            _accessibility?.Dispose();
            _accessibility = new BaseballAccessibilitySession(_activeModal ?? _shellRoot);
        }

        private void OnNavigationCancel(NavigationCancelEvent evt)
        {
            if (TryGoBack()) evt.StopPropagation();
        }

        private static T Require<T>(VisualElement root, string name) where T : VisualElement
        {
            T element = root.Q<T>(name);
            if (element == null) throw new InvalidOperationException($"Shell UI Toolkit 요소를 찾을 수 없습니다: {name}");
            return element;
        }
    }
}
