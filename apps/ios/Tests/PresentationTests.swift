import SwiftUI
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
    /// 스탬프 우선순위 — 홈런 > 연속 스트릭(2+) > 이닝 종료 삼진 > 없음.
    /// 스트릭이 이닝 종료를 이기는 이유: "3타자 연속"은 쌓아 온 서사고 이닝 종료는 사실 하나다.
    func testHighlightStampEscalatesWithStrikeoutStreak() {
        XCTAssertEqual(
            HighlightStamp.kind(outcome: .swingingStrike, plateResult: .strikeout,
                                inningEnded: true, landingDistanceTenthsMeters: nil,
                                consecutiveStrikeouts: 3),
            .strikeoutStreak(count: 3)
        )
        XCTAssertEqual(
            HighlightStamp.kind(outcome: .calledStrike, plateResult: .strikeout,
                                inningEnded: true, landingDistanceTenthsMeters: nil,
                                consecutiveStrikeouts: 1),
            .inningEndingStrikeout
        )
        // 홈런은 스트릭 여부와 무관하게 홈런이다(맞은 순간 스트릭은 이미 끊겼다).
        XCTAssertEqual(
            HighlightStamp.kind(outcome: .homeRun, plateResult: .hit,
                                inningEnded: false, landingDistanceTenthsMeters: 1_150,
                                consecutiveStrikeouts: 4),
            .homeRun(distanceMeters: 115)
        )
        // 이닝 중간의 단발 삼진은 스탬프가 없다 — 매 삼진마다 찍으면 배경이 된다.
        XCTAssertNil(
            HighlightStamp.kind(outcome: .swingingStrike, plateResult: .strikeout,
                                inningEnded: false, landingDistanceTenthsMeters: nil,
                                consecutiveStrikeouts: 1)
        )
    }

    /// 회차 카드가 실제로 이미지가 되는지 — 공유 버튼은 렌더 실패 시 숨으므로,
    /// 렌더가 조용히 죽으면 기능 전체가 조용히 사라진다. 그걸 여기서 잡는다.
    @MainActor
    func testLifeCardRendersToAnImage() {
        let record = HighSchoolCareerStore.LifeRecord(
            lifeNumber: 3, playerName: "김솔", schoolName: "서울덕성고", drafted: true,
            evaluationScore: 82, teamName: "부산 돌핀스", memories: [], games: 5,
            strikeouts: 31, walks: 4, runsAllowed: 3, soulPoints: 44,
            nicknames: ["삼진 사냥꾼", "탈삼진 머신"],
            chronicle: ["1학년 봄 — 서울덕성고 입학. 3년이 시작됩니다.",
                        "2학년 여름 — '탈삼진 머신'(이)라는 별명을 얻었습니다.",
                        "3학년 여름 — 드래프트 1라운드 부산 돌핀스 지명. 3년이 응답받았습니다."]
        )
        let renderer = ImageRenderer(content: LifeCardView(record: record))
        renderer.scale = 2
        let image = renderer.uiImage
        XCTAssertNotNil(image, "회차 카드가 이미지로 렌더되지 않습니다.")
        if let image, let data = image.pngData(),
           let dir = ProcessInfo.processInfo.environment["TMPDIR"] {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("life-card.png")
            try? data.write(to: url)
            print("CARD_EXPORT: \(url.path)")
        }
    }

    /// 조사·금액 표기 — "서울덕성고으로"와 "12,000만 원"은 기계가 쓴 글의 신호다.
    func testKoreanCopyParticlesAndMoney() {
        XCTAssertEqual(KoreanCopy.ro("서울덕성고"), "로")
        XCTAssertEqual(KoreanCopy.ro("한밭"), "으로")
        XCTAssertEqual(KoreanCopy.ro("서울"), "로", "ㄹ 받침은 '로'다.")
        XCTAssertEqual(KoreanCopy.objectParticle(number: 22), "를")
        XCTAssertEqual(KoreanCopy.objectParticle(number: 8), "을")
        XCTAssertEqual(KoreanCopy.objectParticle(number: 10), "을")
        XCTAssertEqual(KoreanCopy.money(won: 120_000_000), "1억 2,000만 원")
        XCTAssertEqual(KoreanCopy.money(won: 90_000_000), "9,000만 원")
        XCTAssertEqual(KoreanCopy.money(won: 200_000_000), "2억 원")
    }

    /// 위기 차단 스탬프 — 실점 없이 닫은 이닝의 마지막 인플레이 아웃에만 찍힌다.
    /// 실점하며 끝난 이닝에 찍히면 "축하"가 거짓말이 된다.
    func testInningShutdownStampRequiresAScorelessEnd() {
        XCTAssertEqual(
            HighlightStamp.kind(outcome: .inPlayOut, plateResult: .inPlayOut,
                                inningEnded: true, landingDistanceTenthsMeters: nil,
                                runsScored: 0),
            .inningShutdown
        )
        XCTAssertNil(
            HighlightStamp.kind(outcome: .inPlayOut, plateResult: .inPlayOut,
                                inningEnded: true, landingDistanceTenthsMeters: nil,
                                runsScored: 1),
            "실점하며 끝난 이닝은 위기 차단이 아니다."
        )
        XCTAssertNil(
            HighlightStamp.kind(outcome: .inPlayOut, plateResult: .inPlayOut,
                                inningEnded: false, landingDistanceTenthsMeters: nil,
                                runsScored: 0),
            "이닝 중간의 아웃에는 찍히지 않는다."
        )
    }

    func testZoneLabels() {
        XCTAssertEqual(PitchCopy.zone(PitchZone(row: 0, column: 0)), "높은 몸쪽")
        XCTAssertEqual(PitchCopy.zone(PitchZone(row: 1, column: 1)), "가운데")
        XCTAssertEqual(PitchCopy.zone(PitchZone(row: 2, column: 2)), "낮은 바깥쪽")
    }

    func testPitchBuildCopyTranslatesEngineValuesIntoPlayerLanguage() {
        let readout = PitchAbilityReadout(
            pitchType: .slider,
            stuffRating: 61,
            commandRating: 57,
            movementRating: 66,
            staminaRating: 58,
            whiffRating: 64,
            weakContactRating: 59,
            nominalVelocityTenthsKPH: 1_327,
            fatigueCost: 1
        )

        XCTAssertEqual(PitchBuildCopy.velocity(readout.nominalVelocityTenthsKPH), "132.7")
        XCTAssertEqual(
            PitchBuildCopy.moment(.movement, readout: readout),
            "키운 변화가 살아난 공 · 움직임 66 · 범타 59"
        )
        XCTAssertEqual(
            PitchBuildCopy.accessibilitySummary(readout),
            "기준 구속 132.7킬로미터, 코스 57, 움직임 66, 체력 58, 한 구 팔 부담 1"
        )
    }
}
