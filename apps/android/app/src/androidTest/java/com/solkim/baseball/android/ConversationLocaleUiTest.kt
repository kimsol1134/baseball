package com.solkim.baseball.android

import com.solkim.baseball.application.fixtures.*
import com.solkim.baseball.application.*

import androidx.compose.runtime.*
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import com.solkim.baseball.design.BaseballMigrationTheme
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test

class ConversationLocaleUiTest {
    @get:Rule val compose = createComposeRule()
    @Test fun changingLanguageKeepsTheSameFaceAndDoesNotCommitTheChoice() {
        val k = HighSchoolPhase4Kernel()
        val base = k.start(HighSchoolPhase4StartRequest("918220", "power_prospect", "actor", "2026-W37", "2026-09-08")).state
        val school = k.chooseSchool("918220", k.completePrologue("918220", k.beginTutorial(base).state).state, HighSchoolSchoolId.HAEDONG_POWER).state
        val run = HighSchoolKernel().resignShadowState(school.run.copy(phase = HighSchoolPhase.RELATIONSHIP,
            currentRelationshipCategory = "coach", currentRelationshipTarget = HighSchoolRelationshipTarget.COACH,
            currentRelationshipEvent = HighSchoolContentCatalog.events.first { it.id == "evt-coach-role" }))
        val state = GameAggregateState.initial("actor").copy(stage = GameStage.HIGH_SCHOOL, highSchool = k.commitShadowState(school.copy(run = run)))
        var language by mutableStateOf("ko")
        var actions = 0
        var screen by mutableStateOf(Phase8ScreenId.P007_RELATIONSHIP)
        compose.setContent { val config = android.content.res.Configuration(LocalConfiguration.current).apply { setLocale(java.util.Locale.forLanguageTag(language)) }
            CompositionLocalProvider(LocalConfiguration provides config) { BaseballMigrationTheme {
                Phase8Shell(state, false, null, screen, Phase8CommandContext(), onNavigate = { screen = it }, onAction = { actions++ })
            } }
        }
        val face = compose.onNodeWithTag("relationship.portrait").performScrollTo().captureToImage().asAndroidBitmap()
        for (locale in listOf("en", "ja")) {
            compose.runOnIdle { language = locale }
            val next = compose.onNodeWithTag("relationship.portrait").performScrollTo().captureToImage().asAndroidBitmap()
            assertTrue("Same actor must keep the same portrait in $locale", face.sameAs(next))
            compose.onNodeWithTag("effect.details.relationship:challenge").performScrollTo().performClick()
            assertEquals(0, actions)
        }
        compose.onNodeWithTag("navigation.records").performClick()
        compose.onNodeWithTag("navigation.records").assertIsSelected()
        compose.onNodeWithTag("navigation.career").performClick()
        compose.onNodeWithTag("conversation.line").assertIsDisplayed()
        val device = androidx.test.uiautomator.UiDevice.getInstance(androidx.test.platform.app.InstrumentationRegistry.getInstrumentation())
        device.pressBack()
        compose.waitForIdle()
        compose.onNodeWithTag("navigation.records").assertIsSelected()
        assertEquals(0, actions)
    }
}
