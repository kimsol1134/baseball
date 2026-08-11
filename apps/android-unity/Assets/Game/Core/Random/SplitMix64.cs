using System;

namespace Baseball.Core.Random
{
    /// <summary>Bit-for-bit port of SimulationCore.SplitMix64.</summary>
    public struct SplitMix64
    {
        public SplitMix64(ulong seed)
        {
            State = seed;
        }

        public ulong State { get; private set; }

        public ulong Next()
        {
            unchecked
            {
                State += 0x9E3779B97F4A7C15UL;
                var value = State;
                value = (value ^ (value >> 30)) * 0xBF58476D1CE4E5B9UL;
                value = (value ^ (value >> 27)) * 0x94D049BB133111EBUL;
                return value ^ (value >> 31);
            }
        }

        public int NextInt(int upperBound)
        {
            if (upperBound <= 0)
            {
                throw new ArgumentOutOfRangeException(nameof(upperBound), "upperBound must be positive");
            }

            return (int)(Next() % (ulong)upperBound);
        }
    }
}
