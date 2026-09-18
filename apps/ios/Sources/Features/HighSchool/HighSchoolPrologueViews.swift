import SwiftUI
import SimulationCore
import BaseballIOSDomain

// MARK: - 단계 카드

struct InheritedStartComparisonCard: View {
    let comparison: InheritedStartComparison

    @Environment(\.gameCopyResolver) private var copyResolver

    private var abilities: [(CopyToken, Int, Int)] {
        [
            (TrainingFocus.velocity.displayCopyToken, comparison.previous.stuff, comparison.current.stuff),
            (TrainingFocus.command.displayCopyToken, comparison.previous.command, comparison.current.command),
            (TrainingFocus.breakingBall.displayCopyToken, comparison.previous.movement, comparison.current.movement),
            (TrainingFocus.stamina.displayCopyToken, comparison.previous.stamina, comparison.current.stamina),
        ]
    }

    private var previousDisplayTotal: Int {
        abilities.map { AbilityDisplayScale.displayRating($0.1) }.reduce(0, +)
    }

    private var currentDisplayTotal: Int {
        abilities.map { AbilityDisplayScale.displayRating($0.2) }.reduce(0, +)
    }

    private func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }

    private func sourceTitle(_ source: InheritedStartComparison.Source) -> String {
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
                        .integer(previousDisplayTotal),
                        .integer(currentDisplayTotal),
                        .userText(signed(currentDisplayTotal - previousDisplayTotal)),
                    ]
                ))
                    .proseLeadStyle()
                    .monospacedDigit()

                HStack(spacing: 8) {
                    ForEach(Array(abilities.enumerated()), id: \.offset) { _, ability in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(copyResolver.resolve(ability.0))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(BaseballTheme.textTertiary)
                            Text("\(AbilityDisplayScale.displayRating(ability.1)) → \(AbilityDisplayScale.displayRating(ability.2))")
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
                    .detailStyle(BaseballTheme.textPrimary)

                ForEach(comparison.sources) { source in
                    Text(copyResolver.resolve(
                        AppCopyKey.prologueInheritedStartSource,
                        arguments: [
                            .userText(sourceTitle(source)),
                            .userText(signed(source.ratingDelta)),
                        ]
                    ))
                        .detailStyle()
                        .monospacedDigit()
                }
            }
            .accessibilityIdentifier("hs.prologue.inheritedStartComparison")
        }
        .onAppear {
            CareerTelemetry.logOnce(
                .inheritedStartComparisonSeen,
                scope: "inherited-start:\(comparison.careerID)",
                properties: [
                    "previous_total": comparison.previous.total,
                    "current_total": comparison.current.total,
                    "inherited_rating_delta": comparison.inheritedRatingDelta,
                    "source_count": comparison.sources.count,
                ]
            )
            CareerTelemetry.logOnce(
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
    var throwTitleKey: GameCopyKey = AppCopyKey.prologueThrow

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

    /// 효과 문구의 부호로 칩 색을 정한다. 이득은 초록, 비용은 주황, 나머지는 회색.
    static func windEffectTone(_ effect: String) -> EffectChip.Tone {
        if effect.contains("+") { return .gain }
        if effect.contains("-") || effect.contains("−") { return .cost }
        return .neutral
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            BaseballCard(title: milestoneTitle, tone: .milestone) {
                VStack(alignment: .leading, spacing: 8) {
                    if opener.variant == .firstLife {
                        Text(verbatim: copyResolver.resolve(AppCopyKey.prologueFirstLifeCoachQuote))
                            .proseStyle()
                    }
                    Text(verbatim: copyResolver.resolve(opener, regionName: regionName))
                        .detailStyle()

                    let windTitle = copyResolver.resolve(wind.titleToken)
                    let windDetail = copyResolver.resolve(wind.detailToken)
                    let effectCopy = wind.effectDescriptors.map { copyResolver.resolve($0.token) }
                    let neutralWindCopy = copyResolver.resolve(AppCopyKey.prologueWindNeutralExplanation)
                    Divider()
                    // 바람은 카드 속 카드가 아니라 굵은 한 줄 + 설명 한 줄 + 효과 칩이다.
                    // 챕터 시작 화면에 눈썹이 넷 이상 늘어서던 원인 하나를 여기서 뺀다.
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verbatim: copyResolver.resolve(
                            AppCopyKey.prologueWindHeading,
                            arguments: [.userText(windTitle)]
                        ))
                            .proseLeadStyle()
                        Text(verbatim: effectCopy.isEmpty ? neutralWindCopy : windDetail)
                            .detailStyle()
                        if !effectCopy.isEmpty {
                            EffectChipFlow {
                                ForEach(Array(effectCopy.enumerated()), id: \.offset) { _, effect in
                                    EffectChip(text: effect, tone: Self.windEffectTone(effect), systemImage: "wind")
                                }
                            }
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
                    if !state.karmas.isEmpty {
                        Divider()
                        Text(verbatim: copyResolver.resolve(AppCopyKey.prologueHandicapHeading))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(BaseballTheme.warning)
                        ForEach(state.karmas, id: \.self) { karma in
                            let copy = karma.copyDescriptor
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: copyResolver.resolve(copy.titleToken))
                                    .font(.subheadline.weight(.semibold))
                                Text(verbatim: copyResolver.resolve(copy.detailToken))
                                    .detailStyle()
                            }
                        }
                    }
                }
            }
            // 주 행동이 능력치 표보다 먼저다 — 첫 화면에서 "다음에 뭘 누르지"가
            // 접힘선 아래에 있으면 유료 게임의 첫 30초를 버리는 것이다(QA P0-1).
            // 이 게임에서 가장 좋은 것은 투구다. 사는 사람이 그걸 두 번째 탭에서 만나게 한다.
            PrimaryButton(
                title: copyResolver.resolve(throwTitleKey),
                identifier: "hs.prologue.throw",
                action: onThrow
            )
            Button(copyResolver.resolve(AppCopyKey.prologueSkip), action: onSkip)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: BaseballMetrics.minimumTapTarget)
                .accessibilityIdentifier("hs.prologue.continue")
            // 능력표는 눈썹 없이 제목 한 줄로. 이 화면의 눈썹은 첫 등교 카드 하나면 된다.
            VStack(alignment: .leading, spacing: 10) {
                Text(verbatim: copyResolver.resolve(AppCopyKey.prologueCurrentPlayerTitle))
                    .font(.headline)
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
                        .detailStyle()
                }
            }
        }
        .onAppear {
            let wind = state.careerWind
            CareerTelemetry.logOnce(
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
            ? copyResolver.resolve(MetaUICopyKey.abilityBaseComplete)
            : copyResolver.resolve(
                AppCopyKey.prologueAbilityCeiling,
                arguments: [.integer(AbilityDisplayScale.displayCeiling(talent.ceiling))]
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
                // 게이지 라벨은 눈썹이 아니다 — 네 줄이 나란히 서면 눈썹이 넷 늘어난다.
                Text(verbatim: label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BaseballTheme.textSecondary)
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
                Text(verbatim: "\(AbilityDisplayScale.displayRating(value))")
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
                .detailStyle()
            if value >= talent.ceiling, talent != .s {
                Text(verbatim: copyResolver.resolve(AppCopyKey.prologueAbilityCeilingReached))
                    .detailStyle()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            preservesKoreanAccessibility && copyResolver.language == .korean
                ? copyResolver.resolve(
                    AppCopyKey.chapterReviewAbilityAccessibility,
                    arguments: [
                        .userText(label), .integer(AbilityDisplayScale.displayRating(value)), .userText(talent.label),
                        .integer(AbilityDisplayScale.displayCeiling(talent.ceiling)), .userText(meaning),
                    ]
                )
                : copyResolver.resolve(
                    AppCopyKey.prologueAbilityAccessibility,
                    arguments: [
                        .userText(label), .integer(AbilityDisplayScale.displayRating(value)), .userText(talentText), .userText(ceilingText),
                    ]
                )
        )
    }
}

/// 학교 선택.

/// Returning lives get their real choices before optional narrative. Practice uses the existing
/// neutral-condition bullpen and never changes the archived life or grants training growth.
struct RebornReadyCard<History: View>: View {
    let state: HighSchoolCareerSnapshot
    let previous: LifeRecord?
    let onContinue: () -> Void
    let onPractice: () -> Void
    @ViewBuilder let history: () -> History
    @Environment(\.gameCopyResolver) private var copyResolver
    @State private var showsMemories = false

    private var samePlayer: Bool { previous.map { PlayerContinuityRules.sameName($0.playerName, state.identity.name) } ?? true }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(verbatim: copyResolver.resolve(.localizable(samePlayer ? "loop.reborn.same" : "loop.reborn.different")))
                .font(.title2.weight(.bold)).accessibilityIdentifier("hs.reborn.title")
            Text(verbatim: copyResolver.resolve(.localizable("loop.reborn.next"))).detailStyle()
            PrimaryButton(title: copyResolver.resolve(.localizable("loop.reborn.continue")),
                identifier: "hs.reborn.continue", action: onContinue)
            Button(copyResolver.resolve(.localizable("loop.reborn.practice")), action: onPractice)
                .frame(maxWidth: .infinity, minHeight: BaseballMetrics.minimumTapTarget)
                .accessibilityIdentifier("hs.reborn.practice")
            if let legacy = previous?.signatureLegacy {
                Text(verbatim: copyResolver.resolve(.localizable("loop.reborn.inherited"), arguments: [
                    .userText(HighSchoolConclusionPresentation.localizedSignature(legacy, resolver: copyResolver).title)]))
                    .font(BaseballType.detail).foregroundStyle(BaseballTheme.milestone)
            }
            if !state.karmas.isEmpty {
                Text(verbatim: copyResolver.resolve(.localizable("loop.reborn.handicaps"), arguments: [.integer(state.karmas.count)]))
                    .detailStyle(BaseballTheme.warning)
            }
            if previous != nil {
                Button(copyResolver.resolve(.localizable(samePlayer ? "loop.reborn.memories" : "loop.reborn.other-record"))) { showsMemories.toggle() }
                    .frame(minHeight: BaseballMetrics.minimumTapTarget).accessibilityIdentifier("hs.reborn.memories")
                if showsMemories {
                    history()
                    let wind = CareerWindPresentationCatalog.descriptor(for: state.careerWind)
                    if !wind.effectDescriptors.isEmpty {
                        EffectChipFlow {
                            ForEach(Array(wind.effectDescriptors.enumerated()), id: \.offset) { _, effect in
                                let text = copyResolver.resolve(effect.token)
                                EffectChip(text: text, tone: PrologueCard.windEffectTone(text), systemImage: "wind")
                            }
                        }
                    }
                }
            }
        }.accessibilityElement(children: .contain)
            .accessibilityIdentifier("hs.reborn.ready")
    }
}
