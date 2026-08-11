using System;
using System.IO;
using System.Text;

namespace Baseball.Platform.Share
{
    public static class SharePayloadPolicy
    {
        public const int MaximumPngBytes = 8 * 1024 * 1024;
        public const int MaximumShareTextLength = 500;
        private static readonly byte[] PngSignature = { 137, 80, 78, 71, 13, 10, 26, 10 };

        public static bool IsValidPng(byte[] bytes)
        {
            if (bytes == null || bytes.Length < PngSignature.Length || bytes.Length > MaximumPngBytes) return false;
            for (int index = 0; index < PngSignature.Length; index++)
            {
                if (bytes[index] != PngSignature[index]) return false;
            }
            return true;
        }

        public static string NormalizePngFileName(string suggestedName)
        {
            string stem = Path.GetFileNameWithoutExtension(suggestedName ?? string.Empty);
            if (string.IsNullOrWhiteSpace(stem)) stem = "baseball-life-card";

            var safe = new StringBuilder(Math.Min(stem.Length, 56));
            bool lastWasDash = false;
            foreach (char character in stem)
            {
                bool accepted = character >= 'a' && character <= 'z'
                    || character >= 'A' && character <= 'Z'
                    || character >= '0' && character <= '9'
                    || character == '-' || character == '_';
                char output = accepted ? character : '-';
                if (output == '-' && lastWasDash) continue;
                safe.Append(output);
                lastWasDash = output == '-';
                if (safe.Length >= 56) break;
            }

            string normalized = safe.ToString().Trim('-', '_');
            if (normalized.Length == 0) normalized = "baseball-life-card";
            return normalized + ".png";
        }

        public static string NormalizeShareText(string text)
        {
            if (string.IsNullOrWhiteSpace(text)) return string.Empty;
            var safe = new StringBuilder(Math.Min(text.Length, MaximumShareTextLength));
            foreach (char character in text)
            {
                if (character == '\n' || character == '\t' || !char.IsControl(character))
                    safe.Append(character);
                if (safe.Length >= MaximumShareTextLength) break;
            }
            return safe.ToString().Trim();
        }
    }
}
