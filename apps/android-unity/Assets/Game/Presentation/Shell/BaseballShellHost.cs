using UnityEngine;
using UnityEngine.UIElements;
using Baseball.Presentation.Pitch;
using Baseball.Presentation.Common;

namespace Baseball.Presentation.Shell
{
    [DisallowMultipleComponent]
    [RequireComponent(typeof(UIDocument))]
    public sealed class BaseballShellHost : MonoBehaviour
    {
        private BaseballShellController _controller;
        private PitchShellFlowCoordinator _pitchFlow;
        private IBaseballShellRuntime _runtime;

        public BaseballShellController Controller => _controller;

        private void Awake()
        {
            UIDocument document = GetComponent<UIDocument>();
            IKoreanUiCopyCatalog copy = KoreanUiCopyCatalog.LoadDefault();
            _runtime = BaseballShellRuntimeComposition.Create(copy);
            _controller = new BaseballShellController(
                document.rootVisualElement,
                _runtime,
                copy,
                BaseballShellController.ResolveInitialRoute(_runtime));
            _pitchFlow = new PitchShellFlowCoordinator(
                document.rootVisualElement,
                _controller,
                feedback: _runtime as IPitchFeedbackBoundary,
                persistence: _runtime as IPitchSessionPersistence);
            _controller.ResumePitchIfNeeded();
        }

        private void Update()
        {
            _pitchFlow?.Tick(Time.unscaledDeltaTime);
            bool backPressed = false;
#if ENABLE_LEGACY_INPUT_MANAGER
            backPressed |= Input.GetKeyDown(KeyCode.Escape);
#endif
            if (backPressed && (_pitchFlow == null || !_pitchFlow.TryHandleBack()))
            {
                _controller?.HandleHardwareBack();
            }
        }

        private void OnApplicationPause(bool paused)
        {
            (_runtime as IBaseballShellLifecycleObserver)?.OnApplicationPause(paused);
        }

        private void OnDestroy()
        {
            _pitchFlow?.Dispose();
            _pitchFlow = null;
            _controller?.Dispose();
            _controller = null;
            _runtime?.Dispose();
            _runtime = null;
        }
    }

    public static class BaseballShellRuntimeBootstrap
    {
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        private static void EnsureShell()
        {
            if (Object.FindAnyObjectByType<BaseballShellHost>() != null) return;
            var root = new GameObject("Baseball UI Shell");
            Object.DontDestroyOnLoad(root);
            var document = root.AddComponent<UIDocument>();
            var panelSettings = ScriptableObject.CreateInstance<PanelSettings>();
            panelSettings.name = "Baseball Runtime Panel";
            panelSettings.scaleMode = PanelScaleMode.ScaleWithScreenSize;
            panelSettings.referenceResolution = new Vector2Int(390, 844);
            panelSettings.textSettings = KoreanFontTextSettings.Create();
            ThemeStyleSheet runtimeTheme = Resources.Load<ThemeStyleSheet>("UnityDefaultRuntimeTheme");
            if (runtimeTheme == null)
            {
                Debug.LogError("BASEBALL_UI_RUNTIME_THEME schema=1 status=failed reason=missing_resource");
                Object.Destroy(root);
                return;
            }
            panelSettings.themeStyleSheet = runtimeTheme;
            Debug.Log("BASEBALL_UI_RUNTIME_THEME schema=1 status=passed");
            document.panelSettings = panelSettings;
            root.AddComponent<BaseballShellHost>();
        }
    }
}
