package com.solkim.baseball.application

import com.solkim.baseball.core.pitch.BaserunnerStateSnapshot
import com.solkim.baseball.core.pitch.PlateAppearanceContext

/** iOS ScoreboardBar와 같은 점수·카운트·상황 한 줄. 화면은 숫자를 만들지 않는다. */
public data class PitchScoreboardModel(
    val scoreText: String,
    val scoreDiff: Int,
    val inningText: String,
    val inning: Int,
    val balls: Int,
    val strikes: Int,
    val outs: Int,
    val situationText: String,
    val fatigue: Int,
    val outingLine: String?,
    val runners: BaserunnerStateSnapshot,
    val accessibilityLabel: String,
)

public object PitchScoreboardProjection {
    public fun model(state: GameAggregateState): PitchScoreboardModel {
        val context = liveContext(state)
        val runners = liveRunners(state)
        val scoreDiff = context.scoreDifferential
        val scoreText = when {
            scoreDiff == 0 -> "동점"
            scoreDiff > 0 -> "${scoreDiff}점 앞섬"
            else -> "${-scoreDiff}점 뒤짐"
        }
        val inningText = "${context.inning.coerceAtLeast(0)}회"
        val situationText = situationLine(context.outs, runners)
        val outingLine = outingLine(state)
        val accessibility = listOfNotNull(
            scoreText,
            inningText,
            "볼 ${context.balls}",
            "스트라이크 ${context.strikes}",
            "아웃 ${context.outs}",
            situationText,
            "피로 ${context.fatigue}",
            outingLine,
        ).joinToString(", ")
        return PitchScoreboardModel(
            scoreText = scoreText,
            scoreDiff = scoreDiff,
            inningText = inningText,
            inning = context.inning.coerceAtLeast(0),
            balls = context.balls,
            strikes = context.strikes,
            outs = context.outs,
            situationText = situationText,
            fatigue = context.fatigue,
            outingLine = outingLine,
            runners = runners,
            accessibilityLabel = accessibility,
        )
    }

    public fun situationLine(outs: Int, runners: BaserunnerStateSnapshot): String {
        val outsText = "${outs.coerceIn(0, 2)}사"
        return when {
            !runners.firstOccupied && !runners.secondOccupied && !runners.thirdOccupied -> "$outsText 주자 없음"
            runners.firstOccupied && runners.secondOccupied && runners.thirdOccupied -> "$outsText 만루"
            else -> {
                val bases = listOfNotNull(
                    "1루".takeIf { runners.firstOccupied },
                    "2루".takeIf { runners.secondOccupied },
                    "3루".takeIf { runners.thirdOccupied },
                ).joinToString("·")
                "$outsText $bases"
            }
        }
    }

    private fun liveContext(state: GameAggregateState): PlateAppearanceContext {
        val pitch = state.pitch
        if (pitch?.careerKind == PitchCareerKind.TUTORIAL) {
            return PlateAppearanceContext(
                plateAppearanceId = pitch.sessionId,
                revision = 0UL,
                inning = 1,
                outs = 0,
                balls = 0,
                strikes = 0,
                pitchNumber = 1,
                scoreDifferential = 0,
                leverage = 200,
                fatigue = 0,
            )
        }
        state.pro?.activePitch?.context?.let { return it }
        state.highSchool?.activePitch?.let { session ->
            return PlateAppearanceContext(
                plateAppearanceId = session.sessionId,
                revision = 0UL,
                inning = session.context.inning,
                outs = session.context.outs,
                balls = session.context.balls,
                strikes = session.context.strikes,
                pitchNumber = session.context.pitchNumber,
                scoreDifferential = session.context.scoreDifferential,
                leverage = session.context.leverage,
                fatigue = session.context.fatigue,
            )
        }
        return PlateAppearanceContext("empty", 0UL, 1, 0, 0, 0, 1, 0, 0, 0)
    }

    private fun liveRunners(state: GameAggregateState): BaserunnerStateSnapshot {
        if (state.pitch?.careerKind == PitchCareerKind.TUTORIAL) return BaserunnerStateSnapshot.EMPTY
        state.pro?.activePitch?.game?.runners?.let { return it }
        state.highSchool?.activePitch?.game?.let { game ->
            return BaserunnerStateSnapshot(game.firstOccupied, game.secondOccupied, game.thirdOccupied, 52)
        }
        return BaserunnerStateSnapshot.EMPTY
    }

    private fun outingLine(state: GameAggregateState): String? {
        val pro = state.pro?.activePitch
        if (pro != null && pro.pitches > 0) {
            return formatOuting(pro.outs, pro.strikeouts, pro.walks, pro.runsAllowed, pro.pitches, pro.perfectReleases)
        }
        val hs = state.highSchool?.activePitch
        if (hs != null && hs.pitches > 0) {
            return formatOuting(hs.outs, hs.strikeouts, hs.walks, hs.runsAllowed, hs.pitches, hs.perfectReleases)
        }
        return null
    }

    private fun formatOuting(outs: Int, strikeouts: Int, walks: Int, runs: Int, pitches: Int, perfect: Int = 0): String {
        val innings = "${outs / 3}.${outs % 3}"
        val base = "${innings}이닝 · ${strikeouts}탈삼진 ${walks}볼넷 ${runs}실점 · ${pitches}구"
        return if (perfect > 0) "$base · 퍼펙트 $perfect" else base
    }
}
