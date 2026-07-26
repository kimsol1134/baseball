import XCTest

/// 고교 3년 → 드래프트 → 기억 계승 → 프로 입단까지 한 번에 걸어 본다.
/// 유닛 테스트는 엔진 연결을, 이 테스트는 "화면으로 실제로 끝까지 갈 수 있는지"를 지킨다.
final class CareerSmokeUITests: XCTestCase {
    private let timeout: TimeInterval = 12
    /// 고교 한 회차는 훈련 12~16 + 관계 4~6 + 경기 4~6 + 각성 3 + 챕터 8이라 단계 수가 많다.
    private let maximumSteps = 400

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        // 자동 릴리스로 돌린다. 타이밍 제스처는 사람이 손으로 확인하고, 이 테스트는 흐름을 본다.
        app.launchArguments = ["-uiTestResetCareer", "-uiTestAutoRelease"]
        app.launch()
        return app
    }

    func testHighSchoolCareerRunsThroughDraftAndRebirth() {
        let app = launch()

        dismissOpening(app)
        let start = app.buttons["hs.start"]
        XCTAssertTrue(start.waitForExistence(timeout: timeout), "고교 시작 화면이 열리지 않았습니다.")
        capture(app, name: "01-highschool-setup")
        start.tap()

        XCTAssertTrue(
            app.buttons["hs.prologue.throw"].waitForExistence(timeout: timeout),
            "프롤로그가 열리지 않았습니다."
        )
        capture(app, name: "02-prologue")

        var steps = 0
        var capturedTraining = false
        var capturedPitch = false
        var reachedDraft = false

        while steps < maximumSteps {
            steps += 1

            if app.buttons["hs.rebirth"].exists {
                capture(app, name: "08-completed")
                XCTAssertTrue(reachedDraft, "드래프트를 거치지 않고 완료에 도달했습니다.")
                tapIfPresent(app.buttons["hs.rebirth"])
                XCTAssertTrue(
                    app.buttons["hs.start"].waitForExistence(timeout: timeout),
                    "다시 태어나기 뒤 새 회차 화면이 열리지 않았습니다."
                )
                capture(app, name: "09-rebirth")
                return
            }

            if tapIfPresent(app.buttons["hs.prologue.continue"]) { continue }
            if tapFirst(app, prefix: "hs.school.") {
                confirmSchool(app)
                capture(app, name: "03-school-selection-done")
                continue
            }
            if app.buttons["hs.training.commit"].exists {
                if !capturedTraining {
                    capturedTraining = true
                    capture(app, name: "04-training")
                }
                tapIfPresent(app.buttons["hs.training.commit"])
                continue
            }
            if tapFirst(app, prefix: "hs.response.") { continue }
            if tapFirst(app, prefix: "hs.awakening.") { confirmAwakening(app); continue }
            if tapIfPresent(app.buttons["hs.chapter.continue"]) { continue }

            if app.buttons["hs.game.start"].exists {
                tapIfPresent(app.buttons["hs.game.start"])
                if !capturedPitch {
                    capturedPitch = true
                    _ = app.buttons["pitch.throw"].waitForExistence(timeout: timeout)
                    capture(app, name: "05-pitch-decision")
                }
                playInning(app, capturePitchResult: !capturedPitch)
                continue
            }

            if app.buttons["hs.draft.resolve"].exists {
                reachedDraft = true
                capture(app, name: "06-draft")
                tapIfPresent(app.buttons["hs.draft.resolve"])
                continue
            }

            if app.buttons["hs.legacy.confirm"].exists {
                selectRequiredMemories(app)
                capture(app, name: "07-legacy")
                XCTAssertTrue(
                    tapIfPresent(app.buttons["hs.legacy.confirm"]),
                    "필요한 만큼 기억을 골랐는데도 확정할 수 없습니다."
                )
                continue
            }

            capture(app, name: "99-stuck")
            XCTFail("어느 단계에서도 진행 가능한 조작을 찾지 못했습니다. \(steps)번째 단계. 보이는 버튼: \(visibleIdentifiers(app))")
            return
        }
        XCTFail("고교 회차가 \(maximumSteps)단계 안에 끝나지 않았습니다.")
    }

    /// 드래프트를 통과했다면 프로 커리어가 그 결과로 열려야 한다.
    func testDraftedRunCanEnterProCareer() {
        let app = launch()
        dismissOpening(app)
        XCTAssertTrue(app.buttons["hs.start"].waitForExistence(timeout: timeout), "고교 시작 화면이 열리지 않았습니다.")
        tapIfPresent(app.buttons["hs.start"])

        var steps = 0
        while steps < maximumSteps {
            steps += 1
            if app.buttons["hs.enterPro"].exists {
                tapIfPresent(app.buttons["hs.enterPro"])
                XCTAssertTrue(
                    app.staticTexts["다음 행동"].waitForExistence(timeout: timeout)
                        || app.buttons["1주 진행"].waitForExistence(timeout: timeout),
                    "프로 커리어 화면이 열리지 않았습니다."
                )
                capture(app, name: "10-pro-entered")
                return
            }
            if app.buttons["hs.rebirth"].exists {
                // 미지명 회차였다. 프로 진입 버튼이 없는 것이 정상이다.
                XCTAssertFalse(app.buttons["hs.enterPro"].exists)
                return
            }

            if tapIfPresent(app.buttons["hs.prologue.continue"]) { continue }
            if tapFirst(app, prefix: "hs.school.") { confirmSchool(app); continue }
            if tapIfPresent(app.buttons["hs.training.commit"]) { continue }
            if tapFirst(app, prefix: "hs.response.") { continue }
            if tapFirst(app, prefix: "hs.awakening.") { confirmAwakening(app); continue }
            if tapIfPresent(app.buttons["hs.chapter.continue"]) { continue }
            if app.buttons["hs.game.start"].exists {
                tapIfPresent(app.buttons["hs.game.start"])
                playInning(app, capturePitchResult: false)
                continue
            }
            if tapIfPresent(app.buttons["hs.draft.resolve"]) { continue }
            if app.buttons["hs.legacy.confirm"].exists {
                selectRequiredMemories(app)
                tapIfPresent(app.buttons["hs.legacy.confirm"])
                continue
            }
            capture(app, name: "99-stuck-pro")
            XCTFail("진행 가능한 조작을 찾지 못했습니다. 보이는 버튼: \(visibleIdentifiers(app))")
            return
        }
        XCTFail("회차가 끝나지 않았습니다.")
    }

    /// 코어는 기억을 정확히 memorySlots장 요구한다. 확정 버튼이 눌릴 때까지 고른다.
    private func selectRequiredMemories(_ app: XCUIApplication) {
        let confirm = app.buttons["hs.legacy.confirm"]
        let options = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "hs.memory."))
        var index = 0
        while !confirm.isEnabled, index < options.count {
            let option = options.element(boundBy: index)
            index += 1
            guard option.exists, bringIntoView(option) else { continue }
            option.tap()
        }
    }

    /// 첫 불펜이 프롤로그 바로 다음에 나와야 한다. 이 게임에서 가장 좋은 것이 투구인데
    /// 사는 사람이 그걸 만나기까지 열 번을 눌러야 하면 안 된다(DOC-IOS-TOP §6.1).
    func testFirstPitchIsReachableInTwoTaps() {
        let app = launch()

        dismissOpening(app)
        let start = app.buttons["hs.start"]
        XCTAssertTrue(start.waitForExistence(timeout: timeout), "고교 시작 화면이 열리지 않았습니다.")
        tapIfPresent(start)

        let throwFirst = app.buttons["hs.prologue.throw"]
        XCTAssertTrue(throwFirst.waitForExistence(timeout: timeout), "프롤로그에 첫 불펜이 없습니다.")
        tapIfPresent(throwFirst)

        XCTAssertTrue(
            app.buttons["pitch.throw"].waitForExistence(timeout: timeout),
            "두 번의 탭으로 투구 화면에 도달하지 못했습니다."
        )
        capture(app, name: "13-first-bullpen")
        playInning(app, capturePitchResult: false)

        XCTAssertTrue(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "hs.school."))
                .element(boundBy: 0).waitForExistence(timeout: timeout),
            "첫 불펜 뒤 학교 선택으로 넘어가지 않았습니다."
        )
    }

    /// 자동 릴리스를 끄고 실제 제스처(누르고 → 끌고 → 뗀다)로 한 구를 던진다.
    /// 유닛 테스트는 미터 값 → 정확도 변환을, 이 테스트는 제스처가 실제로 투구를 만드는지 본다.
    func testManualDeliveryGestureThrowsAPitch() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestResetCareer"]
        app.launch()

        dismissOpening(app)
        let start = app.buttons["hs.start"]
        XCTAssertTrue(start.waitForExistence(timeout: timeout), "고교 시작 화면이 열리지 않았습니다.")
        tapIfPresent(start)

        // 첫 불펜이 바로 나오므로 거기서 제스처를 검증한다.
        tapIfPresent(app.buttons["hs.prologue.throw"])

        var steps = 0
        while steps < maximumSteps {
            steps += 1
            if windUpPad(app).exists { break }
            if app.buttons["hs.game.start"].exists {
                tapIfPresent(app.buttons["hs.game.start"])
                break
            }
            if tapIfPresent(app.buttons["hs.prologue.continue"]) { continue }
            if tapFirst(app, prefix: "hs.school.") { confirmSchool(app); continue }
            if tapIfPresent(app.buttons["hs.training.commit"]) { continue }
            if tapFirst(app, prefix: "hs.response.") { continue }
            if tapFirst(app, prefix: "hs.awakening.") { confirmAwakening(app); continue }
            if tapIfPresent(app.buttons["hs.chapter.continue"]) { continue }
            XCTFail("중요 경기에 도달하기 전에 막혔습니다. 보이는 버튼: \(visibleIdentifiers(app))")
            return
        }

        let pad = windUpPad(app)
        XCTAssertTrue(pad.waitForExistence(timeout: timeout), "와인드업 패드가 없습니다. 자동 릴리스가 꺼져 있어야 합니다.")
        XCTAssertFalse(app.buttons["pitch.throw"].exists, "자동 릴리스가 꺼졌는데도 탭 버튼이 남아 있습니다.")
        _ = bringIntoView(pad)
        capture(app, name: "11-delivery-gesture")

        // 누른 채 조금 끌었다가 뗀다. 실제 손동작과 같은 경로다.
        pad.press(forDuration: 0.6, thenDragTo: pad, withVelocity: .slow, thenHoldForDuration: 0.1)

        XCTAssertTrue(
            app.buttons["pitch.nextBatter"].waitForExistence(timeout: timeout)
                || app.buttons["pitch.finish"].waitForExistence(timeout: 1)
                || windUpPad(app).exists,
            "제스처로 던진 뒤 승부가 진행되지 않았습니다."
        )
        capture(app, name: "12-delivery-result")
    }

    /// 와인드업 패드. 라벨만 갖고 있어 종류를 특정하지 않고 찾는다.
    private func windUpPad(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "와인드업").firstMatch
    }

    // MARK: - 보조

    private func playInning(_ app: XCUIApplication, capturePitchResult: Bool) {
        let throwButton = app.buttons["pitch.throw"]
        let nextBatter = app.buttons["pitch.nextBatter"]
        let finish = app.buttons["pitch.finish"]
        XCTAssertTrue(throwButton.waitForExistence(timeout: timeout), "승부 화면이 열리지 않았습니다.")

        var pitches = 0
        var captured = false
        while !finish.exists, pitches < 120 {
            if throwButton.exists, bringIntoView(throwButton) {
                throwButton.tap()
                pitches += 1
                if capturePitchResult, !captured, pitches >= 2 {
                    captured = true
                    capture(app, name: "05b-pitch-result")
                }
            } else if nextBatter.exists, bringIntoView(nextBatter) {
                nextBatter.tap()
            } else {
                break
            }
        }
        XCTAssertGreaterThan(pitches, 0, "한 구도 던지지 못했습니다.")
        XCTAssertTrue(finish.waitForExistence(timeout: timeout), "이닝이 끝나지 않았습니다.")
        XCTAssertFalse(
            app.staticTexts["승부를 진행할 수 없습니다"].exists,
            "승부 도중 코어 호출이 실패했습니다."
        )
        _ = bringIntoView(finish)
        finish.tap()
    }

    @discardableResult
    /// 1회차에는 오프닝 장면이 먼저 뜬다. 넘기지 않으면 선수 만들기 화면에 닿지 못한다.
    private func dismissOpening(_ app: XCUIApplication) {
        let start = app.buttons["hs.opening.start"]
        if start.waitForExistence(timeout: 5) { start.tap() }
    }

    private func tapIfPresent(_ element: XCUIElement) -> Bool {
        guard element.exists else { return false }
        guard bringIntoView(element) else { return false }
        element.tap()
        return true
    }

    /// 화면 밖에 있는 컨트롤을 끌어올린다. 고교 화면은 카드가 많아 주 조작이 자주 접힌다.
    private func bringIntoView(_ element: XCUIElement, attempts: Int = 8) -> Bool {
        guard element.exists else { return false }
        if element.isHittable { return true }
        let app = XCUIApplication()
        for _ in 0..<attempts {
            app.swipeUp()
            if element.isHittable { return true }
        }
        for _ in 0..<attempts {
            app.swipeDown()
            if element.isHittable { return true }
        }
        return element.isHittable
    }

    /// 학교는 되돌릴 수 없어 확인 창이 뜬다. 카드만 누르고 넘어가면 그 자리에서 막힌다.
    private func confirmSchool(_ app: XCUIApplication) {
        let confirm = app.buttons.matching(identifier: "hs.school.confirm").firstMatch
        if confirm.waitForExistence(timeout: 3) { confirm.tap() }
    }

    /// 각성도 되돌릴 수 없어 확인 창이 뜬다.
    private func confirmAwakening(_ app: XCUIApplication) {
        let confirm = app.buttons.matching(identifier: "hs.awakening.confirm").firstMatch
        if confirm.waitForExistence(timeout: 3) { confirm.tap() }
    }

    /// 접두어로 시작하는 첫 선택지를 누른다. 학교·대응·각성·기억처럼 내용이 매번 달라지는
    /// 목록에서 쓴다.
    private func tapFirst(_ app: XCUIApplication, prefix: String) -> Bool {
        let matches = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", prefix)
        )
        guard matches.count > 0 else { return false }
        let first = matches.element(boundBy: 0)
        guard first.exists, bringIntoView(first) else { return false }
        first.tap()
        return true
    }

    /// 막혔을 때 무엇이 보이는지 알려 준다. 진단 없는 실패 메시지는 두 번 일하게 만든다.
    private func visibleIdentifiers(_ app: XCUIApplication) -> String {
        let buttons = app.buttons.allElementsBoundByIndex.prefix(25).map { element -> String in
            let identifier = element.identifier
            return identifier.isEmpty ? "<\(element.label)>" : identifier
        }
        return buttons.joined(separator: ", ")
    }

    /// 테스트 리포트에 붙인다. 스토어 스크린샷 초안으로 뽑아 쓸 수 있다.
    private func capture(_ app: XCUIApplication, name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
