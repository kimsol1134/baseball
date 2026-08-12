using System;
using System.IO;
using System.Text;

namespace Baseball.Platform.Identity
{
    /// <summary>Pure ID generation/validation policy shared by Unity storage and static tests.</summary>
    public static class AnonymousInstallIdentityPolicy
    {
        public static string CreateCandidate() => Guid.NewGuid().ToString("N");

        public static bool IsValid(string value) => Guid.TryParseExact(value, "N", out _);
    }

    /// <summary>
    /// Pure install-epoch policy for resettable local state that cannot live in the game save.
    /// The raw anonymous ID is never placed in a filename, PlayerPrefs key, or Android intent.
    /// A reset journals its candidate before the first destructive step, so a process restart
    /// necessarily resolves a different namespace even when cleanup of the old namespace did
    /// not run.
    /// </summary>
    public static class InstallScopedLocalStatePolicy
    {
        public const string DirectoryName = "install-local-state-v1";
        public const string AnalyticsOnceFileName = "analytics-once-v1.txt";
        public const string ReviewReceiptFileName = "play-review-receipts-v2.state";
        public const string ReminderAskedKeyPrefix = "baseball.reminder.permission-asked.v1";
        public const string ResetJournalFileName = "reset-all-v1.journal";

        public static string Epoch(string anonymousInstallId)
        {
            if (!AnonymousInstallIdentityPolicy.IsValid(anonymousInstallId))
                throw new ArgumentException(
                    "A 32-character anonymous install ID is required.",
                    nameof(anonymousInstallId));
            return Fnv1A64(anonymousInstallId.ToLowerInvariant()).ToString("x16");
        }

        public static string AnalyticsOncePath(string noBackupDirectory, string anonymousInstallId) =>
            Path.Combine(InstallDirectory(noBackupDirectory, anonymousInstallId), AnalyticsOnceFileName);

        public static string ReviewReceiptPath(string noBackupDirectory, string anonymousInstallId) =>
            Path.Combine(InstallDirectory(noBackupDirectory, anonymousInstallId), ReviewReceiptFileName);

        public static string ReminderAskedKey(string anonymousInstallId) =>
            ReminderAskedKeyPrefix + "." + Epoch(anonymousInstallId);

        public static string ResetJournalPath(string noBackupDirectory)
        {
            if (string.IsNullOrWhiteSpace(noBackupDirectory))
                throw new ArgumentException(
                    "A no-backup directory is required.",
                    nameof(noBackupDirectory));
            return Path.Combine(noBackupDirectory, ResetJournalFileName);
        }

        public static bool MatchesEpoch(string anonymousInstallId, string epoch) =>
            !string.IsNullOrWhiteSpace(epoch) &&
            string.Equals(Epoch(anonymousInstallId), epoch, StringComparison.Ordinal);

        public static string InstallDirectory(string noBackupDirectory, string anonymousInstallId)
        {
            if (string.IsNullOrWhiteSpace(noBackupDirectory))
                throw new ArgumentException(
                    "A no-backup directory is required.",
                    nameof(noBackupDirectory));
            return Path.Combine(noBackupDirectory, DirectoryName, Epoch(anonymousInstallId));
        }

        private static ulong Fnv1A64(string value)
        {
            const ulong offset = 14695981039346656037UL;
            const ulong prime = 1099511628211UL;
            ulong hash = offset;
            foreach (char character in value)
            {
                hash ^= (byte)character;
                hash *= prime;
            }
            return hash;
        }
    }

    /// <summary>
    /// Best-effort physical cleanup for resettable per-install files. Only 16-character epoch
    /// directories created by <see cref="InstallScopedLocalStatePolicy"/> are eligible, and the
    /// current epoch is always retained. Invalid inputs fail before any deletion is attempted;
    /// individual filesystem failures are reported as false without blocking startup.
    /// </summary>
    public static class InstallScopedLocalStateReconciler
    {
        public static bool KeepOnlyCurrentInstall(
            string noBackupDirectory,
            string anonymousInstallId)
        {
            string currentDirectory = Path.GetFullPath(
                InstallScopedLocalStatePolicy.InstallDirectory(
                    noBackupDirectory,
                    anonymousInstallId));
            string container = Path.GetFullPath(Path.Combine(
                noBackupDirectory,
                InstallScopedLocalStatePolicy.DirectoryName));
            if (!Directory.Exists(container)) return true;

            bool complete = true;
            string containerPrefix = container.TrimEnd(
                Path.DirectorySeparatorChar,
                Path.AltDirectorySeparatorChar) + Path.DirectorySeparatorChar;
            string[] directories;
            try { directories = Directory.GetDirectories(container); }
            catch (IOException) { return false; }
            catch (UnauthorizedAccessException) { return false; }

            foreach (string candidate in directories)
            {
                string resolved;
                try { resolved = Path.GetFullPath(candidate); }
                catch (Exception exception) when (
                    exception is ArgumentException ||
                    exception is NotSupportedException ||
                    exception is PathTooLongException)
                {
                    complete = false;
                    continue;
                }
                if (!resolved.StartsWith(containerPrefix, StringComparison.Ordinal) ||
                    string.Equals(resolved, currentDirectory, StringComparison.Ordinal) ||
                    !IsEpochDirectoryName(Path.GetFileName(resolved))) continue;
                try { Directory.Delete(resolved, true); }
                catch (IOException) { complete = false; }
                catch (UnauthorizedAccessException) { complete = false; }
            }
            return complete;
        }

        /// <summary>
        /// Removes only share PNGs owned by the game. Other temporary-cache content is retained,
        /// and any failed deletion keeps the reset journal pending for a later retry.
        /// </summary>
        public static bool ClearSharePngCache(string temporaryCacheDirectory)
        {
            if (string.IsNullOrWhiteSpace(temporaryCacheDirectory))
                throw new ArgumentException(
                    "A temporary cache directory is required.",
                    nameof(temporaryCacheDirectory));
            string shareDirectory = Path.Combine(temporaryCacheDirectory, "share");
            if (!Directory.Exists(shareDirectory)) return true;
            bool complete = true;
            string[] files;
            try { files = Directory.GetFiles(shareDirectory, "*.png"); }
            catch (IOException) { return false; }
            catch (UnauthorizedAccessException) { return false; }
            foreach (string file in files)
            {
                try { File.Delete(file); }
                catch (IOException) { complete = false; }
                catch (UnauthorizedAccessException) { complete = false; }
            }
            return complete;
        }

        private static bool IsEpochDirectoryName(string value)
        {
            if (value?.Length != 16) return false;
            foreach (char character in value)
            {
                bool digit = character >= '0' && character <= '9';
                bool lowerHex = character >= 'a' && character <= 'f';
                if (!digit && !lowerHex) return false;
            }
            return true;
        }
    }

    [Flags]
    public enum InstallResetStep
    {
        None = 0,
        RepositoryReset = 1 << 0,
        IdentityPublished = 1 << 1,
        AnalyticsCleaned = 1 << 2,
        ReviewCleaned = 1 << 3,
        ReminderCleaned = 1 << 4,
        ScopedFilesCleaned = 1 << 5,
        ShareCacheCleaned = 1 << 6,
        All = RepositoryReset | IdentityPublished | AnalyticsCleaned | ReviewCleaned |
            ReminderCleaned | ScopedFilesCleaned | ShareCacheCleaned,
    }

    public enum InstallResetJournalStatus
    {
        None,
        Pending,
        Invalid,
    }

    public sealed class InstallResetJournalRecord
    {
        public InstallResetJournalRecord(
            string previousInstallId,
            string candidateInstallId,
            InstallResetStep completedSteps)
        {
            PreviousInstallId = previousInstallId;
            CandidateInstallId = candidateInstallId;
            CompletedSteps = completedSteps;
        }

        public string PreviousInstallId { get; }
        public string CandidateInstallId { get; }
        public InstallResetStep CompletedSteps { get; }
        public bool IsComplete => CompletedSteps == InstallResetStep.All;
        public bool RequiresRepositoryReset => !Has(InstallResetStep.RepositoryReset);
        public bool Has(InstallResetStep step) => (CompletedSteps & step) == step;
    }

    public sealed class InstallResetJournalReadResult
    {
        private InstallResetJournalReadResult(
            InstallResetJournalStatus status,
            InstallResetJournalRecord record,
            string diagnostic)
        {
            Status = status;
            Record = record;
            Diagnostic = diagnostic;
        }

        public InstallResetJournalStatus Status { get; }
        public InstallResetJournalRecord Record { get; }
        public string Diagnostic { get; }

        public static InstallResetJournalReadResult None() =>
            new InstallResetJournalReadResult(InstallResetJournalStatus.None, null, null);

        public static InstallResetJournalReadResult Pending(InstallResetJournalRecord record) =>
            new InstallResetJournalReadResult(
                InstallResetJournalStatus.Pending,
                record,
                null);

        public static InstallResetJournalReadResult Invalid(string diagnostic) =>
            new InstallResetJournalReadResult(
                InstallResetJournalStatus.Invalid,
                null,
                diagnostic ?? "reset.journal_invalid");
    }

    /// <summary>
    /// Crash-safe two-phase reset journal. Once Prepare succeeds, every restart must converge on
    /// CandidateInstallId. The journal is retained until save deletion, identity publication, and
    /// all platform-local cleanup receipts have been durably acknowledged.
    /// </summary>
    public sealed class InstallResetJournal
    {
        private const string Header = "baseball-install-reset-v1";
        private static readonly object FileGate = new object();
        private readonly string _path;

        public InstallResetJournal(string path)
        {
            _path = string.IsNullOrWhiteSpace(path)
                ? throw new ArgumentException("A reset journal path is required.", nameof(path))
                : path;
        }

        public void Prepare(string previousInstallId, string candidateInstallId)
        {
            RequireInstallId(previousInstallId, nameof(previousInstallId));
            RequireInstallId(candidateInstallId, nameof(candidateInstallId));
            if (string.Equals(previousInstallId, candidateInstallId, StringComparison.OrdinalIgnoreCase))
                throw new ArgumentException("Reset IDs must differ.", nameof(candidateInstallId));
            lock (FileGate)
            {
                InstallResetJournalReadResult existing = ReadCore();
                if (existing.Status == InstallResetJournalStatus.Invalid)
                    throw new InvalidDataException(existing.Diagnostic);
                if (existing.Status == InstallResetJournalStatus.Pending)
                {
                    if (string.Equals(
                            existing.Record.PreviousInstallId,
                            previousInstallId,
                            StringComparison.OrdinalIgnoreCase) &&
                        string.Equals(
                            existing.Record.CandidateInstallId,
                            candidateInstallId,
                            StringComparison.OrdinalIgnoreCase)) return;
                    throw new InvalidOperationException("reset.journal_already_pending");
                }
                WriteAtomic(new InstallResetJournalRecord(
                    Normalize(previousInstallId),
                    Normalize(candidateInstallId),
                    InstallResetStep.None));
            }
        }

        public InstallResetJournalReadResult Read()
        {
            lock (FileGate) return ReadCore();
        }

        public bool Mark(InstallResetStep step)
        {
            if (step == InstallResetStep.None || (step & ~InstallResetStep.All) != 0)
                throw new ArgumentOutOfRangeException(nameof(step));
            lock (FileGate)
            {
                InstallResetJournalReadResult read = ReadCore();
                if (read.Status == InstallResetJournalStatus.None) return false;
                if (read.Status == InstallResetJournalStatus.Invalid)
                    throw new InvalidDataException(read.Diagnostic);
                InstallResetStep completed = read.Record.CompletedSteps | step;
                if (completed == read.Record.CompletedSteps) return true;
                WriteAtomic(new InstallResetJournalRecord(
                    read.Record.PreviousInstallId,
                    read.Record.CandidateInstallId,
                    completed));
                return true;
            }
        }

        public bool TryComplete()
        {
            lock (FileGate)
            {
                InstallResetJournalReadResult read = ReadCore();
                if (read.Status == InstallResetJournalStatus.None) return true;
                if (read.Status != InstallResetJournalStatus.Pending || !read.Record.IsComplete)
                    return false;
                try
                {
                    File.Delete(_path);
                    return !File.Exists(_path);
                }
                catch (IOException) { return false; }
                catch (UnauthorizedAccessException) { return false; }
            }
        }

        private InstallResetJournalReadResult ReadCore()
        {
            if (!File.Exists(_path)) return InstallResetJournalReadResult.None();
            try
            {
                string[] lines = File.ReadAllLines(_path);
                if (lines.Length != 5 || !string.Equals(lines[0], Header, StringComparison.Ordinal))
                    return InstallResetJournalReadResult.Invalid("reset.journal_shape");
                string previous = Field(lines[1], "previous=");
                string candidate = Field(lines[2], "candidate=");
                string stepsValue = Field(lines[3], "steps=");
                string checksum = Field(lines[4], "checksum=");
                if (!AnonymousInstallIdentityPolicy.IsValid(previous) ||
                    !AnonymousInstallIdentityPolicy.IsValid(candidate) ||
                    string.Equals(previous, candidate, StringComparison.OrdinalIgnoreCase) ||
                    !int.TryParse(stepsValue, out int rawSteps) ||
                    rawSteps < 0 ||
                    (rawSteps & ~(int)InstallResetStep.All) != 0)
                    return InstallResetJournalReadResult.Invalid("reset.journal_fields");
                var steps = (InstallResetStep)rawSteps;
                string expected = Checksum(previous, candidate, steps);
                if (!string.Equals(checksum, expected, StringComparison.Ordinal))
                    return InstallResetJournalReadResult.Invalid("reset.journal_checksum");
                return InstallResetJournalReadResult.Pending(new InstallResetJournalRecord(
                    Normalize(previous),
                    Normalize(candidate),
                    steps));
            }
            catch (IOException) { return InstallResetJournalReadResult.Invalid("reset.journal_io"); }
            catch (UnauthorizedAccessException)
            {
                return InstallResetJournalReadResult.Invalid("reset.journal_access");
            }
        }

        private void WriteAtomic(InstallResetJournalRecord record)
        {
            string directory = Path.GetDirectoryName(_path);
            if (!string.IsNullOrEmpty(directory)) Directory.CreateDirectory(directory);
            string temporary = _path + ".tmp-" + Guid.NewGuid().ToString("N");
            try
            {
                string content = string.Join("\n", new[]
                {
                    Header,
                    "previous=" + record.PreviousInstallId,
                    "candidate=" + record.CandidateInstallId,
                    "steps=" + (int)record.CompletedSteps,
                    "checksum=" + Checksum(
                        record.PreviousInstallId,
                        record.CandidateInstallId,
                        record.CompletedSteps),
                    string.Empty,
                });
                byte[] bytes = new UTF8Encoding(false).GetBytes(content);
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

        private static string Field(string line, string prefix) =>
            line != null && line.StartsWith(prefix, StringComparison.Ordinal)
                ? line.Substring(prefix.Length)
                : null;

        private static string Checksum(
            string previousInstallId,
            string candidateInstallId,
            InstallResetStep steps)
        {
            string value = Normalize(previousInstallId) + "|" +
                Normalize(candidateInstallId) + "|" + (int)steps;
            const ulong offset = 14695981039346656037UL;
            const ulong prime = 1099511628211UL;
            ulong hash = offset;
            foreach (char character in value)
            {
                hash ^= (byte)character;
                hash *= prime;
            }
            return hash.ToString("x16");
        }

        private static string Normalize(string installId) => installId.ToLowerInvariant();

        private static void RequireInstallId(string value, string parameterName)
        {
            if (!AnonymousInstallIdentityPolicy.IsValid(value))
                throw new ArgumentException(
                    "A 32-character anonymous install ID is required.",
                    parameterName);
        }
    }
}
