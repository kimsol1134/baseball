import Foundation
import SimulationCore

extension HighSchoolCareerStore {
    // MARK: - 단계 진행

    func completePrologue() {
        tutorialSession = nil
        perform { try engine.completePrologue(.init(seed: $0.nextSeed, state: $0.snapshot)) }
    }

    /// 첫 불펜을 연다. 결과는 커리어에 반영되지 않는다.
    func beginTutorialPitch() {
        guard let result, result.snapshot.phase == .prologue, tutorialSession == nil else { return }
        let session = PitchSession(scenario: .tutorial(state: result.snapshot), seed: result.nextSeed)
        session.start()
        tutorialSession = session
    }

    /// 불펜을 다시 연다. 시드를 바꿔 같은 타석의 반복 암기가 안 되게 한다.
    func retryTutorialPitch() {
        guard let result, result.snapshot.phase == .prologue else { return }
        bullpenRetries += 1
        // 시드는 반드시 숫자 문자열 — 커널 validate가 UInt64(seed) 파싱을 요구하므로
        // "-bullpen-N" 같은 접미사는 즉시 invalidSeed로 죽는다(3차 패널 P0).
        // 파생이 아니라 랜덤인 이유: 카운터 파생은 앱 재실행마다 같은 순서로 되돌아가
        // 연습 판을 외울 수 있다(4차 패널 P2). 연습은 픽스처가 아니다.
        let session = PitchSession(
            scenario: .tutorial(state: result.snapshot),
            seed: String(UInt64.random(in: 1...UInt64.max))
        )
        session.start()
        tutorialSession = session
    }

    /// 연습을 마치고 프롤로그를 끝낸다. 업적·기록에는 남기지 않는다.
    func finishTutorialPitch() {
        if countsTowardWeeklyProgram {
            GameAnalytics.logOnce(.firstPitch)
        }
        completePrologue()
    }

    func chooseSchool(_ schoolID: SchoolID) {
        let beforeRevision = result?.snapshot.revision
        perform { try engine.chooseSchool(.init(seed: $0.nextSeed, state: $0.snapshot, schoolID: schoolID)) }
        guard result?.snapshot.revision != beforeRevision else { return }
        if let school = result?.snapshot.school { note("\(school.name) 입학. 3년이 시작됩니다.") }
        if let selectedName = result?.snapshot.school?.name,
           let previousName = archive.first?.schoolName,
           selectedName != previousName,
           countsTowardWeeklyProgram {
            weekly.record(.differentSchoolSelected)
        }
    }

    func commitTraining(
        focus: TrainingFocus,
        intensity: TrainingIntensity,
        targetPitch: PitchType? = nil
    ) {
        guard let before = result?.snapshot else { return }
        perform { try engine.commitTraining(.init(
            seed: $0.nextSeed,
            state: $0.snapshot,
            focus: focus,
            intensity: intensity,
            targetPitch: targetPitch
        )) }
        guard let after = result?.snapshot, after.revision != before.revision else { return }
        chapterTrainingCount += 1
        for gain in pendingGains where gain.after > gain.before {
            chapterGains[gain.label, default: 0] += gain.after - gain.before
        }
        trainingReceipt = Self.receipt(training: after.lastTraining, gains: pendingGains,
                                       bloom: pendingBloom, fatigueAfter: after.fatigue, focus: focus)
        if countsTowardWeeklyProgram {
            GameAnalytics.log(.careerTrainingCompleted, [
                "life_number": after.lifeNumber,
                "act_number": HighSchoolPresentation.actNumber(chapter: after.chapter.number),
                "focus_id": focus.rawValue,
                "intensity_id": intensity.rawValue,
                "target_pitch_id": targetPitch?.rawValue ?? "all",
                "growth_points": pendingGains.reduce(0) { $0 + max(0, $1.after - $1.before) },
                "fatigue_delta": after.fatigue - before.fatigue,
            ])
        }
        // perform 안의 save()는 이 두 값이 오르기 **전**이다 — 여기서 한 번 더.
        save()
    }

    /// 같은 훈련을 최대 세 번 묶어 진행한다. 관계·각성·공식 경기 같은 선택 국면은
    /// 건너뛰지 않고 즉시 멈추며, 팔 상태가 나빠지거나 피로가 높아져도 멈춘다.
    func commitTrainingBlock(
        focus: TrainingFocus,
        intensity: TrainingIntensity,
        targetPitch: PitchType? = nil,
        maximumSessions: Int = 3
    ) {
        guard maximumSessions > 1,
              let startingPitcher = result?.snapshot.pitcher else { return }
        // 묶음 전체의 피로 변화를 재려면 묶음이 시작될 때의 값이 필요하다. 마지막 한 번의
        // `fatigueBefore`를 쓰면 3회를 돌고도 마지막 1회분만 오른 것처럼 적힌다.
        let startingFatigue = result?.snapshot.fatigue ?? 0
        var completed = 0

        while completed < maximumSessions,
              result?.snapshot.phase == .training {
            let beforeRevision = result?.snapshot.revision
            commitTraining(focus: focus, intensity: intensity, targetPitch: targetPitch)
            guard result?.snapshot.revision != beforeRevision else { break }
            completed += 1

            guard result?.snapshot.phase == .training else { break }
            if pendingBloom != nil { break }
            if focus != .recovery,
               ((result?.snapshot.fatigue ?? 0) >= 75 || armHealth != .normal) {
                break
            }
        }

        guard completed > 1, let finalPitcher = result?.snapshot.pitcher else { return }
        pendingGains = MobileCareerStore.gains(before: startingPitcher, after: finalPitcher)
        let growth = pendingGains.reduce(0) { $0 + max(0, $1.after - $1.before) }
        lastSummary = "같은 훈련 \(completed)회 완료 · 능력 성장 +\(growth)"
        feedbackCue = growth > 0 ? .growth : .neutral
        feedbackTrigger += 1
        // 묶음 훈련은 마지막 한 번이 아니라 묶음 전체가 결과다.
        trainingReceipt = TrainingReceipt(
            focus: focus,
            headline: Self.gainHeadline(pendingGains),
            detail: "\(HighSchoolPresentation.focus(focus)) 훈련 \(completed)회를 이어서 마쳤습니다.",
            gains: pendingGains,
            growth: growth,
            repeatCount: completed,
            jackpot: result?.snapshot.lastTraining?.jackpot ?? false,
            bloom: pendingBloom,
            fatigueAfter: result?.snapshot.fatigue ?? 0,
            fatigueChange: (result?.snapshot.fatigue ?? 0) - startingFatigue,
            opportunityHit: false
        )
    }

    /// 훈련 하나의 영수증. 코어가 준 값만 옮긴다 — 화면이 결과를 다시 해석하지 않는다.
    static func receipt(
        training: CareerTrainingSnapshot?,
        gains: [MobileCareerStore.AbilityGain],
        bloom: Bloom?,
        fatigueAfter: Int,
        focus: TrainingFocus
    ) -> TrainingReceipt {
        TrainingReceipt(
            focus: training?.focus ?? focus,
            headline: gainHeadline(gains),
            detail: training?.feedback ?? "훈련을 마쳤습니다.",
            gains: gains,
            growth: training?.growth ?? gains.reduce(0) { $0 + max(0, $1.after - $1.before) },
            jackpot: training?.jackpot ?? false,
            bloom: bloom,
            fatigueAfter: fatigueAfter,
            fatigueChange: training?.fatigueChange ?? 0,
            opportunityHit: training?.opportunityHit ?? false
        )
    }

    /// "구위 +2 · 체력 +1" 또는 "능력 변화 없음".
    static func gainHeadline(_ gains: [MobileCareerStore.AbilityGain]) -> String {
        let risen = gains.filter { $0.after > $0.before }
        guard !risen.isEmpty else { return "능력 변화 없음" }
        return risen.map { "\($0.label) +\($0.after - $0.before)" }.joined(separator: " · ")
    }

    func resolveRelationship(_ response: RelationshipResponse) {
        guard let current = result else { return }
        let before = responseTally.personality
        var candidateTally = responseTally
        switch response {
        case .listen: candidateTally.listen += 1
        case .explain: candidateTally.explain += 1
        case .challenge: candidateTally.challenge += 1
        }
        var addedChronicle: [ChronicleEntry] = []
        // 성격이 처음 굳거나 서서히 바뀐 순간은 연대기에 남긴다 — 능력치가 아니라
        // 사람됨의 사건이다.
        if let after = candidateTally.personality, after != before {
            addedChronicle.append(ChronicleEntry(
                stage: "\(current.snapshot.chapter.schoolYear)학년 \(current.snapshot.chapter.season)",
                text: before == nil
                    ? "성격이 자리 잡았습니다 — '\(after.title)'. \(after.scoutLine)"
                    : "성격이 달라졌습니다 — '\(after.title)'. 사람은 고정된 값이 아닙니다."
            ))
        }
        _ = perform(
            responseTally: candidateTally,
            appendingChronicle: addedChronicle,
            bondMemory: { [weak self] beforeState, afterState in
                self?.bondMemory(
                    before: beforeState,
                    after: afterState,
                    response: response,
                    personalityBefore: before,
                    personalityAfter: candidateTally.personality
                )
            }
        ) {
            try engine.resolveRelationship(.init(
                seed: $0.nextSeed, state: $0.snapshot, response: response
            ))
        }
    }

    private func bondMemory(
        before: HighSchoolCareerSnapshot,
        after: HighSchoolCareerSnapshot,
        response: RelationshipResponse,
        personalityBefore: Personality?,
        personalityAfter: Personality?
    ) -> PlayerBondMemory? {
        guard let event = before.currentRelationshipEvent,
              let relationship = after.lastRelationship
        else { return nil }

        let kind = Self.bondMemoryKind(
            eventCategory: event.category,
            personalityChanged: personalityAfter != nil && personalityAfter != personalityBefore,
            trustBefore: relationship.trustBefore,
            trustAfter: relationship.trustAfter
        )
        guard let kind else { return nil }

        let target = HighSchoolCareerEngine.relationshipTarget(forEventCategory: event.category)
        let subjectName: String? = switch target {
        case .coach: before.school?.coachName
        case .catcher: before.school?.catcherName
        case .rival: before.rival.name
        }
        return PlayerBondMemory(
            kind: kind,
            eventID: event.id,
            eventCategory: event.category,
            eventTitle: event.title,
            response: response,
            subjectName: subjectName,
            chapterNumber: before.chapter.number,
            trustBefore: relationship.trustBefore,
            trustAfter: relationship.trustAfter
        )
    }

    nonisolated static func bondMemoryKind(
        eventCategory: String,
        personalityChanged: Bool,
        trustBefore: Int,
        trustAfter: Int
    ) -> PlayerBondMemory.Kind? {
        if eventCategory == "health" { return .healthChoice }
        if personalityChanged { return .personality }
        if trustBefore < 70, trustAfter >= 70 { return .trustMilestone }
        return nil
    }

    func chooseAwakening(_ awakening: AwakeningID) {
        guard perform(cue: .growth, {
            try engine.chooseAwakening(.init(
                seed: $0.nextSeed, state: $0.snapshot, awakening: awakening
            ))
        }) else { return }
        // 엔진이 만든 각성 문장("'○○'을 익혔습니다…")을 그대로 적는다.
        if let line = result?.snapshot.news.first { note(line) }
    }

    func advanceChapter() {
        let beforeRevision = result?.snapshot.revision
        perform { try engine.advanceChapter(.init(seed: $0.nextSeed, state: $0.snapshot)) }
        guard result?.snapshot.revision != beforeRevision else { return }
        if countsTowardWeeklyProgram {
            weekly.record(.chaptersAdvanced)
        }
        chapterStartStrikeouts = result?.snapshot.performance.strikeouts ?? chapterStartStrikeouts
        if countsTowardWeeklyProgram {
            let chapter = result?.snapshot.chapter.number ?? 0
            GameAnalytics.log(.chapterAdvanced, [
                "chapter": chapter,
                "act_number": HighSchoolPresentation.actNumber(chapter: chapter),
            ])
        }
        chapterGains = [:]
        chapterTrainingCount = 0
        if let snapshot = result?.snapshot {
            worldNews = CommunityBuzz.rivalNewsLines(
                careerID: snapshot.careerID,
                chapterNumber: snapshot.chapter.number
            )
        }
        buzz = []
        save()
    }

    /// 지명된 회차를 접고 기억 선택으로 들어간다. 미지명은 이미 그 단계에 있다.
    func openLegacy() {
        // 프로에 진입한 선수는 은퇴 기록까지 한 사람의 성장으로 묶는다. 프로 진행 중 고교
        // 탭으로 돌아와 먼저 결말을 확정하면, 이후의 통산 기록이 대표 유산에서 영영 빠진다.
        guard !hasEnteredPro else {
            lastSummary = "프로 커리어를 마치면 고교 시절과 통산 기록을 함께 돌아봅니다."
            return
        }
        guard perform({
            try engine.openLegacy(.init(seed: $0.nextSeed, state: $0.snapshot))
        }) else { return }
        freezeSignatureLegacyCandidatesIfNeeded()
    }

    func resolveDraft() {
        guard perform(cue: .success, {
            try engine.resolveDraft(.init(seed: $0.nextSeed, state: $0.snapshot))
        }) else { return }
        freezeSignatureLegacyCandidatesIfNeeded()
        if let draft = result?.snapshot.draftResult {
            if countsTowardWeeklyProgram {
                GameAnalytics.log(.draftResolved, [
                    "drafted": draft.outcome == .drafted,
                    "score": draft.evaluationScore,
                    "life_number": result?.snapshot.lifeNumber ?? 0,
                    "act_number": HighSchoolPresentation.actNumber(
                        chapter: result?.snapshot.chapter.number ?? 8
                    ),
                ])
            }
            if draft.outcome == .drafted, let team = draft.team {
                note("드래프트 \(draft.round.map { "\($0)라운드 " } ?? "")\(team.name) 지명. 3년이 응답받았습니다.")
            } else {
                note("드래프트 미지명. 하지만 이 3년은 새 선수의 밑천이 됩니다.")
            }
        }
    }

}
