using System;
using System.Collections;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Baseball.Core.Domain;
using Baseball.Core.Pitching;
using Baseball.Platform.Crash;
using Baseball.Presentation.Pitch;
using Baseball.Presentation.Shell;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.Rendering.Universal;
using UnityEngine.TestTools;

namespace Baseball.PlayMode.Tests
{
    [TestFixture]
    public sealed class PitchStagePlayModeTests
    {
        [UnityTest]
        public IEnumerator AuthoritativeSnapshotPublishesReadableThenCompletedWhenSkipped()
        {
            yield return ExerciseStage(reducedMotion: false, requestSkip: true);
        }

        [UnityTest]
        public IEnumerator ReducedMotionPresentationStillPublishesBothBoundaries()
        {
            yield return ExerciseStage(reducedMotion: true, requestSkip: false);
        }

        [UnityTest]
        public IEnumerator ContactFlightCameraFollowsAuthoritativeArcAndSkipRestoresCatcherView()
        {
            var stageObject = new GameObject("Contact Camera Pitch Stage");
            var stage = stageObject.AddComponent<PitchStageController>();
            yield return PrepareStage(stage);
            Camera camera = stageObject.GetComponentInChildren<Camera>();
            Transform ball = stageObject.transform.Find("Authoritative Pitch Ball");
            Assert.That(camera, Is.Not.Null);
            Assert.That(ball, Is.Not.Null);
            Vector3 catcherView = camera.transform.position;
            bool readable = false;
            bool completed = false;
            stage.ResultReadable += _ => readable = true;
            stage.PresentationCompleted += _ => completed = true;

            stage.Play(CreateContactSnapshot());
            yield return PlayModeDeadline.Until(
                () => readable,
                "접촉 결과의 readable 경계가 게시되지 않았습니다.",
                2f);
            yield return PlayModeDeadline.Until(
                () => Vector3.Distance(camera.transform.position, catcherView) > 1f,
                "접촉 뒤 카메라가 결정된 타구 궤적을 따라가지 않았습니다.",
                2f);

            Vector3 cameraToBall = (ball.position - camera.transform.position).normalized;
            Assert.That(Vector3.Dot(camera.transform.forward, cameraToBall), Is.GreaterThan(0.94f));
            Assert.That(ball.position.z, Is.GreaterThan(1f));

            stage.RequestSkip();
            yield return PlayModeDeadline.Until(
                () => completed,
                "타구 follow 중 skip 뒤 presentation이 완료되지 않았습니다.",
                2f);
            Assert.That(Vector3.Distance(camera.transform.position, catcherView), Is.LessThan(0.01f));

            UnityEngine.Object.Destroy(stageObject);
            yield return null;
            Assert.That(UnityEngine.Application.targetFrameRate, Is.EqualTo(60));
        }

        [UnityTest]
        public IEnumerator ReducedMotionContactKeepsCatcherViewAndCompletesWithinDeadline()
        {
            var stageObject = new GameObject("Reduced Contact Camera Pitch Stage");
            var stage = stageObject.AddComponent<PitchStageController>();
            yield return PrepareStage(stage);
            stage.ReducedMotion = true;
            Camera camera = stageObject.GetComponentInChildren<Camera>();
            Vector3 catcherView = camera.transform.position;
            bool completed = false;
            stage.PresentationCompleted += _ => completed = true;

            stage.Play(CreateContactSnapshot());
            float deadline = Time.realtimeSinceStartup + 2f;
            float maximumCameraTravel = 0f;
            while (!completed && Time.realtimeSinceStartup < deadline)
            {
                maximumCameraTravel = Mathf.Max(
                    maximumCameraTravel,
                    Vector3.Distance(camera.transform.position, catcherView));
                yield return null;
            }

            Assert.That(completed, Is.True, "reduced-motion 접촉 presentation이 2초 안에 완료되지 않았습니다.");
            Assert.That(maximumCameraTravel, Is.LessThan(0.01f));
            Assert.That(Vector3.Distance(camera.transform.position, catcherView), Is.LessThan(0.01f));

            UnityEngine.Object.Destroy(stageObject);
            yield return null;
        }

        [UnityTest]
        public IEnumerator LowMemoryForcesLowQualityWithoutChangingAuthoritativeResult()
        {
            CrashReporting.Reset();
            var stageObject = new GameObject("Low Memory Pitch Stage");
            var stage = stageObject.AddComponent<PitchStageController>();
            yield return PrepareStage(stage);
            var trail = stageObject.GetComponentInChildren<TrailRenderer>();
            var particles = stageObject.GetComponentInChildren<ParticleSystem>();
            PitchPresentationSnapshot expected = CreateContactSnapshot();
            PitchPresentationSnapshot readable = null;
            PitchPresentationSnapshot completed = null;
            stage.ResultReadable += snapshot => readable = snapshot;
            stage.PresentationCompleted += snapshot => completed = snapshot;

            stageObject.SendMessage("ApplyQuality", PitchQualityTier.High, SendMessageOptions.RequireReceiver);
            Assert.That(stage.QualityTier, Is.EqualTo(PitchQualityTier.High));
            Assert.That(CrashRuntimeDiagnostics.CurrentQualityTier, Is.EqualTo("high"));
            Assert.That(trail.minVertexDistance, Is.EqualTo(0.035f).Within(0.001f));
            Assert.That(particles.main.maxParticles, Is.EqualTo(24));

            stage.Play(expected);
            yield return null;
            stageObject.SendMessage("HandleLowMemory", SendMessageOptions.RequireReceiver);
            Assert.That(stage.QualityTier, Is.EqualTo(PitchQualityTier.Low));
            Assert.That(CrashRuntimeDiagnostics.CurrentQualityTier, Is.EqualTo("low"));
            Assert.That(trail.minVertexDistance, Is.EqualTo(0.07f).Within(0.001f));
            Assert.That(particles.main.maxParticles, Is.EqualTo(8));
            Assert.That(QualitySettings.antiAliasing, Is.Zero);
            Assert.That(UnityEngine.Application.targetFrameRate, Is.EqualTo(30));
            Assert.That(UniversalRenderPipeline.asset, Is.Not.Null);
            Assert.That(UniversalRenderPipeline.asset.renderScale, Is.EqualTo(0.85f).Within(0.001f));

            yield return PlayModeDeadline.Until(
                () => completed != null,
                "low-memory 품질 전환 뒤 presentation이 완료되지 않았습니다.",
                3f);
            Assert.That(readable, Is.SameAs(expected));
            Assert.That(completed, Is.SameAs(expected));

            UnityEngine.Object.Destroy(stageObject);
            yield return null;
            Assert.That(UnityEngine.Application.targetFrameRate, Is.EqualTo(60));
            CrashReporting.Reset();
        }

        [UnityTest]
        public IEnumerator RequiredArtworkFramesPortraitAndReleasesAllLeases()
        {
            var stageObject = new GameObject("Portrait Artwork Pitch Stage");
            var stage = stageObject.AddComponent<PitchStageController>();
            var loader = new FakeStageVisualAssetLoader();
            Camera camera = stageObject.GetComponentInChildren<Camera>();
            camera.aspect = 9f / 16f;

            yield return Await(stage.PrepareVisualsAsync(loader, CancellationToken.None), true);
            yield return null;

            Assert.That(stage.VisualsReady, Is.True);
            Assert.That(camera.enabled, Is.True);
            Transform backdrop = stageObject.transform.Find("Virtual Ballpark Backdrop");
            Transform batter = stageObject.transform.Find("Batter Stance Billboard");
            Transform catcher = stageObject.transform.Find("Catcher Stance Billboard");
            Assert.That(backdrop, Is.Not.Null);
            Assert.That(batter, Is.Not.Null);
            Assert.That(catcher, Is.Not.Null);
            Assert.That(camera.WorldToViewportPoint(batter.position).x, Is.InRange(0.05f, 0.95f));
            Assert.That(camera.WorldToViewportPoint(catcher.position).x, Is.InRange(0.05f, 0.95f));

            SpriteRenderer backdropRenderer = backdrop.GetComponent<SpriteRenderer>();
            Vector3 minimum = camera.WorldToViewportPoint(backdrop.TransformPoint(
                backdropRenderer.sprite.bounds.min));
            Vector3 maximum = camera.WorldToViewportPoint(backdrop.TransformPoint(
                backdropRenderer.sprite.bounds.max));
            Assert.That(minimum.x, Is.LessThanOrEqualTo(0f));
            Assert.That(minimum.y, Is.LessThanOrEqualTo(0f));
            Assert.That(maximum.x, Is.GreaterThanOrEqualTo(1f));
            Assert.That(maximum.y, Is.GreaterThanOrEqualTo(1f));

            UnityEngine.Object.Destroy(stageObject);
            yield return null;
            Assert.That(loader.DisposedCount, Is.EqualTo(3));
        }

        [UnityTest]
        public IEnumerator MissingRequiredArtworkFailsClosedWithoutActorPrimitives()
        {
            var stageObject = new GameObject("Missing Artwork Pitch Stage");
            var stage = stageObject.AddComponent<PitchStageController>();
            var loader = new FakeStageVisualAssetLoader(missingCatcher: true);

            yield return Await(stage.PrepareVisualsAsync(loader, CancellationToken.None), false);

            Assert.That(stage.VisualsReady, Is.False);
            Assert.That(stageObject.GetComponentInChildren<Camera>().enabled, Is.False);
            Assert.That(stageObject.transform.Find("Batter Stance Billboard"), Is.Null);
            Assert.That(stageObject.transform.Find("Catcher Stance Billboard"), Is.Null);
            Assert.That(() => stage.Play(CreateContactSnapshot()),
                Throws.TypeOf<InvalidOperationException>());
            Assert.That(loader.DisposedCount, Is.EqualTo(2));

            UnityEngine.Object.Destroy(stageObject);
            yield return null;
        }

        private static IEnumerator ExerciseStage(bool reducedMotion, bool requestSkip)
        {
            var presenter = new PitchPlayPresenter(CreatePitchRequest());
            presenter.Start();
            presenter.BeginRelease();
            presenter.AdvanceRelease(0.23d);
            PitchCommit commit = presenter.SubmitRelease();
            Assert.That(commit.Result.Snapshot.Execution, Is.Not.Null);
            Assert.That(commit.Presentation.AccessibilitySummary, Is.EqualTo(commit.Result.Snapshot.AccessibilitySummary));

            var stageObject = new GameObject(reducedMotion ? "Reduced Motion Pitch Stage" : "Skipped Pitch Stage");
            var stage = stageObject.AddComponent<PitchStageController>();
            yield return PrepareStage(stage);
            stage.ReducedMotion = reducedMotion;
            var eventOrder = new List<string>();
            PitchPlayPhase readablePhase = PitchPlayPhase.Idle;
            PitchPresentationSnapshot readable = null;
            PitchPresentationSnapshot completed = null;
            stage.ResultReadable += snapshot =>
            {
                readable = snapshot;
                eventOrder.Add("readable");
                presenter.MarkResultReadable(snapshot);
                readablePhase = presenter.Phase;
            };
            stage.PresentationCompleted += snapshot =>
            {
                completed = snapshot;
                eventOrder.Add("completed");
                presenter.CompletePresentation(snapshot);
            };

            stage.Play(commit.Presentation);
            yield return null;
            if (requestSkip) stage.RequestSkip();
            yield return PlayModeDeadline.Until(
                () => completed != null,
                "PitchStage가 presentation 완료 경계를 게시하지 않았습니다.",
                3f);

            Assert.That(readable, Is.SameAs(commit.Presentation));
            Assert.That(completed, Is.SameAs(commit.Presentation));
            Assert.That(eventOrder, Is.EqualTo(new[] { "readable", "completed" }));
            Assert.That(readablePhase, Is.EqualTo(PitchPlayPhase.Result));
            Assert.That(
                presenter.Phase,
                Is.EqualTo(PitchPlayPhase.Selecting).Or.EqualTo(PitchPlayPhase.Completed));
            Assert.That(stage.ReducedMotion, Is.EqualTo(reducedMotion));

            UnityEngine.Object.Destroy(stageObject);
            yield return null;
        }

        private static PitchPlayRequest CreatePitchRequest()
        {
            var pitcher = new PitcherSnapshot(
                "pitcher-hangyeol",
                "한결",
                62,
                56,
                58,
                60,
                new[]
                {
                    new PitchProfileSnapshot(PitchType.FourSeam, PitchUsageRole.Primary, 1450, 59, 58, 55, 62, 55, 1),
                    new PitchProfileSnapshot(PitchType.Slider, PitchUsageRole.Secondary, 1320, 57, 56, 63, 64, 61, 1),
                    new PitchProfileSnapshot(PitchType.Curveball, PitchUsageRole.Secondary, 1210, 55, 54, 65, 57, 62, 1),
                    new PitchProfileSnapshot(PitchType.Changeup, PitchUsageRole.Development, 1280, 52, 51, 57, 55, 60, 1),
                });
            return new PitchPlayRequest(
                "2026081108",
                pitcher,
                new BatterSnapshot("batter-doyun", "도윤", 57, 54, 61, BatSide.Right),
                new BatterScoutingSnapshot(
                    new PitchZone(1, 1),
                    new PitchZone(2, 0),
                    PitchType.FourSeam,
                    PitchType.Slider,
                    48),
                new PlateAppearanceContext(
                    "highschool-pa-1",
                    0,
                    8,
                    1,
                    0,
                    0,
                    1,
                    1,
                    810,
                    42),
                gameState: GameStateSnapshot.Standard,
                gameLog: new GameLogSnapshot(
                    "highschool-game",
                    0,
                    0,
                    Array.Empty<PitchAnalysisEntry>()));
        }

        private static IEnumerator PrepareStage(PitchStageController stage)
        {
            yield return Await(
                stage.PrepareVisualsAsync(new FakeStageVisualAssetLoader(), CancellationToken.None),
                true);
        }

        private static IEnumerator Await(Task<bool> task, bool expected)
        {
            while (!task.IsCompleted) yield return null;
            if (task.IsFaulted) throw task.Exception;
            Assert.That(task.Result, Is.EqualTo(expected));
        }

        private sealed class FakeStageVisualAssetLoader : IBaseballVisualAssetLoader
        {
            private readonly bool _missingCatcher;

            public FakeStageVisualAssetLoader(bool missingCatcher = false)
            {
                _missingCatcher = missingCatcher;
            }

            public int DisposedCount { get; private set; }

            public Task<IBaseballVisualAssetLease> LoadSpriteAsync(
                string address,
                CancellationToken cancellationToken)
            {
                cancellationToken.ThrowIfCancellationRequested();
                if (_missingCatcher && address == PitchStageVisualPolicy.CatcherAddress)
                    return Task.FromResult<IBaseballVisualAssetLease>(null);
                int width = address == PitchStageVisualPolicy.StadiumAddress ? 1290 :
                    address == PitchStageVisualPolicy.BatterAddress ? 613 : 694;
                int height = address == PitchStageVisualPolicy.StadiumAddress ? 725 : 850;
                var texture = new Texture2D(width, height, TextureFormat.RGBA32, false);
                Sprite sprite = Sprite.Create(
                    texture,
                    new Rect(0f, 0f, width, height),
                    new Vector2(0.5f, 0.5f),
                    100f);
                return Task.FromResult<IBaseballVisualAssetLease>(
                    new FakeLease(sprite, texture, () => DisposedCount++));
            }
        }

        private sealed class FakeLease : IBaseballVisualAssetLease
        {
            private readonly Texture2D _texture;
            private readonly Action _onDispose;
            private bool _disposed;

            public FakeLease(Sprite sprite, Texture2D texture, Action onDispose)
            {
                Sprite = sprite;
                _texture = texture;
                _onDispose = onDispose;
            }

            public Sprite Sprite { get; }

            public void Dispose()
            {
                if (_disposed) return;
                UnityEngine.Object.Destroy(Sprite);
                UnityEngine.Object.Destroy(_texture);
                _onDispose();
                _disposed = true;
            }
        }

        private static PitchPresentationSnapshot CreateContactSnapshot()
        {
            return new PitchPresentationSnapshot(
                "playmode-contact-camera",
                PitchType.FourSeam,
                0.08d,
                0.12d,
                146.2d,
                0.08d,
                new[]
                {
                    new TrajectoryPoint(0d, 0d, 1.85d, 18.44d),
                    new TrajectoryPoint(1d, 0.04d, 0.79d, 0d)
                },
                PitchOutcome.Double,
                SwingPresentation.Contact,
                new ContactPresentation(156d, 24d, 12d, 830),
                new FieldingPresentation(
                    FieldingSector.Outfield,
                    PitchOutcome.Double,
                    34d,
                    1.2d,
                    7d,
                    "결정된 외야 타구"),
                new ScoreDelta(0),
                PitchAudioCue.HardContact,
                PitchHapticCue.Contact,
                0xC0FFEEUL,
                "우중간 2루타" );
        }
    }
}
