import Foundation
import SimulationCore

extension HighSchoolCareerStore {
    // MARK: - 수명 주기

    func restoreOrCreate() {
        guard result == nil else { return }
        applyRestoreOutcome(restore())
    }

#if DEBUG
    /// 드래프트 버튼을 누르기 직전의 확정 미지명 XCUITest 픽스처.
    ///
    /// 실제 엔진으로 약한 3년을 끝까지 진행한 뒤, 복사본만 먼저 지명 처리해 미지명 결과를
    /// 검증한다. 화면에는 원래의 `.draft` 상태를 설치하므로 촬영에서도 사용자가 누르는
    /// `hs.draft.resolve`가 실제 판정을 수행하며 RNG·저장·결과 경로를 우회하지 않는다.
    @discardableResult
    func installUndraftedDraftFixtureForUITesting(seed: String = "17") -> Bool {
        let fixtureEngine = HighSchoolCareerEngine()
        do {
            var fixture = try fixtureEngine.start(.init(
                seed: seed,
                presetID: "precision_commander",
                identity: PlayerIdentitySnapshot(
                    name: "Alex Han", throwingHand: .right, bodyType: .balanced, region: "서울"
                )
            ))
            let startingPitcher = fixture.snapshot.pitcher
            fixture = try fixtureEngine.completePrologue(.init(
                seed: fixture.nextSeed,
                state: fixture.snapshot
            ))
            fixture = try fixtureEngine.chooseSchool(.init(
                seed: fixture.nextSeed,
                state: fixture.snapshot,
                schoolID: .miraeAnalytics
            ))

            fixtureLoop: for _ in 0..<100 {
                switch fixture.snapshot.phase {
                case .training:
                    fixture = try fixtureEngine.commitTraining(.init(
                        seed: fixture.nextSeed,
                        state: fixture.snapshot,
                        focus: fixture.snapshot.school?.strength ?? .command,
                        intensity: .light
                    ))
                case .relationship:
                    fixture = try fixtureEngine.resolveRelationship(.init(
                        seed: fixture.nextSeed,
                        state: fixture.snapshot,
                        response: .challenge
                    ))
                case .importantGame:
                    let number = fixture.snapshot.performance.importantGamesCompleted + 1
                    fixture = try fixtureEngine.recordImportantGame(.init(
                        seed: fixture.nextSeed,
                        state: fixture.snapshot,
                        report: .init(
                            scenarioNumber: number,
                            pitches: 18,
                            strikeouts: 0,
                            walks: 5,
                            runsAllowed: 7,
                            expectedDamage: 1_200,
                            actualDamage: 4_500,
                            recommendationAccepted: 0
                        )
                    ))
                case .awakening:
                    guard let awakening = fixture.snapshot.awakeningOptions.first else {
                        throw NSError(
                            domain: "BaseballIOS.UITestFixture",
                            code: 2,
                            userInfo: [NSLocalizedDescriptionKey: "각성 선택지가 없습니다."]
                        )
                    }
                    fixture = try fixtureEngine.chooseAwakening(.init(
                        seed: fixture.nextSeed,
                        state: fixture.snapshot,
                        awakening: awakening
                    ))
                case .chapterReview:
                    fixture = try fixtureEngine.advanceChapter(.init(
                        seed: fixture.nextSeed,
                        state: fixture.snapshot
                    ))
                case .draft:
                    break fixtureLoop
                case .legacy, .completed:
                    loadState = .failed("UI 테스트용 약한 고교 기록이 드래프트 직전 상태를 지나쳤습니다.")
                    return false
                case .prologue, .schoolSelection:
                    loadState = .failed("UI 테스트용 미지명 픽스처가 이전 국면으로 돌아갔습니다.")
                    return false
                }
            }

            guard fixture.snapshot.phase == .draft else {
                loadState = .failed("UI 테스트용 미지명 픽스처가 100단계 안에 드래프트에 도달하지 못했습니다.")
                return false
            }
            let verified = try fixtureEngine.resolveDraft(.init(
                seed: fixture.nextSeed,
                state: fixture.snapshot
            ))
            guard verified.snapshot.phase == .legacy,
                  verified.snapshot.draftResult?.outcome == .undrafted else {
                loadState = .failed("UI 테스트용 약한 고교 기록이 미지명 결과를 만들지 못했습니다.")
                return false
            }

            updatePersisted {
                $0.result = fixture
                $0.careerStartingPitcher = startingPitcher
                $0.enteredProCareerID = nil
            }
            lastSummary = "UI 테스트용 미지명 직전 상태를 준비했습니다."
            feedbackCue = .neutral
            feedbackTrigger += 1
            loadState = .ready
            guard save() else {
                updatePersisted {
                    $0.result = nil
                    $0.careerStartingPitcher = nil
                }
                loadState = .failed("UI 테스트용 미지명 직전 상태를 저장하지 못했습니다.")
                return false
            }
            return true
        } catch {
            updatePersisted {
                $0.result = nil
                $0.careerStartingPitcher = nil
            }
            loadState = .failed("UI 테스트용 미지명 직전 상태를 만들지 못했습니다: \(error.localizedDescription)")
            return false
        }
    }

    /// 지명 완료 화면에서 시작하는 XCUITest 픽스처.
    ///
    /// 프로 화면 전환을 검증하는 테스트가 3년 자동 플레이의 난이도·드래프트 운까지 함께
    /// 떠안으면 밸런스 조정 때마다 무관한 테스트가 깨진다. 이 픽스처는 실제 고교 엔진을
    /// 모든 국면에 통과시키되, 중요 경기만 강한 고정 기록으로 넣어 결과를 확실한 지명으로
    /// 만든다. 호출 전 `deleteCareer()`로 격리하는 것은 앱의 UI 테스트 부트스트랩이 맡는다.
    @discardableResult
    func installDraftedCareerFixtureForUITesting(seed: String = "20260723") -> Bool {
        let fixtureEngine = HighSchoolCareerEngine()
        do {
            var fixture = try fixtureEngine.start(.init(
                seed: seed,
                presetID: "power_prospect",
                identity: PlayerIdentitySnapshot(
                    name: "Jordan Lee", throwingHand: .right, bodyType: .balanced, region: "서울"
                )
            ))
            let startingPitcher = fixture.snapshot.pitcher
            fixture = try fixtureEngine.completePrologue(.init(
                seed: fixture.nextSeed,
                state: fixture.snapshot
            ))
            fixture = try fixtureEngine.chooseSchool(.init(
                seed: fixture.nextSeed,
                state: fixture.snapshot,
                schoolID: .haedongPower
            ))

            fixtureLoop: for _ in 0..<100 {
                switch fixture.snapshot.phase {
                case .training:
                    fixture = try fixtureEngine.commitTraining(.init(
                        seed: fixture.nextSeed,
                        state: fixture.snapshot,
                        focus: .velocity,
                        intensity: .intensive
                    ))
                case .relationship:
                    fixture = try fixtureEngine.resolveRelationship(.init(
                        seed: fixture.nextSeed,
                        state: fixture.snapshot,
                        response: .listen
                    ))
                case .importantGame:
                    let number = fixture.snapshot.performance.importantGamesCompleted + 1
                    fixture = try fixtureEngine.recordImportantGame(.init(
                        seed: fixture.nextSeed,
                        state: fixture.snapshot,
                        report: .init(
                            scenarioNumber: number,
                            pitches: 18,
                            strikeouts: 4,
                            walks: 0,
                            runsAllowed: 0,
                            expectedDamage: 380,
                            actualDamage: 120,
                            recommendationAccepted: 10,
                            outs: 3
                        )
                    ))
                case .awakening:
                    guard let awakening = fixture.snapshot.awakeningOptions.first else {
                        throw NSError(
                            domain: "BaseballIOS.UITestFixture",
                            code: 1,
                            userInfo: [NSLocalizedDescriptionKey: "각성 선택지가 없습니다."]
                        )
                    }
                    fixture = try fixtureEngine.chooseAwakening(.init(
                        seed: fixture.nextSeed,
                        state: fixture.snapshot,
                        awakening: awakening
                    ))
                case .chapterReview:
                    fixture = try fixtureEngine.advanceChapter(.init(
                        seed: fixture.nextSeed,
                        state: fixture.snapshot
                    ))
                case .draft:
                    fixture = try fixtureEngine.resolveDraft(.init(
                        seed: fixture.nextSeed,
                        state: fixture.snapshot
                    ))
                case .completed:
                    break fixtureLoop
                case .legacy:
                    loadState = .failed("UI 테스트용 강한 고교 기록이 지명에 실패했습니다.")
                    return false
                case .prologue, .schoolSelection:
                    loadState = .failed("UI 테스트용 고교 픽스처가 이전 국면으로 돌아갔습니다.")
                    return false
                }
            }

            guard fixture.snapshot.phase == .completed,
                  fixture.snapshot.draftResult?.outcome == .drafted else {
                loadState = .failed("UI 테스트용 고교 픽스처가 100단계 안에 지명을 마치지 못했습니다.")
                return false
            }

            updatePersisted {
                $0.result = fixture
                $0.careerStartingPitcher = startingPitcher
                $0.enteredProCareerID = nil
            }
            lastSummary = "UI 테스트용 지명 완료 상태를 준비했습니다."
            feedbackCue = .success
            feedbackTrigger += 1
            loadState = .ready
            guard save() else {
                updatePersisted {
                    $0.result = nil
                    $0.careerStartingPitcher = nil
                }
                loadState = .failed("UI 테스트용 지명 상태를 저장하지 못했습니다.")
                return false
            }
            return true
        } catch {
            updatePersisted {
                $0.result = nil
                $0.careerStartingPitcher = nil
            }
            loadState = .failed("UI 테스트용 지명 상태를 만들지 못했습니다: \(error.localizedDescription)")
            return false
        }
    }
#endif

    private func applyRestoreOutcome(_ outcome: RestoreOutcome) {
        switch outcome {
        case .live(let recoveredFromBackup):
            loadState = .ready
            _ = retryPendingGameCompletion()
            if recoveredFromBackup {
                lastSummary = "현재 환생 기록을 읽지 못해 직전 정상 백업으로 복구했습니다."
                feedbackCue = .success
                feedbackTrigger += 1
            }
        case .needsSetup:
            loadState = .needsSetup
        case .unavailable:
            loadState = .failed(Self.unreadableSaveMessage)
        }
    }

    /// 지난 회차의 설정. 원버튼 환생("같은 설정으로 다시")의 재료다.
    struct LastSetup: Codable, Equatable {
        var presetID: String
        var playerName: String
        var region: String
        var harshness: String
        var karmas: [KarmaID]
        var soulDomain: SoulDomain?
    }

    var lastSetup: LastSetup? {
        get {
            UserDefaults.standard.data(forKey: "baseball.lastSetup")
                .flatMap { try? JSONDecoder().decode(LastSetup.self, from: $0) }
        }
        set {
            guard let newValue, let data = try? JSONEncoder().encode(newValue) else {
                UserDefaults.standard.removeObject(forKey: "baseball.lastSetup")
                return
            }
            UserDefaults.standard.set(data, forKey: "baseball.lastSetup")
        }
    }

    func startCareer(
        preset: PitcherPresetSnapshot,
        playerName: String,
        region: String = "서울",
        difficulty: CareerDifficultySnapshot = .standard,
        karmas: [KarmaID] = [],
        soulDomain: SoulDomain? = nil,
        soulBoosts: [SoulBoostID] = [],
        signatureLegacyID: CareerSignatureLegacyID? = nil,
        seedOverride: String? = nil,
        challengeLifeNumber: Int? = nil,
        /// 어느 입구로 회차를 시작했는가(`setup_flow` / `quick_rebirth` / `recap`).
        /// 환생 전환율을 입구별로 갈라 봐야 어느 마찰을 없앤 것이 실제로 들었는지 안다.
        entryPoint: String = "setup_flow"
    ) {
        // 시드 가드 — 오타 하나가 커널 오류 화면(그리고 예전에는 저장 삭제)으로
        // 이어지면 안 된다. 여기서 정중히 되돌린다(4차 패널 P0).
        let trimmedSeed = seedOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedSeed, !trimmedSeed.isEmpty, UInt64(trimmedSeed) == nil {
            lastSummary = "시드는 카드에 적힌 숫자만 입력할 수 있습니다. 다시 확인해 주세요."
            feedbackCue = .setback
            feedbackTrigger += 1
            return
        }
        let isChallenge = challengeLifeNumber != nil
        let previousInheritance = inheritance
        let previousLastSetup = lastSetup
        let previousBondMemories = bondMemories
        let previousRebirthEventIDs = rebirthEventIDs
        if isChallenge {} else {
        lastSetup = LastSetup(
            presetID: preset.id, playerName: playerName, region: region,
            harshness: difficulty.careerHarshness.rawValue, karmas: karmas, soulDomain: soulDomain
        )
        }
        let trimmed = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? preset.pitcher.name : trimmed
        let careerSeed = trimmedSeed?.isEmpty == false
            ? trimmedSeed!
            : String(UInt64.random(in: 1...UInt64.max))
        let lifeNumber = challengeLifeNumber ?? inheritance.lifeNumber
        let identity = PlayerIdentitySnapshot(
            name: name,
            throwingHand: preset.pitcher.throwingHand,
            bodyType: .balanced,
            // 코어가 모르는 지역이 오면 서울로 받는다 — 학교 이름이 조용히 서울로 바뀌는
            // 것보다, 여기서 한 번 거르는 쪽이 원인을 찾기 쉽다.
            region: HighSchoolCareerEngine.regions.contains(region) ? region : "서울",
            appearanceSeed: PlayerAppearanceSeed.make(
                careerSeed: careerSeed,
                lifeNumber: lifeNumber
            )
        )
        var carried = inheritance
        // 직전 프로 커리어 영수증은 그 선수의 결말을 프로 tombstone 삭제까지 멱등하게
        // 지키는 임시 표식이다. 새 고교 선수가 durable하게 시작되는 순간에는 더 이상
        // 같은 프로 저장을 현재 선수와 결합할 수 없으므로 비워 다음 프로 기록을 받을 수 있다.
        if !isChallenge {
            carried.creditedProCareerID = nil
        }
        carried.karmas = karmas
        let requestedSignatureLegacyID = signatureLegacyID ?? carried.equippedSignatureLegacyID
        let availableLegacyIDs = Set((carried.unlockedSignatureLegacies ?? []).map(\.id))
        let equippedSignatureLegacyID: CareerSignatureLegacyID? = if isChallenge {
            nil
        } else if let requestedSignatureLegacyID,
                  availableLegacyIDs.contains(requestedSignatureLegacyID) {
            requestedSignatureLegacyID
        } else {
            carried.equippedSignatureLegacyID.flatMap {
                availableLegacyIDs.contains($0) ? $0 : nil
            }
        }
        carried.equippedSignatureLegacyID = equippedSignatureLegacyID
        let lineageLoadout = isChallenge ? nil : Self.lineageLoadout(
            equippedLegacyID: equippedSignatureLegacyID,
            archive: archive
        )
        let previousLife = isChallenge ? nil : archive.first(where: { $0.lifeNumber < carried.lifeNumber })
        let rebirthEcho = previousLife.map {
            Self.rebirthEcho(
                from: $0,
                inheritedMemoryCount: carried.memories.count,
                inheritedLegacyID: equippedSignatureLegacyID,
                automaticInheritanceTotal: carried.automaticSoulTotal,
                recentEventIDs: Self.recentRebirthEventIDs(from: archive)
            )
        }
        // 영혼 상점 정산 — 부스트 비용은 지갑 잔액에서만 차감한다. 자동 성장 누적은
        // 별도 원장이라 구매나 프로 보너스로 조용히 움직이지 않는다.
        let boostCost = soulBoosts.reduce(0) { $0 + $1.cost }
        let purchased = boostCost <= carried.soulPoints ? soulBoosts : []
        // 차감 전에 두 누적 원장을 고정한다. nil인 옛 저장은 기존 단일 총량 의미를
        // 승계하고, 이후부터 자동 성장과 지갑 경제를 분리한다.
        let automaticSoulTotal = carried.automaticSoulTotal
        carried.soulTotalEarned = carried.soulTotal
        carried.automaticSoulEarned = automaticSoulTotal
        carried.soulPoints -= purchased.reduce(0) { $0 + $1.cost }
        do {
            let created = try engine.start(
                .init(
                    // 시드 입력은 커뮤니티 도전("이 시드로 지명 가능?")의 입구다.
                    seed: careerSeed,
                    presetID: preset.id,
                    // challenge 모드는 카드의 회차를 그대로 쓴다 — 판(재능·바람·일정)은
                    // careerID("시드-회차")의 함수라 회차가 달라지면 다른 판이다.
                    lifeNumber: challengeLifeNumber ?? carried.lifeNumber,
                    // challenge 모드는 맨몸이다: 계승·기억·카르마·상점이 실리면 같은 판의
                    // 비교가 성립하지 않는다.
                    inheritedSoulPoints: isChallenge ? 0 : carried.automaticSoulTotal,
                    inheritedSoulDomain: isChallenge || carried.automaticSoulTotal == 0
                        ? nil : soulDomain,
                    inheritedMemories: isChallenge ? [] : carried.memories,
                    identity: identity,
                    difficulty: difficulty,
                    karmas: isChallenge ? [] : karmas,
                    soulBoosts: isChallenge || purchased.isEmpty ? nil : purchased,
                    inheritedSoulTotal: isChallenge ? 0 : carried.automaticSoulTotal,
                    signatureLegacyID: equippedSignatureLegacyID,
                    inheritanceRulesVersion: isChallenge ? nil : carried.inheritanceRulesVersion,
                    rebirthEcho: isChallenge ? nil : rebirthEcho,
                    lineageLoadout: lineageLoadout
                )
            )
            updatePersisted {
                if !isChallenge { $0.inheritance = carried }
                $0.nicknames = []
                $0.chronicle = []
                $0.bondMemories = []
                $0.rebirthEventIDs = []
                $0.chapterStartStrikeouts = 0
                $0.goalCelebratedChapter = nil
                $0.chapterGains = [:]
                $0.chapterTrainingCount = 0
                $0.responseTally = ResponseTally()
                $0.careerStartingPitcher = created.snapshot.pitcher
                $0.signatureLegacyRulesVersion = isChallenge ? nil : Self.currentSignatureLegacyRulesVersion
                $0.frozenSignatureLegacyCandidates = nil
                $0.selectedSignatureLegacyID = nil
                $0.result = created
                $0.challengeCareerID = isChallenge ? created.snapshot.careerID : nil
            }
            let carriedLegacyCopy: String
            if equippedSignatureLegacyID != nil, carried.memories.isEmpty {
                carriedLegacyCopy = "대표 유산 하나"
            } else if equippedSignatureLegacyID != nil {
                carriedLegacyCopy = "기억 \(carried.memories.count)장과 대표 유산 하나"
            } else {
                carriedLegacyCopy = "기억 \(carried.memories.count)장"
            }
            lastSummary = isChallenge
                ? "기록 없는 도전 — 이 판의 결과는 선수 기록과 계승에 남지 않습니다."
                : carried.lifeNumber > 1
                ? "\(carried.lifeNumber)번째 선수. \(carriedLegacyCopy)로 다시 시작합니다."
                : "고교 첫 해가 시작됩니다."
            feedbackCue = .success
            feedbackTrigger += 1
            loadState = .ready
            guard save() else {
                updatePersisted {
                    $0.result = nil
                    $0.inheritance = previousInheritance
                    $0.bondMemories = previousBondMemories
                    $0.rebirthEventIDs = previousRebirthEventIDs
                    $0.careerStartingPitcher = nil
                    $0.signatureLegacyRulesVersion = nil
                    $0.frozenSignatureLegacyCandidates = nil
                    $0.selectedSignatureLegacyID = nil
                    $0.challengeCareerID = nil
                }
                lastSetup = previousLastSetup
                loadState = .failed("새 선수의 시작을 저장하지 못했습니다. 저장 공간을 확인한 뒤 다시 시도해 주세요.")
                return
            }
            if !isChallenge {
                let reusedName = previousLife.map {
                    $0.playerName.trimmingCharacters(in: .whitespacesAndNewlines)
                        .localizedCaseInsensitiveCompare(name) == .orderedSame
                } ?? false
                let uniqueAppearance = previousLife.map {
                    $0.portraitSeed != created.snapshot.identity.portraitSeed
                } ?? true
                GameAnalytics.logOnce(
                    .lineageIdentityShown,
                    scope: "lineage-identity:\(created.snapshot.careerID)",
                    properties: [
                        "life_number": created.snapshot.lifeNumber,
                        "entry_point": entryPoint,
                        "reused_name": reusedName,
                        "has_unique_appearance": uniqueAppearance,
                    ]
                )
            }
            // 같은 결정론 시드를 다시 시작해도 지난 로컬 보조 상태가 새 회차에 붙지
            // 않는다. durable save 뒤에만 로컬 보조 상태와 외부 퍼널을 갱신한다.
            UserDefaults.standard.removeObject(forKey: pledgeKey(created.snapshot.careerID))
            UserDefaults.standard.removeObject(forKey: pledgeRulesVersionKey(created.snapshot.careerID))
            UserDefaults.standard.removeObject(forKey: rivalLedgerKey(created.snapshot.careerID))
            if !isChallenge {
                GameAnalytics.logOnce(.onboardingCompleted)
                if let equippedSignatureLegacyID {
                    let definition = CareerSignatureLegacy.definition(for: equippedSignatureLegacyID)
                    GameAnalytics.log(.signatureLegacyEquipped, [
                        "legacy_id": equippedSignatureLegacyID.rawValue,
                        "family": definition.family.rawValue,
                        "life_number": carried.lifeNumber,
                        "total_rating_bonus": definition.effect.totalRatingBonus,
                        "inheritance_rules_version": carried.inheritanceRulesVersion ?? 0,
                        "soul_total": carried.automaticSoulTotal,
                        "soul_wallet": carried.soulPoints,
                        "soul_lifetime_earned": carried.soulTotal,
                        "soul_applied": HighSchoolCareerEngine.appliedInheritance(
                            for: carried.automaticSoulTotal,
                            storedRulesVersion: carried.inheritanceRulesVersion
                        ),
                    ])
                    if let lineageLoadout {
                        GameAnalytics.log(.lineageMasteryEquipped, [
                            "legacy_id": lineageLoadout.legacyID.rawValue,
                            "family": definition.family.rawValue,
                            "rank": lineageLoadout.masteryRank,
                            "contributions": lineageLoadout.contributions,
                            "source_life_number": lineageLoadout.sourceLifeNumber ?? 0,
                            "life_number": carried.lifeNumber,
                            "total_rating_bonus": definition.effect.totalRatingBonus,
                        ])
                    }
                }
                if carried.lifeNumber > 1 {
                    GameAnalytics.log(.rebirthStarted, [
                        "life_number": carried.lifeNumber,
                        "entry_point": entryPoint,
                        "selected_legacy_id": equippedSignatureLegacyID?.rawValue ?? "pre_feature_memory_bridge",
                        "inheritance_rules_version": carried.inheritanceRulesVersion ?? 0,
                        "soul_total": carried.automaticSoulTotal,
                        "soul_wallet": carried.soulPoints,
                        "soul_lifetime_earned": carried.soulTotal,
                        "soul_applied": HighSchoolCareerEngine.appliedInheritance(
                            for: carried.automaticSoulTotal,
                            storedRulesVersion: carried.inheritanceRulesVersion
                        ),
                    ])
                    weekly.record(.nextRunStarted)
                }
                // 3회차를 시작한다 = 환생 루프를 스스로 두 번 돌았다.
                if carried.lifeNumber >= 3, ReviewPrompt.shouldAsk(.thirdLife) {
                    reviewMoment += 1
                }
                AchievementStore.shared.record(AchievementRules.fromLifeNumber(carried.lifeNumber))
                AchievementStore.shared.submit(LeaderboardRules.scores(lifeNumber: carried.lifeNumber))
            }
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    /// Replays only the deterministic start pipeline to explain what the lineage changed. The
    /// comparison is display-only and never writes a save or consumes the active career RNG.
    func inheritedStartComparison(
        for state: HighSchoolCareerSnapshot,
        previous: LifeRecord
    ) -> InheritedStartComparison? {
        guard state.phase == .prologue,
              let previousFinal = previous.abilityFinal,
              let setup = lastSetup,
              let preset = PitcherPresetCatalog.all.first(where: { $0.id == setup.presetID }),
              let seed = Self.careerSeed(from: state.careerID, lifeNumber: state.lifeNumber)
        else { return nil }

        let purchasedBoosts = (state.soulBoosts ?? []).compactMap(SoulBoostID.init(rawValue:))
        let common = (
            seed: seed,
            presetID: preset.id,
            lifeNumber: state.lifeNumber,
            identity: state.identity,
            difficulty: state.difficulty,
            karmas: state.karmas
        )

        do {
            let bare = try engine.start(.init(
                seed: common.seed,
                presetID: common.presetID,
                lifeNumber: common.lifeNumber,
                identity: common.identity,
                difficulty: common.difficulty,
                karmas: common.karmas
            )).snapshot.pitcher
            let soulAndMemories = try engine.start(.init(
                seed: common.seed,
                presetID: common.presetID,
                lifeNumber: common.lifeNumber,
                inheritedSoulPoints: inheritance.automaticSoulTotal,
                inheritedSoulDomain: inheritance.automaticSoulTotal == 0 ? nil : setup.soulDomain,
                inheritedMemories: inheritance.memories,
                identity: common.identity,
                difficulty: common.difficulty,
                karmas: common.karmas,
                inheritedSoulTotal: inheritance.automaticSoulTotal,
                signatureLegacyID: nil,
                inheritanceRulesVersion: inheritance.inheritanceRulesVersion
            )).snapshot.pitcher
            let boosted = try engine.start(.init(
                seed: common.seed,
                presetID: common.presetID,
                lifeNumber: common.lifeNumber,
                inheritedSoulPoints: inheritance.automaticSoulTotal,
                inheritedSoulDomain: inheritance.automaticSoulTotal == 0 ? nil : setup.soulDomain,
                inheritedMemories: inheritance.memories,
                identity: common.identity,
                difficulty: common.difficulty,
                karmas: common.karmas,
                soulBoosts: purchasedBoosts.isEmpty ? nil : purchasedBoosts,
                inheritedSoulTotal: inheritance.automaticSoulTotal,
                signatureLegacyID: nil,
                inheritanceRulesVersion: inheritance.inheritanceRulesVersion
            )).snapshot.pitcher
            let signatureOnly = try engine.start(.init(
                seed: common.seed,
                presetID: common.presetID,
                lifeNumber: common.lifeNumber,
                inheritedSoulPoints: inheritance.automaticSoulTotal,
                inheritedSoulDomain: inheritance.automaticSoulTotal == 0 ? nil : setup.soulDomain,
                inheritedMemories: inheritance.memories,
                identity: common.identity,
                difficulty: common.difficulty,
                karmas: common.karmas,
                soulBoosts: purchasedBoosts.isEmpty ? nil : purchasedBoosts,
                inheritedSoulTotal: inheritance.automaticSoulTotal,
                signatureLegacyID: inheritance.equippedSignatureLegacyID,
                inheritanceRulesVersion: inheritance.inheritanceRulesVersion
            )).snapshot.pitcher

            let current = LifeRecord.AbilityLine(state.pitcher)
            let bareLine = LifeRecord.AbilityLine(bare)
            let soulLine = LifeRecord.AbilityLine(soulAndMemories)
            let boostLine = LifeRecord.AbilityLine(boosted)
            var sources: [InheritedStartComparison.Source] = []
            let soulDelta = soulLine.total - bareLine.total
            if soulDelta != 0 {
                sources.append(.init(
                    id: "soul",
                    ratingDelta: soulDelta,
                    signatureLegacyID: nil
                ))
            }
            let boostDelta = boostLine.total - soulLine.total
            if boostDelta != 0 {
                sources.append(.init(
                    id: "boost",
                    ratingDelta: boostDelta,
                    signatureLegacyID: nil
                ))
            }
            let signatureLine = LifeRecord.AbilityLine(signatureOnly)
            let signatureDelta = signatureLine.total - boostLine.total
            if signatureDelta != 0, let legacy = inheritance.equippedSignatureLegacy {
                sources.append(.init(
                    id: "signature",
                    ratingDelta: signatureDelta,
                    signatureLegacyID: legacy.id
                ))
            }
            let masteryDelta = current.total - signatureLine.total
            if masteryDelta != 0, let legacyID = state.lineageLoadout?.legacyID {
                sources.append(.init(
                    id: "mastery",
                    ratingDelta: masteryDelta,
                    signatureLegacyID: legacyID
                ))
            }
            return InheritedStartComparison(
                previousName: previous.playerName,
                careerID: state.careerID,
                previous: previousFinal,
                current: current,
                sources: sources
            )
        } catch {
            return nil
        }
    }

    nonisolated private static func careerSeed(from careerID: String, lifeNumber: Int) -> String? {
        let prefix = "career-"
        let suffix = "-life-\(lifeNumber)"
        guard careerID.hasPrefix(prefix), careerID.hasSuffix(suffix) else { return nil }
        let start = careerID.index(careerID.startIndex, offsetBy: prefix.count)
        let end = careerID.index(careerID.endIndex, offsetBy: -suffix.count)
        let seed = String(careerID[start..<end])
        return UInt64(seed) == nil ? nil : seed
    }

    /// 실패 화면의 비파괴 출구. 메모리에 진행이 있으면 돌아가고, 시작 실패면 다시 복원한다.
    func returnToSetup() {
        if result != nil {
            loadState = .ready
            return
        }
        loadState = .loading
        applyRestoreOutcome(restore())
    }

    var isChallengeRun: Bool {
        guard let result, let challengeCareerID else { return false }
        return result.snapshot.careerID == challengeCareerID
    }

    /// nil은 대표 유산 기능 도입 전에 시작한 진행이다. 그 회차는 당시 기억 규칙으로 끝내고,
    /// 다음 새 회차부터 현재 규칙을 저장해 사용한다.
    var usesSignatureLegacyRules: Bool {
        !isChallengeRun && Self.usesSignatureLegacyRules(storedRulesVersion: signatureLegacyRulesVersion)
    }

    nonisolated static func usesSignatureLegacyRules(storedRulesVersion: Int?) -> Bool {
        storedRulesVersion != nil
    }

    /// 기록·계승이 남지 않는 판은 주간 야구혼으로도 환산하지 않는다.
    var countsTowardWeeklyProgram: Bool { !isChallengeRun }

    /// challenge 모드를 닫는다. 아카이브·계승·야구혼 어디에도 반영하지 않는다.
    func endChallengeRun() {
        updatePersisted {
            $0.result = nil
            $0.pendingGameCompletion = nil
            $0.selectedSignatureLegacyID = nil
            $0.careerStartingPitcher = nil
            $0.signatureLegacyRulesVersion = nil
            $0.frozenSignatureLegacyCandidates = nil
            $0.challengeCareerID = nil
        }
        pitchSession = nil
        tutorialSession = nil
        pendingGains = []
        trainingReceipt = nil
        loadState = .needsSetup
        save()
    }

    @discardableResult
    func deleteCareer() -> Bool {
        let deletedCareerID = result?.snapshot.careerID
        // 메모리와 보조 UserDefaults를 지우기 전에 더 높은 리비전의 묘비를 먼저 내린다.
        // 실패하면 현재 화면·진행·빠른 시작 재료가 모두 그대로여야 같은 버튼으로 재시도할 수 있다.
        let tombstoneRevision = HighSchoolCareerPersistence.nextRevision(
            after: savedRevision,
            atLeast: result?.snapshot.revision ?? 0
        )
        var tombstoneState = HighSchoolCareerPersistedState.empty
        tombstoneState.savedRevision = tombstoneRevision
        let tombstone = HighSchoolCareerPersistence.record(
            from: tombstoneState,
            currentCareerRetention: nil,
            revision: tombstoneRevision
        )
        guard let data = HighSchoolCareerPersistence.encode(tombstone),
              saveWriter?(data) ?? sync.write(data) else { return false }
        sync.discardRecoveryCopies()
        replacePersisted(tombstoneState)
        clearLiveSession()
        lastSetup = nil
        forgetLocalCareerKeys(deletedCareerID)
        // clear() 대신 **묘비를 쓴다.** iCloud 키-값 저장은 결국적 일관성이라 지운
        // 자리에 업로드 지연분·다른 기기의 옛 저장본이 되살아난다 — "모든 진행 삭제가
        // 가끔 안 먹힌다"의 원인. 리비전 +1의 빈 레코드는 어떤 옛 사본과 만나도 이긴다.
        loadState = .needsSetup
        return true
    }

}
