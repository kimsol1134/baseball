package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.*
import kotlinx.coroutines.runBlocking
import java.nio.file.Files
import kotlin.test.*

class CareerMeaningApplicationTest {
    @Test fun careerMeaningCopyKeepsGoalsAndActualDeltasReadableInEveryLanguage() {
        val sources = listOf("지명 완료 · 입단 계약 전", "프로부터 새로 시작", "직접 2이닝 · 2실점 이하",
            "선발 · 5회부터 직접", "목표 달성 · 감독 신뢰 +2", "다음 등판: 선발 테스트", "피로 -12",
            "다음 구위 훈련 지원", "다음 제구 훈련 지원", "다음 변화구 훈련 지원", "다음 체력 훈련 지원", "다음 경기 운영 훈련 지원",
            "등판 때 주자 2명 승계", "1/6 아웃", "이번 생을 마무리하는 선택")
        for (language in listOf(GameLanguage.ENGLISH, GameLanguage.JAPANESE)) {
            val copy = GameCopy(language)
            for (source in sources) {
                val translated = copy.legacy(source)
                assertFalse(Regex("[가-힣]").containsMatchIn(translated), "$language: $source → $translated")
            }
        }
    }
    @Test fun draftResultHasOnlyTheCurrentPlayersContractPath() {
        val kernel = HighSchoolPhase4Kernel()
        val original = kernel.start(HighSchoolPhase4StartRequest("918220", "power_prospect", "draft-state", "2026-W37", "2026-09-08")).state
        for (outcome in HighSchoolDraftOutcome.entries) {
            val team = HighSchoolDraftTeamRules.bestTeam(original.run.pitcher)
            val run = HighSchoolKernel().resignShadowState(original.run.copy(phase = HighSchoolPhase.COMPLETED,
                draftResult = HighSchoolDraftResult(outcome, 72, "4라운드", team.id, team, 4, 32, 120000000)))
            val hs = kernel.commitShadowState(original.copy(run = run))
            val state = GameAggregateState.initial("draft-state").copy(stage = GameStage.HIGH_SCHOOL, highSchool = hs)
            val screen = Phase8ScreenProjection.project(state, Phase8ScreenId.P015_REBIRTH)
            assertTrue(screen.actions.none { it.id == "startDirect" })
            assertEquals(outcome == HighSchoolDraftOutcome.DRAFTED, screen.actions.any { it.id == "startLinked" && it.enabled })
            val status = ProfessionalStatusPresentation.section(state).rows.joinToString { it.value }
            assertTrue(status.contains(if (outcome == HighSchoolDraftOutcome.DRAFTED) "입단 계약 전" else "미지명"))
        }
        val opening = Phase8ScreenProjection.project(GameAggregateState.initial("new-pro"), Phase8ScreenId.P001_OPENING)
        assertTrue(opening.actions.single { it.id == "startDirect" }.label.contains("새로"))
    }
    @Test fun conversationPreviewMatchesTheCommittedChanges() {
        val k = HighSchoolPhase4Kernel()
        val start = k.start(HighSchoolPhase4StartRequest("918220", "power_prospect", "talk", "2026-W37", "2026-09-08")).state
        val ready = k.completePrologue("918220", k.beginTutorial(start).state).state
        val school = k.chooseSchool("918220", ready, HighSchoolSchoolId.HAEDONG_POWER).state
        val core = HighSchoolKernel()
        val event = HighSchoolContentCatalog.events.first { it.id == "evt-coach-role" }
        val run = core.resignShadowState(school.run.copy(phase = HighSchoolPhase.RELATIONSHIP, currentRelationshipCategory = "coach",
            currentRelationshipTarget = HighSchoolRelationshipTarget.COACH, currentRelationshipEvent = event, fatigue = 18))
        for (response in HighSchoolRelationshipResponse.entries) {
            val preview = ConversationPresentation.preview(run, "99881", response)
            val after = core.resolveRelationship(HighSchoolKernel.RelationshipRequest("99881", run, response)).snapshot
            assertEquals(ChoiceEffect.summary(ConversationPresentation.effectItems(run, after)), preview)
            assertTrue(preview.isNotBlank())
        }
    }
    @Test fun nativeStoreKeepsTrainingProgressAndActiveOutingAssignment() = runBlocking {
        val directory = Files.createTempDirectory("career-meaning-native-")
        val repository = CSharpLegacyGameStoreRepository(directory, "meaning-native")
        var store = KotlinGameStore.open("meaning-native", repository, NativeAuthorityMode.NATIVE_AUTHORITATIVE)
        try {
            var controller = Phase8Controller(store)
            controller.execute(Phase8ScreenId.P001_OPENING, "enterSetup")
            controller.execute(Phase8ScreenId.P002_SETUP, "startHighSchool")
            controller.execute(Phase8ScreenId.P003_PROLOGUE, "beginTutorial")
            controller.execute(Phase8ScreenId.P003_PROLOGUE, "completeTutorial")
            controller.execute(Phase8ScreenId.P005_SCHOOL_SELECTION, "chooseSchool:haedong_power")
            val phase7 = Phase7VerticalController(store)
            phase7.commitTraining()
            val development = assertNotNull(store.current.highSchool!!.run.development)
            store.close(); store = KotlinGameStore.open("meaning-native", repository, NativeAuthorityMode.NATIVE_AUTHORITATIVE)
            assertEquals(development, store.current.highSchool!!.run.development)
            controller = Phase8Controller(store)
            var guard = 0
            while (store.current.highSchool!!.run.phase != HighSchoolPhase.IMPORTANT_GAME && guard++ < 100) {
                val c = Phase7VerticalController(store)
                when (store.current.highSchool!!.run.phase) {
                    HighSchoolPhase.TRAINING -> c.commitTraining()
                    HighSchoolPhase.RELATIONSHIP -> c.resolveRelationship()
                    HighSchoolPhase.AWAKENING -> c.chooseAwakening()
                    HighSchoolPhase.CHAPTER_REVIEW -> c.advanceChapter()
                    else -> error("unexpected phase")
                }
            }
            assertTrue(guard < 100)
            controller.execute(Phase8ScreenId.P008_IMPORTANT_GAME, "openImportantGame")
            val assignment = assertNotNull(store.current.highSchool!!.activePitch!!.assignment)
            store.close(); store = KotlinGameStore.open("meaning-native", repository, NativeAuthorityMode.NATIVE_AUTHORITATIVE)
            assertEquals(assignment, store.current.highSchool!!.activePitch!!.assignment)
        } finally {
            store.close()
            Files.walk(directory).use { it.sorted(Comparator.reverseOrder()).forEach(Files::deleteIfExists) }
        }
    }
}
