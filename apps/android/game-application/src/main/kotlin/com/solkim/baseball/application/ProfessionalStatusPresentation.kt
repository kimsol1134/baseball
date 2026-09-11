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
    public fun section(state: GameAggregateState): ScreenSection {
        val pro = state.pro?.takeIf { state.stage in setOf(GameStage.PRO, GameStage.RETIREMENT, GameStage.LEGACY) ||
            (it.startMode == ProStartMode.LINKED && it.sourceHighSchoolCareerId == state.highSchool?.run?.careerId) }
        val draft = state.highSchool?.run?.draftResult
        val rows = when {
            pro?.phase == ProCareerPhase.COMPLETED -> listOf(ScreenRow("다음 단계", "프로 커리어 완료", pro.team.name))
            pro != null -> listOf(
                ScreenRow("다음 단계", if (pro.phase == ProCareerPhase.CONTRACT_OFFER) {
                    if (pro.season == 1 && pro.currentStats.games == 0) "지명 완료 · 입단 계약 전" else "프로 선수 · 계약 검토 중"
                } else "프로 입단 완료"),
                ScreenRow("소속", pro.team.name, if (pro.phase == ProCareerPhase.CONTRACT_OFFER) "계약 조건을 확인해 주세요."
                    else if (pro.level == ProLevel.MAJOR) "1군" else "2군 · 1군 진입에 도전합니다."))
            draft?.outcome == HighSchoolDraftOutcome.DRAFTED -> listOf(
                ScreenRow("다음 단계", "지명 완료 · 입단 계약 전", "고교에서 키운 능력과 구종으로 이어갑니다."),
                ScreenRow("지명 구단", draft.team?.name ?: "지명 구단", listOfNotNull(
                    draft.round?.let { "${it}라운드" }, draft.overallPick?.let { "전체 ${it}순위" }).joinToString(" · ")))
            draft?.outcome == HighSchoolDraftOutcome.UNDRAFTED -> listOf(
                ScreenRow("다음 단계", "이번 드래프트 미지명", "이번 생의 기록과 이어받을 힘을 남겨요."))
            else -> listOf(ScreenRow("다음 단계", "드래프트 발표 전"))
        }
        return ScreenSection("professional-status", "다음 마운드", rows)
    }

    public fun season(state: GameAggregateState): ProSeasonSurface? {
        val pro = state.pro ?: return null
        val stats = pro.careerStats + listOf(pro.currentStats).filter { current -> pro.careerStats.none { it.season == current.season } }
        val settlement = pro.journeyState?.lastSettlement
        val current = pro.careerStats.lastOrNull { it.season == settlement?.season } ?: pro.currentStats
        return ProSeasonSurface(
            seasonCount = stats.size,
            totalGames = stats.sumOf { it.games },
            totalStrikeouts = stats.sumOf { it.strikeouts },
            games = current.games,
            inningsOuts = current.inningsOuts,
            strikeouts = current.strikeouts,
            awards = pro.awards,
            pendingTitle = pro.pendingDecision?.title,
            pendingDetail = pro.pendingDecision?.detail,
            weekLines = pro.currentGameLines.map {
                ProWeekGameLine(it.week, it.outs, it.strikeouts, it.runsAllowed, it.walks, it.hits, it.perfectReleases, it.teamRuns, it.opponentRuns)
            },
        )
    }
}

public data class ProWeekGameLine(
    val week: Int,
    val outs: Int,
    val strikeouts: Int,
    val runs: Int,
    val walks: Int,
    val hits: Int,
    val perfectReleases: Int,
    val teamRuns: Int,
    val opponentRuns: Int,
)

public data class ProSeasonSurface(
    val seasonCount: Int,
    val totalGames: Int,
    val totalStrikeouts: Int,
    val games: Int,
    val inningsOuts: Int,
    val strikeouts: Int,
    val awards: List<String>,
    val pendingTitle: String?,
    val pendingDetail: String?,
    val weekLines: List<ProWeekGameLine>,
)
