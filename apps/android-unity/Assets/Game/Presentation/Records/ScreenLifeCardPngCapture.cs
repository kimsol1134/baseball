using System;
using System.Threading;
using System.Threading.Tasks;
using Baseball.Presentation.Shell;
using UnityEngine;
using UnityEngine.UIElements;

namespace Baseball.Presentation.Records
{
    /// <summary>Captures only the rendered card rectangle; shell chrome and action buttons stay outside.</summary>
    public sealed class ScreenLifeCardPngCapture : IBaseballLifeCardPngCapture
    {
        public Task<byte[]> CaptureAsync(VisualElement card, CancellationToken cancellationToken)
        {
            if (card == null || card.panel == null) return Task.FromResult<byte[]>(null);
            cancellationToken.ThrowIfCancellationRequested();

            ScrollView scroll = card.GetFirstAncestorOfType<ScrollView>();
            scroll?.ScrollTo(card);
            var completion = new TaskCompletionSource<byte[]>(TaskCreationOptions.RunContinuationsAsynchronously);
            CancellationTokenRegistration registration = cancellationToken.Register(
                () => completion.TrySetCanceled(cancellationToken));
            card.schedule.Execute(() =>
            {
                try
                {
                    if (cancellationToken.IsCancellationRequested) return;
                    completion.TrySetResult(CaptureVisibleCard(card));
                }
                catch
                {
                    completion.TrySetResult(null);
                }
                finally
                {
                    registration.Dispose();
                }
            }).ExecuteLater(1);
            return completion.Task;
        }

        private static byte[] CaptureVisibleCard(VisualElement card)
        {
            Texture2D screen = ScreenCapture.CaptureScreenshotAsTexture();
            if (screen == null) return null;
            Texture2D cropped = null;
            try
            {
                Rect panel = card.panel.visualTree.worldBound;
                Rect cardBounds = card.worldBound;
                if (panel.width <= 0f || panel.height <= 0f || cardBounds.width <= 1f || cardBounds.height <= 1f)
                    return null;

                float scaleX = screen.width / panel.width;
                float scaleY = screen.height / panel.height;
                int left = Mathf.Clamp(Mathf.FloorToInt((cardBounds.xMin - panel.xMin) * scaleX), 0, screen.width - 1);
                int right = Mathf.Clamp(Mathf.CeilToInt((cardBounds.xMax - panel.xMin) * scaleX), left + 1, screen.width);
                int top = Mathf.Clamp(Mathf.FloorToInt((cardBounds.yMin - panel.yMin) * scaleY), 0, screen.height - 1);
                int bottom = Mathf.Clamp(Mathf.CeilToInt((cardBounds.yMax - panel.yMin) * scaleY), top + 1, screen.height);
                int width = right - left;
                int height = bottom - top;
                if (width < 16 || height < 16) return null;

                int sourceY = screen.height - bottom;
                cropped = new Texture2D(width, height, TextureFormat.RGBA32, false);
                cropped.SetPixels(screen.GetPixels(left, sourceY, width, height));
                cropped.Apply(false, false);
                return cropped.EncodeToPNG();
            }
            finally
            {
                if (cropped != null) UnityEngine.Object.Destroy(cropped);
                UnityEngine.Object.Destroy(screen);
            }
        }
    }
}
