package com.solkim.baseball.core.pro

import com.solkim.baseball.core.pitch.PitcherSnapshot
import com.solkim.baseball.core.pitch.PitchKind
import com.solkim.baseball.core.pitch.PitchUsageRole

/** Weekly decisions and durable follow-ups. Content and thresholds follow Swift ProCareer. */
public object ProWeeklyDecisionRules {
    public fun lowMasteryPitch(pitcher: PitcherSnapshot): PitchKind? {
        val ranked = pitcher.pitchProfiles.orEmpty().sortedBy { it.command + it.movement + it.whiff }
        return (ranked.firstOrNull { it.role == PitchUsageRole.DEVELOPMENT }
            ?: ranked.firstOrNull { it.role != PitchUsageRole.PRIMARY } ?: ranked.firstOrNull())?.pitchType
    }

    public fun candidates(state: ProState, week: Int, trust: Int): List<ProSeasonDecisionType> {
        val used = state.decisionHistory.filter { it.season == state.season }.map { it.type }.toSet()
        val rotation = state.role == ProRole.STARTER && state.fatigue < 60
        val trial = lowMasteryPitch(state.pitcher) != null
        val farm = trust < 40 || recentRunsWorsened(state, week)
        return buildList {
            addAll(listOf(ProSeasonDecisionType.EXTRA_BULLPEN, ProSeasonDecisionType.CATCHER_GAME_PLAN,
                ProSeasonDecisionType.ROLE_MEETING, ProSeasonDecisionType.RECORD_CHASE,
                ProSeasonDecisionType.RIVAL_ANALYSIS, ProSeasonDecisionType.SEASON_FINALE))
            if (rotation) add(ProSeasonDecisionType.ROTATION_PUSH)
            if (trial) add(ProSeasonDecisionType.NEW_PITCH_TRIAL)
            if (farm) add(ProSeasonDecisionType.FARM_RESET)
            if (state.season >= 2 && !rotation && !trial && !farm) add(ProSeasonDecisionType.VETERAN_MENTOR)
        }.filter { it !in used }
    }

    private fun recentRunsWorsened(state: ProState, week: Int): Boolean {
        val lines = state.currentGameLines.filter { it.season == state.season && it.week <= week }
        val recent = lines.filter { it.week > week - 3 }
        val previous = lines.filter { it.week > week - 6 && it.week <= week - 3 }
        val a = recent.sumOf { it.outs }; val b = previous.sumOf { it.outs }
        return a > 0 && b > 0 && recent.sumOf { it.runsAllowed } * 27_000 / a > previous.sumOf { it.runsAllowed } * 27_000 / b
    }

    public fun title(type: ProSeasonDecisionType): String = when (type) {
        ProSeasonDecisionType.ROTATION_PUSH -> "등판 간격"
        ProSeasonDecisionType.NEW_PITCH_TRIAL -> "신구종 실전"
        ProSeasonDecisionType.FARM_RESET -> "2군 재정비"
        ProSeasonDecisionType.VETERAN_MENTOR -> "베테랑 조언"
        else -> error("pro.weekly.type")
    }

    public fun detail(type: ProSeasonDecisionType): String = when (type) {
        ProSeasonDecisionType.ROTATION_PUSH -> "감독이 묻는다. 3주 동안 등판을 하나 더 맡을 수 있겠냐고. 휴식이 짧아지면 팔이 먼저 안다."
        ProSeasonDecisionType.NEW_PITCH_TRIAL -> "포수가 새 구종을 실전에서 써 보자고 한다. 3주는 제구가 흔들릴 거다."
        ProSeasonDecisionType.FARM_RESET -> "코치가 2군 얘기를 꺼낸다. 3주 쉬면서 부족한 걸 채우고 오라고."
        ProSeasonDecisionType.VETERAN_MENTOR -> "베테랑 선배가 옆에 앉는다. 자기 방식대로 3주만 해 보라고. 느려도 남는 게 있다고."
        else -> error("pro.weekly.type")
    }

    public fun choices(type: ProSeasonDecisionType, state: ProState): List<ProDecisionChoice> {
        fun choice(id: String, title: String, detail: String, effect: ProDecisionEffect) =
            ProDecisionChoice("${type.wire}.$id", title, detail, effect)
        return when (type) {
            ProSeasonDecisionType.ROTATION_PUSH -> listOf(
                choice("accept_short_rest", "짧은 휴식으로 더 던진다", "감독이 나를 더 믿는다. 몸은 더 무거워진다. (믿음 +4 · 피로 +12 · 등판 +1)", ProDecisionEffect(managerTrustDelta = 4, fatigueDelta = 12)),
                choice("keep_normal_rest", "평소 간격을 지킨다", "몸을 지킨다. 감독은 조금 서운해한다. (믿음 -2)", ProDecisionEffect(managerTrustDelta = -2)))
            ProSeasonDecisionType.NEW_PITCH_TRIAL -> listOf(
                choice("live_trial", "실전에서 시험한다", "구종이 빨리 는다. 3주간 제구가 흔들린다. (구종 +2 · 제구 -3, 3주 뒤 회복)", ProDecisionEffect(commandDelta = -3)),
                choice("bullpen_only", "불펜에서만 연습한다", "천천히 익힌다. 실전 제구는 그대로. (구종 +1)", ProDecisionEffect()))
            ProSeasonDecisionType.FARM_RESET -> listOf(
                choice("accept_farm", "2군에서 재정비한다", "3주 동안 등판이 없다. 몸이 가벼워지고 부족한 게 채워진다. (능력 +2 · 피로 -25 · 믿음 -6)", if (state.pitcher.stuff <= state.pitcher.command) ProDecisionEffect(stuffDelta = 2, managerTrustDelta = -6, fatigueDelta = -25) else ProDecisionEffect(commandDelta = 2, managerTrustDelta = -6, fatigueDelta = -25)),
                choice("stay_roster", "현재 자리에서 버틴다", "자리를 지킨다. 감독은 고집이라고 본다. (믿음 -3)", ProDecisionEffect(managerTrustDelta = -3)))
            ProSeasonDecisionType.VETERAN_MENTOR -> listOf(
                choice("take_mentor", "선배의 조언을 따른다", "변화구와 포수 호흡이 남는다. 3주간 훈련은 느려진다. (무브먼트 +1 · 호흡 +5)", ProDecisionEffect(movementDelta = 1, catcherTrustDelta = 5)),
                choice("keep_own_way", "내 방식을 지킨다", "내 훈련대로 간다. 포수는 조금 실망한다. (호흡 -2)", ProDecisionEffect(catcherTrustDelta = -2)))
            else -> error("pro.weekly.type")
        }
    }

    public fun applyingPitchTrial(pitcher: PitcherSnapshot, choiceId: String): PitcherSnapshot {
        val target = lowMasteryPitch(pitcher) ?: return pitcher
        val points = if (choiceId.endsWith(".live_trial")) 2 else 1
        return pitcher.copy(pitchProfiles = pitcher.pitchProfiles?.map {
            if (it.pitchType != target) it else it.copy(control = (it.control + points).coerceAtMost(80),
                command = (it.command + points).coerceAtMost(80), movement = (it.movement + points * 2).coerceAtMost(80), whiff = (it.whiff + points).coerceAtMost(80))
        })
    }

    public fun modifier(pending: ProSeasonDecision, choice: ProDecisionChoice, pitcher: PitcherSnapshot): ProDecisionModifier? {
        val base = ProDecisionModifier(pending.id, pending.type, (pending.week + 3).coerceAtMost(24),
            baselineStuff = pitcher.stuff, baselineCommand = pitcher.command, baselineMovement = pitcher.movement,
            baselineStamina = pitcher.stamina, choiceId = choice.id)
        return when {
            choice.id.endsWith(".accept_short_rest") -> base.copy(extraOutingChance = 1, injuryPressureFloor = 80)
            choice.id.endsWith(".live_trial") -> base.copy(commandDelta = choice.effect.commandDelta, targetPitch = lowMasteryPitch(pitcher))
            choice.id.endsWith(".accept_farm") -> base.copy(suppressOutings = true)
            choice.id.endsWith(".take_mentor") -> base.copy(trainingEfficiencyPermille = 800)
            else -> null
        }
    }

    public fun followUp(modifier: ProDecisionModifier, pitcher: PitcherSnapshot, season: Int, week: Int, restored: Int?): ProDecisionFollowUp =
        ProDecisionFollowUp(modifier.decisionId, modifier.type, season, week, "content.pro-decision.followup.${modifier.type.wire}",
            qualityStarts = modifier.qualityStarts.takeIf { modifier.type == ProSeasonDecisionType.ROTATION_PUSH },
            runsAllowed = modifier.runsAllowed.takeIf { modifier.type == ProSeasonDecisionType.ROTATION_PUSH },
            commandRestored = restored, managerTrustDelta = 4.takeIf { modifier.suppressOutings },
            stuffDelta = (pitcher.stuff - modifier.baselineStuff).takeIf { modifier.type == ProSeasonDecisionType.VETERAN_MENTOR },
            commandDelta = (pitcher.command - modifier.baselineCommand).takeIf { modifier.type == ProSeasonDecisionType.VETERAN_MENTOR },
            movementDelta = (pitcher.movement - modifier.baselineMovement).takeIf { modifier.type == ProSeasonDecisionType.VETERAN_MENTOR },
            staminaDelta = (pitcher.stamina - modifier.baselineStamina).takeIf { modifier.type == ProSeasonDecisionType.VETERAN_MENTOR }, choiceId = modifier.choiceId)

    public fun summary(value: ProDecisionFollowUp): String = when (value.type) {
        ProSeasonDecisionType.ROTATION_PUSH -> "감독: 3주 잘 버텼다. 퀄리티 스타트 ${value.qualityStarts ?: 0}번, 실점 ${value.runsAllowed ?: 0}. 그 정도면 됐다."
        ProSeasonDecisionType.NEW_PITCH_TRIAL -> "포수: 시험 끝. 흔들리던 제구가 ${value.commandRestored ?: 0}만큼 돌아왔다. 이제 그 공은 네 거야."
        ProSeasonDecisionType.FARM_RESET -> "코치: 3주 만에 다른 투수가 돼서 올라왔다. 감독도 봤다. (믿음 +${value.managerTrustDelta ?: 0})"
        ProSeasonDecisionType.VETERAN_MENTOR -> "선배: 3주 고생했다. 구위 ${value.stuffDelta ?: 0}, 제구 ${value.commandDelta ?: 0}, 무브먼트 ${value.movementDelta ?: 0}. 남은 건 네가 챙겨."
        else -> "3주가 지났다. 그 선택은 몸 어딘가에 남았다."
    }
}
