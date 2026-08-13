import SwiftUI
import SimulationCore

/// 고교 커리어 시작 화면. 한 화면에 한 가지만 묻는다.
///
/// 예전에는 이름·투수 유형·난이도·핸디캡이 한 페이지에 세로로 늘어서 있었다. 실기기에서
/// 처음 켠 사람이 **"이름 입력하고 이런 게 잘 안 보인다"**고 했다. 당연하다 — 이름은
/// 카드 네 개 중 하나였고, 화면을 열면 눈에 먼저 들어오는 건 능력치 막대가 그려진
/// 투수 유형 카드였다. 스크롤 없이 보이는 첫 화면에서 "지금 뭘 해야 하는지"가 읽히지
/// 않으면 사람은 나간다.
///
/// 그래서 단계로 쪼갠다. 한 단계에는 질문 하나와 그 질문에 답하는 것만 있다.
/// 첫 회차는 세 단계(이름 → 지역 → 투수 유형), 2회차부터 네 단계(+ 난이도·핸디캡)다.
struct HighSchoolSetupView: View {
    let career: HighSchoolCareerStore

    @Environment(\.gameCopyResolver) private var copyResolver

    /// These arrays follow the engine's stable region order. The stored region IDs remain the
    /// Korean-world identifiers used by simulation and persistence; only their display copy is
    /// localized here.
    private static let regionNameKeys: [GameCopyKey] = [
        AppCopyKey.setupRegionSeoulName, AppCopyKey.setupRegionIncheonName,
        AppCopyKey.setupRegionSuwonName, AppCopyKey.setupRegionDaejeonName,
        AppCopyKey.setupRegionGwangjuName, AppCopyKey.setupRegionDaeguName,
        AppCopyKey.setupRegionBusanName, AppCopyKey.setupRegionChangwonName,
        AppCopyKey.setupRegionUlsanName, AppCopyKey.setupRegionSejongName,
        AppCopyKey.setupRegionGyeonggiName, AppCopyKey.setupRegionGangwonName,
        AppCopyKey.setupRegionChungbukName, AppCopyKey.setupRegionChungnamName,
        AppCopyKey.setupRegionJeonbukName, AppCopyKey.setupRegionJeonnamName,
        AppCopyKey.setupRegionGyeongbukName, AppCopyKey.setupRegionGyeongnamName,
        AppCopyKey.setupRegionJejuName,
    ]

    private static let regionFlavorKeys: [GameCopyKey] = [
        AppCopyKey.setupRegionSeoulFlavor, AppCopyKey.setupRegionIncheonFlavor,
        AppCopyKey.setupRegionSuwonFlavor, AppCopyKey.setupRegionDaejeonFlavor,
        AppCopyKey.setupRegionGwangjuFlavor, AppCopyKey.setupRegionDaeguFlavor,
        AppCopyKey.setupRegionBusanFlavor, AppCopyKey.setupRegionChangwonFlavor,
        AppCopyKey.setupRegionUlsanFlavor, AppCopyKey.setupRegionSejongFlavor,
        AppCopyKey.setupRegionGyeonggiFlavor, AppCopyKey.setupRegionGangwonFlavor,
        AppCopyKey.setupRegionChungbukFlavor, AppCopyKey.setupRegionChungnamFlavor,
        AppCopyKey.setupRegionJeonbukFlavor, AppCopyKey.setupRegionJeonnamFlavor,
        AppCopyKey.setupRegionGyeongbukFlavor, AppCopyKey.setupRegionGyeongnamFlavor,
        AppCopyKey.setupRegionJejuFlavor,
    ]

    /// 설정 단계. 순서가 곧 화면 순서다.
    private enum Step: Int, CaseIterable {
        case name, region, style, handicap
    }

    @State private var step: Step = .name
    @State private var playerName = ""
    /// A localized system suggestion is display-only. Keep it separate from user text so the
    /// save/presentation boundary can still submit an empty name and let the engine choose the
    /// preset's language-neutral default.
    @State private var isSystemSuggestedName = false
    @State private var selectedRegion = HighSchoolCareerEngine.regions.first ?? ""
    @State private var selectedPresetID = PitcherPresetCatalog.all.first?.id ?? ""
    @State private var selectedKarmas: Set<KarmaID> = []
    /// 계승한 야구혼을 어디에 붓는가. 2회차부터만 고른다.
    @State private var soulDomain: SoulDomain = .technique
    /// 영혼 상점에서 담은 부스트. 잔액 안에서만 담긴다.
    @State private var selectedBoosts: Set<SoulBoostID> = []
    /// 발견한 대표 유산 중 이번 선수에게 직접 이어 줄 한 자리.
    @State private var selectedSignatureLegacyID: CareerSignatureLegacyID?
    /// 공유받은 시드로 시작하기. 비우면 랜덤.
    @State private var seedInput = ""

    @State private var harshness: DifficultyLevel = .standard
    @FocusState private var nameFocused: Bool

    /// The first screen must remain readable before the player explicitly taps the field.
    static func shouldAutoFocusName(isRebirth: Bool) -> Bool {
        _ = isRebirth
        return false
    }

    /// 원버튼 환생 — 지난 회차와 같은 설정(이름·지역·유형·난이도·카르마)으로 즉시 시작.
    /// 부스트는 회차마다 다시 고르는 소비라 싣지 않는다.
    @ViewBuilder private var quickRebirthCard: some View {
        if isRebirth, seedInput.isEmpty, let last = career.lastSetup,
           let preset = presets.first(where: { $0.id == last.presetID }) {
            BaseballCard(title: copyResolver.resolve(AppCopyKey.setupQuickRebirthTitle), tone: .raised) {
                VStack(alignment: .leading, spacing: 6) {
                    GameCopyText(
                        AppCopyKey.setupQuickRebirthSummary,
                        arguments: [
                            .userText(Self.localizedQuickRebirthPlayerName(
                                last.playerName,
                                preset: preset,
                                resolver: copyResolver
                            )),
                            .userText(Self.localizedRegionName(last.region, resolver: copyResolver)),
                        ]
                    )
                        .font(.footnote)
                        .foregroundStyle(BaseballTheme.textSecondary)
                    PrimaryPill(
                        title: copyResolver.resolve(AppCopyKey.setupQuickRebirthAction),
                        identifier: "hs.setup.quickRebirth"
                    ) {
                        career.startQuickRebirth(entryPoint: "quick_rebirth")
                    }
                    GameCopyText(AppCopyKey.setupQuickRebirthHint)
                        .font(.caption2)
                        .foregroundStyle(BaseballTheme.textTertiary)
                }
            }
        }
    }

    private var presets: [PitcherPresetSnapshot] { PitcherPresetCatalog.all }
    private var selectedPreset: PitcherPresetSnapshot? {
        presets.first { $0.id == selectedPresetID } ?? presets.first
    }
    /// 고교 회차 번호가 1이어도 direct Pro 은퇴 보너스가 있으면 이미 계승 자원을 가진
    /// 숙련 사용자다. 이 경우 상점을 숨기면 wallet-only로 분리한 프로 보상을 쓸 수 없다.
    private var isRebirth: Bool {
        career.inheritance.lifeNumber > 1
            || career.inheritance.soulPoints > 0
            || career.inheritance.automaticSoulTotal > 0
            || !career.inheritance.memories.isEmpty
            || career.inheritance.equippedSignatureLegacyID != nil
    }
    private var unlockedSignatureLegacies: [CareerSignatureLegacy] {
        (career.inheritance.unlockedSignatureLegacies ?? []).map { discovered in
            let definition = CareerSignatureLegacy.definition(for: discovered.id)
            return CareerSignatureLegacy(
                id: definition.id,
                family: definition.family,
                title: definition.title,
                detail: definition.detail,
                effect: definition.effect,
                evidence: discovered.evidence
            )
        }
    }
    private var selectedSignatureLegacy: CareerSignatureLegacy? {
        guard let id = selectedSignatureLegacyID ?? career.inheritance.equippedSignatureLegacyID else {
            return nil
        }
        return unlockedSignatureLegacies.first { $0.id == id }
            ?? CareerSignatureLegacy.definition(for: id)
    }

    /// 첫 회차에는 난이도·핸디캡 단계가 아예 없다.
    ///
    /// 처음 켠 사람은 **다음 회차가 뭔지 아직 모른다.** "고르면 다음 회차 계승이 커집니다"가
    /// 읽히려면 한 번 끝까지 가 보고 계승을 겪어야 한다. Rogue Legacy도 첫 죽음 전까지
    /// 특성을 보여 주지 않는다.
    private var steps: [Step] { isRebirth ? Step.allCases : [.name, .region, .style] }
    private var stepIndex: Int { steps.firstIndex(of: step) ?? 0 }
    private var isLastStep: Bool { stepIndex == steps.count - 1 }

    /// 카르마 보상 합계(‰). 자발적 핸디캡이 다음 회차 계승분을 키운다.
    private var rewardPermille: Int {
        selectedKarmas.reduce(0) { $0 + $1.rewardPermille }
    }

    /// 이름을 비워 둔 채로 넘어가면 이 이름으로 시작한다.
    private var suggestedName: String {
        guard let selectedPreset else { return copyResolver.resolve(AppCopyKey.setupNameDefault) }
        return copyResolver.resolve(selectedPreset.defaultPlayerNameCopyToken)
    }

    /// The field shows the localized system suggestion after the suggestion action, but that
    /// value must never cross into the stored player identity as user text.
    private var nameFieldBinding: Binding<String> {
        Binding(
            get: { isSystemSuggestedName ? suggestedName : playerName },
            set: { newValue in
                isSystemSuggestedName = false
                playerName = newValue
            }
        )
    }

    /// 입력에서 숫자와 하이픈만 남긴다. 카드 각인("도전 12345-4")을 스크린샷에서
    /// 그대로 옮겨 적어도 열려야 한다 — 접두어·공백에 파서가 까다로우면
    /// 바이럴 경로가 무반응 버튼에서 끝난다(5차 패널 P1).
    private var normalizedSeedInput: String {
        seedInput.filter { $0.isNumber || $0 == "-" }
    }

    /// "시드-회차" 토큰이면 challenge 모드다. 카드의 각인과 같은 형식이다.
    private var parsedChallenge: (seed: String, lifeNumber: Int)? {
        let parts = normalizedSeedInput.split(separator: "-")
        guard parts.count == 2, UInt64(parts[0]) != nil,
              let life = Int(parts[1]), (1...999).contains(life) else { return nil }
        return (String(parts[0]), life)
    }

    /// 시드 입력의 인라인 오류. 시작 버튼이 이 값으로 잠긴다 — 오타가 커널
    /// 오류 화면까지 가면 안 된다(4차 패널 P0).
    private var seedFieldError: String? {
        guard !seedInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        if UInt64(normalizedSeedInput) != nil || parsedChallenge != nil { return nil }
        return copyResolver.resolve(AppCopyKey.setupSeedError)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
                    // 원버튼 환생 — 반복 회차의 첫 마찰(설정 4단계)을 한 탭으로 접는다.
                    if step == .name {
                        quickRebirthCard
                    }
                    // 크로스페이드는 전환 중 두 단계의 한글이 겹쳐 보인다 — 첫 30초에
                    // "고장난 앱"으로 읽히는 P0(QA 문서). 밀어내기는 겹치지 않는다.
                    Group {
                        switch step {
                        case .name: nameStep
                        case .region: regionStep
                        case .style: styleStep
                        case .handicap: handicapStep
                        }
                    }
                    .id(step)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                }
                .padding(BaseballMetrics.gutter)
            }
            footer
        }
        .background(BaseballTheme.canvas)
        .scrollDismissesKeyboard(.interactively)
        .onAppear { GameAnalytics.logOnce(.onboardingStarted) }
        .onAppear {
            nameFocused = Self.shouldAutoFocusName(isRebirth: isRebirth)
            if selectedSignatureLegacyID == nil {
                selectedSignatureLegacyID = career.inheritance.equippedSignatureLegacyID
            }
        }
        .animation(.snappy, value: step)
    }

    // MARK: - 머리

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                GameCopyText(
                    isRebirth ? AppCopyKey.setupProgressRebirth : AppCopyKey.setupProgressFirst,
                    arguments: isRebirth
                        ? [.integer(career.inheritance.lifeNumber), .integer(stepIndex + 1), .integer(steps.count)]
                        : [.integer(stepIndex + 1), .integer(steps.count)]
                )
                    .eyebrowStyle(BaseballTheme.action)
                Spacer()
            }
            HStack(spacing: 4) {
                ForEach(steps, id: \.self) { item in
                    Capsule()
                        .fill(steps.firstIndex(of: item)! <= stepIndex
                              ? BaseballTheme.action : BaseballTheme.border)
                        .frame(height: 3)
                }
            }
            .accessibilityHidden(true)
        }
        .padding(.horizontal, BaseballMetrics.gutter)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(BaseballTheme.surface)
    }

    // MARK: - 1단계 이름

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            GameCopyText(isRebirth ? AppCopyKey.setupNameTitleRebirth : AppCopyKey.setupNameTitleFirst)
                .font(.title.bold())
                .foregroundStyle(BaseballTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

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
                    .font(.footnote.weight(.semibold))
                    .frame(minHeight: BaseballMetrics.minimumTapTarget)
            }
            .buttonStyle(.plain)
            .foregroundStyle(BaseballTheme.action)
            .accessibilityIdentifier("hs.setup.suggestName")

            // 시드로 시작 — 커뮤니티 도전("이 시드로 5회차 안에 지명?")의 입구.
            // 대부분은 안 쓰므로 눈에 띄지 않게 한 줄만.
            TextField(copyResolver.resolve(AppCopyKey.setupSeedPlaceholder), text: $seedInput)
                .font(.footnote.monospaced())
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numbersAndPunctuation)
                .accessibilityIdentifier("hs.setup.seed")
            if let error = seedFieldError {
                GameCopyText(verbatim: error)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(BaseballTheme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let challenge = parsedChallenge {
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

            if isRebirth, parsedChallenge == nil {
                inheritanceCard
            } else {
                // 입력칸 아래 화면 1/3이 빈 검정이었다(QA P2-11) — 이름을 정하는 순간에
                // 3년이 흐를 무대를 미리 보여 준다.
                Image(KeyArt.stadiumNight.rawValue)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 170)
                    .clipShape(RoundedRectangle(cornerRadius: BaseballMetrics.cardRadius))
                    .overlay(alignment: .bottomLeading) {
                        GameCopyText(AppCopyKey.setupStadiumCaption)
                            .font(.caption)
                            .foregroundStyle(BaseballTheme.textSecondary)
                            .padding(10)
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
                            .integer(HighSchoolCareerEngine.appliedInheritance(
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
                    if let step = HighSchoolCareerEngine.nextInheritanceStep(
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
                            .font(.footnote)
                            .foregroundStyle(BaseballTheme.textSecondary)
                    } else if !career.inheritance.memories.isEmpty {
                        ForEach(career.inheritance.memories, id: \.self) { memory in
                            let copy = HighSchoolConclusionPresentation.localizedMemory(
                                memory,
                                resolver: copyResolver
                            )
                            HStack(spacing: 8) {
                                ArtThumb(assetName: "MemoryArt-\(memory.rawValue)", size: 34, cornerRadius: 7)
                                GameCopyText(verbatim: copy.title)
                                    .font(.footnote)
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
                            .font(.footnote.weight(.bold))
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
                GameCopyText(AppCopyKey.setupInheritanceShopDescription)
                    .font(.footnote)
                    .foregroundStyle(BaseballTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
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
                                .font(.footnote.weight(.bold).monospacedDigit())
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

    // MARK: - 2단계 지역

    /// 어느 지역에서 시작하는가. 지역이 학교 네 곳의 이름을 정한다 — 감독·포수·훈련 색은
    /// 학교 유형에 붙어 있으므로, 지역은 "누구와 3년을 보내는가"가 아니라 "어느 이름의
    /// 교정에서 그 3년이 흘러가는가"를 정한다. 회차마다 다른 지역을 고르면 다른 학교
    /// 이름들이 아카이브에 쌓인다.
    private var regionStep: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            GameCopyText(AppCopyKey.setupRegionTitle)
                .font(.title.bold())
                .foregroundStyle(BaseballTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            GameCopyText(AppCopyKey.setupRegionDescription)
                .font(.subheadline)
                .foregroundStyle(BaseballTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            // 아무 정보 없는 16개 버튼은 "고민할 가치 없는 고민"이다(QA P1-14) —
            // 그러면 이후의 진짜 선택(학교·각성)도 장식으로 학습된다. 한 줄의 성격이
            // 선택의 근거를 만든다. 표시 전용이라 밸런스에는 손대지 않는다.
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                ForEach(HighSchoolCareerEngine.regions, id: \.self) { region in
                    Button {
                        selectedRegion = region
                    } label: {
                        VStack(spacing: 2) {
                            GameCopyText(Self.regionNameKey(for: region))
                                .font(.subheadline.weight(.semibold))
                            GameCopyText(Self.regionFlavorKey(for: region))
                                .font(.caption2)
                                .foregroundStyle(BaseballTheme.textTertiary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, minHeight: BaseballMetrics.minimumTapTarget + 8)
                    }
                    .buttonStyle(.plain)
                    .background(
                        selectedRegion == region ? BaseballTheme.selection.opacity(0.2) : BaseballTheme.surface,
                        in: RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                            .stroke(selectedRegion == region ? BaseballTheme.selection : BaseballTheme.border.opacity(0.6),
                                    lineWidth: selectedRegion == region ? 2 : 1)
                    }
                    .accessibilityAddTraits(selectedRegion == region ? .isSelected : [])
                    .accessibilityIdentifier("hs.setup.region.\(region)")
                }
            }
        }
    }

    // MARK: - 3단계 투수 유형

    private var styleStep: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            GameCopyText(AppCopyKey.setupStyleTitle)
                .font(.title.bold())
                .foregroundStyle(BaseballTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            GameCopyText(AppCopyKey.setupStyleDescription)
                .font(.subheadline)
                .foregroundStyle(BaseballTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(presets, id: \.id) { preset in
                PresetRow(preset: preset, selected: preset.id == selectedPresetID) {
                    selectedPresetID = preset.id
                }
            }
        }
    }

    // MARK: - 4단계 난이도·핸디캡 (2회차부터)

    private var handicapStep: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            GameCopyText(AppCopyKey.setupHandicapTitle)
                .font(.title.bold())
                .foregroundStyle(BaseballTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            BaseballCard(title: copyResolver.resolve(AppCopyKey.setupDifficultyTitle)) {
                HStack(spacing: 6) {
                    ForEach(DifficultyLevel.allCases, id: \.self) { level in
                        Button { harshness = level } label: {
                            GameCopyText(Self.difficultyKey(level))
                                .font(.footnote.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: BaseballMetrics.minimumTapTarget)
                        }
                        .buttonStyle(.plain)
                        .background(
                            harshness == level ? BaseballTheme.selection.opacity(0.2) : BaseballTheme.surfaceRaised,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(harshness == level ? BaseballTheme.selection : BaseballTheme.border.opacity(0.6),
                                        lineWidth: harshness == level ? 2 : 1)
                        }
                        .accessibilityAddTraits(harshness == level ? .isSelected : [])
                        .accessibilityIdentifier("hs.setup.harshness.\(level.rawValue)")
                    }
                }
            }

            if parsedChallenge != nil {
                BaseballCard(title: copyResolver.resolve(AppCopyKey.setupChallengeTitle), tone: .milestone) {
                    GameCopyText(AppCopyKey.setupChallengeDescription)
                        .font(.footnote)
                        .foregroundStyle(BaseballTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if parsedChallenge == nil, !unlockedSignatureLegacies.isEmpty {
                BaseballCard(title: copyResolver.resolve(AppCopyKey.setupLegacyTitle), tone: .milestone) {
                    VStack(alignment: .leading, spacing: 8) {
                        GameCopyText(AppCopyKey.setupLegacyDescription)
                            .font(.footnote)
                            .foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        ForEach(unlockedSignatureLegacies) { legacy in
                            let selected = (selectedSignatureLegacyID
                                            ?? career.inheritance.equippedSignatureLegacyID) == legacy.id
                            let mastery = HighSchoolCareerStore.lineageMasteries(from: career.archive)
                                .first { $0.family == legacy.family }
                                ?? CareerLineageMastery(family: legacy.family, contributions: 0)
                            Button { selectedSignatureLegacyID = legacy.id } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: selected ? "checkmark.seal.fill" : "seal")
                                        .foregroundStyle(selected ? BaseballTheme.milestone : BaseballTheme.textTertiary)
                                    VStack(alignment: .leading, spacing: 3) {
                                        GameCopyText(verbatim: legacy.title)
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(BaseballTheme.textPrimary)
                                        GameCopyText(verbatim: legacy.detail)
                                            .font(.caption)
                                            .foregroundStyle(BaseballTheme.textSecondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                        GameCopyText(verbatim: Self.localizedSignatureLegacyEffectLine(legacy.effect, resolver: copyResolver))
                                            .font(.caption2.weight(.semibold).monospacedDigit())
                                            .foregroundStyle(BaseballTheme.milestone)
                                        Text(verbatim: copyResolver.resolve(
                                            LegacyUICopyKey.masteryRank,
                                            arguments: [.integer(mastery.rank), .integer(mastery.contributions)]
                                        ))
                                        .font(.caption2.weight(.bold).monospacedDigit())
                                        .foregroundStyle(BaseballTheme.information)
                                        if let threshold = mastery.nextThreshold {
                                            Text(verbatim: copyResolver.resolve(
                                                LegacyUICopyKey.masteryNext,
                                                arguments: [
                                                    .integer(max(0, threshold - mastery.contributions)),
                                                    .integer(mastery.rank + 1),
                                                ]
                                            ))
                                            .font(.caption2)
                                            .foregroundStyle(BaseballTheme.textTertiary)
                                        } else {
                                            Text(verbatim: copyResolver.resolve(LegacyUICopyKey.masteryMax))
                                                .font(.caption2)
                                                .foregroundStyle(BaseballTheme.textTertiary)
                                        }
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(selected ? BaseballTheme.milestone.opacity(0.12) : BaseballTheme.surfaceRaised,
                                            in: RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius))
                                .overlay {
                                    RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                                        .stroke(selected ? BaseballTheme.milestone : BaseballTheme.border,
                                                lineWidth: selected ? 2 : 1)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(selected ? .isSelected : [])
                            .accessibilityIdentifier("hs.setup.signatureLegacy.\(legacy.id.rawValue)")
                        }
                    }
                }
            }

            // 야구혼을 어디에 붓는지 고른다. 코어는 처음부터 이 값을 받았는데 화면이
            // 넘기지 않아 늘 기본값(제구)으로 갔다 — 회차마다 같은 곳만 오르는 원인 하나였다.
            if Self.showsSoulDomain(
                automaticSoulTotal: career.inheritance.automaticSoulTotal,
                isChallenge: parsedChallenge != nil
            ) {
                BaseballCard(
                    title: copyResolver.resolve(
                        AppCopyKey.setupSoulDomainTitle,
                        arguments: [.integer(career.inheritance.automaticSoulTotal)]
                    )
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            ForEach(SoulDomain.allCases, id: \.self) { domain in
                                Button { soulDomain = domain } label: {
                                    GameCopyText(Self.domainKey(domain))
                                        .font(.footnote.weight(.semibold))
                                        .frame(maxWidth: .infinity, minHeight: BaseballMetrics.minimumTapTarget)
                                }
                                .buttonStyle(.plain)
                                .background(
                                    soulDomain == domain ? BaseballTheme.selection.opacity(0.2) : BaseballTheme.surfaceRaised,
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(soulDomain == domain ? BaseballTheme.selection : BaseballTheme.border.opacity(0.6),
                                                lineWidth: soulDomain == domain ? 2 : 1)
                                }
                                .accessibilityAddTraits(soulDomain == domain ? .isSelected : [])
                            }
                        }
                        GameCopyText(Self.domainDetailKey(soulDomain))
                            .font(.caption)
                            .foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        GameCopyText(AppCopyKey.setupSoulDomainRule)
                            .font(.caption)
                            .foregroundStyle(BaseballTheme.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if parsedChallenge == nil {
                GameCopyText(AppCopyKey.setupHandicapLabel)
                    .font(.headline)
                GameCopyText(
                    AppCopyKey.setupHandicapDescription,
                    arguments: [.integer(rewardPermille / 10)]
                )
                    .font(.footnote)
                    .foregroundStyle(rewardPermille > 0 ? BaseballTheme.milestone : BaseballTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(KarmaID.allCases, id: \.self) { karma in
                    // 코어가 카르마를 2개까지만 받는다(HighSchoolCareerEngine.start). 3개를 보내면
                    // 커리어 생성이 실패하고, 그 화면의 유일한 버튼이 진행 삭제다 — 여기서 막는다.
                    KarmaRow(
                        karma: karma,
                        selected: selectedKarmas.contains(karma),
                        atCapacity: selectedKarmas.count >= 2,
                        onToggle: {
                            if selectedKarmas.contains(karma) { selectedKarmas.remove(karma) }
                            else if selectedKarmas.count < 2 { selectedKarmas.insert(karma) }
                        }
                    )
                }
            }
        }
    }

    // MARK: - 발

    private var footer: some View {
        VStack(spacing: 8) {
            if isLastStep, let error = seedFieldError {
                GameCopyText(
                    AppCopyKey.setupSeedValidation,
                    arguments: [.userText(error)]
                )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BaseballTheme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if isLastStep {
                PrimaryButton(title: copyResolver.resolve(startCopyKey), identifier: "hs.start") {
                    nameFocused = false
                    guard let selectedPreset, seedFieldError == nil else { return }
                    let isChallenge = parsedChallenge != nil
                    career.startCareer(
                        preset: selectedPreset,
                        playerName: Self.submittedPlayerName(
                            playerName,
                            isSystemSuggestion: isSystemSuggestedName
                        ),
                        region: selectedRegion,
                        difficulty: CareerDifficultySnapshot(careerHarshness: harshness),
                        karmas: isChallenge ? [] : Array(selectedKarmas).sorted { $0.rawValue < $1.rawValue },
                        soulDomain: Self.showsSoulDomain(
                            automaticSoulTotal: career.inheritance.automaticSoulTotal,
                            isChallenge: isChallenge
                        ) ? soulDomain : nil,
                        soulBoosts: isChallenge ? [] : Array(selectedBoosts).sorted { $0.rawValue < $1.rawValue },
                        signatureLegacyID: isChallenge ? nil : (selectedSignatureLegacyID
                            ?? career.inheritance.equippedSignatureLegacyID),
                        seedOverride: parsedChallenge?.seed ?? (normalizedSeedInput.isEmpty ? nil : normalizedSeedInput),
                        challengeLifeNumber: parsedChallenge?.lifeNumber
                    )
                }
                .disabled(seedFieldError != nil)
                .opacity(seedFieldError != nil ? 0.5 : 1)
            } else {
                PrimaryButton(title: copyResolver.resolve(AppCopyKey.setupActionNext), identifier: "hs.setup.next") { advance() }
            }

            if stepIndex > 0 {
                Button(copyResolver.resolve(AppCopyKey.setupActionBack)) { back() }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(BaseballTheme.textSecondary)
                    .frame(minHeight: BaseballMetrics.minimumTapTarget)
                    .accessibilityIdentifier("hs.setup.back")
            }
        }
        .padding(BaseballMetrics.gutter)
        .safeAreaPadding(.bottom, 4)
        .background(BaseballTheme.surface)
    }

    private var startCopyKey: GameCopyKey {
        if parsedChallenge != nil { return AppCopyKey.setupStartChallenge }
        if isRebirth { return AppCopyKey.setupStartRebirth }
        return AppCopyKey.setupStartFirst
    }

    private func advance() {
        nameFocused = false
        guard stepIndex + 1 < steps.count else { return }
        step = steps[stepIndex + 1]
    }

    private func back() {
        nameFocused = false
        guard stepIndex > 0 else { return }
        step = steps[stepIndex - 1]
    }

    private static let koreanResolver = GameCopyResolver(language: .korean, policy: .releaseSafe)

    private static func regionKey(
        for region: String,
        keys: [GameCopyKey]
    ) -> GameCopyKey {
        guard let index = HighSchoolCareerEngine.regions.firstIndex(of: region), keys.indices.contains(index) else {
            return .errorTextUnavailable
        }
        return keys[index]
    }

    private static func regionNameKey(for region: String) -> GameCopyKey {
        regionKey(for: region, keys: regionNameKeys)
    }

    private static func regionFlavorKey(for region: String) -> GameCopyKey {
        regionKey(for: region, keys: regionFlavorKeys)
    }

    static func localizedRegionName(_ region: String, resolver: GameCopyResolver) -> String {
        resolver.resolve(regionNameKey(for: region))
    }

    /// A blank LastSetup name means the engine's preset-provided default, not user text. Resolve
    /// that default through the preset's semantic token; every nonempty value remains verbatim.
    nonisolated static func localizedQuickRebirthPlayerName(
        _ storedPlayerName: String,
        preset: PitcherPresetSnapshot,
        resolver: GameCopyResolver
    ) -> String {
        storedPlayerName.isEmpty
            ? resolver.resolve(preset.defaultPlayerNameCopyToken)
            : storedPlayerName
    }

    /// Convert UI-only name mode into the exact value accepted by the career engine. A system
    /// suggestion is only a localized presentation; user text, including an empty string or a
    /// string equal to the suggestion, remains byte-for-byte unchanged.
    nonisolated static func submittedPlayerName(
        _ playerName: String,
        isSystemSuggestion: Bool
    ) -> String {
        isSystemSuggestion ? "" : playerName
    }

    static func localizedDomainLabel(_ domain: SoulDomain, resolver: GameCopyResolver) -> String {
        resolver.resolve(domainKey(domain))
    }

    static func localizedDomainDetail(_ domain: SoulDomain, resolver: GameCopyResolver) -> String {
        resolver.resolve(domainDetailKey(domain))
    }

    static func domainLabel(_ domain: SoulDomain) -> String {
        localizedDomainLabel(domain, resolver: koreanResolver)
    }

    static func domainDetail(_ domain: SoulDomain) -> String {
        localizedDomainDetail(domain, resolver: koreanResolver)
    }

    static func signatureLegacyEffectLine(_ effect: CareerSignatureLegacyEffect) -> String {
        localizedSignatureLegacyEffectLine(effect, resolver: koreanResolver)
    }

    static func localizedSignatureLegacyEffectLine(
        _ effect: CareerSignatureLegacyEffect,
        resolver: GameCopyResolver
    ) -> String {
        let copy = signatureLegacyEffectCopy(effect)
        return resolver.resolve(copy.key, arguments: copy.arguments)
    }

    private static func signatureLegacyEffectCopy(
        _ effect: CareerSignatureLegacyEffect
    ) -> (key: GameCopyKey, arguments: [LocalizedCopyArgument]) {
        let hasStuff = effect.stuff != 0
        let hasCommand = effect.command != 0
        let hasMovement = effect.movement != 0
        let hasStamina = effect.stamina != 0

        return switch (hasStuff, hasCommand, hasMovement, hasStamina) {
        case (false, false, false, false):
            (AppCopyKey.setupSignatureEffectNone, [])
        case (true, false, false, false):
            (AppCopyKey.setupSignatureEffectStuff, [.integer(effect.stuff)])
        case (false, true, false, false):
            (AppCopyKey.setupSignatureEffectCommand, [.integer(effect.command)])
        case (false, false, true, false):
            (AppCopyKey.setupSignatureEffectMovement, [.integer(effect.movement)])
        case (false, false, false, true):
            (AppCopyKey.setupSignatureEffectStamina, [.integer(effect.stamina)])
        case (true, true, false, false):
            (AppCopyKey.setupSignatureEffectStuffCommand, [.integer(effect.stuff), .integer(effect.command)])
        case (true, false, true, false):
            (AppCopyKey.setupSignatureEffectStuffMovement, [.integer(effect.stuff), .integer(effect.movement)])
        case (true, false, false, true):
            (AppCopyKey.setupSignatureEffectStuffStamina, [.integer(effect.stuff), .integer(effect.stamina)])
        case (false, true, true, false):
            (AppCopyKey.setupSignatureEffectCommandMovement, [.integer(effect.command), .integer(effect.movement)])
        case (false, true, false, true):
            (AppCopyKey.setupSignatureEffectCommandStamina, [.integer(effect.command), .integer(effect.stamina)])
        case (false, false, true, true):
            (AppCopyKey.setupSignatureEffectMovementStamina, [.integer(effect.movement), .integer(effect.stamina)])
        case (true, true, true, false):
            (
                AppCopyKey.setupSignatureEffectStuffCommandMovement,
                [.integer(effect.stuff), .integer(effect.command), .integer(effect.movement)]
            )
        case (true, true, false, true):
            (
                AppCopyKey.setupSignatureEffectStuffCommandStamina,
                [.integer(effect.stuff), .integer(effect.command), .integer(effect.stamina)]
            )
        case (true, false, true, true):
            (
                AppCopyKey.setupSignatureEffectStuffMovementStamina,
                [.integer(effect.stuff), .integer(effect.movement), .integer(effect.stamina)]
            )
        case (false, true, true, true):
            (
                AppCopyKey.setupSignatureEffectCommandMovementStamina,
                [.integer(effect.command), .integer(effect.movement), .integer(effect.stamina)]
            )
        case (true, true, true, true):
            (
                AppCopyKey.setupSignatureEffectAll,
                [.integer(effect.stuff), .integer(effect.command), .integer(effect.movement), .integer(effect.stamina)]
            )
        }
    }

    static func localizedDifficultyLabel(_ level: DifficultyLevel, resolver: GameCopyResolver) -> String {
        resolver.resolve(difficultyKey(level))
    }

    static func difficultyLabel(_ level: DifficultyLevel) -> String {
        localizedDifficultyLabel(level, resolver: koreanResolver)
    }

    private static func domainKey(_ domain: SoulDomain) -> GameCopyKey {
        switch domain {
        case .body: AppCopyKey.setupSoulDomainBody
        case .technique: AppCopyKey.setupSoulDomainTechnique
        case .game: AppCopyKey.setupSoulDomainGame
        }
    }

    private static func domainDetailKey(_ domain: SoulDomain) -> GameCopyKey {
        switch domain {
        case .body: AppCopyKey.setupSoulDomainBodyDetail
        case .technique: AppCopyKey.setupSoulDomainTechniqueDetail
        case .game: AppCopyKey.setupSoulDomainGameDetail
        }
    }

    private static func difficultyKey(_ level: DifficultyLevel) -> GameCopyKey {
        switch level {
        case .relaxed: AppCopyKey.setupDifficultyRelaxed
        case .standard: AppCopyKey.setupDifficultyStandard
        case .challenging: AppCopyKey.setupDifficultyChallenging
        }
    }

    static func localizedKarmaCopy(
        _ karma: KarmaID,
        resolver: GameCopyResolver
    ) -> (title: String, detail: String) {
        let keys: (title: GameCopyKey, detail: GameCopyKey) = switch karma {
        case .unknownLand: (AppCopyKey.setupKarmaUnknownLandTitle, AppCopyKey.setupKarmaUnknownLandDetail)
        case .stubbornCoach: (AppCopyKey.setupKarmaStubbornCoachTitle, AppCopyKey.setupKarmaStubbornCoachDetail)
        case .singleWeapon: (AppCopyKey.setupKarmaSingleWeaponTitle, AppCopyKey.setupKarmaSingleWeaponDetail)
        case .geniusGeneration: (AppCopyKey.setupKarmaGeniusGenerationTitle, AppCopyKey.setupKarmaGeniusGenerationDetail)
        case .erasedMemory: (AppCopyKey.setupKarmaErasedMemoryTitle, AppCopyKey.setupKarmaErasedMemoryDetail)
        case .noLastChance: (AppCopyKey.setupKarmaNoLastChanceTitle, AppCopyKey.setupKarmaNoLastChanceDetail)
        }
        return (resolver.resolve(keys.title), resolver.resolve(keys.detail))
    }
}

private struct PresetRow: View {
    let preset: PitcherPresetSnapshot
    let selected: Bool
    let onSelect: () -> Void

    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                // 스타일 아트 — 3년을 함께할 몸을 고르는 화면이 표(스탯)로만 말하면
                // 첫인상 구간을 통째로 버리는 것이다. 이미지가 없으면 지금 그대로.
                if UIImage(named: "PresetArt-\(preset.id)") != nil {
                    // 가운데 크롭은 와인드업의 머리를 잘랐다(실기기 피드백) —
                    // 위 정렬 밴드로 인물의 상단을 지킨다.
                    Image("PresetArt-\(preset.id)")
                        .resizable()
                        .scaledToFill()
                        .frame(height: 150, alignment: .top)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                HStack(spacing: 10) {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? BaseballTheme.selection : BaseballTheme.textSecondary)
                    VStack(alignment: .leading, spacing: 2) {
                        GameCopyText(coreToken: preset.nameCopyToken).font(.headline)
                        GameCopyText(coreToken: preset.taglineCopyToken)
                            .font(.subheadline)
                            .foregroundStyle(BaseballTheme.textSecondary)
                    }
                    Spacer()
                }
                AbilityGaugeView(
                    label: copyResolver.resolve(AppCopyKey.setupStatStuff),
                    value: preset.pitcher.stuff,
                    showsMeaning: false
                )
                AbilityGaugeView(
                    label: copyResolver.resolve(AppCopyKey.setupStatCommand),
                    value: preset.pitcher.command,
                    showsMeaning: false
                )
                AbilityGaugeView(
                    label: copyResolver.resolve(AppCopyKey.setupStatMovement),
                    value: preset.pitcher.movement,
                    showsMeaning: false
                )
                AbilityGaugeView(
                    label: copyResolver.resolve(AppCopyKey.setupStatStamina),
                    value: preset.pitcher.stamina,
                    showsMeaning: false
                )
                Label {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        ForEach(Array(preset.strengthCopyTokens.enumerated()), id: \.offset) { index, token in
                            if index > 0 {
                                Text(verbatim: "·")
                                    .foregroundStyle(BaseballTheme.textTertiary)
                            }
                            GameCopyText(coreToken: token)
                        }
                    }
                } icon: {
                    Image(systemName: "sparkles")
                }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(BaseballTheme.positive)
                    .fixedSize(horizontal: false, vertical: true)
                Label {
                    GameCopyText(coreToken: preset.tradeoffCopyToken)
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                }
                    .font(.footnote)
                    .foregroundStyle(BaseballTheme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(BaseballMetrics.gutter)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                selected ? BaseballTheme.selection.opacity(0.12) : BaseballTheme.surface,
                in: RoundedRectangle(cornerRadius: BaseballMetrics.cardRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: BaseballMetrics.cardRadius)
                    .stroke(selected ? BaseballTheme.selection : BaseballTheme.border, lineWidth: selected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("hs.preset.\(preset.id)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct KarmaRow: View {
    let karma: KarmaID
    let selected: Bool
    /// 이미 2개를 골랐는가. 선택된 행은 계속 눌러서 해제할 수 있어야 하므로 별도로 받는다.
    var atCapacity: Bool = false
    let onToggle: () -> Void

    @Environment(\.gameCopyResolver) private var copyResolver

    private var locked: Bool { atCapacity && !selected }

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: selected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(selected ? BaseballTheme.warning : BaseballTheme.border.opacity(locked ? 0.4 : 1))
                VStack(alignment: .leading, spacing: 2) {
                    let copy = HighSchoolSetupView.localizedKarmaCopy(karma, resolver: copyResolver)
                    GameCopyText(verbatim: copy.title).font(.subheadline.weight(.bold))
                    GameCopyText(verbatim: copy.detail)
                        .font(.footnote)
                        .foregroundStyle(BaseballTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                GameCopyText(
                    AppCopyKey.setupKarmaReward,
                    arguments: [.integer(karma.rewardPermille / 10)]
                )
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(BaseballTheme.milestone)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                selected ? BaseballTheme.warning.opacity(0.12) : BaseballTheme.surface,
                in: RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                    .stroke(selected ? BaseballTheme.warning : BaseballTheme.border, lineWidth: selected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .opacity(locked ? 0.45 : 1)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint(locked ? copyResolver.resolve(AppCopyKey.setupKarmaCapacityHint) : "")
    }
}
