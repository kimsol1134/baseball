import XCTest
import SimulationCore
@testable import BaseballIOS

/// 라이벌 파생·능력 사다리·궤적 좌표 디코딩처럼 화면이 기대는 순수 변환을 지킨다.
final class PresentationTests: XCTestCase {
    private func rival(_ archetype: String) -> ProRivalBatter {
        ProRivalBatter(
            id: "r",
            name: "상대",
            archetype: archetype,
            teamID: "t",
            teamName: "구단",
            record: "기록",
            profile: "설명"
        )
    }

    /// 데스크톱 `proRival.ts`와 같은 표를 써야 두 플랫폼이 같은 상대를 만난다.
    func testArchetypeDerivationMatchesDesktopTable() {
        XCTAssertEqual(ProRivalBatterStats.batter(for: rival("중심타선 거포")).power, 63)
        XCTAssertEqual(ProRivalBatterStats.batter(for: rival("무결점 컨택")).contact, 63)
        XCTAssertEqual(ProRivalBatterStats.batter(for: rival("선구안 좋은 1번")).discipline, 64)
        XCTAssertEqual(ProRivalBatterStats.batter(for: rival("빠른 발")).contact, 58)
    }

    func testUnknownArchetypeFallsBackToTheBalancedProfile() {
        let derived = ProRivalBatterStats.batter(for: rival("알 수 없는 유형"))
        XCTAssertEqual(derived.contact, ProRivalBatterStats.defaultBatter.contact)
        XCTAssertEqual(derived.power, ProRivalBatterStats.defaultBatter.power)
        XCTAssertEqual(derived.name, "상대", "이름은 라이벌에서 그대로 이어받아야 합니다.")
    }

    func testMissingRivalUsesTheDefaultOpponent() {
        XCTAssertEqual(ProRivalBatterStats.batter(for: nil).id, ProRivalBatterStats.defaultBatter.id)
    }

    /// 파생 타순과 수비 수치는 코어 검증 범위(20~80) 안이어야 승부가 시작된다.
    func testDerivedLineupAndDefenseStayInRange() {
        let lineup = ProRivalBatterStats.lineup(rival: rival("갭 파워"), teamID: "seoul_comets")
        XCTAssertGreaterThanOrEqual(lineup.count, 4)
        XCTAssertEqual(Set(lineup.map(\.id)).count, lineup.count, "타순에 중복 id가 있습니다.")
        for batter in lineup {
            for value in [batter.contact, batter.discipline, batter.power] {
                XCTAssertTrue((20...80).contains(value))
            }
        }
        let defense = ProRivalBatterStats.defense(teamID: "seoul_comets")
        XCTAssertEqual(Set((defense.fielders ?? []).map(\.position)).count, defense.fielders?.count)
        for fielder in defense.fielders ?? [] {
            for value in [fielder.range, fielder.glove, fielder.arm] {
                XCTAssertTrue((20...80).contains(value))
            }
        }
    }

    func testScoutingReadIsValidForTheKernel() {
        for archetype in ["중심타선 거포", "무결점 컨택", "선구안 좋은 1번", "알 수 없음"] {
            let scouting = ProRivalBatterStats.scouting(for: rival(archetype))
            XCTAssertTrue((20...80).contains(scouting.chaseTendency))
            XCTAssertTrue((0...100).contains(scouting.reliability))
            XCTAssertTrue((0...2).contains(scouting.hotZone.row))
            XCTAssertTrue((0...2).contains(scouting.coldZone.column))
        }
    }

    /// 사다리는 데스크톱 `ratingScale.ts`와 같은 눈금을 써야 성장 카드의 뜻이 갈리지 않는다.
    func testRatingLadderMatchesTheSharedScale() {
        XCTAssertEqual(RatingScale.meaning(78), "세대 최고 수준")
        XCTAssertEqual(RatingScale.meaning(50), "프로 평균")
        XCTAssertEqual(RatingScale.meaning(44), "고교 상위권 도전")
        XCTAssertEqual(RatingScale.meaning(21), "기본기 다지는 단계")
        XCTAssertEqual(RatingScale.nextStep(50)?.minimum, 55)
        XCTAssertNil(RatingScale.nextStep(80))
        XCTAssertEqual(RatingScale.position(20), 0)
        XCTAssertEqual(RatingScale.position(80), 1)
    }

    /// 성장 카드는 오른 항목만 보여 준다.
    func testGainsOnlyReportIncreases() {
        let before = PitcherSnapshot(id: "p", name: "n", stuff: 40, command: 40, movement: 40, stamina: 40)
        let after = PitcherSnapshot(id: "p", name: "n", stuff: 43, command: 40, movement: 39, stamina: 41)
        let gains = MobileCareerStore.gains(before: before, after: after)
        XCTAssertEqual(gains.map(\.label), ["구위", "체력"])
        XCTAssertEqual(gains.first?.before, 40)
        XCTAssertEqual(gains.first?.after, 43)
        XCTAssertTrue(MobileCareerStore.gains(before: nil, after: after).isEmpty)
    }

    /// 평면 3D 시리즈는 4개씩 끊어 0.1cm 단위를 미터로 바꾼다.
    func testTrajectoryDecoding() {
        let series = [0, 100, 18_400, 1_800, 200, -50, 9_200, 1_100]
        let samples = TrajectorySample.decode(series)
        XCTAssertEqual(samples.count, 2)
        XCTAssertEqual(samples[0].forwardMeters, 18.4, accuracy: 0.001)
        XCTAssertEqual(samples[1].lateralMeters, -0.05, accuracy: 0.001)
        XCTAssertEqual(samples[1].heightMeters, 1.1, accuracy: 0.001)
        XCTAssertTrue(TrajectorySample.decode(nil).isEmpty)
        XCTAssertTrue(TrajectorySample.decode([0, 1, 2, 3]).isEmpty, "표본이 하나뿐이면 궤적을 그릴 수 없습니다.")
    }

    /// 존 라벨은 row·column 순서를 데스크톱과 같게 읽어야 한다.
    func testZoneLabels() {
        XCTAssertEqual(PitchCopy.zone(PitchZone(row: 0, column: 0)), "높은 몸쪽")
        XCTAssertEqual(PitchCopy.zone(PitchZone(row: 1, column: 1)), "가운데")
        XCTAssertEqual(PitchCopy.zone(PitchZone(row: 2, column: 2)), "낮은 바깥쪽")
    }
}
