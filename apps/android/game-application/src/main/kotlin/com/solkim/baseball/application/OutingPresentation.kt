package com.solkim.baseball.application

import com.solkim.baseball.core.pitch.*

public object OutingPresentation {
    public fun assignment(state: GameAggregateState): OutingAssignment? = state.pro?.activePitch?.assignment ?: state.highSchool?.activePitch?.assignment
    public fun roleLabel(role: OutingRole): String = when (role) { OutingRole.STARTER -> "선발 등판"; OutingRole.RELIEF -> "중간계투 등판"; OutingRole.CLOSER -> "마무리 등판" }
    public fun title(state: GameAggregateState): String? = assignment(state)?.let { if (it.goal == OutingGoal.STARTER_TEST) "선발 테스트" else if (it.role == OutingRole.STARTER && it.entryInning > 1) "선발 · ${it.entryInning}회부터 직접" else roleLabel(it.role) }
    public fun goal(assignment: OutingAssignment): String = when (assignment.goal) {
        OutingGoal.STARTER_TEST -> "직접 2이닝 · 2실점 이하"
        OutingGoal.HOLD_LEAD -> "리드를 지켜 이닝 마무리"
        OutingGoal.CLEAN_FRAME -> if (assignment.role == OutingRole.STARTER && assignment.entryInning == 1) "첫 이닝 무실점으로 출발" else "추가 실점 없이 이닝 마무리"
    }
    public fun progress(state: GameAggregateState): String? {
        val goal = assignment(state) ?: return null
        val outs = state.pro?.activePitch?.outs ?: state.highSchool?.activePitch?.outs ?: 0
        return when (goal.status) {
            OutingGoalStatus.ACHIEVED -> if (goal.goal == OutingGoal.STARTER_TEST) "테스트 통과 · 선발 기회 확보" else if (goal.trustReward > 0) "목표 달성 · 감독 신뢰 +${goal.trustReward}" else "목표 달성"
            OutingGoalStatus.FAILED -> "목표는 놓쳤지만, 남은 아웃을 잡아보세요."
            OutingGoalStatus.UNFINISHED -> "다음 기회를 준비해요."
            OutingGoalStatus.PENDING -> "${outs.coerceAtMost(goal.targetOuts)}/${goal.targetOuts} 아웃"
        }
    }
}
