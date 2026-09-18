package com.solkim.baseball.application

import kotlinx.coroutines.runBlocking
import java.nio.file.Files
import kotlin.test.*

class CareerBackupTest {
    @Test fun originalQaSoftlockSaveResumesAndAdvancesWithoutReset() = runBlocking {
        val root = Files.createTempDirectory("career-original-softlock-")
        try {
            val bytes = requireNotNull(javaClass.getResourceAsStream("/regression/high-school-terminal-v42.json")).use { it.readBytes() }
            Files.write(root.resolve("save.json"), bytes)
            val store = KotlinGameStore.open("qa-recovered-device", CSharpLegacyGameStoreRepository(root, "qa-recovered-device", allowDeviceRestore = true), NativeAuthorityMode.NATIVE_AUTHORITATIVE)
            try {
                assertEquals(PitchBoundary.TERMINAL, store.current.pitch?.boundary)
                val controller = ScreenController(store)
                val careerId = store.current.highSchool!!.run.careerId
                val launch = assertNotNull(controller.execute(ScreenId.P008_IMPORTANT_GAME, "resumePitch").launch)
                val pitching = PitchSessionController(store)
                val result = pitching.preparePresentation(launch.sessionId, 0)
                pitching.consumePresentation(launch.sessionId, result)
                pitching.completePitchAndPostgame(launch.sessionId)
                assertEquals(PitchBoundary.COMPLETED, store.current.pitch?.boundary)
                assertEquals(careerId, store.current.highSchool!!.run.careerId)
                if (store.current.highSchool?.activePitch != null) {
                    assertNotNull(controller.execute(ScreenId.P008_IMPORTANT_GAME, "nextImportantPitch").launch)
                    assertEquals(PitchBoundary.PLAYING, store.current.pitch?.boundary)
                } else assertNotEquals(ScreenId.P008_IMPORTANT_GAME, controller.preferredScreen())
            } finally { store.close() }
        } finally { root.toFile().deleteRecursively() }
    }

    @Test fun osRestoredCareerRebindsToNewInstallOnceAndContinues() = runBlocking {
        val root = Files.createTempDirectory("career-device-restore-")
        try {
            val original = KotlinGameStore.open("old-device", CSharpLegacyGameStoreRepository(root, "old-device"), NativeAuthorityMode.NATIVE_AUTHORITATIVE)
            val controller = ScreenController(original)
            controller.execute(ScreenId.P001_OPENING, "enterSetup")
            controller.execute(ScreenId.P002_SETUP, "startHighSchool")
            val career = original.current.highSchool
            val revision = original.current.revision
            original.close()
            assertFails { CSharpLegacyGameStoreRepository(root, "new-device").load() }
            val repository = CSharpLegacyGameStoreRepository(root, "new-device", allowDeviceRestore = true)
            val restored = KotlinGameStore.open("new-device", repository, NativeAuthorityMode.NATIVE_AUTHORITATIVE)
            try {
                assertEquals(career, restored.current.highSchool)
                assertEquals("new-device", restored.current.installId)
                assertEquals(revision + 1UL, restored.current.revision)
                assertEquals(restored.current.revision, repository.load().envelope!!.revision)
                ScreenController(restored).execute(ScreenId.P003_PROLOGUE, "beginTutorial")
                assertEquals(restored.current.highSchool, repository.load().envelope!!.payload.highSchool)
                assertEquals(restored.current.highSchool, CareerBackup.preview(restored.exportCareerBackup()).highSchool)
            } finally { restored.close() }
        } finally { root.toFile().deleteRecursively() }
    }

    @Test fun shadowAlbumBackupRestoresWithAnIntactReceiptChain() = runBlocking {
        val source = KotlinGameStore.open("shadow-source", InMemoryShadowFixtureGameStoreRepository(GameAggregateState.initial("shadow-source")), NativeAuthorityMode.NATIVE_SHADOW_READ_ONLY)
        val destination = KotlinGameStore.open("shadow-destination", InMemoryShadowFixtureGameStoreRepository(GameAggregateState.initial("shadow-destination")), NativeAuthorityMode.NATIVE_SHADOW_READ_ONLY)
        try {
            val controller = ScreenController(source)
            controller.execute(ScreenId.P001_OPENING, "enterSetup")
            controller.execute(ScreenId.P002_SETUP, "startHighSchool")
            val bytes = source.exportCareerBackup()
            assertTrue(source.current.meta.album.isNotEmpty())
            destination.importCareerBackup(bytes, 0UL)
            destination.current.validate()
            assertEquals(source.current.meta.album, destination.current.meta.album)
            assertEquals("shadow-destination", destination.current.installId)
            ScreenController(destination).execute(ScreenId.P003_PROLOGUE, "beginTutorial")
            destination.current.validate()
        } finally { source.close(); destination.close() }
    }
    @Test fun backupCannotReplaceOrTransferAChallengeAndTheNormalCareerSurvives(): Unit = runBlocking {
        val root = Files.createTempDirectory("baseball-backup-challenge-")
        val repository = CSharpLegacyGameStoreRepository(root, "challenge-backup")
        val store = KotlinGameStore.open("challenge-backup", repository, NativeAuthorityMode.NATIVE_AUTHORITATIVE)
        try {
            val controller = ScreenController(store)
            controller.execute(ScreenId.P001_OPENING, "enterSetup")
            controller.execute(ScreenId.P002_SETUP, "startHighSchool")
            val normal = store.current.highSchool
            val bytes = store.exportCareerBackup()
            store.dispatch(GameCommandEnvelope("challenge-start", CareerWire.highSchoolSession(store.current), store.current.revision,
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
            store.dispatch(GameCommandEnvelope("challenge-end", CareerWire.highSchoolSession(store.current), store.current.revision,
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
            val controller = ScreenController(source)
            controller.execute(ScreenId.P001_OPENING, "enterSetup")
            controller.execute(ScreenId.P002_SETUP, "startHighSchool")
            val original = source.current
            assertTrue(original.meta.album.isNotEmpty())
            val bytes = source.exportCareerBackup()
            assertEquals(original.meta.album, CareerBackup.preview(bytes).meta.album)
            assertEquals(original.highSchool, CareerBackup.preview(bytes).highSchool)
            destination.importCareerBackup(bytes, 0UL)
            assertEquals("new-install", destination.current.installId)
            assertEquals(original.highSchool, destination.current.highSchool)
            assertEquals(original.settings, destination.current.settings)
            assertEquals(original.meta.album, destination.current.meta.album)
            val restored = destination.current
            assertFails { destination.importCareerBackup(bytes, 0UL) }
            val corrupt = bytes.copyOf().also { it[it.size / 2] = (it[it.size / 2].toInt() xor 1).toByte() }
            assertFails { destination.importCareerBackup(corrupt, restored.revision) }
            assertEquals(restored, destination.current)
            destination.close()
            destination = KotlinGameStore.open("new-install", CSharpLegacyGameStoreRepository(root.resolve("destination"), "new-install"), NativeAuthorityMode.NATIVE_AUTHORITATIVE)
            assertEquals(restored, destination.current)
            ScreenController(destination).execute(ScreenId.P003_PROLOGUE, "beginTutorial")
            assertTrue(destination.current.highSchool!!.tutorial.started)
            assertEquals(original, source.current)
        } finally {
            source.close(); destination.close()
            Files.walk(root).use { it.sorted(Comparator.reverseOrder()).forEach(Files::deleteIfExists) }
        }
    }
}
