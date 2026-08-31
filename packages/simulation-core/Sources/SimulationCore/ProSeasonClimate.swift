import Foundation

/// 한 주의 시즌 온도. 저장하지 않고 `careerID|season|week` 해시로 다시 만든다.
public enum ProSeasonClimate: String, Codable, Sendable {
    case hot
    case even
    case slump
    case adapted
}

/// 자동 등판이 포수 추천을 얼마나 따를지.
/// 기본값 `.perfect`는 고교·밸런스 CLI·구 프로 저장본의 기존 결과를 그대로 둔다.
public enum AutoCallPolicy: String, Codable, Sendable {
    case perfect
    case mixed
    case slump
}

/// 시즌 안 파도. 난이도 숫자만 바꾸지 않고, 같은 주차를 다시 계산해도 같은 온도가 나오게 한다.
public enum ProSeasonClimateRules {
    public static func offset(for climate: ProSeasonClimate) -> Int {
        switch climate {
        case .hot: -2
        case .even: 0
        case .slump: 3
        case .adapted: 2
        }
    }

    public static func callPolicy(for climate: ProSeasonClimate) -> AutoCallPolicy {
        switch climate {
        case .hot, .even: .mixed
        case .adapted: .mixed
        case .slump: .slump
        }
    }

    public static func newsLine(for climate: ProSeasonClimate, week: Int) -> String {
        switch climate {
        case .hot:
            return "\(week)주차 · 상대 타선이 흔들린다. 오늘 공은 잘 먹힐 공기가 있다."
        case .even:
            return "\(week)주차 · 리그는 평이하다. 리듬을 지키는 주다."
        case .slump:
            return "\(week)주차 · 타선이 직구를 기다리기 시작했다. 한동안 쉽지 않다."
        case .adapted:
            return "\(week)주차 · 상대 벤치가 내 구종 순서를 읽고 있다."
        }
    }

    /// 슬럼프는 시즌당 한 블록(2~4주)으로 묶는다. 주마다 주사위를 던지면 파도가 아니라 노이즈다.
    public static func climate(
        careerID: String,
        season: Int,
        week: Int,
        strikeouts: Int = 0,
        inningsOuts: Int = 0,
        stabilizeCharges: Int = 0
    ) -> ProSeasonClimate {
        guard week >= 1 else { return .even }
        if stabilizeCharges > 0 { return .even }

        let slump = slumpBlock(careerID: careerID, season: season)
        if slump.contains(week) { return .slump }

        if week >= 14 {
            let k9 = strikeouts * 27_000 / max(1, inningsOuts)
            if k9 >= 9_000 {
                let adaptedRoll = hashInt("\(careerID)|season\(season)|week\(week)|adapted") % 100
                if adaptedRoll < 40 { return .adapted }
            }
        }

        let hotRoll = hashInt("\(careerID)|season\(season)|week\(week)|hot") % 100
        if hotRoll < 15 { return .hot }
        return .even
    }

    public static func slumpBlock(careerID: String, season: Int) -> ClosedRange<Int> {
        let startBase = hashInt("\(careerID)|season\(season)|slump-start")
        let lengthBase = hashInt("\(careerID)|season\(season)|slump-length")
        let start = 7 + Int(startBase % 10)
        let length = 2 + Int(lengthBase % 3)
        let end = min(20, start + length - 1)
        return start...end
    }

    private static func hashInt(_ value: String) -> UInt64 {
        UInt64(StableHash.fnv1a64(value), radix: 16) ?? 0
    }
}
