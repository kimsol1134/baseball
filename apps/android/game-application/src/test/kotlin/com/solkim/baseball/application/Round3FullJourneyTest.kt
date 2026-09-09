package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.*
import com.solkim.baseball.core.pro.*
import com.solkim.baseball.core.pitch.PitchDelivery
import kotlinx.coroutines.runBlocking
import java.nio.file.Files
import kotlin.test.*

/** Full command-level journey through the native writer; UI assertions live in Round3JourneyUiTest. */
class Round3FullJourneyTest {
    @org.junit.Test(timeout = 240_000) fun schoolGraduationContractAndProfessionalSeasonKeepTheirRecords() = runBlocking {
        val dir = Files.createTempDirectory("round3-full-journey-")
        var store = KotlinGameStore.open("round3-full", CSharpLegacyGameStoreRepository(dir, "round3-full"), NativeAuthorityMode.NATIVE_AUTHORITATIVE)
        try {
            var c = Phase8Controller(store)
            var pitch = Phase7VerticalController(store, "phase8-ui")
            suspend fun action(screen: Phase8ScreenId, id: String? = null, prefix: String? = null) {
                val a = c.projection(screen).actions.first { it.enabled && (id == null || it.id == id) && (prefix == null || it.id.startsWith(prefix)) }
                c.execute(screen, a.id, a.payloads)
            }
            suspend fun outing(pro: Boolean) {
                val screen = if (pro) Phase8ScreenId.P018_PRO_IMPORTANT_GAME else Phase8ScreenId.P008_IMPORTANT_GAME
                var n = 0
                while (if (pro) store.current.pro!!.phase == ProCareerPhase.IMPORTANT_GAME else store.current.highSchool!!.run.phase == HighSchoolPhase.IMPORTANT_GAME) {
                    check(n++ < 180)
                    when (store.current.pitch?.boundary) {
                        PitchBoundary.PLAYING -> {
                            val id = store.current.pitch!!.sessionId
                            val result = pitch.submitPitch(id, PitchHudSelection.Manual(PitchKind.FOUR_SEAM, PitchZone(1, 1), ZoneIntent.STRIKE, PitchIntensity.CONTROLLED), PitchDelivery(1000, 1000))
                            pitch.consumePresentation(id, result)
                        }
                        PitchBoundary.TERMINAL -> pitch.completePitchAndPostgame(store.current.pitch!!.sessionId)
                        else -> {
                            val ids = if (pro) setOf("openProImportantGame", "nextProPitch", "finishProGame") else setOf("openImportantGame", "nextImportantPitch")
                            action(screen, c.projection(screen).actions.first { it.enabled && it.id in ids }.id)
                        }
                    }
                }
            }
            action(Phase8ScreenId.P001_OPENING, "enterSetup")
            action(Phase8ScreenId.P002_SETUP, "startHighSchool")
            action(Phase8ScreenId.P003_PROLOGUE, "beginTutorial")
            action(Phase8ScreenId.P003_PROLOGUE, "completeTutorial")
            action(Phase8ScreenId.P005_SCHOOL_SELECTION)
            var steps = 0
            while (store.current.highSchool!!.run.phase != HighSchoolPhase.DRAFT) {
                check(steps++ < 300)
                when (store.current.highSchool!!.run.phase) {
                    HighSchoolPhase.TRAINING -> {
                        val state = store.current
                        val player = state.highSchool!!.run.pitcher
                        val focus = if (state.highSchool!!.run.fatigue >= 55) TrainingFocus.RECOVERY else listOf(
                            TrainingFocus.VELOCITY to player.stuff, TrainingFocus.COMMAND to player.command,
                            TrainingFocus.BREAKING_BALL to player.movement, TrainingFocus.STAMINA to player.stamina).minBy { it.second }.first
                        val payloads = TrainingPresentation.payloads(state, c.context, focus, TrainingIntensity.STANDARD, if (focus == TrainingFocus.BREAKING_BALL) TrainingPresentation.initialTarget(state) else null, false)
                        c.execute(Phase8ScreenId.P006_TRAINING, "train:${focus.wire}", payloads)
                    }
                    HighSchoolPhase.RELATIONSHIP -> action(Phase8ScreenId.P007_RELATIONSHIP)
                    HighSchoolPhase.AWAKENING -> action(Phase8ScreenId.P009_AWAKENING)
                    HighSchoolPhase.CHAPTER_REVIEW -> action(Phase8ScreenId.P010_CHAPTER)
                    HighSchoolPhase.IMPORTANT_GAME -> outing(false)
                    else -> error("Unexpected school phase ${store.current.highSchool!!.run.phase}")
                }
            }
            assertEquals(8, store.current.highSchool!!.run.chapter.number)
            action(Phase8ScreenId.P013_DRAFT, "resolveDraft")
            val schoolRecord = CareerRecordPresentation.resolve(store.current, "hs:${store.current.highSchool!!.run.careerId}")
            assertNotNull(schoolRecord)
            assertTrue(schoolRecord.games > 0 && schoolRecord.outs > 0)
            val drafted = store.current.highSchool!!.run.draftResult!!.outcome == HighSchoolDraftOutcome.DRAFTED
            if (drafted) {
                while (!ProfessionalStatusPresentation.canEnterPro(store.current)) {
                    check(steps++ < 320)
                    action(c.preferredScreen())
                }
                action(Phase8ScreenId.P015_REBIRTH, "startLinked")
                action(Phase8ScreenId.P016_PRO_CONTRACT, prefix = "acceptOffer:")
            } else {
                // A fixed bot is not guaranteed a draft selection. Verify its legitimate ending,
                // then independently exercise the direct-pro journey. Linked contracts have their own fixture test.
                assertTrue(c.projection(c.preferredScreen()).sections.isNotEmpty())
                println("ROUND3 school ending: undrafted; games=${schoolRecord.games}, outs=${schoolRecord.outs}")
                store.close()
                store = KotlinGameStore.open("round3-direct", CSharpLegacyGameStoreRepository(dir.resolve("direct"), "round3-direct"), NativeAuthorityMode.NATIVE_AUTHORITATIVE)
                c = Phase8Controller(store)
                pitch = Phase7VerticalController(store, "phase8-ui")
                action(Phase8ScreenId.P001_OPENING, "startDirect")
            }
            assertEquals(GameStage.PRO, store.current.stage)
            var proSteps = 0
            while (store.current.pro!!.season < 2) {
                check(proSteps++ < 220)
                when (store.current.pro!!.phase) {
                    ProCareerPhase.WEEKLY_PLAN -> action(Phase8ScreenId.P017_PRO_WEEK, "proAdvanceSegment")
                    ProCareerPhase.IMPORTANT_GAME -> outing(true)
                    ProCareerPhase.SEASON_DECISION -> action(Phase8ScreenId.P019_PRO_SEASON, prefix = "seasonDecision:")
                    ProCareerPhase.SEASON_REVIEW -> action(Phase8ScreenId.P019_PRO_SEASON, "reviewSeason")
                    ProCareerPhase.SEASON_SETTLEMENT -> action(Phase8ScreenId.P019_PRO_SEASON, "acknowledgeSettlement")
                    ProCareerPhase.NATIONAL_TEAM_CALL -> action(Phase8ScreenId.P019_PRO_SEASON, "nationalTeam:decline")
                    ProCareerPhase.NATIONAL_TOURNAMENT -> action(Phase8ScreenId.P019_PRO_SEASON, "nationalTeam:acknowledge")
                    ProCareerPhase.OFFSEASON_DECISION -> action(Phase8ScreenId.P020_OFFSEASON, "offseason:continue")
                    ProCareerPhase.OFFSEASON_INVESTMENT -> action(Phase8ScreenId.P020_OFFSEASON, "investment:none")
                    else -> error("Unexpected pro phase ${store.current.pro!!.phase}")
                }
                assertEquals(GameStage.PRO, store.current.stage)
            }
            val record = store.current.pro!!.careerStats.single { it.season == 1 }
            assertTrue(record.games > 0 && record.inningsOuts > 0)
            if (drafted) assertEquals(schoolRecord, CareerRecordPresentation.resolve(store.current, "hs:${store.current.highSchool!!.run.careerId}"))
            println("ROUND3 full journey: school steps=$steps, pro steps=$proSteps, season games=${record.games}, outs=${record.inningsOuts}")
        } finally { store.close(); dir.toFile().deleteRecursively() }
    }
}
