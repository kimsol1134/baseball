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
    let defense: DefenseSnapshot
    let park: ParkSnapshot
    let inning: Int
    let outs: Int
    let runners: BaserunnerStateSnapshot
    let leverage: Int
    let scoreDifferential: Int
    let fatigue: Int
    let headline: String
    let detail: String
    /// 이닝이 끝나지 않아도 여기서 멈춘다. 볼넷이 이어질 때 세션이 무한히 길어지는 것을 막는다.
    let maximumBatters: Int

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
        return PitchScenario(
            id: "pa-\(state.proCareerID)-\(state.season)-\(state.week)",
            pitcher: state.pitcher,
            // 프로도 시즌이 갈수록 리그가 자신에게 맞춰 온다.
            lineup: ProRivalBatterStats.lineup(rival: state.currentRival, teamID: state.team.id)
                .map { DifficultyScale.scaled($0, by: DifficultyScale.pro(season: state.season)) },
            scouting: ProRivalBatterStats.scouting(for: state.currentRival),
            defense: ProRivalBatterStats.defense(teamID: state.team.id),
            park: ParkSnapshot(id: state.team.id, name: "\(state.team.name) 홈 구장", hitFactor: 1_000, homeRunFactor: 1_000),
            inning: situation.inning,
            outs: situation.outs,
            runners: situation.runners,
            leverage: situation.leverage,
            scoreDifferential: situation.scoreDifferential,
            fatigue: min(100, max(0, state.fatigue)),
            headline: situation.headline,
            detail: situation.detail,
            maximumBatters: 4
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
    /// 오간다. 예전에는 6종 전부 "리드 중"으로 고정이라 12시즌 60여 번의 승부에 지고 있는
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
            defense: HighSchoolPresentation.defense(schoolID: nil),
            park: ParkSnapshot(id: "bullpen", name: "학교 불펜", hitFactor: 1_000, homeRunFactor: 1_000),
            inning: 1,
            outs: 0,
            runners: .empty,
            leverage: 200,
            scoreDifferential: 0,
            fatigue: 0,
            headline: "첫 불펜",
            detail: "기록에 남지 않는 연습 한 타석입니다. 마음껏 던져 보세요.",
            // 두 타석 — 3구 스크립트(사인→흔들기→결정구)가 실제로 전달될 최소 길이.
            maximumBatters: 2
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
        return PitchScenario(
            id: "hs-\(state.careerID)-\(state.performance.importantGamesCompleted)",
            pitcher: state.pitcher,
            lineup: [rivalBatter] + HighSchoolPresentation.followUpBatters(
                seedText: "\(state.careerID)|\(state.performance.importantGamesCompleted)",
                count: 5
            ).map { DifficultyScale.scaled($0, by: scale) },
            scouting: HighSchoolPresentation.scouting(rival: rival, clarity: state.difficulty.informationClarity),
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
            headline: content?.title ?? "고교 공식 경기",
            detail: content?.narrative ?? "이 이닝을 막아야 합니다.",
            maximumBatters: maximumBattersOverride ?? highSchoolMaximumBatters(state: state)
        )
    }
}

// MARK: - 오늘의 이닝 (일일 도전)

extension PitchScenario {
    /// 날짜가 시드다 — 전국의 모든 플레이어가 같은 투수로 같은 타순을 상대한다.
    ///
    /// 커리어와 완전히 분리된 별도 판이라 밸런스 리스크가 0이고, 회차 진행 중인
    /// 사람에게도 "오늘 3분"의 이유가 된다. 점수는 리더보드로 겨룬다.
    static func daily(dateKey: String) -> PitchScenario {
        let seedText = "daily-\(dateKey)"
        var generator = SplitMix64(seed: Self.dailySeedValue(seedText))
        // 오늘의 투수 — 고정 스펙. 내 커리어가 아니라 손과 배합만으로 겨루는 판이다.
        let pitcher = PitcherSnapshot(
            id: "daily-pitcher", name: "오늘의 투수",
            stuff: 56, command: 56, movement: 56, stamina: 60,
            pitchProfiles: [
                PitchProfileSnapshot(pitchType: .fourSeam, role: .primary, velocityTenthsKPH: 1_430, control: 56, command: 56, movement: 48, whiff: 52, weakContact: 50, fatigueCost: 2),
                PitchProfileSnapshot(pitchType: .slider, role: .secondary, velocityTenthsKPH: 1_290, control: 52, command: 52, movement: 58, whiff: 58, weakContact: 52, fatigueCost: 2),
                PitchProfileSnapshot(pitchType: .curveball, role: .secondary, velocityTenthsKPH: 1_170, control: 50, command: 50, movement: 60, whiff: 56, weakContact: 54, fatigueCost: 2),
                PitchProfileSnapshot(pitchType: .changeup, role: .secondary, velocityTenthsKPH: 1_270, control: 52, command: 54, movement: 54, whiff: 54, weakContact: 56, fatigueCost: 2),
            ],
            throwingHand: .right
        )
        // 오늘의 4번 타자 — 날짜가 능력과 약점을 정한다.
        let names = ["강태건", "서진혁", "차도윤", "임세준", "한결", "표지훈", "위성곤"]
        let slugger = BatterSnapshot(
            id: "daily-slugger-\(dateKey)",
            name: names[generator.nextInt(upperBound: names.count)],
            contact: 52 + generator.nextInt(upperBound: 9),
            discipline: 48 + generator.nextInt(upperBound: 9),
            power: 54 + generator.nextInt(upperBound: 9)
        )
        let weaknessPool: [PitchType] = [.slider, .curveball, .changeup]
        let scouting = BatterScoutingSnapshot(
            hotZone: PitchZone(row: generator.nextInt(upperBound: 2), column: generator.nextInt(upperBound: 3)),
            coldZone: PitchZone(row: 2, column: generator.nextInt(upperBound: 3)),
            pitchStrength: .fourSeam,
            pitchWeakness: weaknessPool[generator.nextInt(upperBound: weaknessPool.count)],
            chaseTendency: 40 + generator.nextInt(upperBound: 21),
            reliability: 60
        )
        return PitchScenario(
            id: "daily-\(dateKey)",
            pitcher: pitcher,
            lineup: [slugger] + HighSchoolPresentation.followUpBatters(seedText: seedText),
            scouting: scouting,
            defense: HighSchoolPresentation.defense(schoolID: nil),
            park: ParkSnapshot(id: "daily-park", name: "전국 공용 구장", hitFactor: 1_000, homeRunFactor: 1_000),
            inning: 9,
            outs: 0,
            runners: BaserunnerStateSnapshot(firstOccupied: false, secondOccupied: false, thirdOccupied: false, leadRunnerSpeed: 52),
            leverage: 900,
            scoreDifferential: 1,
            fatigue: 20,
            headline: "오늘의 이닝",
            detail: "9회초, 한 점 리드. 전국이 오늘 같은 타순을 상대합니다.",
            maximumBatters: 6
        )
    }

    /// 오늘 날짜 키(KST). 자정에 판이 바뀐다.
    static func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        return formatter.string(from: Date())
    }

    /// 세션 시드 문자열 — 날짜에서 결정론적으로.
    static func dailySessionSeed(dateKey: String) -> String {
        String(dailySeedValue("daily-session-\(dateKey)"))
    }

    private static func dailySeedValue(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01B3
        }
        return hash
    }
}
