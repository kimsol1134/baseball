import XCTest
import SimulationCore
@testable import BaseballIOS

/// 성장 게이지 표시 회귀. 옛 빌드가 "현재 %lld/2"로 분모를 하드코딩해 2/2·3/2가 보였고
/// (2026-08-31 사용자 제보), 노장 하락으로 밴드가 내려가면 두-인자 문구에서도 저장된
/// 게이지가 새 분모를 넘을 수 있다. 표시는 항상 분모 이하로 클램프한다.
@MainActor
final class ProWeeklyPlanProgressTests: XCTestCase {
    private let resolver = GameCopyResolver(
        language: .korean,
        catalog: [.korean: ["pro.weekly.progress": "현재 %lld/%lld"]]
    )

    func testProgressTextClampsStaleGaugeToLiveThreshold() throws {
        // 능력 55~64 시절 쌓인 게이지 3이 하락으로 54(임계 2)가 된 스냅숏.
        let state = try snapshot(movement: 54, movementGauge: 3)
        let text = WeeklyPlanView.progressText(.developMovement, state: state, resolver: resolver)
        XCTAssertEqual(text, "현재 2/2")
    }

    func testProgressTextShowsLiveBandThresholdWithoutClampInNormalRange() throws {
        let state = try snapshot(movement: 56, movementGauge: 2)
        let text = WeeklyPlanView.progressText(.developMovement, state: state, resolver: resolver)
        XCTAssertEqual(text, "현재 2/3")
    }

    /// 엔진 픽스처에서 시작해 표시 계산에 필요한 필드만 JSON으로 바꾼다.
    private func snapshot(movement: Int, movementGauge: Int) throws -> ProCareerSnapshot {
        let result = try ProCareerEngine().start(.init(
            seed: "20260831",
            identity: .defaultPitcher,
            pitcher: .init(
                id: "weekly-progress-fixture",
                name: "게이지 픽스처",
                stuff: 58,
                command: 55,
                movement: 56,
                stamina: 57
            ),
            draftResult: .init(
                outcome: .drafted,
                evaluationScore: 72,
                projectedRange: "2~3",
                team: ProCareerEngine.proTeams[0],
                round: 2,
                overallPick: 18,
                signingBonus: 120_000_000,
                firstSeasonGoal: nil,
                summary: "fixture"
            ),
            entitlement: .init(status: .active, source: .development, verifiedAt: "2026-08-31")
        ))
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(result.snapshot)) as? [String: Any]
        )
        var pitcher = try XCTUnwrap(object["pitcher"] as? [String: Any])
        pitcher["movement"] = movement
        object["pitcher"] = pitcher
        object["developmentProgress"] = [
            "stuff": 0, "command": 0, "movement": movementGauge, "stamina": 0,
        ]
        object["proRulesVersion"] = 4
        return try JSONDecoder().decode(
            ProCareerSnapshot.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
    }
}
