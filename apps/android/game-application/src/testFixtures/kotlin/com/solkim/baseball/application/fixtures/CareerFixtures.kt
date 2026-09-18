package com.solkim.baseball.application.fixtures

import com.solkim.baseball.core.highschool.HighSchoolAchievementRules
import com.solkim.baseball.core.highschool.HighSchoolAwakening
import com.solkim.baseball.core.highschool.HighSchoolDraftTeamRules
import com.solkim.baseball.core.highschool.HighSchoolKernel
import com.solkim.baseball.core.highschool.HighSchoolSignatureLegacyRules
import com.solkim.baseball.core.highschool.HighSchoolPhase4Kernel
import com.solkim.baseball.core.highschool.HighSchoolPhase4StartRequest
import com.solkim.baseball.core.highschool.HighSchoolPhase4State
import com.solkim.baseball.core.highschool.HighSchoolPitcher
import com.solkim.baseball.core.highschool.HighSchoolRelationshipResponse
import com.solkim.baseball.core.highschool.HighSchoolSchoolId
import com.solkim.baseball.core.highschool.HighSchoolState
import com.solkim.baseball.core.highschool.HighSchoolTrainingFocus
import com.solkim.baseball.core.highschool.HighSchoolTrainingIntensity
import com.solkim.baseball.core.pitch.PitchCall
import com.solkim.baseball.core.pitch.PitchDelivery
import com.solkim.baseball.core.pitch.PitchKind
import com.solkim.baseball.core.pitch.PitcherSnapshot
import com.solkim.baseball.core.pro.ProCatalog
import com.solkim.baseball.core.pro.ProKernel
import com.solkim.baseball.core.pro.ProStartDirectRequest
import com.solkim.baseball.core.pro.ProStartLinkedRequest
import com.solkim.baseball.core.pro.ProState
import com.solkim.baseball.core.pro.ProWeekPlan

/** Kernel-backed fixture builders. App tests call these; they never name kernels. */
public object CareerFixtures {
    private val highSchool = HighSchoolPhase4Kernel()
    private val core = HighSchoolKernel()
    private val pro = ProKernel()

    public fun startHighSchool(request: HighSchoolPhase4StartRequest): HighSchoolPhase4State = highSchool.start(request).state
    public fun beginTutorial(state: HighSchoolPhase4State): HighSchoolPhase4State = highSchool.beginTutorial(state).state
    public fun completePrologue(seed: String, state: HighSchoolPhase4State): HighSchoolPhase4State =
        highSchool.completePrologue(seed, state).state
    public fun chooseSchool(seed: String, state: HighSchoolPhase4State, schoolId: HighSchoolSchoolId): HighSchoolPhase4State =
        highSchool.chooseSchool(seed, state, schoolId).state
    public fun startAtSchool(
        request: HighSchoolPhase4StartRequest,
        seed: String = request.seed,
        schoolId: HighSchoolSchoolId = HighSchoolSchoolId.HAEDONG_POWER,
    ): HighSchoolPhase4State = chooseSchool(seed, completePrologue(seed, beginTutorial(startHighSchool(request))), schoolId)
    public fun commitTraining(
        seed: String,
        state: HighSchoolPhase4State,
        focus: HighSchoolTrainingFocus,
        intensity: HighSchoolTrainingIntensity,
        targetPitch: PitchKind? = null,
    ): HighSchoolPhase4State = highSchool.commitTraining(seed, state, focus, intensity, targetPitch).state
    public fun commitShadow(state: HighSchoolPhase4State): HighSchoolPhase4State = highSchool.commitShadowState(state)
    public fun prepareLegacy(state: HighSchoolPhase4State): HighSchoolPhase4State = highSchool.prepareLegacy(state).state
    public fun resignRun(run: HighSchoolState): HighSchoolState = core.resignShadowState(run)
    public fun resolveRelationship(seed: String, run: HighSchoolState, response: HighSchoolRelationshipResponse): HighSchoolState =
        core.resolveRelationship(HighSchoolKernel.RelationshipRequest(seed, run, response)).snapshot
    public fun previewAwakening(pitcher: HighSchoolPitcher, awakening: HighSchoolAwakening): HighSchoolPitcher =
        core.previewAwakening(pitcher, awakening)
    public fun availableAwakenings(run: HighSchoolState): List<HighSchoolAwakening> = core.availableAwakenings(run)
    public fun startDirectPro(request: ProStartDirectRequest): ProState = pro.startDirect(request).state
    public fun startLinkedPro(request: ProStartLinkedRequest): ProState = pro.startLinked(request).state
    public fun planWeek(state: ProState, seed: String, plan: ProWeekPlan, targetPitch: PitchKind? = null): ProState =
        pro.planWeek(state, seed, plan, targetPitch).state
    public fun proCommitment(state: ProState): String = pro.commitment(state)
    public fun reserveProGame(state: ProState, seed: String): ProState = pro.reserveImportantGame(state, seed).state
    public fun submitProPitch(state: ProState, sessionId: String, call: PitchCall, delivery: PitchDelivery = PitchDelivery.NEUTRAL): ProState =
        pro.submitPitch(state, sessionId, call, delivery).state
    public fun finishProGame(state: ProState): ProState = pro.finishImportantGame(state).state
    public fun proSegment(week: Int) = ProCatalog.segment(week)
    public fun pitcherForPreset(preset: String, name: String): PitcherSnapshot = ProCatalog.pitcherForPreset(preset, name)
    public fun firstProTeamId(): String = ProCatalog.teams.first().id
    public fun bestDraftTeam(pitcher: HighSchoolPitcher) = HighSchoolDraftTeamRules.bestTeam(pitcher)
    public fun firstStrikeoutAchievementId(): String = HighSchoolAchievementRules.FIRST_STRIKEOUT
    public fun signatureLegacyOptions(): List<Pair<String, String>> =
        HighSchoolSignatureLegacyRules.definitions.take(3).map { it.id to it.title }
    public fun importantHeadline(trigger: com.solkim.baseball.core.pro.ProSeasonTrigger, rival: com.solkim.baseball.core.pro.ProRivalBatter?, level: com.solkim.baseball.core.pro.ProLevel): String =
        pro.importantHeadline(trigger, rival, level)
}
