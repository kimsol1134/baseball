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

public object ScreenPayloads {
    public fun view(state: GameAggregateState, screenId: ScreenId): ScreenCommandPayload =
        payload(state, screenId, "view", GameCommand.RecordAnalytics("screen:${screenId.wire}:${state.revision}", "screen_view"))

    public fun batch(state: GameAggregateState, screenId: ScreenId, actionId: String, commands: List<GameCommand>): List<ScreenCommandPayload> =
        commands.mapIndexed { index, command -> payload(state, screenId, actionId, command, index) }

    /** Captures a product interaction as the same typed aggregate command as every button. */
    public fun analytics(
        state: GameAggregateState,
        screenId: ScreenId,
        actionId: String,
        eventName: String,
        scope: String,
        properties: List<Pair<String, String>> = emptyList(),
    ): ScreenCommandPayload = payload(
        state,
        screenId,
        actionId,
        GameCommand.RecordAnalytics(
            receiptId = AnalyticsProjector.receiptId(state.installId, eventName, scope),
            eventName = eventName,
            properties = properties,
        ),
    )

    public fun startProfessional(state: GameAggregateState, context: ScreenCommandContext, preset: String, name: String): List<ScreenCommandPayload> {
        val command = GameCommand.Pro(ProCommand.StartDirect(ProStartDirectRequest(context.seed(state, "pro-direct"), preset, name.trim())))
        return batch(state, ScreenId.P001_OPENING, "startDirect", listOf(command))
    }

    public fun startHighSchool(state: GameAggregateState, context: ScreenCommandContext): GameCommand =
        startHighSchool(state, "민서준", "서울", "power_prospect", context)

    public fun startHighSchool(
        state: GameAggregateState,
        name: String,
        region: String,
        presetId: String,
        context: ScreenCommandContext,
        throwingHand: String = "right",
        karmas: List<String> = emptyList(),
        lifeNumber: Int = 1,
        difficulty: HighSchoolDifficulty = HighSchoolDifficulty(),
        soulDomain: com.solkim.baseball.core.highschool.HighSchoolSoulDomain = com.solkim.baseball.core.highschool.HighSchoolSoulDomain.TECHNIQUE,
        soulBoosts: List<com.solkim.baseball.core.highschool.HighSchoolSoulBoost> = emptyList(),
        primaryPitch: PitchKind = SetupRepertoire.primary(presetId),
        learningPitch: PitchKind = SetupRepertoire.learning(presetId),
    ): GameCommand {
        require(name.trim().isNotBlank()) { "screen.setup.name" }
        require(region in HighSchoolContentCatalog.regions) { "screen.setup.region" }
        require(HighSchoolContentCatalog.presets.any { it.id == presetId }) { "screen.setup.preset" }
        require(throwingHand == "right" || throwingHand == "left") { "screen.setup.hand" }
        val karmaEnums = karmas.map { wire ->
            HighSchoolKarma.entries.firstOrNull { it.wire == wire } ?: error("screen.setup.karma")
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

    private fun payload(state: GameAggregateState, screenId: ScreenId, actionId: String, command: GameCommand, offset: Int = 0): ScreenCommandPayload {
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
            else -> CareerWire.uiSession(state, command)
        }
        val actionPart = actionId.replace(':', '-').let {
            if (it.length <= 70) it else "${it.take(40)}-${com.solkim.baseball.model.Hashing.sha256Hex(it).take(24)}"
        }
        val commandId = CareerWire.commandId(screenId.wire, actionPart, expectedRevision, offset)
        return ScreenCommandPayload(screenId, actionId, GameCommandEnvelope(commandId, session, expectedRevision, command))
    }
}

public data class ScreenExecution(public val launch: PitchLaunch? = null)

/** Dispatches exactly the payload captured by the current projection; it never rewrites it. */
public class ScreenController(
    public val store: GameStore,
    public val context: ScreenCommandContext = ScreenCommandContext(),
) {
    public fun projection(screenId: ScreenId): ScreenModel = ScreenProjection.project(store.state.value, screenId, context)

    public fun preferredScreen(): ScreenId = ScreenProjection.preferredScreen(store.state.value)

    /** New players go straight from their chosen setup to the mound; guidance belongs on the mound. */
    public suspend fun executePlayerAction(screenId: ScreenId, actionId: String, capturedPayloads: List<ScreenCommandPayload>? = null): ScreenExecution {
        val execution = execute(screenId, actionId, capturedPayloads)
        val state = store.state.value
        if (screenId == ScreenId.P002_SETUP && actionId == "startHighSchool" &&
            state.highSchool?.run?.phase == HighSchoolPhase.PROLOGUE && RebirthContinuity.resolve(state) == null && state.pitch == null) {
            return execute(ScreenId.P003_PROLOGUE, "openTutorialPitch")
        }
        return execution
    }

    /** Complete the saved practice pitch before either opening another or choosing a school. */
    public suspend fun finishPractice(sessionId: String, repeat: Boolean): ScreenExecution {
        require(store.state.value.pitch?.sessionId == sessionId && store.state.value.pitch?.careerKind == PitchCareerKind.TUTORIAL) {
            "screen.practice_session_mismatch"
        }
        PitchSessionController(store).completePitchAndPostgame(sessionId)
        return execute(ScreenId.P003_PROLOGUE, if (repeat) "openTutorialPitch" else "completeTutorial")
    }

    public suspend fun execute(screenId: ScreenId, actionId: String, capturedPayloads: List<ScreenCommandPayload>? = null): ScreenExecution {
        val current = projection(screenId)
        val action = current.actions.singleOrNull { it.id == actionId } ?: throw IllegalArgumentException("screen.action_unknown:$actionId")
        require(action.enabled) { "screen.action_disabled:$actionId" }
        val payloads = capturedPayloads ?: action.payloads
        payloads.forEach { payload ->
            require(payload.screenId == screenId && payload.actionId == actionId) { "screen.action_payload_mismatch" }
        }
        store.dispatchBatch(payloads.map { it.envelope })
        val pitch = store.state.value.pitch
        val launch = if (pitch != null && pitch.boundary !in setOf(PitchBoundary.COMPLETED, PitchBoundary.ABANDONED) && actionId in setOf("openTutorialPitch", "openImportantGame", "nextImportantPitch", "openProImportantGame", "nextProPitch", "resumePitch")) {
            PitchLaunch(pitch.sessionId, store.state.value.revision)
        } else {
            require(payloads.isNotEmpty()) { "screen.action_payload_missing:$actionId" }
            null
        }
        return ScreenExecution(launch)
    }
}

/** 통산 퍼펙트 릴리스. 0이면 줄을 늘리지 않는다. */
internal fun perfectSuffix(run: HighSchoolState?): String =
    run?.performance?.perfectReleases?.takeIf { it > 0 }?.let { " · 퍼펙트 $it" }.orEmpty()

/** 장 결산의 정규 경기 줄: 아직이면 초대, 던졌으면 결과 한 줄. */
internal fun chapterGameRows(state: GameAggregateState): List<ScreenRow> {
    val highSchool = state.highSchool ?: return emptyList()
    val run = highSchool.run
    if (run.phase != HighSchoolPhase.CHAPTER_REVIEW) return emptyList()
    if (run.chapterGameClaimed) {
        val line = highSchool.seasonLog.lastOrNull { it.regular && it.chapter == run.chapter.number }
            ?: return listOf(ScreenRow("정규 경기", "던졌다", "이번 장의 정규 경기는 기록에 남았다."))
        return listOf(ScreenRow(
            "정규 경기",
            "${line.outs / 3}.${line.outs % 3}이닝 ${line.runsAllowed}실점 · K${line.strikeouts}",
            if (line.perfectReleases > 0) "퍼펙트 ${line.perfectReleases} · 기록에 남았다" else "기록에 남았다",
        ))
    }
    if (run.chapter.number >= HighSchoolContentCatalog.chapters.size) return emptyList()
    return emptyList()
}

/** 아웃 수를 이닝 표기로. 18아웃이면 6.0이닝. */
internal fun inningsLabel(outs: Int): String = "${outs / 3}.${outs % 3}이닝"

internal fun proPerfectSuffix(count: Int): String = if (count > 0) " · 퍼펙트 $count" else ""

/** 시즌 결산 뒤 다음 시즌이 열리기 전에는 올해 성적이 통산에도 들어가 있다. 다른 통산 수치와 같은 규칙을 쓴다. */
internal fun proCareerPerfect(pro: ProState?): Int {
    if (pro == null) return 0
    val seasons = if (pro.careerStats.lastOrNull()?.season == pro.currentStats.season) pro.careerStats else pro.careerStats + pro.currentStats
    return seasons.sumOf { it.perfectReleases }
}

/** 한 경기 한 줄. 승부처인지 정규 경기인지, 그리고 그날의 결과. */
internal fun highSchoolGameRow(line: HighSchoolSeasonLine): ScreenRow = ScreenRow(
    if (line.regular) "${line.chapter}장 정규" else "${line.chapter}장 승부처",
    "${inningsLabel(line.outs)} ${line.runsAllowed}실점 · ${line.strikeouts}탈삼진",
    listOfNotNull(
        "${line.walks}볼넷 ${line.hits}피안타",
        line.perfectReleases.takeIf { it > 0 }?.let { "퍼펙트 $it" },
        "${line.teamRuns}-${line.opponentRuns}",
    ).joinToString(" · "),
)

internal fun proGameRow(line: ProGameLine): ScreenRow = ScreenRow(
    "${line.week}주차 ${if (line.started) "선발" else "구원"}",
    "${inningsLabel(line.outs)} ${line.runsAllowed}실점 · ${line.strikeouts}탈삼진",
    listOfNotNull(
        "${line.walks}볼넷 ${line.hits}피안타",
        line.perfectReleases.takeIf { it > 0 }?.let { "퍼펙트 $it" },
        "${line.teamRuns}-${line.opponentRuns}",
    ).joinToString(" · "),
)

/** Saved results must be acknowledged through the existing presentation flow, never replayed as a new pitch. */
