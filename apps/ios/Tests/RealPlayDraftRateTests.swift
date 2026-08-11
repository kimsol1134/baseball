import XCTest
import SimulationCore
@testable import BaseballIOS

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
        harshness: DifficultyLevel = .standard
    ) throws -> RunOutcome? {
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
                let session = PitchSession(
                    scenario: .highSchool(state: state), seed: result.nextSeed
                )
                session.start()
                // 화면에서 한 구씩 누를 때와 같은 경로. 중립 릴리스라 손 실력은 0이다.
                for _ in 0..<12 {
                    if case .ready = session.stage {
                        session.fastForwardCurrentBatter()
                    }
                    if case .betweenBatters = session.stage {
                        session.advanceToNextBatter()
                        continue
                    }
                    break
                }
                let number = state.performance.importantGamesCompleted + 1
                result = try engine.recordImportantGame(
                    .init(seed: result.nextSeed, state: state, report: session.report(scenarioNumber: number))
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
                return RunOutcome(
                    drafted: draft.outcome == .drafted,
                    evaluation: draft.evaluationScore,
                    threshold: forecast.threshold
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
