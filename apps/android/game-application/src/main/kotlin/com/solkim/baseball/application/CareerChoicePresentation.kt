package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.*

public data class AwakeningChoiceView(val id: String, val title: String, val branch: String, val tier: Int,
    val owned: Boolean, val available: Boolean, val leap: Boolean, val requirement: String, val effect: String, val voice: String = "")

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
            val feel = awakeningFeel(node.id)
            AwakeningChoiceView(node.id.wire, HighSchoolDisplayRules.awakeningTitle(node.id.wire),
                when(node.branch) { "power" -> "힘"; "command" -> "제구"; "breaking" -> "변화"; else -> "수싸움" }, node.tier,
                owned, open && run.phase == HighSchoolPhase.AWAKENING && node.id in run.awakeningOptions,
                open && missing.isNotEmpty(), missing.joinToString(" · ") { HighSchoolDisplayRules.awakeningTitle(it.wire) },
                listOf(feel, effects.joinToString(" · ")).filter { it.isNotBlank() }.joinToString("\n"), awakeningVoice(node.id))
        }
    }

    /** What the awakening does to the ball in the player's hand. Mirrors HighSchoolKernel.applyAwakening. */
    public fun awakeningFeel(id: HighSchoolAwakening): String = when (id) {
        HighSchoolAwakening.EXPLOSIVE_FASTBALL -> "포심 +1.5km/h · 헛스윙 ↑ · 팔은 조금 더 무겁다"
        HighSchoolAwakening.RISING_FOUR_SEAM -> "포심 변화량 ↑ · 헛스윙 ↑ · 빗맞은 타구 ↑"
        HighSchoolAwakening.PINPOINT_EDGE -> "존 구석이 손에 붙는다 · 초록 구간 ↑"
        HighSchoolAwakening.BATTERY_SYNC -> "포수 사인이 더 잘 맞는다 · 빗맞은 타구 ↑"
        HighSchoolAwakening.REPEATABLE_RELEASE -> "릴리스가 매번 같아진다 · 초록 구간 ↑"
        HighSchoolAwakening.FIRST_PITCH_STRIKE -> "초구 스트라이크가 늘어난다"
        HighSchoolAwakening.DISAPPEARING_BREAKER -> "변화구 끝이 사라진다 · 헛스윙 ↑"
        HighSchoolAwakening.SINKER_TUNNEL -> "포심·체인지업 변화량 ↑ · 빗맞은 타구 ↑"
        HighSchoolAwakening.FROZEN_CHANGEUP -> "체인지업 앞에서 타자가 멈춘다 · 헛스윙 ↑↑"
        HighSchoolAwakening.SWEEPING_SLIDER -> "슬라이더가 한 뼘 더 휜다 · 헛스윙 ↑"
        HighSchoolAwakening.CURVEBALL_CLOCK -> "커브가 더 크게 떨어진다 · 헛스윙 ↑"
        HighSchoolAwakening.IRON_ARM -> "피로가 덜 쌓인다 · 후반에도 같은 공"
        HighSchoolAwakening.LATE_INNING_RESERVE -> "후반 포심이 살아 있다 · 피로 ↓"
        HighSchoolAwakening.CALM_UNDER_PRESSURE -> "위기에서 미터가 덜 흔들린다"
        HighSchoolAwakening.PICKOFF_RHYTHM -> "일정한 투구 리듬 · 제구·체력 ↑"
        HighSchoolAwakening.TWO_STRIKE_PLAN -> "2스트라이크 변화구 헛스윙 ↑"
        HighSchoolAwakening.TRAFFIC_CONTROLLER -> "위기에서 미터 흔들림 ↓ · 빗맞은 타구 ↑"
        HighSchoolAwakening.SCOUT_COMPOSURE -> "압박 속 미터 흔들림 ↓ · 구위·제구 ↑"
    }

    /** One line in the catcher's voice for the confirmation moment. */
    public fun awakeningVoice(id: HighSchoolAwakening): String = when (id) {
        HighSchoolAwakening.EXPLOSIVE_FASTBALL -> "포수: 방금 그 공, 미트가 울렸어. 그거 그대로 가자."
        HighSchoolAwakening.RISING_FOUR_SEAM -> "포수: 높은 포심이 떠. 타자 눈에는 더 높게 보일 거야."
        HighSchoolAwakening.PINPOINT_EDGE -> "포수: 구석에 세운 미트, 안 움직여도 되겠다."
        HighSchoolAwakening.BATTERY_SYNC -> "포수: 사인 내기 전에 네가 먼저 고개를 끄덕이더라."
        HighSchoolAwakening.REPEATABLE_RELEASE -> "포수: 열 개 던지면 열 개가 같은 팔이야."
        HighSchoolAwakening.FIRST_PITCH_STRIKE -> "포수: 초구부터 카운트 잡고 가자. 그게 제일 편해."
        HighSchoolAwakening.DISAPPEARING_BREAKER -> "포수: 마지막에 공이 없어져. 나도 잡기 힘들 정도로."
        HighSchoolAwakening.SINKER_TUNNEL -> "포수: 포심과 체인지업이 함께 좋아졌어. 두 공으로 타이밍을 바꾸자."
        HighSchoolAwakening.FROZEN_CHANGEUP -> "포수: 타자가 얼었어. 그 체인지업, 결정구다."
        HighSchoolAwakening.SWEEPING_SLIDER -> "포수: 슬라이더가 내 미트 밖까지 휜다. 앉는 자리를 바꿔야겠어."
        HighSchoolAwakening.CURVEBALL_CLOCK -> "포수: 커브 떨어지는 타이밍이 시계 같아."
        HighSchoolAwakening.IRON_ARM -> "코치: 7회에 던진 공이 1회 공이랑 똑같다. 어깨가 다르네."
        HighSchoolAwakening.LATE_INNING_RESERVE -> "코치: 후반에 힘이 남는 투수는 감독이 제일 좋아한다."
        HighSchoolAwakening.CALM_UNDER_PRESSURE -> "포수: 만루에서 네 눈이 안 흔들리더라."
        HighSchoolAwakening.PICKOFF_RHYTHM -> "포수: 공마다 리듬이 일정해졌어. 받기도 한결 편하다."
        HighSchoolAwakening.TWO_STRIKE_PLAN -> "포수: 2스트라이크면 이제 내가 뭘 낼지 너도 알지."
        HighSchoolAwakening.TRAFFIC_CONTROLLER -> "코치: 주자 있을 때 더 침착하다. 그게 에이스야."
        HighSchoolAwakening.SCOUT_COMPOSURE -> "코치: 압박이 커져도 투구가 흔들리지 않더라. 그 침착함을 기억해."
    }

    public fun conclusion(run: HighSchoolState): List<Phase8Section> {
        val draft = run.draftResult ?: return emptyList()
        val assessment = HighSchoolKernel().draftAssessment(run)
        val gap = draft.evaluationScore - assessment.second
        val ratings = listOf("구위" to run.pitcher.stuff, "제구" to run.pitcher.command, "무브먼트" to run.pitcher.movement, "체력" to run.pitcher.stamina)
        val strongest = ratings.maxBy { it.second }.first
        val weakest = ratings.minBy { it.second }.first
        val advice = when {
            run.armRisk >= 45 -> "다음 생에는 팔이 지치기 전에 쉬자. 무리한 등판은 스카우트도 본다."
            run.performance.walks > run.performance.strikeouts / 2 -> "다음 생에는 제구부터. 볼넷이 줄면 승부가 편해진다."
            weakest == "구위" -> "다음 생에는 공에 힘을 더 싣자. 스카우트는 구속부터 본다."
            weakest == "제구" -> "다음 생에는 코스를 잡자. 초록 구간이 넓어지면 승부가 달라진다."
            weakest == "무브먼트" -> "다음 생에는 변화구 하나를 완성하자. 결정구가 있어야 삼진이 는다."
            else -> "다음 생에는 체력을 쌓자. 긴 이닝을 버텨야 평가가 쌓인다."
        }
        val verdict = if (gap >= 0) "기준보다 ${gap}점 위. 이름이 불렸다." else "${-gap}점이 모자랐다."
        return listOf(
            Phase8Section("draft-reasons", "스카우트의 계산", listOf(
                Phase8Row("지명 기준 ${assessment.second}점", verdict, assessment.third.joinToString(" · ")),
                Phase8Row("다음 생의 준비", advice),
            )),
            Phase8Section("life-story", "이번 생에 남긴 것", listOf(
                Phase8Row("나의 강점", strongest, "가장 높이 키운 능력이에요."),
                Phase8Row("쌓아 온 훈련", "${run.totalTrainingsCompleted}회", "한 번씩 쌓은 훈련이 지금의 선수를 만들었어요."),
                Phase8Row("마운드의 기록", "${run.performance.strikeouts}삼진 · ${run.performance.walks}볼넷", "직접 치른 승부처의 기록이에요."),
                Phase8Row("나만의 각성", run.selectedAwakenings.joinToString(" · ") { HighSchoolDisplayRules.awakeningTitle(it.wire) }.ifBlank { "아직 없음" }),
            )),
        )
    }
}
