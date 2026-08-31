import Foundation
import Observation
import SimulationCore
import BaseballIOSDomain
import BaseballIOSPersistence

extension MobileCareerStore {
    func advanceWeek() {
        guard let result, let selectedPlan else { return }
        let beforeRevision = result.snapshot.revision
        perform { try engine.planWeek(.init(
            seed: result.nextSeed,
            state: result.snapshot,
            plan: selectedPlan,
            targetPitch: developmentTarget
        )) }
        if self.result?.snapshot.revision != beforeRevision {
            weekly.record(.proWeeksAdvanced)
            logPitchLearningProgress(before: result.snapshot, after: self.result?.snapshot)
            // 회복은 한 주짜리 명령이다. 성공한 저장 이후에만 선택을 비워 다음 주의
            // 무음 미등판을 막는다. 저장 실패면 기존 선택도 그대로 남아 재시도할 수 있다.
            if selectedPlan == .recover { self.selectedPlan = nil }
        }
    }

    /// 다음 구간 어귀까지 자동으로 진행한다.
    ///
    /// 24주를 한 주씩 넘기는 것이 프로 후반의 실제 경험이었다. 같은 카드 다섯 장에서 하나를
    /// 고르는 일이 시즌마다 24번, 20시즌이면 480번이다. 구간(스프링캠프·개막·전반기·올스타
    /// 브레이크·페넌트레이스·시즌 막바지)은 이미 코어가 알고 있으니, **결정이 필요한 자리에서만
    /// 멈추게** 한다 — 구간이 바뀌거나, 중요 경기가 잡히거나, 역할·소속이 움직이거나, 다치거나.
    func advanceSegment() {
        guard let result, let selectedPlan,
              selectedPlan != .recover || ProCareerEngine.usesAgencyRules(result.snapshot) else { return }
        let beforeRevision = result.snapshot.revision
        var advancedWeeks = 0
        perform {
            var current = result
            let startSegment = current.snapshot.seasonSegment
            for _ in 0..<24 where current.snapshot.phase == .weeklyPlan {
                let before = current.snapshot
                current = try engine.planWeek(
                    .init(seed: current.nextSeed, state: current.snapshot, plan: selectedPlan, targetPitch: developmentTarget)
                )
                advancedWeeks += 1
                let after = current.snapshot
                // 여기서 멈춘다: 화면이 약속한 것들이다.
                if after.seasonSegment != startSegment { break }
                if after.role != before.role || after.level != before.level { break }
                if after.injuryWeeks > before.injuryWeeks { break }
            }
            return current
        }
        if self.result?.snapshot.revision != beforeRevision {
            weekly.record(.proWeeksAdvanced, amount: advancedWeeks)
            logPitchLearningProgress(before: result.snapshot, after: self.result?.snapshot)
        }
    }

    func advanceBlock() {
        guard let result, let selectedPlan,
              selectedPlan != .recover || ProCareerEngine.usesAgencyRules(result.snapshot) else { return }
        let beforeRevision = result.snapshot.revision
        var advancedWeeks = 0
        perform {
            var current = result
            for _ in 0..<3 where current.snapshot.phase == .weeklyPlan {
                let before = current.snapshot
                current = try engine.planWeek(.init(seed: current.nextSeed, state: current.snapshot, plan: selectedPlan, targetPitch: developmentTarget))
                advancedWeeks += 1
                // 화면이 "선발·불펜 역할 변화가 생기면 멈춥니다"라고 약속한다. 역할·소속이
                // 바뀌었는데 남은 주를 그대로 흘려보내면 그 약속이 거짓이 된다.
                if current.snapshot.role != before.role || current.snapshot.level != before.level { break }
            }
            return current
        }
        if self.result?.snapshot.revision != beforeRevision {
            weekly.record(.proWeeksAdvanced, amount: advancedWeeks)
            logPitchLearningProgress(before: result.snapshot, after: self.result?.snapshot)
        }
    }

    var developmentTarget: PitchType? {
        selectedPlan == .developMovement || selectedPlan == .developWeapon
            ? selectedDevelopmentPitch
            : nil
    }

    func preferActiveLearningPitch() {
        if let project = result?.snapshot.pitchLearningProject, !project.isCompleted {
            selectedDevelopmentPitch = project.pitchType
        }
    }

    func logPitchLearningProgress(
        before: ProCareerSnapshot,
        after: ProCareerSnapshot?
    ) {
        guard let beforeProject = before.pitchLearningProject,
              let afterProject = after?.pitchLearningProject,
              beforeProject != afterProject else { return }
        CareerTelemetry.log(.pitchLearningTrainingCompleted, [
            "pitch_id": afterProject.pitchType.rawValue,
            "stage_before": beforeProject.stage.rawValue,
            "stage_after": afterProject.stage.rawValue,
            "intensity_id": "pro_week",
            "credits_gained": afterProject.practiceCredits - beforeProject.practiceCredits,
            "just_game_ready": !beforeProject.isGameReady && afterProject.isGameReady,
            "just_completed": !beforeProject.isCompleted && afterProject.isCompleted,
        ])
    }
}
