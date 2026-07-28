import XCTest
import SimulationCore
@testable import BaseballIOS

/// 중요 경기가 실제 시뮬레이션인지 확인한다. 이전 구현은 선택지별 고정 성적을 돌려줬다(계획 문서 D2).
@MainActor
final class PitchSessionTests: XCTestCase {
    private func snapshot(
        stuff: Int = 42,
        command: Int = 38,
        movement: Int = 40,
        stamina: Int = 40,
        fatigue: Int = 20
    ) -> ProCareerSnapshot {
        let team = ProCareerEngine.proTeams[0]
        let rival = ProRivalBatter(
            id: "rival-1",
            name: "표준상대",
            archetype: "중심타선 거포",
            teamID: team.id,
            teamName: team.name,
            record: "타율 .301 · 22홈런",
            profile: "몸쪽 높은 공을 당겨 넘기는 타자"
        )
        return ProCareerSnapshot(
            proCareerID: "pro-test",
            revision: 3,
            phase: .importantGame,
            identity: .defaultPitcher,
            pitcher: PitcherSnapshot(id: "p-test", name: "테스트", stuff: stuff, command: command, movement: movement, stamina: stamina),
            team: team,
            entitlement: AppEntitlement.paidApp(),
            age: 20,
            season: 1,
            week: 8,
            level: .minor,
            role: .setup,
            managerTrust: 50,
            catcherTrust: 50,
            fatigue: fatigue,
            injuryWeeks: 0,
            serviceYears: 0,
            militaryCompleted: false,
            contract: ProContractSnapshot(yearsRemaining: 3, annualSalary: 30_000_000, rolePromise: .setup),
            currentStats: ProSeasonStats(season: 1, teamID: team.id),
            careerStats: [],
            awards: [],
            milestones: [],
            news: [],
            hallOfFameScore: nil,
            commitment: "",
            balanceVersion: PitcherPresetCatalog.balanceVersion,
            seasonSegment: .firstHalf,
            seasonTrigger: .callUpAudition,
            currentRival: rival,
            seasonTensions: [],
            seasonImportantGames: 0
        )
    }

    /// 세션은 매 투구마다 준비 토큰을 받아야 하며, 던지면 결과가 나와야 한다.
    func testSessionProducesRealPitchResults() {
        let session = PitchSession(state: snapshot(), seed: "20260725")
        session.start()
        XCTAssertNotNil(session.preparation)
        XCTAssertEqual(session.stage, .ready)

        session.throwPitch()
        XCTAssertNotNil(session.lastResult)
        XCTAssertEqual(session.pitches, 1)
        XCTAssertEqual(session.pitchLog.count, 1)
    }

    /// 같은 시드에 같은 사인이면 같은 결과가 나온다. 코어 결정론이 셸을 통과해도 유지돼야 한다.
    func testSameSeedAndSameCallsGiveSameOutcomes() {
        func run() -> [PitchOutcome] {
            let session = PitchSession(state: snapshot(), seed: "20260725")
            session.start()
            var outcomes: [PitchOutcome] = []
            for _ in 0..<6 {
                guard case .ready = session.stage else { break }
                session.selectedPitchType = .fourSeam
                session.selectedZone = PitchZone(row: 1, column: 1)
                session.selectedIntent = .strike
                session.selectedIntensity = .normal
                session.throwPitch()
                if let outcome = session.lastResult?.snapshot.outcome { outcomes.append(outcome) }
            }
            return outcomes
        }
        XCTAssertFalse(run().isEmpty)
        XCTAssertEqual(run(), run())
    }

    /// 시드가 다르면 결과가 갈린다. 고정 리포트였다면 이 검사가 실패한다.
    func testDifferentSeedsDivergeOnTheSameChoices() {
        func outcomes(seed: String) -> [PitchOutcome] {
            let session = PitchSession(state: snapshot(), seed: seed)
            session.start()
            var collected: [PitchOutcome] = []
            for _ in 0..<8 {
                guard case .ready = session.stage else { break }
                session.selectedPitchType = .fourSeam
                session.selectedZone = PitchZone(row: 1, column: 1)
                session.selectedIntent = .strike
                session.selectedIntensity = .normal
                session.throwPitch()
                if let outcome = session.lastResult?.snapshot.outcome { collected.append(outcome) }
            }
            return collected
        }
        let seeds = ["1", "99", "20260725", "777777", "31337"]
        let runs = seeds.map(outcomes(seed:))
        XCTAssertTrue(runs.contains { $0 != runs[0] }, "모든 시드가 같은 결과를 냈습니다. 시뮬레이션이 아니라 고정값일 수 있습니다.")
    }

    /// 능력치가 결과에 영향을 준다. 리포트가 고정값이면 두 투수의 성적이 똑같이 나온다.
    func testAbilityChangesTheAccumulatedReport() {
        func report(stuff: Int, command: Int, seed: String) -> ImportantInningReport {
            let session = PitchSession(state: snapshot(stuff: stuff, command: command), seed: seed)
            session.start()
            var guardCount = 0
            while guardCount < 60 {
                guardCount += 1
                switch session.stage {
                case .ready:
                    session.selectedIntent = .edge
                    session.throwPitch()
                case .betweenBatters:
                    session.advanceToNextBatter()
                case .finished, .failed:
                    return session.report(scenarioNumber: 8)
                }
            }
            return session.report(scenarioNumber: 8)
        }
        // 한 판만 보면 우연히 같은 성적이 나올 수 있다. 여러 시드의 합계로 비교한다.
        let seeds = ["1", "99", "20260725", "777777", "31337", "8675309"]
        func totals(stuff: Int, command: Int) -> [Int] {
            seeds.reduce(into: [0, 0, 0, 0]) { totals, seed in
                let report = report(stuff: stuff, command: command, seed: seed)
                totals[0] += report.strikeouts
                totals[1] += report.walks
                totals[2] += report.runsAllowed
                totals[3] += report.pitches
            }
        }
        XCTAssertNotEqual(
            totals(stuff: 24, command: 24),
            totals(stuff: 76, command: 76),
            "능력치가 달라도 성적 합계가 같습니다."
        )
    }

    /// 세션은 반드시 끝나야 한다. 볼넷이 이어져도 타자 상한에서 멈춘다.
    func testSessionAlwaysTerminates() {
        let session = PitchSession(state: snapshot(command: 20), seed: "5150")
        session.start()
        var steps = 0
        while steps < 200 {
            steps += 1
            switch session.stage {
            case .ready:
                // 존 밖으로만 던져 볼넷을 강제한다.
                session.selectedIntent = .chase
                session.selectedZone = PitchZone(row: 2, column: 0)
                session.throwPitch()
            case .betweenBatters:
                session.advanceToNextBatter()
            case .finished, .failed:
                XCTAssertLessThan(steps, 200)
                return
            }
        }
        XCTFail("세션이 끝나지 않았습니다.")
    }

    /// 타자가 바뀌어도 세션이 실패하지 않아야 한다. 라이벌 기억은 투수-타자 조합에 묶여 있어
    /// 다음 타자로 그대로 넘기면 코어가 matchupID 불일치로 거부한다.
    func testAdvancingBattersDoesNotFailTheSession() {
        for seed in ["1", "42", "20260725", "999999"] {
            let session = PitchSession(state: snapshot(), seed: seed)
            session.start()
            var batters = 0
            var steps = 0
            while steps < 200 {
                steps += 1
                switch session.stage {
                case .ready:
                    session.throwPitch()
                case .betweenBatters:
                    batters += 1
                    session.advanceToNextBatter()
                case .failed(let message):
                    return XCTFail("시드 \(seed)에서 세션이 실패했습니다: \(message)")
                case .finished:
                    XCTAssertGreaterThan(session.pitches, 0)
                    steps = 200
                }
            }
        }
    }

    /// 이닝을 막아낸 등판의 아웃이 0으로 기록되던 버그를 지킨다.
    ///
    /// 초가 끝나면 이닝 상태가 말(아웃 0)로 넘어간다. 최종 상태에서 아웃을 역산하면
    /// 그 순간 막 잡은 3아웃이 통째로 사라진다 — 잘 던질수록 이닝이 기록되지 않아
    /// RA/9가 부풀고 화면에 "0.0이닝"이 찍혔다.
    func testOutsSurviveTheInningFlip() {
        XCTAssertEqual(PitchSession.totalOuts(InningStateSnapshot(inning: 6, half: .top, outs: 2)), 32)
        XCTAssertEqual(PitchSession.totalOuts(InningStateSnapshot(inning: 6, half: .bottom, outs: 0)), 33)

        var verifiedInningEnd = false
        for seed in (1...60).map(String.init) {
            let session = PitchSession(state: snapshot(), seed: seed)
            session.start()
            var steps = 0
            while steps < 200 {
                steps += 1
                switch session.stage {
                case .ready: session.throwPitch()
                case .betweenBatters: session.advanceToNextBatter()
                case .finished, .failed: steps = 200
                }
            }
            guard let state = session.gameState.inningState else { continue }
            // 이 픽스처는 무사(아웃 0)에서 시작한다. 이닝이 실제로 끝났으면 아웃은 정확히 3,
            // 타자 제한으로 끊겼으면 현재 아웃과 같아야 한다.
            if state.half == .bottom || state.inning > 7 {
                XCTAssertEqual(session.report(scenarioNumber: 1).outs, 3, "시드 \(seed)")
                verifiedInningEnd = true
                break
            }
            XCTAssertEqual(session.report(scenarioNumber: 1).outs, state.outs, "시드 \(seed)")
        }
        XCTAssertTrue(verifiedInningEnd, "60개 시드 중 이닝을 끝낸 세션이 없습니다.")
    }

    /// 누적 리포트는 실제 투구 수와 일치해야 한다.
    func testReportMatchesWhatWasActuallyThrown() {
        let session = PitchSession(state: snapshot(), seed: "20260725")
        session.start()
        var thrown = 0
        while thrown < 5, case .ready = session.stage {
            session.throwPitch()
            thrown += 1
        }
        XCTAssertEqual(session.report(scenarioNumber: 8).pitches, session.pitchLog.count)
        XCTAssertEqual(session.report(scenarioNumber: 8).scenarioNumber, 8)
    }

    /// 타자가 바뀌면 직전 결과가 사라져야 한다.
    ///
    /// 실기기에서 발견: 안타를 맞고 다음 타자와 붙는데 화면에 "안타"가 계속 떠 있었다.
    /// 방금 그 공에 맞은 것처럼 보여서 무슨 일이 일어나는지 알 수 없다.
    func testAdvancingToNextBatterClearsThePreviousResult() throws {
        let session = PitchSession(state: snapshot(), seed: "8811")
        session.start()
        // 타석이 끝날 때까지 던진다.
        var guardCount = 0
        while case .ready = session.stage, guardCount < 40 {
            session.throwPitch()
            guardCount += 1
        }
        guard case .betweenBatters = session.stage else {
            throw XCTSkip("이 시드에서는 타석이 끝나지 않았습니다.")
        }
        XCTAssertNotNil(session.lastResult, "타석이 끝났는데 결과가 없습니다.")

        session.advanceToNextBatter()
        XCTAssertNil(session.lastResult, "다음 타자로 넘어갔는데 직전 결과가 남아 있습니다.")
        XCTAssertTrue(session.lastCues.isEmpty, "직전 투구의 소리가 남아 있습니다.")
        XCTAssertNil(session.lastDelivery, "직전 릴리스 판정이 남아 있습니다.")
    }
}
