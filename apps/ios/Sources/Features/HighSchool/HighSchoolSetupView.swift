import SwiftUI
import SimulationCore
import BaseballIOSDomain

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
    @Binding var pendingChallenge: ChallengeLink.Pending?

    @Environment(\.gameCopyResolver) var copyResolver

    /// These arrays follow the engine's stable region order. The stored region IDs remain the
    /// Korean-world identifiers used by simulation and persistence; only their display copy is
    /// localized here.
    static let regionNameKeys: [GameCopyKey] = [
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

    static let regionFlavorKeys: [GameCopyKey] = [
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
    enum Step: Int, CaseIterable {
        case name, region, style, repertoire, handicap
    }

    @State var step: Step = .name
    @State var playerName = ""
    /// A localized system suggestion is display-only. Keep it separate from user text so the
    /// save/presentation boundary can still submit an empty name and let the engine choose the
    /// preset's language-neutral default.
    @State var isSystemSuggestedName = false
    @State var selectedRegion = HighSchoolCareerStore.regions.first ?? ""
    /// 지역 단계의 권역 탭. 도시가 바뀌면 그 도시의 권역으로 따라간다.
    @State var selectedRegionGroup = HighSchoolSetupView.regionGroupID(
        containing: HighSchoolCareerStore.regions.first ?? ""
    )
    @State var selectedPresetID = PitcherPresetCatalog.all.first?.id ?? ""
    /// 주인공의 투구 손. 커널의 플래툰 판정이 실제로 읽는 값이라 표기 이상의 선택이다.
    @State var throwingHand: ThrowingHand = .right
    @State var learningPitch = CareerDisplayRules.recommendedRepertoire(
        presetID: PitcherPresetCatalog.all.first?.id ?? ""
    ).learningPitch
    @State var primaryPitch = CareerDisplayRules.recommendedRepertoire(
        presetID: PitcherPresetCatalog.all.first?.id ?? ""
    ).primaryPitch
    @State var selectedKarmas: Set<KarmaID> = []
    /// 계승한 야구혼을 어디에 붓는가. 2회차부터만 고른다.
    @State var soulDomain: SoulDomain = .technique
    /// 영혼 상점에서 담은 부스트. 잔액 안에서만 담긴다.
    @State var selectedBoosts: Set<SoulBoostID> = []
    /// 발견한 대표 유산 중 이번 선수에게 직접 이어 줄 한 자리.
    @State var selectedSignatureLegacyID: CareerSignatureLegacyID?
    /// 공유받은 시드로 시작하기. 비우면 랜덤.
    @State var seedInput = ""

    @State var harshness: DifficultyLevel = .standard
    @FocusState var nameFocused: Bool

    /// The first screen must remain readable before the player explicitly taps the field.
    static func shouldAutoFocusName(isRebirth: Bool) -> Bool {
        _ = isRebirth
        return false
    }

    /// 원버튼 환생 — 지난 회차와 같은 설정(이름·지역·유형·난이도·카르마)으로 즉시 시작.
    /// 부스트는 회차마다 다시 고르는 소비라 싣지 않는다.
    @ViewBuilder var quickRebirthCard: some View {
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
                        .detailStyle()
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

    var presets: [PitcherPresetSnapshot] { PitcherPresetCatalog.all }
    var selectedPreset: PitcherPresetSnapshot? {
        presets.first { $0.id == selectedPresetID } ?? presets.first
    }
    var startingRepertoire: StartingRepertoireSelection {
        let ready = [PitchType.slider, .curveball, .changeup].filter { $0 != learningPitch }
        return StartingRepertoireSelection(
            readyBreakingPitches: ready,
            primaryPitch: ready.contains(primaryPitch) || primaryPitch == .fourSeam
                ? primaryPitch : .fourSeam,
            learningPitch: learningPitch
        )
    }
    /// 고교 회차 번호가 1이어도 direct Pro 은퇴 보너스가 있으면 이미 계승 자원을 가진
    /// 숙련 사용자다. 이 경우 상점을 숨기면 wallet-only로 분리한 프로 보상을 쓸 수 없다.
    var isRebirth: Bool {
        career.inheritance.lifeNumber > 1
            || career.inheritance.soulPoints > 0
            || career.inheritance.automaticSoulTotal > 0
            || !career.inheritance.memories.isEmpty
            || career.inheritance.equippedSignatureLegacyID != nil
    }
    var unlockedSignatureLegacies: [CareerSignatureLegacy] {
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
    var selectedSignatureLegacy: CareerSignatureLegacy? {
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
    var steps: [Step] { isRebirth ? Step.allCases : [.name, .region, .style, .repertoire] }
    var stepIndex: Int { steps.firstIndex(of: step) ?? 0 }
    var isLastStep: Bool { stepIndex == steps.count - 1 }

    /// 카르마 보상 합계(‰). 자발적 핸디캡이 다음 회차 계승분을 키운다.
    var rewardPermille: Int {
        selectedKarmas.reduce(0) { $0 + $1.rewardPermille }
    }

    /// 이름을 비워 둔 채로 넘어가면 이 이름으로 시작한다.
    var suggestedName: String {
        guard let selectedPreset else { return copyResolver.resolve(AppCopyKey.setupNameDefault) }
        return copyResolver.resolve(selectedPreset.defaultPlayerNameCopyToken)
    }

    /// The field shows the localized system suggestion after the suggestion action, but that
    /// value must never cross into the stored player identity as user text.
    var nameFieldBinding: Binding<String> {
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
    var normalizedSeedInput: String {
        seedInput.filter { $0.isNumber || $0 == "-" }
    }

    /// "시드-회차" 토큰이면 challenge 모드다. 카드의 각인과 같은 형식이다.
    var parsedChallenge: (seed: String, lifeNumber: Int)? {
        guard let parsed = ChallengeLink.parseToken(normalizedSeedInput) else { return nil }
        return (parsed.seed, parsed.life)
    }

    var shareableChallenge: (seed: String, life: Int)? {
        if let challenge = parsedChallenge { return (challenge.seed, challenge.lifeNumber) }
        guard UInt64(normalizedSeedInput) != nil else { return nil }
        return (normalizedSeedInput, career.inheritance.lifeNumber)
    }

    /// 시드 입력의 인라인 오류. 시작 버튼이 이 값으로 잠긴다 — 오타가 커널
    /// 오류 화면까지 가면 안 된다(4차 패널 P0).
    var seedFieldError: String? {
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
                        case .repertoire: repertoireStep
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
            // 단계가 바뀌어도 이전 단계의 스크롤 위치가 남아 새 단계 제목이 머리 밑으로
            // 들어갔다(페르소나 플레이테스트 05-setup-repertoire). 단계마다 새 스크롤뷰로 시작한다.
            .id("setup-step-\(step)")
            footer
        }
        .background(BaseballTheme.canvas)
        .scrollDismissesKeyboard(.interactively)
        .onAppear { CareerTelemetry.logOnce(.onboardingStarted) }
        .onAppear {
            applyPendingChallenge()
            nameFocused = Self.shouldAutoFocusName(isRebirth: isRebirth)
            if isRebirth,
               let last = career.lastSetup,
               let previousRepertoire = last.startingRepertoire,
               presets.contains(where: { $0.id == last.presetID }) {
                selectedPresetID = last.presetID
                learningPitch = previousRepertoire.learningPitch
                primaryPitch = previousRepertoire.primaryPitch
            }
            if selectedSignatureLegacyID == nil {
                selectedSignatureLegacyID = career.inheritance.equippedSignatureLegacyID
            }
        }
        .animation(.snappy, value: step)
        .onChange(of: pendingChallenge) { _, _ in
            applyPendingChallenge()
        }
    }

    func applyPendingChallenge() {
        guard let pending = pendingChallenge else { return }
        seedInput = ChallengeLinkSession.seedInput(from: pending)
    }

    // MARK: - 머리

    var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                // '뒤로'는 '다음' 캡슐 바로 아래 10pt에 있어서 '다음'을 노린 탭이 '뒤로'로
                // 들어갔다(실주행에서 재현). 되돌리는 행동은 머리 왼쪽 관례 자리로 옮긴다.
                if stepIndex > 0 {
                    Button { back() } label: {
                        Label(copyResolver.resolve(AppCopyKey.setupActionBack), systemImage: "chevron.left")
                            .font(BaseballType.detail.weight(.semibold))
                            .foregroundStyle(BaseballTheme.textSecondary)
                            .frame(minHeight: BaseballMetrics.minimumTapTarget - 12)
                    }
                    .accessibilityIdentifier("hs.setup.back")
                }
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

    // MARK: - 발

    var footer: some View {
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
                    pendingChallenge = ChallengeLinkSession.consumePendingOnCareerStart(
                        pending: pendingChallenge
                    )
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
                        startingRepertoire: startingRepertoire,
                        throwingHand: throwingHand,
                        seedOverride: parsedChallenge?.seed ?? (normalizedSeedInput.isEmpty ? nil : normalizedSeedInput),
                        challengeLifeNumber: parsedChallenge?.lifeNumber
                    )
                }
                .disabled(seedFieldError != nil)
                .opacity(seedFieldError != nil ? 0.5 : 1)
            } else {
                PrimaryButton(title: copyResolver.resolve(AppCopyKey.setupActionNext), identifier: "hs.setup.next") { advance() }
            }

        }
        .padding(BaseballMetrics.gutter)
        .safeAreaPadding(.bottom, 4)
        .background(BaseballTheme.surface)
    }

    var startCopyKey: GameCopyKey {
        if parsedChallenge != nil { return AppCopyKey.setupStartChallenge }
        if isRebirth { return AppCopyKey.setupStartRebirth }
        return AppCopyKey.setupStartFirst
    }

    func advance() {
        nameFocused = false
        guard stepIndex + 1 < steps.count else { return }
        step = steps[stepIndex + 1]
    }

    func back() {
        nameFocused = false
        guard stepIndex > 0 else { return }
        step = steps[stepIndex - 1]
    }

    static let koreanResolver = GameCopyResolver(language: .korean, policy: .releaseSafe)

    static func regionKey(
        for region: String,
        keys: [GameCopyKey]
    ) -> GameCopyKey {
        guard let index = HighSchoolCareerStore.regions.firstIndex(of: region), keys.indices.contains(index) else {
            return .errorTextUnavailable
        }
        return keys[index]
    }

    static func regionNameKey(for region: String) -> GameCopyKey {
        regionKey(for: region, keys: regionNameKeys)
    }

    static func regionFlavorKey(for region: String) -> GameCopyKey {
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

    static func signatureLegacyEffectCopy(
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

    static func domainKey(_ domain: SoulDomain) -> GameCopyKey {
        switch domain {
        case .body: AppCopyKey.setupSoulDomainBody
        case .technique: AppCopyKey.setupSoulDomainTechnique
        case .game: AppCopyKey.setupSoulDomainGame
        }
    }

    static func domainDetailKey(_ domain: SoulDomain) -> GameCopyKey {
        switch domain {
        case .body: AppCopyKey.setupSoulDomainBodyDetail
        case .technique: AppCopyKey.setupSoulDomainTechniqueDetail
        case .game: AppCopyKey.setupSoulDomainGameDetail
        }
    }

    static func difficultyKey(_ level: DifficultyLevel) -> GameCopyKey {
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
