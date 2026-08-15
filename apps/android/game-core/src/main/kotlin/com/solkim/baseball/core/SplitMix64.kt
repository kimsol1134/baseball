package com.solkim.baseball.core

/** Bit-for-bit port of the current C#/Swift SplitMix64 implementation. */
public class SplitMix64(public var state: ULong) {
    public fun next(): ULong {
        state += 0x9E3779B97F4A7C15UL
        var value = state
        value = (value xor (value shr 30)) * 0xBF58476D1CE4E5B9UL
        value = (value xor (value shr 27)) * 0x94D049BB133111EBUL
        return value xor (value shr 31)
    }

    public fun nextInt(upperBound: Int): Int {
        require(upperBound > 0) { "upperBound must be positive" }
        return (next() % upperBound.toULong()).toInt()
    }
}
