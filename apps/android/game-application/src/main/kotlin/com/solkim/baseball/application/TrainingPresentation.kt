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
        TrainingFocus.VELOCITY -> "구위와 구속을 키워요. 강하게 훈련하면 팔에 부담이 커져요."
        TrainingFocus.COMMAND -> "원하는 코스로 던지는 능력을 키워요. 피로 부담이 비교적 적어요."
        TrainingFocus.BREAKING_BALL -> "연습할 구종을 골라 공의 움직임과 헛스윙을 유도하는 능력을 키워요."
        TrainingFocus.STAMINA -> "오래 던질 수 있도록 체력을 키워요."
        TrainingFocus.RECOVERY -> "능력 성장 대신 피로를 줄여요. 재활 중이라면 팔도 회복돼요."
        TrainingFocus.GAME_PLANNING -> "타자 공략을 연습하며 제구를 키워요."
    }
    public fun intensityTitle(value: TrainingIntensity, focus: TrainingFocus): String =
        if (focus == TrainingFocus.RECOVERY) when (value) {
            TrainingIntensity.LIGHT -> "푹 쉬기"
            TrainingIntensity.STANDARD -> "가볍게 몸 풀기"
            TrainingIntensity.INTENSIVE -> "쉬면서도 던지기"
        } else when (value) {
            TrainingIntensity.LIGHT -> "가볍게"
            TrainingIntensity.STANDARD -> "보통"
            TrainingIntensity.INTENSIVE -> "몰아붙이기"
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
        return listOf("훈련 ${evidence.size.coerceAtLeast(1)}회 완료") +
            (gains.ifEmpty { listOf(if (last.focus == TrainingFocus.RECOVERY) "휴식 완료" else "${metric(last.focus)} +${last.growth}") }) +
            listOf("피로 ${if (fatigue >= 0) "+" else ""}$fatigue") +
            listOfNotNull("재능의 한계를 넘었어요!".takeIf { last.bloomed },
                last.masteryAfter?.let { "숙련 +${it - (last.masteryBefore ?: it)}" })
    }
}
