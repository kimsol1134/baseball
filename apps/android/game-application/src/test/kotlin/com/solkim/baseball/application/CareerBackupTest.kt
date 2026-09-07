package com.solkim.baseball.application

import kotlinx.coroutines.runBlocking
import java.nio.file.Files
import kotlin.test.*

class CareerBackupTest {
    @Test fun backupCannotReplaceOrTransferAChallengeAndTheNormalCareerSurvives(): Unit = runBlocking {
        val root = Files.createTempDirectory("baseball-backup-challenge-")
        val repository = CSharpLegacyGameStoreRepository(root, "challenge-backup")
        val store = KotlinGameStore.open("challenge-backup", repository, NativeAuthorityMode.NATIVE_AUTHORITATIVE)
        try {
            val controller = Phase8Controller(store)
            controller.execute(Phase8ScreenId.P001_OPENING, "enterSetup")
            controller.execute(Phase8ScreenId.P002_SETUP, "startHighSchool")
            val normal = store.current.highSchool
            val bytes = store.exportCareerBackup()
            store.dispatch(GameCommandEnvelope("challenge-start", "phase8-ui", store.current.revision,
                GameCommand.HighSchool(com.solkim.baseball.core.highschool.HighSchoolPhase4Command.StartSeedChallenge("41233", 2, "power_prospect"))))
            val challenge = store.current
            assertFalse(CareerBackup.isAvailable(challenge))
            assertFalse(CareerBackup.isAvailable(challenge.copy(meta = challenge.meta.copy(seedChallenge = null))))
            assertFails { store.exportCareerBackup() }
            assertFails { store.importCareerBackup(bytes, challenge.revision) }
            assertFails { repository.importCareer(bytes, challenge.revision) }
            assertEquals(challenge, store.current)
            val envelope = com.solkim.baseball.model.StrictJson.parseUtf8(Files.readAllBytes(root.resolve("save.json"))) as com.solkim.baseball.model.JsonValue.Obj
            val unsafeBackup = CareerBackup.encode(envelope["payload"] as com.solkim.baseball.model.JsonValue.Obj)
            assertFails { CareerBackup.preview(unsafeBackup) }
            store.dispatch(GameCommandEnvelope("challenge-end", "phase8-ui", store.current.revision,
                GameCommand.HighSchool(com.solkim.baseball.core.highschool.HighSchoolPhase4Command.EndChallenge)))
            assertEquals(normal?.run, store.current.highSchool?.run)
            assertNotNull(CareerBackup.preview(store.exportCareerBackup()).highSchool)
        } finally {
            store.close()
            Files.walk(root).use { it.sorted(Comparator.reverseOrder()).forEach(Files::deleteIfExists) }
        }
    }

    @Test fun portableBackupRestoresOnAnotherInstallAndRejectsDamageWithoutChangingCurrentSave() = runBlocking {
        val root = Files.createTempDirectory("baseball-portable-backup-")
        val source = KotlinGameStore.open("source-install", CSharpLegacyGameStoreRepository(root.resolve("source"), "source-install"), NativeAuthorityMode.NATIVE_AUTHORITATIVE)
        var destination = KotlinGameStore.open("new-install", CSharpLegacyGameStoreRepository(root.resolve("destination"), "new-install"), NativeAuthorityMode.NATIVE_AUTHORITATIVE)
        try {
            val controller = Phase8Controller(source)
            controller.execute(Phase8ScreenId.P001_OPENING, "enterSetup")
            controller.execute(Phase8ScreenId.P002_SETUP, "startHighSchool")
            val original = source.current
            val bytes = source.exportCareerBackup()
            assertEquals(original.highSchool, CareerBackup.preview(bytes).highSchool)
            destination.importCareerBackup(bytes, 0UL)
            assertEquals("new-install", destination.current.installId)
            assertEquals(original.highSchool, destination.current.highSchool)
            assertEquals(original.settings, destination.current.settings)
            val restored = destination.current
            assertFails { destination.importCareerBackup(bytes, 0UL) }
            val corrupt = bytes.copyOf().also { it[it.size / 2] = (it[it.size / 2].toInt() xor 1).toByte() }
            assertFails { destination.importCareerBackup(corrupt, restored.revision) }
            assertEquals(restored, destination.current)
            destination.close()
            destination = KotlinGameStore.open("new-install", CSharpLegacyGameStoreRepository(root.resolve("destination"), "new-install"), NativeAuthorityMode.NATIVE_AUTHORITATIVE)
            assertEquals(restored, destination.current)
            Phase8Controller(destination).execute(Phase8ScreenId.P003_PROLOGUE, "beginTutorial")
            assertTrue(destination.current.highSchool!!.tutorial.started)
            assertEquals(original, source.current)
        } finally {
            source.close(); destination.close()
            Files.walk(root).use { it.sorted(Comparator.reverseOrder()).forEach(Files::deleteIfExists) }
        }
    }
}
