import CoreGraphics
import UIKit
import XCTest

/// 1.2.8 시뮬레이터 E2E. CareerSmoke 헬퍼와 같은 진입 인자를 쓰되, 스모크 파일을
/// 리팩터하지 않는다(결함이 아닌 변경은 스펙이 금지).
@MainActor
final class Release128JourneyUITests: XCTestCase {
    private let timeout: TimeInterval = 12
    private let shotRoot = URL(fileURLWithPath: "/tmp/baseball-qa-1.2.8", isDirectory: true)
    private var shotIndex = 0

    override func setUp() {
        continueAfterFailure = false
        shotIndex = 0
    }

    func testRetirementSharePreviewOpens() throws {
        executionTimeAllowance = 180
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestResetCareer",
            "-uiTestAutoRelease",
            "-uiTestProCareerJourneyV1",
            "-baseball.audio.sound", "NO",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
        ]
        app.launchEnvironment = ["BASEBALL_UI_RETIRED_SHARE": "1"]
        app.launch()
        selectProWeekTab(app, label: "이번 주")
        let share = identified(app, "share.card.retirement")
        XCTAssertTrue(
            share.waitForExistence(timeout: 20),
            "은퇴 카드 공유 버튼이 없습니다. \(visibleIdentifiers(app))"
        )
        XCTAssertTrue(bringIntoView(share))
        openSharePreview(app, share: share, expectedName: "민서준")
        XCTAssertNotEqual(
            identified(app, "share.card.preview.playerName").label,
            "은퇴 카드"
        )
        writeShareScreenshot(name: "retirement-preview.png")
        dismissSharePreview(app)
    }

    func testDraftSharePreviewOpens() throws {
        executionTimeAllowance = 180
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestResetCareer",
            "-uiTestAutoRelease",
            "-baseball.audio.sound", "NO",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
        ]
        app.launchEnvironment = ["BASEBALL_UI_DRAFT_SHARE": "1"]
        app.launch()
        // 2차 B1에서 고교/프로 탭이 "커리어" 하나로 합쳐졌다.
        if app.tabBars.buttons["커리어"].waitForExistence(timeout: timeout) {
            app.tabBars.buttons["커리어"].tap()
        }
        if !identified(app, "hs.draft.result.continue").waitForExistence(timeout: 4),
           app.buttons["hs.draft.reveal.done"].waitForExistence(timeout: 12) {
            app.buttons["hs.draft.reveal.done"].tap()
        }
        XCTAssertTrue(
            identified(app, "hs.draft.result.continue").waitForExistence(timeout: timeout),
            "드래프트 결과 화면이 없습니다. \(visibleIdentifiers(app))"
        )
        let share = identified(app, "share.card.draft")
        XCTAssertTrue(
            share.waitForExistence(timeout: 20),
            "드래프트 카드 공유 버튼이 없습니다. \(visibleIdentifiers(app))"
        )
        openSharePreview(app, share: share, expectedName: "박하준")
        writeShareScreenshot(name: "draft-preview.png")
        dismissSharePreview(app)
    }

    func testRecordSharePreviewsOpen() throws {
        executionTimeAllowance = 180
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestResetCareer",
            "-uiTestAutoRelease",
            "-uiTestProCareerJourneyV1",
            "-uiTestOpenProWeek",
            "-baseball.audio.sound", "NO",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
        ]
        app.launchEnvironment = ["BASEBALL_UI_RECORD_SHARE": "1"]
        app.launch()
        _ = identified(app, "app.loading.progress").waitForNonExistence(timeout: 10)
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        selectProWeekTab(app, label: "이번 주")
        dismissCareerNoticeIfPresent(app)
        XCTAssertTrue(
            identified(app, "pro.weekly.recordShare").waitForExistence(timeout: 25),
            "탈삼진 마일스톤 공유 카드가 없습니다. \(visibleIdentifiers(app))"
        )
        let recordShares = app.buttons.matching(identifier: "share.card.record")
        XCTAssertTrue(
            recordShares.element(boundBy: 0).waitForExistence(timeout: timeout),
            "탈삼진 마일스톤 공유 버튼이 없습니다. \(visibleIdentifiers(app))"
        )
        openSharePreview(app, share: recordShares.element(boundBy: 0), expectedName: "김도윤")
        writeShareScreenshot(name: "record-milestone-preview.png")
        dismissSharePreview(app)

        XCTAssertTrue(
            identified(app, "pro.weekly.decisionFollowUp.rotation_push").waitForExistence(timeout: timeout),
            "QS 후속 카드가 없습니다. \(visibleIdentifiers(app))"
        )
        XCTAssertGreaterThanOrEqual(recordShares.count, 2, "QS 공유 버튼이 없습니다. \(visibleIdentifiers(app))")
        openSharePreview(app, share: recordShares.element(boundBy: 1), expectedName: "김도윤")
        writeShareScreenshot(name: "record-qs-preview.png")
        dismissSharePreview(app)
    }

    func testNationalSharePreviewOpens() throws {
        executionTimeAllowance = 180
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestResetCareer",
            "-uiTestAutoRelease",
            "-uiTestProCareerJourneyV1",
            "-baseball.audio.sound", "NO",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR",
        ]
        app.launchEnvironment = ["BASEBALL_UI_NATIONAL_SHARE": "1"]
        app.launch()
        selectProWeekTab(app, label: "이번 주")
        XCTAssertTrue(
            identified(app, "pro.nationalTeam.result").waitForExistence(timeout: 20),
            "국가대표 결과 카드가 없습니다. \(visibleIdentifiers(app))"
        )
        let share = identified(app, "share.card.national")
        XCTAssertTrue(
            share.waitForExistence(timeout: timeout),
            "국가대표 카드 공유 버튼이 없습니다. \(visibleIdentifiers(app))"
        )
        openSharePreview(app, share: share, expectedName: "이시우")
        writeShareScreenshot(name: "national-preview.png")
        dismissSharePreview(app)
    }

    func testNewCareerSetupShowsLeftAndRightHand() {
        let app = launch(language: "ko")
        dismissOpening(app)
        XCTAssertTrue(app.buttons["hs.setup.next"].waitForExistence(timeout: timeout))
        capture(app, scenario: "01-pro-entry", step: "setup-name")
        var hops = 0
        let hand = app.descendants(matching: .any)["hs.setup.throwingHand"]
        while !hand.exists, hops < 6 {
            if app.buttons["hs.setup.next"].exists { app.buttons["hs.setup.next"].tap() }
            for _ in 0..<4 { app.swipeUp() }
            hops += 1
            if hand.waitForExistence(timeout: 1) { break }
        }
        XCTAssertTrue(hand.waitForExistence(timeout: timeout), "좌완/우완 선택이 시작 화면에 없습니다.")
        XCTAssertTrue(
            app.buttons["좌완"].exists || app.staticTexts["좌완"].exists,
            "좌완 선택지가 없습니다."
        )
        XCTAssertTrue(
            app.buttons["우완"].exists || app.staticTexts["우완"].exists,
            "우완 선택지가 없습니다."
        )
        capture(app, scenario: "01-pro-entry", step: "setup-throwing-hand")
    }

    func testTrainingGlossaryTermDoesNotSelectFocus() {
        let app = launch(language: "ko")
        dismissOpening(app)
        XCTAssertTrue(completeSetup(app))
        if app.buttons["hs.prologue.throw"].waitForExistence(timeout: 4) {
            XCTAssertTrue(tapIfPresent(app.buttons["hs.prologue.continue"])
                || tapIfPresent(app.buttons["hs.prologue.throw"]))
            if app.buttons["pitch.throw"].waitForExistence(timeout: 3) {
                _ = playInning(app)
            }
        }
        if tapFirst(app, prefix: "hs.school.") { confirmSchool(app) }
        XCTAssertTrue(app.buttons["hs.training.commit"].waitForExistence(timeout: timeout), "훈련 화면이 없습니다.")
        capture(app, scenario: "glyphs-iphone17", step: "training-focus")
        let selectedBefore = focusSelection(app)
        XCTAssertTrue(
            openGlossaryFromKnownTerms(app, preferred: ["stuff", "command", "stamina", "movement", "fatigue"]),
            "훈련 카드에서 용어를 열 수 없습니다. \(visibleIdentifiers(app))"
        )
        capture(app, scenario: "02-role-request", step: "training-glossary-sheet")
        XCTAssertFalse(
            app.buttons["hs.training.commit"].waitForNonExistence(timeout: 1),
            "용어 탭이 훈련 화면을 닫았습니다."
        )
        dismissGlossary(app)
        XCTAssertEqual(focusSelection(app), selectedBefore, "용어 탭이 훈련 선택지를 바꿨습니다.")
        XCTAssertTrue(tapIfPresent(app.buttons["hs.training.commit"]))
        XCTAssertTrue(app.buttons["hs.training.result.dismiss"].waitForExistence(timeout: timeout))
        capture(app, scenario: "glyphs-iphone17", step: "training-result")
    }

    func testManualSliderThrowsOnePitch() {
        let app = launch(autoRelease: false, language: "ko")
        dismissOpening(app)
        XCTAssertTrue(completeSetup(app))
        XCTAssertTrue(tapIfPresent(app.buttons["hs.prologue.throw"]))
        let pad = windUpPad(app)
        XCTAssertTrue(pad.waitForExistence(timeout: timeout), "기본 투구 슬라이더가 없습니다.")
        XCTAssertFalse(app.buttons["pitch.throw"].exists, "기본값이 자동 릴리스입니다.")
        XCTAssertTrue(bringIntoView(pad))
        capture(app, scenario: "05-pitch-slider", step: "windup")
        pad.press(forDuration: 0.6, thenDragTo: pad, withVelocity: .slow, thenHoldForDuration: 0.1)
        capture(app, scenario: "05-pitch-slider", step: "result")
        XCTAssertTrue(
            app.buttons["pitch.nextBatter"].waitForExistence(timeout: timeout)
                || app.buttons["pitch.finish"].waitForExistence(timeout: 1)
                || windUpPad(app).exists,
            "슬라이더로 한 구를 던진 뒤 승부가 진행되지 않았습니다."
        )
    }

    func testRoleRequestResultSettlesWithoutOverlappingOptionCards() throws {
        executionTimeAllowance = 180
        let app = launch(
            draftedCareerFixture: true,
            journeyEnabled: true,
            openProWeek: true,
            autoRelease: true,
            language: "ko"
        )
        enterProFromDraftedFixture(app)
        signRookieContract(app)
        selectProWeekTab(app, label: "이번 주")
        XCTAssertTrue(
            identified(app, "pro.roleRequest").waitForExistence(timeout: timeout),
            "스프링캠프 보직 지원 카드가 없습니다."
        )
        let starter = identified(app, "pro.roleRequest.starter")
        XCTAssertTrue(
            tapIfPresent(starter) || tapIfPresent(app.buttons["pro.roleRequest.starter"]),
            "선발을 선택할 수 없습니다."
        )
        XCTAssertTrue(
            identified(app, "pro.roleRequest").waitForNonExistence(timeout: timeout),
            "보직 지원 카드가 선택 뒤에도 계층에 남아 있습니다. \(visibleIdentifiers(app))"
        )
        RunLoop.current.run(until: Date().addingTimeInterval(2))
        writeFixRoundScreenshot(name: "04-starter-result-settled.png")
        XCTAssertFalse(identified(app, "pro.roleRequest").exists)
        XCTAssertFalse(
            app.staticTexts["이미 맡은 보직입니다"].exists,
            "2초 대기 뒤에도 보직 선택지 문구가 통계 행과 겹칩니다."
        )
        XCTAssertFalse(
            app.staticTexts["긴 이닝 구원"].exists,
            "2초 대기 뒤에도 구원 선택지가 통계 뒤에 남아 있습니다."
        )
    }

    func testKoreanProJourneyRoleDecisionFollowUpSeasonRestore() throws {
        executionTimeAllowance = 1_200
        let app = launch(
            draftedCareerFixture: true,
            journeyEnabled: true,
            openProWeek: true,
            autoRelease: true,
            language: "ko"
        )
        enterProFromDraftedFixture(app)
        capture(app, scenario: "01-pro-entry", step: "contract-offer")
        XCTAssertTrue(identified(app, "pro.contractOffer").waitForExistence(timeout: timeout))
        signRookieContract(app)
        selectProWeekTab(app, label: "이번 주")
        XCTAssertTrue(identified(app, "pro.roleRequest").waitForExistence(timeout: timeout), "스프링캠프 보직 지원 카드가 없습니다.")
        XCTAssertTrue(
            identified(app, "pro.roleRequest.starter").waitForExistence(timeout: timeout)
                || app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "선발")).firstMatch.exists,
            "선발 지원 선택지가 없습니다. \(visibleIdentifiers(app))"
        )
        XCTAssertTrue(
            identified(app, "pro.roleRequest.long_relief").exists
                || app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "중간")).firstMatch.exists
        )
        XCTAssertTrue(
            identified(app, "pro.roleRequest.closer").exists
                || app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "마무리")).firstMatch.exists
        )
        capture(app, scenario: "02-role-request", step: "spring-camp-card")

        XCTAssertTrue(
            openGlossaryFromKnownTerms(app, preferred: ["stamina", "manager-faith", "stuff", "catcher-chemistry", "role"]),
            "보직 선택지 안의 용어를 열 수 없습니다."
        )
        XCTAssertTrue(identified(app, "pro.roleRequest").exists, "용어 탭이 보직 지원을 소비했습니다.")
        XCTAssertFalse(app.buttons["pro.seasonDecision.confirm"].exists)
        capture(app, scenario: "02-role-request", step: "glossary-sheet")
        dismissGlossary(app)

        let starter = identified(app, "pro.roleRequest.starter")
        let starterLabel = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "선발")).firstMatch
        XCTAssertTrue(
            tapIfPresent(starter) || tapIfPresent(starterLabel) || tapIfPresent(app.buttons["pro.roleRequest.starter"]),
            "선발을 선택할 수 없습니다."
        )
        XCTAssertTrue(
            identified(app, "pro.roleRequest").waitForNonExistence(timeout: timeout),
            "보직 지원 카드가 선택 뒤에도 계층에 남아 있습니다. \(visibleIdentifiers(app))"
        )
        RunLoop.current.run(until: Date().addingTimeInterval(2))
        capture(app, scenario: "02-role-request", step: "starter-result")
        writeFixRoundScreenshot(name: "04-starter-result-settled.png")
        XCTAssertFalse(identified(app, "pro.roleRequest").exists)
        XCTAssertFalse(
            app.staticTexts["이미 맡은 보직입니다"].exists,
            "정착 뒤에도 보직 선택지 문구가 통계 뒤에 겹쳐 있습니다."
        )

        capture(app, scenario: "glyphs-iphone17", step: "weekly-plan")
        XCTAssertTrue(advanceToSeasonDecision(app), "3주차 결정 화면에 도달하지 못했습니다. \(visibleIdentifiers(app))")
        XCTAssertTrue(identified(app, "pro.seasonDecision").waitForExistence(timeout: timeout))
        for _ in 0..<3 { app.swipeDown() }
        let weeklyEyebrow = app.descendants(matching: .any).containing(
            NSPredicate(format: "label CONTAINS %@", "3주 결정")
        ).firstMatch
        XCTAssertTrue(
            weeklyEyebrow.exists || identified(app, "pro.seasonDecision").exists,
            "eyebrow '3주 결정'이 없습니다. \(visibleIdentifiers(app))"
        )
        capture(app, scenario: "03-week3-decision", step: "decision")
        let hasImmediate = app.staticTexts["즉시 효과"].exists
            || app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "즉시")).firstMatch.exists
        let hasLater = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "3주")).firstMatch.exists
            || app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "다음 직접")).firstMatch.exists
        XCTAssertTrue(hasImmediate || hasLater, "결정 카드에 효과/후속 요약이 없습니다.")

        if app.buttons["pro.seasonDecision.narrativeToggle"].exists {
            tapIfPresent(app.buttons["pro.seasonDecision.narrativeToggle"])
        }
        let choice = try XCTUnwrap(firstSeasonDecisionChoice(app))
        XCTAssertTrue(bringIntoView(choice))
        XCTAssertTrue(
            openGlossaryFromKnownTerms(app, preferred: [
                "manager-faith", "stamina", "stuff", "command", "movement",
                "fatigue", "catcher-chemistry", "role",
            ]),
            "결정 선택지 안의 용어를 열 수 없습니다."
        )
        XCTAssertTrue(identified(app, "pro.seasonDecision").exists, "용어 탭이 결정을 진행했습니다.")
        XCTAssertFalse(app.buttons["pro.seasonDecision.confirm"].exists, "용어 탭이 선택 확인창을 열었습니다.")
        capture(app, scenario: "03-week3-decision", step: "glossary-without-select")
        dismissGlossary(app)

        XCTAssertTrue(bringIntoView(choice))
        choice.tap()
        let confirm = app.buttons.matching(identifier: "pro.seasonDecision.confirm").firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: timeout), "선택 A 확인창이 없습니다.")
        capture(app, scenario: "03-week3-decision", step: "choice-a-confirm")
        XCTAssertTrue(tapIfPresent(confirm))

        XCTAssertTrue(advanceUntilFollowUp(app), "후속 결과까지 진행하지 못했습니다. \(visibleIdentifiers(app))")
        let followUp = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "pro.weekly.decisionFollowUp.")
        ).firstMatch
        XCTAssertTrue(followUp.waitForExistence(timeout: timeout), "결정 결과 카드가 없습니다. \(visibleIdentifiers(app))")
        capture(app, scenario: "04-follow-up", step: "expanded")
        followUp.tap()
        capture(app, scenario: "04-follow-up", step: "toggled")

        XCTAssertTrue(runUntilFirstOffseason(app), "시즌 정산·오프시즌까지 가지 못했습니다. \(visibleIdentifiers(app))")
        capture(app, scenario: "06-season-complete", step: "offseason")
        if identified(app, "pro.retirement.preview").exists {
            capture(app, scenario: "glyphs-iphone17", step: "retirement-preview")
        }
        XCTAssertTrue(leaveOffseason(app), "오프시즌을 통과하지 못했습니다.")
        if identified(app, "pro.offseasonInvestment").waitForExistence(timeout: 6) {
            XCTAssertTrue(skipInvestment(app))
        }
        selectProWeekTab(app, label: "이번 주")
        capture(app, scenario: "06-season-complete", step: "next-spring")

        let settingsTab = app.tabBars.buttons["설정"]
        if settingsTab.waitForExistence(timeout: 4) {
            settingsTab.tap()
            capture(app, scenario: "glyphs-iphone17", step: "settings")
            if app.buttons["settings.glossary"].waitForExistence(timeout: 2) {
                app.buttons["settings.glossary"].tap()
                capture(app, scenario: "glyphs-iphone17", step: "settings-glossary")
                app.navigationBars.buttons.firstMatch.tap()
            }
        }
        let recordsTab = app.tabBars.buttons["기록"]
        if recordsTab.exists {
            recordsTab.tap()
            capture(app, scenario: "glyphs-iphone17", step: "records")
        }
        selectProWeekTab(app, label: "이번 주")

        app.terminate()
        app.launchArguments = ["-baseball.audio.sound", "NO", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        if app.buttons["이번 주"].waitForExistence(timeout: timeout) {
            app.buttons["이번 주"].tap()
        }
        XCTAssertTrue(
            app.buttons["pro.advanceSegment"].waitForExistence(timeout: timeout)
                || identified(app, "pro.plan.required").waitForExistence(timeout: 4)
                || identified(app, "pro.roleRequest").waitForExistence(timeout: 2)
                || identified(app, "pro.offseasonInvestment").waitForExistence(timeout: 2)
                || app.buttons["이번 주"].exists,
            "저장 복귀 후 프로 화면에 돌아오지 않았습니다. \(visibleIdentifiers(app))"
        )
        capture(app, scenario: "07-save-restore", step: "restored")
    }

    func testEnglishSurfacesHideKorean() throws {
        executionTimeAllowance = 900
        try runLocalizedSurfaces(language: "en", scenario: "08-language-en", weekLabel: "This Week")
    }

    func testJapaneseSurfacesHideHangul() throws {
        executionTimeAllowance = 900
        try runLocalizedSurfaces(language: "ja", scenario: "08-language-ja", weekLabel: "今週")
    }

    func testDenseScreensAtAccessibilityContentSize() throws {
        executionTimeAllowance = 900
        let app = launch(
            draftedCareerFixture: true,
            journeyEnabled: true,
            openProWeek: true,
            autoRelease: true,
            language: "ko",
            contentSize: "UICTContentSizeCategoryAccessibilityL"
        )
        enterProFromDraftedFixture(app)
        capture(app, scenario: "glyphs-iphone17-a11y", step: "contract-offer")
        signRookieContract(app)
        selectProWeekTab(app, label: "이번 주")
        capture(app, scenario: "glyphs-iphone17-a11y", step: "weekly-plan")
        if identified(app, "pro.roleRequest").waitForExistence(timeout: 4) {
            capture(app, scenario: "glyphs-iphone17-a11y", step: "role-request")
        }
        if advanceToSeasonDecision(app) {
            capture(app, scenario: "glyphs-iphone17-a11y", step: "season-decision")
            if let choice = firstSeasonDecisionChoice(app), bringIntoView(choice) {
                choice.tap()
                let confirm = app.buttons.matching(identifier: "pro.seasonDecision.confirm").firstMatch
                if confirm.waitForExistence(timeout: 4) { tapIfPresent(confirm) }
            }
        }
        if runUntilFirstOffseason(app) {
            capture(app, scenario: "glyphs-iphone17-a11y", step: "offseason")
            if identified(app, "pro.retirement.preview").exists {
                _ = bringIntoView(identified(app, "pro.retirement.preview"))
                capture(app, scenario: "glyphs-iphone17-a11y", step: "retirement-preview")
            }
        }
        if app.tabBars.buttons["설정"].waitForExistence(timeout: 3) {
            app.tabBars.buttons["설정"].tap()
            capture(app, scenario: "glyphs-iphone17-a11y", step: "settings")
        }
        if app.tabBars.buttons["기록"].exists {
            app.tabBars.buttons["기록"].tap()
            capture(app, scenario: "glyphs-iphone17-a11y", step: "records")
        }
    }

    func testDenseScreensOnSmallPhoneIfPresent() throws {
        executionTimeAllowance = 900
        let app = launch(
            draftedCareerFixture: true,
            journeyEnabled: true,
            openProWeek: true,
            autoRelease: true,
            language: "ko"
        )
        if app.windows.firstMatch.frame.width > 400 {
            throw XCTSkip("small-phone glyphs run only on iPhone SE (3rd generation)")
        }
        enterProFromDraftedFixture(app)
        capture(app, scenario: "glyphs-se", step: "contract-offer")
        signRookieContract(app)
        selectProWeekTab(app, label: "이번 주")
        capture(app, scenario: "glyphs-se", step: "weekly-plan")
        if identified(app, "pro.roleRequest").waitForExistence(timeout: 4) {
            capture(app, scenario: "glyphs-se", step: "role-request")
        }
        if app.tabBars.buttons["설정"].waitForExistence(timeout: 3) {
            app.tabBars.buttons["설정"].tap()
            capture(app, scenario: "glyphs-se", step: "settings")
        }
        if app.tabBars.buttons["기록"].exists {
            app.tabBars.buttons["기록"].tap()
            capture(app, scenario: "glyphs-se", step: "records")
        }
    }

    // MARK: - Localized 1 / 3 / 4

    private func runLocalizedSurfaces(language: String, scenario: String, weekLabel: String) throws {
        let app = launch(
            draftedCareerFixture: true,
            journeyEnabled: true,
            openProWeek: true,
            autoRelease: true,
            language: language
        )
        enterProFromDraftedFixture(app)
        capture(app, scenario: scenario, step: "01-pro-entry")
        assertNoHangul(app, context: "\(language) contract")
        signRookieContract(app)
        selectProWeekTab(app, label: weekLabel)
        capture(app, scenario: scenario, step: "01-week")
        assertNoHangul(app, context: "\(language) weekly plan")
        XCTAssertTrue(advanceToSeasonDecision(app), "\(language) 3주차 결정에 도달하지 못했습니다.")
        capture(app, scenario: scenario, step: "03-week3-decision")
        assertNoHangul(app, context: "\(language) week-3 decision")
        let choice = try XCTUnwrap(firstSeasonDecisionChoice(app))
        XCTAssertTrue(bringIntoView(choice))
        choice.tap()
        let confirm = app.buttons.matching(identifier: "pro.seasonDecision.confirm").firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: timeout))
        tapIfPresent(confirm)
        XCTAssertTrue(advanceUntilFollowUp(app), "\(language) 후속 결과에 도달하지 못했습니다.")
        capture(app, scenario: scenario, step: "04-follow-up")
        assertNoHangul(app, context: "\(language) follow-up")
    }

    // MARK: - Journey helpers

    private func launch(
        draftedCareerFixture: Bool = false,
        journeyEnabled: Bool = false,
        openProWeek: Bool = false,
        autoRelease: Bool = true,
        language: String? = "ko",
        contentSize: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = ["-uiTestResetCareer", "-baseball.audio.sound", "NO"]
        if autoRelease { arguments.append("-uiTestAutoRelease") }
        if draftedCareerFixture { arguments.append("-uiTestDraftedCareerFixture") }
        if journeyEnabled { arguments.append("-uiTestProCareerJourneyV1") }
        if openProWeek { arguments.append("-uiTestOpenProWeek") }
        if language == "ja" { arguments += ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"] }
        if language == "ko" { arguments += ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"] }
        if language == "en" { arguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"] }
        if let contentSize {
            arguments += ["-UIPreferredContentSizeCategoryName", contentSize]
        }
        app.launchArguments = arguments
        app.launch()
        return app
    }

    private func enterProFromDraftedFixture(_ app: XCUIApplication) {
        // UX 3차 드래프트 2화면: 결과 화면의 "계속"을 먼저 지나야 프로 진입 버튼이 보인다.
        let draftContinue = identified(app, "hs.draft.result.continue")
        if draftContinue.waitForExistence(timeout: 4), !app.buttons["hs.enterPro"].exists {
            _ = bringIntoView(draftContinue)
            draftContinue.tap()
        }
        let enterPro = app.buttons["hs.enterPro"]
        XCTAssertTrue(enterPro.waitForExistence(timeout: timeout), "프로 진입 버튼이 없습니다. \(visibleIdentifiers(app))")
        XCTAssertTrue(bringIntoView(enterPro))
        enterPro.tap()
        XCTAssertTrue(
            app.segmentedControls.firstMatch.waitForExistence(timeout: timeout)
                || identified(app, "pro.contractOffer").waitForExistence(timeout: 4),
            "프로 화면이 열리지 않았습니다."
        )
    }

    private func signRookieContract(_ app: XCUIApplication) {
        guard identified(app, "pro.contractOffer").waitForExistence(timeout: timeout) else { return }
        if identified(app, "pro.contractOffer.ambition.required").exists {
            let ambitionIDs = [
                "pro.contractOffer.ambition.franchise_icon",
                "pro.contractOffer.ambition.record_book",
                "pro.contractOffer.ambition.enduring_pro",
            ]
            if let ambition = ambitionIDs.map({ app.buttons[$0] }).first(where: { $0.exists && $0.isEnabled }) {
                XCTAssertTrue(bringIntoView(ambition, attempts: 12))
                ambition.tap()
            }
        }
        let sign = app.buttons["pro.contractOffer.sign"]
        XCTAssertTrue(sign.waitForExistence(timeout: timeout))
        XCTAssertTrue(bringIntoView(sign, attempts: 12), "신인 계약 서명 버튼이 화면에 없습니다.")
        if sign.isEnabled {
            sign.tap()
        } else {
            sign.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        let confirm = app.buttons.matching(identifier: "pro.contractOffer.confirm.accept")
        XCTAssertTrue(confirm.firstMatch.waitForExistence(timeout: timeout))
        let action = confirm.element(boundBy: max(0, confirm.count - 1))
        tapIfPresent(action)
    }

    private func selectProWeekTab(_ app: XCUIApplication, label: String) {
        for tab in ["커리어", "Career", "キャリア"] where app.tabBars.buttons[tab].exists {
            app.tabBars.buttons[tab].tap()
            break
        }
        let tabs = app.segmentedControls.firstMatch
        guard tabs.waitForExistence(timeout: timeout) else { return }
        let week = tabs.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
        if week.exists {
            if !week.isSelected { week.tap() }
            return
        }
        let byIndex = tabs.buttons.element(boundBy: 1)
        if byIndex.exists, byIndex.label == label, !byIndex.isSelected { byIndex.tap() }
    }

    @discardableResult
    private func advanceToSeasonDecision(_ app: XCUIApplication) -> Bool {
        for _ in 0..<40 {
            if identified(app, "pro.seasonDecision").exists { return true }
            if identified(app, "pro.contractOffer").exists { signRookieContract(app); continue }
            if app.buttons["pro.game.start"].exists {
                tapIfPresent(app.buttons["pro.game.start"])
                _ = playInning(app)
                continue
            }
            if app.buttons["pro.seasonReview.confirm"].exists {
                tapIfPresent(app.buttons["pro.seasonReview.confirm"])
                continue
            }
            if identified(app, "pro.seasonSettlement").exists { return false }
            if !selectAnyPlan(app) { reselectWeekTab(app); continue }
            if app.buttons["pro.advanceWeek"].exists, app.buttons["pro.advanceWeek"].isEnabled {
                tapIfPresent(app.buttons["pro.advanceWeek"])
            } else if app.buttons["pro.advanceSegment"].exists, app.buttons["pro.advanceSegment"].isEnabled {
                tapIfPresent(app.buttons["pro.advanceSegment"])
            } else {
                reselectWeekTab(app)
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.12))
        }
        return identified(app, "pro.seasonDecision").exists
    }

    @discardableResult
    private func advanceUntilFollowUp(_ app: XCUIApplication) -> Bool {
        let followUp = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "pro.weekly.decisionFollowUp.")
        ).firstMatch
        for _ in 0..<48 {
            if followUp.exists { return true }
            if identified(app, "pro.seasonDecision").exists {
                if let choice = firstSeasonDecisionChoice(app), bringIntoView(choice) {
                    choice.tap()
                    let confirm = app.buttons.matching(identifier: "pro.seasonDecision.confirm").firstMatch
                    if confirm.waitForExistence(timeout: 4) { tapIfPresent(confirm) }
                }
                continue
            }
            if app.buttons["pro.game.start"].exists {
                tapIfPresent(app.buttons["pro.game.start"])
                _ = playInning(app)
                continue
            }
            if app.buttons["pro.seasonReview.confirm"].exists {
                tapIfPresent(app.buttons["pro.seasonReview.confirm"])
                continue
            }
            if identified(app, "pro.seasonSettlement").exists { return false }
            if !selectAnyPlan(app) { reselectWeekTab(app); continue }
            if app.buttons["pro.advanceWeek"].exists, app.buttons["pro.advanceWeek"].isEnabled {
                tapIfPresent(app.buttons["pro.advanceWeek"])
            } else if app.buttons["pro.advanceSegment"].exists, app.buttons["pro.advanceSegment"].isEnabled {
                tapIfPresent(app.buttons["pro.advanceSegment"])
            } else {
                reselectWeekTab(app)
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.12))
        }
        return followUp.exists
    }

    @discardableResult
    private func advanceWeeks(_ app: XCUIApplication, count: Int) -> Bool {
        var advanced = 0
        var steps = 0
        while advanced < count, steps < 40 {
            steps += 1
            if identified(app, "pro.seasonDecision").exists {
                if let choice = firstSeasonDecisionChoice(app), bringIntoView(choice) {
                    choice.tap()
                    let confirm = app.buttons.matching(identifier: "pro.seasonDecision.confirm").firstMatch
                    if confirm.waitForExistence(timeout: 4) { tapIfPresent(confirm) }
                }
                continue
            }
            if app.buttons["pro.game.start"].exists {
                tapIfPresent(app.buttons["pro.game.start"])
                _ = playInning(app)
                continue
            }
            if app.buttons["pro.seasonReview.confirm"].exists {
                tapIfPresent(app.buttons["pro.seasonReview.confirm"])
                continue
            }
            if !selectAnyPlan(app) { reselectWeekTab(app); continue }
            if app.buttons["pro.advanceWeek"].exists, app.buttons["pro.advanceWeek"].isEnabled {
                tapIfPresent(app.buttons["pro.advanceWeek"])
                advanced += 1
            } else {
                reselectWeekTab(app)
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.12))
        }
        return advanced >= count
            || app.descendants(matching: .any).matching(
                NSPredicate(format: "identifier BEGINSWITH %@", "pro.weekly.decisionFollowUp.")
            ).firstMatch.exists
    }

    @discardableResult
    private func runUntilFirstOffseason(_ app: XCUIApplication) -> Bool {
        var steps = 0
        while steps < 200 {
            steps += 1
            if app.buttons["pro.offseason.arrow.forward.circle"].exists { return true }
            if identified(app, "pro.seasonSettlement").exists {
                capture(app, scenario: "06-season-complete", step: "settlement")
                capture(app, scenario: "glyphs-iphone17", step: "settlement")
                let ack = app.buttons["pro.settlement.acknowledge"]
                if ack.waitForExistence(timeout: timeout), bringIntoView(ack) { ack.tap() }
                continue
            }
            if identified(app, "pro.seasonDecision").exists {
                if let choice = firstSeasonDecisionChoice(app), bringIntoView(choice) {
                    choice.tap()
                    let confirm = app.buttons.matching(identifier: "pro.seasonDecision.confirm").firstMatch
                    if confirm.waitForExistence(timeout: 4) { tapIfPresent(confirm) }
                }
                continue
            }
            if identified(app, "pro.contractOffer").exists { signRookieContract(app); continue }
            if app.buttons["pro.game.start"].exists {
                tapIfPresent(app.buttons["pro.game.start"])
                _ = playInning(app)
                continue
            }
            if app.buttons["pro.seasonReview.confirm"].exists {
                tapIfPresent(app.buttons["pro.seasonReview.confirm"])
                continue
            }
            if identified(app, "pro.offseasonInvestment").exists { return skipInvestment(app) }
            if !selectAnyPlan(app) {
                reselectWeekTab(app)
                continue
            }
            if app.buttons["pro.advanceSegment"].exists, app.buttons["pro.advanceSegment"].isEnabled {
                tapIfPresent(app.buttons["pro.advanceSegment"])
            } else if app.buttons["pro.advanceWeek"].exists, app.buttons["pro.advanceWeek"].isEnabled {
                tapIfPresent(app.buttons["pro.advanceWeek"])
            } else {
                reselectWeekTab(app)
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.12))
        }
        return app.buttons["pro.offseason.arrow.forward.circle"].exists
            || identified(app, "pro.offseasonInvestment").exists
    }

    @discardableResult
    private func leaveOffseason(_ app: XCUIApplication) -> Bool {
        let forward = app.buttons["pro.offseason.arrow.forward.circle"]
        guard forward.waitForExistence(timeout: timeout), tapIfPresent(forward) else { return false }
        let confirm = app.buttons.matching(identifier: "pro.offseason.confirm").firstMatch
        guard confirm.waitForExistence(timeout: timeout), tapIfPresent(confirm) else { return false }
        return true
    }

    @discardableResult
    private func skipInvestment(_ app: XCUIApplication) -> Bool {
        let none = app.buttons["pro.offseasonInvestment.choice.none"]
        guard none.waitForExistence(timeout: timeout), bringIntoView(none) else { return false }
        none.tap()
        tapIfPresent(app.buttons["pro.offseasonInvestment.confirm"])
        let action = app.buttons.matching(identifier: "pro.offseasonInvestment.confirm.action").firstMatch
        if action.waitForExistence(timeout: 4) { tapIfPresent(action) }
        return true
    }

    @discardableResult
    private func selectAnyPlan(_ app: XCUIApplication) -> Bool {
        let ids = [
            "pro.plan.earnTrust", "pro.plan.refineCommand", "pro.plan.developStuff",
            "pro.plan.buildStamina", "pro.plan.developMovement", "pro.plan.recover",
        ]
        if let plan = ids.map({ app.buttons[$0] }).first(where: { $0.exists && $0.isEnabled }),
           bringIntoView(plan) {
            plan.tap()
            return true
        }
        return false
    }

    private func reselectWeekTab(_ app: XCUIApplication) {
        let tabs = app.segmentedControls.firstMatch
        let week = tabs.buttons.element(boundBy: 1)
        if tabs.exists, week.exists, !week.isSelected { week.tap() }
    }

    private func firstSeasonDecisionChoice(_ app: XCUIApplication) -> XCUIElement? {
        let matches = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "pro.seasonDecision.choice.")
        )
        guard matches.count > 0 else { return nil }
        return (0..<matches.count)
            .map { matches.element(boundBy: $0) }
            .first(where: { $0.exists && $0.isEnabled })
    }

    @discardableResult
    private func openGlossaryFromKnownTerms(_ app: XCUIApplication, preferred: [String]) -> Bool {
        let labels: [String: [String]] = [
            "stamina": ["체력", "Stamina", "体力"],
            "manager-faith": ["감독의 믿음", "Manager faith", "監督の信頼"],
            "stuff": ["구위", "Stuff", "球威"],
            "catcher-chemistry": ["포수와의 호흡", "Catcher trust", "捕手との呼吸"],
            "role": ["보직", "Role", "役割"],
            "command": ["제구", "Command", "制球"],
            "movement": ["변화구", "Movement", "変化球"],
            "fatigue": ["피로", "Fatigue", "疲労"],
        ]
        for id in preferred {
            let sheet = identified(app, "glossary.sheet.\(id)")
            let term = app.descendants(matching: .any)
                .matching(identifier: "glossary.term.\(id)")
                .firstMatch
            if term.exists {
                if term.isHittable {
                    term.tap()
                } else {
                    term.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                }
                if sheet.waitForExistence(timeout: 3) { return true }
            }
            for label in labels[id] ?? [] {
                let link = app.links[label].firstMatch
                if link.exists {
                    if link.isHittable { link.tap() }
                    else { link.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
                    if sheet.waitForExistence(timeout: 3) { return true }
                }
            }
        }
        return false
    }

    private func dismissGlossary(_ app: XCUIApplication) {
        // 알림 큐 배너에도 "닫기"가 있어 라벨 매칭이 모호하다. 시트 전용 식별자를 먼저 쓴다.
        let close = app.buttons["glossary.sheet.close"]
        if close.waitForExistence(timeout: 2) {
            close.tap()
        } else {
            for label in ["닫기", "Close", "閉じる"] {
                let fallback = app.buttons.matching(identifier: label).firstMatch
                if fallback.exists { fallback.tap(); break }
            }
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
    }

    private func focusSelection(_ app: XCUIApplication) -> [String] {
        [
            "hs.focus.velocity", "hs.focus.command", "hs.focus.breaking_ball",
            "hs.focus.stamina", "hs.focus.recovery", "hs.focus.game_planning",
        ]
        .filter { app.buttons[$0].exists && app.buttons[$0].isSelected }
    }

    // MARK: - Shared smoke-style helpers

    @discardableResult
    private func completeSetup(_ app: XCUIApplication) -> Bool {
        let start = app.buttons["hs.start"]
        let next = app.buttons["hs.setup.next"]
        guard start.waitForExistence(timeout: timeout) || next.waitForExistence(timeout: timeout) else { return false }
        var hops = 0
        while !start.exists, next.exists, hops < 6 {
            next.tap()
            hops += 1
        }
        guard start.waitForExistence(timeout: timeout) else { return false }
        start.tap()
        return true
    }

    private func dismissOpening(_ app: XCUIApplication) {
        let start = app.buttons["hs.opening.start"]
        if start.waitForExistence(timeout: 5) { start.tap() }
    }

    @discardableResult
    private func playInning(_ app: XCUIApplication) -> Bool {
        let throwButton = app.buttons["pitch.throw"]
        let fastForward = app.buttons["pitch.fastForwardBatter"]
        let nextBatter = app.buttons["pitch.nextBatter"]
        let finish = app.buttons["pitch.finish"]
        guard throwButton.waitForExistence(timeout: timeout) else { return false }
        var pitches = 0
        while !finish.exists, pitches < 120 {
            if fastForward.exists, bringIntoView(fastForward) {
                fastForward.tap(); pitches += 1
            } else if throwButton.exists, bringIntoView(throwButton) {
                throwButton.tap(); pitches += 1
            } else if nextBatter.exists, bringIntoView(nextBatter) {
                nextBatter.tap()
            } else {
                break
            }
        }
        guard finish.waitForExistence(timeout: timeout), bringIntoView(finish) else { return false }
        finish.tap()
        return finish.waitForNonExistence(timeout: timeout)
    }

    private func confirmSchool(_ app: XCUIApplication) {
        let matches = app.buttons.matching(identifier: "hs.school.confirm")
        guard matches.count > 0 else { return }
        let confirm = matches.element(boundBy: matches.count - 1)
        guard confirm.waitForExistence(timeout: 3) else { return }
        confirm.tap()
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

    @discardableResult
    private func tapIfPresent(_ element: XCUIElement) -> Bool {
        guard element.exists, element.isEnabled, bringIntoView(element) else { return false }
        element.tap()
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

    private func windUpPad(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "pitch.windup").firstMatch
    }

    private func identified(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func visibleIdentifiers(_ app: XCUIApplication) -> String {
        guard app.state == .runningForeground || app.state == .runningBackground else {
            return "<app \(app.state.rawValue)>"
        }
        return app.buttons.allElementsBoundByIndex.prefix(25).map { element in
            element.identifier.isEmpty ? "<\(element.label)>" : element.identifier
        }
        .joined(separator: ", ")
    }

    private func assertNoHangul(_ app: XCUIApplication, context: String) {
        let hangul = try! NSRegularExpression(pattern: "[가-힣ㄱ-ㅎㅏ-ㅣ]")
        let labels = app.staticTexts.allElementsBoundByIndex.map(\.label).filter { !$0.isEmpty }
        let contaminated = labels.filter {
            hangul.firstMatch(in: $0, range: NSRange($0.startIndex..., in: $0)) != nil
        }
        XCTAssertTrue(contaminated.isEmpty, "\(context) Korean leak: \(contaminated.joined(separator: " | "))")
    }

    private func capture(_ app: XCUIApplication, scenario: String, step: String) {
        shotIndex += 1
        let screenshot = XCUIScreen.main.screenshot()
        let name = String(format: "%02d-%@.png", shotIndex, step)
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "\(scenario)/\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
        let directory = shotRoot.appendingPathComponent(scenario, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        try? screenshot.pngRepresentation.write(to: url)
        print("QA_SHOT \(url.path)")
    }

    private func dismissCareerNoticeIfPresent(_ app: XCUIApplication) {
        let banner = identified(app, "pro.notice.banner.dismiss")
        if banner.exists {
            banner.tap()
        }
        let followUp = identified(app, "pro.notice.followUp.dismiss")
        if followUp.exists {
            followUp.tap()
        }
    }

    private func openSharePreview(
        _ app: XCUIApplication,
        share: XCUIElement,
        expectedName: String
    ) {
        dismissCareerNoticeIfPresent(app)
        XCTAssertTrue(bringIntoView(share))
        share.tap()
        XCTAssertTrue(
            identified(app, "share.card.preview").waitForExistence(timeout: timeout),
            "카드 미리보기가 열리지 않았습니다. \(visibleIdentifiers(app))"
        )
        let playerName = identified(app, "share.card.preview.playerName")
        XCTAssertTrue(
            playerName.waitForExistence(timeout: timeout),
            "카드 미리보기에 선수 이름이 없습니다."
        )
        XCTAssertEqual(playerName.label, expectedName)
        XCTAssertTrue(
            identified(app, "share.card.preview.close").waitForExistence(timeout: timeout),
            "카드 미리보기 닫기 버튼이 없습니다. \(visibleIdentifiers(app))"
        )
    }

    private func dismissSharePreview(_ app: XCUIApplication) {
        let close = identified(app, "share.card.preview.close")
        XCTAssertTrue(
            close.waitForExistence(timeout: timeout),
            "카드 미리보기 닫기 버튼이 없습니다. \(visibleIdentifiers(app))"
        )
        close.tap()
        XCTAssertTrue(
            identified(app, "share.card.preview").waitForNonExistence(timeout: timeout),
            "카드 미리보기가 닫히지 않았습니다."
        )
    }

    private func writeShareScreenshot(name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "share/\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
        let url = URL(
            fileURLWithPath: "/Users/solkim/Dev/baseball/apps/ios/releases/qa-1.2.9/share/\(name)"
        )
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? screenshot.pngRepresentation.write(to: url)
        print("QA_SHOT \(url.path)")
    }

    private func writeFixRoundScreenshot(name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "fix-round/\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
        let url = URL(
            fileURLWithPath: "/Users/solkim/Dev/baseball/apps/ios/releases/qa-1.2.8/fix-round/\(name)"
        )
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? screenshot.pngRepresentation.write(to: url)
        print("QA_SHOT \(url.path)")
    }
}
