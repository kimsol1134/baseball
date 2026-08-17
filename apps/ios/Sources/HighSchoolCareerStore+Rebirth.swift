import Foundation
import SimulationCore

extension HighSchoolCareerStore {
    // MARK: - 환생

    func toggleMemory(_ id: MemoryCardID) {
        guard let state else { return }
        if let index = selectedMemories.firstIndex(of: id) {
            selectedMemories.remove(at: index)
        } else if selectedMemories.count < state.memorySlots {
            selectedMemories.append(id)
        }
    }

    /// 이번 3년의 실제 성장과 경기 기록으로 만든 대표 유산 후보. 시작 스냅숏이 없는
    /// 구저장본은 최종 선수를 기준점으로 삼아 경기·각성·관계 근거만으로 후보를 만든다.
    /// 로컬 UserDefaults의 마지막 프리셋을 추측에 쓰면 새 기기 SaveSync 복원에서 같은
    /// 커리어가 다른 세 후보를 만들 수 있으므로, 저장본 자체만 입력으로 사용한다.
    func signatureLegacyCandidates(for state: HighSchoolCareerSnapshot) -> [CareerSignatureLegacy] {
        let candidateCount = Self.signatureLegacyCandidateCount(for: state)
        if let frozenSignatureLegacyCandidates,
           frozenSignatureLegacyCandidates.count == candidateCount,
           Set(frozenSignatureLegacyCandidates.map(\.id)).count == candidateCount {
            return frozenSignatureLegacyCandidates
        }
        return CareerSignatureLegacy.candidates(
            startingPitcher: careerStartingPitcher ?? state.pitcher,
            finalState: state,
            rulesVersion: signatureLegacyRulesVersion,
            candidateLimit: candidateCount
        )
    }

    /// 신규 대표 유산 규칙에서 `extraMemory`는 이번 선수가 실제 기록으로
    /// 발견하는 대표 유산 후보를 하나 더 연다.
    nonisolated static func signatureLegacyCandidateCount(for state: HighSchoolCareerSnapshot) -> Int {
        state.soulBoosts?.contains(SoulBoostID.extraMemory.rawValue) == true ? 4 : 3
    }

    @discardableResult
    func freezeSignatureLegacyCandidatesIfNeeded() -> Bool {
        guard !isChallengeRun,
              signatureLegacyRulesVersion != nil,
              frozenSignatureLegacyCandidates == nil,
              let state,
              state.phase == .legacy else { return frozenSignatureLegacyCandidates != nil || !usesSignatureLegacyRules }
        let generated = CareerSignatureLegacy.candidates(
            startingPitcher: careerStartingPitcher ?? state.pitcher,
            finalState: state,
            rulesVersion: signatureLegacyRulesVersion,
            candidateLimit: Self.signatureLegacyCandidateCount(for: state)
        )
        let expectedCount = Self.signatureLegacyCandidateCount(for: state)
        guard generated.count == expectedCount,
              Set(generated.map(\.id)).count == expectedCount else { return false }
        frozenSignatureLegacyCandidates = generated
        guard save() else {
            frozenSignatureLegacyCandidates = nil
            loadState = .failed("대표 유산 후보를 저장하지 못했습니다. 저장 공간을 확인한 뒤 다시 시도해 주세요.")
            return false
        }
        return true
    }

    /// 대표 유산 카드가 실제로 보일 때 후보 payload를 저장한다. 이후 앱 버전에서 점수식이나
    /// 문구가 바뀌어도 이미 본 세 후보와 선택은 그 회차가 끝날 때까지 그대로다.
    @discardableResult
    func prepareSignatureLegacyCandidates() -> Bool {
        freezeSignatureLegacyCandidatesIfNeeded()
    }

    func selectSignatureLegacy(_ id: CareerSignatureLegacyID) {
        guard freezeSignatureLegacyCandidatesIfNeeded() else { return }
        guard let state, signatureLegacyCandidates(for: state).contains(where: { $0.id == id }) else {
            return
        }
        let previous = selectedSignatureLegacyID
        selectedSignatureLegacyID = id
        guard save() else {
            selectedSignatureLegacyID = previous
            loadState = .failed("대표 유산 선택을 저장하지 못했습니다. 저장 공간을 확인한 뒤 다시 시도해 주세요.")
            return
        }
    }

    /// 기억 카드를 확정하고 다음 회차로 넘길 계승분을 만든다.
    func confirmLegacy() {
        // challenge 모드는 여기로 오면 안 되지만(화면이 분기한다), 방어선을 겹친다 —
        // 이 함수가 실계승·아카이브를 덮는 유일한 문이다(5차 패널 P0).
        guard !isChallengeRun else {
            endChallengeRun()
            return
        }
        guard let current = result else { return }
        let activeRulesVersion = signatureLegacyRulesVersion
        // 기능 도입 전 회차만 당시 memorySlots장을 고른다. 새 규칙은 대표 유산 하나가
        // 유일한 직접 계승이며, 옛 기억 효과를 추가로 쌓지 않는다.
        let chosen: [MemoryCardID]
        if activeRulesVersion == nil {
            guard selectedMemories.count == current.snapshot.memorySlots else { return }
            chosen = selectedMemories
        } else {
            chosen = []
        }
        let signatureCandidates: [CareerSignatureLegacy]
        let signatureLegacy: CareerSignatureLegacy?
        if activeRulesVersion == nil {
            // 기능 도입 전에 시작한 회차는 당시의 기억 선택만으로 끝낸다. nil을 v1 신규
            // 규칙으로 승격해 결말에서 갑자기 추가 선택을 강제하지 않는다.
            signatureCandidates = []
            signatureLegacy = nil
        } else {
            signatureCandidates = signatureLegacyCandidates(for: current.snapshot)
            guard let selectedSignatureLegacyID,
                  let selected = signatureCandidates.first(where: {
                      $0.id == selectedSignatureLegacyID
                  }) else { return }
            signatureLegacy = selected
        }
        // 약속 정산 — 등급별 보상을 기록과 계승이 같은 배율로 쓴다.
        let settledPledge = pledge
        let settledContext = RunPledgeContext(state: current.snapshot, rivalLedger: rivalLedger)
        let pledgeProgress = settledPledge?.progress(in: settledContext)
        let pledgeAchieved = pledgeProgress?.achieved ?? false
        let pledgeBonus = pledgeAchieved ? (settledPledge?.rewardPermille ?? 0) : 0
        do {
            let completed = try engine.selectLegacy(
                .init(
                    seed: current.nextSeed,
                    state: current.snapshot,
                    memoryCards: chosen,
                    signatureLegacyID: signatureLegacy?.id
                )
            )
            let previousInheritance = inheritance
            let previousArchive = archive
            let previousRecap = pendingRecap
            let previousStartingPitcher = careerStartingPitcher
            let previousCandidates = frozenSignatureLegacyCandidates
            let previousSelectedSignature = selectedSignatureLegacyID
            let previousSelectedMemories = selectedMemories

            let closed = Self.lifeRecord(
                from: current.snapshot, memories: chosen, previous: previousInheritance,
                nicknames: nicknames, chronicle: chronicle, personality: personality,
                pledgeBonusPermille: pledgeBonus, pledge: settledPledge, pledgeProgress: pledgeProgress,
                signatureLegacy: signatureLegacy,
                signatureLegacyCandidates: signatureCandidates.isEmpty ? nil : signatureCandidates,
                bondMemories: bondMemories,
                rebirthEventIDs: rebirthEventIDs,
                startingPitcher: careerStartingPitcher
            )
            let nextInheritance = Self.nextInheritance(
                from: current.snapshot,
                memories: chosen,
                previous: previousInheritance,
                pledgeBonusPermille: pledgeBonus,
                signatureLegacy: signatureLegacy,
                discoveredSignatureLegacies: signatureCandidates
            )
            let suggestedIntent = nextIntentSuggestion(
                settled: settledPledge, progress: pledgeProgress, state: current.snapshot
            )
            var nextArchive = archive.filter { $0.lifeNumber != closed.lifeNumber }
            nextArchive.insert(closed, at: 0)
            let masteryRankUp = signatureLegacy.flatMap {
                Self.lineageRankUp(family: $0.family, before: archive, after: nextArchive)
            }
            let recap = RunRecapView.Recap(
                record: closed,
                pledgeID: settledPledge?.id,
                pledgeTitle: settledPledge?.title,
                pledgeAchieved: pledgeAchieved,
                pledgeProgress: pledgeProgress,
                pledgeRewardPermille: settledPledge?.rewardPermille ?? 0,
                suggestedIntent: suggestedIntent,
                rivalLine: rivalLedger.summaryLine.map { "숙적 \(current.snapshot.rival.name) — \($0)" },
                soulBalance: nextInheritance.soulPoints,
                soulAutoApplied: HighSchoolCareerEngine.appliedInheritance(
                    for: nextInheritance.automaticSoulTotal,
                    storedRulesVersion: nextInheritance.inheritanceRulesVersion
                )
            )
            let deservesReview = Self.recapDeservesReview(
                closed,
                pledgeAchieved: pledgeAchieved,
                previousBestEvaluation: archive.filter { $0.lifeNumber != closed.lifeNumber }
                    .map(\.evaluationScore).max() ?? 0
            )

            result = completed
            inheritance = nextInheritance
            archive = nextArchive
            pendingRecap = recap
            selectedMemories = []
            selectedSignatureLegacyID = nil
            careerStartingPitcher = nil
            signatureLegacyRulesVersion = nil
            frozenSignatureLegacyCandidates = nil
            guard save() else {
                result = current
                inheritance = previousInheritance
                archive = previousArchive
                pendingRecap = previousRecap
                selectedMemories = previousSelectedMemories
                selectedSignatureLegacyID = previousSelectedSignature
                careerStartingPitcher = previousStartingPitcher
                signatureLegacyRulesVersion = activeRulesVersion
                frozenSignatureLegacyCandidates = previousCandidates
                loadState = .failed("이 선수의 결말을 저장하지 못했습니다. 저장 공간을 확인한 뒤 다시 시도해 주세요.")
                return
            }

            if let masteryRankUp {
                lastSummary = "\(masteryRankUp.contributions)명의 선수가 이 감각을 이어 왔습니다. 계보 숙련 \(masteryRankUp.rank)등급에 올랐습니다."
            } else {
                lastSummary = signatureLegacy.map {
                    "\($0.title)\(KoreanCopy.particle($0.title, final: "을", open: "를")) 새 선수에게 남깁니다."
                } ?? "기억 \(chosen.count)장을 새 선수에게 남깁니다."
            }
            feedbackCue = .growth
            feedbackTrigger += 1
            loadState = .ready

            // 외부 퍼널·주간·업적·리뷰는 위 durable save 뒤에만 발생한다.
            GameAnalytics.log(.phaseEntered, [
                "phase": completed.snapshot.phase.rawValue,
                "chapter": completed.snapshot.chapter.number,
                "act_number": HighSchoolPresentation.actNumber(chapter: completed.snapshot.chapter.number),
                "life_number": completed.snapshot.lifeNumber,
            ])
            if let settledPledge, let pledgeProgress {
                GameAnalytics.log(.runPledgeResolved, [
                    "pledge_id": settledPledge.id,
                    "achieved": pledgeProgress.achieved,
                    "progress_ratio": pledgeProgress.ratio,
                    "reward_permille": pledgeBonus,
                ])
            }
            if let signatureLegacy {
                GameAnalytics.log(.signatureLegacySelected, [
                    "legacy_id": signatureLegacy.id.rawValue,
                    "family": signatureLegacy.family.rawValue,
                    "life_number": current.snapshot.lifeNumber,
                    "drafted": current.snapshot.draftResult?.outcome == .drafted,
                    "rating_growth": signatureLegacy.evidence.ratingGrowth ?? 0,
                    "includes_pro_career": signatureLegacy.evidence.proPerformance != nil,
                    "pro_seasons": signatureLegacy.evidence.proPerformance?.seasons ?? 0,
                ])
            }
            if let masteryRankUp {
                GameAnalytics.log(.lineageMasteryRankedUp, [
                    "family": masteryRankUp.family.rawValue,
                    "rank": masteryRankUp.rank,
                    "contributions": masteryRankUp.contributions,
                    "life_number": current.snapshot.lifeNumber,
                ])
            }
            GameAnalytics.log(.lifeCompleted, [
                "life_number": current.snapshot.lifeNumber,
                "act_number": HighSchoolPresentation.actNumber(chapter: current.snapshot.chapter.number),
                "drafted": current.snapshot.draftResult?.outcome == .drafted,
                "evaluation": current.snapshot.draftResult?.evaluationScore ?? 0,
                "trainings": current.snapshot.totalTrainingsCompleted,
                "important_games": current.snapshot.performance.importantGamesCompleted,
                "pitches": current.snapshot.performance.pitches,
                "legacy_id": signatureLegacy?.id.rawValue ?? "pre_feature_memory_bridge",
                "legacy_rules_version": activeRulesVersion ?? 0,
                "unlocked_legacy_count": nextInheritance.unlockedSignatureLegacies?.count ?? 0,
                "inheritance_rules_version": nextInheritance.inheritanceRulesVersion ?? 0,
                "soul_total": nextInheritance.automaticSoulTotal,
                "soul_wallet": nextInheritance.soulPoints,
                "soul_lifetime_earned": nextInheritance.soulTotal,
                "soul_applied": HighSchoolCareerEngine.appliedInheritance(
                    for: nextInheritance.automaticSoulTotal,
                    storedRulesVersion: nextInheritance.inheritanceRulesVersion
                ),
            ])
            AchievementStore.shared.record(AchievementRules.fromHighSchool(completed.snapshot))
            AchievementStore.shared.record(AchievementRules.fromArchive(nextArchive))
            if deservesReview, ReviewPrompt.shouldAsk(.goodRecap) {
                reviewMoment += 1
            }
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    /// 다음 회차를 시작한다. 계승분은 유지하고 진행만 비운다.
    ///
    /// 진행을 비운 직후에도 **즉시 저장한다.** 예전에는 여기서 저장을 지우기만 했고
    /// `save()`가 진행 없이는 아무것도 쓰지 않아서, "다시 태어나기"를 누른 순간부터
    /// 새 선수 생성 완료까지 계승분(야구혼·기억·아카이브)이 메모리에만 있었다 —
    /// 그 사이가 하필 이름을 고민하는 화면이라, 앱이 내려가면 회차 전체가 1회차로 리셋됐다.
    func beginNextLife() {
        result = nil
        pitchSession = nil
        pendingGains = []
        trainingReceipt = nil
        selectedSignatureLegacyID = nil
        careerStartingPitcher = nil
        signatureLegacyRulesVersion = nil
        frozenSignatureLegacyCandidates = nil
        loadState = .needsSetup
        save()
    }

    /// 지난 회차와 같은 설정으로 곧장 다음 회차를 연다. 설정을 다시 물을 것이 없으면 nil.
    ///
    /// 왜: 회차가 끝난 뒤 다음 회차까지의 길이 정산 → 완료 화면 → 다시 태어나기 → 스탬프
    /// → 설정 4단계였다. 2026-08 데이터에서 드래프트를 본 42명 중 27명만 다음 회차를
    /// 시작했다. 로그라이트에서 "다시 한 판"은 마찰이 0에 가까워야 하는 행동이다.
    /// 영혼 상점을 쓰려면 여전히 단계대로 갈 수 있다 — 그 길을 없애지는 않는다.
    var quickRebirthPreset: PitcherPresetSnapshot? {
        guard !isChallengeRun, let last = lastSetup else { return nil }
        return PitcherPresetCatalog.all.first { $0.id == last.presetID }
    }

    /// 위 프리셋으로 즉시 시작한다. 부스트는 회차마다 다시 고르는 소비라 싣지 않는다.
    func startQuickRebirth(entryPoint: String) {
        guard let preset = quickRebirthPreset, let last = lastSetup else { return }
        startCareer(
            preset: preset,
            playerName: last.playerName,
            region: last.region,
            difficulty: CareerDifficultySnapshot(
                careerHarshness: DifficultyLevel(rawValue: last.harshness) ?? .standard),
            karmas: last.karmas,
            soulDomain: last.soulDomain,
            entryPoint: entryPoint
        )
    }

    /// 이 정산이 별점을 물어도 좋은 회차인가. 순수 함수라 테스트할 수 있다.
    ///
    /// "잘 끝났다"는 지명 여부가 아니다 — 세상이 이름을 붙여 줬거나, 걸었던 약속을
    /// 지켰거나, 지난 회차들보다 나은 평가를 받았으면 플레이어는 만족한 상태로
    /// 이 화면을 본다. 아무것도 해당하지 않는 회차(첫 판을 망친 경우)에서는 묻지 않는다.
    nonisolated static func recapDeservesReview(
        _ record: LifeRecord,
        pledgeAchieved: Bool,
        previousBestEvaluation: Int
    ) -> Bool {
        if record.drafted { return true }
        if pledgeAchieved { return true }
        if record.nicknames?.isEmpty == false { return true }
        return record.evaluationScore > previousBestEvaluation
    }

    /// 끝난 회차를 한 장으로 접는다. 순수 함수라 테스트할 수 있다.
    nonisolated static func lifeRecord(
        from state: HighSchoolCareerSnapshot,
        memories: [MemoryCardID],
        previous: Inheritance,
        nicknames: [Nickname] = [],
        chronicle: [ChronicleEntry] = [],
        personality: Personality? = nil,
        pledgeBonusPermille: Int = 0,
        pledge: RunPledge? = nil,
        pledgeProgress: RunPledgeProgress? = nil,
        signatureLegacy: CareerSignatureLegacy? = nil,
        signatureLegacyCandidates: [CareerSignatureLegacy]? = nil,
        bondMemories: [PlayerBondMemory] = [],
        rebirthEventIDs: [String] = [],
        /// 이 회차를 시작할 때의 능력. 카드가 "얼마나 키웠는지"를 말하려면 시작점이 있어야 한다.
        startingPitcher: PitcherSnapshot? = nil
    ) -> LifeRecord {
        var record = LifeRecord(
            lifeNumber: state.lifeNumber,
            playerName: state.identity.name,
            appearanceSeed: state.identity.appearanceSeed,
            schoolName: state.school?.name,
            drafted: state.draftResult?.outcome == .drafted,
            evaluationScore: state.draftResult?.evaluationScore ?? 0,
            teamName: state.draftResult?.team?.name,
            memories: memories,
            games: state.performance.importantGamesCompleted,
            strikeouts: state.performance.strikeouts,
            walks: state.performance.walks,
            runsAllowed: state.performance.runsAllowed,
            soulPoints: nextInheritance(from: state, memories: memories, previous: previous, pledgeBonusPermille: pledgeBonusPermille).soulPoints
                - previous.soulPoints,
            talent: state.talent,
            awakenings: state.selectedAwakenings,
            karmas: state.karmas,
            harshness: state.difficulty.careerHarshness.rawValue,
            schoolStrength: state.school.map { HighSchoolPresentation.focus($0.strength) },
            nicknames: nicknames.isEmpty ? nil : nicknames.map(\.title),
            chronicle: chronicle.isEmpty ? nil : chronicle.map { "\($0.stage) — \($0.text)" },
            hadArmWarning: (state.armRisk ?? 0) >= 55
                || (state.injuryRecovery ?? 0) > 0
                || bondMemories.contains(where: { $0.kind == .healthChoice }),
            coachName: state.school?.coachName,
            catcherName: state.school?.catcherName,
            rivalName: state.rival.name,
            coachTrust: state.managerTrust ?? state.relationshipTrust,
            catcherTrust: state.catcherTrust ?? state.relationshipTrust,
            rivalTrust: state.rivalTrust ?? state.relationshipTrust,
            personality: personality?.title,
            careerID: state.careerID,
            pledgeID: pledge?.id,
            pledgeTitle: pledge?.title,
            pledgeTier: pledge?.tier.rawValue,
            pledgeRewardPermille: pledge?.rewardPermille,
            pledgeAchieved: pledgeProgress?.achieved,
            pledgeProgressCurrent: pledgeProgress?.current,
            pledgeProgressTarget: pledgeProgress?.target,
            pledgeProgressLine: pledgeProgress?.line,
            pledgeProgressRatioPermille: pledgeProgress?.ratioPermille,
            windID: state.careerWind.id,
            windTitle: state.careerWind.title,
            signatureLegacy: signatureLegacy,
            signatureLegacyCandidates: signatureLegacyCandidates,
            inheritedLineageLoadout: state.lineageLoadout,
            bondMemories: Self.normalizedBondMemories(bondMemories).isEmpty
                ? nil : Self.normalizedBondMemories(bondMemories),
            rebirthEventIDs: rebirthEventIDs.isEmpty ? nil : Array(rebirthEventIDs.suffix(6))
        )
        record.pitches = state.performance.pitches
        record.outs = state.performance.outs
        record.hits = state.performance.hits
        record.abilityFinal = LifeRecord.AbilityLine(state.pitcher)
        // 시작 능력을 모르는 경로(옛 저장에서 이어 온 회차)에서는 성장 줄을 접는다 —
        // 최종만 있는데 "얼마나 키웠나"를 말하면 거짓이 된다.
        record.abilityStart = startingPitcher.map(LifeRecord.AbilityLine.init)
        record.playerLegacy = PlayerBondStory.legacy(for: record)
        return record
    }

    nonisolated static func rebirthEcho(
        from record: LifeRecord,
        inheritedMemoryCount: Int,
        inheritedLegacyID: CareerSignatureLegacyID? = nil,
        automaticInheritanceTotal: Int = 0,
        recentEventIDs: [String] = []
    ) -> RebirthEchoSnapshot {
        let inferredArmWarning = record.bondMemories?.contains(where: { $0.kind == .healthChoice }) == true
            || record.chronicle?.contains(where: { $0.contains("팔") || $0.contains("재활") }) == true
        return RebirthEchoSnapshot(
            previousPlayerName: record.playerName,
            previousSchoolName: record.schoolName,
            previousNickname: record.nicknames?.last,
            inheritedMemoryCount: inheritedMemoryCount,
            hadArmWarning: record.hadArmWarning ?? inferredArmWarning,
            hadCollapseGame: record.chronicle?.contains(where: { $0.contains("무너진 날") }) == true,
            wasUndrafted: !record.drafted,
            previousLifeNumber: record.lifeNumber,
            previousCoachName: record.coachName,
            previousRivalName: record.rivalName,
            inheritedLegacyID: inheritedLegacyID?.rawValue,
            automaticInheritanceTotal: automaticInheritanceTotal,
            hadRunsAllowed: record.runsAllowed > 0,
            recentEventIDs: recentEventIDs
        )
    }

    /// 최근 세 삶에서 본 환생 장면을 오래된 순서로 넘긴다. 여섯 개만 유지해 무결성
    /// 토큰이 끝없이 커지지 않으면서도 바로 전 회차 반복은 확실히 막는다.
    nonisolated static func recentRebirthEventIDs(from archive: [LifeRecord]) -> [String] {
        let newest = archive.sorted { $0.lifeNumber > $1.lifeNumber }.prefix(3)
        var seen = Set<String>()
        var newestFirst: [String] = []
        for record in newest {
            for eventID in (record.rebirthEventIDs ?? []).reversed()
                where seen.insert(eventID).inserted {
                newestFirst.append(eventID)
                if newestFirst.count == 6 { return newestFirst.reversed() }
            }
        }
        return newestFirst.reversed()
    }

    nonisolated static func lineageMasteries(from archive: [LifeRecord]) -> [CareerLineageMastery] {
        let uniqueSelectedIDs = Dictionary(grouping: archive, by: \.lifeNumber)
            .keys.sorted()
            .compactMap { lifeNumber in
                archive.first { $0.lifeNumber == lifeNumber }?.signatureLegacy?.id
            }
        return CareerLineageMasteryRules.masteries(from: uniqueSelectedIDs)
    }

    nonisolated static func lineageLoadout(
        equippedLegacyID: CareerSignatureLegacyID?,
        archive: [LifeRecord]
    ) -> CareerLineageLoadout? {
        guard let equippedLegacyID else { return nil }
        let family = CareerSignatureLegacy.definition(for: equippedLegacyID).family
        let mastery = lineageMasteries(from: archive).first { $0.family == family }
            ?? CareerLineageMastery(family: family, contributions: 0)
        let sourceLifeNumber = archive
            .filter { $0.signatureLegacy?.id == equippedLegacyID }
            .map(\.lifeNumber)
            .max()
        return CareerLineageLoadout(
            legacyID: equippedLegacyID,
            masteryRank: mastery.rank,
            contributions: mastery.contributions,
            sourceLifeNumber: sourceLifeNumber
        )
    }

    nonisolated static func lineageRankUp(
        family: CareerSignatureLegacyFamily,
        before: [LifeRecord],
        after: [LifeRecord]
    ) -> CareerLineageMastery? {
        let previousRank = lineageMasteries(from: before)
            .first { $0.family == family }?.rank ?? 0
        guard let current = lineageMasteries(from: after).first(where: { $0.family == family }),
              current.rank >= 2,
              current.rank > previousRank else { return nil }
        return current
    }

    /// 회차 보상 계산. 순수 함수라 테스트할 수 있다.
    nonisolated static func nextInheritance(
        from state: HighSchoolCareerSnapshot,
        memories: [MemoryCardID],
        previous: Inheritance,
        pledgeBonusPermille: Int = 0,
        signatureLegacy: CareerSignatureLegacy? = nil,
        discoveredSignatureLegacies: [CareerSignatureLegacy] = []
    ) -> Inheritance {
        // 영혼 포인트는 능력 총합과 경기 기록, 카르마 보상 배율에서 나온다. 실패한 회차도
        // 0이 되지는 않는다 — 환생물의 재접속 장치는 "다음엔 조금 더 강하다"이다.
        let ratings = state.pitcher.stuff + state.pitcher.command + state.pitcher.movement + state.pitcher.stamina
        let record = state.performance.strikeouts * 2 - state.performance.walks - state.performance.runsAllowed * 2
        let base = max(4, ratings / 8 + max(0, record) / 4)
        // 코어의 legacyRewardPermille는 이미 1000(×1.0)을 포함한 배율이다. 여기서 1000을
        // 또 더하면 카르마 없이 ×2.0이 되고, 화면의 "+35%"가 실제로는 절반만 전달된다.
        // 약속 이행 보너스는 배율에 가산한다(‰). 이중 가산 금지 원칙은 그대로 —
        // 1000(×1.0)은 legacyRewardPermille가 이미 품고 있다.
        let rewarded = base * (max(1_000, state.legacyRewardPermille) + pledgeBonusPermille) / 1_000
        var next = Inheritance(
            lifeNumber: previous.lifeNumber + 1,
            memories: memories,
            soulPoints: previous.soulPoints + rewarded,
            karmas: previous.karmas
        )
        next.soulTotalEarned = previous.soulTotal + rewarded
        next.automaticSoulEarned = previous.automaticSoulTotal + rewarded
        next.inheritanceRulesVersion = SoulInheritanceRulesVersion.current.rawValue
        // 프로 기록 저장은 성공했지만 프로 tombstone 쓰기가 실패한 사이에도 사용자는 고교
        // 유산 정산을 끝낼 수 있다. 새 선수를 실제로 시작하기 전까지 동일 프로 영수증을
        // 보존해야 남아 있는 은퇴 저장이 야구혼과 후보를 다시 지급하지 못한다.
        next.creditedProCareerID = previous.creditedProCareerID
        var unlocked = previous.unlockedSignatureLegacies ?? []
        for discovered in discoveredSignatureLegacies where !unlocked.contains(where: { $0.id == discovered.id }) {
            unlocked.append(discovered)
        }
        unlocked.sort { $0.id.rawValue < $1.id.rawValue }
        next.unlockedSignatureLegacies = unlocked.isEmpty ? nil : unlocked
        next.equippedSignatureLegacyID = signatureLegacy?.id ?? previous.equippedSignatureLegacyID
        return next
    }

}
