import XCTest
@testable import SimulationCore

/// 기질 특성 — nil이면 판정이 완전히 같아야 하고(픽스처 보장), 발동 조건은
/// 커널이 이미 아는 값만 써야 한다.
final class PersonalityTraitTests: XCTestCase {
    private func context(strikes: Int = 0, pitchNumber: Int = 2) -> PlateAppearanceContext {
        PlateAppearanceContext(
            plateAppearanceID: "pa", revision: 1, inning: 1, outs: 0, balls: 0,
            strikes: strikes, pitchNumber: pitchNumber, scoreDifferential: 0,
            leverage: 500, fatigue: 10
        )
    }

    func testActivationConditions() {
        XCTAssertTrue(PersonalityTrait.closer.fires(context: context(strikes: 2), runners: nil))
        XCTAssertFalse(PersonalityTrait.closer.fires(context: context(strikes: 1), runners: nil))
        XCTAssertTrue(PersonalityTrait.tactician.fires(context: context(pitchNumber: 5), runners: nil))
        XCTAssertFalse(PersonalityTrait.tactician.fires(context: context(pitchNumber: 4), runners: nil))
        XCTAssertTrue(PersonalityTrait.opener.fires(context: context(pitchNumber: 1), runners: nil))
        let loaded = BaserunnerStateSnapshot(firstOccupied: true, secondOccupied: false, thirdOccupied: false, leadRunnerSpeed: 50)
        let empty = BaserunnerStateSnapshot(firstOccupied: false, secondOccupied: false, thirdOccupied: false, leadRunnerSpeed: 0)
        XCTAssertTrue(PersonalityTrait.anchor.fires(context: context(), runners: loaded))
        XCTAssertFalse(PersonalityTrait.anchor.fires(context: context(), runners: empty))
        XCTAssertFalse(PersonalityTrait.anchor.fires(context: context(), runners: nil))
    }

    /// 보정은 전부 투수 유리(음수) — 특성은 내 선수의 무기이지 함정이 아니다.
    /// 크기는 스카우팅 보정(−30·−36)보다 작아야 한다. 특성은 정체성이지 필살기가 아니다.
    func testAdjustmentsAreModestAndPitcherFavoring() {
        for trait in PersonalityTrait.allCases {
            XCTAssertLessThan(trait.contactAdjustment, 0)
            XCTAssertLessThan(trait.qualityAdjustment, 0)
            XCTAssertGreaterThanOrEqual(trait.contactAdjustment, -20)
            XCTAssertGreaterThanOrEqual(trait.qualityAdjustment, -20)
            XCTAssertFalse(trait.title.isEmpty)
            XCTAssertFalse(trait.activationLine.isEmpty)
        }
    }

    /// 모든 성격은 특성 하나를 가진다 — 성격이 장식이 아니라 메커니즘이라는 보장.
    func testEveryPersonalityCarriesATrait() {
        let personalities = [
            PersonalityRules.personality(listen: 5, explain: 0, challenge: 0),
            PersonalityRules.personality(listen: 0, explain: 5, challenge: 0),
            PersonalityRules.personality(listen: 0, explain: 0, challenge: 5),
            PersonalityRules.personality(listen: 2, explain: 2, challenge: 2),
        ]
        XCTAssertEqual(Set(personalities.compactMap { $0?.trait }), Set(PersonalityTrait.allCases))
    }
}
