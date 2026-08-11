using System;
using System.Threading;
using UnityEngine;

namespace Baseball.Platform.Audio
{
    public enum BaseballAudioFocusChange
    {
        None,
        Gain,
        Loss,
        LossTransient,
        Duck,
    }

    /// <summary>Thin Android music-focus boundary. Callbacks are consumed later on Unity's main thread.</summary>
    public sealed class AndroidAudioFocusService : IDisposable
    {
        private int _pendingChange;
#if UNITY_ANDROID && !UNITY_EDITOR
        private AndroidJavaObject _audioManager;
        private FocusListener _listener;
#endif

        public bool Request()
        {
#if UNITY_ANDROID && !UNITY_EDITOR
            try
            {
                if (_audioManager == null)
                {
                    using var player = new AndroidJavaClass("com.unity3d.player.UnityPlayer");
                    using AndroidJavaObject activity = player.GetStatic<AndroidJavaObject>("currentActivity");
                    _audioManager = activity.Call<AndroidJavaObject>("getSystemService", "audio");
                    _listener = new FocusListener(this);
                }
                int result = _audioManager.Call<int>("requestAudioFocus", _listener, 3, 1);
                return result == 1;
            }
            catch (Exception)
            {
                return false;
            }
#else
            return true;
#endif
        }

        public bool TryConsume(out BaseballAudioFocusChange change)
        {
            int value = Interlocked.Exchange(ref _pendingChange, 0);
            change = (BaseballAudioFocusChange)value;
            return change != BaseballAudioFocusChange.None;
        }

        public void Abandon()
        {
#if UNITY_ANDROID && !UNITY_EDITOR
            try
            {
                if (_audioManager != null && _listener != null)
                    _audioManager.Call<int>("abandonAudioFocus", _listener);
            }
            catch (Exception) { }
#endif
        }

        public void Dispose()
        {
            Abandon();
#if UNITY_ANDROID && !UNITY_EDITOR
            _audioManager?.Dispose();
            _audioManager = null;
            _listener = null;
#endif
        }

#if UNITY_ANDROID && !UNITY_EDITOR
        private sealed class FocusListener : AndroidJavaProxy
        {
            private readonly AndroidAudioFocusService _owner;
            public FocusListener(AndroidAudioFocusService owner)
                : base("android.media.AudioManager$OnAudioFocusChangeListener") => _owner = owner;

            public void onAudioFocusChange(int focusChange)
            {
                BaseballAudioFocusChange mapped;
                switch (focusChange)
                {
                    case 1: mapped = BaseballAudioFocusChange.Gain; break;
                    case -1: mapped = BaseballAudioFocusChange.Loss; break;
                    case -2: mapped = BaseballAudioFocusChange.LossTransient; break;
                    case -3: mapped = BaseballAudioFocusChange.Duck; break;
                    default: mapped = BaseballAudioFocusChange.None; break;
                }
                Interlocked.Exchange(ref _owner._pendingChange, (int)mapped);
            }
        }
#endif
    }
}
