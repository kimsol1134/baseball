import SwiftUI
import UIKit

/// Pure completion policy shared by both life-card share buttons and unit tests.
enum ShareCompletion {
    static func countsAsCompleted(completed: Bool, error: Error?) -> Bool {
        completed && error == nil
    }

    /// 대시보드에서 완료·취소·실패를 나눠 보기 위한 결과 라벨.
    ///
    /// 지금까지는 완료만 기록해서(life_card_share_completed) 시트를 열고 닫은 82%가
    /// 어디로 사라졌는지 알 수 없었다 — 취소인지, 확장 앱의 false 리턴인지, 오류인지.
    static func outcome(completed: Bool, error: Error?) -> String {
        if error != nil { return "failed" }
        return completed ? "completed" : "dismissed"
    }
}

/// 시스템 공유가 끝난 방식. 호출자가 이벤트 이름과 속성을 소유한다.
struct ShareFinish {
    let countsAsCompleted: Bool
    /// 사용자가 고른 공유 대상 (예: com.apple.UIKit.activity.CopyToPasteboard). 취소면 nil.
    let activityType: String?
    /// "completed" | "dismissed" | "failed"
    let outcome: String
}

private struct SharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
    let subject: String
}

/// `ShareLink` does not expose the system completion callback. This wrapper keeps the native
/// activity sheet while distinguishing opening it from actually finishing an activity.
private struct ShareSheet: UIViewControllerRepresentable {
    let payload: SharePayload
    let onFinish: (ShareFinish) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: payload.items,
            applicationActivities: nil
        )
        controller.setValue(payload.subject, forKey: "subject")
        controller.completionWithItemsHandler = { activityType, completed, _, error in
            let finish = ShareFinish(
                countsAsCompleted: ShareCompletion.countsAsCompleted(completed: completed, error: error),
                activityType: activityType?.rawValue,
                outcome: ShareCompletion.outcome(completed: completed, error: error)
            )
            DispatchQueue.main.async { onFinish(finish) }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// Reusable button + item-driven sheet. Callers own event names and accessibility identifiers.
struct ActivityShareButton<Label: View>: View {
    let items: [Any]
    let subject: String
    let onTapped: () -> Void
    let onFinished: (ShareFinish) -> Void
    @ViewBuilder let label: () -> Label

    @State private var payload: SharePayload?

    var body: some View {
        Button {
            onTapped()
            payload = SharePayload(items: items, subject: subject)
        } label: {
            label()
        }
        .sheet(item: $payload) { payload in
            ShareSheet(payload: payload) { finish in
                onFinished(finish)
                self.payload = nil
            }
        }
    }
}
