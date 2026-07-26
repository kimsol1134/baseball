import Foundation
import SimulationCore

/// 유료앱 배포 채널에서의 권한 모델.
///
/// 이 바이너리는 App Store 유료 다운로드로만 획득된다. 따라서 "앱을 실행하고 있다"는 사실
/// 자체가 프로 커리어 이용 권한의 증거이고, 별도의 StoreKit 확인 단계가 없다.
/// 코어(`SimulationCore`)는 여전히 스토어를 알지 못하며 `ProEntitlementSnapshot`만 받는다(ADR-013).
enum AppEntitlement {
    /// 앱 구매로 확보된 프로 커리어 권한. 디버그와 릴리스가 같은 경로를 타야 시뮬레이터 QA가
    /// 실제 배포 빌드를 대표할 수 있으므로 `#if DEBUG` 분기를 두지 않는다.
    static func paidApp(verifiedAt: Date = .now) -> ProEntitlementSnapshot {
        ProEntitlementSnapshot(
            status: .active,
            source: .purchase,
            verifiedAt: ISO8601DateFormatter().string(from: verifiedAt)
        )
    }
}

/// 새 커리어를 만들 때 필요한 지명 결과를 만든다.
///
/// 고교 커리어는 아직 iOS에 이식되지 않았으므로(계획 문서 §6) 프로 입단은 선택한 투수 유형과
/// 시드에서 결정론적으로 파생한다. 같은 시드와 같은 유형이면 언제나 같은 구단·라운드가 나온다.
enum CareerBootstrap {
    /// 지명 평가에 쓰는 종합 점수. 네 능력의 가중 평균을 60 스케일 위에 올린다.
    static func evaluationScore(for pitcher: PitcherSnapshot) -> Int {
        let weighted = pitcher.stuff * 3 + pitcher.command * 3 + pitcher.movement * 2 + pitcher.stamina * 2
        return min(90, max(40, weighted / 10 + 22))
    }

    static func draftResult(preset: PitcherPresetSnapshot, seed: UInt64) -> DraftResultSnapshot {
        var rng = SplitMix64(seed: seed)
        let teams = ProCareerEngine.proTeams
        let team = teams[rng.nextInt(upperBound: teams.count)]
        let score = evaluationScore(for: preset.pitcher)
        // 평가 점수가 높을수록 앞 라운드에 지명된다. 1~4라운드 안에서만 움직여 초반 서사를
        // 프로 커리어(2군 시작)와 어긋나지 않게 유지한다.
        let round = max(1, min(4, 5 - (score - 40) / 13))
        let overallPick = (round - 1) * 10 + rng.nextInt(upperBound: 10) + 1
        let signingBonus = max(30_000_000, (5 - round) * 60_000_000 + rng.nextInt(upperBound: 5) * 10_000_000)
        return DraftResultSnapshot(
            outcome: .drafted,
            evaluationScore: score,
            projectedRange: "\(round)~\(min(4, round + 1))라운드",
            team: team,
            round: round,
            overallPick: overallPick,
            signingBonus: signingBonus,
            firstSeasonGoal: round <= 2 ? "1군 불펜 진입" : "2군 선발 로테이션 정착",
            summary: "\(team.name) \(round)라운드 지명"
        )
    }

    /// 고교 커리어의 실제 지명 결과로 프로 커리어를 연다. 이쪽이 정규 경로이고,
    /// `startCareer(preset:...)`는 고교 3년을 건너뛰고 싶은 사용자를 위한 우회로다.
    static func startCareer(
        draft: DraftResultSnapshot,
        pitcher: PitcherSnapshot,
        identity: PlayerIdentitySnapshot,
        seed: UInt64,
        engine: ProCareerEngine = ProCareerEngine()
    ) throws -> ProCareerResult {
        let started = try engine.start(
            .init(
                seed: String(seed),
                identity: identity,
                pitcher: pitcher,
                draftResult: draft,
                entitlement: AppEntitlement.paidApp()
            )
        )
        return try engine.signContract(.init(seed: started.nextSeed, state: started.snapshot))
    }

    /// 계약 서명까지 끝난 첫 주차 상태를 만든다.
    static func startCareer(
        preset: PitcherPresetSnapshot,
        playerName: String,
        seed: UInt64,
        engine: ProCareerEngine = ProCareerEngine()
    ) throws -> ProCareerResult {
        let trimmed = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? preset.pitcher.name : trimmed
        let identity = PlayerIdentitySnapshot(
            name: name,
            throwingHand: preset.pitcher.throwingHand,
            bodyType: .balanced,
            region: "서울"
        )
        let pitcher = PitcherSnapshot(
            id: preset.pitcher.id,
            name: name,
            stuff: preset.pitcher.stuff,
            command: preset.pitcher.command,
            movement: preset.pitcher.movement,
            stamina: preset.pitcher.stamina,
            pitchProfiles: preset.pitcher.pitchProfiles,
            throwingHand: preset.pitcher.throwingHand
        )
        let draft = draftResult(preset: preset, seed: seed)
        let started = try engine.start(
            .init(
                seed: String(seed),
                identity: identity,
                pitcher: pitcher,
                draftResult: draft,
                entitlement: AppEntitlement.paidApp()
            )
        )
        return try engine.signContract(.init(seed: started.nextSeed, state: started.snapshot))
    }
}
