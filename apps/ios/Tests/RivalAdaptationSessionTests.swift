import XCTest
import SimulationCore
@testable import BaseballIOS

/// **같은 공을 반복하면 읽힌다** — 이 게임이 스토어에서 파는 약속이 실제 승부에서 성립하는가.
///
/// 예전에는 성립하지 않았다. 세션이 타자마다 라이벌 기억을 버려서 `plateAppearancesSeen`이
/// 0에 머물렀고, 그러면 적응도가 420에서 하드캡된다. "완전히 읽힘"(600 이상) 밴드와 포수의
/// 반복 경고는 **도달할 수 없는 죽은 코드**였다. 화면에는 막대가 있는데 그 막대가 끝까지 갈
/// 수 없었다는 뜻이다.
@MainActor
final class RivalAdaptationSessionTests: XCTestCase {

    /// 프로 중요 경기 시나리오. 라인업이 여러 명이라 타자가 실제로 바뀐다.
    private func makeSession(seed: String) -> PitchSession {
        let team = ProCareerEngine.proTeams[0]
        let state = ProCareerSnapshot(
            proCareerID: "adapt-test", revision: 3, phase: .importantGame, identity: .defaultPitcher,
            pitcher: PitcherSnapshot(id: "p-adapt", name: "테스트", stuff: 45, command: 45, movement: 42, stamina: 45),
            team: team, entitlement: AppEntitlement.paidApp(), age: 20, season: 1, week: 8,
            level: .minor, role: .setup, managerTrust: 50, catcherTrust: 50, fatigue: 10, injuryWeeks: 0,
            serviceYears: 0, militaryCompleted: false,
            contract: ProContractSnapshot(yearsRemaining: 3, annualSalary: 30_000_000, rolePromise: .setup),
            currentStats: ProSeasonStats(season: 1, teamID: team.id), careerStats: [], awards: [],
            milestones: [], news: [], hallOfFameScore: nil, commitment: ""
        )
        let session = PitchSession(state: state, seed: seed)
        session.start()
        return session
    }

    /// 세션을 만들고 같은 배합만 되풀이해서 던진다.
    private func hammerOnePattern(pitches: Int) -> PitchSession {
        let session = makeSession(seed: "77")
        for _ in 0..<pitches {
            switch session.stage {
            case .ready:
                // 늘 같은 구종·같은 코스. 이것이 읽히지 않으면 시스템이 없는 것이다.
                session.selectedPitchType = .fourSeam
                session.selectedZone = PitchZone(row: 1, column: 0)
                session.selectedIntent = .strike
                session.throwPitch(delivery: .neutral)
            case .betweenBatters:
                session.advanceToNextBatter()
            case .finished, .failed:
                return session
            }
        }
        return session
    }

    /// 타자가 바뀌어도 기억이 이어진다.
    func testMemorySurvivesTheNextBatter() {
        let session = makeSession(seed: "31")
        session.throwPitch(delivery: .neutral)
        let seenAfterFirst = session.rivalMemory?.totalPitchesSeen ?? 0
        XCTAssertGreaterThan(seenAfterFirst, 0)

        // 타석이 끝날 때까지 던지고 다음 타자로 넘어간다.
        var guardCount = 0
        while case .ready = session.stage, guardCount < 40 {
            session.throwPitch(delivery: .neutral)
            guardCount += 1
        }
        guard case .betweenBatters = session.stage else {
            return  // 이닝이 먼저 끝났으면 이 검사는 의미가 없다.
        }
        let before = session.rivalMemory?.totalPitchesSeen ?? 0
        session.advanceToNextBatter()
        XCTAssertEqual(
            session.rivalMemory?.totalPitchesSeen, before,
            "타자가 바뀌면서 기억이 사라졌습니다 — 벤치가 지켜본다는 계약이 깨졌습니다."
        )
    }

    /// 같은 배합을 계속 던지면 적응도가 예전 한계(420)를 실제로 넘는다.
    func testRepeatingOnePatternPassesTheOldHardCap() {
        let session = hammerOnePattern(pitches: 40)
        let level = session.preparation?.rivalAdaptation.level
            ?? session.lastResult?.rivalAdaptation.level ?? 0
        XCTAssertGreaterThan(
            level, 420,
            "같은 공만 40구를 던졌는데 적응도가 \(level)입니다 — 420을 못 넘으면 예전과 같습니다."
        )
    }

    /// 그리고 "완전히 읽힘"까지 도달한다. 이 밴드가 화면에 나올 수 있어야 경고가 경고다.
    func testLockedOnBandIsReachable() {
        let session = hammerOnePattern(pitches: 40)
        let band = session.preparation?.rivalAdaptation.band
            ?? session.lastResult?.rivalAdaptation.band ?? .noData
        XCTAssertEqual(band, .lockedOn, "완전히 읽힘 밴드에 도달하지 못했습니다(현재 \(band)).")
    }

    /// 섞어 던지면 읽히지 않는다. 위 검사만 있으면 "무조건 오르는 막대"여도 통과한다.
    func testMixingKeepsTheBatterGuessing() {
        let session = makeSession(seed: "77")
        let types: [PitchType] = [.fourSeam, .slider, .curveball, .changeup]
        let zones = [PitchZone(row: 0, column: 0), PitchZone(row: 2, column: 2),
                     PitchZone(row: 1, column: 2), PitchZone(row: 2, column: 0)]
        for index in 0..<40 {
            switch session.stage {
            case .ready:
                session.selectedPitchType = types[index % types.count]
                session.selectedZone = zones[(index / 2) % zones.count]
                session.throwPitch(delivery: .neutral)
            case .betweenBatters:
                session.advanceToNextBatter()
            case .finished, .failed:
                break
            }
        }
        let mixed = session.preparation?.rivalAdaptation.level
            ?? session.lastResult?.rivalAdaptation.level ?? 0
        let repeated = hammerOnePattern(pitches: 40).preparation?.rivalAdaptation.level
            ?? hammerOnePattern(pitches: 40).lastResult?.rivalAdaptation.level ?? 0
        XCTAssertLessThan(mixed, repeated, "섞어 던진 쪽이 더 읽혔습니다 — 위계가 뒤집혔습니다.")
    }
}
