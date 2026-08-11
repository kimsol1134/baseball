using System;
using System.Collections.Generic;
using UnityEngine;

namespace Baseball.Presentation.Shell
{
    public interface IKoreanUiCopyCatalog
    {
        string Locale { get; }
        string Get(string key);
        bool Contains(string key);
    }

    public sealed class KoreanUiCopyCatalog : IKoreanUiCopyCatalog
    {
        public const string Schema = "baseball.ui-copy.v1";
        private readonly Dictionary<string, string> _entries;

        public string Locale { get; }

        private KoreanUiCopyCatalog(string locale, Dictionary<string, string> entries)
        {
            Locale = locale;
            _entries = entries;
        }

        public static KoreanUiCopyCatalog LoadDefault()
        {
            TextAsset asset = Resources.Load<TextAsset>("ui-copy-ko-KR");
            if (asset == null) throw new InvalidOperationException("한국어 UI 카탈로그를 찾을 수 없습니다: ui-copy-ko-KR");
            return FromJson(asset.text);
        }

        public static KoreanUiCopyCatalog FromJson(string json)
        {
            if (string.IsNullOrWhiteSpace(json)) throw new ArgumentException("Copy catalog JSON is required.", nameof(json));
            CatalogData data = JsonUtility.FromJson<CatalogData>(json);
            if (data == null || data.entries == null || data.schema != Schema || data.locale != "ko-KR")
            {
                throw new InvalidOperationException("한국어 UI 카탈로그 형식이 올바르지 않습니다.");
            }

            var entries = new Dictionary<string, string>(StringComparer.Ordinal);
            foreach (CatalogEntry entry in data.entries)
            {
                if (entry == null || string.IsNullOrWhiteSpace(entry.key) || string.IsNullOrWhiteSpace(entry.value))
                {
                    throw new InvalidOperationException("UI 카탈로그에는 빈 키나 문구를 둘 수 없습니다.");
                }
                if (entries.ContainsKey(entry.key)) throw new InvalidOperationException($"중복 UI 카탈로그 키: {entry.key}");
                entries.Add(entry.key, entry.value);
            }
            return new KoreanUiCopyCatalog(data.locale, entries);
        }

        public string Get(string key)
        {
            if (!_entries.TryGetValue(key, out string value)) throw new KeyNotFoundException($"한국어 UI 문구 키를 찾을 수 없습니다: {key}");
            return value;
        }

        public bool Contains(string key) => _entries.ContainsKey(key);

        [Serializable]
        private sealed class CatalogData
        {
            public string schema = string.Empty;
            public string locale = string.Empty;
            public CatalogEntry[] entries = Array.Empty<CatalogEntry>();
        }

        [Serializable]
        private sealed class CatalogEntry
        {
            public string key = string.Empty;
            public string value = string.Empty;
        }
    }
}
