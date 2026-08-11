using System;
using System.Collections.Generic;
using System.IO;

namespace Baseball.Application.Persistence
{
    public interface IAtomicFileSystem
    {
        bool FileExists(string path);

        byte[] ReadAllBytes(string path);

        void CreateDirectory(string path);

        void WriteAllBytesAndFlush(string path, byte[] bytes);

        void CopyFile(string sourcePath, string destinationPath, bool overwrite);

        void MoveFile(string sourcePath, string destinationPath);

        void ReplaceFile(string sourcePath, string destinationPath);

        void DeleteFile(string path);

        IReadOnlyList<string> GetFiles(string directoryPath, string searchPattern);
    }

    public sealed class SystemAtomicFileSystem : IAtomicFileSystem
    {
        public bool FileExists(string path) => File.Exists(path);

        public byte[] ReadAllBytes(string path) => File.ReadAllBytes(path);

        public void CreateDirectory(string path) => Directory.CreateDirectory(path);

        public void WriteAllBytesAndFlush(string path, byte[] bytes)
        {
            if (bytes == null)
            {
                throw new ArgumentNullException(nameof(bytes));
            }

            using (var stream = new FileStream(
                       path,
                       FileMode.Create,
                       FileAccess.Write,
                       FileShare.None,
                       4096,
                       FileOptions.WriteThrough))
            {
                stream.Write(bytes, 0, bytes.Length);
                stream.Flush(true);
            }
        }

        public void CopyFile(string sourcePath, string destinationPath, bool overwrite)
        {
            File.Copy(sourcePath, destinationPath, overwrite);
        }

        public void MoveFile(string sourcePath, string destinationPath)
        {
            File.Move(sourcePath, destinationPath);
        }

        public void ReplaceFile(string sourcePath, string destinationPath)
        {
            // Both paths are created under SaveFileLayout.SaveDirectory, so this is a
            // same-filesystem atomic replacement on the supported Android/.NET runtime.
            File.Replace(sourcePath, destinationPath, null, true);
        }

        public void DeleteFile(string path)
        {
            if (File.Exists(path))
            {
                File.Delete(path);
            }
        }

        public IReadOnlyList<string> GetFiles(string directoryPath, string searchPattern)
        {
            return Directory.Exists(directoryPath)
                ? Directory.GetFiles(directoryPath, searchPattern, SearchOption.TopDirectoryOnly)
                : Array.Empty<string>();
        }
    }
}
