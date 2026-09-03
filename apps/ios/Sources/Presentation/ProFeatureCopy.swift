import Foundation
import SimulationCore
import BaseballIOSDomain

/// 프로 Features 화면이 `resolve(..., arguments:)`를 직접 부르지 않게 하는 문구 조립.
/// 카탈로그 placeholder와 인자의 맞춤은 여기만 고치면 된다.
enum ProSeasonSettlementCopy {
    /// 아크 제목은 완결 문장이라 시즌 번호를 넣지 않는다. 기본 제목만 `%lld시즌 결산`이다.
    static func title(
        arcTitleID: String?,
        season: Int,
        resolver: GameCopyResolver
    ) -> String {
        if let key = arcTitleKey(arcTitleID) {
            return resolver.resolve(key)
        }
        return resolver.resolve(.journeySettlementTitle, arguments: [.integer(season)])
    }

    static func arcTitleKey(_ id: String?) -> ProUICopyKey? {
        switch id {
        case "pro.arc.first_half_ace": .journeyArcFirstHalfAce
        case "pro.arc.dominant": .journeyArcDominant
        case "pro.arc.long_tunnel": .journeyArcLongTunnel
        case "pro.arc.late_recovery": .journeyArcLateRecovery
        case "pro.arc.autumn_door_closed": .journeyArcAutumnDoorClosed
        case "pro.arc.autumn_champion": .journeyArcAutumnChampion
        case "pro.arc.autumn_runner_up": .journeyArcAutumnRunnerUp
        case "pro.arc.autumn_eliminated": .journeyArcAutumnEliminated
        case "pro.arc.autumn_unavailable": .journeyArcAutumnUnavailable
        case "pro.arc.quiet": .journeyArcQuiet
        default: nil
        }
    }

    static func stats(_ settlement: ProSeasonSettlement, resolver: GameCopyResolver) -> String {
        resolver.resolve(
            .journeySettlementStats,
            arguments: [
                .integer(settlement.stats.games),
                .userText(GameFormatters.innings(outs: settlement.stats.inningsOuts, language: resolver.language)),
                .integer(settlement.stats.strikeouts),
            ]
        )
    }

    static func legacy(before: Int, after: Int, resolver: GameCopyResolver) -> String {
        resolver.resolve(
            .journeySettlementLegacy,
            arguments: [.integer(before), .integer(after)]
        )
    }

    static func legacy(_ settlement: ProSeasonSettlement, resolver: GameCopyResolver) -> String {
        legacy(before: settlement.teamLegacyBefore, after: settlement.teamLegacyAfter, resolver: resolver)
    }

    static func hallOfFame(_ settlement: ProSeasonSettlement, resolver: GameCopyResolver) -> String {
        resolver.resolve(
            .journeySettlementHOF,
            arguments: [.integer(settlement.hallOfFameBefore), .integer(settlement.hallOfFameAfter)]
        )
    }

    static func contract(_ settlement: ProSeasonSettlement, resolver: GameCopyResolver) -> String {
        resolver.resolve(
            .journeySettlementContract,
            arguments: [.integer(settlement.contractYearsBefore), .integer(settlement.contractYearsAfter)]
        )
    }

    static func nextRoute(_ route: ProSettlementNextRoute, resolver: GameCopyResolver) -> String {
        let label: String = switch route {
        case .underContract: resolver.resolve(.journeySettlementNextUnderContract)
        case .renewalMarket: resolver.resolve(.journeySettlementNextRenewal)
        case .freeAgencyEligible: resolver.resolve(.journeySettlementNextFreeAgency)
        case .forcedRetirement: resolver.resolve(.journeySettlementNextRetirement)
        }
        return resolver.resolve(.journeySettlementNext, arguments: [.userText(label)])
    }

    static func salary(amount: Int64, resolver: GameCopyResolver) -> String {
        resolver.resolve(
            .journeySettlementSalary,
            arguments: [.userText(GameFormatters.krw(Int(clamping: amount), language: resolver.language))]
        )
    }

    static func fan(_ settlement: ProSeasonSettlement, resolver: GameCopyResolver) -> String {
        resolver.resolve(
            .journeySettlementFan,
            arguments: [.integer(settlement.fanBefore), .integer(settlement.fanAfter)]
        )
    }

    static func fanDelta(_ value: Int, resolver: GameCopyResolver) -> String {
        resolver.resolve(
            .journeySettlementFanDelta,
            arguments: [.userText(value >= 0 ? "+\(value)" : String(value))]
        )
    }

    static func merchandise(amount: Int64, resolver: GameCopyResolver) -> String {
        resolver.resolve(
            .journeySettlementMerchandise,
            arguments: [.userText(GameFormatters.krw(Int(clamping: amount), language: resolver.language))]
        )
    }

    static func merchandiseTier(_ tierName: String, resolver: GameCopyResolver) -> String {
        resolver.resolve(.journeySettlementMerchandiseTier, arguments: [.userText(tierName)])
    }
}

enum ProContractCopy {
    static func team(_ name: String, resolver: GameCopyResolver) -> String {
        resolver.resolve(.contractOfferTeam, arguments: [.userText(name)])
    }

    static func draftRound(_ round: Int, resolver: GameCopyResolver) -> String {
        resolver.resolve(.contractOfferDraftRound, arguments: [.integer(round)])
    }

    static func draftPick(_ pick: Int, resolver: GameCopyResolver) -> String {
        resolver.resolve(.contractOfferDraftPick, arguments: [.integer(pick)])
    }

    static func duration(years: Int, resolver: GameCopyResolver) -> String {
        resolver.resolve(.contractOfferDuration, arguments: [.integer(years)])
    }

    static func rolePromise(_ roleName: String, resolver: GameCopyResolver) -> String {
        resolver.resolve(.contractOfferRolePromise, arguments: [.userText(roleName)])
    }

    static func expectation(
        kindName: String,
        target: Int,
        difficultyName: String,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(
            .contractOfferExpectation,
            arguments: [.userText(kindName), .integer(target), .userText(difficultyName)]
        )
    }

    static func outlook(_ name: String, resolver: GameCopyResolver) -> String {
        resolver.resolve(.contractOfferOutlookLine, arguments: [.userText(name)])
    }

    static func legacyImpact(_ impact: String, resolver: GameCopyResolver) -> String {
        resolver.resolve(.contractOfferLegacyImpact, arguments: [.userText(impact)])
    }

    static func remaining(years: Int, resolver: GameCopyResolver) -> String {
        resolver.resolve(.contractOfferRemaining, arguments: [.integer(years)])
    }

    static func confirmation(
        teamName: String,
        years: Int,
        isTransfer: Bool,
        resolver: GameCopyResolver
    ) -> String {
        let arguments: [LocalizedCopyArgument] = [.userText(teamName), .integer(years)]
        return resolver.resolve(
            isTransfer ? .contractOfferConfirmTransferMessage : .contractOfferConfirmMessage,
            arguments: arguments
        )
    }

    static func interestLevel(_ level: ProClubInterest, resolver: GameCopyResolver) -> String {
        switch level {
        case .hot: resolver.resolve(.contractOfferInterestHot)
        case .warm: resolver.resolve(.contractOfferInterestWarm)
        case .cool: resolver.resolve(.contractOfferInterestCool)
        }
    }

    static func interestReasonKey(_ signal: ProClubInterestSignal) -> String {
        "content.contract.interest.\(signal.level.rawValue).\(signal.reason)"
    }

    static func interestReason(_ signal: ProClubInterestSignal, resolver: GameCopyResolver) -> String {
        resolver.resolve(.gameContent(interestReasonKey(signal)))
    }

    static func counterKindTitle(_ kind: ProContractCounterKind, resolver: GameCopyResolver) -> String {
        switch kind {
        case .extraYear: resolver.resolve(.contractOfferCounterExtraYear)
        case .raiseSalary: resolver.resolve(.contractOfferCounterRaiseSalary)
        }
    }

    static func counterUnavailable(_ reason: ProCounterUnavailableReason, resolver: GameCopyResolver) -> String {
        resolver.resolve(.gameContent("content.contract.counter.unavailable.\(reason.rawValue)"))
    }
}

enum ProWeeklyCopy {
    static func progress(
        _ plan: ProWeekPlan,
        state: ProCareerSnapshot,
        resolver: GameCopyResolver
    ) -> String {
        let required = MobileCareerStore.developmentTicksRequired(
            for: plan,
            pitcher: state.pitcher,
            proRulesVersion: state.proRulesVersion
        ) ?? 2
        // 노장 하락으로 능력 밴드가 내려가면 저장된 게이지가 새 임계값보다 클 수 있다.
        let current = min(state.developmentProgress?.value(for: plan) ?? 0, required)
        return resolver.resolve(
            .weeklyProgress,
            arguments: [.integer(current), .integer(required)]
        )
    }

    /// 게이지 숫자. 회복·신뢰처럼 게이지가 없는 계획은 nil.
    static func progressValues(
        _ plan: ProWeekPlan,
        state: ProCareerSnapshot
    ) -> (current: Int, required: Int)? {
        switch plan {
        case .developStuff, .developMovement, .refineCommand, .buildStamina:
            break
        default:
            return nil
        }
        let required = MobileCareerStore.developmentTicksRequired(
            for: plan,
            pitcher: state.pitcher,
            proRulesVersion: state.proRulesVersion
        ) ?? 2
        let current = min(state.developmentProgress?.value(for: plan) ?? 0, required)
        return (current, max(1, required))
    }

    static func injuryRisk(forecast: ProWeekHealthForecast, resolver: GameCopyResolver) -> String {
        resolver.resolve(.weeklyInjuryRisk, arguments: [
            .userText(injuryBandName(forecast.band, resolver: resolver)),
            .integer(forecast.expectedEffectiveFatigue),
        ])
    }

    static func injuryBandName(_ band: ProWeekInjuryRiskBand, resolver: GameCopyResolver) -> String {
        let bandKey: ProUICopyKey = switch band {
        case .low: .weeklyInjuryRiskLow
        case .caution: .weeklyInjuryRiskCaution
        case .high: .weeklyInjuryRiskHigh
        }
        return resolver.resolve(bandKey)
    }

    /// 부상 위험 칩 — "부상 낮음".
    static func injuryChip(_ band: ProWeekInjuryRiskBand, resolver: GameCopyResolver) -> String {
        resolver.resolve(.weeklyInjuryChip, arguments: [.userText(injuryBandName(band, resolver: resolver))])
    }

    /// 이득 칩 — "구위 ▲".
    static func gainChip(_ name: String, resolver: GameCopyResolver) -> String {
        resolver.resolve(.weeklyGainChip, arguments: [.userText(name)])
    }

    /// 이번 주 예상 피로 변화 칩 — 원피로(다음 주 피로 타일에 찍힐 값)와 현재 피로의 차이.
    /// 오르면 "훈련 피로 +N", 내리면(회복) "피로 −N".
    static func fatigueChip(delta: Int, resolver: GameCopyResolver) -> String {
        if delta > 0 {
            return resolver.resolve(.weeklyTrainingFatigueChip, arguments: [.integer(delta)])
        }
        return resolver.resolve(
            delta < 0 ? .effectFatigueLoss : .effectFatigueGain,
            arguments: [.integer(abs(delta))]
        )
    }

    /// 체력이 덜어 주는 몫 — 원피로와 부상 판정용 유효 피로의 차이. 예전에는 이 몫이
    /// 피로 칩에 섞여 강훈련이 "피로 −12"(초록)로 보였다. 0 이하면 nil.
    static func staminaOffsetChip(rawFatigue: Int, effectiveFatigue: Int, resolver: GameCopyResolver) -> String? {
        let offset = rawFatigue - effectiveFatigue
        guard offset > 0 else { return nil }
        return resolver.resolve(.weeklyStaminaOffsetChip, arguments: [.integer(offset)])
    }

    /// 상태 타일 아래 변화 캡션 — "이번 주 +3".
    static func deltaCaption(_ delta: Int, resolver: GameCopyResolver) -> String {
        resolver.resolve(
            .weeklyDeltaCaption,
            arguments: [.userText(delta >= 0 ? "+\(delta)" : "−\(abs(delta))")]
        )
    }

    /// 이번 계획이 키우는 능력의 이름들. 칩 한 개당 이름 하나.
    static func gainNames(_ plan: ProWeekPlan, resolver: GameCopyResolver) -> [String] {
        switch plan {
        case .developStuff: [resolver.resolve(TalentAbility.stuff.displayCopyToken)]
        case .developMovement: [resolver.resolve(TalentAbility.movement.displayCopyToken)]
        case .refineCommand: [resolver.resolve(TalentAbility.command.displayCopyToken)]
        case .buildStamina: [resolver.resolve(TalentAbility.stamina.displayCopyToken)]
        case .earnTrust: [resolver.resolve(ProUICopyKey.weeklyManagerTrust)]
        default: []
        }
    }

    static func developStuffEffect(progress: String, resolver: GameCopyResolver) -> String {
        resolver.resolve(.weeklyDevelopStuffEffect, arguments: [.userText(progress)])
    }

    static func developMovementEffect(progress: String, resolver: GameCopyResolver) -> String {
        resolver.resolve(.weeklyDevelopMovementEffect, arguments: [.userText(progress)])
    }

    static func commandEffect(progress: String, resolver: GameCopyResolver) -> String {
        resolver.resolve(.weeklyCommandEffect, arguments: [.userText(progress)])
    }

    static func goalBoardTitle(_ row: ProGoalBoardRow, resolver: GameCopyResolver) -> String {
        resolver.resolve(.gameContent(row.titleKey))
    }

    static func goalBoardHint(_ row: ProGoalBoardRow, resolver: GameCopyResolver) -> String {
        resolver.resolve(.gameContent(row.hintKey))
    }

    static func goalBoardLine(_ row: ProGoalBoardRow, resolver: GameCopyResolver) -> String {
        resolver.resolve(
            .weeklyGoalBoardLine,
            arguments: [
                .userText(goalBoardTitle(row, resolver: resolver)),
                .integer(row.current),
                .integer(row.target),
            ]
        )
    }

    static func staminaEffect(progress: String, resolver: GameCopyResolver) -> String {
        resolver.resolve(.weeklyStaminaEffect, arguments: [.userText(progress)])
    }

    static func blueprint(_ buildLabel: String, resolver: GameCopyResolver) -> String {
        resolver.resolve(.weeklyBlueprint, arguments: [.userText(buildLabel)])
    }

    static func rolePromise(_ roleName: String, resolver: GameCopyResolver) -> String {
        resolver.resolve(.weeklyRolePromise, arguments: [.userText(roleName)])
    }

    static func standingSchedule(roleName: String, remainingOutings: Int, resolver: GameCopyResolver) -> String {
        resolver.resolve(
            .weeklyStandingSchedule,
            arguments: [.userText(roleName), .integer(remainingOutings)]
        )
    }

    static func routine(arcName: String, roleName: String, resolver: GameCopyResolver) -> String {
        resolver.resolve(.weeklyRoutine, arguments: [.userText(arcName), .userText(roleName)])
    }

    static func pitchLearningTitle(_ pitchName: String, resolver: GameCopyResolver) -> String {
        resolver.resolve(AppCopyKey.trainingPitchLearningTitle, arguments: [.userText(pitchName)])
    }

    static func pitchLearningProgress(
        practiceCredits: Int,
        qualityUses: Int,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(
            AppCopyKey.trainingPitchLearningProgress,
            arguments: [
                .integer(practiceCredits),
                .integer(CareerDisplayRules.pitchLearningPracticeCap),
                .integer(qualityUses),
                .integer(CareerDisplayRules.pitchLearningQualityUses),
            ]
        )
    }

    static func planUntil(_ segmentName: String, resolver: GameCopyResolver) -> String {
        resolver.resolve(AppCopyKey.proWeeklyPlanUntil, arguments: [.userText(segmentName)])
    }
}

enum ProRoleRequestCopy {
    static func accessibilityID(for role: ProRole) -> String {
        "pro.roleRequest.\(role.rawValue)"
    }

    static func outlook(_ outlook: ProRoleRequestOutlook, resolver: GameCopyResolver) -> String {
        let key: ProUICopyKey = switch outlook {
        case .likely: .roleRequestOutlookLikely
        case .conditional: .roleRequestOutlookConditional
        case .difficult: .roleRequestOutlookDifficult
        }
        return resolver.resolve(key)
    }

    static func condition(
        role: ProRole,
        evaluation: ProRoleRequestEvaluation,
        state: ProCareerSnapshot,
        resolver: GameCopyResolver
    ) -> String {
        if CareerDisplayRules.isAlreadyAssignedRole(role, state: state) {
            return resolver.resolve(.roleRequestConditionAssigned)
        }
        switch evaluation.requested {
        case .longRelief, .setup:
            return resolver.resolve(.roleRequestConditionMiddle)
        case .starter:
            switch evaluation.outlook {
            case .likely:
                return resolver.resolve(.roleRequestConditionStarterLikely, arguments: [
                    .integer(state.pitcher.stamina),
                    .integer(state.managerTrust),
                ])
            case .conditional:
                return resolver.resolve(.roleRequestConditionStarterConditional, arguments: [
                    .integer(state.pitcher.stamina),
                ])
            case .difficult:
                return resolver.resolve(.roleRequestConditionStarterDifficult, arguments: [
                    .integer(state.pitcher.stamina),
                ])
            }
        case .closer:
            switch evaluation.outlook {
            case .likely:
                return resolver.resolve(.roleRequestConditionCloserLikely, arguments: [
                    .integer(state.pitcher.stuff),
                    .integer(state.catcherTrust),
                ])
            case .conditional:
                return resolver.resolve(.roleRequestConditionCloserConditional, arguments: [
                    .integer(state.pitcher.stuff),
                ])
            case .difficult:
                return resolver.resolve(.roleRequestConditionCloserDifficult, arguments: [
                    .integer(state.pitcher.stuff),
                ])
            }
        }
    }
}

enum ProOffseasonCopy {
    static func openMarketServiceLocked(service: Int, resolver: GameCopyResolver) -> String {
        resolver.resolve(.offseasonOpenMarketServiceLocked, arguments: [.integer(service)])
    }

    static func eyebrow(season: Int, age: Int, resolver: GameCopyResolver) -> String {
        resolver.resolve(.offseasonEyebrow, arguments: [.integer(season), .integer(age)])
    }

    static func years(_ service: Int, resolver: GameCopyResolver) -> String {
        resolver.resolve(.offseasonYears, arguments: [.integer(service)])
    }

    static func seasons(_ count: Int, resolver: GameCopyResolver) -> String {
        resolver.resolve(.offseasonSeasons, arguments: [.integer(count)])
    }

    static func renewalDetail(teamName: String, resolver: GameCopyResolver) -> String {
        resolver.resolve(.offseasonRenewalDetail, arguments: [.userText(teamName)])
    }

    static func activeContractDetail(teamName: String, years: Int, resolver: GameCopyResolver) -> String {
        resolver.resolve(
            .offseasonActiveContractDetail,
            arguments: [.userText(teamName), .integer(years)]
        )
    }

    static func continueDetail(teamName: String, resolver: GameCopyResolver) -> String {
        resolver.resolve(.offseasonContinueDetail, arguments: [.userText(teamName)])
    }

    static func confirmRetireMessage(seasons: Int, resolver: GameCopyResolver) -> String {
        resolver.resolve(.offseasonConfirmRetireMessage, arguments: [.integer(seasons)])
    }

    static func confirmMilitaryMessage(ageAfter: Int, resolver: GameCopyResolver) -> String {
        resolver.resolve(.offseasonConfirmMilitaryMessage, arguments: [.integer(ageAfter)])
    }

    static func confirmContinueMessage(teamName: String, nextSeason: Int, resolver: GameCopyResolver) -> String {
        resolver.resolve(
            .offseasonConfirmContinueMessage,
            arguments: [.userText(teamName), .integer(nextSeason)]
        )
    }

    static func investmentDetail(nextSeason: Int, resolver: GameCopyResolver) -> String {
        resolver.resolve(.offseasonInvestmentDetail, arguments: [.integer(nextSeason)])
    }

    static func investmentFunds(available: Int64, resolver: GameCopyResolver) -> String {
        resolver.resolve(
            .offseasonInvestmentFunds,
            arguments: [.userText(GameFormatters.krw(Int(clamping: available), language: resolver.language))]
        )
    }

    static func investmentCost(amount: Int64, resolver: GameCopyResolver) -> String {
        resolver.resolve(
            .offseasonInvestmentCost,
            arguments: [.userText(GameFormatters.krw(Int(clamping: amount), language: resolver.language))]
        )
    }

    static func investmentBenefit(_ benefit: String, resolver: GameCopyResolver) -> String {
        resolver.resolve(.offseasonInvestmentBenefit, arguments: [.userText(benefit)])
    }

    static func investmentDuration(_ duration: String, resolver: GameCopyResolver) -> String {
        resolver.resolve(.offseasonInvestmentDuration, arguments: [.userText(duration)])
    }

    static func investmentConfirmMessage(choice: String, benefit: String, resolver: GameCopyResolver) -> String {
        resolver.resolve(
            .offseasonInvestmentConfirmMessage,
            arguments: [.userText(choice), .userText(benefit)]
        )
    }

    static func pitchLabBenefit(focusTitle: String, resolver: GameCopyResolver) -> String {
        resolver.resolve(.offseasonInvestmentPitchLabBenefit, arguments: [.userText(focusTitle)])
    }
}

enum ProInjuryCopy {
    static func title(recoveryWeeks: Int, resolver: GameCopyResolver) -> String {
        resolver.resolve(.injuryResultTitle, arguments: [.integer(recoveryWeeks)])
    }

    static func body(season: Int, week: Int, resolver: GameCopyResolver) -> String {
        resolver.resolve(.injuryResultBody, arguments: [.integer(season), .integer(week)])
    }

    static func plan(_ planLabel: String, resolver: GameCopyResolver) -> String {
        resolver.resolve(.injuryResultPlan, arguments: [.userText(planLabel)])
    }

    static func evidence(
        rawFatigue: Int,
        effectiveFatigue: Int,
        pitches: Int,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(
            .injuryResultEvidence,
            arguments: [.integer(rawFatigue), .integer(effectiveFatigue), .integer(pitches)]
        )
    }
}

enum ProRetirementCopy {
    static func eyebrow(age: Int, seasons: Int, resolver: GameCopyResolver) -> String {
        resolver.resolve(.retirementEyebrow, arguments: [.integer(age), .integer(seasons)])
    }

    static func confirmMessage(seasons: Int, resolver: GameCopyResolver) -> String {
        resolver.resolve(.retirementConfirmMessage, arguments: [.integer(seasons)])
    }

    static func previewScore(_ score: Int, resolver: GameCopyResolver) -> String {
        resolver.resolve(.retirementPreviewScore, arguments: [.integer(score)])
    }

    static func previewRetiredNumber(
        lastTeamSeasons: Int,
        lastTeamLegacy: Int,
        fanSupport: Int,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(
            .retirementPreviewRetiredNumber,
            arguments: [.integer(lastTeamSeasons), .integer(lastTeamLegacy), .integer(fanSupport)]
        )
    }

    static func retiredTitle(name: String, resolver: GameCopyResolver) -> String {
        resolver.resolve(.retiredTitle, arguments: [.userText(name)])
    }

    static func identityLine(teamName: String, seasons: Int, resolver: GameCopyResolver) -> String {
        resolver.resolve(
            .retiredIdentityLine,
            arguments: [
                .userText(teamName),
                .userText(Self.seasons(seasons, resolver: resolver)),
            ]
        )
    }

    static func seasons(_ count: Int, resolver: GameCopyResolver) -> String {
        resolver.resolve(.offseasonSeasons, arguments: [.integer(count)])
    }

    static func finalScore(_ score: Int, resolver: GameCopyResolver) -> String {
        resolver.resolve(.retirementFinalScore, arguments: [.integer(score)])
    }

    static func soulPoints(_ points: Int, resolver: GameCopyResolver) -> String {
        resolver.resolve(.retiredSoulPoints, arguments: [.integer(points)])
    }

    static func confirmNewPlayer(name: String, isLegacy: Bool, resolver: GameCopyResolver) -> String {
        resolver.resolve(
            isLegacy ? .retiredLegacyConfirmMessage : .retiredSoulConfirmMessage,
            arguments: [.userText(name)]
        )
    }

    static func honorScore(_ score: Int, resolver: GameCopyResolver) -> String {
        resolver.resolve(.retirementHonorScore, arguments: [.integer(score)])
    }

    static func honorTeam(_ teamName: String, resolver: GameCopyResolver) -> String {
        resolver.resolve(.retirementHonorTeam, arguments: [.userText(teamName)])
    }

    static func honorValue(_ value: String, resolver: GameCopyResolver) -> String {
        resolver.resolve(.retirementHonorValue, arguments: [.userText(value)])
    }
}

enum ProDecisionCopy {
    static func eyebrow(
        season: Int,
        week: Int,
        resolver: GameCopyResolver,
        weekly: Bool = false
    ) -> String {
        if weekly {
            return resolver.resolve(.decisionWeeklyEyebrow, arguments: [.integer(season), .integer(week)])
        }
        return resolver.resolve(.decisionEyebrow, arguments: [.integer(season), .integer(week)])
    }

    static func confirmMessage(
        detail: String,
        effect: String,
        timing: String,
        resolver: GameCopyResolver
    ) -> String {
        // 알럿 본문은 효과 한 줄과 비가역 안내만 싣는다(1.2.9). detail·timing은 카드에 이미 있어
        // 여기서 되풀이하지 않는다 — 호출 계약은 그대로 두고 문구만 줄였다.
        _ = (detail, timing)
        return resolver.resolve(.decisionConfirmMessage, arguments: [.userText(effect)])
    }

    static func accessibilityLabel(
        for choice: ProSeasonDecisionChoice,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(
            ProUICopyKey.decisionAccessibility,
            arguments: [
                .userText(ProCareerPresentation.choiceTitle(choice, resolver: resolver)),
                .userText(ProCareerPresentation.choiceDetail(choice, resolver: resolver)),
                .userText(ProCareerPresentation.combinedEffect(
                    choice.effect,
                    journeyEffect: choice.journeyEffect,
                    resolver: resolver
                )),
                .userText(ProCareerPresentation.decisionTiming(for: choice, resolver: resolver)),
            ]
        )
    }

    static func summaryLine(
        season: Int,
        week: Int,
        effect: String,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(
            .summaryDecisionLine,
            arguments: [.integer(season), .integer(week), .userText(effect)]
        )
    }
}

enum ProImportantGameCopy {
    static func eyebrow(season: Int, week: Int, resolver: GameCopyResolver) -> String {
        resolver.resolve(.importantEyebrow, arguments: [.integer(season), .integer(week)])
    }

    static func seriesLastGame(
        _ line: ProPostseasonGameLine,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(
            line.won ? .postseasonSeriesLastGameWin : .postseasonSeriesLastGameLoss,
            arguments: [
                .integer(line.gameNumber),
                .integer(line.teamRuns),
                .integer(line.opponentRuns),
            ]
        )
    }

    static func seriesLastAppearance(
        pitches: Int,
        runs: Int,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(
            .postseasonSeriesLastAppearance,
            arguments: [.integer(pitches), .integer(runs)]
        )
    }

    static func seriesLastPitches(_ pitches: Int, resolver: GameCopyResolver) -> String {
        resolver.resolve(.postseasonSeriesLastPitches, arguments: [.integer(pitches)])
    }

    static func availabilityBody(
        key: ProUICopyKey,
        pitches: Int,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(key, arguments: [.integer(pitches)])
    }

    static func availabilityPitchDetail(
        penalty: Int,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(.postseasonAvailabilityPitchDetail, arguments: [.integer(penalty)])
    }

    static func availabilityRisk(
        key: ProUICopyKey,
        projectedFatigue: Int,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(key, arguments: [.integer(projectedFatigue)])
    }
}

enum ProNationalTeamCopy {
    static func resultTitle(
        _ result: ProNationalTournamentResult?,
        resolver: GameCopyResolver
    ) -> String {
        let key: ProUICopyKey = switch result {
        case .gold: .nationalResultGold
        case .silver: .nationalResultSilver
        case .bronze: .nationalResultBronze
        case .groupExit: .nationalResultGroupExit
        case .none: .nationalResultGroupExit
        }
        return resolver.resolve(key)
    }

    static func callSummary(
        marketScore: Int,
        fanSupport: Int,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(
            .nationalTeamCallSummary,
            arguments: [.integer(marketScore), .integer(fanSupport)]
        )
    }

    static func groupRecord(wins: Int, games: Int, resolver: GameCopyResolver) -> String {
        resolver.resolve(
            .nationalTournamentGroupRecord,
            arguments: [.integer(wins), .integer(games)]
        )
    }

    static func resultFan(delta: Int, resolver: GameCopyResolver) -> String {
        resolver.resolve(.nationalTeamResultFan, arguments: [.integer(delta)])
    }
}
