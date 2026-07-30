import Foundation

/// 경기 뒤 익명 야구 커뮤니티의 반응.
///
/// 기사와 능력치는 공식 세계의 언어다. 애착은 비공식 세계에서 완성된다 —
/// 어딘가의 게시판에서 모르는 사람들이 내 선수 얘기를 하고 있다는 감각.
/// 잘 던지면 감탄하고, 볼넷이 쌓이면 냉정하게 놀린다. 그 냉정함까지가 세상이다.
///
/// 결정론: careerID와 경기 번호로 시드를 만들므로 같은 회차의 같은 경기는
/// 언제 다시 봐도 같은 반응이다. 커널 난수 경로와는 완전히 분리돼 있다.
public enum CommunityBuzz {
    /// 방금 경기에 대한 반응 3줄. 경기 내용에 맞는 풀에서 뽑는다.
    public static func reactions(
        careerID: String,
        gameNumber: Int,
        strikeouts: Int,
        walks: Int,
        runsAllowed: Int,
        newNickname: String? = nil
    ) -> [String] {
        var generator = SplitMix64(
            seed: StableHash.fnv1a64Value("buzz|\(careerID)|\(gameNumber)")
        )

        var picked: [String] = []
        // 별명이 붙은 날은 그 얘기부터 나온다.
        if let nickname = newNickname {
            picked.append(pick(&generator, [
                "'\(nickname)' 별명 붙은 거 봤음? 인정할 수밖에 없긴 함",
                "요즘 애들이 '\(nickname)'(이)라고 부르던데 찰떡이긴 하다",
                "별명이 '\(nickname)'... 고교야구에서 별명 생기면 진짜라는 뜻임",
            ]))
        }

        if runsAllowed == 0, strikeouts >= 5 {
            picked.append(pick(&generator, [
                "오늘 경기 직관했는데 상대 타자들이 공을 아예 못 봄",
                "무실점에 탈삼진 \(strikeouts)개면 고교 레벨이 아닌 듯",
                "저 나이에 저런 공을 던진다고? 더 크면 어떻게 되는 거임?",
                "스카우트들 오늘 수첩에 뭐라고 적었을지 궁금하다",
            ]))
        } else if runsAllowed == 0 {
            picked.append(pick(&generator, [
                "화려하진 않은데 점수를 안 줌. 이런 투수가 무서운 거임",
                "오늘도 무실점. 조용히 꾸준한 게 제일 어려운 건데",
                "상대 팀 응원석이 조용해지는 게 보이더라",
            ]))
        } else if walks >= 3 {
            picked.append(pick(&generator, [
                "공은 좋은데 볼넷 \(walks)개는 좀... 제구 잡히는 게 관건일 듯",
                "오늘 볼넷이 너무 많았음. 본인이 제일 답답했을 듯",
                "구위는 진짜인데 어디로 갈지 모르는 게 함정",
            ]))
        } else if runsAllowed >= 4 {
            picked.append(pick(&generator, [
                "오늘은 공이 다 몰리더라. 이런 날도 있는 거지",
                "\(runsAllowed)실점... 다음 경기에서 어떻게 나오는지가 진짜 시험임",
                "무너진 날 다음이 진짜라고 생각함. 지켜본다",
            ]))
        } else if strikeouts >= 4 {
            picked.append(pick(&generator, [
                "탈삼진 \(strikeouts)개 ㅎㄷㄷ 2스트라이크 잡히면 끝나는 분위기였음",
                "헛스윙 나오는 각도가 다르던데 저거 무슨 공임?",
                "삼진 잡는 리듬이 좋아졌음. 작년이랑 완전 다른 선수 같음",
            ]))
        }

        // 일반 궁금증 — 세상이 이 선수의 '사람'을 궁금해하기 시작했다는 신호.
        let general = [
            "저 선수 몇 학년임? 체격 좋아 보이던데",
            "다음 경기 언제임? 직관 가고 싶은데",
            "훈련을 어떻게 하길래 저렇게 던짐?",
            "프로 갈 생각 있는 선수임? 벌써 궁금하네",
            "경기 밖에서는 어떤 스타일인지 궁금함",
            "부상 없이 쭉 갔으면 좋겠다. 관리 잘 받고 있겠지?",
            "작년에도 이 정도였음? 갑자기 좋아진 것 같은데",
            "저 학교 갑자기 왜 이렇게 강해짐?",
        ]
        while picked.count < 3 {
            let line = pick(&generator, general)
            if !picked.contains(line) { picked.append(line) }
        }
        return picked
    }

    private static func pick(_ generator: inout SplitMix64, _ pool: [String]) -> String {
        pool[generator.nextInt(upperBound: pool.count)]
    }
}
