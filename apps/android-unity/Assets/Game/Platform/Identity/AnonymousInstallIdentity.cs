using System;
using System.IO;
using System.Text;
using UnityEngine;

namespace Baseball.Platform.Identity
{
    public static class AnonymousInstallIdentity
    {
        private const string FileName = "anonymous-install-id-v1";

        public static string GetOrCreate()
        {
            string noBackupDirectory = ResolveNoBackupDirectory();
            InstallResetJournalReadResult pending = ResetJournal(noBackupDirectory).Read();
            if (pending.Status == InstallResetJournalStatus.Invalid)
                throw new InvalidDataException(pending.Diagnostic);
            if (pending.Status == InstallResetJournalStatus.Pending)
            {
                TryReconcilePreparedLocalState();
                return pending.Record.CandidateInstallId;
            }

            string path = Path.Combine(noBackupDirectory, FileName);
            if (File.Exists(path))
            {
                string existing = File.ReadAllText(path).Trim();
                if (!AnonymousInstallIdentityPolicy.IsValid(existing))
                    throw new InvalidDataException("install.identity_invalid");
                ReconcileInstallLocalState(existing);
                return existing;
            }

            // Never hand the runtime an ephemeral identity. If durable creation fails, surface
            // startup failure so the explicit retry bridge can try the same operation again.
            string created = CreateCandidate();
            Replace(created);
            return created;
        }

        public static string CreateCandidate() => AnonymousInstallIdentityPolicy.CreateCandidate();

        public static void PrepareReset(string previousInstallId, string candidateInstallId)
        {
            string persisted = ReadPersistedInstallId();
            if (!string.Equals(persisted, previousInstallId, StringComparison.OrdinalIgnoreCase))
                throw new InvalidOperationException("reset.previous_install_mismatch");
            ResetJournal(ResolveNoBackupDirectory()).Prepare(previousInstallId, candidateInstallId);
        }

        public static InstallResetJournalReadResult ReadPreparedReset() =>
            ResetJournal(ResolveNoBackupDirectory()).Read();

        public static bool MarkPreparedResetStep(InstallResetStep step)
        {
            try { return ResetJournal(ResolveNoBackupDirectory()).Mark(step); }
            catch (IOException) { return false; }
            catch (UnauthorizedAccessException) { return false; }
            catch (InvalidDataException) { return false; }
        }

        /// <summary>
        /// Publishes the candidate identity after repository deletion. The journal deliberately
        /// remains until analytics, review, and reminder cleanup have all acknowledged the reset.
        /// </summary>
        public static void PublishPreparedReset(string candidateInstallId)
        {
            InstallResetJournalReadResult pending = ReadPreparedReset();
            if (pending.Status != InstallResetJournalStatus.Pending ||
                !string.Equals(
                    pending.Record.CandidateInstallId,
                    candidateInstallId,
                    StringComparison.OrdinalIgnoreCase))
                throw new InvalidOperationException("reset.candidate_install_mismatch");
            string persisted = ReadPersistedInstallId();
            if (!string.Equals(
                    persisted,
                    pending.Record.PreviousInstallId,
                    StringComparison.OrdinalIgnoreCase) &&
                !string.Equals(
                    persisted,
                    pending.Record.CandidateInstallId,
                    StringComparison.OrdinalIgnoreCase))
                throw new InvalidOperationException("reset.persisted_install_mismatch");
            if (!string.Equals(persisted, candidateInstallId, StringComparison.OrdinalIgnoreCase))
                Replace(candidateInstallId);
            if (!MarkPreparedResetStep(InstallResetStep.IdentityPublished))
                throw new InvalidOperationException("reset.identity_receipt_failed");
        }

        public static bool TryCompletePreparedReset() =>
            ResetJournal(ResolveNoBackupDirectory()).TryComplete();

        /// <summary>
        /// Physically removes every stale install-epoch directory before acknowledging cleanup.
        /// A failure deliberately leaves the reset journal pending for the next startup retry.
        /// </summary>
        public static bool TryReconcilePreparedLocalState()
        {
            InstallResetJournalReadResult pending = ReadPreparedReset();
            if (pending.Status == InstallResetJournalStatus.None) return true;
            if (pending.Status != InstallResetJournalStatus.Pending) return false;
            if (!ReconcileInstallLocalState(pending.Record.CandidateInstallId)) return false;
            return MarkPreparedResetStep(InstallResetStep.ScopedFilesCleaned);
        }

        /// <summary>Atomically publishes an already-selected ID only after the save reset succeeds.</summary>
        public static void Replace(string anonymousInstallId)
        {
            if (!AnonymousInstallIdentityPolicy.IsValid(anonymousInstallId))
                throw new ArgumentException("A 32-character anonymous install ID is required.", nameof(anonymousInstallId));
            string path = Path.Combine(ResolveNoBackupDirectory(), FileName);
            string directory = Path.GetDirectoryName(path);
            Directory.CreateDirectory(directory);
            string temporaryPath = Path.Combine(directory, FileName + ".tmp-" + Guid.NewGuid().ToString("N"));
            try
            {
                byte[] bytes = new UTF8Encoding(false).GetBytes(anonymousInstallId);
                using (var stream = new FileStream(
                    temporaryPath,
                    FileMode.CreateNew,
                    FileAccess.Write,
                    FileShare.None,
                    4096,
                    FileOptions.WriteThrough))
                {
                    stream.Write(bytes, 0, bytes.Length);
                    stream.Flush(true);
                }
                if (File.Exists(path)) File.Replace(temporaryPath, path, null);
                else File.Move(temporaryPath, path);
            }
            finally
            {
                if (File.Exists(temporaryPath)) File.Delete(temporaryPath);
            }
            if (ReconcileInstallLocalState(anonymousInstallId))
                MarkPreparedResetStep(InstallResetStep.ScopedFilesCleaned);
        }

        public static void Reset()
        {
            string path = Path.Combine(ResolveNoBackupDirectory(), FileName);
            if (File.Exists(path)) File.Delete(path);
        }

        public static string ResolveNoBackupDirectory()
        {
#if UNITY_ANDROID && !UNITY_EDITOR
            try
            {
                using var player = new AndroidJavaClass("com.unity3d.player.UnityPlayer");
                using AndroidJavaObject activity = player.GetStatic<AndroidJavaObject>("currentActivity");
                using AndroidJavaObject directory = activity.Call<AndroidJavaObject>("getNoBackupFilesDir");
                return directory.Call<string>("getAbsolutePath");
            }
            catch (Exception)
            {
                return Path.Combine(UnityEngine.Application.persistentDataPath, "no-backup-fallback");
            }
#else
            return Path.Combine(UnityEngine.Application.persistentDataPath, "no-backup-editor");
#endif
        }

        private static bool ReconcileInstallLocalState(string anonymousInstallId)
        {
            try
            {
                return InstallScopedLocalStateReconciler.KeepOnlyCurrentInstall(
                    ResolveNoBackupDirectory(),
                    anonymousInstallId);
            }
            catch (Exception)
            {
                // Cleanup is retried on the next GetOrCreate and must never replace a valid ID
                // with an ephemeral fallback or fail a durable reset after identity publication.
                return false;
            }
        }

        private static string ReadPersistedInstallId()
        {
            string path = Path.Combine(ResolveNoBackupDirectory(), FileName);
            if (!File.Exists(path)) throw new InvalidOperationException("install.identity_missing");
            string value = File.ReadAllText(path).Trim();
            if (!AnonymousInstallIdentityPolicy.IsValid(value))
                throw new InvalidDataException("install.identity_invalid");
            return value;
        }

        private static InstallResetJournal ResetJournal(string noBackupDirectory) =>
            new InstallResetJournal(
                InstallScopedLocalStatePolicy.ResetJournalPath(noBackupDirectory));
    }
}
