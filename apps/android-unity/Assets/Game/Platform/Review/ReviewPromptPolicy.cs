using System;
using System.IO;
using System.Text;

namespace Baseball.Platform.Review
{
    public readonly struct ReviewEligibilityContext
    {
        public ReviewEligibilityContext(
            bool onboardingCompleted,
            int completedGames,
            int completedImportantGames,
            TimeSpan activePlayTime)
        {
            if (completedGames < 0) throw new ArgumentOutOfRangeException(nameof(completedGames));
            if (completedImportantGames < 0) throw new ArgumentOutOfRangeException(nameof(completedImportantGames));
            if (activePlayTime < TimeSpan.Zero) throw new ArgumentOutOfRangeException(nameof(activePlayTime));

            OnboardingCompleted = onboardingCompleted;
            CompletedGames = completedGames;
            CompletedImportantGames = completedImportantGames;
            ActivePlayTime = activePlayTime;
        }

        public bool OnboardingCompleted { get; }
        public int CompletedGames { get; }
        public int CompletedImportantGames { get; }
        public TimeSpan ActivePlayTime { get; }
    }

    public static class ReviewPromptPolicy
    {
        public static readonly TimeSpan MinimumActivePlayTime = TimeSpan.FromMinutes(30);

        public static bool IsEligible(ReviewEligibilityContext context)
        {
            if (!context.OnboardingCompleted) return false;
            if (context.ActivePlayTime < MinimumActivePlayTime) return false;
            return context.CompletedImportantGames >= 1 || context.CompletedGames >= 3;
        }
    }

    public interface IReviewAttemptGate
    {
        bool TryClaim();
    }

    /// <summary>
    /// Claims the single review attempt before calling Play. CreateNew makes the
    /// claim atomic across duplicate scene/bootstrap instances and app resumes.
    /// </summary>
    public sealed class FileReviewAttemptGate : IReviewAttemptGate
    {
        private readonly string _path;

        public FileReviewAttemptGate(string path)
        {
            _path = string.IsNullOrWhiteSpace(path)
                ? throw new ArgumentException("Review attempt path is required.", nameof(path))
                : path;
        }

        public bool TryClaim()
        {
            try
            {
                string directory = Path.GetDirectoryName(_path);
                if (!string.IsNullOrEmpty(directory)) Directory.CreateDirectory(directory);
                using FileStream stream = new FileStream(_path, FileMode.CreateNew, FileAccess.Write, FileShare.Read);
                byte[] marker = new UTF8Encoding(false).GetBytes("play-review-attempted-v1\n");
                stream.Write(marker, 0, marker.Length);
                stream.Flush(true);
                return true;
            }
            catch (IOException)
            {
                return false;
            }
        }
    }
}
