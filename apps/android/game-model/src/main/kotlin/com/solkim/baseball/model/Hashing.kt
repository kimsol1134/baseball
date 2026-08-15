package com.solkim.baseball.model

import java.security.MessageDigest

public object Hashing {
    public fun sha256Hex(value: String): String = sha256Hex(value.toByteArray(Charsets.UTF_8))

    public fun sha256Hex(value: ByteArray): String = MessageDigest
        .getInstance("SHA-256")
        .digest(value)
        .joinToString(separator = "") { byte -> "%02x".format(byte) }

    /** Bit-for-bit FNV-1a 64-bit over UTF-8, matching the C#/Swift oracle. */
    public fun fnv1a64Hex(value: String): String {
        var hash = 0xcbf29ce484222325UL
        value.toByteArray(Charsets.UTF_8).forEach { byte ->
            hash = (hash xor byte.toUByte().toULong()) * 0x00000100000001b3UL
        }
        return hash.toString(16).padStart(16, '0')
    }
}

public fun JsonValue.canonicalSha256(): String = Hashing.sha256Hex(StrictJson.canonical(this))
