import Foundation
import Observation
import SimulationCore
import BaseballIOSDomain
import BaseballIOSPersistence

extension MobileCareerStore {
    func beginImportantGame() {
        guard let result, Self.canBeginImportantGame(result.snapshot) else { return }
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
        // 재생에 새길 좌표. 앨범이 기록 화면의 등판 행과 이어 붙는 열쇠다.
        session.replaySeason = result.snapshot.season
        session.replayWeek = result.snapshot.week
        session.replayOutingNumber = (result.snapshot.gameLines?.count ?? 0) + 1
        session.start()
        attachCheckpoint(session)
        pitchSession = session
    }

    nonisolated static func canBeginImportantGame(_ state: ProCareerSnapshot) -> Bool {
        guard state.phase == .importantGame else { return false }
        if state.seasonTrigger == .nationalFinal { return true }
        guard ProCareerEngine.usesFinalSeriesRules(state),
              let postseason = state.postseason,
              postseason.currentRound != nil else { return true }
        return ProPostseasonRules.canStartDirectAppearance(postseason, role: state.role)
    }

    func choosePostseasonAvailability(_ choice: ProPostseasonAvailabilityChoice) {
        guard let result else { return }
        let before = result.snapshot
        let didApply = perform(
            summary: choice == .pitchAgain
                ? "연투를 선택했습니다. 추가 피로를 반영했습니다."
                : "한 경기를 쉬고 다음 등판을 준비합니다.",
            cue: choice == .pitchAgain ? .setback : .neutral
        ) {
            try engine.choosePostseasonAvailability(.init(
                seed: result.nextSeed,
                state: result.snapshot,
                choice: choice
            ))
        }
        guard didApply, let after = self.result?.snapshot else { return }
        CareerTelemetry.log(.postseasonAvailabilitySelected, [
            "choice": choice.rawValue,
            "round": before.postseason?.currentRound?.rawValue ?? "none",
            "game_number": before.postseason?.series?.nextGameNumber ?? 0,
            "player_wins": before.postseason?.series?.playerWins ?? 0,
            "opponent_wins": before.postseason?.series?.opponentWins ?? 0,
            "stakes": before.postseason.map(ProPostseasonRules.stakes)?.rawValue ?? "standard",
            "fatigue_before": before.fatigue,
            "fatigue_after": after.fatigue,
            "strength_band": Self.postseasonStrengthBand(before),
        ])
        if choice == .restForDecider,
           let line = after.postseason?.gameHistory?.last {
            Self.logPostseasonGame(line, state: after)
        }
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
        let beforeState = result.snapshot
        let summary = Self.importantGameSummary(report)
        // 이번 등판이 남긴 공을 저장과 같은 트랜잭션에 태운다.
        stagedReplays = session.capturedReplays
        let didSettle = perform(
            summary: summary,
            cue: report.runsAllowed == 0 ? .success : .setback,
            clearGameResumeOnSuccess: true,
            operation: "important-game:\(result.snapshot.season):\(result.snapshot.week)"
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
        if let line = self.result?.snapshot.postseason?.gameHistory?.last,
           line.directlyPlayed,
           (self.result?.snapshot.postseason?.gameHistory?.count ?? 0)
                > (beforeState.postseason?.gameHistory?.count ?? 0) {
            Self.logPostseasonGame(line, state: self.result?.snapshot ?? beforeState)
        }
        if beforeState.seasonTrigger == .nationalFinal,
           let tournament = self.result?.snapshot.nationalTournament,
           let outcome = tournament.result {
            CareerTelemetry.log(.proNationalTeamResult, [
                "result": outcome.rawValue,
                "exempted": tournament.exempted,
            ])
        }
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

    /// 실패 뒤 **저장이 확인된** 등판을 재실행 없이 마무리한다(7-B).
    ///
    /// 같은 리포트를 다시 얹지 않는 것이 요점이다. 디스크에서 현재 상태를 다시 읽고,
    /// 그 상태가 살아 있으면 세션만 닫는다 — 이미 기록된 이닝을 두 번 반영하지 않는다.
    @discardableResult
    func confirmSavedImportantGame() -> Bool {
        guard pitchSession != nil else { return false }
        guard case .live = restore() else { return false }
        pitchSession = nil
        lastActionFailure = nil
        loadState = .ready
        lastSummary = "저장된 등판 결과를 불러왔습니다."
        feedbackCue = .neutral
        feedbackTrigger += 1
        return true
    }

    @discardableResult
    func abandonImportantGame() -> Bool {
        guard let result, pitchSession != nil else { return false }
        let abandonedPitches = pitchSession?.report(scenarioNumber: result.snapshot.week).pitches ?? 0
        // 완료 정산과 같은 원칙이다. resume 제거가 디스크에 내려가기 전에 화면 세션을
        // 지우면 저장 실패 뒤에도 사용자가 던진 이닝을 다시 열 수 없다.
        guard persist(result: result, gameResume: nil) else { return false }
        pitchSession = nil
        updatePersisted { $0.gameResume = nil }
        lastSummary = "등판을 중단했습니다. 다음 마운드는 새 이닝입니다."
        feedbackCue = .setback
        feedbackTrigger += 1
        if ProPostseasonRules.isAutumn(result.snapshot.seasonTrigger) {
            CareerTelemetry.log(.postseasonDirectAbandoned, [
                "round": result.snapshot.postseason?.currentRound?.rawValue ?? "none",
                "game_number": result.snapshot.postseason?.series?.nextGameNumber ?? 0,
                "pitches": abandonedPitches,
            ])
        }
        return true
    }

    nonisolated static func postseasonStrengthBand(_ state: ProCareerSnapshot) -> String {
        let edge = ProPostseasonRules.teamStrengthEdgePermille(state)
        if edge > 25 { return "advantage" }
        if edge < -25 { return "disadvantage" }
        return "even"
    }

    private static func logPostseasonGame(
        _ line: ProPostseasonGameLine,
        state: ProCareerSnapshot
    ) {
        CareerTelemetry.log(.postseasonGameResolved, [
            "round": line.round?.rawValue ?? "none",
            "game_number": line.gameNumber,
            "direct": line.directlyPlayed,
            "won": line.won,
            "team_runs": line.teamRuns,
            "opponent_runs": line.opponentRuns,
            "player_runs": line.playerRunsAllowed ?? -1,
            "player_pitches": line.playerPitches ?? -1,
            "strength_band": postseasonStrengthBand(state),
        ])
        if let postseason = state.postseason, postseason.result != .inProgress {
            CareerTelemetry.log(.postseasonCompleted, [
                "result": postseason.result.rawValue,
                "seed": postseason.seed,
                "games": postseason.gamesPlayed,
                "direct_appearances": postseason.gameHistory?.count { $0.directlyPlayed } ?? 0,
            ])
        }
    }
}
