import Foundation
import SimulationCore

/// 다음 회차를 **다른 투수로** 시작하는 세 갈래.
///
/// 안드로이드 `rebirthPath:` 세 액션의 이식이다. 이름·얼굴·앨범·이어받은 힘은 그대로 두고
/// 프리셋(성장 유형)과 주력 구종만 갈아 끼운다 — 같은 사람이 다른 야구를 하는 것이지
/// 다른 사람이 되는 것이 아니다.
///
/// 구종 배분은 커널이 프리셋마다 이미 답을 갖고 있다(`PitchLearningRules.recommendedSelection`).
/// 여기서 따로 표를 만들면 두 곳이 어긋난다.
public enum RebirthPath: String, CaseIterable, Sendable {
    /// 체력형 · 포심 중심 · 완투를 목표로.
    case endurance
    /// 변화구형 · 슬라이더 중심 · 마무리에 지원.
    case closer
    /// 제구형 · 체인지업 중심 · 효율적인 승부.
    case command

    public var presetID: String {
        switch self {
        case .endurance: "innings_eater"
        case .closer: "breaking_ball_artist"
        case .command: "precision_commander"
        }
    }

    public var repertoire: StartingRepertoireSelection {
        PitchLearningRules.recommendedSelection(presetID: presetID)
    }

    public var primaryPitch: PitchType { repertoire.primaryPitch }

    /// 이 길이 프로에서 겨냥하는 보직. 고교 선택이 프로 목표까지 이어진다.
    public var proRole: ProRole {
        switch self {
        case .closer: .closer
        case .endurance, .command: .starter
        }
    }

    public var preset: PitcherPresetSnapshot? {
        PitcherPresetCatalog.all.first { $0.id == presetID }
    }

    /// 이 프리셋이 실제로 어떤 유형으로 읽히는지는 커널이 능력에서 판단한다.
    public var buildIdentity: PitcherBuildIdentity? {
        preset.map { PitcherBuildRules.identity(for: $0.pitcher) }
    }
}
