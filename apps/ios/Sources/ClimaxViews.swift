import StoreKit
import SwiftUI
import SimulationCore

/// 정점 연출 세 가지 — 드래프트 호명, 환생, 명장면 스탬프.
///
/// 이 게임에는 "남에게 보여주고 싶은 5초"가 없었다(품질 평가 §3-F1, 결격 2). 3년의 종착지인
/// 드래프트가 버튼 한 번에 전부 공개됐고, 로그라이트의 사망·계승 순간인 환생도 그냥 버튼이며,
/// 홈런은 다른 결과와 같은 카드로 지나갔다.
///
/// **정점 연출은 드물어서 정점이다.** 여기 있는 것은 회차당 한 번(드래프트·환생)이거나
/// 이닝을 끝내는 한 공(스탬프)에만 나온다. 일반 화면은 그대로 절제된 카드 언어를 지킨다.
///
/// 모션 감소에서는 전부 즉시 공개 경로로 간다 — 연출이 정보를 늦추면 안 된다.

// MARK: - ① 드래프트 호명

/// 대기 → 라운드 → 호명/미지명.
///
/// 예전에는 "결과 확인"을 누르면 지명 여부·구단·순번·계약금이 한꺼번에 카드로 떴다.
/// 3년을 쌓아 온 순간이 목록 한 장으로 끝났다는 뜻이다.
struct DraftRevealView: View {
    let result: DraftResultSnapshot
    let playerName: String
    /// 이 순간의 선수 카드. 감정이 가장 높은 자리에서 바로 자랑할 수 있게 한다.
    ///
    /// 예전에는 공유 버튼이 정산·기록 화면에만 있었다 — 호명을 본 순간과 공유 버튼
    /// 사이에 화면이 한두 장 끼어 있었고, **그 거리가 곧 공유율이다.** 없으면 버튼을
    /// 그리지 않는다(구저장본에서 온 연출 등).
    var shareRecord: HighSchoolCareerStore.LifeRecord? = nil
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.requestReview) private var requestReview
    @Environment(\.gameCopyResolver) private var copyResolver

    /// 공개 단계. 순서가 곧 긴장의 순서다.
    private enum Stage: Int {
        /// 호명을 기다린다.
        case waiting
        /// 라운드가 하나씩 넘어간다.
        case counting
        /// 결과.
        case revealed
    }

    @State private var stage: Stage = .waiting
    @State private var visibleRound = 1
    @State private var stampScale: CGFloat = 1.6
    @State private var stampOpacity: Double = 0

    private var drafted: Bool { result.outcome == .drafted }
    /// 지명이면 그 라운드까지, 미지명이면 마지막 라운드까지 센다.
    private var finalRound: Int { result.round ?? 10 }
    private var teamAccent: Color {
        result.team.map { BaseballTheme.teamDecoration($0.id) } ?? BaseballTheme.textSecondary
    }

    var body: some View {
        ZStack {
            KeyArtBackdrop(art: .draftDay, dim: stage == .revealed && !drafted ? 0.88 : 0.6)
                // 그림만 화면 끝까지 간다. 루트에 `ignoresSafeArea`를 걸면 아래 버튼이
                // 홈 인디케이터 밑으로 밀려 글자가 잘린다.
                .ignoresSafeArea()
                // 연출 도중 배경을 누르면 즉시 결과로 간다. **루트가 아니라 배경에 건다** —
                // 루트에 탭 제스처를 걸면 화면 전체가 접근성 요소 하나로 접혀서, 안의 버튼을
                // 화면 리더도 UI 테스트도 찾지 못한다.
                .contentShape(Rectangle())
                .onTapGesture { skipToReveal() }

            VStack(spacing: 18) {
                Spacer()

                switch stage {
                case .waiting:
                    Text(copyResolver.resolve(AppCopyKey.conclusionDraftRevealWaiting))
                        .eyebrowStyle(BaseballTheme.milestone)
                    // localization-safe: user-input
                    Text(playerName)
                        .font(BaseballType.display)
                        .foregroundStyle(BaseballTheme.textPrimary)
                        .multilineTextAlignment(.center)
                case .counting:
                    Text(copyResolver.resolve(
                        AppCopyKey.conclusionDraftRevealRound,
                        arguments: [.integer(visibleRound)]
                    )).eyebrowStyle(BaseballTheme.milestone)
                    // localization-safe: symbol
                    Text(visibleRound < finalRound ? "…" : " ")
                        .font(BaseballType.display)
                        .foregroundStyle(BaseballTheme.textTertiary)
                        .monospacedDigit()
                case .revealed:
                    reveal
                }

                Spacer()
            }
            // Window-relative width is finite before intrinsic text layout, so long
            // localized copy wraps without expanding the outer ZStack or its CTA overlay.
            .containerRelativeFrame(.horizontal) { length, _ in
                max(0, length - BaseballMetrics.gutter * 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerRelativeFrame(.horizontal)
        .background(BaseballTheme.canvas.ignoresSafeArea())
        // 버튼은 아래에 겹쳐 놓는다. 내용 VStack 안에 두고 `ignoresSafeArea`를 함께 걸면
        // 상태 표시줄 뒤로 밀려 올라가 위아래에 두 번 그려진 것처럼 보였고,
        // `safeAreaInset`도 같은 증상을 냈다.
        //
        // 버튼은 항상 같은 자리에 있다. 연출 중에는 "건너뛰기", 결과가 나오면 "계속"이다 —
        // 기다리는 동안 출구가 없으면 두 번째 회차부터 이 연출이 방해물이 된다.
        .overlay(alignment: .bottom) {
            VStack(spacing: 8) {
                // 자랑이 먼저, 별점은 나중이다. 순서를 뒤집으면 별점 창이 감정을 끊고
                // 그 뒤에 남는 공유 버튼은 이미 식은 자리가 된다.
                if stage == .revealed, let shareRecord {
                    LifeCardShareButton(record: shareRecord)
                }
                PrimaryPill(
                    title: copyResolver.resolve(
                        stage == .revealed
                            ? AppCopyKey.conclusionDraftRevealContinue
                            : AppCopyKey.conclusionDraftRevealSkip
                    ),
                    identifier: "hs.draft.reveal.done",
                    action: {
                        guard stage == .revealed else { return skipToReveal() }
                        // 지명 확정 스탬프를 닫는 순간은 이 게임의 감정 최고점이다.
                        // 물어도 되는지(이유 소진·간격·UI 테스트)는 ReviewPrompt가 판단한다.
                        if drafted, ReviewPrompt.shouldAsk(.drafted) {
                            requestReview()
                        }
                        onFinish()
                    }
                )
            }
            .padding(.horizontal, BaseballMetrics.gutter)
            .padding(.bottom, BaseballMetrics.gutter)
        }
        .onAppear(perform: start)
    }

    @ViewBuilder private var reveal: some View {
        VStack(spacing: 12) {
            if drafted, let team = result.team {
                Text(copyResolver.resolve(AppCopyKey.conclusionDraftRevealDrafted))
                    .eyebrowStyle(teamAccent)
                Text(HighSchoolConclusionPresentation.localizedTeamName(team, resolver: copyResolver))
                    .font(.system(.title, design: .default, weight: .heavy))
                    .foregroundStyle(teamAccent)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(copyResolver.resolve(
                    AppCopyKey.conclusionDraftRevealPick,
                    arguments: [.integer(result.round ?? 0), .integer(result.overallPick ?? 0)]
                ))
                    .font(BaseballType.scoreboard)
                    .foregroundStyle(BaseballTheme.textPrimary)
                if let bonus = result.signingBonus {
                    Text(copyResolver.resolve(
                        AppCopyKey.conclusionDraftRevealBonus,
                        arguments: [.userText(copyResolver.language == .korean
                            ? KoreanCopy.money(won: bonus)
                            : GameFormatters.krw(bonus, language: copyResolver.language))]
                    ))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(BaseballTheme.textSecondary)
                }
            } else {
                Text(copyResolver.resolve(AppCopyKey.conclusionDraftRevealComplete))
                    .eyebrowStyle(BaseballTheme.textTertiary)
                Text(copyResolver.resolve(AppCopyKey.conclusionDraftRevealNotCalled))
                    .font(.title2.bold())
                    .foregroundStyle(BaseballTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(copyResolver.resolve(AppCopyKey.conclusionDraftRevealUndraftedBody))
                    .font(.subheadline)
                    .foregroundStyle(BaseballTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

            }
        }
        .frame(maxWidth: .infinity)
        // 본문이 화면 끝에 닿으면 유료 게임의 정점 화면이 급조된 화면으로 읽힌다(QA 재검증 신규 2).
        .padding(.horizontal, BaseballMetrics.gutter * 2)
        .scaleEffect(stampScale)
        .opacity(stampOpacity)
    }

    private func start() {
        guard !reduceMotion else {
            skipToReveal()
            return
        }
        // 대기 1.1초 → 라운드 카운트 → 호명. 라운드 수가 많아도 전체가 4초를 넘지 않게
        // 한 라운드당 시간을 나눠 준다.
        let perRound = min(0.34, 2.2 / Double(max(1, finalRound)))
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            guard stage == .waiting else { return }
            stage = .counting
            countRound(1, interval: perRound)
        }
    }

    private func countRound(_ round: Int, interval: Double) {
        guard stage == .counting else { return }
        visibleRound = round
        Haptics.shared.meterEdge()
        guard round < finalRound else {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval) { showReveal() }
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
            countRound(round + 1, interval: interval)
        }
    }

    private func skipToReveal() {
        guard stage != .revealed else { return }
        visibleRound = finalRound
        showReveal()
    }

    private func showReveal() {
        guard stage != .revealed else { return }
        stage = .revealed
        Haptics.shared.outcome(success: drafted)
        GameAudio.shared.play(drafted ? .crowdCheer : .crowdGroan)
        if reduceMotion {
            stampScale = 1
            stampOpacity = 1
        } else {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.62)) {
                stampScale = 1
                stampOpacity = 1
            }
        }
    }
}

// MARK: - ② 환생

/// 회차가 넘어가는 순간. 키아트 한 장과 회차 숫자만 있다.
///
/// 로그라이트에서 사망·계승은 루프의 이음매다. 그 순간에 연출이 하나도 없으면 회차가
/// 쌓이는 감각도 없다.
struct RebirthStampView: View {
    let lifeNumber: Int
    let onFinish: @MainActor @Sendable () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.gameCopyResolver) private var copyResolver
    @State private var stampScale: CGFloat = 2.2
    @State private var stampOpacity: Double = 0

    var body: some View {
        ZStack {
            KeyArtBackdrop(art: .reincarnation, dim: 0.5)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onFinish)
            VStack(spacing: 10) {
                Text(copyResolver.resolve(AppCopyKey.conclusionRebirthStampTitle))
                    .eyebrowStyle(BaseballTheme.milestone)
                Text(copyResolver.resolve(
                    AppCopyKey.conclusionRebirthStampLife,
                    arguments: [.integer(lifeNumber)]
                ))
                    .font(BaseballType.display)
                    .foregroundStyle(BaseballTheme.textPrimary)
                    .monospacedDigit()
                    .scaleEffect(stampScale)
                    .opacity(stampOpacity)
                Text(copyResolver.resolve(AppCopyKey.conclusionRebirthStampBody))
                    .font(.subheadline)
                    .foregroundStyle(BaseballTheme.textSecondary)
                    .opacity(stampOpacity)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("hs.rebirth.stamp")
        .accessibilityLabel(copyResolver.resolve(
            AppCopyKey.conclusionRebirthStampAccessibility,
            arguments: [.integer(lifeNumber)]
        ))
        .onAppear {
            Haptics.shared.outcome(success: true)
            GameAudio.shared.play(.milestone)
            if reduceMotion {
                stampScale = 1
                stampOpacity = 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: onFinish)
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    stampScale = 1
                    stampOpacity = 1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: onFinish)
            }
        }
    }
}

/// 키아트를 전면에 깔고 그 위를 캔버스 색으로 눌러 글자가 읽히게 한다.
///
/// 고대비 모드에서는 `KeyArtHeader`와 같은 이유로 그림을 빼고 단색으로 간다.
private struct KeyArtBackdrop: View {
    let art: KeyArt
    let dim: Double

    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiate
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        ZStack {
            BaseballTheme.canvas
            if contrast != .increased {
                Image(art.rawValue)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .accessibilityHidden(true)
            }
            BaseballTheme.canvas.opacity(dim)
        }
    }
}

// MARK: - ③ 명장면 스탬프

/// 홈런과 이닝을 끝낸 삼진에만 찍힌다.
///
/// 이 장면이 곧 공유용 스크린샷이다. 그래서 숫자를 크게 박는다 — 비거리와 구속은
/// 야구를 아는 사람이 캡처해서 올릴 때 제일 먼저 보는 두 값이다.
///
/// 다른 결과에는 찍지 않는다. 매 공마다 스탬프가 나오면 그건 스탬프가 아니라 배경이다.
struct HighlightStamp: View {
    enum Kind: Equatable {
        case homeRun(distanceMeters: Int)
        case inningEndingStrikeout
        /// 2타자 연속부터. 숫자가 올라갈수록 이 스탬프 하나가 하이라이트가 된다.
        case strikeoutStreak(count: Int)
        /// 실점 없이 이닝을 닫은 마지막 아웃(삼진 외). 병살·야수 정면으로 위기를 막는
        /// 가장 흔한 명장면인데 아무 표시가 없었다(QA P1-7).
        case inningShutdown
        /// 생애 최고 구속 갱신. 회차를 넘어 이어지는 유일한 "내 몸의 기록"이라
        /// 갱신 순간은 결과와 무관하게 하이라이트다.
        case velocityRecord

        func title(resolver: GameCopyResolver) -> String {
            let key: LegacyUICopyKey = switch self {
            case .homeRun: .highlightHomeRunTitle
            case .inningEndingStrikeout, .strikeoutStreak: .highlightStrikeoutTitle
            case .inningShutdown: .highlightShutdownTitle
            case .velocityRecord: .highlightVelocityTitle
            }
            return resolver.resolve(key)
        }

        func subtitle(resolver: GameCopyResolver) -> String? {
            switch self {
            case .homeRun(let distance):
                distance > 0
                    ? GameFormatters.distance(tenthsMeters: distance * 10, language: resolver.language)
                    : nil
            case .inningEndingStrikeout:
                resolver.resolve(.highlightInningEndingSubtitle)
            case .strikeoutStreak(let count):
                resolver.resolve(.highlightStreakSubtitle, arguments: [.integer(count)])
            case .inningShutdown:
                resolver.resolve(.highlightShutdownSubtitle)
            case .velocityRecord:
                resolver.resolve(.highlightVelocitySubtitle)
            }
        }

        var accent: Color {
            switch self {
            case .homeRun: BaseballTheme.negative
            case .inningEndingStrikeout: BaseballTheme.action
            case .strikeoutStreak: BaseballTheme.milestone
            case .inningShutdown: BaseballTheme.positive
            case .velocityRecord: BaseballTheme.milestone
            }
        }
    }

    let kind: Kind
    /// 구속(0.1km/h 단위). 두 장면 모두 이 숫자가 함께 나온다.
    let velocityTenthsKPH: Int

    @Environment(\.gameCopyResolver) private var copyResolver
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scale: CGFloat = 1.8
    @State private var opacity: Double = 0

    /// 이 투구가 스탬프를 받을 자격이 있는가. 뷰가 아니라 규칙이라 순수 함수로 둔다.
    static func kind(
        outcome: PitchOutcome,
        plateResult: PlateAppearanceResult?,
        inningEnded: Bool,
        landingDistanceTenthsMeters: Int?,
        consecutiveStrikeouts: Int = 0,
        runsScored: Int = 0,
        isVelocityRecord: Bool = false
    ) -> Kind? {
        if outcome == .homeRun {
            return .homeRun(distanceMeters: (landingDistanceTenthsMeters ?? 0) / 10)
        }
        // 연속 스트릭이 이닝 종료보다 위다. "3타자 연속"은 쌓아 온 서사고,
        // 이닝 종료는 그 공 하나의 사실이다.
        if plateResult == .strikeout, consecutiveStrikeouts >= 2 {
            return .strikeoutStreak(count: consecutiveStrikeouts)
        }
        // 신기록은 결과보다 위다 — 맞았어도 내 팔은 어제의 나를 이겼다.
        if isVelocityRecord {
            return .velocityRecord
        }
        if plateResult == .strikeout, inningEnded {
            return .inningEndingStrikeout
        }
        if inningEnded, plateResult == .inPlayOut, runsScored == 0 {
            return .inningShutdown
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(verbatim: kind.title(resolver: copyResolver))
                .font(BaseballType.display)
                .foregroundStyle(kind.accent)
            HStack(spacing: 8) {
                if let subtitle = kind.subtitle(resolver: copyResolver) {
                    Text(verbatim: subtitle)
                        .font(BaseballType.scoreboard)
                        .foregroundStyle(BaseballTheme.textPrimary)
                }
                // 인플레이 아웃(위기 차단)에 구속을 병기하면 타구 장면에 투구 수치가
                // 붙는 셈이다 — 그 스탬프는 부제만으로 말한다(QA 재검증 신규 5).
                if kind != .inningShutdown {
                    Text(verbatim: GameFormatters.velocity(
                        tenthsKPH: velocityTenthsKPH,
                        language: copyResolver.language
                    ))
                        .font(BaseballType.scoreboard)
                        .foregroundStyle(BaseballTheme.textSecondary)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(BaseballTheme.canvas.opacity(0.72), in: RoundedRectangle(cornerRadius: BaseballMetrics.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: BaseballMetrics.cardRadius)
                .stroke(kind.accent, lineWidth: 2)
        }
        .scaleEffect(scale)
        .opacity(opacity)
        .accessibilityElement(children: .combine)
        .onAppear {
            guard !reduceMotion else {
                scale = 1
                opacity = 1
                return
            }
            // 리플레이가 끝나는 순간(1.6초)에 맞춰 찍는다. 공이 날아가는 중에 스탬프가
            // 먼저 뜨면 결과를 미리 알려 주는 셈이 된다.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.58)) {
                    scale = 1
                    opacity = 1
                }
            }
        }
    }
}

// MARK: - ④ 만개

/// 재능의 한계가 열리는 순간.
///
/// 이 게임에서 가장 기다리게 되는 순간이다. 막혀 있던 능력을 몇 번이고 두드리다가
/// 어느 훈련에서 벽이 사라진다 — 그 한 번이 회차 전체의 기억이 된다.
///
/// 성장 축하(`GrowthCelebrationView`)와 구분한다. 그건 매주 오는 +1이고 이건 회차에
/// 한두 번이다. 같은 연출을 쓰면 둘 다 평범해진다.
struct BloomCelebrationView: View {
    let ability: TalentAbility
    let grade: TalentGrade
    let onDismiss: () -> Void
    // 만개 아트가 번들에 있으면 축하 카드 배경에 깔린다.

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.gameCopyResolver) private var copyResolver
    @State private var burst: Double = 0
    @State private var scale: CGFloat = 0.7

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: copyResolver.resolve(.bloomTitle)).eyebrowStyle(BaseballTheme.milestone)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(verbatim: copyResolver.resolve(ability.displayCopyToken))
                    .font(BaseballType.display)
                    .foregroundStyle(BaseballTheme.textPrimary)
                Text(verbatim: copyResolver.resolve(grade.displayCopyToken))
                    .font(BaseballType.heroNumeral)
                    .foregroundStyle(BaseballTheme.actionInk)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 2)
                    .background(BaseballTheme.action, in: Capsule())
            }

            Text(
                verbatim: copyResolver.resolve(
                    .bloomCeiling,
                    arguments: [.integer(grade.ceiling)]
                )
            )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BaseballTheme.milestone)
            Text(verbatim: LegacyPresentation.bloomMeaning(grade, resolver: copyResolver))
                .font(.footnote)
                .foregroundStyle(BaseballTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onDismiss) {
                Text(verbatim: copyResolver.resolve(.bloomDismiss))
            }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BaseballTheme.action)
                .frame(maxWidth: .infinity, minHeight: BaseballMetrics.minimumTapTarget)
                .accessibilityIdentifier("hs.bloom.dismiss")
        }
        .padding(BaseballMetrics.gutter)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            // 만개 아트가 있으면 깔린다 — 회차당 몇 번뿐인 순간이라 그림값을 한다.
            if UIImage(named: "BloomArt") != nil {
                Image("BloomArt")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .overlay(BaseballTheme.milestoneSoft.opacity(0.82))
                    .clipShape(RoundedRectangle(cornerRadius: BaseballMetrics.cardRadius))
            } else {
                RoundedRectangle(cornerRadius: BaseballMetrics.cardRadius)
                    .fill(BaseballTheme.milestoneSoft)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: BaseballMetrics.cardRadius)
                .stroke(BaseballTheme.milestone, lineWidth: 2)
                .opacity(0.4 + burst * 0.6)
        }
        .scaleEffect(scale)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            copyResolver.resolve(
                .bloomAccessibility,
                arguments: [
                    .userText(copyResolver.resolve(ability.displayCopyToken)),
                    .userText(copyResolver.resolve(grade.displayCopyToken)),
                    .integer(grade.ceiling),
                ]
            )
        )
        .onAppear {
            Haptics.shared.outcome(success: true)
            GameAudio.shared.play(.milestone)
            guard !reduceMotion else {
                scale = 1
                burst = 1
                return
            }
            withAnimation(.spring(response: 0.44, dampingFraction: 0.6)) { scale = 1 }
            withAnimation(.easeOut(duration: 0.9)) { burst = 1 }
        }
    }
}
