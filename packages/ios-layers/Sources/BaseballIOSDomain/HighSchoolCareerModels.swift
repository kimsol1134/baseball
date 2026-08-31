import Foundation
import SimulationCore

/// 다음 회차로 넘기는 것. 환생 루프의 저장 단위다.
public struct Inheritance: Codable, Equatable, Sendable {
    public var lifeNumber: Int
    public var memories: [MemoryCardID]
    public var soulPoints: Int
    public var karmas: [KarmaID]
    /// 지난 선수의 플레이 기록에서 만들어진 대표 유산 한 자리. 효과는 stable ID를
    /// 코어가 다시 해석하므로 저장된 설명 문구가 바뀌어도 밸런스는 움직이지 않는다.
    /// optional이라 이 기능 이전 저장본은 유산 없이 그대로 시작한다.
    public var equippedSignatureLegacyID: CareerSignatureLegacyID? = nil
    /// 지금까지 발견한 대표 유산. 선택하지 않은 두 후보도 도감에 남겨, 실패한 회차가
    /// 다음 회차의 빌드 선택지를 실제로 넓힌다. 같은 ID는 최초 발견 기록만 보존한다.
    public var unlockedSignatureLegacies: [CareerSignatureLegacy]? = nil
    /// 야구혼으로 이미 접은 프로 커리어. 같은 커리어를 두 번 계산하지 않기 위한 표식이다.
    /// 옵셔널이라 이 필드가 없는 옛 저장본도 그대로 열린다.
    public var creditedProCareerID: String?
    /// 평생 획득한 야구혼 총량. soulPoints는 현재 상점에서 쓸 수 있는 지갑 잔액이다.
    /// 옵셔널: 없는 옛 저장본은 잔액을 총량으로 본다(쓴 만큼은 복구 불가, 최선의 근사).
    public var soulTotalEarned: Int?
    /// 다음 선수에게 자동으로 스며드는 누적분. 고교 정산·주간 보상은 여기에 쌓이고,
    /// 프로 보너스는 지갑에만 들어가 사용자가 상점에서 쓰도록 분리한다. 없는 옛 저장은
    /// 당시 단일 총량 전체가 자동 적용되던 의미를 보존하기 위해 soulTotal로 읽는다.
    public var automaticSoulEarned: Int? = nil
    /// 야구혼이 시작 능력으로 스며드는 곡선의 저장 버전. 없는 옛 저장본은 코어에서
    /// v1로 해석하고, 새로 정산한 선수부터 current를 기록해 업데이트 뒤에도 같은
    /// 시작 능력을 재현한다.
    public var inheritanceRulesVersion: Int? = nil

    /// 평생 획득 총량. 구매로 잔액이 줄어도 줄지 않는다.
    public var soulTotal: Int { max(soulTotalEarned ?? soulPoints, soulPoints) }
    /// 자동 성장 계산에만 쓰는 총량. 프로 보너스나 구매 잔액과 독립적이다.
    public var automaticSoulTotal: Int { max(0, automaticSoulEarned ?? soulTotal) }

    public init(
        lifeNumber: Int,
        memories: [MemoryCardID],
        soulPoints: Int,
        karmas: [KarmaID],
        equippedSignatureLegacyID: CareerSignatureLegacyID? = nil,
        unlockedSignatureLegacies: [CareerSignatureLegacy]? = nil,
        creditedProCareerID: String? = nil,
        soulTotalEarned: Int? = nil,
        automaticSoulEarned: Int? = nil,
        inheritanceRulesVersion: Int? = nil
    ) {
        self.lifeNumber = lifeNumber
        self.memories = memories
        self.soulPoints = soulPoints
        self.karmas = karmas
        self.equippedSignatureLegacyID = equippedSignatureLegacyID
        self.unlockedSignatureLegacies = unlockedSignatureLegacies
        self.creditedProCareerID = creditedProCareerID
        self.soulTotalEarned = soulTotalEarned
        self.automaticSoulEarned = automaticSoulEarned
        self.inheritanceRulesVersion = inheritanceRulesVersion
    }

    public static let firstLife = Inheritance(lifeNumber: 1, memories: [], soulPoints: 0, karmas: [])

    public var equippedSignatureLegacy: CareerSignatureLegacy? {
        guard let equippedSignatureLegacyID else { return nil }
        let definition = CareerSignatureLegacy.definition(for: equippedSignatureLegacyID)
        guard let discovered = unlockedSignatureLegacies?.first(where: {
            $0.id == equippedSignatureLegacyID
        }) else { return definition }
        // 발견 당시 근거는 보존하되, 다음 회차에 적용할 문구·효과는 코어의 현재 stable
        // ID 정의를 쓴다. 화면은 옛 payload를, 실제 시작은 새 정의를 쓰는 불일치를 막는다.
        return CareerSignatureLegacy(
            id: definition.id,
            family: definition.family,
            title: definition.title,
            detail: definition.detail,
            effect: definition.effect,
            evidence: discovered.evidence
        )
    }
}

/// 끝난 회차 한 장. 환생 게임인데 **지난 회차를 볼 방법이 아예 없었다**(품질 평가 §4.3).
///
/// "N회차의 나"들이 쌓이는 게임인데 그 역사가 어디에도 남지 않으면, 회차를 반복할 이유가
/// 다음 회차의 능력치뿐이 된다. 여기 있는 값은 전부 계승을 확정하는 순간 이미 손에 있다.
public struct LifeRecord: Codable, Equatable, Identifiable {
    public var id: Int { lifeNumber }
    public let lifeNumber: Int
    public let playerName: String
    /// One-life portrait identity. Missing old records intentionally fall back to playerName.
    public var appearanceSeed: String? = nil
    public let schoolName: String?
    public let drafted: Bool
    public let evaluationScore: Int
    public let teamName: String?
    public let memories: [MemoryCardID]
    public let games: Int
    public let strikeouts: Int
    public let walks: Int
    public let runsAllowed: Int
    public let soulPoints: Int
    /// **왜 그 회차가 그렇게 끝났는지**를 아카이브가 답할 수 있게 하는 값들.
    /// 전부 옵셔널이라 이 필드가 없는 옛 기록도 그대로 읽힌다.
    public var talent: TalentSnapshot?
    public var awakenings: [AwakeningID]?
    public var karmas: [KarmaID]?
    public var harshness: String?
    public var schoolStrength: String?
    /// 이번 회차에 얻은 별명. 없는 옛 기록은 nil이다.
    public var nicknames: [String]? = nil
    /// 이번 회차의 연대기("2학년 여름 — …"). 없는 옛 기록은 nil이다.
    public var chronicle: [String]? = nil
    /// 이 삶에서 팔 경고나 재활을 실제로 겪었는지. 다음 삶의 통증 회상이 이 값에 기대며,
    /// 없는 옛 기록은 당시 연대기와 관계 기억으로 보수적으로 복원한다.
    public var hadArmWarning: Bool? = nil
    /// 3년을 함께한 사람들. 회차가 끝나면 감독·포수·숙적이 통째로 증발하던 것을
    /// 여기 남긴다(3차 패널 P2 — 애착 축). 없는 옛 기록은 nil이다.
    public var coachName: String? = nil
    public var catcherName: String? = nil
    public var rivalName: String? = nil
    public var coachTrust: Int? = nil
    public var catcherTrust: Int? = nil
    public var rivalTrust: Int? = nil
    /// 이 회차가 어떤 사람이었는가. 없는 옛 기록은 nil이다.
    public var personality: String? = nil
    /// 이 회차의 careerID("career-시드-life-N"). 카드에 시드를 각인해
    /// "같은 시드로 도전"이 가능하게 한다. 없는 옛 기록은 nil이다.
    public var careerID: String? = nil
    /// 웨이브 1 이전 기록에는 없는 약속 결과. 모두 optional이라 그대로 디코드된다.
    public var pledgeID: String? = nil
    /// 카탈로그의 문구·등급·보상이 바뀌어도 지난 선택은 완료 당시 그대로 읽힌다.
    public var pledgeTitle: String? = nil
    public var pledgeTier: String? = nil
    public var pledgeRewardPermille: Int? = nil
    public var pledgeAchieved: Bool? = nil
    public var pledgeProgressCurrent: Int? = nil
    public var pledgeProgressTarget: Int? = nil
    /// Compound conditions must survive in human and normalized form for archive accessibility.
    public var pledgeProgressLine: String? = nil
    public var pledgeProgressRatioPermille: Int? = nil
    /// 회차 규칙이 이후 버전에서 달라져도 지난 카드의 이름은 그대로 남긴다.
    public var windID: String? = nil
    public var windTitle: String? = nil
    /// 이 선수가 떠나며 남긴 한마디와 실제 3년의 대표 순간. 새 카피가 배포돼도
    /// 끝난 사람의 말이 바뀌지 않도록 완료 시점에 동결한다. 없는 옛 기록은 화면에서
    /// 당시 기록으로 결정론적으로 복원한다.
    public var playerLegacy: PlayerLegacy? = nil
    /// 이 선수가 직접 키운 능력과 실제 경기 기록이 다음 세대에 남긴 대표 유산.
    /// 완료 시점의 근거까지 동결해 이후 밸런스·카피 변경이 과거 기록을 바꾸지 않는다.
    public var signatureLegacy: CareerSignatureLegacy? = nil
    /// 함께 발견한 세 후보도 회차에 귀속해 둔다. 선택하지 않은 두 후보가 발견 목록에는
    /// 남으면서 정작 어느 선수가 만든 유산인지 아카이브에서 사라지면 수집의 의미가 약해진다.
    public var signatureLegacyCandidates: [CareerSignatureLegacy]? = nil
    /// 이 선수가 시작할 때 실제로 장착한 유산과 당시 숙련. 이후 승급해도 과거는 바뀌지 않는다.
    public var inheritedLineageLoadout: CareerLineageLoadout? = nil

    /// 3년 동안 실제로 던진 공의 수. 성적을 "몇 경기"보다 구체적으로 말한다.
    public var pitches: Int? = nil
    /// 이닝(아웃 수)과 피안타. 방어율·WHIP은 이 둘이 있어야 만들어진다.
    public var outs: Int? = nil
    public var hits: Int? = nil
    /// 시작과 끝의 네 능력. 이 회차가 **무엇을 얼마나 키웠는지**가 카드의 자랑거리다.
    /// 없는 옛 기록은 nil이라 카드가 그 줄을 통째로 접는다.
    public var abilityStart: AbilityLine? = nil
    public var abilityFinal: AbilityLine? = nil
    /// The few relationship choices that defined this player. Optional keeps old archives
    /// readable; a run records at most one meaningful moment per chapter.
    public var bondMemories: [PlayerBondMemory]? = nil
    /// Stable IDs of the rebirth scenes this player actually encountered.
    public var rebirthEventIDs: [String]? = nil

    public init(
        lifeNumber: Int,
        playerName: String,
        appearanceSeed: String? = nil,
        schoolName: String?,
        drafted: Bool,
        evaluationScore: Int,
        teamName: String?,
        memories: [MemoryCardID],
        games: Int,
        strikeouts: Int,
        walks: Int,
        runsAllowed: Int,
        soulPoints: Int,
        talent: TalentSnapshot? = nil,
        awakenings: [AwakeningID]? = nil,
        karmas: [KarmaID]? = nil,
        harshness: String? = nil,
        schoolStrength: String? = nil,
        nicknames: [String]? = nil,
        chronicle: [String]? = nil,
        hadArmWarning: Bool? = nil,
        coachName: String? = nil,
        catcherName: String? = nil,
        rivalName: String? = nil,
        coachTrust: Int? = nil,
        catcherTrust: Int? = nil,
        rivalTrust: Int? = nil,
        personality: String? = nil,
        careerID: String? = nil,
        pledgeID: String? = nil,
        pledgeTitle: String? = nil,
        pledgeTier: String? = nil,
        pledgeRewardPermille: Int? = nil,
        pledgeAchieved: Bool? = nil,
        pledgeProgressCurrent: Int? = nil,
        pledgeProgressTarget: Int? = nil,
        pledgeProgressLine: String? = nil,
        pledgeProgressRatioPermille: Int? = nil,
        windID: String? = nil,
        windTitle: String? = nil,
        playerLegacy: PlayerLegacy? = nil,
        signatureLegacy: CareerSignatureLegacy? = nil,
        signatureLegacyCandidates: [CareerSignatureLegacy]? = nil,
        inheritedLineageLoadout: CareerLineageLoadout? = nil,
        pitches: Int? = nil,
        outs: Int? = nil,
        hits: Int? = nil,
        abilityStart: AbilityLine? = nil,
        abilityFinal: AbilityLine? = nil,
        bondMemories: [PlayerBondMemory]? = nil,
        rebirthEventIDs: [String]? = nil
    ) {
        self.lifeNumber = lifeNumber
        self.playerName = playerName
        self.appearanceSeed = appearanceSeed
        self.schoolName = schoolName
        self.drafted = drafted
        self.evaluationScore = evaluationScore
        self.teamName = teamName
        self.memories = memories
        self.games = games
        self.strikeouts = strikeouts
        self.walks = walks
        self.runsAllowed = runsAllowed
        self.soulPoints = soulPoints
        self.talent = talent
        self.awakenings = awakenings
        self.karmas = karmas
        self.harshness = harshness
        self.schoolStrength = schoolStrength
        self.nicknames = nicknames
        self.chronicle = chronicle
        self.hadArmWarning = hadArmWarning
        self.coachName = coachName
        self.catcherName = catcherName
        self.rivalName = rivalName
        self.coachTrust = coachTrust
        self.catcherTrust = catcherTrust
        self.rivalTrust = rivalTrust
        self.personality = personality
        self.careerID = careerID
        self.pledgeID = pledgeID
        self.pledgeTitle = pledgeTitle
        self.pledgeTier = pledgeTier
        self.pledgeRewardPermille = pledgeRewardPermille
        self.pledgeAchieved = pledgeAchieved
        self.pledgeProgressCurrent = pledgeProgressCurrent
        self.pledgeProgressTarget = pledgeProgressTarget
        self.pledgeProgressLine = pledgeProgressLine
        self.pledgeProgressRatioPermille = pledgeProgressRatioPermille
        self.windID = windID
        self.windTitle = windTitle
        self.playerLegacy = playerLegacy
        self.signatureLegacy = signatureLegacy
        self.signatureLegacyCandidates = signatureLegacyCandidates
        self.inheritedLineageLoadout = inheritedLineageLoadout
        self.pitches = pitches
        self.outs = outs
        self.hits = hits
        self.abilityStart = abilityStart
        self.abilityFinal = abilityFinal
        self.bondMemories = bondMemories
        self.rebirthEventIDs = rebirthEventIDs
    }

    /// 구위·제구·변화·체력 네 값. 카드와 아카이브가 함께 쓴다.
    public struct AbilityLine: Codable, Equatable {
        public let stuff: Int
        public let command: Int
        public let movement: Int
        public let stamina: Int

        public init(_ pitcher: PitcherSnapshot) {
            stuff = pitcher.stuff
            command = pitcher.command
            movement = pitcher.movement
            stamina = pitcher.stamina
        }

        public var total: Int { stuff + command + movement + stamina }
    }

    /// "미지명 · 평가 57점" / "3라운드 서울 …". 목록 한 줄에 결말이 들어가야 한다.
    public var outcomeLine: String {
        drafted ? "지명 · \(teamName ?? "구단 미정")" : "미지명 · 평가 \(evaluationScore)점"
    }

    public var portraitSeed: String {
        guard let appearanceSeed, !appearanceSeed.isEmpty else { return playerName }
        return appearanceSeed
    }
}

/// 한 선수가 떠날 때 동결해 두는 이야기. 카피 규칙이 훗날 달라져도 이미 끝난
/// 선수의 편지는 바뀌지 않는다. optional로 LifeRecord에 들어가므로 이 기능 이전
/// 저장본도 그대로 열린다.
public struct PlayerLegacy: Codable, Equatable {
    public let title: String
    public let definingMoment: String
    public let farewell: String

    public init(title: String, definingMoment: String, farewell: String) {
        self.title = title
        self.definingMoment = definingMoment
        self.farewell = farewell
    }
}

public struct PlayerBondMemory: Codable, Equatable, Identifiable {
    public enum Kind: String, Codable, Hashable {
        case personality
        case healthChoice = "health_choice"
        case trustMilestone = "trust_milestone"
    }

    public var id: String { "\(chapterNumber):\(eventID):\(kind.rawValue)" }
    public let kind: Kind
    public let eventID: String
    public let eventCategory: String
    public let eventTitle: String
    public let response: RelationshipResponse
    public let subjectName: String?
    public let chapterNumber: Int
    public let trustBefore: Int
    public let trustAfter: Int

    public init(
        kind: Kind,
        eventID: String,
        eventCategory: String,
        eventTitle: String,
        response: RelationshipResponse,
        subjectName: String?,
        chapterNumber: Int,
        trustBefore: Int,
        trustAfter: Int
    ) {
        self.kind = kind
        self.eventID = eventID
        self.eventCategory = eventCategory
        self.eventTitle = eventTitle
        self.response = response
        self.subjectName = subjectName
        self.chapterNumber = chapterNumber
        self.trustBefore = trustBefore
        self.trustAfter = trustAfter
    }

    /// 유대 기억은 회차 로그가 아니라 이 선수를 설명하는 세 장면이다. 구버전 저장에
    /// 중복이 들어 있어도 최초 한 종류만 남기고, 이후 저장부터 같은 계약으로 고정한다.
    public static func normalized(_ memories: [PlayerBondMemory]) -> [PlayerBondMemory] {
        var kinds = Set<Kind>()
        var normalized: [PlayerBondMemory] = []
        for memory in memories where kinds.insert(memory.kind).inserted {
            normalized.append(memory)
            if normalized.count == 3 { break }
        }
        return normalized
    }

    public static func appending(_ memory: PlayerBondMemory, to memories: [PlayerBondMemory]) -> [PlayerBondMemory] {
        let normalized = Self.normalized(memories)
        guard normalized.count < 3,
              !normalized.contains(where: { $0.kind == memory.kind })
        else { return normalized }
        return normalized + [memory]
    }
}

public struct ResponseTally: Codable, Equatable, Sendable {
    public var listen = 0
    public var explain = 0
    public var challenge = 0

    public init(listen: Int = 0, explain: Int = 0, challenge: Int = 0) {
        self.listen = listen
        self.explain = explain
        self.challenge = challenge
    }

    public var personality: Personality? {
        PersonalityRules.personality(listen: listen, explain: explain, challenge: challenge)
    }
}

public struct ChronicleEntry: Codable, Equatable, Sendable {
    /// 언제였는가 — "2학년 여름".
    public let stage: String
    public let text: String

    public init(stage: String, text: String) {
        self.stage = stage
        self.text = text
    }
}

public struct PendingGameCompletion: Codable, Equatable {
    public let id: String
    public let report: ImportantInningReport
    public let achievements: [Achievement]
    public let sequenceTags: [String]
    public let recommendationAcceptanceRate: Double
    public var developmentRulesVersion: Int? = nil
    /// 직접 키운 능력이 실제 결과에서 살아난 공. 옛 영수증은 nil이다.
    public var abilityMomentCount: Int? = nil
    public var abilityMomentTypes: [String]? = nil
    public var manualDeliveryRate: Double? = nil
    public var pitchLearningCompletedAfterGame: Bool? = nil
    public let targetBatters: Int
    public let batters: Int
    public let lifeNumber: Int
    public let actNumber: Int
    public let chapterNumber: Int
    /// `recordImportantGame`가 다음 국면으로 넘긴 경우의 퍼널 계단. nil이면 국면 불변.
    public let enteredPhase: String?
    public let gameGrowth: CareerGameGrowth?
    public let shouldRequestCleanReview: Bool
    public let completedAt: Date

    public init(
        id: String,
        report: ImportantInningReport,
        achievements: [Achievement],
        sequenceTags: [String],
        recommendationAcceptanceRate: Double,
        developmentRulesVersion: Int? = nil,
        abilityMomentCount: Int? = nil,
        abilityMomentTypes: [String]? = nil,
        manualDeliveryRate: Double? = nil,
        pitchLearningCompletedAfterGame: Bool? = nil,
        targetBatters: Int,
        batters: Int,
        lifeNumber: Int,
        actNumber: Int,
        chapterNumber: Int,
        enteredPhase: String?,
        gameGrowth: CareerGameGrowth?,
        shouldRequestCleanReview: Bool,
        completedAt: Date
    ) {
        self.id = id
        self.report = report
        self.achievements = achievements
        self.sequenceTags = sequenceTags
        self.recommendationAcceptanceRate = recommendationAcceptanceRate
        self.developmentRulesVersion = developmentRulesVersion
        self.abilityMomentCount = abilityMomentCount
        self.abilityMomentTypes = abilityMomentTypes
        self.manualDeliveryRate = manualDeliveryRate
        self.pitchLearningCompletedAfterGame = pitchLearningCompletedAfterGame
        self.targetBatters = targetBatters
        self.batters = batters
        self.lifeNumber = lifeNumber
        self.actNumber = actNumber
        self.chapterNumber = chapterNumber
        self.enteredPhase = enteredPhase
        self.gameGrowth = gameGrowth
        self.shouldRequestCleanReview = shouldRequestCleanReview
        self.completedAt = completedAt
    }
}

/// 라이벌 상대 통산(회차 내) 전적. 타석·삼진·안타만 있으면 서사는 화면이 만든다.
public struct RivalLedger: Codable, Equatable, Sendable {
    public var plateAppearances = 0
    public var strikeouts = 0
    public var walks = 0
    public var hits = 0
    public var summaryLine: String? {
        guard plateAppearances > 0 else { return nil }
        return "\(plateAppearances)타석 \(strikeouts)삼진 \(hits)피안타"
    }

    public init(plateAppearances: Int = 0, strikeouts: Int = 0, walks: Int = 0, hits: Int = 0) {
        self.plateAppearances = plateAppearances
        self.strikeouts = strikeouts
        self.walks = walks
        self.hits = hits
    }
}

/// UserDefaults-only state did not follow iCloud to a new device. This optional
/// envelope distinguishes a legacy save with no field from a new save whose player explicitly
/// has not chosen (nil) or skipped (empty string) the current pledge.
public struct CurrentCareerRetention: Codable, Equatable {
    public var careerID: String
    public var pledgeID: String?
    /// nil is a save from before versioning. If it contains a selected/skipped value, v1 is
    /// the only safe interpretation; new decisions always persist v2 explicitly.
    public var pledgeRulesVersion: Int? = nil
    public var rivalLedger: RivalLedger

    public init(
        careerID: String,
        pledgeID: String?,
        pledgeRulesVersion: Int? = nil,
        rivalLedger: RivalLedger
    ) {
        self.careerID = careerID
        self.pledgeID = pledgeID
        self.pledgeRulesVersion = pledgeRulesVersion
        self.rivalLedger = rivalLedger
    }
}
