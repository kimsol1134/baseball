import XCTest
@testable import SimulationCore

final class AwakeningTreeTests: XCTestCase {
    /// 트리는 전수 표다. 하나라도 빠지면 그 각성은 게임에서 도달할 수 없는 죽은 콘텐츠가 된다.
    func testEveryAwakeningAppearsExactlyOnce() {
        let ids = AwakeningTree.nodes.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "같은 각성이 트리에 두 번 들어 있습니다")
        XCTAssertEqual(Set(ids), Set(AwakeningID.allCases), "트리에서 빠진 각성이 있습니다")
    }

    /// 부모는 반드시 같은 갈래의 한 단계 위다. 갈래를 가로지르는 선행 조건이 생기면
    /// 화면이 그리는 "갈래별 줄기"가 거짓말이 된다.
    func testParentsStayInsideTheSameBranchAndOneTierUp() {
        for node in AwakeningTree.nodes {
            if node.parents.isEmpty {
                XCTAssertEqual(node.tier, 1, "\(node.id.rawValue): 부모가 없으면 뿌리여야 합니다")
                continue
            }
            XCTAssertGreaterThan(node.tier, 1, "\(node.id.rawValue): 뿌리에 부모가 있습니다")
            for parent in node.parents {
                XCTAssertEqual(AwakeningTree.branch(parent), node.branch,
                               "\(node.id.rawValue): 부모가 다른 갈래에 있습니다")
                XCTAssertEqual(AwakeningTree.tier(parent), node.tier - 1,
                               "\(node.id.rawValue): 부모가 바로 위 단계가 아닙니다")
            }
        }
    }

    /// 모든 갈래에 뿌리가 정확히 하나. 뿌리가 없는 갈래는 영영 열리지 않고,
    /// 둘이면 "하나를 찍으면 갈래가 열린다"는 규칙이 무너진다.
    func testEachBranchHasExactlyOneRoot() {
        for branch in AwakeningTree.Branch.allCases {
            let roots = AwakeningTree.nodes.filter { $0.branch == branch && $0.parents.isEmpty }
            XCTAssertEqual(roots.count, 1, "\(branch.rawValue) 갈래의 뿌리가 \(roots.count)개입니다")
        }
    }

    func testFirstPickOffersOnlyRoots() {
        let available = AwakeningTree.available(selected: [], sparks: 0)
        XCTAssertEqual(Set(available), Set(AwakeningTree.nodes.filter { $0.parents.isEmpty }.map(\.id)))
    }

    /// 뿌리를 찍으면 그 갈래의 2단이 열리고, 다른 갈래는 여전히 뿌리만 열려 있다.
    func testPickingARootOpensThatBranchOnly() {
        let available = AwakeningTree.available(selected: [.explosiveFastball], sparks: 0)
        XCTAssertTrue(available.contains(.risingFourSeam))
        XCTAssertTrue(available.contains(.ironArm))
        XCTAssertFalse(available.contains(.lateInningReserve), "3단이 2단 없이 열렸습니다")
        XCTAssertTrue(available.contains(.pinpointEdge), "다른 갈래의 뿌리는 계속 열려 있어야 합니다")
        XCTAssertFalse(available.contains(.repeatableRelease), "손대지 않은 갈래의 2단이 열렸습니다")
        XCTAssertFalse(available.contains(.explosiveFastball), "이미 찍은 각성이 다시 나왔습니다")
    }

    /// 전조가 충분하면 같은 갈래 안에서 한 단계를 건너뛴다. 전조가 실제 보상이 되는 지점이다.
    func testSparksAllowASingleLeapInsideTheBranch() {
        let withoutSparks = AwakeningTree.available(selected: [.explosiveFastball], sparks: 0)
        XCTAssertFalse(withoutSparks.contains(.lateInningReserve))

        let withSparks = AwakeningTree.available(selected: [.explosiveFastball],
                                                 sparks: AwakeningTree.leapSparks)
        XCTAssertTrue(withSparks.contains(.lateInningReserve), "전조가 찼는데 건너뛰기가 안 열렸습니다")
        XCTAssertTrue(AwakeningTree.isLeap(.lateInningReserve, selected: [.explosiveFastball]))
        // 발을 걸치지 않은 갈래는 전조가 있어도 3단이 열리지 않는다.
        XCTAssertFalse(withSparks.contains(.calmUnderPressure), "손대지 않은 갈래의 3단이 공짜로 열렸습니다")
    }

    /// 회차당 세 번으로 한 갈래를 끝까지 팔 수 있어야 "깊이 vs 넓이"가 실제 선택이 된다.
    func testThreePicksCanReachTheDeepestNodeInABranch() {
        var selected: [AwakeningID] = []
        for expected in [AwakeningID.explosiveFastball, .ironArm, .lateInningReserve] {
            XCTAssertTrue(AwakeningTree.available(selected: selected, sparks: 0).contains(expected),
                          "\(expected.rawValue)에 순서대로 닿지 못합니다")
            selected.append(expected)
        }
        XCTAssertEqual(selected.count, 3)
    }
}
