using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;

namespace Baseball.Platform.Review
{
    public enum ReviewPromptReason
    {
        ThirdLife,
        GoodRecap,
        Drafted,
    }

    public sealed class ReviewPromptReceiptState
    {
        public ReviewPromptReceiptState(
            long lastAttemptUnixSeconds = 0,
            IReadOnlyList<ReviewPromptReason> attemptedReasons = null)
        {
            LastAttemptUnixSeconds = Math.Max(0L, lastAttemptUnixSeconds);
            AttemptedReasons = (attemptedReasons ?? Array.Empty<ReviewPromptReason>())
                .Distinct()
                .OrderBy(value => value)
                .ToArray();
        }

        public long LastAttemptUnixSeconds { get; }
        public IReadOnlyList<ReviewPromptReason> AttemptedReasons { get; }
    }

    public static class ReviewPromptPolicy
    {
        public static readonly TimeSpan MinimumInterval = TimeSpan.FromHours(24);

        public static bool CanAttempt(
            ReviewPromptReceiptState state,
            ReviewPromptReason reason,
            DateTimeOffset now)
        {
            state = state ?? new ReviewPromptReceiptState();
            if (state.AttemptedReasons.Contains(reason)) return false;
            if (state.LastAttemptUnixSeconds <= 0) return true;
            long elapsed = now.ToUnixTimeSeconds() - state.LastAttemptUnixSeconds;
            return elapsed >= (long)MinimumInterval.TotalSeconds;
        }

        public static ReviewPromptReceiptState Claim(
            ReviewPromptReceiptState state,
            ReviewPromptReason reason,
            DateTimeOffset now)
        {
            if (!CanAttempt(state, reason, now)) return null;
            state = state ?? new ReviewPromptReceiptState();
            return new ReviewPromptReceiptState(
                now.ToUnixTimeSeconds(),
                state.AttemptedReasons.Concat(new[] { reason }).ToArray());
        }

        public static string Wire(ReviewPromptReason reason)
        {
            switch (reason)
            {
                case ReviewPromptReason.ThirdLife: return "third_life";
                case ReviewPromptReason.GoodRecap: return "good_recap";
                case ReviewPromptReason.Drafted: return "drafted";
                default: throw new ArgumentOutOfRangeException(nameof(reason));
            }
        }

        public static bool TryParse(string value, out ReviewPromptReason reason)
        {
            switch (value)
            {
                case "third_life": reason = ReviewPromptReason.ThirdLife; return true;
                case "good_recap": reason = ReviewPromptReason.GoodRecap; return true;
                case "drafted": reason = ReviewPromptReason.Drafted; return true;
                default: reason = default; return false;
            }
        }
    }

    public interface IReviewAttemptGate
    {
        bool TryClaim(ReviewPromptReason reason, DateTimeOffset now);
        void Reset();
    }

    /// <summary>
    /// Atomically records a reason and the last attempt epoch before Play Review is called. A Play
    /// request/launch failure deliberately does not roll the receipt back: gameplay remains
    /// fail-open and a flaky API cannot repeatedly interrupt the same positive moment.
    /// </summary>
    public sealed class FileReviewAttemptGate : IReviewAttemptGate
    {
        private const string Header = "baseball-review-receipts-v2";
        private readonly string _path;
        private readonly object _sync = new object();

        public FileReviewAttemptGate(string path)
        {
            _path = string.IsNullOrWhiteSpace(path)
                ? throw new ArgumentException("Review receipt path is required.", nameof(path))
                : path;
        }

        public bool TryClaim(ReviewPromptReason reason, DateTimeOffset now)
        {
            lock (_sync)
            {
                try
                {
                    if (!TryRead(out ReviewPromptReceiptState state)) return false;
                    ReviewPromptReceiptState claimed = ReviewPromptPolicy.Claim(state, reason, now);
                    if (claimed == null) return false;
                    WriteAtomic(claimed);
                    return true;
                }
                catch (IOException) { return false; }
                catch (UnauthorizedAccessException) { return false; }
            }
        }

        public void Reset()
        {
            lock (_sync)
            {
                try
                {
                    if (File.Exists(_path)) File.Delete(_path);
                }
                catch (IOException) { }
                catch (UnauthorizedAccessException) { }
            }
        }

        private bool TryRead(out ReviewPromptReceiptState state)
        {
            state = new ReviewPromptReceiptState();
            if (!File.Exists(_path)) return true;
            string[] lines = File.ReadAllLines(_path);
            if (lines.Length < 2 || !string.Equals(lines[0], Header, StringComparison.Ordinal))
                return false;
            if (!lines[1].StartsWith("last=", StringComparison.Ordinal) ||
                !long.TryParse(lines[1].Substring(5), out long last) || last < 0)
                return false;
            var reasons = new List<ReviewPromptReason>();
            for (var index = 2; index < lines.Length; index++)
            {
                if (!lines[index].StartsWith("reason=", StringComparison.Ordinal) ||
                    !ReviewPromptPolicy.TryParse(lines[index].Substring(7), out ReviewPromptReason reason))
                    return false;
                reasons.Add(reason);
            }
            state = new ReviewPromptReceiptState(last, reasons);
            return true;
        }

        private void WriteAtomic(ReviewPromptReceiptState state)
        {
            string directory = Path.GetDirectoryName(_path);
            if (!string.IsNullOrEmpty(directory)) Directory.CreateDirectory(directory);
            string temporary = _path + ".tmp-" + Guid.NewGuid().ToString("N");
            try
            {
                var lines = new List<string>
                {
                    Header,
                    "last=" + state.LastAttemptUnixSeconds,
                };
                lines.AddRange(state.AttemptedReasons.Select(reason =>
                    "reason=" + ReviewPromptPolicy.Wire(reason)));
                byte[] bytes = new UTF8Encoding(false).GetBytes(
                    string.Join("\n", lines) + "\n");
                using (var stream = new FileStream(
                    temporary,
                    FileMode.CreateNew,
                    FileAccess.Write,
                    FileShare.None,
                    4096,
                    FileOptions.WriteThrough))
                {
                    stream.Write(bytes, 0, bytes.Length);
                    stream.Flush(true);
                }
                if (File.Exists(_path)) File.Replace(temporary, _path, null);
                else File.Move(temporary, _path);
            }
            finally
            {
                if (File.Exists(temporary)) File.Delete(temporary);
            }
        }
    }
}
