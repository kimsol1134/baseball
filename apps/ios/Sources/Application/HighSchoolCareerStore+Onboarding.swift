import Foundation
import SimulationCore

extension HighSchoolCareerStore {
    /// 커리어를 만들기 전에 연습 투구를 연다. 시드·저장·RNG를 소비하지 않는다.
    func beginOnboardingBullpen() {
        guard loadState == .needsSetup, tutorialSession == nil else { return }
        let pitcher = PitcherPresetCatalog.all.first?.pitcher ?? PitcherSnapshot(
            id: "onboarding-bullpen",
            name: "민서준",
            stuff: 40,
            command: 40,
            movement: 40,
            stamina: 40
        )
        let session = PitchSession(scenario: .onboardingBullpen(pitcher: pitcher), seed: "1")
        session.start()
        tutorialSession = session
    }

    func finishOnboardingBullpen() {
        tutorialSession = nil
        finishedOnboardingBullpen = true
    }

    func retryOnboardingBullpen() {
        tutorialSession = nil
        beginOnboardingBullpen()
    }
}
