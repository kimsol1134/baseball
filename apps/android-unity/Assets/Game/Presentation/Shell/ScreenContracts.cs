using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Baseball.Application.HighSchool;
using UnityEngine;

namespace Baseball.Presentation.Shell
{
    public enum ShellRoute
    {
        Opening,
        Setup,
        Prologue,
        HighSchoolOverview,
        Training,
        Relationship,
        ImportantGame,
        PitchHandoff,
        Awakening,
        Draft,
        RunRecap,
        ProContract,
        ProWeek,
        ProSeason,
        ProRetirement,
        Daily,
        Weekly,
        Records,
        League,
        Achievements,
        LifeArchive,
        LifeCard,
        Settings,
    }

    public enum ScreenSectionTone
    {
        Plain,
        Information,
        Positive,
        Warning,
        Milestone,
    }

    public enum ScreenActionStyle
    {
        Primary,
        Secondary,
        Destructive,
    }

    public sealed class ScreenRowViewModel
    {
        public string Id { get; }
        public string Label { get; }
        public string Value { get; }
        public string Detail { get; }

        public ScreenRowViewModel(string id, string label, string value = null, string detail = null)
        {
            Id = Require(id, nameof(id));
            Label = Require(label, nameof(label));
            Value = value ?? string.Empty;
            Detail = detail ?? string.Empty;
        }

        private static string Require(string value, string name)
        {
            if (string.IsNullOrWhiteSpace(value)) throw new ArgumentException("A non-empty value is required.", name);
            return value;
        }
    }

    public sealed class ScreenSectionViewModel
    {
        public string Id { get; }
        public string Heading { get; }
        public ScreenSectionTone Tone { get; }
        public IReadOnlyList<ScreenRowViewModel> Rows { get; }

        public ScreenSectionViewModel(
            string id,
            string heading,
            ScreenSectionTone tone,
            IReadOnlyList<ScreenRowViewModel> rows)
        {
            Id = string.IsNullOrWhiteSpace(id) ? throw new ArgumentException("A section ID is required.", nameof(id)) : id;
            Heading = string.IsNullOrWhiteSpace(heading) ? throw new ArgumentException("A heading is required.", nameof(heading)) : heading;
            Tone = tone;
            Rows = rows ?? Array.Empty<ScreenRowViewModel>();
        }
    }

    public sealed class ScreenActionViewModel
    {
        public string Id { get; }
        public string Label { get; }
        public string Hint { get; }
        public ShellRoute Target { get; }
        public ScreenActionStyle Style { get; }
        public bool RequiresConfirmation { get; }
        public bool IsEnabled { get; }
        public string DisabledReason { get; }

        public ScreenActionViewModel(
            string id,
            string label,
            ShellRoute target,
            ScreenActionStyle style = ScreenActionStyle.Secondary,
            string hint = null,
            bool requiresConfirmation = false,
            bool isEnabled = true,
            string disabledReason = null)
        {
            Id = string.IsNullOrWhiteSpace(id) ? throw new ArgumentException("An action ID is required.", nameof(id)) : id;
            Label = string.IsNullOrWhiteSpace(label) ? throw new ArgumentException("An action label is required.", nameof(label)) : label;
            Target = target;
            Style = style;
            Hint = hint ?? string.Empty;
            RequiresConfirmation = requiresConfirmation;
            IsEnabled = isEnabled;
            DisabledReason = disabledReason ?? string.Empty;
        }
    }

    public sealed class ScreenChoiceOptionViewModel
    {
        public ScreenChoiceOptionViewModel(
            string id,
            string title,
            string payload,
            string detail = null,
            string effectSummary = null,
            bool isEnabled = true,
            string disabledReason = null,
            string artworkAddress = null,
            string secondaryArtworkAddress = null)
        {
            Id = string.IsNullOrWhiteSpace(id) ? throw new ArgumentException("A choice ID is required.", nameof(id)) : id;
            Title = string.IsNullOrWhiteSpace(title) ? throw new ArgumentException("A choice title is required.", nameof(title)) : title;
            Payload = string.IsNullOrWhiteSpace(payload) ? throw new ArgumentException("A choice payload is required.", nameof(payload)) : payload;
            Detail = detail ?? string.Empty;
            EffectSummary = effectSummary ?? string.Empty;
            IsEnabled = isEnabled;
            DisabledReason = disabledReason ?? string.Empty;
            ArtworkAddress = artworkAddress ?? string.Empty;
            SecondaryArtworkAddress = secondaryArtworkAddress ?? string.Empty;
        }

        public string Id { get; }
        public string Title { get; }
        public string Payload { get; }
        public string Detail { get; }
        public string EffectSummary { get; }
        public bool IsEnabled { get; }
        public string DisabledReason { get; }
        public string ArtworkAddress { get; }
        public string SecondaryArtworkAddress { get; }
    }

    public sealed class ScreenChoiceGroupViewModel
    {
        public ScreenChoiceGroupViewModel(
            string id,
            string heading,
            string detail,
            IReadOnlyList<ScreenChoiceOptionViewModel> choices,
            int maximumSelections = 1)
        {
            Id = string.IsNullOrWhiteSpace(id) ? throw new ArgumentException("A choice group ID is required.", nameof(id)) : id;
            Heading = string.IsNullOrWhiteSpace(heading) ? throw new ArgumentException("A choice heading is required.", nameof(heading)) : heading;
            Detail = detail ?? string.Empty;
            Choices = choices ?? Array.Empty<ScreenChoiceOptionViewModel>();
            MaximumSelections = Math.Max(1, maximumSelections);
        }

        public string Id { get; }
        public string Heading { get; }
        public string Detail { get; }
        public IReadOnlyList<ScreenChoiceOptionViewModel> Choices { get; }
        public int MaximumSelections { get; }
        public bool AllowsMultiple => MaximumSelections > 1;
    }

    /// <summary>Immutable presentation contract shared by production projections and test fixtures.</summary>
    public sealed class BaseballScreenViewModel
    {
        public ShellRoute Route { get; }
        public string Feature { get; }
        public string AppBarTitle { get; }
        public string Eyebrow { get; }
        public string Title { get; }
        public string Lead { get; }
        public IReadOnlyList<ScreenSectionViewModel> Sections { get; }
        public IReadOnlyList<ScreenActionViewModel> Actions { get; }
        public bool ShowsBottomNavigation { get; }
        public string KeyArtAddress { get; }
        public IReadOnlyList<ScreenChoiceGroupViewModel> ChoiceGroups { get; }
        public string PlayerPortraitAddress { get; }
        public string PlayerPortraitLabel { get; }

        public BaseballScreenViewModel(
            ShellRoute route,
            string feature,
            string appBarTitle,
            string eyebrow,
            string title,
            string lead,
            IReadOnlyList<ScreenSectionViewModel> sections,
            IReadOnlyList<ScreenActionViewModel> actions,
            bool showsBottomNavigation = true,
            string keyArtAddress = null,
            IReadOnlyList<ScreenChoiceGroupViewModel> choiceGroups = null,
            string playerPortraitAddress = null,
            string playerPortraitLabel = null)
        {
            Route = route;
            Feature = feature ?? string.Empty;
            AppBarTitle = appBarTitle ?? string.Empty;
            Eyebrow = eyebrow ?? string.Empty;
            Title = string.IsNullOrWhiteSpace(title) ? throw new ArgumentException("A screen title is required.", nameof(title)) : title;
            Lead = lead ?? string.Empty;
            Sections = sections ?? Array.Empty<ScreenSectionViewModel>();
            Actions = actions ?? Array.Empty<ScreenActionViewModel>();
            ShowsBottomNavigation = showsBottomNavigation;
            KeyArtAddress = keyArtAddress ?? string.Empty;
            ChoiceGroups = choiceGroups ?? Array.Empty<ScreenChoiceGroupViewModel>();
            PlayerPortraitAddress = playerPortraitAddress ?? string.Empty;
            PlayerPortraitLabel = playerPortraitLabel ?? string.Empty;
        }
    }

    public interface IBaseballCareerReadModel
    {
        IReadOnlyList<ShellRoute> Routes { get; }
        BaseballScreenViewModel Read(ShellRoute route);
    }

    public interface IShellNavigator
    {
        ShellRoute CurrentRoute { get; }
        bool CanGoBack { get; }
        void Navigate(ShellRoute route);
        bool TryGoBack();
        void ShowConfirmation(ScreenActionViewModel action);
        void Execute(ScreenActionViewModel action);
        void Announce(string message);
    }

    public enum ShellRuntimeStatus
    {
        Loading,
        Ready,
        StartupFailed,
        Unavailable,
    }

    public readonly struct ShellActionResult
    {
        public ShellActionResult(bool succeeded, ShellRoute? destination, string message)
        {
            Succeeded = succeeded;
            Destination = destination;
            Message = message ?? string.Empty;
        }

        public bool Succeeded { get; }
        public ShellRoute? Destination { get; }
        public string Message { get; }

        public static ShellActionResult Success(ShellRoute? destination = null, string message = null) =>
            new ShellActionResult(true, destination, message);

        public static ShellActionResult Failure(string message) =>
            new ShellActionResult(false, null, message);
    }

    public interface IBaseballShellRuntime : IBaseballCareerReadModel, IDisposable
    {
        event Action Changed;
        ShellRuntimeStatus Status { get; }
        ShellRoute PreferredRoute { get; }
        bool IsBusy { get; }
        string StatusMessage { get; }
        Task<ShellActionResult> ExecuteAsync(
            ShellRoute route,
            ScreenActionViewModel action,
            CancellationToken cancellationToken);
        void RetryStartup();
    }

    public interface IBaseballSetupDraft
    {
        string PlayerName { get; }
        string SuggestedPlayerName { get; }
        string Region { get; }
        string PresetId { get; }
        void SetPlayerName(string value);
        void SetRegion(string value);
        void SetPresetId(string value);
    }

    public interface IBaseballAdvancedSetupDraft
    {
        HighSchoolSetupReadModel SetupOptions { get; }
        string SeedInput { get; }
        string SeedValidationMessage { get; }
        string SetupDifficulty { get; }
        string SetupSoulDomain { get; }
        string SetupSignatureLegacy { get; }
        IReadOnlyList<string> SetupKarmas { get; }
        IReadOnlyList<string> SetupSoulBoosts { get; }
        IReadOnlyList<string> SetupMemories { get; }
        void SetSeedInput(string value);
        void SetSetupSingle(string group, string payload);
        void ToggleSetupMulti(string group, string payload);
        bool IsSetupSelected(string group, string payload);
    }

    public interface IBaseballCareerChoiceDraft
    {
        string GetChoice(string group);
        void SetChoice(string group, string payload);
        IReadOnlyList<string> GetChoices(string group);
        void ToggleChoice(string group, string payload, int maximumSelections);
        bool IsChoiceSelected(string group, string payload);
    }

    /// <summary>Clears UI-only selections before leaving a screen without submitting them.</summary>
    public interface IBaseballTransientDraftDiscard
    {
        void DiscardTransientDraft(ShellRoute route);
    }

    public interface IBaseballTrainingCelebrationSource
    {
        bool TryTakeTrainingCelebration(out TrainingCelebrationViewModel celebration);
    }

    /// <summary>Platform boundary for Android's explicit root double-back exit contract.</summary>
    public interface IBaseballApplicationExit
    {
        void ExitApplication();
    }

    public interface IBaseballShellSettings
    {
        bool AutoRelease { get; }
        bool SoundEnabled { get; }
        bool MusicEnabled { get; }
        bool HapticsEnabled { get; }
        bool NotificationsEnabled { get; }
        bool HighContrast { get; }
        bool ReducedMotion { get; }
        bool CanUseNotifications { get; }
        bool NotificationSettingsRequired { get; }
        string NotificationsUnavailableReason { get; }
        void SetAutoRelease(bool enabled);
        void SetSoundEnabled(bool enabled);
        void SetMusicEnabled(bool enabled);
        void SetHapticsEnabled(bool enabled);
        void SetNotificationsEnabled(bool enabled);
        void OpenNotificationSettings();
        void SetHighContrast(bool enabled);
        void SetReducedMotion(bool enabled);
    }

    public interface IBaseballVisualAssetLease : IDisposable
    {
        Sprite Sprite { get; }
    }

    public interface IBaseballVisualAssetLoader
    {
        Task<IBaseballVisualAssetLease> LoadSpriteAsync(string address, CancellationToken cancellationToken);
    }

    public interface IBaseballVisualAssets
    {
        IBaseballVisualAssetLoader VisualAssetLoader { get; }
    }

    public interface IBaseballLifeCardPngCapture
    {
        Task<byte[]> CaptureAsync(
            UnityEngine.UIElements.VisualElement card,
            CancellationToken cancellationToken);
    }

    public interface IBaseballLifeCardShareRuntime
    {
        Task<ShellActionResult> ShareLifeCardAsync(
            byte[] pngBytes,
            CancellationToken cancellationToken);
    }

    public interface IBaseballLifeArchiveInteraction
    {
        void OnLifeArchiveVisible(string lifeNumber);
    }

    /// <summary>Reports a content card only after it enters the rendered screen viewport.</summary>
    public interface IBaseballContentExposure
    {
        Task<bool> OnContentVisibleAsync(
            ShellRoute route,
            string contentId,
            string instanceId,
            CancellationToken cancellationToken);
    }

    public interface IBaseballShellRouteObserver
    {
        void OnRouteChanged(ShellRoute route);
    }

    /// <summary>
    /// Keeps a saved next-day guided return card on the Opening surface until the user explicitly
    /// continues or dismisses it. Holdout and ineligible users follow their saved career route.
    /// </summary>
    public interface IBaseballOpeningPresentationGate
    {
        bool ShouldHoldOpeningForReturnPlan { get; }
    }

    /// <summary>Safe target for links that still decode the retired daily-inning route.</summary>
    public interface IBaseballRetiredDailyRouteFallback
    {
        ShellRoute RetiredDailyFallbackRoute { get; }
    }

    public interface IBaseballShellLifecycleObserver
    {
        void OnApplicationPause(bool paused);
    }

    public interface IBaseballExternalNavigation
    {
        bool TryConsumeExternalRoute(out ShellRoute route);
        void AcknowledgeExternalRoute(ShellRoute renderedRoute);
    }

    public interface IBaseballPitchNavigation
    {
        PitchHandoffViewModel ResumeHandoff { get; }
    }

    public interface IBaseballScreenController : IDisposable
    {
        ShellRoute Route { get; }
        void Mount(UnityEngine.UIElements.VisualElement host, BaseballScreenViewModel viewModel, IShellNavigator navigator);
    }

    /// <summary>Boundary payload for the separately owned 3D pitching presentation.</summary>
    public readonly struct PitchHandoffViewModel
    {
        public ShellRoute Origin { get; }
        public ShellRoute ReturnRoute { get; }

        public PitchHandoffViewModel(ShellRoute origin, ShellRoute returnRoute)
        {
            Origin = origin;
            ReturnRoute = returnRoute;
        }
    }

    public static class BaseballShellRuntimeComposition
    {
        private static Func<IKoreanUiCopyCatalog, IBaseballShellRuntime> _factory;

        public static void Register(Func<IKoreanUiCopyCatalog, IBaseballShellRuntime> factory)
        {
            _factory = factory ?? throw new ArgumentNullException(nameof(factory));
        }

        public static IBaseballShellRuntime Create(IKoreanUiCopyCatalog copy)
        {
            return _factory?.Invoke(copy) ?? new MissingBaseballShellRuntime(copy);
        }

        private sealed class MissingBaseballShellRuntime : IBaseballShellRuntime
        {
            private readonly IKoreanUiCopyCatalog _copy;
            public MissingBaseballShellRuntime(IKoreanUiCopyCatalog copy) =>
                _copy = copy ?? throw new ArgumentNullException(nameof(copy));
            public event Action Changed { add { } remove { } }
            public ShellRuntimeStatus Status => ShellRuntimeStatus.StartupFailed;
            public ShellRoute PreferredRoute => ShellRoute.Opening;
            public bool IsBusy => false;
            public string StatusMessage => "게임 서비스를 불러오지 못했습니다. 앱을 다시 열어 주세요.";
            public IReadOnlyList<ShellRoute> Routes => Array.AsReadOnly((ShellRoute[])Enum.GetValues(typeof(ShellRoute)));
            public BaseballScreenViewModel Read(ShellRoute route) => RuntimeStatusScreen.Create(route, Status, StatusMessage);
            public Task<ShellActionResult> ExecuteAsync(ShellRoute route, ScreenActionViewModel action, CancellationToken cancellationToken) =>
                Task.FromResult(ShellActionResult.Failure(StatusMessage));
            public void RetryStartup() { }
            public void Dispose() { }
        }
    }

    public static class RuntimeStatusScreen
    {
        public static BaseballScreenViewModel Create(ShellRoute route, ShellRuntimeStatus status, string message)
        {
            bool loading = status == ShellRuntimeStatus.Loading;
            bool retryable = status == ShellRuntimeStatus.StartupFailed || status == ShellRuntimeStatus.Unavailable;
            string title = loading ? "게임을 준비하고 있어요" : "저장 데이터를 불러오지 못했어요";
            string lead = string.IsNullOrWhiteSpace(message)
                ? loading ? "안전하게 저장된 진행 상황을 확인하는 중입니다." : "잠시 후 다시 시도해 주세요."
                : message;
            var section = new ScreenSectionViewModel(
                "runtime-status",
                loading ? "불러오는 중" : "복구 안내",
                loading ? ScreenSectionTone.Information : ScreenSectionTone.Warning,
                new[] { new ScreenRowViewModel("runtime-message", "상태", loading ? "기다려 주세요" : "다시 시도할 수 있어요", lead) });
            var actions = retryable
                ? new[] { new ScreenActionViewModel("runtime_retry", "다시 시도", ShellRoute.Opening, ScreenActionStyle.Primary, "저장 상태를 다시 확인합니다.") }
                : Array.Empty<ScreenActionViewModel>();
            return new BaseballScreenViewModel(
                route,
                "opening",
                "야구 못하면 또 환생함",
                loading ? "준비 중" : "시작 오류",
                title,
                lead,
                new[] { section },
                actions,
                false);
        }
    }
}
