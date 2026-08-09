import XCTest

/// QA 촬영 도구. 처음 앱을 켠 사람이 지나가는 **모든 화면**을 파일로 남긴다.
///
/// 스모크(CareerSmokeUITests)는 "끝까지 갈 수 있는지"를 지키고, 이 테스트는 "그 길에서
/// 무엇이 보이는지"를 남긴다. 무엇도 단정하지 않는다 — 사람이 보고 판단할 근거를 만드는 것이
/// 목적이라, 도중에 실패해도 그 순간까지 찍힌 것은 그대로 남아야 한다.
///
/// 실행:
///   xcodebuild test -scheme BaseballIOS -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
///     -only-testing:BaseballIOSUITests/QACaptureUITests
///
/// 결과: /tmp/claude-501/qa-shots/NN-이름.png (호스트 파일). 시뮬레이터에서 호스트 경로에
/// 쓰지 못하는 환경이면 러너 샌드박스의 임시 폴더로 떨어지고, 어느 쪽이든 경로를 로그에
/// 남긴다(QA_SHOT). 첨부(XCTAttachment)도 함께 남겨 xcresult에서 뽑을 수 있게 한다.
final class QACaptureUITests: XCTestCase {
    private let timeout: TimeInterval = 12
    private let maximumSteps = 600
    /// 호스트에서 바로 열 수 있는 자리. 못 쓰면 러너 임시 폴더로 물러난다.
    private let preferredShotDirectory = "/tmp/claude-501/qa-shots"

    private var shotIndex = 0
    /// 같은 이름의 화면을 몇 번 찍었는가. 훈련·관계는 회차당 수십 번 나오므로 상한을 둔다.
    private var shotCounts: [String: Int] = [:]
    private var resolvedDirectory: URL?

    override func setUp() {
        // 도중에 막혀도 남은 화면을 계속 찍는다. 촬영 도구라 첫 실패에서 멈추면 손해다.
        continueAfterFailure = true
    }

    // MARK: - 촬영

    private func shotDirectory() -> URL {
        if let resolvedDirectory { return resolvedDirectory }
        let manager = FileManager.default
        let preferred = URL(fileURLWithPath: preferredShotDirectory, isDirectory: true)
        if (try? manager.createDirectory(at: preferred, withIntermediateDirectories: true)) != nil,
           manager.isWritableFile(atPath: preferred.path) {
            resolvedDirectory = preferred
            print("QA_SHOT_DIR \(preferred.path)")
            return preferred
        }
        let fallback = manager.temporaryDirectory.appendingPathComponent("qa-shots", isDirectory: true)
        try? manager.createDirectory(at: fallback, withIntermediateDirectories: true)
        resolvedDirectory = fallback
        print("QA_SHOT_DIR \(fallback.path)")
        return fallback
    }

    /// 한 장 찍는다. `limit`은 같은 이름으로 남길 최대 장수 — 반복 화면이 폴더를 덮지 않게 한다.
    @discardableResult
    private func capture(_ name: String, limit: Int = 1) -> Bool {
        let taken = shotCounts[name, default: 0]
        guard taken < limit else { return false }
        shotCounts[name] = taken + 1
        shotIndex += 1

        let screenshot = XCUIScreen.main.screenshot()
        let suffix = taken == 0 ? "" : "-\(taken + 1)"
        let fileName = String(format: "%02d-%@%@.png", shotIndex, name, suffix)

        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = fileName
        attachment.lifetime = .keepAlways
        add(attachment)

        let url = shotDirectory().appendingPathComponent(fileName)
        do {
            try screenshot.pngRepresentation.write(to: url)
            print("QA_SHOT \(url.path)")
        } catch {
            print("QA_SHOT_FAIL \(url.path) \(error)")
        }
        return true
    }

    /// 화면 아래쪽까지 찍는다. 고교 화면은 카드가 많아 첫 화면만으로는 무엇이 밀려 있는지 알 수 없다.
    private func captureScrolled(_ app: XCUIApplication, _ name: String, swipes: Int = 1, limit: Int = 1) {
        guard shotCounts[name, default: 0] < limit else { return }
        for _ in 0..<swipes { app.swipeUp() }
        capture(name, limit: limit)
        for _ in 0..<swipes { app.swipeDown() }
    }

    // MARK: - 본편

    func testWalkEveryScreenAndCapture() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestResetCareer", "-uiTestAutoRelease", "-baseball.audio.sound", "NO"]
        app.launch()

        // 1) 오프닝
        let opening = app.buttons["hs.opening.start"]
        if opening.waitForExistence(timeout: 8) {
            capture("opening")
            captureScrolled(app, "opening-scrolled")
            opening.tap()
        } else {
            capture("launch-no-opening")
        }

        // 2) 선수 만들기 — 단계마다 한 장씩
        captureSetup(app, prefix: "setup")
        XCTAssertTrue(app.buttons["hs.start"].waitForExistence(timeout: timeout), "고교 시작 버튼이 없습니다.")
        capture("setup-ready")
        app.buttons["hs.start"].tap()

        // 3) 프롤로그
        if app.buttons["hs.prologue.throw"].waitForExistence(timeout: timeout) {
            capture("prologue")
            captureScrolled(app, "prologue-bottom", swipes: 2)
        }

        var visitedTabs = false
        var reachedDraft = false
        var innings = 0
        var steps = 0

        while steps < maximumSteps {
            steps += 1

            // 전면을 덮는 연출부터 처리한다. 덮인 동안 아래 화면은 눌리지 않는다.
            if app.buttons["hs.draft.reveal.done"].exists {
                capture("draft-reveal-progress")
                app.buttons["hs.draft.reveal.done"].tap()
                capture("draft-reveal-result")
                captureScrolled(app, "draft-reveal-result-bottom")
                tapIfPresent(app.buttons["hs.draft.reveal.done"])
                continue
            }

            // 승부 화면. 프롤로그 불펜은 여기로 들어온다 — 카드에서 시작한 경기와 달리
            // 앞 단계에서 곧바로 넘어오므로 루프가 스스로 알아채야 한다.
            if app.buttons["pitch.throw"].exists || app.buttons["pitch.finish"].exists {
                innings += 1
                playInning(app, index: innings)
                continue
            }

            if app.buttons["hs.rebirth"].exists {
                capture("completion", limit: 2)
                captureScrolled(app, "completion-bottom", swipes: 3, limit: 2)
                let opensLegacy = app.buttons["hs.enterPro"].exists
                if opensLegacy {
                    // 지명된 회차. 프로 진입 버튼이 살아 있는 화면도 근거로 남긴다.
                    capture("completion-drafted")
                }
                tapIfPresent(app.buttons["hs.rebirth"])
                if opensLegacy { continue }

                // 환생 스탬프 — 회차당 한 번뿐인 정점 연출.
                let stamp = app.descendants(matching: .any).matching(identifier: "hs.rebirth.stamp").firstMatch
                if stamp.waitForExistence(timeout: 4) {
                    capture("rebirth-stamp")
                    _ = stamp.waitForNonExistence(timeout: timeout)
                }
                // 2회차 선수 만들기 — 난이도·핸디캡 단계가 새로 붙는다.
                if app.buttons["hs.setup.next"].waitForExistence(timeout: timeout) {
                    captureSetup(app, prefix: "life2-setup", captureAll: true)
                }
                captureArchive(app)
                capture("run-finished")
                return
            }

            if app.buttons["hs.legacy.confirm"].exists {
                capture("legacy-lifecard")
                captureScrolled(app, "legacy-memories", swipes: 3)
                selectRequiredLegacy(app)
                capture("legacy-selected")
                if !tapIfPresent(app.buttons["hs.legacy.confirm"]) {
                    capture("legacy-stuck")
                    XCTFail("기억을 골랐는데도 확정할 수 없습니다.")
                    return
                }
                continue
            }

            if app.buttons["hs.draft.resolve"].exists {
                reachedDraft = true
                capture("draft-card")
                captureScrolled(app, "draft-card-bottom", swipes: 3)
                // 드래프트 직전 기록 탭 — 유망주 랭킹·가상 지명이 이때 가장 볼 만하다.
                captureRecordTab(app, suffix: "predraft")
                tapIfPresent(app.buttons["hs.draft.resolve"])
                continue
            }

            if app.buttons["hs.prologue.continue"].exists, app.buttons["hs.prologue.throw"].exists {
                // 프롤로그에서 불펜을 먼저 던진다. 이 게임에서 가장 좋은 것이 투구다.
                tapIfPresent(app.buttons["hs.prologue.throw"])
                continue
            }
            if tapIfPresent(app.buttons["hs.prologue.continue"]) { continue }

            if firstMatch(app, prefix: "hs.school.").exists {
                capture("school-selection")
                captureScrolled(app, "school-selection-bottom", swipes: 3)
                let card = firstMatch(app, prefix: "hs.school.")
                if bringIntoView(card) { card.tap() }
                // 확인 창의 버튼은 접근성 트리에 두 번 잡힌다(시트 + 액션). 하나만 집는다.
                let confirm = app.buttons.matching(identifier: "hs.school.confirm").firstMatch
                if confirm.waitForExistence(timeout: 3) {
                    capture("school-confirm-dialog")
                    confirm.tap()
                }
                continue
            }

            if app.buttons["hs.training.commit"].exists {
                capture("training", limit: 2)
                captureScrolled(app, "training-bottom", swipes: 3, limit: 2)
                tapIfPresent(app.buttons["hs.training.commit"])
                capture("training-result", limit: 3)
                if !visitedTabs {
                    visitedTabs = true
                    captureProTab(app)
                    captureRecordTab(app, suffix: "early")
                    captureSettingsTab(app)
                }
                continue
            }

            if firstMatch(app, prefix: "hs.response.").exists {
                capture("relationship", limit: 4)
                captureScrolled(app, "relationship-bottom", swipes: 2, limit: 2)
                if !tapFirst(app, prefix: "hs.response.") {
                    capture("relationship-stuck")
                    XCTFail("관계 선택지를 누를 수 없습니다.")
                    return
                }
                continue
            }

            if firstMatch(app, prefix: "hs.awakening.").exists {
                capture("awakening", limit: 2)
                if tapFirst(app, prefix: "hs.awakening.") {
                    let confirm = app.buttons.matching(identifier: "hs.awakening.confirm").firstMatch
                    if confirm.waitForExistence(timeout: 3) {
                        capture("awakening-confirm-dialog")
                        confirm.tap()
                    }
                }
                continue
            }

            if app.buttons["hs.chapter.continue"].exists {
                capture("chapter-review", limit: 2)
                captureScrolled(app, "chapter-review-bottom", swipes: 2)
                tapIfPresent(app.buttons["hs.chapter.continue"])
                continue
            }

            if app.buttons["hs.game.start"].exists {
                // 대진표가 붙는 챕터는 이 화면 위쪽에 있다.
                if app.descendants(matching: .any).matching(identifier: "hs.tournament").firstMatch.exists {
                    capture("tournament-bracket", limit: 2)
                }
                capture("important-game-card", limit: 2)
                captureScrolled(app, "important-game-bottom", swipes: 2)
                tapIfPresent(app.buttons["hs.game.start"])
                innings += 1
                playInning(app, index: innings)
                continue
            }

            capture("stuck")
            XCTFail("진행할 조작을 찾지 못했습니다. \(steps)단계. 드래프트 도달: \(reachedDraft). 보이는 버튼: \(visibleIdentifiers(app))")
            return
        }
        capture("step-budget-exhausted")
        XCTFail("\(maximumSteps)단계 안에 회차가 끝나지 않았습니다.")
    }

    // MARK: - 구간별 촬영

    /// 선수 만들기. 단계마다 한 장씩 남긴다.
    private func captureSetup(_ app: XCUIApplication, prefix: String, captureAll: Bool = true) {
        let start = app.buttons["hs.start"]
        let next = app.buttons["hs.setup.next"]
        guard start.waitForExistence(timeout: timeout) || next.waitForExistence(timeout: timeout) else { return }
        var hops = 0
        while hops < 8 {
            if captureAll || hops == 0 {
                capture("\(prefix)-step\(hops + 1)")
                captureScrolled(app, "\(prefix)-step\(hops + 1)-bottom", swipes: 2)
            }
            if start.exists { break }
            guard next.exists, bringIntoView(next) else { break }
            next.tap()
            hops += 1
        }
    }

    /// 한 이닝. 첫 이닝은 결정·결과·마무리를 촘촘히 남긴다.
    private func playInning(_ app: XCUIApplication, index: Int) {
        let throwButton = app.buttons["pitch.throw"]
        let nextBatter = app.buttons["pitch.nextBatter"]
        let finish = app.buttons["pitch.finish"]
        guard throwButton.waitForExistence(timeout: timeout) else {
            capture("pitch-screen-missing")
            return
        }
        let tag = index <= 1 ? "bullpen" : "game"
        capture("\(tag)-pitch-decision", limit: 2)
        captureScrolled(app, "\(tag)-pitch-decision-bottom", swipes: 2, limit: 2)

        var pitches = 0
        while !finish.exists, pitches < 120 {
            if throwButton.exists, bringIntoView(throwButton) {
                throwButton.tap()
                pitches += 1
                // 판정이 화면에 남아 있는 동안 찍는다. 요소 조회는 느리므로 촬영이 먼저다.
                if pitches <= 3 { capture("\(tag)-pitch-result", limit: 3) }
                if pitches == 2 { captureScrolled(app, "\(tag)-pitch-log", swipes: 2, limit: 2) }
            } else if nextBatter.exists, bringIntoView(nextBatter) {
                capture("\(tag)-batter-done", limit: 2)
                nextBatter.tap()
            } else {
                break
            }
        }
        if finish.waitForExistence(timeout: timeout) {
            capture("\(tag)-inning-finished", limit: 2)
            captureScrolled(app, "\(tag)-inning-finished-bottom", swipes: 3, limit: 2)
            _ = bringIntoView(finish)
            finish.tap()
        } else {
            capture("\(tag)-inning-not-finished")
        }
    }

    /// 기록 탭. 카드가 많아 아래로 훑으며 여러 장 남긴다.
    private func captureRecordTab(_ app: XCUIApplication, suffix: String) {
        guard switchTab(app, to: "기록") else {
            capture("record-tab-unreachable-\(suffix)")
            return
        }
        capture("record-\(suffix)-top")
        for page in 1...5 {
            app.swipeUp()
            capture("record-\(suffix)-p\(page)")
        }
        _ = switchTab(app, to: "고교")
    }

    private func captureProTab(_ app: XCUIApplication) {
        guard switchTab(app, to: "프로") else { return }
        capture("pro-tab-locked")
        captureScrolled(app, "pro-tab-locked-bottom", swipes: 2)
        _ = switchTab(app, to: "고교")
    }

    private func captureSettingsTab(_ app: XCUIApplication) {
        guard switchTab(app, to: "설정") else { return }
        capture("settings-top")
        for page in 1...3 {
            app.swipeUp()
            capture("settings-p\(page)")
        }
        _ = switchTab(app, to: "고교")
    }

    /// 회차 아카이브. 기록 탭 아래쪽에 있다 — 회차가 쌓였을 때만 볼 것이 있다.
    private func captureArchive(_ app: XCUIApplication) {
        guard switchTab(app, to: "기록") else {
            capture("archive-unreachable")
            return
        }
        capture("archive-record-top")
        for page in 1...7 {
            app.swipeUp()
            capture("archive-p\(page)")
        }
        _ = switchTab(app, to: "고교")
    }

    @discardableResult
    private func switchTab(_ app: XCUIApplication, to title: String) -> Bool {
        let tab = app.tabBars.buttons[title]
        if tab.waitForExistence(timeout: 3), tab.isHittable {
            tab.tap()
            return true
        }
        let button = app.buttons[title]
        if button.exists, button.isHittable {
            button.tap()
            return true
        }
        return false
    }

    // MARK: - 보조

    private func selectRequiredLegacy(_ app: XCUIApplication) {
        let confirm = app.buttons["hs.legacy.confirm"]
        let signatureOptions = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "hs.signatureLegacy.")
        )
        if !confirm.isEnabled, signatureOptions.count > 0 {
            let option = signatureOptions.element(boundBy: 0)
            if option.exists, bringIntoView(option) {
                option.tap()
            }
        }

        let options = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "hs.memory."))
        var index = 0
        while !confirm.isEnabled, index < options.count {
            let option = options.element(boundBy: index)
            index += 1
            guard option.exists, bringIntoView(option) else { continue }
            option.tap()
        }
    }

    private func firstMatch(_ app: XCUIApplication, prefix: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).element(boundBy: 0)
    }

    @discardableResult
    private func tapIfPresent(_ element: XCUIElement) -> Bool {
        guard element.exists else { return false }
        if bringIntoView(element) {
            element.tap()
            return true
        }
        // isHittable 거짓 음성 폴백 — 화면상 보이는 활성 버튼이 hittable=false로
        // 보고되는 사례(기억 확정)가 있었다. 프레임이 있으면 좌표로 두드린다.
        let frame = element.frame
        guard !frame.isEmpty, frame.midY > 0 else { return false }
        XCUIApplication().coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: frame.midX, dy: frame.midY)).tap()
        return true
    }

    @discardableResult
    private func tapFirst(_ app: XCUIApplication, prefix: String) -> Bool {
        let matches = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
        guard matches.count > 0 else { return false }
        let first = matches.element(boundBy: 0)
        guard first.exists, bringIntoView(first) else { return false }
        first.tap()
        return true
    }

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

    private func visibleIdentifiers(_ app: XCUIApplication) -> String {
        app.buttons.allElementsBoundByIndex.prefix(25).map { element in
            element.identifier.isEmpty ? "<\(element.label)>" : element.identifier
        }.joined(separator: ", ")
    }
}
