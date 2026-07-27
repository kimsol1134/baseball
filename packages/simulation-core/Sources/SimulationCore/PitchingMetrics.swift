import Foundation

/// 투수 기록 지표.
///
/// 요즘 야구 팬이 실제로 보는 값들이다. 이닝·탈삼진 같은 원시 기록만으로는 "이 시즌이
/// 좋았는가"를 판단할 수 없고, 그 판단을 못 하면 3년을 쌓는 게임이 숫자 나열이 된다.
///
/// **자책점은 세지 않는다.** 커널이 실책을 모델링하지 않으므로 자책점과 실점을 구분할
/// 근거가 없다. 그래서 이 파일 어디에도 "평균자책점(ERA)"이라는 말이 없다 — 전부
/// **9이닝당 실점(RA9)** 이다. 있지도 않은 정밀도를 이름으로 주장하지 않는다.
public enum PitchingMetrics {

    /// 아웃 카운트를 이닝 실수로. 1아웃 = ⅓이닝.
    public static func innings(outs: Int) -> Double {
        Double(max(0, outs)) / 3
    }

    /// "6.1" 같은 야구 기록지 표기. 소수점 뒤는 십진수가 아니라 아웃 개수다.
    public static func inningsText(outs: Int) -> String {
        let safe = max(0, outs)
        return "\(safe / 3)\(safe % 3 == 0 ? "" : ".\(safe % 3)")"
    }

    /// 9이닝당 개수. 탈삼진·볼넷·피안타·홈런 모두 이걸 쓴다.
    public static func per9(_ count: Int, outs: Int) -> Double? {
        guard outs > 0 else { return nil }
        return Double(count) * 27 / Double(outs)
    }

    /// 9이닝당 실점. 평균자책점이 아니다.
    public static func runsPer9(runs: Int, outs: Int) -> Double? {
        per9(runs, outs: outs)
    }

    /// 이닝당 출루 허용. 안타와 볼넷만 센다(KBO 중계 표기와 같다).
    public static func whip(hits: Int, walks: Int, outs: Int) -> Double? {
        guard outs > 0 else { return nil }
        return Double(hits + walks) * 3 / Double(outs)
    }

    /// 탈삼진/볼넷. 볼넷이 0이면 나눌 수 없다 — 무한대를 숫자인 척 돌려주지 않는다.
    public static func strikeoutToWalk(strikeouts: Int, walks: Int) -> Double? {
        guard walks > 0 else { return nil }
        return Double(strikeouts) / Double(walks)
    }

    /// 상대한 타자 수. 커널이 따로 세지 않아 기록에서 되짚는다.
    ///
    /// 아웃 + 안타 + 볼넷이 실제 타자 수의 하한이다(주루사·병살로 늘어난 아웃을 투수의
    /// 상대 타자로 세는 오차가 있지만, 비율 지표의 분모로는 충분하다).
    public static func battersFaced(outs: Int, hits: Int, walks: Int) -> Int {
        max(0, outs) + max(0, hits) + max(0, walks)
    }

    /// 탈삼진 비율. 요즘은 K/9보다 이 값을 먼저 본다 — 이닝 수에 휘둘리지 않는다.
    public static func strikeoutRate(strikeouts: Int, battersFaced: Int) -> Double? {
        guard battersFaced > 0 else { return nil }
        return Double(strikeouts) / Double(battersFaced)
    }

    public static func walkRate(walks: Int, battersFaced: Int) -> Double? {
        guard battersFaced > 0 else { return nil }
        return Double(walks) / Double(battersFaced)
    }

    /// 인플레이 타구의 안타 비율.
    ///
    /// 수비와 운이 섞인 값이라, 이것이 리그 평균(약 .300)에서 크게 벗어나 있으면 그 시즌
    /// 성적은 실력보다 운으로 설명된다. 화면이 이 값을 보여 주는 이유가 그것이다.
    public static func babip(hits: Int, homeRuns: Int, strikeouts: Int, outs: Int, walks: Int) -> Double? {
        let faced = battersFaced(outs: outs, hits: hits, walks: walks)
        let ballsInPlay = faced - walks - strikeouts - homeRuns
        guard ballsInPlay > 0 else { return nil }
        return Double(hits - homeRuns) / Double(ballsInPlay)
    }

    /// 리그 평균 RA9. `check-balance`의 등판 실측에서 온 값이고, FIP의 영점이 된다.
    /// 커널 밸런스를 바꾸면 이 값도 다시 재야 한다.
    public static let leagueRunsPer9 = 3.5

    /// 수비와 운을 걷어 낸 투수 자신의 성적.
    ///
    /// 홈런·볼넷·몸에 맞는 공·탈삼진만 쓴다 — 투수가 혼자 결정하는 결과들이다. RA9보다
    /// 낮으면 "수비와 운이 도왔다", 높으면 "실제보다 나쁜 성적을 받았다"로 읽는다.
    ///
    /// 표준 FIP는 자책점 기준이지만 이 게임은 자책점을 세지 않으므로 **실점 기준**으로
    /// 영점을 잡는다. 계수(13/3/2)는 그대로다.
    public static func fip(
        homeRuns: Int,
        walks: Int,
        hitByPitch: Int = 0,
        strikeouts: Int,
        outs: Int,
        leagueRunsPer9: Double = leagueRunsPer9,
        leagueConstant: Double = fipConstant
    ) -> Double? {
        guard outs > 0 else { return nil }
        let raw = (13 * Double(homeRuns) + 3 * Double(walks + hitByPitch) - 2 * Double(strikeouts))
            / innings(outs: outs)
        return raw + leagueConstant
    }

    /// FIP 상수. 리그 평균 투수의 FIP가 리그 RA9와 같아지도록 맞춘 값이다.
    ///
    /// 실측 리그 평균(600등판): HR/9 0.91 · BB/9 2.36 · K/9 9.97 →
    /// (13×0.91 + 3×2.36 − 2×9.97) / 9 = −0.1657. 3.5 − (−0.1657) = 3.666.
    public static let fipConstant = 3.67

    /// 퀄리티스타트. KBO 중계가 매 경기 세는 값이다.
    ///
    /// 원래 정의는 6이닝 3자책 이하지만 자책점이 없으므로 **6이닝 3실점 이하**로 센다.
    /// 실책이 없는 세계에서는 두 정의가 같다.
    public static func isQualityStart(started: Bool, outs: Int, runsAllowed: Int) -> Bool {
        started && outs >= 18 && runsAllowed <= 3
    }

    /// 등판 목록에서 퀄리티스타트 수.
    public static func qualityStarts(_ lines: [ProGameLine]) -> Int {
        lines.filter { isQualityStart(started: $0.started, outs: $0.outs, runsAllowed: $0.runsAllowed) }.count
    }

    /// 승률. 무승부는 분모에서 뺀다(KBO 표기와 같다).
    public static func winRate(wins: Int, losses: Int) -> Double? {
        let decided = wins + losses
        guard decided > 0 else { return nil }
        return Double(wins) / Double(decided)
    }

    /// ".532" 형태. 야구 기록은 앞의 0을 쓰지 않는다.
    public static func rateText(_ value: Double?) -> String {
        guard let value else { return "-" }
        let text = String(format: "%.3f", value)
        return text.hasPrefix("0.") ? String(text.dropFirst()) : text
    }
}
