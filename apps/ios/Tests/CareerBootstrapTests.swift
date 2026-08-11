import XCTest
import SimulationCore
@testable import BaseballIOS

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
}
