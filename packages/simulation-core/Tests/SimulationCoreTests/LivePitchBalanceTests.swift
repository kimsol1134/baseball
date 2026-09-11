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

    /// 같은 school 곡선인데 **자동 등판은 멀쩡하고 직접 등판은 무너지는가**(§2.5 Step 2).
    ///
    /// 자동 시뮬레이터는 사람의 조준 오차가 없다. 라이브 하네스는 중립 릴리스라 조준 실력이
    /// 0이다. school 곡선(1-B)이 고친 것이 바로 "제구가 낮으면 볼넷·실투가 실제로 나오고
    /// 가운데 몰린 공은 타구 품질에 반영된다"이므로, 두 값의 차이는 곡선의 문제가 아니라
    /// **누가 던졌는가**의 문제일 수 있다. 그 가설을 여기서 잰다.
    func testAutomaticOutingsOnTheSchoolCurve() {
        let pitcher = PitcherSnapshot(
            id: "hs", name: "측정", stuff: 45, command: 40, movement: 42, stamina: 44
        )
        for (name, balance) in [
            ("legacy", PitchBalanceRules.legacy),
            ("school", PitchBalanceRules.school),
        ] {
            let simulator = AutoOutingSimulator(balance: balance)
            var outs = 0, strikeouts = 0, walks = 0, hits = 0, runs = 0, pitches = 0
            for index in 0..<120 {
                let line = simulator.simulate(
                    pitcher: pitcher,
                    startingFatigue: 20,
                    outsTarget: 18,
                    pitchCap: 90,
                    batterOffset: balance.isSchool ? -1 : -6,
                    baseSeed: UInt64(9_000 + index)
                )
                outs += line.outs
                strikeouts += line.strikeouts
                walks += line.walks
                hits += line.hits
                runs += line.runsAllowed
                pitches += line.pitches
            }
            func per9(_ value: Int) -> Double {
                outs > 0 ? Double(value) * 27 / Double(outs) : 0
            }
            print(String(
                format: "[auto-curve] %@  %.1f이닝 · K/9 %.2f · BB/9 %.2f · H/9 %.2f · R/9 %.2f · WHIP %.2f",
                name, Double(outs) / 3, per9(strikeouts), per9(walks), per9(hits), per9(runs),
                outs > 0 ? Double(walks + hits) * 3 / Double(outs) : 0
            ))
            XCTAssertGreaterThan(outs, 0, name)
        }
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
