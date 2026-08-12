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
        private readonly AudioSource _musicSource;
        private readonly AndroidAudioFocusService _audioFocus = new AndroidAudioFocusService();
        private readonly PitchAudioLifecycleRelay _lifecycle;
        private bool _sessionActive;
        private bool _appPaused;
        private bool _focusAllowsAudio;
        private bool _disposed;
        private AudioClip _menuPadClip;
        private AudioClip _milestoneClip;
        private double _temporaryUiFocusReleaseAt;

        public AddressablePitchFeedbackBoundary(AndroidHapticsService haptics)
        {
            _haptics = haptics ?? throw new ArgumentNullException(nameof(haptics));
            var audioObject = new GameObject("Pitch Feedback Audio");
            if (UnityEngine.Application.isPlaying)
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
            _musicSource = audioObject.AddComponent<AudioSource>();
            _musicSource.playOnAwake = false;
            _musicSource.loop = true;
            _musicSource.spatialBlend = 0f;
            _musicSource.volume = 0.14f;
            _lifecycle = audioObject.AddComponent<PitchAudioLifecycleRelay>();
            _lifecycle.PauseChanged = OnApplicationPause;
            _lifecycle.TickRequested = TickAudioFocus;
        }

        public bool SoundEnabled
        {
            get => _soundEnabled;
            set
            {
                _soundEnabled = value;
                if (!value)
                {
                    _effectsSource.Stop();
                    _ambienceSource.Stop();
                    ReleaseAudioFocusIfUnused();
                }
                else if (_sessionActive && !_appPaused && EnsureAudioFocus())
                {
                    PlayAmbience();
                }
            }
        }
        private bool _soundEnabled = true;

        public bool MusicEnabled
        {
            get => _musicEnabled;
            set
            {
                _musicEnabled = value;
                if (!value)
                {
                    _musicSource.Stop();
                    ReleaseAudioFocusIfUnused();
                }
                else if (!_appPaused && EnsureAudioFocus()) PlayMenuMusic();
            }
        }
        private bool _musicEnabled = true;

        public void OnSessionStarted()
        {
            _sessionActive = true;
            _focusAllowsAudio = EnsureAudioFocus();
            if (_focusAllowsAudio && SoundEnabled) PlayAmbience();
            if (_focusAllowsAudio && MusicEnabled) PlayMenuMusic();
        }

        public void OnSessionEnded()
        {
            _sessionActive = false;
            _effectsSource.Stop();
            _ambienceSource.Stop();
            if (!MusicEnabled)
            {
                _audioFocus.Abandon();
                _focusAllowsAudio = false;
            }
        }

        public void OnRelease(PitchHapticCue cue)
        {
            if (cue != PitchHapticCue.None) _haptics.Pulse(HapticCue.PitchRelease);
        }

        public void OnResult(PitchPresentationSnapshot presentation)
        {
            if (presentation == null) return;
            Pulse(presentation.HapticCue);
            if (!SoundEnabled || _appPaused || !_focusAllowsAudio) return;
            PitchAudioSelection selection = PitchAudioSelectionPolicy.Select(presentation);
            PlayEffect(selection.PrimaryAddress);
            PlayEffect(selection.CrowdAddress);
        }

        public void PlayMilestone()
        {
            if (_disposed || !SoundEnabled || _appPaused || !EnsureAudioFocus()) return;
            if (_milestoneClip == null) _milestoneClip = CreateMilestoneClip();
            _effectsSource.PlayOneShot(_milestoneClip);
            if (!MusicEnabled && !_sessionActive)
                _temporaryUiFocusReleaseAt = AudioSettings.dspTime + 0.75d;
        }

        public void Dispose()
        {
            if (_disposed) return;
            foreach (AsyncOperationHandle<AudioClip> handle in _clips.Values)
                if (handle.IsValid()) Addressables.Release(handle);
            _clips.Clear();
            _audioFocus.Dispose();
            if (_menuPadClip != null)
            {
                if (UnityEngine.Application.isPlaying) UnityEngine.Object.Destroy(_menuPadClip);
                else UnityEngine.Object.DestroyImmediate(_menuPadClip);
                _menuPadClip = null;
            }
            if (_milestoneClip != null)
            {
                if (UnityEngine.Application.isPlaying) UnityEngine.Object.Destroy(_milestoneClip);
                else UnityEngine.Object.DestroyImmediate(_milestoneClip);
                _milestoneClip = null;
            }
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
            if (_disposed || !_sessionActive || !SoundEnabled) return;
            try
            {
                if (!_clips.TryGetValue(address, out AsyncOperationHandle<AudioClip> handle))
                {
                    handle = Addressables.LoadAssetAsync<AudioClip>(address);
                    _clips.Add(address, handle);
                }
                AudioClip clip = await handle.Task;
                if (_disposed || !_sessionActive || !SoundEnabled || _appPaused || !_focusAllowsAudio ||
                    handle.Status != AsyncOperationStatus.Succeeded || clip == null) return;
                _ambienceSource.clip = clip;
                if (!_ambienceSource.isPlaying) _ambienceSource.Play();
            }
            catch
            {
                // Ambience is optional and must fail open to the pitch UI.
            }
        }

        private void PlayMenuMusic()
        {
            if (_disposed || !MusicEnabled || _appPaused || !_focusAllowsAudio) return;
            if (_menuPadClip == null) _menuPadClip = CreateMenuPadClip();
            _musicSource.clip = _menuPadClip;
            if (!_musicSource.isPlaying) _musicSource.Play();
        }

        private bool EnsureAudioFocus()
        {
            if (_focusAllowsAudio) return true;
            _focusAllowsAudio = _audioFocus.Request();
            return _focusAllowsAudio;
        }

        private void ReleaseAudioFocusIfUnused()
        {
            if (MusicEnabled || _sessionActive && SoundEnabled) return;
            _audioFocus.Abandon();
            _focusAllowsAudio = false;
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
                _musicSource.Stop();
                _audioFocus.Abandon();
                _focusAllowsAudio = false;
                return;
            }
            _focusAllowsAudio = (MusicEnabled || _sessionActive && SoundEnabled) && _audioFocus.Request();
            if (_sessionActive && _focusAllowsAudio && SoundEnabled) PlayAmbience();
            if (_focusAllowsAudio && MusicEnabled) PlayMenuMusic();
        }

        private void TickAudioFocus()
        {
            if (_temporaryUiFocusReleaseAt > 0d &&
                AudioSettings.dspTime >= _temporaryUiFocusReleaseAt &&
                !MusicEnabled && !_sessionActive)
            {
                _temporaryUiFocusReleaseAt = 0d;
                _audioFocus.Abandon();
                _focusAllowsAudio = false;
            }
            if (!_audioFocus.TryConsume(out BaseballAudioFocusChange change)) return;
            switch (change)
            {
                case BaseballAudioFocusChange.Gain:
                    _focusAllowsAudio = true;
                    _effectsSource.volume = 1f;
                    _ambienceSource.volume = 0.28f;
                    _musicSource.volume = 0.14f;
                    if (_sessionActive && !_appPaused && SoundEnabled) PlayAmbience();
                    if (!_appPaused && MusicEnabled) PlayMenuMusic();
                    break;
                case BaseballAudioFocusChange.Duck:
                    _focusAllowsAudio = true;
                    _effectsSource.volume = 0.25f;
                    _ambienceSource.volume = 0.08f;
                    _musicSource.volume = 0.04f;
                    break;
                case BaseballAudioFocusChange.Loss:
                case BaseballAudioFocusChange.LossTransient:
                    _focusAllowsAudio = false;
                    _effectsSource.Stop();
                    _ambienceSource.Stop();
                    _musicSource.Stop();
                    break;
            }
        }

        private static AudioClip CreateMenuPadClip()
        {
            const int sampleRate = 22050;
            const int seconds = 4;
            const int channels = 2;
            int frames = sampleRate * seconds;
            var samples = new float[frames * channels];
            for (var frame = 0; frame < frames; frame++)
            {
                double t = frame / (double)sampleRate;
                double breathe = 0.78 + 0.12 * Math.Sin(2d * Math.PI * 0.25d * t);
                double left = Math.Sin(2d * Math.PI * 110d * t) * 0.55 +
                    Math.Sin(2d * Math.PI * 165d * t) * 0.28 +
                    Math.Sin(2d * Math.PI * 220d * t) * 0.12;
                double right = Math.Sin(2d * Math.PI * 110d * t) * 0.52 +
                    Math.Sin(2d * Math.PI * 165d * t + 0.08) * 0.30 +
                    Math.Sin(2d * Math.PI * 220d * t + 0.04) * 0.13;
                samples[frame * channels] = (float)(left * breathe * 0.12);
                samples[frame * channels + 1] = (float)(right * breathe * 0.12);
            }
            AudioClip clip = AudioClip.Create("Baseball Menu Pad", frames, channels, sampleRate, false);
            clip.SetData(samples, 0);
            return clip;
        }

        private static AudioClip CreateMilestoneClip()
        {
            const int sampleRate = 22050;
            const int channels = 2;
            int frames = sampleRate / 2;
            var samples = new float[frames * channels];
            for (var frame = 0; frame < frames; frame++)
            {
                double t = frame / (double)sampleRate;
                double envelope = Math.Exp(-5.5d * t);
                double voice = Math.Sin(2d * Math.PI * 660d * t) * 0.65d +
                    Math.Sin(2d * Math.PI * 990d * t) * 0.24d;
                float value = (float)(voice * envelope * 0.16d);
                samples[frame * channels] = value;
                samples[frame * channels + 1] = value;
            }
            AudioClip clip = AudioClip.Create("Baseball Milestone", frames, channels, sampleRate, false);
            clip.SetData(samples, 0);
            return clip;
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
