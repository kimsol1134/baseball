package com.solkim.baseball.android

import android.content.Intent
import android.graphics.Rect
import android.os.SystemClock
import android.util.Log
import android.view.InputDevice
import android.view.MotionEvent
import android.widget.EditText
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.UiObject2
import androidx.test.uiautomator.UiScrollable
import androidx.test.uiautomator.UiSelector
import androidx.test.uiautomator.Until
import java.io.ByteArrayOutputStream
import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Cold-open first session through high school and 20 pro seasons.
 * UiDevice only: a Compose test rule freezes mound input.
 */
@RunWith(AndroidJUnit4::class)
class FirstUserEmulatorE2ETest {
    @Test(timeout = 1_200_000)
    fun coldOpenThroughProSeason20() {
        val inst = InstrumentationRegistry.getInstrumentation()
        val device = UiDevice.getInstance(inst)
        val app = inst.targetContext
        val smokeOnly = InstrumentationRegistry.getArguments().getString("launchSmokeOnly") == "true"
        val launch = app.packageManager.getLaunchIntentForPackage(app.packageName)
            ?: error("missing launch intent")
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        app.startActivity(launch)
        run {
            fun waitText(text: String, timeoutMs: Long = 20_000): Boolean =
                device.wait(Until.hasObject(By.textContains(text)), timeoutMs)

            fun tapText(text: String) {
                val node = device.wait(Until.findObject(By.text(text)), 15_000)
                assertTrue("missing exact action $text", node != null)
                requireNotNull(node).click()
            }

            fun hierarchyXml(): String = runCatching {
                val stream = ByteArrayOutputStream()
                device.dumpWindowHierarchy(stream)
                stream.toString("UTF-8")
            }.getOrDefault("")

            fun visibleTexts(): String =
                Regex("(?:text|content-desc)=\"([^\"]+)\"")
                    .findAll(hierarchyXml())
                    .map { it.groupValues[1] }
                    .filter { it.isNotBlank() }
                    .distinct()
                    .joinToString(" | ")

            fun dump(tag: String) {
                val texts = visibleTexts()
                Log.i(TAG, "$tag texts=$texts")
                val xmlFile = File(inst.targetContext.cacheDir, "e2e-$tag.xml")
                device.dumpWindowHierarchy(xmlFile)
                runCatching { device.takeScreenshot(File(inst.targetContext.cacheDir, "e2e-$tag.png")) }
                val extra = InstrumentationRegistry.getArguments().getString("additionalTestOutputDir")?.let(::File)
                if (extra != null) {
                    runCatching {
                        extra.mkdirs()
                        device.dumpWindowHierarchy(File(extra, "e2e-$tag.xml"))
                        device.takeScreenshot(File(extra, "e2e-$tag.png"))
                    }
                }
            }

            fun hasText(text: String): Boolean = device.hasObject(By.text(text))
            fun hasContains(text: String): Boolean = device.hasObject(By.textContains(text))

            fun atProCap(): Boolean =
                hasText("은퇴하고 기록 남기기") || hasText("은퇴 결정")

            fun waitNotBusy() {
                val deadline = System.currentTimeMillis() + 25_000
                while (System.currentTimeMillis() < deadline && hasText("저장 중")) {
                    Thread.sleep(150)
                }
            }

            fun scrollDown() {
                val w = device.displayWidth
                val h = device.displayHeight
                device.swipe(w / 2, (h * 0.72).toInt(), w / 2, (h * 0.28).toInt(), 28)
                Thread.sleep(250)
            }

            fun isBlocked(node: UiObject2): Boolean {
                var current: UiObject2? = node
                repeat(6) {
                    val obj = current ?: return false
                    val description = obj.contentDescription ?: ""
                    if (!obj.isEnabled) return true
                    if (description.contains("지금은 선택할 수 없습니다")) return true
                    current = obj.parent
                }
                return false
            }

            fun tapLast(text: String): Boolean {
                val nodes = device.findObjects(By.text(text)).filterNot(::isBlocked)
                if (nodes.isEmpty()) return false
                nodes.last().click()
                return true
            }

            fun tapLastContains(text: String): Boolean {
                val nodes = device.findObjects(By.textContains(text)).filterNot(::isBlocked)
                if (nodes.isEmpty()) return false
                nodes.last().click()
                return true
            }

            fun throwSlider(): Boolean {
                if (!hasText("누르고 있다가 놓기") && !device.hasObject(By.descContains("투구 슬라이더"))) {
                    return false
                }
                Thread.sleep(500)
                var threw = hasText("투구 다시 보기")
                var attempt = 0
                while (!threw && attempt < 3) {
                    val box = sliderBounds(device)
                    if (box.width() <= 40 || box.height() <= 20) return false
                    Log.i(TAG, "hold attempt=$attempt bounds=$box")
                    holdFinger(box.centerX(), box.centerY(), holdMs = 900L)
                    threw = device.wait(Until.hasObject(By.text("투구 다시 보기")), 12_000)
                    attempt += 1
                }
                return threw || hasText("투구 다시 보기")
            }

            fun schoolNameFromDump(): String? {
                val names = Regex("""text="([^"]+고)"""")
                    .findAll(hierarchyXml())
                    .map { it.groupValues[1] }
                    .filter { name ->
                        name.length >= 3 &&
                            !name.contains("고교") &&
                            name != "고" &&
                            !name.contains("학교 후보")
                    }
                    .distinct()
                    .toList()
                return names.firstOrNull()
            }

            fun advanceOnce(step: Int): Boolean {
                if (atProCap()) return false
                if (hasText("누르고 있다가 놓기") || device.hasObject(By.descContains("투구 슬라이더"))) {
                    assertTrue("slider throw failed at step=$step visible=${visibleTexts()}", throwSlider())
                    return true
                }
                waitNotBusy()
                val training = device.findObjects(By.res("training.commit")).filterNot(::isBlocked)
                if (training.isNotEmpty()) {
                    training.first().click()
                    Log.i(TAG, "step=$step tap=training")
                    return true
                }
                val actions = listOf(
                    "다음 공 던지기",
                    "평소 간격을 지킨다",
                    "불펜에서만 연습한다",
                    "2군에서 재정비한다",
                    "내 방식을 지킨다",
                    "결과 화면으로",
                    "기록 보관하기",
                    "프로 무대로 가기",
                    "계약 서명",
                    "구간 건너뛰기",
                    "등판하기",
                    "경기 결과 확인",
                    "시즌 결산 보기",
                    "계속하기",
                    "강속구 불펜",
                    "한 타자 강속구",
                    "포심 위력 다듬기",
                    "결정구 완성",
                    "코스 제구 훈련",
                    "긴 이닝 루틴",
                    "연투 버티기",
                    "회복",
                    "베테랑 회복 루틴",
                    "로테이션 신뢰 쌓기",
                    "필승조 신뢰 쌓기",
                    "콜업 경쟁 집중",
                    "주무기 다듬기",
                    "강하게 더 던진다",
                    "변화구만 다듬는다",
                    "오늘은 멈춘다",
                    "포수와 함께 짠다",
                    "감독 보고서를 따른다",
                    "내 공을 밀어붙인다",
                    "선발에 도전한다",
                    "구원에 집중한다",
                    "마무리를 맡는다",
                    "탈삼진을 노린다",
                    "실점 억제를 택한다",
                    "몸을 관리한다",
                    "약점을 깊게 판다",
                    "내 장점을 유지한다",
                    "맞대결까지 보류한다",
                    "순위 경쟁에 건다",
                    "회복을 우선한다",
                    "젊은 선수를 돕는다",
                    "회복 주를 택한다",
                    "밀어붙인다",
                    "구원으로 몸을 낮춘다",
                    "선발을 지킨다",
                    "불펜으로 옮긴다",
                    "회복 연도를 택한다",
                    "투구 연습하기",
                    "연습 시작",
                    "학교 선택하기",
                    "투구 결과 확인하기",
                    "등판하기",
                    "다음 타자 상대하기",
                    "투구 이어 하기",
                    "다음 장으로",
                    "드래프트 결과 확인",
                    "유산 후보 보기",
                    "기록 보관하기",
                    "드래프트 결과 확인 완료",
                    "결산 확인 완료",
                    "끝까지 듣기",
                    "내 뜻 설명하기",
                    "정면 승부하기",
                    "폭발적인 직구",
                    "떠오르는 포심",
                    "강철 어깨",
                    "후반의 여유",
                    "한 점의 끝",
                    "흔들리지 않는 릴리스",
                    "첫 공 스트라이크",
                    "위기 속 평정",
                    "스카우트 앞의 침착함",
                    "사라지는 변화구",
                    "넓게 휘는 슬라이더",
                    "커브의 시계",
                    "멈춘 체인지업",
                    "싱커 터널",
                    "배터리 호흡",
                    "투 스트라이크 설계",
                    "견제 리듬",
                    "주자 흐름 읽기",
                    "마운드에 남은 불꽃",
                    "미트 끝의 지도",
                    "손끝에 남은 궤적",
                    "긴 이닝의 호흡",
                    "이닝을 읽는 장부",
                    "사인 사이의 약속",
                    "제구",
                    "구위",
                    "무브먼트",
                    "체력",
                    "회복",
                    "경기 계획",
                )
                for (label in actions) {
                    if (tapLast(label)) {
                        Log.i(TAG, "step=$step tap=$label")
                        when (label) {
                            "프로 무대로 가기", "계약 서명" -> {
                                device.wait(Until.hasObject(By.text("구간 건너뛰기")), 15_000) ||
                                    device.wait(Until.hasObject(By.text("계약 서명")), 3_000) ||
                                    device.wait(Until.hasObject(By.text("이번 주")), 3_000)
                            }
                            "결과 화면으로", "잠시 나가기" -> {
                                val deadline = System.currentTimeMillis() + 15_000
                                while (System.currentTimeMillis() < deadline) {
                                    if (listOf("다음 선택", "이번 주 선택", "도착한 편지", "성장 신호", "학교 후보", "승부처", "이 장의 기록", "드래프트", "이번 생", "다음 생", "새로운 감각")
                                            .any { hasText(it) || hasContains(it) }
                                    ) {
                                        break
                                    }
                                    Thread.sleep(200)
                                }
                            }
                            "연습 시작", "등판하기", "등판하기", "다음 타자 상대하기", "투구 이어 하기", "투구 결과 확인하기" -> {
                                device.wait(Until.hasObject(By.text("누르고 있다가 놓기")), 20_000) ||
                                    device.wait(Until.hasObject(By.descContains("투구 슬라이더")), 2_000)
                            }
                        }
                        return true
                    }
                }
                schoolNameFromDump()?.let { school ->
                    if (tapLast(school)) {
                        Log.i(TAG, "step=$step school=$school")
                        return true
                    }
                }
                if (hasContains("학교") && tapLastContains("고")) {
                    Log.i(TAG, "step=$step tap school by 고")
                    return true
                }
                if (tapLast("← 이야기")) {
                    Log.i(TAG, "step=$step back to story")
                    return true
                }
                return false
            }

            assertTrue("opening or player setup", waitText("다시 도전하는 야구 인생") || waitText("선수 이름"))
            if (hasText("시작하기")) {
                tapText("시작하기")
            }
            assertTrue("setup", waitText("선수 이름"))

            val name = device.findObject(UiSelector().className(EditText::class.java.name).instance(0))
            name.click()
            name.setText("민서준")
            repeat(2) {
                if (!hasText("다음")) UiScrollable(UiSelector().scrollable(true)).scrollIntoView(UiSelector().text("다음"))
                tapText("다음")
                device.waitForIdle()
            }
            if (hasText("힘으로 승부하는 투수")) {
                device.findObject(By.text("힘으로 승부하는 투수")).click()
            }
            if (!hasText("이 투수로 시작하기")) {
                UiScrollable(UiSelector().scrollable(true)).scrollIntoView(UiSelector().text("이 투수로 시작하기"))
            }
            tapText("이 투수로 시작하기")
            assertTrue(
                "prologue or tutorial",
                waitText("투구 연습하기") || waitText("연습 시작") || waitText("도착한 편지"),
            )

            fun storyFingerprint(): String =
                visibleTexts()
                    .split(" | ")
                    .filterNot { token ->
                        token.contains("Battery") ||
                            token.contains("signal") ||
                            token.contains("notification") ||
                            token.contains("PM") ||
                            token.contains("AM") ||
                            token.matches(Regex("""\d{1,2}:\d{2}.*"""))
                    }
                    .joinToString(" | ")

            var step = 0
            var idle = 0
            while (!atProCap() && step < 900) {
                waitNotBusy()
                val before = storyFingerprint()
                val moved = advanceOnce(step)
                Thread.sleep(400)
                waitNotBusy()
                val after = storyFingerprint()
                if (smokeOnly && hasText("투구 다시 보기")) {
                    dump("first-slider-result")
                    return@run
                }
                if (!moved || before == after) {
                    scrollDown()
                    idle += 1
                    if (idle % 3 == 0) dump("stuck-$step")
                    assertTrue(
                        "stuck before pro season 20 at step=$step visible=$after",
                        idle < 16,
                    )
                } else {
                    idle = 0
                    if (step % 8 == 0) {
                        Log.i(TAG, "progress step=$step texts=$after")
                    }
                }
                step += 1
            }

            if (!atProCap()) dump("pro-cap-missing")
            assertTrue(
                "pro career must reach season 20 retirement. visible=${visibleTexts()}",
                atProCap(),
            )
            dump("pro-season-20")
        }
    }

    private fun sliderBounds(device: UiDevice): Rect {
        val byDesc = device.findObject(By.descContains("투구 슬라이더"))
        if (byDesc != null) return byDesc.visibleBounds
        val byText = device.findObject(By.text("누르고 있다가 놓기"))
        if (byText != null) return byText.visibleBounds
        error("slider pad not on screen")
    }

    private fun holdFinger(x: Int, y: Int, holdMs: Long) {
        val inst = InstrumentationRegistry.getInstrumentation()
        val downTime = SystemClock.uptimeMillis()
        fun event(action: Int, at: Long): MotionEvent {
            val props = arrayOf(
                MotionEvent.PointerProperties().also {
                    it.id = 0
                    it.toolType = MotionEvent.TOOL_TYPE_FINGER
                },
            )
            val coords = arrayOf(
                MotionEvent.PointerCoords().also {
                    it.x = x.toFloat()
                    it.y = y.toFloat()
                    it.pressure = 1f
                    it.size = 0.5f
                },
            )
            return MotionEvent.obtain(
                downTime,
                at,
                action,
                1,
                props,
                coords,
                0,
                0,
                1f,
                1f,
                0,
                0,
                InputDevice.SOURCE_TOUCHSCREEN,
                0,
            )
        }
        val down = event(MotionEvent.ACTION_DOWN, downTime)
        try {
            inst.sendPointerSync(down)
        } catch (error: Throwable) {
            Log.w(TAG, "sendPointerSync DOWN failed, injecting", error)
            inst.uiAutomation.injectInputEvent(down, true)
        } finally {
            down.recycle()
        }
        val deadline = downTime + holdMs
        while (SystemClock.uptimeMillis() < deadline) {
            Thread.sleep(40)
            val move = event(MotionEvent.ACTION_MOVE, SystemClock.uptimeMillis())
            try {
                inst.sendPointerSync(move)
            } catch (_: Throwable) {
                inst.uiAutomation.injectInputEvent(move, true)
            } finally {
                move.recycle()
            }
        }
        val up = event(MotionEvent.ACTION_UP, SystemClock.uptimeMillis())
        try {
            inst.sendPointerSync(up)
        } catch (_: Throwable) {
            inst.uiAutomation.injectInputEvent(up, true)
        } finally {
            up.recycle()
        }
    }

    private companion object {
        const val TAG = "FirstUserE2E"
    }
}
