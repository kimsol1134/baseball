import XCTest
import SimulationCore
@testable import BaseballIOS
import BaseballIOSDomain

/// 실플레이 지명률 — **실제 투구 커널을 통과한** 3년의 결과.
///
/// 왜 필요한가: 코어의 `[draft-balance]` 진단은 통조림 게임라인을 엔진에 직접 먹인다
/// (그 테스트도 "실플레이 밴드가 아니다"라고 스스로 적어 둔다). 그래서 **상대 타자 능력**과
/// **릴리스 판정**을 바꿔도 그 숫자는 꿈쩍하지 않는다 — 두 값 모두 `PitchScenario`와
/// `PitchKernelEngine`에 있고, 앱 계층에서만 만나기 때문이다.
///
/// 난이도를 만졌을 때 정작 알고 싶은 것은 "그래서 사람이 3년을 살면 지명을 받는가"다.
/// 이 하네스가 그 질문에 답한다: 시나리오를 실제로 만들고, `PitchSession`으로 타석을
/// 끝까지 굴리고, 그 리포트를 엔진에 돌려준다. UI만 없을 뿐 플레이와 같은 경로다.
///
/// **중립 릴리스로 던진다.** 즉 여기서 나오는 숫자는 타이밍·조준을 전혀 못 맞히는
/// 사람의 하한선이다. 실제 사람은 이보다 잘한다.
@MainActor
final class RealPlayDraftRateTests: XCTestCase {
    private struct RunOutcome {
        let drafted: Bool
        let evaluation: Int
        let threshold: Int
        /// 성적 항 계수를 훑기 위한 원재료(K·BB·R).
        let strikeouts: Int
        let walks: Int
        let runsAllowed: Int
        /// 성적 항을 다시 만들기 위한 원재료. 코어를 다시 빌드하지 않고 계수·문턱을
        /// 훑기 위해서다(§2.5 Step B).
        let gameQuality: Int
        let directOuts: Int
        /// 마운드에서 온 항들. 코어와 같은 산식을 공개 데이터로 다시 계산한다 —
        /// **실력이 어느 항에 나타나는지**를 보기 위해서다(§2.5 Step B).
        let processBonus: Int
        let seasonTerm: Int
        let ratingScore: Int
        /// 드래프트 평가의 경기 성적 항. 코어와 같은 산식을 공개 데이터로 다시 계산한다 —
        /// **클램프에 걸려 있는지**를 보기 위해서다(§2.5 Step 3).
        let rawPerformance: Int
        let clampedPerformance: Int
        /// 이 회차에서 **직접 던진** 경기들의 합. 지명 여부 하나로는 어느 축이 움직였는지
        /// 알 수 없다 — 손잡이를 고르려면 이 표가 있어야 한다(§2.5 Step 1).
        let pitching: PitchingTotals
    }

    /// 직접 던진 등판의 누적. 9이닝 환산은 `per9`가 한다.
    struct PitchingTotals {
        var games = 0
        var outs = 0
        var pitches = 0
        var strikeouts = 0
        var walks = 0
        var hits = 0
        var runsAllowed = 0

        mutating func add(_ report: ImportantInningReport) {
            games += 1
            outs += report.outs ?? 0
            pitches += report.pitches
            strikeouts += report.strikeouts
            walks += report.walks
            hits += report.hits ?? 0
            runsAllowed += report.runsAllowed
        }

        static func + (lhs: PitchingTotals, rhs: PitchingTotals) -> PitchingTotals {
            PitchingTotals(
                games: lhs.games + rhs.games, outs: lhs.outs + rhs.outs,
                pitches: lhs.pitches + rhs.pitches, strikeouts: lhs.strikeouts + rhs.strikeouts,
                walks: lhs.walks + rhs.walks, hits: lhs.hits + rhs.hits,
                runsAllowed: lhs.runsAllowed + rhs.runsAllowed
            )
        }

        /// 9이닝당. 아웃이 0이면 0을 돌려준다 — 나눌 수 없는 것을 무한대로 만들지 않는다.
        func per9(_ value: Int) -> Double {
            outs > 0 ? Double(value) * 27 / Double(outs) : 0
        }

        var whip: Double {
            outs > 0 ? Double(walks + hits) * 3 / Double(outs) : 0
        }

        var line: String {
            String(
                format: "경기 %d · %.1f이닝 · K/9 %.2f · BB/9 %.2f · H/9 %.2f · R/9 %.2f · WHIP %.2f · 구/경기 %.0f",
                games, Double(outs) / 3, per9(strikeouts), per9(walks), per9(hits),
                per9(runsAllowed), whip, games > 0 ? Double(pitches) / Double(games) : 0
            )
        }
    }

    /// 어떻게 3년을 사는가. 대화는 언제나 듣고, 각성은 첫 번째를 찍는다 — 두 정책의
    /// 차이는 훈련 초점 하나다.
    enum PlayPolicy {
        /// 평범한 사람 — 오늘의 기회를 따라가고, 지치면 쉰다.
        case sensible
        /// UI 스모크와 같은 자동 진행 — 보이는 버튼을 순서대로 누르므로 훈련 초점이
        /// 제구에 고정되고 회복을 한 번도 고르지 않는다. 가장 낮은 바닥이다.
        case smokeAutopilot
    }

    /// 한 회차를 끝까지 자동으로 산다.
    private func playOneCareer(
        seed: String,
        presetID: String = "power_prospect",
        policy: PlayPolicy = .sensible,
        harshness: DifficultyLevel = .standard,
        /// 라이브 확률식을 강제한다. nil이면 커리어 버전이 고른 값(오늘은 `.legacy`).
        /// 두 곡선을 **같은 하네스로** 재기 위한 것이지 운영 경로를 바꾸지 않는다(§2.5).
        forcedBalance: PitchBalanceRules? = nil,
        /// 이 사람의 손. 중립(500/500)이 실력 0의 바닥이다(§2.5 Step 4).
        delivery: PitchDelivery = .neutral,
        /// 한 경기에서 상대할 타자 수를 강제한다. **직접 던지는 표본을 키우면 손맛이
        /// 평가에 반영되는가**를 재기 위한 대리 측정이다(§2.5 Step B).
        battersOverride: Int? = nil
    ) throws -> RunOutcome? {
        var pitching = PitchingTotals()
        let engine = HighSchoolCareerEngine()
        // 화면이 만드는 것과 **같은 선수**로 시작한다. `HighSchoolCareerStore.startCareer`는
        // 이름을 프리셋의 투수 이름으로, 던지는 손을 프리셋의 손으로 채운다. 코어 기본값
        // (`.defaultPitcher`, 우완 '민서준')을 그냥 쓰면 좌우 플래툰이 달라져 같은 시드가
        // 다른 3년이 된다 — 여기서 지명된 시드를 UI 회귀 테스트에 그대로 못 쓴다는 뜻이다.
        let preset = try XCTUnwrap(PitcherPresetCatalog.all.first { $0.id == presetID })
        let identity = PlayerIdentitySnapshot(
            name: preset.pitcher.name,
            throwingHand: preset.pitcher.throwingHand,
            bodyType: .balanced,
            region: "서울"
        )
        var result = try engine.start(.init(
            seed: seed, presetID: presetID, identity: identity,
            difficulty: CareerDifficultySnapshot(careerHarshness: harshness)
        ))
        result = try engine.completePrologue(.init(seed: result.nextSeed, state: result.snapshot))
        let school = try XCTUnwrap(result.snapshot.schoolOptions.first)
        result = try engine.chooseSchool(.init(seed: result.nextSeed, state: result.snapshot, schoolID: school.id))

        for _ in 0..<400 {
            let state = result.snapshot
            switch state.phase {
            case .training:
                // 피로가 쌓이면 쉰다 — 안 그러면 성장이 0으로 지나가는 훈련만 반복한다.
                let focus: TrainingFocus
                switch policy {
                case .sensible:
                    focus = state.fatigue >= 70 ? .recovery : (state.trainingOpportunity?.focus ?? .command)
                case .smokeAutopilot:
                    // 화면 기본값은 직전 훈련의 초점이고, 첫 훈련의 기본값은 제구다.
                    focus = state.lastTraining?.focus ?? .command
                }
                result = try engine.commitTraining(
                    .init(seed: result.nextSeed, state: state, focus: focus, intensity: .standard)
                )
            case .relationship:
                result = try engine.resolveRelationship(
                    .init(seed: result.nextSeed, state: state, response: .listen)
                )
            case .importantGame:
                var scenario = PitchScenario.highSchool(
                    state: state, maximumBattersOverride: battersOverride
                )
                if let forcedBalance { scenario.livePitchBalance = forcedBalance }
                let session = PitchSession(scenario: scenario, seed: result.nextSeed)
                session.start()
                // 화면에서 한 구씩 누를 때와 같은 경로. 중립 릴리스라 손 실력은 0이다.
                for _ in 0..<max(12, (battersOverride ?? 0) * 3) {
                    if case .ready = session.stage {
                        session.fastForwardCurrentBatter(delivery: delivery)
                    }
                    if case .betweenBatters = session.stage {
                        session.advanceToNextBatter()
                        continue
                    }
                    break
                }
                let number = state.performance.importantGamesCompleted + 1
                let report = session.report(scenarioNumber: number)
                pitching.add(report)
                result = try engine.recordImportantGame(
                    .init(seed: result.nextSeed, state: state, report: report)
                )
            case .awakening:
                let option = try XCTUnwrap(state.awakeningOptions.first)
                result = try engine.chooseAwakening(
                    .init(seed: result.nextSeed, state: state, awakening: option)
                )
            case .chapterReview:
                result = try engine.advanceChapter(.init(seed: result.nextSeed, state: state))
            case .draft:
                result = try engine.resolveDraft(.init(seed: result.nextSeed, state: state))
                let draft = try XCTUnwrap(result.snapshot.draftResult)
                let forecast = HighSchoolCareerEngine.draftForecast(state: state)
                // 코어의 v5+ 산식과 같은 계산(HighSchoolCareer.draftEvaluationCore):
                // gameQuality = K*4 − BB*2 − R*2, 이닝당으로 나눈 뒤 ±6으로 자른다.
                let performance = state.performance
                let quality = performance.strikeouts * 4 - performance.walks * 2
                    - performance.runsAllowed * 2
                let outs = performance.outs ?? 0
                let raw = outs == 0 ? 0 : quality * 3 / max(9, outs)
                // processBonus: 기대 피해보다 얼마나 덜 맞았는가 — 이것도 실력 신호다.
                let process = max(-8, min(10,
                    (performance.expectedDamage - performance.actualDamage) / 350))
                // seasonTerm: 공식 기록(직접 + 자동) 전체의 실점률. school 영점 6000·기울기 700.
                let autoLines = (state.seasonLog ?? []).filter { !$0.played }
                let officialOuts = outs + autoLines.reduce(0) { $0 + $1.outs }
                let officialRuns = performance.runsAllowed + autoLines.reduce(0) { $0 + $1.runsAllowed }
                let season = officialOuts == 0 ? 0 : min(8, max(-8,
                    (6_000 - officialRuns * 27_000 / officialOuts) / 700)) * min(90, officialOuts) / 90
                let ratings = state.pitcher.stuff + state.pitcher.command
                    + state.pitcher.movement + state.pitcher.stamina
                return RunOutcome(
                    drafted: draft.outcome == .drafted,
                    evaluation: draft.evaluationScore,
                    threshold: forecast.threshold,
                    strikeouts: performance.strikeouts,
                    walks: performance.walks,
                    runsAllowed: performance.runsAllowed,
                    gameQuality: quality,
                    directOuts: max(9, outs),
                    processBonus: process,
                    seasonTerm: season,
                    ratingScore: ratings / 4 + 15,
                    rawPerformance: raw,
                    clampedPerformance: min(6, max(-6, raw)),
                    pitching: pitching
                )
            case .legacy, .completed:
                return nil
            case .prologue, .schoolSelection:
                XCTFail("학교는 이미 골랐습니다")
                return nil
            }
        }
        XCTFail("시드 \(seed): 3년이 끝나지 않았습니다")
        return nil
    }

    /// 실력 0(중립 릴리스)으로 자동 진행한 회차의 지명률.
    ///
    /// 밴드의 뜻: **하한이 0이면 안 된다** — 손을 아예 못 맞히는 사람도 가끔은 지명을 받아야
    /// 3년이 헛수고가 아니고, **상한이 너무 높아도 안 된다** — 아무것도 안 해도 다 지명되면
    /// 드래프트가 관문이 아니다. 실제 사람은 릴리스를 맞히므로 여기보다 잘한다.
    func testNeutralDeliveryRunsLandInsideTheDraftBand() throws {
        var drafted = 0
        var draftedSeeds: [String] = []
        var evaluations: [Int] = []
        var thresholds: [Int] = []
        let seeds = (1...60).map(String.init)
        for seed in seeds {
            guard let outcome = try playOneCareer(seed: seed, policy: .sensible) else { continue }
            if outcome.drafted {
                drafted += 1
                draftedSeeds.append(seed)
            }
            evaluations.append(outcome.evaluation)
            thresholds.append(outcome.threshold)
        }
        let rate = Double(drafted) / Double(max(1, evaluations.count))
        let sorted = evaluations.sorted()
        // 지명된 시드를 남긴다. UI 스모크의 "프로 진입 회귀용 고정 시드"는 밸런스를
        // 만질 때마다 재보정해야 하는데, 그 후보를 190초짜리 UI 실행으로 찾을 이유가 없다.
        print("[real-play-draft] neutral-delivery rate=\(Int((rate * 100).rounded()))% "
            + "(\(drafted)/\(evaluations.count)) "
            + "eval min=\(sorted.first ?? 0) median=\(sorted[sorted.count / 2]) max=\(sorted.last ?? 0) "
            + "threshold=\(thresholds.first ?? 0) drafted-seeds=\(draftedSeeds.joined(separator: ","))")

        XCTAssertGreaterThan(
            rate, 0.0,
            "실력 없이 자동 진행한 회차가 한 번도 지명되지 않습니다 — 3년이 통째로 헛수고가 됩니다"
        )
        XCTAssertLessThan(
            rate, 0.85,
            "손을 전혀 안 맞혀도 대부분 지명됩니다 — 드래프트가 관문 구실을 못 합니다"
        )
    }

    /// **직접 던지는 공이 어느 곡선을 쓰느냐가 무엇을 바꾸는가**(§2.5 Step 1).
    ///
    /// 지명률 하나로는 손잡이를 고를 수 없다. 같은 하네스로 두 곡선을 돌려 K/9·BB/9·H/9·
    /// R/9를 나란히 찍는다. 여기 나온 표가 Step 2(난이도 이중 계상 확인)의 입력이다.
    ///
    /// 이 검사는 밴드를 주장하지 않는다 — **재는 것이 일이다.** 밴드는 연결을 결정할 때
    /// 측정값 위에서 정한다.
    func testLiveCurveDiagnosticsForBothArenas() throws {
        let seeds = (1...30).map(String.init)
        for (name, balance) in [
            ("legacy (배포 중)", PitchBalanceRules.legacy),
            ("school (고교 7 규칙)", PitchBalanceRules.school),
        ] {
            var totals = PitchingTotals()
            var drafted = 0
            var evaluations: [Int] = []
            for seed in seeds {
                guard let outcome = try playOneCareer(
                    seed: seed, policy: .sensible, forcedBalance: balance
                ) else { continue }
                totals = totals + outcome.pitching
                evaluations.append(outcome.evaluation)
                if outcome.drafted { drafted += 1 }
            }
            let sorted = evaluations.sorted()
            print("[live-curve] \(name)")
            print("[live-curve]   \(totals.line)")
            print("[live-curve]   지명 \(drafted)/\(evaluations.count) · "
                + "평가 \(sorted.first ?? 0)/\(sorted[max(0, sorted.count / 2)])/\(sorted.last ?? 0)")
            XCTAssertGreaterThan(totals.games, 0, "\(name): 직접 던진 경기가 없습니다")
            XCTAssertGreaterThan(totals.outs, 0, "\(name): 아웃이 하나도 기록되지 않았습니다")
        }
    }

    /// **고교 8이 실제로 예측대로 나오는가**(§2.8 확인).
    ///
    /// 스윕은 기록해 둔 원재료로 평가를 재조립한 예측이다. 진짜 코드가 같은 값을 내는지
    /// 확인하지 않으면 그 표는 종이 위의 숫자다. 버전만 v8로 두고 그대로 3년을 산다.
    func testSchoolEightLandsWhereTheSweepSaidItWould() throws {
        let seeds = (1...40).map(String.init)
        var rates: [String: Int] = [:]
        for (handName, accuracy) in [("중립", 500), ("완벽", 950)] {
            var drafted = 0, total = 0
            var thresholds: Set<Int> = []
            for seed in seeds {
                guard let outcome = try playOneCareer(
                    seed: seed, policy: .sensible,
                    delivery: PitchDelivery(releaseAccuracy: accuracy, aimAccuracy: accuracy)
                ) else { continue }
                total += 1
                thresholds.insert(outcome.threshold)
                if outcome.drafted { drafted += 1 }
            }
            let rate = drafted * 100 / max(1, total)
            rates[handName] = rate
            print("[v8] \(handName) — 지명 \(drafted)/\(total) = \(rate)% · 문턱 \(thresholds.sorted())")
        }
        let low = try XCTUnwrap(rates["중립"])
        let high = try XCTUnwrap(rates["완벽"])
        print("[v8] 간격 \(high - low)%p")

        // 밴드는 예측(47%/60%) 주변으로 넉넉히 잡는다. 정확한 숫자를 고정하면 시드 하나에
        // 깨지는 검사가 되고, 너무 넓으면 회귀를 못 잡는다.
        XCTAssertTrue(
            (30...65).contains(low),
            "중립 릴리스 지명률 \(low)% — 손을 못 맞히는 사람의 하한이 무너졌거나 너무 후하다"
        )
        XCTAssertGreaterThanOrEqual(
            high, low,
            "잘 던진 쪽이 더 낮게 지명됐다 — 손맛이 벌이 되고 있다"
        )
    }

    /// **스카우트가 투수의 무엇을 보는가**(§2.5 Step B).
    ///
    /// 계수를 키우는 것도(운만 커진다), 표본을 키우는 것도(비율이라 안 커진다) 답이 아니었다.
    /// 남은 것은 **무엇을 채점하느냐**다.
    ///
    /// 지금 식은 `K*4 − BB*2 − R*2`인데 school에서 R/9는 20, BB/9는 5다. 실력이 볼넷을 41%
    /// 줄여도 실점은 14%밖에 못 줄인다 — 실점은 수비와 운이 절반을 쥐고 있기 때문이다.
    /// 가중치가 같으니 **투수가 통제하는 것이 통제 못 하는 것에 묻힌다.**
    ///
    /// 야구에는 이미 답이 있다: FIP, 수비와 무관한 투구. 투수는 자기가 통제하는 것으로
    /// 평가한다. 그 방향으로 계수를 옮기면 손맛이 평가에 들리는지 잰다.
    func testWhatTheScoutShouldBeWatching() throws {
        let seeds = (1...40).map(String.init)
        var byHand: [String: [RunOutcome]] = [:]
        for (handName, accuracy) in [("중립", 500), ("완벽", 950)] {
            var outcomes: [RunOutcome] = []
            for seed in seeds {
                guard let outcome = try playOneCareer(
                    seed: seed, policy: .sensible, forcedBalance: .school,
                    delivery: PitchDelivery(releaseAccuracy: accuracy, aimAccuracy: accuracy)
                ) else { continue }
                outcomes.append(outcome)
            }
            byHand[handName] = outcomes
        }
        let neutral = try XCTUnwrap(byHand["중립"])
        let perfect = try XCTUnwrap(byHand["완벽"])

        func rate(
            _ outcomes: [RunOutcome],
            k: Int, b: Int, r: Int, scale: Int, clamp: Int, threshold: Int
        ) -> Int {
            let drafted = outcomes.count { outcome in
                let old = min(6, max(-6, outcome.gameQuality * 3 / outcome.directOuts))
                let quality = outcome.strikeouts * k - outcome.walks * b - outcome.runsAllowed * r
                let new = min(clamp, max(-clamp, quality * scale / outcome.directOuts))
                return outcome.evaluation - old + new >= threshold
            }
            return outcomes.isEmpty ? 0 : drafted * 100 / outcomes.count
        }

        print("[fip] school 곡선 · 40시드 · K/BB/R 가중치 × 감도 × 문턱")
        let weightings: [(String, Int, Int, Int)] = [
            ("현재 4/2/2", 4, 2, 2),
            ("실점 절반 4/2/1", 4, 2, 1),
            ("볼넷 강조 5/4/1", 5, 4, 1),
            ("수비무관 6/5/0", 6, 5, 0),
        ]
        for (name, k, b, r) in weightings {
            for (scale, clamp) in [(3, 6), (6, 12)] {
                var best = (gap: -100, low: 0, high: 0, threshold: 0)
                for threshold in 40...70 {
                    let low = rate(neutral, k: k, b: b, r: r, scale: scale, clamp: clamp, threshold: threshold)
                    let high = rate(perfect, k: k, b: b, r: r, scale: scale, clamp: clamp, threshold: threshold)
                    if (15...30).contains(low), high - low > best.gap {
                        best = (high - low, low, high, threshold)
                    }
                }
                print("[fip]   \(name) · 감도 \(scale)/±\(clamp) → 문턱 \(best.threshold): "
                    + "중립 \(best.low)% / 완벽 \(best.high)% (간격 \(best.gap)%p)"
                    + (best.gap >= 25 && (55...75).contains(best.high) ? "  ★ 목표 충족" : ""))
            }
        }
    }

    /// **표본을 키우면 손맛이 평가에 들리는가**(§2.5 Step B).
    ///
    /// 계수 스윕이 답을 냈다 — 3.5이닝짜리 표본을 크게 채점하면 실력만큼 운도 커져서
    /// 간격이 20%p에서 멈춘다. 그러면 남은 길은 하나, **던질 이닝을 늘리는 것**이다.
    /// 1-G(장별 직접 등판)를 짓기 전에 그 가정이 맞는지 대리 측정으로 먼저 확인한다.
    func testABiggerDirectSampleRestoresTheSkillGap() throws {
        let seeds = (1...40).map(String.init)
        for batters in [nil, 8, 14] as [Int?] {
            var results: [(String, Int, Int, Int)] = []
            for (handName, accuracy) in [("중립", 500), ("완벽", 950)] {
                var drafted = 0, total = 0, outs = 0
                for seed in seeds {
                    guard let outcome = try playOneCareer(
                        seed: seed, policy: .sensible, forcedBalance: .school,
                        delivery: PitchDelivery(releaseAccuracy: accuracy, aimAccuracy: accuracy),
                        battersOverride: batters
                    ) else { continue }
                    total += 1
                    outs += outcome.pitching.outs
                    if outcome.drafted { drafted += 1 }
                }
                results.append((handName, drafted * 100 / max(1, total), outs / max(1, total), total))
            }
            let label = batters.map { "타자 \($0)명" } ?? "현재(4~6명)"
            print("[sample] \(label) — 커리어당 직접 아웃 \(results[0].2)개 · "
                + "중립 \(results[0].1)% / 완벽 \(results[1].1)% "
                + "(간격 \(results[1].1 - results[0].1)%p)")
        }
    }

    /// **계수와 문턱을 함께 훑는다**(§2.5 Step A·B).
    ///
    /// 성적 항이 실력을 나르는 유일한 항이라는 것을 알았으니, 그 항의 감도(계수·클램프)와
    /// 당락 문턱을 같이 움직여 본다. 커리어를 다시 돌리지 않고 **기록해 둔 원재료로** 평가를
    /// 다시 만들어 훑으므로, 한 번의 실행으로 조합 전체를 본다.
    ///
    /// 목표는 지명률 복구가 아니라 **간격**이다 — 중립 15~30%, 거의 완벽 55~75%,
    /// 그 차이 최소 25%p. 손맛이 핵심 재미라는 말의 조작적 정의다.
    func testSweepPerformanceWeightAndThreshold() throws {
        let seeds = (1...40).map(String.init)
        var byHand: [String: [RunOutcome]] = [:]
        for (handName, accuracy) in [("중립", 500), ("완벽", 950)] {
            var outcomes: [RunOutcome] = []
            for seed in seeds {
                guard let outcome = try playOneCareer(
                    seed: seed, policy: .sensible, forcedBalance: .school,
                    delivery: PitchDelivery(releaseAccuracy: accuracy, aimAccuracy: accuracy)
                ) else { continue }
                outcomes.append(outcome)
            }
            byHand[handName] = outcomes
        }

        func rate(_ outcomes: [RunOutcome], scale: Int, clamp: Int, threshold: Int) -> Int {
            let drafted = outcomes.count { outcome in
                // 오늘의 성적 항을 빼고 새 계수로 다시 넣는다.
                let old = min(6, max(-6, outcome.gameQuality * 3 / outcome.directOuts))
                let new = min(clamp, max(-clamp, outcome.gameQuality * scale / outcome.directOuts))
                return outcome.evaluation - old + new >= threshold
            }
            return outcomes.isEmpty ? 0 : drafted * 100 / outcomes.count
        }

        let neutral = try XCTUnwrap(byHand["중립"])
        let perfect = try XCTUnwrap(byHand["완벽"])
        print("[sweep] school 곡선 · 40시드 · 계수/클램프 × 문턱 → 중립% / 완벽% (간격)")
        for (scale, clamp) in [(3, 6), (6, 12), (9, 18), (12, 24), (15, 30)] {
            for threshold in [46, 49, 52, 55, 58, 61] {
                let low = rate(neutral, scale: scale, clamp: clamp, threshold: threshold)
                let high = rate(perfect, scale: scale, clamp: clamp, threshold: threshold)
                let marker = (15...30).contains(low) && (55...75).contains(high) && high - low >= 25
                    ? "  ★ 목표 충족" : ""
                print("[sweep]   계수 \(scale)/클램프 ±\(clamp) · 문턱 \(threshold) → "
                    + "\(low)% / \(high)% (간격 \(high - low)%p)\(marker)")
            }
        }
    }

    /// **실력은 어느 항에 나타나는가.**
    ///
    /// 평가는 여러 항의 합이고 마운드에서 오는 것은 셋이다 — 경기 성적(±6), 기대 대비
    /// 피해(−8~+10), 공식 기록 실점률(±8). 어느 항이 실력에 반응하는지 모르면 무게를
    /// 어디에 줘야 할지도 모른다. 추론하지 않고 항별로 쟀다.
    func testWhichEvaluationTermCarriesSkill() throws {
        let seeds = (1...16).map(String.init)
        for (curveName, balance) in [
            ("legacy", PitchBalanceRules.legacy),
            ("school", PitchBalanceRules.school),
        ] {
            var rows: [(String, [Int], [Int], [Int], [Int])] = []
            for (handName, accuracy) in [("중립", 500), ("완벽", 950)] {
                var perf: [Int] = [], process: [Int] = [], season: [Int] = [], rating: [Int] = []
                for seed in seeds {
                    guard let outcome = try playOneCareer(
                        seed: seed, policy: .sensible, forcedBalance: balance,
                        delivery: PitchDelivery(releaseAccuracy: accuracy, aimAccuracy: accuracy)
                    ) else { continue }
                    perf.append(outcome.clampedPerformance)
                    process.append(outcome.processBonus)
                    season.append(outcome.seasonTerm)
                    rating.append(outcome.ratingScore)
                }
                rows.append((handName, perf, process, season, rating))
            }
            func median(_ values: [Int]) -> Int { values.sorted()[values.count / 2] }
            for row in rows {
                print(String(
                    format: "[term] %@ · %@ — 성적 %d · 기대대비 %d · 시즌 %d · 능력 %d",
                    curveName, row.0, median(row.1), median(row.2), median(row.3), median(row.4)
                ))
            }
            let neutral = rows[0], perfect = rows[1]
            print(String(
                format: "[term] %@ · 실력이 바꾼 폭 — 성적 %+d · 기대대비 %+d · 시즌 %+d",
                curveName,
                median(perfect.1) - median(neutral.1),
                median(perfect.2) - median(neutral.2),
                median(perfect.3) - median(neutral.3)
            ))
        }
    }

    /// **평가가 실력을 듣고 있는가**(§2.5 Step 3).
    ///
    /// 사다리에서 school 곡선의 평가 중앙값이 실력과 무관하게 55~56으로 고정됐다. 원인을
    /// 추론하지 않고 잰다 — 경기 성적 항이 ±6 클램프의 **바닥에 붙어 있으면** 실력이 아무리
    /// 늘어도 점수가 움직일 수 없다.
    func testWhetherTheDraftEvaluationStillHearsSkill() throws {
        let seeds = (1...16).map(String.init)
        for (curveName, balance) in [
            ("legacy", PitchBalanceRules.legacy),
            ("school", PitchBalanceRules.school),
        ] {
            for (handName, accuracy) in [("중립 500", 500), ("거의 완벽 950", 950)] {
                var raws: [Int] = []
                var clamped: [Int] = []
                for seed in seeds {
                    guard let outcome = try playOneCareer(
                        seed: seed, policy: .sensible, forcedBalance: balance,
                        delivery: PitchDelivery(releaseAccuracy: accuracy, aimAccuracy: accuracy)
                    ) else { continue }
                    raws.append(outcome.rawPerformance)
                    clamped.append(outcome.clampedPerformance)
                }
                let saturated = clamped.count { $0 <= -6 || $0 >= 6 }
                print(String(
                    format: "[eval] %@ · %@ — 원값 중앙 %d (범위 %d~%d) · 자른 값 중앙 %d · 클램프에 붙은 회차 %d/%d",
                    curveName, handName,
                    raws.sorted()[raws.count / 2], raws.min() ?? 0, raws.max() ?? 0,
                    clamped.sorted()[clamped.count / 2], saturated, clamped.count
                ))
            }
        }
    }

    /// **실력이 보상받는 폭**(§2.5 Step 4).
    ///
    /// 지금까지의 모든 측정은 중립 릴리스 — 타이밍도 조준도 하나도 못 맞히는 사람이다.
    /// 그 한 점만 보고 난이도를 정하면 **못 하는 사람 기준으로 게임을 맞추게 된다.**
    /// 손이 좋아질수록 결과가 좋아지는지, 얼마나 좋아지는지를 사다리로 잰다.
    ///
    /// 이 간격이 곧 투구 슬라이더의 존재 이유다(AGENTS.md 투구 조작 불변 규칙).
    func testSkillLadderOnBothCurves() throws {
        let seeds = (1...24).map(String.init)
        for (curveName, balance) in [
            ("legacy", PitchBalanceRules.legacy),
            ("school", PitchBalanceRules.school),
        ] {
            for (handName, accuracy) in [
                ("중립 500", 500), ("보통 700", 700), ("능숙 850", 850), ("거의 완벽 950", 950),
            ] {
                var totals = PitchingTotals()
                var drafted = 0
                var evaluations: [Int] = []
                for seed in seeds {
                    guard let outcome = try playOneCareer(
                        seed: seed, policy: .sensible, forcedBalance: balance,
                        delivery: PitchDelivery(releaseAccuracy: accuracy, aimAccuracy: accuracy)
                    ) else { continue }
                    totals = totals + outcome.pitching
                    evaluations.append(outcome.evaluation)
                    if outcome.drafted { drafted += 1 }
                }
                let sorted = evaluations.sorted()
                print(String(
                    format: "[skill] %@ · %@ — 지명 %d/%d · 평가 중앙 %d · K/9 %.2f · BB/9 %.2f · R/9 %.2f · WHIP %.2f",
                    curveName, handName, drafted, evaluations.count,
                    sorted.isEmpty ? 0 : sorted[sorted.count / 2],
                    totals.per9(totals.strikeouts), totals.per9(totals.walks),
                    totals.per9(totals.runsAllowed), totals.whip
                ))
            }
        }
    }

    /// UI 스모크와 같은 자동 진행에서 지명되는 시드를 찾아 준다.
    ///
    /// `CareerSmokeUITests.testDraftedRunCanEnterProCareer`는 "지명되는 고정 시드" 하나에
    /// 기대는데, 밸런스를 만지면 그 시드가 미지명으로 넘어간다. 후보를 190초짜리 UI 실행으로
    /// 하나씩 찍어 보는 대신 여기서 같은 정책으로 훑는다.
    func testSmokeAutopilotHasDraftableSeeds() throws {
        // UI 스모크는 **완화 난이도**로 돈다(검증 대상이 지명 확률이 아니라 전환 흐름이라서).
        // 후보도 같은 조건에서 뽑아야 쓸모가 있다.
        var draftedSeeds: [String] = []
        for seed in (1...60).map(String.init) {
            guard let outcome = try playOneCareer(
                seed: seed, policy: .smokeAutopilot, harshness: .relaxed
            ) else { continue }
            if outcome.drafted { draftedSeeds.append(seed) }
        }
        print("[real-play-draft] smoke-autopilot(relaxed) drafted-seeds=\(draftedSeeds.joined(separator: ","))")
        XCTAssertFalse(
            draftedSeeds.isEmpty,
            "가장 낮은 자동 진행 정책으로 지명되는 시드가 하나도 없습니다 — UI 회귀 테스트가 설 자리가 없고, 난이도가 관문이 아니라 벽입니다"
        )
    }
}
