import Foundation
import SimulationCore

/// 타석 경계의 저장용 스냅샷. 공 하나 단위가 아니라 타석 단위라
/// 리트라이 스커밍이 열리지 않고 상태량도 작다.
public struct PitchResumeState: Codable, Equatable {
    public var scenarioID: String
    public var seed: String
    public var batterIndex: Int
    /// 이 등판을 시작했을 때의 최대 상대 타자 수. 없는 옛 체크포인트는 당시 고정값
    /// 4타자로 복원해, 앱 업데이트가 진행 중인 경기의 길이를 바꾸지 않는다.
    public var maximumBatters: Int? = nil
    /// "between"(다음 타자 대기) 또는 "finished"(결과 반영 대기).
    public var stageKind: String
    public var stageMessage: String?
    public var fatigue: Int
    public var gameState: GameStateSnapshot
    public var gameLog: GameLogSnapshot
    public var rivalMemory: RivalMemorySnapshot?
    public var pitches: Int
    public var strikeouts: Int
    public var consecutiveStrikeouts: Int
    public var walks: Int
    public var runsAllowed: Int
    /// 이어하기에서도 안타 수가 살아 있어야 WHIP이 반쪽이 되지 않는다. 옛 저장은 nil이다.
    public var hitsAllowed: Int? = nil
    public var homeRunsAllowed: Int? = nil
    public var expectedDamage: Int
    public var actualDamage: Int
    public var recommendationAccepted: Int
    public var outsRecorded: Int
    public var rivalOutcomes: [PlateAppearanceResult]
    /// 빌드 29 이후 추가 — 옛 복구 스냅샷은 nil이라 0/false로 읽는다.
    public var hitByPitches: Int? = nil
    public var holdCall: Bool? = nil
    /// 빌드 33 이후 — 직접 만든 배합을 고정한 채 앱이 내려가도 같은 사인으로 이어 간다.
    public var selectedPitchType: PitchType? = nil
    public var selectedZone: PitchZone? = nil
    public var selectedIntent: ZoneIntent? = nil
    public var selectedIntensity: PitchIntensity? = nil
    /// 빌드 32 이후 — 복구한 이닝의 정산 화면에서 "투구 기록"이 비면
    /// 복구 자체의 신뢰가 깎인다. 옛 스냅샷은 nil이라 빈 목록으로 읽는다.
    public var pitchLog: [LogLine]? = nil
    /// 수싸움 적중 도입 전 복구본은 nil이며, 빈 목록으로 이어진다.
    public var sequenceMoments: [PitchSequenceMoment]? = nil
    /// 수동 릴리스 숙련 기록 도입 전 복구본은 nil이다. 자동 릴리스의 중립값은 애초에
    /// 이 배열에 들어오지 않으므로, 복구 뒤에도 실제로 손으로 던진 공만 평균에 남는다.
    public var deliveryScores: [Int]? = nil
    /// 이 등판에서 미터 정중앙을 맞힌 횟수. 이어 던지기로 돌아와도 손으로 해낸 것이 남는다.
    /// 이 필드가 없던 저장은 nil이며 0으로 읽는다.
    public var perfectReleases: Int? = nil
    public var pitchLearningUses: [PitchLearningUseReceipt]? = nil
    public var pitchLearningAwardedPlateAppearances: [String]? = nil

    /// PitchLogEntry의 Codable 거울. id(UUID)는 표시용이라 싣지 않는다.
    public struct LogLine: Codable, Equatable {
        public var pitchNumber: Int
        public var call: PitchCall
        public var outcome: PitchOutcome
        public var shortFeedback: String
        public var acceptedRecommendation: Bool
        public var sequenceMoment: PitchSequenceMoment? = nil
        /// 직접 키운 능력 피드백 도입 전 체크포인트는 nil로 읽힌다.
        public var abilityMoment: PitchAbilityKind? = nil

        public init(
            pitchNumber: Int,
            call: PitchCall,
            outcome: PitchOutcome,
            shortFeedback: String,
            acceptedRecommendation: Bool,
            sequenceMoment: PitchSequenceMoment? = nil,
            abilityMoment: PitchAbilityKind? = nil
        ) {
            self.pitchNumber = pitchNumber
            self.call = call
            self.outcome = outcome
            self.shortFeedback = shortFeedback
            self.acceptedRecommendation = acceptedRecommendation
            self.sequenceMoment = sequenceMoment
            self.abilityMoment = abilityMoment
        }
    }

    public init(
        scenarioID: String,
        seed: String,
        batterIndex: Int,
        maximumBatters: Int? = nil,
        stageKind: String,
        stageMessage: String?,
        fatigue: Int,
        gameState: GameStateSnapshot,
        gameLog: GameLogSnapshot,
        rivalMemory: RivalMemorySnapshot?,
        pitches: Int,
        strikeouts: Int,
        consecutiveStrikeouts: Int,
        walks: Int,
        runsAllowed: Int,
        hitsAllowed: Int? = nil,
        homeRunsAllowed: Int? = nil,
        expectedDamage: Int,
        actualDamage: Int,
        recommendationAccepted: Int,
        outsRecorded: Int,
        rivalOutcomes: [PlateAppearanceResult],
        hitByPitches: Int? = nil,
        holdCall: Bool? = nil,
        selectedPitchType: PitchType? = nil,
        selectedZone: PitchZone? = nil,
        selectedIntent: ZoneIntent? = nil,
        selectedIntensity: PitchIntensity? = nil,
        pitchLog: [LogLine]? = nil,
        sequenceMoments: [PitchSequenceMoment]? = nil,
        deliveryScores: [Int]? = nil,
        perfectReleases: Int? = nil,
        pitchLearningUses: [PitchLearningUseReceipt]? = nil,
        pitchLearningAwardedPlateAppearances: [String]? = nil
    ) {
        self.scenarioID = scenarioID
        self.seed = seed
        self.batterIndex = batterIndex
        self.maximumBatters = maximumBatters
        self.stageKind = stageKind
        self.stageMessage = stageMessage
        self.fatigue = fatigue
        self.gameState = gameState
        self.gameLog = gameLog
        self.rivalMemory = rivalMemory
        self.pitches = pitches
        self.strikeouts = strikeouts
        self.consecutiveStrikeouts = consecutiveStrikeouts
        self.walks = walks
        self.runsAllowed = runsAllowed
        self.hitsAllowed = hitsAllowed
        self.homeRunsAllowed = homeRunsAllowed
        self.expectedDamage = expectedDamage
        self.actualDamage = actualDamage
        self.recommendationAccepted = recommendationAccepted
        self.outsRecorded = outsRecorded
        self.rivalOutcomes = rivalOutcomes
        self.hitByPitches = hitByPitches
        self.holdCall = holdCall
        self.selectedPitchType = selectedPitchType
        self.selectedZone = selectedZone
        self.selectedIntent = selectedIntent
        self.selectedIntensity = selectedIntensity
        self.pitchLog = pitchLog
        self.sequenceMoments = sequenceMoments
        self.deliveryScores = deliveryScores
        self.perfectReleases = perfectReleases
        self.pitchLearningUses = pitchLearningUses
        self.pitchLearningAwardedPlateAppearances = pitchLearningAwardedPlateAppearances
    }
}
