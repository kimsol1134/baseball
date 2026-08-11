using System;
using System.Collections.Generic;
using Baseball.Platform.Audio;
using Baseball.Platform.Haptics;
using UnityEngine;
using UnityEngine.AddressableAssets;
using UnityEngine.ResourceManagement.AsyncOperations;

namespace Baseball.Presentation.Pitch
{
    /// <summary>Presentation boundary backed by local Addressables audio and Android haptics.</summary>
    public sealed class AddressablePitchFeedbackBoundary : IPitchFeedbackBoundary, IDisposable
    {
        private readonly AndroidHapticsService _haptics;
        private readonly Dictionary<string, AsyncOperationHandle<AudioClip>> _clips =
            new Dictionary<string, AsyncOperationHandle<AudioClip>>(StringComparer.Ordinal);
        private readonly AudioSource _effectsSource;
        private readonly AudioSource _ambienceSource;
        private readonly AndroidAudioFocusService _audioFocus = new AndroidAudioFocusService();
        private readonly PitchAudioLifecycleRelay _lifecycle;
        private bool _sessionActive;
        private bool _appPaused;
        private bool _focusAllowsAudio;
        private bool _disposed;

        public AddressablePitchFeedbackBoundary(AndroidHapticsService haptics)
        {
            _haptics = haptics ?? throw new ArgumentNullException(nameof(haptics));
            var audioObject = new GameObject("Pitch Feedback Audio");
            UnityEngine.Object.DontDestroyOnLoad(audioObject);
            _effectsSource = audioObject.AddComponent<AudioSource>();
            _effectsSource.playOnAwake = false;
            _effectsSource.loop = false;
            _effectsSource.spatialBlend = 0f;
            _ambienceSource = audioObject.AddComponent<AudioSource>();
            _ambienceSource.playOnAwake = false;
            _ambienceSource.loop = true;
            _ambienceSource.spatialBlend = 0f;
            _ambienceSource.volume = 0.28f;
            _lifecycle = audioObject.AddComponent<PitchAudioLifecycleRelay>();
            _lifecycle.PauseChanged = OnApplicationPause;
            _lifecycle.TickRequested = TickAudioFocus;
        }

        public bool SoundEnabled { get; set; } = true;
        public bool MusicEnabled
        {
            get => _musicEnabled;
            set
            {
                _musicEnabled = value;
                if (!value) _ambienceSource.Stop();
                else if (_sessionActive && !_appPaused && _focusAllowsAudio) PlayAmbience();
            }
        }
        private bool _musicEnabled = true;

        public void OnSessionStarted()
        {
            _sessionActive = true;
            _focusAllowsAudio = _audioFocus.Request();
            if (_focusAllowsAudio && MusicEnabled) PlayAmbience();
        }

        public void OnSessionEnded()
        {
            _sessionActive = false;
            _effectsSource.Stop();
            _ambienceSource.Stop();
            _audioFocus.Abandon();
        }

        public void OnRelease(PitchHapticCue cue)
        {
            if (cue != PitchHapticCue.None) _haptics.Pulse(HapticCue.PitchRelease);
        }

        public void OnResult(PitchAudioCue audioCue, PitchHapticCue hapticCue)
        {
            Pulse(hapticCue);
            if (SoundEnabled && !_appPaused && _focusAllowsAudio) PlayEffect(Address(audioCue));
        }

        public void Dispose()
        {
            if (_disposed) return;
            foreach (AsyncOperationHandle<AudioClip> handle in _clips.Values)
                if (handle.IsValid()) Addressables.Release(handle);
            _clips.Clear();
            _audioFocus.Dispose();
            if (_effectsSource != null)
            {
                if (UnityEngine.Application.isPlaying) UnityEngine.Object.Destroy(_effectsSource.gameObject);
                else UnityEngine.Object.DestroyImmediate(_effectsSource.gameObject);
            }
            _disposed = true;
        }

        private async void PlayEffect(string address)
        {
            if (_disposed || string.IsNullOrWhiteSpace(address)) return;
            try
            {
                if (!_clips.TryGetValue(address, out AsyncOperationHandle<AudioClip> handle))
                {
                    handle = Addressables.LoadAssetAsync<AudioClip>(address);
                    _clips.Add(address, handle);
                }
                AudioClip clip = await handle.Task;
                if (!_disposed && SoundEnabled && !_appPaused && _focusAllowsAudio &&
                    handle.Status == AsyncOperationStatus.Succeeded && clip != null)
                    _effectsSource.PlayOneShot(clip);
            }
            catch
            {
                // Audio is non-authoritative and never blocks the pitch result.
            }
        }

        private async void PlayAmbience()
        {
            const string address = "baseball/audio/crowd-loop";
            if (_disposed || !_sessionActive || !MusicEnabled) return;
            try
            {
                if (!_clips.TryGetValue(address, out AsyncOperationHandle<AudioClip> handle))
                {
                    handle = Addressables.LoadAssetAsync<AudioClip>(address);
                    _clips.Add(address, handle);
                }
                AudioClip clip = await handle.Task;
                if (_disposed || !_sessionActive || !MusicEnabled || _appPaused || !_focusAllowsAudio ||
                    handle.Status != AsyncOperationStatus.Succeeded || clip == null) return;
                _ambienceSource.clip = clip;
                if (!_ambienceSource.isPlaying) _ambienceSource.Play();
            }
            catch
            {
                // Ambience is optional and must fail open to the pitch UI.
            }
        }

        private void Pulse(PitchHapticCue cue)
        {
            switch (cue)
            {
                case PitchHapticCue.Contact: _haptics.Pulse(HapticCue.BallContact); break;
                case PitchHapticCue.ImportantResult: _haptics.Pulse(HapticCue.CriticalMoment); break;
                case PitchHapticCue.Catch:
                case PitchHapticCue.Foul: _haptics.Pulse(HapticCue.Selection); break;
            }
        }

        private void OnApplicationPause(bool paused)
        {
            _appPaused = paused;
            if (paused)
            {
                _effectsSource.Stop();
                _ambienceSource.Stop();
                _audioFocus.Abandon();
                _focusAllowsAudio = false;
                return;
            }
            _focusAllowsAudio = !_sessionActive || _audioFocus.Request();
            if (_sessionActive && _focusAllowsAudio && MusicEnabled) PlayAmbience();
        }

        private void TickAudioFocus()
        {
            if (!_audioFocus.TryConsume(out BaseballAudioFocusChange change)) return;
            switch (change)
            {
                case BaseballAudioFocusChange.Gain:
                    _focusAllowsAudio = true;
                    _effectsSource.volume = 1f;
                    _ambienceSource.volume = 0.28f;
                    if (_sessionActive && !_appPaused && MusicEnabled) PlayAmbience();
                    break;
                case BaseballAudioFocusChange.Duck:
                    _focusAllowsAudio = true;
                    _effectsSource.volume = 0.25f;
                    _ambienceSource.volume = 0.08f;
                    break;
                case BaseballAudioFocusChange.Loss:
                case BaseballAudioFocusChange.LossTransient:
                    _focusAllowsAudio = false;
                    _effectsSource.Stop();
                    _ambienceSource.Stop();
                    break;
            }
        }

        private static string Address(PitchAudioCue cue)
        {
            switch (cue)
            {
                case PitchAudioCue.GloveCatch: return "baseball/audio/glove-catch";
                case PitchAudioCue.SwingMiss: return "baseball/audio/swing-miss";
                case PitchAudioCue.UmpireStrike: return "baseball/audio/umpire-strike";
                case PitchAudioCue.UmpireStrikeout: return "baseball/audio/umpire-strikeout";
                case PitchAudioCue.Foul: return "baseball/audio/bat-foul";
                case PitchAudioCue.WeakContact: return "baseball/audio/bat-contact-weak";
                case PitchAudioCue.HardContact: return "baseball/audio/bat-contact-hard";
                default: return string.Empty;
            }
        }
    }

    internal sealed class PitchAudioLifecycleRelay : MonoBehaviour
    {
        public Action<bool> PauseChanged { private get; set; }
        public Action TickRequested { private get; set; }

        private void Update() => TickRequested?.Invoke();
        private void OnApplicationPause(bool paused) => PauseChanged?.Invoke(paused);
    }
}
