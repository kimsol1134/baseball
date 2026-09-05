package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.*
import com.solkim.baseball.core.pitch.*
import kotlinx.coroutines.runBlocking
import java.nio.file.Files
import kotlin.test.*

class CareerParityPresentationTest {
    @Test fun authoredDialogueChangesWithTrustAndKeepsEventSpecificChoices() {
        val core = HighSchoolKernel()
        val run = core.start(HighSchoolKernel.StartRequest("918220", "power_prospect")).snapshot
        val event = HighSchoolRelationshipEvent("evt-catcher-sign", "사인", "catcher", "사인 이야기")
        val low = run.copy(currentRelationshipEvent = event, catcherTrust = 20)
        val high = low.copy(catcherTrust = 80)
        assertNotEquals(RelationshipNarrative.line(low), RelationshipNarrative.line(high))
        assertEquals("포수가 본 타자 반응부터 묻는다", RelationshipNarrative.choice(high, HighSchoolRelationshipResponse.LISTEN)?.title)
        assertEquals(3, RelationshipNarrative.scene(high)?.choices?.size)
        assertEquals(1, AbilityDisplayScale.rating(20))
        assertEquals(40, AbilityDisplayScale.rating(44))
        assertEquals(100, AbilityDisplayScale.rating(80))
    }

    @Test fun nativeSaveRetainsNewLearningProgressAndLegacyProfileAvailability() = runBlocking {
        val directory = Files.createTempDirectory("baseball-parity-save-")
        val id = "learning-native-save"
        var store = KotlinGameStore.open(id, CSharpLegacyGameStoreRepository(directory, id), NativeAuthorityMode.NATIVE_AUTHORITATIVE)
        try {
            val controller = Phase8Controller(store)
            controller.execute(Phase8ScreenId.P001_OPENING, "enterSetup")
            controller.execute(Phase8ScreenId.P002_SETUP, "startHighSchool")
            val started = store.current.highSchool!!.run
            assertNotNull(started.pitchLearningProject)
            assertEquals(3, started.toPitcherSnapshot().pitchProfiles!!.size)
            controller.execute(Phase8ScreenId.P003_PROLOGUE, "beginTutorial")
            controller.execute(Phase8ScreenId.P003_PROLOGUE, "completeTutorial")
            controller.execute(Phase8ScreenId.P005_SCHOOL_SELECTION, controller.projection(Phase8ScreenId.P005_SCHOOL_SELECTION).actions.first().id)
            val target = started.pitchLearningProject!!.pitchType
            val payload = TrainingPresentation.payloads(store.current, controller.context, TrainingFocus.BREAKING_BALL, TrainingIntensity.INTENSIVE, target, false)
            controller.execute(Phase8ScreenId.P006_TRAINING, "train:breaking_ball", payload)
            val before = store.current
            assertEquals(3, before.highSchool!!.run.pitchLearningProject!!.practiceCredits)
            store.close()
            store = KotlinGameStore.open(id, CSharpLegacyGameStoreRepository(directory, id), NativeAuthorityMode.NATIVE_AUTHORITATIVE)
            assertEquals(before.highSchool, store.current.highSchool)
            assertEquals(before.meta.playerGrowth, store.current.meta.playerGrowth)
        } finally {
            store.close()
            Files.walk(directory).use { it.sorted(Comparator.reverseOrder()).forEach(Files::deleteIfExists) }
        }
    }
}
