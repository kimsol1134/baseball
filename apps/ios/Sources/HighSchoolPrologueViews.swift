import SwiftUI
import SimulationCore

// MARK: - 단계 카드

struct InheritedStartComparisonCard: View {
    let comparison: HighSchoolCareerStore.InheritedStartComparison

    @Environment(\.gameCopyResolver) private var copyResolver

    private var abilities: [(CopyToken, Int, Int)] {
        [
            (TrainingFocus.velocity.displayCopyToken, comparison.previous.stuff, comparison.current.stuff),
            (TrainingFocus.command.displayCopyToken, comparison.previous.command, comparison.current.command),
            (TrainingFocus.breakingBall.displayCopyToken, comparison.previous.movement, comparison.current.movement),
            (TrainingFocus.stamina.displayCopyToken, comparison.previous.stamina, comparison.current.stamina),
        ]
    }

    private func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }

    private func sourceTitle(_ source: HighSchoolCareerStore.InheritedStartComparison.Source) -> String {
        switch source.id {
        case "soul":
            copyResolver.resolve(AppCopyKey.prologueInheritedStartSoul)
        case "boost":
            copyResolver.resolve(AppCopyKey.prologueInheritedStartBoost)
        case "signature":
            source.signatureLegacyID.map {
                HighSchoolConclusionPresentation.localizedSignature(
                    CareerSignatureLegacy.definition(for: $0),
                    resolver: copyResolver
                ).title
            } ?? copyResolver.resolve(AppCopyKey.prologueInheritedStartBoost)
        case "mastery":
            copyResolver.resolve(LegacyUICopyKey.masteryStartSource)
        default:
            source.id
        }
    }

    var body: some View {
        BaseballCard(
            title: copyResolver.resolve(AppCopyKey.prologueInheritedStartTitle),
            tone: .milestone
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Text(copyResolver.resolve(
                    AppCopyKey.prologueInheritedStartJourney,
                    arguments: [
                        .userText(comparison.previousName),
                        .integer(comparison.previous.total),
                        .integer(comparison.current.total),
                        .userText(signed(comparison.totalDelta)),
                    ]
                ))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(BaseballTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    ForEach(Array(abilities.enumerated()), id: \.offset) { _, ability in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(copyResolver.resolve(ability.0))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(BaseballTheme.textTertiary)
                            Text("\(ability.1) → \(ability.2)")
                                .font(.caption.monospacedDigit().weight(.bold))
                                .foregroundStyle(BaseballTheme.textPrimary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Divider()
                Text(copyResolver.resolve(
                    AppCopyKey.prologueInheritedStartTotal,
                    arguments: [.userText(signed(comparison.inheritedRatingDelta))]
                ))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BaseballTheme.milestone)

                ForEach(comparison.sources) { source in
                    Text(copyResolver.resolve(
                        AppCopyKey.prologueInheritedStartSource,
                        arguments: [
                            .userText(sourceTitle(source)),
                            .userText(signed(source.ratingDelta)),
                        ]
                    ))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(BaseballTheme.textSecondary)
                }
            }
            .accessibilityIdentifier("hs.prologue.inheritedStartComparison")
        }
        .onAppear {
            GameAnalytics.logOnce(
                .inheritedStartComparisonSeen,
                scope: "inherited-start:\(comparison.careerID)",
                properties: [
                    "previous_total": comparison.previous.total,
                    "current_total": comparison.current.total,
                    "inherited_rating_delta": comparison.inheritedRatingDelta,
                    "source_count": comparison.sources.count,
                ]
            )
            GameAnalytics.logOnce(
                .lineageComparisonSeen,
                scope: "lineage-comparison:\(comparison.careerID)",
                properties: [
                    "previous_total": comparison.previous.total,
                    "current_total": comparison.current.total,
                    "total_delta": comparison.totalDelta,
                    "inherited_rating_delta": comparison.inheritedRatingDelta,
                    "source_count": comparison.sources.count,
                ]
            )
        }
    }
}

struct PrologueCard: View {
    let state: HighSchoolCareerSnapshot
    let lifeNumber: Int
    let onThrow: () -> Void
    let onSkip: () -> Void

    @Environment(\.gameCopyResolver) private var copyResolver

    private var opener: PrologueCopyDescriptor {
        ProloguePresentationCatalog.opener(lifeNumber: lifeNumber, rawRegion: state.identity.region)
    }

    private var regionName: String? {
        guard let region = opener.region else { return nil }
        return copyResolver.resolve(AppCopyKey.setupRegionName(for: region))
    }

    private var wind: CareerWindCopyDescriptor {
        CareerWindPresentationCatalog.descriptor(for: state.careerWind)
    }

    private var milestoneTitle: String {
        copyResolver.resolve(
            lifeNumber == 1 ? AppCopyKey.prologueFirstLifeTitle : AppCopyKey.prologueRebirthTitle
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            BaseballCard(title: milestoneTitle, tone: .milestone) {
                VStack(alignment: .leading, spacing: 8) {
                    if opener.variant == .firstLife {
                        Text(verbatim: copyResolver.resolve(AppCopyKey.prologueFirstLifeCoachQuote))
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(verbatim: copyResolver.resolve(opener, regionName: regionName))
                        .font(.footnote)
                        .foregroundStyle(BaseballTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    let windTitle = copyResolver.resolve(wind.titleToken)
                    let windDetail = copyResolver.resolve(wind.detailToken)
                    let effectCopy = wind.effectDescriptors.map { copyResolver.resolve($0.token) }
                    let neutralWindCopy = copyResolver.resolve(AppCopyKey.prologueWindNeutralExplanation)
                    Divider()
                    BaseballCard(
                        title: copyResolver.resolve(
                            AppCopyKey.prologueWindHeading,
                            arguments: [.userText(windTitle)]
                        ),
                        tone: .raised
                    ) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(verbatim: windDetail)
                                .font(.caption)
                                .foregroundStyle(BaseballTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            ForEach(Array(effectCopy.enumerated()), id: \.offset) { _, effect in
                                Text(verbatim: "· \(effect)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(BaseballTheme.information)
                            }
                            if effectCopy.isEmpty {
                                Text(verbatim: neutralWindCopy)
                                    .font(.caption)
                                    .foregroundStyle(BaseballTheme.textTertiary)
                            }
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(
                            copyResolver.resolve(
                                AppCopyKey.prologueWindAccessibility,
                                arguments: [
                                    .userText(windTitle),
                                    .userText(windDetail),
                                    .userText(effectCopy.isEmpty ? neutralWindCopy : effectCopy.joined(separator: "; ")),
                                ]
                            )
                        )
                    }
                    if !state.karmas.isEmpty {
                        Divider()
                        Text(verbatim: copyResolver.resolve(AppCopyKey.prologueHandicapHeading))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(BaseballTheme.warning)
                        ForEach(state.karmas, id: \.self) { karma in
                            let copy = karma.copyDescriptor
                            VStack(alignment: .leading, spacing: 1) {
                                Text(verbatim: copyResolver.resolve(copy.titleToken))
                                    .font(.subheadline.weight(.semibold))
                                Text(verbatim: copyResolver.resolve(copy.detailToken))
                                    .font(.caption)
                                    .foregroundStyle(BaseballTheme.textSecondary)
                            }
                        }
                    }
                }
            }
            // 주 행동이 능력치 표보다 먼저다 — 첫 화면에서 "다음에 뭘 누르지"가
            // 접힘선 아래에 있으면 유료 게임의 첫 30초를 버리는 것이다(QA P0-1).
            // 이 게임에서 가장 좋은 것은 투구다. 사는 사람이 그걸 두 번째 탭에서 만나게 한다.
            PrimaryButton(
                title: copyResolver.resolve(AppCopyKey.prologueThrow),
                identifier: "hs.prologue.throw",
                action: onThrow
            )
            Button(copyResolver.resolve(AppCopyKey.prologueSkip), action: onSkip)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: BaseballMetrics.minimumTapTarget)
                .accessibilityIdentifier("hs.prologue.continue")
            BaseballCard(title: copyResolver.resolve(AppCopyKey.prologueCurrentPlayerTitle)) {
                VStack(alignment: .leading, spacing: 10) {
                    // 재능 등급과 한계선을 함께 보여 준다. 이 회차가 어떤 투수인지가
                    // 시작 수치가 아니라 여기서 정해진다.
                    let talent = state.talent ?? .unlimited
                    PrologueAbilityGauge(
                        labelToken: TrainingFocus.velocity.displayCopyToken,
                        value: state.pitcher.stuff,
                        talent: talent.stuff
                    )
                    PrologueAbilityGauge(
                        labelToken: TrainingFocus.command.displayCopyToken,
                        value: state.pitcher.command,
                        talent: talent.command
                    )
                    PrologueAbilityGauge(
                        labelToken: TrainingFocus.breakingBall.displayCopyToken,
                        value: state.pitcher.movement,
                        talent: talent.movement
                    )
                    PrologueAbilityGauge(
                        labelToken: TrainingFocus.stamina.displayCopyToken,
                        value: state.pitcher.stamina,
                        talent: talent.stamina
                    )
                    Text(verbatim: copyResolver.resolve(AppCopyKey.prologueAbilityExplanation))
                        .font(.caption)
                        .foregroundStyle(BaseballTheme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .onAppear {
            let wind = state.careerWind
            GameAnalytics.logOnce(
                .careerWindSeen,
                scope: state.careerID,
                properties: [
                    "wind_id": wind.id,
                    "rules_version": state.effectiveWorldRulesVersion.rawValue,
                ]
            )
        }
    }
}

/// The prologue uses the same rating ladder as the rest of the app, but resolves every visible
/// label locally so English never inherits the legacy Korean strings from `AbilityGaugeView`.
struct PrologueAbilityGauge: View {
    let labelToken: CopyToken
    let value: Int
    let talent: TalentGrade
    var preservesKoreanAccessibility = false

    @Environment(\.gameCopyResolver) private var copyResolver

    private var label: String {
        copyResolver.resolve(labelToken)
    }

    private var talentText: String {
        copyResolver.resolve(
            AppCopyKey.prologueAbilityTalent,
            arguments: [.userText(talent.label)]
        )
    }

    private var ceilingText: String {
        talent == .s
            ? copyResolver.resolve(AppCopyKey.prologueAbilityNoCeiling)
            : copyResolver.resolve(
                AppCopyKey.prologueAbilityCeiling,
                arguments: [.integer(talent.ceiling)]
            )
    }

    private var meaningKey: GameCopyKey {
        switch RatingScale.steps.first(where: { value >= $0.minimum })?.minimum {
        case 75: AppCopyKey.prologueAbilityMeaningBest
        case 65: AppCopyKey.prologueAbilityMeaningProTop
        case 55: AppCopyKey.prologueAbilityMeaningAbovePro
        case 50: AppCopyKey.prologueAbilityMeaningProAverage
        case 47: AppCopyKey.prologueAbilityMeaningRegional
        case 43: AppCopyKey.prologueAbilityMeaningHighSchool
        case 38: AppCopyKey.prologueAbilityMeaningStarter
        case 33: AppCopyKey.prologueAbilityMeaningDeveloping
        default: AppCopyKey.prologueAbilityMeaningFoundations
        }
    }

    private var meaning: String {
        copyResolver.resolve(meaningKey)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: label).eyebrowStyle(BaseballTheme.textTertiary)
                Text(verbatim: talentText)
                    .font(.caption2.weight(.black))
                    .foregroundStyle(BaseballTheme.actionInk)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(RatingScale.tone(talent.ceiling), in: Capsule())
                Text(verbatim: ceilingText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(BaseballTheme.textTertiary)
                Spacer()
                Text(verbatim: "\(value)")
                    .font(BaseballType.scoreboard)
                    .foregroundStyle(BaseballTheme.textPrimary)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(BaseballTheme.surfaceRaised)
                    Capsule()
                        .fill(RatingScale.tone(value))
                        .frame(width: max(4, proxy.size.width * RatingScale.position(value)))
                    if talent != .s {
                        Rectangle()
                            .fill(BaseballTheme.borderStrong)
                            .frame(width: 2)
                            .offset(x: proxy.size.width * RatingScale.position(talent.ceiling))
                    }
                }
            }
            .frame(height: 8)
            Text(verbatim: meaning)
                .font(.caption)
                .foregroundStyle(BaseballTheme.textSecondary)
            if value >= talent.ceiling, talent != .s {
                Text(verbatim: copyResolver.resolve(AppCopyKey.prologueAbilityCeilingReached))
                    .font(.caption)
                    .foregroundStyle(BaseballTheme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            preservesKoreanAccessibility && copyResolver.language == .korean
                ? copyResolver.resolve(
                    AppCopyKey.chapterReviewAbilityAccessibility,
                    arguments: [
                        .userText(label), .integer(value), .userText(talent.label),
                        .integer(talent.ceiling), .userText(meaning),
                    ]
                )
                : copyResolver.resolve(
                    AppCopyKey.prologueAbilityAccessibility,
                    arguments: [
                        .userText(label), .integer(value), .userText(talentText), .userText(ceilingText),
                    ]
                )
        )
    }
}

/// 학교 선택.
