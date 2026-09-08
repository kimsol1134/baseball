package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.HighSchoolDraftOutcome
import com.solkim.baseball.core.pro.ProCareerPhase
import com.solkim.baseball.core.pro.ProLevel
import com.solkim.baseball.core.pro.ProStartMode

public object ProfessionalStatusPresentation {
    public fun canEnterPro(state: GameAggregateState): Boolean {
        val run = state.highSchool?.run ?: return false
        return run.phase == com.solkim.baseball.core.highschool.HighSchoolPhase.COMPLETED && run.draftResult?.outcome == HighSchoolDraftOutcome.DRAFTED &&
            (state.pro == null || (state.pro.phase == ProCareerPhase.COMPLETED && state.pro.sourceHighSchoolCareerId != run.careerId))
    }
    public fun section(state: GameAggregateState): Phase8Section {
        val pro = state.pro?.takeIf { state.stage in setOf(GameStage.PRO, GameStage.RETIREMENT, GameStage.LEGACY) ||
            (it.startMode == ProStartMode.LINKED && it.sourceHighSchoolCareerId == state.highSchool?.run?.careerId) }
        val draft = state.highSchool?.run?.draftResult
        val rows = when {
            pro?.phase == ProCareerPhase.COMPLETED -> listOf(Phase8Row("현재 신분", "프로 커리어 완료", pro.team.name))
            pro != null -> listOf(
                Phase8Row("현재 신분", if (pro.phase == ProCareerPhase.CONTRACT_OFFER) {
                    if (pro.season == 1 && pro.currentStats.games == 0) "지명 완료 · 입단 계약 전" else "프로 선수 · 계약 검토 중"
                } else "프로 입단 완료"),
                Phase8Row("소속", pro.team.name, if (pro.phase == ProCareerPhase.CONTRACT_OFFER) "계약 조건을 확인해 주세요."
                    else if (pro.level == ProLevel.MAJOR) "1군" else "2군 · 1군 진입에 도전합니다."))
            draft?.outcome == HighSchoolDraftOutcome.DRAFTED -> listOf(
                Phase8Row("현재 신분", "지명 완료 · 입단 계약 전", "고교에서 키운 능력과 구종으로 이어갑니다."),
                Phase8Row("지명 구단", draft.team?.name ?: "지명 구단", listOfNotNull(
                    draft.round?.let { "${it}라운드" }, draft.overallPick?.let { "전체 ${it}순위" }).joinToString(" · ")))
            draft?.outcome == HighSchoolDraftOutcome.UNDRAFTED -> listOf(
                Phase8Row("현재 신분", "이번 드래프트 미지명", "이번 생의 기록과 이어받을 힘을 남겨요."))
            else -> listOf(Phase8Row("현재 신분", "드래프트 발표 전"))
        }
        return Phase8Section("professional-status", "현재 진로", rows)
    }
}
