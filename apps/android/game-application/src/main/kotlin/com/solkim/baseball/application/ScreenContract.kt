package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.HighSchoolTournamentRules

import com.solkim.baseball.core.highschool.HighSchoolContentCatalog
import com.solkim.baseball.core.highschool.HighSchoolDifficulty
import com.solkim.baseball.core.highschool.HighSchoolPledgeRules
import com.solkim.baseball.core.highschool.HighSchoolAwakening
import com.solkim.baseball.core.highschool.HighSchoolAchievementRules
import com.solkim.baseball.core.highschool.HighSchoolDraftOutcome
import com.solkim.baseball.core.highschool.HighSchoolIdentity
import com.solkim.baseball.core.highschool.HighSchoolKarma
import com.solkim.baseball.core.highschool.HighSchoolPhase
import com.solkim.baseball.core.highschool.HighSchoolState
import com.solkim.baseball.core.highschool.HighSchoolPhase4Command
import com.solkim.baseball.core.highschool.HighSchoolPhase4Kernel
import com.solkim.baseball.core.highschool.HighSchoolPhase4StartRequest
import com.solkim.baseball.core.highschool.HighSchoolRebirthEntryPath
import com.solkim.baseball.core.highschool.HighSchoolRelationshipTarget
import com.solkim.baseball.core.highschool.HighSchoolRelationshipResponse
import com.solkim.baseball.core.highschool.HighSchoolReturnDestination
import com.solkim.baseball.core.highschool.HighSchoolSeasonLine
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
import com.solkim.baseball.core.pro.ProGameLine
import com.solkim.baseball.core.pro.ProState
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
public enum class ScreenId(
    public val wire: String,
    public val title: String,
    public val group: ScreenGroup,
) {
    P001_OPENING("P-001", "나의 야구 인생", ScreenGroup.CAREER_CORE),
    P002_SETUP("P-002", "새로운 투수", ScreenGroup.CAREER_CORE),
    P003_PROLOGUE("P-003", "프롤로그", ScreenGroup.CAREER_CORE),
    P004_PITCH_TUTORIAL("P-004", "첫 투구", ScreenGroup.CAREER_CORE),
    P005_SCHOOL_SELECTION("P-005", "학교 선택", ScreenGroup.CAREER_CORE),
    P006_TRAINING("P-006", "훈련", ScreenGroup.CAREER_CORE),
    P007_RELATIONSHIP("P-007", "관계", ScreenGroup.CAREER_CORE),
    P008_IMPORTANT_GAME("P-008", "중요 경기", ScreenGroup.CAREER_CORE),
    P009_AWAKENING("P-009", "각성", ScreenGroup.CAREER_CORE),
    P010_CHAPTER("P-010", "장 결산", ScreenGroup.CAREER_CORE),
    P011_HIGH_SCHOOL_CAREER("P-011", "경기 기록", ScreenGroup.CAREER_CORE),
    P012_TOURNAMENT_LEAGUE("P-012", "대회와 리그", ScreenGroup.CAREER_CORE),
    P013_DRAFT("P-013", "드래프트", ScreenGroup.RECAP_REBIRTH),
    P014_RUN_RECAP("P-014", "이번 생 결산", ScreenGroup.RECAP_REBIRTH),
    P015_REBIRTH("P-015", "다음 생", ScreenGroup.RECAP_REBIRTH),
    P016_PRO_CONTRACT("P-016", "프로 계약", ScreenGroup.PRO),
    P017_PRO_WEEK("P-017", "프로 주간", ScreenGroup.PRO),
    P018_PRO_IMPORTANT_GAME("P-018", "프로 중요 경기", ScreenGroup.PRO),
    P019_PRO_SEASON("P-019", "프로 시즌", ScreenGroup.PRO),
    P020_OFFSEASON("P-020", "비시즌", ScreenGroup.PRO),
    P021_PRO_RETIREMENT("P-021", "은퇴", ScreenGroup.PRO),
    P022_PRO_LEGACY("P-022", "프로 유산", ScreenGroup.PRO),
    P024_WEEKLY("P-024", "주간 야구 노트", ScreenGroup.RECORDS_META),
    P025_RECORDS_LEAGUE("P-025", "기록과 순위", ScreenGroup.RECORDS_META),
    P026_ACHIEVEMENTS("P-026", "업적", ScreenGroup.RECORDS_META),
    P027_SETTINGS("P-027", "설정", ScreenGroup.SETTINGS_PLATFORM),
    P028_LIFECARD("P-028", "선수 앨범", ScreenGroup.SETTINGS_PLATFORM),
    P029_RETURN_PLAN("P-029", "복귀 계획", ScreenGroup.RETURN_REVIEW),
    P030_REVIEW("P-030", "리뷰", ScreenGroup.RETURN_REVIEW),
    ;

    public companion object {
        public val ordered: List<ScreenId> = entries
    }
}

public enum class ScreenGroup(public val title: String) {
    CAREER_CORE("커리어"),
    RECAP_REBIRTH("결산과 다음 생"),
    PRO("프로 커리어"),
    RECORDS_META("기록"),
    SETTINGS_PLATFORM("설정"),
    RETURN_REVIEW("복귀와 리뷰"),
}

/** Korea-local date source; tests inject a fixed implementation and production uses Seoul time. */
public fun interface KoreaClock {
    public fun today(): LocalDate
}

public class SystemKoreaClock(
    private val clock: Clock = Clock.system(ZoneId.of("Asia/Seoul")),
) : KoreaClock {
    override fun today(): LocalDate = LocalDate.now(clock)
}

public class ScreenCommandContext(
    public val clock: KoreaClock = SystemKoreaClock(),
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

public data class ScreenRow(
    public val label: String,
    public val value: String,
    public val detail: String = "",
)

/** Frozen archive projection used by native sharing. It never falls back to the active run. */
public data class FrozenLifeCard(
    public val careerId: String,
    public val lifeNumber: Int,
    public val title: String,
    public val text: String,
    public val lines: List<String>,
)

public object LifeCardProjection {
    public fun selected(state: GameAggregateState, selectedCareerId: String? = null): FrozenLifeCard? {
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
            "능력: ${listOf("구위", "제구", "무브먼트", "체력").zip(record.ratings.map(AbilityDisplayScale::rating)).joinToString(" · ") { (label, value) -> "$label $value" }}",
            "중요 경기: ${record.importantGames}경기",
            "투구: ${record.pitches}구",
            "삼진: ${record.strikeouts}개",
            "볼넷: ${record.walks}개",
            "실점: ${record.runsAllowed}점",
            "각성: ${record.selectedAwakenings.map { HighSchoolDisplayRules.awakeningTitle(it) }.ifEmpty { listOf("선택 없음") }.joinToString(" · ")}",
            "대표 유산: ${record.selectedSignatureLegacyId?.let { runCatching { HighSchoolSignatureLegacyRules.definition(it).title }.getOrNull() } ?: "선택 없음"}",
            "약속: ${record.pledgeId?.let { runCatching { HighSchoolPledgeRules.definition(it).title }.getOrNull() } ?: "선택 없음"} · ${if (record.pledgeAchieved) "달성" else "진행 중"}",
            "야구혼: ${record.soulEarned}",
        ) + if (record.perfectReleases > 0) listOf("퍼펙트: ${record.perfectReleases}회") else emptyList()
        return FrozenLifeCard(
            careerId = record.careerId,
            lifeNumber = record.lifeNumber,
            title = "${record.playerName} · ${record.lifeNumber}번째 생",
            text = lines.joinToString("\n"),
            lines = lines,
        )
    }
}

public enum class PlayerLegacyExposureSurface { RECAP, NEXT_LIFE, ARCHIVE }

public data class PlayerLegacyExposure(
    public val source: String,
    public val scope: String,
    public val lifeNumber: Int,
    public val drafted: Boolean,
    public val hasFrozenLegacy: Boolean,
)

/** One source of truth for the three allowed frozen-record viewport callers. */
public object PlayerLegacyExposurePolicy {
    public fun resolve(
        state: GameAggregateState,
        surface: PlayerLegacyExposureSurface,
        selectedCareerId: String? = null,
    ): PlayerLegacyExposure? {
        val highSchool = state.highSchool ?: return null
        if (highSchool.challenge.active) return null
        val run = highSchool.run
        val record = when (surface) {
            PlayerLegacyExposureSurface.RECAP -> {
                // The recap card is a frozen current-life record, so it is not exposed while
                // the player is still choosing a legacy in the pre-archive LEGACY phase.
                if (run.phase != HighSchoolPhase.COMPLETED) return null
                highSchool.archive.firstOrNull { it.careerId == run.careerId && it.lifeNumber == run.lifeNumber }
            }
            PlayerLegacyExposureSurface.NEXT_LIFE -> {
                val echo = highSchool.rebirthEcho ?: return null
                if (run.lifeNumber <= 1 || echo.previousCareerId == run.careerId || echo.previousLifeNumber >= run.lifeNumber) return null
                highSchool.archive.firstOrNull { it.careerId == echo.previousCareerId && it.lifeNumber == echo.previousLifeNumber }
            }
            PlayerLegacyExposureSurface.ARCHIVE -> {
                val id = selectedCareerId ?: highSchool.archive.lastOrNull()?.careerId ?: return null
                highSchool.archive.firstOrNull { it.careerId == id }
            }
        } ?: return null
        val source = when (surface) {
            PlayerLegacyExposureSurface.RECAP -> "recap"
            PlayerLegacyExposureSurface.NEXT_LIFE -> "next_life"
            PlayerLegacyExposureSurface.ARCHIVE -> "archive"
        }
        return PlayerLegacyExposure(
            source = source,
            scope = when (surface) {
                PlayerLegacyExposureSurface.RECAP -> "recap:${record.careerId}"
                PlayerLegacyExposureSurface.NEXT_LIFE -> "next-life:${record.careerId}:${run.careerId}"
                PlayerLegacyExposureSurface.ARCHIVE -> "archive:${record.careerId}"
            },
            lifeNumber = record.lifeNumber,
            drafted = record.drafted,
            hasFrozenLegacy = record.selectedSignatureLegacyId != null,
        )
    }
}

public data class ScreenSection(
    public val id: String,
    public val title: String,
    public val rows: List<ScreenRow>,
)

/** A strict aggregate command captured by Compose before it crosses the store boundary. */
public data class ScreenCommandPayload(
    public val screenId: ScreenId,
    public val actionId: String,
    public val envelope: GameCommandEnvelope,
) {
    public val encoded: ByteArray get() = GameCommandCodec.encode(envelope)
    public val payloadSha256: String get() = Hashing.sha256Hex(encoded)

    init {
        envelope.validate()
        require(actionId.isNotBlank()) { "screen.action.id" }
    }
}

public data class ScreenActionModel(
    public val id: String,
    public val label: String,
    public val description: String,
    public val enabled: Boolean,
    public val payloads: List<ScreenCommandPayload> = emptyList(),
    public val destructive: Boolean = false,
    public val effects: List<ChoiceEffect> = emptyList(),
) {
    public val contentDescription: String get() = "$label. $description"
}

public data class ScreenModel(
    public val id: ScreenId,
    public val title: String,
    public val subtitle: String,
    public val sections: List<ScreenSection>,
    public val actions: List<ScreenActionModel>,
    public val viewPayload: ScreenCommandPayload,
) {
    public val contentDescription: String get() = "$title. $subtitle"
}

public object ScreenAccessibilityContract {
    public val fontScales: List<Float> = listOf(1.0f, 1.3f, 1.5f, 2.0f)

    public fun minimumActionHeightDp(fontScale: Float): Int = maxOf(56, kotlin.math.ceil(48.0 * fontScale).toInt())

    public fun validate(model: ScreenModel) {
        require(model.title.isNotBlank() && model.subtitle.isNotBlank()) { "screen.semantics.title" }
        require(model.contentDescription.isNotBlank()) { "screen.semantics.description" }
        require(model.sections.all { it.id.isNotBlank() && it.title.isNotBlank() }) { "screen.semantics.section" }
        require(model.actions.map { it.id }.distinct().size == model.actions.size) { "screen.semantics.action_duplicate" }
        require(model.actions.all { it.contentDescription.isNotBlank() }) { "screen.semantics.action_description" }
    }
}
