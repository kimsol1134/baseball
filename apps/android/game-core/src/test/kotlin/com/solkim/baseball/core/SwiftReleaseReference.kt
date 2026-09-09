package com.solkim.baseball.core

import com.solkim.baseball.model.Hashing
import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.model.StrictJson
import java.nio.file.Files
import java.nio.file.Path
import java.security.MessageDigest

/** Swift-authored evidence is a test resource, so a missing local export can no longer skip parity. */
internal object SwiftReleaseReference {
    private val reference: JsonValue.Obj by lazy {
        val bytes = checkNotNull(javaClass.getResourceAsStream("/fixtures/swift-release-parity-v4-v10.json")).use { it.readBytes() }
        check(Hashing.sha256Hex(bytes) == "b3d02ad0e1e3617cbb0cfc8ca5f6970a29c71c64d66643955c35b055c718fec6") { "Swift reference bytes changed; regenerate and review from Swift, never from Kotlin output" }
        val root = StrictJson.parseUtf8(bytes) as JsonValue.Obj
        val source = Path.of("../../../packages/simulation-core/Sources/SimulationCore")
        if (Files.isDirectory(source)) {
            val digest = MessageDigest.getInstance("SHA-256")
            Files.walk(source).use { files -> files.filter { Files.isRegularFile(it) && it.fileName.toString().endsWith(".swift") }.sorted().forEach {
                digest.update((source.relativize(it).toString().replace('\\', '/') + "\n").toByteArray())
                digest.update(Files.readAllBytes(it))
            } }
            val actual = digest.digest().joinToString("") { "%02x".format(it.toInt() and 255) }
            check(actual == (root.entries.getValue("sourceTreeSha256") as JsonValue.Str).value) { "Swift source changed; generate fresh same-version evidence before updating the frozen reference" }
        }
        root
    }
    internal fun read(): JsonValue.Obj = reference
}
