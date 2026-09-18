package com.solkim.baseball.android

import com.solkim.baseball.application.fixtures.*
import com.solkim.baseball.application.*

import androidx.compose.runtime.*
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import com.solkim.baseball.design.BaseballMigrationTheme
import org.junit.Rule
import org.junit.Test

class CareerMilestoneCelebrationTest {
    @get:Rule val compose = createComposeRule()
    @Test fun ordinaryChangesDoNotInterruptAndNewAwakeningIsCelebratedOnce() {
        val school = CareerFixtures.startHighSchool(HighSchoolPhase4StartRequest("918220", "power_prospect", "celebrate", "2026-W36", "2026-09-05"))
        var state by mutableStateOf(GameAggregateState.initial("celebrate").withCareers(highSchool = school))
        compose.setContent { BaseballMigrationTheme { CareerMilestoneCelebration(state) } }
        compose.onNodeWithTag("career.milestone").assertDoesNotExist()
        compose.runOnIdle { state = state.withCareers(highSchool = school.copy(run = school.run.copy(revision = school.run.revision + 1UL))) }
        compose.onNodeWithTag("career.milestone").assertDoesNotExist()
        compose.runOnIdle {
            state = state.withCareers(highSchool = school.copy(run = school.run.copy(revision = school.run.revision + 2UL,
                selectedAwakenings = listOf(HighSchoolContentCatalog.awakeningNodes.first().id))))
        }
        compose.onNodeWithTag("career.milestone").assertIsDisplayed()
        compose.onNodeWithTag("career.milestone.art.${HighSchoolContentCatalog.awakeningNodes.first().id.wire}").assertIsDisplayed()
        val inst = androidx.test.platform.app.InstrumentationRegistry.getInstrumentation()
        // Let the Android dialog-window entrance finish before visual QA capture.
        android.os.SystemClock.sleep(500)
        androidx.test.uiautomator.UiDevice.getInstance(inst).takeScreenshot(java.io.File(inst.targetContext.cacheDir, "skill-celebration-art.png"))
        compose.onNodeWithTag("career.milestone.continue").performClick()
        compose.runOnIdle {
            val current = CareerAccess.school(state)!!
            state = state.withCareers(highSchool = current.copy(run = current.run.copy(revision = current.run.revision + 1UL)))
        }
        compose.onNodeWithTag("career.milestone").assertDoesNotExist()
    }
    @Test fun everyBranchHasDistinctLandscapeArtwork() {
        val context = androidx.test.platform.app.InstrumentationRegistry.getInstrumentation().targetContext
        val resources = listOf("power", "command", "breaking", "game").map(::skillCelebrationArt)
        org.junit.Assert.assertEquals(4, resources.distinct().size)
        resources.forEach { resource ->
            val options = android.graphics.BitmapFactory.Options().apply { inJustDecodeBounds = true }
            android.graphics.BitmapFactory.decodeResource(context.resources, resource, options)
            org.junit.Assert.assertTrue(options.outWidth > 0 && options.outHeight > 0)
            org.junit.Assert.assertEquals(1.5f, options.outWidth.toFloat() / options.outHeight, 0.01f)
        }
    }

}
