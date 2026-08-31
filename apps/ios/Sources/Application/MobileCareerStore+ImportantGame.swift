import Foundation
import Observation
import SimulationCore
import BaseballIOSDomain
import BaseballIOSPersistence

extension MobileCareerStore {
    func beginImportantGame() {
        guard let result, result.snapshot.phase == .importantGame else { return }
        guard pitchSession == nil else { return }
        // **등판을 시작하는 순간 시드를 넘기고 저장한다.**
        //
        // 예전에는 여기서 저장하지 않았다. 그래서 결과를 반영하기 전에 앱을 강제 종료하면
        // 저장본에 같은 시드가 그대로 남아, **같은 이닝을 똑같은 난수로 다시 던질 수 있었다.**
        // 한 번 겪어 타자의 노림수와 결과를 알아낸 뒤 되돌리는 것이라, 이 게임이 파는
        // "한 번뿐인 승부"가 성립하지 않는다.
        //
        // 시드를 넘기면 다시 시도해도 다른 이닝이 된다. 배운 정보가 남지 않는다.
        let sessionSeed = Self.advanced(result.nextSeed)
        let checkpointed = ProCareerResult(
            snapshot: result.snapshot,
            nextSeed: sessionSeed,
            events: result.events,
            injuryEvent: result.injuryEvent
        )
        // 저장이 끝나기 전에는 시드나 화면을 바꾸지 않는다. 실패 뒤 같은 버튼을 누르면
        // 아직 소비되지 않은 원래 시드로 정확히 한 번 다시 시도할 수 있다.
        guard persist(result: checkpointed, gameResume: nil) else { return }
        updatePersisted {
            $0.result = checkpointed
            $0.gameResume = nil
        }
        let session = PitchSession(state: result.snapshot, seed: sessionSeed)
        session.start()
        attachCheckpoint(session)
        pitchSession = session
    }

    /// 시드를 한 칸 굴린다. 코어와 같은 SplitMix64를 쓴다.
    nonisolated static func advanced(_ seed: String) -> String {
        var generator = SplitMix64(seed: UInt64(seed) ?? 0x9E37_79B9_7F4A_7C15)
        return String(max(1, generator.next() >> 1))
    }

    /// 세션에서 실제로 누적된 리포트를 프로 커리어에 반영한다.
    func finishImportantGame() {
        guard let result, let session = pitchSession else { return }
        let learningWasCompleted = result.snapshot.pitchLearningProject?.isCompleted ?? true
        let report = session.report(scenarioNumber: result.snapshot.week)
        let sequenceMasteryCount = session.sequenceMasteryCount
        let beforeRevision = result.snapshot.revision
        let summary = Self.importantGameSummary(report)
        let didSettle = perform(
            summary: summary,
            cue: report.runsAllowed == 0 ? .success : .setback,
            clearGameResumeOnSuccess: true
        ) {
            try engine.resolveImportantGame(.init(seed: result.nextSeed, state: result.snapshot, report: report))
        }
        guard didSettle else { return }
        // 코어 결과와 resume 제거가 한 레코드로 저장된 뒤에만 세션을 화면에서 내린다.
        pitchSession = nil
        guard self.result?.snapshot.revision != beforeRevision else { return }
        AchievementStore.shared.record(AchievementRules.fromInning(report: report) + session.bestDeliveryAchievements)
        weekly.record(.sequenceMasteryTriggered, amount: sequenceMasteryCount)
        weekly.record(.playedOnTwoDays, receiptID: "played-day:\(CareerPlayClock.dayKey(for: Date()))")
        let gameFinishedProperties = session.gameFinishedAnalyticsMetrics.merging([
            "mode": "pro",
            "result": report.runsAllowed == 0 ? "scoreless" : "runs_allowed",
            "strikeouts": report.strikeouts,
            "walks": report.walks,
            "runs": report.runsAllowed,
        ]) { _, modeSpecific in modeSpecific }
        CareerTelemetry.log(.gameFinished, gameFinishedProperties)
        if let use = report.pitchLearningUses?.first {
            CareerTelemetry.log(.pitchLearningGameSummary, [
                "pitch_id": use.pitchType.rawValue,
                "pitches_thrown": use.pitchesThrown,
                "quality_uses_gained": use.qualityUses,
                "completed_after_game": !learningWasCompleted
                    && (self.result?.snapshot.pitchLearningProject?.isCompleted ?? false),
                "manual_delivery_rate": report.pitches > 0
                    ? Double(session.deliveryScores.count) / Double(report.pitches) : 0,
                "mode": "pro",
            ])
        }
        CareerTelemetry.recordCompletedGame()
        // 연속 일수는 모드를 가리지 않는다 — 프로 등판도 오늘 던진 것이다.
        CareerPlayClock.recordPlay()
    }

    nonisolated static func importantGameSummary(_ report: ImportantInningReport) -> String {
        "\(report.pitches)구 · \(report.strikeouts)탈삼진 · \(report.walks)볼넷 · \(report.runsAllowed)실점"
    }

    nonisolated static func retirementDurationText(_ state: ProCareerSnapshot) -> String {
        retirementDurationText(completedSeasons: state.careerStats.count)
    }

    nonisolated static func retirementDurationText(completedSeasons: Int) -> String {
        return completedSeasons > 0 ? "\(completedSeasons)시즌" : "프로 첫 시즌"
    }

    @discardableResult
    func abandonImportantGame() -> Bool {
        guard let result, pitchSession != nil else { return false }
        // 완료 정산과 같은 원칙이다. resume 제거가 디스크에 내려가기 전에 화면 세션을
        // 지우면 저장 실패 뒤에도 사용자가 던진 이닝을 다시 열 수 없다.
        guard persist(result: result, gameResume: nil) else { return false }
        pitchSession = nil
        updatePersisted { $0.gameResume = nil }
        lastSummary = "등판을 중단했습니다. 다음 마운드는 새 이닝입니다."
        feedbackCue = .setback
        feedbackTrigger += 1
        return true
    }
}
