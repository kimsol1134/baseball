import Foundation
import SimulationCore
import BaseballIOSDomain

extension HighSchoolPresentation {
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

    static func localizedFocusDetail(_ focus: TrainingFocus, resolver: GameCopyResolver) -> String {
        resolver.resolve(focus.detailCopyToken)
    }

    static func localizedFocusTradeoff(_ focus: TrainingFocus, resolver: GameCopyResolver) -> String {
        resolver.resolve(focus.tradeoffCopyToken)
    }

    static func localizedFocusMetric(_ focus: TrainingFocus, resolver: GameCopyResolver) -> String {
        resolver.resolve(focus.metricCopyToken)
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

    static func localized(
        _ intensity: TrainingIntensity,
        focus: TrainingFocus,
        resolver: GameCopyResolver
    ) -> String {
        focus == .recovery
            ? resolver.resolve(intensity.recoveryCopyToken)
            : resolver.resolve(intensity.displayCopyToken)
    }

    static func localizedOutlook(
        _ outlook: TrainingGrowthOutlook,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(outlook.detailCopyToken)
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
            case .explain: "던지고 싶은 공을 설명한다"
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
        case .listen: "상대와의 믿음을 쌓는 가장 안전한 선택입니다."
        case .explain: "믿음이 오르고 관련 능력이 조금 오릅니다."
        case .challenge: "위험하지만 성공하면 능력이 크게 오릅니다."
        }
    }

    static func localized(
        _ response: RelationshipResponse,
        category: String,
        resolver: GameCopyResolver
    ) -> String {
        if resolver.language == .korean {
            return Self.response(response, category: category)
        }
        return resolver.resolve(response.displayCopyToken)
    }

    static func armHealth(_ state: ArmHealthState) -> (label: String, tone: BaseballCardTone) {
        switch state {
        case .normal: ("팔 상태 정상", .positive)
        case .caution: ("팔에 부담이 쌓임", .warning)
        case .warning: ("팔 상태 경고", .negative)
        case .recovering: ("회복 중", .raised)
        }
    }

    static func localizedArmHealth(
        _ state: ArmHealthState,
        resolver: GameCopyResolver
    ) -> (label: String, tone: BaseballCardTone) {
        let tone: BaseballCardTone = switch state {
        case .normal: .positive
        case .caution: .warning
        case .warning: .negative
        case .recovering: .raised
        }
        return (resolver.resolve(state.displayCopyToken), tone)
    }

    static func localizedOpportunityReason(
        _ opportunity: TrainingOpportunitySnapshot,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(opportunity.copyDescriptor.token)
    }

    static func localizedTrainingResultTitle(
        _ receipt: TrainingReceipt,
        resolver: GameCopyResolver
    ) -> String {
        if receipt.bloom != nil {
            return resolver.resolve(AppCopyKey.trainingResultTitleBloom)
        }
        if receipt.jackpot {
            return resolver.resolve(AppCopyKey.trainingResultTitleJackpot)
        }
        return receipt.gains.contains { $0.after > $0.before }
            ? resolver.resolve(AppCopyKey.trainingResultTitleGrowth)
            : resolver.resolve(AppCopyKey.trainingResultTitleNoGrowth)
    }

    static func localizedTrainingResultHeadline(
        _ receipt: TrainingReceipt,
        resolver: GameCopyResolver
    ) -> String {
        let gains = receipt.gains.filter { $0.after > $0.before }
        guard !gains.isEmpty else {
            return resolver.resolve(AppCopyKey.trainingResultHeadlineNoGain)
        }
        return gains.map { gain in
            resolver.resolve(
                AppCopyKey.trainingResultGainValue,
                arguments: [
                    .userText(resolver.resolve(gain.ability.displayCopyToken)),
                    .integer(AbilityDisplayScale.displayDelta(before: gain.before, after: gain.after)),
                ]
            )
        }.joined(separator: " · ")
    }

    static func localizedTrainingGainRow(
        _ gain: AbilityGain,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(
            AppCopyKey.trainingResultGainRow,
            arguments: [
                .userText(resolver.resolve(gain.ability.displayCopyToken)),
                .integer(AbilityDisplayScale.displayRating(gain.before)),
                .integer(AbilityDisplayScale.displayRating(gain.after)),
            ]
        )
    }

    static func localizedTrainingResultBloom(
        _ bloom: TalentBloom,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(
            GameCopyKey.gameContent("content.training-result.bloom-headline"),
            arguments: [
                .userText(resolver.resolve(bloom.ability.displayCopyToken)),
                .userText(resolver.resolve(bloom.grade.displayCopyToken)),
                .integer(AbilityDisplayScale.displayCeiling(bloom.grade.ceiling)),
            ]
        )
    }

    static func localizedTrainingResultDetail(
        _ receipt: TrainingReceipt,
        resolver: GameCopyResolver
    ) -> String {
        // Korean receipts are already the shipped Korean copy, including dynamic rehab and
        // talent-wall wording. Preserve that behavior verbatim; the English branch below is
        // the strict semantic reauthoring boundary and never interpolates the raw sentence.
        if resolver.language == .korean {
            return receipt.detail
        }

        let base: String
        if let repeatCount = receipt.repeatCount {
            base = resolver.resolve(
                GameCopyKey.gameContent("content.training-result.detail.repeat"),
                arguments: [
                    .userText(resolver.resolve(receipt.focus.displayCopyToken)),
                    .integer(repeatCount),
                ]
            )
        } else if let bloom = receipt.bloom {
            base = localizedTrainingResultBloom(bloom, resolver: resolver)
        } else if receipt.detail.contains("재능의 한계") {
            base = resolver.resolve(
                GameCopyKey.gameContent("content.training-result.detail.blocked"),
                arguments: [
                    .userText(resolver.resolve(TalentAbility.from(receipt.focus).displayCopyToken)),
                ]
            )
        } else if receipt.detail.hasPrefix("재활 훈련으로 팔 상태를 회복합니다.") {
            base = resolver.resolve(GameCopyKey.gameContent("content.training-result.detail.rehab"))
        } else if receipt.growth > 0 {
            let metric = resolver.resolve(receipt.focus.metricCopyToken)
            if receipt.fatigueChange < 0 {
                base = resolver.resolve(
                    GameCopyKey.gameContent("content.training-result.detail.growth-recovery"),
                    arguments: [
                        .userText(metric),
                        .integer(receipt.growth),
                        .integer(-receipt.fatigueChange),
                    ]
                )
            } else {
                base = resolver.resolve(
                    GameCopyKey.gameContent("content.training-result.detail.growth"),
                    arguments: [.userText(metric), .integer(receipt.growth)]
                )
            }
        } else if receipt.focus == .recovery, receipt.fatigueChange < 0 {
            base = resolver.resolve(
                GameCopyKey.gameContent("content.training-result.detail.recovery"),
                arguments: [.integer(-receipt.fatigueChange)]
            )
        } else if knownNoGrowthFeedback.contains(receipt.detail) {
            base = resolver.resolve(GameCopyKey.gameContent("content.training-result.detail.no-growth"))
        } else if receipt.detail.isEmpty || receipt.detail == "훈련을 마쳤습니다." {
            base = resolver.resolve(GameCopyKey.gameContent("content.training-result.detail.unknown"))
        } else {
            // A future or corrupted legacy sentence is deliberately not interpolated. The
            // structured result above is the only source allowed into English rendering.
            base = resolver.resolve(GameCopyKey.gameContent("content.training-result.detail.unknown"))
        }

        guard receipt.jackpot else { return base }
        return resolver.resolve(
            GameCopyKey.gameContent("content.training-result.detail.jackpot"),
            arguments: [.userText(base)]
        )
    }

    /// The engine still stores Korean feedback in legacy-compatible snapshots. Keep the
    /// English boundary strict: only the six current authored no-growth sentences may select
    /// the semantic no-growth token; arbitrary legacy text remains the neutral fallback.
    static let knownNoGrowthFeedback: Set<String> = [
        "오늘은 공 끝의 힘이 달라지지 않았습니다. 다음에는 투구 수나 강도를 조절해 볼 수 있습니다.",
        "미트에서 벗어나는 폭이 그대로입니다. 낮은 강도로 릴리스 지점을 먼저 맞춰 볼 수 있습니다.",
        "회전축이 손에 붙지 않았습니다. 그립과 손목 각도를 다시 잡아 볼 수 있습니다.",
        "후반 동작이 버티는 시간은 그대로입니다. 훈련 강도와 휴식 간격을 바꿔 볼 수 있습니다.",
        "몸의 무거움이 충분히 가시지 않았습니다. 다음 일정도 회복 간격을 남겨 두는 편이 좋습니다.",
        "타자 반응을 읽는 속도가 아직 공 배합으로 이어지지 않았습니다. 영상 범위를 좁혀 다시 볼 수 있습니다.",
    ]

    static func localizedTrainingFatigue(
        _ receipt: TrainingReceipt,
        resolver: GameCopyResolver
    ) -> String {
        if receipt.fatigueChange == 0 {
            return resolver.resolve(
                AppCopyKey.trainingResultFatigueSteady,
                arguments: [.integer(receipt.fatigueAfter)]
            )
        }
        return resolver.resolve(
            AppCopyKey.trainingResultFatigueChanged,
            arguments: [.integer(receipt.fatigueAfter), .integer(receipt.fatigueChange)]
        )
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
}
