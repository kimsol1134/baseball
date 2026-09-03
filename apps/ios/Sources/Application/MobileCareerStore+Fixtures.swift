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
#endif
}
