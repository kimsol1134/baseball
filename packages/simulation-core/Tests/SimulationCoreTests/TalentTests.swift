import XCTest
@testable import SimulationCore

/// 재능과 만개.
///
/// 이 시스템의 목적은 **회차마다 다른 투수가 되는 것**과 **막힌 것이 열리는 순간**이다.
/// 둘 다 "그럴듯한 코드"만으로는 성립하지 않는다 — 실제 회차를 돌려서 벽에 닿고, 두드려서
/// 열리는지를 봐야 한다.
final class TalentTests: XCTestCase {
    private let engine = HighSchoolCareerEngine()

    // MARK: - 뽑기

    func testTalentIsDeterministicPerCareer() {
        XCTAssertEqual(TalentRules.make(careerID: "career-7-life-1"), TalentRules.make(careerID: "career-7-life-1"))
    }

    /// 회차가 바뀌면 재능도 바뀐다. 이게 안 되면 "매번 똑같다"는 문제가 그대로 남는다.
    func testTalentVariesAcrossLives() {
        let talents = (1...12).map { TalentRules.make(careerID: "career-abc-life-\($0)") }
        XCTAssertGreaterThanOrEqual(Set(talents.map { "\($0)" }).count, 8, "회차별 재능이 거의 같습니다")
    }

    /// 규칙 둘: 적어도 하나는 B 이상(시작할 이유), 적어도 하나는 C 이하(만개할 자리).
    func testEveryRunHasStrengthAndWall() {
        for index in 1...200 {
            let talent = TalentRules.make(careerID: "career-\(index)-life-1")
            let grades = TalentAbility.allCases.map { talent.grade($0) }
            XCTAssertTrue(grades.contains { $0 >= .b }, "\(index): 전부 막힌 회차")
            XCTAssertTrue(grades.contains { $0 <= .c }, "\(index): 벽이 하나도 없는 회차")
        }
    }

    /// S가 흔하면 S가 아니다.
    func testGradeDistributionIsBellShaped() {
        var counts: [TalentGrade: Int] = [:]
        for index in 1...400 {
            let talent = TalentRules.make(careerID: "career-\(index)-life-1")
            for ability in TalentAbility.allCases { counts[talent.grade(ability), default: 0] += 1 }
        }
        let total = counts.values.reduce(0, +)
        XCTAssertLessThan(Double(counts[.s] ?? 0) / Double(total), 0.20, "S가 너무 흔합니다")
        XCTAssertGreaterThan(Double(counts[.b] ?? 0) / Double(total), 0.15, "가운데 등급이 얇습니다")
    }

    // MARK: - 한계와 만개

    func testGrowthStopsAtTheCeiling() {
        let talent = TalentSnapshot(stuff: .d, command: .s, movement: .s, stamina: .s)
        let (allowed, _, bloomed) = TalentRules.apply(talent: talent, ability: .stuff, current: 51, points: 2)
        XCTAssertEqual(allowed, 1, "D의 한계는 52다")
        XCTAssertNil(bloomed)
    }

    /// 막힌 훈련은 헛되지 않다. 두드린 횟수가 쌓여 만개가 온다.
    func testBlockedTrainingAccumulatesAndBlooms() {
        var talent = TalentSnapshot(stuff: .d, command: .s, movement: .s, stamina: .s)
        var bloomedAt: Int?
        for attempt in 1...4 {
            let (allowed, updated, bloomed) = TalentRules.apply(
                talent: talent, ability: .stuff, current: 52, points: 1
            )
            if bloomedAt == nil {
                XCTAssertEqual(allowed, 0, "만개 전에는 한계에 닿아 있어 오르지 않는다")
            }
            talent = updated
            if bloomed != nil, bloomedAt == nil { bloomedAt = attempt }
        }
        XCTAssertEqual(bloomedAt, TalentGrade.d.bloomThreshold, "D는 두 번 두드리면 열려야 한다")
        XCTAssertEqual(talent.stuff, .c)
        XCTAssertEqual(talent.stuffPressure, 0, "만개하면 압박이 0으로 돌아간다")
    }

    /// **낮은 등급이 더 빨리 열린다.** 반대로 두면 재능이 나쁜 회차는 시작하자마자 끝난 회차가 된다.
    func testLowerGradesBloomFaster() {
        let thresholds = TalentGrade.allCases.dropLast().map(\.bloomThreshold)
        for (earlier, later) in zip(thresholds, thresholds.dropFirst()) {
            XCTAssertLessThan(earlier, later)
        }
    }

    func testTopGradeNeverBlooms() {
        var talent = TalentSnapshot(stuff: .s, command: .s, movement: .s, stamina: .s)
        for _ in 0..<20 {
            let (_, updated, bloomed) = TalentRules.apply(talent: talent, ability: .stuff, current: 80, points: 1)
            talent = updated
            XCTAssertNil(bloomed)
        }
        XCTAssertEqual(talent.stuff, .s)
    }

    // MARK: - 실제 회차

    /// 한 능력만 집중해서 3년을 던지면 **실제로 벽에 닿고, 두드려서 연다.**
    ///
    /// 처음 잡았던 한계(D 60)는 고교에서 한 번도 걸리지 않아 시스템이 통째로 없는 것과
    /// 같았다. 그 회귀를 여기서 잡는다.
    func testFocusedRunHitsAWallAndBloomsAtLeastOnce() throws {
        var wallSeen = 0
        var bloomSeen = 0
        for seed in 41...52 {
            var result = try engine.start(.init(seed: String(seed * 7717), presetID: "power_prospect"))
            result = try engine.completePrologue(.init(seed: result.nextSeed, state: result.snapshot))
            result = try engine.chooseSchool(.init(seed: result.nextSeed, state: result.snapshot, schoolID: .haedongPower))
            // 재능이 가장 낮은 능력에 3년을 전부 붓는다. 벽에 닿는 가장 빠른 길이다.
            let talent = try XCTUnwrap(result.snapshot.talent)
            let weakest = TalentAbility.allCases.min { talent.grade($0) < talent.grade($1) ? true : false }
            let focus: TrainingFocus = {
                switch weakest ?? .stuff {
                case .stuff: .velocity
                case .command: .command
                case .movement: .breakingBall
                case .stamina: .stamina
                }
            }()
            for _ in 0..<160 {
                switch result.snapshot.phase {
                case .training:
                    result = try engine.commitTraining(
                        .init(seed: result.nextSeed, state: result.snapshot, focus: focus, intensity: .intensive)
                    )
                    if let training = result.snapshot.lastTraining {
                        if training.bloomedAbility != nil { bloomSeen += 1 }
                        if training.growth == 0, training.bloomedAbility == nil, training.focus == focus { wallSeen += 1 }
                    }
                case .relationship:
                    result = try engine.resolveRelationship(.init(seed: result.nextSeed, state: result.snapshot, response: .listen))
                case .importantGame:
                    let number = result.snapshot.performance.importantGamesCompleted + 1
                    result = try engine.recordImportantGame(.init(
                        seed: result.nextSeed, state: result.snapshot,
                        report: .init(scenarioNumber: number, pitches: 18, strikeouts: 4, walks: 1,
                                      runsAllowed: 1, expectedDamage: 500, actualDamage: 400, recommendationAccepted: 8)
                    ))
                case .awakening:
                    result = try engine.chooseAwakening(.init(
                        seed: result.nextSeed, state: result.snapshot,
                        awakening: try XCTUnwrap(result.snapshot.awakeningOptions.first)
                    ))
                case .chapterReview:
                    result = try engine.advanceChapter(.init(seed: result.nextSeed, state: result.snapshot))
                case .draft:
                    result = try engine.resolveDraft(.init(seed: result.nextSeed, state: result.snapshot))
                default:
                    break
                }
                if result.snapshot.draftResult != nil { break }
            }
        }
        XCTAssertGreaterThan(wallSeen, 0, "3년을 한 능력에 부었는데 한 번도 벽에 닿지 않았습니다 — 한계가 너무 높습니다")
        XCTAssertGreaterThan(bloomSeen, 0, "벽에 닿기만 하고 한 번도 열리지 않았습니다 — 만개가 도달 불가능합니다")
    }

    /// 재능이 없는 저장본은 예전과 똑같이 동작한다.
    func testMissingTalentReadsAsUnlimited() {
        XCTAssertEqual(TalentSnapshot.unlimited.ceiling(.stuff), 80)
        let (allowed, _, bloomed) = TalentRules.apply(
            talent: .unlimited, ability: .stuff, current: 70, points: 2
        )
        XCTAssertEqual(allowed, 2)
        XCTAssertNil(bloomed)
    }
}
