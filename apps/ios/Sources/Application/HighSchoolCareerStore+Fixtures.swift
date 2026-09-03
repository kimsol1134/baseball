import Foundation
import SimulationCore
import BaseballIOSDomain

extension HighSchoolCareerStore {
#if DEBUG
    /// 고교 1장·학교 선택 완료·훈련 국면 첫 주.
    ///
    /// 고정 시드로 start → 프롤로그 완료 → 학교 선택만 수행한다. 훈련 루프를 돌리지 않아
    /// 커리어 RNG를 소비하지 않고, 엔진이 서명한 스냅샷을 그대로 설치한다.
    @discardableResult
    func installTrainingFixtureForUITesting(seed: String = "20260903") -> Bool {
        let fixtureEngine = HighSchoolCareerEngine()
        do {
            var fixture = try fixtureEngine.start(.init(
                seed: seed,
                presetID: "power_prospect",
                identity: PlayerIdentitySnapshot(
                    name: "민서준", throwingHand: .right, bodyType: .balanced, region: "서울"
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
            guard fixture.snapshot.phase == .training,
                  fixture.snapshot.school != nil,
                  fixture.snapshot.chapter.number == 1,
                  fixture.snapshot.chapterTrainingCount == 0,
                  fixture.snapshot.totalTrainingsCompleted == 0 else {
                loadState = .failed("UI 테스트용 훈련 픽스처가 1장 훈련 첫 주에 도달하지 못했습니다.")
                return false
            }
            updatePersisted {
                $0.result = fixture
                $0.careerStartingPitcher = startingPitcher
                $0.enteredProCareerID = nil
            }
            lastSummary = nil
            feedbackCue = .neutral
            feedbackTrigger += 1
            loadState = .ready
            guard save() else {
                updatePersisted {
                    $0.result = nil
                    $0.careerStartingPitcher = nil
                }
                loadState = .failed("UI 테스트용 훈련 상태를 저장하지 못했습니다.")
                return false
            }
            return true
        } catch {
            updatePersisted {
                $0.result = nil
                $0.careerStartingPitcher = nil
            }
            loadState = .failed("UI 테스트용 훈련 상태를 만들지 못했습니다: \(error.localizedDescription)")
            return false
        }
    }
#endif
}
