using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Baseball.Application.Commands;
using Baseball.Application.HighSchool;
using Baseball.Application.Meta;
using Baseball.Application.Persistence;
using Baseball.Application.Pro;
using Baseball.Application.Stores;
using Baseball.Bootstrap;
using Baseball.Core.Catalogs;
using Baseball.Platform.Analytics;
using Baseball.Platform.Configuration;
using Baseball.Platform.Crash;
using Baseball.Platform.Haptics;
using Baseball.Platform.Identity;
using Baseball.Platform.Notifications;
using Baseball.Platform.Review;
using Baseball.Platform.Share;
using Baseball.Presentation.Pitch;
using UnityEngine;

namespace Baseball.Presentation.Shell
{
    /// <summary>Production read/write adapter over the durably published application store.</summary>
    public sealed partial class ProductionBaseballShellRuntime : IBaseballShellRuntime,
        IBaseballSetupDraft, IBaseballAdvancedSetupDraft, IBaseballCareerChoiceDraft,
        IBaseballShellSettings, IBaseballVisualAssets, IBaseballShellRouteObserver,
        IBaseballPitchNavigation, IBaseballLifeCardShareRuntime, IBaseballExternalNavigation,
        IBaseballShellLifecycleObserver, IBaseballLifeArchiveInteraction, IPitchFeedbackBoundary,
        IBaseballOpeningPresentationGate, IBaseballContentExposure,
        IBaseballRetiredDailyRouteFallback, IBaseballTransientDraftDiscard,
        IBaseballTrainingCelebrationSource
    {
        private readonly StoreBaseballCareerReadModel _readModel;
        private readonly AndroidHapticsService _haptics = new AndroidHapticsService();
        private readonly IBaseballVisualAssetLoader _visualAssets = new AddressableVisualAssetLoader();
        private readonly AddressablePitchFeedbackBoundary _pitchFeedback;
        private readonly string _crashDistribution;
        private GameApplicationStore _store;
        private ShellRuntimeStatus _status = ShellRuntimeStatus.Loading;
        private string _statusMessage = "안전하게 저장된 진행 상황을 확인하는 중입니다.";
        private string _playerName = string.Empty;
        private int _setupStep;
        private string _region = "서울";
        private string _presetId = "power_prospect";
        private string _seedInput = string.Empty;
        private string _seedValidationMessage = string.Empty;
        private string _setupDifficulty = "standard";
        private string _setupSoulDomain = "technique";
        private string _setupSignatureLegacy = string.Empty;
        private readonly HashSet<string> _setupKarmas = new HashSet<string>(StringComparer.Ordinal);
        private readonly HashSet<string> _setupSoulBoosts = new HashSet<string>(StringComparer.Ordinal);
        private readonly SetupDraftLifecyclePolicy _setupDraftLifecycle =
            new SetupDraftLifecyclePolicy();
        private readonly CareerChoiceDraftLifecyclePolicy _careerChoiceDraftLifecycle =
            new CareerChoiceDraftLifecyclePolicy();
        private readonly Dictionary<string, string> _careerChoices =
            new Dictionary<string, string>(StringComparer.Ordinal);
        private readonly Dictionary<string, HashSet<string>> _careerMultiChoices =
            new Dictionary<string, HashSet<string>>(StringComparer.Ordinal);
        private int _commandSequence;
        private bool _weeklyObserveInFlight;
        private ulong? _weeklyObservedRevision;
        private bool? _pendingReminderEnabled;
        private string _pendingReminderSource;
        private bool _reminderSettingsInFlight;
        private bool _reminderOpenInFlight;
        private bool _reminderNavigationReceiptInFlight;
        private bool _retiredDailyCleanupInFlight;
        private ShellRoute? _externalRoute;
        private string _externalRouteReminderToken;
        private ShellRoute? _consumedExternalRoute;
        private string _consumedExternalRouteReminderToken;
        private bool _disposed;
        private TrainingCelebrationViewModel _pendingTrainingCelebration;

        public ProductionBaseballShellRuntime(IKoreanUiCopyCatalog copy)
        {
            _crashDistribution = AnalyticsRuntimeConfiguration.Load().ResolveDistributionValue();
            CrashRuntimeDiagnostics.InitializeQualityTier(InitialPitchQualityTier());
            _pitchFeedback = new AddressablePitchFeedbackBoundary(_haptics);
            _pitchFeedback.SoundEnabled = SoundEnabled;
            _pitchFeedback.MusicEnabled = MusicEnabled;
            _readModel = new StoreBaseballCareerReadModel(
                copy,
                () => _store?.Current,
                () => _status,
                () => _statusMessage,
                () => _presetId,
                GetChoice,
                GetChoices,
                () => AndroidReminderService.Instance?.ShouldOfferOptIn == true,
                setupSeedInputValid: () => SetupSeedInputPolicy.IsValid(_seedInput));
            RuntimeGameServices.Ready += OnReady;
            RuntimeGameServices.StoreChanged += OnStoreChanged;
            RuntimeGameServices.BecameUnavailable += OnUnavailable;
            RuntimeGameServices.StartupFailed += OnStartupFailed;
            RuntimeGameServices.SessionEndPrepared += OnSessionEndPrepared;
            if (AndroidReminderService.Instance != null)
            {
                AndroidReminderService.Instance.EnablementChanged += OnReminderChanged;
                AndroidReminderService.Instance.ReminderOpenAvailable += OnReminderOpenAvailable;
            }
            if (RuntimeGameServices.TryGetStore(out GameApplicationStore ready)) OnReady(ready);
        }

        public event Action Changed;
        public ShellRuntimeStatus Status => _status;
        public ShellRoute PreferredRoute =>
            (_store?.Current?.PitchResume?.CareerKind == PitchCareerKind.Daily
                ? RetiredDailyFallbackRoute
                : _readModel.PreferredRoute);
        public ShellRoute RetiredDailyFallbackRoute =>
            StoreBaseballCareerReadModel.RetiredDailyFallbackFor(_store?.Current);
        public bool ShouldHoldOpeningForReturnPlan =>
            _status == ShellRuntimeStatus.Ready &&
            ReturnPlanPresentationPolicy.ShouldHoldOpening(_store?.Current, DateTimeOffset.UtcNow);
        public bool IsBusy => _store?.IsBusy == true;
        public string StatusMessage => _statusMessage;
        public IReadOnlyList<ShellRoute> Routes => _readModel.Routes;
        public int SetupStep => _setupStep;
        public string PlayerName => _playerName;
        public string SuggestedPlayerName => PitcherPresetCatalog.All.FirstOrDefault(value =>
            string.Equals(value.Id, _presetId, StringComparison.Ordinal))?.Pitcher?.Name ?? "민서준";
        public string Region => _region;
        public string PresetId => _presetId;
        public HighSchoolSetupReadModel SetupOptions =>
            HighSchoolSetupCatalog.For(_store?.Current?.Meta ?? MetaProgressState.Initial);
        public string SeedInput => _seedInput;
        public string SeedValidationMessage => _seedValidationMessage;
        public string SetupDifficulty => _setupDifficulty;
        public string SetupSoulDomain => _setupSoulDomain;
        public string SetupSignatureLegacy => _setupSignatureLegacy;
        public IReadOnlyList<string> SetupKarmas => _setupKarmas.OrderBy(value => value, StringComparer.Ordinal).ToArray();
        public IReadOnlyList<string> SetupSoulBoosts => _setupSoulBoosts.OrderBy(value => value, StringComparer.Ordinal).ToArray();
        public IReadOnlyList<string> SetupMemories =>
            SetupOptions?.CarriedMemories?.ToArray() ?? Array.Empty<string>();
        private GameSettingsState Settings => _store?.Current?.Settings ?? GameSettingsState.Default;
        public bool AutoRelease => Settings.AutoReleaseEnabled;
        public bool SoundEnabled => Settings.SoundEnabled;
        public bool MusicEnabled => Settings.MusicEnabled;
        public bool HapticsEnabled => Settings.HapticsEnabled;
        public bool NotificationsEnabled => Settings.NotificationsEnabled;
        public bool CanUseNotifications =>
            AndroidReminderService.Instance?.IsInstallBound == true;
        public bool NotificationSettingsRequired => AndroidReminderService.Instance?.RequiresSystemSettings == true;
        public string NotificationsUnavailableReason => CanUseNotifications
            ? string.Empty
            : "이 기기에서는 알림 서비스를 준비하지 못했습니다.";
        public bool HighContrast => Settings.HighContrastEnabled;
        public bool ReducedMotion => Settings.ReducedMotionEnabled;
        public IBaseballVisualAssetLoader VisualAssetLoader => _visualAssets;
        public PitchHandoffViewModel ResumeHandoff
        {
            get
            {
                PitchCareerKind? kind = _store?.Current?.PitchResume?.CareerKind;
                ShellRoute origin = kind == PitchCareerKind.Tutorial
                    ? ShellRoute.Prologue
                    : kind == PitchCareerKind.Daily
                    ? RetiredDailyFallbackRoute
                    : kind == PitchCareerKind.Pro ? ShellRoute.ProWeek : ShellRoute.ImportantGame;
                ShellRoute destination = kind == PitchCareerKind.Tutorial
                    ? ShellRoute.Prologue
                    : kind == PitchCareerKind.Daily
                    ? RetiredDailyFallbackRoute
                    : kind == PitchCareerKind.Pro ? ShellRoute.ProWeek : ShellRoute.Awakening;
                return new PitchHandoffViewModel(origin, destination);
            }
        }

        public BaseballScreenViewModel Read(ShellRoute route) => _readModel.Read(route);

        public bool TryConsumeExternalRoute(out ShellRoute route)
        {
            if (_externalRoute.HasValue)
            {
                route = _externalRoute.Value;
                _externalRoute = null;
                _consumedExternalRoute = route;
                _consumedExternalRouteReminderToken = _externalRouteReminderToken;
                _externalRouteReminderToken = null;
                return true;
            }
            route = default;
            return false;
        }

        public void AcknowledgeExternalRoute(ShellRoute renderedRoute)
        {
            if (!_consumedExternalRoute.HasValue ||
                _consumedExternalRoute.Value != renderedRoute &&
                !(_consumedExternalRoute.Value == ShellRoute.Daily &&
                  RetiredDailyFallbackRoute == renderedRoute))
                return;
            string reminderToken = _consumedExternalRouteReminderToken;
            _consumedExternalRoute = null;
            _consumedExternalRouteReminderToken = null;
            if (!string.IsNullOrWhiteSpace(reminderToken))
                ConfirmReminderNavigation(reminderToken);
        }

    }

    public static class ProductionBaseballShellComposition
    {
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
        private static void Register()
        {
            BaseballShellRuntimeComposition.Register(copy => new ProductionBaseballShellRuntime(copy));
        }
    }
}
