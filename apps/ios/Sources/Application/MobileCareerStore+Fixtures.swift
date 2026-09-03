import Foundation
import SimulationCore
import BaseballIOSDomain

extension MobileCareerStore {
#if DEBUG
    /// 프로 1시즌 6주차 결정 대기.
    ///
    /// `CareerBootstrap.startCareer`로 고정 시드 스냅샷을 만든 뒤, 주차·국면·pending
    /// 결정만 JSON으로 덮어 서명한다. 주간 진행으로 커리어 RNG를 소비하지 않는다.
    @discardableResult
    func installSeasonDecisionFixtureForUITesting() -> Bool {
        do {
            let preset = PitcherPresetCatalog.all[0]
            let base = try CareerBootstrap.startCareer(
                preset: preset,
                playerName: "민서준",
                seed: 202_609_03,
                startingRepertoire: PitchLearningRules.recommendedSelection(presetID: preset.id),
                engine: engine
            )
            var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(base.snapshot)) as! [String: Any]
            object["phase"] = ProCareerPhase.seasonDecision.rawValue
            object["season"] = 1
            object["week"] = 6
            object["seasonSegment"] = ProSeasonSegment.firstHalf.rawValue
            let decision = ProSeasonDecision(
                id: "season-1-week-6-catcher_game_plan",
                type: .catcherGamePlan,
                season: 1,
                week: 6,
                title: "포수와 경기 계획",
                detail: "다음 등판의 구종 순서와 승부 방식을 정합니다.",
                choices: [
                    ProSeasonDecisionChoice(
                        id: "catcher_game_plan.battery_plan",
                        title: "포수와 함께 짠다",
                        detail: "배터리 호흡과 코스 실행을 우선합니다.",
                        effect: .init(commandDelta: 1, catcherTrustDelta: 8, fatigueDelta: 4)
                    ),
                    ProSeasonDecisionChoice(
                        id: "catcher_game_plan.staff_report",
                        title: "감독 보고서를 따른다",
                        detail: "벤치가 원하는 경기 운영에 맞춥니다.",
                        effect: .init(managerTrustDelta: 7, catcherTrustDelta: 1, fatigueDelta: 3)
                    ),
                    ProSeasonDecisionChoice(
                        id: "catcher_game_plan.own_sequence",
                        title: "내 공을 밀어붙인다",
                        detail: "변화구 감각을 얻는 대신 두 사람의 믿음을 겁니다.",
                        effect: .init(movementDelta: 1, managerTrustDelta: -2, catcherTrustDelta: -3, fatigueDelta: 5)
                    ),
                ]
            )
            object["pendingDecision"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(decision))
            let decoded = try JSONDecoder().decode(
                ProCareerSnapshot.self,
                from: JSONSerialization.data(withJSONObject: object)
            )
            let signed = engine.resignFixtureForTesting(decoded)
            let fixture = ProCareerResult(
                snapshot: signed,
                nextSeed: base.nextSeed,
                events: ["ui_season_decision_fixture"]
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
    /// 프로 1시즌 24주차, 시즌 리뷰 대기. 계약을 실제로 수락한 상태라 `reviewSeason` →
    /// 결산 → 오프시즌까지 엔진 검증을 통과한다(기존 포스트시즌 픽스처는 계약이 없어
    /// `missing_contract`로 막혔다 — 4차 검수). 주간 진행 RNG는 소비하지 않는다.
    @discardableResult
    func installSeasonReviewFixtureForUITesting() -> Bool {
        do {
            let preset = PitcherPresetCatalog.all[1]
            let base = try CareerBootstrap.startCareer(
                preset: preset,
                playerName: "민서준",
                seed: 202_609_04,
                startingRepertoire: PitchLearningRules.recommendedSelection(presetID: preset.id),
                engine: engine
            )
            guard let market = base.snapshot.journeyState?.pendingContractMarket,
                  let offer = market.offers.first else {
                NSLog("[fixture] season review: no rookie market (journey=%@)", base.snapshot.journeyState == nil ? "nil" : "present")
                loadState = .failed("season review fixture: no rookie market")
                return false
            }
            let signedContract = try engine.acceptContract(.init(
                seed: base.nextSeed,
                state: base.snapshot,
                expectedRevision: base.snapshot.revision,
                marketID: market.id,
                offerID: offer.id,
                ambition: .franchiseIcon
            ))
            var object = try JSONSerialization.jsonObject(
                with: JSONEncoder().encode(signedContract.snapshot)
            ) as! [String: Any]
            object["phase"] = ProCareerPhase.seasonReview.rawValue
            object["season"] = 1
            object["week"] = 24
            object["fatigue"] = 41
            object.removeValue(forKey: "postseason")
            object.removeValue(forKey: "pendingDecision")
            let decoded = try JSONDecoder().decode(
                ProCareerSnapshot.self,
                from: JSONSerialization.data(withJSONObject: object)
            )
            let signed = engine.resignFixtureForTesting(decoded)
            let fixture = ProCareerResult(
                snapshot: signed,
                nextSeed: signedContract.nextSeed,
                events: ["ui_season_review_fixture"]
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
            NSLog("[fixture] season review failed: %@", String(describing: error))
            loadState = .failed(error.localizedDescription)
            return false
        }
    }
#endif
}
