using System;
using UnityEngine;

namespace Baseball.Platform.Haptics
{
    public enum HapticCue
    {
        Selection,
        PitchRelease,
        BallContact,
        CriticalMoment
    }

    public readonly struct HapticPattern
    {
        public HapticPattern(long milliseconds, int amplitude)
        {
            Milliseconds = milliseconds;
            Amplitude = amplitude;
        }

        public long Milliseconds { get; }
        public int Amplitude { get; }
    }

    public sealed class AndroidHapticsService
    {
        private bool _isEnabled = true;

        public bool IsEnabled
        {
            get => _isEnabled;
            set
            {
                _isEnabled = value;
                if (!value) Cancel();
            }
        }

        public static HapticPattern PatternFor(HapticCue cue)
        {
            switch (cue)
            {
                case HapticCue.Selection: return new HapticPattern(12L, 72);
                case HapticCue.PitchRelease: return new HapticPattern(18L, 104);
                case HapticCue.BallContact: return new HapticPattern(34L, 180);
                case HapticCue.CriticalMoment: return new HapticPattern(52L, 255);
                default: throw new ArgumentOutOfRangeException(nameof(cue), cue, null);
            }
        }

        public bool Pulse(HapticCue cue)
        {
            if (!IsEnabled) return false;
#if UNITY_ANDROID && !UNITY_EDITOR
            try
            {
                using AndroidJavaObject vibrator = GetVibrator();
                if (vibrator == null || !vibrator.Call<bool>("hasVibrator")) return false;
                HapticPattern pattern = PatternFor(cue);
                int sdk = new AndroidJavaClass("android.os.Build$VERSION").GetStatic<int>("SDK_INT");
                if (sdk >= 26)
                {
                    using var effectClass = new AndroidJavaClass("android.os.VibrationEffect");
                    using AndroidJavaObject effect = effectClass.CallStatic<AndroidJavaObject>(
                        "createOneShot",
                        pattern.Milliseconds,
                        pattern.Amplitude);
                    vibrator.Call("vibrate", effect);
                }
                else
                {
                    vibrator.Call("vibrate", pattern.Milliseconds);
                }
                return true;
            }
            catch (Exception exception)
            {
                Debug.LogException(exception);
                return false;
            }
#else
            return false;
#endif
        }

        public void Cancel()
        {
#if UNITY_ANDROID && !UNITY_EDITOR
            try
            {
                using AndroidJavaObject vibrator = GetVibrator();
                vibrator?.Call("cancel");
            }
            catch (Exception) { }
#endif
        }

#if UNITY_ANDROID && !UNITY_EDITOR
        private static AndroidJavaObject GetVibrator()
        {
            using var player = new AndroidJavaClass("com.unity3d.player.UnityPlayer");
            using AndroidJavaObject activity = player.GetStatic<AndroidJavaObject>("currentActivity");
            int sdk = new AndroidJavaClass("android.os.Build$VERSION").GetStatic<int>("SDK_INT");
            if (sdk >= 31)
            {
                using AndroidJavaObject manager = activity.Call<AndroidJavaObject>("getSystemService", "vibrator_manager");
                return manager?.Call<AndroidJavaObject>("getDefaultVibrator");
            }
            return activity.Call<AndroidJavaObject>("getSystemService", "vibrator");
        }
#endif
    }
}
