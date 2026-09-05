package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.*
import com.solkim.baseball.core.pro.*
import kotlinx.coroutines.runBlocking
import java.nio.file.Files
import java.nio.file.Path
import kotlin.test.*

class SeedChallengeTest {
    @Test fun linksUseTheSharedFormatAndRejectForeignOrMalformedInputs() {
        val code = SeedChallengeCode("18446744073709551615", 999)
        assertEquals(code, SeedChallengeCode.parse(code.webUrl + "/?source=share"))
        assertEquals(code, SeedChallengeCode.parse(code.appUrl))
        assertEquals(SeedChallengeCode("42", 1), SeedChallengeCode.parse(" 00042-001 "))
        for (invalid in listOf("18446744073709551616-1", "1-0", "1-1000", "text42-1", "https://example.com/challenge/42-1",
            "https://baseball-reincarnation.vercel.app.evil.test/challenge/42-1", "yagurebirth://challenge/42-1/extra")) {
            assertNull(SeedChallengeCode.parse(invalid), invalid)
        }
    }

    @Test fun freshChallengeDoesNotCreateANormalCareerOnExit() = runBlocking {
        for (native in listOf(false, true)) withStore(native, "fresh") { harness ->
            harness.send(GameCommand.HighSchool(HighSchoolPhase4Command.StartSeedChallenge("41233", 2, "power_prospect")))
            assertTrue(harness.state.highSchool!!.challenge.active)
            assertEquals(HighSchoolPhase.SCHOOL_SELECTION, harness.state.highSchool!!.run.phase)
            assertFalse(harness.state.meta.seedChallenge!!.hadHighSchool)
            harness.reopen()
            val school = harness.state.highSchool!!.run.schoolOptions.first().id
            harness.send(GameCommand.HighSchool(HighSchoolPhase4Command.ChooseSchool("41234", school)))
            harness.send(GameCommand.HighSchool(HighSchoolPhase4Command.Training("41235", HighSchoolTrainingFocus.COMMAND, HighSchoolTrainingIntensity.STANDARD)))
            assertEquals(0UL, harness.state.meta.completedGameCount)
            harness.send(GameCommand.HighSchool(HighSchoolPhase4Command.EndChallenge))
            harness.reopen()
            assertNull(harness.state.highSchool)
            assertNull(harness.state.meta.seedChallenge)
            assertEquals(GameStage.OPENING, harness.state.stage)
            assertEquals(0UL, harness.state.meta.completedGameCount)
            assertTrue(harness.state.meta.lifeArchiveCareerIds.isEmpty())
        }
    }

    @Test fun aChallengeRestoresTheExistingHighSchoolAndProAndCannotAdvancePro() = runBlocking {
        for (native in listOf(false, true)) withStore(native, "existing") { harness ->
            harness.send(GameCommand.EnterSetup)
            harness.send(GameCommand.HighSchool(HighSchoolPhase4Command.Start(HighSchoolPhase4StartRequest(
                "42231", "precision_commander", harness.id, "2026-W36", "2026-09-05", inheritedSoulPoints = 80,
            ))))
            harness.send(GameCommand.HighSchool(HighSchoolPhase4Command.BeginTutorial))
            harness.send(GameCommand.HighSchool(HighSchoolPhase4Command.CompleteTutorial("42232")))
            harness.send(GameCommand.HighSchool(HighSchoolPhase4Command.ChooseSchool("42233", harness.state.highSchool!!.run.schoolOptions.first().id)))
            harness.send(GameCommand.Pro(ProCommand.StartDirect(ProStartDirectRequest("42234", "power_prospect", "이전선수", harness.state.highSchool!!.run.careerId))))
            val before = harness.state
            val context = Phase8CommandContext()
            val normalSeed = context.seed(before, "pro-plan:develop_stuff")
            harness.send(GameCommand.HighSchool(HighSchoolPhase4Command.StartSeedChallenge("41233", 2, "power_prospect")))
            val challengeSeed = context.seed(harness.state, "school-choice")
            harness.send(GameCommand.RecordAnalytics("challenge-view", "screen_view"))
            assertEquals(challengeSeed, context.seed(harness.state, "school-choice"), "UI events must not reroll a challenge")
            assertFailsWith<GameCommandException> { harness.send(GameCommand.Pro(ProCommand.PlanWeek("42235", ProWeekPlan.RECOVER))) }
            harness.reopen()
            harness.send(GameCommand.HighSchool(HighSchoolPhase4Command.EndChallenge))
            harness.reopen()
            assertEquals(before.highSchool!!.run, harness.state.highSchool!!.run)
            assertEquals(before.highSchool!!.inheritance, harness.state.highSchool!!.inheritance)
            assertEquals(before.highSchool!!.weekly, harness.state.highSchool!!.weekly)
            assertEquals(before.pro, harness.state.pro)
            assertEquals(before.stage, harness.state.stage)
            assertEquals(before.meta.completedGameCount, harness.state.meta.completedGameCount)
            assertEquals(normalSeed, context.seed(harness.state, "pro-plan:develop_stuff"))
        }
    }

    @Test fun theSameCodeAndBuildIgnoreInstallationIdentityAndOuterRevision() = runBlocking {
        var first: GameAggregateState? = null
        for (id in listOf("player-a", "player-b")) withStore(false, id) { harness ->
            if (id == "player-b") harness.send(GameCommand.RecordAnalytics("before-challenge", "screen_view"))
            harness.send(GameCommand.HighSchool(HighSchoolPhase4Command.StartSeedChallenge("41233", 2, "power_prospect")))
            val prior = first
            if (prior == null) first = harness.state else {
                assertEquals(prior.highSchool!!.run, harness.state.highSchool!!.run)
                assertEquals(Phase8CommandContext().seed(prior, "training"), Phase8CommandContext().seed(harness.state, "training"))
            }
        }
    }

    private suspend fun withStore(native: Boolean, suffix: String, action: suspend (Harness) -> Unit) {
        val directory = Files.createTempDirectory("baseball-seed-challenge-")
        val harness = Harness(native, directory, "seed-$suffix-${if (native) "native" else "shadow"}")
        try { harness.reopen(); action(harness) } finally {
            harness.store?.close()
            Files.walk(directory).use { it.sorted(Comparator.reverseOrder()).forEach(Files::deleteIfExists) }
        }
    }

    private class Harness(val native: Boolean, val directory: Path, val id: String) {
        var store: KotlinGameStore? = null
        var index = 0
        val state: GameAggregateState get() = requireNotNull(store).current
        suspend fun reopen() {
            store?.close()
            store = KotlinGameStore.open(id,
                if (native) CSharpLegacyGameStoreRepository(directory, id) else FileShadowFixtureGameStoreRepository(directory),
                if (native) NativeAuthorityMode.NATIVE_AUTHORITATIVE else NativeAuthorityMode.NATIVE_SHADOW_READ_ONLY)
        }
        suspend fun send(command: GameCommand) {
            requireNotNull(store).dispatch(GameCommandEnvelope("seed-command-${index++}", "phase8-ui", state.revision, command))
        }
    }
}
