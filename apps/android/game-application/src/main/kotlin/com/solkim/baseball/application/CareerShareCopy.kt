package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.HighSchoolDraftOutcome
import com.solkim.baseball.core.pro.ProNationalTeamRules
import com.solkim.baseball.core.pro.careerGames
import com.solkim.baseball.core.pro.careerStrikeouts

/** Player-facing share text for draft, retirement, national-team, and records moments. */
public object CareerShareCopy {
    public const val LIFE_CARD_TITLE: String = "나의 야구 인생"
    public fun challenge(state: GameAggregateState): String? {
        val session = state.meta.seedChallenge ?: return null
        val run = state.highSchool?.run ?: return null
        return listOfNotNull("도전 코드 ${session.code.token}", run.draftResult?.let { "평가 ${it.evaluationScore}" },
            "${run.performance.pitches}구 · ${run.performance.strikeouts}탈삼진").joinToString("\n")
    }
    public fun draft(state: GameAggregateState): String? {
        val run = state.highSchool?.run ?: return null
        val result = run.draftResult ?: return null
        val name = run.identity.name.ifBlank { "투수" }
        val outcome = when (result.outcome) {
            HighSchoolDraftOutcome.DRAFTED -> "지명됨"
            HighSchoolDraftOutcome.UNDRAFTED -> "지명되지 않음"
        }
        return buildString {
            append(name)
            append(" · ")
            append(outcome)
            append(" · 평가 ${result.evaluationScore}")
            if (result.summary.isNotBlank()) append('\n').append(result.summary)
        }
    }

    public fun retirement(state: GameAggregateState): String? {
        val pro = state.pro ?: return null
        if (pro.phase != com.solkim.baseball.core.pro.ProCareerPhase.RETIREMENT_DECISION &&
            pro.phase != com.solkim.baseball.core.pro.ProCareerPhase.LEGACY_SELECTION &&
            pro.phase != com.solkim.baseball.core.pro.ProCareerPhase.COMPLETED
        ) {
            return null
        }
        return buildString {
            append(pro.identityName)
            append(" · ")
            append("${pro.careerStats.size}시즌")
            append(" · ")
            append("${pro.careerGames()}경기")
            append(" · ")
            append("${pro.careerStrikeouts()}탈삼진")
            pro.hallOfFameScore?.let { append(if (it >= 70) " · 명예의 전당 헌액" else " · 명예의 전당까지 ${70 - it}점") }
        }
    }

    public fun nationalMedal(state: GameAggregateState): String? {
        val tournament = state.pro?.nationalTournament ?: return null
        val outcome = tournament.result ?: return null
        return buildString {
            append("환태평양 초청 대회")
            append(" · ")
            append(ProNationalTeamRules.resultLabel(outcome))
            append('\n')
            append(ProNationalTeamRules.news(outcome))
            if (tournament.exempted) append("\n병역 면제")
        }
    }

    public fun records(state: GameAggregateState): String {
        challenge(state)?.let { return it }
        val run = state.highSchool?.run
        val pro = state.pro
        val lines = buildList {
            run?.identity?.name?.takeIf { it.isNotBlank() }?.let { add(it) }
            if (run != null) {
                add("고교 ${run.performance.pitches}구 · ${run.performance.strikeouts}탈삼진")
            }
            if (pro != null) {
                add("프로 ${pro.careerGames()}경기 · ${pro.careerStrikeouts()}탈삼진 · ${pro.careerStats.size}시즌")
            }
            state.highSchool?.archive?.size?.takeIf { it > 0 }?.let { add("보관한 생 ${it}회") }
        }
        return lines.joinToString("\n").ifBlank { "아직 남길 기록이 없습니다." }
    }
}
