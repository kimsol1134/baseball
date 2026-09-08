package com.solkim.baseball.application

import com.solkim.baseball.core.pitch.*
import com.solkim.baseball.core.highschool.*
import com.solkim.baseball.core.pro.*

public data class OutingBriefing(val title: String, val situation: String, val score: String, val goal: String, val reward: String, val story: String,
    val inning: Int, val outs: Int, val bases: List<Int>, val lead: Int, val starterTrial: Boolean, val rewardTrust: Int) {
    public fun localized(copy: GameCopy): OutingBriefing {
        val runners = if (bases.isEmpty()) copy.resolve("improve.outing.empty-bases") else copy.resolve("improve.outing.bases", GameCopyArgument.UserText(bases.joinToString("·")))
        return this.copy(title = copy.legacy(title), goal = copy.legacy(goal), story = copy.legacy(story),
            score = if (lead == 0) copy.resolve("improve.outing.tied") else copy.resolve(if (lead > 0) "improve.outing.lead" else "improve.outing.trail", GameCopyArgument.Whole(kotlin.math.abs(lead).toLong())),
            situation = copy.resolve("improve.outing.situation", GameCopyArgument.Whole(inning.toLong()), GameCopyArgument.Whole(outs.toLong()), GameCopyArgument.UserText(runners)),
            reward = listOfNotNull(copy.resolve("improve.outing.chance").takeIf { starterTrial },
                copy.resolve("improve.outing.reward", GameCopyArgument.Whole(rewardTrust.toLong())).takeIf { rewardTrust > 0 }).joinToString(" · "))
    }
}

public object OutingPresentation {
    public fun briefing(state: GameAggregateState, context: Phase8CommandContext = Phase8CommandContext()): OutingBriefing? {
        val pro = state.pro?.takeIf { state.stage == GameStage.PRO && it.phase == ProCareerPhase.IMPORTANT_GAME }
        val hs = state.highSchool?.takeIf { it.run.phase == HighSchoolPhase.IMPORTANT_GAME }
        val preview = when {
            pro != null -> state.copy(pitch = null, pro = if (pro.activePitch == null) ProKernel().reserveImportantGame(pro, context.seed(state, "pro-important-game")).state else pro)
            hs != null -> state.copy(pitch = null, highSchool = if (hs.activePitch == null) HighSchoolPhase4Kernel().reserveImportantGame(context.seed(state, "important-game"), hs).state else hs)
            else -> return null
        }
        val assignment = assignment(preview)
        val board = PitchScoreboardProjection.model(preview)
        val trust = if (pro != null) pro.managerTrust else hs?.run?.managerTrust ?: 100
        val trial = assignment?.goal == OutingGoal.STARTER_TEST
        val reward = minOf(if (trial) 8 else 2, (100 - trust).coerceAtLeast(0))
        return OutingBriefing(title(preview) ?: "등판 상황", "${board.inningText} · ${board.outs}사 · ${PitchScoreboardProjection.situationLine(board.outs, board.runners).substringAfter(' ')}",
            board.scoreText, assignment?.let(::goal) ?: "이번 이닝에 집중해요.",
            listOfNotNull("선발 기회".takeIf { trial }, "감독 신뢰 +$reward".takeIf { assignment != null && reward > 0 }).joinToString(" · "),
            if (pro != null) ProKernel().importantHeadline(pro.seasonTrigger ?: ProSeasonTrigger.STANDINGS_RACE, pro.currentRival, pro.level)
            else preview.highSchool?.run?.currentGameScenario?.narrative.orEmpty(), board.inning, board.outs,
            listOfNotNull(1.takeIf { board.runners.firstOccupied }, 2.takeIf { board.runners.secondOccupied }, 3.takeIf { board.runners.thirdOccupied }), board.scoreDiff, trial, if (assignment != null) reward else 0)
    }
    public fun isStarterTrial(state: GameAggregateState): Boolean = assignment(state)?.goal == OutingGoal.STARTER_TEST
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
