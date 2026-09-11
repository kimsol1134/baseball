package com.solkim.baseball.android

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.solkim.baseball.application.*
import kotlinx.coroutines.runBlocking
import org.junit.Test
import org.junit.Assert.*
import org.junit.runner.RunWith
import java.io.File

/** Two-device runner uses only generated fixtures; never imports over the installed career. */
@RunWith(AndroidJUnit4::class)
class ReleaseBackupDeviceTest {
    @Test fun exportOrRestorePortableCareer() = runBlocking {
        val inst = InstrumentationRegistry.getInstrumentation()
        val context = inst.targetContext
        require(context.packageName.endsWith(".compose.qa"))
        val mode = InstrumentationRegistry.getArguments().getString("backupMode") ?: "export"
        val id = "release-backup-$mode"
        val directory = File(context.cacheDir, id)
        directory.deleteRecursively()
        val store = KotlinGameStore.open(id, CSharpLegacyGameStoreRepository(directory.toPath(), id), NativeAuthorityMode.NATIVE_AUTHORITATIVE)
        val transfer = File(context.getExternalFilesDir(null), "release-backup-transfer.json")
        try {
            val controller = ScreenController(store)
            if (mode == "export") {
                controller.execute(ScreenId.P001_OPENING, "enterSetup")
                controller.execute(ScreenId.P002_SETUP, "startHighSchool")
                controller.execute(ScreenId.P003_PROLOGUE, "beginTutorial")
                controller.execute(ScreenId.P003_PROLOGUE, "completeTutorial")
                controller.execute(ScreenId.P005_SCHOOL_SELECTION, controller.projection(ScreenId.P005_SCHOOL_SELECTION).actions.first().id)
                val target = TrainingPresentation.initialTarget(store.current)
                val commands = TrainingPresentation.payloads(store.current, controller.context, TrainingFocus.BREAKING_BALL, TrainingIntensity.LIGHT, target, false)
                controller.execute(ScreenId.P006_TRAINING, "train:breaking_ball", commands)
                transfer.writeBytes(store.exportCareerBackup())
            } else {
                require(mode == "import")
                val bytes = transfer.readBytes()
                val preview = CareerBackup.preview(bytes)
                store.importCareerBackup(bytes, store.current.revision)
                assertEquals(CareerAccess.school(preview), CareerAccess.school(store.current))
                assertEquals(id, store.current.installId)
                val before = CareerAccess.school(store.current)!!.run.totalTrainingsCompleted
                val commands = TrainingPresentation.payloads(store.current, controller.context, TrainingFocus.COMMAND, TrainingIntensity.LIGHT, null, false)
                controller.execute(ScreenId.P006_TRAINING, "train:command", commands)
                assertEquals(before + 1, CareerAccess.school(store.current)!!.run.totalTrainingsCompleted)
                val saved = CareerAccess.school(store.current)
                store.close()
                val reopened = KotlinGameStore.open(id, CSharpLegacyGameStoreRepository(directory.toPath(), id), NativeAuthorityMode.NATIVE_AUTHORITATIVE)
                try { assertEquals(saved, CareerAccess.school(reopened.current)) } finally { reopened.close() }
            }
        } finally { store.close(); directory.deleteRecursively() }
    }
}
