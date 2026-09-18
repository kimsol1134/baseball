package com.solkim.baseball.application

/**
 * Prefixes written into the durable aggregate. Older Phase 7/8 wires are rewritten on load
 * so parsers only understand the current prefixes.
 */
public object CareerWire {
    public const val COMMAND_PREFIX: String = "career"
    public const val UI_SESSION: String = "career-ui"
    public const val TUTORIAL_PREFIX: String = "tutorial:"
    public const val PITCH_INDEX_CHECKPOINT_PREFIX: String = "pitch-index:"
    public const val SUSPEND_CHECKPOINT_PREFIX: String = "pitch:"

    private const val LEGACY_COMMAND_PREFIX: String = "phase8-"
    private const val LEGACY_PITCH_INDEX_PREFIX: String = "phase7-index:"
    private val legacyUiSessions: Set<String> = setOf("phase8-ui", "phase7-shell")
    private val boundCommand = Regex("^career-.+-([0-9]+)-[0-9]+$")

    public fun commandId(screenWire: String, actionPart: String, expectedRevision: ULong, offset: Int): String =
        "$COMMAND_PREFIX-$screenWire-$actionPart-$expectedRevision-$offset"

    public fun migrateCommandId(id: String): String =
        if (id.startsWith(LEGACY_COMMAND_PREFIX)) "$COMMAND_PREFIX-${id.removePrefix(LEGACY_COMMAND_PREFIX)}" else id

    public fun migrateSessionId(id: String): String = if (id in legacyUiSessions) UI_SESSION else id

    public fun migrateCheckpoint(value: String?): String? {
        val raw = value ?: return null
        return if (raw.startsWith(LEGACY_PITCH_INDEX_PREFIX)) {
            PITCH_INDEX_CHECKPOINT_PREFIX + raw.removePrefix(LEGACY_PITCH_INDEX_PREFIX)
        } else raw
    }

    public fun boundCommandRevision(id: String): ULong? =
        boundCommand.matchEntire(migrateCommandId(id))?.groupValues?.get(1)?.toULongOrNull()

    public fun tutorialSession(careerId: String?): String =
        "$TUTORIAL_PREFIX${careerId?.takeIf { it.isNotBlank() } ?: "career"}"

    public fun highSchoolSession(state: GameAggregateState, fallback: String = UI_SESSION): String =
        state.highSchool?.commandReceipts?.firstOrNull()?.sessionId?.takeIf { it.isNotBlank() } ?: fallback

    public fun proSession(state: GameAggregateState, fallback: String = UI_SESSION): String =
        state.pro?.commandReceipts?.firstOrNull()?.sessionId?.takeIf { it.isNotBlank() } ?: fallback

    public fun uiSession(state: GameAggregateState, command: GameCommand): String = when (command) {
        is GameCommand.HighSchool -> highSchoolSession(state)
        is GameCommand.Pro -> proSession(state)
        else -> UI_SESSION
    }

    public fun pitchIndexCheckpoint(pitchIndex: Int, requestSha256: String): String =
        "$PITCH_INDEX_CHECKPOINT_PREFIX$pitchIndex:$requestSha256"

    public fun parsePitchIndex(checkpoint: String?): Int? {
        val value = checkpoint ?: return null
        if (!value.startsWith(PITCH_INDEX_CHECKPOINT_PREFIX)) return null
        return value.removePrefix(PITCH_INDEX_CHECKPOINT_PREFIX).substringBefore(':').toIntOrNull()
    }

    public fun suspendCheckpoint(reason: String): String = "$SUSPEND_CHECKPOINT_PREFIX$reason"
}
