package com.solkim.baseball.application

import com.solkim.baseball.bridge.PitchIpcCodec
import com.solkim.baseball.core.pitch.BatterScoutingSnapshot
import com.solkim.baseball.core.pitch.BatSide
import com.solkim.baseball.core.pitch.PitchCall
import com.solkim.baseball.core.pitch.PitchIntensity
import com.solkim.baseball.core.pitch.PitchKernel
import com.solkim.baseball.core.pitch.PitchKernelResult
import com.solkim.baseball.core.pitch.PitchKind
import com.solkim.baseball.core.pitch.PitchOutcome
import com.solkim.baseball.core.pitch.PitchZone
import com.solkim.baseball.core.pitch.PitcherSnapshot
import com.solkim.baseball.core.pitch.PlateAppearanceContext
import com.solkim.baseball.core.highschool.HighSchoolPresentationState
import com.solkim.baseball.model.ImpactKind
import com.solkim.baseball.model.PitchPresentationRequest
import com.solkim.baseball.model.PitchType
import com.solkim.baseball.model.PresentationVisual
import com.solkim.baseball.model.QualityTier
import com.solkim.baseball.model.TrailKind
import com.solkim.baseball.model.TrajectoryPoint

/**
 * Converts an authoritative Kotlin result into the renderer-only IPC snapshot.
 *
 * The Unity request contains trajectory and visual metadata only. It intentionally does not
 * carry outcome, count, save, or player-authority fields; those remain in [PitchKernelResult].
 */
public object PitchPresentationFactory {
    public fun fromKernelResult(
        sessionId: String,
        sequence: Int,
        result: PitchKernelResult,
    ): PitchPresentationRequest {
        return fromSnapshot(
            sessionId = sessionId,
            sequence = sequence,
            presentation = result.snapshot.trajectoryPresentation,
            outcome = result.snapshot.outcome,
        )
    }

    /** Converts a saved HighSchool presentation checkpoint into the exact same renderer wire. */
    public fun fromHighSchoolPresentation(
        sessionId: String,
        sequence: Int,
        state: HighSchoolPresentationState,
    ): PitchPresentationRequest {
        val outcome = PitchOutcome.entries.firstOrNull { it.wire == state.outcome }
            ?: error("pitch.presentation.outcome_unknown")
        return fromSnapshot(sessionId, sequence, state.snapshot, outcome)
    }

    /** Converts the saved Pro trajectory snapshot without moving any result meaning into Unity. */
    public fun fromTrajectoryPresentation(
        sessionId: String,
        sequence: Int,
        presentation: com.solkim.baseball.core.pitch.TrajectoryPresentationSnapshot,
        outcome: PitchOutcome,
    ): PitchPresentationRequest = fromSnapshot(sessionId, sequence, presentation, outcome)

    private fun fromSnapshot(
        sessionId: String,
        sequence: Int,
        presentation: com.solkim.baseball.core.pitch.TrajectoryPresentationSnapshot,
        outcome: PitchOutcome,
    ): PitchPresentationRequest {
        val points = presentation.trajectorySeries.chunked(4).mapIndexed { index, values ->
            TrajectoryPoint(
                timePermille = index * 1_000 / 24,
                xMm = values[1],
                yMm = values[3],
                zMm = values[2],
            )
        }
        val pitchType = presentation.pitchType
        return PitchIpcCodec.createRequest(
            requestId = "$sessionId:request:$sequence",
            pitchId = "$sessionId:pitch:$sequence",
            sequence = sequence,
            pitchType = pitchType.toModelType(),
            flightDurationMs = presentation.flightDurationMilliseconds,
            plateXMm = presentation.plateXMm,
            plateYMm = presentation.plateYMm,
            velocityDeciKph = presentation.velocityTenthsKph,
            trajectory = points,
            presentationSeed = presentation.presentationSeed,
            visual = PresentationVisual(
                trailKind = pitchType.trailKind(),
                impactKind = outcome.impactKind(),
                reducedMotion = false,
                qualityTier = QualityTier.HIGH,
            ),
        )
    }

    private fun PitchKernelResult.snapshotCallType(): PitchKind = snapshot.trajectoryPresentation.pitchType

    private fun PitchKind.toModelType(): PitchType = when (this) {
        PitchKind.FOUR_SEAM -> PitchType.FOUR_SEAM
        PitchKind.SLIDER -> PitchType.SLIDER
        PitchKind.CURVEBALL -> PitchType.CURVEBALL
        PitchKind.CHANGEUP -> PitchType.CHANGEUP
    }

    private fun PitchKind.trailKind(): TrailKind = when (this) {
        PitchKind.FOUR_SEAM -> TrailKind.STRAIGHT
        PitchKind.SLIDER -> TrailKind.BREAKING
        PitchKind.CURVEBALL -> TrailKind.DROPPING
        PitchKind.CHANGEUP -> TrailKind.FADE
    }

    private fun PitchOutcome.impactKind(): ImpactKind = when (this) {
        PitchOutcome.BALL, PitchOutcome.CALLED_STRIKE, PitchOutcome.SWINGING_STRIKE -> ImpactKind.MISS
        PitchOutcome.FOUL, PitchOutcome.IN_PLAY_OUT, PitchOutcome.SINGLE,
        PitchOutcome.DOUBLE, PitchOutcome.TRIPLE, PitchOutcome.HOME_RUN -> ImpactKind.PLATE
        PitchOutcome.HIT_BY_PITCH -> ImpactKind.GLOVE
    }
}

/** One Kotlin-owned pitch session used by the Compose host; Unity receives only its snapshot. */
public class KotlinPitchPresentationSession(
    private val kernel: PitchKernel = PitchKernel(),
) {
    private val pitcher = PitcherSnapshot("pitcher-shell", "가상 투수", 62, 54, 58, 60)
    private val batter = com.solkim.baseball.core.pitch.BatterSnapshot("batter-shell", "가상 타자", 56, 52, 58, BatSide.RIGHT)
    private val scouting = BatterScoutingSnapshot(
        hotZone = PitchZone(1, 1),
        coldZone = PitchZone(2, 0),
        pitchStrength = PitchKind.FOUR_SEAM,
        pitchWeakness = PitchKind.SLIDER,
        chaseTendency = 48,
    )
    private val calls = listOf(
        PitchCall(PitchKind.FOUR_SEAM, PitchZone(1, 1), com.solkim.baseball.core.pitch.ZoneIntent.STRIKE, PitchIntensity.NORMAL),
        PitchCall(PitchKind.SLIDER, PitchZone(2, 0), com.solkim.baseball.core.pitch.ZoneIntent.EDGE, PitchIntensity.NORMAL),
        PitchCall(PitchKind.CURVEBALL, PitchZone(2, 2), com.solkim.baseball.core.pitch.ZoneIntent.EDGE, PitchIntensity.NORMAL),
        PitchCall(PitchKind.CHANGEUP, PitchZone(1, 2), com.solkim.baseball.core.pitch.ZoneIntent.EDGE, PitchIntensity.NORMAL),
    )

    public fun request(sessionId: String, index: Int, sequence: Int = index + 1): PitchPresentationRequest {
        val safeIndex = index.coerceIn(calls.indices)
        val seed = (2_026_072_1L + safeIndex).toString()
        val context = PlateAppearanceContext("$sessionId:pa", sequence.toULong(), 7, 0, 1, 1, 1, 0, 600, 12)
        val prepare = kernel.prepare(
            PitchKernel.PrepareRequest(seed, pitcher, batter, scouting, context),
        )
        val result = kernel.submit(
            PitchKernel.SubmitRequest(
                seed = seed,
                pitcher = pitcher,
                batter = batter,
                scouting = scouting,
                context = context,
                preparationToken = prepare.preparationToken,
                call = calls[safeIndex],
            ),
        )
        return PitchPresentationFactory.fromKernelResult(sessionId, sequence, result)
    }
}
