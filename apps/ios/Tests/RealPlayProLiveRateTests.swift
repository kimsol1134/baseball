import XCTest
import SimulationCore
@testable import BaseballIOS
import BaseballIOSDomain

/// 프로 직접 등판이 어느 곡선을 쓰는가 — 고교 §2.5와 같은 질문.
///
/// v13은 자동 등판만 프로 확률식이고 직접 등판은 `.legacy`다. v14는 곡선과
/// 평가 감도를 **한 버전에서 같이** 옮긴다. 최종 지표는 고교 지명률에 해당하는
/// 시즌 1 콜업·보직. 생 프리셋은 능력 평균 37이라 콜업 문(46)에 시즌 1로는
/// 닿지 않으므로, 능력 문은 선 위에 올려 믿음·경험이 당락을 가리게 한다.
@MainActor
final class RealPlayProLiveRateTests: XCTestCase {
    private struct PitchingTotals {
        var games = 0
        var outs = 0
        var strikeouts = 0
        var walks = 0
        var hits = 0
        var runsAllowed = 0

        mutating func add(_ report: ImportantInningReport) {
            games += 1
            outs += report.outs ?? 0
            strikeouts += report.strikeouts
            walks += report.walks
            hits += report.hits ?? 0
            runsAllowed += report.runsAllowed
        }

        static func + (lhs: PitchingTotals, rhs: PitchingTotals) -> PitchingTotals {
            PitchingTotals(
                games: lhs.games + rhs.games, outs: lhs.outs + rhs.outs,
                strikeouts: lhs.strikeouts + rhs.strikeouts, walks: lhs.walks + rhs.walks,
                hits: lhs.hits + rhs.hits, runsAllowed: lhs.runsAllowed + rhs.runsAllowed
            )
        }

        func per9(_ value: Int) -> Double {
            outs > 0 ? Double(value) * 27 / Double(outs) : 0
        }

        var whip: Double {
            outs > 0 ? Double(walks + hits) * 3 / Double(outs) : 0
        }

        var line: String {
            String(
                format: "경기 %d · %.1f이닝 · K/9 %.2f · BB/9 %.2f · H/9 %.2f · R/9 %.2f · WHIP %.2f",
                games, Double(outs) / 3, per9(strikeouts), per9(walks), per9(hits),
                per9(runsAllowed), whip
            )
        }
    }

    private struct SeasonOne {
        let calledUp: Bool
        let everMajor: Bool
        let trust: Int
        let skill: Int
        let level: ProLevel
        let role: ProRole
        let evaluationTrust: Int
        let pitching: PitchingTotals
        let seasonRA9: Double
        let seasonGames: Int
        let seasonStrikeouts: Int
        let door: String
    }

    /// 콜업 능력 문(46) 위에 올린 신인. 생 프리셋 평균 37은 시즌 1에 구조적으로
    /// 콜업이 0이라, 고교 지명률에 해당하는 지표를 잴 수 없다.
    private func skillLinePitcher(_ base: PitcherSnapshot) -> PitcherSnapshot {
        PitcherSnapshot(
            id: base.id,
            name: base.name,
            stuff: 50,
            command: 44,
            movement: 46,
            stamina: 44,
            pitchProfiles: base.pitchProfiles,
            throwingHand: base.throwingHand
        )
    }

    private func playSeasonOne(
        seed: UInt64,
        rulesVersion: Int,
        delivery: PitchDelivery = .neutral
    ) throws -> SeasonOne? {
        let engine = ProCareerEngine(rulesVersion: rulesVersion)
        let preset = try XCTUnwrap(PitcherPresetCatalog.all.first { $0.id == "power_prospect" })
        let pitcher = skillLinePitcher(preset.pitcher)
        let identity = PlayerIdentitySnapshot(
            name: preset.pitcher.name,
            throwingHand: pitcher.throwingHand,
            bodyType: .balanced,
            region: "서울",
            appearanceSeed: PlayerAppearanceSeed.make(careerSeed: String(seed), lifeNumber: 1)
        )
        var result = try engine.start(.init(
            seed: String(seed),
            identity: identity,
            pitcher: pitcher,
            draftResult: CareerBootstrap.draftResult(preset: preset, seed: seed),
            entitlement: AppEntitlement.paidApp()
        ))
        if result.snapshot.phase == .contractOffer {
            result = try engine.signContract(.init(seed: result.nextSeed, state: result.snapshot))
        }
        var pitching = PitchingTotals()
        var liveTrust = 0
        var everMajor = result.snapshot.level == .major

        for _ in 0..<80 {
            let state = result.snapshot
            everMajor = everMajor || state.level == .major
            switch state.phase {
            case .weeklyPlan:
                let plan: ProWeekPlan
                if state.fatigue >= 70 {
                    plan = .recover
                } else if state.managerTrust < 62 {
                    plan = .earnTrust
                } else {
                    plan = .refineCommand
                }
                result = try engine.planWeek(.init(seed: result.nextSeed, state: state, plan: plan))
            case .importantGame:
                let scenario = PitchScenario.pro(state: state)
                let session = PitchSession(scenario: scenario, seed: result.nextSeed)
                session.start()
                for _ in 0..<24 {
                    if case .ready = session.stage {
                        session.fastForwardCurrentBatter(delivery: delivery)
                    }
                    if case .betweenBatters = session.stage {
                        session.advanceToNextBatter()
                        continue
                    }
                    break
                }
                let report = session.report(scenarioNumber: max(1, state.week))
                pitching.add(report)
                let trustBefore = state.managerTrust
                result = try engine.resolveImportantGame(
                    .init(seed: result.nextSeed, state: state, report: report)
                )
                liveTrust += result.snapshot.managerTrust - trustBefore
            case .seasonDecision:
                let decision = try XCTUnwrap(state.pendingDecision)
                let choice = try XCTUnwrap(decision.choices.min { lhs, rhs in
                    if lhs.effect.fatigueDelta != rhs.effect.fatigueDelta {
                        return lhs.effect.fatigueDelta < rhs.effect.fatigueDelta
                    }
                    return lhs.id < rhs.id
                })
                result = try engine.applySeasonDecision(.init(
                    seed: result.nextSeed, state: state,
                    decisionID: decision.id, choiceID: choice.id
                ))
            case .seasonReview:
                let finished = state
                let outs = finished.currentStats.inningsOuts
                let ra9 = outs > 0
                    ? Double(finished.currentStats.runsAllowed) * 27 / Double(outs)
                    : 0
                let skill = ProCallUpRules.skill(finished.pitcher)
                var doors: [String] = []
                if finished.managerTrust < ProCallUpRules.trustRequired {
                    doors.append("믿음 \(finished.managerTrust)<\(ProCallUpRules.trustRequired)")
                }
                if skill < ProCallUpRules.skillRequired {
                    doors.append("능력 \(skill)<\(ProCallUpRules.skillRequired)")
                }
                if !ProCallUpRules.experience(season: finished.season, stats: finished.currentStats) {
                    doors.append(
                        "경험 경기\(finished.currentStats.games)<\(ProCallUpRules.gamesRequired) "
                            + "K\(finished.currentStats.strikeouts)<\(ProCallUpRules.strikeoutsRequired)"
                    )
                }
                return SeasonOne(
                    calledUp: finished.level == .major,
                    everMajor: everMajor || finished.level == .major,
                    trust: finished.managerTrust,
                    skill: skill,
                    level: finished.level,
                    role: finished.role,
                    evaluationTrust: liveTrust,
                    pitching: pitching,
                    seasonRA9: ra9,
                    seasonGames: finished.currentStats.games,
                    seasonStrikeouts: finished.currentStats.strikeouts,
                    door: doors.isEmpty ? "열림" : doors.joined(separator: " · ")
                )
            case .offseasonDecision, .retirementDecision, .completed:
                XCTFail("시즌 1 정산을 건너뛰었습니다")
                return nil
            case .contractOffer:
                result = try engine.signContract(.init(seed: result.nextSeed, state: state))
            default:
                XCTFail("시즌 1에서 예상하지 못한 국면 \(state.phase)")
                return nil
            }
        }
        XCTFail("시드 \(seed): 시즌 1이 끝나지 않았습니다")
        return nil
    }

    /// 같은 하네스로 v13(배포)과 v14(곡선+감도)의 시즌 1 콜업을 나란히 찍는다.
    /// 밴드를 주장하지 않는다 — **재는 것이 일이다.**
    func testSeasonOneCallUpOnBothLiveCurves() throws {
        let seeds: [UInt64] = Array(1...24)
        var starterEligible: [String: [String: Int]] = [:]
        var trustMedian: [String: [String: Int]] = [:]
        for (curveName, rulesVersion) in [
            ("v13 배포 · legacy 라이브", 13),
            ("v14 곡선+감도", 14),
        ] {
            var rates: [String: (called: Int, ever: Int, starter: Int, total: Int)] = [:]
            for (handName, accuracy) in [("중립", 500), ("완벽", 950)] {
                var called = 0
                var ever = 0
                var starter = 0
                var eligible = 0
                var total = 0
                var trusts: [Int] = []
                var liveTrusts: [Int] = []
                var skills: [Int] = []
                var games: [Int] = []
                var roles: [String] = []
                var live = PitchingTotals()
                var ra9: [Double] = []
                var doors: [String] = []
                for seed in seeds {
                    guard let season = try playSeasonOne(
                        seed: seed,
                        rulesVersion: rulesVersion,
                        delivery: PitchDelivery(releaseAccuracy: accuracy, aimAccuracy: accuracy)
                    ) else { continue }
                    total += 1
                    if season.calledUp { called += 1 }
                    if season.everMajor { ever += 1 }
                    if season.role == .starter { starter += 1 }
                    if season.trust >= 74 { eligible += 1 }
                    trusts.append(season.trust)
                    liveTrusts.append(season.evaluationTrust)
                    skills.append(season.skill)
                    games.append(season.seasonGames)
                    roles.append(season.role.rawValue)
                    live = live + season.pitching
                    ra9.append(season.seasonRA9)
                    doors.append(season.door)
                }
                rates[handName] = (called, ever, starter, total)
                func median(_ values: [Int]) -> Int {
                    guard !values.isEmpty else { return 0 }
                    let sorted = values.sorted()
                    return sorted[sorted.count / 2]
                }
                let trustMid = median(trusts)
                starterEligible[curveName, default: [:]][handName] = total == 0 ? 0 : eligible * 100 / total
                trustMedian[curveName, default: [:]][handName] = trustMid
                let rate = total == 0 ? 0 : called * 100 / total
                let everRate = total == 0 ? 0 : ever * 100 / total
                let starterRate = total == 0 ? 0 : starter * 100 / total
                let eligibleRate = total == 0 ? 0 : eligible * 100 / total
                print("[pro-live] \(curveName) · \(handName) — 콜업 \(called)/\(total) = \(rate)% · "
                    + "시즌 중 1군 \(ever)/\(total) = \(everRate)% · 선발 \(starter)/\(total) = \(starterRate)% · "
                    + "선발 가능 믿음 \(eligible)/\(total) = \(eligibleRate)%")
                print("[pro-live]   믿음 중앙 \(median(trusts)) · 직접 믿음 중앙 \(median(liveTrusts)) · "
                    + "능력 중앙 \(median(skills)) · 경기 중앙 \(median(games)) · "
                    + "시즌 RA/9 중앙 \(ra9.isEmpty ? 0 : ra9.sorted()[ra9.count / 2])")
                print("[pro-live]   직접 등판 \(live.line)")
                let doorCounts = Dictionary(doors.map { ($0, 1) }, uniquingKeysWith: +)
                let roleCounts = Dictionary(roles.map { ($0, 1) }, uniquingKeysWith: +)
                print("[pro-live]   문 \(doorCounts.keys.sorted().map { "\($0) \(doorCounts[$0] ?? 0)" }.joined(separator: " · "))")
                print("[pro-live]   보직 \(roleCounts.keys.sorted().map { "\($0) \(roleCounts[$0] ?? 0)" }.joined(separator: " · "))")
                print("[pro-live]   믿음 \(trusts.sorted().map(String.init).joined(separator: ","))")
                XCTAssertGreaterThan(live.games, 0, "\(curveName) \(handName): 직접 던진 경기가 없습니다")
            }
            let low = rates["중립"]?.called ?? 0
            let high = rates["완벽"]?.called ?? 0
            let total = max(1, rates["중립"]?.total ?? 1)
            print("[pro-live] \(curveName) 콜업 간격 \(high * 100 / total - low * 100 / total)%p")
            let eligibleLow = starterEligible[curveName]?["중립"] ?? 0
            let eligibleHigh = starterEligible[curveName]?["완벽"] ?? 0
            print("[pro-live] \(curveName) 선발 가능 간격 \(eligibleHigh - eligibleLow)%p")
        }
        let v13Gap = (starterEligible["v13 배포 · legacy 라이브"]?["완벽"] ?? 0)
            - (starterEligible["v13 배포 · legacy 라이브"]?["중립"] ?? 0)
        let v14Gap = (starterEligible["v14 곡선+감도"]?["완벽"] ?? 0)
            - (starterEligible["v14 곡선+감도"]?["중립"] ?? 0)
        let v13Trust = trustMedian["v13 배포 · legacy 라이브"]?["중립"] ?? 0
        let v14Trust = trustMedian["v14 곡선+감도"]?["중립"] ?? 0
        XCTAssertGreaterThan(v14Gap, v13Gap, "v14 감도가 선발 가능 믿음 간격을 벌리지 못했습니다")
        XCTAssertGreaterThan(v13Trust, v14Trust, "v14 곡선이 중립 믿음을 낮추지 못했습니다")
        XCTAssertGreaterThanOrEqual(v14Gap, 20, "선발 가능 간격이 24시드 실측(29%p)에서 너무 줄었습니다")
    }
}
