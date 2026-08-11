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
        fatigue: Int = 20,
        catcherTrust: Int = 50
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
            catcherTrust: catcherTrust,
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

    /// 첫 불펜은 학습을 위한 연습이므로 어떤 합법적인 투구 결과도 8구를 넘기지 않는다.
    func testTutorialPitchCapStopsEveryRepresentativeSeedAtEightPitches() throws {
        let engine = HighSchoolCareerEngine()
        for seed in ["1", "17", "20260723", "44771", "8675309"] {
            let started = try engine.start(.init(seed: seed, presetID: "power_prospect"))
            let session = PitchSession(
                scenario: .tutorial(state: started.snapshot), seed: started.nextSeed
            )
            XCTAssertEqual(session.scenario.maximumPitches, 8)
            session.start()

            var steps = 0
            while steps < 100 {
                steps += 1
                switch session.stage {
                case .ready:
                    session.throwPitch(delivery: .neutral)
                case .betweenBatters:
                    session.advanceToNextBatter()
                case .finished:
                    steps = 100
                case .failed(let message):
                    XCTFail("튜토리얼 합법 투구가 실패했습니다: \(message)")
                    steps = 100
                }
            }
            XCTAssertEqual(session.stage, .finished)
            XCTAssertLessThanOrEqual(session.pitches, 8)
        }
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

    func testManualCallAutomaticallyHoldsUntilCatcherCallIsAccepted() throws {
        let session = PitchSession(state: snapshot(), seed: "91731")
        session.start()
        let recommendation = try XCTUnwrap(session.preparation?.primaryRecommendation.call)
        let manualPitch = session.repertoire.first(where: { $0 != recommendation.pitchType })
            ?? recommendation.pitchType
        let manualZone = recommendation.zone == PitchZone(row: 0, column: 0)
            ? PitchZone(row: 2, column: 2)
            : PitchZone(row: 0, column: 0)

        session.choosePitchType(manualPitch)
        session.chooseZone(manualZone)
        session.chooseIntent(.edge)
        session.chooseIntensity(.controlled)

        XCTAssertTrue(session.holdCall)
        XCTAssertEqual(session.selectedPitchType, manualPitch)
        XCTAssertEqual(session.selectedZone, manualZone)
        XCTAssertEqual(session.selectedIntensity, .controlled)

        session.acceptCatcherRecommendation()
        XCTAssertFalse(session.holdCall)
        XCTAssertEqual(session.selectedPitchType, recommendation.pitchType)
        XCTAssertEqual(session.selectedZone, recommendation.zone)
        XCTAssertEqual(session.selectedIntent, recommendation.zoneIntent)
        XCTAssertEqual(session.selectedIntensity, recommendation.intensity)
    }

    func testCatcherTrustChangesVisibleScoutingReliabilityWithoutChangingTheBatter() {
        XCTAssertEqual(PitchScenario.scoutingReliability(base: 45, catcherTrust: 0), 20)
        XCTAssertEqual(PitchScenario.scoutingReliability(base: 45, catcherTrust: 50), 45)
        XCTAssertEqual(PitchScenario.scoutingReliability(base: 45, catcherTrust: 100), 70)

        let low = PitchScenario.pro(state: snapshot(catcherTrust: 0))
        let high = PitchScenario.pro(state: snapshot(catcherTrust: 100))
        XCTAssertEqual(low.lineup, high.lineup)
        XCTAssertEqual(low.scouting.reliability, 20)
        XCTAssertEqual(high.scouting.reliability, 70)
    }

    func testHeldManualCallSurvivesResumeCheckpoint() {
        var resume = syntheticResume(log: [])
        resume.holdCall = true
        resume.selectedPitchType = .slider
        resume.selectedZone = PitchZone(row: 2, column: 2)
        resume.selectedIntent = .chase
        resume.selectedIntensity = .controlled

        let restored = PitchSession(state: snapshot(), seed: "91732")
        restored.restore(from: resume)

        XCTAssertTrue(restored.holdCall)
        XCTAssertEqual(restored.selectedPitchType, .slider)
        XCTAssertEqual(restored.selectedZone, PitchZone(row: 2, column: 2))
        XCTAssertEqual(restored.selectedIntent, .chase)
        XCTAssertEqual(restored.selectedIntensity, .controlled)
    }

    func testSelectedBuildReadoutChangesBeforeThePitchWithEffort() {
        let session = PitchSession(state: snapshot(stuff: 64, command: 61, movement: 59), seed: "build-readout")
        session.start()
        session.selectedPitchType = .fourSeam
        session.selectedIntensity = .controlled
        let controlled = session.selectedAbilityReadout
        session.selectedIntensity = .maxEffort
        let maximum = session.selectedAbilityReadout

        XCTAssertGreaterThan(maximum.nominalVelocityTenthsKPH, controlled.nominalVelocityTenthsKPH)
        XCTAssertGreaterThanOrEqual(maximum.fatigueCost, controlled.fatigueCost)
        XCTAssertEqual(maximum.commandRating, controlled.commandRating)
    }

    func testRealStrongPitchingCanEarnOnlyOutcomeBackedAbilityMoments() {
        var moments: [PitchSession.PitchLogEntry] = []
        for seed in ["71", "991", "20260725", "44771", "8675309"] {
            let session = PitchSession(
                state: snapshot(stuff: 72, command: 72, movement: 72, stamina: 72),
                seed: seed
            )
            session.start()
            var decisions = 0
            while decisions < 100 {
                decisions += 1
                switch session.stage {
                case .ready:
                    session.selectedPitchType = decisions.isMultiple(of: 2) ? .slider : .fourSeam
                    session.selectedIntensity = .controlled
                    session.throwPitch()
                case .betweenBatters:
                    session.advanceToNextBatter()
                case .finished, .failed:
                    moments.append(contentsOf: session.pitchLog.filter { $0.abilityMoment != nil })
                    decisions = 100
                }
            }
        }

        XCTAssertFalse(moments.isEmpty, "강한 능력이 실제 성공 결과를 만들었는데도 체감 순간이 한 번도 잡히지 않았습니다.")
        XCTAssertTrue(moments.allSatisfy {
            [.calledStrike, .swingingStrike, .inPlayOut].contains($0.outcome)
        }, "볼·안타·파울에 능력 칭찬을 붙이면 결과를 왜곡합니다.")
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

    func testFastForwardUsesCatcherRecommendationsAndStopsAtBatterBoundary() {
        let session = PitchSession(state: snapshot(), seed: "20260725")
        session.start()
        XCTAssertEqual(session.stage, .ready)
        let startingBatter = session.batterIndex

        let advanced = session.fastForwardCurrentBatter()

        XCTAssertGreaterThan(advanced, 0)
        XCTAssertLessThanOrEqual(advanced, 12)
        XCTAssertEqual(session.pitchLog.count, advanced)
        XCTAssertTrue(session.pitchLog.allSatisfy(\.acceptedRecommendation))
        XCTAssertEqual(session.lastDelivery, .neutral)
        if case .ready = session.stage {
            XCTAssertEqual(advanced, 12, "타석이 끝나지 않았다면 안전 상한에서 멈춰야 합니다.")
        } else {
            XCTAssertTrue(session.batterIndex != startingBatter || session.stage != .ready)
        }
    }

    func testFastForwardVisibilityKeepsPracticeAndClutchCountsManual() {
        XCTAssertFalse(PitchView.canFastForwardCurrentBatter(
            isPractice: true, totalPitches: 1, leverage: 100, balls: 0, strikes: 0
        ))
        XCTAssertFalse(PitchView.canFastForwardCurrentBatter(
            isPractice: false, totalPitches: 1, leverage: 800, balls: 0, strikes: 0
        ))
        XCTAssertFalse(PitchView.canFastForwardCurrentBatter(
            isPractice: false, totalPitches: 1, leverage: 100, balls: 3, strikes: 1
        ))
        XCTAssertFalse(PitchView.canFastForwardCurrentBatter(
            isPractice: false, totalPitches: 1, leverage: 100, balls: 1, strikes: 2
        ))
        XCTAssertTrue(PitchView.canFastForwardCurrentBatter(
            isPractice: false, totalPitches: 1, leverage: 300, balls: 1, strikes: 1
        ))
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

    func testResumePreservesSequenceMomentsWithoutResurrectingAnOlderBadge() throws {
        let older = PitchSequenceMoment(
            pitchNumber: 1,
            tag: .stealStrike,
            headline: "카운트를 되찾았다",
            detail: "타자 우세 카운트에서 스트라이크를 넣었습니다."
        )
        let first = PitchSession.ResumeState.LogLine(
            pitchNumber: 1,
            call: call(type: .fourSeam, row: 1, column: 1),
            outcome: .calledStrike,
            shortFeedback: "스트라이크",
            acceptedRecommendation: true,
            sequenceMoment: older
        )
        let lastWithoutBadge = PitchSession.ResumeState.LogLine(
            pitchNumber: 2,
            call: call(type: .slider, row: 1, column: 1),
            outcome: .ball,
            shortFeedback: "볼",
            acceptedRecommendation: false,
            sequenceMoment: nil
        )
        var resume = syntheticResume(log: [first, lastWithoutBadge])
        resume.sequenceMoments = [older]

        let decoded = try JSONDecoder().decode(
            PitchSession.ResumeState.self,
            from: JSONEncoder().encode(resume)
        )
        let restored = PitchSession(state: snapshot(), seed: "resume-sequence")
        restored.restore(from: decoded)

        XCTAssertEqual(restored.sequenceMoments, [older])
        XCTAssertEqual(restored.sequenceMasteryCount, 1)
        XCTAssertNil(restored.lastSequenceMoment, "마지막 공의 명시적 nil이 이전 배지를 되살리면 안 됩니다.")
        XCTAssertEqual(restored.report(scenarioNumber: 8).sequenceMasteryCount, 1)
    }

    func testLegacyResumeWithoutSequenceFieldsLoadsAnEmptySequence() throws {
        let older = PitchSequenceMoment(
            pitchNumber: 1,
            tag: .insideOutside,
            headline: "가로 폭을 썼다",
            detail: "몸쪽과 바깥쪽을 갈랐습니다."
        )
        var current = syntheticResume(log: [
            .init(
                pitchNumber: 1,
                call: call(type: .fourSeam, row: 1, column: 0),
                outcome: .calledStrike,
                shortFeedback: "스트라이크",
                acceptedRecommendation: true,
                sequenceMoment: older
            ),
        ])
        current.sequenceMoments = [older]
        current.maximumBatters = 6
        let data = try JSONEncoder().encode(current)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "sequenceMoments")
        object.removeValue(forKey: "maximumBatters")
        if var lines = object["pitchLog"] as? [[String: Any]] {
            for index in lines.indices { lines[index].removeValue(forKey: "sequenceMoment") }
            object["pitchLog"] = lines
        }

        let legacy = try JSONDecoder().decode(
            PitchSession.ResumeState.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        let restored = PitchSession(state: snapshot(), seed: "legacy-sequence")
        restored.restore(from: legacy)
        XCTAssertNil(legacy.maximumBatters, "옛 체크포인트는 당시 고정 길이 4타자로 해석할 수 있어야 합니다.")
        XCTAssertTrue(restored.sequenceMoments.isEmpty)
        XCTAssertNil(restored.lastSequenceMoment)
        XCTAssertNil(restored.pitchLog.first?.sequenceMoment)
    }

    func testFirstPitchToNextBatterCannotUsePreviousBattersPitchForTwoPitchTag() {
        let previousBatterPitch = PitchSession.ResumeState.LogLine(
            pitchNumber: 3,
            call: call(type: .fourSeam, row: 0, column: 0),
            outcome: .calledStrike,
            shortFeedback: "타석 종료",
            acceptedRecommendation: true,
            sequenceMoment: nil
        )
        let session = PitchSession(state: snapshot(), seed: "44771")
        session.restore(from: syntheticResume(log: [previousBatterPitch]))
        session.advanceToNextBatter()
        XCTAssertEqual(session.context.pitchNumber, 1)

        session.selectedPitchType = .changeup
        session.selectedZone = PitchZone(row: 2, column: 2)
        session.selectedIntent = .strike
        session.selectedIntensity = .normal
        session.throwPitch()

        let forbidden: Set<PitchSequenceTag> = [.speedLadder, .eyeLevelChange, .insideOutside]
        XCTAssertFalse(session.lastSequenceMoment.map { forbidden.contains($0.tag) } ?? false)
    }

    func testSequenceAnalyticsAreAggregatedSortedAndRecommendationRateIsNormalized() {
        let moments = [
            PitchSequenceMoment(pitchNumber: 1, tag: .speedLadder, headline: "속도차 적중", detail: "속도차"),
            PitchSequenceMoment(pitchNumber: 2, tag: .counterRead, headline: "읽힘을 역이용했다", detail: "반복 끊기"),
            PitchSequenceMoment(pitchNumber: 3, tag: .speedLadder, headline: "속도차 적중", detail: "속도차"),
        ]
        var resume = syntheticResume(log: [])
        resume.pitches = 4
        resume.recommendationAccepted = 3
        resume.sequenceMoments = moments
        let session = PitchSession(state: snapshot(), seed: "analytics-sequence")
        session.restore(from: resume)

        XCTAssertEqual(session.sequenceMasteryCount, 3)
        XCTAssertEqual(session.sequenceTagIDs, ["counter_read", "speed_ladder"])
        XCTAssertEqual(session.recommendationAcceptancePermille, 750)
        XCTAssertEqual(session.recommendationAcceptanceRate, 0.75, accuracy: 0.000_001)
        let metrics = session.gameFinishedAnalyticsMetrics
        XCTAssertEqual(metrics["recommendation_acceptance_rate"] as? Double, 0.75)
        XCTAssertEqual(metrics["sequence_mastery_count"] as? Int, 3)
        XCTAssertEqual(metrics["sequence_tags"] as? String, "counter_read,speed_ladder")
        XCTAssertEqual(session.report(scenarioNumber: 8).sequenceMasteryCount, 3)

        resume.pitches = 0
        resume.recommendationAccepted = 0
        session.restore(from: resume)
        XCTAssertEqual(session.recommendationAcceptanceRate, 0)

        resume.pitches = 4
        resume.recommendationAccepted = 4
        session.restore(from: resume)
        XCTAssertEqual(session.recommendationAcceptanceRate, 1)
    }

    func testAbilityMomentsSurviveResumeAndAggregateWithoutDuplicateTypes() throws {
        let lines: [PitchSession.ResumeState.LogLine] = [
            .init(
                pitchNumber: 1,
                call: call(type: .fourSeam, row: 1, column: 1),
                outcome: .swingingStrike,
                shortFeedback: "헛스윙",
                acceptedRecommendation: true,
                abilityMoment: .power
            ),
            .init(
                pitchNumber: 2,
                call: call(type: .slider, row: 2, column: 2),
                outcome: .inPlayOut,
                shortFeedback: "땅볼 아웃",
                acceptedRecommendation: false,
                abilityMoment: .movement
            ),
            .init(
                pitchNumber: 3,
                call: call(type: .fourSeam, row: 0, column: 0),
                outcome: .swingingStrike,
                shortFeedback: "헛스윙",
                acceptedRecommendation: true,
                abilityMoment: .power
            ),
        ]
        let resume = syntheticResume(log: lines)
        let decoded = try JSONDecoder().decode(
            PitchSession.ResumeState.self,
            from: JSONEncoder().encode(resume)
        )
        let restored = PitchSession(state: snapshot(), seed: "ability-resume")
        restored.restore(from: decoded)

        XCTAssertEqual(restored.abilityMomentCount, 3)
        XCTAssertEqual(restored.abilityMomentIDs, ["movement", "power"])
        XCTAssertEqual(restored.lastAbilityMoment, .power)
        XCTAssertEqual(restored.gameFinishedAnalyticsMetrics["ability_moment_count"] as? Int, 3)
        XCTAssertEqual(
            restored.gameFinishedAnalyticsMetrics["ability_moment_types"] as? String,
            "movement,power"
        )
    }

    func testLegacyResumeWithoutAbilityMomentLoadsWithoutInventingOne() throws {
        let resume = syntheticResume(log: [
            .init(
                pitchNumber: 1,
                call: call(type: .fourSeam, row: 1, column: 1),
                outcome: .calledStrike,
                shortFeedback: "스트라이크",
                acceptedRecommendation: true,
                abilityMoment: .command
            ),
        ])
        let data = try JSONEncoder().encode(resume)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        if var lines = object["pitchLog"] as? [[String: Any]] {
            for index in lines.indices { lines[index].removeValue(forKey: "abilityMoment") }
            object["pitchLog"] = lines
        }

        let legacy = try JSONDecoder().decode(
            PitchSession.ResumeState.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        let restored = PitchSession(state: snapshot(), seed: "legacy-ability")
        restored.restore(from: legacy)

        XCTAssertNil(restored.pitchLog.first?.abilityMoment)
        XCTAssertNil(restored.lastAbilityMoment)
        XCTAssertEqual(restored.abilityMomentCount, 0)
        XCTAssertEqual(restored.gameFinishedAnalyticsMetrics["ability_moment_types"] as? String, "")
    }

    func testDeliberateAlternatingSequencesEarnMoreMasteryThanAutoRecommendations() {
        func mastery(seed: String, deliberate: Bool) -> Int {
            let session = PitchSession(state: snapshot(), seed: seed)
            session.start()
            var decisions = 0
            while decisions < 120 {
                decisions += 1
                switch session.stage {
                case .ready:
                    if deliberate {
                        let even = session.context.pitchNumber.isMultiple(of: 2)
                        session.selectedPitchType = even ? .curveball : .fourSeam
                        session.selectedZone = PitchZone(
                            row: even ? 2 : 0,
                            column: even ? 2 : 0
                        )
                        session.selectedIntent = session.context.strikes == 2 ? .chase : .strike
                        session.selectedIntensity = .controlled
                    }
                    session.throwPitch()
                case .betweenBatters:
                    session.advanceToNextBatter()
                case .finished, .failed:
                    return session.sequenceMasteryCount
                }
            }
            return session.sequenceMasteryCount
        }

        let seeds = (1...16).map { String($0 * 7_919) }
        let automatic = seeds.reduce(0) { $0 + mastery(seed: $1, deliberate: false) }
        let deliberate = seeds.reduce(0) { $0 + mastery(seed: $1, deliberate: true) }
        XCTAssertGreaterThan(deliberate, automatic, "의도적인 속도·눈높이 변화가 자동 사인만 따른 세션보다 더 많이 인식돼야 합니다.")
    }

    private func call(type: PitchType, row: Int, column: Int) -> PitchCall {
        PitchCall(
            pitchType: type,
            zone: PitchZone(row: row, column: column),
            zoneIntent: .strike,
            intensity: .normal
        )
    }

    private func syntheticResume(
        log: [PitchSession.ResumeState.LogLine]
    ) -> PitchSession.ResumeState {
        let base = PitchSession(state: snapshot(), seed: "99117")
        return PitchSession.ResumeState(
            scenarioID: base.scenario.id,
            seed: "99117",
            batterIndex: 0,
            stageKind: "between",
            stageMessage: "타석이 끝났습니다.",
            fatigue: base.context.fatigue,
            gameState: base.gameState,
            gameLog: base.gameLog,
            rivalMemory: nil,
            pitches: log.count,
            strikeouts: 0,
            consecutiveStrikeouts: 0,
            walks: 0,
            runsAllowed: 0,
            expectedDamage: 0,
            actualDamage: 0,
            recommendationAccepted: log.filter(\.acceptedRecommendation).count,
            outsRecorded: 0,
            rivalOutcomes: [],
            hitByPitches: 0,
            holdCall: false,
            pitchLog: log,
            sequenceMoments: log.compactMap(\.sequenceMoment)
        )
    }
}
