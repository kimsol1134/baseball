import Foundation

/// 리그 순위표와 투수 순위.
///
/// 야구 게임에서 내 성적만 보이고 리그가 없으면, 그 성적이 좋은지 나쁜지 알 방법이 없다.
/// 야구 팬이 매일 보는 두 화면이 순위표와 개인 순위다.
///
/// **한 경기씩 시뮬레이션하지 않는다.** 10팀 144경기를 매주 커널로 굴리면 비용이 폭발하고,
/// 무엇보다 이 게임의 주인공은 한 명의 투수다. 리그는 배경이므로 **시드에서 결정론적으로
/// 만들어 낸 분포**로 충분하다 — 대신 같은 회차에서는 언제 봐도 같은 순위표가 나온다.
///
/// 새 난수를 커널 스트림에서 뽑지 않는다. 전부 `season + seed`에서 만든 지역 생성기다.
public enum LeagueTable {
    /// 한국 프로 리그와 같은 144경기.
    public static let gamesPerSeason = 144
    /// 프로 커리어 한 시즌의 주차 수.
    public static let weeksPerSeason = 24

    public struct StandingRow: Codable, Equatable, Sendable, Identifiable {
        public let teamID: String
        public let teamName: String
        public let wins: Int
        public let losses: Int
        public let draws: Int

        public var id: String { teamID }
        public var games: Int { wins + losses + draws }
        /// 무승부는 분모에서 뺀다.
        public var winRate: Double? { PitchingMetrics.winRate(wins: wins, losses: losses) }

        public init(teamID: String, teamName: String, wins: Int, losses: Int, draws: Int) {
            self.teamID = teamID
            self.teamName = teamName
            self.wins = wins
            self.losses = losses
            self.draws = draws
        }
    }

    /// 1위와의 승차. ((1위 승 − 내 승) + (내 패 − 1위 패)) / 2.
    public static func gamesBehind(_ row: StandingRow, leader: StandingRow) -> Double {
        Double((leader.wins - row.wins) + (row.losses - leader.losses)) / 2
    }

    /// 이 시점까지의 순위표. 승률 내림차순, 동률이면 승수.
    ///
    /// - Parameter gamesPlayed: 각 팀이 치른 경기 수. 주차에서 환산해 넘긴다.
    public static func standings(season: Int, seed: String, gamesPlayed: Int) -> [StandingRow] {
        let played = min(gamesPerSeason, max(0, gamesPlayed))
        guard played > 0 else {
            return HighSchoolCareerEngine.teams.map {
                StandingRow(teamID: $0.id, teamName: $0.name, wins: 0, losses: 0, draws: 0)
            }
        }
        var generator = SplitMix64(
            seed: (UInt64(StableHash.fnv1a64("league|\(seed)|\(season)"), radix: 16) ?? 0x4c45_4147_5545) ^ UInt64(season)
        )
        let teams = HighSchoolCareerEngine.teams

        // 팀마다 시즌 승률 기대치를 뽑는다. .380 ~ .620 사이 — 실제 한국 프로 리그의 시즌 승률 폭이다.
        var strengths = teams.map { _ in 380 + generator.nextInt(upperBound: 241) }
        // 리그 전체 승률의 평균은 .500이어야 한다. 안 맞추면 순위표의 승수 합과 패수 합이 어긋난다.
        let mean = strengths.reduce(0, +) / strengths.count
        strengths = strengths.map { $0 - mean + 500 }

        // 무승부는 팀당 시즌 2~5경기(실제 리그의 범위). 경기 수에 비례해 늘어난다.
        var draws = teams.map { _ in (2 + generator.nextInt(upperBound: 4)) * played / gamesPerSeason }
        // 승부가 난 경기의 총합은 **짝수여야 한다.** 한 경기에서 한 팀이 이기면 다른 한 팀이
        // 지므로 승수 합 == 패수 합이고, 그러면 둘의 합인 승부 경기 수도 짝수다. 홀수로 두면
        // 아래 균형 맞추기가 ±2씩만 움직여 영원히 0에 닿지 못한다(실제로 그렇게 터졌다).
        if (played * teams.count - draws.reduce(0, +)) % 2 != 0 {
            draws[0] += 1
        }

        var rows: [StandingRow] = []
        var winTotal = 0
        for (index, team) in teams.enumerated() {
            let decided = played - draws[index]
            // 기대 승수에 ±3경기의 흔들림을 준다. 기대치대로만 가면 순위가 시즌 내내 고정된다.
            let expected = decided * strengths[index] / 1_000
            let wins = min(decided, max(0, expected + generator.nextInt(upperBound: 7) - 3))
            winTotal += wins
            rows.append(StandingRow(
                teamID: team.id, teamName: team.name,
                wins: wins, losses: decided - wins, draws: draws[index]
            ))
        }

        // 승수 합과 패수 합을 맞춘다. 리그에서 누군가 이기면 누군가는 진다 — 이게 안 맞으면
        // 순위표를 아는 사람은 곧바로 알아본다.
        rows = balanced(rows, winTotal: winTotal)
        return rows.sorted {
            let left = $0.winRate ?? 0
            let right = $1.winRate ?? 0
            return left == right ? $0.wins > $1.wins : left > right
        }
    }

    /// 승수 합 == 패수 합이 되도록 한 경기씩 옮긴다.
    ///
    /// 남는 승은 이미 많이 이긴 팀에서, 모자란 승은 이미 많이 진 팀에게서 뺀다. 그래야
    /// 균형을 맞추는 과정이 순위를 뒤집지 않고 극단만 눌러 준다.
    ///
    /// `surplus`는 항상 짝수다(위에서 승부 경기 총합을 짝수로 맞춘다). 예전에는 그 보장이
    /// 없어서 홀수일 때 ±2 조정이 0을 지나쳐 되돌아오기를 반복했고, 400번 반복하는 동안
    /// 상위 팀은 승률 .84, 하위 팀은 .15까지 벌어졌다 — 야구가 아닌 순위표가 나왔다.
    private static func balanced(_ rows: [StandingRow], winTotal: Int) -> [StandingRow] {
        let lossTotal = rows.reduce(0) { $0 + $1.losses }
        var surplus = winTotal - lossTotal
        guard surplus != 0 else { return rows }
        var adjusted = rows
        // 승이 남으면 승수가 많은 팀부터, 모자라면 승수가 적은 팀부터 한 경기씩.
        let order = rows.indices.sorted {
            surplus > 0 ? (rows[$0].wins > rows[$1].wins) : (rows[$0].wins < rows[$1].wins)
        }
        var index = 0
        var stalled = 0
        while surplus != 0, stalled < order.count {
            let target = order[index % order.count]
            index += 1
            let row = adjusted[target]
            if surplus > 0, row.wins > 0 {
                adjusted[target] = StandingRow(
                    teamID: row.teamID, teamName: row.teamName,
                    wins: row.wins - 1, losses: row.losses + 1, draws: row.draws
                )
                surplus -= 2
                stalled = 0
            } else if surplus < 0, row.losses > 0 {
                adjusted[target] = StandingRow(
                    teamID: row.teamID, teamName: row.teamName,
                    wins: row.wins + 1, losses: row.losses - 1, draws: row.draws
                )
                surplus += 2
                stalled = 0
            } else {
                stalled += 1
            }
        }
        return adjusted
    }

    // MARK: - 투수 순위

    public struct PitcherRow: Codable, Equatable, Sendable, Identifiable {
        public let name: String
        public let teamName: String
        public let inningsOuts: Int
        public let wins: Int
        public let losses: Int
        public let saves: Int
        public let strikeouts: Int
        public let walks: Int
        public let hits: Int
        public let homeRuns: Int
        public let runsAllowed: Int
        /// 내 선수인가. 목록에서 강조하는 데 쓴다.
        public let isPlayer: Bool

        public var id: String { name }
        public var runsPer9: Double? { PitchingMetrics.runsPer9(runs: runsAllowed, outs: inningsOuts) }
        public var whip: Double? { PitchingMetrics.whip(hits: hits, walks: walks, outs: inningsOuts) }

        public init(
            name: String, teamName: String, inningsOuts: Int, wins: Int, losses: Int, saves: Int,
            strikeouts: Int, walks: Int, hits: Int, homeRuns: Int, runsAllowed: Int, isPlayer: Bool = false
        ) {
            self.name = name; self.teamName = teamName; self.inningsOuts = inningsOuts
            self.wins = wins; self.losses = losses; self.saves = saves
            self.strikeouts = strikeouts; self.walks = walks; self.hits = hits
            self.homeRuns = homeRuns; self.runsAllowed = runsAllowed; self.isPlayer = isPlayer
        }
    }

    /// 정렬 기준.
    public enum PitcherSort: String, CaseIterable, Sendable {
        case runsPer9, strikeouts, wins, whip

        public var title: String {
            switch self {
            case .runsPer9: "9이닝당 실점"
            case .strikeouts: "탈삼진"
            case .wins: "승"
            case .whip: "WHIP"
            }
        }
    }

    /// 리그 선발 투수 순위. 팀마다 두 명씩, 규정 이닝에 가까운 선수들만 올린다.
    ///
    /// 값의 중심은 실측 리그 평균(RA9 3.5 · K/9 10.0 · BB/9 2.4 · HR/9 0.9)에 맞춘다.
    /// 리그가 내 성적과 다른 세계의 숫자를 쓰면 순위표가 거짓말이 된다.
    public static func pitchers(
        season: Int,
        seed: String,
        gamesPlayed: Int,
        player: PitcherRow? = nil,
        sort: PitcherSort = .runsPer9
    ) -> [PitcherRow] {
        let played = min(gamesPerSeason, max(0, gamesPlayed))
        var generator = SplitMix64(
            seed: (UInt64(StableHash.fnv1a64("leaders|\(seed)|\(season)"), radix: 16) ?? 0x4c44_5253) ^ UInt64(season &* 31)
        )
        var rows: [PitcherRow] = []
        for team in HighSchoolCareerEngine.teams {
            for slot in 0..<2 {
                // 규정 이닝(144경기 기준 144이닝)의 0.75~1.15배.
                let fullOuts = 432 * (75 + generator.nextInt(upperBound: 41)) / 100
                let outs = fullOuts * played / gamesPerSeason
                guard outs >= 30 else { continue }
                let innings = Double(outs) / 3
                let ra9 = 2.2 + Double(generator.nextInt(upperBound: 260)) / 100      // 2.20 ~ 4.79
                let k9 = 6.5 + Double(generator.nextInt(upperBound: 550)) / 100        // 6.50 ~ 12.0
                let bb9 = 1.2 + Double(generator.nextInt(upperBound: 300)) / 100       // 1.20 ~ 4.19
                let h9 = 7.0 + Double(generator.nextInt(upperBound: 350)) / 100        // 7.00 ~ 10.5
                let hr9 = 0.4 + Double(generator.nextInt(upperBound: 110)) / 100       // 0.40 ~ 1.49
                let runs = Int((ra9 * innings / 9).rounded())
                // 잘 던진 투수가 더 많이 이긴다. 팀 득점 지원은 흔들림으로 들어간다.
                let decisions = max(1, outs / 54)
                let winShare = max(20, min(80, 50 + Int((3.5 - ra9) * 22)))
                let wins = decisions * winShare / 100 + (generator.nextInt(upperBound: 3) - 1)
                rows.append(PitcherRow(
                    name: pitcherName(team: team.id, slot: slot, generator: &generator),
                    teamName: team.name,
                    inningsOuts: outs,
                    wins: max(0, wins),
                    losses: max(0, decisions - max(0, wins)),
                    saves: 0,
                    strikeouts: Int((k9 * innings / 9).rounded()),
                    walks: Int((bb9 * innings / 9).rounded()),
                    hits: Int((h9 * innings / 9).rounded()),
                    homeRuns: Int((hr9 * innings / 9).rounded()),
                    runsAllowed: runs
                ))
            }
        }
        if let player { rows.append(player) }
        return sorted(rows, by: sort)
    }

    public static func sorted(_ rows: [PitcherRow], by sort: PitcherSort) -> [PitcherRow] {
        switch sort {
        case .runsPer9:
            // 낮을수록 좋다. 이닝이 없는 선수는 뒤로 보낸다.
            return rows.sorted { ($0.runsPer9 ?? .greatestFiniteMagnitude) < ($1.runsPer9 ?? .greatestFiniteMagnitude) }
        case .whip:
            return rows.sorted { ($0.whip ?? .greatestFiniteMagnitude) < ($1.whip ?? .greatestFiniteMagnitude) }
        case .strikeouts:
            return rows.sorted { $0.strikeouts > $1.strikeouts }
        case .wins:
            return rows.sorted { $0.wins > $1.wins }
        }
    }

    /// 리그 투수 이름. 회차마다 달라지되 같은 회차에서는 고정이다.
    private static func pitcherName(team: String, slot: Int, generator: inout SplitMix64) -> String {
        let surnames = ["김", "이", "박", "최", "정", "강", "조", "윤", "장", "임", "한", "오", "서", "신", "권", "황"]
        let givens = ["도현", "지훈", "성민", "우진", "재원", "하준", "시우", "건우", "예준", "선우",
                      "태윤", "민석", "현우", "정후", "승현", "주환"]
        let surname = surnames[generator.nextInt(upperBound: surnames.count)]
        let given = givens[generator.nextInt(upperBound: givens.count)]
        return "\(surname)\(given)"
    }

    /// 주차를 경기 수로. 24주 144경기이므로 주당 6경기다.
    public static func gamesPlayed(week: Int) -> Int {
        min(gamesPerSeason, max(0, week) * gamesPerSeason / weeksPerSeason)
    }
}
