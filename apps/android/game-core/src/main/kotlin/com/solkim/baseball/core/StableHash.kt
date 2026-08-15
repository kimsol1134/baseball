package com.solkim.baseball.core

import com.solkim.baseball.model.Hashing

/** Stable hash facade kept in the pure Kotlin core; values are part of the cross-runtime wire. */
public object StableHash {
    public fun fnv1a64(value: String): String = Hashing.fnv1a64Hex(value)
}
