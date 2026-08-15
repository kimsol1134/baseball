using System;
using System.Collections;
using UnityEngine;

namespace Baseball.PitchRuntime
{
    /**
     * Presentation-only renderer. It consumes a bounded trajectory supplied by Kotlin and never
     * computes, persists, or publishes gameplay results.
     */
    public sealed class PitchTrajectoryRenderer : MonoBehaviour
    {
        private const float MillimetresToUnityUnits = 0.001f;

        private GameObject _ball;
        private Mesh _ballMesh;
        private LineRenderer _trail;
        private Material _trailMaterial;
        private Coroutine _playback;
        private bool _paused;
        private PitchPresentationWire _request;
        private Action<PitchPresentationWire> _onStarted;
        private Action<PitchPresentationWire, string> _onMarker;
        private Action<PitchPresentationWire, string, string> _onTerminal;

        internal bool IsPlaying => _playback != null;

        internal void Play(
            PitchPresentationWire request,
            Action<PitchPresentationWire> onStarted,
            Action<PitchPresentationWire, string> onMarker,
            Action<PitchPresentationWire, string, string> onTerminal)
        {
            CancelWithoutCallback();
            _request = request;
            _onStarted = onStarted;
            _onMarker = onMarker;
            _onTerminal = onTerminal;
            _paused = false;
            PrepareVisuals(request);
            _playback = StartCoroutine(Playback());
        }

        internal void Pause()
        {
            if (IsPlaying) _paused = true;
        }

        internal void Resume()
        {
            if (IsPlaying) _paused = false;
        }

        internal void Cancel()
        {
            if (!IsPlaying || _request == null) return;
            var request = _request;
            CancelWithoutCallback();
            _onTerminal?.Invoke(request, "cancelled", "presentation.cancelled");
            ClearCallbacks();
        }

        private IEnumerator Playback()
        {
            var request = _request;
            _onStarted?.Invoke(request);
            _onMarker?.Invoke(request, "release");

            var elapsed = 0f;
            var duration = request.visual.reducedMotion ? 0.08f : request.flightDurationMs / 1000f;
            var sentPlate = false;
            var sentImpact = false;
            while (elapsed < duration)
            {
                while (_paused) yield return null;
                elapsed += Time.unscaledDeltaTime;
                var normalized = Mathf.Clamp01(elapsed / duration);
                SetBallPosition(EvaluatePosition(request.trajectory, normalized));
                if (!sentPlate && normalized >= 0.96f)
                {
                    sentPlate = true;
                    _onMarker?.Invoke(request, "plate");
                }
                if (!sentImpact && normalized >= 0.99f)
                {
                    sentImpact = true;
                    _onMarker?.Invoke(request, "impact");
                }
                yield return null;
            }

            SetBallPosition(EvaluatePosition(request.trajectory, 1f));
            if (!sentPlate) _onMarker?.Invoke(request, "plate");
            if (!sentImpact) _onMarker?.Invoke(request, "impact");
            _playback = null;
            _onTerminal?.Invoke(request, "completed", null);
            ClearCallbacks();
        }

        private void PrepareVisuals(PitchPresentationWire request)
        {
            EnsureVisualObjects();
            _trail.positionCount = request.trajectory.Length;
            for (var index = 0; index < request.trajectory.Length; index++)
                _trail.SetPosition(index, ToUnityPosition(request.trajectory[index]));
            _trail.startColor = ColorForTrail(request.visual.trailKind);
            _trail.endColor = new Color(_trail.startColor.r, _trail.startColor.g, _trail.startColor.b, 0.08f);
            _ball.SetActive(true);
            SetBallPosition(ToUnityPosition(request.trajectory[0]));
        }

        private void EnsureVisualObjects()
        {
            if (_ball == null)
            {
                _ball = new GameObject("PitchVisualBall");
                _ball.name = "PitchVisualBall";
                _ball.transform.localScale = Vector3.one * 0.18f;
                _ballMesh = BuildSphereMesh(12, 20);
                _ball.AddComponent<MeshFilter>().sharedMesh = _ballMesh;
                var material = new Material(RequiredVisualShader());
                material.color = new Color(0.96f, 0.97f, 1f, 1f);
                _ball.AddComponent<MeshRenderer>().material = material;
            }

            if (_trail == null)
            {
                var trailObject = new GameObject("PitchVisualTrail");
                trailObject.transform.SetParent(transform, false);
                _trail = trailObject.AddComponent<LineRenderer>();
                _trail.useWorldSpace = true;
                _trail.widthMultiplier = 0.035f;
                _trail.numCapVertices = 4;
                _trailMaterial = new Material(RequiredVisualShader());
                _trail.material = _trailMaterial;
            }
        }

        private static Shader RequiredVisualShader()
        {
            // Keep the shader in a Resources folder so the single exported library does not
            // depend on Unity's legacy built-in shader stripping decisions.
            var shader = Resources.Load<Shader>("PitchVisual") ?? Shader.Find("BaseballPitch/UnlitColor");
            if (shader == null) throw new InvalidOperationException("pitch.visual_shader_missing");
            return shader;
        }

        private static Mesh BuildSphereMesh(int rings, int segments)
        {
            var vertices = new Vector3[(rings + 1) * (segments + 1)];
            var normals = new Vector3[vertices.Length];
            var uv = new Vector2[vertices.Length];
            var triangles = new int[rings * segments * 6];
            var vertex = 0;
            for (var ring = 0; ring <= rings; ring++)
            {
                var vertical = ring / (float)rings;
                var latitude = Mathf.PI * (vertical - 0.5f);
                var y = Mathf.Sin(latitude);
                var radius = Mathf.Cos(latitude);
                for (var segment = 0; segment <= segments; segment++)
                {
                    var horizontal = segment / (float)segments * Mathf.PI * 2f;
                    var normal = new Vector3(
                        radius * Mathf.Cos(horizontal),
                        y,
                        radius * Mathf.Sin(horizontal));
                    vertices[vertex] = normal * 0.5f;
                    normals[vertex] = normal;
                    uv[vertex] = new Vector2(segment / (float)segments, vertical);
                    vertex++;
                }
            }

            var triangle = 0;
            for (var ring = 0; ring < rings; ring++)
            {
                for (var segment = 0; segment < segments; segment++)
                {
                    var current = ring * (segments + 1) + segment;
                    var next = current + segments + 1;
                    triangles[triangle++] = current;
                    triangles[triangle++] = next;
                    triangles[triangle++] = current + 1;
                    triangles[triangle++] = current + 1;
                    triangles[triangle++] = next;
                    triangles[triangle++] = next + 1;
                }
            }

            var mesh = new Mesh { name = "PitchVisualBallMesh" };
            mesh.vertices = vertices;
            mesh.normals = normals;
            mesh.uv = uv;
            mesh.triangles = triangles;
            return mesh;
        }

        private void SetBallPosition(Vector3 position)
        {
            if (_ball != null) _ball.transform.position = position;
        }

        private static Vector3 EvaluatePosition(PitchTrajectoryPointWire[] points, float normalized)
        {
            var targetTime = Mathf.RoundToInt(normalized * 1000f);
            for (var index = 1; index < points.Length; index++)
            {
                if (targetTime > points[index].timePermille) continue;
                var previous = points[index - 1];
                var current = points[index];
                var span = Mathf.Max(1, current.timePermille - previous.timePermille);
                var local = Mathf.Clamp01((targetTime - previous.timePermille) / (float)span);
                return Vector3.Lerp(ToUnityPosition(previous), ToUnityPosition(current), local);
            }
            return ToUnityPosition(points[points.Length - 1]);
        }

        private static Vector3 ToUnityPosition(PitchTrajectoryPointWire point) =>
            new Vector3(point.xMm, point.yMm, point.zMm) * MillimetresToUnityUnits;

        private static Color ColorForTrail(string kind)
        {
            switch (kind)
            {
                case "breaking": return new Color(0.98f, 0.52f, 0.24f, 0.9f);
                case "dropping": return new Color(0.44f, 0.76f, 1f, 0.9f);
                case "fade": return new Color(0.76f, 0.62f, 1f, 0.9f);
                default: return new Color(0.96f, 0.96f, 0.74f, 0.9f);
            }
        }

        private void CancelWithoutCallback()
        {
            if (_playback != null)
            {
                StopCoroutine(_playback);
                _playback = null;
            }
            if (_ball != null) _ball.SetActive(false);
            _paused = false;
        }

        private void ClearCallbacks()
        {
            _request = null;
            _onStarted = null;
            _onMarker = null;
            _onTerminal = null;
        }

        private void OnDestroy()
        {
            CancelWithoutCallback();
            if (_trailMaterial != null) Destroy(_trailMaterial);
            if (_ballMesh != null) Destroy(_ballMesh);
        }
    }
}
