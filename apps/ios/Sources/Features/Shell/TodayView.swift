import SwiftUI
import SimulationCore
import BaseballIOSDomain

struct TodayView: View {
    let career: MobileCareerStore
    /// "위의 '이번 주'에서 확인하세요"는 길만 가리키고 데려다주지 않았다(페르소나 보고서 §2-5).
    /// 버튼 하나로 세그먼트를 넘긴다. 셸이 넘겨주지 않으면 무동작.
    var onOpenWeek: () -> Void = {}

    var body: some View {
        Group {
            if let state = career.state {
                TodayDashboard(state: state, onOpenWeek: onOpenWeek)
            } else {
                ContentUnavailableView {
                    Label {
                        GameCopyText(AppCopyKey.careerUnavailable)
                    } icon: {
                        Image(systemName: "baseball")
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .background(BaseballTheme.canvas)
    }
}

private struct TodayDashboard: View {
    let state: ProCareerSnapshot
    var onOpenWeek: () -> Void = {}
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
                KeyArtHeader(
                    // 1군 데뷔와 은퇴는 커리어에 한 번뿐이라 전용 그림을 준다.
                    art: state.phase == .completed ? .retirement
                        : state.level == .major ? .majorDebut : .stadiumNight,
                    eyebrow: copyResolver.resolve(
                        AppCopyKey.proSeasonHeader,
                        arguments: [
                            .integer(state.season),
                            .integer(state.week),
                            .userText(Self.segmentText(state.seasonSegment, resolver: copyResolver)),
                        ]
                    ),
                    title: copyResolver.resolve(
                        AppCopyKey.proDashboardTitle,
                        arguments: [
                            .userText(ProCareerPresentation.teamName(state.team, resolver: copyResolver)),
                            .userText(copyResolver.resolve(state.level.displayCopyToken)),
                            .userText(copyResolver.resolve(state.role.displayCopyToken)),
                        ]
                    ),
                    accent: BaseballTheme.teamDecoration(state.team.id)
                )

                SeasonArcBar(segment: state.seasonSegment, week: state.week)

                HStack(spacing: 10) {
                    // 프로가 된 그 얼굴 — 고교 대시보드와 같은 자리, 자란 모습이다.
                    PortraitView(seed: state.identity.portraitSeed, role: .player, size: 46, playerStage: .pro)
                    Metric(
                        title: copyResolver.resolve(AppCopyKey.proFatigueLabel),
                        value: "\(state.fatigue)",
                        tone: CareerDisplayRules.proFatigueBand(fatigue: state.fatigue) == .normal
                            ? .standard : .warning,
                        caption: copyResolver.resolve(
                            CareerDisplayRules.proFatigueBand(fatigue: state.fatigue).copyKey
                        )
                    )
                    Metric(
                        title: copyResolver.resolve(AppCopyKey.proManagerTrustLabel),
                        value: "\(state.managerTrust)",
                        tone: state.managerTrust >= 60 ? .positive : .standard
                    )
                    Metric(
                        title: copyResolver.resolve(AppCopyKey.proInjuryLabel),
                        value: state.injuryWeeks > 0
                            ? copyResolver.resolve(AppCopyKey.proInjuryWeeks, arguments: [.integer(state.injuryWeeks)])
                            : copyResolver.resolve(AppCopyKey.proInjuryNormal),
                        tone: state.injuryWeeks > 0 ? .negative : .standard
                    )
                }

                if state.journeyState != nil {
                    CareerDirectionCard(state: state)
                }

                BaseballCard(title: copyResolver.resolve(AppCopyKey.proNextActionTitle), tone: .raised) {
                    VStack(alignment: .leading, spacing: 10) {
                        GameCopyText(Self.actionKey(state.phase)).proseLeadStyle()
                        PrimaryPill(
                            title: copyResolver.resolve(MetaUICopyKey.proTodayOpenWeek.gameCopyKey),
                            identifier: "pro.today.openWeek"
                        ) {
                            onOpenWeek()
                        }
                    }
                }

                if let tensions = state.seasonTensions, !tensions.isEmpty {
                    BaseballCard(title: copyResolver.resolve(AppCopyKey.proTensionsTitle)) {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(tensions.enumerated()), id: \.offset) { _, tension in
                                let tensionCopy = ProCareerPresentation.tension(
                                    tension,
                                    state: state,
                                    resolver: copyResolver
                                )
                                VStack(alignment: .leading, spacing: 2) {
                                    // localization-safe: resolved-copy
                                    Text(tensionCopy.title).font(BaseballType.detail.weight(.semibold))
                                    // localization-safe: resolved-copy
                                    Text(tensionCopy.detail)
                                        .detailStyle()
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }
                }

                if let rival = state.currentRival {
                    let rivalCopy = ProCareerPresentation.rival(rival, resolver: copyResolver)
                    BaseballCard(title: copyResolver.resolve(AppCopyKey.proRivalTitle), tone: .warning) {
                        HStack(spacing: 10) {
                            // 고교 라이벌 카드와 같은 문법 — 상대에게 얼굴이 있어야 승부다.
                            PortraitView(seed: rival.name, role: .rival, size: 46)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(rivalCopy.name) · \(rivalCopy.teamName)").font(.headline)
                                // localization-safe: resolved-copy
                                Text(rivalCopy.archetype)
                                    .font(.subheadline)
                                    .foregroundStyle(BaseballTheme.textSecondary)
                                // localization-safe: resolved-copy
                                Text(rivalCopy.record)
                                    .font(BaseballType.annotation.monospacedDigit())
                                    .foregroundStyle(BaseballTheme.textSecondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }

                if let milestone = state.milestones.last {
                    BaseballCard(title: copyResolver.resolve(AppCopyKey.proMilestoneTitle), tone: .milestone) {
                        Label {
                            Text(ProCareerPresentation.milestone(milestone, resolver: copyResolver))
                        } icon: {
                            Image(systemName: "star.fill")
                        }
                        .foregroundStyle(BaseballTheme.milestone)
                    }
                }

                // 3주를 한 번에 건너뛰어도(`advanceBlock`) 그 사이의 등판이 여기 남는다.
                // 예전에는 뉴스 한 줄로 증발해서 시즌이 통째로 기억에 남지 않았다.
                if let line = state.gameLines?.last {
                    BaseballCard(title: copyResolver.resolve(AppCopyKey.proLatestOutingTitle)) {
                        VStack(alignment: .leading, spacing: 8) {
                            if line.played {
                                GameCopyText(AppCopyKey.proDirectOuting).eyebrowStyle(BaseballTheme.action)
                            }
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                // localization-safe: numeric
                                Text(GameLineFormat.score(line))
                                    .font(BaseballType.scoreboard)
                                    .foregroundStyle(BaseballTheme.textPrimary)
                                if let decisionKey = Self.decisionKey(line.decision) {
                                    GameCopyText(decisionKey)
                                        .font(.headline.weight(.heavy))
                                        .foregroundStyle(GameLineFormat.decisionTone(line.decision))
                                }
                                Spacer()
                                GameCopyText(
                                    AppCopyKey.proOutingWeek,
                                    arguments: [.integer(line.week)]
                                )
                                    .font(BaseballType.annotation.monospacedDigit())
                                    .foregroundStyle(BaseballTheme.textTertiary)
                            }
                            GameCopyText(
                                Self.outingSummaryKey(line),
                                arguments: Self.outingSummaryArguments(line, language: copyResolver.language)
                            )
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(BaseballTheme.textSecondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(Self.outingAccessibility(
                            line,
                            resolver: copyResolver
                        ))
                        .accessibilityIdentifier("today.lastOuting")
                    }
                }

                BaseballCard(title: copyResolver.resolve(AppCopyKey.proLatestNewsTitle)) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(state.news.prefix(3).enumerated()), id: \.offset) { _, item in
                            Text(ProCareerPresentation.news(item, state: state, resolver: copyResolver))
                                .detailStyle(BaseballTheme.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .padding(BaseballMetrics.gutter)
        }
        .background(BaseballTheme.canvas)
        // 고교 화면과 같은 이유 — 내비게이션 바가 없어 스크롤한 본문이 시계와 겹친다.
        .topStatusScrim()
    }

    private static func segmentText(
        _ segment: ProSeasonSegment?,
        resolver: GameCopyResolver
    ) -> String {
        guard let segment else {
            return resolver.resolve(AppCopyKey.proSegmentPreparation)
        }
        return resolver.resolve(segment.displayCopyToken)
    }

    static func segmentLabel(_ segment: ProSeasonSegment?) -> String {
        segmentText(
            segment,
            resolver: GameCopyResolver(language: .korean, policy: .releaseSafe)
        )
    }

    private static func actionKey(_ phase: ProCareerPhase) -> GameCopyKey {
        // "커리어 탭"은 존재하지 않는다 — 탭 바에는 고교/프로/기록/설정뿐이고, 실제로는
        // 프로 화면 위의 "이번 주" 세그먼트다. 없는 곳을 가리키면 처음 온 사람이 길을 잃는다.
        switch phase {
        case .weeklyPlan: AppCopyKey.proActionWeeklyPlan
        case .importantGame: AppCopyKey.proActionImportantGame
        case .seasonReview: AppCopyKey.proActionSeasonReview
        case .seasonSettlement: ProUICopyKey.actionSeasonSettlement.gameCopyKey
        case .offseasonDecision: AppCopyKey.proActionOffseasonDecision
        default: AppCopyKey.proActionDefault
        }
    }

    static func actionText(_ phase: ProCareerPhase) -> String {
        GameCopyResolver(language: .korean, policy: .releaseSafe).resolve(actionKey(phase))
    }

    private static func outingRoleKey(_ line: ProGameLine) -> GameCopyKey {
        line.started ? AppCopyKey.proRoleStarter : AppCopyKey.proRoleReliever
    }

    private static func outingSummaryKey(_ line: ProGameLine) -> GameCopyKey {
        line.hits == nil ? AppCopyKey.proOutingSummary : AppCopyKey.proOutingSummaryHits
    }

    private static func outingSummaryArguments(
        _ line: ProGameLine,
        language: AppLanguage
    ) -> [LocalizedCopyArgument] {
        let role = GameCopyResolver(language: language, policy: .releaseSafe)
            .resolve(outingRoleKey(line))
        let innings = GameFormatters.innings(outs: line.outs, language: language)
        var arguments: [LocalizedCopyArgument] = [
            .userText(role),
            .userText(innings),
        ]
        if let hits = line.hits {
            arguments.append(.integer(hits))
        }
        arguments.append(contentsOf: [
            .integer(line.strikeouts),
            .integer(line.walks),
            .integer(line.runsAllowed),
        ])
        return arguments
    }

    private static func decisionKey(_ decision: PitchingDecision) -> GameCopyKey? {
        switch decision {
        case .win: AppCopyKey.proDecisionWin
        case .loss: AppCopyKey.proDecisionLoss
        case .save: AppCopyKey.proDecisionSave
        case .noDecision: nil
        }
    }

    private static func outingAccessibility(
        _ line: ProGameLine,
        resolver: GameCopyResolver
    ) -> String {
        let role = resolver.resolve(outingRoleKey(line))
        let innings = GameFormatters.innings(outs: line.outs, language: resolver.language)
        var arguments: [LocalizedCopyArgument] = [
            .integer(line.week),
            .userText(role),
            .userText(innings),
            .userText(resolver.resolve(
                outingSummaryKey(line),
                arguments: outingSummaryArguments(line, language: resolver.language)
            )),
            .integer(line.teamRuns),
            .integer(line.opponentRuns),
        ]
        if let decisionKey = decisionKey(line.decision) {
            arguments.append(.userText(resolver.resolve(decisionKey)))
        }
        let key: GameCopyKey
        switch (decisionKey(line.decision), line.played) {
        case (nil, false): key = AppCopyKey.proOutingAccessibility
        case (nil, true): key = AppCopyKey.proOutingAccessibilityPlayed
        case (.some, false): key = AppCopyKey.proOutingAccessibilityDecision
        case (.some, true): key = AppCopyKey.proOutingAccessibilityDecisionPlayed
        }
        return resolver.resolve(key, arguments: arguments)
    }
}

/// 프로 커리어 탭 상단 상태 헤더. 오늘/이번 주 세그먼트 대신 주차·상태 3칸·진행바만 둔다.
struct ProCareerStatusHeader: View {
    let state: ProCareerSnapshot
    @Environment(\.gameCopyResolver) private var copyResolver

    @State private var showsDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
        Button { showsDetails = true } label: {
            HStack(spacing: 10) {
                PortraitView(seed: state.identity.portraitSeed, role: .player, size: 34, playerStage: .pro)
                Text(verbatim: state.identity.name).font(.headline).accessibilityIdentifier("career.playerName")
                Spacer(minLength: 4)
                Text(verbatim: copyResolver.resolve(.localizable("mobile.core.pro-season"), arguments: [.integer(state.season)]))
                    .font(BaseballType.annotation).foregroundStyle(BaseballTheme.textSecondary)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(BaseballTheme.action)
            }.frame(minHeight: BaseballMetrics.minimumTapTarget).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("pro.playerDetails")
        if CareerDisplayRules.proFatigueBand(fatigue: state.fatigue) != .normal || state.injuryWeeks > 0 {
            HStack {
                Text(verbatim: "\(copyResolver.resolve(AppCopyKey.proFatigueLabel)) \(state.fatigue)")
                if state.injuryWeeks > 0 {
                    Text(verbatim: copyResolver.resolve(AppCopyKey.proInjuryWeeks, arguments: [.integer(state.injuryWeeks)]))
                }
            }.font(.subheadline).foregroundStyle(BaseballTheme.warning)
        }
        }
        .sheet(isPresented: $showsDetails) {
            CorePitchDetailSheet(title: copyResolver.resolve(.localizable("mobile.core.stats"))) {
                playerSummary
                DisclosureGroup(copyResolver.resolve(.localizable("mobile.core.career-details"))) { fullHeader }
            }
        }
    }

    private var playerSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                PortraitView(seed: state.identity.portraitSeed, role: .player, size: 72, playerStage: .pro)
                VStack(alignment: .leading, spacing: 5) {
                    Text(verbatim: state.identity.name).font(.title2.weight(.bold)).accessibilityIdentifier("career.playerName")
                    Text(verbatim: copyResolver.resolve(.localizable("mobile.core.pro-season"), arguments: [.integer(state.season)]))
                        .foregroundStyle(BaseballTheme.action)
                    Text(verbatim: ProCareerPresentation.teamName(state.team, resolver: copyResolver)).detailStyle()
                }
            }
            HStack(alignment: .top, spacing: 12) {
                CorePlayerStat(title: copyResolver.resolve(.localizable("mobile.core.velocity")),
                    value: state.pitcher.profile(for: .fourSeam).map { GameFormatters.velocity(tenthsKPH: $0.velocityTenthsKPH, language: copyResolver.language) } ?? "—")
                CorePlayerStat(title: copyResolver.resolve(TalentAbility.command.displayCopyToken), value: "\(AbilityDisplayScale.displayRating(state.pitcher.command))", commandRating: state.pitcher.command)
                CorePlayerStat(title: copyResolver.resolve(TalentAbility.stamina.displayCopyToken), value: "\(AbilityDisplayScale.displayRating(state.pitcher.stamina))")
            }
            if CareerDisplayRules.proFatigueBand(fatigue: state.fatigue) != .normal || state.injuryWeeks > 0 {
                HStack {
                    Metric(title: copyResolver.resolve(AppCopyKey.proFatigueLabel), value: "\(state.fatigue)", tone: .warning)
                    if state.injuryWeeks > 0 {
                        Text(verbatim: copyResolver.resolve(AppCopyKey.proInjuryWeeks, arguments: [.integer(state.injuryWeeks)]))
                            .foregroundStyle(BaseballTheme.warning)
                    }
                }
            }
            Button(copyResolver.resolve(.localizable("mobile.core.stats"))) { showsDetails = true }
                .frame(minHeight: BaseballMetrics.minimumTapTarget)
                .accessibilityIdentifier("pro.playerDetails")
        }
    }

    private var fullHeader: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            KeyArtHeader(
                art: Self.art(for: state),
                eyebrow: copyResolver.resolve(
                    AppCopyKey.proSeasonHeader,
                    arguments: [
                        .integer(state.season),
                        .integer(state.week),
                        .userText(Self.segmentText(state.seasonSegment, resolver: copyResolver)),
                    ]
                ),
                title: copyResolver.resolve(
                    AppCopyKey.proDashboardTitle,
                    arguments: [
                        .userText(ProCareerPresentation.teamName(state.team, resolver: copyResolver)),
                        .userText(copyResolver.resolve(state.level.displayCopyToken)),
                        .userText(copyResolver.resolve(state.role.displayCopyToken)),
                    ]
                ),
                accent: BaseballTheme.teamDecoration(state.team.id),
                height: state.phase == .completed || state.phase == .contractOffer
                    ? BaseballMetrics.keyArtHeight
                    : BaseballMetrics.keyArtHeightCompact
            )

            SeasonArcBar(segment: state.seasonSegment, week: state.week)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    PortraitView(seed: state.identity.portraitSeed, role: .player, size: 46, playerStage: .pro)
                    Metric(
                        title: copyResolver.resolve(AppCopyKey.proFatigueLabel),
                        value: "\(state.fatigue)",
                        tone: CareerDisplayRules.proFatigueBand(fatigue: state.fatigue) == .normal
                            ? .standard : .warning,
                        caption: copyResolver.resolve(
                            CareerDisplayRules.proFatigueBand(fatigue: state.fatigue).wordCopyKey
                        )
                    )
                    Metric(
                        title: copyResolver.resolve(AppCopyKey.proManagerTrustLabel),
                        value: "\(state.managerTrust)",
                        tone: state.managerTrust >= 60 ? .positive : .standard
                    )
                    Metric(
                        title: copyResolver.resolve(AppCopyKey.proInjuryLabel),
                        value: state.injuryWeeks > 0
                            ? copyResolver.resolve(AppCopyKey.proInjuryWeeks, arguments: [.integer(state.injuryWeeks)])
                            : copyResolver.resolve(AppCopyKey.proInjuryNormal),
                        tone: state.injuryWeeks > 0 ? .negative : .standard
                    )
                }
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        PortraitView(seed: state.identity.portraitSeed, role: .player, size: 46, playerStage: .pro)
                        Metric(
                            title: copyResolver.resolve(AppCopyKey.proFatigueLabel),
                            value: "\(state.fatigue)",
                            tone: CareerDisplayRules.proFatigueBand(fatigue: state.fatigue) == .normal
                                ? .standard : .warning,
                            caption: copyResolver.resolve(
                                CareerDisplayRules.proFatigueBand(fatigue: state.fatigue).wordCopyKey
                            )
                        )
                    }
                    HStack(spacing: 10) {
                        Metric(
                            title: copyResolver.resolve(AppCopyKey.proManagerTrustLabel),
                            value: "\(state.managerTrust)",
                            tone: state.managerTrust >= 60 ? .positive : .standard
                        )
                        Metric(
                            title: copyResolver.resolve(AppCopyKey.proInjuryLabel),
                            value: state.injuryWeeks > 0
                                ? copyResolver.resolve(AppCopyKey.proInjuryWeeks, arguments: [.integer(state.injuryWeeks)])
                                : copyResolver.resolve(AppCopyKey.proInjuryNormal),
                            tone: state.injuryWeeks > 0 ? .negative : .standard
                        )
                    }
                }
            }
        }
    }

    static func art(for state: ProCareerSnapshot) -> KeyArt {
        if state.phase == .completed { return .retirement }
        if state.phase == .contractOffer { return .majorDebut }
        return .proStadiumTunnel
    }

    private static func segmentText(
        _ segment: ProSeasonSegment?,
        resolver: GameCopyResolver
    ) -> String {
        guard let segment else {
            return resolver.resolve(AppCopyKey.proSegmentPreparation)
        }
        return resolver.resolve(segment.displayCopyToken)
    }
}

/// 오늘 화면에 있던 긴장·소식·최근 기록. 커리어 흐름 맨 아래 접기로 옮긴다.
struct ProCareerNewsSection: View {
    let state: ProCareerSnapshot
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        ProgressiveDisclosure(
            contentID: "pro.weekly.news.v1",
            title: copyResolver.resolve(AppCopyKey.newsSectionTitle),
            summary: copyResolver.resolve(AppCopyKey.newsSectionSummary)
        ) {
            VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
                if let tensions = state.seasonTensions, !tensions.isEmpty {
                    BaseballCard(title: copyResolver.resolve(AppCopyKey.proTensionsTitle)) {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(tensions.enumerated()), id: \.offset) { _, tension in
                                let tensionCopy = ProCareerPresentation.tension(
                                    tension,
                                    state: state,
                                    resolver: copyResolver
                                )
                                VStack(alignment: .leading, spacing: 2) {
                                    // localization-safe: resolved-copy
                                    Text(tensionCopy.title).font(BaseballType.detail.weight(.semibold))
                                    // localization-safe: resolved-copy
                                    Text(tensionCopy.detail).detailStyle()
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }
                }

                if let rival = state.currentRival {
                    let rivalCopy = ProCareerPresentation.rival(rival, resolver: copyResolver)
                    BaseballCard(title: copyResolver.resolve(AppCopyKey.proRivalTitle), tone: .warning) {
                        HStack(spacing: 10) {
                            PortraitView(seed: rival.name, role: .rival, size: 46)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(rivalCopy.name) · \(rivalCopy.teamName)").font(.headline)
                                // localization-safe: resolved-copy
                                Text(rivalCopy.archetype)
                                    .font(.subheadline)
                                    .foregroundStyle(BaseballTheme.textSecondary)
                                // localization-safe: resolved-copy
                                Text(rivalCopy.record)
                                    .font(BaseballType.annotation.monospacedDigit())
                                    .foregroundStyle(BaseballTheme.textSecondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }

                if let milestone = state.milestones.last {
                    BaseballCard(title: copyResolver.resolve(AppCopyKey.proMilestoneTitle), tone: .milestone) {
                        Label {
                            Text(ProCareerPresentation.milestone(milestone, resolver: copyResolver))
                        } icon: {
                            Image(systemName: "star.fill")
                        }
                        .foregroundStyle(BaseballTheme.milestone)
                    }
                }

                if let line = state.gameLines?.last {
                    BaseballCard(title: copyResolver.resolve(AppCopyKey.proLatestOutingTitle)) {
                        VStack(alignment: .leading, spacing: 8) {
                            if line.played {
                                GameCopyText(AppCopyKey.proDirectOuting).eyebrowStyle(BaseballTheme.action)
                            }
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                // localization-safe: numeric
                                Text(GameLineFormat.score(line))
                                    .font(BaseballType.scoreboard)
                                    .foregroundStyle(BaseballTheme.textPrimary)
                                Spacer()
                                GameCopyText(
                                    AppCopyKey.proOutingWeek,
                                    arguments: [.integer(line.week)]
                                )
                                    .font(BaseballType.annotation.monospacedDigit())
                                    .foregroundStyle(BaseballTheme.textTertiary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("today.lastOuting")
                    }
                }

                BaseballCard(title: copyResolver.resolve(AppCopyKey.proLatestNewsTitle)) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(state.news.prefix(3).enumerated()), id: \.offset) { _, item in
                            Text(ProCareerPresentation.news(item, state: state, resolver: copyResolver))
                                .detailStyle(BaseballTheme.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
    }
}
