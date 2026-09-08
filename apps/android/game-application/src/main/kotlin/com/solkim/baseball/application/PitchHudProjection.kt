package com.solkim.baseball.application

import com.solkim.baseball.core.pitch.PitchLearningProject
import com.solkim.baseball.core.pitch.PitchLearningRules
import com.solkim.baseball.core.highschool.HighSchoolPhase4Kernel
import com.solkim.baseball.core.highschool.HighSchoolTutorialMound
import com.solkim.baseball.core.highschool.currentBatter
import com.solkim.baseball.core.highschool.toPitcherSnapshot
import com.solkim.baseball.core.pitch.BatterSnapshot
import com.solkim.baseball.core.pitch.PitchCall
import com.solkim.baseball.core.pitch.PitchIntensity
import com.solkim.baseball.core.pitch.PitchKernel
import com.solkim.baseball.core.pitch.PitchKind
import com.solkim.baseball.core.pitch.PitchPreparation
import com.solkim.baseball.core.pitch.PitchZone
import com.solkim.baseball.core.pitch.PitcherSnapshot
import com.solkim.baseball.core.pitch.RivalAdaptationBand
import com.solkim.baseball.core.pitch.RivalAdaptationSnapshot
import com.solkim.baseball.core.pitch.ZoneIntent

public sealed interface PitchHudSelection {
    public data object Primary : PitchHudSelection
    public data object Alternative : PitchHudSelection
    public data class Manual(
        val pitchType: PitchKind,
        val zone: PitchZone,
        val intent: ZoneIntent = ZoneIntent.EDGE,
        val intensity: PitchIntensity = PitchIntensity.NORMAL,
    ) : PitchHudSelection
}

public data class PitchHudModel(
    val repertoire: List<PitchKind>,
    val batter: BatterSnapshot,
    val preparation: PitchPreparation,
    val canContinueInSession: Boolean,
    val scenarioTitle: String,
    val scenarioDetail: String,
    val stakesLabel: String,
    val stakesValue: String,
    val contactLabel: String,
    val disciplineLabel: String,
    val powerLabel: String,
    val currentPitchLine: String,
    val primaryExplanation: String,
    val holdToReleasePrompt: String,
    val autoReleaseEnabled: Boolean,
    val coachLabel: String,
    val coachTip: String?,
    val adaptationTitle: String,
    val adaptationBandLabel: String,
    val adaptationWarning: String,
    val adaptationLevel: Int,
    val catcherConfidencePercent: Int,
    val catcherConfidenceLabel: String,
    val catcherTrust: Int,
    val catcherBondLabel: String,
    val catcherTrustLabel: String,
    val autoReleaseLabel: String,
    val abortLabel: String,
    val sessionPitches: Int,
    val canFastForward: Boolean,
    val scoutingTitle: String,
    val scoutingBody: String,
    val scoutingAvoid: String,
)

/** Assembles the live mound call from repertoire + catcher signs. The UI does not invent a PitchCall. */
public object PitchHudProjection {
    public fun selectableTypes(pitcher: PitcherSnapshot): List<PitchKind> {
        val profiles = pitcher.pitchProfiles.orEmpty()
        if (profiles.isEmpty()) return PitchKind.entries.toList()
        return profiles.map { it.pitchType }.distinct()
    }

    public fun pitcher(state: GameAggregateState): PitcherSnapshot {
        val pitch = state.pitch
        val pro = state.pro
        if (pitch?.careerKind == PitchCareerKind.PRO && pro != null) return PitchLearningRules.playable(pro.pitcher, pro.pitchLearningProject)
        val highSchool = requireNotNull(state.highSchool) { "pitch.hud.highSchool_missing" }
        return highSchool.run.toPitcherSnapshot()
    }

    /** Match the active simulation context; archived pro fatigue must never leak into a new life. */
    public fun fatigue(state: GameAggregateState): Int = when (state.pitch?.careerKind) {
        PitchCareerKind.TUTORIAL -> 0
        PitchCareerKind.PRO -> state.pro?.activePitch?.context?.fatigue ?: state.pro?.fatigue ?: 0
        else -> state.highSchool?.activePitch?.context?.fatigue ?: state.highSchool?.run?.fatigue ?: 0
    }

    public fun batter(state: GameAggregateState): BatterSnapshot {
        val pitch = state.pitch
        if (pitch?.careerKind == PitchCareerKind.PRO) {
            return requireNotNull(state.pro?.activePitch?.batter) { "pitch.hud.pro_batter_missing" }
        }
        if (pitch?.careerKind == PitchCareerKind.TUTORIAL) return HighSchoolTutorialMound.BATTER
        val highSchool = requireNotNull(state.highSchool) { "pitch.hud.highSchool_missing" }
        return highSchool.currentBatter()
    }

    public fun repertoire(state: GameAggregateState): List<PitchKind> = selectableTypes(pitcher(state))

    public fun preparation(state: GameAggregateState): PitchPreparation {
        val pitch = requireNotNull(state.pitch) { "pitch.hud.pitch_missing" }
        return when (pitch.careerKind) {
            PitchCareerKind.TUTORIAL -> HighSchoolPhase4Kernel().prepareTutorial(
                requireNotNull(state.highSchool) { "pitch.hud.highSchool_missing" },
                pitch.sessionId,
            )
            PitchCareerKind.HIGH_SCHOOL -> HighSchoolPhase4Kernel().prepareActivePitch(
                requireNotNull(state.highSchool) { "pitch.hud.highSchool_missing" },
            )
            PitchCareerKind.PRO -> {
                val pro = requireNotNull(state.pro) { "pitch.hud.pro_missing" }
                val session = requireNotNull(pro.activePitch) { "pitch.hud.pro_pitch_missing" }
                PitchKernel().prepare(
                    PitchKernel.PrepareRequest(
                        seed = session.seed,
                        pitcher = PitchLearningRules.playable(pro.pitcher, pro.pitchLearningProject),
                        batter = session.batter,
                        scouting = session.scouting,
                        context = session.context,
                        rivalMemory = session.memory,
                        gameState = session.game,
                        gameLog = session.log,
                    ),
                )
            }
        }
    }

    public fun model(state: GameAggregateState): PitchHudModel {
        val preparation = preparation(state)
        val active = state.highSchool?.activePitch
        val proActive = state.pro?.activePitch
        val canContinue = (active != null && !active.ended) || (proActive != null && !proActive.ended)
        val batter = batter(state)
        val primary = preparation.primaryRecommendation
        val adaptation = preparation.rivalAdaptation
        val catcherTrust = catcherTrust(state)
        val catcherBond = catcherBondLabel(catcherTrust)
        val catcherConfidence = (primary.confidence / 10).coerceIn(0, 100)
        return PitchHudModel(
            repertoire = repertoire(state),
            batter = batter,
            preparation = preparation,
            canContinueInSession = canContinue,
            scenarioTitle = scenarioTitle(state),
            scenarioDetail = scenarioDetail(state),
            stakesLabel = "중요도",
            stakesValue = stakesValue(leverage(state)),
            contactLabel = "공 맞히기",
            disciplineLabel = "볼 고르기",
            powerLabel = "장타력",
            currentPitchLine = callLine(primary.call, batter.batSide),
            primaryExplanation = primary.shortReason,
            holdToReleasePrompt = "길게 눌러 와인드업",
            autoReleaseEnabled = state.settings.autoReleaseEnabled,
            coachLabel = "코치",
            coachTip = coachTip(state),
            adaptationTitle = "타자가 내 공을 읽는 정도",
            adaptationBandLabel = adaptationBandLabel(adaptation.band),
            adaptationWarning = adaptationWarning(adaptation),
            adaptationLevel = adaptation.level,
            catcherConfidencePercent = catcherConfidence,
            catcherConfidenceLabel = "사인 확신 ${when { catcherConfidence >= 75 -> "높음"; catcherConfidence >= 50 -> "보통"; else -> "낮음" }}",
            catcherTrust = catcherTrust,
            catcherBondLabel = catcherBond,
            catcherTrustLabel = "포수 호흡 · $catcherBond",
            autoReleaseLabel = "자동 릴리스 · 탭 한 번으로 던지기",
            abortLabel = "중단",
            sessionPitches = sessionPitches(state),
            canFastForward = canFastForward(state),
            scoutingTitle = scoutingTitle(preparation, batter.batSide),
            scoutingBody = scoutingBody(preparation, batter.batSide),
            scoutingAvoid = scoutingAvoid(preparation, batter.batSide),
        )
    }

    public fun scenarioTitle(state: GameAggregateState): String = when (state.pitch?.careerKind) {
        PitchCareerKind.TUTORIAL -> "첫 불펜"
        PitchCareerKind.PRO -> when (state.pro?.seasonTrigger) {
            com.solkim.baseball.core.pro.ProSeasonTrigger.MAJOR_DEBUT -> "1군 데뷔"
            com.solkim.baseball.core.pro.ProSeasonTrigger.CALL_UP_AUDITION -> "콜업 오디션"
            com.solkim.baseball.core.pro.ProSeasonTrigger.OPENING_STATEMENT -> "개막 선언"
            com.solkim.baseball.core.pro.ProSeasonTrigger.STANDINGS_RACE -> "순위 경쟁"
            com.solkim.baseball.core.pro.ProSeasonTrigger.NATIONAL_FINAL -> "대표팀 결승"
            com.solkim.baseball.core.pro.ProSeasonTrigger.RECORD_CHASE -> "기록이 걸린 등판"
            com.solkim.baseball.core.pro.ProSeasonTrigger.ROLE_SHOWDOWN -> "보직이 걸린 등판"
            com.solkim.baseball.core.pro.ProSeasonTrigger.AUTUMN_WILD_CARD -> "와일드카드"
            com.solkim.baseball.core.pro.ProSeasonTrigger.AUTUMN_SEMIFINAL -> "준플레이오프"
            com.solkim.baseball.core.pro.ProSeasonTrigger.AUTUMN_PLAYOFF -> "플레이오프"
            com.solkim.baseball.core.pro.ProSeasonTrigger.AUTUMN_FINAL -> "우승 결정전"
            null -> "프로 중요 경기"
        }
        else -> "마운드 승부처"
    }

    public fun scenarioDetail(state: GameAggregateState): String = when (state.pitch?.careerKind) {
        PitchCareerKind.TUTORIAL -> if ((state.highSchool?.run?.lifeNumber ?: 1) > 1) "기록에 안 남는 연습 한 구. 새 몸을 시험해 보자."
            else "기록에 안 남는 연습 한 타석. 마음껏 던져 보자."
        PitchCareerKind.PRO -> state.pro?.currentRival?.profile ?: "오늘 이 타석이 시즌의 무게를 가른다."
        else -> {
            val rival = state.highSchool?.run?.rival?.name
            if (rival.isNullOrBlank()) "오늘 이 타석이 승부처다." else "${rival}과의 승부. 이 타석이 오늘을 가른다."
        }
    }

    public fun stakesValue(leverage: Int): String = when {
        leverage >= 900 -> "최대 승부"
        leverage >= 780 -> "높은 승부"
        leverage >= 620 -> "흐름이 갈린다"
        else -> "일상적인 이닝"
    }

    public fun coachTip(state: GameAggregateState): String? {
        if (state.pitch?.careerKind != PitchCareerKind.TUTORIAL) return null
        val session = state.highSchool?.activePitch
        val pitches = session?.pitches ?: 0
        if (pitches >= 3) return null
        val strikes = session?.context?.strikes ?: 0
        return when {
            pitches == 0 -> "길게 눌러 와인드업. 미터가 가운데 초록에 올 때 떼자. 구종과 코스는 포수가 골라 뒀다."
            strikes >= 2 -> "결정구다. 상대가 약한 구종으로 유인하자. 존을 살짝 벗어나도 방망이가 나온다."
            else -> "같은 곳에 두 번은 없다. 구종이나 코스를 바꿔 타자의 눈을 흔들자."
        }
    }

    public fun adaptationBandLabel(band: RivalAdaptationBand): String = when (band) {
        RivalAdaptationBand.NO_DATA -> "아직 못 읽음"
        RivalAdaptationBand.WATCHING -> "지켜보는 중"
        RivalAdaptationBand.LEARNING -> "읽어 가는 중"
        RivalAdaptationBand.LOCKED_ON -> "완전히 읽힘"
    }

    public fun adaptationWarning(snapshot: RivalAdaptationSnapshot): String =
        if (snapshot.detectedPitch != null || snapshot.detectedZone != null) snapshot.warning else ""

    public fun catcherTrust(state: GameAggregateState): Int =
        if (state.pitch?.careerKind == PitchCareerKind.PRO) {
            requireNotNull(state.pro) { "pitch.hud.pro_missing" }.catcherTrust
        } else {
            state.highSchool?.run?.catcherTrust ?: 50
        }

    public fun catcherBondLabel(trust: Int): String = when {
        trust >= 75 -> "한 호흡"
        trust >= 55 -> "합이 맞음"
        trust >= 35 -> "맞춰 가는 중"
        else -> "엇갈리는 중"
    }

    public fun sessionPitches(state: GameAggregateState): Int = when (state.pitch?.careerKind) {
        PitchCareerKind.PRO -> state.pro?.activePitch?.log?.entries?.size ?: 0
        else -> state.highSchool?.activePitch?.pitches ?: 0
    }

    public fun canFastForward(state: GameAggregateState): Boolean {
        if (state.pitch?.careerKind == PitchCareerKind.TUTORIAL) return false
        val pitches = sessionPitches(state)
        val leverage: Int
        val balls: Int
        val strikes: Int
        if (state.pitch?.careerKind == PitchCareerKind.PRO) {
            val context = state.pro?.activePitch?.context
            leverage = context?.leverage ?: 500
            balls = context?.balls ?: 0
            strikes = context?.strikes ?: 0
        } else {
            val context = state.highSchool?.activePitch?.context
            leverage = context?.leverage ?: 500
            balls = context?.balls ?: 0
            strikes = context?.strikes ?: 0
        }
        // Skipping is for low-pressure plate appearances only; a full count or two strikes is one pitch away anyway.
        return leverage < 780 && !(balls == 3 || strikes == 2) || (pitches == 0 && leverage < 780)
    }

    public fun scoutingTitle(preparation: PitchPreparation, batSide: com.solkim.baseball.core.pitch.BatSide): String {
        val band = if (preparation.scoutingReport.band == "trusted") "확인됨" else "추정"
        return "상대 분석 · $band"
    }

    public fun scoutingBody(preparation: PitchPreparation, batSide: com.solkim.baseball.core.pitch.BatSide): String {
        val report = preparation.scoutingReport
        val weakness = koreanLabel(report.estimatedWeakness)
        val zone = zoneLabel(report.estimatedColdZone, batSide)
        return if (report.band == "trusted") {
            "약점은 $weakness · ${zone}로 굳어졌습니다."
        } else {
            "아직 추정. 약점은 $weakness · $zone 근처."
        }
    }

    public fun scoutingAvoid(preparation: PitchPreparation, batSide: com.solkim.baseball.core.pitch.BatSide): String {
        val report = preparation.scoutingReport
        val strength = report.estimatedStrength ?: return ""
        val hot = report.estimatedHotZone ?: return ""
        return "피할 것 — ${koreanLabel(strength)} · ${zoneLabel(hot, batSide)}"
    }

    public fun callLine(call: PitchCall, batSide: com.solkim.baseball.core.pitch.BatSide): String =
        listOf(koreanLabel(call.pitchType), zoneLabel(call.zone, batSide), intentLabel(call.zoneIntent), intensityLabel(call.intensity))
            .joinToString(" · ")

    public fun zoneLabel(zone: PitchZone, batSide: com.solkim.baseball.core.pitch.BatSide): String {
        val column = if (batSide == com.solkim.baseball.core.pitch.BatSide.LEFT) 2 - zone.column else zone.column
        val labels = listOf(
            "높은 몸쪽", "높은 가운데", "높은 바깥쪽",
            "가운데 몸쪽", "가운데", "가운데 바깥쪽",
            "낮은 몸쪽", "낮은 가운데", "낮은 바깥쪽",
        )
        val index = zone.row * 3 + column
        return labels.getOrElse(index) { "알 수 없는 코스" }
    }

    public fun intentLabel(intent: ZoneIntent): String = when (intent) {
        ZoneIntent.STRIKE -> "존 안으로"
        ZoneIntent.EDGE -> "존 경계"
        ZoneIntent.CHASE -> "존 밖 유인"
    }

    public fun intensityLabel(intensity: PitchIntensity): String = when (intensity) {
        PitchIntensity.CONTROLLED -> "힘 빼고"
        PitchIntensity.NORMAL -> "보통"
        PitchIntensity.MAX_EFFORT -> "전력"
    }

    private fun leverage(state: GameAggregateState): Int = when (state.pitch?.careerKind) {
        PitchCareerKind.TUTORIAL -> 200
        PitchCareerKind.PRO -> state.pro?.activePitch?.context?.leverage ?: 500
        else -> state.highSchool?.activePitch?.context?.leverage ?: 500
    }

    public fun resolveCall(
        pitcher: PitcherSnapshot,
        preparation: PitchPreparation,
        selection: PitchHudSelection,
    ): PitchCall {
        val allowed = selectableTypes(pitcher)
        val call = when (selection) {
            PitchHudSelection.Primary -> preparation.primaryRecommendation.call
            PitchHudSelection.Alternative -> preparation.alternativeRecommendation.call
            is PitchHudSelection.Manual -> PitchCall(selection.pitchType, selection.zone, selection.intent, selection.intensity)
        }
        require(call.pitchType in allowed) { "pitch.not_in_repertoire" }
        return call
    }

    public fun resolveCall(state: GameAggregateState, selection: PitchHudSelection): PitchCall =
        resolveCall(pitcher(state), preparation(state), selection)

    public fun koreanLabel(kind: PitchKind): String = when (kind) {
        PitchKind.FOUR_SEAM -> "포심"
        PitchKind.SLIDER -> "슬라이더"
        PitchKind.CURVEBALL -> "커브"
        PitchKind.CHANGEUP -> "체인지업"
    }
}
