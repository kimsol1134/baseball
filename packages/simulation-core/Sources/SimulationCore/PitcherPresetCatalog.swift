public struct PitcherPresetSnapshot: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let tagline: String
    public let strengths: [String]
    public let tradeoff: String
    public let pitcher: PitcherSnapshot

    public init(
        id: String,
        name: String,
        tagline: String,
        strengths: [String],
        tradeoff: String,
        pitcher: PitcherSnapshot
    ) {
        self.id = id
        self.name = name
        self.tagline = tagline
        self.strengths = strengths
        self.tradeoff = tradeoff
        self.pitcher = pitcher
    }
}

public enum PitcherPresetCatalog {
    public static let all: [PitcherPresetSnapshot] = [
        PitcherPresetSnapshot(
            id: "power_prospect",
            name: "강속구 원석",
            tagline: "빠른 포심으로 타자를 밀어붙입니다.",
            strengths: ["직구의 위력", "최고 구속", "헛스윙"],
            tradeoff: "전력투구의 피로와 제구 난도가 큽니다.",
            pitcher: PitcherSnapshot(
                id: "pitcher-power",
                name: "민서준",
                stuff: 72,
                command: 44,
                movement: 52,
                stamina: 52,
                pitchProfiles: [
                    profile(.fourSeam, .primary, 1_525, 48, 45, 58, 74, 62, 2),
                    profile(.slider, .secondary, 1_345, 43, 42, 57, 61, 54, 2),
                    profile(.curveball, .secondary, 1_205, 40, 39, 54, 50, 50, 2),
                    profile(.changeup, .development, 1_375, 34, 33, 43, 40, 43, 2)
                ]
            )
        ),
        PitcherPresetSnapshot(
            id: "precision_commander",
            name: "정교한 제구형",
            tagline: "스트라이크존 끝에 꾸준히 던집니다.",
            strengths: ["제구", "코스 공략", "볼넷 억제"],
            tradeoff: "삼진을 잡을 강한 결정구가 부족합니다.",
            pitcher: PitcherSnapshot(
                id: "pitcher-command",
                name: "고태윤",
                stuff: 54,
                command: 74,
                movement: 53,
                stamina: 61,
                pitchProfiles: [
                    profile(.fourSeam, .primary, 1_445, 76, 75, 51, 52, 58, 1),
                    profile(.slider, .secondary, 1_285, 67, 70, 57, 56, 59, 1),
                    profile(.curveball, .development, 1_160, 48, 51, 53, 45, 48, 2),
                    profile(.changeup, .secondary, 1_310, 70, 72, 55, 55, 63, 1)
                ]
            )
        ),
        PitcherPresetSnapshot(
            id: "breaking_ball_artist",
            name: "변화구 아티스트",
            tagline: "속도와 움직임이 다른 변화구로 타자의 타이밍을 빼앗습니다.",
            strengths: ["변화구 움직임", "헛스윙", "빗맞은 타구"],
            tradeoff: "직구 구속과 장기 체력은 평범합니다.",
            pitcher: PitcherSnapshot(
                id: "pitcher-artist",
                name: "진서율",
                stuff: 59,
                command: 54,
                movement: 74,
                stamina: 49,
                pitchProfiles: [
                    profile(.fourSeam, .secondary, 1_425, 56, 53, 48, 49, 52, 1),
                    profile(.slider, .primary, 1_305, 58, 61, 78, 76, 73, 2),
                    profile(.curveball, .secondary, 1_175, 55, 59, 76, 69, 76, 2),
                    profile(.changeup, .development, 1_295, 43, 46, 63, 58, 64, 2)
                ]
            )
        ),
        PitcherPresetSnapshot(
            id: "innings_eater",
            name: "체력형 선발",
            tagline: "큰 기복 없이 많은 공을 소화합니다.",
            strengths: ["체력", "피로가 천천히 쌓임", "꾸준한 제구"],
            tradeoff: "타자를 압도하는 헛스윙 능력은 낮습니다.",
            pitcher: PitcherSnapshot(
                id: "pitcher-stamina",
                name: "도하람",
                stuff: 53,
                command: 62,
                movement: 52,
                stamina: 78,
                pitchProfiles: [
                    profile(.fourSeam, .primary, 1_435, 65, 63, 50, 49, 57, 0),
                    profile(.slider, .secondary, 1_275, 60, 61, 54, 50, 58, 1),
                    profile(.curveball, .development, 1_150, 51, 50, 50, 42, 50, 1),
                    profile(.changeup, .secondary, 1_300, 63, 64, 57, 51, 65, 0)
                ]
            )
        )
    ]

    private static func profile(
        _ pitchType: PitchType,
        _ role: PitchUsageRole,
        _ velocityTenthsKPH: Int,
        _ control: Int,
        _ command: Int,
        _ movement: Int,
        _ whiff: Int,
        _ weakContact: Int,
        _ fatigueCost: Int
    ) -> PitchProfileSnapshot {
        PitchProfileSnapshot(
            pitchType: pitchType,
            role: role,
            velocityTenthsKPH: velocityTenthsKPH,
            control: control,
            command: command,
            movement: movement,
            whiff: whiff,
            weakContact: weakContact,
            fatigueCost: fatigueCost
        )
    }
}
