import Foundation

/// 다시 볼 만한 공 하나.
///
/// 커널이 이미 궤적을 내놓으므로(`PitchExecutionSnapshot.trajectorySeries`) 저장하는 것은
/// 그 배열과 그 공이 무엇이었는지뿐이다. **재생은 읽기 전용이다** — 다시 그릴 때 커널을
/// 부르지 않으므로 난수도, 명령도, 보상도 움직이지 않는다.
public struct AlbumReplay: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let season: Int
    public let week: Int
    /// 시즌 안에서 몇 번째 등판인지. 기록 화면의 등판 행과 이어 붙이는 열쇠다.
    public let outingNumber: Int
    public let pitchNumber: Int
    public let pitchType: PitchType
    public let velocityTenthsKPH: Int
    public let outcome: PitchOutcome
    /// 타석 결과. 타석을 끝내지 않은 공은 nil이다.
    public let result: PlateAppearanceResult?
    public let perfectRelease: Bool
    /// 4개씩 한 표본(시각·좌우·전후·높이). 커널이 준 값을 그대로 둔다.
    public let trajectory: [Int]

    public init(
        id: String,
        season: Int,
        week: Int,
        outingNumber: Int,
        pitchNumber: Int,
        pitchType: PitchType,
        velocityTenthsKPH: Int,
        outcome: PitchOutcome,
        result: PlateAppearanceResult?,
        perfectRelease: Bool,
        trajectory: [Int]
    ) {
        self.id = id
        self.season = season
        self.week = week
        self.outingNumber = outingNumber
        self.pitchNumber = pitchNumber
        self.pitchType = pitchType
        self.velocityTenthsKPH = velocityTenthsKPH
        self.outcome = outcome
        self.result = result
        self.perfectRelease = perfectRelease
        self.trajectory = trajectory
    }
}

public enum AlbumReplayRules {
    /// 한 시즌이 들 수 있는 재생 수. 안드로이드 `AlbumReplayRetention`과 같은 예산이다.
    public static let replaysPerSeason = 128
    public static let totalReplays = 512
    public static let totalTrajectoryValues = 65_536

    /// **앨범은 기록이 아니라 highlight다.**
    ///
    /// 한 시즌이 수천 구인데 예산은 512개다. 전부 담는 것은 애초에 불가능하므로 무엇을
    /// 남길지가 예산보다 중요한 결정이다. 남는 것은 **기억에 남을 이유가 있는 공**이다 —
    /// 타석을 끝낸 삼진, 얻어맞은 홈런, 그리고 손으로 정중앙을 맞힌 공. 앞의 둘은 승부가
    /// 갈린 순간이고, 마지막은 플레이어가 해낸 일이다.
    ///
    /// 파울이나 볼은 남기지 않는다. 남겨 봐야 예산만 먹고 다시 볼 이유가 없다.
    public static func isWorthKeeping(
        outcome: PitchOutcome,
        result: PlateAppearanceResult?,
        perfectRelease: Bool
    ) -> Bool {
        if perfectRelease { return true }
        if result == .strikeout { return true }
        return outcome == .homeRun
    }

    /// 예산이 찼는가. 셋 중 하나라도 차면 더 담지 않는다.
    public static func isFull(_ replays: [AlbumReplay], season: Int) -> Bool {
        if replays.count >= totalReplays { return true }
        if replays.count(where: { $0.season == season }) >= replaysPerSeason { return true }
        return trajectoryValues(replays) >= totalTrajectoryValues
    }

    /// 담을 수 있으면 담고, 아니면 있는 그대로 돌려준다.
    ///
    /// **한도에 닿아도 기존 재생을 지우지 않는다.** 오래된 것을 밀어내면 플레이어가 아끼던
    /// 공이 조용히 사라진다 — 새로 담는 것만 멈추는 편이 낫고, 예산을 넘겨 들어온 옛
    /// 저장본도 그대로 재생된다.
    public static func appending(_ replay: AlbumReplay, to replays: [AlbumReplay]) -> [AlbumReplay] {
        guard !replays.contains(where: { $0.id == replay.id }) else { return replays }
        guard !isFull(replays, season: replay.season) else { return replays }
        guard trajectoryValues(replays) + replay.trajectory.count <= totalTrajectoryValues else {
            return replays
        }
        return replays + [replay]
    }

    public static func trajectoryValues(_ replays: [AlbumReplay]) -> Int {
        replays.reduce(0) { $0 + $1.trajectory.count }
    }
}
