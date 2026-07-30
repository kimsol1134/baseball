import Foundation

/// 대회 대진 — 챕터를 "시간"이 아니라 "무대"로 만든다.
///
/// 같은 중요 경기라도 "4챕터의 경기"와 "왕중왕전 준결승, 8팀 중 살아남은 4팀"은
/// 다른 무게로 다가온다. 대진표는 커널 일정을 건드리지 않는 세계 묘사다 —
/// 내 등판이 어느 무대인지 말해 주되, 일정에 대해 거짓말하지 않는다.
public enum TournamentBracket {
    public struct Field: Equatable, Sendable {
        public let tournamentName: String
        /// 내 학교를 포함한 8팀. 순서가 곧 대진(1-2, 3-4…).
        public let schools: [String]
        /// 내 등판의 무대 — "준결승" 같은 라운드 이름.
        public let playerRound: String
    }

    /// 대회가 있는 챕터인가. 카탈로그의 대회 챕터(여름·전국·가을·마지막)와 맞춘다.
    public static func isTournamentChapter(_ chapterNumber: Int) -> Bool {
        [2, 4, 6, 8].contains(chapterNumber)
    }

    /// 가상 대회명. 실존 대회명은 쓰지 않는다 — 격은 이름이 아니라 무대 연출이 만든다.
    public static func tournamentName(chapterNumber: Int) -> String {
        switch chapterNumber {
        case 2: "청룡곡 여름 초청전"
        case 4: "전국 화랑기"
        case 6: "가을 왕중왕전"
        default: "최후의 여름 — 전국 선수권"
        }
    }

    public static func field(careerID: String, chapterNumber: Int, playerSchool: String) -> Field {
        var generator = SplitMix64(
            seed: StableHash.fnv1a64Value("bracket|\(careerID)|\(chapterNumber)")
        )
        let pool = ["북부상고", "남해정보고", "동성공고", "서령고", "중앙체고",
                    "한서고", "대양고", "청암고", "금강고", "삼도고", "백파고", "운암공고"]
        var rivals: [String] = []
        var used = Set<String>([playerSchool])
        while rivals.count < 7 {
            let school = pool[generator.nextInt(upperBound: pool.count)]
            guard !used.contains(school) else { continue }
            used.insert(school)
            rivals.append(school)
        }
        // 내 학교의 대진 위치도 시드가 정한다 — 회차마다 같은 자리면 대진표가 벽지가 된다.
        var schools = rivals
        schools.insert(playerSchool, at: generator.nextInt(upperBound: 8))
        // 후반 챕터일수록 내 등판의 무대가 깊어진다 — 3년의 무게가 라운드 이름에 실린다.
        let round = chapterNumber >= 8 ? "결승" : chapterNumber >= 6 ? "준결승" : "8강"
        return Field(
            tournamentName: tournamentName(chapterNumber: chapterNumber),
            schools: schools,
            playerRound: round
        )
    }
}
