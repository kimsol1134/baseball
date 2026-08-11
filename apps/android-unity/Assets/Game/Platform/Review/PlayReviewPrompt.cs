using System;
using System.Collections;
using System.IO;
using Baseball.Platform.Identity;
using UnityEngine;

#if UNITY_ANDROID && !UNITY_EDITOR
using Google.Play.Review;
#endif

namespace Baseball.Platform.Review
{
    public enum ReviewPromptOutcome
    {
        Completed,
        RequestFailed,
        LaunchFailed,
        Unsupported
    }

    [DefaultExecutionOrder(-8800)]
    public sealed class PlayReviewPrompt : MonoBehaviour
    {
        private static PlayReviewPrompt _instance;
        private IReviewAttemptGate _attemptGate;
        private bool _running;

        public static event Action<ReviewPromptOutcome> Finished;

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
        private static void ResetStatics()
        {
            _instance = null;
            Finished = null;
        }

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
        private static void EnsureExists()
        {
            if (_instance == null) new GameObject("Play Review Prompt").AddComponent<PlayReviewPrompt>();
        }

        public static bool TryRequest(ReviewEligibilityContext context)
        {
            if (_instance == null || !ReviewPromptPolicy.IsEligible(context)) return false;
            return _instance.TryStart();
        }

        public static void ResetLocalAttempt()
        {
            string markerPath = MarkerPath();
            try
            {
                if (File.Exists(markerPath)) File.Delete(markerPath);
            }
            catch (IOException) { }
            catch (UnauthorizedAccessException) { }
            if (_instance != null) _instance._attemptGate = new FileReviewAttemptGate(markerPath);
        }

        private void Awake()
        {
            if (_instance != null && _instance != this)
            {
                Destroy(gameObject);
                return;
            }

            _instance = this;
            DontDestroyOnLoad(gameObject);
            _attemptGate = new FileReviewAttemptGate(MarkerPath());
        }

        private bool TryStart()
        {
            if (_running || _attemptGate == null || !_attemptGate.TryClaim()) return false;
            _running = true;
            StartCoroutine(RunPrompt());
            return true;
        }

        private IEnumerator RunPrompt()
        {
#if UNITY_ANDROID && !UNITY_EDITOR
            var manager = new ReviewManager();
            var request = manager.RequestReviewFlow();
            yield return request;
            if (request.Error != ReviewErrorCode.NoError)
            {
                Complete(ReviewPromptOutcome.RequestFailed);
                yield break;
            }

            PlayReviewInfo reviewInfo = request.GetResult();
            var launch = manager.LaunchReviewFlow(reviewInfo);
            yield return launch;
            Complete(launch.Error == ReviewErrorCode.NoError
                ? ReviewPromptOutcome.Completed
                : ReviewPromptOutcome.LaunchFailed);
#else
            yield return null;
            Complete(ReviewPromptOutcome.Unsupported);
#endif
        }

        private void Complete(ReviewPromptOutcome outcome)
        {
            _running = false;
            Action<ReviewPromptOutcome> handlers = Finished;
            if (handlers == null) return;
            foreach (Action<ReviewPromptOutcome> handler in handlers.GetInvocationList())
            {
                try { handler(outcome); }
                catch (Exception exception) { Debug.LogException(exception); }
            }
        }

        private static string MarkerPath() => Path.Combine(
            AnonymousInstallIdentity.ResolveNoBackupDirectory(),
            "play-review-attempted-v1.marker");
    }
}
