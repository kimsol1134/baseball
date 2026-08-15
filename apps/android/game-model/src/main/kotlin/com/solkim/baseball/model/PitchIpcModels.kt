package com.solkim.baseball.model

public object PitchIpcContract {
    public const val SCHEMA: String = "baseball-pitch-ipc-v1"
    public const val SCHEMA_VERSION: Int = 1
    public const val MAX_MESSAGE_BYTES: Int = 64 * 1024
    public const val MAX_TRAJECTORY_POINTS: Int = 64
}

public enum class PitchType(public val wire: String) {
    FOUR_SEAM("fourSeam"),
    SLIDER("slider"),
    CURVEBALL("curveball"),
    CHANGEUP("changeup"),
    ;

    public companion object {
        public fun fromWire(wire: String): PitchType = entries.firstOrNull { it.wire == wire }
            ?: throw IpcValidationException("pitchType.unknown:$wire")
    }
}

public enum class TrailKind(public val wire: String) {
    STRAIGHT("straight"),
    BREAKING("breaking"),
    DROPPING("dropping"),
    FADE("fade"),
    ;

    public companion object {
        public fun fromWire(wire: String): TrailKind = entries.firstOrNull { it.wire == wire }
            ?: throw IpcValidationException("trailKind.unknown:$wire")
    }
}

public enum class ImpactKind(public val wire: String) {
    GLOVE("glove"),
    PLATE("plate"),
    MISS("miss"),
    ;

    public companion object {
        public fun fromWire(wire: String): ImpactKind = entries.firstOrNull { it.wire == wire }
            ?: throw IpcValidationException("impactKind.unknown:$wire")
    }
}

public enum class QualityTier(public val wire: String) {
    HIGH("high"),
    LOW("low"),
    ;

    public companion object {
        public fun fromWire(wire: String): QualityTier = entries.firstOrNull { it.wire == wire }
            ?: throw IpcValidationException("qualityTier.unknown:$wire")
    }
}

public enum class PresentationMarker(public val wire: String) {
    RELEASE("release"),
    PLATE("plate"),
    IMPACT("impact"),
    ;

    public companion object {
        public fun fromWire(wire: String): PresentationMarker = entries.firstOrNull { it.wire == wire }
            ?: throw IpcValidationException("marker.unknown:$wire")
    }
}

public enum class PitchCommandKind(public val wire: String) {
    INITIALIZE_BRIDGE("initializeBridge"),
    PLAY_PRESENTATION("playPresentation"),
    PAUSE_PRESENTATION("pausePresentation"),
    RESUME_PRESENTATION("resumePresentation"),
    CANCEL_PRESENTATION("cancelPresentation"),
    SET_QUALITY_TIER("setQualityTier"),
    ;

    public companion object {
        public fun fromWire(wire: String): PitchCommandKind = entries.firstOrNull { it.wire == wire }
            ?: throw IpcValidationException("command.unknown:$wire")
    }
}

public enum class PitchAcknowledgementKind(public val wire: String) {
    UNITY_READY("unityReady"),
    PRESENTATION_STARTED("presentationStarted"),
    PRESENTATION_MARKER("presentationMarker"),
    PRESENTATION_COMPLETED("presentationCompleted"),
    PRESENTATION_FAILED("presentationFailed"),
    PRESENTATION_PAUSED("presentationPaused"),
    PRESENTATION_RESUMED("presentationResumed"),
    PRESENTATION_CANCELLED("presentationCancelled"),
    UNITY_UNLOADED("unityUnloaded"),
    ;

    public companion object {
        public fun fromWire(wire: String): PitchAcknowledgementKind =
            entries.firstOrNull { it.wire == wire }
                ?: throw IpcValidationException("acknowledgement.unknown:$wire")
    }
}

public enum class PresentationTerminalStatus(public val wire: String) {
    COMPLETED("completed"),
    FAILED("failed"),
    SKIPPED("skipped"),
    CANCELLED("cancelled"),
    ;

    public companion object {
        public fun fromWire(wire: String): PresentationTerminalStatus =
            entries.firstOrNull { it.wire == wire }
                ?: throw IpcValidationException("terminalStatus.unknown:$wire")
    }
}

public data class TrajectoryPoint(
    val timePermille: Int,
    val xMm: Int,
    val yMm: Int,
    val zMm: Int,
)

public data class PresentationVisual(
    val trailKind: TrailKind,
    val impactKind: ImpactKind,
    val reducedMotion: Boolean,
    val qualityTier: QualityTier,
)

/** Immutable, bounded visual data. It contains no save, player, career, or result authority. */
public data class PitchPresentationRequest(
    val requestId: String,
    val pitchId: String,
    val sequence: Int,
    val pitchType: PitchType,
    val flightDurationMs: Int,
    val plateXMm: Int,
    val plateYMm: Int,
    val velocityDeciKph: Int,
    val trajectory: List<TrajectoryPoint>,
    val presentationSeed: String,
    val visual: PresentationVisual,
    val requestSha256: String,
) {
    public fun bodyWithoutHash(): PitchPresentationRequest = copy(requestSha256 = "")

    public fun validate() {
        requireIdentifier(requestId, "requestId", 128)
        requireIdentifier(pitchId, "pitchId", 128)
        requireIdentifier(presentationSeed, "presentationSeed", 128)
        requireBounded(sequence, 0..1_000_000, "sequence")
        requireBounded(flightDurationMs, 150..3_000, "flightDurationMs")
        requireBounded(plateXMm, -50_000..50_000, "plateXMm")
        requireBounded(plateYMm, -50_000..50_000, "plateYMm")
        requireBounded(velocityDeciKph, 0..5_000, "velocityDeciKph")
        if (trajectory.size !in 2..PitchIpcContract.MAX_TRAJECTORY_POINTS) {
            throw IpcValidationException("trajectory.count")
        }
        var previous = -1
        trajectory.forEach { point ->
            requireBounded(point.timePermille, 0..1_000, "trajectory.timePermille")
            if (point.timePermille <= previous) {
                throw IpcValidationException("trajectory.time_not_strictly_increasing")
            }
            previous = point.timePermille
            requireBounded(point.xMm, -100_000..100_000, "trajectory.xMm")
            requireBounded(point.yMm, -100_000..100_000, "trajectory.yMm")
            requireBounded(point.zMm, -100_000..100_000, "trajectory.zMm")
        }
        if (!Regex("[0-9a-f]{64}").matches(requestSha256)) {
            throw IpcValidationException("requestSha256.invalid")
        }
    }
}

public data class PitchIpcCommand(
    val schema: String,
    val schemaVersion: Int,
    val messageId: String,
    val sessionId: String,
    val presentationSeed: String,
    val command: PitchCommandKind,
    val request: PitchPresentationRequest? = null,
    val qualityTier: QualityTier? = null,
    val reason: String? = null,
) {
    public fun validate() {
        validateEnvelope(schema, schemaVersion, messageId, sessionId, presentationSeed)
        when (command) {
            PitchCommandKind.INITIALIZE_BRIDGE -> require(request == null && qualityTier == null, "initialize.payload")
            PitchCommandKind.PLAY_PRESENTATION -> {
                val validRequest = request ?: throw IpcValidationException("play.payload")
                require(qualityTier == null, "play.payload")
                validRequest.validate()
                if (validRequest.presentationSeed != presentationSeed) {
                    throw IpcValidationException("presentationSeed.mismatch")
                }
            }
            PitchCommandKind.SET_QUALITY_TIER -> require(qualityTier != null && request == null, "quality.payload")
            PitchCommandKind.PAUSE_PRESENTATION,
            PitchCommandKind.RESUME_PRESENTATION,
            PitchCommandKind.CANCEL_PRESENTATION -> require(request == null && qualityTier == null, "lifecycle.payload")
        }
        reason?.let { requireIdentifier(it, "reason", 64) }
    }
}

public data class PitchTerminalResult(
    val status: PresentationTerminalStatus,
    val pitchId: String,
    val requestSha256: String,
    val errorCode: String? = null,
)

public data class PitchIpcAcknowledgement(
    val schema: String,
    val schemaVersion: Int,
    val messageId: String,
    val sessionId: String,
    val presentationSeed: String,
    val acknowledgement: PitchAcknowledgementKind,
    val pitchId: String? = null,
    val requestSha256: String? = null,
    val marker: PresentationMarker? = null,
    val terminal: PitchTerminalResult? = null,
    val errorCode: String? = null,
) {
    public fun validate() {
        validateEnvelope(schema, schemaVersion, messageId, sessionId, presentationSeed)
        pitchId?.let { requireIdentifier(it, "pitchId", 128) }
        requestSha256?.let {
            if (!Regex("[0-9a-f]{64}").matches(it)) throw IpcValidationException("requestSha256.invalid")
        }
        when (acknowledgement) {
            PitchAcknowledgementKind.UNITY_READY,
            PitchAcknowledgementKind.UNITY_UNLOADED -> require(pitchId == null && terminal == null, "ack.payload")
            PitchAcknowledgementKind.PRESENTATION_MARKER -> require(
                pitchId != null && requestSha256 != null && marker != null && terminal == null,
                "marker.payload",
            )
            PitchAcknowledgementKind.PRESENTATION_STARTED,
            PitchAcknowledgementKind.PRESENTATION_PAUSED,
            PitchAcknowledgementKind.PRESENTATION_RESUMED,
            PitchAcknowledgementKind.PRESENTATION_CANCELLED -> require(
                pitchId != null && requestSha256 != null && terminal == null,
                "presentation.lifecycle.payload",
            )
            PitchAcknowledgementKind.PRESENTATION_COMPLETED,
            PitchAcknowledgementKind.PRESENTATION_FAILED -> require(
                pitchId != null && requestSha256 != null && terminal != null,
                "terminal.payload",
            )
        }
        terminal?.also {
            require(it.pitchId == pitchId && it.requestSha256 == requestSha256, "terminal.identity")
            it.errorCode?.let { code -> requireIdentifier(code, "errorCode", 64) }
        }
        errorCode?.let { requireIdentifier(it, "errorCode", 64) }
    }
}

public class IpcValidationException(message: String) : IllegalArgumentException(message)

internal fun validateEnvelope(
    schema: String,
    schemaVersion: Int,
    messageId: String,
    sessionId: String,
    presentationSeed: String,
) {
    if (schema != PitchIpcContract.SCHEMA) throw IpcValidationException("schema.invalid")
    if (schemaVersion != PitchIpcContract.SCHEMA_VERSION) throw IpcValidationException("schemaVersion.invalid")
    requireIdentifier(messageId, "messageId", 128)
    requireIdentifier(sessionId, "sessionId", 128)
    requireIdentifier(presentationSeed, "presentationSeed", 128)
}

internal fun requireIdentifier(value: String, field: String, maxLength: Int) {
    if (value.isBlank() || value.length > maxLength || value.any { it.code < 0x20 }) {
        throw IpcValidationException("$field.invalid")
    }
}

internal fun requireBounded(value: Int, range: IntRange, field: String) {
    if (value !in range) throw IpcValidationException("$field.bounds")
}

internal fun require(condition: Boolean, code: String) {
    if (!condition) throw IpcValidationException(code)
}
