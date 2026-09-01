import Foundation
import Observation
import SimulationCore
import BaseballIOSDomain
import BaseballIOSPersistence

extension MobileCareerStore {
    func restoreOrCreateCareer() {
        guard result == nil else { return }
        applyRestoreOutcome(restore())
    }

    /// 진행 중 오류라면 기존 상태로 돌아가고, 시작 복원 오류라면 원본을 보존한 채 다시 읽는다.
    func retryRestoreOrReturn() {
        if result != nil {
            loadState = .ready
            return
        }
        loadState = .loading
        applyRestoreOutcome(restore())
    }

    func applyRestoreOutcome(_ outcome: RestoreOutcome) {
        switch outcome {
        case .live(let recoveredFromBackup):
            loadState = .ready
            preferActiveLearningPitch()
            if recoveredFromBackup {
                lastSummary = "현재 저장본을 읽지 못해 직전 정상 백업으로 복구했습니다."
                feedbackCue = .success
                feedbackTrigger += 1
            }
        case .needsSetup:
            loadState = .needsSetup
        case .unavailable:
            loadState = .failed(Self.unreadableSaveMessage)
        }
    }

    /// 유료앱에서는 앱 구매가 곧 이용 권한이므로 디버그/릴리스가 같은 경로를 탄다.
    @discardableResult
    func startNewCareer(
        preset: PitcherPresetSnapshot,
        playerName: String,
        startingRepertoire: StartingRepertoireSelection? = nil
    ) -> Bool {
        guard !isBlockedByUnreadableSave else { return false }
        let previous = capturePersisted()
        let previousSummary = lastSummary
        let previousFeedbackCue = feedbackCue
        let previousFeedbackTrigger = feedbackTrigger
        let previousLoadState = loadState
        do {
            let seed = UInt64.random(in: 1...UInt64.max)
            let created = try CareerBootstrap.startCareer(
                preset: preset,
                playerName: playerName,
                seed: seed,
                startingRepertoire: startingRepertoire,
                engine: engine
            )
            updatePersisted {
                $0.result = created
                $0.sourceHighSchoolCareerID = nil
                $0.careerOrigin = .direct
            }
            preferActiveLearningPitch()
            lastSummary = created.snapshot.phase == .contractOffer
                ? "\(created.snapshot.team.name) 지명. 신인 계약 제안을 확인해 주세요."
                : "\(created.snapshot.team.name) 입단. 2군에서 첫 시즌을 시작합니다."
            feedbackCue = .success
            feedbackTrigger += 1
            loadState = .ready
            guard save() else {
                replacePersisted(previous)
                lastSummary = previousSummary
                feedbackCue = previousFeedbackCue
                feedbackTrigger = previousFeedbackTrigger
                loadState = .failed("프로 커리어 시작을 저장하지 못했습니다. 저장 공간을 확인한 뒤 다시 시도해 주세요.")
                return false
            }
            if let startingRepertoire {
                CareerTelemetry.log(.repertoireSelected, [
                    "preset_id": preset.id,
                    "ready_pitch_ids": startingRepertoire.readyBreakingPitches.map(\.rawValue).sorted().joined(separator: ","),
                    "primary_pitch_id": startingRepertoire.primaryPitch.rawValue,
                    "learning_pitch_id": startingRepertoire.learningPitch.rawValue,
                    "life_number": 1,
                    "used_recommended_default": startingRepertoire == PitchLearningRules.recommendedSelection(presetID: preset.id),
                ])
            }
            return true
        } catch {
            replacePersisted(previous)
            lastSummary = previousSummary
            feedbackCue = previousFeedbackCue
            feedbackTrigger = previousFeedbackTrigger
            loadState = .failed(error.localizedDescription)
            if previous.result != nil { loadState = previousLoadState }
            return false
        }
    }

    /// 고교 커리어의 지명 결과로 프로를 연다. 정규 경로다.
    @discardableResult
    func startProCareer(
        draft: DraftResultSnapshot,
        pitcher: PitcherSnapshot,
        identity: PlayerIdentitySnapshot,
        sourceHighSchoolCareerID: String,
        sourceFanInterest: Int? = nil,
        repertoireRulesVersion: Int? = nil,
        pitchLearningProject: PitchLearningProjectSnapshot? = nil
    ) -> Bool {
        guard !isBlockedByUnreadableSave else { return false }
        let previous = capturePersisted()
        let previousSummary = lastSummary
        let previousFeedbackCue = feedbackCue
        let previousFeedbackTrigger = feedbackTrigger
        let previousLoadState = loadState
        do {
            let created = try CareerBootstrap.startCareer(
                draft: draft,
                pitcher: pitcher,
                identity: identity,
                seed: UInt64.random(in: 1...UInt64.max),
                sourceFanInterest: sourceFanInterest,
                repertoireRulesVersion: repertoireRulesVersion,
                pitchLearningProject: pitchLearningProject,
                engine: engine
            )
            updatePersisted {
                $0.result = created
                $0.sourceHighSchoolCareerID = sourceHighSchoolCareerID
                $0.careerOrigin = .highSchool
            }
            preferActiveLearningPitch()
            lastSummary = created.snapshot.phase == .contractOffer
                ? "\(created.snapshot.team.name) 지명. 신인 계약 제안을 확인해 주세요."
                : "\(created.snapshot.team.name) 입단. 고교 3년의 능력을 그대로 안고 시작합니다."
            feedbackCue = .success
            feedbackTrigger += 1
            loadState = .ready
            guard save() else {
                replacePersisted(previous)
                lastSummary = previousSummary
                feedbackCue = previousFeedbackCue
                feedbackTrigger = previousFeedbackTrigger
                loadState = .failed("프로 진입을 저장하지 못했습니다. 저장 공간을 확인한 뒤 다시 시도해 주세요.")
                return false
            }
            return true
        } catch {
            replacePersisted(previous)
            lastSummary = previousSummary
            feedbackCue = previousFeedbackCue
            feedbackTrigger = previousFeedbackTrigger
            loadState = .failed(error.localizedDescription)
            if previous.result != nil { loadState = previousLoadState }
            return false
        }
    }

#if DEBUG
    /// 포스트시즌 전력·전적·연투·타자 적응 UI를 긴 커리어 진행 없이 검증한다.
    @discardableResult
    func installPostseasonFixtureForUITesting() -> Bool {
        do {
            let preset = PitcherPresetCatalog.all[2]
            let base = try CareerBootstrap.startCareer(
                preset: preset,
                playerName: "가을 필승조",
                seed: 202_609_01,
                startingRepertoire: PitchLearningRules.recommendedSelection(presetID: preset.id),
                engine: engine
            )
            let opponent = ProCareerEngine.proTeams.first { $0.id != base.snapshot.team.id }
                ?? ProCareerEngine.proTeams[1]
            let rival = ProRivalBatter(
                id: "ui-postseason-rival",
                name: "서가람",
                archetype: "가을 중심 타자",
                teamID: opponent.id,
                teamName: opponent.name,
                record: "시리즈 2홈런",
                profile: "앞 경기에서 반복된 슬라이더를 기다립니다."
            )
            let history: [ProPostseasonGameLine] = [
                .init(round: .final, gameNumber: 1, teamRuns: 4, opponentRuns: 2, directlyPlayed: true, playerPitches: 14, playerOuts: 3, playerRunsAllowed: 0),
                .init(round: .final, gameNumber: 2, teamRuns: 2, opponentRuns: 5, directlyPlayed: false),
                .init(round: .final, gameNumber: 3, teamRuns: 3, opponentRuns: 1, directlyPlayed: true, playerPitches: 17, playerOuts: 3, playerRunsAllowed: 0),
                .init(round: .final, gameNumber: 4, teamRuns: 1, opponentRuns: 3, directlyPlayed: true, playerPitches: 18, playerOuts: 3, playerRunsAllowed: 1),
            ]
            let memory = RivalMemorySnapshot(
                matchupID: "\(base.snapshot.pitcher.id):bench:\(opponent.id)",
                revision: 6,
                plateAppearancesSeen: 3,
                totalPitchesSeen: 6,
                recentObservations: [
                    .init(pitchType: .slider, zone: .init(row: 2, column: 2), zoneIntent: .chase, balls: 1, strikes: 2, outcome: .swingingStrike),
                    .init(pitchType: .slider, zone: .init(row: 2, column: 2), zoneIntent: .chase, balls: 0, strikes: 2, outcome: .ball),
                    .init(pitchType: .fourSeam, zone: .init(row: 0, column: 0), zoneIntent: .strike, balls: 0, strikes: 0, outcome: .foul),
                ]
            )
            let postseason = ProPostseasonState(
                seed: 1,
                currentRound: .final,
                result: .inProgress,
                gamesPlayed: 4,
                series: .init(
                    round: .final,
                    opponentTeamID: opponent.id,
                    playerWinsRequired: 3,
                    opponentWinsRequired: 3,
                    playerWins: 2,
                    opponentWins: 2,
                    nextGameNumber: 5,
                    totalDirectAppearances: 3,
                    lastAppearancePitches: 18,
                    lastAppearanceGameNumber: 4,
                    gameLines: history,
                    rivalMemory: memory
                ),
                gameHistory: history
            )

            var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(base.snapshot)) as! [String: Any]
            object["phase"] = ProCareerPhase.importantGame.rawValue
            object["week"] = 24
            object["level"] = ProLevel.major.rawValue
            object["role"] = ProRole.setup.rawValue
            object["fatigue"] = 78
            object["proRulesVersion"] = 7
            object["seasonTrigger"] = ProSeasonTrigger.autumnFinal.rawValue
            object["currentRival"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(rival))
            object["postseason"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(postseason))
            object.removeValue(forKey: "journeyState")
            let decoded = try JSONDecoder().decode(
                ProCareerSnapshot.self,
                from: JSONSerialization.data(withJSONObject: object)
            )
            let signed = engine.resignFixtureForTesting(decoded)
            let fixture = ProCareerResult(
                snapshot: signed,
                nextSeed: "2026090101",
                events: ["ui_postseason_fixture"]
            )
            updatePersisted {
                $0.result = fixture
                $0.gameResume = nil
                $0.sourceHighSchoolCareerID = nil
                $0.careerOrigin = .direct
            }
            selectedPlan = nil
            pendingGains = []
            lastSummary = nil
            feedbackCue = .neutral
            feedbackTrigger += 1
            loadState = .ready
            return save()
        } catch {
            loadState = .failed(error.localizedDescription)
            return false
        }
    }

    /// Stable UI-only state for validating the post-100 mastery and explainable injury surfaces.
    /// Release builds do not compile this path and normal saves can never request it.
    @discardableResult
    func installReviewImprovementFixtureForUITesting() -> Bool {
        do {
            let preset = PitcherPresetCatalog.all[0]
            let base = try CareerBootstrap.startCareer(
                preset: preset,
                playerName: "리뷰 검증 투수",
                seed: 202_608_28,
                startingRepertoire: PitchLearningRules.recommendedSelection(presetID: preset.id)
            )
            let data = try JSONEncoder().encode(base)
            guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  var snapshot = object["snapshot"] as? [String: Any],
                  var pitcher = snapshot["pitcher"] as? [String: Any] else { return false }

            pitcher["stuff"] = 80
            pitcher["command"] = 80
            pitcher["movement"] = 80
            pitcher["stamina"] = 80
            pitcher["mastery"] = ["stuff": 14, "command": 9, "movement": 11, "stamina": 7]
            snapshot["pitcher"] = pitcher
            snapshot["fatigue"] = 82
            snapshot["injuryWeeks"] = 3
            object["snapshot"] = snapshot

            let event = ProInjuryEventSnapshot(
                season: snapshot["season"] as? Int ?? 1,
                week: max(1, snapshot["week"] as? Int ?? 1),
                plan: .developStuff,
                rawFatigue: 82,
                effectiveFatigue: 86,
                pitches: 91,
                recoveryWeeks: 3,
                careerID: snapshot["proCareerID"] as? String,
                revision: (snapshot["revision"] as? NSNumber)?.uint64Value
            )
            object["injuryEvent"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(event))
            let fixture = try JSONDecoder().decode(
                ProCareerResult.self,
                from: JSONSerialization.data(withJSONObject: object)
            )
            updatePersisted {
                $0.result = fixture
                $0.gameResume = nil
                $0.sourceHighSchoolCareerID = nil
                $0.careerOrigin = .direct
                $0.pendingInjuryEvent = event
                $0.acknowledgedInjuryEventID = nil
            }
            selectedPlan = nil
            pendingGains = []
            lastSummary = nil
            feedbackCue = .setback
            feedbackTrigger += 1
            loadState = .ready
            return save()
        } catch {
            loadState = .failed(error.localizedDescription)
            return false
        }
    }
#endif

    @discardableResult
    func deleteCareer() -> Bool {
        // clear() 대신 묘비 — 고교 쪽과 같은 이유(iCloud 부활 방지).
        // 삭제 API의 성공은 "무언가를 실제로 지웠는가"가 아니라 "호출 뒤 진행이 없는가"다.
        // 복원이 끝나 빈 저장소임이 확정된 경우는 성공한 no-op으로 돌려, 전체 초기화 같은
        // 호출자가 `false`를 저장 오류로 오인해 화면 복귀를 건너뛰지 않게 한다.
        // loading/failed의 nil은 미확인·손상 저장일 수 있으므로 여전히 실패다.
        guard let deletedResult = result else { return loadState == .needsSetup }
        // The tombstone must stay in the same generation as the career it deletes. A legacy
        // production build may replace a schema-2 tombstone with its next legacy career, while a
        // schema-2 writer must never replace a schema-3 journey tombstone. Capture this before the
        // in-memory result is cleared below.
        let tombstoneSchemaVersion = ProCareerPersistence.schemaVersion(for: deletedResult)
        let tombstone = ProCareerPersistence.nextRevision(
            after: syncedRevision,
            atLeast: deletedResult.snapshot.revision
        )
        var tombstoneState = ProCareerPersistedState.empty
        tombstoneState.syncedRevision = tombstone
        guard canWrite(),
              let data = ProCareerPersistence.encode(
            ProCareerPersistence.record(
                from: tombstoneState,
                deletedRevision: tombstone,
                schemaVersion: tombstoneSchemaVersion,
                syncRevision: tombstone
            )
        ), sync.write(data) else {
            // 은퇴 저장은 이미 고교 쪽 유산에 접혔지만 tombstone만 실패한 상태다. `.failed`로
            // 바꾸면 AppShell이 고교 탭을 다시 열어 사용자가 다음 선수까지 진행할 수 있고,
            // 남은 프로 저장은 이후 현재 고교와 연결할 길을 잃는다. 완료 화면을 그대로
            // 유지해 같은 CTA가 삭제만 재시도하게 한다.
            let message = "프로 기록 정리를 저장하지 못했습니다. 저장 공간을 확인한 뒤 다시 눌러 주세요."
            lastSummary = message
            feedbackCue = .setback
            feedbackTrigger += 1
            // 유효한 프로 스냅숏이 있을 때만 완료 화면을 유지할 수 있다. 커리어 시작 저장도
            // 실패해 result가 nil인 상태를 `.ready`로 만들면 프로/고교 양쪽이 가려진다.
            loadState = result == nil ? .failed(message) : .ready
            return false
        }
        sync.discardRecoveryCopies()
        applyTombstone(revision: tombstone)
        lastSummary = nil
        loadState = .needsSetup
        return true
    }
}
