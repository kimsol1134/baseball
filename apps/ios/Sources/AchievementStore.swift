import Foundation
import GameKit
import Observation

/// 업적 보관과 Game Center 연동.
///
/// 원칙(DOC-IOS-TOP §5.2): **Game Center가 없어도 앱이 정상 동작한다.** 인증 실패는 조용히
/// 무시하고, 달성 기록은 로컬이 원본이다. 그래야 App Store Connect 설정 전이나 오프라인에서도
/// 업적 화면이 살아 있다.
@MainActor
@Observable
final class AchievementStore {
    static let shared = AchievementStore()

    private(set) var progress = AchievementProgress()
    /// 방금 달성해 아직 사용자에게 보여 주지 않은 것.
    var freshlyUnlocked: [Achievement] = []
    private(set) var isGameCenterAuthenticated = false

    private static let storageKey = "baseball.achievements.v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(AchievementProgress.self, from: data) {
            progress = decoded
        }
    }

    /// 조용히 시도한다. 실패해도 앱은 그대로 돌아간다.
    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] _, _ in
            Task { @MainActor in
                self?.isGameCenterAuthenticated = GKLocalPlayer.local.isAuthenticated
                if GKLocalPlayer.local.isAuthenticated { self?.syncUnlockedToGameCenter() }
            }
        }
    }

    func record(_ achievements: [Achievement]) {
        guard !achievements.isEmpty else { return }
        let fresh = progress.unlock(achievements)
        guard !fresh.isEmpty else { return }
        freshlyUnlocked.append(contentsOf: fresh)
        persist()
        report(fresh)
    }

    func acknowledge() {
        freshlyUnlocked.removeAll()
    }

    func submit(_ scores: [Leaderboard: Int]) {
        guard isGameCenterAuthenticated, !scores.isEmpty else { return }
        for (board, value) in scores {
            GKLeaderboard.submitScore(
                value,
                context: 0,
                player: GKLocalPlayer.local,
                leaderboardIDs: [board.gameCenterID]
            ) { _ in }
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private func syncUnlockedToGameCenter() {
        report(Achievement.allCases.filter { progress.has($0) })
    }

    private func report(_ achievements: [Achievement]) {
        guard isGameCenterAuthenticated, !achievements.isEmpty else { return }
        let reports = achievements.map { achievement -> GKAchievement in
            let entry = GKAchievement(identifier: achievement.gameCenterID)
            entry.percentComplete = 100
            entry.showsCompletionBanner = true
            return entry
        }
        GKAchievement.report(reports) { _ in }
    }
}
