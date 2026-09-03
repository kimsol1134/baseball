import SwiftUI
import SimulationCore
import BaseballIOSDomain

extension HighSchoolSetupView {
    var nameStep: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            GameCopyText(isRebirth ? AppCopyKey.setupNameTitleRebirth : AppCopyKey.setupNameTitleFirst)
                .font(.title.bold())
                .foregroundStyle(BaseballTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if showOnboardingNameCTA {
                Text(verbatim: copyResolver.resolve(AppCopyKey.onboardingBullpenNameCTA))
                    .font(BaseballType.sectionTitle)
                    .foregroundStyle(BaseballTheme.action)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("hs.setup.nameCTA")
            }

            GameCopyText(AppCopyKey.setupNameDescription)
                .font(.subheadline)
                .foregroundStyle(BaseballTheme.textSecondary)

            // 입력칸이 화면에서 가장 큰 요소다. 여기가 지금 할 일이라는 뜻이다.
            VStack(alignment: .leading, spacing: 8) {
                TextField(
                    copyResolver.resolve(AppCopyKey.setupNameDefault),
                    text: nameFieldBinding,
                    prompt: Text(verbatim: suggestedName)
                )
                    .font(.system(.title, design: .default, weight: .bold))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .onSubmit { advance() }
                    .frame(minHeight: 56)
                    .accessibilityIdentifier("hs.setup.name")
                Rectangle()
                    .fill(nameFocused ? BaseballTheme.action : BaseballTheme.border)
                    .frame(height: 2)
            }
            .padding(.horizontal, BaseballMetrics.gutter)
            .padding(.vertical, 4)
            .background(BaseballTheme.surface, in: RoundedRectangle(cornerRadius: BaseballMetrics.cardRadius))

            Button {
                playerName = ""
                isSystemSuggestedName = true
                nameFocused = false
            } label: {
                Label {
                    GameCopyText(AppCopyKey.setupNameSuggestionAction, arguments: [.userText(suggestedName)])
                } icon: {
                    Image(systemName: "wand.and.stars")
                }
                    .font(BaseballType.detail.weight(.semibold))
                    .frame(minHeight: BaseballMetrics.minimumTapTarget)
            }
            .buttonStyle(.plain)
            .foregroundStyle(BaseballTheme.action)
            .accessibilityIdentifier("hs.setup.suggestName")

            // 시드로 시작 — 커뮤니티 도전("이 시드로 5회차 안에 지명?")의 입구.
            // 대부분은 안 쓰므로 눈에 띄지 않게 한 줄만.
            TextField(copyResolver.resolve(AppCopyKey.setupSeedPlaceholder), text: $seedInput)
                .font(BaseballType.detail.monospaced())
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numbersAndPunctuation)
                .accessibilityIdentifier("hs.setup.seed")
            if let error = seedFieldError {
                GameCopyText(verbatim: error)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(BaseballTheme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let challenge = parsedChallenge {
                if pendingChallenge?.token == "\(challenge.seed)-\(challenge.lifeNumber)" {
                    GameCopyText(AppCopyKey.challengeLinkApplied)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(BaseballTheme.milestone)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("app.challenge-link.applied")
                }
                GameCopyText(
                    AppCopyKey.setupSeedChallengeSummary,
                    arguments: [.integer(challenge.lifeNumber)]
                )
                    .font(.caption2)
                    .foregroundStyle(BaseballTheme.milestone)
                    .fixedSize(horizontal: false, vertical: true)
            } else if !seedInput.isEmpty {
                GameCopyText(
                    AppCopyKey.setupSeedSummary,
                    arguments: [.integer(career.inheritance.lifeNumber)]
                )
                    .font(.caption2)
                    .foregroundStyle(BaseballTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let share = shareableChallenge,
               let copy = ChallengeLink.shareText(seed: share.seed, life: share.life) {
                let text = copyResolver.resolve(
                    AppCopyKey.challengeLinkShareText,
                    arguments: [.userText(copy.token)]
                )
                let items = ChallengeLinkSession.shareItems(
                    seed: share.seed,
                    life: share.life,
                    host: ChallengeLink.host(from: Bundle.main.infoDictionary),
                    resolvedText: text
                )
                ActivityShareButton(
                    items: items,
                    subject: copyResolver.resolve(AppCopyKey.challengeLinkShareAction),
                    onTapped: {
                        CareerTelemetry.log(.challengeLinkShared, [
                            "life_number": share.life,
                        ])
                    },
                    onFinished: { _ in }
                ) {
                    Label {
                        GameCopyText(AppCopyKey.challengeLinkShareAction)
                    } icon: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .font(BaseballType.detail.weight(.semibold))
                    .frame(minHeight: BaseballMetrics.minimumTapTarget)
                }
                .buttonStyle(.plain)
                .foregroundStyle(BaseballTheme.action)
                .disabled(items.isEmpty)
                .accessibilityIdentifier("hs.setup.shareChallengeLink")
            }

            if isRebirth, parsedChallenge == nil {
                inheritanceCard
            } else {
                // 입력칸 아래 화면 1/3이 빈 검정이었다(QA P2-11) — 이름을 정하는 순간에
                // 3년이 흐를 무대를 미리 보여 준다.
                Image(KeyArt.stadiumNight.rawValue)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 170)
                    .overlay {
                        // 캡션이 밝은 잔디 위에 놓여 대비가 무너졌다. 아래쪽만 캔버스색으로 눌러 준다.
                        LinearGradient(
                            colors: [BaseballTheme.canvas.opacity(0), BaseballTheme.canvas.opacity(0.85)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: BaseballMetrics.cardRadius))
                    .overlay(alignment: .bottomLeading) {
                        GameCopyText(AppCopyKey.setupStadiumCaption)
                            .detailStyle(BaseballTheme.textPrimary)
                            .padding(12)
                    }
                    .accessibilityHidden(true)
            }
        }
        .padding(.bottom, 16)
        // 어느 회차에서도 키보드를 먼저 올리지 않는다.
        //
        // 1회차에서는 앱을 켠 두 번째 화면에서 한글 키보드가 하단 40%를 덮고 그 위에
        // `다음`이 겹쳤다 — "게임을 켰는데 회원가입 폼이 뜬다". 이름은 placeholder로
        // 그냥 진행할 수 있고 `민서준 쓰기` 버튼도 있으므로, 키보드는 유저가 부를 때만
        // 올라오면 된다. 환생 회차는 계승 카드가 가려지는 문제까지 있었다(QA P2-11).
    }

    private var inheritanceCard: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.tightSpacing) {
            // 환생 회차의 첫 화면이 텍스트 카드뿐이었다 — 루프 재시작은 이 게임의
            // 감정적 핵심이라, 1회차의 구장 그림과 같은 무게의 무대를 준다.
            Image(KeyArt.reincarnation.rawValue)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: BaseballMetrics.cardRadius))
                .overlay(alignment: .bottomLeading) {
                    GameCopyText(AppCopyKey.setupRebirthCaption)
                        .font(.caption)
                        .foregroundStyle(BaseballTheme.textSecondary)
                        .padding(10)
                }
                .accessibilityHidden(true)
            BaseballCard(title: copyResolver.resolve(AppCopyKey.setupInheritanceTitle), tone: .milestone) {
                VStack(alignment: .leading, spacing: 8) {
                    GameCopyText(
                        AppCopyKey.setupInheritancePoints,
                        arguments: [.integer(career.inheritance.soulPoints)]
                    )
                        .font(.subheadline.bold().monospacedDigit())
                    // 정직한 계승 안내 — 고교·주간에서 모은 자동 누적과 프로 보너스를
                    // 포함한 지갑은 다르다. 화면에서도 한 숫자로 섞지 않는다.
                    GameCopyText(
                        AppCopyKey.setupInheritanceAutomaticGrowth,
                        arguments: [
                            .integer(HighSchoolCareerStore.appliedInheritance(
                                for: career.inheritance.automaticSoulTotal,
                                storedRulesVersion: career.inheritance.inheritanceRulesVersion
                            )),
                            .integer(remainingSoul),
                        ]
                    )
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(BaseballTheme.textSecondary)
                    // 다음 계단을 함께 적는다. "24혼 모았는데 +1"만 있으면 정직해도
                    // 몰수처럼 읽힌다 — 같은 숫자가 다음 구간과 나란히 서면 진척이 된다.
                    if let step = HighSchoolCareerStore.nextInheritanceStep(
                        for: career.inheritance.automaticSoulTotal,
                        storedRulesVersion: career.inheritance.inheritanceRulesVersion
                    ) {
                        GameCopyText(
                            AppCopyKey.setupInheritanceNextStep,
                            arguments: [.integer(step.soulPoints), .integer(step.applied)]
                        )
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(BaseballTheme.action)
                            .accessibilityIdentifier("hs.inheritance.next")
                    } else {
                        GameCopyText(AppCopyKey.setupInheritanceMaxed)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(BaseballTheme.action)
                            .accessibilityIdentifier("hs.inheritance.next")
                    }
                    if career.inheritance.memories.isEmpty, selectedSignatureLegacy == nil {
                        GameCopyText(AppCopyKey.setupInheritanceEmptyMemories)
                            .detailStyle()
                    } else if !career.inheritance.memories.isEmpty {
                        ForEach(career.inheritance.memories, id: \.self) { memory in
                            let copy = HighSchoolConclusionPresentation.localizedMemory(
                                memory,
                                resolver: copyResolver
                            )
                            HStack(spacing: 8) {
                                ArtThumb(assetName: "MemoryArt-\(memory.rawValue)", size: 34, cornerRadius: 7)
                                GameCopyText(verbatim: copy.title)
                                    .font(BaseballType.detail)
                                    .foregroundStyle(BaseballTheme.textSecondary)
                            }
                        }
                    }
                    if let legacy = selectedSignatureLegacy {
                        Divider()
                        GameCopyText(
                            AppCopyKey.setupInheritanceLegacy,
                            arguments: [.userText(legacy.title)]
                        )
                            .font(BaseballType.detail.weight(.bold))
                            .foregroundStyle(BaseballTheme.milestone)
                        GameCopyText(verbatim: Self.localizedSignatureLegacyEffectLine(legacy.effect, resolver: copyResolver))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(BaseballTheme.textSecondary)
                    }
                }
            }
            soulShopCard
        }
    }

    /// 상점에서 산 것을 빼고 남는 지갑 잔액. 자동 성장 누적과는 독립적이다.
    private var remainingSoul: Int {
        career.inheritance.soulPoints - selectedBoosts.reduce(0) { $0 + $1.cost }
    }

    static func showsSoulDomain(automaticSoulTotal: Int, isChallenge: Bool) -> Bool {
        !isChallenge && automaticSoulTotal > 0
    }

    /// 영혼 상점 — 상한 너머의 야구혼이 처음으로 흘러갈 배수구.
    /// 스탯이 아니라 규칙을 판다: 재능 돌파·기억 확장·조기 성장·성장 리듬.
    private var soulShopCard: some View {
        BaseballCard(title: copyResolver.resolve(AppCopyKey.setupInheritanceShopTitle), tone: .raised) {
            VStack(alignment: .leading, spacing: 8) {
                ProgressiveDisclosure(
                    contentID: "hs.setup.inheritance.shop.v1",
                    title: copyResolver.resolve(AppCopyKey.setupInheritanceShopGuideTitle),
                    summary: copyResolver.resolve(AppCopyKey.setupInheritanceShopSummary)
                ) {
                    GameCopyText(AppCopyKey.setupInheritanceShopDescription)
                        .detailStyle()
                }
                ForEach(SoulBoostID.allCases, id: \.self) { boost in
                    let selected = selectedBoosts.contains(boost)
                    let affordable = selected || boost.cost <= remainingSoul
                    Button {
                        if selected { selectedBoosts.remove(boost) }
                        else if affordable { selectedBoosts.insert(boost) }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selected ? BaseballTheme.milestone : affordable ? BaseballTheme.textSecondary : BaseballTheme.border)
                            VStack(alignment: .leading, spacing: 1) {
                                let copy = Self.localizedBoostCopy(boost, resolver: copyResolver)
                                GameCopyText(verbatim: copy.title)
                                    .font(.subheadline.weight(.semibold))
                                GameCopyText(verbatim: copy.detail)
                                    .font(.caption)
                                    .foregroundStyle(BaseballTheme.textSecondary)
                            }
                            Spacer()
                            GameCopyText(
                                AppCopyKey.setupBoostCost,
                                arguments: [.integer(boost.cost)]
                            )
                                .font(BaseballType.annotation.weight(.bold).monospacedDigit())
                                .foregroundStyle(affordable ? BaseballTheme.milestone : BaseballTheme.textTertiary)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(selected ? BaseballTheme.milestone.opacity(0.12) : BaseballTheme.surface,
                                    in: RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius))
                        .overlay {
                            RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                                .stroke(selected ? BaseballTheme.milestone : BaseballTheme.border, lineWidth: selected ? 2 : 1)
                        }
                        .opacity(affordable ? 1 : 0.5)
                    }
                    .buttonStyle(.plain)
                    .disabled(!affordable && !selected)
                    .accessibilityIdentifier("hs.shop.\(boost.rawValue)")
                }
            }
        }
    }

    static func boostCopy(_ boost: SoulBoostID) -> (title: String, detail: String) {
        localizedBoostCopy(boost, resolver: koreanResolver)
    }

    static func localizedBoostCopy(
        _ boost: SoulBoostID,
        resolver: GameCopyResolver
    ) -> (title: String, detail: String) {
        switch boost {
        case .talentBreak:
            (
                resolver.resolve(AppCopyKey.setupBoostTalentBreakTitle),
                resolver.resolve(AppCopyKey.setupBoostTalentBreakDetail)
            )
        case .extraMemory:
            (
                resolver.resolve(AppCopyKey.setupBoostExtraMemoryTitle),
                resolver.resolve(AppCopyKey.setupBoostExtraMemoryDetail)
            )
        case .headStart:
            (
                resolver.resolve(AppCopyKey.setupBoostHeadStartTitle),
                resolver.resolve(AppCopyKey.setupBoostHeadStartDetail)
            )
        case .trainingRhythm:
            (
                resolver.resolve(AppCopyKey.setupBoostTrainingRhythmTitle),
                resolver.resolve(AppCopyKey.setupBoostTrainingRhythmDetail)
            )
        }
    }

}
