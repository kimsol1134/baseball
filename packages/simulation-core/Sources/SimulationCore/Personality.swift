import Foundation

/// 성격 — 선택이 쌓여 만들어지는 사람됨.
///
/// 능력치는 훈련이 만들지만 성격은 **선택**이 만든다. 감독의 지적에 묵묵히
/// 들었는지, 근거를 대며 설명했는지, 정면으로 부딪혔는지 — 그 응답들이 쌓여
/// 이 선수가 어떤 사람인지가 된다. 경기 성적은 성격을 바꾸지 않는다.
/// 잘 던져서 좋은 사람이 되는 게 아니다.
public struct Personality: Equatable, Sendable {
    public let title: String
    /// 스카우트 평가서에 적히는 문장 — 세상이 이 성격을 어떻게 읽는가.
    public let scoutLine: String
    /// 이 성격이 마운드 위에서 발동하는 기질 특성.
    public let trait: PersonalityTrait
}

public enum PersonalityRules {
    /// 성격이 굳는 데 필요한 선택의 수. 두어 번의 대화로 사람을 규정하면 점괘다.
    public static let crystallizationThreshold = 5

    /// 응답 누적 → 성격. 표본이 모자라면 nil — 아직 어떤 사람인지 모른다.
    ///
    /// 한 축이 45% 이상 기울면 그쪽 성격, 아니면 균형형. 계속 다른 선택을 하면
    /// 성격도 서서히 바뀐다 — 사람은 고정된 값이 아니다.
    public static func personality(listen: Int, explain: Int, challenge: Int) -> Personality? {
        let total = listen + explain + challenge
        guard total >= crystallizationThreshold else { return nil }
        let dominant = max(listen, explain, challenge)
        guard dominant * 100 >= total * 45 else {
            return Personality(
                title: "유연한 중심",
                scoutLine: "상황에 맞는 얼굴을 꺼낼 줄 압니다. 어느 클럽하우스에 놓아도 제 몫을 하는 유형.",
                trait: .opener
            )
        }
        if dominant == challenge {
            return Personality(
                title: "불같은 승부사",
                scoutLine: "물러서는 법을 모릅니다. 큰 경기, 큰 타자 앞에서 구속이 오르는 유형.",
                trait: .closer
            )
        }
        if dominant == listen {
            return Personality(
                title: "조용한 버팀목",
                scoutLine: "끝까지 듣고 먼저 움직입니다. 시간이 지나면 클럽하우스가 이 선수를 중심으로 돕니다.",
                trait: .anchor
            )
        }
        return Personality(
            title: "차가운 분석가",
            scoutLine: "감정을 빼고 근거로 답합니다. 타자와의 수싸움을 스스로 설계할 줄 아는 머리.",
            trait: .tactician
        )
    }
}
