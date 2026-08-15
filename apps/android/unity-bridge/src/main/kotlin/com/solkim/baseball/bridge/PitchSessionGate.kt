package com.solkim.baseball.bridge

import com.solkim.baseball.model.PitchAcknowledgementKind
import com.solkim.baseball.model.PitchIpcAcknowledgement
import com.solkim.baseball.model.PitchIpcCommand
import com.solkim.baseball.model.PitchPresentationRequest
import com.solkim.baseball.model.PresentationMarker

public enum class ProtocolDecisionKind {
    ACCEPTED,
    DUPLICATE,
    REJECTED,
}

public data class ProtocolDecision(
    val kind: ProtocolDecisionKind,
    val code: String,
) {
    public val accepted: Boolean get() = kind == ProtocolDecisionKind.ACCEPTED
}

/**
 * One-session, one-active-request protocol gate. This is deliberately independent of gameplay
 * state: it only protects bridge ordering and replay safety.
 */
public class PitchSessionGate {
    private var sessionId: String? = null
    private var initialized: Boolean = false
    private var unityReady: Boolean = false
    private var active: ActivePresentation? = null
    private val commandMessages = LinkedHashMap<String, String>()
    private val acknowledgementMessages = LinkedHashMap<String, String>()
    private var lastUnloaded: Boolean = false

    public fun acceptCommand(command: PitchIpcCommand): ProtocolDecision {
        val fingerprint = runCatching { PitchIpcCodec.encodeCommand(command) }
            .getOrElse { return ProtocolDecision(ProtocolDecisionKind.REJECTED, "command.invalid") }
        if (sessionId != null && command.sessionId != sessionId) {
            return ProtocolDecision(ProtocolDecisionKind.REJECTED, "stale_session")
        }
        commandMessages[command.messageId]?.let { previous ->
            return if (previous == fingerprint) {
                ProtocolDecision(ProtocolDecisionKind.DUPLICATE, "duplicate_message")
            } else {
                ProtocolDecision(ProtocolDecisionKind.REJECTED, "message_id_reuse")
            }
        }
        when (command.command) {
            com.solkim.baseball.model.PitchCommandKind.INITIALIZE_BRIDGE -> {
                if (sessionId != null || initialized) {
                    return ProtocolDecision(ProtocolDecisionKind.REJECTED, "already_initialized")
                }
                sessionId = command.sessionId
                initialized = true
                lastUnloaded = false
            }
            com.solkim.baseball.model.PitchCommandKind.PLAY_PRESENTATION -> {
                if (!initialized) return ProtocolDecision(ProtocolDecisionKind.REJECTED, "not_initialized")
                if (!unityReady) return ProtocolDecision(ProtocolDecisionKind.REJECTED, "unity_not_ready")
                val request = command.request ?: return ProtocolDecision(ProtocolDecisionKind.REJECTED, "request_missing")
                val current = active
                if (current != null) {
                    if (current.request.pitchId == request.pitchId &&
                        current.request.requestSha256 == request.requestSha256
                    ) {
                        if (current.terminal) {
                            // A terminal presentation is replayable: Kotlin already owns the
                            // result, so a new renderer request may show the exact same snapshot.
                            active = ActivePresentation(request)
                        } else {
                            return ProtocolDecision(ProtocolDecisionKind.DUPLICATE, "duplicate_presentation")
                        }
                    } else if (!current.terminal) {
                        return ProtocolDecision(ProtocolDecisionKind.REJECTED, "active_request")
                    }
                }
                if (current == null || current.request.pitchId != request.pitchId || current.request.requestSha256 != request.requestSha256) {
                    active = ActivePresentation(request)
                }
            }
            com.solkim.baseball.model.PitchCommandKind.PAUSE_PRESENTATION,
            com.solkim.baseball.model.PitchCommandKind.RESUME_PRESENTATION,
            com.solkim.baseball.model.PitchCommandKind.CANCEL_PRESENTATION -> {
                if (active == null) return ProtocolDecision(ProtocolDecisionKind.REJECTED, "no_active_request")
            }
            com.solkim.baseball.model.PitchCommandKind.SET_QUALITY_TIER -> {
                if (!initialized) return ProtocolDecision(ProtocolDecisionKind.REJECTED, "not_initialized")
            }
        }
        commandMessages[command.messageId] = fingerprint
        return ProtocolDecision(ProtocolDecisionKind.ACCEPTED, "accepted")
    }

    public fun acceptAcknowledgement(acknowledgement: PitchIpcAcknowledgement): ProtocolDecision {
        val fingerprint = runCatching { PitchIpcCodec.encodeAcknowledgement(acknowledgement) }
            .getOrElse { return ProtocolDecision(ProtocolDecisionKind.REJECTED, "ack.invalid") }
        if (acknowledgement.sessionId != sessionId) {
            return ProtocolDecision(ProtocolDecisionKind.REJECTED, "stale_session")
        }
        acknowledgementMessages[acknowledgement.messageId]?.let { previous ->
            return if (previous == fingerprint) {
                ProtocolDecision(ProtocolDecisionKind.DUPLICATE, "duplicate_ack")
            } else {
                ProtocolDecision(ProtocolDecisionKind.REJECTED, "message_id_reuse")
            }
        }
        when (acknowledgement.acknowledgement) {
            PitchAcknowledgementKind.UNITY_READY -> {
                if (!initialized) return ProtocolDecision(ProtocolDecisionKind.REJECTED, "not_initialized")
                if (unityReady) return ProtocolDecision(ProtocolDecisionKind.DUPLICATE, "already_ready")
                unityReady = true
            }
            PitchAcknowledgementKind.UNITY_UNLOADED -> {
                if (active?.terminal == false) return ProtocolDecision(ProtocolDecisionKind.REJECTED, "active_request")
                lastUnloaded = true
            }
            else -> {
                val current = active ?: return ProtocolDecision(ProtocolDecisionKind.REJECTED, "stale_pitch")
                if (acknowledgement.pitchId != current.request.pitchId ||
                    acknowledgement.requestSha256 != current.request.requestSha256 ||
                    acknowledgement.presentationSeed != current.request.presentationSeed
                ) {
                    return ProtocolDecision(ProtocolDecisionKind.REJECTED, "stale_pitch")
                }
                val duplicateTerminal = current.terminal &&
                    (acknowledgement.acknowledgement == PitchAcknowledgementKind.PRESENTATION_COMPLETED ||
                        acknowledgement.acknowledgement == PitchAcknowledgementKind.PRESENTATION_FAILED)
                if (duplicateTerminal) return ProtocolDecision(ProtocolDecisionKind.DUPLICATE, "duplicate_terminal")
                when (acknowledgement.acknowledgement) {
                    PitchAcknowledgementKind.PRESENTATION_STARTED -> {
                        if (current.started) return ProtocolDecision(ProtocolDecisionKind.DUPLICATE, "already_started")
                        current.started = true
                    }
                    PitchAcknowledgementKind.PRESENTATION_MARKER -> {
                        if (!current.started) return ProtocolDecision(ProtocolDecisionKind.REJECTED, "marker_before_started")
                        val marker = acknowledgement.marker ?: return ProtocolDecision(ProtocolDecisionKind.REJECTED, "marker_missing")
                        if (current.markers.contains(marker)) return ProtocolDecision(ProtocolDecisionKind.DUPLICATE, "duplicate_marker")
                        if (marker.ordinal != current.markers.size) {
                            return ProtocolDecision(ProtocolDecisionKind.REJECTED, "marker_order")
                        }
                        current.markers += marker
                    }
                    PitchAcknowledgementKind.PRESENTATION_COMPLETED,
                    PitchAcknowledgementKind.PRESENTATION_FAILED -> {
                        if (!current.started) return ProtocolDecision(ProtocolDecisionKind.REJECTED, "terminal_before_started")
                        current.terminal = true
                    }
                    PitchAcknowledgementKind.PRESENTATION_PAUSED,
                    PitchAcknowledgementKind.PRESENTATION_RESUMED,
                    PitchAcknowledgementKind.PRESENTATION_CANCELLED -> {
                        if (current.terminal) return ProtocolDecision(ProtocolDecisionKind.REJECTED, "terminal_request")
                    }
                    PitchAcknowledgementKind.UNITY_READY,
                    PitchAcknowledgementKind.UNITY_UNLOADED -> error("handled above")
                }
            }
        }
        acknowledgementMessages[acknowledgement.messageId] = fingerprint
        return ProtocolDecision(ProtocolDecisionKind.ACCEPTED, "accepted")
    }

    public fun activeRequest(): PitchPresentationRequest? = active?.request
    public fun isInitialized(): Boolean = initialized
    public fun isUnityReady(): Boolean = unityReady
    public fun wasUnloaded(): Boolean = lastUnloaded

    private class ActivePresentation(val request: PitchPresentationRequest) {
        var started: Boolean = false
        var terminal: Boolean = false
        val markers: MutableList<PresentationMarker> = ArrayList()
    }
}
