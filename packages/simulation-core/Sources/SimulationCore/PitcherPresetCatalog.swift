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
                stuff: 62,
                command: 42,
                movement: 48,
                stamina: 50,
                pitchProfiles: [
                    profile(.fourSeam, .primary, 1_430, 46, 43, 54, 64, 57, 2),
                    profile(.slider, .secondary, 1_290, 41, 40, 54, 56, 51, 2),
                    profile(.curveball, .secondary, 1_150, 38, 37, 50, 46, 47, 2),
                    profile(.changeup, .development, 1_290, 34, 33, 42, 39, 42, 2)
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
                stuff: 48,
                command: 63,
                movement: 49,
                stamina: 55,
                pitchProfiles: [
                    profile(.fourSeam, .primary, 1_390, 65, 64, 48, 47, 54, 1),
                    profile(.slider, .secondary, 1_250, 59, 61, 53, 51, 55, 1),
                    profile(.curveball, .development, 1_125, 45, 48, 50, 42, 45, 2),
                    profile(.changeup, .secondary, 1_260, 61, 63, 52, 50, 59, 1)
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
                stuff: 51,
                command: 49,
                movement: 64,
                stamina: 47,
                pitchProfiles: [
                    profile(.fourSeam, .secondary, 1_400, 52, 49, 46, 45, 49, 1),
                    profile(.slider, .primary, 1_270, 55, 57, 66, 63, 64, 2),
                    profile(.curveball, .secondary, 1_135, 52, 55, 65, 58, 66, 2),
                    profile(.changeup, .development, 1_255, 41, 43, 57, 52, 58, 2)
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
                stuff: 49,
                command: 54,
                movement: 48,
                stamina: 64,
                pitchProfiles: [
                    profile(.fourSeam, .primary, 1_405, 57, 55, 47, 44, 54, 0),
                    profile(.slider, .secondary, 1_250, 54, 55, 50, 45, 54, 1),
                    profile(.curveball, .development, 1_120, 47, 46, 47, 38, 46, 1),
                    profile(.changeup, .secondary, 1_260, 56, 57, 52, 46, 60, 0)
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
