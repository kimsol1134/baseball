import Foundation
import SimulationCore

/// 정산할 회차와 부속 결과. 스토어가 confirmLegacy에서 만들어 준다.
public struct CareerRecap: Identifiable, Equatable {
    public var id: Int { record.lifeNumber }
    public let record: LifeRecord
    /// 걸었던 약속과 이행 여부. 약속 없는 회차는 nil.
    public var pledgeID: String? = nil
    public let pledgeTitle: String?
    public let pledgeAchieved: Bool
    public var pledgeProgress: RunPledgeProgress? = nil
    public var pledgeRewardPermille: Int = 0
    /// 정산에서 사용자가 직접 저장할 수 있는 다음 회차 추천. 자동 선택하지 않는다.
    public var suggestedIntent: NextRunIntent? = nil
    /// 숙적 상대 전적 한 줄(타석이 있을 때만).
    public let rivalLine: String?
    /// 정산 후 야구혼 잔액. 상점에서 쓸 수 있는 돈이다.
    public var soulBalance: Int = 0
    /// 그 잔액이 다음 회차에 자동으로 스며드는 양(상한 적용 후 실제값).
    /// 화면이 이 값을 말하지 않으면 게임이 거짓 영수증을 발행하는 셈이다.
    public var soulAutoApplied: Int = 0

    public init(
        record: LifeRecord,
        pledgeID: String? = nil,
        pledgeTitle: String?,
        pledgeAchieved: Bool,
        pledgeProgress: RunPledgeProgress? = nil,
        pledgeRewardPermille: Int = 0,
        suggestedIntent: NextRunIntent? = nil,
        rivalLine: String?,
        soulBalance: Int = 0,
        soulAutoApplied: Int = 0
    ) {
        self.record = record
        self.pledgeID = pledgeID
        self.pledgeTitle = pledgeTitle
        self.pledgeAchieved = pledgeAchieved
        self.pledgeProgress = pledgeProgress
        self.pledgeRewardPermille = pledgeRewardPermille
        self.suggestedIntent = suggestedIntent
        self.rivalLine = rivalLine
        self.soulBalance = soulBalance
        self.soulAutoApplied = soulAutoApplied
    }
}
