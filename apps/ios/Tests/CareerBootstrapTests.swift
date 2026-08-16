import XCTest
import SimulationCore
@testable import BaseballIOS

private final class CareerBootstrapMemoryRemoteStore: SaveSyncRemoteStoring {
    private var values: [String: Data] = [:]

    func data(forKey key: String) -> Data? { values[key] }
    func set(_ value: Any?, forKey key: String) { values[key] = value as? Data }
    func removeObject(forKey key: String) { values.removeValue(forKey: key) }
    @discardableResult func synchronize() -> Bool { true }
}

/// 유료앱 권한 모델과 새 커리어 생성 경로를 지킨다.
final class CareerBootstrapTests: XCTestCase {
    private var preset: PitcherPresetSnapshot {
        PitcherPresetCatalog.all[0]
    }

    /// 앱 구매 자체가 권한이므로 디버그·릴리스 구분 없이 활성 권한이 나와야 한다.
    func testPaidAppEntitlementIsActivePurchase() {
        let entitlement = AppEntitlement.paidApp()
        XCTAssertEqual(entitlement.status, .active)
        XCTAssertEqual(entitlement.source, .purchase)
        XCTAssertNotEqual(entitlement.source, .development)
    }

    /// 릴리스 빌드에서 커리어가 열리지 않던 결함(계획 문서 D1)의 회귀 방지.
    func testStartCareerProducesPlayableFirstWeek() throws {
        let result = try CareerBootstrap.startCareer(preset: preset, playerName: "테스트", seed: 20_260_725)
        XCTAssertEqual(result.snapshot.phase, .weeklyPlan)
        XCTAssertEqual(result.snapshot.entitlement.status, .active)
        XCTAssertNotNil(result.snapshot.contract)
        XCTAssertEqual(result.snapshot.identity.name, "테스트")
        XCTAssertEqual(result.snapshot.pitcher.name, "테스트")
    }

    /// Wave 0 characterization: the linked iOS bootstrap still signs the rookie contract
    /// before it exposes week one. This deliberately records the legacy path; it does not
    /// change the product flow.
    func testWave0RookieStartAutomaticallySignsBeforeWeekOne() throws {
        let result = try CareerBootstrap.startCareer(preset: preset, playerName: "웨이브0투수", seed: 20_260_814)
        XCTAssertEqual(result.snapshot.phase, .weeklyPlan)
        XCTAssertEqual(result.snapshot.week, 0)
        XCTAssertEqual(result.snapshot.contract?.yearsRemaining, 3)
        XCTAssertTrue(result.events.contains("rookie_contract_signed"))
    }

    func testStartCareerIsDeterministicForTheSameSeed() throws {
        let first = try CareerBootstrap.startCareer(preset: preset, playerName: "민서준", seed: 777)
        let second = try CareerBootstrap.startCareer(preset: preset, playerName: "민서준", seed: 777)
        XCTAssertEqual(first.snapshot.team.id, second.snapshot.team.id)
        XCTAssertEqual(first.snapshot.proCareerID, second.snapshot.proCareerID)
        XCTAssertEqual(first.nextSeed, second.nextSeed)
    }

    func testBlankNameFallsBackToThePresetName() throws {
        let result = try CareerBootstrap.startCareer(preset: preset, playerName: "   ", seed: 42)
        XCTAssertEqual(result.snapshot.identity.name, preset.pitcher.name)
    }

    /// 지명 라운드는 1~4에 머물러야 프로 커리어 초반 서사(2군 시작)와 어긋나지 않는다.
    func testDraftRoundStaysWithinTheNarrativeRange() {
        for preset in PitcherPresetCatalog.all {
            for seed in stride(from: UInt64(1), through: 400, by: 7) {
                let draft = CareerBootstrap.draftResult(preset: preset, seed: seed)
                XCTAssertEqual(draft.outcome, .drafted)
                let round = try? XCTUnwrap(draft.round)
                XCTAssertNotNil(round)
                XCTAssertTrue((1...4).contains(round ?? 0), "round \(round ?? -1) out of range")
                XCTAssertNotNil(draft.team)
            }
        }
    }

    /// 프리셋 능력은 코어가 요구하는 20~80 범위 안이어야 투구 시뮬레이션이 검증을 통과한다.
    func testEveryPresetIsValidForThePitchKernel() {
        for preset in PitcherPresetCatalog.all {
            for value in [preset.pitcher.stuff, preset.pitcher.command, preset.pitcher.movement, preset.pitcher.stamina] {
                XCTAssertTrue((20...80).contains(value), "\(preset.id) rating \(value) out of range")
            }
        }
    }

    @MainActor
    func testDraftedUITestFixtureStartsAtCompletedDraftedState() {
        let store = HighSchoolCareerStore(saveWriter: { _ in true })

        XCTAssertTrue(store.installDraftedCareerFixtureForUITesting())
        XCTAssertEqual(store.state?.phase, .completed)
        XCTAssertEqual(store.state?.draftResult?.outcome, .drafted)
        XCTAssertNotNil(store.state?.draftResult?.team)
        XCTAssertFalse(store.hasEnteredPro)
    }

    /// Wave 0 characterization: store review persists only the existing core review result;
    /// there is no salary, fan-support, or team-legacy settlement object yet.
    @MainActor
    func testWave0SeasonReviewStoreHasNoSalaryFanOrTeamLegacySettlement() throws {
        let review = try seasonReviewFixture()
        let contractBefore = review.snapshot.contract
        let sync = SaveSync(
            key: "career-bootstrap-wave0-\(UUID().uuidString).json",
            store: CareerBootstrapMemoryRemoteStore()
        )
        sync.clear()
        defer { sync.clear() }
        let store = MobileCareerStore(sync: sync, saveWriter: { _ in true })
        store.result = review

        store.reviewSeason()

        let state = try XCTUnwrap(store.state)
        XCTAssertEqual(store.result?.events, ["pro_season_reviewed"])
        XCTAssertEqual(store.lastSummary, "시즌 기록을 통산 기록에 확정했습니다.")
        XCTAssertEqual(state.contract, contractBefore)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any]
        )
        for key in ["salarySettlement", "fanSupport", "teamLegacy", "teamRecords", "settlement"] {
            XCTAssertNil(object[key], "legacy season-review JSON unexpectedly contains \(key)")
        }
    }

    /// Wave 0 characterization: the season-review branch is still a single generic action card,
    /// so no salary/fan/team-legacy settlement is exposed by the current UI.
    func testWave0SeasonReviewUIIsTheCurrentPlainActionCard() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/CareerFlowView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let start = try XCTUnwrap(source.range(of: "case .seasonReview:"))
        let remainder = source[start.upperBound...]
        let end = try XCTUnwrap(remainder.range(of: "case .offseasonDecision:"))
        let branch = String(remainder[..<end.lowerBound])

        XCTAssertTrue(branch.contains("ActionCard("))
        XCTAssertTrue(branch.contains("career.reviewSeason"))
        for token in ["salary", "fanSupport", "teamLegacy", "teamRecords", "settlement"] {
            XCTAssertFalse(branch.contains(token), "season-review UI unexpectedly contains \(token)")
        }
    }

    private func seasonReviewFixture() throws -> ProCareerResult {
        let engine = ProCareerEngine()
        var result = try CareerBootstrap.startCareer(
            preset: preset,
            playerName: "웨이브0투수",
            seed: 20_260_815,
            engine: engine
        )
        var steps = 0
        while result.snapshot.phase != .seasonReview {
            steps += 1
            guard steps <= 160 else {
                throw SimulationError.invalidProCareer("Wave 0 season-review fixture exceeded its step bound")
            }
            switch result.snapshot.phase {
            case .weeklyPlan:
                let plan: ProWeekPlan = result.snapshot.fatigue > 72
                    ? .recover
                    : result.snapshot.managerTrust < 62 ? .earnTrust : .refineCommand
                result = try engine.planWeek(.init(seed: result.nextSeed, state: result.snapshot, plan: plan))
            case .importantGame:
                result = try engine.resolveImportantGame(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    report: .init(
                        scenarioNumber: result.snapshot.week,
                        pitches: 18,
                        strikeouts: 2,
                        walks: 0,
                        runsAllowed: 0,
                        expectedDamage: 380,
                        actualDamage: 240,
                        recommendationAccepted: 12
                    )
                ))
            case .seasonDecision:
                guard let decision = result.snapshot.pendingDecision,
                      let choice = decision.choices.min(by: {
                          if $0.effect.fatigueDelta != $1.effect.fatigueDelta {
                              return $0.effect.fatigueDelta < $1.effect.fatigueDelta
                          }
                          return $0.id < $1.id
                      }) else {
                    throw SimulationError.invalidProCareer("Wave 0 season-review fixture has no decision choice")
                }
                result = try engine.applySeasonDecision(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    decisionID: decision.id,
                    choiceID: choice.id
                ))
            default:
                throw SimulationError.invalidProCareer("Wave 0 season-review fixture entered \(result.snapshot.phase.rawValue)")
            }
        }
        return result
    }
}
