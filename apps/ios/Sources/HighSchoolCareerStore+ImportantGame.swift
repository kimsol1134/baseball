import Foundation
import SimulationCore

extension HighSchoolCareerStore {
    // MARK: - 중요 경기

    func beginImportantGame() {
        guard let result, result.snapshot.phase == .importantGame, pitchSession == nil else { return }
        // 프로와 같은 이유로 시드를 넘기고 저장한다. 결과 반영 전에 앱을 껐다 켜면 같은
        // 이닝을 같은 난수로 다시 던질 수 있었다(무제한 리트라이).
        let sessionSeed = MobileCareerStore.advanced(result.nextSeed)
        let checkpointed = HighSchoolCareerResult(
            revision: result.revision, nextSeed: sessionSeed, events: result.events,
            snapshot: result.snapshot, eventHash: result.eventHash
        )
        guard persist(
            result: checkpointed,
            gameResume: nil,
            chronicle: chronicle,
            responseTally: responseTally,
            nextRunIntent: nextRunIntent
        ) else { return }
        self.result = checkpointed
        gameResume = nil
        let session = PitchSession(highSchool: result.snapshot, seed: sessionSeed)
        session.start()
        session.trait = personality?.trait
        attachCheckpoint(session)
        pitchSession = session
    }

    func finishImportantGame() {
        // 앞 경기의 durable 후속 영수증을 덮어쓰지 않는다. 보통 AppShell configure에서
        // 이미 비워지지만, 주간 저장소가 계속 실패한 상태라면 현재 이닝을 그대로 보존한다.
        if pendingGameCompletion != nil, !retryPendingGameCompletion() { return }
        guard let current = result, let session = pitchSession else { return }
        let report = session.report(
            scenarioNumber: current.snapshot.performance.importantGamesCompleted + 1
        )
        let gameGrowth = CareerGameGrowth.evaluating(state: current.snapshot, report: report)
        let resultLine = "\(report.pitches)구 · \(report.strikeouts)탈삼진 · \(report.walks)볼넷 · \(report.runsAllowed)실점"
        // 직접 던진 결과가 왜 능력치로 남았는지 경기 직후 한 문장으로 잇는다.
        // 숫자 +1만 띄우면 훈련과 경기의 인과가 다시 끊어진다.
        let summary = gameGrowth.map { "\(resultLine) · \($0.title). \($0.detail)" } ?? resultLine
        do {
            let updated = try engine.recordImportantGame(.init(
                seed: current.nextSeed, state: current.snapshot, report: report
            ))
            let gains = MobileCareerStore.gains(
                before: current.snapshot.pitcher, after: updated.snapshot.pitcher
            )
            let stage = "\(updated.snapshot.chapter.schoolYear)학년 \(updated.snapshot.chapter.season)"

            // Rival, nickname, chronicle, and chapter-goal state are part of the same first
            // durable record as the core result. They cannot be reconstructed by retry after the
            // phase advances, so staging them later would create an unrecoverable crash window.
            var candidateLedger = rivalLedger
            if countsTowardWeeklyProgram {
                candidateLedger = Self.accumulating(
                    candidateLedger, outcomes: session.rivalOutcomes
                )
            }
            let retention = retentionEnvelope(
                for: updated.snapshot, rivalLedger: candidateLedger
            )
            let existingNicknameIDs = Set(nicknames.map(\.id))
            let freshNicknames = NicknameRules.earned(
                performance: updated.snapshot.performance
            ).filter { !existingNicknameIDs.contains($0.id) }
            let candidateNicknames = nicknames + freshNicknames
            var candidateChronicle = chronicle
            for earned in freshNicknames {
                candidateChronicle.append(ChronicleEntry(
                    stage: stage,
                    text: "'\(earned.title)'\(KoreanCopy.particle(earned.title, final: "이라는", open: "라는")) 별명을 얻었습니다. \(earned.reason)"
                ))
            }
            if let line = Self.gameChronicleLine(
                games: updated.snapshot.performance.importantGamesCompleted,
                report: report,
                summary: summary
            ) {
                candidateChronicle.append(ChronicleEntry(stage: stage, text: line))
            }
            var candidateGoal = goalCelebratedChapter
            var completedGoal: (title: String, progress: Int)?
            let goal = ChapterGoal.goal(
                careerID: updated.snapshot.careerID,
                chapterNumber: updated.snapshot.chapter.number
            )
            let goalProgress = updated.snapshot.performance.strikeouts - chapterStartStrikeouts
            if candidateGoal != updated.snapshot.chapter.number,
               goalProgress >= goal.targetStrikeouts {
                candidateGoal = updated.snapshot.chapter.number
                completedGoal = (goal.title, goalProgress)
                candidateChronicle.append(ChronicleEntry(
                    stage: stage,
                    text: "\(goal.title) 완수 — 이번 이야기 탈삼진 \(goalProgress)개."
                ))
            }

            let completion: PendingGameCompletion? = countsTowardWeeklyProgram
                ? PendingGameCompletion(
                    id: "hs-game:\(updated.snapshot.careerID):\(report.scenarioNumber):\(updated.snapshot.revision)",
                    report: report,
                    achievements: AchievementRules.fromInning(report: report)
                        + session.bestDeliveryAchievements
                        + AchievementRules.fromHighSchool(updated.snapshot),
                    sequenceTags: session.sequenceTagIDs,
                    recommendationAcceptanceRate: session.recommendationAcceptanceRate,
                    developmentRulesVersion: current.snapshot.balanceVersion ?? 1,
                    abilityMomentCount: session.abilityMomentCount,
                    abilityMomentTypes: session.abilityMomentIDs,
                    targetBatters: session.scenario.maximumBatters,
                    batters: session.batterIndex + 1,
                    lifeNumber: updated.snapshot.lifeNumber,
                    actNumber: HighSchoolPresentation.actNumber(
                        chapter: updated.snapshot.chapter.number
                    ),
                    chapterNumber: updated.snapshot.chapter.number,
                    enteredPhase: updated.snapshot.phase != current.snapshot.phase
                        ? updated.snapshot.phase.rawValue : nil,
                    gameGrowth: gameGrowth,
                    shouldRequestCleanReview: report.runsAllowed == 0,
                    completedAt: Date()
                ) : nil
            let overrides = PersistenceOverrides(
                nicknames: candidateNicknames,
                goalCelebratedChapter: candidateGoal,
                currentCareerRetention: retention,
                pendingGameCompletion: completion
            )
            guard persist(
                result: updated,
                gameResume: nil,
                chronicle: candidateChronicle,
                responseTally: responseTally,
                nextRunIntent: nextRunIntent,
                overrides: overrides
            ) else { return }

            result = updated
            gameResume = nil
            pitchSession = nil
            nicknames = candidateNicknames
            chronicle = candidateChronicle
            goalCelebratedChapter = candidateGoal
            pendingGameCompletion = completion
            pendingGains = gains
            if countsTowardWeeklyProgram { mirrorRetention(retention) }
            if let completedGoal {
                lastSummary = "\(completedGoal.title) 완수. 삼진 \(completedGoal.progress)개 — 숙제는 끝났고, 다음은 욕심의 영역입니다."
                feedbackCue = .success
            } else if let nickname = freshNicknames.first {
                lastSummary = "이제 사람들이 '\(nickname.title)'\(KoreanCopy.particle(nickname.title, final: "이라고", open: "라고")) 부릅니다. \(nickname.reason)"
                feedbackCue = .success
            } else {
                lastSummary = summary
                feedbackCue = report.runsAllowed == 0 ? .success : .setback
            }
            feedbackTrigger += 1
            loadState = .ready

            _ = retryPendingGameCompletion()
            buzz = CommunityBuzz.reactionLines(
                careerID: updated.snapshot.careerID,
                gameNumber: updated.snapshot.performance.importantGamesCompleted,
                strikeouts: report.strikeouts,
                walks: report.walks,
                runsAllowed: report.runsAllowed,
                newNickname: freshNicknames.first
            )
        } catch {
            loadState = .failed(error.localizedDescription)
            // A stale/corrupt core state cannot settle this local inning. Clear it durably before
            // removing the UI; a storage failure keeps the exact session for another retry.
            if persist(
                result: current,
                gameResume: nil,
                chronicle: chronicle,
                responseTally: responseTally,
                nextRunIntent: nextRunIntent
            ) {
                gameResume = nil
                pitchSession = nil
            }
        }
    }

    /// 코어 경기 결과와 함께 저장된 후속 작업을 stable receipt로 마저 적용한다.
    ///
    /// 주간 진행을 먼저 durable하게 만든 뒤, 자체 원장을 가진 업적·리뷰·analytics를 적용하고
    /// 마지막으로 receipt를 지운다. 어느 줄 뒤에서 앱이 종료돼도 재호출은 같은 ID를 보고
    /// 중복 없이 이어진다. 주가 넘어간 영수증은 새 주로 이월하지 않고 외부 후속 작업만 닫는다.
    @discardableResult
    func retryPendingGameCompletion(
        calendar: Calendar = .current
    ) -> Bool {
        guard let completion = pendingGameCompletion else { return true }
        guard let completionMoment = WeeklyProgramMoment.resolve(
            date: completion.completedAt, calendar: calendar
        ) else { return false }

        let expired = weekly.lastObservedWeekStart.map {
            completionMoment.weekStart < $0
        } ?? false
        if !expired {
            guard weekly.record(
                .importantGamesCompleted,
                receiptID: "\(completion.id):weekly-game",
                now: completion.completedAt,
                calendar: calendar
            ) else { return false }
            let masteryCount = completion.report.sequenceMasteryCount ?? 0
            if masteryCount > 0 {
                guard weekly.record(
                    .sequenceMasteryTriggered,
                    amount: masteryCount,
                    receiptID: "\(completion.id):weekly-sequence",
                    now: completion.completedAt,
                    calendar: calendar
                ) else { return false }
            }
            // 하루에 몇 경기를 던지든 이 목표는 하루치만 오른다. 영수증 ID에 날짜를
            // 박아 같은 날의 두 번째 경기가 중복으로 세지 않게 한다.
            guard weekly.record(
                .playedOnTwoDays,
                receiptID: "played-day:\(DailyStreak.key(for: completion.completedAt))",
                now: completion.completedAt,
                calendar: calendar
            ) else { return false }
        }

        AchievementStore.shared.record(completion.achievements)
        // 첫 공식 경기 직후 시스템 리뷰 시트가 결과·성장 축하를 가로막았다.
        // 옛 영수증의 필드는 저장 호환을 위해 남기되, 요청은 3년 정산/지명/3회차처럼
        // 플레이 흐름이 이미 멈춘 긍정적 결절에서만 한다.

        let report = completion.report
        let analytics = [
            "mode": "high_school",
            "life_number": completion.lifeNumber,
            "act_number": completion.actNumber,
            "result": report.runsAllowed == 0 ? "scoreless" : "runs_allowed",
            "strikeouts": report.strikeouts,
            "walks": report.walks,
            "runs": report.runsAllowed,
            "sequence_mastery_count": report.sequenceMasteryCount ?? 0,
            "sequence_tags": completion.sequenceTags.joined(separator: ","),
            "recommendation_acceptance_rate": completion.recommendationAcceptanceRate,
            "development_rules_version": completion.developmentRulesVersion ?? 1,
            "ability_moment_count": completion.abilityMomentCount ?? 0,
            "ability_moment_types": (completion.abilityMomentTypes ?? []).joined(separator: ","),
            "target_batters": completion.targetBatters,
            "batters": completion.batters,
        ] as [String: Any]
        if GameAnalytics.logOnce(
            .gameFinished, scope: completion.id, properties: analytics
        ) {
            GameAnalytics.recordCompletedGame()
            // 연속 일수는 모드를 가리지 않는다 — 마운드에 올랐으면 야구를 한 것이다.
            // 날짜는 **영수증의 완료 시각**을 쓴다. 재시도 경로가 자정을 넘겨 불리면
            // 같은 경기가 주간 노트에는 어제로, 연속 일수에는 오늘로 들어간다.
            DailyStreak.recordPlay(now: completion.completedAt)
        }
        GameAnalytics.logOnce(.activationFirstGame)
        if let enteredPhase = completion.enteredPhase {
            GameAnalytics.logOnce(
                .phaseEntered,
                scope: "\(completion.id):phase",
                properties: [
                    "phase": enteredPhase,
                    "chapter": completion.chapterNumber,
                    "act_number": completion.actNumber,
                    "life_number": completion.lifeNumber,
                ]
            )
        }
        if let growth = completion.gameGrowth {
            GameAnalytics.logOnce(
                .gameGrowthApplied,
                scope: completion.id,
                properties: [
                    "life_number": completion.lifeNumber,
                    "act_number": completion.actNumber,
                    "reason_id": growth.reason.rawValue,
                    "growth_focus": growth.ability.rawValue,
                    "growth_points": growth.points,
                ]
            )
        }

        guard let current = result else { return false }
        let retention = retentionEnvelope(
            for: current.snapshot, rivalLedger: rivalLedger
        )
        let overrides = PersistenceOverrides(
            nicknames: nicknames,
            goalCelebratedChapter: goalCelebratedChapter,
            currentCareerRetention: retention,
            pendingGameCompletion: nil
        )
        guard persist(
            result: current,
            gameResume: gameResume,
            chronicle: chronicle,
            responseTally: responseTally,
            nextRunIntent: nextRunIntent,
            overrides: overrides
        ) else { return false }
        pendingGameCompletion = nil
        return true
    }

    /// 챕터 목표를 방금 넘었으면 한 번만 축하한다. 보상은 능력치가 아니라
    /// 축하와 기록이다 — 숫자 보상을 걸면 목표가 밸런스 뒷문이 된다.
    private func celebrateChapterGoalIfCrossed() {
        guard let snapshot = result?.snapshot else { return }
        let chapter = snapshot.chapter.number
        guard goalCelebratedChapter != chapter else { return }
        let goal = ChapterGoal.goal(careerID: snapshot.careerID, chapterNumber: chapter)
        let progress = snapshot.performance.strikeouts - chapterStartStrikeouts
        guard progress >= goal.targetStrikeouts else { return }
        goalCelebratedChapter = chapter
        note("\(goal.title) 완수 — 이번 이야기 탈삼진 \(progress)개.")
        lastSummary = "\(goal.title) 완수. 삼진 \(progress)개 — 숙제는 끝났고, 다음은 욕심의 영역입니다."
        feedbackCue = .success
        feedbackTrigger += 1
        save()
    }

    /// 경기 전부를 적지 않는다 — 처음, 완벽, 압도, 붕괴. 이야기가 되는 경기만.
    private func noteGame(report: ImportantInningReport, summary: String) {
        let games = result?.snapshot.performance.importantGamesCompleted ?? 0
        if let line = Self.gameChronicleLine(games: games, report: report, summary: summary) {
            note(line)
        }
    }

    /// 경기 결과와 같은 첫 SaveRecord에 넣을 수 있도록 순수 문구 판정으로 분리한다.
    private static func gameChronicleLine(
        games: Int,
        report: ImportantInningReport,
        summary: String
    ) -> String? {
        if games == 1 { return "첫 공식 등판 — \(summary)" }
        if report.runsAllowed == 0 { return "무실점 호투 — \(summary)" }
        if report.strikeouts >= 6 {
            return "탈삼진 \(report.strikeouts)개로 압도 — \(summary)"
        }
        if report.runsAllowed >= 5 {
            return "무너진 날 — \(summary). 이 경기를 기억해야 합니다."
        }
        return nil
    }

    /// 연대기에 한 줄을 적는다. 드물게 불러야 한다 — 매주 적으면 일기가 아니라 로그다.
    func note(_ text: String) {
        guard let chapter = result?.snapshot.chapter else { return }
        chronicle.append(ChronicleEntry(stage: "\(chapter.schoolYear)학년 \(chapter.season)", text: text))
        save()
    }

    /// 별명이 있으면 이름 앞에 붙인다 — '제로' 김솔. 호명·프로필이 같은 규칙을 쓴다.
    func displayName(_ name: String) -> String {
        guard let latest = nicknames.last else { return name }
        return "'\(latest.title)' \(name)"
    }

    /// 경기 뒤 별명 획득 판정. 새로 얻은 별명은 그 주의 소식이 된다 —
    /// 능력치 숫자보다 "세상이 내 아이를 알아봤다"는 문장이 오래 남는다.
    private func earnNicknames() {
        guard let performance = result?.snapshot.performance else { return }
        let fresh = NicknameRules.earned(performance: performance)
            .filter { earned in !nicknames.contains { $0.id == earned.id } }
        guard !fresh.isEmpty else { return }
        nicknames.append(contentsOf: fresh)
        for earned in fresh { note("'\(earned.title)'\(KoreanCopy.particle(earned.title, final: "이라는", open: "라는")) 별명을 얻었습니다. \(earned.reason)") }
        if let first = fresh.first {
            lastSummary = "이제 사람들이 '\(first.title)'\(KoreanCopy.particle(first.title, final: "이라고", open: "라고")) 부릅니다. \(first.reason)"
            feedbackCue = .success
            feedbackTrigger += 1
        }
        save()
    }

}
