import Foundation

public enum PitchLearningStage: String, Codable, CaseIterable, Sendable {
    case grip
    case bullpen
    case liveTrial = "live_trial"
    case completed
}

public struct StartingRepertoireSelection: Codable, Equatable, Sendable {
    public let readyBreakingPitches: [PitchType]
    public let primaryPitch: PitchType
    public let learningPitch: PitchType

    public init(
        readyBreakingPitches: [PitchType],
        primaryPitch: PitchType,
        learningPitch: PitchType
    ) {
        self.readyBreakingPitches = readyBreakingPitches
        self.primaryPitch = primaryPitch
        self.learningPitch = learningPitch
    }
}

public struct PitchLearningProjectSnapshot: Codable, Equatable, Sendable {
    public let pitchType: PitchType
    public let practiceCredits: Int
    public let qualityUses: Int
    public let stage: PitchLearningStage
    public let startedChapter: Int?
    public let completedChapter: Int?

    public init(
        pitchType: PitchType,
        practiceCredits: Int = 0,
        qualityUses: Int = 0,
        startedChapter: Int? = nil,
        completedChapter: Int? = nil
    ) {
        let credits = min(PitchLearningRules.maximumPracticeCredits, max(0, practiceCredits))
        let uses = min(PitchLearningRules.requiredQualityUses, max(0, qualityUses))
        self.pitchType = pitchType
        self.practiceCredits = credits
        self.qualityUses = uses
        self.stage = Self.stage(practiceCredits: credits, qualityUses: uses)
        self.startedChapter = startedChapter
        self.completedChapter = self.stage == .completed ? completedChapter : nil
    }

    public var isGameReady: Bool { practiceCredits >= PitchLearningRules.gameReadyPracticeCredits }
    public var isCompleted: Bool { stage == .completed }
    public var commitmentToken: String {
        [
            pitchType.rawValue,
            String(practiceCredits),
            String(qualityUses),
            stage.rawValue,
            startedChapter.map(String.init) ?? "none",
            completedChapter.map(String.init) ?? "none",
        ].joined(separator: ":")
    }

    public func addingPractice(_ amount: Int, chapter: Int?) -> PitchLearningProjectSnapshot {
        PitchLearningProjectSnapshot(
            pitchType: pitchType,
            practiceCredits: practiceCredits + max(0, amount),
            qualityUses: qualityUses,
            startedChapter: startedChapter ?? chapter,
            completedChapter: completedChapter ?? chapter
        )
    }

    public func addingQualityUses(_ amount: Int, chapter: Int?) -> PitchLearningProjectSnapshot {
        PitchLearningProjectSnapshot(
            pitchType: pitchType,
            practiceCredits: practiceCredits,
            qualityUses: qualityUses + max(0, amount),
            startedChapter: startedChapter ?? chapter,
            completedChapter: completedChapter ?? chapter
        )
    }

    public static func stage(practiceCredits: Int, qualityUses: Int) -> PitchLearningStage {
        if practiceCredits >= PitchLearningRules.maximumPracticeCredits
            || (practiceCredits >= PitchLearningRules.liveCompletionPracticeCredits
                && qualityUses >= PitchLearningRules.requiredQualityUses) { return .completed }
        if practiceCredits >= PitchLearningRules.gameReadyPracticeCredits { return .liveTrial }
        if practiceCredits >= PitchLearningRules.bullpenPracticeCredits { return .bullpen }
        return .grip
    }
}

public struct PitchLearningReceiptSnapshot: Codable, Equatable, Sendable {
    public let pitchType: PitchType
    public let stageBefore: PitchLearningStage
    public let stageAfter: PitchLearningStage
    public let practiceCreditsBefore: Int
    public let practiceCreditsAfter: Int
    public let justUnlockedForGames: Bool
    public let justCompleted: Bool

    public init(before: PitchLearningProjectSnapshot, after: PitchLearningProjectSnapshot) {
        pitchType = after.pitchType
        stageBefore = before.stage
        stageAfter = after.stage
        practiceCreditsBefore = before.practiceCredits
        practiceCreditsAfter = after.practiceCredits
        justUnlockedForGames = !before.isGameReady && after.isGameReady
        justCompleted = !before.isCompleted && after.isCompleted
    }
}

public struct PitchLearningUseReceipt: Codable, Equatable, Sendable {
    public let pitchType: PitchType
    public let pitchesThrown: Int
    public let qualityUses: Int

    public init(pitchType: PitchType, pitchesThrown: Int, qualityUses: Int) {
        self.pitchType = pitchType
        self.pitchesThrown = max(0, pitchesThrown)
        self.qualityUses = min(PitchLearningRules.requiredQualityUses, max(0, qualityUses))
    }
}

public enum PitchLearningRules {
    public static let rulesVersion = 1
    public static let bullpenPracticeCredits = 2
    public static let gameReadyPracticeCredits = 5
    public static let liveCompletionPracticeCredits = 7
    public static let maximumPracticeCredits = 9
    public static let requiredQualityUses = 2
    public static let breakingPitches: Set<PitchType> = [.slider, .curveball, .changeup]

    public static func recommendedSelection(presetID: String) -> StartingRepertoireSelection {
        switch presetID {
        case "precision_commander":
            return .init(
                readyBreakingPitches: [.slider, .changeup],
                primaryPitch: .changeup,
                learningPitch: .curveball
            )
        case "breaking_ball_artist":
            return .init(
                readyBreakingPitches: [.slider, .curveball],
                primaryPitch: .slider,
                learningPitch: .changeup
            )
        case "innings_eater":
            return .init(
                readyBreakingPitches: [.curveball, .changeup],
                primaryPitch: .fourSeam,
                learningPitch: .slider
            )
        default:
            return .init(
                readyBreakingPitches: [.slider, .changeup],
                primaryPitch: .fourSeam,
                learningPitch: .curveball
            )
        }
    }

    public static func validate(_ selection: StartingRepertoireSelection) throws {
        let ready = Set(selection.readyBreakingPitches)
        guard selection.readyBreakingPitches.count == 2,
              ready.count == 2,
              ready.isSubset(of: breakingPitches),
              breakingPitches.contains(selection.learningPitch),
              !ready.contains(selection.learningPitch),
              ready.union([selection.learningPitch]) == breakingPitches,
              selection.primaryPitch == .fourSeam || ready.contains(selection.primaryPitch) else {
            throw SimulationError.invalidPitcherLab("starting repertoire must contain four-seam, two ready secondary pitches, and one learning pitch")
        }
    }

    public static func profileCommitmentToken(for pitcher: PitcherSnapshot) -> String {
        (pitcher.pitchProfiles ?? [])
            .sorted { $0.pitchType.rawValue < $1.pitchType.rawValue }
            .map { profile in
                [
                    profile.pitchType.rawValue,
                    profile.role.rawValue,
                    profile.availability?.rawValue ?? "legacy",
                    String(profile.velocityTenthsKPH),
                    String(profile.control),
                    String(profile.command),
                    String(profile.movement),
                    String(profile.whiff),
                    String(profile.weakContact),
                    String(profile.fatigueCost),
                ].joined(separator: ":")
            }
            .joined(separator: ",")
    }

    public static func validateState(
        pitcher: PitcherSnapshot,
        rulesVersion: Int?,
        project: PitchLearningProjectSnapshot?
    ) throws {
        guard let rulesVersion else {
            guard project == nil else {
                throw SimulationError.invalidPitcherLab("legacy repertoire cannot carry a learning project")
            }
            return
        }
        guard rulesVersion == Self.rulesVersion,
              let project,
              let profiles = pitcher.pitchProfiles,
              profiles.count == PitchType.allCases.count,
              Set(profiles.map(\.pitchType)) == Set(PitchType.allCases),
              profiles.allSatisfy({ $0.availability != nil }),
              profiles.filter({ $0.role == .primary }).count == 1,
              let learning = profiles.first(where: { $0.pitchType == project.pitchType }) else {
            throw SimulationError.invalidPitcherLab("versioned repertoire state is incomplete")
        }
        let readyCount = profiles.filter(\.isGameReady).count
        guard profiles.first(where: { $0.role == .primary })?.isGameReady == true,
              readyCount == (project.isGameReady ? 4 : 3),
              learning.isGameReady == project.isGameReady,
              learning.role == (project.isCompleted ? .secondary : .development),
              project.stage == PitchLearningProjectSnapshot.stage(
                practiceCredits: project.practiceCredits,
                qualityUses: project.qualityUses
              ) else {
            throw SimulationError.invalidPitcherLab("pitch profile and learning project disagree")
        }
    }

    public static func validateTrainingTarget(
        _ target: PitchType?,
        pitcher: PitcherSnapshot,
        rulesVersion: Int?,
        project: PitchLearningProjectSnapshot?
    ) throws {
        guard rulesVersion != nil else { return }
        guard let target,
              target != .fourSeam,
              let profile = pitcher.profile(for: target) else {
            throw SimulationError.invalidPitcherLab("versioned breaking-ball training requires a valid target pitch")
        }
        if !profile.isGameReady {
            guard let project,
                  !project.isCompleted,
                  project.pitchType == target,
                  profile.role == .development else {
                throw SimulationError.invalidPitcherLab("locked pitch is not the active learning project")
            }
        }
    }

    public static func apply(
        selection: StartingRepertoireSelection,
        to pitcher: PitcherSnapshot,
        chapter: Int? = 1
    ) throws -> (pitcher: PitcherSnapshot, project: PitchLearningProjectSnapshot) {
        try validate(selection)
        guard let profiles = pitcher.pitchProfiles,
              Set(profiles.map(\.pitchType)) == Set(PitchType.allCases) else {
            throw SimulationError.invalidPitcherLab("starting repertoire requires a complete pitch profile catalog")
        }
        let ready = Set(selection.readyBreakingPitches).union([.fourSeam])
        let compensation = preparationCompensation(for: selection.learningPitch)
        let updated = profiles.map { profile in
            let receivesCompensation = profile.pitchType != .fourSeam
                && ready.contains(profile.pitchType)
            return PitchProfileSnapshot(
                pitchType: profile.pitchType,
                role: profile.pitchType == selection.primaryPitch
                    ? .primary
                    : profile.pitchType == selection.learningPitch ? .development : .secondary,
                velocityTenthsKPH: profile.velocityTenthsKPH,
                control: profile.control,
                command: min(80, profile.command + (receivesCompensation ? compensation.command : 0)),
                movement: profile.movement,
                whiff: min(80, profile.whiff + (receivesCompensation ? compensation.whiff : 0)),
                weakContact: min(80, profile.weakContact + (receivesCompensation ? compensation.weakContact : 0)),
                fatigueCost: profile.fatigueCost,
                availability: ready.contains(profile.pitchType) ? .gameReady : .locked
            )
        }
        let result = PitcherSnapshot(
            id: pitcher.id,
            name: pitcher.name,
            stuff: pitcher.stuff,
            command: pitcher.command,
            movement: pitcher.movement,
            stamina: pitcher.stamina,
            pitchProfiles: updated,
            throwingHand: pitcher.throwingHand,
            mastery: pitcher.mastery
        )
        return (
            result,
            PitchLearningProjectSnapshot(pitchType: selection.learningPitch, startedChapter: chapter)
        )
    }

    public static func practiceCredit(for intensity: TrainingIntensity) -> Int {
        switch intensity {
        case .light: 1
        case .standard: 2
        case .intensive: 3
        }
    }

    public static func advancing(
        pitcher: PitcherSnapshot,
        project: PitchLearningProjectSnapshot,
        practiceCredits: Int = 0,
        qualityUses: Int = 0,
        chapter: Int? = nil
    ) throws -> (
        pitcher: PitcherSnapshot,
        project: PitchLearningProjectSnapshot,
        receipt: PitchLearningReceiptSnapshot
    ) {
        guard let profile = pitcher.profile(for: project.pitchType),
              profile.availability != nil else {
            throw SimulationError.invalidPitcherLab("pitch learning project does not match a versioned pitch profile")
        }
        let practiced = project.addingPractice(practiceCredits, chapter: chapter)
        let after = practiced.addingQualityUses(qualityUses, chapter: chapter)
        let justUnlocked = !project.isGameReady && after.isGameReady
        let compensation = preparationCompensation(for: project.pitchType)
        let profiles = pitcher.pitchProfiles?.map { current -> PitchProfileSnapshot in
            if current.pitchType != project.pitchType {
                guard justUnlocked, current.pitchType != .fourSeam else { return current }
                return PitchProfileSnapshot(
                    pitchType: current.pitchType,
                    role: current.role,
                    velocityTenthsKPH: current.velocityTenthsKPH,
                    control: current.control,
                    command: max(20, current.command - compensation.command),
                    movement: current.movement,
                    whiff: max(20, current.whiff - compensation.whiff),
                    weakContact: max(20, current.weakContact - compensation.weakContact),
                    fatigueCost: current.fatigueCost,
                    availability: current.availability
                )
            }
            return PitchProfileSnapshot(
                pitchType: current.pitchType,
                role: after.isCompleted ? .secondary : .development,
                velocityTenthsKPH: current.velocityTenthsKPH,
                control: current.control,
                command: current.command,
                movement: current.movement,
                whiff: current.whiff,
                weakContact: current.weakContact,
                fatigueCost: current.fatigueCost,
                availability: after.isGameReady ? .gameReady : .locked
            )
        }
        let updated = PitcherSnapshot(
            id: pitcher.id,
            name: pitcher.name,
            stuff: pitcher.stuff,
            command: pitcher.command,
            movement: pitcher.movement,
            stamina: pitcher.stamina,
            pitchProfiles: profiles,
            throwingHand: pitcher.throwingHand,
            mastery: pitcher.mastery
        )
        return (updated, after, PitchLearningReceiptSnapshot(before: project, after: after))
    }

    /// Three-pitch starts temporarily redistribute the missing pitch's tactical value so choosing
    /// which pitch to learn is not a hidden difficulty selector. The bonus is removed exactly once
    /// when that pitch becomes game-ready, leaving every four-pitch build on the same long-term
    /// profile budget.
    private static func preparationCompensation(
        for learningPitch: PitchType
    ) -> (command: Int, whiff: Int, weakContact: Int) {
        switch learningPitch {
        case .slider: (10, 10, 4)
        case .curveball: (5, 5, 3)
        case .changeup, .fourSeam: (0, 0, 0)
        }
    }
}
