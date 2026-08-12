using System;
using System.Collections;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Baseball.Platform.Crash;
using Baseball.Presentation.Shell;
using UnityEngine;
using UnityEngine.Rendering.Universal;

namespace Baseball.Presentation.Pitch
{
    /// <summary>
    /// Prefab-free mobile pitch stage. It consumes a committed snapshot and never performs gameplay physics.
    /// </summary>
    public sealed class PitchStageController : MonoBehaviour
    {
        private const float ResultHoldSeconds = 0.70f;
        public const float RecoveredSummaryMaximumSeconds = 0.50f;
        private const float RecoveredSummaryHoldSeconds = 0.35f;
        private const int FrameSampleCapacity = 90;
        private const string ShaderReadyMarker =
            "BASEBALL_PITCH_STAGE_SHADER_READY schema=1 status=passed";
        private static bool _shaderReadyMarkerLogged;
        private static readonly Vector3 DefaultCameraPosition = new Vector3(0f, 1.20f, -2.35f);
        private static readonly Vector3 DefaultCameraTarget = new Vector3(0f, 1.15f, 7.2f);
        private static readonly Vector3 BatterRestPosition = new Vector3(0.27f, 0.88f, 0.30f);
        private static readonly Vector3 CatcherRestPosition = new Vector3(-0.22f, 0.69f, -0.34f);
        private const float StadiumLayerDistance = 22f;

        [SerializeField] private Camera stageCamera;
        [SerializeField] private bool reducedMotion;
        [SerializeField, Range(45f, 55f)] private float verticalFieldOfView = 50f;

        private Transform _ball;
        private TrailRenderer _trail;
        private Transform _batterBody;
        private Transform _catcherBody;
        private SpriteRenderer _stadiumRenderer;
        private SpriteRenderer _batterRenderer;
        private SpriteRenderer _catcherRenderer;
        private LineRenderer _fieldChalk;
        private ParticleSystem _contactParticles;
        private IBaseballVisualAssetLease _stadiumLease;
        private IBaseballVisualAssetLease _batterLease;
        private IBaseballVisualAssetLease _catcherLease;
        private readonly List<Material> _runtimeMaterials = new List<Material>();
        private readonly float[] _frameMilliseconds = new float[FrameSampleCapacity];
        private Coroutine _activePresentation;
        private bool _skipRequested;
        private int _frameSampleCount;
        private PitchQualityTier _qualityTier;
        private bool _qualityGlobalsCaptured;
        private int _originalAntiAliasing;
        private int _originalTargetFrameRate;
        private float _originalWidthScale;
        private float _originalHeightScale;
        private UniversalRenderPipelineAsset _renderPipeline;
        private float _originalRenderScale;
        private int _originalUrpMsaa;
        private bool _visualsReady;
        private float _lastBackdropAspect = -1f;
        private Shader _stageShader;
        private bool _shaderFailureLogged;

        public event Action<PitchPresentationSnapshot> ResultReadable;
        public event Action<PitchPresentationSnapshot> PresentationCompleted;

        public bool ReducedMotion
        {
            get => reducedMotion;
            set => reducedMotion = value;
        }

        public PitchQualityTier QualityTier => _qualityTier;
        public bool VisualsReady => _visualsReady;
        public string VisualPreparationError { get; private set; }

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
        private static void ResetShaderMarker()
        {
            _shaderReadyMarkerLogged = false;
        }

        private void Awake()
        {
            if (!EnsureStageShader()) return;
            EnsureStage();
            CaptureQualityGlobals();
            ApplyQuality(PitchQualityPolicy.Select(new PitchQualitySignals(
                SystemInfo.systemMemorySize,
                0d,
                0,
                false)));
        }

        private void OnEnable()
        {
            UnityEngine.Application.lowMemory += HandleLowMemory;
        }

        private void OnDisable()
        {
            UnityEngine.Application.lowMemory -= HandleLowMemory;
        }

        private void Update()
        {
            if (_qualityTier != PitchQualityTier.High || _frameSampleCount >= FrameSampleCapacity) return;
            _frameMilliseconds[_frameSampleCount++] = Time.unscaledDeltaTime * 1000f;
            if (_frameSampleCount != PitchQualityPolicy.MinimumFrameSamples) return;

            float[] ordered = new float[_frameSampleCount];
            Array.Copy(_frameMilliseconds, ordered, _frameSampleCount);
            Array.Sort(ordered);
            int index = Mathf.Clamp(Mathf.CeilToInt(ordered.Length * 0.95f) - 1, 0, ordered.Length - 1);
            ApplyQuality(PitchQualityPolicy.Select(new PitchQualitySignals(
                SystemInfo.systemMemorySize,
                ordered[index],
                _frameSampleCount,
                false)));
        }

        private void LateUpdate()
        {
            if (!_visualsReady || stageCamera == null) return;
            UpdateBackdropFraming();
        }

        private void OnDestroy()
        {
            if (_activePresentation != null) StopCoroutine(_activePresentation);
            _stadiumLease?.Dispose();
            _batterLease?.Dispose();
            _catcherLease?.Dispose();
            _stadiumLease = null;
            _batterLease = null;
            _catcherLease = null;
            foreach (Material material in _runtimeMaterials)
            {
                if (material != null) Destroy(material);
            }
            _runtimeMaterials.Clear();
            if (_qualityGlobalsCaptured)
            {
                QualitySettings.antiAliasing = _originalAntiAliasing;
                UnityEngine.Application.targetFrameRate = _originalTargetFrameRate;
                ScalableBufferManager.ResizeBuffers(_originalWidthScale, _originalHeightScale);
                if (_renderPipeline != null)
                {
                    _renderPipeline.renderScale = _originalRenderScale;
                    _renderPipeline.msaaSampleCount = _originalUrpMsaa;
                }
            }
        }

        public void Play(PitchPresentationSnapshot snapshot)
        {
            if (snapshot == null) throw new ArgumentNullException(nameof(snapshot));
            EnsureStage();
            if (!_visualsReady)
                throw new InvalidOperationException("pitch.stage_visual_assets_not_ready");
            if (_activePresentation != null) StopCoroutine(_activePresentation);
            _skipRequested = false;
            _activePresentation = StartCoroutine(PlayRoutine(snapshot));
        }

        /// <summary>
        /// Process-death recovery presents the exact committed snapshot as a short result card;
        /// it never replays the full delivery/contact timeline or asks Core to simulate again.
        /// </summary>
        public void PlayRecoveredSummary(PitchPresentationSnapshot snapshot)
        {
            if (snapshot == null) throw new ArgumentNullException(nameof(snapshot));
            EnsureStage();
            if (!_visualsReady)
                throw new InvalidOperationException("pitch.stage_visual_assets_not_ready");
            if (_activePresentation != null) StopCoroutine(_activePresentation);
            _skipRequested = false;
            _activePresentation = StartCoroutine(PlayRecoveredSummaryRoutine(snapshot));
        }

        public void RequestSkip()
        {
            _skipRequested = true;
        }

        /// <summary>
        /// Loads all required local Addressables before gameplay can present. Missing artwork never
        /// falls back to production primitives; the caller keeps the saved pitch session intact.
        /// </summary>
        public async Task<bool> PrepareVisualsAsync(
            IBaseballVisualAssetLoader loader,
            CancellationToken cancellationToken)
        {
            if (_visualsReady) return true;
            if (!EnsureStageShader()) return false;
            EnsureStage();
            if (loader == null) return false;
            IBaseballVisualAssetLease stadium = null;
            IBaseballVisualAssetLease batter = null;
            IBaseballVisualAssetLease catcher = null;
            try
            {
                stadium = await loader.LoadSpriteAsync(
                    PitchStageVisualPolicy.StadiumAddress,
                    cancellationToken);
                batter = await loader.LoadSpriteAsync(
                    PitchStageVisualPolicy.BatterAddress,
                    cancellationToken);
                catcher = await loader.LoadSpriteAsync(
                    PitchStageVisualPolicy.CatcherAddress,
                    cancellationToken);
                cancellationToken.ThrowIfCancellationRequested();
                if (!PitchStageVisualPolicy.HasRequiredSprites(
                        stadium?.Sprite != null,
                        batter?.Sprite != null,
                        catcher?.Sprite != null))
                {
                    VisualPreparationError = "pitch.stage_visual_assets_not_ready";
                    return false;
                }

                EnsureVisualLayers(stadium.Sprite, batter.Sprite, catcher.Sprite);
                _stadiumLease = stadium;
                _batterLease = batter;
                _catcherLease = catcher;
                stadium = null;
                batter = null;
                catcher = null;
                _visualsReady = true;
                VisualPreparationError = string.Empty;
                stageCamera.enabled = true;
                ApplyQuality(_qualityTier);
                UpdateBackdropFraming();
                return true;
            }
            catch (OperationCanceledException)
            {
                throw;
            }
            catch
            {
                VisualPreparationError = "pitch.stage_visual_assets_not_ready";
                return false;
            }
            finally
            {
                stadium?.Dispose();
                batter?.Dispose();
                catcher?.Dispose();
            }
        }

        private IEnumerator PlayRoutine(PitchPresentationSnapshot snapshot)
        {
            stageCamera.transform.position = DefaultCameraPosition;
            stageCamera.transform.LookAt(DefaultCameraTarget);
            stageCamera.fieldOfView = verticalFieldOfView;
            _trail.Clear();
            _trail.enabled = !reducedMotion;
            _ball.gameObject.SetActive(true);
            PoseActors();

            float flightDuration = reducedMotion
                ? Mathf.Min(0.45f, (float)snapshot.FlightDurationSeconds)
                : (float)snapshot.FlightDurationSeconds;
            float elapsed = 0f;
            while (elapsed < flightDuration && !_skipRequested)
            {
                elapsed = Mathf.Min(flightDuration, elapsed + Time.unscaledDeltaTime);
                float normalized = flightDuration <= 0f ? 1f : elapsed / flightDuration;
                _ball.position = Evaluate(snapshot.Trajectory, normalized);
                _ball.Rotate(580f * Time.unscaledDeltaTime, 390f * Time.unscaledDeltaTime, 210f * Time.unscaledDeltaTime, Space.Self);
                if (!reducedMotion)
                {
                    FollowBall(normalized);
                    AnimateActors(snapshot, normalized);
                }
                yield return null;
            }

            _ball.position = Evaluate(snapshot.Trajectory, 1f);
            AnimateActors(snapshot, 1f);
            ResultReadable?.Invoke(snapshot);
            EmitContactParticles(snapshot);

            if (!reducedMotion && _qualityTier == PitchQualityTier.High)
            {
                yield return ContactOrCatchImpulse(snapshot);
            }

            if (snapshot.Contact != null && snapshot.Fielding != null && !_skipRequested)
            {
                yield return AnimateBattedBall(snapshot);
            }

            float hold = reducedMotion ? 0.20f : ResultHoldSeconds;
            float held = 0f;
            while (held < hold && !_skipRequested)
            {
                held += Time.unscaledDeltaTime;
                yield return null;
            }

            _trail.enabled = false;
            RestoreDefaultCamera();
            _activePresentation = null;
            PresentationCompleted?.Invoke(snapshot);
        }

        private IEnumerator PlayRecoveredSummaryRoutine(PitchPresentationSnapshot snapshot)
        {
            stageCamera.transform.position = DefaultCameraPosition;
            stageCamera.transform.LookAt(DefaultCameraTarget);
            stageCamera.fieldOfView = verticalFieldOfView;
            _trail.Clear();
            _trail.enabled = false;
            _ball.gameObject.SetActive(true);
            _ball.position = Evaluate(snapshot.Trajectory, 1f);
            PoseActors();
            AnimateActors(snapshot, 1f);
            ResultReadable?.Invoke(snapshot);

            float held = 0f;
            while (held < RecoveredSummaryHoldSeconds && !_skipRequested)
            {
                held += Time.unscaledDeltaTime;
                yield return null;
            }

            RestoreDefaultCamera();
            _activePresentation = null;
            PresentationCompleted?.Invoke(snapshot);
        }

        private IEnumerator ContactOrCatchImpulse(PitchPresentationSnapshot snapshot)
        {
            const float duration = 0.12f;
            float strength = snapshot.Contact == null ? 0.018f : Mathf.Lerp(0.022f, 0.055f, snapshot.Contact.ContactQuality / 1000f);
            Vector3 original = stageCamera.transform.position;
            float originalFov = stageCamera.fieldOfView;
            float elapsed = 0f;
            while (elapsed < duration && !_skipRequested)
            {
                elapsed += Time.unscaledDeltaTime;
                float t = Mathf.Clamp01(elapsed / duration);
                float envelope = Mathf.Sin(t * Mathf.PI) * (1f - t * 0.35f);
                float phase = t * Mathf.PI * 6f + (snapshot.PresentationSeed & 31UL) * 0.11f;
                stageCamera.transform.position = original + new Vector3(Mathf.Sin(phase), Mathf.Cos(phase * 0.71f), 0f) * strength * envelope;
                stageCamera.fieldOfView = originalFov - (snapshot.Contact == null ? 0.3f : 1.2f) * envelope;
                yield return null;
            }
            stageCamera.transform.position = original;
            stageCamera.fieldOfView = originalFov;
        }

        private IEnumerator AnimateBattedBall(PitchPresentationSnapshot snapshot)
        {
            ContactPresentation contact = snapshot.Contact;
            FieldingPresentation fielding = snapshot.Fielding;
            float duration = Mathf.Clamp((float)fielding.HangTimeSeconds, 0.55f, 2.20f);
            if (reducedMotion) duration = Mathf.Min(duration, 0.35f);
            float visibleDistance = Mathf.Clamp((float)fielding.LandingDistanceMeters, 8f, 48f);
            float direction = (float)(contact.DirectionDegrees * Mathf.Deg2Rad);
            Vector3 start = _ball.position;
            Vector3 travelDirection = new Vector3(Mathf.Sin(direction), 0f, Mathf.Cos(direction));
            Vector3 end = start + travelDirection * visibleDistance;
            float apex = Mathf.Clamp((float)fielding.ApexHeightMeters, 1.5f, 16f);
            Vector3 cameraPosition = stageCamera.transform.position;
            Quaternion cameraRotation = stageCamera.transform.rotation;
            float cameraFieldOfView = stageCamera.fieldOfView;
            float elapsed = 0f;
            try
            {
                while (elapsed < duration && !_skipRequested)
                {
                    elapsed = Mathf.Min(duration, elapsed + Time.unscaledDeltaTime);
                    float t = elapsed / duration;
                    Vector3 position = Vector3.LerpUnclamped(start, end, t);
                    position.y = Mathf.Lerp(start.y, 0.10f, t) + 4f * apex * t * (1f - t);
                    _ball.position = position;
                    _ball.Rotate(900f * Time.unscaledDeltaTime, 620f * Time.unscaledDeltaTime, 0f, Space.Self);
                    if (!reducedMotion)
                    {
                        FollowBattedBall(position, travelDirection, apex, t, cameraPosition, cameraRotation);
                    }
                    yield return null;
                }
            }
            finally
            {
                stageCamera.transform.SetPositionAndRotation(cameraPosition, cameraRotation);
                stageCamera.fieldOfView = cameraFieldOfView;
            }
        }

        private void FollowBattedBall(
            Vector3 ballPosition,
            Vector3 travelDirection,
            float apex,
            float normalized,
            Vector3 originPosition,
            Quaternion originRotation)
        {
            float pickup = Mathf.SmoothStep(0f, 1f, Mathf.InverseLerp(0.03f, 0.20f, normalized));
            float settle = 1f - Mathf.SmoothStep(0f, 1f, Mathf.InverseLerp(0.86f, 1f, normalized));
            float trackingWeight = pickup * settle * (_qualityTier == PitchQualityTier.High ? 1f : 0.55f);
            Vector3 lift = Vector3.up * (2.0f + Mathf.Min(1.4f, apex * 0.10f));
            Vector3 desiredPosition = ballPosition - travelDirection * 5.5f + lift;
            Vector3 lookTarget = ballPosition + travelDirection * Mathf.Lerp(2.2f, 0.6f, normalized);
            Vector3 lookDirection = lookTarget - desiredPosition;
            Quaternion desiredRotation = lookDirection.sqrMagnitude < 0.0001f
                ? originRotation
                : Quaternion.LookRotation(lookDirection, Vector3.up);
            stageCamera.transform.SetPositionAndRotation(
                Vector3.Lerp(originPosition, desiredPosition, trackingWeight),
                Quaternion.Slerp(originRotation, desiredRotation, trackingWeight));
        }

        private void FollowBall(float normalized)
        {
            float ease = normalized * normalized * (3f - 2f * normalized);
            Vector3 follow = new Vector3(_ball.position.x * 0.10f, (_ball.position.y - 1f) * 0.035f, ease * 0.13f);
            stageCamera.transform.position = DefaultCameraPosition + follow;
            stageCamera.transform.LookAt(Vector3.Lerp(DefaultCameraTarget, _ball.position, ease * 0.18f));
        }

        private void RestoreDefaultCamera()
        {
            stageCamera.transform.position = DefaultCameraPosition;
            stageCamera.transform.LookAt(DefaultCameraTarget);
            stageCamera.fieldOfView = verticalFieldOfView;
        }

        private void CaptureQualityGlobals()
        {
            if (_qualityGlobalsCaptured) return;
            _qualityGlobalsCaptured = true;
            _originalAntiAliasing = QualitySettings.antiAliasing;
            _originalTargetFrameRate = UnityEngine.Application.targetFrameRate > 0
                ? UnityEngine.Application.targetFrameRate
                : 60;
            _originalWidthScale = ScalableBufferManager.widthScaleFactor;
            _originalHeightScale = ScalableBufferManager.heightScaleFactor;
            _renderPipeline = UniversalRenderPipeline.asset;
            if (_renderPipeline != null)
            {
                _originalRenderScale = _renderPipeline.renderScale;
                _originalUrpMsaa = _renderPipeline.msaaSampleCount;
            }
        }

        private void ApplyQuality(PitchQualityTier tier)
        {
            _qualityTier = tier;
            CrashRuntimeDiagnostics.PublishQualityTier(tier.Value());
            bool high = tier == PitchQualityTier.High;
            UnityEngine.Application.targetFrameRate = high ? 60 : 30;
            QualitySettings.antiAliasing = high ? 2 : 0;
            float renderScale = high ? 1f : 0.85f;
            ScalableBufferManager.ResizeBuffers(renderScale, renderScale);
            if (_renderPipeline != null)
            {
                _renderPipeline.renderScale = renderScale;
                _renderPipeline.msaaSampleCount = high ? 2 : 1;
            }
            if (_trail != null)
            {
                _trail.time = high ? 0.18f : 0.12f;
                _trail.minVertexDistance = high ? 0.035f : 0.07f;
            }
            if (_contactParticles != null)
            {
                ParticleSystem.MainModule main = _contactParticles.main;
                main.maxParticles = high ? 24 : 8;
            }
            if (_stadiumRenderer != null)
            {
                _stadiumRenderer.color = high
                    ? Color.white
                    : new Color(0.88f, 0.91f, 0.96f, 1f);
            }
            if (_fieldChalk != null) _fieldChalk.enabled = high;
        }

        private void HandleLowMemory()
        {
            ApplyQuality(PitchQualityTier.Low);
            _trail?.Clear();
            _contactParticles?.Clear(true);
        }

        private void EmitContactParticles(PitchPresentationSnapshot snapshot)
        {
            if (reducedMotion || snapshot.Contact == null || _contactParticles == null) return;
            _contactParticles.transform.position = _ball.position;
            int highCount = snapshot.Contact.ContactQuality >= 700 ? 20 : 12;
            int count = _qualityTier == PitchQualityTier.High
                ? highCount
                : Mathf.Max(1, Mathf.RoundToInt(highCount * 0.35f));
            _contactParticles.Emit(count);
        }

        private void EnsureStage()
        {
            if (!EnsureStageShader())
                throw new InvalidOperationException(PitchStageVisualPolicy.ShaderUnavailableError);
            if (stageCamera == null)
            {
                var cameraObject = new GameObject("Pitch Camera");
                cameraObject.transform.SetParent(transform, false);
                stageCamera = cameraObject.AddComponent<Camera>();
                stageCamera.clearFlags = CameraClearFlags.Depth;
                stageCamera.backgroundColor = Color.clear;
                stageCamera.nearClipPlane = 0.05f;
                stageCamera.farClipPlane = 80f;
                stageCamera.depth = 5f;
                stageCamera.enabled = false;
            }

            if (_ball == null)
            {
                GameObject ballObject = GameObject.CreatePrimitive(PrimitiveType.Sphere);
                ballObject.name = "Authoritative Pitch Ball";
                ballObject.transform.SetParent(transform, false);
                ballObject.transform.localScale = Vector3.one * 0.074f;
                Destroy(ballObject.GetComponent<Collider>());
                var renderer = ballObject.GetComponent<MeshRenderer>();
                renderer.sharedMaterial = CreateMaterial(new Color(0.97f, 0.96f, 0.91f, 1f));
                _trail = ballObject.AddComponent<TrailRenderer>();
                _trail.time = 0.18f;
                _trail.minVertexDistance = 0.035f;
                _trail.widthMultiplier = 0.035f;
                _trail.sharedMaterial = CreateMaterial(new Color(0.82f, 0.91f, 1f, 0.72f));
                _trail.startColor = new Color(0.86f, 0.94f, 1f, 0.76f);
                _trail.endColor = new Color(0.58f, 0.75f, 1f, 0f);
                _ball = ballObject.transform;
            }

            if (_contactParticles == null)
            {
                var particleObject = new GameObject("Contact Particles");
                particleObject.transform.SetParent(transform, false);
                _contactParticles = particleObject.AddComponent<ParticleSystem>();
                _contactParticles.Stop(true, ParticleSystemStopBehavior.StopEmittingAndClear);
                ParticleSystem.MainModule main = _contactParticles.main;
                main.loop = false;
                main.playOnAwake = false;
                main.duration = 0.15f;
                main.startLifetime = 0.16f;
                main.startSpeed = 1.1f;
                main.startSize = 0.055f;
                main.maxParticles = 24;
                ParticleSystem.EmissionModule emission = _contactParticles.emission;
                emission.enabled = false;
                ParticleSystem.ShapeModule shape = _contactParticles.shape;
                shape.shapeType = ParticleSystemShapeType.Sphere;
                shape.radius = 0.08f;
                var particleRenderer = particleObject.GetComponent<ParticleSystemRenderer>();
                particleRenderer.sharedMaterial = CreateMaterial(new Color(1f, 0.72f, 0.26f, 0.86f));
            }

            EnsureFieldReferenceLayers();
            RestoreDefaultCamera();
        }

        private void EnsureVisualLayers(Sprite stadium, Sprite batter, Sprite catcher)
        {
            if (_stadiumRenderer == null)
            {
                _stadiumRenderer = CreateSpriteLayer(
                    "Virtual Ballpark Backdrop",
                    stadium,
                    -100);
            }
            else _stadiumRenderer.sprite = stadium;

            if (_batterRenderer == null)
            {
                _batterRenderer = CreateSpriteLayer("Batter Stance Billboard", batter, 10);
                _batterBody = _batterRenderer.transform;
            }
            else _batterRenderer.sprite = batter;

            if (_catcherRenderer == null)
            {
                _catcherRenderer = CreateSpriteLayer("Catcher Stance Billboard", catcher, 8);
                _catcherBody = _catcherRenderer.transform;
            }
            else _catcherRenderer.sprite = catcher;

            _batterBody.localScale = Vector3.one * 0.12f;
            _catcherBody.localScale = Vector3.one * 0.11f;
            PoseActors();
        }

        private SpriteRenderer CreateSpriteLayer(string name, Sprite sprite, int sortingOrder)
        {
            var layer = new GameObject(name);
            layer.transform.SetParent(transform, false);
            var renderer = layer.AddComponent<SpriteRenderer>();
            renderer.sprite = sprite;
            renderer.sortingOrder = sortingOrder;
            return renderer;
        }

        private void PoseActors()
        {
            if (_batterBody != null)
            {
                _batterBody.localPosition = BatterRestPosition;
                _batterBody.localRotation = Quaternion.identity;
            }
            if (_catcherBody != null)
            {
                _catcherBody.localPosition = CatcherRestPosition;
                _catcherBody.localRotation = Quaternion.identity;
            }
        }

        private void AnimateActors(PitchPresentationSnapshot snapshot, float normalized)
        {
            if (_catcherBody != null)
            {
                Vector3 catchPoint = PitchSpace.PlateCrossing(snapshot.ActualPlateX, snapshot.ActualPlateY);
                float receive = Mathf.SmoothStep(0f, 1f, Mathf.InverseLerp(0.45f, 1f, normalized));
                Vector3 receivePose = CatcherRestPosition + new Vector3(
                    Mathf.Clamp(catchPoint.x, -0.5f, 0.5f) * 0.16f,
                    Mathf.Clamp(catchPoint.y - 0.85f, -0.5f, 0.5f) * 0.12f,
                    0f);
                _catcherBody.localPosition = Vector3.Lerp(CatcherRestPosition, receivePose, receive);
            }

            if (_batterBody == null || snapshot.Swing == SwingPresentation.Take) return;
            float swing = Mathf.SmoothStep(0f, 1f, Mathf.InverseLerp(0.52f, 0.94f, normalized));
            _batterBody.localPosition = BatterRestPosition + new Vector3(
                Mathf.Lerp(0f, -0.08f, swing),
                Mathf.Sin(swing * Mathf.PI) * 0.035f,
                0f);
            _batterBody.localRotation = Quaternion.Euler(0f, 0f, Mathf.Lerp(0f, 7f, swing));
        }

        private void EnsureFieldReferenceLayers()
        {
            if (_fieldChalk == null)
            {
                var chalk = new GameObject("Home Plate Chalk Layer");
                chalk.transform.SetParent(transform, false);
                _fieldChalk = chalk.AddComponent<LineRenderer>();
                _fieldChalk.loop = true;
                _fieldChalk.useWorldSpace = false;
                _fieldChalk.widthMultiplier = 0.012f;
                _fieldChalk.positionCount = 5;
                _fieldChalk.SetPositions(new[]
                {
                    new Vector3(-0.215f, 0.015f, 0.17f),
                    new Vector3(0.215f, 0.015f, 0.17f),
                    new Vector3(0.215f, 0.015f, -0.05f),
                    new Vector3(0f, 0.015f, -0.23f),
                    new Vector3(-0.215f, 0.015f, -0.05f),
                });
                _fieldChalk.sharedMaterial = CreateMaterial(new Color(0.88f, 0.91f, 0.88f, 0.86f));
            }

            if (transform.Find("Strike Zone") == null)
            {
                var zone = new GameObject("Strike Zone");
                zone.transform.SetParent(transform, false);
                var line = zone.AddComponent<LineRenderer>();
                line.loop = true;
                line.useWorldSpace = true;
                line.widthMultiplier = 0.008f;
                line.positionCount = 4;
                line.SetPositions(new[]
                {
                    new Vector3(-PitchSpace.StrikeZoneHalfWidthMeters, PitchSpace.StrikeZoneBottomMeters, 0f),
                    new Vector3(PitchSpace.StrikeZoneHalfWidthMeters, PitchSpace.StrikeZoneBottomMeters, 0f),
                    new Vector3(PitchSpace.StrikeZoneHalfWidthMeters, PitchSpace.StrikeZoneTopMeters, 0f),
                    new Vector3(-PitchSpace.StrikeZoneHalfWidthMeters, PitchSpace.StrikeZoneTopMeters, 0f)
                });
                line.sharedMaterial = CreateMaterial(new Color(0.42f, 0.80f, 1f, 0.72f));
            }
        }

        private void UpdateBackdropFraming()
        {
            if (_stadiumRenderer == null || _stadiumRenderer.sprite == null || stageCamera == null)
                return;
            Transform cameraTransform = stageCamera.transform;
            Transform backdrop = _stadiumRenderer.transform;
            backdrop.position = cameraTransform.position + cameraTransform.forward * StadiumLayerDistance;
            backdrop.rotation = cameraTransform.rotation;
            float aspect = Mathf.Max(0.1f, stageCamera.aspect);
            if (Mathf.Abs(aspect - _lastBackdropAspect) < 0.001f) return;
            Vector3 spriteSize = _stadiumRenderer.sprite.bounds.size;
            float scale = PitchStageVisualPolicy.CoverScale(
                spriteSize.x,
                spriteSize.y,
                StadiumLayerDistance,
                stageCamera.fieldOfView,
                aspect);
            backdrop.localScale = Vector3.one * scale * 1.02f;
            _lastBackdropAspect = aspect;
        }

        private static Vector3 Evaluate(IReadOnlyList<TrajectoryPoint> points, float normalized)
        {
            if (points == null || points.Count == 0) return PitchSpace.ReleasePoint;
            if (normalized <= points[0].NormalizedTime) return PitchSpace.ToWorld(points[0]);
            for (int index = 1; index < points.Count; index++)
            {
                TrajectoryPoint right = points[index];
                if (normalized > right.NormalizedTime) continue;
                TrajectoryPoint left = points[index - 1];
                double width = Math.Max(0.000001, right.NormalizedTime - left.NormalizedTime);
                float local = (float)((normalized - left.NormalizedTime) / width);
                return Vector3.Lerp(PitchSpace.ToWorld(left), PitchSpace.ToWorld(right), local);
            }
            return PitchSpace.ToWorld(points[points.Count - 1]);
        }

        private Material CreateMaterial(Color color)
        {
            if (_stageShader == null)
                throw new InvalidOperationException(PitchStageVisualPolicy.ShaderUnavailableError);
            var material = new Material(_stageShader) { color = color };
            _runtimeMaterials.Add(material);
            return material;
        }

        private bool EnsureStageShader()
        {
            if (_stageShader != null && _stageShader.isSupported) return true;
            _stageShader = UnityEngine.Resources.Load<Shader>(
                PitchStageVisualPolicy.ShaderResourcePath);
            if (_stageShader == null || !_stageShader.isSupported ||
                !string.Equals(
                    _stageShader.name,
                    PitchStageVisualPolicy.ShaderName,
                    StringComparison.Ordinal))
            {
                VisualPreparationError = PitchStageVisualPolicy.ShaderUnavailableError;
                if (!_shaderFailureLogged)
                {
                    _shaderFailureLogged = true;
                    Debug.LogError(PitchStageVisualPolicy.ShaderUnavailableError);
                }
                return false;
            }

            VisualPreparationError = string.Empty;
            if (!_shaderReadyMarkerLogged)
            {
                _shaderReadyMarkerLogged = true;
                Debug.Log(ShaderReadyMarker + " shader=" + PitchStageVisualPolicy.ShaderName);
            }
            return true;
        }
    }
}
