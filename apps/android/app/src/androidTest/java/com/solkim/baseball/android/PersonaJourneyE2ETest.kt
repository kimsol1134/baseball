package com.solkim.baseball.android

import android.content.Intent
import android.os.SystemClock
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.*
import com.solkim.baseball.application.*
import com.solkim.baseball.application.fixtures.*
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test
import org.json.JSONObject
import java.io.File

/** Real native save + production Activities. Only the disposable audit application is accepted.
 * Long schedules use production commands (explicitly hybrid E2E), never edited player snapshots.
 */
class PersonaJourneyE2ETest {
    private val inst = InstrumentationRegistry.getInstrumentation()
    private val context = inst.targetContext
    private val device = UiDevice.getInstance(inst)
    private val store get() = (context.applicationContext as BaseballApplication).gameStore
    private val controller get() = ScreenController(store)
    @get:org.junit.Rule val evidenceOnFailure = object : org.junit.rules.TestWatcher() {
        override fun failed(error: Throwable, description: org.junit.runner.Description) {
            capture("failure-${description.methodName}")
            report("failure-${description.methodName}", JSONObject().put("error", error.toString()))
        }
    }
    private var deliveries = 0
    private fun guard() { require(context.packageName == "com.solkim.baseball.android.audit.compose.qa") }
    private fun launch() {
        guard(); device.wakeUp()
        context.startActivity(requireNotNull(context.packageManager.getLaunchIntentForPackage(context.packageName))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK))
        device.waitForIdle()
    }
    private fun capture(name: String) {
        device.waitForIdle()
        device.takeScreenshot(File(context.cacheDir, "persona-$name.png"))
        device.dumpWindowHierarchy(File(context.cacheDir, "persona-$name.xml"))
    }
    private fun tap(tag: String) {
        val selector = By.res(tag).pkg(context.packageName).enabled(true)
        for (attempt in 0..7) {
            device.waitForIdle()
            val node = device.wait(Until.findObject(selector), if (attempt == 0) 10_000 else 600)
            if (node != null && node.visibleBounds.height() > 8) {
                val bounds = node.visibleBounds
                SystemClock.sleep(350)
                val settled = device.findObject(selector)?.visibleBounds
                if (settled == null || settled != bounds) continue
                android.util.Log.i("PersonaE2E", "tap=$tag bounds=$bounds")
                device.click(bounds.centerX(), bounds.centerY()); device.waitForIdle(); return
            }
            device.swipe(device.displayWidth/2, device.displayHeight*3/4, device.displayWidth/2, device.displayHeight/3, 80)
            device.waitForIdle()
        }
        capture("missing-${tag.replace(':','-')}")
        fail("Visible action unavailable: $tag; phase=${controller.preferredScreen()}")
    }
    private fun waitTag(tag: String) { assertTrue("Missing $tag", device.wait(Until.hasObject(By.res(tag).pkg(context.packageName)), 20_000)) }
    private fun report(name: String, extra: JSONObject = JSONObject()) {
        extra.put("stage", store.current.stage.wire).put("revision", store.current.revision.toString())
            .put("life", CareerAccess.school(store.current)?.run?.lifeNumber).put("season", CareerAccess.pro(store.current)?.season)
            .put("defaultSlider", !store.current.settings.autoReleaseEnabled).put("albumPages", store.current.meta.album.size)
            .put("scriptedDeliveries", deliveries)
        File(context.cacheDir, "persona-$name.json").writeText(extra.toString(2))
    }
    private suspend fun action(screen: ScreenId = controller.preferredScreen(), id: String? = null, prefix: String? = null) {
        val option = controller.projection(screen).actions.firstOrNull { it.enabled && !it.destructive && (id == null || it.id == id) && (prefix == null || it.id.startsWith(prefix)) }
            ?: error("No $id/$prefix at $screen: ${controller.projection(screen).actions.map { it.id to it.enabled }}")
        controller.execute(screen, option.id, option.payloads)
    }
    private suspend fun important(pro: Boolean) {
        val pitchSession = PitchSessionController(store)
        val screen = if (pro) ScreenId.P018_PRO_IMPORTANT_GAME else ScreenId.P008_IMPORTANT_GAME
        var guard = 0
        while (if (pro) CareerAccess.pro(store.current)?.phase == ProCareerPhase.IMPORTANT_GAME else CareerAccess.school(store.current)?.run?.phase == HighSchoolPhase.IMPORTANT_GAME) {
            check(guard++ < 150) { "Outing did not end" }
            when (store.current.pitch?.boundary) {
                PitchBoundary.PLAYING -> {
                    val session = store.current.pitch!!.sessionId
                    val delivery = PitchDelivery(780 + (deliveries % 4)*45, 740 + (deliveries % 3)*60)
                    val request = pitchSession.submitPitch(session, PitchHudSelection.Primary, delivery)
                    pitchSession.consumePresentation(session, request)
                    deliveries++
                }
                PitchBoundary.TERMINAL -> pitchSession.completePitchAndPostgame(store.current.pitch!!.sessionId)
                else -> {
                    val actions = controller.projection(screen).actions
                    val candidates = if (pro) setOf("openProImportantGame", "nextProPitch", "finishProGame") else setOf("openImportantGame", "nextImportantPitch")
                    action(screen, id = actions.first { it.enabled && it.id in candidates }.id)
                }
            }
        }
    }

    @Test(timeout = 120_000) fun newcomerSelectsSchoolAndGetsPersistentTrainingFeedback() = runBlocking {
        guard(); assertEquals(HighSchoolPhase.SCHOOL_SELECTION, CareerAccess.school(store.current)!!.run.phase)
        launch()
        val school = device.wait(Until.findObject(By.res(java.util.regex.Pattern.compile("action.chooseSchool:.*")).enabled(true)), 20_000)
        assertNotNull(school); school!!.click()
        waitTag("training.commit")
        tap("training.focus.command"); tap("training.intensity.light")
        val before = CareerAccess.school(store.current)!!.run.totalTrainingsCompleted
        tap("training.commit")
        assertTrue(device.wait(Until.hasObject(By.text("훈련 완료")), 15_000))
        assertEquals(before+1, CareerAccess.school(store.current)!!.run.totalTrainingsCompleted)
        val count = CareerAccess.school(store.current)!!.run.totalTrainingsCompleted
        SystemClock.sleep(5000)
        assertTrue(device.wait(Until.hasObject(By.text("훈련 완료")), 15_000))
        capture("newcomer-feedback")
        device.pressHome(); SystemClock.sleep(500); launch()
        assertEquals(count, CareerAccess.school(store.current)!!.run.totalTrainingsCompleted)
        assertTrue(device.wait(Until.hasObject(By.text("훈련 완료")), 15_000))
        report("newcomer", JSONObject().put("trainings", count).put("feedbackSurvivedReturn", true))
    }

    @Test(timeout = 900_000) fun busyBaseballFanCompletesSeasonInspectsSharesAndRestoresRecords() = runBlocking {
        guard(); assertEquals(GameStage.OPENING, store.current.stage)
        launch(); tap("opening.proMode")
        val name = device.wait(Until.findObject(By.clazz("android.widget.EditText")), 10_000)!!
        name.click(); name.text = "기록덕후"
        device.wait(Until.findObject(By.text("프로 시작")), 10_000)!!.click()
        waitTag("week.commit")
        val week = CareerAccess.pro(store.current)!!.week
        tap("week.select.proPlan:refine_command")
        assertEquals(week, CareerAccess.pro(store.current)!!.week)
        tap("week.commit"); assertTrue(device.wait(Until.hasObject(By.text("이번 주의 변화")), 15_000))
        assertEquals(week+1, CareerAccess.pro(store.current)!!.week)
        capture("fan-week-result"); device.findObject(By.text("다음 일정으로")).click()
        var commands = 0
        while (CareerAccess.pro(store.current)!!.season < 2) {
            check(commands++ < 240) { "Season did not advance" }
            val pro = CareerAccess.pro(store.current)!!
            when (pro.phase) {
                ProCareerPhase.WEEKLY_PLAN -> action(ScreenId.P017_PRO_WEEK, "proAdvanceSegment")
                ProCareerPhase.IMPORTANT_GAME -> important(true)
                ProCareerPhase.SEASON_DECISION -> action(ScreenId.P019_PRO_SEASON, prefix = "seasonDecision:")
                ProCareerPhase.SEASON_REVIEW -> action(ScreenId.P019_PRO_SEASON, "reviewSeason")
                ProCareerPhase.SEASON_SETTLEMENT -> action(ScreenId.P019_PRO_SEASON, "acknowledgeSettlement")
                ProCareerPhase.NATIONAL_TEAM_CALL -> action(ScreenId.P019_PRO_SEASON, "nationalTeam:decline")
                ProCareerPhase.NATIONAL_TOURNAMENT -> action(ScreenId.P019_PRO_SEASON, "nationalTeam:acknowledge")
                ProCareerPhase.OFFSEASON_DECISION -> action(ScreenId.P020_OFFSEASON, "offseason:continue")
                ProCareerPhase.OFFSEASON_INVESTMENT -> action(ScreenId.P020_OFFSEASON, "investment:none")
                else -> error("Unexpected phase ${pro.phase}")
            }
        }
        val page = store.current.meta.album.single { it.scope.id == "pro:${CareerAccess.pro(store.current)!!.careerId}:1" }
        val season = CareerAccess.pro(store.current)!!.careerStats.single { it.season == 1 }
        assertTrue(season.games > 10); assertTrue(season.inningsOuts > 30)
        assertEquals(season.games, page.rows.size)
        assertEquals(season.inningsOuts, page.rows.sumOf { it.outs })
        val stats = AlbumPitchingStats.from(page)
        assertNotEquals("—", stats.whip)
        val backup = store.exportCareerBackup()
        assertEquals(store.current.meta.album, CareerBackup.preview(backup).meta.album)
        val destination = File(context.cacheDir, "persona-restored")
        var restored = KotlinGameStore.open("persona-second-install", CSharpLegacyGameStoreRepository(destination.toPath(), "persona-second-install"), NativeAuthorityMode.NATIVE_AUTHORITATIVE)
        try {
            restored.importCareerBackup(backup, restored.current.revision)
            assertEquals(store.current.meta.album, restored.current.meta.album)
            val original = restored.current
            val corrupt = backup.copyOf().also { it[it.size/2] = (it[it.size/2].toInt() xor 1).toByte() }
            var rejected = false
            try { restored.importCareerBackup(corrupt, restored.current.revision) } catch (_: Exception) { rejected = true }
            assertTrue("Damaged backup must be rejected", rejected)
            assertEquals(original, restored.current)
            val blocked = File(destination, "save.tmp")
            assertTrue(blocked.mkdir())
            val child = File(blocked, "persona-fault").apply { writeText("temporary fault") }
            val retry = GameCommandEnvelope("persona-retry", "persona-backup", restored.current.revision,
                GameCommand.UpdateSettings(restored.current.settings.copy(hapticsEnabled = !restored.current.settings.hapticsEnabled)))
            try {
                rejected = false
                try { restored.dispatch(retry) } catch (_: Exception) { rejected = true }
                assertTrue("Write failure must not be reported as a successful save", rejected)
                assertEquals(original, restored.current)
            } finally { child.delete(); assertTrue(blocked.delete()) }
            restored.dispatch(retry)
            assertEquals(original.revision + 1UL, restored.current.revision)
            assertEquals(original.meta.album, restored.current.meta.album)
            restored.close()
            restored = KotlinGameStore.open("persona-second-install", CSharpLegacyGameStoreRepository(destination.toPath(), "persona-second-install"), NativeAuthorityMode.NATIVE_AUTHORITATIVE)
            assertEquals(store.current.meta.album, restored.current.meta.album)
        } finally { restored.close() }
        inspectFanRecords()
        report("fan", JSONObject().put("automaticAndManualGames", season.games).put("inningsOuts", season.inningsOuts).put("whip", stats.whip).put("backupBytes", backup.size).put("restored", true).put("corruptBackupRejected", true).put("writeRetryRecovered", true))
    }

    @Test(timeout = 120_000) fun fanCanSharePersistedSeasonAfterColdRestart() {
        guard(); assertTrue(CareerAccess.pro(store.current)!!.season >= 2)
        inspectFanRecords()
    }
    private fun inspectFanRecords() {
        launch(); tap("navigation.records"); tap("records.tab.P-028"); tap("album.scopes")
        val option = device.wait(Until.findObject(By.textContains("기록덕후 · 프로 1시즌")), 10_000)
        assertNotNull(option); option!!.click()
        tap("album.pitching.stats")
        assertTrue(device.hasObject(By.text("WHIP")))
        capture("fan-season-stats")
        tap("album.card"); assertTrue(device.wait(Until.hasObject(By.text("카드 미리보기")), 10_000))
        capture("fan-share-card")
        val frozen = store.current
        device.findObject(By.text("공유")).click()
        assertTrue("System chooser must open", device.wait(Until.hasObject(By.pkg("com.android.intentresolver")), 10_000) || device.currentPackageName == "android")
        capture("fan-share-chooser"); device.pressBack()
        assertEquals(frozen, store.current)
    }

    @Test(timeout = 900_000) fun attachedPlayerFinishesSchoolAndRebirthKeepsThePreviousLife() = runBlocking {
        guard(); assertEquals(GameStage.OPENING, store.current.stage)
        action(ScreenId.P001_OPENING, "enterSetup")
        val setup = ScreenPayloads.startHighSchool(store.current, "나의투수", "부산", "precision_commander", controller.context)
        store.dispatch(GameCommandEnvelope("persona-school-start", CareerWire.UI_SESSION, store.current.revision, setup))
        action(ScreenId.P003_PROLOGUE, "beginTutorial")
        action(ScreenId.P004_PITCH_TUTORIAL, "openTutorialPitch")
        val pitchSession = PitchSessionController(store)
        val session = store.current.pitch!!.sessionId
        val request = pitchSession.submitPitch(session, PitchHudSelection.Primary, PitchDelivery(850, 820))
        pitchSession.consumePresentation(session, request); pitchSession.completePitchAndPostgame(session)
        action(ScreenId.P003_PROLOGUE, "completeTutorial")
        action(ScreenId.P005_SCHOOL_SELECTION)
        var steps = 0
        while (CareerAccess.school(store.current)!!.run.phase != HighSchoolPhase.DRAFT) {
            check(steps++ < 260) { "School did not finish" }
            when (CareerAccess.school(store.current)!!.run.phase) {
                HighSchoolPhase.IMPORTANT_GAME -> important(false)
                HighSchoolPhase.TRAINING -> {
                    val focus = if (CareerAccess.school(store.current)!!.run.fatigue > 60) TrainingFocus.RECOVERY else TrainingFocus.COMMAND
                    val payload = TrainingPresentation.payloads(store.current, controller.context, focus, TrainingIntensity.STANDARD, null, false)
                    controller.execute(ScreenId.P006_TRAINING, "train:${focus.wire}", payload)
                }
                HighSchoolPhase.RELATIONSHIP -> action(ScreenId.P007_RELATIONSHIP, "relationship:listen")
                else -> action()
            }
        }
        action(ScreenId.P013_DRAFT, "resolveDraft")
        action(ScreenId.P014_RUN_RECAP, "prepareLegacy")
        action(ScreenId.P014_RUN_RECAP, prefix = "selectLegacy:")
        action(ScreenId.P015_REBIRTH, "finalizeArchive")
        val prior = CareerAccess.school(store.current)!!.run
        val album = store.current.meta.album.single { it.scope.id == "hs:${prior.careerId}" }
        assertTrue(album.games > 0); assertTrue(album.rows.isNotEmpty())
        launch()
        if (device.wait(Until.hasObject(By.res("career.otherPath")), 1500)) tap("career.otherPath")
        capture("attached-before-rebirth"); tap("rebirth.path.closer")
        capture("attached-selected-closer"); tap("rebirth.path.start")
        assertTrue(device.wait(Until.hasObject(By.text("어떤 강점을 키울까요?")), 20_000))
        assertEquals(HighSchoolPhase.SCHOOL_SELECTION, CareerAccess.school(store.current)!!.run.phase)
        val deadline = android.os.SystemClock.elapsedRealtime() + 15_000
        while ((store.current.meta.companion?.careerPath != "closer" || store.current.meta.companion?.representative != "slider") && android.os.SystemClock.elapsedRealtime() < deadline) android.os.SystemClock.sleep(50)
        assertEquals("closer", store.current.meta.companion?.careerPath)
        assertEquals("slider", store.current.meta.companion?.representative)
        assertEquals("breaking_ball_artist", CareerAccess.school(store.current)!!.run.presetId)
        assertEquals(prior.lifeNumber+1, CareerAccess.school(store.current)!!.run.lifeNumber)
        assertEquals(prior.identity.name, CareerAccess.school(store.current)!!.run.identity.name)
        val preserved = store.current.meta.album.single { it.scope.id == album.scope.id }
        assertEquals(album.rows, preserved.rows); assertEquals(album.pitches, preserved.pitches)
        assertEquals(album.portraitSeed, preserved.portraitSeed)
        capture("attached-reborn"); device.pressHome(); launch()
        assertTrue(device.wait(Until.hasObject(By.text("어떤 강점을 키울까요?")), 20_000))
        assertFalse(store.current.settings.autoReleaseEnabled)
        report("attached", JSONObject().put("previousGames", album.games).put("previousOuts", album.outs).put("previousLife", prior.lifeNumber).put("draftOutcome", prior.draftResult?.outcome?.wire))
    }
}
