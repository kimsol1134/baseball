import Foundation
import BaseballIOSPersistence

/// Features가 Persistence의 SaveSync를 직접 보지 않게 하는 기동 창구.
enum CareerSaveSync {
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
