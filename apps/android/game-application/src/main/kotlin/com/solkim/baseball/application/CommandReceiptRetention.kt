package com.solkim.baseball.application

/** Only revision-bound IDs can be forgotten: an evicted ID cannot be applied at a later revision. */
public object CommandReceiptRetention {
    public const val RECENT_LIMIT: Int = 256
    private val phase8 = Regex("^phase8-.+-([0-9]+)-[0-9]+$")

    public fun id(revision: ULong, operation: String): String =
        "revision:$revision:${com.solkim.baseball.model.Hashing.sha256Hex(operation)}"

    internal fun revision(id: String): ULong? = when {
        id.startsWith("revision:") -> id.split(':').getOrNull(1)?.toULongOrNull()
        else -> phase8.matchEntire(id)?.groupValues?.get(1)?.toULongOrNull()
    }

    internal fun validate(id: String, expectedRevision: ULong) {
        if (id.startsWith("revision:")) require(revision(id) != null) { "game.command.id" }
        revision(id)?.let { require(it == expectedRevision) { "game.command.stale_revision" } }
    }

    internal fun retain(ids: List<String>): List<String> {
        val unique = ids.distinct()
        // Pre-migration opaque IDs have no safe expiry. Preserve them exactly; new app writers
        // use bound IDs. Never infer age from lexical order or discard unknown imported IDs.
        val opaque = unique.filter { revision(it) == null }
        val recent = unique.filter { revision(it) != null }.sortedBy { revision(it) }.takeLast(RECENT_LIMIT)
        return (opaque + recent).sorted()
    }
}
