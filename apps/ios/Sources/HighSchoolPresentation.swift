import Foundation
import SimulationCore

/// 고교 커리어 화면이 쓰는 표시 문구와 파생값. 데스크톱 `HighSchoolCareerView.tsx`의 라벨 표와
/// 같은 값을 쓰므로 두 플랫폼의 각성·기억 카드 설명이 갈리지 않는다.
enum HighSchoolPresentation {
    // MARK: - 라벨

    static func phase(_ phase: HighSchoolCareerPhase) -> String {
        switch phase {
        case .prologue: "다시 태어남"
        case .schoolSelection: "학교 선택"
        case .training: "훈련"
        case .relationship: "사람들"
        case .importantGame: "중요 경기"
        case .awakening: "각성"
        case .chapterReview: "챕터 마무리"
        case .draft: "드래프트"
        case .legacy: "다음 생에 가져갈 것"
        case .completed: "완료"
        }
    }

    static func focus(_ focus: TrainingFocus) -> String {
        switch focus {
        case .velocity: "구위"
        case .command: "제구"
        case .breakingBall: "변화구"
        case .stamina: "체력"
        case .recovery: "회복"
        case .gamePlanning: "승부 설계"
        }
    }

    static func focusDetail(_ focus: TrainingFocus) -> String {
        switch focus {
        case .velocity: "구위가 오릅니다. 직구가 빨라지고 헛스윙이 늘어납니다. 피로가 큽니다."
        case .command: "제구가 오릅니다."
        case .breakingBall: "변화구가 오릅니다. 공이 더 꺾이고 떨어집니다."
        case .stamina: "체력이 오릅니다."
        case .recovery: "피로가 줄고 팔 상태가 회복됩니다."
        case .gamePlanning: "포수와의 호흡과 승부 판단이 좋아집니다."
        }
    }

    static func focusSymbol(_ focus: TrainingFocus) -> String {
        switch focus {
        case .velocity: "flame"
        case .command: "scope"
        case .breakingBall: "tornado"
        case .stamina: "figure.run"
        case .recovery: "bed.double"
        case .gamePlanning: "brain.head.profile"
        }
    }

    /// 강도 이름. **무엇을 하느냐에 따라 달라진다.**
    ///
    /// "회복을 몰아붙이기로 한다"는 말이 안 된다. 계산상으로는 뜻이 있다 — 회복은 피로를
    /// 18 줄이고 강도가 그만큼 도로 쌓으므로, 몰아붙이면 실제로 3만 회복된다. 즉 "쉬면서
    /// 얼마나 몸을 쓰느냐"다. 그러면 그렇게 불러야 한다.
    static func intensity(_ level: TrainingIntensity, focus: TrainingFocus) -> String {
        guard focus == .recovery else { return intensity(level) }
        switch level {
        case .light: return "푹 쉰다"
        case .standard: return "가볍게 몸만 푼다"
        case .intensive: return "쉬면서도 던진다"
        }
    }

    static func intensity(_ intensity: TrainingIntensity) -> String {
        switch intensity {
        case .light: "가볍게"
        case .standard: "보통"
        case .intensive: "몰아붙이기"
        }
    }

    /// 대화 응답 문구. **상황에 따라 달라진다.**
    ///
    /// 코어의 판정은 세 가지 태도(듣는다·설명한다·증명한다) 위에 서 있고 그건 그대로 둔다.
    /// 바뀌는 건 말이다. 예전에는 부모님 전화에도 "다음 승부로 증명한다"가 붙었는데,
    /// 전화기에 대고 할 말이 아니다. 같은 태도라도 상대가 감독인지 부모인지 기자인지에
    /// 따라 사람은 다르게 말한다.
    static func response(_ response: RelationshipResponse, category: String) -> String {
        switch category {
        case "life":
            switch response {
            case .listen: "끝까지 듣는다"
            case .explain: "내 생각을 솔직히 말한다"
            case .challenge: "걱정 마시라고 말한다"
            }
        case "coach":
            switch response {
            case .listen: "지시를 그대로 받는다"
            case .explain: "내 판단을 말해 본다"
            case .challenge: "다음 등판으로 보여드리겠다고 한다"
            }
        case "catcher":
            switch response {
            case .listen: "포수 리드에 맡긴다"
            case .explain: "원하는 배합을 이야기한다"
            case .challenge: "내 공을 믿어 달라고 한다"
            }
        case "rival":
            switch response {
            case .listen: "말을 아낀다"
            case .explain: "실력은 실력으로 가리자고 한다"
            case .challenge: "다음 승부에서 보자고 한다"
            }
        case "media", "fan":
            switch response {
            case .listen: "질문을 끝까지 듣는다"
            case .explain: "지금 하는 준비를 설명한다"
            case .challenge: "기록으로 답하겠다고 한다"
            }
        case "health":
            switch response {
            case .listen: "코치에게 알리고 쉰다"
            case .explain: "상태를 정확히 설명한다"
            case .challenge: "괜찮다고 하고 계속 던진다"
            }
        case "team":
            switch response {
            case .listen: "동료의 말을 먼저 듣는다"
            case .explain: "내 입장을 설명한다"
            case .challenge: "결과로 정리하자고 한다"
            }
        case "draft":
            switch response {
            case .listen: "평가를 그대로 듣는다"
            case .explain: "내가 준비한 것을 말한다"
            case .challenge: "남은 경기로 뒤집겠다고 한다"
            }
        default:
            switch response {
            case .listen: "먼저 듣는다"
            case .explain: "내 생각을 말한다"
            case .challenge: "다음 승부로 증명한다"
            }
        }
    }

    static func responseDetail(_ response: RelationshipResponse) -> String {
        switch response {
        case .listen: "상대와의 믿음이 오르고 피로가 줄어듭니다."
        case .explain: "믿음이 오르고 관련 능력이 조금 오릅니다."
        case .challenge: "위험하지만 성공하면 능력이 크게 오릅니다."
        }
    }

    static func armHealth(_ state: ArmHealthState) -> (label: String, tone: BaseballCardTone) {
        switch state {
        case .normal: ("팔 상태 정상", .positive)
        case .caution: ("팔에 부담이 쌓임", .warning)
        case .warning: ("팔 상태 경고", .negative)
        case .recovering: ("회복 중", .raised)
        }
    }

    static func karma(_ karma: KarmaID) -> (title: String, detail: String) {
        switch karma {
        case .unknownLand: ("낯선 땅", "연고가 없는 지역에서 시작합니다.")
        case .stubbornCoach: ("고집 센 감독", "감독의 믿음을 얻기가 어렵습니다.")
        case .singleWeapon: ("단 하나의 무기", "구종 하나에만 기댈 수 있습니다.")
        case .geniusGeneration: ("천재들의 세대", "같은 학년에 뛰어난 투수가 많습니다.")
        case .erasedMemory: ("지워진 기억", "가져갈 기억 카드가 줄어듭니다.")
        case .noLastChance: ("마지막 기회는 없다", "부상 한 번이 커리어를 끝낼 수 있습니다.")
        }
    }

    static func awakening(_ id: AwakeningID) -> (title: String, detail: String) {
        switch id {
        case .explosiveFastball: ("폭발하는 포심", "구위 +4 · 제구 -2 · 직구 구속과 헛스윙 증가")
        case .pinpointEdge: ("바늘끝 제구", "제구 +4 · 구위 -1 · 스트라이크존 끝 제구 향상")
        case .disappearingBreaker: ("사라지는 변화구", "변화구 +4 · 제구 -1 · 변화구 헛스윙 증가")
        case .ironArm: ("강철의 어깨", "체력 +5 · 변화구 -1 · 공마다 쌓이는 피로 감소")
        case .calmUnderPressure: ("고요한 마운드", "제구 +2 · 체력 +1 · 주자가 있을 때 제구 향상")
        case .batterySync: ("포수와 한마음", "제구 +2 · 변화구 +1 · 빗맞은 타구 증가")
        case .risingFourSeam: ("떠오르는 포심", "직구의 위력과 헛스윙 증가 · 변화구 -1")
        case .sinkerTunnel: ("같은 길에서 갈라지는 공", "변화구 +3 · 직구와 체인지업의 빗맞은 타구 증가")
        case .frozenChangeup: ("멈춘 체인지업", "체인지업 궤적·헛스윙 상승 · 체력 -1")
        case .sweepingSlider: ("스위퍼 궤도", "변화구 +4 · 제구 -1 · 슬라이더 헛스윙 증가")
        case .curveballClock: ("일정한 커브 타이밍", "변화구 +4 · 체력 -1 · 커브 헛스윙 증가")
        case .repeatableRelease: ("흔들리지 않는 투구 동작", "제구 +4 · 구위 -1 · 모든 구종의 제구 향상")
        case .pickoffRhythm: ("주자를 묶는 리듬", "제구 +1 · 체력 +2 · 주자가 있을 때 흔들림 감소")
        case .twoStrikePlan: ("2스트라이크 승부법", "제구·변화구 +2 · 체력 -1 · 변화구 헛스윙 증가")
        case .firstPitchStrike: ("초구 스트라이크", "제구 +3 · 체력 -1 · 초구 스트라이크 증가")
        case .trafficController: ("주자를 두고도 침착하게", "제구·체력 +2 · 구위 -1 · 빗맞은 타구 증가")
        case .lateInningReserve: ("후반에도 남는 힘", "체력 +4 · 공마다 쌓이는 피로 감소")
        case .scoutComposure: ("압박 속 침착함", "구위·제구 +2 · 체력 -1")
        }
    }

    static func memory(_ id: MemoryCardID) -> (title: String, detail: String) {
        switch id {
        case .velocityBlueprint: ("직구 구속 훈련법", "직구 구속·헛스윙 증가, 제구 소폭 감소")
        case .fingertipMemory: ("손끝의 기억", "변화구 움직임 상승, 체력 소폭 감소")
        case .catcherNotebook: ("포수의 노트", "제구와 빗맞은 타구 유도 증가")
        case .rivalNotebook: ("라이벌 노트", "제구·변화구와 변화구 헛스윙 증가")
        case .recoveryRoutine: ("회복 방법", "체력 상승, 공마다 피로 소모 감소")
        case .pressureRehearsal: ("압박의 예행연습", "제구·체력과 위기 상황 제구 향상")
        case .firstPitchMap: ("초구 지도", "초구 제구 상승, 체력 소폭 감소")
        case .twoStrikeSequence: ("2스트라이크 구종 순서", "변화구 움직임·헛스윙 상승, 체력 소폭 감소")
        case .fatigueDiary: ("피로 일지", "체력과 후반 제구 상승")
        case .mechanicsVideo: ("투구 동작 교정 영상", "제구 향상, 공의 최고 위력 소폭 감소")
        case .schoolPlaybook: ("학교에서 배운 승부법", "제구·변화구 향상")
        case .coachLetter: ("코치의 편지", "제구·체력 향상")
        case .draftReport: ("구단 평가표", "구위·제구 향상")
        case .stadiumEcho: ("구장의 메아리", "구위·헛스윙 증가, 제구 소폭 감소")
        case .teamFirstPromise: ("팀을 위한 약속", "제구·체력과 빗맞은 타구 유도 증가")
        case .failureScorebook: ("실패의 스코어북", "제구·변화구 향상, 체력 소폭 감소")
        case .winterProgram: ("겨울 훈련표", "구위·체력 향상, 피로 누적 감소")
        case .bullpenCompass: ("불펜의 나침반", "구위·체력 향상, 피로 누적 감소")
        }
    }

    // MARK: - 승부 장면 파생

    /// 고교 후속 타순. 라이벌 뒤에 설 세 타자를 학교·경기 번호에서 결정론적으로 만든다.
    static func followUpBatters(seedText: String) -> [BatterSnapshot] {
        var rng = SplitMix64(seed: seedValue(seedText))
        let names = ["구본휘", "설재빈", "천유겸", "봉시원", "옥준서", "석다온"]
        var used: Set<String> = []
        return (0..<3).map { slot in
            var name = names[rng.nextInt(upperBound: names.count)]
            var attempts = 0
            while used.contains(name), attempts < names.count {
                name = names[rng.nextInt(upperBound: names.count)]
                attempts += 1
            }
            used.insert(name)
            return BatterSnapshot(
                id: "hs-lineup-\(slot)",
                name: name,
                // 고교 타자는 프로보다 낮고 편차가 크다.
                contact: 34 + rng.nextInt(upperBound: 24),
                discipline: 32 + rng.nextInt(upperBound: 24),
                power: 32 + rng.nextInt(upperBound: 26),
                batSide: rng.nextInt(upperBound: 3) == 0 ? .left : .right
            )
        }
    }

    /// 우리 학교 수비. 고교라 프로보다 낮다.
    static func defense(schoolID: SchoolID?) -> DefenseSnapshot {
        var rng = SplitMix64(seed: seedValue("hs-defense|\(schoolID?.rawValue ?? "none")"))
        let names = ["유시환", "임태오", "나건우", "배준서", "하민규", "조유찬", "신태양", "도경훈"]
        let positions: [FielderPosition] = [
            .catcher, .firstBase, .secondBase, .shortstop, .leftField, .centerField, .rightField, .thirdBase
        ]
        var fielders = [FielderSnapshot(id: "f-p", name: "본인", position: .pitcher, range: 40, glove: 44, arm: 52)]
        for (index, position) in positions.enumerated() {
            fielders.append(
                FielderSnapshot(
                    id: "f-\(position.rawValue)",
                    name: names[index],
                    position: position,
                    range: 34 + rng.nextInt(upperBound: 22),
                    glove: 34 + rng.nextInt(upperBound: 22),
                    arm: 34 + rng.nextInt(upperBound: 24)
                )
            )
        }
        return DefenseSnapshot(infield: 44, outfield: 42, arm: 45, fielders: fielders)
    }

    /// 라이벌 스카우팅. 정보 명료도가 낮은 회차일수록 처음의 확신이 낮다.
    static func scouting(rival: RivalSnapshot, clarity: DifficultyLevel) -> BatterScoutingSnapshot {
        let powerHitter = rival.power >= 55
        let baseline: Int
        switch clarity {
        case .relaxed: baseline = 100
        case .standard: baseline = 45
        case .challenging: baseline = 22
        }
        return BatterScoutingSnapshot(
            hotZone: powerHitter ? PitchZone(row: 1, column: 1) : PitchZone(row: 1, column: 0),
            coldZone: powerHitter ? PitchZone(row: 2, column: 2) : PitchZone(row: 0, column: 2),
            pitchStrength: rival.contact >= 55 ? .slider : .fourSeam,
            pitchWeakness: powerHitter ? .changeup : .curveball,
            chaseTendency: min(80, max(20, 50 - (rival.discipline - 50))),
            reliability: baseline
        )
    }

    /// FNV-1a. 코어의 `StableHash`는 internal이라 셸에서 쓸 수 없어 같은 식을 여기에 둔다.
    private static func seedValue(_ value: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01B3
        }
        return hash
    }
}
