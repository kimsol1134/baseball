import Foundation
import SimulationCore

/// 한 번의 승부 장면에 필요한 모든 입력. 프로 커리어와 고교 커리어가 같은 `PitchSession`을
/// 쓰기 위한 공통 형태다(DOC-IOS-TOP §4.3).
///
/// 고교 쪽이 오히려 정보가 많다. `ImportantGameScenarioContent`가 이닝·아웃·주자·레버리지·서사를
/// 이미 갖고 있고 `RivalSnapshot`은 타격 수치까지 들고 있다.
struct PitchScenario {
    let id: String
    let pitcher: PitcherSnapshot
    /// 첫 타자가 이 승부의 주인공(라이벌)이고 뒤는 후속 타순이다.
    let lineup: [BatterSnapshot]
    let scouting: BatterScoutingSnapshot
    /// 커리어에서 쌓은 포수와의 호흡. 분석 신뢰도와 사인 설명에 실제로 쓰인다.
    let catcherTrust: Int
    let defense: DefenseSnapshot
    let park: ParkSnapshot
    let inning: Int
    let outs: Int
    let runners: BaserunnerStateSnapshot
    let leverage: Int
    let scoreDifferential: Int
    let fatigue: Int
    /// iOS-only presentation input. It is derived from saved values at the scenario boundary and
    /// is never added to the shared save schema.
    let moundComposure: MoundComposureInput
    let headline: String
    let detail: String
    /// 이닝이 끝나지 않아도 여기서 멈춘다. 볼넷이 이어질 때 세션이 무한히 길어지는 것을 막는다.
    let maximumBatters: Int
    /// 투구 수 상한. 튜토리얼처럼 "배우는 자리"의 길이를 타자 수가 아니라 구 수로
    /// 못 박아야 할 때만 쓴다. nil이면 타자 수만 본다.
    var maximumPitches: Int?
    /// 같은 앱 빌드 안의 보존 v3와 신규 v4 결과를 분석에서 섞지 않는다.
    let developmentRulesVersion: Int

    var gameState: GameStateSnapshot {
        GameStateSnapshot(
            defense: defense,
            park: park,
            runners: runners,
            runsAllowed: 0,
            inningState: InningStateSnapshot(inning: inning, half: .top, outs: outs)
        )
    }

    // MARK: - 프로 커리어

    static func pro(state: ProCareerSnapshot) -> PitchScenario {
        let situation = proSituation(for: state.seasonTrigger, season: state.season, week: state.week)
        let catcherTrust = min(100, max(0, state.catcherTrust))
        return PitchScenario(
            id: "pa-\(state.proCareerID)-\(state.season)-\(state.week)",
            pitcher: state.pitcher,
            // 프로도 시즌이 갈수록 리그가 자신에게 맞춰 온다.
            lineup: ProRivalBatterStats.lineup(rival: state.currentRival, teamID: state.team.id)
                .map { DifficultyScale.scaled($0, by: DifficultyScale.pro(season: state.season)) },
            scouting: scoutingWithCatcherBond(
                ProRivalBatterStats.scouting(for: state.currentRival),
                catcherTrust: catcherTrust
            ),
            catcherTrust: catcherTrust,
            defense: ProRivalBatterStats.defense(teamID: state.team.id),
            park: ParkSnapshot(id: state.team.id, name: "\(state.team.name) 홈 구장", hitFactor: 1_000, homeRunFactor: 1_000),
            inning: situation.inning,
            outs: situation.outs,
            runners: situation.runners,
            leverage: situation.leverage,
            scoreDifferential: situation.scoreDifferential,
            fatigue: min(100, max(0, state.fatigue)),
            moundComposure: MoundComposureInput(
                command: state.pitcher.command,
                stamina: state.pitcher.stamina
            ),
            headline: situation.headline,
            detail: situation.detail,
            maximumBatters: 4,
            maximumPitches: nil,
            developmentRulesVersion: state.balanceVersion ?? 1
        )
    }

    private struct ProSituation {
        let inning: Int
        let outs: Int
        let runners: BaserunnerStateSnapshot
        let scoreDifferential: Int
        let leverage: Int
        let headline: String
        let detail: String
    }

    /// 무사에서 시작한다. 1사로 시작하면 병살 하나에 이닝이 끝나 승부 한 번이 한 구로 끝나는
    /// 일이 생긴다. 유료앱의 주력 장면이 그렇게 짧아지면 안 된다.
    ///
    /// 점수 국면은 트리거마다 다르고, 기록·순위 승부는 시즌·주차에 따라 리드와 열세를
    /// 오간다. 예전에는 6종 전부 "리드 중"으로 고정이라 20시즌의 수많은 승부에 지고 있는
    /// 마운드가 한 번도 없었다.
    private static func proSituation(for trigger: ProSeasonTrigger?, season: Int, week: Int) -> ProSituation {
        let onSecond = BaserunnerStateSnapshot(firstOccupied: false, secondOccupied: true, thirdOccupied: false, leadRunnerSpeed: 52)
        let onFirst = BaserunnerStateSnapshot(firstOccupied: true, secondOccupied: false, thirdOccupied: false, leadRunnerSpeed: 54)
        let corners = BaserunnerStateSnapshot(firstOccupied: true, secondOccupied: true, thirdOccupied: false, leadRunnerSpeed: 56)
        // 결정론: 같은 시즌·주차면 같은 국면. 홀짝만 쓰므로 저장·복원에도 흔들리지 않는다.
        let leading = (season + week) % 2 == 0
        switch trigger {
        case .majorDebut:
            return ProSituation(inning: 6, outs: 0, runners: onSecond, scoreDifferential: 0, leverage: 780, headline: "1군 데뷔 등판", detail: "동점 · 무사 2루")
        case .callUpAudition:
            return ProSituation(inning: 7, outs: 0, runners: onSecond, scoreDifferential: -1, leverage: 820, headline: "콜업을 결정할 등판", detail: "한 점 뒤짐 · 무사 2루 — 여기서 끊어야 반격이 산다")
        case .roleShowdown:
            return ProSituation(inning: 8, outs: 0, runners: onFirst, scoreDifferential: 1, leverage: 900, headline: "보직을 가를 등판", detail: "한 점 앞섬 · 무사 1루")
        case .recordChase:
            return leading
                ? ProSituation(inning: 7, outs: 0, runners: onFirst, scoreDifferential: 2, leverage: 700, headline: "기록이 걸린 등판", detail: "두 점 앞섬 · 무사 1루")
                : ProSituation(inning: 7, outs: 0, runners: onFirst, scoreDifferential: -2, leverage: 700, headline: "기록이 걸린 등판", detail: "두 점 뒤짐 · 무사 1루 — 점수와 상관없이 기록은 쌓인다")
        case .standingsRace:
            return leading
                ? ProSituation(inning: 9, outs: 0, runners: corners, scoreDifferential: 1, leverage: 950, headline: "순위 싸움의 마지막 이닝", detail: "한 점 앞섬 · 무사 1·2루")
                : ProSituation(inning: 9, outs: 0, runners: corners, scoreDifferential: -1, leverage: 950, headline: "순위 싸움의 마지막 이닝", detail: "한 점 뒤짐 · 무사 1·2루 — 더 내주면 역전의 문이 닫힌다")
        case .openingStatement, .none:
            return ProSituation(inning: 5, outs: 0, runners: onSecond, scoreDifferential: 1, leverage: 720, headline: "시즌 첫 승부처", detail: "한 점 앞섬 · 무사 2루")
        }
    }

    // MARK: - 첫 불펜(튜토리얼)

    /// 프롤로그 직후의 연습 한 타석.
    ///
    /// 이 게임에서 가장 좋은 것은 투구인데, 코어 뼈대대로면 첫 중요 경기까지 약 10번의 결정을
    /// 거쳐야 한다. 사는 사람이 대표 메커닉을 만나기까지 그만큼 기다리면 안 된다.
    /// 커리어 상태를 바꾸지 않는 연습 타석이라 결과가 기록에 남지 않는다.
    static func tutorial(state: HighSchoolCareerSnapshot) -> PitchScenario {
        PitchScenario(
            id: "hs-bullpen-\(state.careerID)",
            pitcher: state.pitcher,
            // 두 타자 — 한 타자는 첫 공 인플레이로 1구 만에 끝날 수 있어 3구 스크립트가
            // 성립하지 않는다(3차 패널 P1). 둘이면 최소 2구, 통상 6구 안팎이다.
            lineup: [
                BatterSnapshot(id: "bullpen-batter", name: "연습 타자", contact: 42, discipline: 40, power: 40),
                BatterSnapshot(id: "bullpen-batter-2", name: "연습 타자 B", contact: 46, discipline: 44, power: 42)
            ],
            scouting: BatterScoutingSnapshot(
                hotZone: PitchZone(row: 1, column: 1),
                coldZone: PitchZone(row: 2, column: 0),
                pitchStrength: .fourSeam,
                pitchWeakness: .curveball,
                chaseTendency: 45,
                // 연습이라 포수가 상대를 다 알려 준다. 배우는 자리에서 정보까지 감추지 않는다.
                reliability: 100
            ),
            catcherTrust: 50,
            defense: HighSchoolPresentation.defense(schoolID: nil),
            park: ParkSnapshot(id: "bullpen", name: "학교 불펜", hitFactor: 1_000, homeRunFactor: 1_000),
            inning: 1,
            outs: 0,
            runners: .empty,
            leverage: 200,
            scoreDifferential: 0,
            fatigue: 0,
            moundComposure: MoundComposureInput(
                command: state.pitcher.command,
                stamina: state.pitcher.stamina,
                awakenings: state.selectedAwakenings,
                memories: state.selectedMemories
            ),
            headline: "첫 불펜",
            detail: "기록에 남지 않는 연습 한 타석입니다. 마음껏 던져 보세요.",
            // 두 타석 — 3구 스크립트(사인→흔들기→결정구)가 실제로 전달될 최소 길이.
            maximumBatters: 2,
            // 실측에서 첫 불펜이 13구까지 갔다(주석의 "통상 6구 안팎"과 두 배 이상 차이).
            // 게다가 기본값이 사인 추종이라 13구가 전부 같은 코스였다 — 배우는 자리가
            // 아니라 같은 버튼을 열세 번 누르는 자리였다. 8구면 3구 스크립트가 두 바퀴 돈다.
            maximumPitches: 8,
            developmentRulesVersion: state.balanceVersion ?? 1
        )
    }

    // MARK: - 고교 커리어

    /// 중요한 순간의 길이는 상황이 정한다. 2사 승부는 한두 타자로 날카롭게 끝나고,
    /// 무사 만루·마지막 여름처럼 무게가 큰 장면은 최대 여섯 타자까지 책임진다.
    /// 모든 경기를 같은 네 타자로 고정하면 3년이 같은 미니게임의 반복이 된다.
    static func highSchoolMaximumBatters(state: HighSchoolCareerSnapshot) -> Int {
        highSchoolMaximumBatters(
            outs: state.currentGameScenario?.outs ?? 0,
            leverage: state.currentGameScenario?.leverage ?? 0,
            chapter: state.chapter.number,
            balanceVersion: state.balanceVersion
        )
    }

    static func highSchoolMaximumBatters(
        outs: Int,
        leverage: Int,
        chapter: Int,
        balanceVersion: Int? = PitcherPresetCatalog.balanceVersion
    ) -> Int {
        // 기능 도입 전에 시작한 선수는 남은 고교 공식 경기도 당시의 4타자 규칙으로
        // 끝낸다. 진행 중 저장을 업데이트만으로 더 길거나 짧은 경기로 바꾸지 않는다.
        guard (balanceVersion ?? 1) >= 4 else { return 4 }
        if outs >= 2 { return 2 }
        if leverage >= 900 || chapter == 8 { return 6 }
        if chapter >= 5 { return 5 }
        return 4
    }

    static func highSchool(
        state: HighSchoolCareerSnapshot,
        maximumBattersOverride: Int? = nil
    ) -> PitchScenario {
        let content = state.currentGameScenario
        let rival = state.rival
        // 상대는 학년이 오르고 회차가 쌓일수록 세진다. 안 그러면 플레이어만 성장해
        // 난이도 곡선이 단조 하강한다 — 뒤로 갈수록 쉬워지는 게임이 된다.
        let scale = DifficultyScale.highSchool(chapter: state.chapter.number, lifeNumber: state.lifeNumber)
        let rivalBatter = DifficultyScale.scaled(
            BatterSnapshot(
                id: rival.id,
                name: rival.name,
                contact: rival.contact,
                discipline: rival.discipline,
                power: rival.power
            ),
            by: scale
        )
        // 고교 수비는 프로보다 낮고 편차가 크다. 학교마다 결정론적으로 갈린다.
        let defense = HighSchoolPresentation.defense(schoolID: state.school?.id)
        let catcherTrust = min(100, max(0, state.catcherTrust ?? state.relationshipTrust))
        return PitchScenario(
            id: "hs-\(state.careerID)-\(state.performance.importantGamesCompleted)",
            pitcher: state.pitcher,
            lineup: [rivalBatter] + HighSchoolPresentation.followUpBatters(
                seedText: "\(state.careerID)|\(state.performance.importantGamesCompleted)",
                count: 5
            ).map { DifficultyScale.scaled($0, by: scale) },
            scouting: scoutingWithCatcherBond(
                HighSchoolPresentation.scouting(rival: rival, clarity: state.difficulty.informationClarity),
                catcherTrust: catcherTrust
            ),
            catcherTrust: catcherTrust,
            defense: defense,
            park: ParkSnapshot(id: "hs-park", name: "고교 구장", hitFactor: 1_000, homeRunFactor: 1_000),
            inning: content?.inning ?? 5,
            outs: content?.outs ?? 0,
            runners: content?.runners ?? .empty,
            leverage: content?.leverage ?? 500,
            // 시나리오가 점수 차를 들고 온다. 예전에는 전부 "1점 앞섬" 고정이라 고교 3년의
            // 모든 승부가 리드를 지키는 경기였다 — 지고 있는 마운드가 한 번도 없었다.
            scoreDifferential: content?.scoreDifferential ?? 1,
            fatigue: min(100, max(0, state.fatigue)),
            moundComposure: MoundComposureInput(
                command: state.pitcher.command,
                stamina: state.pitcher.stamina,
                awakenings: state.selectedAwakenings,
                memories: state.selectedMemories
            ),
            headline: content?.title ?? "고교 공식 경기",
            detail: content?.narrative ?? "이 이닝을 막아야 합니다.",
            maximumBatters: maximumBattersOverride ?? highSchoolMaximumBatters(state: state),
            maximumPitches: nil,
            developmentRulesVersion: state.balanceVersion ?? 1
        )
    }

    /// 포수 관계를 숨은 결과 보정이 아니라, 플레이어가 보고 판단하는 정보의 질로 바꾼다.
    /// 평균 호흡 50에서는 기존 리포트와 같고, 0...100 범위가 신뢰도에 -25...+25를 준다.
    /// 커널은 낮은 신뢰도에서 추정 사인, 높은 신뢰도에서 실제 약점 사인을 만들어 낸다.
    static func scoutingReliability(base: Int, catcherTrust: Int) -> Int {
        let trust = min(100, max(0, catcherTrust))
        return min(100, max(0, base + (trust - 50) / 2))
    }

    private static func scoutingWithCatcherBond(
        _ scouting: BatterScoutingSnapshot,
        catcherTrust: Int
    ) -> BatterScoutingSnapshot {
        BatterScoutingSnapshot(
            hotZone: scouting.hotZone,
            coldZone: scouting.coldZone,
            pitchStrength: scouting.pitchStrength,
            pitchWeakness: scouting.pitchWeakness,
            chaseTendency: scouting.chaseTendency,
            reliability: scoutingReliability(base: scouting.reliability, catcherTrust: catcherTrust)
        )
    }
}
