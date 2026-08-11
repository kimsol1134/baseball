using UnityEngine;
using UnityEngine.Rendering;

namespace Baseball.Platform.Performance
{
    /// <summary>Sets the app-wide 2D/UI frame contract before the bootstrap scene loads.</summary>
    public static class AppFramePacing
    {
        public const int UiTargetFramesPerSecond = 60;

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
        public static void Configure()
        {
            QualitySettings.vSyncCount = 0;
            OnDemandRendering.renderFrameInterval = 1;
            UnityEngine.Application.targetFrameRate = UiTargetFramesPerSecond;
        }
    }
}
