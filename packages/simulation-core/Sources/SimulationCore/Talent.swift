import Foundation

/// 재능 — 능력마다 다른 성장 한계, 그리고 그 한계가 열리는 순간.
///
/// 예전에는 네 능력이 전부 20~80으로 똑같이 열려 있었다. 그래서 회차마다 다른 것은
/// 시작 수치뿐이었고, 훈련을 어디에 넣든 결국 같은 곳에 도달했다. **회차가 반복될수록
/// 똑같아지는 원인이 여기였다.**
///
/// 재능은 두 가지 일을 한다.
///
/// 1. **회차에 성격을 준다.** 이번 회차는 구위 재능이 좋고 제구가 막혀 있다 — 그러면
///    훈련 계획이 달라지고, 같은 프리셋으로 시작해도 다른 투수가 된다.
/// 2. **막힌 것이 열리는 순간을 만든다.** 한계에 닿은 능력을 계속 두드리면 만개한다.
///    등급이 낮을수록 빨리 터진다 — 재능이 나쁘게 뽑힌 회차가 버려지는 회차가 되면 안 된다.
///    대기만성은 야구에서 가장 흔한 이야기이기도 하다.
///
/// **저장 호환**: 스냅숏에 옵셔널로 붙고 커밋 해시에 들어가지 않는다. 재능이 없는 옛
/// 저장본은 `TalentSnapshot.unlimited`(전부 S)로 읽혀 예전과 똑같이 동작한다.
public enum TalentGrade: String, Codable, CaseIterable, Sendable, Comparable {
    case d, c, b, a, s

    /// 이 등급에서 훈련으로 닿을 수 있는 최댓값.
    ///
    /// 고교 3년의 집중 훈련이 능력 하나를 대략 55~60까지 올린다. 그래서 D를 52에 둔다 —
    /// **회차 안에서 실제로 벽에 닿아야** 재능이 화면에 존재하게 된다. 처음 잡았던 60은
    /// 고교에서 한 번도 걸리지 않아 아무 일도 하지 않았다(드래프트 통과율이 30%로 그대로였다).
    ///
    /// 벽에 닿는 것 자체는 벌이 아니다. 두드리면 열리고, 낮은 등급일수록 빨리 열린다.
    public var ceiling: Int {
        switch self {
        case .d: 52
        case .c: 58
        case .b: 65
        case .a: 72
        case .s: 80
        }
    }

    public var label: String { rawValue.uppercased() }

    /// 한 단계 위. S는 더 오르지 않는다.
    public var next: TalentGrade? {
        switch self {
        case .d: .c
        case .c: .b
        case .b: .a
        case .a: .s
        case .s: nil
        }
    }

    /// 만개에 필요한 두드림. 낮은 등급일수록 빨리 열린다.
    ///
    /// 이 기울기가 이 시스템의 핵심이다. 반대로 두면 좋은 재능만 더 좋아져서, 재능이
    /// 나쁘게 뽑힌 회차는 시작하자마자 끝난 회차가 된다.
    public var bloomThreshold: Int {
        switch self {
        case .d: 2
        case .c: 3
        case .b: 4
        case .a: 6
        case .s: .max
        }
    }

    public static func < (lhs: TalentGrade, rhs: TalentGrade) -> Bool {
        let order = TalentGrade.allCases
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}

/// 네 능력의 재능 등급과 만개 게이지.
public struct TalentSnapshot: Codable, Equatable, Sendable {
    public var stuff: TalentGrade
    public var command: TalentGrade
    public var movement: TalentGrade
    public var stamina: TalentGrade
    /// 한계에 막힌 채로 훈련한 횟수. 능력별로 센다.
    public var stuffPressure: Int
    public var commandPressure: Int
    public var movementPressure: Int
    public var staminaPressure: Int

    public init(
        stuff: TalentGrade, command: TalentGrade, movement: TalentGrade, stamina: TalentGrade,
        stuffPressure: Int = 0, commandPressure: Int = 0, movementPressure: Int = 0, staminaPressure: Int = 0
    ) {
        self.stuff = stuff
        self.command = command
        self.movement = movement
        self.stamina = stamina
        self.stuffPressure = stuffPressure
        self.commandPressure = commandPressure
        self.movementPressure = movementPressure
        self.staminaPressure = staminaPressure
    }

    /// 재능 개념이 없던 저장본이 읽히는 값. 예전과 똑같이 20~80이 전부 열려 있다.
    public static let unlimited = TalentSnapshot(stuff: .s, command: .s, movement: .s, stamina: .s)

    public func grade(_ ability: TalentAbility) -> TalentGrade {
        switch ability {
        case .stuff: stuff
        case .command: command
        case .movement: movement
        case .stamina: stamina
        }
    }

    public func pressure(_ ability: TalentAbility) -> Int {
        switch ability {
        case .stuff: stuffPressure
        case .command: commandPressure
        case .movement: movementPressure
        case .stamina: staminaPressure
        }
    }

    public func ceiling(_ ability: TalentAbility) -> Int { grade(ability).ceiling }

    public mutating func setGrade(_ grade: TalentGrade, for ability: TalentAbility) {
        switch ability {
        case .stuff: stuff = grade
        case .command: command = grade
        case .movement: movement = grade
        case .stamina: stamina = grade
        }
    }

    public mutating func setPressure(_ value: Int, for ability: TalentAbility) {
        switch ability {
        case .stuff: stuffPressure = value
        case .command: commandPressure = value
        case .movement: movementPressure = value
        case .stamina: staminaPressure = value
        }
    }
}

public enum TalentAbility: String, Codable, CaseIterable, Sendable {
    case stuff, command, movement, stamina

    public var label: String {
        switch self {
        case .stuff: "구위"
        case .command: "제구"
        case .movement: "변화구"
        case .stamina: "체력"
        }
    }

    /// 훈련 초점이 어느 능력을 미는가. `HighSchoolCareerEngine.grow`와 같은 대응이다.
    public static func from(_ focus: TrainingFocus) -> TalentAbility {
        switch focus {
        case .velocity: .stuff
        case .command, .gamePlanning: .command
        case .breakingBall: .movement
        case .stamina, .recovery: .stamina
        }
    }
}

public enum TalentRules {
    /// 회차의 재능을 뽑는다.
    ///
    /// 규칙 둘을 지킨다.
    /// - **적어도 하나는 B 이상.** 네 능력이 전부 막힌 회차는 시작할 이유가 없다.
    /// - **적어도 하나는 C 이하.** 전부 열려 있으면 재능이라는 개념이 화면에서 사라지고,
    ///   무엇보다 만개할 자리가 없어진다.
    public static func make(careerID: String) -> TalentSnapshot {
        var generator = SplitMix64(
            seed: UInt64(StableHash.fnv1a64("talent|\(careerID)"), radix: 16) ?? 0x5441_4c45_4e54
        )
        var grades: [TalentGrade] = (0..<4).map { _ in draw(&generator) }
        if !grades.contains(where: { $0 >= .b }) {
            grades[generator.nextInt(upperBound: 4)] = generator.nextInt(upperBound: 2) == 0 ? .b : .a
        }
        if !grades.contains(where: { $0 <= .c }) {
            grades[generator.nextInt(upperBound: 4)] = generator.nextInt(upperBound: 2) == 0 ? .c : .d
        }
        return TalentSnapshot(stuff: grades[0], command: grades[1], movement: grades[2], stamina: grades[3])
    }

    /// 등급 분포. 가운데가 두껍고 양끝이 얇다 — S가 흔하면 S가 아니다.
    private static func draw(_ generator: inout SplitMix64) -> TalentGrade {
        switch generator.nextInt(upperBound: 100) {
        case ..<18: .d
        case ..<45: .c
        case ..<75: .b
        case ..<93: .a
        default: .s
        }
    }

    /// 훈련 한 번의 결과를 재능에 통과시킨다.
    ///
    /// - Returns: 한계까지 실제로 오를 수 있는 점수, 갱신된 재능, 그리고 만개했다면 그 능력.
    ///
    /// 한계에 막혀 성장이 0이 된 훈련은 **헛되지 않다.** 그 횟수가 쌓여 만개를 만든다.
    /// 막혔다는 이유로 훈련이 낭비가 되면, 재능은 그냥 벌점이 된다.
    public static func apply(
        talent: TalentSnapshot,
        ability: TalentAbility,
        current: Int,
        points: Int
    ) -> (allowed: Int, talent: TalentSnapshot, bloomed: TalentAbility?) {
        var updated = talent
        let ceiling = talent.ceiling(ability)
        let allowed = max(0, min(points, ceiling - current))
        guard allowed < points else {
            // 한계에 여유가 있었다. 압박은 쌓이지 않는다.
            return (allowed, updated, nil)
        }
        let grade = talent.grade(ability)
        guard let next = grade.next else { return (allowed, updated, nil) }
        let pressure = talent.pressure(ability) + 1
        guard pressure >= grade.bloomThreshold else {
            updated.setPressure(pressure, for: ability)
            return (allowed, updated, nil)
        }
        // 만개. 등급이 한 단계 열리고 압박은 0으로 돌아간다.
        updated.setGrade(next, for: ability)
        updated.setPressure(0, for: ability)
        return (allowed, updated, ability)
    }

    /// 만개 소식 한 줄.
    public static func bloomHeadline(ability: TalentAbility, to grade: TalentGrade) -> String {
        "\(ability.label)의 한계가 열렸습니다 — 재능 \(grade.label). 지금까지 막혀 있던 자리가 \(grade.ceiling)까지 늘었습니다."
    }

    /// 화면이 읽어 줄 재능 설명.
    public static func meaning(_ grade: TalentGrade) -> String {
        switch grade {
        case .d: "지금은 \(grade.ceiling)에서 막힙니다. 계속 두드리면 가장 빨리 열립니다."
        case .c: "\(grade.ceiling)까지. 조금만 더 밀면 열립니다."
        case .b: "\(grade.ceiling)까지. 프로에서 통하는 수준입니다."
        case .a: "\(grade.ceiling)까지. 리그 상위권에 닿습니다."
        case .s: "한계가 없습니다."
        }
    }
}
