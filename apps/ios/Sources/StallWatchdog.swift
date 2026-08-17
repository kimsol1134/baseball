import SwiftUI

/// 잠깐만 보여야 하는 로딩·대기 화면이 기준 시간을 넘겨 남아 있으면 한 번 기록한다.
///
/// 1.0.2~1.0.4의 검은 화면 리뷰는 크래시 리포트에 전혀 잡히지 않았다 — 앱이 죽지 않고
/// 멈춰 있었기 때문이다. 전환 애니메이션(PhaseCurtain)을 제거해 증상은 줄었지만,
/// 재발 여부는 화면이 스스로 신고해야만 대시보드에서 보인다. 뷰가 기준 시간 안에
/// 사라지면 `.task`가 취소되어 아무것도 기록하지 않는다.
struct StallWatchdogModifier: ViewModifier {
    let context: String
    var threshold: TimeInterval = 3

    func body(content: Content) -> some View {
        content.task {
            try? await Task.sleep(nanoseconds: UInt64(threshold * 1_000_000_000))
            guard !Task.isCancelled else { return }
            GameAnalytics.log(.screenStallDetected, [
                "context": context,
                "threshold_seconds": Int(threshold),
            ])
        }
    }
}

extension View {
    /// 이 뷰가 `threshold`초 이상 화면에 남으면 멈춤으로 기록한다.
    func stallWatchdog(_ context: String, threshold: TimeInterval = 3) -> some View {
        modifier(StallWatchdogModifier(context: context, threshold: threshold))
    }
}
