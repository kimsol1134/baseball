package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.HighSchoolPhase4Kernel
import com.solkim.baseball.core.highschool.HighSchoolTutorialMound
import com.solkim.baseball.core.highschool.toBatterSnapshot
import com.solkim.baseball.core.highschool.toPitcherSnapshot
import com.solkim.baseball.core.pitch.BatterSnapshot
import com.solkim.baseball.core.pitch.PitchCall
import com.solkim.baseball.core.pitch.PitchIntensity
import com.solkim.baseball.core.pitch.PitchKernel
import com.solkim.baseball.core.pitch.PitchKind
import com.solkim.baseball.core.pitch.PitchPreparation
import com.solkim.baseball.core.pitch.PitchZone
import com.solkim.baseball.core.pitch.PitcherSnapshot
import com.solkim.baseball.core.pitch.ZoneIntent

public sealed interface PitchHudSelection {
    public data object Primary : PitchHudSelection
    public data object Alternative : PitchHudSelection
    public data class Manual(val pitchType: PitchKind, val zone: PitchZone) : PitchHudSelection
}

public data class PitchHudModel(
    val repertoire: List<PitchKind>,
    val batter: BatterSnapshot,
    val preparation: PitchPreparation,
    val canContinueInSession: Boolean,
)

/** Assembles the live mound call from repertoire + catcher signs. The UI does not invent a PitchCall. */
public object PitchHudProjection {
    public fun selectableTypes(pitcher: PitcherSnapshot): List<PitchKind> {
        val profiles = pitcher.pitchProfiles.orEmpty()
        if (profiles.isEmpty()) return PitchKind.entries.toList()
        return profiles.map { it.pitchType }.distinct()
    }

    public fun pitcher(state: GameAggregateState): PitcherSnapshot {
        val pitch = state.pitch
        val pro = state.pro
        if (pitch?.careerKind == PitchCareerKind.PRO && pro != null) return pro.pitcher
        val highSchool = requireNotNull(state.highSchool) { "pitch.hud.highSchool_missing" }
        return highSchool.run.toPitcherSnapshot()
    }

    public fun batter(state: GameAggregateState): BatterSnapshot {
        val pitch = state.pitch
        if (pitch?.careerKind == PitchCareerKind.PRO) {
            return requireNotNull(state.pro?.activePitch?.batter) { "pitch.hud.pro_batter_missing" }
        }
        if (pitch?.careerKind == PitchCareerKind.TUTORIAL) return HighSchoolTutorialMound.BATTER
        val highSchool = requireNotNull(state.highSchool) { "pitch.hud.highSchool_missing" }
        return highSchool.run.toBatterSnapshot()
    }

    public fun repertoire(state: GameAggregateState): List<PitchKind> = selectableTypes(pitcher(state))

    public fun preparation(state: GameAggregateState): PitchPreparation {
        val pitch = requireNotNull(state.pitch) { "pitch.hud.pitch_missing" }
        return when (pitch.careerKind) {
            PitchCareerKind.TUTORIAL -> HighSchoolPhase4Kernel().prepareTutorial(
                requireNotNull(state.highSchool) { "pitch.hud.highSchool_missing" },
                pitch.sessionId,
            )
            PitchCareerKind.HIGH_SCHOOL -> HighSchoolPhase4Kernel().prepareActivePitch(
                requireNotNull(state.highSchool) { "pitch.hud.highSchool_missing" },
            )
            PitchCareerKind.PRO -> {
                val pro = requireNotNull(state.pro) { "pitch.hud.pro_missing" }
                val session = requireNotNull(pro.activePitch) { "pitch.hud.pro_pitch_missing" }
                PitchKernel().prepare(
                    PitchKernel.PrepareRequest(
                        seed = session.seed,
                        pitcher = pro.pitcher,
                        batter = session.batter,
                        scouting = session.scouting,
                        context = session.context,
                        rivalMemory = session.memory,
                        gameState = session.game,
                        gameLog = session.log,
                    ),
                )
            }
        }
    }

    public fun model(state: GameAggregateState): PitchHudModel {
        val preparation = preparation(state)
        val active = state.highSchool?.activePitch
        val proActive = state.pro?.activePitch
        val canContinue = (active != null && !active.ended) || (proActive != null && !proActive.ended)
        return PitchHudModel(
            repertoire = repertoire(state),
            batter = batter(state),
            preparation = preparation,
            canContinueInSession = canContinue,
        )
    }

    public fun resolveCall(
        pitcher: PitcherSnapshot,
        preparation: PitchPreparation,
        selection: PitchHudSelection,
    ): PitchCall {
        val allowed = selectableTypes(pitcher)
        val call = when (selection) {
            PitchHudSelection.Primary -> preparation.primaryRecommendation.call
            PitchHudSelection.Alternative -> preparation.alternativeRecommendation.call
            is PitchHudSelection.Manual -> {
                val matched = listOf(
                    preparation.primaryRecommendation,
                    preparation.alternativeRecommendation,
                ).firstOrNull { it.call.pitchType == selection.pitchType && it.call.zone == selection.zone }
                matched?.call ?: PitchCall(selection.pitchType, selection.zone, ZoneIntent.EDGE, PitchIntensity.NORMAL)
            }
        }
        require(call.pitchType in allowed) { "pitch.not_in_repertoire" }
        return call
    }

    public fun resolveCall(state: GameAggregateState, selection: PitchHudSelection): PitchCall =
        resolveCall(pitcher(state), preparation(state), selection)

    public fun koreanLabel(kind: PitchKind): String = when (kind) {
        PitchKind.FOUR_SEAM -> "직구"
        PitchKind.SLIDER -> "슬라이더"
        PitchKind.CURVEBALL -> "커브"
        PitchKind.CHANGEUP -> "체인지업"
    }
}
