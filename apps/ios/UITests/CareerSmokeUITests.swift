import XCTest

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

    private func launch(pitchAbilityFeedback: Bool = false) -> XCUIApplication {
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
                if !tapIfPresent(app.buttons["hs.training.commitBlock"]) {
                    tapIfPresent(app.buttons["hs.training.commit"])
                }
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

    /// 드래프트를 통과했다면 프로 커리어가 그 결과로 열려야 한다.
    func testDraftedRunCanEnterProCareer() {
        let app = launch()
        dismissOpening(app)
        // **이 테스트가 지키는 것은 지명 확률이 아니라 전환 흐름이다** — 지명을 받은 회차가
        // 프로 커리어를 열고, 그때 탭 선택 대상이 교체되며, 프로 첫 주부터 은퇴까지 화면이
        // 이어지는가.
        //
        // 예전에는 "표준 난이도에서 지명되는 고정 시드" 하나에 기대고 있었다. 그래서 밸런스를
        // 만질 때마다 이 테스트가 깨졌고, 그때마다 190초짜리 실행으로 새 시드를 찾아야 했다 —
        // 실제로 당락선을 올린 뒤에는 후보 아홉 개가 연속으로 미지명이었다. 검증 대상과
        // 무관한 추첨에 회귀 테스트를 매달아 둔 셈이다.
        //
        // 완화 난이도로 시작한다. 당락선이 낮아 자동 진행도 대개 지명을 받으므로 흐름이
        // 안정적으로 검증되고, 표준 난이도의 밸런스를 어떻게 조정하든 이 테스트는 흔들리지
        // 않는다. 난이도별 지명률 자체는 `RealPlayDraftRateTests`가 따로 잰다.
        XCTAssertTrue(
            completeSetup(app, seed: "11", harshness: "relaxed"),
            "고교 시작 화면이 열리지 않았습니다."
        )

        var steps = 0
        var usedFastForwardDuringRun = false
        while steps < maximumSteps {
            steps += 1
            if tapIfPresent(app.buttons["hs.draft.reveal.done"]) { continue }
            if app.buttons["hs.recap.continue"].exists {
                capture(app, name: "99-undrafted-recap")
                XCTFail("완화 난이도의 고정 시드가 미지명 정산으로 들어갔습니다 — 시드나 난이도 축을 다시 보정해야 합니다.")
                return
            }
            if app.buttons["hs.enterPro"].exists {
                XCTAssertTrue(usedFastForwardDuringRun)
                tapIfPresent(app.buttons["hs.enterPro"])
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
                return
            }
            if app.buttons["hs.rebirth"].exists {
                capture(app, name: "99-undrafted")
                XCTFail("완화 난이도의 고정 시드가 미지명으로 끝났습니다 — 시드나 난이도 축을 다시 보정해야 합니다.")
                return
            }

            if tapIfPresent(app.buttons["hs.prologue.continue"]) { continue }
            if tapFirst(app, prefix: "hs.school.") { confirmSchool(app); continue }
            if tapIfPresent(app.buttons["hs.training.commitBlock"])
                || tapIfPresent(app.buttons["hs.training.commit"]) { continue }
            if tapFirst(app, prefix: "hs.response.") { continue }
            if tapFirst(app, prefix: "hs.awakening.") { confirmAwakening(app); continue }
            if tapIfPresent(app.buttons["hs.chapter.continue"]) { continue }
            if app.buttons["hs.game.start"].exists {
                tapIfPresent(app.buttons["hs.game.start"])
                usedFastForwardDuringRun = playInning(
                    app, capturePitchResult: false, usesFastForwardWhenAvailable: true
                ) || usedFastForwardDuringRun
                continue
            }
            if tapIfPresent(app.buttons["hs.draft.resolve"]) { continue }
            if app.buttons["hs.legacy.confirm"].exists {
                selectRequiredLegacy(app)
                XCTAssertTrue(tapIfPresent(app.buttons["hs.legacy.confirm"]))
                let closeLife = app.buttons["확정하고 이 선수의 이야기를 닫는다"]
                XCTAssertTrue(closeLife.waitForExistence(timeout: timeout))
                closeLife.tap()
                continue
            }
            capture(app, name: "99-stuck-pro")
            XCTFail("진행 가능한 조작을 찾지 못했습니다. 보이는 버튼: \(visibleIdentifiers(app))")
            return
        }
        XCTFail("회차가 끝나지 않았습니다.")
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

    /// 이번 제품 빌드의 행동 가설은 '다음 행동 복귀' 하나다. 투구 수치 패널은 별도
    /// 실험에서만 켜야 복귀 효과와 손맛 효과를 서로의 성과로 오인하지 않는다.
    func testPitchAbilityFeedbackIsHiddenWithoutItsDedicatedExperimentFlag() {
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
        XCTAssertFalse(
            app.descendants(matching: .any)
                .matching(identifier: "pitch.buildReadout").firstMatch.exists,
            "복귀 실험 빌드에 투구 피드백 실험이 함께 노출됐습니다."
        )
        XCTAssertFalse(
            app.staticTexts["구종 · 내가 만든 공"].exists,
            "숨긴 실험의 인과 문구가 카드 제목으로 남아 있습니다."
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
        if stamp.waitForExistence(timeout: 4) {
            capture(app, name: "09-rebirth")
            _ = stamp.waitForNonExistence(timeout: timeout)
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
