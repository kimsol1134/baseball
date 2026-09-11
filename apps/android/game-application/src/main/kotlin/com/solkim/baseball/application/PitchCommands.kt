package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.HighSchoolPhase
import com.solkim.baseball.core.pro.ProCareerPhase

internal data class PitchReduction(val state: GameAggregateState, val eventName: String)

/** Single pitch-command apply used by the typed reducer and the C# save bridge. */
internal object PitchCommands {
    fun reserve(state: GameAggregateState, command: GameCommand.ReservePitch): PitchReduction {
        require(state.pitch == null || state.pitch.boundary == PitchBoundary.COMPLETED || state.pitch.boundary == PitchBoundary.ABANDONED) { "pitch.reserve_active" }
        require(!state.deleted) { "pitch.reserve_deleted" }
        when (command.careerKind) {
            PitchCareerKind.HIGH_SCHOOL -> {
                val highSchool = state.highSchool
                require(highSchool != null && highSchool.run.careerId == command.careerId) { "pitch.reserve_highSchool_career" }
                require(highSchool.run.phase != HighSchoolPhase.COMPLETED) { "pitch.reserve_highSchool_inactive" }
            }
            PitchCareerKind.PRO -> {
                val pro = state.pro
                require(pro != null && pro.careerId == command.careerId) { "pitch.reserve_pro_career" }
                require(pro.phase != ProCareerPhase.COMPLETED) { "pitch.reserve_pro_inactive" }
            }
            PitchCareerKind.TUTORIAL -> state.requireActiveTutorialPitch(
                careerId = command.careerId,
                boundary = PitchBoundary.RESERVED,
                challengeRun = command.challengeRun,
                errorPrefix = "pitch.reserve_tutorial",
            )
        }
        val next = PitchDurableState(command.sessionId, command.careerKind, command.careerId, command.gameId, command.seed, PitchBoundary.RESERVED, challengeRun = command.challengeRun)
        return PitchReduction(state.copy(pitch = next), "pitch.reserved")
    }

    fun start(state: GameAggregateState, command: GameCommand.StartPitch): PitchReduction {
        val pitch = requirePitch(state, command.sessionId)
        require(pitch.boundary == PitchBoundary.RESERVED) { "pitch.start_boundary" }
        return PitchReduction(state.copy(pitch = pitch.copy(boundary = PitchBoundary.PLAYING)), "pitch.playing")
    }

    fun commit(state: GameAggregateState, command: GameCommand.CommitPitch): PitchReduction {
        val pitch = requirePitch(state, command.sessionId)
        require(pitch.boundary == PitchBoundary.PLAYING) { "pitch.commit_boundary" }
        require(command.pitchId.isNotBlank() && command.resultHash.isNotBlank()) { "pitch.commit_payload" }
        require(command.pitchId !in pitch.committedPitchIds) { "pitch.commit_duplicate" }
        val next = pitch.copy(
            boundary = PitchBoundary.COMMITTED,
            pitchIndex = pitch.pitchIndex + 1,
            committedPitchIds = pitch.committedPitchIds + command.pitchId,
            resultHashes = pitch.resultHashes + command.resultHash,
            checkpoint = command.checkpoint ?: pitch.checkpoint,
        )
        return PitchReduction(state.copy(pitch = next), "pitch.committed")
    }

    fun consume(state: GameAggregateState, command: GameCommand.ConsumePitch): PitchReduction {
        val pitch = requirePitch(state, command.sessionId)
        require(pitch.boundary == PitchBoundary.COMMITTED) { "pitch.consume_boundary" }
        require(command.pitchId in pitch.committedPitchIds && command.pitchId !in pitch.consumedPitchIds) { "pitch.consume_payload" }
        return PitchReduction(state.copy(pitch = pitch.copy(boundary = PitchBoundary.CONSUMED, consumedPitchIds = pitch.consumedPitchIds + command.pitchId)), "pitch.consumed")
    }

    fun terminal(state: GameAggregateState, command: GameCommand.MarkPitchTerminal): PitchReduction {
        val pitch = requirePitch(state, command.sessionId)
        require(pitch.boundary == PitchBoundary.CONSUMED) { "pitch.terminal_boundary" }
        require(command.pitchId in pitch.consumedPitchIds && command.terminalHash.isNotBlank()) { "pitch.terminal_payload" }
        val resultHashes = pitch.resultHashes.toMutableList()
        resultHashes[pitch.consumedPitchIds.indexOf(command.pitchId)] = command.terminalHash
        return PitchReduction(state.copy(pitch = pitch.copy(boundary = PitchBoundary.TERMINAL, terminalPitchId = command.pitchId, resultHashes = resultHashes)), "pitch.terminal")
    }

    fun complete(state: GameAggregateState, command: GameCommand.CompletePitch): PitchReduction =
        PitchReduction(GameCompletionRules.completePitch(state, command.sessionId), "pitch.completed")

    fun suspend(state: GameAggregateState, command: GameCommand.SuspendPitch): PitchReduction {
        val pitch = requirePitch(state, command.sessionId)
        return PitchReduction(state.copy(pitch = PitchStateTransitions.suspend(pitch, command.checkpoint)), "pitch.suspended")
    }

    fun resume(state: GameAggregateState, command: GameCommand.ResumePitch): PitchReduction {
        val pitch = requirePitch(state, command.sessionId)
        return PitchReduction(state.copy(pitch = PitchStateTransitions.resume(pitch)), "pitch.resumed")
    }

    fun abandon(state: GameAggregateState, command: GameCommand.AbandonPitch): PitchReduction {
        val pitch = requirePitch(state, command.sessionId)
        return PitchReduction(state.copy(pitch = PitchStateTransitions.abandon(pitch, command.reason)), "pitch.abandoned")
    }

    fun holdCall(state: GameAggregateState, command: GameCommand.SetPitchHoldCall): PitchReduction {
        val pitch = state.pitch ?: throw GameCommandException("pitch.hold_call_missing")
        require(pitch.sessionId == command.sessionId) { "pitch.hold_call_session" }
        if (pitch.holdCall == command.holdCall) return PitchReduction(state, "pitch.hold_call")
        return PitchReduction(state.copy(pitch = pitch.copy(holdCall = command.holdCall)), "pitch.hold_call")
    }

    fun clearPresentation(state: GameAggregateState, command: GameCommand.ClearPitchPresentation): PitchReduction {
        val pitch = requirePitch(state, command.sessionId)
        require(pitch.boundary == PitchBoundary.COMPLETED || pitch.boundary == PitchBoundary.ABANDONED) {
            "pitch.clear_boundary"
        }
        return when (pitch.careerKind) {
            PitchCareerKind.PRO -> {
                val pro = state.pro
                if (pro != null && (pro.lastPresentation != null || pro.lastBattedBall != null || pro.lastFielding != null)) {
                    val cleared = pro.copy(
                        lastPresentation = null,
                        lastBattedBall = null,
                        lastFielding = null,
                        commitment = "",
                    )
                    val resigned = cleared.copy(commitment = com.solkim.baseball.core.pro.ProKernel().commitment(cleared))
                    PitchReduction(state.copy(pro = resigned), "pitch.presentation_cleared")
                } else {
                    PitchReduction(state, "pitch.presentation_already_clear")
                }
            }
            PitchCareerKind.HIGH_SCHOOL, PitchCareerKind.TUTORIAL -> {
                val highSchool = state.highSchool
                if (highSchool?.lastPresentation != null) {
                    val resigned = com.solkim.baseball.core.highschool.HighSchoolPhase4Kernel()
                        .commitShadowState(highSchool.copy(lastPresentation = null))
                    PitchReduction(state.copy(highSchool = resigned), "pitch.presentation_cleared")
                } else {
                    PitchReduction(state, "pitch.presentation_already_clear")
                }
            }
        }
    }

    fun requirePitch(state: GameAggregateState, sessionId: String): PitchDurableState {
        val pitch = state.pitch ?: throw GameCommandException("pitch.missing")
        require(pitch.sessionId == sessionId) { "pitch.session_mismatch" }
        return pitch
    }
}
