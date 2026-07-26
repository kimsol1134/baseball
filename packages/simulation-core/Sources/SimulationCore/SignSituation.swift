import Foundation

/// 포수가 사인을 낼 때 읽는 상황.
///
/// 예전에는 사인이 타석 내내 똑같았다 — 코스는 언제나 `scouting.coldZone`이었고, 카운트는
/// 3볼과 2스트라이크만 갈랐다. 주자·아웃·직전 구는 `preparePitch`가 이미 들고 있으면서도
/// 추천에 전달되지 않았다. 그래서 0-2와 3-1에 같은 공을 요구했고, 1루 주자가 있어도 병살을
/// 노리지 않았다. 야구를 아는 사람에게는 포수가 경기를 안 보는 것처럼 보인다.
///
/// **난수를 쓰지 않는다.** `preparePitch`와 `submitPitch`가 각자 추천을 다시 계산해
/// `preparationToken`으로 대조하므로(`PitchKernelEngine.swift`), 여기에 비결정 입력이 하나라도
/// 들어가면 두 계산이 갈라져 투구가 통째로 거부된다. 골든 픽스처가 안전한 것도 같은 이유다 —
/// 이 타입은 커널 RNG 스트림을 건드리지 않는다.
struct SignSituation {
    /// 카운트가 만드는 국면. 야구에서 볼카운트는 곧 누가 유리한지다.
    enum Count {
        /// 초구. 스트라이크를 선점하는 것이 그 타석 전체를 좌우한다.
        case first
        /// 투수가 앞선다(0-2, 1-2). 존 밖으로 유인할 여유가 있다.
        case ahead
        /// 타자가 앞선다(2-0, 3-1). 존 안에서 승부해야 한다.
        case behind
        /// 3-0. 볼넷을 주지 않는 것이 유일한 목표다.
        case mustThrowStrike
        case even
    }

    let count: Count
    /// 1루에 주자가 있고 2아웃 미만 — 병살을 노릴 수 있다.
    let doublePlayChance: Bool
    /// 3루에 주자가 있고 2아웃 미만 — 뜬공 하나에 점수가 난다.
    let sacrificeFlyRisk: Bool
    /// 직전 구가 장타를 맞았거나 파울로 커트당했다.
    let avoidsRepeat: Bool

    init(context: PlateAppearanceContext, gameState: GameStateSnapshot?, lastPitch: PitchAnalysisEntry?) {
        count = switch (context.balls, context.strikes) {
        case (0, 0): .first
        case (3, 0): .mustThrowStrike
        case (0, 2), (1, 2): .ahead
        case (2, 0), (3, 1): .behind
        default: .even
        }

        let runners = gameState?.runners
        let mayHaveDoublePlay = context.outs < 2
        doublePlayChance = mayHaveDoublePlay && (runners?.firstOccupied ?? false)
        sacrificeFlyRisk = mayHaveDoublePlay && (runners?.thirdOccupied ?? false)

        // 같은 공을 또 주면 안 되는 두 경우: 얻어맞았거나, 커트당하며 타이밍이 맞아 가고 있다.
        switch lastPitch?.outcome {
        case .single, .double, .triple, .homeRun: avoidsRepeat = true
        case .foul: avoidsRepeat = context.strikes == 2
        default: avoidsRepeat = false
        }
    }

    /// 약점 코스를 상황에 맞게 민다. `coldZone`이 기준점이라 스카우팅의 가치는 유지된다.
    ///
    /// 존은 3×3이고 row 0이 높은 쪽, row 2가 낮은 쪽이다.
    func shift(_ zone: PitchZone) -> PitchZone {
        var row = zone.row
        var column = zone.column

        switch count {
        case .mustThrowStrike:
            // 볼넷을 주느니 맞는 편이 낫다. 한복판에 붙인다.
            row = 1
            column = 1
        case .behind:
            // 존 안으로 한 칸 당긴다. 가장자리를 노리다 볼이 되면 더 불리해진다.
            row = pullInward(row)
            column = pullInward(column)
        case .ahead:
            // 유인구. 낮은 쪽으로 한 칸 빼서 헛스윙을 노린다.
            row = min(2, row + 1)
        case .first, .even:
            break
        }

        if doublePlayChance, count != .mustThrowStrike {
            // 땅볼을 만들어야 한다. 커널의 타구 판정은 발사각 기반이라 낮은 존이 실제로 유효하다.
            row = max(row, 1)
        }
        if sacrificeFlyRisk, count != .mustThrowStrike {
            // 높은 공은 뜬공이 되고, 3루 주자는 그것만으로 홈에 들어온다.
            row = max(row, 1)
        }
        return PitchZone(row: row, column: column)
    }

    /// 존 가장자리를 노릴지, 존 밖으로 뺄지, 확실히 넣을지.
    func zoneIntent(protectZone: Bool, twoStrikes: Bool) -> ZoneIntent {
        if protectZone || count == .mustThrowStrike { return .strike }
        switch count {
        case .behind: return .strike
        case .ahead: return .chase
        case .first: return .edge
        default: return twoStrikes ? .chase : .edge
        }
    }

    /// 힘보다 제구가 필요한 상황인가.
    var demandsControl: Bool {
        switch count {
        case .mustThrowStrike, .behind: true
        default: doublePlayChance
        }
    }

    /// 화면이 한국어로 풀어 보여 줄 코드.
    var countCode: String {
        switch count {
        case .first: "count.first_pitch"
        case .ahead: "count.pitcher_ahead"
        case .behind: "count.pitcher_behind"
        case .mustThrowStrike: "count.avoid_walk"
        case .even: "count.standard"
        }
    }

    var extraReasonCodes: [String] {
        var codes: [String] = []
        if doublePlayChance { codes.append("runners.double_play_setup") }
        if sacrificeFlyRisk { codes.append("runners.suppress_sacrifice_fly") }
        return codes
    }

    /// 존 안쪽으로 한 칸. 이미 가운데면 그대로 둔다.
    private func pullInward(_ value: Int) -> Int {
        switch value {
        case 0: 1
        case 2: 1
        default: value
        }
    }
}
