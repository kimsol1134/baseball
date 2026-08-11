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
            string path = Path.Combine(ResolveNoBackupDirectory(), FileName);
            try
            {
                if (File.Exists(path))
                {
                    string existing = File.ReadAllText(path).Trim();
                    if (AnonymousInstallIdentityPolicy.IsValid(existing)) return existing;
                }

                string created = CreateCandidate();
                Replace(created);
                return created;
            }
            catch (Exception)
            {
                return Guid.NewGuid().ToString("N");
            }
        }

        public static string CreateCandidate() => AnonymousInstallIdentityPolicy.CreateCandidate();

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
    }
}
