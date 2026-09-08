package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.*
import com.solkim.baseball.core.pro.*
import com.solkim.baseball.core.pitch.PitchAbilityRules

public data class LineageView(val legacyId: String, val rank: Int, val contributions: Int, val nextThreshold: Int?, val family: String)
/** Rendering receives facts and commands from the application boundary, not a second rules implementation. */
public object CareerUiRules {
    public val chapterCount: Int get() = HighSchoolContentCatalog.chapters.size
    public fun isDrafted(state: GameAggregateState): Boolean = state.highSchool?.run?.draftResult?.outcome == HighSchoolDraftOutcome.DRAFTED
    public fun legacyFamily(id: String): String? = HighSchoolSignatureLegacyRules.definitions.firstOrNull { it.id == id }?.family
    public fun achievementIds(state: GameAggregateState): List<String> {
        val legacy = setOf(HighSchoolAchievementRules.MAJOR_DEBUT, HighSchoolAchievementRules.HUNDRED_STRIKEOUTS, HighSchoolAchievementRules.HALL_OF_FAME)
        return HighSchoolAchievementRules.all.filter { it !in legacy || it in state.highSchool?.achievements.orEmpty() }
    }
    public fun schoolWins(state: GameAggregateState): Int = state.highSchool?.seasonLog.orEmpty().count { it.played && it.decision == HighSchoolPitchingDecision.WIN }
    public fun proRole(state: GameAggregateState): String = state.pro?.role?.label.orEmpty()
    public fun proContext(state: GameAggregateState): String = state.pro?.let { "프로 선수 · ${it.team.name} · ${if (it.level == ProLevel.MAJOR) "1군" else "2군"}" }.orEmpty()
    public fun lineage(state: GameAggregateState): LineageView? {
        val school = state.highSchool ?: return null
        val inherited = HighSchoolLineageRules.recovered(school.inheritance, school.archive)
        val active = inherited.lineageLoadout ?: return null
        val mastery = inherited.lineageMasteries.firstOrNull { it.family == legacyFamily(active.legacyId) } ?: return null
        return LineageView(active.legacyId, mastery.rank, mastery.contributions, mastery.nextThreshold, mastery.family)
    }
    public fun selectedVelocity(state: GameAggregateState, selection: PitchHudSelection): Int = PitchAbilityRules.expectedVelocity(
        PitchHudProjection.pitcher(state), PitchHudProjection.resolveCall(state, selection), PitchHudProjection.fatigue(state),
        (state.highSchool?.activePitch?.sessionId ?: state.pro?.activePitch?.sessionId).orEmpty().endsWith(":outing-v2"))
    public fun startProfessional(state: GameAggregateState, context: Phase8CommandContext, preset: String, name: String): List<Phase8CommandPayload> {
        val command = GameCommand.Pro(ProCommand.StartDirect(ProStartDirectRequest(context.seed(state, "pro-direct"), preset, name.trim())))
        return Phase8Payloads.batch(state, Phase8ScreenId.P001_OPENING, "startDirect", listOf(command))
    }
}
