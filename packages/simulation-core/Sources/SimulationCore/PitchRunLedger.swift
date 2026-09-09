import Foundation

/// Who is on base, and who is answerable for them.
///
/// A pitcher's earned-run average is not the scoreboard. It asks a counterfactual question — how
/// many of these runs would have scored if the defense had played the inning cleanly? — and the
/// only way to answer it is to carry, for every runner, the reason they are standing there.
/// The scoreboard cannot tell you that after the fact, so the ledger walks alongside the game.
///
/// Each base holds one token:
///
/// - `0` empty
/// - `-1` inherited: someone else put them on, so their run is charged to that pitcher
/// - `1` this pitcher's own runner, earned
/// - `2` this pitcher's own runner who reached on an error, so their run is unearned
/// - `-2` an inherited runner who had reached on an error
///
/// `virtualOuts` is the reconstruction: the out count the inning *would* have had without the
/// errors. Once it reaches three, the half-inning is over in the clean replay and nothing after
/// that is earned, however many real outs are left.
///
/// A save written before this ledger existed has no entry for it, and no honest way to invent one.
/// Those seasons report earned runs as unknown rather than guessing — see `ProSeasonStats`.
public struct PitchRunLedger: Equatable, Sendable {
    /// First, second, third — the responsibility token on each base.
    public let bases: [Int]
    /// Runs charged to this pitcher (inherited runners excluded).
    public let runs: Int
    /// The subset of `runs` that survives the clean replay.
    public let earnedRuns: Int
    /// Runs by runners this pitcher inherited. They belong to whoever put them on.
    public let inheritedScored: Int
    /// Outs the inning would have had if the defense had been clean. Capped at three.
    public let virtualOuts: Int

    public init(
        bases: [Int] = [0, 0, 0],
        runs: Int = 0,
        earnedRuns: Int = 0,
        inheritedScored: Int = 0,
        virtualOuts: Int = 0
    ) {
        precondition(bases.count == 3 && bases.allSatisfy { (-2...2).contains($0) })
        precondition((0...3).contains(virtualOuts))
        precondition(runs >= 0 && (0...runs).contains(earnedRuns) && inheritedScored >= 0)
        self.bases = bases
        self.runs = runs
        self.earnedRuns = earnedRuns
        self.inheritedScored = inheritedScored
        self.virtualOuts = virtualOuts
    }

    /// Walk the ledger through one resolved pitch.
    ///
    /// The kernel reports how many runners scored and which bases are occupied afterwards, but not
    /// *which* runner ended up where. Baseball's own convention settles it: runners advance in
    /// order, the lead runner scores first. So the tokens are queued from third base down, the
    /// batter joins the back of the queue when they reach, the front of the queue scores, and what
    /// is left is laid back onto the occupied bases from third downward. Any mismatch between the
    /// queue and the reported occupancy is a bug in the caller, not something to paper over — the
    /// ledger refuses rather than charging the wrong pitcher.
    public func advance(_ pitch: PlateAppearanceSnapshot) throws -> PitchRunLedger {
        var next = bases
        let transition = pitch.inningTransition
        // A runner thrown out stealing is a real out that the clean replay also gets. But if that
        // runner only reached on an error, they would not have been on base at all — counting
        // their caught stealing as a virtual out would invent an out the clean inning never had.
        let caughtErrorRunner = pitch.stealAttempt.map {
            !$0.succeeded && abs(next[$0.fromBase - 1]) == 2
        } ?? false
        if let steal = pitch.stealAttempt {
            let runner = next[steal.fromBase - 1]
            next[steal.fromBase - 1] = 0
            if steal.succeeded { next[steal.toBase - 1] = runner }
        }
        let doublePlayCompleted = transition?.doublePlayCompleted ?? false
        let errorRunnerDoublePlay = doublePlayCompleted && (next[0] == 2 || next[0] == -2)
        if doublePlayCompleted { next[0] = 0 }
        let error = pitch.result == .reachedOnError
        // The error itself is the out that was not made, so the clean replay records it.
        let reconstructedOuts = min(
            3,
            virtualOuts
                + (transition?.outsRecorded ?? 0)
                + (error ? 1 : 0)
                - (errorRunnerDoublePlay ? 1 : 0)
                - (caughtErrorRunner ? 1 : 0)
        )
        var queue = next.reversed().filter { $0 != 0 }
        if pitch.result == .hit || pitch.result == .walk { queue.append(1) }
        if error { queue.append(2) }
        guard pitch.runsScored <= queue.count else { throw SimulationError.invalidGameState("scoring.runner_missing") }
        let scored = queue.prefix(pitch.runsScored)
        var remaining = queue.dropFirst(pitch.runsScored).makeIterator()
        let occupancy = [
            pitch.runnersAfter.firstOccupied,
            pitch.runnersAfter.secondOccupied,
            pitch.runnersAfter.thirdOccupied
        ]
        var after = [0, 0, 0]
        let inningEnded = transition?.inningEnded ?? false
        if !inningEnded {
            for base in stride(from: 2, through: 0, by: -1) where occupancy[base] {
                guard let owner = remaining.next() else { throw SimulationError.invalidGameState("scoring.runner_missing") }
                after[base] = owner
            }
            guard remaining.next() == nil else { throw SimulationError.invalidGameState("scoring.runner_lost") }
        }
        return PitchRunLedger(
            bases: after,
            runs: runs + scored.filter { $0 > 0 }.count,
            earnedRuns: earnedRuns + (reconstructedOuts >= 3 ? 0 : scored.filter { $0 == 1 }.count),
            inheritedScored: inheritedScored + scored.filter { $0 == -1 }.count,
            virtualOuts: inningEnded ? 0 : reconstructedOuts
        )
    }

    /// A compact form for the save file. Six or seven comma-separated integers.
    public func token() -> String {
        (bases + [runs, earnedRuns, inheritedScored, virtualOuts])
            .map(String.init)
            .joined(separator: ",")
    }

    /// Take over a half-inning in progress. Everyone already on base is somebody else's.
    public static func entry(runners: BaserunnerStateSnapshot, outs: Int = 0) -> PitchRunLedger {
        PitchRunLedger(
            bases: [runners.firstOccupied, runners.secondOccupied, runners.thirdOccupied]
                .map { $0 ? -1 : 0 },
            virtualOuts: outs
        )
    }

    /// Read a token back. Saves written before `virtualOuts` existed carry six values.
    public static func decode(_ token: String) -> PitchRunLedger? {
        let values = token.split(separator: ",").map { Int($0) }
        guard values.count >= 6, values.count <= 7, !values.contains(where: { $0 == nil }) else {
            return nil
        }
        let numbers = values.compactMap { $0 }
        guard Array(numbers[0..<3]).allSatisfy({ (-2...2).contains($0) }) else { return nil }
        let virtualOuts = numbers.count > 6 ? numbers[6] : 0
        guard (0...3).contains(virtualOuts),
              numbers[3] >= 0,
              (0...numbers[3]).contains(numbers[4]),
              numbers[5] >= 0
        else { return nil }
        return PitchRunLedger(
            bases: Array(numbers[0..<3]),
            runs: numbers[3],
            earnedRuns: numbers[4],
            inheritedScored: numbers[5],
            virtualOuts: virtualOuts
        )
    }
}
