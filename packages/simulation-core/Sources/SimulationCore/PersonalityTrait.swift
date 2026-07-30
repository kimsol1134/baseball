import Foundation

/// 기질 특성 — 성격이 마운드 위의 메커니즘이 되는 자리.
///
/// 성격(선택의 누적)마다 발동 조건이 다른 특성 하나가 붙는다. 발동은 화면에
/// 배지로 공개된다 — 숨은 보정은 이 게임에 없다. 효과는 스카우팅 보정(−36..+32)
/// 보다 작게 시작한다. 특성은 정체성이지 필살기가 아니다.
public enum PersonalityTrait: String, Codable, CaseIterable, Sendable {
    /// 불같은 승부사 — 2스트라이크, 끝내러 가는 공.
    case closer
    /// 조용한 버팀목 — 주자를 등에 업었을 때.
    case anchor
    /// 차가운 분석가 — 수싸움이 길어질수록.
    case tactician
    /// 유연한 중심 — 타석의 첫 공을 지배한다.
    case opener

    public var title: String {
        switch self {
        case .closer: "결정구"
        case .anchor: "위기의 어깨"
        case .tactician: "수싸움"
        case .opener: "초구 장악"
        }
    }

    /// 발동 조건 설명. 배지와 특성 안내가 같은 문장을 쓴다.
    public var activationLine: String {
        switch self {
        case .closer: "2스트라이크에서 공이 무거워집니다"
        case .anchor: "주자가 있을 때 흔들리지 않습니다"
        case .tactician: "5구째부터 수싸움을 지배합니다"
        case .opener: "타석의 첫 공이 날카롭습니다"
        }
    }

    /// 이 공에서 발동하는가. 커널이 이미 아는 값만 쓴다 — 새 난수 없음.
    public func fires(context: PlateAppearanceContext, runners: BaserunnerStateSnapshot?) -> Bool {
        switch self {
        case .closer: return context.strikes == 2
        case .anchor: return runners.map { $0.firstOccupied || $0.secondOccupied || $0.thirdOccupied } ?? false
        case .tactician: return context.pitchNumber >= 5
        case .opener: return context.pitchNumber == 1
        }
    }

    /// 타자 콘택트 보정(음수 = 투수 유리). 스카우팅(−30급)보다 작다.
    public var contactAdjustment: Int {
        switch self {
        case .closer: -14
        case .anchor: -12
        case .tactician: -16
        case .opener: -10
        }
    }

    /// 타구 질 보정(음수 = 약한 타구).
    public var qualityAdjustment: Int {
        switch self {
        case .closer: -12
        case .anchor: -10
        case .tactician: -12
        case .opener: -10
        }
    }
}
