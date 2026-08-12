using System;
using System.Threading;
using System.Threading.Tasks;
using Baseball.Presentation.Shell;
using UnityEngine;
using UnityEngine.UIElements;

namespace Baseball.Presentation.Records
{
    /// <summary>
    /// Captures the entire card into one portrait PNG. Tall cards are scrolled and stitched so
    /// shell chrome, action buttons, and the current screen viewport never define the output crop.
    /// </summary>
    public sealed class ScreenLifeCardPngCapture : IBaseballLifeCardPngCapture
    {
        public Task<byte[]> CaptureAsync(VisualElement card, CancellationToken cancellationToken)
        {
            if (card == null || card.panel == null) return Task.FromResult<byte[]>(null);
            cancellationToken.ThrowIfCancellationRequested();
            ScrollView scroll = card.GetFirstAncestorOfType<ScrollView>();
            if (scroll == null) return Task.FromResult<byte[]>(null);
            return new FullCardCaptureSession(card, scroll, cancellationToken).Start();
        }

        private sealed class FullCardCaptureSession
        {
            private readonly VisualElement _card;
            private readonly ScrollView _scroll;
            private readonly CancellationToken _cancellationToken;
            private readonly TaskCompletionSource<byte[]> _completion =
                new TaskCompletionSource<byte[]>(TaskCreationOptions.RunContinuationsAsynchronously);
            private CancellationTokenRegistration _cancellationRegistration;
            private IVisualElementScheduledItem _scheduled;
            private Texture2D _stitched;
            private float _originalScroll;
            private float _cardContentTop;
            private int _nextPixelTop;
            private int _nextOutputPixelTop;
            private int _sourceWidth;
            private int _sourceHeight;
            private bool _finished;

            public FullCardCaptureSession(
                VisualElement card,
                ScrollView scroll,
                CancellationToken cancellationToken)
            {
                _card = card;
                _scroll = scroll;
                _cancellationToken = cancellationToken;
            }

            public Task<byte[]> Start()
            {
                try
                {
                    _originalScroll = _scroll.verticalScroller.value;
                    _cancellationRegistration = _cancellationToken.Register(
                        () => _completion.TrySetCanceled(_cancellationToken));
                    Schedule(Initialize);
                }
                catch
                {
                    Finish(null);
                }
                return _completion.Task;
            }

            private void Initialize()
            {
                try
                {
                    if (!CanCapture())
                    {
                        Finish(null);
                        return;
                    }

                    Rect panelBounds = _card.panel.visualTree.worldBound;
                    Rect cardBounds = _card.worldBound;
                    Rect viewportBounds = _scroll.contentViewport.worldBound;
                    if (panelBounds.width <= 0f || panelBounds.height <= 0f ||
                        cardBounds.width <= 1f || cardBounds.height <= 1f ||
                        viewportBounds.height <= 1f || Screen.width <= 1 || Screen.height <= 1)
                    {
                        Finish(null);
                        return;
                    }

                    float scaleX = Screen.width / panelBounds.width;
                    float scaleY = Screen.height / panelBounds.height;
                    if (float.IsNaN(scaleX) || float.IsInfinity(scaleX) || scaleX <= 0f ||
                        float.IsNaN(scaleY) || float.IsInfinity(scaleY) || scaleY <= 0f)
                    {
                        Finish(null);
                        return;
                    }
                    int width = Mathf.CeilToInt(cardBounds.width * scaleX);
                    int height = Mathf.CeilToInt(cardBounds.height * scaleY);
                    if (!LifeCardCaptureGeometry.TryPlanOutput(
                            width,
                            height,
                            SystemInfo.maxTextureSize,
                            out LifeCardCaptureOutputPlan plan))
                    {
                        Finish(null);
                        return;
                    }

                    _sourceWidth = plan.SourceWidth;
                    _sourceHeight = plan.SourceHeight;
                    _stitched = new Texture2D(
                        plan.OutputWidth,
                        plan.OutputHeight,
                        TextureFormat.RGBA32,
                        false);
                    _cardContentTop = _scroll.verticalScroller.value +
                        cardBounds.yMin - viewportBounds.yMin;
                    ScrollToPixel(0, scaleY);
                }
                catch
                {
                    // Unsupported dimensions, GPU/CPU allocation pressure, or a detached panel
                    // must resolve the Task so the shell can fall back to text sharing.
                    Finish(null);
                }
            }

            private void CaptureNextTile()
            {
                if (!CanCapture() || _stitched == null)
                {
                    Finish(null);
                    return;
                }

                Texture2D screen = null;
                try
                {
                    screen = ScreenCapture.CaptureScreenshotAsTexture();
                    if (screen == null)
                    {
                        Finish(null);
                        return;
                    }

                    Rect panelBounds = _card.panel.visualTree.worldBound;
                    Rect cardBounds = _card.worldBound;
                    Rect viewportBounds = _scroll.contentViewport.worldBound;
                    float scaleX = screen.width / panelBounds.width;
                    float scaleY = screen.height / panelBounds.height;
                    int left = Mathf.Clamp(
                        Mathf.FloorToInt((cardBounds.xMin - panelBounds.xMin) * scaleX),
                        0,
                        screen.width - 1);
                    int width = Mathf.Min(_sourceWidth, screen.width - left);
                    int cardTop = Mathf.RoundToInt((cardBounds.yMin - panelBounds.yMin) * scaleY);
                    int viewportTop = Mathf.Clamp(
                        Mathf.CeilToInt((viewportBounds.yMin - panelBounds.yMin) * scaleY),
                        0,
                        screen.height);
                    int viewportBottom = Mathf.Clamp(
                        Mathf.FloorToInt((viewportBounds.yMax - panelBounds.yMin) * scaleY),
                        0,
                        screen.height);
                    int sourceTop = cardTop + _nextPixelTop;
                    int sourceBottom = Mathf.Min(
                        Mathf.Min(cardTop + _sourceHeight, viewportBottom),
                        screen.height);

                    // A tile must begin exactly at the first uncaptured card pixel. Otherwise a
                    // clamped or stale scroll position would silently create a truncated PNG.
                    if (width != _sourceWidth || sourceTop < viewportTop ||
                        sourceTop < 0 || sourceTop >= sourceBottom)
                    {
                        Finish(null);
                        return;
                    }

                    int tileHeight = Mathf.Min(sourceBottom - sourceTop,
                        _sourceHeight - _nextPixelTop);
                    if (!LifeCardCaptureGeometry.CanUseColor32Buffer(
                            screen.width,
                            screen.height,
                            out _))
                    {
                        Finish(null);
                        return;
                    }
                    int sourcePixelBottom = LifeCardCaptureGeometry.NextPixelTop(
                        _sourceHeight,
                        _nextPixelTop,
                        tileHeight);
                    int outputPixelBottom = _nextOutputPixelTop;
                    while (outputPixelBottom < _stitched.height &&
                           LifeCardCaptureGeometry.SourcePixelForDestination(
                               outputPixelBottom,
                               _stitched.height,
                               _sourceHeight) < sourcePixelBottom)
                        outputPixelBottom++;

                    int outputTileHeight = outputPixelBottom - _nextOutputPixelTop;
                    if (outputTileHeight > 0)
                    {
                        if (!LifeCardCaptureGeometry.CanUseColor32Buffer(
                                _stitched.width,
                                outputTileHeight,
                                out _))
                        {
                            Finish(null);
                            return;
                        }
                        Color32[] sourcePixels = screen.GetPixels32();
                        Color32[] outputPixels = new Color32[
                            _stitched.width * outputTileHeight];
                        for (int outputTop = _nextOutputPixelTop;
                             outputTop < outputPixelBottom;
                             outputTop++)
                        {
                            int sourceGlobalTop = LifeCardCaptureGeometry.SourcePixelForDestination(
                                outputTop,
                                _stitched.height,
                                _sourceHeight);
                            int screenTop = cardTop + sourceGlobalTop;
                            if (screenTop < viewportTop || screenTop >= viewportBottom)
                            {
                                Finish(null);
                                return;
                            }
                            int sourceY = screen.height - screenTop - 1;
                            int outputLocalTop = outputTop - _nextOutputPixelTop;
                            int outputLocalY = outputTileHeight - outputLocalTop - 1;
                            for (int outputX = 0; outputX < _stitched.width; outputX++)
                            {
                                int sourceX = LifeCardCaptureGeometry.SourcePixelForDestination(
                                    outputX,
                                    _stitched.width,
                                    _sourceWidth);
                                outputPixels[outputLocalY * _stitched.width + outputX] =
                                    sourcePixels[sourceY * screen.width + left + sourceX];
                            }
                        }
                        int destinationY = _stitched.height - outputPixelBottom;
                        _stitched.SetPixels32(
                            0,
                            destinationY,
                            _stitched.width,
                            outputTileHeight,
                            outputPixels);
                    }

                    _nextPixelTop = sourcePixelBottom;
                    _nextOutputPixelTop = outputPixelBottom;
                    if (_nextPixelTop >= _sourceHeight)
                    {
                        if (_nextOutputPixelTop != _stitched.height)
                        {
                            Finish(null);
                            return;
                        }
                        _stitched.Apply(false, false);
                        byte[] png = _stitched.EncodeToPNG();
                        Finish(png != null && png.Length > 0 ? png : null);
                        return;
                    }

                    ScrollToPixel(_nextPixelTop, scaleY);
                }
                catch
                {
                    Finish(null);
                }
                finally
                {
                    if (screen != null)
                    {
                        try { UnityEngine.Object.Destroy(screen); }
                        catch { /* Capture failure already falls back to text. */ }
                    }
                }
            }

            private void ScrollToPixel(int pixelTop, float scaleY)
            {
                float target = _cardContentTop + pixelTop / Math.Max(scaleY, 0.001f);
                _scroll.verticalScroller.value = Mathf.Clamp(
                    target,
                    _scroll.verticalScroller.lowValue,
                    _scroll.verticalScroller.highValue);
                Schedule(CaptureNextTile);
            }

            private bool CanCapture() =>
                !_finished && !_cancellationToken.IsCancellationRequested &&
                _card.panel != null && _scroll.panel != null;

            private void Schedule(Action action)
            {
                if (_finished) return;
                try
                {
                    _scheduled?.Pause();
                    _scheduled = _card.schedule.Execute(() => RunScheduled(action));
                    _scheduled.ExecuteLater(1);
                }
                catch
                {
                    Finish(null);
                }
            }

            private void RunScheduled(Action action)
            {
                if (_finished) return;
                try { action(); }
                catch { Finish(null); }
            }

            private void Finish(byte[] png)
            {
                if (_finished) return;
                _finished = true;
                try { _scheduled?.Pause(); }
                catch { /* Completion must continue. */ }
                try
                {
                    if (_scroll.panel != null)
                        _scroll.verticalScroller.value = _originalScroll;
                }
                catch { /* A detached panel cannot block text-share fallback. */ }
                try
                {
                    if (_stitched != null) UnityEngine.Object.Destroy(_stitched);
                }
                catch { /* Completion must continue. */ }
                _stitched = null;
                try { _cancellationRegistration.Dispose(); }
                catch { /* Completion must continue. */ }
                if (_cancellationToken.IsCancellationRequested)
                    _completion.TrySetCanceled(_cancellationToken);
                else
                    _completion.TrySetResult(png);
            }
        }
    }
}
