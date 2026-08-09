import SwiftUI
import UIKit

/// Pure completion policy shared by both life-card share buttons and unit tests.
enum ShareCompletion {
    static func countsAsCompleted(completed: Bool, error: Error?) -> Bool {
        completed && error == nil
    }
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
    let onCompletion: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: payload.items,
            applicationActivities: nil
        )
        controller.setValue(payload.subject, forKey: "subject")
        controller.completionWithItemsHandler = { _, completed, _, error in
            let shouldCount = ShareCompletion.countsAsCompleted(completed: completed, error: error)
            DispatchQueue.main.async { onCompletion(shouldCount) }
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
    let onCompleted: () -> Void
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
            ShareSheet(payload: payload) { completed in
                if completed { onCompleted() }
                self.payload = nil
            }
        }
    }
}
