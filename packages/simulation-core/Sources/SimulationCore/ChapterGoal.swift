import Foundation

/// 챕터 단위의 단기 목표 — "3년 뒤 드래프트"는 너무 멀다.
///
/// 긴 목표는 방향을 주지만 오늘 훈련 하나를 누르게 만드는 것은 이번 챕터의
/// 숫자다. 목표는 careerID·챕터로 결정론이라 같은 회차의 같은 챕터는 언제나
/// 같은 숙제를 낸다. 보상은 능력치가 아니라 축하와 기록이다 — 숫자 보상을
/// 걸면 목표가 밸런스 뒷문이 된다.
public enum ChapterGoal {
    /// Presentation identity for the four authored goal frames. This is not persisted and does
    /// not participate in the target formula or the deterministic generator stream.
    public enum Frame: String, CaseIterable, Sendable {
        case coachAssignment = "coach-assignment"
        case scoutAttention = "scout-attention"
        case catcherBet = "catcher-bet"
        case personalPromise = "personal-promise"
    }

    public struct Goal: Equatable, Sendable {
        /// 누가 낸 숙제인가 — 같은 숫자도 "감독의 숙제"와 "스카우트의 시선"은 다르게 읽힌다.
        public let title: String
        public let detail: String
        public let targetStrikeouts: Int
        /// Ephemeral identity for localized presentation; never saved or hashed.
        public let frame: Frame

        public init(
            title: String,
            detail: String,
            targetStrikeouts: Int,
            frame: Frame = .coachAssignment
        ) {
            self.title = title
            self.detail = detail
            self.targetStrikeouts = targetStrikeouts
            self.frame = frame
        }
    }

    public static func goal(careerID: String, chapterNumber: Int) -> Goal {
        var generator = SplitMix64(
            seed: StableHash.fnv1a64Value("goal|\(careerID)|\(chapterNumber)")
        )
        // 챕터가 갈수록 숙제가 커진다. 1챕터 4~6개 → 후반 8~10개.
        let target = 3 + min(chapterNumber, 5) + generator.nextInt(upperBound: 3)
        let frames: [(Frame, String, String)] = [
            (.coachAssignment, "감독의 숙제", "감독이 지나가듯 말했다 — 이번 이야기에 삼진 \(target)개는 잡아 보라고."),
            (.scoutAttention, "스카우트의 시선", "관중석 뒤편의 수첩이 이번 이야기 탈삼진 \(target)개를 기다립니다."),
            (.catcherBet, "포수의 내기", "포수가 장비를 챙기며 웃었다 — 이번 이야기 삼진 \(target)개, 내기할까?"),
            (.personalPromise, "나와의 약속", "소등 전에 적어 둔 한 줄 — 이번 이야기, 삼진 \(target)개."),
        ]
        let frame = frames[generator.nextInt(upperBound: frames.count)]
        return Goal(
            title: frame.1,
            detail: frame.2,
            targetStrikeouts: target,
            frame: frame.0
        )
    }
}
