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
