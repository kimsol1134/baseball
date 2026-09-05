import XCTest

/// 선수 만들기 단계 제목이 화면 왼쪽·머리 아래로 잘리지 않는지 실화면에서 지킨다.
///
/// 유닛 렌더는 획 여백을 보고, 이 테스트는 '다음'을 누른 뒤 새 제목이 머리 밑·화면 안에
/// 남아 있는지를 본다. 전환이 다시 스크롤 안 콘텐츠를 왼쪽으로 밀면 여기서 터진다.
final class SetupTitleClipUITests: XCTestCase {
    func testSetupQuestionStaysFullyOnScreenAfterEachStep() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestResetCareer", "-uiTestAutoRelease", "-baseball.audio.sound", "NO"]
        app.launch()

        if app.buttons["hs.opening.start"].waitForExistence(timeout: 10) {
            app.buttons["hs.opening.start"].tap()
        }
        skipOnboardingBullpenIfNeeded(app)

        let question = app.descendants(matching: .any).matching(identifier: "hs.setup.question").firstMatch
        XCTAssertTrue(
            question.waitForExistence(timeout: 12),
            "선수 만들기 질문 제목이 없습니다."
        )
        assertQuestionFullyVisible(app, question, step: 0)

        let next = app.buttons["hs.setup.next"]
        var hops = 0
        while next.exists, hops < 6 {
            next.tap()
            hops += 1
            XCTAssertTrue(
                question.waitForExistence(timeout: 6),
                "\(hops)단계로 넘어간 뒤 질문 제목이 사라졌습니다."
            )
            // 밀어내기 전환이 끝난 뒤에 좌표를 읽는다.
            _ = question.waitForExistence(timeout: 0.5)
            assertQuestionFullyVisible(app, question, step: hops)
            if app.buttons["hs.start"].exists { break }
        }
    }

    private func skipOnboardingBullpenIfNeeded(_ app: XCUIApplication) {
        let abort = app.buttons["pitch.abort"]
        guard abort.waitForExistence(timeout: 3) else { return }
        abort.tap()
        // iOS 26 알럿은 같은 identifier를 wrapper/실제 버튼으로 두 번 노출한다.
        let confirm = app.buttons.matching(identifier: "pitch.abort.practice.confirm").firstMatch
        if confirm.waitForExistence(timeout: 3) {
            confirm.tap()
        } else if app.buttons["연습을 끝낸다"].waitForExistence(timeout: 2) {
            app.buttons["연습을 끝낸다"].firstMatch.tap()
        }
    }

    private func assertQuestionFullyVisible(_ app: XCUIApplication, _ question: XCUIElement, step: Int) {
        let screen = app.frame
        let frame = question.frame
        XCTAssertGreaterThan(frame.width, 40, "\(step)단계 제목 폭이 비정상입니다. \(frame)")
        XCTAssertGreaterThan(frame.height, 18, "\(step)단계 제목 높이가 잘린 값입니다. \(frame)")
        XCTAssertGreaterThanOrEqual(
            frame.minX,
            screen.minX + 8,
            "\(step)단계 제목이 화면 왼쪽으로 잘렸습니다. \(frame) screen=\(screen)"
        )
        XCTAssertLessThanOrEqual(
            frame.maxX,
            screen.maxX - 4,
            "\(step)단계 제목이 화면 오른쪽으로 잘렸습니다. \(frame)"
        )
        let header = app.descendants(matching: .any).matching(identifier: "hs.setup.header").firstMatch
        if header.exists {
            XCTAssertGreaterThanOrEqual(
                frame.minY,
                header.frame.maxY - 2,
                "\(step)단계 제목이 머리 밑으로 들어가 윗획이 잘렸습니다. title=\(frame) header=\(header.frame)"
            )
        } else {
            XCTAssertGreaterThan(
                frame.minY,
                44,
                "\(step)단계 제목이 상태 막대와 겹칩니다. \(frame)"
            )
        }
    }
}