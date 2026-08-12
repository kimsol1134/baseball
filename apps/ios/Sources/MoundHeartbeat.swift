import Foundation
import QuartzCore
import SimulationCore

/// The iOS-only inputs used to derive mound composure. This deliberately does not extend
/// `PitcherSnapshot`; saved game data stays owned by the shared simulation model.
struct MoundComposureInput: Equatable, Sendable {
    let command: Int
    let stamina: Int
    let awakenings: [AwakeningID]
    let memories: [MemoryCardID]

    init(
        command: Int,
        stamina: Int,
        awakenings: [AwakeningID] = [],
        memories: [MemoryCardID] = []
    ) {
        self.command = command
        self.stamina = stamina
        self.awakenings = awakenings
        self.memories = memories
    }
}

/// A clean boundary between the game situation and the iOS presentation effect.
struct MoundTensionInput: Equatable, Sendable {
    let officialGame: Bool
    let leverage: Int
    let runners: BaserunnerStateSnapshot
    let balls: Int
    let strikes: Int
    let outs: Int
    let fatigue: Int
    /// Batter threat is a normalized 0...100 presentation input, not a new saved stat.
    let batterThreat: Int
    let recentAdverseEvent: Bool
    let composure: MoundComposureInput

    init(
        officialGame: Bool,
        leverage: Int,
        runners: BaserunnerStateSnapshot,
        balls: Int,
        strikes: Int,
        outs: Int,
        fatigue: Int,
        batterThreat: Int,
        recentAdverseEvent: Bool,
        composure: MoundComposureInput
    ) {
        self.officialGame = officialGame
        self.leverage = leverage
        self.runners = runners
        self.balls = balls
        self.strikes = strikes
        self.outs = outs
        self.fatigue = fatigue
        self.batterThreat = batterThreat
        self.recentAdverseEvent = recentAdverseEvent
        self.composure = composure
    }
}

enum MoundTensionBand: Equatable, Sendable {
    case low
    case medium
    case high
    case climax
}

/// Pure situation, composure, and tuning rules for the mound effect.
enum MoundTensionModel {
    static let mediumThreshold = 0.32
    static let highThreshold = 0.58
    static let climaxThreshold = 0.80

    /// Derives a private presentation-only composure signal from existing skills and
    /// pressure-related high-school evidence. A fully composed pitcher gets a 92% effect
    /// reduction through `damping(for:)` below.
    static func composure(from input: MoundComposureInput) -> Double {
        let command = normalized(Double(input.command))
        let stamina = normalized(Double(input.stamina))

        var value = command * 0.38 + stamina * 0.27
        for awakening in input.awakenings {
            value += awakeningBonus(awakening)
        }
        for memory in input.memories {
            value += memoryBonus(memory)
        }
        return clamp(value)
    }

    /// Maximum composure leaves 8% of the raw signal, which is approximately a 92% reduction.
    static func damping(for composure: Double) -> Double {
        1 - 0.92 * clamp(composure)
    }

    /// The undamped situation signal. Keeping this separate makes the composure effect explicit
    /// and lets tests distinguish situation monotonicity from skill damping.
    static func baseTension(for input: MoundTensionInput) -> Double {
        guard input.officialGame else { return 0 }

        let leverage = normalized(Double(input.leverage), maximum: 1_000)
        // Low-leverage innings remain quiet. Official-game entry still gets the subtle entry
        // pulse, but there is no ongoing pressure signal to feed the meter.
        let stakes = max(0, (leverage - 0.62) / 0.38)
        guard stakes > 0 else { return 0 }

        let runnerPressure = (input.runners.firstOccupied ? 0.07 : 0)
            + (input.runners.secondOccupied ? 0.16 : 0)
            + (input.runners.thirdOccupied ? 0.25 : 0)
        let balls = min(3, max(0, input.balls))
        let strikes = min(2, max(0, input.strikes))
        let countPressure: Double
        if balls == 3 && strikes == 2 {
            countPressure = 0.25
        } else if strikes == 2 {
            countPressure = 0.13
        } else if balls == 3 {
            countPressure = 0.10
        } else {
            countPressure = 0
        }

        let outsPressure = min(2, max(0, input.outs)) == 2 ? 0.08 : 0
        let fatiguePressure = max(0, (normalized(Double(input.fatigue), maximum: 100) - 0.45) / 0.55) * 0.08
        let threatPressure = max(0, (normalized(Double(input.batterThreat), maximum: 100) - 0.55) / 0.45) * 0.10
        let adversePressure = input.recentAdverseEvent ? 0.10 : 0

        return clamp(
            stakes * 0.55
                + runnerPressure
                + countPressure
                + outsPressure
                + fatiguePressure
                + threatPressure
                + adversePressure
        )
    }

    /// Effective tension used by heartbeat cadence and release-meter disturbance.
    static func tension(for input: MoundTensionInput) -> Double {
        baseTension(for: input) * damping(for: composure(from: input.composure))
    }

    static func band(for tension: Double) -> MoundTensionBand {
        let clamped = clamp(tension)
        switch clamped {
        case ..<mediumThreshold: return .low
        case ..<highThreshold: return .medium
        case ..<climaxThreshold: return .high
        default: return .climax
        }
    }

    /// Maximum meter disturbance as a fraction of the full release meter width.
    static func jitterCap(for tension: Double) -> Double {
        let value = clamp(tension)
        switch value {
        case 0..<mediumThreshold:
            return interpolate(value, from: 0, to: mediumThreshold, low: 0, high: 0.01)
        case mediumThreshold..<highThreshold:
            return interpolate(value, from: mediumThreshold, to: highThreshold, low: 0.01, high: 0.03)
        case highThreshold..<climaxThreshold:
            return interpolate(value, from: highThreshold, to: climaxThreshold, low: 0.03, high: 0.05)
        default:
            return 0.06
        }
    }

    /// Entry beats are deliberately still audible/tactile in a quiet official game, while a
    /// practice/bullpen scene remains entirely free of tension feedback.
    static func entryTension(rawTension: Double, officialGame: Bool) -> Double {
        guard officialGame else { return 0 }
        return max(0.06, clamp(rawTension))
    }

    /// The useful sweet-spot pulse remains present, but pressure masks it. Composure lowers the
    /// effective tension before the mask is applied, so a calm pitcher hears/feels it more clearly.
    static func sweetSpotHapticClarity(effectiveTension: Double) -> Double {
        clamp(1 - 0.72 * clamp(effectiveTension))
    }

    /// 심박 촉감도 유효 긴장도에 비례시킨다. 담력 최대의 0.08 신호는 원래 진폭의 8%만
    /// 남으므로 미터뿐 아니라 손에서도 약 92% 감쇠가 실제로 지켜진다.
    static func heartbeatHapticIntensity(effectiveTension: Double) -> Double {
        0.52 * clamp(effectiveTension)
    }

    static func batterThreat(contact: Int, discipline: Int, power: Int) -> Int {
        let value = normalized(Double(contact), maximum: 100) * 0.45
            + normalized(Double(discipline), maximum: 100) * 0.30
            + normalized(Double(power), maximum: 100) * 0.25
        return Int((value * 100).rounded())
    }

    /// Stable seed for a scenario. Swift's `hashValue` is intentionally process-randomized, so it
    /// cannot drive a replayable meter disturbance.
    static func seed(from text: String) -> UInt64 {
        text.utf8.reduce(14_695_981_039_346_656_037) { partial, byte in
            (partial ^ UInt64(byte)) &* 1_099_511_628_211
        }
    }

    /// A deterministic 0...1 value for schedules and low-frequency meter phases.
    static func deterministicUnit(_ seed: UInt64) -> Double {
        var value = seed &+ 0x9E37_79B9_7F4A_7C15
        value ^= value >> 30
        value &*= 0xBF58_476D_1CE4_E5B9
        value ^= value >> 27
        value &*= 0x94D0_49BB_1331_11EB
        value ^= value >> 31
        return Double(value >> 11) / 9_007_199_254_740_992.0
    }

    private static func awakeningBonus(_ awakening: AwakeningID) -> Double {
        switch awakening {
        case .calmUnderPressure: 0.14
        case .scoutComposure: 0.12
        case .repeatableRelease: 0.08
        case .twoStrikePlan: 0.06
        case .trafficController: 0.06
        case .lateInningReserve: 0.04
        default: 0
        }
    }

    private static func memoryBonus(_ memory: MemoryCardID) -> Double {
        switch memory {
        case .pressureRehearsal: 0.10
        case .twoStrikeSequence: 0.06
        case .bullpenCompass: 0.04
        case .fatigueDiary: 0.03
        case .coachLetter: 0.02
        default: 0
        }
    }

    private static func normalized(_ value: Double, maximum: Double = 100) -> Double {
        clamp(value / maximum)
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }

    private static func interpolate(_ value: Double, from lower: Double, to upper: Double, low: Double, high: Double) -> Double {
        let span = max(0.000_001, upper - lower)
        let progress = min(1, max(0, (value - lower) / span))
        return low + (high - low) * progress
    }
}

enum MoundHeartbeatSettings {
    static func meterJitterEnabled(hapticsEnabled: Bool) -> Bool { hapticsEnabled }
    static func heartbeatAudioEnabled(soundEnabled: Bool) -> Bool { soundEnabled }
}

struct MoundHeartbeatCadence: Equatable, Sendable {
    let band: MoundTensionBand
    let cycles: Int
    let restRange: ClosedRange<Double>
    let cycleInterval: Double

    static func forTension(_ tension: Double) -> MoundHeartbeatCadence {
        switch MoundTensionModel.band(for: tension) {
        case .low:
            MoundHeartbeatCadence(band: .low, cycles: 0, restRange: 0...0, cycleInterval: 0.82)
        case .medium:
            MoundHeartbeatCadence(band: .medium, cycles: 2, restRange: 4...6, cycleInterval: 0.72)
        case .high:
            MoundHeartbeatCadence(band: .high, cycles: 3, restRange: 2...4, cycleInterval: 0.63)
        case .climax:
            MoundHeartbeatCadence(band: .climax, cycles: 4, restRange: 0.8...1.5, cycleInterval: 0.54)
        }
    }

    func rest(seed: UInt64, burstIndex: Int) -> Double {
        guard restRange.lowerBound < restRange.upperBound else { return restRange.lowerBound }
        let mixed = seed &+ UInt64(max(0, burstIndex)) &* 0x9E37_79B9_7F4A_7C15
        return restRange.lowerBound
            + (restRange.upperBound - restRange.lowerBound) * MoundTensionModel.deterministicUnit(mixed)
    }
}

struct MoundHeartbeatBeat: Equatable, Sendable {
    let offset: Double
    let cycle: Int
    let isIrregular: Bool
}

struct MoundHeartbeatPattern: Equatable, Sendable {
    let beats: [MoundHeartbeatBeat]
    let rest: Double

    static func entry(tension: Double) -> MoundHeartbeatPattern {
        let cadence = MoundHeartbeatCadence.forTension(tension)
        return MoundHeartbeatPattern(
            beats: (0..<3).map {
                MoundHeartbeatBeat(offset: Double($0) * cadence.cycleInterval, cycle: $0, isIrregular: false)
            },
            rest: cadence.cycleInterval * 1.15
        )
    }

    static func burst(
        tension: Double,
        seed: UInt64,
        burstIndex: Int = 0,
        adverseEpisode: Bool = false
    ) -> MoundHeartbeatPattern {
        let cadence = MoundHeartbeatCadence.forTension(tension)
        guard cadence.cycles > 0 else { return MoundHeartbeatPattern(beats: [], rest: 0) }

        let irregularCycle = adverseEpisode
            ? Int(seed % UInt64(max(1, cadence.cycles - 1))) + 1
            : -1
        let direction = MoundTensionModel.deterministicUnit(seed ^ 0xD1B5_4A32_D192_ED03) < 0.5 ? -1.0 : 1.0
        let intervalJitter = direction < 0
            ? -cadence.cycleInterval * 0.18
            : cadence.cycleInterval * 0.32

        let beats = (0..<cadence.cycles).map { cycle in
            let isIrregular = cycle == irregularCycle
            let offset = Double(cycle) * cadence.cycleInterval + (isIrregular ? intervalJitter : 0)
            return MoundHeartbeatBeat(offset: max(0, offset), cycle: cycle, isIrregular: isIrregular)
        }
        return MoundHeartbeatPattern(
            beats: beats,
            rest: cadence.rest(seed: seed, burstIndex: burstIndex)
        )
    }
}

struct MoundHeartbeatEvent: Equatable, Sendable {
    let tension: Double
    let cycle: Int
    let isIrregular: Bool
}

/// Main-actor bridge between scheduled heartbeat events and the display-link meter.
@MainActor
final class MoundHeartbeatSignal {
    private(set) var beatTimes: [CFTimeInterval] = []

    func recordBeat(at time: CFTimeInterval = CACurrentMediaTime()) {
        beatTimes.append(time)
        // A meter only needs the short-lived impulse. Keeping a small bounded history prevents a
        // long mound session from growing state while preserving enough overlap for slow frames.
        if beatTimes.count > 24 {
            beatTimes.removeFirst(beatTimes.count - 24)
        }
    }

    func reset() {
        beatTimes.removeAll(keepingCapacity: true)
    }
}

/// Deterministic, bounded release-meter disturbance. It is sampled from absolute time rather
/// than accumulated per frame, so 30/60/120 Hz produce the same position at the same timestamp.
enum MoundMeterDisturbance {
    static func offset(
        at time: Double,
        effectiveTension: Double,
        beatTimes: [Double],
        hapticsEnabled: Bool,
        reduceMotion: Bool,
        seed: UInt64
    ) -> Double {
        guard MoundHeartbeatSettings.meterJitterEnabled(hapticsEnabled: hapticsEnabled) else { return 0 }

        let cap = MoundTensionModel.jitterCap(for: effectiveTension)
        guard cap > 0 else { return 0 }

        let phase = MoundTensionModel.deterministicUnit(seed ^ 0xA24B_AED4_963E_E407) * 2 * .pi
        let frequency = 0.55 + 0.25 * MoundTensionModel.deterministicUnit(seed ^ 0x9FB2_1C65_1E98_DF25)
        let lowFrequency = 0.22 * sin(2 * .pi * frequency * max(0, time) + phase)
        let heartbeatImpulse = beatTimes.reduce(0.0) { partial, beatTime in
            let age = time - beatTime
            guard age >= 0, age < 0.50 else { return partial }
            let primary = exp(-age / 0.13)
            let rebound = age > 0.14 ? -0.20 * exp(-(age - 0.14) / 0.12) : 0
            return partial + primary + rebound
        }

        let normalized = min(1, max(-1, lowFrequency * 0.35 + heartbeatImpulse * 0.72))
        let motionScale = reduceMotion ? 0.5 : 1
        return min(cap, max(-cap, cap * normalized * motionScale))
    }

    static func position(
        base: Double,
        at time: Double,
        effectiveTension: Double,
        beatTimes: [Double],
        hapticsEnabled: Bool,
        reduceMotion: Bool,
        seed: UInt64
    ) -> Double {
        min(1, max(0, base + offset(
            at: time,
            effectiveTension: effectiveTension,
            beatTimes: beatTimes,
            hapticsEnabled: hapticsEnabled,
            reduceMotion: reduceMotion,
            seed: seed
        )))
    }
}

/// Lifecycle-owned scheduler. Its only asynchronous work is a stored, cancellable Task; no
/// detached tasks or timers survive a release, state transition, disappearance, or backgrounding.
@MainActor
final class MoundHeartbeatController {
    let signal = MoundHeartbeatSignal()

    private var task: Task<Void, Never>?
    private var generation: UInt64 = 0

    func start(
        tension: Double,
        seed: UInt64,
        includeEntry: Bool,
        adverseEpisode: Bool,
        onBeat: @escaping (MoundHeartbeatEvent) -> Void
    ) {
        stop()
        guard tension > 0 else { return }

        generation &+= 1
        let token = generation
        let signal = self.signal
        task = Task { @MainActor [weak self] in
            await Self.run(
                tension: tension,
                seed: seed,
                includeEntry: includeEntry,
                adverseEpisode: adverseEpisode,
                emit: { [weak self] event in
                    guard let self, self.generation == token else { return }
                    signal.recordBeat()
                    onBeat(event)
                }
            )
            guard let self, self.generation == token else { return }
            self.task = nil
        }
    }

    func stop() {
        generation &+= 1
        task?.cancel()
        task = nil
        signal.reset()
    }

    deinit {
        task?.cancel()
    }

    private static func run(
        tension: Double,
        seed: UInt64,
        includeEntry: Bool,
        adverseEpisode: Bool,
        emit: @escaping (MoundHeartbeatEvent) -> Void
    ) async {
        let cadence = MoundHeartbeatCadence.forTension(tension)

        if includeEntry {
            let entry = MoundHeartbeatPattern.entry(tension: tension)
            guard await Self.emit(pattern: entry, tension: tension, emit: emit) else { return }
            guard await sleep(seconds: entry.rest) else { return }
        }

        guard cadence.cycles > 0 else { return }
        var burstIndex = 0
        var shouldUseIrregularEpisode = adverseEpisode
        while !Task.isCancelled {
            let pattern = MoundHeartbeatPattern.burst(
                tension: tension,
                seed: seed &+ UInt64(burstIndex),
                burstIndex: burstIndex,
                adverseEpisode: shouldUseIrregularEpisode
            )
            guard await Self.emit(pattern: pattern, tension: tension, emit: emit) else { return }
            guard await sleep(seconds: pattern.rest) else { return }
            shouldUseIrregularEpisode = false
            burstIndex += 1
        }
    }

    private static func emit(
        pattern: MoundHeartbeatPattern,
        tension: Double,
        emit: @escaping (MoundHeartbeatEvent) -> Void
    ) async -> Bool {
        var elapsed = 0.0
        for beat in pattern.beats {
            guard await sleep(seconds: beat.offset - elapsed) else { return false }
            guard !Task.isCancelled else { return false }
            emit(MoundHeartbeatEvent(tension: tension, cycle: beat.cycle, isIrregular: beat.isIrregular))
            elapsed = beat.offset
        }
        return true
    }

    private static func sleep(seconds: Double) async -> Bool {
        guard seconds > 0 else { return !Task.isCancelled }
        do {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return !Task.isCancelled
        } catch {
            return false
        }
    }
}
