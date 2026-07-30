import Foundation

/// 전국 고교 유망주 랭킹 — 드래프트라는 최종 시험 전에 세상이 매기는 중간 점수.
///
/// 순위표는 프로에만 있었고, 고교 3년 동안 "전국에서 내가 몇 번째인가"를 답해 주는
/// 화면이 없었다. 그 답이 매 경기 갱신될 때 드래프트 기대감이 매주의 감정이 된다.
///
/// 결정론: 경쟁 유망주 명단은 careerID 시드로, 내 순위는 누적 성적의 순수 함수로
/// 정해진다. 커널 난수 경로와 분리돼 있어 골든 픽스처에 영향이 없다.
public enum ProspectRanking {
    public struct Entry: Equatable, Sendable, Identifiable {
        public let rank: Int
        public let name: String
        public let school: String
        /// 스카우트 한 줄 평 — 이 선수가 왜 여기 있는가.
        public let tag: String
        public let isPlayer: Bool

        public var id: Int { rank }
    }

    /// 랭킹은 20위까지만 발표된다. 그 밖은 "랭킹 밖" — 진입 자체가 첫 사건이 되도록.
    public static let boardSize = 20

    /// 내 전국 순위. 아직 등판이 없으면 nil(세상이 모른다), 성적이 모자라면
    /// boardSize 밖의 순위가 나온다 — 그것도 "몇 계단 남았는지"를 말해 주는 정보다.
    public static func playerRank(performance: CareerPerformanceSnapshot) -> Int? {
        let games = performance.importantGamesCompleted
        guard games > 0 else { return nil }
        // 평가 점수: 탈삼진은 재능, 볼넷·실점은 감점, 경기 수는 검증된 표본.
        let score = performance.strikeouts * 3 - performance.walks * 2
            - performance.runsAllowed * 3 + games * 4
        // 점수 0 이하 = 60위권(무명), 점수가 쌓일수록 계단을 오른다. 1위는 90점 —
        // 5경기 30탈삼진 무실점급이 도달하는 자리다.
        let rank = max(1, 60 - (score * 59) / 90)
        return rank
    }

    /// 발표된 랭킹 보드. 내가 20위 안이면 명단에 함께 실린다.
    public static func board(careerID: String, playerName: String, playerSchool: String,
                             performance: CareerPerformanceSnapshot) -> [Entry] {
        var generator = SplitMix64(seed: StableHash.fnv1a64Value("prospect|\(careerID)"))
        let surnames = ["강", "고", "권", "김", "도", "문", "박", "배", "서", "신", "안", "유", "이", "임", "정", "조", "차", "최", "한", "황"]
        let given = ["도현", "민재", "서준", "예준", "시우", "하준", "지호", "은찬", "준서", "건우",
                     "현빈", "태윤", "재민", "성민", "규현", "동주", "찬영", "우진", "석현", "영웅"]
        let schools = ["북부상고", "남해정보고", "동성공고", "서령고", "중앙체고",
                       "한서고", "대양고", "청암고", "금강고", "삼도고"]
        let tags = ["최고 구속으로 스카우트 보고서 첫 줄을 차지한 파이어볼러",
                    "존 네 귀퉁이를 마음대로 쓰는 완성형 제구",
                    "각이 다른 종변화구 — 헛스윙 유도 1위",
                    "3학년 여름에 만개한 늦깎이 에이스",
                    "이닝을 먹는 체력 — 완투가 기본",
                    "위기에서만 구속이 오르는 승부사",
                    "중학 시절부터 이름난 엘리트 코스",
                    "무명 학교에서 혼자 팀을 끌어올린 화제의 투수",
                    "타자들이 타이밍을 못 잡는 디셉션",
                    "부상 복귀 후 더 강해져 돌아온 재활의 표본"]

        // 명단은 회차마다 다르되 그 회차 안에서는 고정 — 라이벌은 얼굴이 있어야 한다.
        var names: Set<String> = [playerName]
        var rivals: [(String, String, String)] = []
        while rivals.count < Self.boardSize {
            let name = surnames[generator.nextInt(upperBound: surnames.count)]
                + given[generator.nextInt(upperBound: given.count)]
            guard !names.contains(name) else { continue }
            names.insert(name)
            rivals.append((
                name,
                schools[generator.nextInt(upperBound: schools.count)],
                tags[generator.nextInt(upperBound: tags.count)]
            ))
        }

        let mine = playerRank(performance: performance)
        var entries: [Entry] = []
        var rivalIndex = 0
        for rank in 1...Self.boardSize {
            if rank == mine {
                entries.append(Entry(rank: rank, name: playerName, school: playerSchool,
                                     tag: "이 명단에서 유일하게 당신이 키우는 선수", isPlayer: true))
            } else {
                let rival = rivals[rivalIndex]
                rivalIndex += 1
                entries.append(Entry(rank: rank, name: rival.0, school: rival.1, tag: rival.2, isPlayer: false))
            }
        }
        return entries
    }
}
