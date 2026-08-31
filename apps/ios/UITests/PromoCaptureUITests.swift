import XCTest

/// 홍보 영상용 실사 촬영. `simctl io recordVideo`를 켜 둔 채로 이 테스트를 돌리면
/// 사람이 조작하는 속도로 앱을 한 바퀴 걷는다. 시뮬레이터 녹화는 기기 해상도 그대로(@3x)
/// 나오므로 별도 확대가 필요 없다.
///
/// 실행:
///   xcrun simctl io booted recordVideo --codec h264 raw.mov &
///   xcodebuild test -only-testing:BaseballIOSUITests/PromoCaptureUITests …
///
/// 이 테스트는 무엇도 검증하지 않는다 — 촬영 도구다. 사람이 읽을 시간을 벌려고 일부러
/// 멈추므로 1분 가까이 걸린다. CI는 `-skip-testing`으로 제외한다(.github/workflows/ci.yml).
final class PromoCaptureUITests: XCTestCase {
    private let timeout: TimeInterval = 12
    private var startedAt = Date()

    private func launchArguments(_ arguments: [String]) -> [String] {
        let bundled = Bundle(for: PromoCaptureUITests.self)
            .object(forInfoDictionaryKey: "BaseballCaptureLanguage") as? String
        let language = (bundled?.isEmpty == false ? bundled : nil)
            ?? ProcessInfo.processInfo.environment["BASEBALL_CAPTURE_LANGUAGE"]
        guard language == "en" || language == "ja" else {
            return arguments
        }
        if language == "ja" {
            return arguments + ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        }
        return arguments + ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// 각성은 되돌릴 수 없어 확인 창이 뜬다.
    private func confirmAwakening(_ app: XCUIApplication) {
        let confirm = app.buttons.matching(identifier: "hs.awakening.confirm").firstMatch
        if confirm.waitForExistence(timeout: 3) { confirm.tap() }
    }

    /// 편집점을 찾을 때 쓴다. 녹화 시작과 앱 실행 사이의 지연은 알 수 없으므로
    /// 절대 시각이 아니라 "테스트 시작 이후 경과"를 남기고, 최종 컷은 프레임을 보고 맞춘다.
    private func mark(_ name: String) {
        let elapsed = Date().timeIntervalSince(startedAt)
        print(String(format: "PROMO_MARK %.2f %@", elapsed, name))
    }

    /// 화면을 그대로 두는 시간. 사람이 읽을 틈이 없으면 영상에서 아무것도 보이지 않는다.
    /// 1회차에는 오프닝 장면이 먼저 뜬다. 넘기지 않으면 선수 만들기 화면에 닿지 못한다.
    private func dismissOpening(_ app: XCUIApplication) {
        let start = app.buttons["hs.opening.start"]
        if start.waitForExistence(timeout: 5) { start.tap() }
    }

    /// 단계형 선수 만들기를 마지막 단계까지 넘긴다. `hs.start`가 보이면 참을 돌려준다.
    @discardableResult
    private func advanceSetup(_ app: XCUIApplication) -> Bool {
        let start = app.buttons["hs.start"]
        let next = app.buttons["hs.setup.next"]
        guard start.waitForExistence(timeout: timeout) || next.waitForExistence(timeout: timeout) else { return false }
        var hops = 0
        while !start.exists, next.exists, hops < 6 {
            next.tap()
            hops += 1
        }
        return start.waitForExistence(timeout: timeout)
    }

    private func hold(_ seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }

    /// 제스처 컷. 누르고 → 끌고 → 떼는 손동작 자체를 담는다. 조준이 흔들려 결과는 대체로
    /// 나쁘게 나오므로 영상에서는 "던지는 방법"을 보여 주는 짧은 컷으로만 쓴다.
    func testGestureForPromoVideo() {
        let app = XCUIApplication()
        app.launchArguments = launchArguments(["-uiTestResetCareer", "-uiTestPromoCapture"])
        app.launch()
        startedAt = Date()

        // 1회차는 오프닝 장면이 먼저 뜬다. 넘기지 않으면 선수 만들기에 닿지 못한다.
        dismissOpening(app)
        XCTAssertTrue(advanceSetup(app), "선수 만들기 화면이 열리지 않았습니다.")
        hold(1.0)
        app.buttons["hs.start"].tap()
        XCTAssertTrue(app.buttons["hs.prologue.throw"].waitForExistence(timeout: timeout))
        hold(1.0)
        app.buttons["hs.prologue.throw"].tap()

        let pad = app.descendants(matching: .any).matching(identifier: "pitch.windup").firstMatch
        XCTAssertTrue(pad.waitForExistence(timeout: timeout), "와인드업 패드가 없습니다.")
        hold(2.5)

        for index in 0..<2 {
            let currentPad = app.descendants(matching: .any).matching(identifier: "pitch.windup").firstMatch
            guard currentPad.exists, currentPad.isHittable else { break }
            mark("gesture-press-\(index)")
            currentPad.press(
                forDuration: 0.9,
                thenDragTo: currentPad,
                withVelocity: .slow,
                thenHoldForDuration: 0.2
            )
            mark("gesture-release-\(index)")
            hold(3.0)
            let nextBatter = app.buttons["pitch.nextBatter"]
            if nextBatter.exists, nextBatter.isHittable {
                nextBatter.tap()
                hold(1.0)
            }
        }
        mark("gesture-end")
        hold(1.0)
    }

    /// 본편. 자동 릴리스로 제구가 안정되어 스트라이크와 타구가 골고루 나온다.
    /// 승부 장면(PitchDramaView)은 던진 직후 1.6초만 재생되므로, 매 구 직후의 정지 시간을
    /// 애니메이션 길이에 맞춰 잡는다. 마커가 그대로 편집점이 된다.
    func testWalkthroughForPromoVideo() {
        let app = XCUIApplication()
        app.launchArguments = launchArguments([
            "-uiTestResetCareer", "-uiTestAutoRelease", "-uiTestPromoCapture",
        ])
        app.launch()
        startedAt = Date()
        mark("launch")

        dismissOpening(app)
        XCTAssertTrue(advanceSetup(app), "고교 시작 화면이 열리지 않았습니다.")
        hold(2.0)
        mark("setup")
        app.buttons["hs.start"].tap()

        let throwFirst = app.buttons["hs.prologue.throw"]
        XCTAssertTrue(throwFirst.waitForExistence(timeout: timeout), "프롤로그가 열리지 않았습니다.")
        hold(2.5)
        mark("prologue")
        throwFirst.tap()

        // 1) 승부 결정 화면: 구종·코스·포수 사인
        let throwButton = app.buttons["pitch.throw"]
        XCTAssertTrue(throwButton.waitForExistence(timeout: timeout), "승부 화면이 열리지 않았습니다.")
        hold(3.5)
        mark("decision")

        // 2) 승부 장면. 영상의 중심이라 결과가 갈릴 때까지 여러 구를 담는다.
        for index in 0..<12 {
            let button = app.buttons["pitch.throw"]
            if button.exists, button.isHittable {
                mark("throw-\(index)")
                button.tap()
                // 1.6초 재생 + 판정을 읽는 시간. 여기가 실제로 쓰는 컷이다.
                hold(1.7)
                mark("verdict-\(index)")
                hold(1.6)
            }

            let nextBatter = app.buttons["pitch.nextBatter"]
            if nextBatter.exists, nextBatter.isHittable {
                mark("batter-done-\(index)")
                hold(1.2)
                nextBatter.tap()
                hold(0.8)
                continue
            }
            if app.buttons["pitch.finish"].exists { break }
        }

        // 3) 이닝을 닫고 고교 진행으로 돌아간다.
        let finish = app.buttons["pitch.finish"]
        if finish.waitForExistence(timeout: timeout) {
            mark("inning-finished")
            hold(2.5)
            finish.tap()
        }

        // 4) 학교 선택 → 훈련 결과. 육성이 있다는 것을 보여 주는 컷.
        var steps = 0
        var showedTraining = false
        while steps < 40 {
            steps += 1
            let schools = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "hs.school."))
            if schools.count > 0, schools.element(boundBy: 0).exists {
                mark("school")
                hold(3.0)
                schools.element(boundBy: 0).tap()
                // 되돌릴 수 없는 선택이라 확인 창이 뜬다.
                let confirm = app.buttons.matching(identifier: "hs.school.confirm").firstMatch
                if confirm.waitForExistence(timeout: 3) {
                    hold(1.5)
                    confirm.tap()
                }
                hold(1.0)
                continue
            }
            if app.buttons["hs.training.commit"].exists {
                if !showedTraining {
                    showedTraining = true
                    mark("training")
                    hold(1.2)
                    // 손가락으로 끄는 동안은 XCUITest가 애니메이션을 꺼도 화면이 실제로 움직인다.
                    // 목록이 길다는 사실은 정지 캡처로는 보여 줄 수 없다.
                    mark("training-scroll")
                    app.swipeUp(velocity: .slow)
                    hold(1.0)
                    app.swipeDown(velocity: .slow)
                    hold(1.4)
                }
                app.buttons["hs.training.commit"].tap()
                hold(1.5)
                if showedTraining {
                    mark("training-result")
                    hold(3.0)
                    break
                }
                continue
            }
            if app.buttons["hs.chapter.continue"].exists {
                app.buttons["hs.chapter.continue"].tap()
                hold(1.0)
                continue
            }
            if app.buttons["hs.prologue.continue"].exists {
                app.buttons["hs.prologue.continue"].tap()
                hold(1.0)
                continue
            }
            break
        }

        mark("end")
        hold(1.5)
    }

    /// 광고 히어로 컷. 투구 슬라이더를 보여 주고, 퍼펙트 릴리스로 던진 뒤 삼진이 날 때까지 반복한다.
    /// `simctl io recordVideo`를 켠 채로 실행한다.
    func testPerfectSliderStrikeoutForAd() {
        let app = XCUIApplication()
        app.launchArguments = launchArguments([
            "-uiTestResetCareer",
            "-uiTestPromoCapture",
            "-uiTestPerfectRelease",
        ])
        app.launch()
        startedAt = Date()
        mark("launch")

        dismissOpening(app)
        XCTAssertTrue(advanceSetup(app), "선수 만들기 화면이 열리지 않았습니다.")
        hold(1.2)
        app.buttons["hs.start"].tap()

        let throwFirst = app.buttons["hs.prologue.throw"]
        XCTAssertTrue(throwFirst.waitForExistence(timeout: timeout), "프롤로그가 열리지 않았습니다.")
        hold(1.6)
        mark("prologue")
        throwFirst.tap()

        let padQuery = app.descendants(matching: .any).matching(identifier: "pitch.windup")
        XCTAssertTrue(padQuery.firstMatch.waitForExistence(timeout: timeout), "투구 슬라이더가 없습니다.")
        hold(2.2)
        mark("slider-visible")

        var caughtStrikeout = false
        for index in 0..<16 {
            let pad = padQuery.firstMatch
            guard pad.exists, pad.isHittable else { break }

            mark("slider-press-\(index)")
            pad.press(forDuration: 0.85, thenDragTo: pad, withVelocity: .slow, thenHoldForDuration: 0.15)
            mark("perfect-release-\(index)")
            hold(1.8)

            if app.staticTexts["삼진"].exists {
                mark("strikeout")
                hold(3.4)
                caughtStrikeout = true
                break
            }
            if app.staticTexts["루킹 스트라이크"].exists || app.staticTexts["헛스윙"].exists {
                mark("strike-\(index)")
                hold(1.4)
            }

            let nextBatter = app.buttons["pitch.nextBatter"]
            if nextBatter.exists, nextBatter.isHittable {
                mark("batter-done-\(index)")
                hold(1.0)
                nextBatter.tap()
                hold(1.2)
                continue
            }
            if app.buttons["pitch.finish"].exists { break }
            hold(0.8)
        }

        if !caughtStrikeout {
            mark("no-strikeout")
            hold(1.5)
        }
        mark("end")
        hold(1.0)
    }

    /// 촬영 언어. 빌드 세팅(BaseballCaptureLanguage)이 UITest 번들 Info.plist로 들어온다.
    private var captureLanguage: String {
        let bundled = Bundle(for: PromoCaptureUITests.self)
            .object(forInfoDictionaryKey: "BaseballCaptureLanguage") as? String
        return (bundled?.isEmpty == false ? bundled : nil)
            ?? ProcessInfo.processInfo.environment["BASEBALL_CAPTURE_LANGUAGE"]
            ?? "ko"
    }

    /// 삼진 스탬프(이닝 종료 삼진·연속 삼진에만 뜬다) 문구. legacy.highlight.strikeout.title.
    private var strikeoutStampTexts: [String] {
        switch captureLanguage {
        case "en": ["STRIKEOUT"]
        case "ja": ["三振"]
        default: ["삼진"]
        }
    }

    /// 스트라이크 판정 라벨. content.pitch-outcome.called_strike/swinging_strike.
    private var strikeLabelTexts: [String] {
        switch captureLanguage {
        case "en": ["Called strike", "Swinging strike"]
        case "ja": ["見逃しストライク", "空振り"]
        default: ["루킹 스트라이크", "헛스윙"]
        }
    }

    private func anyStaticText(_ app: XCUIApplication, _ candidates: [String]) -> Bool {
        candidates.contains { app.staticTexts[$0].exists }
    }

    /// 앱스토어 P1 로컬라이즈 촬영. 이름 입력 → 구종 선택 → 첫 마운드 → 슬라이더 투구
    /// (퍼펙트 릴리스) → 이닝 종료까지 P1 컷 길이만큼 각 화면에 머문다.
    /// 삼진 비트를 확보해야 하므로 판정 라벨을 언어별로 감지해 마커를 남긴다 —
    /// 최종 편집점은 여전히 마커와 프레임으로 찾는다.
    /// `BASEBALL_CAPTURE_LANGUAGE=ja|en` 빌드 세팅과 `simctl io recordVideo`를 켠 채로 실행한다.
    func testJourneyCaptureForAppPreview() {
        let app = XCUIApplication()
        app.launchArguments = launchArguments([
            "-uiTestResetCareer",
            "-uiTestPromoCapture",
            "-uiTestPerfectRelease",
        ])
        app.launch()
        startedAt = Date()
        mark("launch")

        dismissOpening(app)

        // P1 컷은 1/3(이름)과 3/3(구종)에서 머문다. 중간 페이지는 짧게 통과.
        let start = app.buttons["hs.start"]
        let next = app.buttons["hs.setup.next"]
        XCTAssertTrue(
            start.waitForExistence(timeout: timeout) || next.waitForExistence(timeout: timeout),
            "선수 만들기 화면이 열리지 않았습니다."
        )
        mark("setup-name")
        hold(3.6)
        var hops = 0
        while !start.exists, next.exists, hops < 6 {
            next.tap()
            hops += 1
            if start.exists { break }
            mark("setup-page-\(hops)")
            hold(1.2)
        }
        XCTAssertTrue(start.waitForExistence(timeout: timeout), "구종 선택 화면이 열리지 않았습니다.")
        mark("setup-pitch-select")
        hold(3.6)
        start.tap()

        let throwFirst = app.buttons["hs.prologue.throw"]
        XCTAssertTrue(throwFirst.waitForExistence(timeout: timeout), "프롤로그가 열리지 않았습니다.")
        mark("prologue")
        hold(3.0)
        throwFirst.tap()

        let padQuery = app.descendants(matching: .any).matching(identifier: "pitch.windup")
        XCTAssertTrue(padQuery.firstMatch.waitForExistence(timeout: timeout), "투구 슬라이더가 없습니다.")
        mark("slider-visible")
        hold(1.6)

        var sawStrikeout = false
        for index in 0..<24 {
            if app.buttons["pitch.finish"].exists {
                mark("inning-finished")
                hold(4.5)
                break
            }
            let pad = padQuery.firstMatch
            guard pad.exists, pad.isHittable else { break }
            mark("pitch-press-\(index)")
            pad.press(forDuration: 0.85, thenDragTo: pad, withVelocity: .slow, thenHoldForDuration: 0.15)
            mark("pitch-release-\(index)")
            hold(3.2)

            // 삼진 감지. 스탬프(이닝 종료·연속 삼진)가 최우선, 스탬프 없이 타석이
            // 스트라이크 판정으로 끝나도 삼진이다(다음 타자 버튼 + 스트라이크 라벨).
            let nextBatter = app.buttons["pitch.nextBatter"]
            if anyStaticText(app, strikeoutStampTexts) {
                sawStrikeout = true
                mark("strikeout-stamp-\(index)")
                hold(1.6)
            } else if nextBatter.exists, anyStaticText(app, strikeLabelTexts) {
                sawStrikeout = true
                mark("strikeout-plain-\(index)")
                hold(1.2)
            }

            if nextBatter.exists, nextBatter.isHittable {
                mark("batter-done-\(index)")
                hold(1.2)
                nextBatter.tap()
                hold(1.0)
            }
        }
        mark(sawStrikeout ? "journey-had-strikeout" : "journey-no-strikeout")
        mark("end")
        hold(1.0)
    }
}
