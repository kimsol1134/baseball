import XCTest
@testable import SimulationCore

final class ProAdvancementRulesTests: XCTestCase {
    /// 문턱은 규칙이 실제로 쓰는 값이어야 한다. 화면이 따로 든 숫자를 보여 주면
    /// "체력 4 남았다"를 채웠는데 문이 안 열리는 일이 생긴다.
    func testThresholdsComeFromTheRulesThatEnforceThem() {
        let board = ProAdvancementRules.board(state: snapshot())
        let callUp = row(board, .majorCallUp)
        XCTAssertEqual(callUp.requirements.first { $0.id == "trust" }?.target, ProCallUpRules.trustRequired)
        XCTAssertEqual(callUp.requirements.first { $0.id == "skill" }?.target, ProCallUpRules.skillRequired)

        let starter = row(board, .starterRole)
        XCTAssertEqual(starter.requirements.first { $0.id == "stamina" }?.target, ProRoleRequestRules.starterAcceptStamina)
        XCTAssertEqual(starter.requirements.first { $0.id == "trust" }?.target, ProRoleRequestRules.starterAcceptTrust)

        let closer = row(board, .closerRole)
        XCTAssertEqual(closer.requirements.first { $0.id == "stuff" }?.target, ProRoleRequestRules.closerAcceptStuff)
        XCTAssertEqual(closer.requirements.first { $0.id == "catcherTrust" }?.target, ProRoleRequestRules.closerAcceptCatcherTrust)
    }

    /// 승격 조건은 커널과 보드가 **같은 함수**를 본다. 하나만 고쳐 어긋나면 여기서 잡힌다.
    func testCallUpRowAgreesWithTheEngineCondition() {
        for trust in [40, 59, 60, 80] {
            for skill in [40, 45, 46, 60] {
                let pitcher = PitcherSnapshot(id: "p", name: "t", stuff: skill, command: skill, movement: skill, stamina: skill)
                let state = snapshot(pitcher: pitcher, managerTrust: trust, level: .minor, season: 3)
                let engineSays = ProCallUpRules.qualifies(
                    trust: trust, skill: ProCallUpRules.skill(pitcher),
                    season: state.season, stats: state.currentStats
                )
                XCTAssertEqual(row(ProAdvancementRules.board(state: state), .majorCallUp).unlocked, engineSays,
                               "신뢰 \(trust) 능력 \(skill)")
            }
        }
    }

    /// **다음 문턱까지 남은 거리.** 이것이 없으면 보드는 잠긴 문 목록일 뿐이다.
    func testNearestGapNamesTheConditionTheyCanActOnNow() {
        let pitcher = PitcherSnapshot(id: "p", name: "t", stuff: 50, command: 50, movement: 50, stamina: 51)
        let state = snapshot(pitcher: pitcher, managerTrust: 20, level: .major, role: .longRelief)
        let starter = row(ProAdvancementRules.board(state: state), .starterRole)
        XCTAssertFalse(starter.unlocked)
        // 체력은 4 남았고 신뢰는 25 남았다. 이번 주에 손댈 수 있는 쪽을 말한다.
        XCTAssertEqual(starter.nearestGap?.id, "stamina")
        XCTAssertEqual(starter.nearestGap?.remaining, ProRoleRequestRules.starterAcceptStamina - 51)
    }

    /// 이미 가진 자격은 문턱을 다시 묻지 않는다.
    func testHeldRolesDoNotAskForTheirOwnThresholdAgain() {
        let weak = PitcherSnapshot(id: "p", name: "t", stuff: 20, command: 20, movement: 20, stamina: 20)
        let board = ProAdvancementRules.board(state: snapshot(pitcher: weak, level: .major, role: .starter))
        XCTAssertTrue(row(board, .starterRole).unlocked, "이미 선발인데 선발 자격이 잠겨 있습니다")
        XCTAssertEqual(row(board, .starterRole).permille, 1_000)
        XCTAssertTrue(row(board, .majorCallUp).unlocked, "이미 1군인데 승격이 잠겨 있습니다")
    }

    /// 조건이 둘인 줄은 하나만 채워도 절반까지만 간다. 하나 채우고 다 왔다고 보이면 안 된다.
    func testPermilleCountsEveryConditionNotJustTheMetOne() {
        let pitcher = PitcherSnapshot(id: "p", name: "t", stuff: 80, command: 20, movement: 20, stamina: 20)
        let closer = row(ProAdvancementRules.board(state: snapshot(pitcher: pitcher, catcherTrust: 0, role: .longRelief)), .closerRole)
        XCTAssertFalse(closer.unlocked)
        XCTAssertLessThan(closer.permille, 1_000)
        XCTAssertGreaterThan(closer.permille, 0)
    }

    /// 다음 문턱은 **가장 가까운** 잠긴 문이다.
    func testNextIsTheClosestLockedDoor() {
        let pitcher = PitcherSnapshot(id: "p", name: "t", stuff: 30, command: 30, movement: 30, stamina: 54)
        let board = ProAdvancementRules.board(state: snapshot(pitcher: pitcher, managerTrust: 50, level: .major, role: .longRelief))
        let next = try! XCTUnwrap(board.next)
        XCTAssertFalse(next.unlocked)
        for locked in board.rows where !locked.unlocked {
            XCTAssertLessThanOrEqual(locked.permille, next.permille, "\(locked.kind)가 다음 문턱보다 가깝습니다")
        }
    }

    func testContentKeysAreStableSemanticIDs() {
        let keys = ProAdvancementRules.contentKeys
        XCTAssertFalse(keys.isEmpty)
        XCTAssertEqual(Set(keys).count, keys.count)
        for key in keys {
            XCTAssertTrue(key.hasPrefix("content.advancement."), key)
            XCTAssertFalse(key.contains(" "), key)
            XCTAssertFalse(key.contains("_"), key)
            XCTAssertEqual(key, key.lowercased(), key)
        }
        // 모든 줄의 문구 키가 목록에 있다. 목록에서 빠지면 번역 검사를 통과하고도 화면이 빈다.
        for kind in ProAdvancementKind.allCases {
            let row = ProAdvancementRules.board(state: snapshot()).rows.first { $0.kind == kind }
            guard let row else { continue }
            XCTAssertTrue(keys.contains(row.titleKey), row.titleKey)
            XCTAssertTrue(keys.contains(row.hintKey), row.hintKey)
            for requirement in row.requirements {
                XCTAssertTrue(keys.contains(requirement.labelKey), requirement.labelKey)
            }
        }
    }

    // MARK: -

    private func row(_ board: ProAdvancementBoard, _ kind: ProAdvancementKind) -> ProAdvancement {
        try! XCTUnwrap(board.rows.first { $0.kind == kind }, "\(kind) 줄이 없습니다")
    }

    private func snapshot(
        pitcher: PitcherSnapshot? = nil,
        managerTrust: Int = 50,
        catcherTrust: Int = 45,
        level: ProLevel = .minor,
        role: ProRole = .longRelief,
        season: Int = 3
    ) -> ProCareerSnapshot {
        ProCareerSnapshot(
            proCareerID: "pro-1", revision: 1, phase: .weeklyPlan, identity: .defaultPitcher,
            pitcher: pitcher ?? .init(id: "p", name: "t", stuff: 50, command: 50, movement: 50, stamina: 50),
            team: ProCareerEngine.proTeams[0],
            entitlement: .init(status: .active, source: .development, verifiedAt: "2026-07-22", offlineValidUntil: "2026-08-22"),
            age: 21, season: season, week: 4, level: level, role: role,
            managerTrust: managerTrust, catcherTrust: catcherTrust, fatigue: 30, injuryWeeks: 0,
            serviceYears: 1, militaryCompleted: false, contract: nil,
            currentStats: ProSeasonStats(season: season, teamID: ProCareerEngine.proTeams[0].id),
            careerStats: [], awards: [], milestones: [], news: [], hallOfFameScore: nil,
            commitment: "", balanceVersion: PitcherPresetCatalog.balanceVersion,
            proRulesVersion: ProGameplayRules.current
        )
    }
}
