package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.*
import com.solkim.baseball.core.pitch.PitchKind
import com.solkim.baseball.core.pitch.PitchUsageRole

public typealias TrainingFocus = HighSchoolTrainingFocus
public typealias TrainingIntensity = HighSchoolTrainingIntensity
public typealias TrainingPreview = HighSchoolTrainingPreview

/** Training display and command creation share the authoritative rules; UI never rolls a result. */
public object TrainingPresentation {
    public fun title(focus: TrainingFocus): String = when (focus) {
        TrainingFocus.VELOCITY -> "구위 훈련"
        TrainingFocus.COMMAND -> "제구 훈련"
        TrainingFocus.BREAKING_BALL -> "변화구 훈련"
        TrainingFocus.STAMINA -> "체력 훈련"
        TrainingFocus.RECOVERY -> "휴식과 회복"
        TrainingFocus.GAME_PLANNING -> "경기 운영 훈련"
    }
    public fun metric(focus: TrainingFocus): String = when (focus) {
        TrainingFocus.VELOCITY -> "구위"
        TrainingFocus.COMMAND, TrainingFocus.GAME_PLANNING -> "제구"
        TrainingFocus.BREAKING_BALL -> "무브먼트"
        TrainingFocus.STAMINA -> "체력"
        TrainingFocus.RECOVERY -> "회복"
    }
    public fun detail(focus: TrainingFocus): String = when (focus) {
        TrainingFocus.VELOCITY -> "공에 힘을 싣는다. 세게 던질수록 팔이 무거워진다."
        TrainingFocus.COMMAND -> "원하는 코스에 꽂는 감각. 다음 공의 초록 구간이 넓어진다."
        TrainingFocus.BREAKING_BALL -> "구종 하나를 골라 공 끝을 더 흔든다. 헛스윙이 늘어난다."
        TrainingFocus.STAMINA -> "긴 이닝을 버티는 몸을 만든다."
        TrainingFocus.RECOVERY -> "성장 대신 피로를 던다. 재활 중이면 팔도 돌아온다."
        TrainingFocus.GAME_PLANNING -> "어떤 공을 어떤 순서로 던질지 연습해요. 제구도 함께 늘어요."
    }
    public fun intensityTitle(value: TrainingIntensity, focus: TrainingFocus): String =
        if (focus == TrainingFocus.RECOVERY) when (value) {
            TrainingIntensity.LIGHT -> "푹 쉬기"
            TrainingIntensity.STANDARD -> "몸 풀기"
            TrainingIntensity.INTENSIVE -> "투구 병행"
        } else when (value) {
            TrainingIntensity.LIGHT -> "가볍게"
            TrainingIntensity.STANDARD -> "보통"
            TrainingIntensity.INTENSIVE -> "강하게"
        }
    public fun recommended(state: GameAggregateState): TrainingFocus {
        val run = requireNotNull(state.highSchool).run
        if (run.injuryRecovery > 0 || run.fatigue >= 70 || run.armRisk >= 55) return TrainingFocus.RECOVERY
        return run.trainingOpportunity?.focus ?: run.lastTraining?.focus ?: TrainingFocus.COMMAND
    }
    public fun initialIntensity(state: GameAggregateState): TrainingIntensity {
        val run = requireNotNull(state.highSchool).run
        return when {
            run.injuryRecovery > 0 || run.fatigue >= 70 -> TrainingIntensity.LIGHT
            run.lastTraining != null -> requireNotNull(run.lastTraining).intensity
            else -> TrainingIntensity.STANDARD
        }
    }
    public fun initialFocus(state: GameAggregateState): TrainingFocus {
        val run = requireNotNull(state.highSchool).run
        return if (run.fatigue >= 70 || run.armRisk >= 55 || run.injuryRecovery > 0) TrainingFocus.RECOVERY
            else run.lastTraining?.focus ?: recommended(state)
    }
    public fun targets(state: GameAggregateState): List<PitchKind> = state.highSchool?.run?.pitcher?.pitchProfiles.orEmpty()
        .map { it.pitchType }.filter { it != PitchKind.FOUR_SEAM }.distinct()
    public fun initialTarget(state: GameAggregateState): PitchKind? =
        state.highSchool?.trainingEvidence?.lastOrNull()?.targetPitch?.takeIf { it in targets(state) }
            ?: state.highSchool?.run?.pitcher?.pitchProfiles?.firstOrNull { it.role == PitchUsageRole.DEVELOPMENT }?.pitchType
            ?: targets(state).firstOrNull()
    public fun pitchLabel(pitch: PitchKind): String = when (pitch) {
        PitchKind.FOUR_SEAM -> "포심"; PitchKind.SLIDER -> "슬라이더"; PitchKind.CURVEBALL -> "커브"; PitchKind.CHANGEUP -> "체인지업"
    }
    public fun learningLines(state: GameAggregateState): List<String> {
        val project = state.highSchool?.run?.pitchLearningProject ?: return emptyList()
        return learningLines(project)
    }
    public fun learningLines(project: com.solkim.baseball.core.pitch.PitchLearningProject): List<String> = listOf(
        "${pitchLabel(project.pitchType)} · ${when(project.stage) { "grip" -> "그립 익히기"; "bullpen" -> "불펜 연습"; "live_trial" -> "실전 적응"; else -> "습득 완료" }}",
        "연습 ${project.practiceCredits}/9 · 실전 감각 ${project.qualityUses}/2",
        when { project.completed -> "이제 자신 있게 던질 수 있는 구종이 됐어요."; !project.gameReady -> "연습 5부터 경기에서 던질 수 있어요."; else -> "연습 7과 좋은 실전 투구 2회, 또는 연습 9를 채우면 완성돼요." },
    )
    public fun targetStatus(state: GameAggregateState, target: PitchKind): String = state.highSchool?.run?.pitchLearningProject?.takeIf { it.pitchType == target }?.let {
        when { it.completed -> "습득 완료"; it.gameReady -> "실전 적응"; else -> "연습 중" }
    } ?: when (state.highSchool?.run?.pitcher?.pitchProfiles?.firstOrNull { it.pitchType == target }?.role) {
        PitchUsageRole.PRIMARY -> "주 구종"
        PitchUsageRole.SECONDARY -> "실전 구종"
        PitchUsageRole.DEVELOPMENT -> "연습 중"
        null -> ""
    }
    public fun preview(state: GameAggregateState, focus: TrainingFocus, intensity: TrainingIntensity): TrainingPreview =
        HighSchoolKernel().trainingPreview(requireNotNull(state.highSchool).run, focus, intensity)
    public fun displayGrowth(state: GameAggregateState, focus: TrainingFocus, growth: Int): Int {
        val p = state.highSchool?.run?.pitcher ?: return 0
        val before = when(focus) { TrainingFocus.VELOCITY -> p.stuff; TrainingFocus.COMMAND, TrainingFocus.GAME_PLANNING -> p.command; TrainingFocus.BREAKING_BALL -> p.movement; else -> p.stamina }
        return AbilityDisplayScale.delta(before, before + growth)
    }
    public fun growthOutlook(state: GameAggregateState, focus: TrainingFocus, preview: TrainingPreview, copy: GameCopy): String {
        val minimum = displayGrowth(state, focus, preview.minimumGrowth)
        val maximum = displayGrowth(state, focus, preview.maximumGrowth)
        if (preview.masteryTraining) return copy.resolve("growth.path.mastery")
        if (preview.breakthroughTarget > 0) return copy.resolve("growth.path.breakthrough",
            GameCopyArgument.Whole(preview.breakthroughProgress.toLong()), GameCopyArgument.Whole(preview.breakthroughTarget.toLong()))
        if (maximum == 0 && preview.practiceStep > 0) return copy.resolve("growth.path.progress",
            GameCopyArgument.UserText(copy.legacy(metric(focus))), GameCopyArgument.Whole(preview.experience.toLong()),
            GameCopyArgument.Whole(minOf(100, preview.experience + preview.practiceStep).toLong()))
        if (maximum == 0) return copy.resolve("training.clear.no-growth")
        val ability = GameCopyArgument.UserText(copy.legacy(metric(focus)))
        return if (minimum == maximum) copy.resolve("training.clear.fixed", ability, GameCopyArgument.Whole(maximum.toLong()))
        else copy.resolve("training.clear.range", ability, GameCopyArgument.Whole(minimum.toLong()), GameCopyArgument.Whole(maximum.toLong()))
    }

    /** Total growth on a great training result, not an extra amount added to the base label. */
    public fun jackpotOutlook(state: GameAggregateState, focus: TrainingFocus, preview: TrainingPreview, copy: GameCopy): String? {
        if (preview.jackpotChancePercent <= 0 || preview.atTalentWall || preview.rehabilitation || focus == TrainingFocus.RECOVERY) return null
        val minimum = displayGrowth(state, focus, preview.jackpotMinimumGrowth)
        val maximum = displayGrowth(state, focus, preview.jackpotMaximumGrowth)
        if (maximum <= displayGrowth(state, focus, preview.minimumGrowth)) return null
        val chance = GameCopyArgument.Whole(preview.jackpotChancePercent.toLong())
        val ability = GameCopyArgument.UserText(copy.legacy(metric(focus)))
        return if (minimum == maximum) copy.resolve("training.intensity.jackpot-fixed", chance, ability, GameCopyArgument.Whole(maximum.toLong()))
        else copy.resolve("training.intensity.jackpot-range", chance, ability, GameCopyArgument.Whole(minimum.toLong()), GameCopyArgument.Whole(maximum.toLong()))
    }

    public fun payloads(state: GameAggregateState, context: Phase8CommandContext, focus: TrainingFocus,
                        intensity: TrainingIntensity, target: PitchKind?, repeat: Boolean): List<Phase8CommandPayload> {
        val run = requireNotNull(state.highSchool).run
        require(run.phase == HighSchoolPhase.TRAINING) { "training.phase" }
        val effective = if (run.injuryRecovery > 0) TrainingFocus.RECOVERY else focus
        val pitch = target.takeIf { effective == TrainingFocus.BREAKING_BALL }
        require(effective != TrainingFocus.BREAKING_BALL || (pitch == null && targets(state).isEmpty()) || pitch in targets(state)) { "training.target" }
        val seed = context.seed(state, "training:${effective.wire}")
        val command = if (repeat) HighSchoolPhase4Command.TrainingBlock(seed, List(3) { effective to intensity }, pitch, stopForSafety = true)
            else HighSchoolPhase4Command.Training(seed, effective, intensity, pitch)
        return Phase8Payloads.batch(state, Phase8ScreenId.P006_TRAINING, "train:${effective.wire}", listOf(GameCommand.HighSchool(command)))
    }
    /** One line from the coach after training. Speaks to the player; never restates the numbers. */
    public fun coachLine(state: GameAggregateState): String? {
        val run = state.highSchool?.run ?: return null
        val last = run.lastTraining ?: return null
        if (last.bloomed) return "코치: 벽을 넘었다. 이제 다른 투수다."
        return when (last.focus) {
            TrainingFocus.VELOCITY -> if (last.growth > 0) "코치: 공이 무거워졌다. 다음 공에서 느껴 봐." else "코치: 오늘은 몸이 안 따라왔다. 내일 다시."
            TrainingFocus.COMMAND -> if (last.growth > 0) "코치: 코스가 손에 붙었다. 초록이 넓어졌을 거다." else "코치: 아직 손끝이 흔들린다. 반복이 답이다."
            TrainingFocus.BREAKING_BALL -> if (last.growth > 0) "코치: 공 끝이 살아났다. 실전에서 한번 던져 봐." else "코치: 그립부터 다시. 급하게 굴리지 마."
            TrainingFocus.STAMINA -> if (last.growth > 0) "코치: 6회에도 같은 공을 던질 몸이 된다." else "코치: 오늘은 여기까지. 무리하면 팔이 먼저 간다."
            TrainingFocus.RECOVERY -> "코치: 잘 쉬었다. 쉬는 것도 훈련이다."
            TrainingFocus.GAME_PLANNING -> if (last.growth > 0) "코치: 타자가 보이기 시작했지. 다음 승부에서 써먹자." else "코치: 타자를 더 봐. 공만 보면 안 된다."
        }
    }
    public fun fatigueChange(state: GameAggregateState, afterNumber: Int): Int {
        val school = state.highSchool ?: return 0
        val last = school.run.lastTraining ?: return 0
        val from = if (afterNumber in 0 until last.number) afterNumber else last.number - 1
        val evidence = school.trainingEvidence.filter { it.trainingNumber > from }
        return if (evidence.isEmpty()) last.fatigueChange else evidence.sumOf { it.fatigueDelta }
    }
    public fun resultLines(state: GameAggregateState, afterNumber: Int): List<String> {
        val school = state.highSchool ?: return emptyList()
        val last = school.run.lastTraining ?: return emptyList()
        val from = if (afterNumber in 0 until last.number) afterNumber else last.number - 1
        val evidence = school.trainingEvidence.filter { it.trainingNumber > from }
        val gains = evidence.filter { it.focus != TrainingFocus.RECOVERY }.groupBy { metric(it.focus) }.map { (label, items) -> run {
            val p = school.run.pitcher
            val after = when(items.first().focus) { TrainingFocus.VELOCITY -> p.stuff; TrainingFocus.COMMAND, TrainingFocus.GAME_PLANNING -> p.command; TrainingFocus.BREAKING_BALL -> p.movement; else -> p.stamina }
            "$label +${AbilityDisplayScale.delta(after - items.sumOf { it.growthPoints }, after)}"
        } }
        val fatigue = if (evidence.isEmpty()) last.fatigueChange else evidence.sumOf { it.fatigueDelta }
        return listOf("훈련 ${evidence.size.coerceAtLeast(1)}회") +
            (gains.ifEmpty { listOf(if (last.focus == TrainingFocus.RECOVERY) "휴식 완료" else "${metric(last.focus)} +${last.growth}") }) +
            listOf("피로 ${if (fatigue >= 0) "+" else ""}$fatigue") +
            listOfNotNull("재능의 한계를 넘었어요!".takeIf { last.bloomed },
                last.masteryAfter?.let { "숙련 +${it - (last.masteryBefore ?: it)}" })
    }
}
