package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.*

public data class AwakeningChoiceView(val id: String, val title: String, val branch: String, val tier: Int,
    val owned: Boolean, val available: Boolean, val leap: Boolean, val requirement: String, val effect: String)

public object CareerChoicePresentation {
    public fun awakeningTree(state: GameAggregateState): List<AwakeningChoiceView> {
        val run = state.highSchool?.run ?: return emptyList()
        val kernel = HighSchoolKernel()
        val available = kernel.availableAwakenings(run).toSet()
        return HighSchoolContentCatalog.awakeningNodes.map { node ->
            val owned = node.id in run.selectedAwakenings
            val open = node.id in available
            val missing = node.parents.filterNot { it in run.selectedAwakenings }
            val after = kernel.previewAwakening(run.pitcher, node.id)
            val beforeRatings = listOf(run.pitcher.stuff, run.pitcher.command, run.pitcher.movement, run.pitcher.stamina)
            val afterRatings = listOf(after.stuff, after.command, after.movement, after.stamina)
            val labels = listOf("구위", "제구", "무브먼트", "체력")
            val effects = labels.indices.filter { beforeRatings[it] != afterRatings[it] }.map {
                "${labels[it]} ${AbilityDisplayScale.rating(beforeRatings[it])} → ${AbilityDisplayScale.rating(afterRatings[it])}"
            }
            AwakeningChoiceView(node.id.wire, HighSchoolDisplayRules.awakeningTitle(node.id.wire),
                when(node.branch) { "power" -> "힘"; "command" -> "제구"; "breaking" -> "변화"; else -> "수싸움" }, node.tier,
                owned, open && run.phase == HighSchoolPhase.AWAKENING && node.id in run.awakeningOptions,
                open && missing.isNotEmpty(), missing.joinToString(" · ") { HighSchoolDisplayRules.awakeningTitle(it.wire) },
                effects.joinToString(" · ").ifEmpty { "구종의 움직임과 제구가 달라져요." })
        }
    }

    public fun conclusion(run: HighSchoolState): List<Phase8Section> {
        val draft = run.draftResult ?: return emptyList()
        val assessment = HighSchoolKernel().draftAssessment(run)
        val gap = draft.evaluationScore - assessment.second
        val ratings = listOf("구위" to run.pitcher.stuff, "제구" to run.pitcher.command, "무브먼트" to run.pitcher.movement, "체력" to run.pitcher.stamina)
        val strongest = ratings.maxBy { it.second }.first
        val weakest = ratings.minBy { it.second }.first
        val advice = when {
            run.armRisk >= 45 -> "다음 생에는 팔이 지치기 전에 쉬어 주세요. 무리한 등판도 평가에 남아요."
            run.performance.walks > run.performance.strikeouts / 2 -> "다음 생에는 제구를 먼저 키워 보세요. 볼넷을 줄이면 승부가 편해져요."
            else -> "다음 생에는 $weakest 훈련을 보완해 보세요."
        }
        return listOf(
            Phase8Section("draft-reasons", "이 평가를 받은 이유", listOf(
                Phase8Row("지명 기준", "${assessment.second}점", if (gap >= 0) "기준보다 ${gap}점 높았어요." else "지명까지 ${-gap}점 모자랐어요."),
            ) + assessment.third.map { Phase8Row("평가 근거", it) } + listOf(Phase8Row("다음 생의 준비", advice))),
            Phase8Section("life-story", "이번 생에 남긴 것", listOf(
                Phase8Row("나의 강점", strongest, "가장 높이 키운 능력이에요."),
                Phase8Row("쌓아 온 훈련", "${run.totalTrainingsCompleted}회", "한 번씩 쌓은 훈련이 지금의 선수를 만들었어요."),
                Phase8Row("마운드의 기록", "${run.performance.strikeouts}삼진 · ${run.performance.walks}볼넷", "직접 치른 승부처의 기록이에요."),
                Phase8Row("나만의 각성", run.selectedAwakenings.joinToString(" · ") { HighSchoolDisplayRules.awakeningTitle(it.wire) }.ifBlank { "아직 없음" }),
            )),
        )
    }
}
