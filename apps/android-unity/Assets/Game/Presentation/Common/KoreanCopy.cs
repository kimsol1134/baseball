using System;
using System.Globalization;

namespace Baseball.Presentation.Common
{
    public static class KoreanCopy
    {
        private const int HangulStart = 0xAC00;
        private const int HangulEnd = 0xD7A3;
        private static readonly int[] DigitFinalConsonants = { 21, 8, 0, 16, 0, 0, 1, 8, 8, 0 };

        public static string Particle(string word, string withFinal, string withoutFinal)
        {
            int? finalConsonant = LastFinalConsonant(word);
            return finalConsonant.HasValue && finalConsonant.Value != 0 ? withFinal : withoutFinal;
        }

        public static string Ro(string word)
        {
            int? finalConsonant = LastFinalConsonant(word);
            return !finalConsonant.HasValue || finalConsonant.Value == 0 || finalConsonant.Value == 8 ? "로" : "으로";
        }

        public static string ObjectParticle(int number)
        {
            int last = Math.Abs(number % 10);
            return last == 0 || last == 1 || last == 3 || last == 6 || last == 7 || last == 8 ? "을" : "를";
        }

        public static string Money(int won)
        {
            int man = won / 10_000;
            int eok = man / 10_000;
            int rest = Math.Abs(man % 10_000);
            if (eok != 0)
            {
                return rest > 0
                    ? $"{eok.ToString(CultureInfo.InvariantCulture)}억 {rest.ToString("N0", CultureInfo.InvariantCulture)}만 원"
                    : $"{eok.ToString(CultureInfo.InvariantCulture)}억 원";
            }
            return $"{man.ToString("N0", CultureInfo.InvariantCulture)}만 원";
        }

        private static int? LastFinalConsonant(string word)
        {
            if (string.IsNullOrEmpty(word)) return null;
            for (int index = word.Length - 1; index >= 0; index--)
            {
                char character = word[index];
                if (character >= HangulStart && character <= HangulEnd) return (character - HangulStart) % 28;
                if (character >= '0' && character <= '9') return DigitFinalConsonants[character - '0'];
            }
            return null;
        }
    }
}
