import Foundation

public struct SimulationEngine: Sendable {
    public init() {}

    public func simulatePitch(_ params: SimulatePitchParams) throws -> SimulatePitchResult {
        try validate(params)

        guard let seed = UInt64(params.seed) else {
            throw SimulationError.invalidSeed(params.seed)
        }

        var generator = SplitMix64(seed: seed)
        let pitchProfile = profile(for: params.selection.pitchType)
        let intensity = intensityProfile(for: params.selection.intensity)
        let cornerPenalty = zonePenalty(params.selection.zone)

        let effectiveCommand = clamp(
            params.pitcher.command * 10
                + pitchProfile.commandModifier
                - intensity.commandPenalty
                - params.fatigue * 2,
            80,
            900
        )
        let effectiveStuff = clamp(
            params.pitcher.stuff * 10
                + pitchProfile.stuffModifier
                + intensity.stuffBonus
                - params.fatigue,
            100,
            1_000
        )
        let effectiveMovement = clamp(
            params.pitcher.movement * 10
                + pitchProfile.movementModifier
                - params.fatigue,
            100,
            1_000
        )

        let executionScore = effectiveCommand
            + generator.nextInt(upperBound: 1_000)
            - 500
            - cornerPenalty
        let wasInZone = executionScore >= 220

        let swingChance: Int
        if wasInZone {
            swingChance = clamp(
                690 + params.count.strikes * 65 - (params.batter.discipline - 50) * 2,
                430,
                940
            )
        } else {
            swingChance = clamp(
                280
                    + effectiveMovement / 12
                    + params.count.strikes * 55
                    - params.batter.discipline * 5,
                35,
                480
            )
        }

        let batterSwung = generator.nextInt(upperBound: 1_000) < swingChance
        var contactQuality: Int?
        let outcome: PitchOutcome

        if !batterSwung {
            outcome = wasInZone ? .calledStrike : .ball
        } else {
            let contactChance = clamp(
                590
                    + (params.batter.contact - 50) * 7
                    - (effectiveStuff - 500) / 2
                    - params.count.strikes * 35,
                90,
                900
            )

            if generator.nextInt(upperBound: 1_000) >= contactChance {
                outcome = .swingingStrike
            } else {
                let foulChance = clamp(
                    190 + effectiveMovement / 10 - params.batter.contact,
                    130,
                    360
                )
                if generator.nextInt(upperBound: 1_000) < foulChance {
                    outcome = .foul
                } else {
                    let quality = params.batter.power * 6
                        + params.batter.contact * 2
                        + generator.nextInt(upperBound: 1_000)
                        - effectiveMovement / 2
                        - max(0, executionScore - 350) / 3
                    contactQuality = quality
                    outcome = fairBallOutcome(quality)
                }
            }
        }

        let feedback = feedback(
            outcome: outcome,
            selection: params.selection,
            wasInZone: wasInZone,
            executionScore: executionScore,
            contactQuality: contactQuality
        )
        let nextSeed = String(generator.state)
        let canonicalEvent = [
            params.seed,
            nextSeed,
            params.selection.pitchType.rawValue,
            String(params.selection.zone.row),
            String(params.selection.zone.column),
            params.selection.intensity.rawValue,
            outcome.rawValue,
            wasInZone ? "1" : "0",
            batterSwung ? "1" : "0",
            String(executionScore),
            contactQuality.map(String.init) ?? "none"
        ].joined(separator: "|")

        let event = PitchResolvedEvent(
            seed: params.seed,
            nextSeed: nextSeed,
            outcome: outcome,
            wasInZone: wasInZone,
            batterSwung: batterSwung,
            executionScore: executionScore,
            contactQuality: contactQuality,
            reasonCodes: reasonCodes(
                outcome: outcome,
                executionScore: executionScore,
                wasInZone: wasInZone
            ),
            eventHash: StableHash.fnv1a64(canonicalEvent)
        )
        let snapshot = PitchDecisionSnapshot(
            outcome: outcome,
            wasInZone: wasInZone,
            batterSwung: batterSwung,
            executionScore: executionScore,
            contactQuality: contactQuality,
            shortFeedback: feedback.summary,
            detailFeedback: feedback.detail,
            accessibilitySummary: "\(feedback.summary) \(feedback.detail)"
        )
        return SimulatePitchResult(revision: 1, events: [event], snapshot: snapshot)
    }

    private func validate(_ params: SimulatePitchParams) throws {
        guard UInt64(params.seed) != nil else {
            throw SimulationError.invalidSeed(params.seed)
        }

        let ratings = [
            ("pitcher.stuff", params.pitcher.stuff),
            ("pitcher.command", params.pitcher.command),
            ("pitcher.movement", params.pitcher.movement),
            ("pitcher.stamina", params.pitcher.stamina),
            ("batter.contact", params.batter.contact),
            ("batter.discipline", params.batter.discipline),
            ("batter.power", params.batter.power)
        ]
        for (field, value) in ratings where !(20...80).contains(value) {
            throw SimulationError.invalidRating(field: field, value: value)
        }

        guard (0...2).contains(params.selection.zone.row),
              (0...2).contains(params.selection.zone.column) else {
            throw SimulationError.invalidZone(
                row: params.selection.zone.row,
                column: params.selection.zone.column
            )
        }
        guard (0...3).contains(params.count.balls),
              (0...2).contains(params.count.strikes) else {
            throw SimulationError.invalidCount(
                balls: params.count.balls,
                strikes: params.count.strikes
            )
        }
        guard (0...100).contains(params.fatigue) else {
            throw SimulationError.invalidFatigue(params.fatigue)
        }
    }

    private func profile(for pitchType: PitchType) -> (
        stuffModifier: Int,
        movementModifier: Int,
        commandModifier: Int
    ) {
        switch pitchType {
        case .fourSeam:
            return (stuffModifier: 70, movementModifier: -25, commandModifier: 20)
        case .slider:
            return (stuffModifier: 35, movementModifier: 80, commandModifier: -30)
        case .curveball:
            return (stuffModifier: 10, movementModifier: 115, commandModifier: -55)
        case .changeup:
            return (stuffModifier: 20, movementModifier: 55, commandModifier: 5)
        }
    }

    private func intensityProfile(for intensity: PitchIntensity) -> (
        stuffBonus: Int,
        commandPenalty: Int
    ) {
        switch intensity {
        case .controlled:
            return (stuffBonus: -40, commandPenalty: -55)
        case .normal:
            return (stuffBonus: 0, commandPenalty: 0)
        case .maxEffort:
            return (stuffBonus: 95, commandPenalty: 120)
        }
    }

    private func zonePenalty(_ zone: PitchZone) -> Int {
        let onHorizontalEdge = zone.column == 0 || zone.column == 2
        let onVerticalEdge = zone.row == 0 || zone.row == 2
        switch (onHorizontalEdge, onVerticalEdge) {
        case (true, true):
            return 100
        case (true, false), (false, true):
            return 55
        case (false, false):
            return 0
        }
    }

    private func fairBallOutcome(_ quality: Int) -> PitchOutcome {
        switch quality {
        case ..<515:
            return .inPlayOut
        case 515..<690:
            return .single
        case 690..<820:
            return .double
        default:
            return .homeRun
        }
    }

    private func feedback(
        outcome: PitchOutcome,
        selection: PitchSelection,
        wasInZone: Bool,
        executionScore: Int,
        contactQuality: Int?
    ) -> (summary: String, detail: String) {
        let pitchName: String
        switch selection.pitchType {
        case .fourSeam: pitchName = "포심"
        case .slider: pitchName = "슬라이더"
        case .curveball: pitchName = "커브"
        case .changeup: pitchName = "체인지업"
        }

        let summary: String
        switch outcome {
        case .ball: summary = "\(pitchName)이 존을 벗어나 볼이 됐습니다."
        case .calledStrike: summary = "\(pitchName)이 존에 들어가 루킹 스트라이크를 잡았습니다."
        case .swingingStrike: summary = "타자의 타이밍을 빼앗아 헛스윙을 끌어냈습니다."
        case .foul: summary = "타자가 가까스로 걷어내 파울이 됐습니다."
        case .inPlayOut: summary = "약한 타구를 유도해 인플레이 아웃을 만들었습니다."
        case .single: summary = "타자가 빈틈을 찾아 단타를 만들었습니다."
        case .double: summary = "강한 타구가 외야를 갈라 2루타가 됐습니다."
        case .homeRun: summary = "실투를 놓치지 않은 타자가 홈런을 만들었습니다."
        }

        let executionDescription: String
        switch executionScore {
        case ..<220: executionDescription = "목표보다 크게 벗어났습니다"
        case 220..<430: executionDescription = "존에는 들어갔지만 다소 몰렸습니다"
        case 430..<650: executionDescription = "의도한 코스에 가깝게 제구됐습니다"
        default: executionDescription = "의도한 코스를 정교하게 찔렀습니다"
        }
        let contactDescription = contactQuality.map { " 타구 강도는 \($0)/1000이었습니다." } ?? ""
        let zoneDescription = wasInZone ? "스트라이크 존" : "존 바깥"
        return (
            summary: summary,
            detail: "공은 \(zoneDescription)에 형성됐고 \(executionDescription).\(contactDescription)"
        )
    }

    private func reasonCodes(
        outcome: PitchOutcome,
        executionScore: Int,
        wasInZone: Bool
    ) -> [String] {
        let executionReason: String
        switch executionScore {
        case ..<220: executionReason = "execution.missed_target"
        case 220..<430: executionReason = "execution.location_vulnerable"
        case 430..<650: executionReason = "execution.near_target"
        default: executionReason = "execution.precise"
        }
        return [
            "outcome.\(outcome.rawValue)",
            wasInZone ? "location.in_zone" : "location.out_of_zone",
            executionReason
        ]
    }

    private func clamp(_ value: Int, _ lowerBound: Int, _ upperBound: Int) -> Int {
        min(max(value, lowerBound), upperBound)
    }
}
