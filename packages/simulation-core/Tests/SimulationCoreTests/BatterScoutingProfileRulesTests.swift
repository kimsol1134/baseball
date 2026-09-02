import XCTest
@testable import SimulationCore

final class BatterScoutingProfileRulesTests: XCTestCase {
    func testNineArchetypesTimesThirtyRivalsCoverFourPitchesAndSixZones() {
        var weaknesses = Set<PitchType>()
        var coldZones = Set<PitchZone>()
        for archetype in BatterScoutingArchetype.allCases {
            var archetypeWeaknesses = Set<PitchType>()
            for index in 0..<30 {
                let profile = BatterScoutingProfileRules.profile(
                    archetype: archetype,
                    seedToken: "rival-\(archetype.rawValue)-\(index)|season-1"
                )
                weaknesses.insert(profile.pitchWeakness)
                archetypeWeaknesses.insert(profile.pitchWeakness)
                coldZones.insert(profile.coldZone)
                XCTAssertNotEqual(profile.hotZone, profile.coldZone, "\(archetype) rival \(index)")
                XCTAssertNotEqual(profile.pitchWeakness, profile.pitchStrength, "\(archetype) rival \(index)")
                XCTAssertTrue((0...2).contains(profile.hotZone.row))
                XCTAssertTrue((0...2).contains(profile.coldZone.column))
            }
            XCTAssertGreaterThan(
                archetypeWeaknesses.count,
                1,
                "\(archetype.rawValue) collapsed to a single weakness: \(archetypeWeaknesses)"
            )
        }
        XCTAssertEqual(weaknesses, Set(PitchType.allCases), "weaknesses seen: \(weaknesses)")
        XCTAssertGreaterThanOrEqual(coldZones.count, 6, "cold zones seen: \(coldZones.count)")
    }

    func testArchetypeKeywordsMatchTheProTableOrder() {
        XCTAssertEqual(BatterScoutingProfileRules.archetype(from: "중심타선 거포"), .slugger)
        XCTAssertEqual(BatterScoutingProfileRules.archetype(from: "당겨치는 홈런형"), .homeRun)
        XCTAssertEqual(BatterScoutingProfileRules.archetype(from: "장신 파워형"), .power)
        XCTAssertEqual(BatterScoutingProfileRules.archetype(from: "컨택 무결점형"), .contact)
        XCTAssertEqual(BatterScoutingProfileRules.archetype(from: "교타 정확형"), .spray)
        XCTAssertEqual(BatterScoutingProfileRules.archetype(from: "선구안 출루형"), .patient)
        XCTAssertEqual(BatterScoutingProfileRules.archetype(from: "중장거리 갭 히터형"), .gap)
        XCTAssertEqual(BatterScoutingProfileRules.archetype(from: "빠른 발 도루형"), .speed)
        XCTAssertEqual(BatterScoutingProfileRules.archetype(from: "빠른 발 갭 타자형"), .gap)
        XCTAssertEqual(BatterScoutingProfileRules.archetype(from: "득점권 해결사형"), .clutch)
        XCTAssertEqual(BatterScoutingProfileRules.archetype(from: "알 수 없음"), .clutch)
    }

    func testSameSeedTokenIsDeterministic() {
        let first = BatterScoutingProfileRules.profile(archetype: .power, seedToken: "pro-rival-busan|2")
        let second = BatterScoutingProfileRules.profile(archetype: .power, seedToken: "pro-rival-busan|2")
        XCTAssertEqual(first, second)
    }
}
