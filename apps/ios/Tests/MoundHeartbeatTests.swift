import XCTest
import SimulationCore
@testable import BaseballIOS

@MainActor
final class MoundHeartbeatTests: XCTestCase {
    private func runners(_ first: Bool = false, _ second: Bool = false, _ third: Bool = false) -> BaserunnerStateSnapshot {
        BaserunnerStateSnapshot(
            firstOccupied: first,
            secondOccupied: second,
            thirdOccupied: third,
            leadRunnerSpeed: 52
        )
    }

    private func input(
        officialGame: Bool = true,
        leverage: Int = 900,
        runners: BaserunnerStateSnapshot = BaserunnerStateSnapshot.empty,
        balls: Int = 0,
        strikes: Int = 0,
        outs: Int = 0,
        fatigue: Int = 0,
        batterThreat: Int = 50,
        recentAdverseEvent: Bool = false,
        command: Int = 0,
        stamina: Int = 0,
        awakenings: [AwakeningID] = [],
        memories: [MemoryCardID] = []
    ) -> MoundTensionInput {
        MoundTensionInput(
            officialGame: officialGame,
            leverage: leverage,
            runners: runners,
            balls: balls,
            strikes: strikes,
            outs: outs,
            fatigue: fatigue,
            batterThreat: batterThreat,
            recentAdverseEvent: recentAdverseEvent,
            composure: MoundComposureInput(
                command: command,
                stamina: stamina,
                awakenings: awakenings,
                memories: memories
            )
        )
    }

    func testTensionRisesMonotonicallyWithSituationPressure() {
        let leverageValues = [620, 700, 780, 900, 1_000]
        let tensions = leverageValues.map {
            MoundTensionModel.tension(for: input(leverage: $0))
        }

        for pair in zip(tensions, tensions.dropFirst()) {
            XCTAssertLessThanOrEqual(pair.0, pair.1)
        }

        let calm = MoundTensionModel.tension(for: input(leverage: 800))
        let runnersAndCount = MoundTensionModel.tension(for: input(
            leverage: 800,
            runners: runners(true, true, true),
            balls: 3,
            strikes: 2,
            outs: 2,
            fatigue: 80,
            batterThreat: 95,
            recentAdverseEvent: true
        ))
        XCTAssertGreaterThan(runnersAndCount, calm)
        XCTAssertLessThanOrEqual(runnersAndCount, 1)
    }

    func testEachApprovedSituationFactorRaisesTension() {
        let baseline = MoundTensionModel.tension(for: input(leverage: 800))
        XCTAssertGreaterThan(
            MoundTensionModel.tension(for: input(leverage: 900)),
            baseline
        )
        XCTAssertGreaterThan(
            MoundTensionModel.tension(for: input(leverage: 800, runners: runners(false, true, false))),
            baseline
        )
        XCTAssertGreaterThan(
            MoundTensionModel.tension(for: input(leverage: 800, balls: 3, strikes: 2)),
            baseline
        )
        XCTAssertGreaterThan(
            MoundTensionModel.tension(for: input(leverage: 800, outs: 2)),
            baseline
        )
        XCTAssertGreaterThan(
            MoundTensionModel.tension(for: input(leverage: 800, fatigue: 100)),
            baseline
        )
        XCTAssertGreaterThan(
            MoundTensionModel.tension(for: input(leverage: 800, batterThreat: 100)),
            baseline
        )
        XCTAssertGreaterThan(
            MoundTensionModel.tension(for: input(leverage: 800, recentAdverseEvent: true)),
            baseline
        )
    }

    func testMaximumComposureDampsTensionByAboutNinetyTwoPercent() {
        let situation = input(
            leverage: 1_000,
            runners: runners(true, true, true),
            balls: 3,
            strikes: 2,
            outs: 2,
            fatigue: 90,
            batterThreat: 100,
            recentAdverseEvent: true
        )
        let composed = input(
            leverage: 1_000,
            runners: runners(true, true, true),
            balls: 3,
            strikes: 2,
            outs: 2,
            fatigue: 90,
            batterThreat: 100,
            recentAdverseEvent: true,
            command: 100,
            stamina: 100,
            awakenings: [.calmUnderPressure, .scoutComposure, .repeatableRelease, .twoStrikePlan, .trafficController, .lateInningReserve],
            memories: [.pressureRehearsal, .twoStrikeSequence, .bullpenCompass, .fatigueDiary, .coachLetter]
        )

        XCTAssertEqual(MoundTensionModel.composure(from: composed.composure), 1, accuracy: 0.000_001)
        XCTAssertEqual(MoundTensionModel.damping(for: 1), 0.08, accuracy: 0.000_001)
        XCTAssertLessThanOrEqual(
            MoundTensionModel.tension(for: composed),
            MoundTensionModel.tension(for: situation) * 0.08 + 0.000_001
        )
        XCTAssertEqual(
            MoundTensionModel.heartbeatHapticIntensity(effectiveTension: 0.08),
            MoundTensionModel.heartbeatHapticIntensity(effectiveTension: 1) * 0.08,
            accuracy: 0.000_001
        )
        let fullAudio = GameAudio.heartbeatVoices(tension: 1).map(\.gain)
        let composedAudio = GameAudio.heartbeatVoices(tension: 0.08).map(\.gain)
        XCTAssertEqual(composedAudio[0], fullAudio[0] * 0.08, accuracy: 0.000_001)
        XCTAssertEqual(composedAudio[1], fullAudio[1] * 0.08, accuracy: 0.000_001)
    }

    func testPracticeAndOffSituationHaveNoTensionFeedback() {
        let practice = input(
            officialGame: false,
            leverage: 1_000,
            runners: runners(true, true, true),
            balls: 3,
            strikes: 2,
            outs: 2,
            recentAdverseEvent: true
        )

        XCTAssertEqual(MoundTensionModel.tension(for: practice), 0)
        XCTAssertEqual(MoundTensionModel.entryTension(rawTension: 0.8, officialGame: false), 0)
        XCTAssertTrue(MoundHeartbeatPattern.burst(tension: 0, seed: 7).beats.isEmpty)
        XCTAssertEqual(
            MoundMeterDisturbance.offset(
                at: 0.2,
                effectiveTension: MoundTensionModel.tension(for: practice),
                beatTimes: [0],
                hapticsEnabled: true,
                reduceMotion: false,
                seed: 7
            ),
            0
        )
    }

    func testOfficialEntryHasThreeBeatsAndBandsUseApprovedBurstCadence() {
        XCTAssertEqual(MoundHeartbeatPattern.entry(tension: 0.1).beats.count, 3)
        XCTAssertEqual(MoundHeartbeatCadence.forTension(0.1).cycles, 0)

        let medium = MoundHeartbeatCadence.forTension(0.45)
        XCTAssertEqual(medium.cycles, 2)
        XCTAssertEqual(medium.restRange, 4...6)

        let high = MoundHeartbeatCadence.forTension(0.70)
        XCTAssertEqual(high.cycles, 3)
        XCTAssertEqual(high.restRange, 2...4)

        let climax = MoundHeartbeatCadence.forTension(0.90)
        XCTAssertEqual(climax.cycles, 4)
        XCTAssertEqual(climax.restRange, 0.8...1.5)
    }

    func testAdverseEventChangesOnlyOneBurstEpisode() {
        let adverse = MoundHeartbeatPattern.burst(
            tension: 0.70,
            seed: 44,
            burstIndex: 0,
            adverseEpisode: true
        )
        XCTAssertEqual(adverse.beats.filter(\.isIrregular).count, 1)

        let following = MoundHeartbeatPattern.burst(
            tension: 0.70,
            seed: 44,
            burstIndex: 1,
            adverseEpisode: false
        )
        XCTAssertTrue(following.beats.allSatisfy { !$0.isIrregular })
        XCTAssertTrue(adverse.beats.contains { $0.isIrregular })
    }

    func testJitterRespectsBandCapsAndReduceMotionHalvesIt() {
        let beatTimes = [0.0, 0.72]
        for tension in [0.10, 0.45, 0.70, 1.0] {
            let values = stride(from: 0.0, through: 1.2, by: 0.03).map { time in
                MoundMeterDisturbance.offset(
                    at: time,
                    effectiveTension: tension,
                    beatTimes: beatTimes,
                    hapticsEnabled: true,
                    reduceMotion: false,
                    seed: 123
                )
            }
            XCTAssertLessThanOrEqual(
                values.map(abs).max() ?? 0,
                MoundTensionModel.jitterCap(for: tension) + 0.000_001
            )
        }

        let full = MoundMeterDisturbance.offset(
            at: 0.16,
            effectiveTension: 0.90,
            beatTimes: [0],
            hapticsEnabled: true,
            reduceMotion: false,
            seed: 123
        )
        let reduced = MoundMeterDisturbance.offset(
            at: 0.16,
            effectiveTension: 0.90,
            beatTimes: [0],
            hapticsEnabled: true,
            reduceMotion: true,
            seed: 123
        )
        XCTAssertEqual(reduced, full * 0.5, accuracy: 0.000_001)
    }

    func testMeterDisturbanceIsDeterministicAndFrameIndependent() {
        let sampleTimes = [0.0, 0.017, 0.033, 0.083, 0.137, 0.251, 0.499, 0.812]
        let first = sampleTimes.map {
            MoundMeterDisturbance.position(
                base: 0.5,
                at: $0,
                effectiveTension: 0.70,
                beatTimes: [0.0, 0.63],
                hapticsEnabled: true,
                reduceMotion: false,
                seed: 991
            )
        }
        let second = sampleTimes.map {
            MoundMeterDisturbance.position(
                base: 0.5,
                at: $0,
                effectiveTension: 0.70,
                beatTimes: [0.0, 0.63],
                hapticsEnabled: true,
                reduceMotion: false,
                seed: 991
            )
        }
        XCTAssertEqual(first, second)
    }

    func testVisibleMeterPositionIsThePositionUsedForReleaseScoring() {
        let visible = MoundMeterDisturbance.position(
            base: 0.5,
            at: 0.06,
            effectiveTension: 1,
            beatTimes: [0],
            hapticsEnabled: true,
            reduceMotion: false,
            seed: 8
        )
        let delivery = DeliveryControl.delivery(meter: visible, aim: .zero, aimRadius: 46)
        let expected = Int(((1 - min(1, abs(visible - 0.5) * 2)) * 1_000).rounded())
        XCTAssertEqual(delivery.releaseAccuracy, expected)
    }

    func testSettingsKeepBaseMotionButGateTensionEffects() {
        XCTAssertFalse(MoundHeartbeatSettings.meterJitterEnabled(hapticsEnabled: false))
        XCTAssertTrue(MoundHeartbeatSettings.meterJitterEnabled(hapticsEnabled: true))
        XCTAssertFalse(MoundHeartbeatSettings.heartbeatAudioEnabled(soundEnabled: false))
        XCTAssertTrue(MoundHeartbeatSettings.heartbeatAudioEnabled(soundEnabled: true))
        XCTAssertEqual(
            MoundMeterDisturbance.offset(
                at: 0.1,
                effectiveTension: 1,
                beatTimes: [0],
                hapticsEnabled: false,
                reduceMotion: false,
                seed: 3
            ),
            0
        )
        XCTAssertTrue(SettingsCopy.hapticsFooter.contains("릴리스 미터"))
    }
}
