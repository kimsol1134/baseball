import Foundation
import BaseballIOSPersistence

/// Features가 Persistence의 SaveSync를 직접 보지 않게 하는 기동 창구.
enum CareerSaveSync {
#if DEBUG
    /// Dedicated local files for UI regression fixtures. No production cloud keys are touched.
    static func isolatedUITestStore(key: String) -> SaveSync {
        SaveSync(key: "ui-review-\(key)", store: UITestRemoteStore())
    }

    private final class UITestRemoteStore: SaveSyncRemoteStoring {
        func data(forKey key: String) -> Data? { nil }
        func set(_ value: Any?, forKey key: String) {}
        func removeObject(forKey key: String) {}
        func synchronize() -> Bool { true }
    }
#endif
    static func prime() {
        SaveSync.prime()
    }

    @discardableResult
    static func observeRemoteChanges(
        _ handler: @escaping @MainActor @Sendable () -> Void
    ) -> NSObjectProtocol {
        SaveSync.observeRemoteChanges(handler)
    }
}
