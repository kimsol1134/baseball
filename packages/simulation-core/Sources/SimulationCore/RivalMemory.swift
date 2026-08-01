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
    /// Most-frequent pitch in the recent evidence window. Always defined so the batter can
    /// lean on the observed distribution by a continuous amount (see `pitchReadStrength`),
    /// rather than only when a hard detection threshold is crossed.
    public let leanPitch: PitchType
    /// Most-frequent zone in the recent evidence window. See `zoneReadStrength`.
    public let leanZone: PitchZone
    /// Continuous, capped strength (0...) of the pitch-type read. Scales the batter's
    /// anticipation and the resulting contact correction. Non-zero even for a mixed
    /// sequence (small familiarity), hard-capped so a repeated pattern cannot collapse.
    public let pitchReadStrength: Int
    /// Continuous, capped strength (0...) of the zone read. See `pitchReadStrength`.
    public let zoneReadStrength: Int
    public let confidence: Int
    public let warning: String

    public init(
        level: Int,
        band: RivalAdaptationBand,
        evidenceCount: Int,
        detectedPitch: PitchType?,
        detectedZone: PitchZone?,
        leanPitch: PitchType,
        leanZone: PitchZone,
        pitchReadStrength: Int,
        zoneReadStrength: Int,
        confidence: Int,
        warning: String
    ) {
        self.level = level
        self.band = band
        self.evidenceCount = evidenceCount
        self.detectedPitch = detectedPitch
        self.detectedZone = detectedZone
        self.leanPitch = leanPitch
        self.leanZone = leanZone
        self.pitchReadStrength = pitchReadStrength
        self.zoneReadStrength = zoneReadStrength
        self.confidence = confidence
        self.warning = warning
    }
}

public struct RivalMemoryEngine: Sendable {
    public static let maximumObservations = 24

    // MARK: Continuous read-strength tuning
    //
    // The batter's anticipation used to be a 1-bit cliff: a pattern was either "detected"
    // (evidence >= 4 AND share >= 50%) — instantly worth the full `level` correction — or
    // invisible, so an even four-pitch mix was permanently immune. These constants replace
    // that with a smooth curve: the read grows with both sample size and how far the observed
    // distribution leans past uniform, keeps a small non-zero floor even for a mix, and is
    // hard-capped so an infinitely repeated call can no longer collapse the sim.
    /// Evidence count below which a read barely registers (a lone pitch is trivially "100%").
    /// Keeps short / within-plate-appearance memories close to the no-adaptation baseline.
    static let readSampleFloor = 3
    /// Evidence count at which the sample factor saturates.
    static let readSampleSaturation = 18
    /// Pitch share (per-mille) at/below which there is no pattern signal (uniform is 250).
    static let pitchReadBaseline = 260
    /// Zone share (per-mille) at/below which there is no pattern signal (uniform is ~111).
    static let zoneReadBaseline = 150
    /// Small read the batter gets purely from having seen many pitches (removes the mix exemption).
    static let pitchFamiliarityFloor = 60
    static let zoneFamiliarityFloor = 40
    /// Hard caps on the read strengths — the ceiling that bounds the worst-case correction.
    static let pitchReadCap = 300
    static let zoneReadCap = 250
    /// Ceiling applied to `level` before it scales the on-contact bonuses in the resolver.
    /// Below the cap the resolver behaves exactly as before (so short / non-persistent
    /// memories are unchanged); above it the repeated-pattern amplifier stops growing.
    static let resolveDamageCap = 420

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

    /// **상대 벤치가 지켜본다.** 한 명의 타자가 아니라 등판 전체를 한 매치업으로 기억한다.
    ///
    /// 예전에는 기억이 투수-타자 한 쌍에 묶여 있어서, 타자가 바뀌면 화면이 기억을 버려야 했다
    /// (안 버리면 커널이 matchupID 불일치로 거부한다). 그래서 한 타석 안에서만 학습이 일어났고,
    /// `plateAppearancesSeen`이 0에 머물러 적응도가 420에서 하드캡됐다 — "완전히 읽힘"(600 이상)과
    /// 포수의 반복 경고는 **도달할 수 없는 죽은 코드**였다. 스토어 문안이 약속하는
    /// "같은 공을 반복하면 타자가 읽습니다"가 실제 승부에서 성립하지 않았다는 뜻이다.
    ///
    /// 야구에서도 타자 혼자 읽지 않는다. 더그아웃이 함께 보고 다음 타자에게 말해 준다.
    public func benchMemory(pitcher: PitcherSnapshot, benchID: String) -> RivalMemorySnapshot {
        RivalMemorySnapshot(
            matchupID: Self.benchMatchupID(pitcherID: pitcher.id, benchID: benchID),
            revision: 0,
            plateAppearancesSeen: 0,
            totalPitchesSeen: 0,
            recentObservations: []
        )
    }

    /// 벤치 스코프의 매치업 식별자.
    ///
    /// 스코프를 식별자 문자열 자체에 넣는다. 그래야 커널의 호출 규약(파라미터 구조체)을
    /// 바꾸지 않고, 옛 저장본의 타자별 기억도 그대로 통과한다.
    public static func benchMatchupID(pitcherID: String, benchID: String) -> String {
        "\(pitcherID):bench:\(benchID)"
    }

    public func validate(
        _ memory: RivalMemorySnapshot?,
        pitcher: PitcherSnapshot,
        batter: BatterSnapshot
    ) throws {
        guard let memory else { return }
        // 벤치 스코프 기억은 타자가 바뀌어도 같은 매치업이다. 투수만 일치하면 된다.
        let benchPrefix = "\(pitcher.id):bench:"
        guard memory.matchupID == matchupID(pitcher: pitcher, batter: batter)
                || memory.matchupID.hasPrefix(benchPrefix) else {
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
                leanPitch: .fourSeam,
                leanZone: PitchZone(row: 1, column: 1),
                pitchReadStrength: 0,
                zoneReadStrength: 0,
                confidence: 0,
                warning: "아직 이 투수의 공을 충분히 보지 못했습니다."
            )
        }

        let matchingCount = memory.recentObservations.filter {
            ($0.strikes == 2) == (context.strikes == 2)
                && ($0.balls == 3) == (context.balls == 3)
        }
        let evidence = matchingCount.count >= 3 ? matchingCount : memory.recentObservations
        // 실효 표본 — 결과 가중(정타 6 ~ 헛스윙 1, 중립 2)의 합을 관측 수 스케일로.
        // 전량 헛스윙 시퀀스는 실효 표본이 절반 이하로 줄어 '반복해도 덜 읽힌다'가
        // 진짜로 성립한다. share 정규화만으로는 같은 결과끼리 상쇄돼 효과가 0이었다.
        let effectiveCount = max(1, evidence.reduce(0) { $0 + observationWeight($1) } / 2)
        let topPitch = mostFrequentPitch(in: evidence)
        let topZone = mostFrequentZone(in: evidence)
        let pitchShare = topPitch.count * 1_000 / evidence.count
        let zoneShare = topZone.count * 1_000 / evidence.count
        let sampleSignal = max(0, effectiveCount - 2) * 15
        let pitchSignal = max(0, pitchShare - 400) / 2
        let zoneSignal = max(0, zoneShare - 350) / 4
        let rematchSignal = min(memory.plateAppearancesSeen * 80, 240)
        var level = min(900, sampleSignal + pitchSignal + zoneSignal + rematchSignal)
        if memory.plateAppearancesSeen == 0 {
            level = min(level, 420)
        }
        // Continuous read strengths: grow with sample size AND with how far the observed
        // distribution leans past uniform, keep a small floor, and are hard-capped. These —
        // not `level` — drive the batter's anticipation and contact correction downstream,
        // so a repeated pattern is bounded and a mixed sequence is never fully exempt.
        let sampleWeight = min(effectiveCount, Self.readSampleSaturation)
        let patternSample = max(0, sampleWeight - Self.readSampleFloor)
        let patternSpan = Self.readSampleSaturation - Self.readSampleFloor
        let pitchExcess = max(0, pitchShare - Self.pitchReadBaseline)
        let zoneExcess = max(0, zoneShare - Self.zoneReadBaseline)
        let pitchReadStrength = min(
            Self.pitchReadCap,
            (pitchExcess * patternSample / patternSpan)
                + (patternSample * Self.pitchFamiliarityFloor / patternSpan)
        )
        let zoneReadStrength = min(
            Self.zoneReadCap,
            (zoneExcess * patternSample / patternSpan)
                + (patternSample * Self.zoneFamiliarityFloor / patternSpan)
        )
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
            leanPitch: topPitch.pitchType,
            leanZone: topZone.zone,
            pitchReadStrength: pitchReadStrength,
            zoneReadStrength: zoneReadStrength,
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

    /// 관측 하나의 무게 — 타자는 빈도가 아니라 '잘 보인 공'을 노린다.
    /// 정타(×3)는 다음에도 노리고, 파울·범타(×2)는 타이밍이 왔다는 뜻이고,
    /// 헛스윙을 뽑아낸 결정구(÷2)는 봤어도 여전히 못 친다. 예전에는 outcome을
    /// 저장만 하고 안 읽어서, 3연속 헛스윙을 만든 공과 3연속 안타를 맞은 공이
    /// 같은 무게로 '읽혔다'. 2배 스케일 정수 가중치라 결정론은 그대로다.
    private func observationWeight(_ observation: RivalPitchObservation) -> Int {
        switch observation.outcome {
        case .single, .double, .triple, .homeRun: 6
        case .foul, .inPlayOut: 4
        case .ball, .calledStrike, .hitByPitch: 2
        case .swingingStrike: 1
        }
    }

    private func mostFrequentPitch(
        in observations: [RivalPitchObservation]
    ) -> (pitchType: PitchType, count: Int) {
        var best = (pitchType: PitchType.fourSeam, count: -1)
        let totalWeight = max(1, observations.reduce(0) { $0 + observationWeight($1) })
        for pitchType in PitchType.allCases {
            let weight = observations.lazy.filter { $0.pitchType == pitchType }
                .reduce(0) { $0 + observationWeight($1) }
            // count는 하위 계산(share)이 기존과 같은 스케일을 갖도록 관측 수 기준으로 환산.
            let count = weight * observations.count / totalWeight
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
        let totalWeight = max(1, observations.reduce(0) { $0 + observationWeight($1) })
        for index in 0..<9 {
            let zone = PitchZone(row: index / 3, column: index % 3)
            let weight = observations.lazy.filter { $0.zone == zone }
                .reduce(0) { $0 + observationWeight($1) }
            let count = weight * observations.count / totalWeight
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
