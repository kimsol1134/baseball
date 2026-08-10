import XCTest

/// 상태바 밑을 지나가는 글자가 시계와 겹치는지만 보는 빠른 회귀 촬영.
///
/// 제보 "화면이 조금 어긋나서 글자가 깨진다"의 실체가 이것이다 — 내비게이션 바를 숨겨
/// iOS의 스크롤 가장자리 효과가 없는 화면에서, 스크롤된 본문이 시계·와이파이·배터리와
/// 같은 자리에 그려진다.
final class StatusBarScrimUITests: XCTestCase {
    private let shotDirectory = "/tmp/claude-501/scrim-shots"

    func testScrolledContentDoesNotCollideWithStatusBar() {
        try? FileManager.default.createDirectory(
            at: URL(fileURLWithPath: shotDirectory, isDirectory: true),
            withIntermediateDirectories: true
        )
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestResetCareer", "-uiTestAutoRelease", "-baseball.audio.sound", "NO"]
        app.launch()

        if app.buttons["hs.opening.start"].waitForExistence(timeout: 10) {
            app.buttons["hs.opening.start"].tap()
        }
        let start = app.buttons["hs.start"]
        let next = app.buttons["hs.setup.next"]
        _ = start.waitForExistence(timeout: 12) || next.waitForExistence(timeout: 12)
        var hops = 0
        while hops < 8, !start.exists {
            guard next.exists else { break }
            next.tap()
            hops += 1
        }
        XCTAssertTrue(start.waitForExistence(timeout: 12))
        start.tap()
        XCTAssertTrue(app.buttons["hs.prologue.throw"].waitForExistence(timeout: 12))

        for step in 1...3 {
            app.swipeUp()
            capture("scrolled-\(step)")
        }
    }

    private func capture(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let url = URL(fileURLWithPath: shotDirectory).appendingPathComponent("\(name).png")
        try? screenshot.pngRepresentation.write(to: url)
        print("SCRIM_SHOT \(url.path)")
    }
}
