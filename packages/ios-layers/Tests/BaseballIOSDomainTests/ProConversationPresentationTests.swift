import XCTest
import SimulationCore
@testable import BaseballIOSDomain

/// 대화 미리보기는 **커널에게 물어본 결과**여야 한다. 선언된 `ProDecisionEffect`를 읽는
/// 방식은 clamp·구종 다듬기·3주 약속을 전부 놓친다.
final class ProConversationPresentationTests: XCTestCase {
    private let engine = ProCareerEngine()

    func testRivalAnalysisSpeaksThroughTheCatcherNotAnInventedRival() {
        XCTAssertEqual(ProConversationPresentation.role(for: .rivalAnalysis), .catcher)
        XCTAssertEqual(ProConversationPresentation.role(for: .catcherGamePlan), .catcher)
        XCTAssertNil(ProConversationPresentation.role(for: nil))
    }

    /// 아홉 종류 전부에 화자가 있어야 한다. 빠진 하나는 화면에서 얼굴 없는 카드가 된다.
    func testEveryDecisionTypeHasASpeaker() {
        for type in ProSeasonDecisionType.allCases {
            XCTAssertNotNil(ProConversationPresentation.role(for: type), type.rawValue)
        }
        let coached: Set<ProSeasonDecisionType> = [
            .rotationPush, .newPitchTrial, .farmReset, .extraBullpen,
            .roleMeeting, .recordChase, .seasonFinale, .formCrisis,
        ]
        for type in coached {
            XCTAssertEqual(ProConversationPresentation.role(for: type), .coach, type.rawValue)
        }
        for type in [ProSeasonDecisionType.mediaOpportunity, .agingCrossroads, .veteranMentor] {
            XCTAssertEqual(ProConversationPresentation.role(for: type), .staff, type.rawValue)
        }
    }

    func testPreviewMatchesWhatApplyingTheChoiceActuallyDoes() throws {
        let pending = try firstDecision(seed: "8801")
        let decision = try XCTUnwrap(pending.snapshot.pendingDecision)
        for choice in decision.choices {
            let preview = ProConversationPresentation.preview(
                engine: engine,
                state: pending.snapshot,
                seed: pending.nextSeed,
                decisionID: decision.id,
                choiceID: choice.id
            )
            let applied = try engine.applySeasonDecision(.init(
                seed: pending.nextSeed,
                state: pending.snapshot,
                decisionID: decision.id,
                choiceID: choice.id
            ))
            XCTAssertEqual(
                preview,
                ProConversationPresentation.outcome(before: pending.snapshot, after: applied.snapshot),
                choice.id
            )
        }
    }

    /// 미리보기는 상태를 쓰지 않는다 — 스냅숏도 시드도 그대로다.
    func testPreviewWritesNothing() throws {
        let pending = try firstDecision(seed: "8802")
        let decision = try XCTUnwrap(pending.snapshot.pendingDecision)
        let before = pending.snapshot
        for choice in decision.choices {
            _ = ProConversationPresentation.preview(
                engine: engine,
                state: before,
                seed: pending.nextSeed,
                decisionID: decision.id,
                choiceID: choice.id
            )
        }
        XCTAssertEqual(before, pending.snapshot)
        XCTAssertEqual(before.revision, pending.snapshot.revision)
    }

    /// 능력이 천장에 닿아 있으면 선언된 "+1"은 일어나지 않는다. 커널에게 물으면 칩이 사라지고,
    /// 선언값을 읽으면 없는 이득이 보인다.
    func testClampedAbilityGainDoesNotShowAsAGain() throws {
        let pending = try advance(seed: "8803", pitcher: maxedPitcher()) { state, decision in
            decision.choices.contains { Self.cappedGains(state: state, choice: $0).isEmpty == false }
        }
        let decision = try XCTUnwrap(pending.snapshot.pendingDecision)
        var checked = 0
        for choice in decision.choices {
            let capped = Self.cappedGains(state: pending.snapshot, choice: choice)
            guard !capped.isEmpty else { continue }
            let preview = try XCTUnwrap(ProConversationPresentation.preview(
                engine: engine,
                state: pending.snapshot,
                seed: pending.nextSeed,
                decisionID: decision.id,
                choiceID: choice.id
            ))
            for ability in capped {
                checked += 1
                XCTAssertNil(
                    preview.abilities.first(where: { $0.ability == ability }),
                    "천장에 닿은 \(ability.rawValue)는 오르지 않는데 칩이 남았다"
                )
                // 선언값만 읽는 예전 방식이라면 여기서 이득 칩이 나왔다.
                XCTAssertGreaterThan(Self.declaredDelta(choice.effect, ability), 0)
            }
        }
        XCTAssertGreaterThan(checked, 0)
    }

    /// 이미 80인데 "오른다"고 적힌 능력들.
    private static func cappedGains(
        state: ProCareerSnapshot, choice: ProSeasonDecisionChoice
    ) -> [ProConversationOutcome.Ability] {
        ProConversationOutcome.Ability.allCases.filter {
            declaredDelta(choice.effect, $0) > 0 && current(state.pitcher, $0) >= 80
        }
    }

    private static func declaredDelta(
        _ effect: ProDecisionEffect, _ ability: ProConversationOutcome.Ability
    ) -> Int {
        switch ability {
        case .stuff: effect.stuffDelta
        case .command: effect.commandDelta
        case .movement: effect.movementDelta
        case .stamina: effect.staminaDelta
        }
    }

    private static func current(
        _ pitcher: PitcherSnapshot, _ ability: ProConversationOutcome.Ability
    ) -> Int {
        switch ability {
        case .stuff: pitcher.stuff
        case .command: pitcher.command
        case .movement: pitcher.movement
        case .stamina: pitcher.stamina
        }
    }

    /// 주간 2지선다는 3주짜리 약속을 남긴다. 선언된 효과에는 이 비용이 한 글자도 없다.
    func testWeeklyBinaryChoiceSurfacesTheThreeWeekCommitment() throws {
        let pending = try weeklyDecision(seed: "8804")
        let decision = try XCTUnwrap(pending.snapshot.pendingDecision)
        var sawCommitment = false
        for choice in decision.choices {
            guard let preview = ProConversationPresentation.preview(
                engine: engine,
                state: pending.snapshot,
                seed: pending.nextSeed,
                decisionID: decision.id,
                choiceID: choice.id
            ) else { continue }
            guard !preview.commitments.isEmpty else { continue }
            sawCommitment = true
            let expires = try XCTUnwrap(preview.commitmentExpiresWeek)
            XCTAssertGreaterThan(expires, pending.snapshot.week)
            switch decision.type {
            case .rotationPush:
                XCTAssertTrue(preview.commitments.contains(.extraOuting))
                XCTAssertTrue(preview.commitments.contains(.injuryPressure))
            case .farmReset:
                XCTAssertTrue(preview.commitments.contains(.noFirstTeamOutings))
            case .veteranMentor:
                XCTAssertTrue(preview.commitments.contains(.reducedTraining))
            case .newPitchTrial:
                XCTAssertTrue(preview.commitments.contains(.commandReturnsLater))
            default:
                XCTFail("주간 2지선다가 아닌 유형: \(decision.type.rawValue)")
            }
        }
        XCTAssertTrue(sawCommitment, "\(decision.type.rawValue)의 두 선택지 중 하나는 약속을 남긴다")
    }

    /// 신구종 실전은 구종 하나를 실제로 다듬는다. 선언된 효과에는 그 구종이 없다.
    func testNewPitchTrialNamesThePitchItSharpens() throws {
        let pending = try advance(seed: "8805") { _, decision in decision.type == .newPitchTrial }
        let decision = try XCTUnwrap(pending.snapshot.pendingDecision)
        let sharpened = decision.choices.compactMap {
            ProConversationPresentation.preview(
                engine: engine,
                state: pending.snapshot,
                seed: pending.nextSeed,
                decisionID: decision.id,
                choiceID: $0.id
            )?.sharpenedPitch
        }
        XCTAssertFalse(sharpened.isEmpty, "다듬는 구종이 이름으로 나와야 한다")
    }

    // MARK: - 준비

    private func firstDecision(seed: String, pitcher: PitcherSnapshot? = nil) throws -> ProCareerResult {
        try advance(seed: seed, pitcher: pitcher) { _, _ in true }
    }

    private func weeklyDecision(seed: String) throws -> ProCareerResult {
        try advance(seed: seed) { _, decision in decision.type.isWeeklyBinaryDecision }
    }

    /// `matching`을 만족하는 첫 시즌 결정까지 커리어를 굴린다. 만족하지 않는 결정은
    /// 첫 선택지로 지나간다.
    private func advance(
        seed: String,
        pitcher: PitcherSnapshot? = nil,
        matching: (ProCareerSnapshot, ProSeasonDecision) -> Bool
    ) throws -> ProCareerResult {
        var result = try engine.start(.init(
            seed: seed,
            identity: .defaultPitcher,
            pitcher: pitcher ?? Self.pitcher,
            draftResult: Self.drafted,
            entitlement: Self.entitlement,
            sourceFanInterest: nil,
            // 구종 프로필이 있어야 "신구종 실전"이 후보에 오른다. 프로필 없는 투수로는
            // 이 대화가 영영 나오지 않아, 검사가 조용히 건너뛰어진다.
            startingRepertoire: .init(
                readyBreakingPitches: [.slider, .changeup],
                primaryPitch: .fourSeam,
                learningPitch: .curveball
            ),
            repertoireRulesVersion: nil,
            pitchLearningProject: nil
        ))
        result = try engine.signContract(.init(seed: result.nextSeed, state: result.snapshot))
        for _ in 0..<600 {
            switch result.snapshot.phase {
            case .seasonDecision:
                guard let pending = result.snapshot.pendingDecision else {
                    result = try engine.recoverMissingSeasonDecision(
                        .init(seed: result.nextSeed, state: result.snapshot)
                    )
                    continue
                }
                if matching(result.snapshot, pending) { return result }
                result = try engine.applySeasonDecision(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    decisionID: pending.id,
                    choiceID: pending.choices[0].id
                ))
            case .weeklyPlan:
                result = try engine.planWeek(.init(seed: result.nextSeed, state: result.snapshot, plan: .recover))
            case .importantGame:
                result = try engine.resolveImportantGame(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    report: Self.report(result.snapshot.week)
                ))
            case .seasonReview:
                result = try engine.reviewSeason(.init(seed: result.nextSeed, state: result.snapshot))
            case .offseasonDecision:
                result = try engine.chooseOffseason(.init(
                    seed: result.nextSeed,
                    state: result.snapshot,
                    decision: .continueCareer
                ))
            default:
                throw SimulationError.invalidProCareer("찾는 시즌 결정에 도달하지 못했습니다: \(result.snapshot.phase)")
            }
        }
        throw SimulationError.invalidProCareer("시즌 결정 탐색 한도를 넘었습니다.")
    }

    /// 시작 레퍼토리는 완전한 구종 프로필 표를 요구한다. 프리셋 투수가 그 표를 갖고 있다.
    private static let pitcher = PitcherPresetCatalog.all[0].pitcher

    private func maxedPitcher() -> PitcherSnapshot {
        Self.rated(Self.pitcher, stuff: 80, command: 80, movement: 80, stamina: 80)
    }

    private static func rated(
        _ pitcher: PitcherSnapshot, stuff: Int, command: Int, movement: Int, stamina: Int
    ) -> PitcherSnapshot {
        .init(
            id: pitcher.id,
            name: pitcher.name,
            stuff: stuff,
            command: command,
            movement: movement,
            stamina: stamina,
            pitchProfiles: pitcher.pitchProfiles,
            throwingHand: pitcher.throwingHand,
            mastery: pitcher.mastery
        )
    }

    private static let entitlement = ProEntitlementSnapshot(
        status: .active, source: .development, verifiedAt: "2026-07-22", offlineValidUntil: "2026-08-22"
    )

    private static let drafted = DraftResultSnapshot(
        outcome: .drafted,
        evaluationScore: 72,
        projectedRange: "2~3라운드",
        team: ProCareerEngine.proTeams[0],
        round: 2,
        overallPick: 18,
        signingBonus: 120_000_000,
        firstSeasonGoal: "2군 선발",
        summary: "지명"
    )

    private static func report(_ number: Int) -> ImportantInningReport {
        .init(
            scenarioNumber: number, pitches: 18, strikeouts: 2, walks: 0, runsAllowed: 0,
            expectedDamage: 380, actualDamage: 240, recommendationAccepted: 12
        )
    }
}
