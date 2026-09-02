import Foundation
import BaseballIOSDomain

/// 앱 진입 → pendingChallenge → 시작 화면/배너 계약. 저장 중인 커리어는 덮어쓰지 않는다.
enum ChallengeLinkSession {
    struct Open: Equatable {
        var pending: ChallengeLink.Pending?
        var invalid: Bool
        var source: ChallengeLink.Source?
        var valid: Bool
    }

    static func handleOpen(
        url: URL,
        highSchoolNeedsSetup: Bool,
        highSchoolTabVisible: Bool,
        existing: ChallengeLink.Pending?
    ) -> Open {
        let setupOpen = ChallengeLink.setupScreenOpen(
            highSchoolNeedsSetup: highSchoolNeedsSetup,
            highSchoolTabVisible: highSchoolTabVisible
        )
        let result = ChallengeLink.open(url: url, setupScreenOpen: setupOpen)
        if result.valid {
            return Open(
                pending: result.pending,
                invalid: false,
                source: result.source,
                valid: true
            )
        }
        return Open(
            pending: existing,
            invalid: result.showsInvalidNotice,
            source: result.source,
            valid: false
        )
    }

    static func seedInput(from pending: ChallengeLink.Pending) -> String {
        pending.token
    }

    static func consumePendingOnCareerStart(
        pending: ChallengeLink.Pending?
    ) -> ChallengeLink.Pending? {
        _ = pending
        return nil
    }

    static func shareItems(
        seed: String,
        life: Int,
        host: String?,
        resolvedText: String
    ) -> [Any] {
        var items: [Any] = []
        if !resolvedText.isEmpty { items.append(resolvedText) }
        if let url = ChallengeLink.shareURL(seed: seed, life: life, host: host) {
            items.append(url)
        }
        return items
    }
}
