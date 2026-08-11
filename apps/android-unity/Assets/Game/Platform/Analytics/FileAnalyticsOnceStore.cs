using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;

namespace Baseball.Platform.Analytics
{
    public sealed class FileAnalyticsOnceStore : IAnalyticsOnceStore
    {
        private readonly string _path;
        private readonly object _gate = new object();
        private HashSet<string> _keys;

        public FileAnalyticsOnceStore(string path)
        {
            _path = path ?? throw new ArgumentNullException(nameof(path));
        }

        public bool TryMark(string key)
        {
            if (string.IsNullOrWhiteSpace(key)) throw new ArgumentException("Once key is required.", nameof(key));
            lock (_gate)
            {
                EnsureLoaded();
                if (!_keys.Add(key)) return false;
                Persist();
                return true;
            }
        }

        public void Clear()
        {
            lock (_gate)
            {
                _keys = new HashSet<string>(StringComparer.Ordinal);
                if (File.Exists(_path)) File.Delete(_path);
            }
        }

        private void EnsureLoaded()
        {
            if (_keys != null) return;
            _keys = File.Exists(_path)
                ? new HashSet<string>(File.ReadAllLines(_path).Where(line => !string.IsNullOrWhiteSpace(line)), StringComparer.Ordinal)
                : new HashSet<string>(StringComparer.Ordinal);
        }

        private void Persist()
        {
            string directory = Path.GetDirectoryName(_path);
            if (!string.IsNullOrEmpty(directory)) Directory.CreateDirectory(directory);
            string temporary = _path + ".tmp";
            File.WriteAllLines(temporary, _keys.OrderBy(value => value, StringComparer.Ordinal), new UTF8Encoding(false));
            if (File.Exists(_path)) File.Delete(_path);
            File.Move(temporary, _path);
        }
    }
}
