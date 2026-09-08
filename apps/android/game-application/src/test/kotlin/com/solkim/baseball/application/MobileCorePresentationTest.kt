package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.*
import kotlinx.coroutines.runBlocking
import java.nio.file.Files
import kotlin.test.*

class MobileCorePresentationTest {
    @Test fun firstTrainingCopySeparatesGuaranteedGrowthFromTotalJackpotGrowth() {
        val hs = HighSchoolPhase4Kernel().start(HighSchoolPhase4StartRequest("918220", "power_prospect", "forecast", "2026-W36", "2026-09-06")).state
        val state = GameAggregateState.initial("forecast").copy(stage = GameStage.HIGH_SCHOOL, highSchool = hs)
        val preview = HighSchoolTrainingPreview(1, 1, 4, 0, false, false, false, false,
            jackpotChancePercent = 37, jackpotMinimumGrowth = 2, jackpotMaximumGrowth = 2, firstTrainingGuaranteed = true)
        for (language in GameLanguage.entries) {
            val copy = GameCopy(language)
            val base = TrainingPresentation.growthOutlook(state, TrainingFocus.VELOCITY, preview, copy)
            val bonus = assertNotNull(TrainingPresentation.jackpotOutlook(state, TrainingFocus.VELOCITY, preview, copy))
            assertTrue(base.contains("+${TrainingPresentation.displayGrowth(state, TrainingFocus.VELOCITY, 1)}"))
            assertTrue(bonus.contains("37%"))
            assertTrue(bonus.contains("+${TrainingPresentation.displayGrowth(state, TrainingFocus.VELOCITY, 2)}"))
            assertFalse(bonus.contains("%1$"))
            assertNull(TrainingPresentation.jackpotOutlook(state, TrainingFocus.RECOVERY, preview, copy))
            assertNull(TrainingPresentation.jackpotOutlook(state, TrainingFocus.VELOCITY, preview.copy(atTalentWall = true), copy))
        }
    }

    @Test fun growthForecastNamesTheAbilityAndSeparatesZeroFixedAndRange() {
        val hs = HighSchoolPhase4Kernel().start(HighSchoolPhase4StartRequest("918220", "power_prospect", "forecast", "2026-W36", "2026-09-06")).state
        val state = GameAggregateState.initial("forecast").copy(stage = GameStage.HIGH_SCHOOL, highSchool = hs)
        val preview = HighSchoolTrainingPreview(0, 0, 6, 0, false, false, false, false)
        for (language in GameLanguage.entries) {
            val copy = GameCopy(language)
            assertEquals(copy.resolve("training.clear.no-growth"), TrainingPresentation.growthOutlook(state, TrainingFocus.COMMAND, preview, copy))
            val fixed = TrainingPresentation.growthOutlook(state, TrainingFocus.COMMAND, preview.copy(minimumGrowth = 1, maximumGrowth = 1), copy)
            assertTrue(fixed.contains(copy.legacy("제구")))
            assertEquals(1, fixed.count { it == '+' })
            val range = TrainingPresentation.growthOutlook(state, TrainingFocus.COMMAND, preview.copy(maximumGrowth = 2), copy)
            assertTrue(range.contains(copy.legacy("제구")))
            assertEquals(2, range.count { it == '+' })
        }
    }

    @Test fun displayScaleMatchesIOSAtEndpointsAndRoundingBoundaries() {
        assertEquals(listOf(1, 2, 38, 50, 72, 73, 100), listOf(20, 21, 43, 50, 63, 64, 80).map(AbilityDisplayScale::rating))
        assertEquals(1, AbilityDisplayScale.delta(63, 64))
        assertEquals(0, AbilityDisplayScale.delta(80, 81))
    }

    @Test fun nextAppearanceCountdownMatchesActualPreparationAcrossSeededSchedules() {
        val kernel = HighSchoolPhase4Kernel()
        for (seed in listOf("918220", "918221", "120212")) {
            var hs = kernel.start(HighSchoolPhase4StartRequest(seed, "power_prospect", "cue", "2026-W36", "2026-09-05")).state
            fun aggregate() = GameAggregateState.initial("cue").copy(stage = GameStage.HIGH_SCHOOL, highSchool = hs)
            assertNull(NextAppearanceCue.resolve(aggregate()))
            hs = kernel.completeTutorial(seed, kernel.beginTutorial(hs).state).state
            hs = kernel.chooseSchool(seed, hs, HighSchoolSchoolId.HAEDONG_POWER).state
            assertEquals(TrainingIntensity.STANDARD, TrainingPresentation.initialIntensity(aggregate()))
            val initial = assertNotNull(NextAppearanceCue.resolve(aggregate()))
            var trainings = 0
            var choices = 0
            repeat(60) {
                if (hs.run.phase == HighSchoolPhase.IMPORTANT_GAME) return@repeat
                val cue = assertNotNull(NextAppearanceCue.resolve(aggregate()))
                assertEquals(initial.trainings - trainings, cue.trainings)
                assertEquals(initial.choices - choices, cue.choices)
                hs = when (hs.run.phase) {
                    HighSchoolPhase.TRAINING -> { trainings++; kernel.commitTraining(seed, hs, HighSchoolTrainingFocus.COMMAND, HighSchoolTrainingIntensity.STANDARD).state }
                    HighSchoolPhase.RELATIONSHIP -> { choices++; kernel.resolveRelationship(seed, hs, HighSchoolRelationshipResponse.LISTEN).state }
                    HighSchoolPhase.AWAKENING -> { choices++; kernel.chooseAwakening(seed, hs, hs.run.awakeningOptions.first()).state }
                    HighSchoolPhase.CHAPTER_REVIEW -> { choices++; kernel.advanceChapter(seed, hs).state }
                    else -> error("Unexpected preparation phase ${hs.run.phase}")
                }
            }
            assertEquals(HighSchoolPhase.IMPORTANT_GAME, hs.run.phase)
            assertEquals(NextAppearanceCue(0, 0), NextAppearanceCue.resolve(aggregate()))
            assertEquals(initial, NextAppearanceCue(trainings, choices))
        }
    }

    @Test fun growthFeedbackKeepsSmallGainsCompactAndLabelsFatigueInEveryLanguage() {
        val small = PlayerGrowthReceipt("life", "training", "training", listOf(40, 35, 40, 40), listOf(40, 36, 40, 40))
        assertFalse(GrowthFeedbackPresentation.controlMilestone(small))
        assertEquals(1, GrowthFeedbackPresentation.primary(small))
        val milestone = small.copy(before = listOf(40, 39, 40, 40), after = listOf(43, 40, 40, 40))
        assertTrue(GrowthFeedbackPresentation.controlMilestone(milestone))
        assertEquals(1, GrowthFeedbackPresentation.primary(milestone))
        for (language in GameLanguage.entries) {
            val copy = GameCopy(language)
            val tired = GrowthFeedbackPresentation.condition(copy, 11, 6)
            val recovered = GrowthFeedbackPresentation.condition(copy, 5, -6)
            assertTrue(tired.contains("11") && tired.contains("+6"), tired)
            assertTrue(recovered.contains("5") && recovered.contains("-6"), recovered)
            assertFalse(tired.contains("loop."))
            assertNotEquals(tired, recovered)
        }
        assertTrue(RebirthContinuity.sameName(" Alex Han ", "alex han"))
        assertFalse(RebirthContinuity.sameName("Alex Han", "Jamie Han"))
        assertFalse(RebirthContinuity.sameName(" ", " "))
    }

    @Test fun growthReceiptUsesCommittedBeforeAfterAndSurvivesNativeReloadWithoutDoubleGrant() = runBlocking {
        val directory = Files.createTempDirectory("baseball-core-growth-")
        val id = "core-growth"
        val repository = CSharpLegacyGameStoreRepository(directory, id)
        val store = KotlinGameStore.open(id, repository, NativeAuthorityMode.NATIVE_AUTHORITATIVE)
        try {
            var number = 0
            suspend fun dispatch(command: GameCommand) = store.dispatch(GameCommandEnvelope("core-${number++}", "core-ui", store.current.revision, command))
            dispatch(GameCommand.EnterSetup)
            dispatch(GameCommand.HighSchool(HighSchoolPhase4Command.Start(HighSchoolPhase4StartRequest("918220", "power_prospect", id, "2026-W36", "2026-09-05"))))
            dispatch(GameCommand.HighSchool(HighSchoolPhase4Command.BeginTutorial))
            dispatch(GameCommand.HighSchool(HighSchoolPhase4Command.CompleteTutorial("918220")))
            dispatch(GameCommand.HighSchool(HighSchoolPhase4Command.ChooseSchool("918220", HighSchoolSchoolId.HAEDONG_POWER)))
            val before = store.current
            val envelope = GameCommandEnvelope("training-growth", "core-ui", before.revision,
                GameCommand.HighSchool(HighSchoolPhase4Command.Training("918221", HighSchoolTrainingFocus.COMMAND, HighSchoolTrainingIntensity.LIGHT)))
            store.dispatch(envelope)
            val after = store.current
            val receipt = assertNotNull(after.meta.playerGrowth)
            assertEquals("training", receipt.source)
            assertEquals(before.highSchool!!.run.pitcher.command, receipt.before[1])
            assertEquals(after.highSchool!!.run.pitcher.command, receipt.after[1])
            assertEquals(before.highSchool!!.run.careerId, receipt.careerId)
            runCatching { store.dispatch(envelope) } // A stale retry may be rejected by the legacy boundary.
            assertEquals(after, store.current)
            store.dispatch(envelope.copy(expectedRevision = after.revision))
            assertEquals(after, store.current)
            val reopened = KotlinGameStore.open(id, repository, NativeAuthorityMode.NATIVE_AUTHORITATIVE)
            try {
                assertEquals(receipt, reopened.current.meta.playerGrowth)
                assertEquals(after.highSchool, reopened.current.highSchool)
            } finally { reopened.close() }
            assertNull(PlayerGrowthReceipt.decode(null))
            val withoutReceipt = GameAggregateState.initial("old-format-growth")
            assertNull(GameAggregateCodec.decodePayload(GameAggregateCodec.encodePayload(withoutReceipt)).meta.playerGrowth)
        } finally {
            store.close()
            Files.walk(directory).use { it.sorted(Comparator.reverseOrder()).forEach(Files::deleteIfExists) }
        }
    }
}
