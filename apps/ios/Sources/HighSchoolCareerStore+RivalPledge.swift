import Foundation
import SimulationCore

extension HighSchoolCareerStore {
    // MARK: - 숙적 전적 · 고교 3년 목표

    /// 라이벌 상대 통산(회차 내) 전적. 타석·삼진·안타만 있으면 서사는 화면이 만든다.
    struct RivalLedger: Codable, Equatable {
        var plateAppearances = 0
        var strikeouts = 0
        var walks = 0
        var hits = 0
        var summaryLine: String? {
            guard plateAppearances > 0 else { return nil }
            return "\(plateAppearances)타석 \(strikeouts)삼진 \(hits)피안타"
        }
    }

    /// UserDefaults-only state did not follow SaveSync/iCloud to a new device. This optional
    /// envelope distinguishes a legacy save with no field from a new save whose player explicitly
    /// has not chosen (nil) or skipped (empty string) the current pledge.
    struct CurrentCareerRetention: Codable, Equatable {
        var careerID: String
        var pledgeID: String?
        /// nil is a save from before versioning. If it contains a selected/skipped value, v1 is
        /// the only safe interpretation; new decisions always persist v2 explicitly.
        var pledgeRulesVersion: Int? = nil
        var rivalLedger: RivalLedger
    }

    func rivalLedgerKey(_ careerID: String) -> String { "baseball.rivalLedger.\(careerID)" }

    var rivalLedger: RivalLedger {
        guard let careerID = result?.snapshot.careerID,
              let data = UserDefaults.standard.data(forKey: rivalLedgerKey(careerID)),
              let ledger = try? JSONDecoder().decode(RivalLedger.self, from: data) else { return RivalLedger() }
        return ledger
    }

    private func accumulateRivalLedger(_ outcomes: [PlateAppearanceResult]) {
        guard let careerID = result?.snapshot.careerID, !outcomes.isEmpty else { return }
        let ledger = Self.accumulating(rivalLedger, outcomes: outcomes)
        if let data = try? JSONEncoder().encode(ledger) {
            UserDefaults.standard.set(data, forKey: rivalLedgerKey(careerID))
            // Mirror the updated ledger into the authoritative SaveSync record as well.
            save()
        }
    }

    static func accumulating(
        _ current: RivalLedger,
        outcomes: [PlateAppearanceResult]
    ) -> RivalLedger {
        var ledger = current
        for outcome in outcomes {
            ledger.plateAppearances += 1
            switch outcome {
            case .strikeout: ledger.strikeouts += 1
            case .walk: ledger.walks += 1
            case .hit: ledger.hits += 1
            case .inPlayOut: break
            }
        }
        return ledger
    }

    func retentionEnvelope(
        for state: HighSchoolCareerSnapshot,
        rivalLedger: RivalLedger
    ) -> CurrentCareerRetention {
        let careerID = state.careerID
        let pledgeID = UserDefaults.standard.string(forKey: pledgeKey(careerID))
        return CurrentCareerRetention(
            careerID: careerID,
            pledgeID: pledgeID,
            pledgeRulesVersion: UserDefaults.standard.object(forKey: pledgeKey(careerID)) == nil
                ? nil : pledgeRulesVersion,
            rivalLedger: rivalLedger
        )
    }

    func mirrorRetention(_ retention: CurrentCareerRetention) {
        let pledgeStorageKey = pledgeKey(retention.careerID)
        if let pledgeID = retention.pledgeID {
            UserDefaults.standard.set(pledgeID, forKey: pledgeStorageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: pledgeStorageKey)
        }
        let versionStorageKey = pledgeRulesVersionKey(retention.careerID)
        if let version = retention.pledgeRulesVersion {
            UserDefaults.standard.set(version, forKey: versionStorageKey)
        } else if retention.pledgeID != nil {
            UserDefaults.standard.set(RunPledge.legacyRulesVersion, forKey: versionStorageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: versionStorageKey)
        }
        if let data = try? JSONEncoder().encode(retention.rivalLedger) {
            UserDefaults.standard.set(data, forKey: rivalLedgerKey(retention.careerID))
        }
    }

    func pledgeKey(_ careerID: String) -> String { "baseball.pledge.\(careerID)" }
    func pledgeRulesVersionKey(_ careerID: String) -> String {
        "baseball.pledgeRulesVersion.\(careerID)"
    }

    private var pledgeRulesVersion: Int {
        guard let careerID = result?.snapshot.careerID else { return RunPledge.currentRulesVersion }
        if let number = UserDefaults.standard.object(
            forKey: pledgeRulesVersionKey(careerID)
        ) as? NSNumber {
            return number.intValue
        }
        // A selected value with no version was written by the shipped v1 implementation.
        if UserDefaults.standard.object(forKey: pledgeKey(careerID)) != nil {
            return RunPledge.legacyRulesVersion
        }
        return RunPledge.currentRulesVersion
    }

    /// 이번 회차에 걸어 둔 약속. 프롤로그에서 한 번 고르면 회차가 끝날 때 정산된다.
    var pledge: RunPledge? {
        guard let careerID = result?.snapshot.careerID,
              let id = UserDefaults.standard.string(forKey: pledgeKey(careerID)) else { return nil }
        return RunPledge.pledge(id: id, rulesVersion: pledgeRulesVersion)
    }

    /// 약속을 걸었는가(넘긴 것도 결정이다) — 프롤로그 카드가 다시 묻지 않기 위한 표식.
    var pledgeDecided: Bool {
        guard let careerID = result?.snapshot.careerID else { return true }
        return UserDefaults.standard.object(forKey: pledgeKey(careerID)) != nil
    }

    @discardableResult
    func choosePledge(_ id: String?) -> Bool {
        guard let current = result else { return false }
        let state = current.snapshot
        // 기록 없는 도전은 정산·보상·주간 기록을 남기지 않는다. 목표 선택도 받지 않아
        // canonical 재도전 의도와 analytics를 소비하지 않는 것이 화면의 약속과 같다.
        guard countsTowardWeeklyProgram else { return false }
        let careerID = state.careerID
        let recommended = id != nil && nextRunIntent?.pledgeID == id
        let storedID = id ?? ""
        let chosen = id.flatMap {
            RunPledge.pledge(id: $0, rulesVersion: RunPledge.currentRulesVersion)
        }
        var candidateChronicle = chronicle
        if let chosen {
            candidateChronicle.append(ChronicleEntry(
                stage: "\(state.chapter.schoolYear)학년 \(state.chapter.season)",
                text: "고교 3년 목표 — \(chosen.title)."
            ))
        }
        let retention = CurrentCareerRetention(
            careerID: careerID,
            pledgeID: storedID,
            pledgeRulesVersion: RunPledge.currentRulesVersion,
            rivalLedger: rivalLedger
        )
        guard persist(
            result: current,
            gameResume: gameResume,
            chronicle: candidateChronicle,
            responseTally: responseTally,
            nextRunIntent: nil,
            currentCareerRetention: retention
        ) else { return false }

        chronicle = candidateChronicle
        nextRunIntent = nil
        UserDefaults.standard.set(storedID, forKey: pledgeKey(careerID))
        UserDefaults.standard.set(
            RunPledge.currentRulesVersion, forKey: pledgeRulesVersionKey(careerID)
        )
        if let chosen {
            lastSummary = "목표를 정했습니다: \(chosen.title). 이루면 계승 포인트 +\(chosen.rewardPermille / 10)%."
            feedbackCue = .growth
            feedbackTrigger += 1
            GameAnalytics.log(.runPledgeSelected, [
                "pledge_id": chosen.id,
                "tier": chosen.tier.rawValue,
                "life_number": state.lifeNumber,
                "recommended": recommended,
            ])
            if recommended {
                GameAnalytics.log(.nextRunIntentApplied, [
                    "pledge_id": chosen.id, "life_number": state.lifeNumber,
                ])
            }
            weekly.record(.pledgeSelected)
        } else {
            GameAnalytics.log(.runPledgeSelected, [
                "pledge_id": "none", "tier": "none",
                "life_number": state.lifeNumber, "recommended": false,
            ])
        }
        // Any explicit decision consumes the carry-over: matching applies it, every other choice discards it.
        return true
    }

    @discardableResult
    func saveNextRunIntent(_ intent: NextRunIntent) -> Bool {
        guard RunPledge.pledge(id: intent.pledgeID) != nil else { return false }
        guard persist(
            result: result,
            gameResume: gameResume,
            chronicle: chronicle,
            responseTally: responseTally,
            nextRunIntent: intent
        ) else { return false }
        nextRunIntent = intent
        GameAnalytics.log(.nextRunIntentSaved, [
            "pledge_id": intent.pledgeID,
            "source_life_number": intent.sourceLifeNumber,
        ])
        return true
    }

    func nextIntentSuggestion(
        settled: RunPledge?,
        progress: RunPledgeProgress?,
        state: HighSchoolCareerSnapshot
    ) -> NextRunIntent? {
        if let settled, progress?.achieved != true {
            return NextRunIntent(
                pledgeID: settled.id,
                sourceLifeNumber: state.lifeNumber,
                reason: RunPledge.retryIntentReason
            )
        }
        let context = RunPledgeContext(state: state, rivalLedger: rivalLedger)
        guard let candidate = RunPledge.options(careerID: state.careerID, state: state)
            .first(where: { $0.id != settled?.id && !$0.progress(in: context).achieved }) else { return nil }
        return NextRunIntent(
            pledgeID: candidate.id,
            sourceLifeNumber: state.lifeNumber,
            reason: "아카이브에 아직 완주하지 않은 목표입니다."
        )
    }

    func acknowledgeBloom() {
        pendingBloom = nil
    }

}
