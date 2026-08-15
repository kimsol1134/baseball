using UnityEngine;

namespace Baseball.PitchRuntime
{
    /** Keeps the single presentation scene alive while UnityPlayer is unloaded and reattached. */
    [DisallowMultipleComponent]
    public sealed class PitchRuntimePersistence : MonoBehaviour
    {
        private static PitchRuntimePersistence _instance;

        private void Awake()
        {
            if (_instance != null && _instance != this)
            {
                Destroy(gameObject);
                return;
            }

            _instance = this;
            DontDestroyOnLoad(gameObject);
        }
    }
}
