import SwiftUI
import GameKit

/// Game Center 리더보드를 앱 안에서 연다.
///
/// **SwiftUI `.sheet`에 싣지 않는다.** `GKGameCenterViewController`는 자기 표시 스택을
/// 직접 관리하는 시스템 화면이다. `UIViewControllerRepresentable`로 감싸 시트에 얹으면
/// 시트가 만든 컨테이너와 충돌해 내용이 비고 탭이 먹지 않는다. 가장 위 뷰 컨트롤러에서
/// 직접 present 하는 것이 애플이 의도한 경로다.
enum GameCenterBoard {
    /// 리더보드를 연다. 인증이 안 돼 있으면 아무 일도 하지 않고 false를 돌려준다 —
    /// 화면은 그 값으로 "왜 안 열리는지"를 대신 말할 수 있다.
    @MainActor
    @discardableResult
    static func present(leaderboardID: String, onDismiss: @escaping () -> Void = {}) -> Bool {
        guard GKLocalPlayer.local.isAuthenticated, let presenter = topViewController() else {
            return false
        }
        let controller = GKGameCenterViewController(
            leaderboardID: leaderboardID, playerScope: .global, timeScope: .today
        )
        let delegate = Delegate(onDismiss: onDismiss)
        controller.gameCenterDelegate = delegate
        // 델리게이트를 지역 변수로만 두면 present 직후 해제돼 "완료"가 아무 일도 하지
        // 않는 화면이 된다(닫히지 않는 리더보드). 컨트롤러 수명에 묶어 둔다.
        objc_setAssociatedObject(controller, &Delegate.key, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        presenter.present(controller, animated: true)
        return true
    }

    /// Game Center 로그인 화면. 이미 무언가 떠 있으면 그 위에 얹지 않고 조용히 넘긴다 —
    /// 승부 도중에 시스템 시트가 끼어들면 이닝이 끊긴다. 다음 실행에서 다시 물어본다.
    @MainActor
    static func presentAuthentication(_ controller: UIViewController) {
        guard let presenter = topViewController(), presenter.presentedViewController == nil else { return }
        presenter.present(controller, animated: true)
    }

    @MainActor
    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.first { $0.activationState == .foregroundActive }?.keyWindow
            ?? scenes.first?.keyWindow
        var top = window?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }

    private final class Delegate: NSObject, @preconcurrency GKGameCenterControllerDelegate {
        nonisolated(unsafe) static var key: UInt8 = 0
        let onDismiss: () -> Void
        init(onDismiss: @escaping () -> Void) { self.onDismiss = onDismiss }

        @MainActor
        func gameCenterViewControllerDidFinish(_ controller: GKGameCenterViewController) {
            controller.dismiss(animated: true) { self.onDismiss() }
        }
    }
}
