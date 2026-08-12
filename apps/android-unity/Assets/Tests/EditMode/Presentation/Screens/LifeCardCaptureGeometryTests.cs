using System.Linq;
using Baseball.Presentation.Records;
using NUnit.Framework;

namespace Baseball.Presentation.Tests.Screens
{
    public sealed class LifeCardCaptureGeometryTests
    {
        [Test]
        public void TwoHundredPercentTallCardCoversEveryPixelIncludingBottomMarker()
        {
            const int fullCardHeight = 8640;
            const int portraitViewportHeight = 1314;
            var tiles = LifeCardCaptureGeometry.Plan(fullCardHeight, portraitViewportHeight);

            Assert.That(tiles.Count, Is.GreaterThan(1));
            Assert.That(tiles[0].PixelTop, Is.Zero);
            for (int index = 1; index < tiles.Count; index++)
                Assert.That(tiles[index].PixelTop, Is.EqualTo(tiles[index - 1].PixelBottom));
            Assert.That(tiles.Sum(tile => tile.Height), Is.EqualTo(fullCardHeight));
            Assert.That(tiles[tiles.Count - 1].PixelBottom, Is.EqualTo(fullCardHeight),
                "the footer/bottom marker must be inside the encoded PNG");
        }

        [Test]
        public void FullContentOutputHeightIsNotClampedToPortraitViewport()
        {
            var tiles = LifeCardCaptureGeometry.Plan(6200, 844);
            Assert.That(tiles.Count, Is.EqualTo(8));
            Assert.That(tiles[tiles.Count - 1].Height, Is.EqualTo(292));
            Assert.That(tiles[tiles.Count - 1].PixelBottom, Is.EqualTo(6200));
        }

        [Test]
        public void OutputAllocationFailsClosedAgainstDeviceAndMemoryLimitsWithoutLatchingRetry()
        {
            Assert.That(LifeCardCaptureGeometry.TryPlanOutput(
                1080,
                8640,
                8192,
                out LifeCardCaptureOutputPlan scaled), Is.True);
            Assert.That(scaled.OutputWidth, Is.EqualTo(1024));
            Assert.That(scaled.OutputHeight, Is.EqualTo(8192));
            Assert.That(scaled.IsDownscaled, Is.True,
                "the complete card must be uniformly downscaled instead of falling back to text");

            Assert.That(LifeCardCaptureGeometry.TryPlanOutput(
                4096,
                4096,
                512,
                out _), Is.False,
                "a final image below the readable portrait width must use text fallback");

            Assert.That(LifeCardCaptureGeometry.TryPlanOutput(
                1080,
                6200,
                8192,
                out LifeCardCaptureOutputPlan retry), Is.True,
                "a later bounded attempt remains available after an earlier initialization failure");
            Assert.That(retry.OutputWidth, Is.EqualTo(1080));
            Assert.That(retry.OutputHeight, Is.EqualTo(6200));
            Assert.That(LifeCardCaptureGeometry.CanAllocateOutput(
                retry.OutputWidth,
                retry.OutputHeight,
                8192,
                out long acceptedBytes), Is.True);
            Assert.That(acceptedBytes, Is.EqualTo(1080L * 6200L * 4L));
            Assert.That(acceptedBytes, Is.LessThanOrEqualTo(
                LifeCardCaptureGeometry.MaximumOutputRgbaBytes));
        }

        [Test]
        public void TileReadBufferIsBoundedBeforeUnityAllocatesColorArray()
        {
            Assert.That(LifeCardCaptureGeometry.CanUseColor32Buffer(
                1080,
                1920,
                out long acceptedBytes), Is.True);
            Assert.That(acceptedBytes, Is.EqualTo(1080L * 1920L * 4L));

            Assert.That(LifeCardCaptureGeometry.CanUseColor32Buffer(
                4096,
                4096,
                out long rejectedBytes), Is.False);
            Assert.That(rejectedBytes, Is.GreaterThan(
                LifeCardCaptureGeometry.MaximumColor32BufferBytes));
        }

        [Test]
        public void DownscaledTilesCoverEveryDestinationPixelAndBottomMarkerExactlyOnce()
        {
            const int sourceHeight = 8640;
            const int outputHeight = 8192;
            var tiles = LifeCardCaptureGeometry.PlanScaledDestinationTiles(
                sourceHeight,
                outputHeight,
                1314);

            Assert.That(tiles[0].PixelTop, Is.Zero);
            for (int index = 1; index < tiles.Count; index++)
                Assert.That(tiles[index].PixelTop, Is.EqualTo(tiles[index - 1].PixelBottom));
            Assert.That(tiles.Sum(value => value.Height), Is.EqualTo(outputHeight));
            Assert.That(tiles[tiles.Count - 1].PixelBottom, Is.EqualTo(outputHeight));
            Assert.That(LifeCardCaptureGeometry.SourcePixelForDestination(
                outputHeight - 1,
                outputHeight,
                sourceHeight), Is.EqualTo(sourceHeight - 1),
                "the last output row samples the source footer/bottom marker");
        }
    }
}
