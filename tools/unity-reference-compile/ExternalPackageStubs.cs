using System;
using System.Collections;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace UnityEngine.ResourceManagement.AsyncOperations
{
    public enum AsyncOperationStatus { None, Succeeded, Failed }
    public struct AsyncOperationHandle<T>
    {
        public Task<T> Task => System.Threading.Tasks.Task.FromResult(default(T));
        public AsyncOperationStatus Status => AsyncOperationStatus.Succeeded;
        public bool IsValid() => true;
    }
}

namespace UnityEngine.AddressableAssets
{
    using UnityEngine.ResourceManagement.AsyncOperations;
    public static class Addressables
    {
        public static AsyncOperationHandle<T> LoadAssetAsync<T>(object key) => new AsyncOperationHandle<T>();
        public static void Release<T>(AsyncOperationHandle<T> handle) { }
    }
}

namespace UnityEngine.TestTools
{
    [AttributeUsage(AttributeTargets.Method)]
    public sealed class UnityTestAttribute : Attribute { }
    [AttributeUsage(AttributeTargets.Method)]
    public sealed class UnitySetUpAttribute : Attribute { }
    [AttributeUsage(AttributeTargets.Method)]
    public sealed class UnityTearDownAttribute : Attribute { }
}

namespace Unity.Notifications.Android
{
    public enum PermissionStatus { RequestPending, Allowed, Denied, NotificationsBlockedForApp }
    public enum Importance { Default }
    public enum LockScreenVisibility { Private }

    public sealed class PermissionRequest
    {
        public PermissionStatus Status => PermissionStatus.Allowed;
    }

    public sealed class AndroidNotificationChannel
    {
        public string Id { get; set; }
        public string Name { get; set; }
        public string Description { get; set; }
        public Importance Importance { get; set; }
        public bool EnableVibration { get; set; }
        public LockScreenVisibility LockScreenVisibility { get; set; }
    }

    public sealed class AndroidNotification
    {
        public string Title { get; set; }
        public string Text { get; set; }
        public DateTime FireTime { get; set; }
        public string IntentData { get; set; }
        public string SmallIcon { get; set; }
        public bool ShouldAutoCancel { get; set; }
    }

    public sealed class AndroidNotificationIntentData
    {
        public AndroidNotification Notification { get; set; }
    }

    public static class AndroidNotificationCenter
    {
        public static PermissionStatus UserPermissionToPost => PermissionStatus.Allowed;
        public static void RegisterNotificationChannel(AndroidNotificationChannel channel) { }
        public static void SendNotificationWithExplicitID(AndroidNotification notification, string channelId, int id) { }
        public static void CancelScheduledNotification(int id) { }
        public static void CancelDisplayedNotification(int id) { }
        public static void OpenNotificationSettings(string channelId) { }
        public static AndroidNotificationIntentData GetLastNotificationIntent() => null;
    }
}

namespace Firebase
{
    public enum DependencyStatus { Available, Unavailable }
    public static class FirebaseApp
    {
        public static Task<DependencyStatus> CheckAndFixDependenciesAsync() =>
            Task.FromResult(DependencyStatus.Available);
    }
}

namespace Firebase.Analytics
{
    public sealed class Parameter
    {
        public Parameter(string key, long value) { }
        public Parameter(string key, double value) { }
        public Parameter(string key, string value) { }
    }

    public static class FirebaseAnalytics
    {
        public static void SetAnalyticsCollectionEnabled(bool enabled) { }
        public static void SetUserId(string value) { }
        public static void LogEvent(string eventName, params Parameter[] parameters) { }
    }
}

namespace Firebase.Crashlytics
{
    public static class Crashlytics
    {
        public static bool IsCrashlyticsCollectionEnabled { get; set; }
        public static void SetCustomKey(string key, string value) { }
        public static void LogException(Exception exception) { }
    }
}

public sealed class Amplitude
{
    public static Amplitude getInstance(string instanceName) => new Amplitude();
    public void setTrackingOptions(Dictionary<string, bool> options) { }
    public void init(string apiKey) { }
    public void setDeviceId(string value) { }
    public void setUserId(string value) { }
    public void logEvent(string eventName, Dictionary<string, object> properties) { }
    public void uploadEvents() { }
}

namespace Google.Play.Review
{
    public enum ReviewErrorCode { NoError, Error }
    public sealed class PlayReviewInfo { }

    public sealed class ReviewOperation : IEnumerator
    {
        public ReviewErrorCode Error => ReviewErrorCode.NoError;
        public object Current => null;
        public bool MoveNext() => false;
        public void Reset() { }
        public PlayReviewInfo GetResult() => new PlayReviewInfo();
    }

    public sealed class ReviewManager
    {
        public ReviewOperation RequestReviewFlow() => new ReviewOperation();
        public ReviewOperation LaunchReviewFlow(PlayReviewInfo info) => new ReviewOperation();
    }
}
