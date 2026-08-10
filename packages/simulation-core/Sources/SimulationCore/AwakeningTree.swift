import Foundation

/// 각성 스킬트리 — 회차마다 하나씩 찍어 내려가는 네 갈래.
///
/// 예전에는 각성이 올 때마다 18개 중 2~3개를 뽑아 보여 줬다. 그 방식의 문제는 **선택이
/// 쌓이지 않는다**는 것이다. 세 번의 각성이 서로 아무 관계가 없으니 회차가 끝나도
/// "이 선수를 이렇게 만들었다"는 이야기가 남지 않고, 매번 처음 보는 카드 세 장 중
/// 무엇이 나은지만 재는 문제가 된다.
///
/// 트리는 그 셋을 한 문장으로 묶는다. 뿌리 하나를 찍으면 그 갈래의 다음 가지가 열리고,
/// 세 번뿐인 각성으로 **한 갈래를 끝까지 파거나(깊이) 여러 갈래를 얕게 가져가거나(넓이)**를
/// 고르게 된다. 같은 18개 능력이 그대로지만, 순서가 전략이 된다.
///
/// - 뿌리(1단)는 언제나 열려 있다.
/// - 2·3단은 부모를 찍어야 열린다.
/// - **전조(`awakeningSparks`)가 3 이상이면 한 단계를 건너뛸 수 있다.** 시즌을 호투로
///   채운 회차만 3단에 두 번의 각성으로 닿는다 — 전조가 여기서 실제 보상이 된다.
public enum AwakeningTree {
    /// 네 갈래. `RunPledgeAwakeningFamily`(앱 계층)와 같은 분류를 코어에 둔 것이다.
    public enum Branch: String, CaseIterable, Codable, Sendable {
        case power, command, breaking, game

        public var title: String {
            switch self {
            case .power: "힘"
            case .command: "제구"
            case .breaking: "변화"
            case .game: "수싸움"
            }
        }

        public var detail: String {
            switch self {
            case .power: "구속과 이닝을 버티는 몸. 정면 승부로 눌러 이긴다."
            case .command: "원하는 곳에 꽂는 손. 볼넷을 지우고 카운트를 지배한다."
            case .breaking: "떨어지고 휘는 공. 방망이를 헛돌게 만든다."
            case .game: "상대를 읽는 머리. 주자와 카운트를 관리해 실점을 막는다."
            }
        }

        public var symbol: String {
            switch self {
            case .power: "flame.fill"
            case .command: "scope"
            case .breaking: "tornado"
            case .game: "brain.head.profile"
            }
        }
    }

    /// 한 노드. 부모가 비어 있으면 뿌리다.
    public struct Node: Equatable, Sendable {
        public let id: AwakeningID
        public let branch: Branch
        /// 1(뿌리) · 2 · 3.
        public let tier: Int
        /// 이 노드를 열기 위해 먼저 찍어야 하는 각성. 뿌리는 빈 배열이다.
        public let parents: [AwakeningID]

        public init(id: AwakeningID, branch: Branch, tier: Int, parents: [AwakeningID]) {
            self.id = id
            self.branch = branch
            self.tier = tier
            self.parents = parents
        }
    }

    /// 트리 전체. 18개 각성이 빠짐없이 한 번씩 들어간다(테스트가 지킨다).
    public static let nodes: [Node] = [
        // 힘 — 뿌리에서 갈라져 마지막 이닝까지.
        Node(id: .explosiveFastball, branch: .power, tier: 1, parents: []),
        Node(id: .risingFourSeam, branch: .power, tier: 2, parents: [.explosiveFastball]),
        Node(id: .ironArm, branch: .power, tier: 2, parents: [.explosiveFastball]),
        Node(id: .lateInningReserve, branch: .power, tier: 3, parents: [.ironArm]),

        // 제구 — 코스에서 시작해 압박 속의 침착함으로.
        Node(id: .pinpointEdge, branch: .command, tier: 1, parents: []),
        Node(id: .repeatableRelease, branch: .command, tier: 2, parents: [.pinpointEdge]),
        Node(id: .firstPitchStrike, branch: .command, tier: 2, parents: [.pinpointEdge]),
        Node(id: .calmUnderPressure, branch: .command, tier: 3, parents: [.repeatableRelease]),
        Node(id: .scoutComposure, branch: .command, tier: 3, parents: [.firstPitchStrike]),

        // 변화 — 하나의 결정구에서 구종 전체로.
        Node(id: .disappearingBreaker, branch: .breaking, tier: 1, parents: []),
        Node(id: .sweepingSlider, branch: .breaking, tier: 2, parents: [.disappearingBreaker]),
        Node(id: .curveballClock, branch: .breaking, tier: 2, parents: [.disappearingBreaker]),
        Node(id: .frozenChangeup, branch: .breaking, tier: 3, parents: [.sweepingSlider]),
        Node(id: .sinkerTunnel, branch: .breaking, tier: 3, parents: [.curveballClock]),

        // 수싸움 — 포수와의 호흡에서 경기 운영으로.
        Node(id: .batterySync, branch: .game, tier: 1, parents: []),
        Node(id: .twoStrikePlan, branch: .game, tier: 2, parents: [.batterySync]),
        Node(id: .pickoffRhythm, branch: .game, tier: 2, parents: [.batterySync]),
        Node(id: .trafficController, branch: .game, tier: 3, parents: [.twoStrikePlan]),
    ]

    private static let index: [AwakeningID: Node] = Dictionary(
        uniqueKeysWithValues: nodes.map { ($0.id, $0) }
    )

    public static func node(_ id: AwakeningID) -> Node {
        // 트리는 전수 표라 여기 없는 각성은 존재하지 않는다. 테스트가 그것을 지킨다.
        index[id] ?? Node(id: id, branch: .game, tier: 1, parents: [])
    }

    public static func branch(_ id: AwakeningID) -> Branch { node(id).branch }
    public static func tier(_ id: AwakeningID) -> Int { node(id).tier }

    /// 한 단계를 건너뛰게 해 주는 전조. 이 값 이상이면 부모를 하나 빚진 노드도 열린다.
    public static let leapSparks = 3

    /// 지금 찍을 수 있는 각성.
    ///
    /// - Parameters:
    ///   - selected: 이번 회차에서 이미 찍은 각성.
    ///   - sparks: 각성의 전조. `nil`은 전조 개념 이전 저장본이라 도약을 허용한다
    ///     (규칙이 소급해서 벌하지 않는다).
    public static func available(selected: [AwakeningID], sparks: Int?) -> [AwakeningID] {
        let taken = Set(selected)
        let canLeap = (sparks ?? leapSparks) >= leapSparks
        return nodes.compactMap { node in
            guard !taken.contains(node.id) else { return nil }
            let unmet = node.parents.filter { !taken.contains($0) }
            if unmet.isEmpty { return node.id }
            // 도약은 한 칸까지다. 두 칸 빚진 노드(뿌리도 없는 3단)는 열리지 않는다.
            guard canLeap, unmet.count == node.parents.count, node.parents.count == 1 else { return nil }
            // 같은 갈래에 발을 하나라도 걸쳐 놨을 때만 건너뛴다 — 아무 갈래의 3단이
            // 공짜로 열리면 트리가 그냥 목록으로 돌아간다.
            return taken.contains(where: { branch($0) == node.branch }) ? node.id : nil
        }
    }

    /// 도약(부모를 건너뛴 해금)으로만 열린 노드인가. 화면이 그 사실을 표시한다.
    public static func isLeap(_ id: AwakeningID, selected: [AwakeningID]) -> Bool {
        let taken = Set(selected)
        return !node(id).parents.allSatisfy { taken.contains($0) }
    }

    /// 이 훈련 초점을 밀어 온 선수에게 어울리는 갈래. 추천은 강제가 아니라 표시다.
    public static func branch(forTrainingFocus focus: TrainingFocus) -> Branch {
        switch focus {
        case .velocity: .power
        case .stamina: .power
        case .command: .command
        case .recovery: .command
        case .breakingBall: .breaking
        case .gamePlanning: .game
        }
    }
}
