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

struct PitcherBalanceMigration {
    let pitcher: PitcherSnapshot
    let ratingOffsets: [TrainingFocus: Int]
}

public enum PitcherPresetCatalog {
    public static let balanceVersion = 4

    // v3 저장본을 새 공통 능력 예산으로 옮길 때, 이미 얻은 성장분과 구종 성장을
    // 한 점도 잃지 않도록 직전 카탈로그를 그대로 보존한다.
    static let balanceV3: [PitcherPresetSnapshot] = [
        PitcherPresetSnapshot(
            id: "power_prospect",
            name: "강속구 원석",
            tagline: "빠른 포심으로 타자를 밀어붙입니다.",
            strengths: ["직구의 위력", "최고 구속", "헛스윙"],
            tradeoff: "전력투구의 피로와 제구 난도가 큽니다.",
            pitcher: PitcherSnapshot(
                id: "pitcher-power",
                name: "민서준",
                stuff: 42,
                command: 34,
                movement: 36,
                stamina: 38,
                pitchProfiles: [
                    profile(.fourSeam, .primary, 1_410, 35, 32, 37, 45, 41, 2),
                    profile(.slider, .secondary, 1_240, 31, 29, 40, 41, 38, 2),
                    profile(.curveball, .secondary, 1_090, 27, 26, 38, 33, 35, 2),
                    profile(.changeup, .development, 1_210, 23, 22, 31, 28, 31, 2)
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
                stuff: 36,
                command: 43,
                movement: 37,
                stamina: 39,
                pitchProfiles: [
                    profile(.fourSeam, .primary, 1_340, 45, 44, 34, 33, 39, 1),
                    profile(.slider, .secondary, 1_190, 41, 42, 39, 37, 40, 1),
                    profile(.curveball, .development, 1_060, 31, 33, 37, 29, 34, 2),
                    profile(.changeup, .secondary, 1_210, 43, 44, 39, 36, 42, 1)
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
                stuff: 37,
                command: 36,
                movement: 44,
                stamina: 36,
                pitchProfiles: [
                    profile(.fourSeam, .secondary, 1_360, 38, 35, 34, 33, 37, 1),
                    profile(.slider, .primary, 1_220, 39, 40, 46, 44, 45, 2),
                    profile(.curveball, .secondary, 1_080, 37, 39, 45, 41, 46, 2),
                    profile(.changeup, .development, 1_200, 31, 33, 41, 38, 41, 2)
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
                stuff: 36,
                command: 39,
                movement: 36,
                stamina: 44,
                pitchProfiles: [
                    profile(.fourSeam, .primary, 1_370, 41, 40, 34, 32, 39, 0),
                    profile(.slider, .secondary, 1_200, 38, 40, 37, 33, 39, 1),
                    profile(.curveball, .development, 1_060, 33, 32, 35, 28, 34, 1),
                    profile(.changeup, .secondary, 1_210, 40, 41, 39, 34, 43, 0)
                ]
            )
        )
    ]

    /// 네 시작 유형은 강점의 위치만 다르고 네 능력 합은 모두 150이다.
    ///
    /// v3에서는 제구형·변화구형·체력형이 3~5점을 더 들고 시작해 같은 노력으로도
    /// 스카우트 총점이 먼저 올랐다. 강점은 그대로 두고 비주력 능력만 내려 선택 예산을 맞춘다.
    public static let all: [PitcherPresetSnapshot] = balanceV3.map { preset in
        let pitcher = preset.pitcher
        let ratings: (stuff: Int, command: Int, movement: Int, stamina: Int) = switch preset.id {
        case "precision_commander": (34, 43, 35, 38)
        case "breaking_ball_artist": (37, 34, 44, 35)
        // 체력형이 제구형보다 볼넷까지 적었던 조합(34/38/34/44)을 분리한다. 같은 150점
        // 예산 안에서 오래 버티지만 노린 곳에 던지는 힘은 양보하는 청사진이다.
        case "innings_eater": (37, 32, 37, 44)
        default: (pitcher.stuff, pitcher.command, pitcher.movement, pitcher.stamina)
        }
        let profiles = pitcher.pitchProfiles?.map { profile in
            guard preset.id == "innings_eater" else { return profile }
            return PitchProfileSnapshot(
                pitchType: profile.pitchType,
                role: profile.role,
                velocityTenthsKPH: profile.velocityTenthsKPH,
                control: max(20, profile.control - 4),
                command: max(20, profile.command - 4),
                movement: profile.movement,
                whiff: profile.whiff,
                weakContact: profile.weakContact,
                fatigueCost: profile.fatigueCost
            )
        }
        return PitcherPresetSnapshot(
            id: preset.id,
            name: preset.name,
            tagline: preset.tagline,
            strengths: preset.strengths,
            tradeoff: preset.id == "innings_eater"
                ? "긴 이닝을 버티지만 정밀 제구와 초반 압도력은 낮습니다."
                : preset.tradeoff,
            pitcher: PitcherSnapshot(
                id: pitcher.id,
                name: pitcher.name,
                stuff: ratings.stuff,
                command: ratings.command,
                movement: ratings.movement,
                stamina: ratings.stamina,
                pitchProfiles: profiles,
                throwingHand: pitcher.throwingHand
            )
        )
    }

    // Kept to translate v2 saves while preserving every point earned after creation.
    static let balanceV2: [PitcherPresetSnapshot] = [
        PitcherPresetSnapshot(
            id: "power_prospect", name: "강속구 원석", tagline: "", strengths: [], tradeoff: "",
            pitcher: PitcherSnapshot(id: "pitcher-power", name: "민서준", stuff: 62, command: 42, movement: 48, stamina: 50,
                pitchProfiles: [
                    profile(.fourSeam, .primary, 1_430, 46, 43, 54, 64, 57, 2),
                    profile(.slider, .secondary, 1_290, 41, 40, 54, 56, 51, 2),
                    profile(.curveball, .secondary, 1_150, 38, 37, 50, 46, 47, 2),
                    profile(.changeup, .development, 1_290, 34, 33, 42, 39, 42, 2)
                ])
        ),
        PitcherPresetSnapshot(
            id: "precision_commander", name: "정교한 제구형", tagline: "", strengths: [], tradeoff: "",
            pitcher: PitcherSnapshot(id: "pitcher-command", name: "고태윤", stuff: 48, command: 63, movement: 49, stamina: 55,
                pitchProfiles: [
                    profile(.fourSeam, .primary, 1_390, 65, 64, 48, 47, 54, 1),
                    profile(.slider, .secondary, 1_250, 59, 61, 53, 51, 55, 1),
                    profile(.curveball, .development, 1_125, 45, 48, 50, 42, 45, 2),
                    profile(.changeup, .secondary, 1_260, 61, 63, 52, 50, 59, 1)
                ])
        ),
        PitcherPresetSnapshot(
            id: "breaking_ball_artist", name: "변화구 아티스트", tagline: "", strengths: [], tradeoff: "",
            pitcher: PitcherSnapshot(id: "pitcher-artist", name: "진서율", stuff: 51, command: 49, movement: 64, stamina: 47,
                pitchProfiles: [
                    profile(.fourSeam, .secondary, 1_400, 52, 49, 46, 45, 49, 1),
                    profile(.slider, .primary, 1_270, 55, 57, 66, 63, 64, 2),
                    profile(.curveball, .secondary, 1_135, 52, 55, 65, 58, 66, 2),
                    profile(.changeup, .development, 1_255, 41, 43, 57, 52, 58, 2)
                ])
        ),
        PitcherPresetSnapshot(
            id: "innings_eater", name: "체력형 선발", tagline: "", strengths: [], tradeoff: "",
            pitcher: PitcherSnapshot(id: "pitcher-stamina", name: "도하람", stuff: 49, command: 54, movement: 48, stamina: 64,
                pitchProfiles: [
                    profile(.fourSeam, .primary, 1_405, 57, 55, 47, 44, 54, 0),
                    profile(.slider, .secondary, 1_250, 54, 55, 50, 45, 54, 1),
                    profile(.curveball, .development, 1_120, 47, 46, 47, 38, 46, 1),
                    profile(.changeup, .secondary, 1_260, 56, 57, 52, 46, 60, 0)
                ])
        )
    ]

    // Kept only to translate pre-v2 saves while preserving every point earned after creation.
    static let balanceV1: [PitcherPresetSnapshot] = [
        PitcherPresetSnapshot(
            id: "power_prospect", name: "강속구 원석", tagline: "", strengths: [], tradeoff: "",
            pitcher: PitcherSnapshot(id: "pitcher-power", name: "민서준", stuff: 72, command: 44, movement: 52, stamina: 52,
                pitchProfiles: [
                    profile(.fourSeam, .primary, 1_525, 48, 45, 58, 74, 62, 2),
                    profile(.slider, .secondary, 1_345, 43, 42, 57, 61, 54, 2),
                    profile(.curveball, .secondary, 1_205, 40, 39, 54, 50, 50, 2),
                    profile(.changeup, .development, 1_375, 34, 33, 43, 40, 43, 2)
                ])
        ),
        PitcherPresetSnapshot(
            id: "precision_commander", name: "정교한 제구형", tagline: "", strengths: [], tradeoff: "",
            pitcher: PitcherSnapshot(id: "pitcher-command", name: "고태윤", stuff: 54, command: 74, movement: 53, stamina: 61,
                pitchProfiles: [
                    profile(.fourSeam, .primary, 1_445, 76, 75, 51, 52, 58, 1),
                    profile(.slider, .secondary, 1_285, 67, 70, 57, 56, 59, 1),
                    profile(.curveball, .development, 1_160, 48, 51, 53, 45, 48, 2),
                    profile(.changeup, .secondary, 1_310, 70, 72, 55, 55, 63, 1)
                ])
        ),
        PitcherPresetSnapshot(
            id: "breaking_ball_artist", name: "변화구 아티스트", tagline: "", strengths: [], tradeoff: "",
            pitcher: PitcherSnapshot(id: "pitcher-artist", name: "진서율", stuff: 59, command: 54, movement: 74, stamina: 49,
                pitchProfiles: [
                    profile(.fourSeam, .secondary, 1_425, 56, 53, 48, 49, 52, 1),
                    profile(.slider, .primary, 1_305, 58, 61, 78, 76, 73, 2),
                    profile(.curveball, .secondary, 1_175, 55, 59, 76, 69, 76, 2),
                    profile(.changeup, .development, 1_295, 43, 46, 63, 58, 64, 2)
                ])
        ),
        PitcherPresetSnapshot(
            id: "innings_eater", name: "체력형 선발", tagline: "", strengths: [], tradeoff: "",
            pitcher: PitcherSnapshot(id: "pitcher-stamina", name: "도하람", stuff: 53, command: 62, movement: 52, stamina: 78,
                pitchProfiles: [
                    profile(.fourSeam, .primary, 1_435, 65, 63, 50, 49, 57, 0),
                    profile(.slider, .secondary, 1_275, 60, 61, 54, 50, 58, 1),
                    profile(.curveball, .development, 1_150, 51, 50, 50, 42, 50, 1),
                    profile(.changeup, .secondary, 1_300, 63, 64, 57, 51, 65, 0)
                ])
        )
    ]

    static func migrate(
        _ pitcher: PitcherSnapshot,
        fromVersion: Int?,
        targetVersion: Int = balanceVersion
    ) -> PitcherBalanceMigration? {
        let version = fromVersion ?? 1
        guard version < targetVersion, (3...balanceVersion).contains(targetVersion) else { return nil }
        let sourceCatalog = version <= 1 ? balanceV1 : version == 2 ? balanceV2 : balanceV3
        let targetCatalog = targetVersion == 3 ? balanceV3 : all
        guard let source = sourceCatalog.first(where: { $0.pitcher.id == pitcher.id })?.pitcher,
              let calibrated = targetCatalog.first(where: { $0.pitcher.id == pitcher.id })?.pitcher else { return nil }
        let offsets: [TrainingFocus: Int] = [
            .velocity: calibrated.stuff - source.stuff,
            .command: calibrated.command - source.command,
            .breakingBall: calibrated.movement - source.movement,
            .stamina: calibrated.stamina - source.stamina,
            .recovery: calibrated.stamina - source.stamina,
            .gamePlanning: calibrated.command - source.command
        ]
        let profiles = pitcher.pitchProfiles?.map { current -> PitchProfileSnapshot in
            guard let old = source.profile(for: current.pitchType),
                  let new = calibrated.profile(for: current.pitchType) else { return current }
            return PitchProfileSnapshot(
                pitchType: current.pitchType, role: new.role,
                velocityTenthsKPH: clamp(new.velocityTenthsKPH + current.velocityTenthsKPH - old.velocityTenthsKPH, 1_000, 1_700),
                control: clamp(new.control + current.control - old.control, 20, 80),
                command: clamp(new.command + current.command - old.command, 20, 80),
                movement: clamp(new.movement + current.movement - old.movement, 20, 80),
                whiff: clamp(new.whiff + current.whiff - old.whiff, 20, 80),
                weakContact: clamp(new.weakContact + current.weakContact - old.weakContact, 20, 80),
                fatigueCost: clamp(new.fatigueCost + current.fatigueCost - old.fatigueCost, 0, 20)
            )
        }
        return PitcherBalanceMigration(
            pitcher: PitcherSnapshot(
                id: pitcher.id, name: pitcher.name,
                stuff: clamp(pitcher.stuff + calibrated.stuff - source.stuff, 20, 80),
                command: clamp(pitcher.command + calibrated.command - source.command, 20, 80),
                movement: clamp(pitcher.movement + calibrated.movement - source.movement, 20, 80),
                stamina: clamp(pitcher.stamina + calibrated.stamina - source.stamina, 20, 80),
                pitchProfiles: profiles,
                throwingHand: pitcher.throwingHand
            ),
            ratingOffsets: offsets
        )
    }

    static func inferredLegacyVersion(for pitcher: PitcherSnapshot) -> Int {
        let candidates = [(1, balanceV1), (2, balanceV2), (3, balanceV3)]
        return candidates.min { lhs, rhs in
            distance(from: pitcher, to: lhs.1) < distance(from: pitcher, to: rhs.1)
        }?.0 ?? 2
    }

    private static func distance(from pitcher: PitcherSnapshot, to catalog: [PitcherPresetSnapshot]) -> Int {
        guard let baseline = catalog.first(where: { $0.pitcher.id == pitcher.id })?.pitcher else { return .max }
        let ratingDistance = abs(pitcher.stuff - baseline.stuff) + abs(pitcher.command - baseline.command)
            + abs(pitcher.movement - baseline.movement) + abs(pitcher.stamina - baseline.stamina)
        let velocityDistance = zip(pitcher.pitchProfiles ?? [], baseline.pitchProfiles ?? []).reduce(0) {
            $0 + abs($1.0.velocityTenthsKPH - $1.1.velocityTenthsKPH) / 5
        }
        return ratingDistance + velocityDistance
    }

    private static func clamp(_ value: Int, _ low: Int, _ high: Int) -> Int {
        min(high, max(low, value))
    }

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
