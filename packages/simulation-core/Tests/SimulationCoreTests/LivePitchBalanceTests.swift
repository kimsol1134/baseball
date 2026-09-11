import XCTest
@testable import SimulationCore

/// 직접 던지는 공이 어느 확률식을 쓰는가 — **기본 인자가 아니라 버전이 정한다**(§2.5).
///
/// 앱이 `PitchKernelEngine`을 기본 인자로 만들어 `.legacy`가 조용히 들어갔고, 그래서 고교 7과
/// 프로 11~13의 재조정은 자동 등판에만 적용돼 왔다. 여기 검사들은 두 가지를 지킨다:
/// 지금 배포 중인 버전은 한 줄도 바뀌지 않는다는 것, 그리고 **누군가 연결하려 하면 반드시
/// 측정을 거치게 되는 것**.
final class LivePitchBalanceTests: XCTestCase {
    /// 오늘 배포되는 고교·프로 커리어는 예전과 같은 확률식으로 던진다.
    func testEveryShippedVersionStillThrowsOnTheLegacyCurve() {
        for version in 1...HighSchoolGameplayRules.current {
            XCTAssertEqual(
                HighSchoolGameplayRules.livePitchBalance(version).arena, .legacy,
                "고교 v\(version)"
            )
        }
        for version in 1...ProGameplayRules.current {
            XCTAssertEqual(
                ProGameplayRules.livePitchBalance(version).arena, .legacy,
                "프로 v\(version)"
            )
        }
        // 버전이 없던 저장본도 마찬가지다.
        XCTAssertEqual(HighSchoolGameplayRules.livePitchBalance(nil).arena, .legacy)
        XCTAssertEqual(ProGameplayRules.livePitchBalance(nil).arena, .legacy)
    }

    /// 연결은 다음 버전에서만 열린다.
    func testTheConnectionOpensOnlyOnTheNextVersion() {
        XCTAssertEqual(HighSchoolGameplayRules.livePitchBalance(8).arena, .school)
        XCTAssertEqual(ProGameplayRules.livePitchBalance(14).arena, .professional)
    }

    /// **측정 없이 버전을 올리지 못하게 하는 선.**
    ///
    /// `current`를 올리는 순간 이 검사가 깨진다. 깨졌다면 계획 문서 §2.5의 측정을 마치고
    /// 기준선(중립 릴리스 지명률 43%)과 비교한 결과를 근거로 이 검사를 함께 고쳐야 한다.
    /// 그냥 숫자만 맞춰 통과시키는 것은 이 검사가 막으려는 바로 그 일이다.
    func testConnectingTheLiveCurveRequiresTheMeasurement() {
        XCTAssertEqual(
            HighSchoolGameplayRules.current, 7,
            "고교 current를 올렸다면 §2.5 측정을 마쳤는지 확인하라 — 라이브 곡선 연결은 "
                + "중립 릴리스 지명률을 43%에서 5%로 떨어뜨린다"
        )
        XCTAssertEqual(
            ProGameplayRules.current, 13,
            "프로 current를 올렸다면 §2.5 측정을 마쳤는지 확인하라 — 프로 직접 등판도 "
                + "같은 이유로 아직 legacy다"
        )
    }
}
