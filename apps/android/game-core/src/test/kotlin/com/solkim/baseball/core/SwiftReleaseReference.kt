package com.solkim.baseball.core

import com.solkim.baseball.model.Hashing
import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.model.StrictJson

/**
 * Frozen Swift-authored v4/v10 evidence. Versioned Kotlin engines compare against these bytes.
 * Live SimulationCore may already be a newer rules version, so the working tree is not hashed here.
 * Regenerating this fixture must start from Swift at the same rules version, never from Kotlin output.
 */
internal object SwiftReleaseReference {
    private val reference: JsonValue.Obj by lazy {
        val bytes = checkNotNull(javaClass.getResourceAsStream("/fixtures/swift-release-parity-v4-v10.json")).use { it.readBytes() }
        check(Hashing.sha256Hex(bytes) == "b3d02ad0e1e3617cbb0cfc8ca5f6970a29c71c64d66643955c35b055c718fec6") { "Swift reference bytes changed; regenerate and review from Swift, never from Kotlin output" }
        StrictJson.parseUtf8(bytes) as JsonValue.Obj
    }
    internal fun read(): JsonValue.Obj = reference
}
