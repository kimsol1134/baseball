public enum RivalAdaptationBand: String, Codable, CaseIterable, Sendable {
    case noData = "no_data"
    case watching
    case learning
    case lockedOn = "locked_on"
}

public struct RivalPitchObservation: Codable, Equatable, Sendable {
    public let pitchType: PitchType
    public let zone: PitchZone
    public let zoneIntent: ZoneIntent
    public let balls: Int
    public let strikes: Int
    public let outcome: PitchOutcome

    public init(
        pitchType: PitchType,
        zone: PitchZone,
        zoneIntent: ZoneIntent,
        balls: Int,
        strikes: Int,
        outcome: PitchOutcome
    ) {
        self.pitchType = pitchType
        self.zone = zone
        self.zoneIntent = zoneIntent
        self.balls = balls
        self.strikes = strikes
        self.outcome = outcome
    }
}

public struct RivalMemorySnapshot: Codable, Equatable, Sendable {
    public let matchupID: String
    public let revision: UInt64
    public let plateAppearancesSeen: Int
    public let totalPitchesSeen: Int
    public let recentObservations: [RivalPitchObservation]

    public init(
        matchupID: String,
        revision: UInt64,
        plateAppearancesSeen: Int,
        totalPitchesSeen: Int,
        recentObservations: [RivalPitchObservation]
    ) {
        self.matchupID = matchupID
        self.revision = revision
        self.plateAppearancesSeen = plateAppearancesSeen
        self.totalPitchesSeen = totalPitchesSeen
        self.recentObservations = recentObservations
    }
}

public struct RivalAdaptationSnapshot: Codable, Equatable, Sendable {
    public let level: Int
    public let band: RivalAdaptationBand
    public let evidenceCount: Int
    public let detectedPitch: PitchType?
    public let detectedZone: PitchZone?
    public let confidence: Int
    public let warning: String

    public init(
        level: Int,
        band: RivalAdaptationBand,
        evidenceCount: Int,
        detectedPitch: PitchType?,
        detectedZone: PitchZone?,
        confidence: Int,
        warning: String
    ) {
        self.level = level
        self.band = band
        self.evidenceCount = evidenceCount
        self.detectedPitch = detectedPitch
        self.detectedZone = detectedZone
        self.confidence = confidence
        self.warning = warning
    }
}

public struct RivalMemoryEngine: Sendable {
    public static let maximumObservations = 24

    public init() {}

    public func emptyMemory(
        pitcher: PitcherSnapshot,
        batter: BatterSnapshot
    ) -> RivalMemorySnapshot {
        RivalMemorySnapshot(
            matchupID: matchupID(pitcher: pitcher, batter: batter),
            revision: 0,
            plateAppearancesSeen: 0,
            totalPitchesSeen: 0,
            recentObservations: []
        )
    }

    public func validate(
        _ memory: RivalMemorySnapshot?,
        pitcher: PitcherSnapshot,
        batter: BatterSnapshot
    ) throws {
        guard let memory else { return }
        guard memory.matchupID == matchupID(pitcher: pitcher, batter: batter) else {
            throw SimulationError.invalidRivalMemory("matchupID does not match pitcher and batter")
        }
        guard memory.plateAppearancesSeen >= 0,
              memory.totalPitchesSeen >= memory.recentObservations.count,
              memory.recentObservations.count <= Self.maximumObservations else {
            throw SimulationError.invalidRivalMemory("counters or observation count are invalid")
        }
        for observation in memory.recentObservations {
            guard (0...2).contains(observation.zone.row),
                  (0...2).contains(observation.zone.column),
                  (0...3).contains(observation.balls),
                  (0...2).contains(observation.strikes) else {
                throw SimulationError.invalidRivalMemory("an observation is outside the valid range")
            }
        }
    }

    public func analyze(
        _ memory: RivalMemorySnapshot?,
        context: PlateAppearanceContext
    ) -> RivalAdaptationSnapshot {
        guard let memory, !memory.recentObservations.isEmpty else {
            return RivalAdaptationSnapshot(
                level: 0,
                band: .noData,
                evidenceCount: 0,
                detectedPitch: nil,
                detectedZone: nil,
                confidence: 0,
                warning: "아직 이 투수의 공을 충분히 보지 못했습니다."
            )
        }

        let matchingCount = memory.recentObservations.filter {
            ($0.strikes == 2) == (context.strikes == 2)
                && ($0.balls == 3) == (context.balls == 3)
        }
        let evidence = matchingCount.count >= 3 ? matchingCount : memory.recentObservations
        let topPitch = mostFrequentPitch(in: evidence)
        let topZone = mostFrequentZone(in: evidence)
        let pitchShare = topPitch.count * 1_000 / evidence.count
        let zoneShare = topZone.count * 1_000 / evidence.count
        let sampleSignal = max(0, evidence.count - 2) * 15
        let pitchSignal = max(0, pitchShare - 400) / 2
        let zoneSignal = max(0, zoneShare - 350) / 4
        let rematchSignal = min(memory.plateAppearancesSeen * 80, 240)
        var level = min(900, sampleSignal + pitchSignal + zoneSignal + rematchSignal)
        if memory.plateAppearancesSeen == 0 {
            level = min(level, 420)
        }
        let detectedPitch = evidence.count >= 4 && pitchShare >= 500 ? topPitch.pitchType : nil
        let detectedZone = evidence.count >= 4 && zoneShare >= 500 ? topZone.zone : nil
        let confidence = min(950, evidence.count * 28 + max(pitchShare, zoneShare) / 2)
        let band: RivalAdaptationBand
        switch level {
        case 0: band = .noData
        case ..<250: band = .watching
        case 250..<600: band = .learning
        default: band = .lockedOn
        }

        let warning: String
        if let detectedPitch, let detectedZone {
            warning = "\(pitchDisplayName(detectedPitch))과 \(zoneDisplayName(detectedZone)) 반복을 함께 읽고 있습니다."
        } else if let detectedPitch {
            warning = "\(pitchDisplayName(detectedPitch)) 사용 비중이 읽히기 시작했습니다."
        } else if let detectedZone {
            warning = "\(zoneDisplayName(detectedZone)) 코스 반복이 읽히기 시작했습니다."
        } else {
            warning = "아직 확정적인 패턴은 없지만 투구 기록을 쌓고 있습니다."
        }
        return RivalAdaptationSnapshot(
            level: level,
            band: band,
            evidenceCount: evidence.count,
            detectedPitch: detectedPitch,
            detectedZone: detectedZone,
            confidence: confidence,
            warning: warning
        )
    }

    public func record(
        _ memory: RivalMemorySnapshot?,
        pitcher: PitcherSnapshot,
        batter: BatterSnapshot,
        context: PlateAppearanceContext,
        call: PitchCall,
        outcome: PitchOutcome,
        plateAppearanceEnded: Bool
    ) -> RivalMemorySnapshot {
        let current = memory ?? emptyMemory(pitcher: pitcher, batter: batter)
        let observation = RivalPitchObservation(
            pitchType: call.pitchType,
            zone: call.zone,
            zoneIntent: call.zoneIntent,
            balls: context.balls,
            strikes: context.strikes,
            outcome: outcome
        )
        let observations = Array(
            (current.recentObservations + [observation]).suffix(Self.maximumObservations)
        )
        return RivalMemorySnapshot(
            matchupID: current.matchupID,
            revision: current.revision + 1,
            plateAppearancesSeen: current.plateAppearancesSeen + (plateAppearanceEnded ? 1 : 0),
            totalPitchesSeen: current.totalPitchesSeen + 1,
            recentObservations: observations
        )
    }

    private func matchupID(pitcher: PitcherSnapshot, batter: BatterSnapshot) -> String {
        "\(pitcher.id):\(batter.id)"
    }

    private func mostFrequentPitch(
        in observations: [RivalPitchObservation]
    ) -> (pitchType: PitchType, count: Int) {
        var best = (pitchType: PitchType.fourSeam, count: -1)
        for pitchType in PitchType.allCases {
            let count = observations.lazy.filter { $0.pitchType == pitchType }.count
            if count > best.count {
                best = (pitchType, count)
            }
        }
        return best
    }

    private func mostFrequentZone(
        in observations: [RivalPitchObservation]
    ) -> (zone: PitchZone, count: Int) {
        var best = (zone: PitchZone(row: 0, column: 0), count: -1)
        for index in 0..<9 {
            let zone = PitchZone(row: index / 3, column: index % 3)
            let count = observations.lazy.filter { $0.zone == zone }.count
            if count > best.count {
                best = (zone, count)
            }
        }
        return best
    }

    private func pitchDisplayName(_ pitchType: PitchType) -> String {
        switch pitchType {
        case .fourSeam: return "포심"
        case .slider: return "슬라이더"
        case .curveball: return "커브"
        case .changeup: return "체인지업"
        }
    }

    private func zoneDisplayName(_ zone: PitchZone) -> String {
        let vertical = ["높은", "가운데", "낮은"][zone.row]
        let horizontal = ["몸쪽", "가운데", "바깥쪽"][zone.column]
        return vertical == "가운데" && horizontal == "가운데"
            ? "가운데"
            : "\(vertical) \(horizontal)"
    }
}
