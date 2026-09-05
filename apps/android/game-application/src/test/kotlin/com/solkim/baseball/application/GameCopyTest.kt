package com.solkim.baseball.application

import kotlin.test.*

class GameCopyTest {
    @Test fun releaseWindowCopyFormatsActualPercentagesInEveryLanguage() {
        for (language in GameLanguage.entries) {
            val copy = GameCopy(language)
            val text = copy.resolve("control.window.accessibility", GameCopyArgument.Decimal(24.0))
            assertTrue(text.contains("24.0%"), text)
            val comparison = copy.resolve("control.window.comparison", GameCopyArgument.Decimal(18.0), GameCopyArgument.Decimal(24.0))
            assertTrue(comparison.contains("18.0%") && comparison.contains("24.0%"), comparison)
            if (language != GameLanguage.KOREAN) assertFalse(Regex("[가-힣]").containsMatchIn(text))
        }
    }

    @Test fun signatureEffectsUseActualBonusesAndNativeLabelsInEveryLocale() {
        for (language in GameLanguage.entries) {
            val copy = GameCopy(language)
            for (definition in com.solkim.baseball.core.highschool.HighSchoolSignatureLegacyRules.definitions) {
                val effect = assertNotNull(SignatureLegacyDisplay.effect(definition.id, copy))
                assertFalse(effect.contains("+0"))
                assertFalse(effect.contains("중심"))
                if (language != GameLanguage.KOREAN) assertFalse(Regex("[가-힣]").containsMatchIn(effect))
            }
        }
        assertEquals("球威 +3 · スタミナ +1", SignatureLegacyDisplay.effect("power_imprint", GameCopy(GameLanguage.JAPANESE)))
    }

    @Test fun editedKoreanAlsoAppliesToOldSavedSentencesWithoutChangingPlayerNames() {
        val source = "제구 중심으로 한 블록 훈련합니다."
        assertEquals("제구 훈련을 합니다.", GameCopy(GameLanguage.KOREAN).legacy(source))
        assertEquals("제구 중심으로 한 블록 훈련합니다.", source)
        assertEquals("투구 연습하기", GameCopy(GameLanguage.KOREAN).legacy("첫 사인 익히기"))
        assertEquals("Practice pitching", GameCopy(GameLanguage.ENGLISH).legacy("첫 사인 익히기"))
        assertEquals("投球を練習する", GameCopy(GameLanguage.JAPANESE).legacy("첫 사인 익히기"))
        assertEquals("첫 사인 익히기", GameCopy(GameLanguage.KOREAN).legacy("첫 사인 익히기", setOf("첫 사인 익히기")))
    }
    @Test fun sourceCataloguesResolveExplicitKeysInAllThreeLanguages() {
        assertEquals("선수 만들기", GameCopy(GameLanguage.KOREAN).resolve("android.setup.title"))
        assertEquals("Create your pitcher", GameCopy(GameLanguage.ENGLISH).resolve("android.setup.title"))
        assertEquals("投手を作成", GameCopy(GameLanguage.JAPANESE).resolve("android.setup.title"))
    }
    @Test fun typedArgumentsAndLegacyCompatibilityPreservePlayerText() {
        val en = GameCopy(GameLanguage.ENGLISH)
        assertEquals("Spirit shop · balance 240 · spending 90", en.resolve("android.rebirth.boost-wallet", GameCopyArgument.Whole(240), GameCopyArgument.Whole(90)))
        assertEquals("Spirit shop · Available 240 · Cost 90", en.legacy("영혼 상점 · 잔액 240 · 사용 90"))
        assertEquals("포심", en.legacy("포심", userTexts = setOf("포심")))
        assertEquals("Four-seam", en.legacy("포심"))
        assertFails { en.resolve("android.rebirth.boost-wallet", GameCopyArgument.UserText("240")) }
    }
    @Test fun localeSelectionSupportsRegionalTagsAndNeverChangesTheSource() {
        assertEquals(GameLanguage.ENGLISH, GameLanguage.fromTag("en-US"))
        assertEquals(GameLanguage.JAPANESE, GameLanguage.fromTag("ja_JP"))
        val source = "제구 회복 +3 · 실전 시험을 마쳤습니다."
        assertEquals("Control restored +3 · Live trial complete.", GameCopy(GameLanguage.ENGLISH).legacy(source))
        assertEquals("제구 회복 +3 · 실전 시험을 마쳤습니다.", source)
    }

    @Test fun composedRationaleAndSelectionAccessibilityAreLocalized() {
        for (language in listOf(GameLanguage.ENGLISH, GameLanguage.JAPANESE)) {
            val copy = GameCopy(language)
            val reason = copy.sentences("타자의 약점 구종과 코스를 공략합니다. 강속구형의 포심·구속 강점을 반영한 사인입니다.")
            assertFalse(Regex("[가-힣]").containsMatchIn(reason), reason)
            assertFalse(Regex("[가-힣]").containsMatchIn(copy.legacy("포수 추천 선택됨")))
            assertFalse(Regex("[가-힣]").containsMatchIn(copy.legacy("커브 선택 가능")))
        }
    }

    @Test fun namesThatResembleNumbersOrPitchNamesAreNeverRewritten() {
        val en = GameCopy(GameLanguage.ENGLISH)
        assertEquals("사용자이름구", en.legacy("사용자이름구"))
        assertEquals("사용자이름원", en.legacy("사용자이름원"))
        val pro = com.solkim.baseball.core.pro.ProKernel().startDirect(
            com.solkim.baseball.core.pro.ProStartDirectRequest("7841", "power_prospect", "포심")).state
        val state = GameAggregateState.initial("copy-name").copy(pro = pro, stage = GameStage.PRO)
        val id = Phase8ScreenId.P025_RECORDS_LEAGUE
        val model = Phase8ScreenModel(id, "기록", "기록", listOf(Phase8Section("test", "기록", listOf(
            Phase8Row("선수", "포심"), Phase8Row("구종", "포심"),
        ))), emptyList(), Phase8Payloads.view(state, id)).localized(en, state)
        assertEquals("포심", model.sections.single().rows[0].value)
        assertEquals("Four-seam", model.sections.single().rows[1].value)
    }
}
