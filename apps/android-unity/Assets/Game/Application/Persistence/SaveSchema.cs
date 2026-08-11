using System;
using System.Globalization;
using System.IO;

namespace Baseball.Application.Persistence
{
    public static class SaveSchema
    {
        public const string Name = "android-unity-save-v1";
        public const int Version = 1;
        public const int BackupCount = 3;
    }

    public sealed class SaveFileLayout
    {
        public SaveFileLayout(string saveDirectory)
        {
            if (string.IsNullOrWhiteSpace(saveDirectory))
            {
                throw new ArgumentException("A save directory is required.", nameof(saveDirectory));
            }

            SaveDirectory = Path.GetFullPath(saveDirectory);
            CanonicalPath = Path.Combine(SaveDirectory, "save.json");
            TempPath = Path.Combine(SaveDirectory, "save.tmp");
        }

        public string SaveDirectory { get; }

        public string CanonicalPath { get; }

        public string TempPath { get; }

        public string BackupPath(int position)
        {
            if (position < 1 || position > SaveSchema.BackupCount)
            {
                throw new ArgumentOutOfRangeException(nameof(position));
            }

            return Path.Combine(
                SaveDirectory,
                string.Format(CultureInfo.InvariantCulture, "save.bak.{0}", position));
        }

        public string QuarantinePath(DateTimeOffset utcNow, string origin, int collisionIndex = 0)
        {
            var timestamp = utcNow.UtcDateTime.ToString("yyyyMMdd'T'HHmmssfff'Z'", CultureInfo.InvariantCulture);
            var safeOrigin = string.IsNullOrWhiteSpace(origin) ? "unknown" : origin.Replace('.', '-');
            var suffix = collisionIndex == 0
                ? string.Empty
                : "." + collisionIndex.ToString(CultureInfo.InvariantCulture);
            return Path.Combine(
                SaveDirectory,
                string.Format(
                    CultureInfo.InvariantCulture,
                    "save.corrupt.{0}.{1}{2}.json",
                    timestamp,
                    safeOrigin,
                    suffix));
        }
    }
}
