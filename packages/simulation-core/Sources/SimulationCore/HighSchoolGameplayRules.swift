import Foundation

/// Which high school gameplay rules an engine runs.
///
/// `reference` (4) is the frozen path. Every golden fixture, the parity exporters and the Android
/// comparison data are generated from it, so a career signed at 4 must keep computing exactly what
/// it computed the day it was signed. `current` is what a live career runs.
///
/// The version lives on the state (`HighSchoolCareerSnapshot.balanceVersion`), not on the engine
/// alone: an engine signs every state it produces with its own version, so an in-progress career
/// moves onto the newer rules at its next command while its already-recorded schedule, ratings,
/// repertoire and finished games stay exactly as they were.
///
/// - 4: frozen reference.
/// - 5: reworked draft evaluation, training progress that accumulates between growth points,
///   intensity-scaled jackpot chance.
/// - 6: intensive training costs 11 fatigue instead of 15.
/// - 7: rebalanced school pitching, opponents that no longer scale with the rebirth count,
///   completed-life inheritance, and a draft threshold matched to the harder games.
public enum HighSchoolGameplayRules {
    /// The frozen comparison path.
    public static let reference = 4
    /// What a new or resumed career runs.
    public static let current = 8

    /// The rules version a state actually carries. Unversioned legacy saves read as 1.
    public static func version(of balanceVersion: Int?) -> Int { balanceVersion ?? 1 }

    /// v5+: the reworked draft evaluation, training progress and intensity jackpot.
    public static func usesCurrentEvaluation(_ balanceVersion: Int?) -> Bool { version(of: balanceVersion) >= 5 }
    /// v6+: the lighter intensive-training fatigue cost.
    public static func usesLightenedIntensity(_ balanceVersion: Int?) -> Bool { version(of: balanceVersion) >= 6 }
    /// v7+: the school balance pass — pitching, opponents, inheritance and draft threshold.
    public static func usesSchoolBalance(_ balanceVersion: Int?) -> Bool { version(of: balanceVersion) >= 7 }

    /// **직접 던지는 공이 어느 확률식을 쓰는가.**
    ///
    /// v7의 재조정은 자동 등판(`AutoOutingSimulator`)을 기준으로 맞춘 값이고, 플레이어가
    /// 직접 던지는 경기에는 한 번도 적용된 적이 없다 — 앱이 `PitchKernelEngine`을 기본
    /// 인자로 만들어 `.legacy`가 조용히 들어갔기 때문이다. **기본값이 밸런스를 정하고
    /// 있었고 아무도 그것을 고른 적이 없다.**
    ///
    /// 그래서 여기서 버전으로 명시한다. v7까지는 오늘과 **바이트 단위로 같은** `.legacy`다.
    /// 연결은 v8에서 측정과 함께 한다(계획 문서 §2.5) — 그냥 켜면 중립 릴리스 지명률이
    /// 43%에서 5%로 떨어진다.
    public static func livePitchBalance(_ balanceVersion: Int?) -> PitchBalanceRules {
        version(of: balanceVersion) >= 8 ? .school : .legacy
    }

    /// v8+: 직접 던진 경기의 평가 감도와 당락 문턱을 함께 옮긴 경로.
    ///
    /// 라이브 곡선을 연결하면 같은 투구가 더 낮은 성적을 만든다. 문턱을 그대로 두면 지명이
    /// 사실상 막히므로 둘을 **한 버전에서 같이** 옮긴다(계획 문서 §2.8).
    public static func usesLiveBalanceEvaluation(_ balanceVersion: Int?) -> Bool {
        version(of: balanceVersion) >= 8
    }
}
