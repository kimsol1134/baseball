package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.HighSchoolContentCatalog
import com.solkim.baseball.core.highschool.HighSchoolDifficulty
import com.solkim.baseball.core.highschool.HighSchoolPledgeRules
import com.solkim.baseball.core.highschool.HighSchoolAwakening
import com.solkim.baseball.core.highschool.HighSchoolAchievementRules
import com.solkim.baseball.core.highschool.HighSchoolDraftOutcome
import com.solkim.baseball.core.highschool.HighSchoolIdentity
import com.solkim.baseball.core.highschool.HighSchoolKarma
import com.solkim.baseball.core.highschool.HighSchoolPhase
import com.solkim.baseball.core.highschool.HighSchoolPhase4Command
import com.solkim.baseball.core.highschool.HighSchoolPhase4Kernel
import com.solkim.baseball.core.highschool.HighSchoolPhase4StartRequest
import com.solkim.baseball.core.highschool.HighSchoolRebirthEntryPath
import com.solkim.baseball.core.highschool.HighSchoolRelationshipTarget
import com.solkim.baseball.core.highschool.HighSchoolRelationshipResponse
import com.solkim.baseball.core.highschool.HighSchoolReturnDestination
import com.solkim.baseball.core.highschool.HighSchoolSchoolId
import com.solkim.baseball.core.highschool.HighSchoolSignatureLegacyRules
import com.solkim.baseball.core.highschool.HighSchoolTrainingFocus
import com.solkim.baseball.core.highschool.HighSchoolTrainingIntensity
import com.solkim.baseball.core.pro.OffseasonDecision
import com.solkim.baseball.core.pro.ProCatalog
import com.solkim.baseball.core.pro.ProCareerPhase
import com.solkim.baseball.core.pro.ProCommand
import com.solkim.baseball.core.pro.ProDevelopmentFocus
import com.solkim.baseball.core.pro.ProEntitlement
import com.solkim.baseball.core.pro.ProFanReasonKind
import com.solkim.baseball.core.pro.ProMerchandiseTier
import com.solkim.baseball.core.pro.ProSettlementNextRoute
import com.solkim.baseball.core.pro.ProOffseasonInvestment
import com.solkim.baseball.core.pro.ProHighSchoolLegacyContext
import com.solkim.baseball.core.pro.ProKernel
import com.solkim.baseball.core.pro.ProLevel
import com.solkim.baseball.core.pro.ProNationalTeamRules
import com.solkim.baseball.core.pro.ProNationalTournamentStage
import com.solkim.baseball.core.pro.ProRole
import com.solkim.baseball.core.pro.ProSeasonSegment
import com.solkim.baseball.core.pro.ProStartDirectRequest
import com.solkim.baseball.core.pro.ProStartLinkedRequest
import com.solkim.baseball.core.pro.ProWeekPlan
import com.solkim.baseball.core.pro.careerGames
import com.solkim.baseball.core.pro.careerStrikeouts
import com.solkim.baseball.core.pitch.PitchKind
import com.solkim.baseball.core.pitch.PitchProfileSnapshot
import com.solkim.baseball.core.pitch.PitchUsageRole
import com.solkim.baseball.core.pitch.PitcherSnapshot
import com.solkim.baseball.model.Hashing
import java.time.Clock
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.WeekFields

/** Internal coverage identifiers. They are never rendered as product copy. */
public enum class Phase8ScreenId(
    public val wire: String,
    public val title: String,
    public val group: Phase8Group,
) {
    P001_OPENING("P-001", "나의 야구 인생", Phase8Group.CAREER_CORE),
    P002_SETUP("P-002", "새로운 투수", Phase8Group.CAREER_CORE),
    P003_PROLOGUE("P-003", "프롤로그", Phase8Group.CAREER_CORE),
    P004_PITCH_TUTORIAL("P-004", "첫 투구", Phase8Group.CAREER_CORE),
    P005_SCHOOL_SELECTION("P-005", "학교 선택", Phase8Group.CAREER_CORE),
    P006_TRAINING("P-006", "훈련", Phase8Group.CAREER_CORE),
    P007_RELATIONSHIP("P-007", "관계", Phase8Group.CAREER_CORE),
    P008_IMPORTANT_GAME("P-008", "중요 경기", Phase8Group.CAREER_CORE),
    P009_AWAKENING("P-009", "각성", Phase8Group.CAREER_CORE),
    P010_CHAPTER("P-010", "장 결산", Phase8Group.CAREER_CORE),
    P011_HIGH_SCHOOL_CAREER("P-011", "고교 커리어", Phase8Group.CAREER_CORE),
    P012_TOURNAMENT_LEAGUE("P-012", "대회와 리그", Phase8Group.CAREER_CORE),
    P013_DRAFT("P-013", "드래프트", Phase8Group.RECAP_REBIRTH),
    P014_RUN_RECAP("P-014", "이번 생 결산", Phase8Group.RECAP_REBIRTH),
    P015_REBIRTH("P-015", "다음 생", Phase8Group.RECAP_REBIRTH),
    P016_PRO_CONTRACT("P-016", "프로 계약", Phase8Group.PRO),
    P017_PRO_WEEK("P-017", "프로 주간", Phase8Group.PRO),
    P018_PRO_IMPORTANT_GAME("P-018", "프로 중요 경기", Phase8Group.PRO),
    P019_PRO_SEASON("P-019", "프로 시즌", Phase8Group.PRO),
    P020_OFFSEASON("P-020", "비시즌", Phase8Group.PRO),
    P021_PRO_RETIREMENT("P-021", "은퇴", Phase8Group.PRO),
    P022_PRO_LEGACY("P-022", "프로 유산", Phase8Group.PRO),
    P024_WEEKLY("P-024", "주간 야구 노트", Phase8Group.RECORDS_META),
    P025_RECORDS_LEAGUE("P-025", "기록과 순위", Phase8Group.RECORDS_META),
    P026_ACHIEVEMENTS("P-026", "업적", Phase8Group.RECORDS_META),
    P027_SETTINGS("P-027", "설정", Phase8Group.SETTINGS_PLATFORM),
    P028_LIFECARD("P-028", "라이프 카드", Phase8Group.SETTINGS_PLATFORM),
    P029_RETURN_PLAN("P-029", "복귀 계획", Phase8Group.RETURN_REVIEW),
    P030_REVIEW("P-030", "리뷰", Phase8Group.RETURN_REVIEW),
    ;

    public companion object {
        public val ordered: List<Phase8ScreenId> = entries
    }
}

public enum class Phase8Group(public val title: String) {
    CAREER_CORE("커리어"),
    RECAP_REBIRTH("결산과 다음 생"),
    PRO("프로 커리어"),
    RECORDS_META("기록"),
    SETTINGS_PLATFORM("설정"),
    RETURN_REVIEW("복귀와 리뷰"),
}

/** Korea-local date source; tests inject a fixed implementation and production uses Seoul time. */
public fun interface Phase8KoreaClock {
    public fun today(): LocalDate
}

public class SystemPhase8KoreaClock(
    private val clock: Clock = Clock.system(ZoneId.of("Asia/Seoul")),
) : Phase8KoreaClock {
    override fun today(): LocalDate = LocalDate.now(clock)
}

public class Phase8CommandContext(
    public val clock: Phase8KoreaClock = SystemPhase8KoreaClock(),
) {
    public fun dayKey(state: GameAggregateState): String {
        if (state.meta.seedChallenge != null) return "1970-01-01"
        val saved = state.highSchool?.selectedDayKey
        return if (saved != null && saved.matches(Regex("\\d{4}-\\d{2}-\\d{2}")) && saved != "1970-01-01") {
            saved
        } else {
            clock.today().toString()
        }
    }

    public fun weekKey(state: GameAggregateState): String {
        val date = runCatching { LocalDate.parse(dayKey(state)) }.getOrElse { clock.today() }
        val week = date.get(WeekFields.ISO.weekOfWeekBasedYear())
        return "%04d-W%02d".format(date.get(WeekFields.ISO.weekBasedYear()), week)
    }

    /** Numeric, state-derived seed accepted by the Swift-shaped Kotlin kernels. */
    public fun seed(state: GameAggregateState, purpose: String): String {
        val challenge = state.meta.seedChallenge
        val source = when {
            challenge != null -> "challenge|${challenge.code.token}|${challenge.presetId}|${state.highSchool?.run?.revision}|$purpose"
            state.pro != null && state.pro.phase != ProCareerPhase.COMPLETED -> "pro|${state.pro.careerId}|${state.pro.revision}|$purpose"
            state.highSchool != null -> "high-school|${state.highSchool.run.careerId}|${state.highSchool.run.revision}|$purpose"
            else -> "${state.installId}|${state.revision}|$purpose"
        }
        return Hashing.fnv1a64Hex(source).toULong(16).toString()
    }
}

public data class Phase8Row(
    public val label: String,
    public val value: String,
    public val detail: String = "",
)

/** Frozen archive projection used by native sharing. It never falls back to the active run. */
public data class Phase9FrozenLifeCard(
    public val careerId: String,
    public val lifeNumber: Int,
    public val title: String,
    public val text: String,
    public val lines: List<String>,
)

public object Phase9LifeCardProjection {
    public fun selected(state: GameAggregateState, selectedCareerId: String? = null): Phase9FrozenLifeCard? {
        val record = if (selectedCareerId == null) {
            state.highSchool?.archive?.lastOrNull()
        } else {
            state.highSchool?.archive?.firstOrNull { it.careerId == selectedCareerId }
        } ?: return null
        val lines = listOf(
            "선수: ${record.playerName}",
            "생: ${record.lifeNumber}번째 생",
            "학교: ${record.schoolName ?: "학교 기록 없음"}",
            "드래프트: ${if (record.drafted) "지명" else "미지명"}",
            "평가: ${record.draftEvaluation}",
            "팀: ${ProCatalog.teams.firstOrNull { it.id == record.teamId }?.name ?: "없음"}",
            "능력: ${record.ratings.map(AbilityDisplayScale::rating).joinToString(" · ")}",
            "중요 경기: ${record.importantGames}경기",
            "투구: ${record.pitches}구",
            "삼진: ${record.strikeouts}개",
            "볼넷: ${record.walks}개",
            "실점: ${record.runsAllowed}점",
            "각성: ${record.selectedAwakenings.map { HighSchoolDisplayRules.awakeningTitle(it) }.ifEmpty { listOf("선택 없음") }.joinToString(" · ")}",
            "대표 유산: ${record.selectedSignatureLegacyId?.let { runCatching { HighSchoolSignatureLegacyRules.definition(it).title }.getOrNull() } ?: "선택 없음"}",
            "약속: ${record.pledgeId?.let { runCatching { HighSchoolPledgeRules.definition(it).title }.getOrNull() } ?: "선택 없음"} · ${if (record.pledgeAchieved) "달성" else "진행 중"}",
            "야구혼: ${record.soulEarned}",
        )
        return Phase9FrozenLifeCard(
            careerId = record.careerId,
            lifeNumber = record.lifeNumber,
            title = "${record.playerName} · ${record.lifeNumber}번째 생",
            text = lines.joinToString("\n"),
            lines = lines,
        )
    }
}

public enum class Phase9PlayerLegacyExposureSurface { RECAP, NEXT_LIFE, ARCHIVE }

public data class Phase9PlayerLegacyExposure(
    public val source: String,
    public val scope: String,
    public val lifeNumber: Int,
    public val drafted: Boolean,
    public val hasFrozenLegacy: Boolean,
)

/** One source of truth for the three allowed frozen-record viewport callers. */
public object Phase9PlayerLegacyExposurePolicy {
    public fun resolve(
        state: GameAggregateState,
        surface: Phase9PlayerLegacyExposureSurface,
        selectedCareerId: String? = null,
    ): Phase9PlayerLegacyExposure? {
        val highSchool = state.highSchool ?: return null
        if (highSchool.challenge.active) return null
        val run = highSchool.run
        val record = when (surface) {
            Phase9PlayerLegacyExposureSurface.RECAP -> {
                // The recap card is a frozen current-life record, so it is not exposed while
                // the player is still choosing a legacy in the pre-archive LEGACY phase.
                if (run.phase != HighSchoolPhase.COMPLETED) return null
                highSchool.archive.firstOrNull { it.careerId == run.careerId && it.lifeNumber == run.lifeNumber }
            }
            Phase9PlayerLegacyExposureSurface.NEXT_LIFE -> {
                val echo = highSchool.rebirthEcho ?: return null
                if (run.lifeNumber <= 1 || echo.previousCareerId == run.careerId || echo.previousLifeNumber >= run.lifeNumber) return null
                highSchool.archive.firstOrNull { it.careerId == echo.previousCareerId && it.lifeNumber == echo.previousLifeNumber }
            }
            Phase9PlayerLegacyExposureSurface.ARCHIVE -> {
                val id = selectedCareerId ?: highSchool.archive.lastOrNull()?.careerId ?: return null
                highSchool.archive.firstOrNull { it.careerId == id }
            }
        } ?: return null
        val source = when (surface) {
            Phase9PlayerLegacyExposureSurface.RECAP -> "recap"
            Phase9PlayerLegacyExposureSurface.NEXT_LIFE -> "next_life"
            Phase9PlayerLegacyExposureSurface.ARCHIVE -> "archive"
        }
        return Phase9PlayerLegacyExposure(
            source = source,
            scope = when (surface) {
                Phase9PlayerLegacyExposureSurface.RECAP -> "recap:${record.careerId}"
                Phase9PlayerLegacyExposureSurface.NEXT_LIFE -> "next-life:${record.careerId}:${run.careerId}"
                Phase9PlayerLegacyExposureSurface.ARCHIVE -> "archive:${record.careerId}"
            },
            lifeNumber = record.lifeNumber,
            drafted = record.drafted,
            hasFrozenLegacy = record.selectedSignatureLegacyId != null,
        )
    }
}

public data class Phase8Section(
    public val id: String,
    public val title: String,
    public val rows: List<Phase8Row>,
)

/** A strict aggregate command captured by Compose before it crosses the store boundary. */
public data class Phase8CommandPayload(
    public val screenId: Phase8ScreenId,
    public val actionId: String,
    public val envelope: GameCommandEnvelope,
) {
    public val encoded: ByteArray get() = GameCommandCodec.encode(envelope)
    public val payloadSha256: String get() = Hashing.sha256Hex(encoded)

    init {
        envelope.validate()
        require(actionId.isNotBlank()) { "phase8.action.id" }
    }
}

public data class Phase8ActionModel(
    public val id: String,
    public val label: String,
    public val description: String,
    public val enabled: Boolean,
    public val payloads: List<Phase8CommandPayload> = emptyList(),
    public val destructive: Boolean = false,
) {
    public val contentDescription: String get() = "$label. $description"
}

public data class Phase8ScreenModel(
    public val id: Phase8ScreenId,
    public val title: String,
    public val subtitle: String,
    public val sections: List<Phase8Section>,
    public val actions: List<Phase8ActionModel>,
    public val viewPayload: Phase8CommandPayload,
) {
    public val contentDescription: String get() = "$title. $subtitle"
}

public object Phase8AccessibilityContract {
    public val fontScales: List<Float> = listOf(1.0f, 1.3f, 1.5f, 2.0f)

    public fun minimumActionHeightDp(fontScale: Float): Int = maxOf(56, kotlin.math.ceil(48.0 * fontScale).toInt())

    public fun validate(model: Phase8ScreenModel) {
        require(model.title.isNotBlank() && model.subtitle.isNotBlank()) { "phase8.semantics.title" }
        require(model.contentDescription.isNotBlank()) { "phase8.semantics.description" }
        require(model.sections.all { it.id.isNotBlank() && it.title.isNotBlank() }) { "phase8.semantics.section" }
        require(model.actions.map { it.id }.distinct().size == model.actions.size) { "phase8.semantics.action_duplicate" }
        require(model.actions.all { it.contentDescription.isNotBlank() }) { "phase8.semantics.action_description" }
    }
}

public object Phase8ScreenProjection {
    public fun all(state: GameAggregateState, context: Phase8CommandContext = Phase8CommandContext()): List<Phase8ScreenModel> =
        Phase8ScreenId.ordered.map { project(state, it, context) }

    /** State-only route used on cold launch, process restart, and after a committed command. */
    public fun preferredScreen(state: GameAggregateState): Phase8ScreenId {
        if (state.stage == GameStage.SETUP) return Phase8ScreenId.P002_SETUP
        state.pitch?.let { pitch ->
            if (pitch.boundary !in setOf(PitchBoundary.COMPLETED, PitchBoundary.ABANDONED)) {
                return when (pitch.careerKind) {
                    PitchCareerKind.TUTORIAL -> Phase8ScreenId.P004_PITCH_TUTORIAL
                    PitchCareerKind.HIGH_SCHOOL -> Phase8ScreenId.P008_IMPORTANT_GAME
                    PitchCareerKind.PRO -> Phase8ScreenId.P018_PRO_IMPORTANT_GAME
                }
            }
            if (pitch.careerKind == PitchCareerKind.TUTORIAL &&
                pitch.boundary == PitchBoundary.COMPLETED &&
                state.stage == GameStage.HIGH_SCHOOL &&
                state.highSchool?.run?.phase == HighSchoolPhase.PROLOGUE &&
                state.highSchool?.tutorial?.completed != true
            ) {
                return Phase8ScreenId.P003_PROLOGUE
            }
        }
        if (state.meta.seedChallenge != null && state.highSchool?.run?.phase in setOf(HighSchoolPhase.LEGACY, HighSchoolPhase.COMPLETED)) return Phase8ScreenId.P014_RUN_RECAP
        // A linked Pro career deliberately keeps its HighSchool archive in the aggregate, but
        // the active stage owns the launcher route. Never let the preserved HS copy shadow Pro.
        state.pro?.takeIf { state.stage != GameStage.HIGH_SCHOOL }?.let { pro ->
            return when (pro.phase) {
                ProCareerPhase.CONTRACT_OFFER -> Phase8ScreenId.P016_PRO_CONTRACT
                ProCareerPhase.WEEKLY_PLAN -> Phase8ScreenId.P017_PRO_WEEK
                ProCareerPhase.IMPORTANT_GAME -> Phase8ScreenId.P018_PRO_IMPORTANT_GAME
                ProCareerPhase.SEASON_DECISION,
                ProCareerPhase.NATIONAL_TEAM_CALL,
                ProCareerPhase.NATIONAL_TOURNAMENT,
                ProCareerPhase.SEASON_SETTLEMENT,
                ProCareerPhase.SEASON_REVIEW -> Phase8ScreenId.P019_PRO_SEASON
                ProCareerPhase.OFFSEASON_DECISION,
                ProCareerPhase.OFFSEASON_INVESTMENT -> Phase8ScreenId.P020_OFFSEASON
                ProCareerPhase.RETIREMENT_DECISION -> Phase8ScreenId.P021_PRO_RETIREMENT
                ProCareerPhase.LEGACY_SELECTION -> Phase8ScreenId.P022_PRO_LEGACY
                ProCareerPhase.COMPLETED -> if (state.highSchool?.run?.phase == HighSchoolPhase.COMPLETED) Phase8ScreenId.P015_REBIRTH else Phase8ScreenId.P025_RECORDS_LEAGUE
            }
        }
        state.highSchool?.run?.let { run ->
            return when (run.phase) {
                HighSchoolPhase.PROLOGUE -> if (state.highSchool.tutorial.started && !state.highSchool.tutorial.completed) Phase8ScreenId.P004_PITCH_TUTORIAL else Phase8ScreenId.P003_PROLOGUE
                HighSchoolPhase.SCHOOL_SELECTION -> Phase8ScreenId.P005_SCHOOL_SELECTION
                HighSchoolPhase.TRAINING -> Phase8ScreenId.P006_TRAINING
                HighSchoolPhase.RELATIONSHIP -> Phase8ScreenId.P007_RELATIONSHIP
                HighSchoolPhase.IMPORTANT_GAME -> Phase8ScreenId.P008_IMPORTANT_GAME
                HighSchoolPhase.AWAKENING -> Phase8ScreenId.P009_AWAKENING
                HighSchoolPhase.CHAPTER_REVIEW -> Phase8ScreenId.P010_CHAPTER
                HighSchoolPhase.DRAFT -> Phase8ScreenId.P013_DRAFT
                HighSchoolPhase.LEGACY -> Phase8ScreenId.P014_RUN_RECAP
                HighSchoolPhase.COMPLETED -> Phase8ScreenId.P015_REBIRTH
            }
        }
        return when (state.stage) {
            GameStage.SETUP -> Phase8ScreenId.P002_SETUP
            else -> Phase8ScreenId.P001_OPENING
        }
    }

    /** Utility and summary screens are reachable only when their owning aggregate exists. */
    public fun isReachable(state: GameAggregateState, id: Phase8ScreenId): Boolean {
        if (state.meta.seedChallenge != null && id in setOf(Phase8ScreenId.P001_OPENING, Phase8ScreenId.P002_SETUP,
            Phase8ScreenId.P015_REBIRTH, Phase8ScreenId.P016_PRO_CONTRACT, Phase8ScreenId.P017_PRO_WEEK,
            Phase8ScreenId.P018_PRO_IMPORTANT_GAME, Phase8ScreenId.P019_PRO_SEASON, Phase8ScreenId.P020_OFFSEASON,
            Phase8ScreenId.P021_PRO_RETIREMENT, Phase8ScreenId.P022_PRO_LEGACY, Phase8ScreenId.P024_WEEKLY,
            Phase8ScreenId.P026_ACHIEVEMENTS, Phase8ScreenId.P028_LIFECARD, Phase8ScreenId.P029_RETURN_PLAN, Phase8ScreenId.P030_REVIEW)) return false
        return when (id) {
        Phase8ScreenId.P001_OPENING -> state.stage == GameStage.OPENING
        Phase8ScreenId.P002_SETUP -> state.stage == GameStage.SETUP
        Phase8ScreenId.P003_PROLOGUE -> state.highSchool?.run?.phase == HighSchoolPhase.PROLOGUE
        Phase8ScreenId.P004_PITCH_TUTORIAL ->
            state.highSchool?.let { hs ->
                hs.run.phase == HighSchoolPhase.PROLOGUE && hs.tutorial.started && !hs.tutorial.completed &&
                    (state.pitch == null || state.pitch.careerKind == PitchCareerKind.TUTORIAL)
            } == true
        Phase8ScreenId.P005_SCHOOL_SELECTION -> state.highSchool?.run?.phase == HighSchoolPhase.SCHOOL_SELECTION
        Phase8ScreenId.P006_TRAINING -> state.highSchool?.run?.phase == HighSchoolPhase.TRAINING
        Phase8ScreenId.P007_RELATIONSHIP -> state.highSchool?.run?.phase == HighSchoolPhase.RELATIONSHIP
        Phase8ScreenId.P008_IMPORTANT_GAME ->
            state.highSchool?.run?.phase == HighSchoolPhase.IMPORTANT_GAME &&
                (state.pitch == null || state.pitch.careerKind == PitchCareerKind.HIGH_SCHOOL ||
                    (state.pitch.careerKind == PitchCareerKind.TUTORIAL && state.pitch.boundary in setOf(PitchBoundary.COMPLETED, PitchBoundary.ABANDONED)))
        Phase8ScreenId.P009_AWAKENING -> state.highSchool?.run?.phase == HighSchoolPhase.AWAKENING
        Phase8ScreenId.P010_CHAPTER -> state.highSchool?.run?.phase == HighSchoolPhase.CHAPTER_REVIEW
        Phase8ScreenId.P011_HIGH_SCHOOL_CAREER,
        Phase8ScreenId.P012_TOURNAMENT_LEAGUE,
        Phase8ScreenId.P024_WEEKLY,
        Phase8ScreenId.P025_RECORDS_LEAGUE,
        Phase8ScreenId.P026_ACHIEVEMENTS,
        Phase8ScreenId.P028_LIFECARD,
        Phase8ScreenId.P029_RETURN_PLAN -> state.highSchool != null || state.pro != null
        Phase8ScreenId.P013_DRAFT -> state.highSchool?.run?.phase == HighSchoolPhase.DRAFT
        Phase8ScreenId.P014_RUN_RECAP -> state.highSchool?.run?.phase == HighSchoolPhase.LEGACY || state.highSchool?.run?.phase == HighSchoolPhase.COMPLETED
        Phase8ScreenId.P015_REBIRTH -> state.stage == GameStage.BETWEEN_LIVES || state.highSchool?.run?.phase == HighSchoolPhase.COMPLETED
        Phase8ScreenId.P016_PRO_CONTRACT ->
            state.pro != null || state.highSchool != null || state.stage == GameStage.OPENING
        Phase8ScreenId.P017_PRO_WEEK -> state.pro != null
        Phase8ScreenId.P018_PRO_IMPORTANT_GAME ->
            state.pro?.phase == ProCareerPhase.IMPORTANT_GAME &&
                (state.pitch == null || state.pitch.careerKind == PitchCareerKind.PRO)
        Phase8ScreenId.P019_PRO_SEASON,
        Phase8ScreenId.P020_OFFSEASON,
        Phase8ScreenId.P021_PRO_RETIREMENT,
        Phase8ScreenId.P022_PRO_LEGACY -> state.pro != null
        Phase8ScreenId.P027_SETTINGS -> true
        // The review page is a reachable utility surface. The native Play request remains
        // disabled until one of the exact product moments is durably confirmed.
        Phase8ScreenId.P030_REVIEW -> state.highSchool != null || state.pro != null
    }
    }

    /** Retired Daily links have no product entry; they resolve to the state-owned route. */
    public fun normalizeLegacyRoute(raw: String, state: GameAggregateState): Phase8ScreenId =
        when (raw.trim().lowercase()) {
            "daily", "daily_inning", "p-023", "p023" -> preferredScreen(state)
            else -> preferredScreen(state)
        }

    public fun project(
        state: GameAggregateState,
        id: Phase8ScreenId,
        context: Phase8CommandContext = Phase8CommandContext(),
    ): Phase8ScreenModel {
        require(isReachable(state, id) || id == preferredScreen(state)) { "phase8.screen_unreachable:${id.wire}" }
        val highSchool = state.highSchool
        val run = highSchool?.run
        val pro = state.pro?.takeUnless { state.meta.seedChallenge != null || (id == Phase8ScreenId.P016_PRO_CONTRACT && it.phase == ProCareerPhase.COMPLETED) }
        val sections = mutableListOf<Phase8Section>()
        val actions = mutableListOf<Phase8ActionModel>()

        fun addSection(section: Phase8Section) { sections += section }
        fun addAction(actionId: String, label: String, description: String, enabled: Boolean, commands: List<GameCommand> = emptyList(), destructive: Boolean = false) {
            actions += Phase8ActionModel(
                id = actionId,
                label = label,
                description = description,
                enabled = enabled,
                payloads = if (enabled) Phase8Payloads.batch(state, id, actionId, commands) else emptyList(),
                destructive = destructive,
            )
        }

        if (id == Phase8ScreenId.P014_RUN_RECAP && state.meta.seedChallenge != null) {
            val challenge = state.meta.seedChallenge
            addSection(Phase8Section("seed-result", "같은 조건에서 남긴 기록", listOf(
                Phase8Row("도전 코드", challenge.code.token),
                Phase8Row("평가", "${run?.draftResult?.evaluationScore ?: 0}"),
                Phase8Row("투구", "${run?.performance?.pitches ?: 0}구 · ${run?.performance?.strikeouts ?: 0}탈삼진"),
            )))
            addAction("endSeedChallenge", "원래 이야기로 돌아가기", "도전 전의 커리어로 돌아갑니다. 원래 기록과 야구혼은 그대로입니다.", true,
                listOf(hs(HighSchoolPhase4Command.EndChallenge)))
            return Phase8ScreenModel(id, "도전 결과", "새로운 선택으로 같은 시작을 바꿨습니다.", sections, actions, Phase8Payloads.view(state, id))
        }
        when (id) {
            Phase8ScreenId.P001_OPENING -> {
                addSection(Phase8Section("opening", "새로운 시작", listOf(
                    Phase8Row("이 게임", "환생 투수 커리어", "야구가 안 되면 다음 생으로 이어집니다. 직접 던지는 기본은 투구 슬라이더입니다."),
                    Phase8Row("기본 투구", "길게 눌러 와인드업", "손을 떼는 타이밍으로 공을 던집니다. 자동 릴리스는 보조 설정입니다."),
                    Phase8Row("돌아오기", "저장된 장면에서 계속", "앱을 다시 열어도 마지막으로 확정된 장면에서 이어집니다."),
                )))
                addAction("enterSetup", "시작하기", "나만의 투수로 첫 이야기를 시작합니다.", state.stage == GameStage.OPENING, listOf(GameCommand.EnterSetup))
            }
            Phase8ScreenId.P002_SETUP -> {
                addSection(Phase8Section("setup", "선수 만들기", HighSchoolContentCatalog.presets.map { preset ->
                    Phase8Row(HighSchoolDisplayRules.presetTitle(preset.id), "구위 ${AbilityDisplayScale.rating(preset.baseStuff)} · 제구 ${AbilityDisplayScale.rating(preset.baseCommand)}", "무브먼트 ${AbilityDisplayScale.rating(preset.baseMovement)} · 체력 ${AbilityDisplayScale.rating(preset.baseStamina)}")
                } + listOf(
                    Phase8Row("지역", "19개 지역", "지역에 따라 네 학교와 코치·포수의 이야기가 달라집니다."),
                    Phase8Row("난이도", "표준", "상황을 읽고 직접 선택하는 기본 난이도입니다."),
                    Phase8Row("능력 배분", "구위 · 제구 · 무브먼트 · 체력", "선택한 유형의 네 가지 시작 능력입니다."),
                )))
                addAction("startHighSchool", "이 투수로 시작하기", "첫 학교에서 나의 야구 이야기를 시작합니다.", state.stage == GameStage.SETUP, listOf(Phase8Payloads.startHighSchool(state, context)))
            }
            Phase8ScreenId.P003_PROLOGUE -> {
                addSection(Phase8Section("letter", "도착한 편지", listOf(
                    Phase8Row("선수", run?.identity?.name ?: "—", "이번 생의 첫 기록"),
                    Phase8Row("편지", run?.news?.take(2)?.joinToString("\n\n") ?: "아직 편지가 도착하지 않았습니다.", "이전 선수의 마음이 다음 선택을 비춥니다."),
                    Phase8Row("튜토리얼", if (highSchool?.tutorial?.started == true) "시작했습니다" else "시작 전", "첫 사인은 짧은 튜토리얼에서 배웁니다."),
                )))
                addAction("beginTutorial", "첫 사인 익히기", "첫 투구 튜토리얼을 시작합니다.", run?.phase == HighSchoolPhase.PROLOGUE && highSchool?.tutorial?.started != true, listOf(hs(HighSchoolPhase4Command.BeginTutorial)))
                addAction("completeTutorial", "튜토리얼 마치기", "다음 학교 선택으로 이동합니다.", run?.phase == HighSchoolPhase.PROLOGUE && (highSchool?.tutorial?.let { it.started && !it.completed } == true || state.pitch?.boundary == PitchBoundary.COMPLETED), listOf(hs(HighSchoolPhase4Command.CompleteTutorial(context.seed(state, "tutorial-complete")))))
            }
            Phase8ScreenId.P004_PITCH_TUTORIAL -> {
                addSection(Phase8Section("first-pitch", "첫 투구", listOf(
                    Phase8Row("첫 공의 선택", "구종 · 코스 · 강도", "처음에는 포수의 사인을 따라 던져 보세요."),
                    Phase8Row("직접 던지기", "누르고 초록 구간에서 놓기", "누른 채 조준을 맞추고, 슬라이더가 초록 구간에 오면 손을 뗍니다."),
                )))
                val reusable = state.pitch == null || state.pitch?.boundary in setOf(PitchBoundary.COMPLETED, PitchBoundary.ABANDONED)
                val hasPendingResult = state.pitch?.boundary in setOf(PitchBoundary.COMMITTED, PitchBoundary.CONSUMED, PitchBoundary.TERMINAL)
                val session = tutorialSession(state)
                val tutorialReady = (highSchool?.tutorial?.let { it.started && !it.completed } == true && reusable) || hasPendingResult
                val commands = if (hasPendingResult) emptyList() else tutorialCommands(state, context)
                addAction("openTutorialPitch", if (hasPendingResult) "투구 결과 확인하기" else "첫 투구 열기", if (hasPendingResult) "투구 결과를 확인하고 완료합니다." else "첫 투구 화면을 엽니다.", tutorialReady, commands)
                addAction("resumePitch", "투구 이어 하기", "저장한 투구를 이어 합니다.", state.pitch?.boundary == PitchBoundary.SUSPENDED, listOfNotNull(state.pitch?.let { GameCommand.ResumePitch(it.sessionId) }))
                addAction("abandonPitch", "이번 투구 포기", "이번 투구만 포기하고 다음 선택으로 돌아갑니다.", state.pitch?.boundary in setOf(PitchBoundary.RESERVED, PitchBoundary.PLAYING, PitchBoundary.SUSPENDED), listOfNotNull(state.pitch?.let { GameCommand.AbandonPitch(it.sessionId, "사용자가 투구를 포기함") }), true)
            }
            Phase8ScreenId.P005_SCHOOL_SELECTION -> {
                val schools = run?.schoolOptions?.ifEmpty { run?.let { HighSchoolContentCatalog.schools(it.identity.region) } } ?: emptyList()
                addSection(Phase8Section("schools", "학교 후보", schools.map { school ->
                    Phase8Row(school.name, school.philosophy, "코치 ${school.coachName} · 포수 ${school.catcherName}")
                }))
                schools.forEach { school -> addAction("chooseSchool:${school.id.wire}", school.name, school.philosophy, run?.phase == HighSchoolPhase.SCHOOL_SELECTION, listOf(hs(HighSchoolPhase4Command.ChooseSchool(context.seed(state, "school:${school.id.wire}"), school.id)))) }
            }
            Phase8ScreenId.P006_TRAINING -> {
                val opportunity = run?.trainingOpportunity
                val recommended = opportunity?.focus
                addSection(Phase8Section("training", "오늘 훈련", listOf(
                    Phase8Row("장면", recommended?.label ?: "훈련장", opportunity?.reason ?: "코치가 오늘의 과제를 정해 두었습니다. 한 블록을 고르면 몸이 남습니다."),
                    Phase8Row("몸 상태", "구위 ${run?.pitcher?.stuff?.let(AbilityDisplayScale::rating) ?: 0} · 제구 ${run?.pitcher?.command?.let(AbilityDisplayScale::rating) ?: 0}", "무브먼트 ${run?.pitcher?.movement?.let(AbilityDisplayScale::rating) ?: 0} · 체력 ${run?.pitcher?.stamina?.let(AbilityDisplayScale::rating) ?: 0}"),
                    Phase8Row("이번 블록", "${run?.chapterTrainingCount ?: 0}회", "블록이 끝나면 다음 장면으로 넘어갑니다."),
                )))
                val focuses = if (recommended == null) {
                    HighSchoolTrainingFocus.entries
                } else {
                    listOf(recommended) + HighSchoolTrainingFocus.entries.filter { it != recommended }
                }
                focuses.forEach { focus ->
                    val recommendedMark = if (focus == recommended) "오늘 과제 · " else ""
                    addAction(
                        "train:${focus.wire}",
                        "$recommendedMark${focus.label}",
                        if (focus == recommended) {
                            opportunity?.reason ?: "${focus.label} 중심으로 한 블록 훈련합니다."
                        } else {
                            "${focus.label} 중심으로 한 블록 훈련합니다."
                        },
                        run?.phase == HighSchoolPhase.TRAINING,
                        listOf(hs(HighSchoolPhase4Command.Training(context.seed(state, "training:${focus.wire}"), focus, HighSchoolTrainingIntensity.STANDARD, focus.pitchKindOrNull()))),
                    )
                }
            }
            Phase8ScreenId.P007_RELATIONSHIP -> {
                val event = run?.currentRelationshipEvent
                addSection(Phase8Section("relationship", event?.title ?: "이번 대화", listOf(
                    Phase8Row(run?.let(RelationshipNarrative::speaker) ?: "동료", run?.let(RelationshipNarrative::line) ?: "동료와 코치의 목소리가 들립니다.", ""),
                    Phase8Row("상대", run?.currentRelationshipTarget?.label ?: "팀", "감독 ${run?.managerTrust ?: 0} · 포수 ${run?.catcherTrust ?: 0} · 라이벌 ${run?.rivalTrust ?: 0}"),
                )))
                HighSchoolRelationshipResponse.entries.forEach { response ->
                    addAction(
                        "relationship:${response.wire}",
                        run?.let { RelationshipNarrative.choice(it, response)?.title } ?: relationshipChoiceTitle(event?.category, response),
                        run?.let { RelationshipNarrative.choice(it, response)?.detail } ?: relationshipChoiceDetail(event?.category, response),
                        run?.phase == HighSchoolPhase.RELATIONSHIP,
                        listOf(hs(HighSchoolPhase4Command.Relationship(context.seed(state, "relationship:${response.wire}"), response))),
                    )
                }
            }
            Phase8ScreenId.P008_IMPORTANT_GAME -> {
                val scenario = run?.currentGameScenario
                addSection(Phase8Section("important-game", scenario?.title ?: "승부처", listOf(
                    Phase8Row("오늘", scenario?.narrative ?: "상황과 상대를 확인한 뒤 마운드에 오릅니다.", "직접 슬라이더로 던지는 타석입니다."),
                    Phase8Row("상황", importantGameSituation(scenario), "승부처의 점수와 주자"),
                    Phase8Row("기록", "${run?.performance?.pitches ?: 0}구 · ${run?.performance?.strikeouts ?: 0}탈삼진", state.pitch?.boundary?.let { pitchBoundaryLabel(it) } ?: "준비 전"),
                )))
                val reusable = state.pitch == null || state.pitch?.boundary in setOf(PitchBoundary.COMPLETED, PitchBoundary.ABANDONED)
                val canOpenImportantGame = run?.phase == HighSchoolPhase.IMPORTANT_GAME && reusable && highSchool?.activePitch == null
                val canOpenNextPitch = run?.phase == HighSchoolPhase.IMPORTANT_GAME && state.pitch?.boundary in setOf(PitchBoundary.COMPLETED, PitchBoundary.ABANDONED) && highSchool?.activePitch != null
                addAction("openImportantGame", "승부처에 오르기", "중요 경기의 첫 타석을 엽니다.", canOpenImportantGame, if (canOpenImportantGame) importantGameCommands(state, context) else emptyList())
                addAction("nextImportantPitch", "다음 타석 열기", "같은 경기의 다음 타석을 엽니다.", canOpenNextPitch, if (canOpenNextPitch) nextHighSchoolPitchCommands(state) else emptyList())
                val canResumePitch = state.pitch?.boundary in setOf(PitchBoundary.PLAYING, PitchBoundary.SUSPENDED)
                addAction("resumePitch", "투구 이어 하기", "저장한 투구를 이어 합니다.", canResumePitch, listOfNotNull(state.pitch?.takeIf { it.boundary == PitchBoundary.SUSPENDED }?.let { GameCommand.ResumePitch(it.sessionId) }))
                addAction("abandonPitch", "이번 투구 포기", "이번 타석만 포기합니다.", state.pitch?.boundary in setOf(PitchBoundary.RESERVED, PitchBoundary.PLAYING, PitchBoundary.SUSPENDED), listOfNotNull(state.pitch?.let { GameCommand.AbandonPitch(it.sessionId, "사용자가 투구를 포기함") }), true)
            }
            Phase8ScreenId.P009_AWAKENING -> {
                addSection(Phase8Section("awakening", "새로운 감각", (run?.awakeningOptions ?: HighSchoolContentCatalog.awakeningNodes.map { it.id }).take(8).map { awakening ->
                    Phase8Row(awakening.label, "선택 가능", "이번 선택은 다음 장의 투구 감각에 남습니다.")
                }))
                run?.awakeningOptions.orEmpty().forEach { awakening -> addAction("awakening:${awakening.wire}", awakening.label, "${awakening.label}을(를) 선택합니다.", run?.phase == HighSchoolPhase.AWAKENING, listOf(hs(HighSchoolPhase4Command.ChooseAwakening(context.seed(state, "awakening:${awakening.wire}"), awakening)))) }
            }
            Phase8ScreenId.P010_CHAPTER -> {
                val chapter = run?.chapter
                addSection(Phase8Section("chapter", "장 결산", listOf(
                    Phase8Row("장", chapter?.number?.toString() ?: "—", chapter?.title ?: "다음 장을 준비합니다."),
                    Phase8Row("주제", chapter?.theme ?: "—", "이번 장의 목표와 성장 기록"),
                    Phase8Row("자동 경기", "${run?.automaticGames ?: 0}경기 · ${run?.automaticOuts ?: 0}아웃", "저장된 시즌 흐름"),
                )))
                addAction("advanceChapter", "다음 장으로", "장 결산을 확정합니다.", run?.phase == HighSchoolPhase.CHAPTER_REVIEW, listOf(hs(HighSchoolPhase4Command.AdvanceChapter(context.seed(state, "chapter")))))
            }
            Phase8ScreenId.P011_HIGH_SCHOOL_CAREER -> addSection(Phase8Section("career", "고교 커리어", listOf(
                Phase8Row("선수", run?.identity?.name ?: "—", "${run?.lifeNumber ?: 0}번째 생"),
                Phase8Row("현재 장면", run?.chapter?.title ?: "—", run?.phase?.label ?: "—"),
                Phase8Row("공식 경기", "${highSchool?.completedGameCounter ?: 0}경기", "한 경기의 타석을 이어서 상대합니다."),
            )))
            Phase8ScreenId.P012_TOURNAMENT_LEAGUE -> {
                val rows = highSchool?.tournaments.orEmpty().map { tournament ->
                    Phase8Row(tournament.name, tournament.playerRound, if (tournament.completed) "완료" else "진행 중")
                } + highSchool?.prospectBoard.orEmpty().take(8).map { prospect ->
                    Phase8Row("${prospect.rank}위 ${prospect.name}", prospect.schoolName, "평가 ${prospect.score} · ${prospect.tag}")
                }
                addSection(Phase8Section("league", "대회와 순위", rows))
            }
            Phase8ScreenId.P013_DRAFT -> addSection(Phase8Section("draft", "드래프트 결과", listOf(
                Phase8Row("결과", run?.draftResult?.outcome?.label ?: "결과를 기다리는 중", run?.draftResult?.summary ?: "곧 나의 다음 무대가 정해집니다."),
                Phase8Row("평가", run?.draftResult?.evaluationScore?.toString() ?: "—", "현재 능력과 성장의 종합 평가"),
                Phase8Row("다음", if (run?.draftResult?.outcome?.wire == "drafted") "프로 계약" else "다음 생", "선택 가능한 길을 확인합니다."),
            )))
            .also { run?.let { CareerChoicePresentation.conclusion(it).forEach(::addSection) } }
            .also { addAction("resolveDraft", "드래프트 결과 확인", "마지막 평가를 저장하고 다음 장면을 엽니다.", run?.let { it.phase == HighSchoolPhase.DRAFT && it.draftResult == null } == true, listOf(hs(HighSchoolPhase4Command.ResolveDraft(context.seed(state, "draft"))))) }
            Phase8ScreenId.P014_RUN_RECAP -> {
                run?.let { CareerChoicePresentation.conclusion(it).forEach(::addSection) }
                addSection(Phase8Section("recap", "이번 생의 기록", listOf(
                    Phase8Row("선수", run?.identity?.name ?: "—", "이번 생에 남긴 기록"),
                    Phase8Row("투구", "${run?.performance?.pitches ?: 0}구", "실점 ${run?.performance?.runsAllowed ?: 0} · 삼진 ${run?.performance?.strikeouts ?: 0}"),
                    Phase8Row("유산", run?.legacyOptions.orEmpty().takeIf { it.isNotEmpty() }?.joinToString(" · ") { legacyTitle(it) } ?: "준비 중", "대표 유산은 한 번만 선택합니다."),
                )))
                addAction("prepareLegacy", "유산 후보 보기", "이번 생에서 남길 세 가지를 준비합니다.", run?.let { it.phase == HighSchoolPhase.LEGACY || (it.phase == HighSchoolPhase.COMPLETED && it.draftResult?.outcome?.wire == "drafted") } == true, listOf(hs(HighSchoolPhase4Command.PrepareLegacy)))
                // Old base-engine memory options must first be converted into frozen signature candidates.
                run?.legacyOptions.orEmpty().filter { id -> HighSchoolSignatureLegacyRules.definitions.any { it.id == id } }
                    .forEach { legacy -> addAction("selectLegacy:$legacy", legacyTitle(legacy), legacyEffect(legacy), run?.phase == HighSchoolPhase.LEGACY, listOf(hs(HighSchoolPhase4Command.SelectLegacy(legacy)))) }
                addAction("finalizeArchive", "기록 보관하기", "이번 생의 기록을 보관하고 다음 선택으로 갑니다.", run?.phase == HighSchoolPhase.COMPLETED && highSchool?.selectedSignatureLegacyId != null, listOf(hs(HighSchoolPhase4Command.FinalizeArchive)))
                val draftedReviewReceipt = "review-moment:${run?.careerId}:drafted-reveal-confirmed"
                val recapReviewReceipt = "review-moment:${run?.careerId}:good-recap"
                if (run?.draftResult?.outcome == HighSchoolDraftOutcome.DRAFTED) {
                    addAction(
                        "confirmDraftResult",
                        "드래프트 결과 확인 완료",
                        "결과를 읽고 다음 선택을 준비합니다.",
                        state.analytics.receipts.none { it.receiptId == draftedReviewReceipt },
                        listOf(GameCommand.RecordAnalytics(draftedReviewReceipt, "review_moment_drafted_reveal_confirmed")),
                    )
                } else if (run?.draftResult != null && recapDeservesReview(state)) {
                    addAction(
                        "confirmRecap",
                        "결산 확인 완료",
                        "이번 생의 결산을 읽고 다음 장면을 준비합니다.",
                        state.analytics.receipts.none { it.receiptId == recapReviewReceipt },
                        listOf(GameCommand.RecordAnalytics(recapReviewReceipt, "review_moment_good_recap")),
                    )
                }
            }
            Phase8ScreenId.P015_REBIRTH -> {
                val inheritedId = highSchool?.inheritance?.selectedSignatureLegacyId
                addSection(Phase8Section("rebirth", "다음 생에도, 나의 공", listOf(
                    Phase8Row("이어지는 힘", inheritedId?.let(::legacyTitle) ?: "남은 기억", inheritedId?.let(::legacyEffect).orEmpty()),
                    Phase8Row("남은 기억", highSchool?.inheritance?.inheritedMemories?.size?.toString() ?: "0", "선택한 기억이 다음 선수에게 남습니다."),
                    Phase8Row("다시 시작", "고교 1학년부터 다시 시작", ""),
                )))
                val canBeginRebirth = run?.phase == HighSchoolPhase.COMPLETED && highSchool?.archive?.any { it.careerId == run.careerId } == true
                addAction(
                    "quickRebirth",
                    "이 힘으로 환생하기",
                    "보관된 기록과 선택한 기억을 바로 이어 새 장면을 엽니다.",
                    canBeginRebirth,
                    listOf(hs(HighSchoolPhase4Command.BeginRebirth(context.seed(state, "quick-rebirth"), context.dayKey(state), HighSchoolRebirthEntryPath.QUICK_REBIRTH))),
                )
                addAction(
                    "customizeRebirth",
                    "다음 생 설정하기",
                    "이름과 구종, 이어받을 힘을 직접 고릅니다.",
                    canBeginRebirth,
                    listOf(GameCommand.EnterSetup),
                )
                addAction(
                    "finalizeArchive",
                    "기록 보관하기",
                    "이번 생의 기록을 보관하고 다음 선택으로 갑니다.",
                    run?.phase == HighSchoolPhase.COMPLETED &&
                        highSchool?.selectedSignatureLegacyId != null &&
                        highSchool.archive.none { it.careerId == run.careerId },
                    listOf(hs(HighSchoolPhase4Command.FinalizeArchive)),
                )
                if ((state.pro == null || state.pro.phase == ProCareerPhase.COMPLETED) && run?.phase == HighSchoolPhase.COMPLETED) {
                    if (run.draftResult?.outcome == HighSchoolDraftOutcome.DRAFTED) addAction(
                        "startLinked",
                        "프로 무대로 가기",
                        "현재 고교 기록을 보존한 채 프로로 이어 갑니다.",
                        true,
                        listOf(pro(ProCommand.StartLinked(linkedRequest(state, context)))),
                    )
                    val name = run?.identity?.name?.ifBlank { null } ?: "민서준"
                    addAction(
                        "startDirect",
                        "직접 프로 시작",
                        "고교 기록과 분리된 새 프로 커리어를 시작합니다.",
                        true,
                        listOf(pro(ProCommand.StartDirect(ProStartDirectRequest(context.seed(state, "pro-direct"), "power_prospect", name)))),
                    )
                }
            }
            Phase8ScreenId.P016_PRO_CONTRACT -> {
                val market = pro?.journeyState?.pendingContractMarket
                val contract = pro?.contract
                val salary = contract?.annualSalary
                val salaryText = if (salary == null) "제안 대기" else "%,d원".format(java.util.Locale.KOREA, salary)
                if (market != null && market.offers.isNotEmpty()) {
                    addSection(
                        Phase8Section(
                            "pro-contract-market",
                            if (market.kind == com.solkim.baseball.core.pro.ProContractMarketKind.ROOKIE) "신인 계약 시장" else if (market.kind == com.solkim.baseball.core.pro.ProContractMarketKind.FREE_AGENCY) "FA 시장" else "재계약 시장",
                            market.offers.map { offer ->
                                val team = ProCatalog.teams.firstOrNull { it.id == offer.teamId }
                                Phase8Row(
                                    team?.name ?: offer.teamId,
                                    "${offer.years}년 · ${"%,d원".format(java.util.Locale.KOREA, offer.annualSalary)} · ${offer.rolePromise.label}",
                                    buildString {
                                        append(contractKindLabel(offer.contractKind))
                                        append(" · ")
                                        append(outlookLabel(offer.outlook))
                                        append(" · ")
                                        append(if (offer.preservesTeamLegacy) "잔류 유산 유지" else "이적")
                                        offer.signingBonus?.let { append(" · 계약금 ${"%,d원".format(java.util.Locale.KOREA, it)}") }
                                    },
                                )
                            },
                        ),
                    )
                    val completedGoals = pro?.journeyState?.goalHistory.orEmpty().filter { it.outcome == com.solkim.baseball.core.pro.ProCareerGoalOutcome.COMPLETED }.map { it.ambition }.toSet()
                    val ambitions = com.solkim.baseball.core.pro.ProCareerAmbition.entries.filter { it !in completedGoals }
                    market.offers.forEach { offer ->
                        val teamName = ProCatalog.teams.firstOrNull { it.id == offer.teamId }?.name ?: offer.teamId
                        val choices = ambitions.map { it as com.solkim.baseball.core.pro.ProCareerAmbition? }.ifEmpty { listOf(null) }
                        choices.forEach { ambition ->
                            val goalTitle = when (ambition) {
                                com.solkim.baseball.core.pro.ProCareerAmbition.FRANCHISE_ICON -> "한 팀의 전설"
                                com.solkim.baseball.core.pro.ProCareerAmbition.RECORD_BOOK -> "기록으로 남는 투수"
                                com.solkim.baseball.core.pro.ProCareerAmbition.ENDURING_PRO -> "오래 뛰는 선수"
                                null -> "이룬 목표를 이어가기"
                            }
                            addAction("acceptOffer:${offer.id}:${ambition?.wire ?: "complete"}", "$teamName · $goalTitle",
                                "이 목표를 선택하고 ${offer.years}년 계약에 서명합니다.", pro?.phase == ProCareerPhase.CONTRACT_OFFER,
                                listOf(pro(ProCommand.AcceptContractOffer(context.seed(state, "accept:${offer.id}"), offer.id, ambition))))
                        }
                    }
                } else {
                    addSection(Phase8Section("pro-contract", "프로 계약", listOf(
                        Phase8Row("프로 무대로", "고교에서 키운 선수로 도전하기", "고교에서 쌓은 능력과 기억을 이어 갑니다."),
                        Phase8Row("팀", pro?.team?.name ?: "팀을 고르는 중", pro?.team?.developmentPlan ?: "팀의 성장 계획"),
                        Phase8Row("계약 기간", "${contract?.yearsRemaining ?: 0}년", "제시된 계약의 남은 시즌"),
                        Phase8Row("연봉", salaryText, "시즌 단위 연봉. 총 보장은 기간과 함께 읽습니다."),
                        Phase8Row("보직", contract?.rolePromise?.label ?: pro?.role?.label ?: "선발", "계약이 약속한 등판 역할"),
                    )))
                    addAction("signContract", "계약 서명", "제시된 계약을 확정합니다.", pro?.phase == ProCareerPhase.CONTRACT_OFFER, listOf(pro(ProCommand.SignContract)))
                }
                val name = run?.identity?.name ?: "민서준"
                addAction("startDirect", "직접 프로 시작", "고교 기록과 분리된 새 프로 커리어를 시작합니다.", pro == null, listOf(pro(ProCommand.StartDirect(ProStartDirectRequest(context.seed(state, "pro-direct"), "power_prospect", name)))))
                val canLink = highSchool != null && pro == null && run?.draftResult?.outcome == HighSchoolDraftOutcome.DRAFTED && run.phase in setOf(HighSchoolPhase.DRAFT, HighSchoolPhase.COMPLETED)
                if (highSchool != null) addAction("startLinked", "프로 무대로 가기", "현재 고교 기록을 보존한 채 프로로 이어 갑니다.", canLink,
                    if (canLink) listOf(pro(ProCommand.StartLinked(linkedRequest(state, context)))) else emptyList())
            }
            Phase8ScreenId.P017_PRO_WEEK -> {
                if (pro != null) {
                    pro.resolvedFollowUps.orEmpty().takeLast(3).reversed().forEach { followUp ->
                        addSection(Phase8Section("followup:${followUp.decisionId}", "지난 선택의 결과", listOf(
                            Phase8Row(com.solkim.baseball.core.pro.ProWeeklyDecisionRules.title(followUp.type),
                                com.solkim.baseball.core.pro.ProWeeklyDecisionRules.summary(followUp), "${followUp.season}시즌 ${followUp.week}주차"),
                        )))
                    }
                    if (com.solkim.baseball.core.pro.ProRoleRequestRules.shouldOffer(pro)) {
                        addSection(Phase8Section("role-request", "스프링캠프 보직 지원", listOf(
                            Phase8Row("이번 시즌의 자리", "선발·중간·마무리 중 지원할 수 있습니다.", "이번 시즌 한 번 지원합니다. 조건부 지원은 6주차 면담으로 이어집니다."),
                        )))
                        com.solkim.baseball.core.pro.ProRoleRequestRules.requestableRoles.forEach { role ->
                            val outcome = com.solkim.baseball.core.pro.ProRoleRequestRules.evaluate(pro, role)
                            val outlook = when (outcome) {
                                com.solkim.baseball.core.pro.ProRoleRequestOutcome.ACCEPTED -> "수락 가능 · 다음 등판부터 준비"
                                com.solkim.baseball.core.pro.ProRoleRequestOutcome.CONDITIONAL -> "조건부 · 6주차 역할 면담"
                                com.solkim.baseball.core.pro.ProRoleRequestOutcome.REJECTED -> "준비 필요 · 거절되면 감독의 믿음 -1"
                            }
                            addAction("requestRole:${role.wire}", "${role.label} 지원", outlook, true,
                                listOf(pro(ProCommand.RequestRole(context.seed(state, "role-request"), role))))
                        }
                    } else pro.roleRequest?.let { request ->
                        val result = when (request.outcome) {
                            com.solkim.baseball.core.pro.ProRoleRequestOutcome.ACCEPTED -> "수락됨"
                            com.solkim.baseball.core.pro.ProRoleRequestOutcome.CONDITIONAL -> "조건부 · ${request.reviewWeek}주차 면담"
                            com.solkim.baseball.core.pro.ProRoleRequestOutcome.REJECTED -> "준비가 더 필요합니다"
                        }
                        addSection(Phase8Section("role-result", "보직 지원 결과", listOf(Phase8Row(request.requested.label, result))))
                    }
                }
                val remaining = if (pro == null) 0 else ProCatalog.expectedRemainingOutings(pro.week, pro.injuryWeeks, pro.role)
                val tensions = pro?.seasonTensions.orEmpty().take(2).map { tension ->
                    Phase8Row(tension.title, tension.detail, "시즌 긴장")
                }
                val newsRows = pro?.news.orEmpty().take(3).mapIndexed { index, line ->
                    Phase8Row("뉴스 ${index + 1}", line, "최근 소식")
                }
                addSection(Phase8Section("pro-week", "프로 주간 계획", listOf(
                    Phase8Row("주차", pro?.week?.toString() ?: "—", ProCatalog.segmentLabel(pro?.seasonSegment ?: ProSeasonSegment.SPRING_CAMP)),
                    Phase8Row("역할", pro?.role?.label ?: "—", "현재 ${pro?.level?.label ?: "—"}"),
                    Phase8Row("남은 등판", "${remaining}경기", "이번 시즌 주간 일정에서 앞으로 남을 자동 등판입니다."),
                    Phase8Row("성장", "구위 ${pro?.pitcher?.stuff?.let(AbilityDisplayScale::rating) ?: 0} · 무브먼트 ${pro?.pitcher?.movement?.let(AbilityDisplayScale::rating) ?: 0}", "표적 능력과 구종을 함께 고릅니다."),
                    Phase8Row("피로", "${pro?.fatigue ?: 0}", "회복 계획은 다음 주 기록에도 반영됩니다."),
                ) + tensions + newsRows))
                pro?.pitchLearningProject?.let { project ->
                    addSection(Phase8Section("pitch-learning", "구종 익히기", TrainingPresentation.learningLines(project).map { Phase8Row("", it, "") }))
                }
                ProWeekPlan.currentChoices.forEach { plan ->
                    addAction(
                        "proPlan:${plan.wire}",
                        plan.iosTitle(pro),
                        plan.iosDescription(pro),
                        pro?.phase == com.solkim.baseball.core.pro.ProCareerPhase.WEEKLY_PLAN,
                        listOf(pro(ProCommand.PlanWeek(context.seed(state, "pro-plan:${plan.wire}"), plan, plan.targetPitchOrNull(pro)))),
                    )
                }
                addAction(
                    "proAdvanceSegment",
                    "구간 건너뛰기",
                    "주간 선택 없이 같은 구간을 자동으로 진행합니다. 한 주씩 고르는 길이 기본입니다.",
                    pro?.phase == com.solkim.baseball.core.pro.ProCareerPhase.WEEKLY_PLAN,
                    listOf(pro(ProCommand.AdvanceSegment(context.seed(state, "pro-segment"), ProWeekPlan.DEVELOP_STUFF, null))),
                )
            }
            Phase8ScreenId.P018_PRO_IMPORTANT_GAME -> {
                addSection(Phase8Section("pro-game", "프로 승부처", listOf(
                    Phase8Row("상대", pro?.currentRival?.name ?: "오늘의 상대", pro?.currentRival?.profile ?: "상대 분석을 확인합니다."),
                    Phase8Row("기록", "${pro?.activePitch?.pitches ?: 0}구 · ${pro?.activePitch?.strikeouts ?: 0}탈삼진", "중요 경기의 저장된 기록"),
                    Phase8Row("상태", state.pitch?.boundary?.let { pitchBoundaryLabel(it) } ?: "준비 전", "던진 공의 결과와 다음 승부를 확인합니다."),
                )))
                val reusable = state.pitch == null || state.pitch?.boundary in setOf(PitchBoundary.COMPLETED, PitchBoundary.ABANDONED)
                val canOpenProImportantGame = pro?.phase == ProCareerPhase.IMPORTANT_GAME && pro.activePitch == null && reusable
                val canOpenNextPitch = pro?.phase == ProCareerPhase.IMPORTANT_GAME && state.pitch?.boundary in setOf(PitchBoundary.COMPLETED, PitchBoundary.ABANDONED) && pro.activePitch != null && pro.activePitch?.ended == false
                val canFinishGame = (pro?.phase == ProCareerPhase.IMPORTANT_GAME && pro.activePitch?.ended == true) || state.pitch?.boundary == PitchBoundary.TERMINAL
                val proFinishCommands = mutableListOf<GameCommand>()
                if (pro?.activePitch?.ended == true) proFinishCommands += pro(ProCommand.FinishImportantGame)
                if (state.pitch?.boundary == PitchBoundary.TERMINAL) proFinishCommands += GameCommand.CompletePitch(requireNotNull(state.pitch).sessionId)
                addAction("openProImportantGame", "프로 승부처 열기", "프로 중요 경기의 투구를 엽니다.", canOpenProImportantGame, if (canOpenProImportantGame) proImportantGameCommands(state, context) else emptyList())
                addAction("nextProPitch", "다음 타석 열기", "같은 경기의 다음 타석을 엽니다.", canOpenNextPitch, if (canOpenNextPitch) nextProPitchCommands(state) else emptyList())
                addAction("finishProGame", "경기 결과 확인", "승부처 경기를 마무리하고 결산합니다.", canFinishGame, proFinishCommands)
                val canResumePitch = state.pitch?.boundary in setOf(PitchBoundary.PLAYING, PitchBoundary.SUSPENDED)
                addAction("resumePitch", "투구 이어 하기", "저장한 투구를 이어 합니다.", canResumePitch, listOfNotNull(state.pitch?.takeIf { it.boundary == PitchBoundary.SUSPENDED }?.let { GameCommand.ResumePitch(it.sessionId) }))
                addAction("abandonPitch", "이번 투구 포기", "이번 타석만 포기합니다.", state.pitch?.boundary in setOf(PitchBoundary.RESERVED, PitchBoundary.PLAYING, PitchBoundary.SUSPENDED), listOfNotNull(state.pitch?.let { GameCommand.AbandonPitch(it.sessionId, "사용자가 투구를 포기함") }), true)
            }
            Phase8ScreenId.P019_PRO_SEASON -> {
                val tournament = pro?.nationalTournament
                val settlement = pro?.journeyState?.lastSettlement
                when {
                    pro?.phase == ProCareerPhase.SEASON_SETTLEMENT && settlement != null -> {
                        val stats = pro.careerStats.lastOrNull { it.season == settlement.season } ?: pro.currentStats
                        val innings = stats.inningsOuts / 3
                        val money = { value: Long -> "%,d원".format(java.util.Locale.KOREA, value) }
                        val reasonRows = settlement.fanReasons.map { reason ->
                            Phase8Row(
                                fanReasonLabel(reason.kind),
                                "${if (reason.delta >= 0) "+" else ""}${reason.delta}",
                                reason.contentId,
                            )
                        }
                        addSection(Phase8Section("season-settlement", "시즌 리뷰", listOf(
                            Phase8Row("시즌", settlement.season.toString(), settlementNextRouteLabel(settlement.nextRoute)),
                            Phase8Row("성적", "${stats.games}경기 · ${innings}이닝 · ${stats.strikeouts}탈삼진", "9이닝당 실점 ${"%.2f".format(java.util.Locale.ROOT, stats.runPerNinePermille / 1_000.0)}"),
                            Phase8Row("연봉", money(settlement.salaryIncome), "이번 시즌 계약에서 들어온 금액입니다."),
                            Phase8Row("응원상품", money(settlement.merchandiseIncome), settlement.merchandiseTier?.let { merchandiseTierLabel(it) } ?: "팬 지지에 따른 상품 수입"),
                            Phase8Row("팬 지지", "${settlement.fanBefore} → ${settlement.fanAfter}", "시즌 변화 ${if (settlement.fanDelta >= 0) "+" else ""}${settlement.fanDelta}"),
                            Phase8Row("구단 유산", "${settlement.teamLegacyBefore} → ${settlement.teamLegacyAfter}", "명예의 전당 예상 ${settlement.hallOfFameBefore} → ${settlement.hallOfFameAfter}"),
                            Phase8Row("잔여 계약", "${settlement.contractYearsBefore}년 → ${settlement.contractYearsAfter}년", settlementNextRouteLabel(settlement.nextRoute)),
                        ) + reasonRows))
                        addAction(
                            "acknowledgeSettlement",
                            "결산 확인",
                            "결산을 확인하고 다음 국면으로 갑니다.",
                            true,
                            listOf(pro(ProCommand.AcknowledgeSeasonSettlement(context.seed(state, "season-settlement"), settlement.id))),
                        )
                    }
                    pro?.phase == ProCareerPhase.NATIONAL_TEAM_CALL -> {
                        val fan = pro.journeyState?.reputation?.fanSupport ?: 0
                        val market = (pro.pitcher.stuff + pro.pitcher.command + pro.pitcher.movement + pro.pitcher.stamina) / 4
                        addSection(Phase8Section("national-call", "국가대표 소집 통보", listOf(
                            Phase8Row("국가대표", "시즌 성적이 대표팀 레이더에 걸렸습니다.", "수락하면 조별 3경기를 치르고 결승은 직접 등판합니다."),
                            Phase8Row("선발 이유", "시장 점수 $market · 팬 지지 $fan", "짝수 시즌, 31세 이하, 팬 지지나 수상·기량이 기준을 넘을 때 소집됩니다."),
                            Phase8Row("대가", "다음 스프링캠프를 피로를 안고 시작합니다.", "결승에서 많이 던질수록 무겁고, 부상 판정도 한 번 있습니다."),
                        )))
                        addAction(
                            "nationalTeam:accept",
                            "소집을 수락한다",
                            "조별 3경기를 치르고 결승은 직접 등판합니다.",
                            true,
                            listOf(pro(ProCommand.RespondNationalTeamCall(context.seed(state, "national-team:accept"), true))),
                        )
                        addAction(
                            "nationalTeam:decline",
                            "이번엔 사양한다",
                            "소집을 거절하고 비시즌으로 갑니다. 팬 지지가 조금 내려갑니다.",
                            true,
                            listOf(pro(ProCommand.RespondNationalTeamCall(context.seed(state, "national-team:decline"), false))),
                        )
                    }
                    pro?.phase == ProCareerPhase.NATIONAL_TOURNAMENT && tournament != null -> {
                        val groupRows = tournament.groupGames.map { line ->
                            Phase8Row(
                                ProNationalTeamRules.opponentLabel(line.opponentId),
                                "${line.teamRuns}-${line.opponentRuns} ${if (line.won) "승" else "패"}",
                                "조별 ${line.gameNumber}경기",
                            )
                        }
                        addSection(
                            Phase8Section(
                                "national-group",
                                "환태평양 초청 대회",
                                groupRows + listOf(
                                    Phase8Row(
                                        "조별 성적",
                                        "${tournament.groupWins}승 ${tournament.groupGames.size}경기",
                                        if (tournament.stage == ProNationalTournamentStage.AWAITING_FINAL) {
                                            "2승 이상으로 결승에 올랐습니다. 결승은 직접 등판입니다."
                                        } else {
                                            tournament.result?.let(ProNationalTeamRules::resultLabel) ?: "대회 진행 중"
                                        },
                                    ),
                                ),
                            ),
                        )
                        if (tournament.stage == ProNationalTournamentStage.AWAITING_FINAL && tournament.result == null) {
                            addAction(
                                "nationalTeam:startFinal",
                                "결승 직접 등판",
                                "대표팀 결승에 직접 올라 슬라이더로 던집니다.",
                                true,
                                listOf(pro(ProCommand.StartNationalFinal(context.seed(state, "national-team:start-final")))),
                            )
                        }
                        tournament.result?.let { outcome ->
                            addSection(
                                Phase8Section(
                                    "national-result",
                                    "대회 결과",
                                    listOfNotNull(
                                        Phase8Row(ProNationalTeamRules.resultLabel(outcome), ProNationalTeamRules.news(outcome), "팬 지지 ${if (tournament.fanDelta >= 0) "+" else ""}${tournament.fanDelta}"),
                                        if (tournament.exempted) Phase8Row("병역", "병역 면제 처리됐습니다.", "금메달 한 번으로 복무를 마칩니다.") else null,
                                    ),
                                ),
                            )
                            addAction(
                                "nationalTeam:acknowledge",
                                "오프시즌으로",
                                "대회 결과를 확인하고 비시즌 선택으로 갑니다.",
                                true,
                                listOf(pro(ProCommand.AcknowledgeNationalTeamResult(context.seed(state, "national-team:acknowledge")))),
                            )
                            CareerShareCopy.nationalMedal(state)?.let { share ->
                                addSection(Phase8Section("national-share", "공유", listOf(
                                    Phase8Row("대회 기록", share, "대표팀 결과를 글로 남깁니다."),
                                )))
                            }
                        }
                    }
                    else -> {
                        addSection(Phase8Section("pro-season", "프로 시즌", listOf(
                            Phase8Row("시즌", pro?.season?.toString() ?: "—", ProCatalog.segmentLabel(pro?.seasonSegment ?: ProSeasonSegment.SPRING_CAMP)),
                            Phase8Row("개인 기록", "${pro?.currentStats?.games ?: 0}경기 · ${pro?.currentStats?.strikeouts ?: 0}탈삼진", "현재 시즌 성적"),
                            Phase8Row("팀 순위", "${pro?.standings?.firstOrNull { it.isPlayerTeam }?.wins ?: 0}승", "리그 순위와 리더보드"),
                            Phase8Row("수상과 이정표", "${pro?.awards?.size ?: 0} · ${pro?.milestones?.size ?: 0}", "결정 기록 ${pro?.decisionHistory?.size ?: 0}개"),
                            Phase8Row("다음 이야기", pro?.pendingDecision?.title ?: "다음 주간 계획", pro?.pendingDecision?.detail ?: "저장된 시즌 흐름을 이어 갑니다."),
                        )))
                        pro?.pendingDecision?.let { decision ->
                            decision.choices.forEach { choice ->
                                addAction("seasonDecision:${choice.id}", choice.title, choice.detail, pro.phase == ProCareerPhase.SEASON_DECISION, listOf(pro(ProCommand.ApplySeasonDecision(context.seed(state, "decision:${choice.id}"), decision.id, choice.id))))
                            }
                        }
                        addAction("reviewSeason", "시즌 결산 보기", "이번 시즌의 기록과 다음 결정을 저장합니다.", pro?.phase == ProCareerPhase.SEASON_REVIEW, listOf(pro(ProCommand.ReviewSeason(context.seed(state, "season-review")))))
                    }
                }
            }
            Phase8ScreenId.P020_OFFSEASON -> {
                if (pro?.phase == ProCareerPhase.OFFSEASON_INVESTMENT) {
                    val funds = pro.journeyState?.finances?.availableFunds ?: 0L
                    addSection(Phase8Section("offseason-investment", "비시즌 투자", listOf(
                        Phase8Row("가용 자금", "%,d원".format(java.util.Locale.KOREA, funds), "다음 시즌을 앞두고 어디에 쓸지 고릅니다."),
                        Phase8Row("피치랩", "5천만원", "능력 포커스를 정해 다음 시즌 헤드스타트를 얻습니다."),
                        Phase8Row("리커버리", "4천만원", "부상 위험을 한 시즌 완화합니다."),
                        Phase8Row("팬 재단", "3천만원", "팬과 커뮤니티에 남깁니다."),
                    )))
                    val enabled = true
                    addAction(
                        "investment:pitch_lab",
                        "피치랩",
                        "제구를 중심으로 다음 시즌을 한 발 앞서 시작합니다.",
                        enabled && funds >= 50_000_000L,
                        listOf(pro(ProCommand.ChooseInvestment(context.seed(state, "investment:pitch_lab"), ProOffseasonInvestment.PITCH_LAB, ProDevelopmentFocus.COMMAND))),
                    )
                    addAction(
                        "investment:recovery_team",
                        "리커버리 팀",
                        "다음 시즌 부상 위험을 줄입니다.",
                        enabled && funds >= 40_000_000L,
                        listOf(pro(ProCommand.ChooseInvestment(context.seed(state, "investment:recovery_team"), ProOffseasonInvestment.RECOVERY_TEAM, null))),
                    )
                    addAction(
                        "investment:fan_foundation",
                        "팬 재단",
                        "팬 기반을 남기고 다음 시즌으로 갑니다.",
                        enabled && funds >= 30_000_000L,
                        listOf(pro(ProCommand.ChooseInvestment(context.seed(state, "investment:fan_foundation"), ProOffseasonInvestment.FAN_FOUNDATION, null))),
                    )
                    addAction(
                        "investment:none",
                        "이번엔 안 한다",
                        "돈을 아껴 두고 다음 시즌 주간으로 갑니다.",
                        enabled,
                        listOf(pro(ProCommand.ChooseInvestment(context.seed(state, "investment:none"), ProOffseasonInvestment.NONE, null))),
                    )
                } else {
                addSection(Phase8Section("offseason", "비시즌 선택", listOf(
                    Phase8Row("현재 계약", "${pro?.contract?.yearsRemaining ?: 0}년", "계속하기와 새로운 선택을 비교합니다."),
                    Phase8Row("복무", "${pro?.serviceYears ?: 0}년", if (pro?.militaryCompleted == true) "완료" else "선택 가능"),
                )))
                val offseasonEnabled = pro?.phase == com.solkim.baseball.core.pro.ProCareerPhase.OFFSEASON_DECISION
                val faEligible = (pro?.serviceYears ?: 0) >= 6 && (pro?.contract?.yearsRemaining ?: 0) == 0
                addAction(
                    "offseason:continue",
                    "계속하기",
                    "현재 구단에 남아 다음 시즌을 준비합니다. 나이와 계약만 한 해 진행됩니다.",
                    offseasonEnabled,
                    listOf(pro(ProCommand.ChooseOffseason(context.seed(state, "offseason:continue"), OffseasonDecision.CONTINUE))),
                )
                addAction(
                    "offseason:military_service",
                    "군 복무",
                    "두 시즌 동안 계약을 멈추고 복무를 다녀옵니다. 한 번만 선택할 수 있습니다.",
                    offseasonEnabled && pro?.militaryCompleted != true,
                    listOf(pro(ProCommand.ChooseOffseason(context.seed(state, "offseason:military_service"), OffseasonDecision.MILITARY_SERVICE))),
                )
                addAction(
                    "offseason:free_agency",
                    "FA 시장",
                    "계약이 끝난 뒤에만 새 팀과 계약할 수 있습니다. 1군 6년이 필요합니다.",
                    offseasonEnabled && faEligible,
                    listOf(pro(ProCommand.ChooseOffseason(context.seed(state, "offseason:free_agency"), OffseasonDecision.FREE_AGENCY))),
                )
                addAction(
                    "offseason:retire",
                    "은퇴하기",
                    "여기서 커리어를 마칩니다. 통산 기록과 명예의 전당 점수가 확정됩니다. 되돌릴 수 없습니다.",
                    offseasonEnabled,
                    listOf(pro(ProCommand.ChooseOffseason(context.seed(state, "offseason:retire"), OffseasonDecision.RETIRE))),
                    destructive = true,
                )
                }
            }
            Phase8ScreenId.P021_PRO_RETIREMENT -> {
                addSection(Phase8Section("retirement", "은퇴", listOf(
                    Phase8Row("나이", pro?.age?.toString() ?: "—", "커리어의 마지막 계절을 맞이합니다."),
                    Phase8Row("통산", "${pro?.careerGames() ?: 0}경기 · ${pro?.careerStrikeouts() ?: 0}탈삼진", "시즌 기록과 수상 이력"),
                    Phase8Row("다음", "프로 유산", "마지막 선택 뒤 기록을 남깁니다."),
                )))
                addAction("retire", "은퇴하고 기록 남기기", "프로 커리어를 마치고 유산 후보를 엽니다.", pro?.phase == ProCareerPhase.RETIREMENT_DECISION, listOf(pro(ProCommand.ChooseOffseason(context.seed(state, "retire"), OffseasonDecision.RETIRE))), destructive = true)
            }
            Phase8ScreenId.P022_PRO_LEGACY -> {
                addSection(Phase8Section("pro-legacy", "프로 유산", (pro?.legacyCandidates.orEmpty().map { candidate -> Phase8Row(candidate.title, candidate.evidenceSummary, candidate.farewell) } + listOf(Phase8Row("다음 생에 남길 것", "프로에서 남긴 유산", "이번 선수의 기억을 다음 생으로 이어 갑니다.")))))
                pro?.legacyCandidates.orEmpty().forEach { candidate -> addAction("selectProLegacy:${candidate.id}", candidate.title, "이 유산을 선택합니다.", pro?.phase == ProCareerPhase.LEGACY_SELECTION, listOf(pro(ProCommand.SelectLegacy(candidate.id)))) }
            }
            Phase8ScreenId.P024_WEEKLY -> {
                val weekly = highSchool?.weekly
                val taskRows = weekly?.tasks.orEmpty().map { task ->
                    Phase8Row(
                        weeklyTaskTitle(task.kind),
                        "${task.progress}/${task.target}${if (task.completed) " · 완료" else ""}",
                        if (task.completed) "이번 주 과제를 채웠습니다." else "훈련과 경기가 이 숫자를 올립니다.",
                    )
                }
                val stampRows = weekly?.stamps.orEmpty().takeLast(6).map { stamp ->
                    Phase8Row(
                        stamp.weekKey,
                        if (stamp.perfect) "완벽 도장" else "도장 ${stamp.completedTaskCount}",
                        "주간 노트를 이어 온 기록입니다.",
                    )
                }
                addSection(Phase8Section("weekly", "주간 야구 노트", listOf(
                    Phase8Row("이번 주", weekly?.weekKey ?: "기록 없음", "훈련과 경기의 작은 목표"),
                    Phase8Row("과제", "${weekly?.tasks?.count { it.completed } ?: 0}/${weekly?.tasks?.size ?: 0}", "완료한 과제"),
                    Phase8Row("도장", weekly?.stamps?.size?.toString() ?: "0", "꾸준히 쌓이는 기록"),
                    Phase8Row("보상", if (weekly?.rewardClaimed == true) "받음" else "받기 전", "한 번 받은 보상은 다시 지급되지 않습니다."),
                ) + taskRows + stampRows))
                addAction("claimWeeklyReward", "보상 받기", "이번 주 보상을 받습니다.", weekly?.rewardClaimed == false && weekly.tasks.any { it.completed }, listOf(hs(HighSchoolPhase4Command.ClaimWeeklyReward)))
            }
            Phase8ScreenId.P025_RECORDS_LEAGUE -> {
                if (state.canEnterPlayerSetup()) addAction("enterSetup", "새로운 야구 인생 시작", "남긴 기록과 야구혼을 간직하고 다음 선수로 시작합니다.", true, listOf(GameCommand.EnterSetup))
                state.meta.retiredProCareers.filter { state.meta.seedChallenge == null && it.careerId != pro?.careerId }.asReversed().forEach { retired ->
                    addSection(Phase8Section("retired:${retired.careerId}", retired.identityName, listOf(
                        Phase8Row("프로 통산", "${retired.careerStats.size}시즌 · ${retired.careerGames()}경기 · ${retired.careerStrikeouts()}탈삼진"),
                        Phase8Row("남긴 유산", retired.legacyCandidates.firstOrNull { it.id == retired.selectedLegacyId }?.title ?: "기억"),
                        Phase8Row("명예의 전당", "${retired.hallOfFameScore ?: 0}"),
                    )))
                }
                val standings = pro?.standings.orEmpty().take(5)
                addSection(Phase8Section("records", "기록과 순위", listOf(
                    Phase8Row("고교 기록", "${run?.performance?.pitches ?: 0}구 · ${run?.performance?.strikeouts ?: 0}탈삼진", "이번 생의 투구 기록"),
                    Phase8Row("프로 기록", "${pro?.careerGames() ?: 0}경기 · ${pro?.careerStrikeouts() ?: 0}탈삼진", "프로 통산 ${pro?.careerStats?.size ?: 0}시즌"),
                    Phase8Row("보관 기록", "${highSchool?.archive?.size ?: 0}회", "선택한 생의 기록만 카드로 남깁니다."),
                ) + standings.map { row ->
                    Phase8Row("${row.rank}위 ${row.teamName}", "${row.wins}승 ${row.losses}패", if (row.isPlayerTeam) "내 구단" else "리그 순위")
                }))
            }
            Phase8ScreenId.P026_ACHIEVEMENTS -> {
                val unlocked = highSchool?.achievements.orEmpty()
                val pending = highSchool?.unacknowledgedAchievements.orEmpty()
                val legacyOnly = setOf(HighSchoolAchievementRules.MAJOR_DEBUT, HighSchoolAchievementRules.HUNDRED_STRIKEOUTS, HighSchoolAchievementRules.HALL_OF_FAME)
                addSection(Phase8Section("achievements", "업적", HighSchoolAchievementRules.all.filter { it !in legacyOnly || it in unlocked }.map { achievement ->
                    Phase8Row(
                        achievementTitle(achievement),
                        when {
                            achievement in pending -> "새 기록"
                            achievement in unlocked -> "확인함"
                            else -> "잠김"
                        },
                        achievementDescription(achievement),
                    )
                }))
                pending.forEach { achievement -> addAction("ack:$achievement", "${achievementTitle(achievement)} 확인", "새 업적을 확인합니다.", true, listOf(hs(HighSchoolPhase4Command.AcknowledgeAchievement(achievement)))) }
            }
            Phase8ScreenId.P027_SETTINGS -> {
                addSection(Phase8Section("settings", "플레이 방식", listOf(
                    Phase8Row("자동 릴리스", boolLabel(state.settings.autoReleaseEnabled), "자동 릴리스는 접근성 보조입니다. 기본 투구는 길게 눌러 와인드업입니다."),
                    Phase8Row("소리와 음악", "${boolLabel(state.settings.soundEnabled)} · ${boolLabel(state.settings.musicEnabled)}", "경기 분위기"),
                    Phase8Row("진동", boolLabel(state.settings.hapticsEnabled), "선택과 결과의 손맛"),
                    Phase8Row("알림", boolLabel(state.settings.notificationsEnabled), "복귀 안내"),
                    Phase8Row("접근성", "고대비 ${boolLabel(state.settings.highContrastEnabled)} · 모션 ${if (state.settings.reducedMotionEnabled) "줄임" else "기본"}", "읽기 편한 화면"),
                    Phase8Row("진행 삭제", "첫 화면으로 돌아갑니다", "저장된 커리어와 투구를 지우고 새로 시작합니다. 되돌릴 수 없습니다."),
                )))
                addAction("toggleAutoRelease", if (state.settings.autoReleaseEnabled) "자동 릴리스 끄기" else "자동 릴리스 켜기", "자동 릴리스 설정을 저장합니다.", true, listOf(settingsCommand(state) { it.copy(autoReleaseEnabled = !it.autoReleaseEnabled) }))
                addAction("toggleSound", if (state.settings.soundEnabled) "소리 끄기" else "소리 켜기", "소리 설정을 저장합니다.", true, listOf(settingsCommand(state) { it.copy(soundEnabled = !it.soundEnabled) }))
                addAction("toggleMusic", if (state.settings.musicEnabled) "음악 끄기" else "음악 켜기", "음악 설정을 저장합니다.", true, listOf(settingsCommand(state) { it.copy(musicEnabled = !it.musicEnabled) }))
                addAction("toggleHaptics", if (state.settings.hapticsEnabled) "진동 끄기" else "진동 켜기", "진동 설정을 저장합니다.", true, listOf(settingsCommand(state) { it.copy(hapticsEnabled = !it.hapticsEnabled) }))
                addAction("toggleContrast", if (state.settings.highContrastEnabled) "고대비 끄기" else "고대비 켜기", "고대비 화면 설정을 저장합니다.", true, listOf(settingsCommand(state) { it.copy(highContrastEnabled = !it.highContrastEnabled) }))
                addAction("toggleMotion", if (state.settings.reducedMotionEnabled) "기본 모션 사용" else "모션 줄이기", "화면 움직임 설정을 저장합니다.", true, listOf(settingsCommand(state) { it.copy(reducedMotionEnabled = !it.reducedMotionEnabled) }))
                addSection(Phase8Section("glossary", "용어집", BaseballGlossary.terms.map { term ->
                    Phase8Row(term.name, term.definition)
                }))
                if (state.meta.seedChallenge == null) addAction("resetProgress", "진행 삭제", "저장된 진행을 지우고 첫 화면으로 돌아갑니다.", true, listOf(GameCommand.ResetProgress), destructive = true)
            }
            Phase8ScreenId.P028_LIFECARD -> {
                val card = Phase9LifeCardProjection.selected(state)
                addSection(Phase8Section("life-card", "라이프 카드", if (card == null) listOf(
                    Phase8Row("보관된 생", "아직 없음", "한 생의 기록을 남기면 나만의 카드를 만들 수 있습니다."),
                ) else card.lines.map { line -> Phase8Row("보관된 기록", line) } + listOf(
                    Phase8Row("공유", "카드와 글 함께 준비", "카드 이미지와 글을 함께 공유합니다."),
                )))
            }
            Phase8ScreenId.P029_RETURN_PLAN -> {
                addSection(Phase8Section("return-plan", "복귀 계획", listOf(
                    Phase8Row("다음 목적지", highSchool?.returnPlan?.destination?.label ?: "아직 없음", "잠깐 쉬고 돌아올 위치"),
                    Phase8Row("안내", highSchool?.returnPlan?.reason ?: "복귀 계획을 준비해 보세요.", "다음 날의 안내는 저장된 계획을 따릅니다."),
                    Phase8Row("알림", "기기 권한 확인 필요", "권한을 허용한 경우에만 복귀 안내를 예약합니다."),
                )))
                addAction("prepareReturnPlan", "복귀 계획 준비", "복귀 계획을 저장합니다.", highSchool != null, listOf(hs(HighSchoolPhase4Command.PrepareReturnPlan(context.dayKey(state), HighSchoolContentCatalog.WORLD_RULES_VERSION))))
                addAction("dismissReturnPlan", "복귀 카드 닫기", "저장된 복귀 카드를 닫습니다.", highSchool?.returnPlan?.dismissed == false, listOf(hs(HighSchoolPhase4Command.DismissReturnPlan)))
            }
            Phase8ScreenId.P030_REVIEW -> {
                addSection(Phase8Section("review", "리뷰", listOf(
                    Phase8Row("나의 야구 이야기", "플레이는 어떠셨나요?", "남겨 주신 의견은 다음 이야기를 더 즐겁게 만드는 데 도움이 됩니다."),
                )))
            }
        }

        if (id == Phase8ScreenId.P017_PRO_WEEK) actions.sortBy { if (it.id.startsWith("proPlan:")) 0 else 1 }
        return Phase8ScreenModel(id, id.title, subtitle(id), sections, actions, Phase8Payloads.view(state, id))
    }

    private fun hs(command: HighSchoolPhase4Command): GameCommand = GameCommand.HighSchool(command)
    private fun pro(command: ProCommand): GameCommand = GameCommand.Pro(command)

    private fun subtitle(id: Phase8ScreenId): String = when (id) {
        Phase8ScreenId.P001_OPENING -> "환생 투수 커리어의 첫 장면입니다. 기본 투구는 투구 슬라이더입니다."
        Phase8ScreenId.P002_SETUP -> "이번 생의 이름과 지역을 고릅니다."
        Phase8ScreenId.P003_PROLOGUE -> "편지와 첫 사인을 따라 이야기를 시작합니다."
        Phase8ScreenId.P004_PITCH_TUTORIAL -> "내가 고른 투구를 공의 궤적으로 확인합니다."
        Phase8ScreenId.P005_SCHOOL_SELECTION -> "네 학교의 철학과 사람을 비교합니다."
        Phase8ScreenId.P006_TRAINING -> "다음 한 블록의 성장을 선택합니다."
        Phase8ScreenId.P007_RELATIONSHIP -> "짧은 대화가 다음 장면을 바꿉니다."
        Phase8ScreenId.P008_IMPORTANT_GAME -> "상황을 읽고 승부처에 오릅니다."
        Phase8ScreenId.P009_AWAKENING -> "내 투구의 새로운 감각을 깨웁니다."
        Phase8ScreenId.P010_CHAPTER -> "한 장을 돌아보고 다음 장을 엽니다."
        Phase8ScreenId.P011_HIGH_SCHOOL_CAREER -> "지금까지의 고교 기록을 한눈에 봅니다."
        Phase8ScreenId.P012_TOURNAMENT_LEAGUE -> "대회와 라이벌의 흐름을 확인합니다."
        Phase8ScreenId.P013_DRAFT -> "마지막 평가와 다음 길을 확인합니다."
        Phase8ScreenId.P014_RUN_RECAP -> "이번 생에 남은 기록과 유산을 고릅니다."
        Phase8ScreenId.P015_REBIRTH -> "남은 기억을 품고 다음 선수를 시작합니다."
        Phase8ScreenId.P016_PRO_CONTRACT -> "고교에서 이어 가거나 직접 프로를 시작합니다."
        Phase8ScreenId.P017_PRO_WEEK -> "여섯 계획 중 하나로 한 주를 보냅니다."
        Phase8ScreenId.P018_PRO_IMPORTANT_GAME -> "한 점 차 승부에서 다음 공을 직접 고릅니다."
        Phase8ScreenId.P019_PRO_SEASON -> "성장, 기록, 수상과 대표팀 결정을 돌아봅니다."
        Phase8ScreenId.P020_OFFSEASON -> "다음 시즌의 길을 선택합니다."
        Phase8ScreenId.P021_PRO_RETIREMENT -> "긴 커리어의 마지막을 준비합니다."
        Phase8ScreenId.P022_PRO_LEGACY -> "프로의 시간을 하나의 유산으로 남깁니다."
        Phase8ScreenId.P024_WEEKLY -> "이번 주의 작은 목표와 보상을 확인합니다."
        Phase8ScreenId.P025_RECORDS_LEAGUE -> "고교와 프로의 기록을 함께 봅니다."
        Phase8ScreenId.P026_ACHIEVEMENTS -> "커리어에서 쌓은 업적을 확인합니다."
        Phase8ScreenId.P027_SETTINGS -> "내가 편한 방식으로 경기를 조절합니다."
        Phase8ScreenId.P028_LIFECARD -> "선택한 생의 이야기를 카드로 돌아봅니다."
        Phase8ScreenId.P029_RETURN_PLAN -> "다음에 돌아올 장면을 준비합니다."
        Phase8ScreenId.P030_REVIEW -> "리뷰 안내가 필요한 순간을 확인합니다."
    }

    private fun achievementTitle(id: String): String = when (id) {
        HighSchoolAchievementRules.FIRST_DRAFT -> "첫 지명"
        HighSchoolAchievementRules.FIRST_STRIKEOUT -> "첫 탈삼진"
        HighSchoolAchievementRules.CLEAN_INNING -> "무실점 등판"
        HighSchoolAchievementRules.PERFECT_DELIVERY -> "정확한 투구"
        HighSchoolAchievementRules.MAJOR_DEBUT -> "첫 큰 무대"
        HighSchoolAchievementRules.HUNDRED_STRIKEOUTS -> "백 탈삼진"
        HighSchoolAchievementRules.THIRD_LIFE -> "세 번째 생"
        HighSchoolAchievementRules.FIFTH_LIFE -> "다섯 번째 생"
        HighSchoolAchievementRules.TENTH_LIFE -> "열 번째 생"
        HighSchoolAchievementRules.KARMA_RUN -> "이어진 마음"
        HighSchoolAchievementRules.DOUBLE_KARMA -> "두 겹의 마음"
        HighSchoolAchievementRules.AWAKENED_THRICE -> "세 번의 각성"
        HighSchoolAchievementRules.FOUR_SCHOOLS -> "네 학교의 기록"
        HighSchoolAchievementRules.FIVE_DRAFTS -> "다섯 번의 평가"
        HighSchoolAchievementRules.HALL_OF_FAME -> "명예의 기록"
        else -> "새로운 업적"
    }

    private fun achievementDescription(id: String): String = when (id) {
        HighSchoolAchievementRules.FIRST_DRAFT -> "드래프트에서 처음으로 지명을 받으세요."
        HighSchoolAchievementRules.FIRST_STRIKEOUT -> "타자를 삼진으로 잡으세요."
        HighSchoolAchievementRules.CLEAN_INNING -> "직접 등판한 경기를 무실점으로 마치세요."
        HighSchoolAchievementRules.PERFECT_DELIVERY -> "조준과 타이밍 정확도를 모두 90% 이상 맞히세요."
        HighSchoolAchievementRules.THIRD_LIFE -> "세 번째 선수로 새 삶을 시작하세요."
        HighSchoolAchievementRules.FIFTH_LIFE -> "다섯 번째 선수로 새 삶을 시작하세요."
        HighSchoolAchievementRules.TENTH_LIFE -> "열 번째 선수로 새 삶을 시작하세요."
        HighSchoolAchievementRules.KARMA_RUN -> "핸디캡을 적용하고 고교 과정을 마치세요."
        HighSchoolAchievementRules.DOUBLE_KARMA -> "핸디캡 2개를 적용하고 고교 과정을 마치세요."
        HighSchoolAchievementRules.AWAKENED_THRICE -> "한 선수로 각성을 세 번 선택하세요."
        HighSchoolAchievementRules.FOUR_SCHOOLS -> "서로 다른 유형의 학교 네 곳에서 선수 생활을 마치세요."
        HighSchoolAchievementRules.FIVE_DRAFTS -> "드래프트 지명을 받은 선수 다섯 명의 기록을 남기세요."
        else -> ""
    }

    private fun legacyEffect(id: String): String = runCatching {
        val effect = HighSchoolSignatureLegacyRules.definition(id)
        listOf("구위" to effect.stuff, "제구" to effect.command, "무브먼트" to effect.movement, "체력" to effect.stamina)
            .filter { it.second > 0 }.sortedByDescending { it.second }.joinToString(" · ") { (label, amount) -> "$label ${if (amount >= 3) "중심" else if (amount == 2) "강화" else "보조"}" }
    }.getOrDefault("")

    private fun legacyTitle(id: String): String = runCatching {
        HighSchoolSignatureLegacyRules.definition(id).title
    }.getOrDefault("남겨진 유산")

    private fun boolLabel(value: Boolean): String = if (value) "켜짐" else "꺼짐"
    public fun reviewTrigger(state: GameAggregateState): String? {
        val run = state.highSchool?.run ?: return null
        val recapReady = run.phase == HighSchoolPhase.LEGACY || run.phase == HighSchoolPhase.COMPLETED
        val draftedReceipt = "review-moment:${run.careerId}:drafted-reveal-confirmed"
        val recapReceipt = "review-moment:${run.careerId}:good-recap"
        val draftedMoment = state.analytics.receipts.firstOrNull { it.receiptId == draftedReceipt && it.eventName == "review_moment_drafted_reveal_confirmed" }
        val recapMoment = state.analytics.receipts.firstOrNull { it.receiptId == recapReceipt && it.eventName == "review_moment_good_recap" }
        val hasThirdLifeStart = state.analytics.receipts.any { receipt ->
            receipt.eventName == "rebirth_started" &&
                receipt.properties.any { (key, value) -> key == "life_number" && value == run.lifeNumber.toString() }
        }
        return when {
            recapReady && run.draftResult?.outcome == HighSchoolDraftOutcome.DRAFTED && draftedMoment != null &&
                (recapMoment == null || draftedMoment.revision >= recapMoment.revision) -> "drafted-reveal-confirmed"
            recapReady && recapDeservesReview(state) && recapMoment != null &&
                (draftedMoment == null || recapMoment.revision > draftedMoment.revision) -> "good-recap"
            run.phase == HighSchoolPhase.PROLOGUE && run.lifeNumber >= 3 && hasThirdLifeStart -> "third-life"
            else -> null
        }
    }

    /** Mirrors the current iOS recapDeservesReview rule with only facts in the Kotlin archive. */
    public fun recapDeservesReview(state: GameAggregateState): Boolean {
        val highSchool = state.highSchool ?: return false
        val run = highSchool.run
        if (run.phase != HighSchoolPhase.LEGACY && run.phase != HighSchoolPhase.COMPLETED) return false
        val record = highSchool.archive.firstOrNull { it.careerId == run.careerId }
        if (record?.drafted == true || run.draftResult?.outcome == HighSchoolDraftOutcome.DRAFTED) return true
        if (record?.pledgeAchieved == true || highSchool.pledge?.achieved == true) return true
        val currentEvaluation = record?.draftEvaluation ?: run.draftResult?.evaluationScore ?: return false
        val previousBest = highSchool.archive
            .filterNot { it.careerId == run.careerId }
            .maxOfOrNull { it.draftEvaluation } ?: 0
        return currentEvaluation > previousBest
    }

    private fun reviewReason(state: GameAggregateState): String? = when (reviewTrigger(state)) {
        "third-life" -> "세 번째 생의 결산"
        "good-recap" -> "좋은 결산"
        "drafted-reveal-confirmed" -> "드래프트 결과 공개"
        else -> null
    }

    private fun pitchBoundaryLabel(boundary: PitchBoundary): String = when (boundary) {
        PitchBoundary.RESERVED -> "투구 준비 완료"
        PitchBoundary.PLAYING -> "투구 진행 중"
        PitchBoundary.COMMITTED, PitchBoundary.CONSUMED, PitchBoundary.TERMINAL -> "투구 결과"
        PitchBoundary.COMPLETED -> "투구 완료"
        PitchBoundary.SUSPENDED -> "잠시 멈춤"
        PitchBoundary.ABANDONED -> "이번 투구를 포기함"
    }

    private fun tutorialSession(state: GameAggregateState): String = "phase8:tutorial:${state.highSchool?.run?.careerId ?: "career"}"

    private fun tutorialCommands(state: GameAggregateState, context: Phase8CommandContext): List<GameCommand> {
        val session = tutorialSession(state)
        return listOf(
            GameCommand.ReservePitch(session, PitchCareerKind.TUTORIAL, TUTORIAL_CAREER_ID, "tutorial", context.seed(state, "tutorial-pitch"), false),
            GameCommand.StartPitch(session),
        )
    }

    private fun importantGameCommands(state: GameAggregateState, context: Phase8CommandContext): List<GameCommand> {
        val highSchool = requireNotNull(state.highSchool)
        val seed = context.seed(state, "important-game")
        val reserved = HighSchoolPhase4Kernel().reserveImportantGame(seed, highSchool).state
        val active = requireNotNull(reserved.activePitch)
        return listOf(
            hs(HighSchoolPhase4Command.ReserveImportantGame(seed)),
            GameCommand.ReservePitch(active.sessionId, PitchCareerKind.HIGH_SCHOOL, highSchool.run.careerId, active.log.gameId, active.seed, highSchool.challenge.active),
            GameCommand.StartPitch(active.sessionId),
        )
    }

    private fun nextHighSchoolPitchCommands(state: GameAggregateState): List<GameCommand> {
        val highSchool = requireNotNull(state.highSchool)
        val active = requireNotNull(highSchool.activePitch)
        return listOf(
            GameCommand.ClearPitchPresentation(active.sessionId),
            GameCommand.ReservePitch(active.sessionId, PitchCareerKind.HIGH_SCHOOL, highSchool.run.careerId, active.log.gameId, active.seed, highSchool.challenge.active),
            GameCommand.StartPitch(active.sessionId),
        )
    }

    private fun proImportantGameCommands(state: GameAggregateState, context: Phase8CommandContext): List<GameCommand> {
        val pro = requireNotNull(state.pro)
        val seed = context.seed(state, "pro-important-game")
        val reserved = ProKernel().reserveImportantGame(pro, seed).state
        val active = requireNotNull(reserved.activePitch)
        return listOf(
            pro(ProCommand.ReserveImportantGame(seed)),
            GameCommand.ReservePitch(active.sessionId, PitchCareerKind.PRO, pro.careerId, active.log.gameId, active.seed, false),
            GameCommand.StartPitch(active.sessionId),
        )
    }

    private fun nextProPitchCommands(state: GameAggregateState): List<GameCommand> {
        val pro = requireNotNull(state.pro)
        val active = requireNotNull(pro.activePitch)
        return listOf(
            GameCommand.ClearPitchPresentation(active.sessionId),
            GameCommand.ReservePitch(active.sessionId, PitchCareerKind.PRO, pro.careerId, active.log.gameId, active.seed, false),
            GameCommand.StartPitch(active.sessionId),
        )
    }

    private fun settingsCommand(state: GameAggregateState, transform: (GameSettingsState) -> GameSettingsState): GameCommand =
        GameCommand.UpdateSettings(transform(state.settings))

    private fun linkedRequest(state: GameAggregateState, context: Phase8CommandContext): ProStartLinkedRequest {
        val run = requireNotNull(state.highSchool).run
        val pitcher = run.pitcher.toPitcherSnapshot()
        return ProStartLinkedRequest(
            seed = context.seed(state, "pro-linked"),
            highSchoolCareerId = run.careerId,
            pitchLearningProject = run.pitchLearningProject,
            identityName = run.identity.name,
            pitcher = pitcher,
            teamId = requireNotNull(run.draftResult?.teamId) { "pro.drafted_team_missing" },
            draftRound = run.draftResult?.round,
            signingBonus = run.draftResult?.signingBonus?.toLong(),
            overallPick = run.draftResult?.overallPick,
            sourceFanInterest = run.fanInterest,
            draftEvaluation = run.draftResult?.evaluationScore ?: 60,
            entitlement = ProEntitlement(),
            activeHighSchoolPreserved = true,
            highSchoolLegacyContext = ProHighSchoolLegacyContext(requireNotNull(state.highSchool).startingPitcher.toPitcherSnapshot(), pitcher, run.performance, run.selectedAwakenings.map { it.wire }, run.managerTrust, run.catcherTrust, run.rivalTrust),
        )
    }

    private fun com.solkim.baseball.core.highschool.HighSchoolPitcher.toPitcherSnapshot(): PitcherSnapshot = PitcherSnapshot(
        id = id,
        name = name,
        stuff = stuff,
        command = command,
        movement = movement,
        stamina = stamina,
        pitchProfiles = pitchProfiles.ifEmpty { listOf(PitchProfileSnapshot(PitchKind.FOUR_SEAM, PitchUsageRole.PRIMARY, 1_400, command, command, stuff, stuff, command, 1), PitchProfileSnapshot(PitchKind.SLIDER, PitchUsageRole.SECONDARY, 1_240, command, command, movement, movement, movement, 1)) },
        throwingHand = throwingHand,
        mastery = mastery,
    )

    private fun HighSchoolTrainingFocus.pitchKindOrNull(): PitchKind? = when (this) {
        HighSchoolTrainingFocus.VELOCITY -> PitchKind.FOUR_SEAM
        HighSchoolTrainingFocus.BREAKING_BALL -> PitchKind.SLIDER
        else -> null
    }

    private val HighSchoolTrainingFocus.label: String get() = when (this) {
        HighSchoolTrainingFocus.VELOCITY -> "구위"
        HighSchoolTrainingFocus.COMMAND -> "제구"
        HighSchoolTrainingFocus.BREAKING_BALL -> "무브먼트"
        HighSchoolTrainingFocus.STAMINA -> "체력"
        HighSchoolTrainingFocus.RECOVERY -> "회복"
        HighSchoolTrainingFocus.GAME_PLANNING -> "경기 계획"
    }

    private val HighSchoolAwakening.label: String get() = HighSchoolDisplayRules.awakeningTitle(wire)

    private val HighSchoolRelationshipTarget.label: String get() = when (this) {
        HighSchoolRelationshipTarget.COACH -> "코치"
        HighSchoolRelationshipTarget.CATCHER -> "포수"
        HighSchoolRelationshipTarget.RIVAL -> "라이벌"
    }

    private val HighSchoolRelationshipResponse.label: String get() = when (this) {
        HighSchoolRelationshipResponse.LISTEN -> "끝까지 듣기"
        HighSchoolRelationshipResponse.EXPLAIN -> "내 뜻 설명하기"
        HighSchoolRelationshipResponse.CHALLENGE -> "정면으로 부딪치기"
    }

    private fun relationshipSpeakerLabel(category: String?): String = when (category) {
        "coach" -> "감독"
        "catcher" -> "포수"
        "rival" -> "라이벌"
        "growth" -> "훈련"
        "health" -> "몸 상태"
        "team" -> "팀"
        "draft" -> "스카우트"
        "media" -> "취재"
        "fan" -> "팬"
        "game" -> "경기"
        "life" -> "일상"
        "awakening" -> "각성"
        "legacy" -> "기록"
        else -> "이야기"
    }

    private fun relationshipChoiceTitle(category: String?, response: HighSchoolRelationshipResponse): String = when (category) {
        "coach" -> when (response) {
            HighSchoolRelationshipResponse.LISTEN -> "감독의 말을 듣는다"
            HighSchoolRelationshipResponse.EXPLAIN -> "내 등판을 설명한다"
            HighSchoolRelationshipResponse.CHALLENGE -> "내 자리를 주장한다"
        }
        "catcher" -> when (response) {
            HighSchoolRelationshipResponse.LISTEN -> "포수의 사인을 듣는다"
            HighSchoolRelationshipResponse.EXPLAIN -> "내가 던지고 싶은 공을 말한다"
            HighSchoolRelationshipResponse.CHALLENGE -> "내 감각을 밀어붙인다"
        }
        "rival" -> when (response) {
            HighSchoolRelationshipResponse.LISTEN -> "라이벌의 말을 새긴다"
            HighSchoolRelationshipResponse.EXPLAIN -> "내 승부 방식을 말한다"
            HighSchoolRelationshipResponse.CHALLENGE -> "같은 코스로 답한다"
        }
        else -> response.label
    }

    private fun relationshipChoiceDetail(category: String?, response: HighSchoolRelationshipResponse): String = when (response) {
        HighSchoolRelationshipResponse.LISTEN -> when (category) {
            "coach" -> "감독의 기준을 끝까지 듣고 다음 준비를 맞춥니다."
            "catcher" -> "포수가 왜 그 사인을 냈는지부터 확인합니다."
            "rival" -> "상대의 말을 기억하고 다음 승부에 남깁니다."
            "health" -> "몸의 신호를 먼저 듣고 오늘은 참습니다."
            else -> "상대의 말을 끝까지 듣고 다음 기준을 함께 확인합니다."
        }
        HighSchoolRelationshipResponse.EXPLAIN -> when (category) {
            "coach" -> "왜 선발 또는 긴 이닝을 원하는지 기록으로 남깁니다."
            "catcher" -> "지금 던지고 싶은 공과 코스를 말로 맞춥니다."
            "draft" -> "무너진 경기 뒤 무엇을 바꿨는지 설명합니다."
            else -> "선택의 이유를 짧게 설명하고 다음 장면을 엽니다."
        }
        HighSchoolRelationshipResponse.CHALLENGE -> when (category) {
            "coach" -> "말로 설득하기보다 다음 등판의 결과로 답합니다."
            "rival" -> "같은 초구, 같은 코스로 승부를 받습니다."
            "health" -> "통증 소문보다 오늘 던질 공을 고릅니다."
            else -> "결과로 답하기로 하고 승부처로 갑니다."
        }
    }

    private fun importantGameSituation(scenario: com.solkim.baseball.core.highschool.HighSchoolGameScenario?): String {
        if (scenario == null) return "마운드에 오르기 전"
        val occupied = listOfNotNull(
            if (scenario.firstOccupied) "1루" else null,
            if (scenario.secondOccupied) "2루" else null,
            if (scenario.thirdOccupied) "3루" else null,
        )
        val bases = if (occupied.isEmpty()) "주자 없음" else occupied.joinToString(" · ")
        val score = scenario.scoreDifferential?.let { diff ->
            when {
                diff > 0 -> "${diff}점 앞"
                diff < 0 -> "${-diff}점 뒤"
                else -> "동점"
            }
        } ?: "점수 대기"
        return "${scenario.inning}회 · ${scenario.outs}아웃 · $bases · $score"
    }

    private fun contractKindLabel(kind: com.solkim.baseball.core.pro.ProContractKind): String = when (kind) {
        com.solkim.baseball.core.pro.ProContractKind.ROOKIE -> "신인 계약"
        com.solkim.baseball.core.pro.ProContractKind.RENEWAL_LONG -> "장기 재계약"
        com.solkim.baseball.core.pro.ProContractKind.PROVE_IT -> "증명 계약"
        com.solkim.baseball.core.pro.ProContractKind.FREE_AGENT -> "FA 계약"
        com.solkim.baseball.core.pro.ProContractKind.LONG_TERM -> "장기 계약"
    }

    private fun outlookLabel(outlook: com.solkim.baseball.core.pro.ProTeamOutlook): String = when (outlook) {
        com.solkim.baseball.core.pro.ProTeamOutlook.OPPORTUNITY -> "기회"
        com.solkim.baseball.core.pro.ProTeamOutlook.BALANCED -> "균형"
        com.solkim.baseball.core.pro.ProTeamOutlook.CONTENDER -> "우승 경쟁"
    }

    private val ProWeekPlan.label: String get() = iosTitle(null)

    private fun ProWeekPlan.iosTitle(pro: com.solkim.baseball.core.pro.ProState?): String {
        val relief = pro?.role != null && pro.role != ProRole.STARTER
        val veteran = (pro?.season ?: 1) >= 9
        val minor = pro?.level == ProLevel.MINOR
        return when (this) {
            ProWeekPlan.DEVELOP_STUFF -> when {
                relief -> "한 타자 강속구"
                veteran -> "포심 위력 다듬기"
                else -> "강속구 불펜"
            }
            ProWeekPlan.DEVELOP_MOVEMENT -> "결정구 완성"
            ProWeekPlan.REFINE_COMMAND -> "코스 제구 훈련"
            ProWeekPlan.BUILD_STAMINA -> if (relief) "연투 버티기" else "긴 이닝 루틴"
            ProWeekPlan.RECOVER -> if (veteran) "베테랑 회복 루틴" else "회복"
            ProWeekPlan.EARN_TRUST -> when {
                minor -> "콜업 경쟁 집중"
                relief -> "필승조 신뢰 쌓기"
                else -> "로테이션 신뢰 쌓기"
            }
            ProWeekPlan.DEVELOP_WEAPON -> "주무기 다듬기"
        }
    }

    private fun ProWeekPlan.iosDescription(pro: com.solkim.baseball.core.pro.ProState?): String {
        val fatigue = pro?.fatigue ?: 0
        val risk = when {
            this == ProWeekPlan.RECOVER -> "부상 위험 낮음"
            fatigue >= 90 -> "부상 위험 높음"
            fatigue >= 70 -> "부상 위험 주의"
            else -> "부상 위험 낮음"
        }
        val effect = when (this) {
            ProWeekPlan.DEVELOP_STUFF -> "구위·포심 구속·헛스윙 성장"
            ProWeekPlan.DEVELOP_MOVEMENT -> "변화구 결정구를 키웁니다"
            ProWeekPlan.REFINE_COMMAND -> "존 가장자리를 찌르는 제구"
            ProWeekPlan.BUILD_STAMINA -> "후반 체감 피로가 줄어듭니다"
            ProWeekPlan.RECOVER -> "이번 주 피로 20 회복"
            ProWeekPlan.EARN_TRUST -> "감독의 믿음을 쌓습니다"
            ProWeekPlan.DEVELOP_WEAPON -> "주무기의 완성도를 올립니다"
        }
        return "$effect. $risk"
    }

    private val OffseasonDecision.label: String get() = when (this) {
        OffseasonDecision.CONTINUE -> "계속하기"
        OffseasonDecision.MILITARY_SERVICE -> "복무 선택"
        OffseasonDecision.FREE_AGENCY -> "새 팀 찾기"
        OffseasonDecision.RETIRE -> "은퇴하기"
    }

    private val ProLevel.label: String get() = when (this) {
        ProLevel.MINOR -> "육성 리그"
        ProLevel.MAJOR -> "주전 리그"
    }

    private val ProRole.label: String get() = when (this) {
        ProRole.STARTER -> "선발"
        ProRole.LONG_RELIEF -> "롱릴리프"
        ProRole.SETUP -> "셋업"
        ProRole.CLOSER -> "마무리"
    }

    private val ProSeasonSegment.label: String get() = ProCatalog.segmentLabel(this)
    private val ProCareerPhase.label: String get() = when (this) {
        ProCareerPhase.CONTRACT_OFFER -> "계약 제안"
        ProCareerPhase.WEEKLY_PLAN -> "주간 계획"
        ProCareerPhase.SEASON_DECISION -> "시즌 결정"
        ProCareerPhase.IMPORTANT_GAME -> "중요 경기"
        ProCareerPhase.SEASON_REVIEW -> "시즌 결산"
        ProCareerPhase.SEASON_SETTLEMENT -> "시즌 리뷰"
        ProCareerPhase.NATIONAL_TEAM_CALL -> "대표팀 소집"
        ProCareerPhase.NATIONAL_TOURNAMENT -> "대표팀 대회"
        ProCareerPhase.OFFSEASON_DECISION -> "비시즌 선택"
        ProCareerPhase.OFFSEASON_INVESTMENT -> "비시즌 투자"
        ProCareerPhase.RETIREMENT_DECISION -> "은퇴 결정"
        ProCareerPhase.LEGACY_SELECTION -> "유산 선택"
        ProCareerPhase.COMPLETED -> "커리어 완료"
    }

    private fun settlementNextRouteLabel(route: ProSettlementNextRoute): String = when (route) {
        ProSettlementNextRoute.UNDER_CONTRACT -> "잔여 계약으로 다음 시즌을 맞습니다."
        ProSettlementNextRoute.RENEWAL_MARKET -> "재계약 시장이 열립니다."
        ProSettlementNextRoute.FREE_AGENCY_ELIGIBLE -> "FA 자격이 열립니다."
        ProSettlementNextRoute.FORCED_RETIREMENT -> "커리어의 마지막 결산입니다."
    }

    private fun merchandiseTierLabel(tier: ProMerchandiseTier): String = when (tier) {
        ProMerchandiseTier.LOCAL -> "지역 상품"
        ProMerchandiseTier.RISING -> "상승 상품"
        ProMerchandiseTier.STAR -> "스타 상품"
        ProMerchandiseTier.ICON -> "아이콘 상품"
    }

    private fun weeklyTaskTitle(kind: String): String = when (kind) {
        "daily_inning_completed", "daily-inning" -> "이닝을 마치기"
        "training_block", "train" -> "훈련 블록"
        "relationship" -> "관계를 고르기"
        "important_game", "important-game" -> "승부처에 오르기"
        else -> kind.ifBlank { "이번 주 과제" }
    }

    private fun fanReasonLabel(kind: ProFanReasonKind): String = when (kind) {
        ProFanReasonKind.IMPORTANT_GAME_SCORELESS -> "무실점 등판"
        ProFanReasonKind.IMPORTANT_GAME_RUNS_ALLOWED -> "실점 등판"
        ProFanReasonKind.SEASON_AWARD -> "시즌 수상"
        ProFanReasonKind.CAREER_MILESTONE -> "커리어 이정표"
        ProFanReasonKind.SAME_TEAM_SEASON -> "같은 구단에서 한 해"
        ProFanReasonKind.CONTRACT_EXPECTATION_MET -> "계약 목표 달성"
        ProFanReasonKind.CONTRACT_EXPECTATION_MISSED -> "계약 목표 미달"
        ProFanReasonKind.CAREER_AMBITION_COMPLETED -> "커리어 목표 달성"
    }
    private val HighSchoolPhase.label: String get() = when (this) {
        HighSchoolPhase.PROLOGUE -> "프롤로그"
        HighSchoolPhase.SCHOOL_SELECTION -> "학교 선택"
        HighSchoolPhase.TRAINING -> "훈련"
        HighSchoolPhase.RELATIONSHIP -> "관계"
        HighSchoolPhase.IMPORTANT_GAME -> "중요 경기"
        HighSchoolPhase.AWAKENING -> "각성"
        HighSchoolPhase.CHAPTER_REVIEW -> "장 결산"
        HighSchoolPhase.DRAFT -> "드래프트"
        HighSchoolPhase.LEGACY -> "유산"
        HighSchoolPhase.COMPLETED -> "완료"
    }
    private val HighSchoolReturnDestination.label: String get() = when (this) {
        HighSchoolReturnDestination.HIGH_SCHOOL -> "고교 커리어"
        HighSchoolReturnDestination.PRO -> "프로 커리어"
        // Daily is retired in the Compose product. Old saved return-plan values are rendered as
        // the current career destination; callers are normalized before they reach this shell.
        HighSchoolReturnDestination.DAILY_INNING -> "현재 커리어"
    }

    private fun ProWeekPlan.targetPitchOrNull(pro: com.solkim.baseball.core.pro.ProState?): PitchKind? = when (this) {
        ProWeekPlan.DEVELOP_MOVEMENT, ProWeekPlan.DEVELOP_WEAPON -> pro?.pitchLearningProject?.takeIf { !it.completed }?.pitchType ?: pro?.pitcher?.pitchProfiles?.firstOrNull { it.pitchType != PitchKind.FOUR_SEAM }?.pitchType
        else -> null
    }

    private val HighSchoolDraftOutcome.label: String get() = when (this) {
        HighSchoolDraftOutcome.DRAFTED -> "지명됨"
        HighSchoolDraftOutcome.UNDRAFTED -> "지명되지 않음"
    }
}

public object Phase8Payloads {
    public fun view(state: GameAggregateState, screenId: Phase8ScreenId): Phase8CommandPayload =
        payload(state, screenId, "view", GameCommand.RecordAnalytics("screen:${screenId.wire}:${state.revision}", "screen_view"))

    public fun batch(state: GameAggregateState, screenId: Phase8ScreenId, actionId: String, commands: List<GameCommand>): List<Phase8CommandPayload> =
        commands.mapIndexed { index, command -> payload(state, screenId, actionId, command, index) }

    /** Captures a product interaction as the same typed aggregate command as every button. */
    public fun analytics(
        state: GameAggregateState,
        screenId: Phase8ScreenId,
        actionId: String,
        eventName: String,
        scope: String,
        properties: List<Pair<String, String>> = emptyList(),
    ): Phase8CommandPayload = payload(
        state,
        screenId,
        actionId,
        GameCommand.RecordAnalytics(
            receiptId = Phase9AnalyticsProjector.receiptId(state.installId, eventName, scope),
            eventName = eventName,
            properties = properties,
        ),
    )

    public fun startHighSchool(state: GameAggregateState, context: Phase8CommandContext): GameCommand =
        startHighSchool(state, "민서준", "서울", "power_prospect", context)

    public fun startHighSchool(
        state: GameAggregateState,
        name: String,
        region: String,
        presetId: String,
        context: Phase8CommandContext,
        throwingHand: String = "right",
        karmas: List<String> = emptyList(),
        lifeNumber: Int = 1,
        difficulty: HighSchoolDifficulty = HighSchoolDifficulty(),
        soulDomain: com.solkim.baseball.core.highschool.HighSchoolSoulDomain = com.solkim.baseball.core.highschool.HighSchoolSoulDomain.TECHNIQUE,
        soulBoosts: List<com.solkim.baseball.core.highschool.HighSchoolSoulBoost> = emptyList(),
        primaryPitch: PitchKind = SetupRepertoire.primary(presetId),
        learningPitch: PitchKind = SetupRepertoire.learning(presetId),
    ): GameCommand {
        require(name.trim().isNotBlank()) { "phase8.setup.name" }
        require(region in HighSchoolContentCatalog.regions) { "phase8.setup.region" }
        require(HighSchoolContentCatalog.presets.any { it.id == presetId }) { "phase8.setup.preset" }
        require(throwingHand == "right" || throwingHand == "left") { "phase8.setup.hand" }
        val karmaEnums = karmas.map { wire ->
            HighSchoolKarma.entries.firstOrNull { it.wire == wire } ?: error("phase8.setup.karma")
        }
        if (state.highSchool != null) return GameCommand.HighSchool(HighSchoolPhase4Command.ConfigureRebirth(
            context.seed(state, "customize-rebirth"), context.dayKey(state), com.solkim.baseball.core.highschool.HighSchoolRebirthSetup(
                presetId = presetId, identity = HighSchoolIdentity(name = name.trim().take(12), throwingHand = throwingHand, region = region),
                difficulty = difficulty, karmas = karmaEnums, soulDomain = soulDomain, soulBoosts = soulBoosts,
                primaryPitch = primaryPitch, learningPitch = learningPitch,
            ),
        ))
        val initialRequest = HighSchoolPhase4StartRequest(
            seed = context.seed(state, "high-school-start"),
            presetId = presetId,
            stableUserId = state.installId,
            weekKey = context.weekKey(state),
            dayKey = context.dayKey(state),
            lifeNumber = lifeNumber.coerceAtLeast(1),
            identity = HighSchoolIdentity(name = name.trim().take(12), throwingHand = throwingHand, region = region),
            difficulty = difficulty,
            karmas = karmaEnums,
            inheritedSoulDomain = soulDomain.takeIf { state.meta.standaloneSoulBalance > 0 },
            soulBoosts = soulBoosts,
        )
        return GameCommand.HighSchool(HighSchoolPhase4Command.StartConfigured(initialRequest, primaryPitch, learningPitch))
    }

    private fun payload(state: GameAggregateState, screenId: Phase8ScreenId, actionId: String, command: GameCommand, offset: Int = 0): Phase8CommandPayload {
        val expectedRevision = state.revision + offset.toULong()
        val session = when (command) {
            is GameCommand.ReservePitch -> command.sessionId
            is GameCommand.StartPitch -> command.sessionId
            is GameCommand.CommitPitch -> command.sessionId
            is GameCommand.ConsumePitch -> command.sessionId
            is GameCommand.MarkPitchTerminal -> command.sessionId
            is GameCommand.CompletePitch -> command.sessionId
            is GameCommand.SuspendPitch -> command.sessionId
            is GameCommand.ResumePitch -> command.sessionId
            is GameCommand.AbandonPitch -> command.sessionId
            is GameCommand.ClearPitchPresentation -> command.sessionId
            else -> "phase8-ui"
        }
        val commandId = "phase8-${screenId.wire}-${actionId.replace(':', '-')}-${expectedRevision}-$offset".take(120)
        return Phase8CommandPayload(screenId, actionId, GameCommandEnvelope(commandId, session, expectedRevision, command))
    }
}

public data class Phase8Execution(public val launch: PitchLaunch? = null)

/** Dispatches exactly the payload captured by the current projection; it never rewrites it. */
public class Phase8Controller(
    public val store: GameStore,
    public val context: Phase8CommandContext = Phase8CommandContext(),
) {
    public fun projection(screenId: Phase8ScreenId): Phase8ScreenModel = Phase8ScreenProjection.project(store.state.value, screenId, context)

    public fun preferredScreen(): Phase8ScreenId = Phase8ScreenProjection.preferredScreen(store.state.value)

    public suspend fun execute(screenId: Phase8ScreenId, actionId: String, capturedPayloads: List<Phase8CommandPayload>? = null): Phase8Execution {
        val current = projection(screenId)
        val action = current.actions.singleOrNull { it.id == actionId } ?: throw IllegalArgumentException("phase8.action_unknown:$actionId")
        require(action.enabled) { "phase8.action_disabled:$actionId" }
        val payloads = capturedPayloads ?: action.payloads
        payloads.forEach { payload ->
            require(payload.screenId == screenId && payload.actionId == actionId) { "phase8.action_payload_mismatch" }
        }
        store.dispatchBatch(payloads.map { it.envelope })
        val pitch = store.state.value.pitch
        val launch = if (pitch != null && pitch.boundary !in setOf(PitchBoundary.COMPLETED, PitchBoundary.ABANDONED) && actionId in setOf("openTutorialPitch", "openImportantGame", "nextImportantPitch", "openProImportantGame", "nextProPitch", "resumePitch")) {
            PitchLaunch(pitch.sessionId, store.state.value.revision)
        } else {
            require(payloads.isNotEmpty()) { "phase8.action_payload_missing:$actionId" }
            null
        }
        return Phase8Execution(launch)
    }
}
