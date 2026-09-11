package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.*
import kotlin.test.*

class ChoiceEffectTest {
    @Test fun costsAreVisibleEvenWhenSeveralBenefitsComeFirstAndAllEffectsRemainAvailable() {
        val effects = listOf(ChoiceEffect("다음 등판: 선발 테스트"), ChoiceEffect("구위", 2), ChoiceEffect("피로", 6, false), ChoiceEffect("신뢰", -4, false))
        val highlights = ChoiceEffect.highlighted(effects)
        assertTrue(highlights.containsAll(effects.filter { !it.favorable }))
        assertEquals(4, effects.size)
        val text = ChoiceEffect.summary(effects)
        assertTrue(text.contains("피로 +6")); assertTrue(text.contains("신뢰 -4")); assertTrue(text.contains("외 1개"))
    }
    @Test fun completeRelationshipDescriptionsTranslateAtomicallyAndKeepSigns() {
        val k = HighSchoolPhase4Kernel()
        val base = k.start(HighSchoolPhase4StartRequest("918220", "power_prospect", "effect", "2026-W37", "2026-09-08")).state
        val school = k.chooseSchool("918220", k.completePrologue("918220", k.beginTutorial(base).state).state, HighSchoolSchoolId.HAEDONG_POWER).state
        val run = HighSchoolKernel().resignShadowState(school.run.copy(phase = HighSchoolPhase.RELATIONSHIP,
            currentRelationshipCategory = "coach", currentRelationshipTarget = HighSchoolRelationshipTarget.COACH,
            currentRelationshipEvent = HighSchoolContentCatalog.events.first { it.id == "evt-coach-role" }))
        val state = GameAggregateState.initial("effect").copy(highSchool = k.commitShadowState(school.copy(run = run)), stage = GameStage.HIGH_SCHOOL)
        for (language in GameLanguage.entries) {
            val model = ScreenProjection.project(state, ScreenId.P007_RELATIONSHIP).localized(GameCopy(language), state)
            for (action in model.actions) {
                if (language != GameLanguage.KOREAN) assertFalse(Regex("[가-힣]").containsMatchIn(action.description), action.description)
                action.effects.filter { !it.favorable }.forEach { effect -> assertTrue(action.description.contains("${if (effect.delta!! > 0) "+" else ""}${effect.delta}")) }
            }
        }
    }
}
