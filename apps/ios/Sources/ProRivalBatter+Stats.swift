import Foundation
import SimulationCore

/// 프로 라이벌 타자(`ProCareerSnapshot.currentRival`)는 아키타입 문구만 갖고 타격 수치가 없다.
/// 중요 경기 투구 시뮬레이션에 쓰도록 아키타입에서 공 맞히기·볼 고르기·장타력을 결정론적으로
/// 파생한다. 데스크톱 `apps/windows/src/proRival.ts`와 같은 표를 쓰므로 두 플랫폼에서 같은
/// 상대가 같은 성향으로 나온다. 이름·id는 그대로 이어받아 리포트의 상대가 커리어 화면의
/// 라이벌과 일치하게 한다.
enum ProRivalBatterStats {
    /// 구세이브·아키타입 미상일 때의 기본 상대. 기존 하드코딩 상대(중심타자)와 같은 균형형 수치.
    static let defaultBatter = BatterSnapshot(
        id: "pro-opponent-cleanup",
        name: "오재민",
        contact: 52,
        discipline: 50,
        power: 55
    )

    private struct Profile {
        let match: [String]
        let contact: Int
        let discipline: Int
        let power: Int
    }

    /// 위에서부터 먼저 걸리는 성향을 쓴다(파워 신호가 가장 강함).
    private static let profiles: [Profile] = [
        Profile(match: ["거포"], contact: 48, discipline: 48, power: 63),
        Profile(match: ["홈런"], contact: 47, discipline: 45, power: 62),
        Profile(match: ["파워"], contact: 46, discipline: 49, power: 64),
        Profile(match: ["컨택", "무결점"], contact: 63, discipline: 56, power: 44),
        Profile(match: ["교타", "정확"], contact: 61, discipline: 54, power: 44),
        Profile(match: ["선구안", "출루"], contact: 51, discipline: 64, power: 46),
        Profile(match: ["갭"], contact: 55, discipline: 52, power: 52),
        Profile(match: ["빠른 발", "빠른발", "도루"], contact: 58, discipline: 52, power: 45),
        Profile(match: ["득점권", "해결사", "중심"], contact: 54, discipline: 53, power: 55)
    ]

    static func batter(for rival: ProRivalBatter?) -> BatterSnapshot {
        guard let rival else { return defaultBatter }
        for profile in profiles where profile.match.contains(where: { rival.archetype.contains($0) }) {
            return BatterSnapshot(
                id: rival.id,
                name: rival.name,
                contact: profile.contact,
                discipline: profile.discipline,
                power: profile.power
            )
        }
        return BatterSnapshot(
            id: rival.id,
            name: rival.name,
            contact: defaultBatter.contact,
            discipline: defaultBatter.discipline,
            power: defaultBatter.power
        )
    }

    /// 라이벌 뒤에 이어지는 타순. 중요 경기는 한 이닝이라 라이벌 + 후속 타자 세 명이면 충분하다.
    /// 실존 선수와 무관한 가상 인물만 쓴다(AGENTS.md).
    private static let followUpNames = ["여준호", "심우재", "표시윤", "명하람", "국지훈", "노경환"]

    static func lineup(rival: ProRivalBatter?, teamID: String) -> [BatterSnapshot] {
        var rng = SplitMix64(seed: seedValue("lineup|\(teamID)|\(rival?.id ?? "none")"))
        var batters = [batter(for: rival)]
        var usedNames: Set<String> = [batters[0].name]
        for slot in 0..<3 {
            var name = followUpNames[rng.nextInt(upperBound: followUpNames.count)]
            var guardCount = 0
            while usedNames.contains(name), guardCount < followUpNames.count {
                name = followUpNames[rng.nextInt(upperBound: followUpNames.count)]
                guardCount += 1
            }
            usedNames.insert(name)
            batters.append(
                BatterSnapshot(
                    id: "\(teamID)-lineup-\(slot)",
                    name: name,
                    contact: 42 + rng.nextInt(upperBound: 19),
                    discipline: 40 + rng.nextInt(upperBound: 21),
                    power: 40 + rng.nextInt(upperBound: 21),
                    batSide: rng.nextInt(upperBound: 3) == 0 ? .left : .right
                )
            )
        }
        return batters
    }

    /// 아키타입에서 스카우팅 리포트의 진짜 값을 파생한다. 화면에 보이는 것은 코어가 이 값을
    /// 신뢰도만큼 흐린 추정치이므로(ScoutingEstimate), 여기 값이 곧 정답이 되지는 않는다.
    static func scouting(for rival: ProRivalBatter?) -> BatterScoutingSnapshot {
        let archetype = rival?.archetype ?? ""
        let powerHitter = ["거포", "홈런", "파워"].contains { archetype.contains($0) }
        let contactHitter = ["컨택", "교타", "정확", "무결점"].contains { archetype.contains($0) }
        let patient = ["선구안", "출루"].contains { archetype.contains($0) }
        return BatterScoutingSnapshot(
            hotZone: powerHitter ? PitchZone(row: 1, column: 1) : PitchZone(row: 1, column: 0),
            coldZone: powerHitter ? PitchZone(row: 2, column: 2) : PitchZone(row: 0, column: 2),
            pitchStrength: contactHitter ? .slider : .fourSeam,
            pitchWeakness: powerHitter ? .changeup : .curveball,
            chaseTendency: patient ? 32 : (powerHitter ? 58 : 47),
            // 프로 중요 경기는 처음 만나는 상대다. 관측이 쌓이면서 확신이 올라가는 편이
            // 정답을 그냥 알려 주는 것보다 승부를 만든다(ScoutingEstimate).
            reliability: 45
        )
    }

    /// 소속 구단에서 파생한 우리 팀 수비. 이름은 프로젝트 고유 가상 인물이다.
    static func defense(teamID: String) -> DefenseSnapshot {
        var rng = SplitMix64(seed: seedValue("defense|\(teamID)"))
        let names = ["유시환", "임태오", "나건우", "배준서", "하민규", "조유찬", "신태양", "도경훈"]
        let positions: [FielderPosition] = [
            .catcher, .firstBase, .secondBase, .shortstop, .leftField, .centerField, .rightField, .thirdBase
        ]
        var fielders: [FielderSnapshot] = [
            FielderSnapshot(id: "f-p", name: "본인", position: .pitcher, range: 48, glove: 52, arm: 60)
        ]
        for (index, position) in positions.enumerated() {
            fielders.append(
                FielderSnapshot(
                    id: "f-\(position.rawValue)",
                    name: names[index],
                    position: position,
                    range: 46 + rng.nextInt(upperBound: 22),
                    glove: 48 + rng.nextInt(upperBound: 20),
                    arm: 48 + rng.nextInt(upperBound: 22)
                )
            )
        }
        return DefenseSnapshot(infield: 55, outfield: 54, arm: 56, fielders: fielders)
    }

    /// FNV-1a. 코어의 `StableHash`는 internal이라 셸에서 쓸 수 없어 같은 식을 여기에 둔다.
    private static func seedValue(_ value: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01B3
        }
        return hash
    }
}
