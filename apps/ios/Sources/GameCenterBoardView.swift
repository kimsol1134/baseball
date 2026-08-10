import SwiftUI
import GameKit

/// Game Center 리더보드를 앱 안에서 연다.
///
/// "순위는 Game Center에서"라고 적어 놓고 앱 밖으로 내보내면 대부분 안 간다 —
/// 오늘의 이닝의 경쟁 감정은 점수 화면에서 한 탭 안에 있어야 산다(2차 패널 P1).
struct GameCenterBoardView: UIViewControllerRepresentable {
    let leaderboardID: String
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> GKGameCenterViewController {
        let controller = GKGameCenterViewController(
            leaderboardID: leaderboardID, playerScope: .global, timeScope: .today
        )
        controller.gameCenterDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: GKGameCenterViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onDismiss: onDismiss) }

    final class Coordinator: NSObject, @preconcurrency GKGameCenterControllerDelegate {
        let onDismiss: () -> Void
        init(onDismiss: @escaping () -> Void) { self.onDismiss = onDismiss }
        @MainActor
        func gameCenterViewControllerDidFinish(_ controller: GKGameCenterViewController) {
            controller.dismiss(animated: true)
            onDismiss()
        }
    }
}
