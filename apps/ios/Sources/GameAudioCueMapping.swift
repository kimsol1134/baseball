import Foundation
import SimulationCore

/// 투구 결과 → 소리. 순수 함수라 오디오 엔진 없이 테스트할 수 있고, 세션은 소리를 내지 않고
/// 목록만 내놓는다(화면이 재생한다). 그래서 유닛 테스트가 AVAudioEngine을 켜지 않는다.
enum GameAudioMapping {
    static func cues(for snapshot: PlateAppearanceSnapshot) -> [GameAudioCue] {
        var cues: [GameAudioCue] = [.pitchRelease]
        switch snapshot.outcome {
        case .ball:
            cues += [.gloveCatch, .umpireBall]
        case .calledStrike:
            cues += [.gloveCatch, .umpireStrike]
        case .swingingStrike:
            cues += [.swingMiss, .umpireStrike]
        case .foul:
            cues.append(.batFoul)
        case .inPlayOut, .single, .double, .triple, .homeRun:
            cues.append(.batContact(power: contactPower(snapshot.battedBall)))
        case .hitByPitch:
            cues.append(.batFoul)
        }

        switch snapshot.result {
        case .strikeout:
            // 심판은 삼진을 "스트라이크" 콜에서 멈추지 않는다 — "아웃!"까지 지른다.
            // 이 한 마디가 삼진을 다른 스트라이크와 다른 사건으로 만든다.
            cues.append(.umpireOut)
            cues.append(.crowdCheer)
        case .inPlayOut:
            cues.append(snapshot.runsScored > 0 ? .crowdGroan : .crowdCheer)
        case .walk:
            cues.append(.crowdGroan)
        case .hit:
            cues.append(.crowdGroan)
        case .none:
            if snapshot.runsScored > 0 { cues.append(.crowdGroan) }
        }
        return cues
    }

    /// 타구 세기 0~1. 타격음의 두께를 정한다. 타구가 없으면(헛스윙 등) 중간값.
    static func contactPower(_ battedBall: BattedBall?) -> Double {
        guard let battedBall else { return 0.5 }
        return min(1, max(0, Double(battedBall.contactQuality) / 1_000))
    }

    /// 레버리지 0~1000 → 관중 밀도 0~1. 승부처일수록 스탠드가 두꺼워진다.
    static func crowdIntensity(leverage: Int) -> Double {
        min(1, max(0.15, Double(leverage) / 1_000 * 0.9 + 0.1))
    }

    static func cue(for feedback: MobileCareerStore.FeedbackCue) -> GameAudioCue? {
        switch feedback {
        case .growth: .growth
        case .success: .milestone
        case .setback: .crowdGroan
        case .neutral: nil
        }
    }
}
