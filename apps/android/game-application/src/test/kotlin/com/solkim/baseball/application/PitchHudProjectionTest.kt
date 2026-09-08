package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.HighSchoolTutorialMound
import com.solkim.baseball.core.pitch.PitchCall
import com.solkim.baseball.core.pitch.PitchDelivery
import com.solkim.baseball.core.pitch.PitchKernel
import com.solkim.baseball.core.pitch.PitchKind
import com.solkim.baseball.core.pitch.PitchProfileSnapshot
import com.solkim.baseball.core.pitch.PitchUsageRole
import com.solkim.baseball.core.pitch.PitchZone
import com.solkim.baseball.core.pitch.PitcherSnapshot
import com.solkim.baseball.core.pitch.PlateAppearanceContext
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertTrue
import kotlinx.coroutines.runBlocking

class PitchHudProjectionTest {
    @Test fun manualEffortIsNeverOverwrittenByMatchingCatcherPitchAndZone() = runBlocking {
        val store = KotlinGameStore.fromShadowFixture(GameAggregateState.initial("manual-effort"))
        val controller = Phase7VerticalController(store)
        controller.enterSetup()
        controller.startHighSchool("민서준")
        controller.beginTutorial()
        controller.reserveTutorialPitch()
        val primary = PitchHudProjection.model(store.current).preparation.primaryRecommendation.call
        val call = PitchHudProjection.resolveCall(store.current, PitchHudSelection.Manual(
            primary.pitchType, primary.zone, ZoneIntent.STRIKE, PitchIntensity.MAX_EFFORT))
        assertEquals(PitchIntensity.MAX_EFFORT, call.intensity)
        assertEquals(ZoneIntent.STRIKE, call.zoneIntent)
    }

    @Test
    fun tutorialHudProjectsIosOrderCopyAndSliderDefault() = runBlocking {
        val store = KotlinGameStore.fromShadowFixture(GameAggregateState.initial("hud-tutorial-ios"))
        val controller = Phase7VerticalController(store)
        controller.enterSetup()
        controller.startHighSchool("민서준")
        controller.beginTutorial()
        controller.reserveTutorialPitch()
        assertFalse(store.current.settings.autoReleaseEnabled)
        val hud = PitchHudProjection.model(store.current)
        assertEquals("첫 불펜", hud.scenarioTitle)
        assertEquals(0, PitchHudProjection.fatigue(store.current))
        assertTrue(hud.scenarioDetail.contains("연습"))
        assertTrue(hud.scenarioDetail.contains("타석"))
        assertEquals("포심", PitchHudProjection.koreanLabel(PitchKind.FOUR_SEAM))
        assertTrue(hud.scoutingTitle.contains("상대 분석"))
        assertTrue(hud.scoutingBody.isNotBlank())
        assertFalse(hud.canFastForward)
        assertEquals("중요도", hud.stakesLabel)
        assertEquals("공 맞히기", hud.contactLabel)
        assertEquals("볼 고르기", hud.disciplineLabel)
        assertEquals("장타력", hud.powerLabel)
        assertTrue(hud.currentPitchLine.contains("·"))
        assertTrue(hud.primaryExplanation.length > 12)
        assertEquals("길게 눌러 와인드업", hud.holdToReleasePrompt)
        assertFalse(hud.autoReleaseEnabled)
        assertEquals("코치", hud.coachLabel)
        assertTrue(requireNotNull(hud.coachTip).startsWith("길게 눌러"))
        assertEquals("타자가 내 공을 읽는 정도", hud.adaptationTitle)
        assertTrue(hud.catcherConfidenceLabel.contains("사인 확신"))
        assertTrue(hud.catcherTrustLabel.contains("포수 호흡"))
        assertEquals("중단", hud.abortLabel)
        assertTrue(hud.autoReleaseLabel.contains("자동 릴리스"))
        val primary = hud.preparation.primaryRecommendation
        assertTrue(primary.shortReason == hud.primaryExplanation)
        assertTrue(hud.currentPitchLine.contains(PitchHudProjection.koreanLabel(primary.call.pitchType)))
    }

    @Test
    fun officialHudProjectsMatchupLabelsAndPrimaryExplanation() = runBlocking {
        val store = KotlinGameStore.fromShadowFixture(GameAggregateState.initial("hud-official-ios"))
        val controller = Phase7VerticalController(store)
        controller.enterSetup()
        controller.startHighSchool("민서준")
        controller.beginTutorial()
        controller.completeTutorial()
        controller.chooseSchool()
        reachImportantGame(controller, store)
        controller.reserveImportantGame()
        assertFalse(store.current.settings.autoReleaseEnabled)
        val hud = PitchHudProjection.model(store.current)
        assertEquals("중간계투 등판", hud.scenarioTitle)
        assertEquals(com.solkim.baseball.core.pitch.OutingRole.RELIEF, OutingPresentation.assignment(store.current)?.role)
        assertEquals("중요도", hud.stakesLabel)
        assertEquals("공 맞히기", hud.contactLabel)
        assertEquals("볼 고르기", hud.disciplineLabel)
        assertEquals("장타력", hud.powerLabel)
        assertTrue(hud.primaryExplanation.length > 12)
        assertEquals("길게 눌러 와인드업", hud.holdToReleasePrompt)
        assertFalse(hud.autoReleaseEnabled)
        assertEquals(null, hud.coachTip)
        assertEquals("중단", hud.abortLabel)
        assertEquals("타자가 내 공을 읽는 정도", hud.adaptationTitle)
    }

    @Test
    fun missingTypeCannotBeSelectedAndPresentTypeResolves() {
        val pitcher = PitcherSnapshot(
            id = "limited",
            name = "한정 레퍼토리",
            stuff = 50,
            command = 50,
            movement = 50,
            stamina = 50,
            pitchProfiles = listOf(
                PitchProfileSnapshot(PitchKind.FOUR_SEAM, PitchUsageRole.PRIMARY, 1400, 40, 40, 40, 40, 40, 1),
                PitchProfileSnapshot(PitchKind.SLIDER, PitchUsageRole.SECONDARY, 1250, 40, 40, 40, 40, 40, 1),
            ),
        )
        val types = PitchHudProjection.selectableTypes(pitcher)
        assertEquals(listOf(PitchKind.FOUR_SEAM, PitchKind.SLIDER), types)
        assertFalse(PitchKind.CURVEBALL in types)
        val preparation = PitchKernel().prepare(
            PitchKernel.PrepareRequest(
                seed = "1",
                pitcher = pitcher,
                batter = HighSchoolTutorialMound.BATTER,
                scouting = HighSchoolTutorialMound.SCOUTING,
                context = PlateAppearanceContext("pa", 0UL, 1, 0, 0, 0, 1, 0, 200, 0),
            ),
        )
        val allowed = PitchHudProjection.resolveCall(
            pitcher,
            preparation,
            PitchHudSelection.Manual(PitchKind.FOUR_SEAM, PitchZone(1, 1)),
        )
        assertEquals(PitchKind.FOUR_SEAM, allowed.pitchType)
        val error = assertFailsWith<IllegalArgumentException> {
            PitchHudProjection.resolveCall(
                pitcher,
                preparation,
                PitchHudSelection.Manual(PitchKind.CURVEBALL, PitchZone(1, 1)),
            )
        }
        assertTrue(error.message?.contains("pitch.not_in_repertoire") == true)
    }

    @Test
    fun primaryAndAlternativeRecommendationsRoundTripIntoSubmitCall() = runBlocking {
        val store = KotlinGameStore.fromShadowFixture(GameAggregateState.initial("hud-signs"))
        val controller = Phase7VerticalController(store)
        controller.enterSetup()
        controller.startHighSchool("민서준")
        controller.beginTutorial()
        controller.completeTutorial()
        controller.chooseSchool()
        reachImportantGame(controller, store)
        val launch = controller.reserveImportantGame()

        val preparation = PitchHudProjection.preparation(store.current)
        val primary = preparation.primaryRecommendation.call
        val alternative = preparation.alternativeRecommendation.call
        assertEquals(primary, PitchHudProjection.resolveCall(store.current, PitchHudSelection.Primary))
        assertEquals(alternative, PitchHudProjection.resolveCall(store.current, PitchHudSelection.Alternative))
        assertEquals(primary.pitchType, PitchHudProjection.resolveCall(store.current, PitchHudSelection.Primary).pitchType)
        assertEquals(primary.zone, PitchHudProjection.resolveCall(store.current, PitchHudSelection.Primary).zone)
        assertEquals(primary.zoneIntent, PitchHudProjection.resolveCall(store.current, PitchHudSelection.Primary).zoneIntent)
        assertEquals(primary.intensity, PitchHudProjection.resolveCall(store.current, PitchHudSelection.Primary).intensity)
        assertEquals(alternative.pitchType, PitchHudProjection.resolveCall(store.current, PitchHudSelection.Alternative).pitchType)
        assertEquals(alternative.zone, PitchHudProjection.resolveCall(store.current, PitchHudSelection.Alternative).zone)
        assertEquals(alternative.zoneIntent, PitchHudProjection.resolveCall(store.current, PitchHudSelection.Alternative).zoneIntent)
        assertEquals(alternative.intensity, PitchHudProjection.resolveCall(store.current, PitchHudSelection.Alternative).intensity)
        assertTrue(primary.pitchType in PitchHudProjection.repertoire(store.current))
        assertTrue(alternative.pitchType in PitchHudProjection.repertoire(store.current))
        assertFalse(requireNotNull(store.current.pitch).holdCall)
        controller.setPitchHoldCall(true)
        assertTrue(requireNotNull(store.current.pitch).holdCall)
        val restored = GameAggregateCodec.decodePayload(GameAggregateCodec.encodePayload(store.current))
        assertTrue(requireNotNull(restored.pitch).holdCall)

        val primaryRequest = controller.submitPitch(
            launch.sessionId,
            PitchHudSelection.Primary,
            PitchDelivery(200, 200),
        )
        assertSubmittedCall(store, primary)
        controller.consumePresentation(launch.sessionId, primaryRequest)
        controller.completePitchAndPostgame(launch.sessionId)
        assertFalse(requireNotNull(store.current.highSchool?.activePitch).ended)
        val next = requireNotNull(controller.continueOfficialPitch())
        val altNow = PitchHudProjection.preparation(store.current).alternativeRecommendation.call
        assertEquals(altNow, PitchHudProjection.resolveCall(store.current, PitchHudSelection.Alternative))
        controller.submitPitch(next.sessionId, PitchHudSelection.Alternative, PitchDelivery(200, 200))
        assertSubmittedCall(store, altNow)
    }

    @Test
    fun highSchoolMatchupUsesRunBatterSnapshotNotFallback() = runBlocking {
        val store = KotlinGameStore.fromShadowFixture(GameAggregateState.initial("hud-batter"))
        val controller = Phase7VerticalController(store)
        controller.enterSetup()
        controller.startHighSchool("민서준")
        controller.beginTutorial()
        controller.completeTutorial()
        controller.chooseSchool()
        reachImportantGame(controller, store)
        controller.reserveImportantGame()
        val run = requireNotNull(store.current.highSchool).run
        val batter = PitchHudProjection.batter(store.current)
        assertEquals(run.rival.name, batter.name)
        assertEquals(run.rival.contact, batter.contact)
        assertEquals(run.rival.discipline, batter.discipline)
        assertEquals(run.rival.power, batter.power)
        assertFalse(batter.name == "고교 4번 타자")
        assertFalse(batter.contact == 55 && batter.discipline == 50 && batter.power == 60)
        assertNotNull(store.current.highSchool?.activePitch)
        Unit
    }

    private suspend fun reachImportantGame(controller: Phase7VerticalController, store: KotlinGameStore) {
        var guard = 0
        while (store.current.highSchool?.run?.phase != com.solkim.baseball.core.highschool.HighSchoolPhase.IMPORTANT_GAME && guard++ < 120) {
            when (store.current.highSchool?.run?.phase) {
                com.solkim.baseball.core.highschool.HighSchoolPhase.TRAINING -> controller.commitTraining()
                com.solkim.baseball.core.highschool.HighSchoolPhase.RELATIONSHIP -> controller.resolveRelationship()
                com.solkim.baseball.core.highschool.HighSchoolPhase.AWAKENING -> controller.chooseAwakening()
                com.solkim.baseball.core.highschool.HighSchoolPhase.CHAPTER_REVIEW -> controller.advanceChapter()
                else -> error("unexpected phase ${store.current.highSchool?.run?.phase}")
            }
        }
        assertEquals(com.solkim.baseball.core.highschool.HighSchoolPhase.IMPORTANT_GAME, store.current.highSchool?.run?.phase)
    }

    private fun assertSubmittedCall(store: KotlinGameStore, call: PitchCall) {
        val highSchool = requireNotNull(store.current.highSchool)
        val presentation = requireNotNull(highSchool.lastPresentation)
        assertEquals(call.pitchType, presentation.snapshot.pitchType)
        val recorded = highSchool.activePitch?.sequencePitches?.lastOrNull()
        if (recorded != null) {
            assertEquals(call.pitchType, recorded.pitchType)
            assertEquals(call.zone, recorded.zone)
            assertEquals(call.zoneIntent, recorded.intent)
        }
        val log = requireNotNull(highSchool.activePitch?.log?.entries?.lastOrNull())
        assertEquals(call.pitchType, log.pitchType)
    }
}
