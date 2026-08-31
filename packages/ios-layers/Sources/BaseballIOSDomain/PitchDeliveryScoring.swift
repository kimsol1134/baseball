import Foundation
import SimulationCore

public enum PitchDeliveryScoring {
    /// 이번 등판의 릴리스 점수. 타이밍과 조준의 평균이고, 중립(자동 릴리스)은 세지 않는다.
    public static func score(_ delivery: PitchDelivery) -> Int? {
        guard !delivery.isNeutral else { return nil }
        return (delivery.releaseAccuracy + delivery.aimAccuracy) / 2
    }
}
