import Foundation

/// 대표 유산 후보 합성 규칙 버전. 후보 payload를 저장할 때 함께 동결한다.
///
/// nil과 알 수 없는 미래 값은 출시 규칙 v1으로 fail-closed한다. 기존 2-인자 API도
/// 항상 v1을 사용하므로 카탈로그가 늘어도 이미 저장된 회차의 후보가 움직이지 않는다.
public enum CareerSignatureLegacyRulesVersion: Int, Codable, CaseIterable, Hashable, Sendable {
    case v1 = 1

    public static let current = CareerSignatureLegacyRulesVersion.v1

    public static func resolve(storedValue: Int?) -> CareerSignatureLegacyRulesVersion {
        storedValue.flatMap(Self.init(rawValue:)) ?? .v1
    }
}

/// 대표 유산의 영구 저장 ID. raw value는 저장·해금 목록에서 바꾸지 않는다.
public enum CareerSignatureLegacyID: String, Codable, CaseIterable, Hashable, Sendable {
    case powerImprint = "power_imprint"
    case commandMap = "command_map"
    case breakingTrace = "breaking_trace"
    case enduranceRhythm = "endurance_rhythm"
    case gamecraftLedger = "gamecraft_ledger"
    case batteryPromise = "battery_promise"
}

/// 서로 다른 투수 빌드 축. 후보 셋에는 같은 family가 두 번 들어가지 않는다.
public enum CareerSignatureLegacyFamily: String, Codable, CaseIterable, Hashable, Sendable {
    case power
    case command
    case breaking
    case endurance
    case gamecraft
    case battery
}

public enum CareerLineageRulesVersion: Int, Codable, CaseIterable, Sendable {
    case v1 = 1
    public static let current = CareerLineageRulesVersion.v1
}

/// 같은 감각을 실제로 남긴 선수 수에서 다시 계산되는 장기 숙련. 별도 화폐나 가변 원장이 없다.
public struct CareerLineageMastery: Codable, Equatable, Sendable {
    public let family: CareerSignatureLegacyFamily
    public let contributions: Int
    public let rank: Int
    public let nextThreshold: Int?

    public init(family: CareerSignatureLegacyFamily, contributions: Int) {
        self.family = family
        self.contributions = max(0, contributions)
        switch contributions {
        case 6...: rank = 3; nextThreshold = nil
        case 3...: rank = 2; nextThreshold = 6
        case 1...: rank = 1; nextThreshold = 3
        default: rank = 0; nextThreshold = 1
        }
    }
}

/// 이번 선수가 실제로 장착해 시작한 하나의 계보 효과. 진행 중 밸런스가 바뀌지 않게 동결한다.
public struct CareerLineageLoadout: Codable, Equatable, Sendable {
    public let rulesVersion: Int
    public let legacyID: CareerSignatureLegacyID
    public let masteryRank: Int
    public let contributions: Int
    public let sourceLifeNumber: Int?

    public init(
        rulesVersion: Int = CareerLineageRulesVersion.current.rawValue,
        legacyID: CareerSignatureLegacyID,
        masteryRank: Int,
        contributions: Int,
        sourceLifeNumber: Int? = nil
    ) {
        self.rulesVersion = rulesVersion
        self.legacyID = legacyID
        self.masteryRank = min(3, max(0, masteryRank))
        self.contributions = max(0, contributions)
        self.sourceLifeNumber = sourceLifeNumber
    }
}

public enum CareerLineageMasteryRules {
    public static func masteries(
        from selectedLegacyIDs: [CareerSignatureLegacyID]
    ) -> [CareerLineageMastery] {
        let counts = selectedLegacyIDs.reduce(into: [CareerSignatureLegacyFamily: Int]()) { result, id in
            result[CareerSignatureLegacy.definition(for: id).family, default: 0] += 1
        }
        return CareerSignatureLegacyFamily.allCases.map {
            CareerLineageMastery(family: $0, contributions: counts[$0, default: 0])
        }
    }

    public static func mastery(
        for id: CareerSignatureLegacyID,
        selectedLegacyIDs: [CareerSignatureLegacyID]
    ) -> CareerLineageMastery {
        let family = CareerSignatureLegacy.definition(for: id).family
        return masteries(from: selectedLegacyIDs).first { $0.family == family }
            ?? CareerLineageMastery(family: family, contributions: 0)
    }

    /// 기본 +4 뒤에 적용하는 v1 숙련. rank 3 직접 보너스는 정확히 두 방향에 +1씩이며,
    /// 재능 상한에 막힌 값은 다른 능력으로 옮기지 않는다.
    public static func apply(
        loadout: CareerLineageLoadout?,
        pitcher: PitcherSnapshot,
        talent: TalentSnapshot
    ) -> (pitcher: PitcherSnapshot, talent: TalentSnapshot, catcherTrust: Int) {
        guard let loadout else { return (pitcher, talent, 50) }
        let family = CareerSignatureLegacy.definition(for: loadout.legacyID).family
        var updatedTalent = talent
        if loadout.masteryRank >= 2 {
            let abilities: [TalentAbility] = switch family {
            case .power: [.stuff]
            case .command: [.command]
            case .breaking: [.movement]
            case .endurance: [.stamina]
            case .gamecraft: [pitcher.command <= pitcher.movement ? .command : .movement]
            case .battery: []
            }
            for ability in abilities {
                let maximum = max(0, updatedTalent.grade(ability).bloomThreshold - 1)
                updatedTalent.setPressure(min(maximum, updatedTalent.pressure(ability) + 2), for: ability)
            }
        }

        guard loadout.masteryRank >= 3 else {
            return (pitcher, updatedTalent, family == .battery && loadout.masteryRank >= 2 ? 55 : 50)
        }
        let bonus: CareerSignatureLegacyEffect = switch family {
        case .power, .endurance: .init(stuff: 1, stamina: 1)
        case .command, .breaking: .init(command: 1, movement: 1)
        case .gamecraft, .battery: .init(command: 1, stamina: 1)
        }
        func capped(_ current: Int, _ add: Int, _ ability: TalentAbility) -> Int {
            min(updatedTalent.ceiling(ability), current + add)
        }
        let updatedPitcher = PitcherSnapshot(
            id: pitcher.id,
            name: pitcher.name,
            stuff: capped(pitcher.stuff, bonus.stuff, .stuff),
            command: capped(pitcher.command, bonus.command, .command),
            movement: capped(pitcher.movement, bonus.movement, .movement),
            stamina: capped(pitcher.stamina, bonus.stamina, .stamina),
            pitchProfiles: pitcher.pitchProfiles,
            throwingHand: pitcher.throwingHand
        )
        return (updatedPitcher, updatedTalent, family == .battery ? 55 : 50)
    }
}

/// 다음 선수의 시작 능력에 한 번만 더하는 작고 고정된 효과.
public struct CareerSignatureLegacyEffect: Codable, Equatable, Sendable {
    public let stuff: Int
    public let command: Int
    public let movement: Int
    public let stamina: Int

    public var totalRatingBonus: Int { stuff + command + movement + stamina }

    public init(stuff: Int = 0, command: Int = 0, movement: Int = 0, stamina: Int = 0) {
        self.stuff = stuff
        self.command = command
        self.movement = movement
        self.stamina = stamina
    }

    public func applying(to pitcher: PitcherSnapshot) -> PitcherSnapshot {
        PitcherSnapshot(
            id: pitcher.id,
            name: pitcher.name,
            stuff: Self.bounded(pitcher.stuff + stuff),
            command: Self.bounded(pitcher.command + command),
            movement: Self.bounded(pitcher.movement + movement),
            stamina: Self.bounded(pitcher.stamina + stamina),
            pitchProfiles: pitcher.pitchProfiles,
            throwingHand: pitcher.throwingHand
        )
    }

    private static func bounded(_ value: Int) -> Int { min(80, max(20, value)) }
}

/// 프로 은퇴까지 이어진 회차에서 대표 유산의 근거로 남기는 통산 기록.
///
/// `inningsOuts`는 ⅓이닝 단위의 정수라 저장과 합산 과정에서 소수 오차가 생기지 않는다.
public struct CareerSignatureLegacyProEvidence: Codable, Equatable, Sendable {
    public let finalPitcher: PitcherSnapshot
    public let seasons: Int
    public let games: Int
    public let starts: Int
    public let inningsOuts: Int
    public let strikeouts: Int
    public let walks: Int
    public let awards: [String]

    public init(
        finalPitcher: PitcherSnapshot,
        seasons: Int,
        games: Int,
        starts: Int,
        inningsOuts: Int,
        strikeouts: Int,
        walks: Int,
        awards: [String]
    ) {
        self.finalPitcher = finalPitcher
        self.seasons = seasons
        self.games = games
        self.starts = starts
        self.inningsOuts = inningsOuts
        self.strikeouts = strikeouts
        self.walks = walks
        self.awards = awards
    }
}

/// 후보가 왜 이 회차의 대표 유산으로 뽑혔는지 되짚을 수 있는 실제 기록.
public struct CareerSignatureLegacyEvidence: Codable, Equatable, Sendable {
    public let summary: String
    public let ratingGrowth: Int?
    public let performance: CareerPerformanceSnapshot?
    public let selectedAwakenings: [AwakeningID]
    public let matchedAwakenings: [AwakeningID]
    public let relationshipTarget: RelationshipTarget?
    public let relationshipTrust: Int?
    /// 프로 진출 전 후보에는 nil이다. optional이라 기존 동결 payload도 그대로 열린다.
    public let proPerformance: CareerSignatureLegacyProEvidence?

    public init(
        summary: String,
        ratingGrowth: Int? = nil,
        performance: CareerPerformanceSnapshot? = nil,
        selectedAwakenings: [AwakeningID] = [],
        matchedAwakenings: [AwakeningID] = [],
        relationshipTarget: RelationshipTarget? = nil,
        relationshipTrust: Int? = nil,
        proPerformance: CareerSignatureLegacyProEvidence? = nil
    ) {
        self.summary = summary
        self.ratingGrowth = ratingGrowth
        self.performance = performance
        self.selectedAwakenings = selectedAwakenings
        self.matchedAwakenings = matchedAwakenings
        self.relationshipTarget = relationshipTarget
        self.relationshipTrust = relationshipTrust
        self.proPerformance = proPerformance
    }
}

/// 한 회차의 성장 방향과 경기 기록에서 합성한 `대표 유산` 후보.
public struct CareerSignatureLegacy: Codable, Equatable, Identifiable, Sendable {
    public let id: CareerSignatureLegacyID
    public let family: CareerSignatureLegacyFamily
    public let title: String
    public let detail: String
    public let effect: CareerSignatureLegacyEffect
    public let evidence: CareerSignatureLegacyEvidence

    public init(
        id: CareerSignatureLegacyID,
        family: CareerSignatureLegacyFamily,
        title: String,
        detail: String,
        effect: CareerSignatureLegacyEffect,
        evidence: CareerSignatureLegacyEvidence
    ) {
        self.id = id
        self.family = family
        self.title = title
        self.detail = detail
        self.effect = effect
        self.evidence = evidence
    }

    /// 저장된 ID를 UI와 시작 효과가 함께 쓰는 단일 정의로 해석한다.
    public static func definition(for id: CareerSignatureLegacyID) -> CareerSignatureLegacy {
        let sharedEvidence = CareerSignatureLegacyEvidence(summary: "이 대표 유산의 고정 시작 효과입니다.")
        switch id {
        case .powerImprint:
            return .init(
                id: id, family: .power, title: "마운드에 남은 불꽃",
                detail: "강한 공으로 승부한 감각이 다음 투수의 첫 공에 스며듭니다.",
                effect: .init(stuff: 3, stamina: 1), evidence: sharedEvidence
            )
        case .commandMap:
            return .init(
                id: id, family: .command, title: "미트 끝의 지도",
                detail: "원하는 곳에 공을 놓던 궤적이 다음 투수의 기준점이 됩니다.",
                effect: .init(command: 3, movement: 1), evidence: sharedEvidence
            )
        case .breakingTrace:
            return .init(
                id: id, family: .breaking, title: "손끝에 남은 궤적",
                detail: "타자 앞에서 공을 꺾던 손끝 감각이 다음 투수에게 이어집니다.",
                effect: .init(command: 1, movement: 3), evidence: sharedEvidence
            )
        case .enduranceRhythm:
            return .init(
                id: id, family: .endurance, title: "긴 이닝의 호흡",
                detail: "끝까지 투구 동작을 지킨 호흡이 다음 투수의 몸에 남습니다.",
                effect: .init(stuff: 1, stamina: 3), evidence: sharedEvidence
            )
        case .gamecraftLedger:
            return .init(
                id: id, family: .gamecraft, title: "이닝을 읽는 장부",
                detail: "타자의 노림수와 경기 흐름을 읽은 기록이 다음 투수의 판단을 엽니다.",
                effect: .init(command: 2, movement: 1, stamina: 1), evidence: sharedEvidence
            )
        case .batteryPromise:
            return .init(
                id: id, family: .battery, title: "사인 사이의 약속",
                detail: "포수와 한 공씩 쌓은 믿음이 다음 투수의 침착한 출발을 돕습니다.",
                effect: .init(command: 2, stamina: 2), evidence: sharedEvidence
            )
        }
    }

    /// 시작과 끝의 능력 차, 중요 경기 합계, 선택한 각성, 세 관계를 모두 반영해
    /// 서로 다른 빌드 family 세 개를 결정론적으로 고른다.
    public static func candidates(
        startingPitcher: PitcherSnapshot,
        finalState: HighSchoolCareerSnapshot,
        candidateLimit: Int = 3
    ) -> [CareerSignatureLegacy] {
        candidates(
            startingPitcher: startingPitcher,
            finalState: finalState,
            rulesVersion: .v1,
            candidateLimit: candidateLimit
        )
    }

    /// 저장소가 가진 optional 정수 버전용 호환 경로. nil·미지원 값은 v1로 닫힌다.
    public static func candidates(
        startingPitcher: PitcherSnapshot,
        finalState: HighSchoolCareerSnapshot,
        rulesVersion storedRulesVersion: Int?,
        candidateLimit: Int = 3
    ) -> [CareerSignatureLegacy] {
        candidates(
            startingPitcher: startingPitcher,
            finalState: finalState,
            rulesVersion: CareerSignatureLegacyRulesVersion.resolve(storedValue: storedRulesVersion),
            candidateLimit: candidateLimit
        )
    }

    public static func candidates(
        startingPitcher: PitcherSnapshot,
        finalState: HighSchoolCareerSnapshot,
        rulesVersion: CareerSignatureLegacyRulesVersion,
        candidateLimit: Int = 3
    ) -> [CareerSignatureLegacy] {
        switch rulesVersion {
        case .v1:
            v1Candidates(
                startingPitcher: startingPitcher,
                finalState: finalState,
                candidateLimit: candidateLimit
            )
        }
    }

    /// 프로 은퇴 기록까지 반영하는 저장소용 경로. nil·미지원 값은 v1로 닫힌다.
    /// 기존 고교 후보 API는 이 경로를 호출하지 않아 이미 동결된 payload가 바뀌지 않는다.
    public static func candidates(
        startingPitcher: PitcherSnapshot,
        highSchoolState: HighSchoolCareerSnapshot,
        proCareer: ProCareerSnapshot,
        rulesVersion storedRulesVersion: Int?,
        candidateLimit: Int = 3
    ) -> [CareerSignatureLegacy] {
        candidates(
            startingPitcher: startingPitcher,
            highSchoolState: highSchoolState,
            proCareer: proCareer,
            rulesVersion: CareerSignatureLegacyRulesVersion.resolve(storedValue: storedRulesVersion),
            candidateLimit: candidateLimit
        )
    }

    public static func candidates(
        startingPitcher: PitcherSnapshot,
        highSchoolState: HighSchoolCareerSnapshot,
        proCareer: ProCareerSnapshot,
        rulesVersion: CareerSignatureLegacyRulesVersion,
        candidateLimit: Int = 3
    ) -> [CareerSignatureLegacy] {
        switch rulesVersion {
        case .v1:
            v1Candidates(
                startingPitcher: startingPitcher,
                highSchoolState: highSchoolState,
                proCareer: proCareer,
                candidateLimit: candidateLimit
            )
        }
    }

    private static func v1Candidates(
        startingPitcher: PitcherSnapshot,
        finalState: HighSchoolCareerSnapshot,
        candidateLimit: Int
    ) -> [CareerSignatureLegacy] {
        let growth = Growth(
            stuff: max(0, finalState.pitcher.stuff - startingPitcher.stuff),
            command: max(0, finalState.pitcher.command - startingPitcher.command),
            movement: max(0, finalState.pitcher.movement - startingPitcher.movement),
            stamina: max(0, finalState.pitcher.stamina - startingPitcher.stamina)
        )
        let scored = CareerSignatureLegacyID.allCases.map { id -> (legacy: CareerSignatureLegacy, score: Int) in
            let base = definition(for: id)
            return (
                legacy: base.withEvidence(evidence(for: base.family, growth: growth, state: finalState)),
                score: score(for: base.family, growth: growth, state: finalState)
            )
        }
        return scored.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.legacy.id.rawValue < $1.legacy.id.rawValue
        }.prefix(normalizedCandidateLimit(candidateLimit)).map(\.legacy)
    }

    private static func v1Candidates(
        startingPitcher: PitcherSnapshot,
        highSchoolState: HighSchoolCareerSnapshot,
        proCareer: ProCareerSnapshot,
        candidateLimit: Int
    ) -> [CareerSignatureLegacy] {
        let highSchoolGrowth = Growth(
            stuff: max(0, highSchoolState.pitcher.stuff - startingPitcher.stuff),
            command: max(0, highSchoolState.pitcher.command - startingPitcher.command),
            movement: max(0, highSchoolState.pitcher.movement - startingPitcher.movement),
            stamina: max(0, highSchoolState.pitcher.stamina - startingPitcher.stamina)
        )
        let proGrowth = Growth(
            stuff: max(0, proCareer.pitcher.stuff - highSchoolState.pitcher.stuff),
            command: max(0, proCareer.pitcher.command - highSchoolState.pitcher.command),
            movement: max(0, proCareer.pitcher.movement - highSchoolState.pitcher.movement),
            stamina: max(0, proCareer.pitcher.stamina - highSchoolState.pitcher.stamina)
        )
        let totalGrowth = Growth(
            stuff: max(0, proCareer.pitcher.stuff - startingPitcher.stuff),
            command: max(0, proCareer.pitcher.command - startingPitcher.command),
            movement: max(0, proCareer.pitcher.movement - startingPitcher.movement),
            stamina: max(0, proCareer.pitcher.stamina - startingPitcher.stamina)
        )
        let proPerformance = proEvidence(from: proCareer)
        let scored = CareerSignatureLegacyID.allCases.map { id -> (legacy: CareerSignatureLegacy, score: Int) in
            let base = definition(for: id)
            return (
                legacy: base.withEvidence(proEvidence(
                    for: base.family,
                    growth: totalGrowth,
                    highSchoolState: highSchoolState,
                    proPerformance: proPerformance
                )),
                score: score(for: base.family, growth: highSchoolGrowth, state: highSchoolState)
                    + proScore(
                        for: base.family,
                        growth: proGrowth,
                        performance: proPerformance,
                        managerTrust: proCareer.managerTrust,
                        catcherTrust: proCareer.catcherTrust
                    )
            )
        }
        return scored.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.legacy.id.rawValue < $1.legacy.id.rawValue
        }.prefix(normalizedCandidateLimit(candidateLimit)).map(\.legacy)
    }

    /// 후보 확장 부스트가 있더라도 정의된 서로 다른 family 수를 넘길 수 없다.
    /// 0 이하 요청은 프로토콜 오용이지만, 저장 복구 경로에서 빈 후보로 막히지 않게 1로 닫는다.
    private static func normalizedCandidateLimit(_ requested: Int) -> Int {
        min(CareerSignatureLegacyID.allCases.count, max(1, requested))
    }

    /// optional 하나만 받아 고정 효과를 한 번 적용한다. nil은 값 정체성이다.
    public static func apply(
        _ id: CareerSignatureLegacyID?,
        to pitcher: PitcherSnapshot
    ) -> PitcherSnapshot {
        guard let id else { return pitcher }
        return definition(for: id).effect.applying(to: pitcher)
    }

    private struct Growth {
        let stuff: Int
        let command: Int
        let movement: Int
        let stamina: Int
    }

    private func withEvidence(_ evidence: CareerSignatureLegacyEvidence) -> CareerSignatureLegacy {
        CareerSignatureLegacy(
            id: id, family: family, title: title, detail: detail, effect: effect, evidence: evidence
        )
    }

    private static func score(
        for family: CareerSignatureLegacyFamily,
        growth: Growth,
        state: HighSchoolCareerSnapshot
    ) -> Int {
        let games = state.performance.importantGamesCompleted
        let matched = matchedAwakenings(for: family, in: state.selectedAwakenings).count
        let coach = state.managerTrust ?? state.relationshipTrust
        let catcher = state.catcherTrust ?? state.relationshipTrust
        let rival = state.rivalTrust ?? state.relationshipTrust
        switch family {
        case .power:
            return growth.stuff * 120 + state.performance.strikeouts * 12 + matched * 80 + rival
        case .command:
            let cleanWork = max(0, games * 3 - state.performance.walks)
            return growth.command * 120 + cleanWork * 18 + matched * 80 + coach
        case .breaking:
            return growth.movement * 120 + state.performance.strikeouts * 9 + matched * 80 + catcher
        case .endurance:
            return growth.stamina * 120 + state.performance.pitches / 2 + matched * 80 + coach
        case .gamecraft:
            let damagePrevented = max(0, state.performance.expectedDamage - state.performance.actualDamage)
            return (growth.command + growth.movement) * 60 + damagePrevented / 20
                + matched * 80 + max(coach, catcher, rival)
        case .battery:
            let cleanWork = max(0, games * 3 - state.performance.walks)
            return growth.command * 60 + cleanWork * 12 + matched * 100 + catcher * 2
        }
    }

    private static func evidence(
        for family: CareerSignatureLegacyFamily,
        growth: Growth,
        state: HighSchoolCareerSnapshot
    ) -> CareerSignatureLegacyEvidence {
        let performance = state.performance
        let relationship = relationshipEvidence(for: family, state: state)
        let matched = matchedAwakenings(for: family, in: state.selectedAwakenings)
        let familyGrowth: Int
        let lead: String
        switch family {
        case .power:
            familyGrowth = growth.stuff
            lead = "구위 +\(familyGrowth) · \(performance.strikeouts)탈삼진"
        case .command:
            familyGrowth = growth.command
            lead = "제구 +\(familyGrowth) · \(performance.walks)볼넷"
        case .breaking:
            familyGrowth = growth.movement
            lead = "변화구 +\(familyGrowth) · \(performance.strikeouts)탈삼진"
        case .endurance:
            familyGrowth = growth.stamina
            lead = "체력 +\(familyGrowth) · 직접 등판 \(performance.pitches)구"
        case .gamecraft:
            familyGrowth = growth.command + growth.movement
            lead = "제구·변화구 +\(familyGrowth) · 예상 피해 \(performance.expectedDamage) / 실제 \(performance.actualDamage)"
        case .battery:
            familyGrowth = growth.command
            lead = "제구 +\(familyGrowth) · 포수와 쌓은 믿음 \(relationship.trust)"
        }
        let awakeningPart = matched.isEmpty ? "맞닿은 각성 없음" : "맞닿은 각성 \(matched.count)개"
        let summary = "\(lead) · 고교 공식 경기 \(performance.importantGamesCompleted)회 · \(awakeningPart) · \(relationship.label) \(relationship.trust)"
        return CareerSignatureLegacyEvidence(
            summary: summary,
            ratingGrowth: familyGrowth,
            performance: performance,
            selectedAwakenings: state.selectedAwakenings,
            matchedAwakenings: matched,
            relationshipTarget: relationship.target,
            relationshipTrust: relationship.trust
        )
    }

    private static func proEvidence(from career: ProCareerSnapshot) -> CareerSignatureLegacyProEvidence {
        var seasons = career.careerStats
        if seasons.last?.season != career.currentStats.season {
            seasons.append(career.currentStats)
        }
        return CareerSignatureLegacyProEvidence(
            finalPitcher: career.pitcher,
            seasons: seasons.count,
            games: seasons.reduce(0) { $0 + max(0, $1.games) },
            starts: seasons.reduce(0) { $0 + max(0, $1.starts) },
            inningsOuts: seasons.reduce(0) { $0 + max(0, $1.inningsOuts) },
            strikeouts: seasons.reduce(0) { $0 + max(0, $1.strikeouts) },
            walks: seasons.reduce(0) { $0 + max(0, $1.walks) },
            awards: career.awards
        )
    }

    private static func proScore(
        for family: CareerSignatureLegacyFamily,
        growth: Growth,
        performance: CareerSignatureLegacyProEvidence,
        managerTrust: Int,
        catcherTrust: Int
    ) -> Int {
        let pitcher = performance.finalPitcher
        let awardScore = proAwardScore(for: family, awards: performance.awards)
        switch family {
        case .power:
            return growth.stuff * 140 + pitcher.stuff * 8
                + performance.strikeouts * 2 + awardScore
        case .command:
            let controlledOutings = max(0, performance.games * 2 - performance.walks)
            return growth.command * 140 + pitcher.command * 8
                + controlledOutings * 2 + managerTrust * 2 + awardScore
        case .breaking:
            return growth.movement * 140 + pitcher.movement * 8
                + performance.strikeouts * 3 / 2 + awardScore
        case .endurance:
            return growth.stamina * 140 + pitcher.stamina * 8
                + performance.inningsOuts / 2 + performance.starts + awardScore
        case .gamecraft:
            let avoidedWalks = max(0, performance.strikeouts - performance.walks)
            return (growth.command + growth.movement) * 70
                + (pitcher.command + pitcher.movement) * 4
                + avoidedWalks + performance.games + max(managerTrust, catcherTrust) * 2
                + awardScore
        case .battery:
            let controlledOutings = max(0, performance.games * 2 - performance.walks)
            return (growth.command + growth.stamina) * 70
                + (pitcher.command + pitcher.stamina) * 4
                + controlledOutings + performance.games + catcherTrust * 3 + awardScore
        }
    }

    private static func proAwardScore(
        for family: CareerSignatureLegacyFamily,
        awards: [String]
    ) -> Int {
        let keywords: [String]
        switch family {
        case .power, .breaking:
            keywords = ["탈삼진"]
        case .command, .gamecraft, .battery:
            keywords = ["최소 실점", "무실점"]
        case .endurance:
            keywords = ["이닝", "완투"]
        }
        let thematic = awards.filter { award in keywords.contains { award.contains($0) } }.count
        return awards.count * 30 + thematic * 120
    }

    private static func proEvidence(
        for family: CareerSignatureLegacyFamily,
        growth: Growth,
        highSchoolState: HighSchoolCareerSnapshot,
        proPerformance: CareerSignatureLegacyProEvidence
    ) -> CareerSignatureLegacyEvidence {
        let highSchoolEvidence = evidence(for: family, growth: growth, state: highSchoolState)
        let familyGrowth: Int
        let finalRatings: String
        let pitcher = proPerformance.finalPitcher
        switch family {
        case .power:
            familyGrowth = growth.stuff
            finalRatings = "구위 \(pitcher.stuff)"
        case .command:
            familyGrowth = growth.command
            finalRatings = "제구 \(pitcher.command)"
        case .breaking:
            familyGrowth = growth.movement
            finalRatings = "변화구 \(pitcher.movement)"
        case .endurance:
            familyGrowth = growth.stamina
            finalRatings = "체력 \(pitcher.stamina)"
        case .gamecraft:
            familyGrowth = growth.command + growth.movement
            finalRatings = "제구 \(pitcher.command)·변화구 \(pitcher.movement)"
        case .battery:
            familyGrowth = growth.command + growth.stamina
            finalRatings = "제구 \(pitcher.command)·체력 \(pitcher.stamina)"
        }
        let awards = proPerformance.awards.isEmpty
            ? "수상 없음"
            : "수상 \(proPerformance.awards.count)회 · \(proPerformance.awards.joined(separator: " / "))"
        let summary = "\(highSchoolEvidence.summary) · 프로 통산 \(proPerformance.games)경기 \(inningsDescription(proPerformance.inningsOuts)), \(proPerformance.strikeouts)탈삼진 \(proPerformance.walks)볼넷 · 프로 최종 \(finalRatings) · \(awards)"
        return CareerSignatureLegacyEvidence(
            summary: summary,
            ratingGrowth: familyGrowth,
            performance: highSchoolEvidence.performance,
            selectedAwakenings: highSchoolEvidence.selectedAwakenings,
            matchedAwakenings: highSchoolEvidence.matchedAwakenings,
            relationshipTarget: highSchoolEvidence.relationshipTarget,
            relationshipTrust: highSchoolEvidence.relationshipTrust,
            proPerformance: proPerformance
        )
    }

    private static func inningsDescription(_ outs: Int) -> String {
        let safeOuts = max(0, outs)
        let whole = safeOuts / 3
        switch safeOuts % 3 {
        case 1: return "\(whole)⅓이닝"
        case 2: return "\(whole)⅔이닝"
        default: return "\(whole)이닝"
        }
    }

    private static func relationshipEvidence(
        for family: CareerSignatureLegacyFamily,
        state: HighSchoolCareerSnapshot
    ) -> (target: RelationshipTarget, trust: Int, label: String) {
        switch family {
        case .power:
            return (.rival, state.rivalTrust ?? state.relationshipTrust, "라이벌과 쌓은 믿음")
        case .command, .endurance:
            return (.coach, state.managerTrust ?? state.relationshipTrust, "감독과 쌓은 믿음")
        case .breaking, .battery:
            return (.catcher, state.catcherTrust ?? state.relationshipTrust, "포수와 쌓은 믿음")
        case .gamecraft:
            let values: [(RelationshipTarget, Int, String)] = [
                (.coach, state.managerTrust ?? state.relationshipTrust, "감독과 쌓은 믿음"),
                (.catcher, state.catcherTrust ?? state.relationshipTrust, "포수와 쌓은 믿음"),
                (.rival, state.rivalTrust ?? state.relationshipTrust, "라이벌과 쌓은 믿음")
            ]
            return values.max { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
                return lhs.0.rawValue > rhs.0.rawValue
            }!
        }
    }

    private static func matchedAwakenings(
        for family: CareerSignatureLegacyFamily,
        in selected: [AwakeningID]
    ) -> [AwakeningID] {
        selected.filter { awakening in
            switch family {
            case .power:
                return [.explosiveFastball, .risingFourSeam].contains(awakening)
            case .command:
                return [.pinpointEdge, .repeatableRelease, .firstPitchStrike, .scoutComposure].contains(awakening)
            case .breaking:
                return [.disappearingBreaker, .sinkerTunnel, .frozenChangeup, .sweepingSlider, .curveballClock].contains(awakening)
            case .endurance:
                return [.ironArm, .lateInningReserve].contains(awakening)
            case .gamecraft:
                return [.calmUnderPressure, .pickoffRhythm, .twoStrikePlan, .trafficController, .scoutComposure].contains(awakening)
            case .battery:
                return [.batterySync, .pickoffRhythm, .trafficController].contains(awakening)
            }
        }
    }
}
