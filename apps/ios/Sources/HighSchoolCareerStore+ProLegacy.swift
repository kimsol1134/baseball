import Foundation
import SimulationCore

extension HighSchoolCareerStore {
    // MARK: - 프로 커리어의 계승

    /// 프로 저장에 적힌 원본 고교와 현재 고교 회차가 같은지 확인한다. 필드가 없던 구버전
    /// 프로 저장은 고교 쪽 진입 영수증과 동일한 선수 신원까지 맞을 때만 안전하게 연결한다.
    func canAttachProLegacy(
        _ proState: ProCareerSnapshot?,
        sourceHighSchoolCareerID: String?,
        allowsLegacySourceMigration: Bool = false
    ) -> Bool {
        guard let proState,
              let current = result?.snapshot,
              current.draftResult?.outcome == .drafted,
              current.identity == proState.identity else { return false }
        // 명시 source가 있으면 그것이 권위다. 구버전처럼 source가 없으면 현재 지명 선수와
        // 신원이 일치하고, 영수증이 없거나 현재 회차를 가리킬 때만 정규 경로로 복원한다.
        if let sourceHighSchoolCareerID {
            return sourceHighSchoolCareerID == current.careerID
                && (enteredProCareerID == nil || enteredProCareerID == current.careerID)
        }
        guard allowsLegacySourceMigration else { return false }
        // origin/source가 모두 없던 시대에는 direct Pro도 같은 모양이었다. 정규 진입은
        // 투수 ID와 최초 프로 구단이 고교 지명 결과와 같아야 하므로 이 두 불변값까지 맞춘다.
        let entryTeamID = proState.careerStats.first?.teamID ?? proState.currentStats.teamID
        guard current.pitcher.id == proState.pitcher.id,
              current.draftResult?.team?.id == entryTeamID else { return false }
        return enteredProCareerID == nil || enteredProCareerID == current.careerID
    }

    /// 은퇴한 프로 커리어를 다음 회차의 야구혼과 대표 유산 후보로 접는다.
    ///
    /// 예전에는 15년 명예의 전당 커리어도 계승에 0을 남겼다 — 환생 루프가 고교 스냅숏만
    /// 읽어서, 드래프트 직후 바로 접은 회차와 전설로 은퇴한 회차가 다음 회차에서 완전히
    /// 같았다. 프로에서의 시간이 환생과 아무 관계가 없으면, 게임의 후반 전체가 루프
    /// 바깥에 있게 된다.
    @discardableResult
    func recordProLegacy(
        _ proState: ProCareerSnapshot?,
        sourceHighSchoolCareerID: String? = nil,
        allowsLegacySourceMigration: Bool = false
    ) -> Bool {
        guard let proState,
              proState.phase == .completed,
              let current = result,
              canAttachProLegacy(
                  proState,
                  sourceHighSchoolCareerID: sourceHighSchoolCareerID,
                  allowsLegacySourceMigration: allowsLegacySourceMigration
              ),
              [.completed, .legacy].contains(current.snapshot.phase) else { return false }

        // 다른 프로 커리어의 영수증이 같은 고교 회차에 붙는 것은 저장 연결이 깨진 상태다.
        // 조용히 덮으면 야구혼과 유산 근거가 서로 다른 선수가 된다.
        if let credited = inheritance.creditedProCareerID, credited != proState.proCareerID {
            return false
        }
        // 첫 저장은 이미 성공했고 프로 tombstone 삭제만 재시도하는 경우다. 사용자가 그 사이
        // 후보를 고르거나 유산 정산까지 끝냈어도 완료 상태를 다시 `.legacy`로 열지 않는다.
        // credited 영수증은 후보/야구혼/고교 상태를 한 번에 durable save한 뒤에만 생긴다.
        if inheritance.creditedProCareerID == proState.proCareerID {
            return true
        }

        let opened: HighSchoolCareerResult
        do {
            opened = current.snapshot.phase == .legacy
                ? current
                : try engine.openLegacy(.init(seed: current.nextSeed, state: current.snapshot))
        } catch {
            loadState = .failed(error.localizedDescription)
            return false
        }

        let combinedCandidates: [CareerSignatureLegacy]?
        if signatureLegacyRulesVersion != nil {
            let generated = CareerSignatureLegacy.candidates(
                startingPitcher: careerStartingPitcher ?? current.snapshot.pitcher,
                highSchoolState: current.snapshot,
                proCareer: proState,
                rulesVersion: signatureLegacyRulesVersion,
                candidateLimit: Self.signatureLegacyCandidateCount(for: current.snapshot)
            )
            let expectedCount = Self.signatureLegacyCandidateCount(for: current.snapshot)
            guard generated.count == expectedCount,
                  Set(generated.map(\.id)).count == expectedCount else { return false }
            combinedCandidates = generated
        } else {
            // 기능 도입 전에 시작한 선수는 당시 기억 카드 규칙으로 마무리한다.
            combinedCandidates = nil
        }

        let previousResult = result
        let previousInheritance = inheritance
        let previousCandidates = frozenSignatureLegacyCandidates
        let previousSelection = selectedSignatureLegacyID
        let previousEnteredProCareerID = enteredProCareerID
        let creditsNewProCareer = inheritance.creditedProCareerID == nil

        result = opened
        // source/entered 필드가 없던 정상 고교→프로 저장도 이번 원자 저장에서 연결 영수증을
        // 보강한다. 그래야 프로 삭제 뒤 같은 지명으로 다시 들어가 중복 보상을 만들지 못한다.
        enteredProCareerID = current.snapshot.careerID
        if creditsNewProCareer {
            let bonus = Self.proSoulBonus(for: proState)
            inheritance.creditedProCareerID = proState.proCareerID
            // Legacy saves had a single total. Freeze that historical automatic amount before
            // adding the Pro wallet credit so a long career does not silently alter the next
            // high-school pitcher's ratings.
            inheritance.automaticSoulEarned = inheritance.automaticSoulTotal
            inheritance.soulTotalEarned = inheritance.soulTotal + bonus
            inheritance.soulPoints += bonus
        }
        // 고교 기록만으로 미리 생성된 후보가 있더라도 프로 은퇴 시점에는 통산 기록을 포함한
        // 세 후보로 교체하고 다시 고르게 한다. 선택과 실제 근거가 어긋나지 않게 한다.
        frozenSignatureLegacyCandidates = combinedCandidates
        selectedSignatureLegacyID = nil

        guard save() else {
            result = previousResult
            inheritance = previousInheritance
            frozenSignatureLegacyCandidates = previousCandidates
            selectedSignatureLegacyID = previousSelection
            enteredProCareerID = previousEnteredProCareerID
            loadState = .failed("프로 기록을 유산으로 저장하지 못했습니다. 저장 공간을 확인한 뒤 다시 시도해 주세요.")
            return false
        }

        loadState = .ready
        lastSummary = combinedCandidates == nil
            ? "프로 커리어를 마쳤습니다. 이제 당시 규칙대로 남길 기억을 고릅니다."
            : "고교 시절과 프로 통산 기록에서 대표 유산 \(combinedCandidates?.count ?? 0)개를 찾았습니다."
        feedbackCue = .growth
        feedbackTrigger += 1
        if creditsNewProCareer {
            GameAnalytics.log(.proLegacyRecorded, [
                "life_number": current.snapshot.lifeNumber,
                "pro_seasons": proState.careerStats.count,
                "soul_bonus": Self.proSoulBonus(for: proState),
                "has_signature_candidates": combinedCandidates != nil,
            ])
        }
        return true
    }

    /// 고교를 건너뛰고 시작한 프로 커리어는 특정 고교 선수의 대표 유산으로 꾸미지 않는다.
    /// 대신 통산 무게만 야구혼으로 안전하게 남기고 현재 고교 진행은 그대로 보존한다.
    @discardableResult
    func recordStandaloneProLegacy(_ proState: ProCareerSnapshot?) -> Bool {
        guard let proState, proState.phase == .completed else { return false }
        let receipt = "standalone-pro:\(proState.proCareerID)"
        if creditedExternalRewardIDs.contains(receipt) { return true }

        let previousInheritance = inheritance
        let previousReceipts = creditedExternalRewardIDs
        let bonus = Self.proSoulBonus(for: proState)
        creditedExternalRewardIDs.insert(receipt)
        inheritance.automaticSoulEarned = inheritance.automaticSoulTotal
        inheritance.soulTotalEarned = inheritance.soulTotal + bonus
        inheritance.soulPoints += bonus
        guard save() else {
            inheritance = previousInheritance
            creditedExternalRewardIDs = previousReceipts
            loadState = .failed("프로 기록을 저장하지 못했습니다. 저장 공간을 확인한 뒤 다시 시도해 주세요.")
            return false
        }

        loadState = result == nil ? .needsSetup : .ready
        GameAnalytics.log(.proLegacyRecorded, [
            "life_number": inheritance.lifeNumber,
            "pro_seasons": proState.careerStats.count,
            "soul_bonus": bonus,
            "has_signature_candidates": false,
        ])
        return true
    }

    /// 외부 야구혼 보상을 영수증과 함께 원자적으로 받아들인다.
    ///
    /// 이미 받은 ID도 `true`를 돌려준다. 보상 저장 뒤 주간 저장이 끊긴 경우 호출자가
    /// 안전하게 `claimed`를 마저 기록할 수 있고, 잔액은 두 번 오르지 않는다.
    @discardableResult
    func acceptExternalSoulReward(id: String, soulPoints: Int) -> Bool {
        guard !id.isEmpty, soulPoints > 0 else { return false }
        if creditedExternalRewardIDs.contains(id) { return true }
        let previousInheritance = inheritance
        let previousRewardIDs = creditedExternalRewardIDs
        let previousAutomaticSoul = inheritance.automaticSoulTotal
        let previousSoulTotal = inheritance.soulTotal
        creditedExternalRewardIDs.insert(id)
        inheritance.soulTotalEarned = previousSoulTotal + soulPoints
        inheritance.automaticSoulEarned = previousAutomaticSoul + soulPoints
        inheritance.soulPoints += soulPoints
        guard save() else {
            inheritance = previousInheritance
            creditedExternalRewardIDs = previousRewardIDs
            return false
        }
        return true
    }

    /// 프로 커리어가 남기는 야구혼. 스펙(메타 계승)의 프로 스케일을 따른다:
    /// 짧은 2군 커리어 ~30, 평범한 1군 커리어 ~80~120, 20시즌 전설은 300+까지 오른다.
    nonisolated static func proSoulBonus(for state: ProCareerSnapshot) -> Int {
        let strikeouts = state.careerStats.reduce(0) { $0 + $1.strikeouts }
        let outs = state.careerStats.reduce(0) { $0 + $1.inningsOuts }
        let decisions = state.careerStats.reduce(0) { $0 + $1.wins + $1.saves }
        // 탈삼진형만 다음 회차 재화를 더 받지 않도록, 이닝 소화와 승리·세이브를
        // 탈삼진 환산치로 함께 비교한다. 기존 수치 전용 오버로드는 구테스트 호환용이다.
        let equivalentAchievement = max(strikeouts, outs / 3, decisions * 4)
        return proSoulBonus(
            seasons: state.careerStats.count,
            strikeouts: equivalentAchievement,
            awards: state.awards.count,
            hallOfFameScore: state.hallOfFameScore ?? 0
        )
    }

    nonisolated static func proSoulBonus(seasons: Int, strikeouts: Int, awards: Int, hallOfFameScore: Int) -> Int {
        // 20은 지명받아 프로 유니폼을 입었다는 것 자체의 무게다.
        20 + seasons * 3 + strikeouts / 25 + awards * 8 + hallOfFameScore / 2
    }

    func acknowledgeGains() {
        pendingGains = []
    }

}
