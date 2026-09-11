package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.*
import kotlinx.coroutines.runBlocking
import java.nio.file.Files
import kotlin.test.*

class TrainingPresentationTest {
    @Test fun nativeRepeatedTrainingPersistsTargetIntensityAndCombinedResult() = runBlocking {
        val directory = Files.createTempDirectory("baseball-training-ui-")
        val id = "training-native"
        val repository = CSharpLegacyGameStoreRepository(directory, id)
        val store = KotlinGameStore.open(id, repository, NativeAuthorityMode.NATIVE_AUTHORITATIVE)
        try {
            var commandNumber = 0
            suspend fun dispatch(command: GameCommand) = store.dispatch(GameCommandEnvelope("setup-${commandNumber++}", CareerWire.uiSession(store.current, command), store.current.revision, command))
            dispatch(GameCommand.EnterSetup)
            dispatch(GameCommand.HighSchool(HighSchoolPhase4Command.Start(HighSchoolPhase4StartRequest("918220", "power_prospect", id, "2026-W36", "2026-09-05"))))
            dispatch(GameCommand.HighSchool(HighSchoolPhase4Command.BeginTutorial))
            dispatch(GameCommand.HighSchool(HighSchoolPhase4Command.CompleteTutorial("918220")))
            dispatch(GameCommand.HighSchool(HighSchoolPhase4Command.ChooseSchool("918220", HighSchoolSchoolId.HAEDONG_POWER)))
            val before = store.current
            val target = TrainingPresentation.targets(before).last()
            val context = ScreenCommandContext()
            val payloads = TrainingPresentation.payloads(before, context, TrainingFocus.BREAKING_BALL, TrainingIntensity.LIGHT, target, true)
            val command = (payloads.single().envelope.command as GameCommand.HighSchool).command as HighSchoolPhase4Command.TrainingBlock
            assertTrue(command.stopForSafety)
            assertEquals(3, command.requests.size)
            ScreenController(store, context).execute(ScreenId.P006_TRAINING, "train:breaking_ball", payloads)
            val after = store.current
            val evidence = after.highSchool!!.trainingEvidence
            assertTrue(evidence.size in 1..3)
            assertTrue(evidence.all { it.targetPitch == target && it.intensity == TrainingIntensity.LIGHT })
            assertEquals(after.highSchool!!.run.fatigue - before.highSchool!!.run.fatigue, evidence.sumOf { it.fatigueDelta })
            val lines = TrainingPresentation.resultLines(after, before.highSchool!!.run.totalTrainingsCompleted)
            assertTrue(lines.contains("무브먼트 +${AbilityDisplayScale.delta(before.highSchool!!.run.pitcher.movement, after.highSchool!!.run.pitcher.movement)}"), lines.toString())
            val reopened = KotlinGameStore.open(id, repository, NativeAuthorityMode.NATIVE_AUTHORITATIVE)
            try { assertEquals(after.highSchool, reopened.current.highSchool) } finally { reopened.close() }
        } finally {
            store.close()
            Files.walk(directory).use { it.sorted(Comparator.reverseOrder()).forEach(Files::deleteIfExists) }
        }
    }
}
