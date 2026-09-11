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

public object ScreenProjection {
    public fun all(state: GameAggregateState, context: ScreenCommandContext = ScreenCommandContext()): List<ScreenModel> =
        ScreenId.ordered.map { project(state, it, context) }

    /** State-only route used on cold launch, process restart, and after a committed command. */
    public fun preferredScreen(state: GameAggregateState): ScreenId {
        if (state.stage == GameStage.SETUP) return ScreenId.P002_SETUP
        state.pitch?.let { pitch ->
            if (pitch.boundary !in setOf(PitchBoundary.COMPLETED, PitchBoundary.ABANDONED)) {
                return when (pitch.careerKind) {
                    PitchCareerKind.TUTORIAL -> ScreenId.P004_PITCH_TUTORIAL
                    PitchCareerKind.HIGH_SCHOOL -> ScreenId.P008_IMPORTANT_GAME
                    PitchCareerKind.PRO -> ScreenId.P018_PRO_IMPORTANT_GAME
                }
            }
            if (pitch.careerKind == PitchCareerKind.TUTORIAL &&
                pitch.boundary == PitchBoundary.COMPLETED &&
                state.stage == GameStage.HIGH_SCHOOL &&
                state.highSchool?.run?.phase == HighSchoolPhase.PROLOGUE &&
                state.highSchool?.tutorial?.completed != true
            ) {
                return ScreenId.P003_PROLOGUE
            }
        }
        if (state.meta.seedChallenge != null && state.highSchool?.run?.phase in setOf(HighSchoolPhase.LEGACY, HighSchoolPhase.COMPLETED)) return ScreenId.P014_RUN_RECAP
        // A linked Pro career deliberately keeps its HighSchool archive in the aggregate, but
        // the active stage owns the launcher route. Never let the preserved HS copy shadow Pro.
        state.pro?.takeIf { state.stage != GameStage.HIGH_SCHOOL }?.let { pro ->
            return when (pro.phase) {
                ProCareerPhase.CONTRACT_OFFER -> ScreenId.P016_PRO_CONTRACT
                ProCareerPhase.WEEKLY_PLAN -> ScreenId.P017_PRO_WEEK
                ProCareerPhase.IMPORTANT_GAME -> ScreenId.P018_PRO_IMPORTANT_GAME
                ProCareerPhase.SEASON_DECISION,
                ProCareerPhase.NATIONAL_TEAM_CALL,
                ProCareerPhase.NATIONAL_TOURNAMENT,
                ProCareerPhase.SEASON_SETTLEMENT,
                ProCareerPhase.SEASON_REVIEW -> ScreenId.P019_PRO_SEASON
                ProCareerPhase.OFFSEASON_DECISION,
                ProCareerPhase.OFFSEASON_INVESTMENT -> ScreenId.P020_OFFSEASON
                ProCareerPhase.RETIREMENT_DECISION -> ScreenId.P021_PRO_RETIREMENT
                ProCareerPhase.LEGACY_SELECTION -> ScreenId.P022_PRO_LEGACY
                ProCareerPhase.COMPLETED -> if (state.highSchool?.run?.phase == HighSchoolPhase.COMPLETED) ScreenId.P015_REBIRTH else ScreenId.P025_RECORDS_LEAGUE
            }
        }
        state.highSchool?.run?.let { run ->
            return when (run.phase) {
                HighSchoolPhase.PROLOGUE -> if (state.highSchool.tutorial.started && !state.highSchool.tutorial.completed) ScreenId.P004_PITCH_TUTORIAL else ScreenId.P003_PROLOGUE
                HighSchoolPhase.SCHOOL_SELECTION -> ScreenId.P005_SCHOOL_SELECTION
                HighSchoolPhase.TRAINING -> ScreenId.P006_TRAINING
                HighSchoolPhase.RELATIONSHIP -> ScreenId.P007_RELATIONSHIP
                HighSchoolPhase.IMPORTANT_GAME -> ScreenId.P008_IMPORTANT_GAME
                HighSchoolPhase.AWAKENING -> ScreenId.P009_AWAKENING
                HighSchoolPhase.CHAPTER_REVIEW -> ScreenId.P010_CHAPTER
                HighSchoolPhase.DRAFT -> ScreenId.P013_DRAFT
                HighSchoolPhase.LEGACY -> ScreenId.P014_RUN_RECAP
                HighSchoolPhase.COMPLETED -> ScreenId.P015_REBIRTH
            }
        }
        return when (state.stage) {
            GameStage.SETUP -> ScreenId.P002_SETUP
            else -> ScreenId.P001_OPENING
        }
    }

    /** Utility and summary screens are reachable only when their owning aggregate exists. */
    public fun isReachable(state: GameAggregateState, id: ScreenId): Boolean {
        if (state.meta.seedChallenge != null && id in setOf(ScreenId.P001_OPENING, ScreenId.P002_SETUP,
            ScreenId.P015_REBIRTH, ScreenId.P016_PRO_CONTRACT, ScreenId.P017_PRO_WEEK,
            ScreenId.P018_PRO_IMPORTANT_GAME, ScreenId.P019_PRO_SEASON, ScreenId.P020_OFFSEASON,
            ScreenId.P021_PRO_RETIREMENT, ScreenId.P022_PRO_LEGACY, ScreenId.P024_WEEKLY,
            ScreenId.P026_ACHIEVEMENTS, ScreenId.P028_LIFECARD, ScreenId.P029_RETURN_PLAN, ScreenId.P030_REVIEW)) return false
        if (id == ScreenId.P024_WEEKLY) return WeeklyNotePolicy.isAvailable(state)
        return when (id) {
        ScreenId.P001_OPENING -> state.stage == GameStage.OPENING
        ScreenId.P002_SETUP -> state.stage == GameStage.SETUP
        ScreenId.P003_PROLOGUE -> state.highSchool?.run?.phase == HighSchoolPhase.PROLOGUE
        ScreenId.P004_PITCH_TUTORIAL ->
            state.highSchool?.let { hs ->
                hs.run.phase == HighSchoolPhase.PROLOGUE && hs.tutorial.started && !hs.tutorial.completed &&
                    (state.pitch == null || state.pitch.careerKind == PitchCareerKind.TUTORIAL)
            } == true
        ScreenId.P005_SCHOOL_SELECTION -> state.highSchool?.run?.phase == HighSchoolPhase.SCHOOL_SELECTION
        ScreenId.P006_TRAINING -> state.highSchool?.run?.phase == HighSchoolPhase.TRAINING
        ScreenId.P007_RELATIONSHIP -> state.highSchool?.run?.phase == HighSchoolPhase.RELATIONSHIP
        ScreenId.P008_IMPORTANT_GAME ->
            state.highSchool?.run?.phase == HighSchoolPhase.IMPORTANT_GAME &&
                (state.pitch == null || state.pitch.careerKind == PitchCareerKind.HIGH_SCHOOL ||
                    (state.pitch.careerKind == PitchCareerKind.TUTORIAL && state.pitch.boundary in setOf(PitchBoundary.COMPLETED, PitchBoundary.ABANDONED)))
        ScreenId.P009_AWAKENING -> state.highSchool?.run?.phase == HighSchoolPhase.AWAKENING
        ScreenId.P010_CHAPTER -> state.highSchool?.run?.phase == HighSchoolPhase.CHAPTER_REVIEW
        ScreenId.P011_HIGH_SCHOOL_CAREER,
        ScreenId.P012_TOURNAMENT_LEAGUE,
        ScreenId.P024_WEEKLY,
        ScreenId.P025_RECORDS_LEAGUE,
        ScreenId.P026_ACHIEVEMENTS,
        ScreenId.P028_LIFECARD,
        ScreenId.P029_RETURN_PLAN -> state.highSchool != null || state.pro != null
        ScreenId.P013_DRAFT -> state.highSchool?.run?.phase == HighSchoolPhase.DRAFT
        ScreenId.P014_RUN_RECAP -> state.highSchool?.run?.phase == HighSchoolPhase.LEGACY || state.highSchool?.run?.phase == HighSchoolPhase.COMPLETED
        ScreenId.P015_REBIRTH -> state.stage == GameStage.BETWEEN_LIVES || state.highSchool?.run?.phase == HighSchoolPhase.COMPLETED
        ScreenId.P016_PRO_CONTRACT ->
            state.pro != null || state.highSchool != null || state.stage == GameStage.OPENING
        ScreenId.P017_PRO_WEEK -> state.pro != null
        ScreenId.P018_PRO_IMPORTANT_GAME ->
            state.pro?.phase == ProCareerPhase.IMPORTANT_GAME &&
                (state.pitch == null || state.pitch.careerKind == PitchCareerKind.PRO)
        ScreenId.P019_PRO_SEASON,
        ScreenId.P020_OFFSEASON,
        ScreenId.P021_PRO_RETIREMENT,
        ScreenId.P022_PRO_LEGACY -> state.pro != null
        ScreenId.P027_SETTINGS -> true
        // The review page is a reachable utility surface. The native Play request remains
        // disabled until one of the exact product moments is durably confirmed.
        ScreenId.P030_REVIEW -> state.highSchool != null || state.pro != null
    }
    }

    /** Retired Daily links have no product entry; they resolve to the state-owned route. */
    public fun normalizeLegacyRoute(raw: String, state: GameAggregateState): ScreenId =
        when (raw.trim().lowercase()) {
            "daily", "daily_inning", "p-023", "p023" -> preferredScreen(state)
            else -> preferredScreen(state)
        }

    public fun project(
        state: GameAggregateState,
        id: ScreenId,
        context: ScreenCommandContext = ScreenCommandContext(),
    ): ScreenModel {
        require(isReachable(state, id) || id == preferredScreen(state)) { "screen.screen_unreachable:${id.wire}" }
        return ScreenBuilder(state, id, context).build()
    }

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
}

/** Each screen compiles independently instead of exceeding ART's method instruction budget. */
internal class ScreenBuilder(val state: GameAggregateState, val id: ScreenId, val context: ScreenCommandContext) {
        internal val highSchool = state.highSchool
        internal val run = highSchool?.run
        internal val pro = state.pro?.takeUnless { state.meta.seedChallenge != null || (id == ScreenId.P016_PRO_CONTRACT && it.phase == ProCareerPhase.COMPLETED) }
        internal val sections = mutableListOf<ScreenSection>()
        internal val actions = mutableListOf<ScreenActionModel>()

        fun addSection(section: ScreenSection) { sections += section }
        fun addAction(actionId: String, label: String, description: String, enabled: Boolean, commands: List<GameCommand> = emptyList(), destructive: Boolean = false, effects: List<ChoiceEffect> = emptyList()) {
            actions += ScreenActionModel(
                id = actionId,
                label = label,
                description = description,
                enabled = enabled,
                payloads = if (enabled) ScreenPayloads.batch(state, id, actionId, commands) else emptyList(),
                destructive = destructive,
                effects = effects,
            )
        }

        fun build(): ScreenModel {
        if (id == ScreenId.P014_RUN_RECAP && state.meta.seedChallenge != null) {
            val challenge = state.meta.seedChallenge
            addSection(ScreenSection("seed-result", "같은 조건에서 남긴 기록", listOf(
                ScreenRow("도전 코드", challenge.code.token),
                ScreenRow("평가", "${run?.draftResult?.evaluationScore ?: 0}"),
                ScreenRow("투구", "${run?.performance?.pitches ?: 0}구 · ${run?.performance?.strikeouts ?: 0}탈삼진"),
            )))
            addAction("endSeedChallenge", "원래 이야기로 돌아가기", "도전 전의 커리어로 돌아갑니다. 원래 기록과 야구혼은 그대로입니다.", true,
                listOf(hs(HighSchoolPhase4Command.EndChallenge)))
            return ScreenModel(id, "도전 결과", "새로운 선택으로 같은 시작을 바꿨습니다.", sections, actions, ScreenPayloads.view(state, id))
        }
        when (id) {
            ScreenId.P001_OPENING -> buildP001_OPENING()
            ScreenId.P002_SETUP -> buildP002_SETUP()
            ScreenId.P003_PROLOGUE -> buildP003_PROLOGUE()
            ScreenId.P004_PITCH_TUTORIAL -> buildP004_PITCH_TUTORIAL()
            ScreenId.P005_SCHOOL_SELECTION -> buildP005_SCHOOL_SELECTION()
            ScreenId.P006_TRAINING -> buildP006_TRAINING()
            ScreenId.P007_RELATIONSHIP -> buildP007_RELATIONSHIP()
            ScreenId.P008_IMPORTANT_GAME -> buildP008_IMPORTANT_GAME()
            ScreenId.P009_AWAKENING -> buildP009_AWAKENING()
            ScreenId.P010_CHAPTER -> buildP010_CHAPTER()
            ScreenId.P011_HIGH_SCHOOL_CAREER -> buildP011_HIGH_SCHOOL_CAREER()
            ScreenId.P012_TOURNAMENT_LEAGUE -> buildP012_TOURNAMENT_LEAGUE()
            ScreenId.P013_DRAFT -> buildP013_DRAFT()
            ScreenId.P014_RUN_RECAP -> buildP014_RUN_RECAP()
            ScreenId.P015_REBIRTH -> buildP015_REBIRTH()
            ScreenId.P016_PRO_CONTRACT -> buildP016_PRO_CONTRACT()
            ScreenId.P017_PRO_WEEK -> buildP017_PRO_WEEK()
            ScreenId.P018_PRO_IMPORTANT_GAME -> buildP018_PRO_IMPORTANT_GAME()
            ScreenId.P019_PRO_SEASON -> buildP019_PRO_SEASON()
            ScreenId.P020_OFFSEASON -> buildP020_OFFSEASON()
            ScreenId.P021_PRO_RETIREMENT -> buildP021_PRO_RETIREMENT()
            ScreenId.P022_PRO_LEGACY -> buildP022_PRO_LEGACY()
            ScreenId.P024_WEEKLY -> buildP024_WEEKLY()
            ScreenId.P025_RECORDS_LEAGUE -> buildP025_RECORDS_LEAGUE()
            ScreenId.P026_ACHIEVEMENTS -> buildP026_ACHIEVEMENTS()
            ScreenId.P027_SETTINGS -> buildP027_SETTINGS()
            ScreenId.P028_LIFECARD -> buildP028_LIFECARD()
            ScreenId.P029_RETURN_PLAN -> buildP029_RETURN_PLAN()
            ScreenId.P030_REVIEW -> buildP030_REVIEW()
        }

        if (id == ScreenId.P017_PRO_WEEK) actions.sortBy { if (it.id.startsWith("proPlan:")) 0 else 1 }
        return ScreenModel(id, id.title, subtitle(id), sections, actions, ScreenPayloads.view(state, id))

        }

    }

