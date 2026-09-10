import SwiftUI
import SimulationCore
import BaseballIOSDomain

struct DraftCard: View {
    let state: HighSchoolCareerSnapshot
    let chronicle: [ChronicleEntry]
    let career: HighSchoolCareerStore
    let onResolve: () -> Void
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            BaseballCard(title: copyResolver.resolve(AppCopyKey.conclusionDraftTitle), tone: .milestone) {
                Text(copyResolver.resolve(AppCopyKey.conclusionDraftIntro))
                    .font(.subheadline)
            }
            if let personality = career.personality {
                let personalityTitle = HighSchoolConclusionPresentation.localizedPersonalityTitle(
                    personality, resolver: copyResolver
                )
                BaseballCard(title: copyResolver.resolve(AppCopyKey.conclusionScoutTitle)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("'\(personalityTitle)'")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(BaseballTheme.milestone)
                        Text(HighSchoolConclusionPresentation.localizedPersonalityScoutLine(
                            personality, resolver: copyResolver
                        ))
                            .detailStyle()
                    }
                }
            }
            BaseballCard(title: copyResolver.resolve(AppCopyKey.conclusionRecordTitle)) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(copyResolver.resolve(
                        AppCopyKey.conclusionOfficialGames,
                        arguments: [.integer(state.performance.importantGamesCompleted)]
                    ))
                    Text(copyResolver.resolve(
                        AppCopyKey.conclusionRecordStats,
                        arguments: [
                            .integer(state.performance.strikeouts), .integer(state.performance.walks),
                            .integer(state.performance.runsAllowed),
                        ]
                    ))
                    Text(copyResolver.resolve(
                        AppCopyKey.conclusionAwakeningTraining,
                        arguments: [.integer(state.selectedAwakenings.count), .integer(state.totalTrainingsCompleted)]
                    ))
                }
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(BaseballTheme.textSecondary)
            }
            // 자동으로 흘러간 팀 경기도 평가에 들어간다. 여기 보여 주지 않으면
            // 드래프트 카드의 "시즌 기록 +N"이 어디서 나온 숫자인지 알 수 없다.
            if let log = state.seasonLog, !log.isEmpty {
                SeasonRecordCard(log: log)
            }
            ChronicleCard(entries: chronicle)
            PrimaryButton(
                title: copyResolver.resolve(AppCopyKey.conclusionResolveDraft),
                identifier: "hs.draft.resolve",
                action: onResolve
            )
        }
    }
}

/// 미지명·지명 직후, 왜 그 점수가 나왔는지를 한 장으로 보여 준다.
struct DraftReasonCard: View {
    let state: HighSchoolCareerSnapshot
    let bestPast: Int
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        if let draft = state.draftResult {
            let breakdown = HighSchoolCareerStore.draftEvaluationBreakdown(state: state)
            let drafted = draft.outcome == .drafted
            let gap = abs(draft.evaluationScore - breakdown.threshold)
            let ranked = breakdown.items.sorted { lhs, rhs in
                drafted ? lhs.points > rhs.points : lhs.points < rhs.points
            }
            let chips = Array(ranked.prefix(2))
            BaseballCard(
                title: copyResolver.resolve(
                    drafted ? AppCopyKey.draftReasonShortDrafted : AppCopyKey.draftReasonShortUndrafted,
                    arguments: [.integer(gap)]
                ),
                tone: drafted ? .positive : .negative
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    if bestPast == 0 {
                        Text(copyResolver.resolve(
                            AppCopyKey.conclusionEvaluationScore,
                            arguments: [.integer(draft.evaluationScore)]
                        ))
                        .font(BaseballType.heroNumeral)
                        .foregroundStyle(drafted ? BaseballTheme.positive : BaseballTheme.textPrimary)
                    }
                    EffectChipFlow {
                        ForEach(chips) { item in
                            EffectChip(
                                text: chipText(
                                    id: item.id,
                                    points: item.points,
                                    shortfall: drafted ? 0 : gap,
                                    ratingAverage: breakdown.ratingAverage
                                ),
                                tone: item.points >= 0 ? .gain : .cost
                            )
                        }
                    }
                    if !drafted, let weakest = ranked.first {
                        Text(verbatim: copyResolver.resolve(adviceKey(for: weakest.id)))
                            .detailStyle()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .accessibilityIdentifier("hs.bestEvaluation")
        }
    }

    private func chipText(id: String, points: Int, shortfall: Int, ratingAverage: Int) -> String {
        if id == "rating", shortfall > 0 {
            return copyResolver.resolve(
                AppCopyKey.draftReasonChipRating,
                arguments: [.integer(ratingAverage), .integer(shortfall)]
            )
        }
        let name = copyResolver.resolve(nameKey(for: id))
        if points >= 0 {
            return copyResolver.resolve(
                AppCopyKey.draftReasonChipGain,
                arguments: [.userText(name), .integer(points)]
            )
        }
        return copyResolver.resolve(
            AppCopyKey.draftReasonChipCost,
            arguments: [.userText(name), .integer(-points)]
        )
    }

    private func nameKey(for id: String) -> GameCopyKey {
        switch id {
        case "rating": AppCopyKey.draftReasonRating
        case "performance": AppCopyKey.draftReasonPerformance
        case "awakening": AppCopyKey.draftReasonAwakening
        case "relationship": AppCopyKey.draftReasonRelationship
        case "overuse": AppCopyKey.draftReasonOveruse
        case "season": AppCopyKey.draftReasonSeason
        case "fan": AppCopyKey.draftReasonFan
        default: AppCopyKey.draftReasonKarma
        }
    }

    private func adviceKey(for id: String) -> GameCopyKey {
        switch id {
        case "rating": AppCopyKey.draftReasonAdviceRating
        case "performance": AppCopyKey.draftReasonAdvicePerformance
        case "awakening": AppCopyKey.draftReasonAdviceAwakening
        case "relationship": AppCopyKey.draftReasonAdviceRelationship
        case "overuse": AppCopyKey.draftReasonAdviceOveruse
        case "season": AppCopyKey.draftReasonAdviceSeason
        case "fan": AppCopyKey.draftReasonAdviceFan
        default: AppCopyKey.draftReasonAdviceKarma
        }
    }
}

/// 드래프트 직후 1화면. 도장·점수·이유 칩 2개·주 행동 하나만.
struct DraftPeakResultView: View {
    let state: HighSchoolCareerSnapshot
    let drafted: Bool
    /// 회차를 시작할 때의 능력. 없으면 성장 막대만 접힌다(이 필드가 없던 구저장본).
    var startingPitcher: PitcherSnapshot?
    let onContinue: () -> Void
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            if let draft = state.draftResult {
                // 지명 결과가 먼저다. 점수와 근거보다 "어느 구단이 몇 번째로 불렀는가"가
                // 3년의 대답이다(6-C).
                draftDestination(draft)
                let breakdown = HighSchoolCareerStore.draftEvaluationBreakdown(state: state)
                let ranked = breakdown.items.sorted { lhs, rhs in
                    draft.outcome == .drafted ? lhs.points > rhs.points : lhs.points < rhs.points
                }
                let chips = Array(ranked.prefix(2))
                Text(verbatim: copyResolver.resolve(draft.outcome.displayCopyToken))
                    .font(BaseballType.display)
                    .foregroundStyle(draft.outcome == .drafted ? BaseballTheme.positive : BaseballTheme.negative)
                Text(copyResolver.resolve(
                    AppCopyKey.conclusionEvaluationScore,
                    arguments: [.integer(draft.evaluationScore)]
                ))
                .font(BaseballType.heroNumeral)
                .foregroundStyle(BaseballTheme.textPrimary)
                .accessibilityIdentifier("hs.bestEvaluation")
                EffectChipFlow {
                    ForEach(chips) { item in
                        EffectChip(
                            text: item.points >= 0
                                ? copyResolver.resolve(
                                    AppCopyKey.draftReasonChipGain,
                                    arguments: [
                                        .userText(copyResolver.resolve(nameKey(for: item.id))),
                                        .integer(item.points),
                                    ]
                                )
                                : copyResolver.resolve(
                                    AppCopyKey.draftReasonChipCost,
                                    arguments: [
                                        .userText(copyResolver.resolve(nameKey(for: item.id))),
                                        .integer(-item.points),
                                    ]
                                ),
                            tone: item.points >= 0 ? .gain : .cost
                        )
                    }
                }
                journeySummary
                CareerShareButton(
                    model: CareerSharePresentation.draft(
                        result: draft,
                        state: state,
                        resolver: copyResolver
                    )
                )
            }
            PrimaryButton(
                title: copyResolver.resolve(
                    drafted ? AppCopyKey.conclusionEnterPro : AppCopyKey.draftResultPrepareNext
                ),
                identifier: "hs.draft.result.continue",
                action: onContinue
            )
        }
    }

    /// 지명 구단 · 라운드 · 전체 순위. 미지명이면 그 사실 한 줄.
    @ViewBuilder
    private func draftDestination(_ draft: DraftResultSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: draft.team.map {
                ProCareerPresentation.teamName($0, resolver: copyResolver)
            } ?? copyResolver.resolve(AppCopyKey.draftJourneyUndrafted))
            .font(.title2.weight(.bold))
            .foregroundStyle(BaseballTheme.milestone)
            if let round = draft.round, let pick = draft.overallPick {
                Text(copyResolver.resolve(
                    AppCopyKey.draftJourneyPick,
                    arguments: [.integer(round), .integer(pick)]
                ))
                .detailStyle(BaseballTheme.textPrimary)
                .monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("hs.draft.journey.destination")
    }

    /// 3년이 남긴 것. 신분 카드(이름·학교·얼굴)는 회차 카드가 이미 한 장으로 보여 주므로
    /// 여기서 되풀이하지 않는다 — 여기 있는 것은 **여정의 숫자**뿐이다(6-C).
    @ViewBuilder
    private var journeySummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(copyResolver.resolve(
                AppCopyKey.draftJourneyRecord,
                arguments: [
                    .integer(state.performance.importantGamesCompleted),
                    .userText(GameFormatters.innings(
                        outs: state.performance.outs ?? 0,
                        language: copyResolver.language
                    )),
                    .integer(state.performance.strikeouts),
                ]
            ))
            .proseStyle()
            .monospacedDigit()
            .accessibilityIdentifier("hs.draft.journey.record")

            if let startingPitcher {
                Text(copyResolver.resolve(AppCopyKey.draftJourneyGrowth))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(BaseballTheme.textPrimary)
                ProAbilityPanel(
                    pitcher: state.pitcher,
                    previous: AbilityHistoryPoint(
                        season: 0,
                        stuff: startingPitcher.stuff,
                        command: startingPitcher.command,
                        movement: startingPitcher.movement,
                        stamina: startingPitcher.stamina
                    ),
                    identifierPrefix: "hs.draft.journey.ability"
                )
            }

            Text(copyResolver.resolve(
                AppCopyKey.draftJourneyEffort,
                arguments: [
                    .integer(state.totalTrainingsCompleted),
                    .integer(state.relationshipsCompleted),
                ]
            ))
            .detailStyle(BaseballTheme.textPrimary)
            .monospacedDigit()
            .accessibilityIdentifier("hs.draft.journey.effort")

            EffectChip(
                text: ProCareerPresentation.buildLabel(
                    CareerDisplayRules.pitcherIdentity(for: state.pitcher),
                    resolver: copyResolver
                ),
                tone: .neutral,
                systemImage: "figure.baseball"
            )
            .accessibilityIdentifier("hs.draft.journey.build")

            coachFarewell
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 감독의 마지막 한마디. 3년을 함께한 사람이 무슨 말로 보내는지는 **쌓은 믿음**이 정한다.
    @ViewBuilder
    private var coachFarewell: some View {
        let trust = state.managerTrust ?? state.relationshipTrust
        let quote = copyResolver.resolve(
            trust >= DraftPeakResultView.trustedFarewellThreshold
                ? AppCopyKey.draftJourneyCoachTrusted
                : AppCopyKey.draftJourneyCoachNext
        )
        if let school = state.school {
            AvatarRow(
                // 시드는 관계 카드와 **같은 원본 이름**이어야 한다. 현지화된 표시 이름으로
                // 시드를 주면 같은 감독이 화면마다 다른 얼굴이 된다.
                seed: school.coachName,
                role: .coach,
                name: HighSchoolPresentation.localizedSchoolCastName(
                    school,
                    rawRegion: state.identity.region,
                    role: .coach,
                    resolver: copyResolver
                ),
                caption: quote,
                size: 56
            )
            .accessibilityIdentifier("hs.draft.journey.coach")
        } else {
            Text(verbatim: quote)
                .proseStyle()
                .accessibilityIdentifier("hs.draft.journey.coach")
        }
    }

    /// 주간 화면·자격 보드와 같은 "믿음이 두터운" 선. 안드로이드도 같은 65다.
    static let trustedFarewellThreshold = 65

    private func nameKey(for id: String) -> GameCopyKey {
        switch id {
        case "rating": AppCopyKey.draftReasonRating
        case "performance": AppCopyKey.draftReasonPerformance
        case "awakening": AppCopyKey.draftReasonAwakening
        case "relationship": AppCopyKey.draftReasonRelationship
        case "overuse": AppCopyKey.draftReasonOveruse
        case "season": AppCopyKey.draftReasonSeason
        case "fan": AppCopyKey.draftReasonFan
        default: AppCopyKey.draftReasonKarma
        }
    }
}

struct LegacyCard: View {
    @State private var confirmingLegacy = false
    @Environment(\.gameCopyResolver) private var copyResolver

    let career: HighSchoolCareerStore
    let state: HighSchoolCareerSnapshot
    var includeReason = true

    var body: some View {
        let signatureCandidates = career.usesSignatureLegacyRules
            ? career.signatureLegacyCandidates(for: state)
            : []
        let selectedSignatureLegacy = signatureCandidates.first {
            $0.id == career.selectedSignatureLegacyID
        }
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            DisclosureGroup(copyResolver.resolve(.localizable("mobile.core.career-details"))) {
            if includeReason {
            DraftReasonCard(
                state: state,
                bestPast: career.archive
                    .filter { $0.lifeNumber != state.lifeNumber }
                    .map(\.evaluationScore).max() ?? 0
            )
            }
            // 아직 접지 않은 회차의 카드를 미리 만들어 보여 준다. 3년을 함께한
            // 선수의 얼굴·별명·기록이 한 장에 담긴 것을 보고 나서 작별하는 것과,
            // 숫자 목록을 보고 작별하는 것은 다른 경험이다.
            let provisional = HighSchoolCareerStore.lifeRecord(
                from: state, memories: career.selectedMemories, previous: career.inheritance,
                nicknames: career.nicknames, chronicle: career.chronicle,
                personality: career.personality,
                signatureLegacy: selectedSignatureLegacy,
                signatureLegacyCandidates: signatureCandidates,
                bondMemories: career.bondMemories,
                startingPitcher: career.careerStartingPitcher
            )
            BaseballCard(title: copyResolver.resolve(AppCopyKey.conclusionPlayerRecordCard), tone: .milestone) {
                VStack(alignment: .leading, spacing: 10) {
                    LifeCardPreview(record: provisional)
                    LifeCardShareButton(record: provisional)
                }
            }
            ChronicleCard(entries: career.chronicle)
            if !career.bondMemories.isEmpty {
                PlayerBondMemoryList(
                    memories: career.bondMemories,
                    surface: .conclusion,
                    lifeNumber: state.lifeNumber
                )
            }
            if let draft = state.draftResult {
                let signature = draft.team.map { HighSchoolConclusionPresentation.localizedTeamName($0, resolver: copyResolver) }
                let projected = HighSchoolConclusionPresentation.localizedDraftProjectedRange(
                    draft.projectedRange, resolver: copyResolver
                )
                let summary = HighSchoolConclusionPresentation.localizedDraftSummary(
                    draft, resolver: copyResolver
                )
                let firstSeasonGoal = HighSchoolConclusionPresentation.localizedFirstSeasonGoal(
                    draft.firstSeasonGoal, resolver: copyResolver
                )
                BaseballCard(title: copyResolver.resolve(draft.outcome.displayCopyToken),
                             tone: draft.outcome == .drafted ? .positive : .negative) {
                    VStack(alignment: .leading, spacing: 10) {
                        // localization-safe: resolved-copy
                        Text(summary).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                        // localization-safe: resolved-copy
                        Text(projected)
                            .font(BaseballType.annotation.weight(.semibold).monospacedDigit())
                            .foregroundStyle(BaseballTheme.milestone)
                        if let firstSeasonGoal {
                            // localization-safe: resolved-copy
                            Text(firstSeasonGoal)
                                .font(.caption)
                                .foregroundStyle(BaseballTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if let signature {
                            // localization-safe: resolved-copy
                            Text(signature)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BaseballTheme.information)
                        }
                        // 무엇이 점수를 만들었는지. 이게 없으면 3년 동안 쌓은 것들이
                        // 결과에 어떻게 반영됐는지 알 방법이 없다.
                        if let breakdown = HighSchoolConclusionPresentation.localizedEvaluationBreakdown(
                            draft.evaluationBreakdown,
                            resolver: copyResolver
                        ), !breakdown.isEmpty {
                            Divider()
                            Text(copyResolver.resolve(
                                AppCopyKey.conclusionEvaluationScore,
                                arguments: [.integer(draft.evaluationScore)]
                            )).eyebrowStyle(BaseballTheme.textTertiary)
                            FlowRow(items: breakdown, resolver: copyResolver)
                        }
                    }
                }
            }
            WindSettlementCard(wind: state.careerWind)
            }
            .accessibilityIdentifier("hs.legacy.details")
            if career.usesSignatureLegacyRules {
                let signatureCount = selectedSignatureLegacy == nil ? 0 : 1
                BaseballCard(
                    title: copyResolver.resolve(
                        AppCopyKey.conclusionSignatureTitle,
                        arguments: [.integer(signatureCount)]
                    ),
                    tone: .milestone
                ) {
                    VStack(alignment: .leading, spacing: 5) {
                        if state.soulBoosts?.contains(SoulBoostID.extraMemory.rawValue) == true {
                            let boostCopy = HighSchoolSetupView.localizedBoostCopy(
                                .extraMemory,
                                resolver: copyResolver
                            )
                            Label(boostCopy.title, systemImage: "sparkles")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(BaseballTheme.milestone)
                                .accessibilityIdentifier("hs.signatureLegacy.extraMemoryActive")
                        }
                        Text(copyResolver.resolve(AppCopyKey.conclusionSignatureDescription))
                            .detailStyle()
                        Text(copyResolver.resolve(AppCopyKey.conclusionSignatureRemainder))
                            .font(.caption)
                            .foregroundStyle(BaseballTheme.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .onViewportExposure {
                    guard career.prepareSignatureLegacyCandidates() else { return }
                    CareerTelemetry.logOnce(
                        .signatureLegacyOptionsSeen,
                        scope: "signature-options:\(state.careerID)",
                        properties: [
                            "life_number": state.lifeNumber,
                            "drafted": state.draftResult?.outcome == .drafted,
                            "option_count": signatureCandidates.count,
                            "includes_pro_career": signatureCandidates.contains {
                                $0.evidence.proPerformance != nil
                            },
                            "option_ids": Array(Set(signatureCandidates.map { $0.id.rawValue }))
                                .sorted().joined(separator: ","),
                        ]
                    )
                }
                ForEach(signatureCandidates) { legacy in
                    let selected = legacy.id == career.selectedSignatureLegacyID
                    let copy = HighSchoolConclusionPresentation.localizedSignature(
                        legacy, resolver: copyResolver
                    )
                    Button { career.selectSignatureLegacy(legacy.id) } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: selected ? "checkmark.seal.fill" : "seal")
                                .foregroundStyle(selected ? BaseballTheme.milestone : BaseballTheme.border)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 4) {
                                // localization-safe: resolved-copy
                                Text(copy.title)
                                    .font(.subheadline.weight(.heavy))
                                    .foregroundStyle(BaseballTheme.textPrimary)
                                // localization-safe: resolved-copy
                                // localization-safe: resolved-copy
                                Text(copy.evidence)
                                    .font(.caption)
                                    .foregroundStyle(BaseballTheme.information)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(HighSchoolConclusionPresentation.localizedSignatureEffect(
                                    legacy.effect, resolver: copyResolver
                                ))
                                    .font(.caption2.weight(.bold).monospacedDigit())
                                    .foregroundStyle(BaseballTheme.milestone)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            selected ? BaseballTheme.milestone.opacity(0.12) : BaseballTheme.surface,
                            in: RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                                .stroke(selected ? BaseballTheme.milestone : BaseballTheme.border,
                                        lineWidth: selected ? 2 : 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("hs.signatureLegacy.\(legacy.id.rawValue)")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            if !career.usesSignatureLegacyRules {
                BaseballCard(title: copyResolver.resolve(
                    AppCopyKey.conclusionMemoryTitle,
                    arguments: [.integer(career.selectedMemories.count), .integer(state.memorySlots)]
                ), tone: .milestone) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(copyResolver.resolve(AppCopyKey.conclusionMemoryDescription))
                            .detailStyle()
                        // 구규칙은 정확히 memorySlots장을 요구한다. 부족한 채로 확정하면
                        // 오류가 나므로 화면에서 막고 남은 장수를 알려 준다.
                        if career.selectedMemories.count < state.memorySlots {
                            Text(copyResolver.resolve(
                                AppCopyKey.conclusionMemoryMore,
                                arguments: [.integer(state.memorySlots - career.selectedMemories.count)]
                            ))
                                .font(BaseballType.detail.weight(.semibold))
                                .foregroundStyle(BaseballTheme.warning)
                        }
                    }
                }
                ForEach(state.legacyOptions, id: \.self) { option in
                    let copy = HighSchoolConclusionPresentation.localizedMemory(
                        option, resolver: copyResolver
                    )
                    let selected = career.selectedMemories.contains(option)
                    Button { career.toggleMemory(option) } label: {
                        HStack(alignment: .center, spacing: 10) {
                            Image(systemName: selected ? "checkmark.square.fill" : "square")
                                .foregroundStyle(selected ? BaseballTheme.selection : BaseballTheme.border)
                            ArtThumb(assetName: "MemoryArt-\(option.rawValue)", size: 52)
                            VStack(alignment: .leading, spacing: 2) {
                                // localization-safe: resolved-copy
                                Text(copy.title).font(.subheadline.weight(.bold))
                                // localization-safe: resolved-copy
                                Text(copy.detail).detailStyle()
                            }
                            Spacer()
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            selected ? BaseballTheme.selection.opacity(0.12) : BaseballTheme.surface,
                            in: RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                                .stroke(selected ? BaseballTheme.selection : BaseballTheme.border, lineWidth: selected ? 2 : 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("hs.memory.\(option.rawValue)")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            let legacyConfirmAction = career.usesSignatureLegacyRules
                ? AppCopyKey.conclusionLegacyConfirmAction
                : AppCopyKey.conclusionMemoryConfirmAction
            let selectedLegacyTitle = selectedSignatureLegacy.map {
                HighSchoolConclusionPresentation.localizedSignature($0, resolver: copyResolver).title
            } ?? copyResolver.resolve(AppCopyKey.conclusionSignatureTitle, arguments: [.integer(0)])
            let legacySubject: String = {
                guard career.usesSignatureLegacyRules else { return selectedLegacyTitle }
                guard copyResolver.language == .korean else { return selectedLegacyTitle }
                return selectedLegacyTitle + KoreanCopy.particle(selectedLegacyTitle, final: "을", open: "를")
            }()
            PrimaryButton(
                title: copyResolver.resolve(legacyConfirmAction),
                identifier: "hs.legacy.confirm"
            ) { confirmingLegacy = true }
                .disabled(
                    career.usesSignatureLegacyRules
                        ? selectedSignatureLegacy == nil
                        : career.selectedMemories.count != state.memorySlots
                )
                .alert(
                    copyResolver.resolve(
                        career.usesSignatureLegacyRules
                            ? AppCopyKey.conclusionLegacyConfirmationTitle
                            : AppCopyKey.conclusionMemoryConfirmationTitle,
                        arguments: career.usesSignatureLegacyRules
                            ? [.userText(legacySubject)]
                            : [.integer(career.selectedMemories.count)]
                    ),
                    isPresented: $confirmingLegacy
                ) {
                    Button(copyResolver.resolve(AppCopyKey.conclusionConfirmationConfirm)) {
                        career.confirmLegacy()
                    }
                    .accessibilityIdentifier("hs.legacy.finalize")
                    Button(copyResolver.resolve(AppCopyKey.conclusionConfirmationCancel)) {
                        confirmingLegacy = false
                    }
                } message: {
                    Text(copyResolver.resolve(
                        career.usesSignatureLegacyRules
                            ? AppCopyKey.conclusionLegacyConfirmationMessage
                            : AppCopyKey.conclusionMemoryConfirmationMessage
                    ))
                }
        }
    }
}

struct CompletionCard: View {
    @State private var confirmingFold = false
    let career: HighSchoolCareerStore
    let state: HighSchoolCareerSnapshot
    /// 이 회차로 프로에 이미 진출했는가.
    let hasEnteredPro: Bool
    var onRecoverMissingPro: (() -> Void)? = nil
    let onEnterPro: (DraftResultSnapshot, PitcherSnapshot, PlayerIdentitySnapshot) -> Void
    var onSkipToPro: (() -> Void)? = nil
    var includeReason = true
    /// 환생 스탬프를 띄우고 나서 다음 회차로 넘어간다. 화면이 갈아 끼워지기 전에
    /// 회차 번호를 보여 줘야 회차가 쌓이는 감각이 생긴다.
    let onRebirth: () -> Void
    /// 고른 길로 다음 회차를 시작한다. nil이면 길 고르기 자체를 감춘다(도전 런 등).
    var onRebirthPath: ((RebirthPath) -> Void)?
    @Environment(\.gameCopyResolver) private var copyResolver
    @State private var selectedPath: RebirthPath?

    /// **이번 생에는 다른 야구.** 이름·얼굴·앨범·이어받은 힘은 그대로 두고 성장 유형과
    /// 주력 구종만 바꾼다. 대화 화면과 같은 카드 관용구를 쓰고, **확인 전에는 시작하지
    /// 않는다** — 고르는 일은 명령이 아니다(6-E).
    @ViewBuilder
    private var rebirthPathPicker: some View {
        if let onRebirthPath, career.canChooseRebirthPath {
            VStack(alignment: .leading, spacing: 10) {
                Text(copyResolver.resolve(AppCopyKey.rebirthPathTitle))
                    .font(.headline)
                    .foregroundStyle(BaseballTheme.textPrimary)
                Text(copyResolver.resolve(AppCopyKey.rebirthPathBody))
                    .detailStyle()
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(RebirthPath.allCases, id: \.self) { path in
                    ConversationChoiceCard(
                        title: copyResolver.resolve(Self.pathTitleKey(path)),
                        detail: copyResolver.resolve(Self.pathDetailKey(path)),
                        chips: pathChips(path),
                        isSelected: selectedPath == path,
                        identifier: "hs.rebirthPath.\(path.rawValue)"
                    ) {
                        selectedPath = path
                    }
                }
                PrimaryPill(
                    title: copyResolver.resolve(AppCopyKey.rebirthPathConfirm),
                    identifier: "hs.rebirthPath.confirm",
                    enabled: selectedPath != nil
                ) {
                    guard let selectedPath else { return }
                    onRebirthPath(selectedPath)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("hs.rebirthPath")
        }
    }

    private func pathChips(_ path: RebirthPath) -> [ConversationChip] {
        var chips: [ConversationChip] = []
        if let identity = path.buildIdentity {
            chips.append(ConversationChip(
                id: "build",
                text: ProCareerPresentation.buildLabel(identity, resolver: copyResolver),
                tone: .neutral
            ))
        }
        chips.append(ConversationChip(
            id: "pitch",
            text: copyResolver.resolve(
                AppCopyKey.rebirthPathPrimaryPitch,
                arguments: [.userText(PitchCopy.localized(path.primaryPitch, resolver: copyResolver))]
            ),
            tone: .gain
        ))
        chips.append(ConversationChip(
            id: "role",
            text: copyResolver.resolve(path.proRole.displayCopyToken),
            tone: .neutral,
            systemImage: "figure.baseball"
        ))
        return chips
    }

    private static func pathTitleKey(_ path: RebirthPath) -> GameCopyKey {
        switch path {
        case .endurance: AppCopyKey.rebirthPathEnduranceTitle
        case .closer: AppCopyKey.rebirthPathCloserTitle
        case .command: AppCopyKey.rebirthPathCommandTitle
        }
    }

    private static func pathDetailKey(_ path: RebirthPath) -> GameCopyKey {
        switch path {
        case .endurance: AppCopyKey.rebirthPathEnduranceDetail
        case .closer: AppCopyKey.rebirthPathCloserDetail
        case .command: AppCopyKey.rebirthPathCommandDetail
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            if let onRecoverMissingPro {
                BaseballCard(title: copyResolver.resolve(.localizable("career.recovery.missing-pro.title")), tone: .milestone) {
                    Text(verbatim: copyResolver.resolve(.localizable("career.recovery.missing-pro.body")))
                        .detailStyle()
                    PrimaryButton(
                        title: copyResolver.resolve(.localizable("career.recovery.missing-pro.action")),
                        identifier: "hs.recoverMissingPro",
                        action: onRecoverMissingPro
                    )
                }
            }
            let bestPast = career.archive
                .filter { $0.lifeNumber != state.lifeNumber }
                .map(\.evaluationScore).max() ?? 0
            if includeReason {
                DraftReasonCard(state: state, bestPast: bestPast)
            }
            let completionSummary = state.draftResult.map {
                HighSchoolConclusionPresentation.localizedDraftSummary($0, resolver: copyResolver)
            } ?? copyResolver.resolve(AppCopyKey.conclusionCompletionEnded)
            BaseballCard(title: copyResolver.resolve(AppCopyKey.conclusionCompletionTitle), tone: .milestone) {
                VStack(alignment: .leading, spacing: 6) {
                    // localization-safe: resolved-copy
                    Text(completionSummary)
                        .font(.subheadline).fixedSize(horizontal: false, vertical: true)
                    // 지명된 회차에서는 아직 계승이 정해지지 않았다. 지난 회차의 것만 보여 준다.
                    if career.inheritance.memories.isEmpty {
                        EmptyView()
                    } else {
                        Text(copyResolver.resolve(
                            AppCopyKey.conclusionCarriedMemorySummary,
                            arguments: [
                                .integer(career.inheritance.memories.count),
                                .integer(career.inheritance.soulPoints),
                            ]
                        ))
                            .font(BaseballType.annotation.monospacedDigit())
                            .foregroundStyle(BaseballTheme.milestone)
                    }
                }
            }
            WindSettlementCard(wind: state.careerWind)

            // 지명된 구단에서 누가 기다리는지. 이름만 있으면 "어느 팀"이 문자열 하나이고,
            // 프로 첫 시즌의 경쟁 구도가 시작 전에 서지 않는다.
            if let team = state.draftResult?.team, state.draftResult?.outcome == .drafted {
                let teamName = HighSchoolConclusionPresentation.localizedTeamName(team, resolver: copyResolver)
                let coachName = HighSchoolConclusionPresentation.localizedTeamField(
                    team, field: .proCoach, resolver: copyResolver
                )
                let competitorName = HighSchoolConclusionPresentation.localizedTeamField(
                    team, field: .positionCompetitor, resolver: copyResolver
                )
                let coachProfile = HighSchoolConclusionPresentation.localizedTeamField(
                    team, field: team.coachProfile == nil ? .developmentPlan : .coachProfile,
                    resolver: copyResolver
                )
                let competitorProfile = HighSchoolConclusionPresentation.localizedTeamField(
                    team, field: team.competitorProfile == nil ? .positionCompetitor : .competitorProfile,
                    resolver: copyResolver
                )
                BaseballCard(title: copyResolver.resolve(
                    AppCopyKey.conclusionTeamWaiting,
                    arguments: [.userText(teamName)]
                ), tone: .milestone) {
                    VStack(alignment: .leading, spacing: 10) {
                        AvatarRow(seed: team.proCoach, role: .coach,
                                  name: copyResolver.resolve(
                                    AppCopyKey.conclusionCoachName,
                                    arguments: [.userText(coachName)]
                                  ), caption: coachProfile, size: 44)
                        // 경쟁자를 player 역할로 두면 같은 카드에서 코치는 사진, 경쟁자는 벡터로
                        // 갈린다(QA P1-9) — 한 화면 안 화풍 혼재는 미완성으로 읽힌다.
                        AvatarRow(seed: team.positionCompetitor, role: .rival,
                                  name: competitorName,
                                  caption: team.competitorProfile == nil
                                    ? copyResolver.resolve(AppCopyKey.conclusionCompetitorFallback)
                                    : competitorProfile,
                                  size: 44)
                    }
                }
            }

            // 기억을 이미 확정한 회차는 결정이 끝난 회차다. 이 구분이 없던 동안, 지명 회차를
            // 접기로 하고 기억까지 고른 사용자가 "이 회차를 접고 다시 시작"을 누를 때마다
            // 다시 기억 선택으로 끌려갔다 — 환생에 영영 닿지 못하는 무한 순환이었다.
            let legacyConfirmed = !state.selectedMemories.isEmpty
                || career.inheritance.lifeNumber > state.lifeNumber

            // 프로에 이미 다녀왔으면 다시 들어가지 않는다.
            //
            // 예전에는 프로에서 은퇴하고 고교 완료 화면으로 돌아오면 "프로 커리어 시작"이
            // 다시 살아났다. 같은 지명으로 프로 커리어를 무한히 새로 만들 수 있었고, 은퇴
            // 계승(야구혼)도 그때마다 다시 적립될 여지가 있었다.
            if let draft = state.draftResult, draft.outcome == .drafted, !legacyConfirmed, !hasEnteredPro {
                CareerShareButton(
                    model: CareerSharePresentation.draft(
                        result: draft,
                        state: state,
                        resolver: copyResolver
                    )
                )
                PrimaryButton(title: copyResolver.resolve(AppCopyKey.conclusionEnterPro), identifier: "hs.enterPro") {
                    onEnterPro(draft, state.pitcher, state.identity)
                }
                Text(copyResolver.resolve(AppCopyKey.conclusionNotOver))
                    .font(.caption).foregroundStyle(BaseballTheme.textSecondary)

                // 잘한 회차일수록 다음 선수 이야기를 못 본다.
                //
                // 지명되면 대표 유산 선택은 프로를 접거나 은퇴한 뒤에야 나온다. 지명률이
                // 회차가 갈수록 오르니 **다수의 회차가 이 경로로 빠지고**, 성공 직후에
                // 환생 동기가 오히려 끊긴다. 고르게 하지는 않되, 무엇이 남을지는 지금
                // 보여 준다 — 이 화면이 다음 회차를 한 글자도 말하지 않던 것을 고친다.
                let upcoming = career.signatureLegacyCandidates(for: state)
                if !upcoming.isEmpty {
                    BaseballCard(title: copyResolver.resolve(AppCopyKey.conclusionLegacyPreviewTitle), tone: .raised) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(copyResolver.resolve(AppCopyKey.conclusionLegacyPreviewBody))
                                .font(.caption)
                                .foregroundStyle(BaseballTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            ForEach(upcoming, id: \.id) { candidate in
                                Label(
                                    HighSchoolConclusionPresentation.localizedSignature(
                                        candidate, resolver: copyResolver
                                    ).title,
                                    systemImage: "seal.fill"
                                )
                                    .font(BaseballType.annotation.weight(.semibold))
                                    .foregroundStyle(BaseballTheme.milestone)
                            }
                        }
                    }
                    .accessibilityIdentifier("hs.legacyPreview")
                }
            }

            // 지명된 회차는 아직 끝나지 않았다. 프로에 들어가지 않았다면 포기 확인 뒤
            // 유산을 고르고, 이미 프로에 들어갔다면 은퇴 기록이 돌아올 때까지 기다린다.
            let awaitsProRetirement = state.draftResult?.outcome == .drafted
                && !legacyConfirmed && hasEnteredPro
            let opensLegacy = state.draftResult?.outcome == .drafted
                && !legacyConfirmed && !hasEnteredPro

            // 이 회차의 카드를 여기서 나눈다.
            //
            // 예전에는 공유 버튼이 기억 선택 화면과 정산 화면에만 있었다. 지명에 성공한
            // 회차는 **정산 화면을 거치지 않고** 곧장 이 화면으로 오므로, 이 게임에서
            // 감정이 가장 높은 순간에 공유 경로가 통째로 없었다(2026-08 기준 공유 5%).
            if legacyConfirmed || state.draftResult != nil {
                LifeCardShareButton(record: HighSchoolCareerStore.lifeRecord(
                    from: state, memories: career.selectedMemories, previous: career.inheritance,
                    nicknames: career.nicknames, chronicle: career.chronicle,
                    personality: career.personality,
                    bondMemories: career.bondMemories,
                    startingPitcher: career.careerStartingPitcher
                ))
            }

            // 남은 행동이 하나뿐인 화면에서 그 버튼이 회색 테두리면, 화면은 "끝났다"로
            // 읽힌다. 기억까지 확정한 회차의 다음 행동은 환생 하나뿐이므로 주 버튼으로
            // 세운다 — 드래프트를 본 42명 중 27명만 다음 회차를 시작했다(2026-08).
            if awaitsProRetirement {
                if onRecoverMissingPro == nil {
                    BaseballCard(title: copyResolver.resolve(AppCopyKey.conclusionAwaitingRetirementTitle), tone: .milestone) {
                        Text(copyResolver.resolve(AppCopyKey.conclusionAwaitingRetirementBody))
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else if !opensLegacy {
                // 지명 위쪽의 목표.
                //
                // 계승은 4회차 전후에 상한(+20)에 닿고, 그때쯤 "지명"은 거의 자동이 된다.
                // 그 뒤로 회차를 더 도는 이유가 업적 문구뿐이라 목표가 사라진다. 스카우트
                // 평가는 상한이 없고 회차를 가로질러 비교되므로, 다음 회차의 과녁이 된다.
                let thisRun = state.draftResult?.evaluationScore ?? 0
                if bestPast > 0 {
                    let isRecord = thisRun > bestPast
                    BaseballCard(title: copyResolver.resolve(
                        isRecord ? AppCopyKey.conclusionBestEvaluationRecordTitle
                                 : AppCopyKey.conclusionBestEvaluationNextTitle
                    ),
                                 tone: isRecord ? .milestone : .raised) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(
                                verbatim: copyResolver.resolve(
                                    .evaluationPoints,
                                    arguments: [.integer(max(thisRun, bestPast))]
                                )
                            )
                                .font(BaseballType.heroNumeral)
                                .foregroundStyle(isRecord ? BaseballTheme.milestone : BaseballTheme.textPrimary)
                            Text(copyResolver.resolve(
                                isRecord ? AppCopyKey.conclusionBestEvaluationRecordBody
                                         : AppCopyKey.conclusionBestEvaluationNextBody,
                                arguments: [.integer(isRecord ? bestPast : thisRun)]
                            ))
                                .detailStyle()
                        }
                    }
                }
                if let onSkipToPro {
                    Button(action: onSkipToPro) {
                        Text(verbatim: copyResolver.resolve(AppCopyKey.proLockedSkipButton))
                            .font(BaseballType.detail.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: BaseballMetrics.minimumTapTarget, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("hs.skipToPro")
                }
                rebirthPathPicker
                PrimaryButton(title: copyResolver.resolve(
                    AppCopyKey.conclusionRebirthAction,
                    arguments: [.integer(career.inheritance.lifeNumber)]
                ), identifier: "hs.rebirth", action: onRebirth)
                let memoryCount = career.inheritance.memories.count
                let points = career.inheritance.soulPoints
                let summaryKey = copyResolver.language == .korean
                    ? (KoreanCopy.objectParticle(number: points) == "을"
                        ? AppCopyKey.conclusionRebirthSummaryWithEul
                        : AppCopyKey.conclusionRebirthSummaryWithReul)
                    : AppCopyKey.conclusionRebirthSummaryWithEul
                Text(copyResolver.resolve(
                    summaryKey,
                    arguments: [.integer(memoryCount), .integer(points)]
                ))
                    .font(.caption).foregroundStyle(BaseballTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Button {
                    // 프로 포기는 이 게임에서 가장 무거운 되돌릴 수 없는 결정인데
                    // 학교 선택보다 마찰이 낮았다 — 같은 확인 문법을 준다.
                    confirmingFold = true
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(copyResolver.resolve(AppCopyKey.conclusionFoldTitle))
                            .font(.subheadline.weight(.semibold))
                        Text(copyResolver.resolve(AppCopyKey.conclusionFoldBody))
                            .font(.caption).foregroundStyle(BaseballTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .frame(minHeight: BaseballMetrics.minimumTapTarget)
                .accessibilityIdentifier("hs.rebirth")
                .alert(
                    copyResolver.resolve(AppCopyKey.conclusionFoldConfirmationTitle),
                    isPresented: $confirmingFold
                ) {
                    Button(copyResolver.resolve(AppCopyKey.conclusionFoldAction), role: .destructive) { career.openLegacy() }
                        .accessibilityIdentifier("hs.fold.confirm")
                    // iOS 26 팝오버는 .cancel을 그리지 않는다 — 역할 없이 넣는다.
                    Button(copyResolver.resolve(AppCopyKey.conclusionFoldCancel)) { confirmingFold = false }
                } message: {
                    Text(copyResolver.resolve(AppCopyKey.conclusionFoldMessage))
                }
            }
        }
    }
}

/// 상태바 뒤를 지나가는 본문을 가리는 스크림.
///
/// 이 화면은 내비게이션 바를 숨긴다(키아트가 제목이라 제목이 두 번 나온다). 그래서
/// iOS가 스크롤 가장자리에 걸어 주는 흐림이 없고, 스크롤한 본문이 시계·와이파이·배터리와
/// **같은 자리에 그대로 겹쳐 그려진다** — "글자가 깨져 보인다"는 제보의 실체다.
///
/// 예전 스크림은 **높이 28 고정**이었다. 이 기기(iPhone 17 Pro)의 상단 안전 영역은
/// 62pt라, 띠는 시계 위쪽 여백만 덮고 정작 글자가 겹치는 28~62pt 구간을 비워 두고
/// 있었다 — 시뮬레이터에서 색 띠로 좌표를 재서 확인했다.
///
/// `ignoresSafeArea(edges: .top)`를 **frame 다음에** 걸어야 띠가 화면 맨 위(y=0)를
/// 기준으로 놓인다. 걸지 않으면 안전 영역 아래(62pt)에서 시작한다. 높이는 기기마다
