import CoreGraphics
import XCTest
import UIKit

/// 고교 3년 → 드래프트 → 기억 계승 → 프로 입단까지 한 번에 걸어 본다.
/// 유닛 테스트는 엔진 연결을, 이 테스트는 "화면으로 실제로 끝까지 갈 수 있는지"를 지킨다.
@MainActor
final class CareerSmokeUITests: XCTestCase {
    private let timeout: TimeInterval = 12
    /// 고교 한 회차는 훈련 12~16 + 관계 4~6 + 경기 4~6 + 각성 3 + 챕터 8이라 단계 수가 많다.
    private let maximumSteps = 400

    override func setUp() {
        continueAfterFailure = false
    }

    /// 선수 만들기가 단계형이라 마지막 단계에 닿아야 `hs.start`가 나온다.
    /// 첫 회차는 이름 → 투수 유형 두 단계, 2회차부터 난이도·핸디캡이 하나 더 붙는다.
    @discardableResult
    private func completeSetup(
        _ app: XCUIApplication,
        seed: String? = nil,
        harshness: String? = nil
    ) -> Bool {
        let start = app.buttons["hs.start"]
        let next = app.buttons["hs.setup.next"]
        guard start.waitForExistence(timeout: timeout) || next.waitForExistence(timeout: timeout) else { return false }
        if let seed {
            let seedField = app.textFields["hs.setup.seed"]
            guard seedField.waitForExistence(timeout: timeout) else { return false }
            seedField.tap()
            seedField.typeText(seed)
        }
        var hops = 0
        while !start.exists, next.exists, hops < 6 {
            // 난이도 칸은 설정 흐름 중간에 있다. 지나가면서 원하는 값을 고른다.
            if let harshness {
                let option = app.buttons["hs.setup.harshness.\(harshness)"]
                if option.exists, option.isHittable { option.tap() }
            }
            next.tap()
            hops += 1
        }
        if let harshness {
            let option = app.buttons["hs.setup.harshness.\(harshness)"]
            if option.exists, option.isHittable { option.tap() }
        }
        guard start.waitForExistence(timeout: timeout) else { return false }
        start.tap()
        return true
    }

    private func launch(
        pitchAbilityFeedback: Bool = false,
        draftedCareerFixture: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        // 자동 릴리스로 돌린다. 타이밍 제스처는 사람이 손으로 확인하고, 이 테스트는 흐름을 본다.
        // 소리는 끈다 — 스모크가 검증할 대상이 아니고, 호스트 오디오 상태가 나쁘면
        // AVAudioPlayerNode.scheduleBuffer의 NSException으로 앱이 통째로 죽어 흐름 검증까지
        // 무너진다(시뮬레이터에서 재현, HEAD에서도 동일). 인자 도메인이라 앱 코드는 그대로다.
        var launchArguments = [
            "-uiTestResetCareer",
            "-uiTestAutoRelease",
            "-baseball.audio.sound", "NO",
        ]
        if pitchAbilityFeedback {
            launchArguments.append("-uiTestPitchAbilityFeedback")
        }
        if draftedCareerFixture {
            launchArguments.append("-uiTestDraftedCareerFixture")
        }
        app.launchArguments = launchArguments
        app.launch()
        return app
    }

    func testHighSchoolCareerRunsThroughDraftAndRebirth() {
        let app = launch()

        dismissOpening(app)
        XCTAssertTrue(app.buttons["hs.setup.next"].waitForExistence(timeout: timeout), "선수 만들기 화면이 열리지 않았습니다.")
        capture(app, name: "01-highschool-setup")
        XCTAssertTrue(completeSetup(app), "고교 시작 화면이 열리지 않았습니다.")

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

            // 드래프트 호명 연출은 전면을 덮는다. 아래 화면의 버튼은 "존재"하지만 눌리지
            // 않으므로, 무엇보다 먼저 이것을 넘긴다. 연출 중에는 같은 버튼이 "건너뛰기"라
            // 두 번 눌러야 빠져나온다.
            if app.buttons["hs.draft.reveal.done"].exists {
                // 첫 탭은 "건너뛰기"라 결과를 공개한다. 스토어 스크린샷은 **공개된 뒤**를
                // 찍어야 한다 — 연출 중간(라운드 카운트)은 아무 정보도 없는 화면이다.
                tapIfPresent(app.buttons["hs.draft.reveal.done"])
                capture(app, name: "07-draft-reveal")
                tapIfPresent(app.buttons["hs.draft.reveal.done"])
                continue
            }

            if app.buttons["hs.recap.continue"].exists {
                XCTAssertTrue(reachedDraft, "드래프트 전인데 3년 결산이 열렸습니다.")
                XCTAssertTrue(
                    finishRecapAndAssertPlayerContinuity(app),
                    "결산에서 다음 선수의 편지까지 이어지지 않았습니다."
                )
                return
            }

            if app.buttons["hs.rebirth"].exists {
                capture(app, name: "08-completed")
                XCTAssertTrue(reachedDraft, "드래프트를 거치지 않고 완료에 도달했습니다.")
                // 지명된 회차에서 같은 버튼은 "이 회차를 접고 다시 시작"이고, 누르면 새
                // 회차가 아니라 확인창을 거쳐 **기억 선택**으로 간다.
                let drafted = app.buttons["hs.enterPro"].exists
                XCTAssertTrue(tapIfPresent(app.buttons["hs.rebirth"]))
                if drafted {
                    let confirmFold = app.buttons["접고 기억을 고른다"]
                    XCTAssertTrue(
                        confirmFold.waitForExistence(timeout: timeout),
                        "프로를 접는 확인창이 열리지 않았습니다."
                    )
                    confirmFold.tap()
                    continue
                }
                // 환생 스탬프가 전면을 덮는다. **먼저** 이것이 사라지기를 기다린다 —
                // 덮인 동안에는 아래 화면이 접근성 트리에 잡히지 않는다.
                // 스탬프는 접근성 요소로 합쳐지므로 종류를 가리지 않고 찾는다.
                let stamp = app.descendants(matching: .any).matching(identifier: "hs.rebirth.stamp").firstMatch
                if stamp.waitForExistence(timeout: 4) {
                    capture(app, name: "09-rebirth")
                    _ = stamp.waitForNonExistence(timeout: timeout)
                }
                XCTAssertTrue(
                    app.buttons["hs.setup.next"].waitForExistence(timeout: timeout),
                    "다시 태어나기 뒤 새 회차 화면이 열리지 않았습니다."
                )
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
                let committed = tapIfPresent(app.buttons["hs.training.commitBlock"])
                    || tapIfPresent(app.buttons["hs.training.commit"])
                XCTAssertTrue(committed, "훈련 버튼을 화면 안으로 가져와 누를 수 없습니다.")
                assertTrainingResultIsImmediatelyUsable(app)
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
                _ = playInning(
                    app, capturePitchResult: !capturedPitch, usesFastForwardWhenAvailable: true
                )
                continue
            }

            if app.buttons["hs.draft.resolve"].exists {
                reachedDraft = true
                capture(app, name: "06-draft")
                tapIfPresent(app.buttons["hs.draft.resolve"])
                continue
            }

            if app.buttons["hs.legacy.confirm"].exists {
                selectRequiredLegacy(app)
                capture(app, name: "07-legacy")
                XCTAssertTrue(
                    tapIfPresent(app.buttons["hs.legacy.confirm"]),
                    "필요한 만큼 기억을 골랐는데도 확정할 수 없습니다."
                )
                let closeLife = app.buttons["확정하고 이 선수의 이야기를 닫는다"]
                XCTAssertTrue(
                    closeLife.waitForExistence(timeout: timeout),
                    "기억 확정 확인창이 열리지 않았습니다."
                )
                closeLife.tap()
                continue
            }

            capture(app, name: "99-stuck")
            XCTFail("어느 단계에서도 진행 가능한 조작을 찾지 못했습니다. \(steps)번째 단계. 보이는 버튼: \(visibleIdentifiers(app))")
            return
        }
        XCTFail("고교 회차가 \(maximumSteps)단계 안에 끝나지 않았습니다.")
    }

    /// 훈련 카드는 화면 아래에서 눌리고, 다음 국면 카드는 훨씬 짧을 수 있다. 그 높이
    /// 변화 뒤에도 결과가 빈 캔버스 밖이 아니라 현재 화면 안에 놓이는지 짧게 회귀 검증한다.
    func testTrainingCompletionKeepsResultOnScreen() {
        let app = launch()

        dismissOpening(app)
        XCTAssertTrue(completeSetup(app), "고교 시작 화면이 열리지 않았습니다.")
        XCTAssertTrue(
            tapIfPresent(app.buttons["hs.prologue.continue"]),
            "프롤로그를 지나 학교 선택으로 갈 수 없습니다."
        )
        XCTAssertTrue(tapFirst(app, prefix: "hs.school."), "학교를 선택할 수 없습니다.")
        confirmSchool(app)

        let commit = app.buttons["hs.training.commit"]
        XCTAssertTrue(commit.waitForExistence(timeout: timeout), "첫 훈련 화면이 열리지 않았습니다.")

        // 첫 훈련이 같은 국면에 머물더라도 반복해, 관계·경기처럼 더 짧은 국면으로
        // 갈아타는 경계까지 가능한 한 함께 밟는다.
        var completed = 0
        while completed < 4, commit.exists {
            // 첫 동작은 결과가 가장 길고 내부 상태 변경도 여러 번인 묶음 훈련으로 한다.
            // 단일 훈련만 확인하면 묶음 요약 피드백이 스크롤을 취소하는 회귀를 놓친다.
            let block = app.buttons["hs.training.commitBlock"]
            let action = completed == 0 && block.exists ? block : commit
            XCTAssertTrue(tapIfPresent(action), "훈련 버튼을 화면 안으로 가져와 누를 수 없습니다.")
            completed += 1
            assertTrainingResultIsImmediatelyUsable(app)

            // 닫기도 실제로 눌러 본다. 결과가 보이기만 하고 조작 불가능한 회귀도 막는다.
            app.buttons["hs.training.result.dismiss"].tap()
        }

        XCTAssertGreaterThan(completed, 0, "훈련을 한 번도 완료하지 못했습니다.")
        let response = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "hs.response.")
        ).firstMatch
        let awakening = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "hs.awakening.")
        ).firstMatch
        XCTAssertTrue(
            commit.exists
                || response.exists
                || awakening.exists
                || app.buttons["hs.game.start"].exists
                || app.buttons["hs.chapter.continue"].exists,
            "훈련 결과 뒤 이어서 진행할 행동이 없습니다. 보이는 버튼: \(visibleIdentifiers(app))"
        )
    }

    /// 드래프트를 통과했다면 프로 커리어가 그 결과로 열려야 한다.
    func testDraftedRunCanEnterProCareer() {
        // 프로 20시즌을 실제 UI로 완주하므로 일반 스모크의 기본 제한보다 오래 걸린다.
        // 밸런스나 기기 속도 변화가 기능 실패로 오인되지 않도록 이 종주만 여유를 명시한다.
        executionTimeAllowance = 1_800

        // 고교 3년 UI 종주는 별도 테스트가 맡는다. 여기서는 실제 고교 엔진으로 완주한
        // 확정 지명 픽스처를 써서, 드래프트 밸런스와 무관한 프로 전환·은퇴 흐름만 지킨다.
        let app = launch(draftedCareerFixture: true)
        let enterPro = app.buttons["hs.enterPro"]
        XCTAssertTrue(
            enterPro.waitForExistence(timeout: timeout),
            "지명 완료 픽스처에서 프로 진입 버튼이 열리지 않았습니다. 보이는 버튼: \(visibleIdentifiers(app))"
        )

        // 지명 완료 화면의 마지막 조작도 실제로 손에 닿아야 한다. 프로 진입 전에 끝까지
        // 내려 보며 떠 있는 탭 바가 다시 시작 버튼을 가리지 않는지도 함께 지킨다.
        let restart = app.buttons["hs.rebirth"]
        XCTAssertTrue(restart.exists, "완료 화면에 다시 시작 버튼이 없습니다.")
        XCTAssertTrue(
            bringIntoView(restart),
            "완료 화면의 마지막 버튼이 탭 바에 가려 닿지 않습니다."
        )
        XCTAssertTrue(bringIntoView(enterPro), "프로 진입 버튼을 다시 화면에 올리지 못했습니다.")
        enterPro.tap()

        XCTAssertTrue(
            app.staticTexts["다음 행동"].waitForExistence(timeout: timeout)
                || app.buttons["1주 진행"].waitForExistence(timeout: timeout),
            "프로 커리어 화면이 열리지 않았습니다."
        )
        capture(app, name: "10-pro-entered")
        XCTAssertTrue(
            finishProCareer(app),
            "프로 첫 주부터 은퇴까지 화면 흐름을 완료하지 못했습니다."
        )
        XCTAssertTrue(
            finishProLegacyAndReachNextPlayer(app),
            "프로 은퇴 기록이 대표 유산과 다음 고교 선수까지 이어지지 않았습니다."
        )
    }

    /// 프로는 구간 진행을 사용하되, 시즌 갈림길과 중요 경기는 실제 화면에서 직접 처리한다.
    /// 코어 완주 테스트만으로는 화면의 누락 국면·빈 화면·확인창 연결 단절을 잡을 수 없다.
    private func finishProCareer(_ app: XCUIApplication) -> Bool {
        // 입단 직후 기본 화면은 '오늘' 대시보드다. 실제 결정을 내리는 '이번 주'로 옮긴다.
        let weeklyScreen = app.segmentedControls.buttons["이번 주"]
        guard weeklyScreen.waitForExistence(timeout: timeout) else { return false }
        weeklyScreen.tap()

        var steps = 0
        while steps < 700 {
            steps += 1

            if app.buttons["pro.newPlayer"].exists {
                capture(app, name: "11-pro-retired")
                return true
            }
            if app.buttons["pro.plan.required"].exists
                || (app.buttons["pro.advanceSegment"].exists
                    && !app.buttons["pro.advanceSegment"].isEnabled) {
                let plans = app.descendants(matching: .any).matching(
                    NSPredicate(
                        format: "identifier BEGINSWITH %@ AND identifier != %@",
                        "pro.plan.", "pro.plan.required"
                    )
                )
                guard plans.count > 0 else { return false }
                let plan = plans.element(boundBy: 0)
                guard plan.exists, bringIntoView(plan), plan.isEnabled else { return false }
                plan.tap()
                continue
            }
            if tapIfPresent(app.buttons["pro.advanceSegment"]) { continue }

            if let choice = firstSeasonDecisionChoice(app) {
                guard choice.exists, bringIntoView(choice) else { return false }
                choice.tap()
                let identifiedConfirm = app.buttons.matching(
                    identifier: "pro.seasonDecision.confirm"
                ).firstMatch
                let confirm = identifiedConfirm.exists
                    ? identifiedConfirm : app.buttons["이 선택으로 결정"].firstMatch
                guard confirm.waitForExistence(timeout: timeout) else { return false }
                confirm.tap()
                continue
            }

            if tapIfPresent(app.buttons["pro.game.start"]) {
                _ = playInning(app, capturePitchResult: false, usesFastForwardWhenAvailable: true)
                continue
            }
            if tapIfPresent(app.buttons["시즌 기록 확인"]) { continue }

            if tapIfPresent(app.buttons["pro.offseason.arrow.forward.circle"]) {
                let confirm = app.buttons.matching(identifier: "pro.offseason.confirm").firstMatch
                guard confirm.waitForExistence(timeout: timeout) else { return false }
                confirm.tap()
                continue
            }
            if tapIfPresent(app.buttons["pro.retire"]) {
                let confirm = app.buttons.matching(identifier: "pro.retire.confirm").firstMatch
                guard confirm.waitForExistence(timeout: timeout) else { return false }
                confirm.tap()
                continue
            }

            // 화면 전환 애니메이션 한가운데라면 잠깐 안정화를 기다리고 한 번 더 판정한다.
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
            if app.buttons["pro.advanceSegment"].exists
                || app.buttons["pro.game.start"].exists
                || app.buttons["pro.retire"].exists { continue }
            capture(app, name: "99-stuck-pro-career")
            return false
        }
        capture(app, name: "99-pro-career-step-limit")
        return false
    }

    /// 은퇴 버튼이 보이는 것으로 끝내지 않고, 프로 기록을 고교 대표 유산에 합치고 새
    /// 선수의 편지까지 실제로 걷는다. 환생 게임의 가장 긴 결제 가치는 이 연결에 있다.
    private func finishProLegacyAndReachNextPlayer(_ app: XCUIApplication) -> Bool {
        let newPlayer = app.buttons["pro.newPlayer"]
        guard newPlayer.waitForExistence(timeout: timeout), tapIfPresent(newPlayer) else { return false }
        let confirmNewPlayer = app.buttons.matching(identifier: "pro.newPlayer.confirm").firstMatch
        guard confirmNewPlayer.waitForExistence(timeout: timeout) else { return false }
        confirmNewPlayer.tap()

        let legacyConfirm = app.buttons["hs.legacy.confirm"]
        guard legacyConfirm.waitForExistence(timeout: timeout) else { return false }
        selectRequiredLegacy(app)
        guard legacyConfirm.isEnabled, tapIfPresent(legacyConfirm) else { return false }
        let closeLife = app.buttons["확정하고 이 선수의 이야기를 닫는다"]
        guard closeLife.waitForExistence(timeout: timeout) else { return false }
        closeLife.tap()
        return finishRecapAndAssertPlayerContinuity(app)
    }

    /// SwiftUI가 카드 버튼의 identifier를 잠깐 `other`에 붙이는 프레임이 있어 역할을
    /// `button`으로만 한정하면 화면에 선택지가 보이는데도 0개로 판정될 수 있다.
    /// identifier를 우선하고, 실제 접근성 문구의 공통 계약인 "효과:"를 안전망으로 쓴다.
    private func firstSeasonDecisionChoice(_ app: XCUIApplication) -> XCUIElement? {
        let byIdentifier = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "pro.seasonDecision.choice.")
        )
        if byIdentifier.count > 0 { return byIdentifier.element(boundBy: 0) }

        let decision = app.descendants(matching: .any)["pro.seasonDecision"]
        let decisionEyebrow = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "주차 결정")
        )
        guard decision.exists || decisionEyebrow.count > 0 else { return nil }
        let byAccessibleEffect = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "효과:")
        )
        return byAccessibleEffect.count > 0 ? byAccessibleEffect.element(boundBy: 0) : nil
    }

    /// 새 회차는 대표 유산 하나를, 기능 도입 전 저장은 기존 기억을 필요한 만큼 고른다.
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

    /// 첫 불펜이 프롤로그 바로 다음에 나와야 한다. 이 게임에서 가장 좋은 것이 투구인데
    /// 사는 사람이 그걸 만나기까지 열 번을 눌러야 하면 안 된다(DOC-IOS-TOP §6.1).
    func testFirstPitchIsReachableInTwoTaps() {
        let app = launch()

        dismissOpening(app)
        XCTAssertTrue(completeSetup(app), "고교 시작 화면이 열리지 않았습니다.")

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

    /// 키운 능력이 지금 공에 어떻게 번역됐는지는 제품 화면에서 항상 보여야 한다.
    /// 상세 그리드는 QA 플래그에 남기고, 한 줄 요약은 기본 흐름을 늘리지 않는다.
    func testCompactPitchAbilityFeedbackIsVisibleWithoutDetailedExperimentFlag() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestResetCareer", "-uiTestAutoRelease",
            "-baseball.audio.sound", "NO",
        ]
        app.launch()

        dismissOpening(app)
        XCTAssertTrue(completeSetup(app), "고교 시작 화면이 열리지 않았습니다.")
        XCTAssertTrue(tapIfPresent(app.buttons["hs.prologue.throw"]))
        XCTAssertTrue(app.buttons["pitch.throw"].waitForExistence(timeout: timeout))
        XCTAssertTrue(
            app.descendants(matching: .any)
                .matching(identifier: "pitch.buildSummary").firstMatch.waitForExistence(timeout: timeout),
            "기본 투구 화면에 성장 수치 한 줄 요약이 없습니다."
        )
        XCTAssertFalse(
            app.descendants(matching: .any)
                .matching(identifier: "pitch.buildReadout").firstMatch.exists,
            "상세 QA 그리드가 플래그 없이 노출됐습니다."
        )
        XCTAssertTrue(
            app.staticTexts["구종 · 내가 만든 공"].exists,
            "훈련과 투구를 잇는 카드 제목이 보이지 않습니다."
        )
    }

    /// 관계 선택 직후 연속으로 국면이 바뀌어도 암전 커튼이 남지 않아야 한다.
    ///
    /// 예전 회귀는 `allowsHitTesting(false)` 커튼 아래의 버튼이 XCUITest에 계속
    /// 잡혀 조작 검사만으로는 통과했다. 이 테스트는 반응 선택 직후의 실제
    /// 스크린샷 픽셀을 연속으로 읽어 시각 콘텐츠가 남아 있는지 검증한다.
    func testRapidRelationshipChoicesNeverLeaveOpaqueBlankFrame() {
        executionTimeAllowance = 600
        let app = launch()

        dismissOpening(app)
        XCTAssertTrue(completeSetup(app), "고교 시작 화면이 열리지 않았습니다.")

        if tapIfPresent(app.buttons["hs.prologue.throw"]) {
            _ = playInning(app, capturePitchResult: false, usesFastForwardWhenAvailable: true)
        }

        var relationshipChoices = 0
        var steps = 0
        while relationshipChoices < 2, steps < 160 {
            steps += 1

            let responses = app.buttons.matching(
                NSPredicate(format: "identifier BEGINSWITH %@", "hs.response.")
            )
            if responses.count > 0 {
                let response = responses.element(boundBy: 0)
                XCTAssertTrue(bringIntoView(response), "관계 선택지를 화면에 올리지 못했습니다.")
                response.tap()
                relationshipChoices += 1

                // 취소된 지연 애니메이션이 사라지지 않는 문제를 잡으려면 한 시점만
                // 지나가서는 안 된다. 선택 직후의 연속 프레임을 검사한다.
                for frame in 0..<4 {
                    assertScreenContainsVisibleContent(
                        XCUIScreen.main.screenshot(),
                        context: "관계 선택 \(relationshipChoices) 후 프레임 \(frame)"
                    )
                    RunLoop.current.run(until: Date().addingTimeInterval(0.03))
                }
                continue
            }

            if tapIfPresent(app.buttons["hs.prologue.continue"]) { continue }
            if tapFirst(app, prefix: "hs.school.") { confirmSchool(app); continue }
            if tapIfPresent(app.buttons["hs.training.commitBlock"]) { continue }
            if tapIfPresent(app.buttons["hs.training.commit"]) { continue }
            if tapFirst(app, prefix: "hs.awakening.") { confirmAwakening(app); continue }
            if tapIfPresent(app.buttons["hs.chapter.continue"]) { continue }
            if tapIfPresent(app.buttons["hs.game.start"]) {
                _ = playInning(app, capturePitchResult: false, usesFastForwardWhenAvailable: true)
                continue
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }

        XCTAssertEqual(
            relationshipChoices,
            2,
            "결정적 초기화 흐름에서 관계 선택을 두 번 통과하지 못했습니다. "
                + "보이는 버튼: \(visibleIdentifiers(app))"
        )
    }

    /// 자동 릴리스를 끄고 실제 제스처(누르고 → 끌고 → 뗀다)로 한 구를 던진다.
    /// 유닛 테스트는 미터 값 → 정확도 변환을, 이 테스트는 제스처가 실제로 투구를 만드는지 본다.
    func testManualDeliveryGestureThrowsAPitch() {
        let app = XCUIApplication()
        // 소리를 끄는 이유는 launch()와 같다.
        app.launchArguments = ["-uiTestResetCareer", "-baseball.audio.sound", "NO"]
        app.launch()

        dismissOpening(app)
        XCTAssertTrue(completeSetup(app), "고교 시작 화면이 열리지 않았습니다.")

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

        // **되돌아오기 전에** 찍는다. 리플레이가 끝나면 화면이 다음 배합을 고르는 자리로
        // 자동 복귀하므로(학습 루프), 그 뒤에 찍으면 조작부만 나온다 — 스토어 2번 슬롯이
        // 요구하는 것은 궤적과 판정이다. 요소 조회는 느리므로 조회 전에 먼저 찍는다.
        capture(app, name: "12-delivery-result")

        XCTAssertTrue(
            app.buttons["pitch.nextBatter"].waitForExistence(timeout: timeout)
                || app.buttons["pitch.finish"].waitForExistence(timeout: 1)
                || windUpPad(app).exists,
            "제스처로 던진 뒤 승부가 진행되지 않았습니다."
        )
        // 복귀까지 마친 화면. 결과를 보고 나면 조작부로 돌아온다는 계약의 증거다.
        capture(app, name: "14-controls-after-result")
    }

    /// 와인드업 패드. 라벨만 갖고 있어 종류를 특정하지 않고 찾는다.
    private func windUpPad(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "와인드업").firstMatch
    }

    // MARK: - 보조

    /// 끝난 선수의 편지가 결산에서 보이고, 빠른 환생 뒤 새 선수에게 실제로 도착하는지 걷는다.
    /// 수치 계승만 검증하면 감정 연속성 UI가 끊겨도 테스트가 초록색으로 남는다.
    private func finishRecapAndAssertPlayerContinuity(_ app: XCUIApplication) -> Bool {
        let continueButton = app.buttons["hs.recap.continue"]
        guard continueButton.waitForExistence(timeout: timeout) else { return false }

        let legacy = app.descendants(matching: .any)
            .matching(identifier: "hs.recap.playerLegacy").firstMatch
        guard legacy.waitForExistence(timeout: timeout) else { return false }
        _ = bringIntoView(legacy)
        capture(app, name: "08-player-farewell")

        let enabled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "enabled == true"), object: continueButton
        )
        guard XCTWaiter.wait(for: [enabled], timeout: timeout) == .completed else { return false }
        continueButton.tap()

        let stamp = app.descendants(matching: .any)
            .matching(identifier: "hs.rebirth.stamp").firstMatch
        if !stamp.waitForExistence(timeout: 4) {
            // 일반 플레이는 마지막 선수 설정으로 즉시 환생한다. 완주 픽스처처럼 설정
            // 영수증이 없는 구버전 경로는 완료 화면에 머무르므로 다시 시작을 눌러 설정을
            // 한 번 마쳐야 새 선수에게 편지가 도착한다.
            let rebirth = app.buttons["hs.rebirth"]
            guard rebirth.waitForExistence(timeout: timeout), tapIfPresent(rebirth) else {
                return false
            }
            guard stamp.waitForExistence(timeout: 4) else { return false }
        }
        if stamp.exists {
            capture(app, name: "09-rebirth")
            _ = stamp.waitForNonExistence(timeout: timeout)
        }

        if app.buttons["hs.setup.next"].waitForExistence(timeout: 2) {
            guard completeSetup(app) else { return false }
        }

        let inheritedLetter = app.descendants(matching: .any)
            .matching(identifier: "hs.previousPlayerLetter").firstMatch
        guard inheritedLetter.waitForExistence(timeout: timeout) else { return false }
        _ = bringIntoView(inheritedLetter)
        capture(app, name: "10-previous-player-letter")
        return true
    }

    @discardableResult
    private func playInning(
        _ app: XCUIApplication,
        capturePitchResult: Bool,
        usesFastForwardWhenAvailable: Bool = false,
        expectsPitchAbilityFeedback: Bool = false
    ) -> Bool {
        let throwButton = app.buttons["pitch.throw"]
        let fastForward = app.buttons["pitch.fastForwardBatter"]
        let nextBatter = app.buttons["pitch.nextBatter"]
        let finish = app.buttons["pitch.finish"]
        XCTAssertTrue(throwButton.waitForExistence(timeout: timeout), "승부 화면이 열리지 않았습니다.")
        XCTAssertTrue(
            app.descendants(matching: .any)
                .matching(identifier: "pitch.buildSummary").firstMatch.waitForExistence(timeout: timeout),
            "지금 고른 공의 성장 수치 요약이 보이지 않습니다."
        )
        let buildReadout = app.descendants(matching: .any)
            .matching(identifier: "pitch.buildReadout").firstMatch
        if expectsPitchAbilityFeedback {
            XCTAssertTrue(
                buildReadout.waitForExistence(timeout: timeout),
                "투구 피드백 실험을 켰지만 수치 패널이 보이지 않습니다."
            )
        } else {
            XCTAssertFalse(
                buildReadout.exists,
                "제품 설정 종주에 투구 피드백 실험이 함께 노출됐습니다."
            )
        }
        XCTAssertFalse(app.tabBars.firstMatch.exists, "투구 조작 위에 하단 탭 바가 겹치면 안 됩니다.")

        var pitches = 0
        var captured = false
        var usedFastForward = false
        while !finish.exists, pitches < 120 {
            if usesFastForwardWhenAvailable, fastForward.exists, bringIntoView(fastForward) {
                fastForward.tap()
                usedFastForward = true
                pitches += 1
            } else if throwButton.exists, bringIntoView(throwButton) {
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
        return usedFastForward
    }

    /// 1회차에는 오프닝 장면이 먼저 뜬다. 넘기지 않으면 선수 만들기 화면에 닿지 못한다.
    private func dismissOpening(_ app: XCUIApplication) {
        let start = app.buttons["hs.opening.start"]
        if start.waitForExistence(timeout: 5) { start.tap() }
    }

    @discardableResult
    private func tapIfPresent(_ element: XCUIElement) -> Bool {
        guard element.exists, element.isEnabled else { return false }
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

    /// 스크롤 제스처로 구조를 구해 주기 전에 결과 패널이 스스로 화면 안에 들어와야 한다.
    /// 패널의 닫기 버튼은 상단에 있으므로 `hittable`이면 검은 빈 영역이 아니라 결과를
    /// 보고 있으며 곧바로 다음 조작도 할 수 있다는 강한 신호다.
    private func assertTrainingResultIsImmediatelyUsable(
        _ app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let dismiss = app.buttons["hs.training.result.dismiss"]
        let visible = NSPredicate(format: "exists == true AND hittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: visible, object: dismiss)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(
            result, .completed,
            "훈련 직후 결과가 화면 안에 나타나지 않았습니다. 보이는 버튼: \(visibleIdentifiers(app))",
            file: file, line: line
        )
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

    /// 스크린 중앙(상태 바·하단 탭 제외)의 픽셀 중 RGB 최댓값이 40/255를
    /// 넘는 픽셀이 0.5% 이상이어야 한다. 정상 카드의 글자·테두리·액션 색은
    /// 충분히 이 기준을 넘지만, 전면 `BaseballTheme.canvas`(#080D0B) 커튼은 0%다.
    private func assertScreenContainsVisibleContent(
        _ screenshot: XCUIScreenshot,
        context: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let image = UIImage(data: screenshot.pngRepresentation)?.cgImage else {
            XCTFail("스크린샷 픽셀을 읽지 못했습니다: \(context)", file: file, line: line)
            return
        }

        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let rendered = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard rendered else {
            XCTFail("스크린샷 픽셀 버퍼를 만들지 못했습니다: \(context)", file: file, line: line)
            return
        }

        let xRange = Int(Double(width) * 0.08)..<Int(Double(width) * 0.92)
        let yRange = Int(Double(height) * 0.10)..<Int(Double(height) * 0.78)
        let stride = max(1, min(width, height) / 120)
        var samples = 0
        var visibleSamples = 0
        for y in Swift.stride(from: yRange.lowerBound, to: yRange.upperBound, by: stride) {
            for x in Swift.stride(from: xRange.lowerBound, to: xRange.upperBound, by: stride) {
                let offset = (y * width + x) * 4
                let brightestChannel = max(pixels[offset], pixels[offset + 1], pixels[offset + 2])
                samples += 1
                if brightestChannel > 40 { visibleSamples += 1 }
            }
        }

        let visibleRatio = samples == 0 ? 0 : Double(visibleSamples) / Double(samples)
        XCTAssertGreaterThanOrEqual(
            visibleRatio,
            0.005,
            "\(context): 중앙 화면의 밝은 픽셀이 \(visibleRatio * 100)%로, "
                + "전면 불투명 암전 프레임으로 보입니다.",
            file: file,
            line: line
        )
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
