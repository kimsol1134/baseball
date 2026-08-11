using Baseball.Presentation.Shell;
using NUnit.Framework;

namespace Baseball.Presentation.Tests.Screens
{
    public sealed class ContentExposurePolicyTests
    {
        [Test]
        public void OffscreenContentDoesNotExposeUntilItScrollsIntoViewport()
        {
            var gate = new ContentExposureGate();
            Assert.That(gate.TryExpose(
                true, true, 0f, 700f, 300f, 800f, 0f, 0f, 300f, 600f), Is.False);
            Assert.That(gate.TryExpose(
                true, true, 0f, 550f, 300f, 650f, 0f, 0f, 300f, 600f), Is.True);
            Assert.That(gate.TryExpose(
                true, true, 0f, 100f, 300f, 200f, 0f, 0f, 300f, 600f), Is.False);
        }

        [Test]
        public void DetachedHiddenAndZeroGeometryNeverExpose()
        {
            var detached = new ContentExposureGate();
            Assert.That(detached.TryExpose(
                false, true, 0f, 0f, 10f, 10f, 0f, 0f, 20f, 20f), Is.False);
            var hidden = new ContentExposureGate();
            Assert.That(hidden.TryExpose(
                true, false, 0f, 0f, 10f, 10f, 0f, 0f, 20f, 20f), Is.False);
            var unlaidOut = new ContentExposureGate();
            Assert.That(unlaidOut.TryExpose(
                true, true, 0f, 0f, 0f, 0f, 0f, 0f, 20f, 20f), Is.False);
        }

        [Test]
        public void ReRenderOfSameContentIsSuppressedButChangedInstanceCanExpose()
        {
            var deduplicator = new ContentExposureDeduplicator();
            Assert.That(deduplicator.TryMark("prologue", "player-legacy-letter", "life-1"), Is.True);
            Assert.That(deduplicator.TryMark("prologue", "player-legacy-letter", "life-1"), Is.False);
            Assert.That(deduplicator.TryMark("prologue", "player-legacy-letter", "life-2"), Is.True);
        }
    }
}
