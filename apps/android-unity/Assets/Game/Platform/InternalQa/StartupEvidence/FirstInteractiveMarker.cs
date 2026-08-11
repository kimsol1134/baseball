using System.Collections;
using Baseball.Bootstrap;
using Baseball.Presentation.Shell;
using UnityEngine;
using UnityEngine.Scripting;
using UnityEngine.UIElements;

namespace Baseball.Platform.StartupEvidence
{
    /// <summary>
    /// Passive production startup evidence. It exposes no command surface and emits no player data;
    /// it only reports when the real shell has a visible, enabled control backed by a ready store.
    /// </summary>
    [Preserve]
    [DisallowMultipleComponent]
    public sealed class FirstInteractiveMarker : MonoBehaviour
    {
        public const string PassedPrefix = "BASEBALL_FIRST_INTERACTIVE schema=1 status=passed";
        public const string FailedPrefix = "BASEBALL_FIRST_INTERACTIVE schema=1 status=failed";
        public const float TimeoutSeconds = 60f;

        private float _startedAt;

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        [Preserve]
        private static void Install()
        {
            if (Object.FindAnyObjectByType<FirstInteractiveMarker>() != null) return;
            var marker = new GameObject("Baseball First Interactive Evidence");
            Object.DontDestroyOnLoad(marker);
            marker.AddComponent<FirstInteractiveMarker>();
        }

        private IEnumerator Start()
        {
            _startedAt = Time.realtimeSinceStartup;
            while (Time.realtimeSinceStartup - _startedAt < TimeoutSeconds)
            {
                if (TryResolveInteractiveShell(out string route))
                {
                    long elapsedMilliseconds = (long)((Time.realtimeSinceStartup - _startedAt) * 1000f);
                    Debug.Log(PassedPrefix + " route=" + route + " elapsed_ms=" + elapsedMilliseconds);
                    Destroy(gameObject);
                    yield break;
                }

                yield return null;
            }

            Debug.LogError(
                FailedPrefix + " reason=timeout elapsed_ms=" + (long)(TimeoutSeconds * 1000f));
            Destroy(gameObject);
        }

        private static bool TryResolveInteractiveShell(out string route)
        {
            route = "unknown";
            if (!RuntimeGameServices.IsReady) return false;

            BaseballShellHost host = Object.FindAnyObjectByType<BaseballShellHost>();
            if (host == null || !host.isActiveAndEnabled || host.Controller == null) return false;
            UIDocument document = host.GetComponent<UIDocument>();
            VisualElement root = document?.rootVisualElement;
            VisualElement shell = root?.Q<VisualElement>("shell-root");
            if (!IsVisible(shell) || !HasInteractiveButton(shell)) return false;

            route = host.Controller.CurrentRoute.ToString().ToLowerInvariant();
            return true;
        }

        private static bool HasInteractiveButton(VisualElement parent)
        {
            for (int index = 0; index < parent.childCount; index++)
            {
                VisualElement child = parent[index];
                if (!IsVisible(child)) continue;
                if (child is Button && child.enabledInHierarchy)
                {
                    return true;
                }
                if (HasInteractiveButton(child)) return true;
            }
            return false;
        }

        private static bool IsVisible(VisualElement element)
        {
            return element != null && element.panel != null && element.visible &&
                element.resolvedStyle.display != DisplayStyle.None &&
                element.worldBound.width > 0f && element.worldBound.height > 0f;
        }
    }
}
