package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.*
import com.solkim.baseball.core.pro.*
import com.solkim.baseball.core.pitch.PitchAbilityRules

/** Rendering receives facts and commands from the application boundary, not a second rules implementation. */
public object CareerUiRules {
    public fun legacyTitle(id: String): String = HighSchoolSignatureLegacyRules.definitions.firstOrNull { it.id == id }?.title.orEmpty()
    public val chapterCount: Int get() = HighSchoolContentCatalog.chapters.size
    public fun hasCareer(state: GameAggregateState): Boolean = state.highSchool != null || state.pro != null
    public fun hasPro(state: GameAggregateState): Boolean = state.pro != null
    public fun challengeActive(state: GameAggregateState): Boolean = state.highSchool?.challenge?.active == true
    public fun playerName(state: GameAggregateState): String? =
        state.pro?.identityName?.takeIf { it.isNotBlank() } ?: state.highSchool?.run?.identity?.name?.takeIf { it.isNotBlank() }
    public fun portraitSeed(state: GameAggregateState): String? =
        state.highSchool?.archive?.firstOrNull()?.playerName?.takeIf { it.isNotBlank() } ?: playerName(state)
    public fun highSchoolCareerId(state: GameAggregateState): String? = state.highSchool?.run?.careerId
    public fun proCareerId(state: GameAggregateState): String? = state.pro?.careerId
    public fun schoolYear(state: GameAggregateState): Int = state.highSchool?.run?.chapter?.schoolYear ?: 1
    public fun isAceYear(state: GameAggregateState): Boolean = schoolYear(state) >= 3
    public fun lastTrainingNumber(state: GameAggregateState): Int = state.highSchool?.run?.lastTraining?.number ?: 0
    public fun lastTrainingMarker(state: GameAggregateState): String? {
        val run = state.highSchool?.run ?: return null
        val training = run.lastTraining ?: return null
        return "${run.careerId}:training:${training.number}"
    }
    public fun totalTrainingsCompleted(state: GameAggregateState): Int = state.highSchool?.run?.totalTrainingsCompleted ?: 0
    public fun completedGameCount(state: GameAggregateState): ULong = state.highSchool?.completedGameCounter ?: 0UL
    public fun lastArchiveCareerId(state: GameAggregateState): String? = state.highSchool?.archive?.lastOrNull()?.careerId
    public fun archive(state: GameAggregateState): List<ArchiveLifeView> = state.highSchool?.archive.orEmpty().map(ArchiveLifeView::from)
    public fun hasUnacknowledgedAchievements(state: GameAggregateState): Boolean =
        state.highSchool?.unacknowledgedAchievements?.isNotEmpty() == true
    public fun achievements(state: GameAggregateState): List<String> = state.highSchool?.achievements.orEmpty()
    public fun unacknowledgedAchievements(state: GameAggregateState): List<String> = state.highSchool?.unacknowledgedAchievements.orEmpty()
    public fun proWeek(state: GameAggregateState): Int? = state.pro?.week
    public fun hasPendingSeasonDecision(state: GameAggregateState): Boolean = state.pro?.pendingDecision != null
    public fun growthRevision(state: GameAggregateState): String? =
        if (state.stage in setOf(GameStage.PRO, GameStage.RETIREMENT)) state.pro?.revision?.toString()
        else state.highSchool?.run?.revision?.toString()
    public fun hasLiveOuting(state: GameAggregateState): Boolean =
        state.pitch != null && (state.pro?.activePitch != null || state.highSchool?.activePitch != null)
    public fun liveOutingOuts(state: GameAggregateState): Int =
        if (state.pitch?.careerKind == PitchCareerKind.PRO) state.pro?.activePitch?.outs ?: 0
        else state.highSchool?.activePitch?.outs ?: 0
    public fun archiveSize(state: GameAggregateState): Int = state.highSchool?.archive?.size ?: 0
    public fun isDrafted(state: GameAggregateState): Boolean = state.highSchool?.run?.draftResult?.outcome == HighSchoolDraftOutcome.DRAFTED
    public fun legacyFamily(id: String): String? = HighSchoolSignatureLegacyRules.definitions.firstOrNull { it.id == id }?.family
    public fun achievementIds(state: GameAggregateState): List<String> {
        val legacy = setOf(HighSchoolAchievementRules.MAJOR_DEBUT, HighSchoolAchievementRules.HUNDRED_STRIKEOUTS, HighSchoolAchievementRules.HALL_OF_FAME)
        return HighSchoolAchievementRules.all.filter { it !in legacy || it in state.highSchool?.achievements.orEmpty() }
    }
    public fun schoolWins(state: GameAggregateState): Int = state.highSchool?.seasonLog.orEmpty().count { it.played && it.decision == HighSchoolPitchingDecision.WIN }
    public fun proRole(state: GameAggregateState): String = state.pro?.role?.label.orEmpty()
    public fun isProMinor(state: GameAggregateState): Boolean = state.pro?.level == ProLevel.MINOR
    public fun proContext(state: GameAggregateState): String = state.pro?.let { "프로 선수 · ${it.team.name} · ${if (it.level == ProLevel.MAJOR) "1군" else "2군"}" }.orEmpty()
    public fun lineage(state: GameAggregateState): LineageView? {
        val school = state.highSchool ?: return null
        val inherited = HighSchoolLineageRules.recovered(school.inheritance, school.archive)
        val active = inherited.lineageLoadout ?: return null
        val mastery = inherited.lineageMasteries.firstOrNull { it.family == legacyFamily(active.legacyId) } ?: return null
        return LineageView(active.legacyId, mastery.rank, mastery.contributions, mastery.nextThreshold, mastery.family)
    }
    public fun selectedVelocity(state: GameAggregateState, selection: PitchHudSelection): Int = PitchAbilityRules.expectedVelocity(
        PitchHudProjection.pitcher(state), PitchHudProjection.resolveCall(state, selection), PitchHudProjection.fatigue(state),
        (state.highSchool?.activePitch?.sessionId ?: state.pro?.activePitch?.sessionId).orEmpty().endsWith(":outing-v2"))
    public fun startProfessional(state: GameAggregateState, context: ScreenCommandContext, preset: String, name: String): List<ScreenCommandPayload> =
        ScreenPayloads.startProfessional(state, context, preset, name)
    public fun lifeNumber(state: GameAggregateState): Int = state.highSchool?.run?.lifeNumber ?: 1
    public fun chapterNumber(state: GameAggregateState): Int = state.highSchool?.run?.chapter?.number ?: 8
    public fun chapterTitle(state: GameAggregateState): String = state.highSchool?.run?.chapter?.title.orEmpty()
    public fun karmaCount(state: GameAggregateState): Int = state.highSchool?.run?.karmas?.size ?: 0
    public fun hasDraftResult(state: GameAggregateState): Boolean = state.highSchool?.run?.draftResult != null
    public fun selectedSignatureLegacyId(state: GameAggregateState): String? = state.highSchool?.selectedSignatureLegacyId
    public fun weekly(state: GameAggregateState): WeeklyNoteView? = state.highSchool?.weekly?.let(WeeklyNoteView::from)
    public fun returnPlan(state: GameAggregateState): ReturnPlanView? = state.highSchool?.returnPlan?.let(ReturnPlanView::from)
    public fun soulPoints(state: GameAggregateState): Int = state.highSchool?.inheritance?.soulPoints ?: state.meta.standaloneSoulBalance
    public fun lastPresentationPitchNumber(state: GameAggregateState): Int = state.highSchool?.lastPresentation?.pitchNumber ?: 0
    public fun hasLastPresentation(state: GameAggregateState): Boolean = state.highSchool?.lastPresentation != null
    public fun schoolRevision(state: GameAggregateState): ULong? = state.highSchool?.run?.revision
    public fun proRevision(state: GameAggregateState): ULong? = state.pro?.revision
    public fun proSeason(state: GameAggregateState): Int? = state.pro?.season
    public fun hasProCareerStats(state: GameAggregateState): Boolean = state.pro?.careerStats?.isNotEmpty() == true
    public fun decisionHistorySize(state: GameAggregateState): Int = state.pro?.decisionHistory?.size ?: 0
    public fun relationshipsCompleted(state: GameAggregateState): Int = state.highSchool?.run?.relationshipsCompleted ?: 0
    public fun currentFatigue(state: GameAggregateState): Int =
        if (state.stage in setOf(GameStage.PRO, GameStage.RETIREMENT)) state.pro?.fatigue ?: 0
        else state.highSchool?.run?.fatigue ?: 0
    public fun currentRivalName(state: GameAggregateState): String? =
        state.pro?.currentRival?.name ?: state.highSchool?.run?.rival?.name
    public fun lastArchivePlayerName(state: GameAggregateState): String? =
        state.highSchool?.archive?.lastOrNull()?.playerName?.takeIf { it.isNotBlank() }
            ?: state.meta.retiredProCareers.lastOrNull()?.identityName?.takeIf { it.isNotBlank() }
    public fun archiveRecord(state: GameAggregateState, careerId: String): ArchiveLifeView? =
        state.highSchool?.archive?.firstOrNull { it.careerId == careerId }?.let(ArchiveLifeView::from)
    public fun previousArchiveCareerId(state: GameAggregateState, life: Int): String? =
        state.highSchool?.archive?.lastOrNull { it.lifeNumber < life }?.careerId
    public fun startingRatings(state: GameAggregateState): List<Int>? =
        state.highSchool?.startingPitcher?.let { listOf(it.stuff, it.command, it.movement, it.stamina) }
    public fun schoolCommitment(state: GameAggregateState): String? = state.highSchool?.run?.stateCommitment
    public fun userDisplayNames(state: GameAggregateState): Set<String> {
        if (state.meta.seedChallenge != null) return emptySet()
        return buildSet {
            state.highSchool?.run?.identity?.name?.let(::add)
            state.pro?.identityName?.let(::add)
            state.highSchool?.archive.orEmpty().forEach { add(it.playerName) }
            state.meta.retiredProCareers.orEmpty().forEach { add(it.identityName) }
        }
    }
    public fun fourSeam(state: GameAggregateState) =
        if (state.stage in setOf(GameStage.PRO, GameStage.RETIREMENT)) state.pro?.pitcher?.profile(com.solkim.baseball.core.pitch.PitchKind.FOUR_SEAM)
        else state.highSchool?.run?.pitcher?.pitchProfiles?.firstOrNull { it.pitchType == com.solkim.baseball.core.pitch.PitchKind.FOUR_SEAM }
    public fun albumScope(state: GameAggregateState): String? =
        if (state.stage in setOf(GameStage.PRO, GameStage.RETIREMENT, GameStage.LEGACY))
            state.pro?.let { "pro:${it.careerId}:${it.season}" }
        else state.highSchool?.run?.let { "hs:${it.careerId}" }
    public fun header(state: GameAggregateState): CareerHeaderView? {
        val pro = state.pro.takeIf { state.stage in setOf(GameStage.PRO, GameStage.RETIREMENT) }
        val run = state.highSchool?.run
        val command = pro?.pitcher?.command ?: run?.pitcher?.command ?: return null
        val stamina = pro?.pitcher?.stamina ?: run?.pitcher?.stamina ?: return null
        val name = pro?.identityName ?: run?.identity?.name ?: return null
        return CareerHeaderView(
            name = name,
            lifeNumber = run?.lifeNumber ?: 1,
            season = pro?.season,
            isPro = pro != null,
            freshman = run?.chapter?.schoolYear == 1,
            chapterTitle = run?.chapter?.title.orEmpty(),
            command = command,
            stamina = stamina,
            fatigue = pro?.fatigue ?: run?.fatigue ?: 0,
            pitchProfiles = pro?.pitcher?.pitchProfiles ?: run?.pitcher?.pitchProfiles.orEmpty(),
        )
    }
    public fun schoolFacts(state: GameAggregateState): SchoolRunFacts? {
        val run = state.highSchool?.run ?: return null
        return SchoolRunFacts(
            careerId = run.careerId,
            playerName = run.identity.name,
            lifeNumber = run.lifeNumber,
            revision = run.revision,
            trainings = run.totalTrainingsCompleted,
            learningCompleted = run.pitchLearningProject?.completed == true,
            learningPitch = run.pitchLearningProject?.pitchType,
            awakeningWires = run.selectedAwakenings.map { it.wire },
            lastBloomed = run.lastTraining?.bloomed == true,
            lastFocus = run.lastTraining?.focus,
            chapterNumber = run.chapter.number,
            importantGames = run.performance.importantGamesCompleted,
            strikeouts = run.performance.strikeouts,
            perfectReleases = run.performance.perfectReleases,
            drafted = run.draftResult?.outcome?.let { it == HighSchoolDraftOutcome.DRAFTED },
            phaseWire = run.phase.wire,
            legacyOptions = run.legacyOptions,
            relationshipEventId = run.currentRelationshipEvent?.id,
            relationshipEventTitle = run.currentRelationshipEvent?.title,
            relationshipEventSummary = run.currentRelationshipEvent?.summary,
            relationshipCategory = run.currentRelationshipEvent?.category,
        )
    }
}
