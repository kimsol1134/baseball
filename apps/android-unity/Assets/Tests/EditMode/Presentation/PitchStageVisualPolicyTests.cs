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
            Assert.That(PitchStageVisualPolicy.HasRequiredSprites(true), Is.True);
            Assert.That(PitchStageVisualPolicy.HasRequiredSprites(false), Is.False);
            Assert.That(PitchStageVisualPolicy.ShaderResourcePath, Is.EqualTo("PitchStageUnlit"));
            Assert.That(PitchStageVisualPolicy.ShaderName, Is.EqualTo("Baseball/PitchStageUnlit"));
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
            string shader = File.ReadAllText(FindFromParents(
                "apps/android-unity/Assets/Game/Presentation/Pitch/Resources/PitchStageUnlit.shader"));
            string build = File.ReadAllText(FindFromParents(
                "apps/android-unity/Assets/Game/Editor/Build/AndroidBuild.cs"));
            string graphics = File.ReadAllText(FindFromParents(
                "apps/android-unity/ProjectSettings/GraphicsSettings.asset"));
            string shaderMeta = File.ReadAllText(FindFromParents(
                "apps/android-unity/Assets/Game/Presentation/Pitch/Resources/PitchStageUnlit.shader.meta"));

            Assert.That(stage, Does.Contain("PrimitiveType.Sphere"), "the authoritative ball remains 3D");
            Assert.That(stage, Does.Not.Contain("PrimitiveType.Capsule"));
            Assert.That(stage, Does.Not.Contain("PrimitiveType.Cube"));
            Assert.That(stage, Does.Not.Contain("Batter Stance Billboard"));
            Assert.That(stage, Does.Not.Contain("Catcher Stance Billboard"));
            Assert.That(stage, Does.Not.Contain("AnimateActors"));
            Assert.That(stage, Does.Not.Contain("CameraClearFlags.SolidColor"));
            Assert.That(stage, Does.Contain("SpriteRenderer"));
            Assert.That(stage, Does.Contain("pitch.stage_visual_assets_not_ready"));
            Assert.That(stage, Does.Contain("Resources.Load<Shader>"));
            Assert.That(stage, Does.Contain("PitchStageVisualPolicy.ShaderUnavailableError"));
            Assert.That(stage, Does.Contain("BASEBALL_PITCH_STAGE_SHADER_READY schema=1 status=passed"));
            Assert.That(stage, Does.Not.Contain("Shader.Find("),
                "runtime shader-name lookup can be stripped from an IL2CPP player");
            Assert.That(shader, Does.Contain("Shader \"Baseball/PitchStageUnlit\""));
            Assert.That(shader, Does.Contain("RenderPipeline"));
            Assert.That(build, Does.Contain("ValidatePitchStageShaderResource();"));
            Assert.That(build, Does.Contain("EnsurePitchStageShaderAlwaysIncluded();"));
            Assert.That(build, Does.Contain("m_AlwaysIncludedShaders"));
            Assert.That(build, Does.Contain("SerializedObject"));
            Assert.That(build, Does.Contain("PitchStageUnlit.shader"));
            Assert.That(build, Does.Contain("vulnerable to shader stripping"));
            Assert.That(shaderMeta, Does.Contain("guid: 79f07846e39b46c986657c06a0d5cc1a"));
            Assert.That(graphics, Does.Contain(
                "{fileID: 4800000, guid: 79f07846e39b46c986657c06a0d5cc1a, type: 3}"));
            Assert.That(coordinator, Does.Contain("await _stage.PrepareVisualsAsync"));
            Assert.That(coordinator, Does.Contain("저장된 경기 상태는 그대로 보존됩니다"));
            Assert.That(coordinator, Does.Contain("투구 렌더링 재료를 이 기기에서 준비하지 못했습니다"));
            int completed = coordinator.IndexOf("private void OnPresentationCompleted", StringComparison.Ordinal);
            int durableMarker = coordinator.IndexOf("_completionMarker.TryMark", completed, StringComparison.Ordinal);
            int consume = coordinator.IndexOf("ConsumeActivePresentation();", completed, StringComparison.Ordinal);
            Assert.That(durableMarker, Is.GreaterThan(completed));
            Assert.That(consume, Is.GreaterThan(durableMarker));
            Assert.That(coordinator, Does.Contain("#if !BASEBALL_INTERNAL_QA"));
            Assert.That(coordinator, Does.Contain("PitchPresentationCompletionMarker.LogLine"));
            Assert.That(manifest, Does.Contain("\"logicalName\": \"KeyArtStadiumNight\""));
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
