import XCTest
@testable import SimulationCore

final class AlbumReplayRulesTests: XCTestCase {
    /// **앨범은 기록이 아니라 highlight다.** 다시 볼 이유가 있는 공만 남는다.
    func testOnlyPitchesWorthRememberingAreKept() {
        XCTAssertTrue(AlbumReplayRules.isWorthKeeping(outcome: .swingingStrike, result: .strikeout, perfectRelease: false))
        XCTAssertTrue(AlbumReplayRules.isWorthKeeping(outcome: .homeRun, result: .hit, perfectRelease: false))
        XCTAssertTrue(AlbumReplayRules.isWorthKeeping(outcome: .ball, result: nil, perfectRelease: true))
        // 파울과 볼은 예산만 먹는다.
        XCTAssertFalse(AlbumReplayRules.isWorthKeeping(outcome: .foul, result: nil, perfectRelease: false))
        XCTAssertFalse(AlbumReplayRules.isWorthKeeping(outcome: .ball, result: nil, perfectRelease: false))
        XCTAssertFalse(AlbumReplayRules.isWorthKeeping(outcome: .single, result: .hit, perfectRelease: false))
    }

    /// 같은 공을 두 번 담지 않는다.
    func testTheSamePitchIsNotStoredTwice() {
        let one = replay(id: "a", season: 1)
        let kept = AlbumReplayRules.appending(one, to: AlbumReplayRules.appending(one, to: []))
        XCTAssertEqual(kept.count, 1)
    }

    /// **한도에 닿아도 기존 재생을 지우지 않는다.** 새로 담는 것만 멈춘다.
    func testAFullAlbumStopsAcceptingButNeverDeletes() {
        var replays: [AlbumReplay] = []
        for index in 0..<AlbumReplayRules.replaysPerSeason {
            replays = AlbumReplayRules.appending(replay(id: "s1-\(index)", season: 1), to: replays)
        }
        XCTAssertEqual(replays.count, AlbumReplayRules.replaysPerSeason)
        let refused = AlbumReplayRules.appending(replay(id: "s1-extra", season: 1), to: replays)
        XCTAssertEqual(refused, replays, "한도에 닿았는데 기존 재생이 밀려났습니다")
        // 시즌 예산이지 전체 예산이 아니다. 다음 시즌은 다시 담을 수 있다.
        let nextSeason = AlbumReplayRules.appending(replay(id: "s2-0", season: 2), to: replays)
        XCTAssertEqual(nextSeason.count, replays.count + 1)
    }

    /// 궤적 정수 예산은 개수와 따로 센다. 긴 궤적 몇 개가 예산을 다 먹을 수 있다.
    func testTheTrajectoryBudgetIsCountedSeparately() {
        let long = Array(repeating: 0, count: AlbumReplayRules.totalTrajectoryValues)
        let first = AlbumReplayRules.appending(replay(id: "a", season: 1, trajectory: long), to: [])
        XCTAssertEqual(first.count, 1)
        XCTAssertTrue(AlbumReplayRules.isFull(first, season: 1))
        XCTAssertEqual(AlbumReplayRules.appending(replay(id: "b", season: 1), to: first), first)
    }

    /// 예산을 넘겨 들어온 옛 저장본도 그대로 재생된다 — 잘라내지 않는다.
    func testAnOverBudgetSaveKeepsEveryReplayItAlreadyHas() {
        let imported = (0..<(AlbumReplayRules.totalReplays + 40)).map { replay(id: "old-\($0)", season: 1) }
        XCTAssertTrue(AlbumReplayRules.isFull(imported, season: 1))
        XCTAssertEqual(AlbumReplayRules.appending(replay(id: "new", season: 1), to: imported), imported)
        XCTAssertEqual(imported.count, AlbumReplayRules.totalReplays + 40)
    }

    func testReplayRoundTripsThroughTheSaveFormat() throws {
        let one = replay(id: "a", season: 3, trajectory: [1, 2, 3, 4, 5, 6, 7, 8])
        let decoded = try JSONDecoder().decode(AlbumReplay.self, from: JSONEncoder().encode(one))
        XCTAssertEqual(decoded, one)
    }

    private func replay(id: String, season: Int, trajectory: [Int] = Array(repeating: 1, count: 100)) -> AlbumReplay {
        AlbumReplay(
            id: id, season: season, week: 4, outingNumber: 2, pitchNumber: 11,
            pitchType: .slider, velocityTenthsKPH: 1_320, outcome: .swingingStrike,
            result: .strikeout, perfectRelease: false, trajectory: trajectory
        )
    }
}
