import XCTest
@testable import BaseballIOSDomain

final class CommandReceiptRetentionTests: XCTestCase {
    /// 같은 명령이라도 다른 revision에서 온 것은 다른 영수증이다 —
    /// "3주차의 훈련"이 "5주차의 같은 훈련"을 막으면 안 된다.
    func testTheSameOperationAtADifferentRevisionIsADifferentReceipt() {
        let third = CommandReceiptRetention.id(revision: 3, operation: "plan-week:refine_command")
        let fifth = CommandReceiptRetention.id(revision: 5, operation: "plan-week:refine_command")
        XCTAssertNotEqual(third, fifth)
        XCTAssertEqual(CommandReceiptRetention.revision(of: third), 3)
        XCTAssertTrue(CommandReceiptRetention.accepts(fifth, at: 5, seen: [third]))
    }

    /// 이미 적용한 명령은 거부한다. 버튼이 두 번 눌린 경우다.
    func testAReceiptAlreadySeenIsRefused() {
        let id = CommandReceiptRetention.id(revision: 7, operation: "sign-contract")
        XCTAssertTrue(CommandReceiptRetention.accepts(id, at: 7, seen: []))
        XCTAssertFalse(CommandReceiptRetention.accepts(id, at: 7, seen: [id]))
    }

    /// 화면이 들고 있던 옛 상태에서 눌린 버튼은 낡은 명령이다.
    func testAReceiptBoundToAnotherRevisionIsRefused() {
        let id = CommandReceiptRetention.id(revision: 4, operation: "plan-week:recover")
        XCTAssertFalse(CommandReceiptRetention.accepts(id, at: 9, seen: []))
    }

    /// **묶이지 않은 옛 영수증은 버리지 않는다.** 나이를 알 수 없으므로 버리면 그 명령이
    /// 나중에 다시 적용될 수 있다.
    func testOpaqueReceiptsAreNeverEvicted() {
        let opaque = ["legacy-a", "legacy-b"]
        let bound = (0..<(CommandReceiptRetention.recentLimit + 50)).map {
            CommandReceiptRetention.id(revision: UInt64($0), operation: "op")
        }
        let retained = CommandReceiptRetention.retaining(opaque + bound)
        for id in opaque {
            XCTAssertTrue(retained.contains(id), "묶이지 않은 영수증 \(id)가 버려졌습니다")
        }
        // 묶인 것은 최근 것만 남는다.
        let keptBound = retained.filter { CommandReceiptRetention.revision(of: $0) != nil }
        XCTAssertEqual(keptBound.count, CommandReceiptRetention.recentLimit)
        // 남은 것은 최근 revision이다 — 오래된 쪽이 밀려난다.
        let revisions = keptBound.compactMap(CommandReceiptRetention.revision(of:))
        XCTAssertEqual(revisions.min(), 50)
    }

    /// 문자열 순서로 나이를 짐작하지 않는다. revision 10이 revision 9보다 최근이다.
    func testAgeComesFromTheRevisionNotTheString() {
        let ids = [9, 10, 11].map { CommandReceiptRetention.id(revision: UInt64($0), operation: "op") }
        let retained = CommandReceiptRetention.retaining(ids)
        XCTAssertEqual(Set(retained), Set(ids))
    }

    func testDuplicatesCollapse() {
        let id = CommandReceiptRetention.id(revision: 1, operation: "op")
        XCTAssertEqual(CommandReceiptRetention.retaining([id, id, id]), [id])
    }
}
