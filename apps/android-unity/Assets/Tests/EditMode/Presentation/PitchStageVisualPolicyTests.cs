using System;
using System.IO;
using Baseball.Presentation.Pitch;
using NUnit.Framework;

namespace Baseball.Presentation.Tests
{
    public sealed class PitchStageVisualPolicyTests
    {
        [Test]
        public void ProductionAddressesUseImportedLocalArt()
        {
            Assert.That(PitchStageVisualPolicy.StadiumAddress,
                Is.EqualTo("baseball/highschool/KeyArtStadiumNight"));
            Assert.That(PitchStageVisualPolicy.BatterAddress,
                Is.EqualTo("baseball/pitch/BatterStance"));
            Assert.That(PitchStageVisualPolicy.CatcherAddress,
                Is.EqualTo("baseball/pitch/CatcherStance"));
            Assert.That(PitchStageVisualPolicy.HasRequiredSprites(true, true, true), Is.True);
            Assert.That(PitchStageVisualPolicy.HasRequiredSprites(true, false, true), Is.False);
        }

        [Test]
        public void StadiumCoverScaleFillsPortraitAndLandscapeWithoutStretching()
        {
            float portrait = PitchStageVisualPolicy.CoverScale(12.9f, 7.25f, 22f, 50f, 9f / 16f);
            float landscape = PitchStageVisualPolicy.CoverScale(12.9f, 7.25f, 22f, 50f, 21f / 9f);

            Assert.That(portrait * 7.25f, Is.GreaterThanOrEqualTo(
                2f * 22f * (float)Math.Tan(25f * Math.PI / 180d)));
            Assert.That(landscape, Is.GreaterThan(portrait));
            Assert.That(() => PitchStageVisualPolicy.CoverScale(0f, 1f, 1f, 50f, 1f),
                Throws.TypeOf<ArgumentOutOfRangeException>());
        }

        [Test]
        public void ProductionStageHasNoActorOrPlatePrimitiveFallbackAndManifestOwnsArtwork()
        {
            string stage = File.ReadAllText(FindFromParents(
                "apps/android-unity/Assets/Game/Presentation/Pitch/Runtime/PitchStageController.cs"));
            string coordinator = File.ReadAllText(FindFromParents(
                "apps/android-unity/Assets/Game/Presentation/Pitch/Runtime/PitchShellFlowCoordinator.cs"));
            string manifest = File.ReadAllText(FindFromParents(
                "apps/android-unity/Assets/Game/Content/Manifests/asset-manifest.json"));

            Assert.That(stage, Does.Contain("PrimitiveType.Sphere"), "the authoritative ball remains 3D");
            Assert.That(stage, Does.Not.Contain("PrimitiveType.Capsule"));
            Assert.That(stage, Does.Not.Contain("PrimitiveType.Cube"));
            Assert.That(stage, Does.Not.Contain("CameraClearFlags.SolidColor"));
            Assert.That(stage, Does.Contain("SpriteRenderer"));
            Assert.That(stage, Does.Contain("pitch.stage_visual_assets_not_ready"));
            Assert.That(coordinator, Does.Contain("await _stage.PrepareVisualsAsync"));
            Assert.That(coordinator, Does.Contain("저장된 경기 상태는 그대로 보존됩니다"));
            foreach (string logicalName in new[]
                     {
                         "KeyArtStadiumNight", "BatterStance", "CatcherStance"
                     })
            {
                Assert.That(manifest, Does.Contain("\"logicalName\": \"" + logicalName + "\""));
            }
            Assert.That(manifest, Does.Contain("\"addressableLabel\": \"pitch\""));
            Assert.That(manifest, Does.Contain("\"addressableLabel\": \"highschool\""));
        }

        private static string FindFromParents(string relativePath)
        {
            DirectoryInfo current = new DirectoryInfo(TestContext.CurrentContext.TestDirectory);
            while (current != null)
            {
                string candidate = Path.Combine(current.FullName, relativePath);
                if (File.Exists(candidate)) return candidate;
                current = current.Parent;
            }
            throw new FileNotFoundException("Repository source was not found.", relativePath);
        }
    }
}
