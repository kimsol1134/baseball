import XCTest
import SwiftUI
import SimulationCore
@testable import BaseballIOS
import BaseballIOSDomain

/// 승부 장면은 애니메이션 중간이 본체다. 정지 상태만 보면 스윙도 임팩트도 확인할 수 없으므로
/// 진행도를 고정해 프레임을 직접 렌더한다. `BASEBALL_DRAMA_DIR`이 있으면 PNG로도 남긴다.
@MainActor
final class PitchDramaRenderTests: XCTestCase {

    /// 외야 깊숙한 타구. 2컷 카메라가 실제로 무엇을 그리는지 보려면 수비 판정이 필요하다.
    static let deepFly = FieldingResolutionSnapshot(
        neutralOutcome: .homeRun, finalOutcome: .homeRun, sector: .fence,
        difficulty: 900, defenseRating: 55, defenseAdjustment: 0, parkAdjustment: 0,
        impact: .neutral, fielderPosition: .leftField, fielderName: "하민규",
        landingDistanceTenthsMeters: 1_180, hangTimeMilliseconds: 4_200,
        apexHeightTenthsMeters: 320, ballFlightSeries: nil,
        shortExplanation: "좌측 담장을 넘겼습니다."
    )

    private func execution(actualX: Int = 40, actualY: Int = -60) -> PitchExecution {
        // 릴리스에서 홈플레이트까지의 3D 시리즈. 코어가 내보내는 형식과 같다.
        var series: [Int] = []
        for step in 0...24 {
            let t = Double(step) / 24
            series.append(Int(480 * t))
            series.append(Int(-40 + 90 * t * t))
            series.append(Int(18_440 * (1 - t)))
            series.append(Int(1_850 - 780 * t * t))
        }
        return PitchExecution(
            targetX: 0, targetY: 0, actualX: actualX, actualY: actualY,
            velocityTenthsKPH: 1_402, horizontalBreakTenthsCM: 60,
            verticalBreakTenthsCM: 150, executionQuality: 760,
            flightTimeMilliseconds: 480, trajectoryControlX: 0, trajectoryControlY: 0,
            trajectorySeries: series
        )
    }

    private func render(_ view: some View, name: String) -> Bool {
        let renderer = ImageRenderer(content: view.frame(width: 360, height: 320))
        renderer.scale = 3
        guard let image = renderer.uiImage, let data = image.pngData() else { return false }
        XCTAssertGreaterThan(data.count, 2_000, "\(name): 렌더 결과가 비어 있습니다.")
        // 결과 번들에 붙여 눈으로 확인한다. xcodebuild의 환경변수는 테스트 프로세스로 넘어가지 않는다.
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        return true
    }

    /// 헛스윙: 배트가 존을 지나고 흰 섬광이 뜬다.
    func testSwingingStrikeFrames() {
        for progress in [0.30, 0.50, 0.60, 0.72, 1.0] {
            let view = PitchDramaView(
                execution: execution(),
                outcome: .swingingStrike,
                battedBall: nil,
                fielding: nil,
                progress: progress
            )
            XCTAssertTrue(render(view, name: String(format: "swing-%.2f", progress)))
        }
    }

    /// 판정 도장과 실밥(Phase 4 장식). 콜 뒤에 도장이 찍히고, 공이 돌아 보이는지 본다.
    func testCalledStrikeStampAndSeams() {
        for progress in [0.44, 0.50, 0.62, 1.0] {
            let view = PitchDramaView(
                execution: execution(),
                outcome: .calledStrike,
                battedBall: nil,
                fielding: nil,
                progress: progress
            )
            XCTAssertTrue(render(view, name: String(format: "stamp-%.2f", progress)))
        }
    }

    /// 홈런: 임팩트 섬광이 가장 크고 화면이 흔들린다.
    func testHomeRunFrames() {
        let batted = BattedBall(
            exitVelocityTenthsKPH: 1_720,
            launchAngleTenthsDegrees: 280,
            directionTenthsDegrees: -180,
            contactQuality: 940
        )
        for progress in [0.55, 0.62, 0.80, 1.0] {
            let view = PitchDramaView(
                execution: execution(),
                outcome: .homeRun,
                battedBall: batted,
                fielding: Self.deepFly,
                progress: progress
            )
            XCTAssertTrue(render(view, name: String(format: "homerun-%.2f", progress)))
        }
    }

    /// 루킹 스트라이크: 배트가 움직이지 않고 존이 라임으로 밝아진다.
    func testCalledStrikeFrames() {
        for progress in [0.50, 0.70, 1.0] {
            let view = PitchDramaView(
                execution: execution(actualX: 10, actualY: 20),
                outcome: .calledStrike,
                battedBall: nil,
                fielding: nil,
                progress: progress
            )
            XCTAssertTrue(render(view, name: String(format: "called-%.2f", progress)))
        }
    }

    /// 결과를 가리지 않는 한 개의 배합 숙련 배지가 완성 프레임에 남는다.
    func testSequenceMasteryBadgeFrame() {
        let moment = PitchSequenceMoment(
            pitchNumber: 2,
            tag: .eyeLevelChange,
            headline: "눈높이를 바꿨다",
            detail: "높은 코스와 낮은 코스를 이어 타자의 시선을 흔들었습니다."
        )
        let view = PitchDramaView(
            execution: execution(),
            outcome: .swingingStrike,
            battedBall: nil,
            fielding: nil,
            sequenceMoment: moment,
            progress: 1
        )
        XCTAssertTrue(render(view, name: "sequence-mastery"))
    }

    /// 스윙 여부는 코어 판정에서만 나온다. 볼·루킹은 절대 배트가 나가면 안 된다.
    func testBatOnlyMovesWhenTheCoreSaysTheBatterSwung() {
        let silent: [PitchOutcome] = [.ball, .calledStrike, .hitByPitch]
        let swinging: [PitchOutcome] = [.swingingStrike, .foul, .inPlayOut, .single, .double, .triple, .homeRun]
        for outcome in silent + swinging {
            let view = PitchDramaView(
                execution: execution(), outcome: outcome, battedBall: nil, fielding: nil, progress: 0.6
            )
            XCTAssertTrue(render(view, name: "outcome-\(outcome.rawValue)"))
        }
    }
}

/// 손으로 정중앙을 맞힌 공은 장면에서도 다르게 흐른다(4-D).
final class PerfectReleaseTimingTests: XCTestCase {
    /// **퍼펙트는 15% 빨리 도착한다.** 손으로 해낸 일이 화면에서 아무것도 바꾸지 않으면
    /// 그 조작은 그 순간에만 살고 만다.
    func testAPerfectReleaseShortensTheFlight() {
        let ordinary = PitchFeedbackTimeline.replayDuration(isClutch: false, perfectRelease: false)
        let perfect = PitchFeedbackTimeline.replayDuration(isClutch: false, perfectRelease: true)
        XCTAssertEqual(perfect, ordinary * PitchFeedbackTimeline.perfectReleaseFlightScale, accuracy: 0.0001)
        XCTAssertLessThan(perfect, ordinary)
    }

    /// 승부구 배율과 함께 걸린다. 둘 다 곱해져야 승부구도 퍼펙트도 각자 읽힌다.
    func testTheClutchTempoAndThePerfectScaleBothApply() {
        let clutchPerfect = PitchFeedbackTimeline.replayDuration(isClutch: true, perfectRelease: true)
        let clutchOrdinary = PitchFeedbackTimeline.replayDuration(isClutch: true, perfectRelease: false)
        XCTAssertLessThan(clutchPerfect, clutchOrdinary)
        XCTAssertGreaterThan(clutchPerfect, PitchFeedbackTimeline.replayDuration(isClutch: false, perfectRelease: true))
    }

    /// 퍼펙트면 삼진 콜이 앞선다 — 심판이 먼저 알아본 것처럼 들린다.
    func testAPerfectReleasePullsTheStrikeoutCallForward() {
        let ordinary = PitchFeedbackTimeline.callDelay(contactDelay: 1.32, perfectRelease: false)
        let perfect = PitchFeedbackTimeline.callDelay(contactDelay: 1.32, perfectRelease: true)
        XCTAssertEqual(ordinary, 1.32, accuracy: 0.0001)
        XCTAssertEqual(perfect, 1.32 - PitchFeedbackTimeline.perfectReleaseCallLead, accuracy: 0.0001)
    }

    /// **콜이 공보다 빨라질 수는 없다.** 앞당김이 포구 시각을 넘으면 0에서 자른다.
    func testTheCallNeverArrivesBeforeTheBall() {
        XCTAssertEqual(
            PitchFeedbackTimeline.callDelay(contactDelay: 0.1, perfectRelease: true),
            0,
            accuracy: 0.0001
        )
    }
}

/// 새로 만든 화면을 눈으로 확인하기 위한 렌더. 결과 번들에 붙고,
/// `BASEBALL_SHOT_DIR`이 있으면 PNG로도 남는다.
@MainActor
final class NewSurfaceRenderTests: XCTestCase {
    private func save(_ view: some View, name: String, width: CGFloat = 360, height: CGFloat? = nil) {
        let sized = height.map { AnyView(view.frame(width: width, height: $0)) }
            ?? AnyView(view.frame(width: width))
        let renderer = ImageRenderer(
            content: sized
                .padding(12)
                .background(BaseballTheme.canvas)
                .environment(\.gameCopyResolver, GameCopyResolver(language: .korean))
        )
        renderer.scale = 3
        guard let image = renderer.uiImage, let data = image.pngData() else {
            XCTFail("\(name): 렌더 실패")
            return
        }
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["BASEBALL_SHOT_DIR"] {
            try? data.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
    }

    /// 화면 전체를 그대로 찍는다.
    ///
    /// `ImageRenderer`는 `ScrollView` 본문을 그리지 못한다 — 스크롤이 바깥에 있는 화면은
    /// 캔버스가 비고 `safeAreaInset` 바만 남는다. 진짜 창에 올린 `UIHostingController`를
    /// 찍으면 스크롤도 레이아웃을 받는다. 스크롤 안쪽까지 보려면 `height`를 화면보다
    /// 크게 준다(뷰가 그만큼 세로로 펼쳐진다).
    private func saveScreen(
        _ view: some View,
        name: String,
        width: CGFloat = 390,
        height: CGFloat = 844
    ) {
        let host = UIHostingController(
            rootView: AnyView(
                view
                    .environment(\.gameCopyResolver, GameCopyResolver(language: .korean))
                    .frame(width: width, height: height)
                    .background(BaseballTheme.canvas)
            )
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: height))
        window.rootViewController = host
        window.isHidden = false
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        // 한 번의 레이아웃으로는 스크롤 내용이 비는 경우가 있다. 런루프를 한 바퀴 돌린다.
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 3
        // `drawHierarchy(afterScreenUpdates:)`는 실제 화면이 없는 유닛 테스트에서 흰 판을
        // 준다. 레이어를 직접 그린다.
        let data = UIGraphicsImageRenderer(bounds: window.bounds, format: format).pngData { context in
            window.layer.render(in: context.cgContext)
        }
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["BASEBALL_SHOT_DIR"] {
            try? data.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
        window.isHidden = true
    }

    private func history() -> [AbilityHistoryPoint] {
        [
            .init(season: 1, stuff: 42, command: 41, movement: 36, stamina: 39),
            .init(season: 2, stuff: 44, command: 50, movement: 36, stamina: 41),
            .init(season: 4, stuff: 48, command: 64, movement: 36, stamina: 46),
            .init(season: 7, stuff: 54, command: 77, movement: 35, stamina: 52),
            .init(season: 10, stuff: 61, command: 80, movement: 31, stamina: 61),
            .init(season: 13, stuff: 63, command: 80, movement: 27, stamina: 67),
        ]
    }

    func testAbilityGrowthGraph() {
        save(AbilityGrowthGraph(points: history()), name: "01-ability-growth-graph", height: 215)
    }

    func testAbilityBars() {
        let pitcher = PitcherSnapshot(id: "p", name: "t", stuff: 63, command: 80, movement: 27, stamina: 67)
        save(
            ProAbilityPanel(pitcher: pitcher, previous: history().first),
            name: "07-ability-bars"
        )
    }

    /// 프로 대화. 얼굴·역할·풀카드·커널이 계산한 칩이 한 장에 들어오는지 눈으로 본다.
    func testProConversation() throws {
        let store = MobileCareerStore(saveWriter: { _ in true }, configuration: .production)
        XCTAssertTrue(
            store.installLiveSeasonDecisionFixtureForUITesting(),
            String(describing: store.loadState)
        )
        let decision = try XCTUnwrap(store.state?.pendingDecision)
        save(
            ProSeasonDecisionView(career: store, decision: decision),
            name: "08-pro-conversation"
        )
    }

    /// 확정 뒤 같은 무대에 남는 결과.
    func testProConversationResult() throws {
        let store = MobileCareerStore(saveWriter: { _ in true }, configuration: .production)
        XCTAssertTrue(
            store.installLiveSeasonDecisionFixtureForUITesting(),
            String(describing: store.loadState)
        )
        let decision = try XCTUnwrap(store.state?.pendingDecision)
        store.applySeasonDecision(decisionID: decision.id, choiceID: decision.choices[0].id)
        XCTAssertNil(store.state?.pendingDecision, "확정이 실제로 적용돼야 결과가 남는다")
        let receipt = try XCTUnwrap(store.lastSeasonDecisionReceipt)
        save(
            ProSeasonDecisionResultView(career: store, receipt: receipt),
            name: "09-pro-conversation-result"
        )
    }

    /// 신인 계약. 카드를 고르는 일과 서명하는 일이 갈라져 있고, 확인이 모달이 아니라
    /// 같은 화면 아래에 열리는지 눈으로 본다(6-D).
    func testContractOfferConfirmStaysOnTheScreen() throws {
        let preset = PitcherPresetCatalog.all[0]
        let engine = ProCareerEngine(journeyEnabled: true)
        let started = try CareerBootstrap.startCareer(
            preset: preset,
            playerName: "민서준",
            seed: 20_260_903,
            startingRepertoire: PitchLearningRules.recommendedSelection(presetID: preset.id),
            engine: engine
        )
        XCTAssertEqual(started.snapshot.phase, .contractOffer)
        let store = MobileCareerStore(saveWriter: { _ in true }, configuration: .production)
        XCTAssertTrue(store.installLiveSeasonDecisionFixtureForUITesting())
        let market = try XCTUnwrap(started.snapshot.journeyState?.pendingContractMarket)
        let offer = try XCTUnwrap(market.offers.first)
        saveScreen(
            ProContractOfferView(career: store, state: started.snapshot),
            name: "11-contract-offer"
        )
        saveScreen(
            ProContractOfferView(
                career: store,
                state: started.snapshot,
                initialSelection: (offerID: offer.id, ambition: .franchiseIcon)
            ),
            name: "12-contract-offer-confirm"
        )

    }

    /// 다음 회차의 세 갈래. 고르는 일과 시작하는 일이 갈라져 있는지 눈으로 본다(6-E).
    func testRebirthPathPicker() throws {
        let store = HighSchoolCareerStore(saveWriter: { _ in true })
        XCTAssertTrue(store.installUndraftedDraftFixtureForUITesting())
        store.updatePersisted {
            $0.signatureLegacyRulesVersion = HighSchoolCareerStore.currentSignatureLegacyRulesVersion
        }
        store.lastSetup = .init(
            presetID: "precision_commander", playerName: "민서준", region: "서울",
            harshness: "standard", karmas: [], soulDomain: nil,
            startingRepertoire: PitchLearningRules.recommendedSelection(presetID: "precision_commander"),
            throwingHand: .right
        )
        store.resolveDraft()
        let legacyState = try XCTUnwrap(store.state)
        XCTAssertEqual(legacyState.phase, .legacy)
        XCTAssertTrue(store.prepareSignatureLegacyCandidates())
        if let legacy = store.signatureLegacyCandidates(for: legacyState).first {
            store.selectSignatureLegacy(legacy.id)
        }
        store.confirmLegacy()
        let completed = try XCTUnwrap(store.state)
        XCTAssertEqual(completed.phase, .completed)
        XCTAssertTrue(store.canChooseRebirthPath, "길 고르기가 열려야 이 검사가 의미 있다")
        saveScreen(
            ScrollView {
                CompletionCard(
                    career: store,
                    state: completed,
                    hasEnteredPro: false,
                    onEnterPro: { _, _, _ in },
                    includeReason: false,
                    onRebirth: {},
                    onRebirthPath: { _ in }
                )
                .padding(BaseballMetrics.gutter)
            }
            .background(BaseballTheme.canvas),
            name: "14-rebirth-path",
            height: 1_600
        )
    }

    /// 드래프트 직후 "3년의 결과". 지명 구단이 먼저 오고, 여정의 숫자가 따라오는지 본다(6-C).
    func testDraftJourneySummary() throws {
        let engine = HighSchoolCareerEngine()
        var result = try engine.start(.init(
            seed: "20260903",
            presetID: "power_prospect",
            creationAllocation: .balanced,
            identity: PlayerIdentitySnapshot(
                name: "민서준", throwingHand: .right, bodyType: .balanced, region: "서울"
            )
        ))
        let start = result.snapshot.pitcher
        result = try engine.completePrologue(.init(seed: result.nextSeed, state: result.snapshot))
        result = try engine.chooseSchool(.init(
            seed: result.nextSeed, state: result.snapshot, schoolID: .haedongPower
        ))
        for _ in 0..<400 {
            if result.snapshot.phase == .draft { break }
            switch result.snapshot.phase {
            case .training:
                result = try engine.commitTraining(.init(
                    seed: result.nextSeed, state: result.snapshot,
                    focus: .command, intensity: .standard
                ))
            case .relationship:
                result = try engine.resolveRelationship(.init(
                    seed: result.nextSeed, state: result.snapshot, response: .listen
                ))
            case .importantGame:
                result = try engine.recordImportantGame(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    report: .init(
                        scenarioNumber: result.snapshot.performance.importantGamesCompleted + 1,
                        pitches: 84, strikeouts: 7, walks: 1, runsAllowed: 1,
                        expectedDamage: 1_100, actualDamage: 700, recommendationAccepted: 48,
                        outs: 18, hits: 4
                    )
                ))
            case .awakening:
                let choice = try XCTUnwrap(result.snapshot.awakeningOptions.first)
                result = try engine.chooseAwakening(.init(
                    seed: result.nextSeed, state: result.snapshot, awakening: choice
                ))
            case .chapterReview:
                result = try engine.advanceChapter(.init(seed: result.nextSeed, state: result.snapshot))
            default:
                XCTFail("드래프트 전에 예상 밖 국면: \(result.snapshot.phase.rawValue)")
                return
            }
        }
        XCTAssertEqual(result.snapshot.phase, .draft)
        result = try engine.resolveDraft(.init(seed: result.nextSeed, state: result.snapshot))
        let drafted = try XCTUnwrap(result.snapshot.draftResult)
        saveScreen(
            ScrollView {
                DraftPeakResultView(
                    state: result.snapshot,
                    drafted: drafted.outcome == .drafted,
                    startingPitcher: start,
                    onContinue: {}
                )
                .padding(BaseballMetrics.gutter)
            }
            .background(BaseballTheme.canvas),
            name: "13-draft-journey"
        )
    }

    /// 고교 관계 카드. 프로와 같은 관용구를 쓰는지 나란히 놓고 본다.
    func testHighSchoolConversation() throws {
        let engine = HighSchoolCareerEngine()
        var result = try engine.start(.init(
            seed: "20260903",
            presetID: "power_prospect",
            creationAllocation: .balanced,
            identity: PlayerIdentitySnapshot(
                name: "민서준", throwingHand: .right, bodyType: .balanced, region: "서울"
            )
        ))
        result = try engine.completePrologue(.init(seed: result.nextSeed, state: result.snapshot))
        result = try engine.chooseSchool(.init(
            seed: result.nextSeed, state: result.snapshot, schoolID: .haedongPower
        ))
        // 관계 사건은 훈련 사이에 끼어든다. 각성·경기 국면을 지나쳐야 도달한다.
        for _ in 0..<24 {
            if result.snapshot.phase == .relationship { break }
            switch result.snapshot.phase {
            case .training:
                result = try engine.commitTraining(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    focus: .command,
                    intensity: .standard
                ))
            case .awakening:
                let choice = try XCTUnwrap(result.snapshot.awakeningOptions.first)
                result = try engine.chooseAwakening(.init(
                    seed: result.nextSeed, state: result.snapshot, awakening: choice
                ))
            case .importantGame:
                result = try engine.recordImportantGame(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    report: .init(
                        scenarioNumber: 1, pitches: 18, strikeouts: 2, walks: 0, runsAllowed: 0,
                        expectedDamage: 380, actualDamage: 240, recommendationAccepted: 12
                    )
                ))
            case .chapterReview:
                result = try engine.advanceChapter(.init(seed: result.nextSeed, state: result.snapshot))
            default:
                XCTFail("관계 사건 전에 예상 밖 국면: \(result.snapshot.phase.rawValue)")
                return
            }
        }
        XCTAssertEqual(result.snapshot.phase, .relationship)
        save(
            RelationshipCard(state: result.snapshot, onRespond: { _ in }),
            name: "10-high-school-conversation"
        )
    }
}
