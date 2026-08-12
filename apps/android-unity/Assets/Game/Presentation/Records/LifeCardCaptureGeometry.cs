using System;
using System.Collections.Generic;

namespace Baseball.Presentation.Records
{
    public readonly struct LifeCardCaptureTile
    {
        public LifeCardCaptureTile(int pixelTop, int height)
        {
            PixelTop = pixelTop;
            Height = height;
        }

        public int PixelTop { get; }
        public int Height { get; }
        public int PixelBottom => PixelTop + Height;
    }

    public readonly struct LifeCardCaptureOutputPlan
    {
        public LifeCardCaptureOutputPlan(
            int sourceWidth,
            int sourceHeight,
            int outputWidth,
            int outputHeight)
        {
            SourceWidth = sourceWidth;
            SourceHeight = sourceHeight;
            OutputWidth = outputWidth;
            OutputHeight = outputHeight;
        }

        public int SourceWidth { get; }
        public int SourceHeight { get; }
        public int OutputWidth { get; }
        public int OutputHeight { get; }
        public bool IsDownscaled => OutputWidth < SourceWidth || OutputHeight < SourceHeight;
    }

    /// <summary>Pure coverage rules shared by full-content capture and its regression tests.</summary>
    public static class LifeCardCaptureGeometry
    {
        public const long MaximumOutputPixels = 10_000_000;
        public const long MaximumOutputRgbaBytes = 40L * 1024L * 1024L;
        public const long MaximumColor32BufferBytes = 40L * 1024L * 1024L;
        public const int MinimumReadableOutputWidth = 720;
        private const int RgbaBytesPerPixel = 4;

        public static bool TryPlanOutput(
            int sourceWidth,
            int sourceHeight,
            int maximumTextureSize,
            out LifeCardCaptureOutputPlan plan)
        {
            plan = default;
            if (sourceWidth < 16 || sourceHeight < 16 || maximumTextureSize < 16)
                return false;

            double sourcePixels = (double)sourceWidth * sourceHeight;
            double scale = Math.Min(1d, Math.Min(
                (double)maximumTextureSize / sourceWidth,
                (double)maximumTextureSize / sourceHeight));
            scale = Math.Min(scale, Math.Sqrt(MaximumOutputPixels / sourcePixels));
            scale = Math.Min(scale, Math.Sqrt(
                MaximumOutputRgbaBytes / (sourcePixels * RgbaBytesPerPixel)));
            if (double.IsNaN(scale) || double.IsInfinity(scale) || scale <= 0d)
                return false;

            int outputWidth = Math.Max(1, (int)Math.Floor(sourceWidth * scale));
            int outputHeight = Math.Max(1, (int)Math.Floor(sourceHeight * scale));
            if (outputWidth < MinimumReadableOutputWidth ||
                !CanAllocateOutput(outputWidth, outputHeight, maximumTextureSize, out _))
                return false;

            plan = new LifeCardCaptureOutputPlan(
                sourceWidth,
                sourceHeight,
                outputWidth,
                outputHeight);
            return true;
        }

        public static bool CanAllocateOutput(
            int width,
            int height,
            int maximumTextureSize,
            out long rgbaBytes)
        {
            rgbaBytes = 0;
            if (width < 16 || height < 16 || maximumTextureSize < 16 ||
                width > maximumTextureSize || height > maximumTextureSize)
                return false;

            long pixels = (long)width * height;
            if (pixels <= 0) return false;
            rgbaBytes = pixels * RgbaBytesPerPixel;
            return pixels <= MaximumOutputPixels &&
                rgbaBytes > 0 && rgbaBytes <= MaximumOutputRgbaBytes;
        }

        public static bool CanUseColor32Buffer(int width, int height, out long bufferBytes)
        {
            bufferBytes = 0;
            if (width <= 0 || height <= 0) return false;
            long pixels = (long)width * height;
            if (pixels <= 0) return false;
            bufferBytes = pixels * RgbaBytesPerPixel;
            return bufferBytes > 0 && bufferBytes <= MaximumColor32BufferBytes;
        }

        public static int SourcePixelForDestination(
            int destinationPixel,
            int destinationSize,
            int sourceSize)
        {
            if (destinationSize <= 0) throw new ArgumentOutOfRangeException(nameof(destinationSize));
            if (sourceSize <= 0) throw new ArgumentOutOfRangeException(nameof(sourceSize));
            if (destinationPixel < 0 || destinationPixel >= destinationSize)
                throw new ArgumentOutOfRangeException(nameof(destinationPixel));
            long numerator = ((long)destinationPixel * 2L + 1L) * sourceSize;
            return Math.Min(sourceSize - 1, (int)(numerator / (destinationSize * 2L)));
        }

        public static IReadOnlyList<LifeCardCaptureTile> PlanScaledDestinationTiles(
            int sourceHeight,
            int outputHeight,
            int sourceViewportHeight)
        {
            IReadOnlyList<LifeCardCaptureTile> sourceTiles = Plan(
                sourceHeight,
                sourceViewportHeight);
            var output = new List<LifeCardCaptureTile>();
            int destinationTop = 0;
            foreach (LifeCardCaptureTile source in sourceTiles)
            {
                int destinationBottom = destinationTop;
                while (destinationBottom < outputHeight &&
                       SourcePixelForDestination(
                           destinationBottom,
                           outputHeight,
                           sourceHeight) < source.PixelBottom)
                    destinationBottom++;
                if (destinationBottom > destinationTop)
                    output.Add(new LifeCardCaptureTile(
                        destinationTop,
                        destinationBottom - destinationTop));
                destinationTop = destinationBottom;
            }
            if (destinationTop != outputHeight)
                throw new InvalidOperationException("Scaled capture tiles did not cover the output.");
            return output;
        }

        public static int NextPixelTop(int fullHeight, int currentPixelTop, int tileHeight)
        {
            if (fullHeight <= 0) throw new ArgumentOutOfRangeException(nameof(fullHeight));
            if (currentPixelTop < 0 || currentPixelTop >= fullHeight)
                throw new ArgumentOutOfRangeException(nameof(currentPixelTop));
            if (tileHeight <= 0 || tileHeight > fullHeight - currentPixelTop)
                throw new ArgumentOutOfRangeException(nameof(tileHeight));
            return currentPixelTop + tileHeight;
        }

        public static IReadOnlyList<LifeCardCaptureTile> Plan(int fullHeight, int viewportHeight)
        {
            if (fullHeight <= 0) throw new ArgumentOutOfRangeException(nameof(fullHeight));
            if (viewportHeight <= 0) throw new ArgumentOutOfRangeException(nameof(viewportHeight));
            var result = new List<LifeCardCaptureTile>();
            int top = 0;
            while (top < fullHeight)
            {
                int height = Math.Min(viewportHeight, fullHeight - top);
                result.Add(new LifeCardCaptureTile(top, height));
                top = NextPixelTop(fullHeight, top, height);
            }
            return result;
        }
    }
}
