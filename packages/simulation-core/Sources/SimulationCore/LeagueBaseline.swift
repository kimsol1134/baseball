import Foundation

/// 리그 평균이 어떻게 생겼는지.
///
/// "실제 야구처럼"을 정직하게 구현하는 방법에 대해:
///
/// 이 앱은 오프라인이고 외부 데이터를 받아오지 않는다. 그래서 남의 데이터셋을 담지 않는다.
/// 대신 **공개된 집계 통계의 모양만** 상수로 옮긴다 — 한 경기에 몇 점이 나는지의 분포,
/// 선발이 몇 이닝을 던지는지의 분포 같은 것들이다. 개별 선수나 구단의 기록은 들어 있지 않고,
/// 들어갈 이유도 없다. 필요한 것은 "야구라는 경기가 만들어 내는 숫자의 모양"뿐이다.
///
/// 이 파일이 존재하는 이유는 그 모양이 코드 여기저기에 흩어져 마법의 숫자로 박히는 것을 막기
/// 위해서다. 밸런스를 고칠 때 볼 곳이 한 군데여야 한다.
enum LeagueBaseline {

    // MARK: - 팀 득점

    /// 한 경기에서 한 팀이 뽑는 점수의 분포. 인덱스가 곧 득점이고 값은 천분율이다.
    ///
    /// 야구의 득점 분포는 평균 근처가 봉우리이면서 오른쪽으로 긴 꼬리를 갖는다 — 0점 경기가
    /// 드물지 않고, 두 자리 득점도 가끔 나온다. 평균은 4.4점 근처다. 정규분포로 뽑으면
    /// 완봉패와 난타전이 둘 다 사라져서 시즌이 밋밋해진다.
    ///
    /// 합은 1,000이어야 한다(`runDistributionSumsToOneThousand` 테스트가 지킨다).
    static let teamRunsPerGamePermille: [Int] = [
        62,    // 0점 — 완봉당하는 경기
        104,   // 1
        131,   // 2
        138,   // 3
        135,   // 4
        119,   // 5
        95,    // 6
        70,    // 7
        50,    // 8
        34,    // 9
        22,    // 10
        14,    // 11
        9,     // 12
        6,     // 13
        4,     // 14
        3,     // 15
        2,     // 16
        1,     // 17
        1,     // 18
    ]

    /// 득점 분포에서 하나 뽑는다. 시드된 RNG만 받는다 — 결정성을 깨지 않기 위해서다.
    static func teamRuns(using rng: inout SplitMix64) -> Int {
        let roll = rng.nextInt(upperBound: 1_000)
        var cumulative = 0
        for (runs, weight) in teamRunsPerGamePermille.enumerated() {
            cumulative += weight
            if roll < cumulative { return runs }
        }
        return teamRunsPerGamePermille.count - 1
    }

    /// 내가 던지지 않은 이닝에서 우리 팀 나머지 투수들이 준 점수.
    ///
    /// 이게 없으면 마무리가 1이닝을 무실점으로 막은 날 최종 스코어가 5:0으로 찍힌다 —
    /// 내가 등판한 날에는 앞선 여덟 이닝에서 아무도 점수를 안 줬다는 뜻이 되고, 야구를 아는
    /// 사람은 시즌 로그 한 페이지만 봐도 알아챈다. 팀 득점 분포에서 하나 뽑아 잔여 이닝
    /// 비율로 줄인다.
    static func restOfTeamRuns(outsCovered: Int, using rng: inout SplitMix64) -> Int {
        let full = teamRuns(using: &rng)
        return full * max(0, outsCovered) / 27
    }

    // MARK: - 판정 규칙

    /// 선발승의 최소 이닝. 야구 규칙 그대로 5이닝이다.
    static let minimumOutsForStarterWin = 15

    /// 세이브가 성립하는 최대 점수 차. 3점 차 이내에서 마무리해야 한다.
    static let saveLeadCeiling = 3

    // MARK: - 고교

    /// 고교 팀이 한 경기에서 뽑는 점수. 프로보다 편차가 크고 대량 득점이 잦다.
    /// 아마추어 야구는 수비와 제구가 프로만큼 안정적이지 않아 점수가 크게 벌어진다.
    static let highSchoolRunsPerGamePermille: [Int] = [
        70, 92, 112, 124, 126, 116, 100, 80, 62, 45, 32, 21, 13, 7, 0,
    ]

    /// 고교판 "내가 안 던진 이닝의 실점". 프로와 같은 이유로 필요하다.
    static func restOfHighSchoolTeamRuns(outsCovered: Int, using rng: inout SplitMix64) -> Int {
        let full = highSchoolTeamRuns(using: &rng)
        return full * max(0, outsCovered) / 27
    }

    static func highSchoolTeamRuns(using rng: inout SplitMix64) -> Int {
        let roll = rng.nextInt(upperBound: 1_000)
        var cumulative = 0
        for (runs, weight) in highSchoolRunsPerGamePermille.enumerated() {
            cumulative += weight
            if roll < cumulative { return runs }
        }
        return highSchoolRunsPerGamePermille.count - 1
    }
}

/// 한 번의 등판에 붙는 판정.
public enum PitchingDecision: String, Codable, Equatable, Sendable {
    case win
    case loss
    case save
    /// 승도 패도 아니다. **이 게임에서 가장 중요한 값이다** — 7이닝 무실점을 던지고도
    /// 타선이 못 쳐서 노디시전으로 끝나는 경기가 투수의 삶이고, 그것이 없으면 성적이
    /// 그냥 내가 잘했는지의 요약표가 된다.
    case noDecision
}

/// 등판 하나의 기록. 시즌 합계만 있으면 "잘 던졌다"는 느낌이 남지 않는다 —
/// 어느 경기에 무엇을 했는지가 남아야 커리어가 이야기가 된다.
public struct ProGameLine: Codable, Equatable, Sendable, Identifiable {
    public let season: Int
    public let week: Int
    /// 시즌 안에서 몇 번째 등판인지. 화면 정렬과 식별에 쓴다.
    public let outingNumber: Int
    public let started: Bool
    public let outs: Int
    public let strikeouts: Int
    public let walks: Int
    public let runsAllowed: Int
    public let pitches: Int
    /// 우리 팀이 낸 점수. **이것을 보여 주지 않으면 패전이 억울한 게 아니라 이상해 보인다.**
    public let teamRuns: Int
    public let opponentRuns: Int
    public let decision: PitchingDecision
    /// 직접 던진 승부가 포함된 경기인가. 자동으로 지나간 경기와 구분해서 보여 준다.
    public let played: Bool
    /// 피안타·피홈런. 직접 던진 경기는 화면이 세지 않으므로 nil이다 —
    /// 그때는 "6.1이닝 7K 2BB 2실점"으로도 행이 성립한다.
    public let hits: Int?
    public let homeRuns: Int?

    public var id: String { "\(season)-\(outingNumber)" }

    public init(
        season: Int,
        week: Int,
        outingNumber: Int,
        started: Bool,
        outs: Int,
        strikeouts: Int,
        walks: Int,
        runsAllowed: Int,
        pitches: Int,
        teamRuns: Int,
        opponentRuns: Int,
        decision: PitchingDecision,
        played: Bool,
        hits: Int? = nil,
        homeRuns: Int? = nil
    ) {
        self.season = season
        self.week = week
        self.outingNumber = outingNumber
        self.started = started
        self.outs = outs
        self.strikeouts = strikeouts
        self.walks = walks
        self.runsAllowed = runsAllowed
        self.pitches = pitches
        self.teamRuns = teamRuns
        self.opponentRuns = opponentRuns
        self.decision = decision
        self.played = played
        self.hits = hits
        self.homeRuns = homeRuns
    }

    /// 없는 키는 nil로 읽는다. 중간 빌드를 태운 내부 테스터의 저장을 보호한다.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        season = try container.decode(Int.self, forKey: .season)
        week = try container.decode(Int.self, forKey: .week)
        outingNumber = try container.decode(Int.self, forKey: .outingNumber)
        started = try container.decodeIfPresent(Bool.self, forKey: .started) ?? false
        outs = try container.decodeIfPresent(Int.self, forKey: .outs) ?? 0
        strikeouts = try container.decodeIfPresent(Int.self, forKey: .strikeouts) ?? 0
        walks = try container.decodeIfPresent(Int.self, forKey: .walks) ?? 0
        runsAllowed = try container.decodeIfPresent(Int.self, forKey: .runsAllowed) ?? 0
        pitches = try container.decodeIfPresent(Int.self, forKey: .pitches) ?? 0
        teamRuns = try container.decodeIfPresent(Int.self, forKey: .teamRuns) ?? 0
        opponentRuns = try container.decodeIfPresent(Int.self, forKey: .opponentRuns) ?? 0
        decision = try container.decodeIfPresent(PitchingDecision.self, forKey: .decision) ?? .noDecision
        played = try container.decodeIfPresent(Bool.self, forKey: .played) ?? false
        hits = try container.decodeIfPresent(Int.self, forKey: .hits)
        homeRuns = try container.decodeIfPresent(Int.self, forKey: .homeRuns)
    }

    /// "6.1이닝" 형태. 야구에서 이닝은 3분의 1 단위로 센다.
    public var inningsText: String {
        let full = outs / 3
        let remainder = outs % 3
        return remainder == 0 ? "\(full)" : "\(full).\(remainder)"
    }
}

/// 등판 결과에 승패를 붙인다.
///
/// 규칙은 실제 야구 그대로다. 선발은 5이닝을 채워야 승리 투수가 될 수 있고, 팀이 지면
/// 패전이 붙고, 팀이 이겼는데 5이닝을 못 채웠으면 노디시전이다. 마무리는 3점 차 이내를
/// 지켜냈을 때만 세이브다.
///
/// **왜 상대 팀을 통째로 시뮬레이션하지 않는가**: 플레이어가 알고 싶은 것은 자기 기록과
/// 그 경기의 승패뿐이다. 상대 타선 아홉 명을 굴리면 계산은 늘고 화면에 나오는 것은 같다.
/// 대신 팀 득점을 실제 분포에서 뽑아 규칙을 적용한다 — 결과의 모양은 같고 비용은 훨씬 싸다.
enum DecisionRules {
    static func decide(
        started: Bool,
        isCloser: Bool,
        outs: Int,
        runsAllowed: Int,
        teamRuns: Int,
        opponentRuns: Int
    ) -> PitchingDecision {
        let teamWon = teamRuns > opponentRuns
        let teamLost = teamRuns < opponentRuns

        if started {
            if teamWon {
                return outs >= LeagueBaseline.minimumOutsForStarterWin ? .win : .noDecision
            }
            // 선발이 실점했고 팀이 졌으면 패전. 한 점도 안 줬는데 진 경기는 구원 투수의 몫이다.
            return teamLost && runsAllowed > 0 ? .loss : .noDecision
        }

        if isCloser, teamWon, runsAllowed == 0,
           teamRuns - opponentRuns <= LeagueBaseline.saveLeadCeiling {
            return .save
        }
        if teamLost, runsAllowed > 0 { return .loss }
        if teamWon, runsAllowed == 0 { return .noDecision }
        return .noDecision
    }
}
