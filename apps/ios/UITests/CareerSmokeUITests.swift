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
        draftedCareerFixture: Bool = false,
        journeyEnabled: Bool = false,
        language: String? = nil
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
        if journeyEnabled {
            launchArguments.append("-uiTestProCareerJourneyV1")
        }
        if language == "ja" {
            launchArguments += ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        }
        app.launchArguments = launchArguments
        app.launch()
        return app
    }

    func testJapaneseBinaryRunsFromOpeningThroughPrologueWithoutHangulFallback() {
        let app = launch(language: "ja")

        let opening = app.buttons["hs.opening.start"]
        XCTAssertTrue(opening.waitForExistence(timeout: timeout), "日本語のオープニングが表示されません。")
        XCTAssertEqual(opening.label, "スタート")
        XCTAssertTrue(app.staticTexts["野球がダメならまた転生"].exists)
        assertVisibleCopyContainsNoHangul(app, context: "Japanese opening")

        opening.tap()
        let next = app.buttons["hs.setup.next"]
        XCTAssertTrue(next.waitForExistence(timeout: timeout), "日本語の選手作成画面が表示されません。")
        XCTAssertEqual(next.label, "次へ")
        XCTAssertTrue(completeSetup(app), "日本語の選手作成を完了できません。")

        let firstPitch = app.buttons["hs.prologue.throw"]
        XCTAssertTrue(firstPitch.waitForExistence(timeout: timeout), "日本語のプロローグが表示されません。")
        XCTAssertEqual(firstPitch.label, "初球を投げる")
        assertVisibleCopyContainsNoHangul(app, context: "Japanese prologue")
    }

    /// 프로를 시작하지 않은 상태에서도 "모든 진행 삭제"는 성공으로 끝나야 한다.
    /// 삭제할 프로가 없다는 no-op을 실패로 오인하면 설정 탭에 그대로 남는다.
    func testDeleteAllProgressReturnsToFirstLaunchWhenProCareerIsAlreadyEmpty() {
        let app = launch(draftedCareerFixture: true)

        let settingsTab = app.tabBars.buttons["설정"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: timeout), "설정 탭이 열리지 않았습니다.")
        settingsTab.tap()

        let deleteAll = app.buttons["settings.deleteAll"]
        // SwiftUI List는 화면 밖의 행을 지연 생성하므로, 존재 여부를 기다리기 전에
        // 목록 끝까지 내려 삭제 행을 접근성 트리에 올린다.
        for _ in 0..<8 {
            if deleteAll.exists, deleteAll.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(deleteAll.waitForExistence(timeout: timeout), "모든 진행 삭제 버튼이 없습니다.")
        XCTAssertTrue(deleteAll.isHittable, "모든 진행 삭제 버튼을 화면에 올리지 못했습니다.")
        deleteAll.tap()

        // confirmationDialog의 SwiftUI 접근성 트리는 같은 액션을 부모/자식 버튼으로
        // 중복 노출할 수 있으므로 첫 번째 실제 매치를 사용한다.
        let confirm = app.buttons.matching(identifier: "settings.deleteAll.confirm").firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: timeout), "진행 삭제 확인 버튼이 없습니다.")
        confirm.tap()

        let opening = app.buttons["hs.opening.start"]
        XCTAssertTrue(
            opening.waitForExistence(timeout: timeout),
            "모든 진행 삭제 후 첫 실행 오프닝으로 돌아오지 않았습니다. 보이는 버튼: \(visibleIdentifiers(app))"
        )
        XCTAssertFalse(app.tabBars.firstMatch.exists, "첫 실행 오프닝에 기존 탭 바가 남았습니다.")
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

        // 이 여섯 행은 App Store crash의 actor-isolation 경계였다. 화면이 열린 뒤 모든
        // 고정 행이 접근성 트리에 남아 있으면 구조 수정이 선택지를 누락하지 않은 것이다.
        for identifier in [
            "hs.focus.velocity",
            "hs.focus.command",
            "hs.focus.breaking_ball",
            "hs.focus.stamina",
            "hs.focus.recovery",
            "hs.focus.game_planning",
        ] {
            XCTAssertTrue(
                app.buttons[identifier].waitForExistence(timeout: 2),
                "훈련 선택 행이 누락됐습니다: \(identifier)"
            )
        }

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
    func testJapaneseDraftedRunCompletesProCareerJourneyAtMaximumHorizon() throws {
        // 프로 20시즌을 실제 UI로 완주하므로 일반 스모크의 기본 제한보다 오래 걸린다.
        // 밸런스나 기기 속도 변화가 기능 실패로 오인되지 않도록 이 종주만 여유를 명시한다.
        // A measured 20-season run on the iPhone 17 Pro Max simulator takes about 37 minutes.
        // Keep enough headroom for slower CI hosts while still bounding a genuinely stuck run.
        executionTimeAllowance = 3_000

        // 고교 3년 UI 종주는 별도 테스트가 맡는다. 여기서는 실제 고교 엔진으로 완주한
        // 확정 지명 픽스처를 써서, 드래프트 밸런스와 무관한 프로 전환·은퇴 흐름만 지킨다.
        let app = launch(draftedCareerFixture: true, journeyEnabled: true, language: "ja")
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

        let proTabs = app.segmentedControls.firstMatch
        let proTabsOpened = proTabs.waitForExistence(timeout: timeout)
        if !proTabsOpened {
            capture(app, name: "10-pro-entry-failed")
        }
        XCTAssertTrue(
            proTabsOpened,
            "프로 커리어 화면이 열리지 않았습니다. 보이는 버튼: \(visibleIdentifiers(app))"
        )
        let thisWeek = proTabs.buttons.element(boundBy: 1)
        XCTAssertTrue(thisWeek.exists, "프로의 이번 주 화면 선택지가 없습니다.")
        XCTAssertEqual(thisWeek.label, "今週")
        capture(app, name: "10-pro-entered")
        thisWeek.tap()

        let evidence = try XCTUnwrap(
            finishProCareer(app),
            "프로 첫 주부터 최대 시즌 은퇴까지 화면 흐름을 완료하지 못했습니다."
        )
        XCTAssertTrue(evidence.rookieContractSeen, "신인 계약 화면을 보지 못했습니다.")
        XCTAssertTrue(evidence.rookieContractSigned, "신인 계약을 실제로 서명하지 못했습니다.")
        XCTAssertGreaterThanOrEqual(evidence.settlementsSeen, 1, "시즌 결산 화면을 보지 못했습니다.")
        XCTAssertEqual(
            evidence.settlementsSeen,
            expectedMaximumCareerSeasons,
            "자발적 조기 은퇴가 아니라 제품 최대 시즌까지 모든 결산을 봐야 합니다."
        )
        XCTAssertEqual(
            evidence.settlementsAcknowledged,
            evidence.settlementsSeen,
            "모든 persisted settlement는 확인 액션으로 닫혀야 합니다."
        )
        XCTAssertGreaterThanOrEqual(evidence.offseasonsSeen, 1, "오프시즌 화면을 보지 못했습니다.")
        XCTAssertGreaterThanOrEqual(evidence.offseasonsCompleted, 1, "오프시즌 계속 경로를 완료하지 못했습니다.")
        XCTAssertGreaterThanOrEqual(evidence.investmentsSeen, 1, "오프시즌 투자 화면을 보지 못했습니다.")
        XCTAssertGreaterThanOrEqual(evidence.investmentsCompleted, 1, "투자하지 않음 경로를 완료하지 못했습니다.")
        if evidence.laterContractMarketsPresented > 0 {
            XCTAssertGreaterThanOrEqual(
                evidence.laterContractMarketsAccepted,
                1,
                "후속 계약 시장이 열렸지만 실제 offer를 수락하지 않았습니다."
            )
        }
        XCTAssertTrue(evidence.retirementPreviewSeen, "최대 시즌 은퇴 미리보기를 보지 못했습니다.")
        XCTAssertTrue(evidence.finalHonorsReached, "최종 은퇴 명예와 새 선수 경계에 도달하지 못했습니다.")
    }

    /// 프로는 구간 진행을 사용하되, 시즌 갈림길과 중요 경기는 실제 화면에서 직접 처리한다.
    /// 코어 완주 테스트만으로는 화면의 누락 국면·빈 화면·확인창 연결 단절을 잡을 수 없다.
    private struct ProJourneyEvidence {
        var rookieContractSeen = false
        var rookieContractSigned = false
        var settlementsSeen = 0
        var settlementsAcknowledged = 0
        var offseasonsSeen = 0
        var offseasonsCompleted = 0
        var investmentsSeen = 0
        var investmentsCompleted = 0
        var laterContractMarketsPresented = 0
        var laterContractMarketsAccepted = 0
        var retirementPreviewSeen = false
        var finalHonorsReached = false
    }

    private let expectedMaximumCareerSeasons = 20

    private func finishProCareer(_ app: XCUIApplication) -> ProJourneyEvidence? {
        var evidence = ProJourneyEvidence()
        var steps = 0
        while steps < 1_200 {
            steps += 1

            if app.buttons["pro.newPlayer"].exists {
                capture(app, name: "11-pro-retired")
                let honors = identified(app, "pro.retirement.honors")
                let finalScore = identified(app, "pro.retirement.final.score")
                guard honors.waitForExistence(timeout: timeout), finalScore.exists else {
                    return stopProJourney(app, "최종 은퇴 명예 또는 최종 점수 영역이 없습니다.")
                }
                XCTAssertTrue(bringIntoView(honors), "최종 은퇴 명예를 화면에 올리지 못했습니다.")
                assertVisibleCopyContainsNoHangul(app, context: "Japanese final retirement honors")
                evidence.finalHonorsReached = true
                return evidence
            }

            if identified(app, "pro.contractOffer").exists {
                guard handleContractOffer(app, evidence: &evidence) else { return nil }
                continue
            }

            if identified(app, "pro.seasonSettlement").exists {
                guard handleSettlement(app, evidence: &evidence) else { return nil }
                continue
            }

            if identified(app, "pro.offseasonInvestment").exists {
                guard handleInvestment(app, evidence: &evidence) else { return nil }
                continue
            }

            if identified(app, "pro.seasonDecision").exists {
                guard let choice = firstSeasonDecisionChoice(app), choice.exists,
                      bringIntoView(choice) else {
                    return stopProJourney(app, "시즌 결정 화면에 stable choice action이 없습니다.")
                }
                choice.tap()
                let confirmMatches = app.buttons.matching(identifier: "pro.seasonDecision.confirm")
                guard confirmMatches.count > 0 else {
                    return stopProJourney(app, "시즌 결정 확인 action이 없습니다.")
                }
                let confirm = confirmMatches.element(boundBy: confirmMatches.count - 1)
                guard confirm.waitForExistence(timeout: timeout), tapIfPresent(confirm) else {
                    return stopProJourney(app, "시즌 결정 확인 action을 누를 수 없습니다.")
                }
                continue
            }

            if app.buttons["pro.game.start"].exists {
                guard tapIfPresent(app.buttons["pro.game.start"]) else {
                    return stopProJourney(app, "중요 경기 시작 action을 누를 수 없습니다.")
                }
                guard playInning(app, capturePitchResult: false, usesFastForwardWhenAvailable: true) else {
                    return stopProJourney(app, "중요 경기를 실제 투구 UI로 끝내지 못했습니다.")
                }
                continue
            }

            if app.buttons["pro.seasonReview.confirm"].exists {
                guard tapIfPresent(app.buttons["pro.seasonReview.confirm"]) else {
                    return stopProJourney(app, "시즌 리뷰 확인 action을 누를 수 없습니다.")
                }
                continue
            }

            if app.buttons["pro.offseason.arrow.forward.circle"].exists {
                evidence.offseasonsSeen += 1
                if evidence.offseasonsSeen == 1 {
                    assertVisibleCopyContainsNoHangul(app, context: "Japanese first offseason")
                }
                guard tapIfPresent(app.buttons["pro.offseason.arrow.forward.circle"]) else {
                    return stopProJourney(app, "오프시즌 계속/재계약 경로를 누를 수 없습니다.")
                }
                let confirmMatches = app.buttons.matching(identifier: "pro.offseason.confirm")
                guard confirmMatches.count > 0 else {
                    return stopProJourney(app, "오프시즌 확인 dialog가 열리지 않았습니다.")
                }
                let confirm = confirmMatches.element(boundBy: confirmMatches.count - 1)
                guard confirm.waitForExistence(timeout: timeout), tapIfPresent(confirm) else {
                    return stopProJourney(app, "오프시즌 확인 action을 누를 수 없습니다.")
                }
                evidence.offseasonsCompleted += 1
                continue
            }

            // A read-only retirement projection is intentionally visible in every ordinary
            // offseason. Only the maximum-horizon retirement phase exposes `pro.retire`, so
            // do not mistake an early projection card for the forced-retirement boundary.
            if app.buttons["pro.retire"].exists {
                guard identified(app, "pro.retirement.preview").exists else {
                    return stopProJourney(app, "최대 시즌 은퇴 action 앞에 미리보기가 없습니다.")
                }
                guard handleRetirementPreview(app, evidence: &evidence) else { return nil }
                continue
            }

            if identified(app, "pro.plan.required").exists
                || (app.buttons["pro.advanceSegment"].exists
                    && !app.buttons["pro.advanceSegment"].isEnabled) {
                guard let plan = firstWeeklyPlan(app), plan.exists, bringIntoView(plan), plan.isEnabled else {
                    return stopProJourney(app, "주간 계획 화면에 선택 가능한 stable plan이 없습니다.")
                }
                plan.tap()
                continue
            }
            if tapIfPresent(app.buttons["pro.advanceSegment"]) { continue }

            // A phase mutation can recreate the tab content and restore the default Today tab.
            // Re-select the structural second segment by index; its Japanese label is asserted,
            // never used as the selector.
            let tabs = app.segmentedControls.firstMatch
            let week = tabs.buttons.element(boundBy: 1)
            if tabs.exists, week.exists, week.label == "今週", !week.isSelected {
                week.tap()
                continue
            }

            // 화면 전환 애니메이션 한가운데라면 잠깐 안정화를 기다리고 한 번 더 판정한다.
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
            if app.buttons["pro.advanceSegment"].exists
                || app.buttons["pro.game.start"].exists
                || app.buttons["pro.seasonReview.confirm"].exists
                || identified(app, "pro.seasonSettlement").exists
                || identified(app, "pro.offseasonInvestment").exists { continue }
            return stopProJourney(app, "프로 여정의 어느 phase에서도 진행 가능한 stable action을 찾지 못했습니다.")
        }
        return stopProJourney(app, "프로 여정이 1,200단계 안에 최대 시즌 은퇴까지 끝나지 않았습니다.")
    }

    private func handleContractOffer(
        _ app: XCUIApplication,
        evidence: inout ProJourneyEvidence
    ) -> Bool {
        let offerRoot = identified(app, "pro.contractOffer")
        guard offerRoot.waitForExistence(timeout: timeout) else {
            failProJourney(app, "계약 offer 화면이 stable root로 열리지 않았습니다.")
            return false
        }
        assertVisibleCopyContainsNoHangul(app, context: "Japanese contract offer")
        for suffix in ["duration", "annualSalary", "role", "expectation", "legacy"] {
            let identifier = "pro.contractOffer.offer.0.\(suffix)"
            guard identified(app, identifier).waitForExistence(timeout: timeout) else {
                failProJourney(app, "계약 offer의 \(suffix) semantic region이 없습니다.")
                return false
            }
            XCTAssertFalse(identified(app, identifier).label.isEmpty, identifier)
        }

        if identified(app, "pro.contractOffer.ambition.required").exists {
            let ambitionIDs = [
                "pro.contractOffer.ambition.franchise_icon",
                "pro.contractOffer.ambition.record_book",
                "pro.contractOffer.ambition.enduring_pro",
            ]
            guard let ambition = ambitionIDs
                .map({ app.buttons[$0] })
                .first(where: { $0.exists && $0.isEnabled }),
                bringIntoView(ambition) else {
                failProJourney(app, "서명에 필요한 unfinished ambition을 선택할 수 없습니다.")
                return false
            }
            ambition.tap()
        }

        let rookieSign = app.buttons["pro.contractOffer.sign"]
        let isRookie = rookieSign.waitForExistence(timeout: 1)
        if isRookie {
            if !evidence.rookieContractSeen {
                evidence.rookieContractSeen = true
            }
            guard tapIfPresent(rookieSign) else {
                failProJourney(app, "신인 계약 서명 action을 누를 수 없습니다.")
                return false
            }
        } else {
            evidence.laterContractMarketsPresented += 1
            let offerIDs = (0...2).map { "pro.contractOffer.offer.\($0)" }
            guard let offer = offerIDs
                .map({ app.buttons[$0] })
                .first(where: { $0.exists && $0.isEnabled }),
                bringIntoView(offer) else {
                failProJourney(app, "후속 계약 시장에서 선택 가능한 실제 offer card가 없습니다.")
                return false
            }
            offer.tap()
        }

        let confirmMatches = app.buttons.matching(identifier: "pro.contractOffer.confirm.accept")
        guard confirmMatches.count > 0 else {
            failProJourney(app, "계약 offer 확인 action이 열리지 않았습니다.")
            return false
        }
        let confirm = confirmMatches.element(boundBy: confirmMatches.count - 1)
        guard confirm.waitForExistence(timeout: timeout), tapIfPresent(confirm) else {
            failProJourney(app, "계약 offer 확인 action을 누를 수 없습니다.")
            return false
        }
        if isRookie {
            evidence.rookieContractSigned = true
        } else {
            evidence.laterContractMarketsAccepted += 1
        }
        if isRookie {
            guard identified(app, "pro.plan.required").waitForExistence(timeout: timeout)
                || app.buttons["pro.advanceSegment"].waitForExistence(timeout: timeout) else {
                failProJourney(app, "신인 계약 수락 뒤 주간 계획 phase로 돌아오지 않았습니다.")
                return false
            }
        } else {
            guard identified(app, "pro.offseasonInvestment").waitForExistence(timeout: timeout) else {
                failProJourney(app, "후속 계약 수락 뒤 오프시즌 투자 phase가 열리지 않았습니다.")
                return false
            }
        }
        return true
    }

    private func handleSettlement(
        _ app: XCUIApplication,
        evidence: inout ProJourneyEvidence
    ) -> Bool {
        evidence.settlementsSeen += 1
        assertVisibleCopyContainsNoHangul(app, context: "Japanese season settlement")
        for identifier in [
            "pro.seasonSettlement",
            "pro.settlement.goal.metrics",
            "pro.settlement.fanReasons",
            "pro.settlement.merchandise",
        ] {
            guard identified(app, identifier).waitForExistence(timeout: timeout) else {
                failProJourney(app, "결산의 \(identifier) semantic region이 없습니다.")
                return false
            }
        }
        let acknowledge = app.buttons["pro.settlement.acknowledge"]
        guard acknowledge.waitForExistence(timeout: timeout), bringIntoView(acknowledge) else {
            failProJourney(app, "persisted settlement acknowledge action이 없습니다.")
            return false
        }
        XCTAssertEqual(acknowledge.label, "決算を確認")
        acknowledge.tap()
        evidence.settlementsAcknowledged += 1
        guard identified(app, "pro.seasonSettlement").waitForNonExistence(timeout: timeout) else {
            failProJourney(app, "결산 확인 뒤 settlement 화면이 닫히지 않았습니다.")
            return false
        }
        return true
    }

    private func handleInvestment(
        _ app: XCUIApplication,
        evidence: inout ProJourneyEvidence
    ) -> Bool {
        evidence.investmentsSeen += 1
        if evidence.investmentsSeen == 1 {
            assertVisibleCopyContainsNoHangul(app, context: "Japanese first offseason investment")
        }
        guard identified(app, "pro.offseasonInvestment").waitForExistence(timeout: timeout) else {
            failProJourney(app, "오프시즌 투자 stable root가 없습니다.")
            return false
        }
        let none = app.buttons["pro.offseasonInvestment.choice.none"]
        guard none.waitForExistence(timeout: timeout), none.isEnabled, bringIntoView(none) else {
            failProJourney(app, "동등한 투자하지 않음 선택지를 누를 수 없습니다.")
            return false
        }
        XCTAssertEqual(none.label, "投資しない")
        none.tap()

        let confirm = app.buttons["pro.offseasonInvestment.confirm"]
        guard confirm.waitForExistence(timeout: timeout), tapIfPresent(confirm) else {
            failProJourney(app, "투자 확인 action을 열 수 없습니다.")
            return false
        }
        let confirmMatches = app.buttons.matching(identifier: "pro.offseasonInvestment.confirm.action")
        guard confirmMatches.count > 0 else {
            failProJourney(app, "투자 confirmation dialog action이 없습니다.")
            return false
        }
        let confirmAction = confirmMatches.element(boundBy: confirmMatches.count - 1)
        guard confirmAction.waitForExistence(timeout: timeout), tapIfPresent(confirmAction) else {
            failProJourney(app, "투자 confirmation dialog action을 누를 수 없습니다.")
            return false
        }
        evidence.investmentsCompleted += 1
        guard identified(app, "pro.offseasonInvestment").waitForNonExistence(timeout: timeout) else {
            failProJourney(app, "투자하지 않음 확인 뒤 투자 화면이 닫히지 않았습니다.")
            return false
        }
        return true
    }

    private func handleRetirementPreview(
        _ app: XCUIApplication,
        evidence: inout ProJourneyEvidence
    ) -> Bool {
        guard evidence.settlementsSeen == expectedMaximumCareerSeasons else {
            failProJourney(
                app,
                "은퇴 미리보기가 최대 시즌 결산 \(expectedMaximumCareerSeasons)회 뒤에 열리지 않았습니다."
            )
            return false
        }
        assertVisibleCopyContainsNoHangul(app, context: "Japanese retirement preview")
        for identifier in [
            "pro.retirement.preview",
            "pro.retirement.preview.score",
            "pro.retirement.preview.retired-number",
        ] {
            guard identified(app, identifier).waitForExistence(timeout: timeout) else {
                failProJourney(app, "은퇴 미리보기의 \(identifier) semantic region이 없습니다.")
                return false
            }
        }
        let maximumSeasonLabel = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "\(expectedMaximumCareerSeasons) キャリアシーズン")
        ).firstMatch
        XCTAssertTrue(
            maximumSeasonLabel.exists,
            "제품 최대 시즌이 아닌 조기 은퇴 미리보기입니다. 보이는 버튼: \(visibleIdentifiers(app))"
        )

        let retire = app.buttons["pro.retire"]
        guard retire.waitForExistence(timeout: timeout), tapIfPresent(retire) else {
            failProJourney(app, "은퇴 미리보기의 retire action을 누를 수 없습니다.")
            return false
        }
        let confirmMatches = app.buttons.matching(identifier: "pro.retire.confirm")
        guard confirmMatches.count > 0 else {
            failProJourney(app, "은퇴 확인 dialog action이 없습니다.")
            return false
        }
        let confirm = confirmMatches.element(boundBy: confirmMatches.count - 1)
        guard confirm.waitForExistence(timeout: timeout), tapIfPresent(confirm) else {
            failProJourney(app, "은퇴 확인 dialog action을 누를 수 없습니다.")
            return false
        }
        evidence.retirementPreviewSeen = true
        return true
    }

    private func firstWeeklyPlan(_ app: XCUIApplication) -> XCUIElement? {
        [
            "pro.plan.earnTrust",
            "pro.plan.refineCommand",
            "pro.plan.developStuff",
            "pro.plan.buildStamina",
            "pro.plan.developMovement",
            "pro.plan.recover",
        ]
            .map { app.buttons[$0] }
            .first(where: { $0.exists && $0.isEnabled })
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

    /// 시즌 결정은 내용이 매번 달라지므로 localized label이 아닌 제품 접근성 계약으로만
    /// 선택한다. 화면이 안정화되기 전에는 nil을 돌려 caller가 진단을 남기고 실패한다.
    private func firstSeasonDecisionChoice(_ app: XCUIApplication) -> XCUIElement? {
        let byIdentifier = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "pro.seasonDecision.choice.")
        )
        guard byIdentifier.count > 0 else { return nil }
        return (0..<byIdentifier.count)
            .map { byIdentifier.element(boundBy: $0) }
            .first(where: { $0.exists && $0.isEnabled })
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

    /// 퍼펙트 축하가 다음 공의 입력 패드에 잔상으로 붙거나 타석 종료와 함께 잘리지 않는다.
    /// 실제 2.5% 타이밍 창은 유닛 테스트가 지키고, 이 테스트는 Debug 전용 고정 인자로
    /// 피드백의 화면 수명·위치를 결정적으로 검증한다.
    func testPerfectReleaseEffectStaysWithThrownPitch() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestResetCareer",
            "-uiTestPerfectRelease",
            "-baseball.audio.sound", "NO",
        ]
        app.launch()

        dismissOpening(app)
        XCTAssertTrue(completeSetup(app), "고교 시작 화면이 열리지 않았습니다.")

        let openBullpen = app.buttons["hs.prologue.throw"]
        XCTAssertTrue(openBullpen.waitForExistence(timeout: timeout), "첫 불펜 진입 버튼이 없습니다.")
        openBullpen.tap()

        let pad = windUpPad(app)
        XCTAssertTrue(pad.waitForExistence(timeout: timeout), "수동 와인드업 패드가 없습니다.")
        XCTAssertTrue(bringIntoView(pad), "와인드업 패드를 화면에 가져오지 못했습니다.")
        pad.press(forDuration: 0.25)

        let effect = app.descendants(matching: .any)
            .matching(identifier: "pitch.perfectEffect").firstMatch
        XCTAssertTrue(
            effect.waitForExistence(timeout: 0.35),
            "퍼펙트 직후 축하 이펙트가 한 프레임도 나타나지 않았습니다."
        )
        let effectFrame = effect.frame
        XCTAssertGreaterThan(effectFrame.width, 0)
        XCTAssertGreaterThan(effectFrame.height, 0)

        let nextPad = windUpPad(app)
        if nextPad.exists {
            XCTAssertLessThanOrEqual(
                effectFrame.maxY,
                nextPad.frame.minY,
                "퍼펙트 축하가 다음 공의 '길게 눌러 와인드업' 안내와 다시 겹쳤습니다."
            )
        }
        var verifiedTerminalStage = app.buttons["pitch.nextBatter"].exists
            || app.buttons["pitch.finish"].exists
        if verifiedTerminalStage {
            XCTAssertTrue(effect.exists, "타석 종료와 함께 퍼펙트 축하가 잘렸습니다.")
        }

        XCTAssertTrue(
            effect.waitForNonExistence(timeout: 1.2),
            "축하 이펙트가 끝난 뒤 화면에 잔상으로 남았습니다."
        )

        let persistentBadge = app.descendants(matching: .any)
            .matching(identifier: "pitch.perfectRelease").firstMatch
        XCTAssertFalse(
            persistentBadge.exists,
            "결과 장면 구석의 퍼펙트 릴리스 배지는 제거된 상태여야 합니다."
        )

        // 첫 공이 파울·스트라이크라면 강제 퍼펙트를 더 던져 타석 종료/투구 수 상한까지 간다.
        // footer가 nextBatter/finish로 교체되는 바로 그 프레임에도 화면 소유 축하가 살아 있어야 한다.
        var additionalPitches = 0
        while !verifiedTerminalStage, additionalPitches < 7 {
            let currentPad = windUpPad(app)
            guard currentPad.waitForExistence(timeout: 1) else { break }
            XCTAssertTrue(bringIntoView(currentPad), "다음 와인드업 패드를 가져오지 못했습니다.")
            currentPad.press(forDuration: 0.25)

            let terminalEffect = app.descendants(matching: .any)
                .matching(identifier: "pitch.perfectEffect").firstMatch
            XCTAssertTrue(
                terminalEffect.waitForExistence(timeout: 0.35),
                "연속 퍼펙트에서 축하 이펙트가 다시 시작되지 않았습니다."
            )
            verifiedTerminalStage = app.buttons["pitch.nextBatter"].exists
                || app.buttons["pitch.finish"].exists
            if verifiedTerminalStage {
                XCTAssertTrue(
                    terminalEffect.exists,
                    "footer가 종료 상태로 바뀌는 순간 퍼펙트 축하가 함께 제거됐습니다."
                )
            }
            XCTAssertTrue(
                terminalEffect.waitForNonExistence(timeout: 1.2),
                "연속 퍼펙트 축하가 다음 투구까지 잔상으로 남았습니다."
            )
            additionalPitches += 1
        }
        XCTAssertTrue(
            verifiedTerminalStage,
            "퍼펙트 축하의 타석 종료 수명을 검증할 terminal footer에 도달하지 못했습니다."
        )
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
        while !finish.exists, pitches < 120 {
            if usesFastForwardWhenAvailable, fastForward.exists, bringIntoView(fastForward) {
                fastForward.tap()
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
        let finished = finish.waitForNonExistence(timeout: timeout)
        XCTAssertTrue(
            finished,
            "등판 종료를 탭한 뒤에도 투구 화면이 사라지지 않았습니다."
        )
        return finished
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
        let scrollView = app.scrollViews.firstMatch
        guard scrollView.waitForExistence(timeout: 1) else { return false }
        for _ in 0..<attempts {
            scrollView.swipeUp()
            if element.isHittable { return true }
        }
        for _ in 0..<attempts {
            scrollView.swipeDown()
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
        let matches = app.buttons.matching(identifier: "hs.school.confirm")
        guard matches.count > 0 else { return }

        // iOS 26 alert는 같은 identifier를 가진 wrapper/실제 버튼을 함께 노출한다.
        // 바깥 wrapper의 tap이 합성됐지만 alert가 남는 경우가 있어 안쪽 버튼을 먼저 누른다.
        let confirm = matches.element(boundBy: matches.count - 1)
        guard confirm.waitForExistence(timeout: 3) else { return }
        confirm.tap()
        if !confirm.waitForNonExistence(timeout: 2) {
            let retryMatches = app.buttons.matching(identifier: "hs.school.confirm")
            guard retryMatches.count > 0 else { return }
            retryMatches.element(boundBy: retryMatches.count - 1)
                .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .tap()
        }
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

    private func identified(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func failProJourney(_ app: XCUIApplication, _ message: String) {
        capture(app, name: "99-stuck-pro-career")
        XCTFail("\(message) 보이는 버튼: \(visibleIdentifiers(app))")
    }

    private func stopProJourney(_ app: XCUIApplication, _ message: String) -> ProJourneyEvidence? {
        failProJourney(app, message)
        return nil
    }

    /// 막혔을 때 무엇이 보이는지 알려 준다. 진단 없는 실패 메시지는 두 번 일하게 만든다.
    private func visibleIdentifiers(_ app: XCUIApplication) -> String {
        let buttons = app.buttons.allElementsBoundByIndex.prefix(25).map { element -> String in
            let identifier = element.identifier
            return identifier.isEmpty ? "<\(element.label)>" : identifier
        }
        return buttons.joined(separator: ", ")
    }

    private func assertVisibleCopyContainsNoHangul(
        _ app: XCUIApplication,
        context: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let hangul = try! NSRegularExpression(pattern: "[가-힣ㄱ-ㅎㅏ-ㅣ]")
        let labels = app.staticTexts.allElementsBoundByIndex.map(\.label).filter { !$0.isEmpty }
        let contaminated = labels.filter { label in
            hangul.firstMatch(in: label, range: NSRange(label.startIndex..., in: label)) != nil
        }
        XCTAssertTrue(
            contaminated.isEmpty,
            "\(context) contains Korean fallback: \(contaminated.joined(separator: " | "))",
            file: file,
            line: line
        )
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
