using Baseball.Presentation.Common;
using Baseball.Presentation.Shell;
using UnityEngine.UIElements;

namespace Baseball.Presentation.Settings
{
    public sealed class SettingsScreenController : BaseballScreenControllerBase
    {
        public SettingsScreenController() : base(ShellRoute.Settings, "SettingsScreen") { }

        protected override void AddCustomContent(VisualElement host, BaseballScreenViewModel viewModel, IShellNavigator navigator)
        {
            host.style.display = DisplayStyle.Flex;
            host.AddToClassList("screen-control-stack");
            IBaseballShellPreferences preferences = navigator as IBaseballShellPreferences;
            IBaseballShellSettings settings = navigator as IBaseballShellSettings;
            host.Add(new AccessibleToggle(
                "자동 릴리스",
                "screen-settings-auto-release",
                settings?.AutoRelease ?? false,
                enabled => settings?.SetAutoRelease(enabled)));
            host.Add(new AccessibleToggle(
                "효과음",
                "screen-settings-sound",
                settings?.SoundEnabled ?? true,
                enabled => settings?.SetSoundEnabled(enabled)));
            host.Add(new AccessibleToggle(
                "음악",
                "screen-settings-music",
                settings?.MusicEnabled ?? true,
                enabled => settings?.SetMusicEnabled(enabled)));
            host.Add(new AccessibleToggle(
                "진동",
                "screen-settings-vibration",
                settings?.HapticsEnabled ?? false,
                enabled => settings?.SetHapticsEnabled(enabled)));
            var notification = new AccessibleToggle(
                "복귀 알림 받기",
                "screen-settings-notification",
                settings?.NotificationsEnabled ?? false,
                enabled => settings?.SetNotificationsEnabled(enabled));
            bool canNotify = settings != null && settings.CanUseNotifications;
            bool requiresSettings = settings?.NotificationSettingsRequired == true;
            notification.SetEnabled(canNotify && !requiresSettings);
            notification.tooltip = requiresSettings
                ? "알림이 거부되어 Android 설정에서 허용해야 합니다."
                : canNotify ? "알림 권한은 선택한 뒤 요청합니다." : settings?.NotificationsUnavailableReason ?? "알림 서비스를 사용할 수 없습니다.";
            host.Add(notification);
            if (requiresSettings)
            {
                host.Add(new SecondaryButton(
                    "Android 알림 설정 열기",
                    "screen-settings-notification-system-settings",
                    () => settings.OpenNotificationSettings()));
            }
            host.Add(new AccessibleToggle(
                "고대비",
                "screen-settings-high-contrast",
                preferences != null && preferences.HighContrast,
                enabled => preferences?.SetHighContrast(enabled)));
            host.Add(new AccessibleToggle(
                "동작 줄이기",
                "screen-settings-reduced-motion",
                preferences != null && preferences.ReducedMotion,
                enabled => preferences?.SetReducedMotion(enabled)));
            var fontScale = new BaseballCallout(
                "글자 크기",
                BaseballCalloutTone.Information,
                "screen-settings-system-font-scale");
            fontScale.Content.Add(new Label(
                "게임 글자는 Android 시스템의 글자 크기 설정을 자동으로 따릅니다."));
            host.Add(fontScale);
        }
    }
}
