using System;
using System.Collections;
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
        private string _installEpoch;
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

        public static bool TryRequest(
            ReviewPromptReason reason,
            DateTimeOffset? requestedAt = null)
        {
            if (_instance == null) return false;
            return _instance.TryStart(reason, requestedAt ?? DateTimeOffset.UtcNow);
        }

        public static void ResetLocalAttempt()
        {
            string installId = AnonymousInstallIdentity.GetOrCreate();
            string installEpoch = InstallScopedLocalStatePolicy.Epoch(installId);
            var replacement = new FileReviewAttemptGate(MarkerPath(installId));
            replacement.Reset();
            if (_instance != null)
            {
                _instance._attemptGate?.Reset();
                _instance._attemptGate = replacement;
                _instance._installEpoch = installEpoch;
            }
            AcknowledgePreparedResetCleanup();
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
            string installId = AnonymousInstallIdentity.GetOrCreate();
            _installEpoch = InstallScopedLocalStatePolicy.Epoch(installId);
            _attemptGate = new FileReviewAttemptGate(MarkerPath(installId));
            AcknowledgePreparedResetCleanup();
        }

        private bool TryStart(ReviewPromptReason reason, DateTimeOffset now)
        {
            BindCurrentInstallNamespace();
            if (_running || _attemptGate == null || !_attemptGate.TryClaim(reason, now)) return false;
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

        private static string MarkerPath(string installId) =>
            InstallScopedLocalStatePolicy.ReviewReceiptPath(
                AnonymousInstallIdentity.ResolveNoBackupDirectory(),
                installId);

        private void BindCurrentInstallNamespace()
        {
            string installId = AnonymousInstallIdentity.GetOrCreate();
            string installEpoch = InstallScopedLocalStatePolicy.Epoch(installId);
            if (string.Equals(_installEpoch, installEpoch, StringComparison.Ordinal)) return;
            _installEpoch = installEpoch;
            _attemptGate = new FileReviewAttemptGate(MarkerPath(installId));
        }

        private static void AcknowledgePreparedResetCleanup()
        {
            if (!AnonymousInstallIdentity.TryReconcilePreparedLocalState()) return;
            if (!AnonymousInstallIdentity.MarkPreparedResetStep(
                    InstallResetStep.ReviewCleaned)) return;
            AnonymousInstallIdentity.TryCompletePreparedReset();
        }
    }
}
