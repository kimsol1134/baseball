import Foundation

/// Which professional gameplay rules an engine runs.
///
/// `reference` (10) is the frozen path that the Android parity data compares against, and the
/// version every already-shipped career carries. `current` is what a live career runs.
///
/// The version lives on the state (`ProCareerSnapshot.proRulesVersion`): an engine signs every
/// state it produces with its own version, so an in-progress career moves onto the newer rules at
/// its next command while its recorded seasons, contracts and awards stay exactly as they were.
///
/// - 10: frozen reference.
/// - 11: the current catcher signs and effort split reach automatic outings.
/// - 12: rebalanced professional pitching — one saturating whiff edge, a real opposing lineup,
///   earned runs tracked against an explicit runner ledger, and a direct outing whose remaining
///   innings are simulated by the same pitch engine instead of being split by innings ratio.
/// - 13: workload — pitch count, stamina, runs and the late-inning situation decide the change,
///   so an ace can finish a game.
/// - 14: the live pitch uses the professional workload curve, with live-outing
///   trust sensitivity moved in the same version. The starter trust line stays 74.
public enum ProGameplayRules {
    /// The frozen comparison path.
    public static let reference = 10
    /// What a new or resumed career runs.
    public static let current = 14

    /// The rules version a state actually carries. Unversioned legacy saves read as 1.
    public static func version(of proRulesVersion: Int?) -> Int { proRulesVersion ?? 1 }

    /// v11+: modern recommendations in automatic outings.
    public static func usesModernPitching(_ proRulesVersion: Int?) -> Bool { version(of: proRulesVersion) >= 11 }
    /// v12+: the professional balance pass and the earned-run ledger.
    public static func usesProfessionalBalance(_ proRulesVersion: Int?) -> Bool { version(of: proRulesVersion) >= 12 }
    /// v13+: workload-driven changes and complete games.
    public static func usesWorkload(_ proRulesVersion: Int?) -> Bool { version(of: proRulesVersion) >= 13 }

    /// **직접 던지는 공이 어느 확률식을 쓰는가.** v13까지는 `.legacy`다.
    ///
    /// v11~v13의 프로 재조정은 자동 등판에만 적용돼 왔다. 중요 경기·가을야구처럼 플레이어가
    /// 직접 던지는 경기는 옛 확률식이었다. v14는 고교 8과 같이 곡선과 평가를 한 버전에서
    /// 옮긴다(계획 문서 §2.5).
    public static func livePitchBalance(_ proRulesVersion: Int?) -> PitchBalanceRules {
        version(of: proRulesVersion) >= 14 ? .professionalWorkload : .legacy
    }

    /// v14+: 직접 던진 경기의 평가 감도를 곡선과 한 버전에서 같이 옮긴 경로.
    ///
    /// 라이브 곡선을 연결하면 같은 투구가 볼넷·실점을 더 낸다. 감도를 그대로 두면
    /// 손맛이 커리어를 못 밀고(시즌 말 믿음이 천장에 붙는다), 선발 문(74)만 내리면
    /// 그냥 쉬워지므로 감도만 두 배로 연다. 24시드에서 선발 가능 믿음이 중립 54% ·
    /// 완벽 83%로 갈린다 — 문 74가 그 분포 안에 들어 숫자는 그대로 둔다.
    public static func usesLiveBalanceEvaluation(_ proRulesVersion: Int?) -> Bool {
        version(of: proRulesVersion) >= 14
    }
}
