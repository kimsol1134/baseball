import Foundation
import SimulationCore
import BaseballIOSDomain

extension HighSchoolPresentation {
    /// 고교 후속 타순. 기본은 기존 세 타자를 유지하고, 긴 승부 장면만 다섯 타자까지
    /// 요청한다. 같은 seed/count는 언제나 같은 타순이라 저장 복구와 재현성이 흔들리지 않는다.
    static func followUpBatters(seedText: String, count: Int = 3) -> [BatterSnapshot] {
        var rng = SplitMix64(seed: seedValue(seedText))
        let names = ["구본휘", "설재빈", "천유겸", "봉시원", "옥준서", "석다온"]
        var used: Set<String> = []
        return (0..<min(max(0, count), names.count)).map { slot in
            var name = names[rng.nextInt(upperBound: names.count)]
            var attempts = 0
            while used.contains(name), attempts < names.count {
                name = names[rng.nextInt(upperBound: names.count)]
                attempts += 1
            }
            used.insert(name)
            return BatterSnapshot(
                id: "hs-lineup-\(slot)",
                name: name,
                // 고교 타자는 프로보다 낮고 편차가 크다.
                //
                // 기본선을 34/32/32에서 45/43/43으로 올렸다. 예전 타순은 평균 44 언저리라
                // 성장한 투수 앞에서 사실상 아웃 자판기였다 — 환생 한 번 없이 3~4경기
                // 연속 무실점이 나온 실제 원인이다. 지금도 평균은 프로 기준(50) 아래이고
                // 편차도 그대로지만, 라이벌 뒤의 타순이 실점을 만들 수 있다.
                //
                // 여기서 더 올리지 않는 이유: 실측에서 이 값은 지명률을 능력 +1당 약
                // 1%p밖에 못 움직인다(60시드에서 52/50/50 → 43%, 60/58/58 → 35%).
                // 목표치까지 밀려면 고교 타자가 프로 평균보다 강해져야 해서 설정이 깨진다.
                // 관문의 높이는 `draftThreshold`가 맡는다.
                contact: 45 + rng.nextInt(upperBound: 24),
                discipline: 43 + rng.nextInt(upperBound: 24),
                power: 43 + rng.nextInt(upperBound: 26),
                batSide: rng.nextInt(upperBound: 3) == 0 ? .left : .right
            )
        }
    }

    /// 우리 학교 수비. 고교라 프로보다 낮다.
    static func defense(schoolID: SchoolID?) -> DefenseSnapshot {
        var rng = SplitMix64(seed: seedValue("hs-defense|\(schoolID?.rawValue ?? "none")"))
        let names = ["유시환", "임태오", "나건우", "배준서", "하민규", "조유찬", "신태양", "도경훈"]
        let positions: [FielderPosition] = [
            .catcher, .firstBase, .secondBase, .shortstop, .leftField, .centerField, .rightField, .thirdBase
        ]
        var fielders = [FielderSnapshot(id: "f-p", name: "본인", position: .pitcher, range: 40, glove: 44, arm: 52)]
        for (index, position) in positions.enumerated() {
            fielders.append(
                FielderSnapshot(
                    id: "f-\(position.rawValue)",
                    name: names[index],
                    position: position,
                    range: 34 + rng.nextInt(upperBound: 22),
                    glove: 34 + rng.nextInt(upperBound: 22),
                    arm: 34 + rng.nextInt(upperBound: 24)
                )
            )
        }
        return DefenseSnapshot(infield: 44, outfield: 42, arm: 45, fielders: fielders)
    }

    /// 라이벌 스카우팅. 정보 명료도가 낮은 회차일수록 처음의 확신이 낮다.
    static func scouting(rival: RivalSnapshot, clarity: DifficultyLevel) -> BatterScoutingSnapshot {
        let powerHitter = rival.power >= 55
        let baseline: Int
        switch clarity {
        case .relaxed: baseline = 100
        case .standard: baseline = 45
        case .challenging: baseline = 22
        }
        return BatterScoutingSnapshot(
            hotZone: powerHitter ? PitchZone(row: 1, column: 1) : PitchZone(row: 1, column: 0),
            coldZone: powerHitter ? PitchZone(row: 2, column: 2) : PitchZone(row: 0, column: 2),
            pitchStrength: rival.contact >= 55 ? .slider : .fourSeam,
            pitchWeakness: powerHitter ? .changeup : .curveball,
            chaseTendency: min(80, max(20, 50 - (rival.discipline - 50))),
            reliability: baseline
        )
    }

    /// FNV-1a. 코어의 `StableHash`는 internal이라 셸에서 쓸 수 없어 같은 식을 여기에 둔다.
    static func summaryCaptures(_ value: String, pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let fullRange = NSRange(value.startIndex..<value.endIndex, in: value)
        guard let match = regex.firstMatch(in: value, range: fullRange) else { return nil }
        return (1..<match.numberOfRanges).compactMap { index in
            Range(match.range(at: index), in: value).map { String(value[$0]) }
        }
    }

    static func chapterGoalFrame(koreanTitle: String) -> ChapterGoal.Frame? {
        switch koreanTitle {
        case "감독의 숙제": .coachAssignment
        case "스카우트의 시선": .scoutAttention
        case "포수의 내기": .catcherBet
        case "나와의 약속": .personalPromise
        default: nil
        }
    }

    static func seedValue(_ value: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01B3
        }
        return hash
    }
}
