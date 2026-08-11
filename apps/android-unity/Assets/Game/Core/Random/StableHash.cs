using System.Text;

namespace Baseball.Core.Random
{
    /// <summary>Stable FNV-1a 64-bit hashing over UTF-8 bytes.</summary>
    public static class StableHash
    {
        public static ulong Fnv1A64Value(string value)
        {
            unchecked
            {
                var hash = 0xCBF29CE484222325UL;
                var bytes = Encoding.UTF8.GetBytes(value ?? string.Empty);
                for (var index = 0; index < bytes.Length; index++)
                {
                    hash ^= bytes[index];
                    hash *= 0x00000100000001B3UL;
                }

                return hash;
            }
        }

        public static string Fnv1A64(string value) => Fnv1A64Value(value).ToString("x16");
    }
}
