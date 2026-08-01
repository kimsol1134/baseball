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
    /// 지역의 한 줄 성격. 실제 지역 야구 문화의 인상을 빌린 가상 묘사다.
    static let regionFlavor: [String: String] = [
        "서울": "스카우트가 가장 자주 오는 무대",
        "인천": "바닷바람 속 끈질긴 야구",
        "수원": "신흥 명문들의 각축전",
        "대전": "뚝심의 원포인트 승부",
        "광주": "타격의 고장, 투수엔 시련",
        "대구": "더위를 이기는 근성",
        "부산": "함성이 가장 큰 관중석",
        "창원": "짜임새 있는 수비 야구",
        "울산": "묵묵히 던지는 공업 도시",
        "세종": "역사가 짧아 기회가 많다",
        "경기": "팀 수가 가장 많은 격전지",
        "강원": "산바람에 단련된 어깨",
        "충북": "조용히 강한 다크호스",
        "충남": "전통 강호의 자존심",
        "전북": "거친 바람의 홈그라운드",
        "전남": "느리게, 그러나 확실하게",
        "경북": "전통과 자부심의 명문가",
        "경남": "남쪽 끝의 탄탄한 전력",
        "제주": "가장 먼 곳에서 온 유망주",
    ]

    let career: HighSchoolCareerStore

    /// 설정 단계. 순서가 곧 화면 순서다.
    private enum Step: Int, CaseIterable {
        case name, region, style, handicap
    }

    @State private var step: Step = .name
    @State private var playerName = ""
    @State private var selectedRegion = "서울"
    @State private var selectedPresetID = PitcherPresetCatalog.all.first?.id ?? ""
    @State private var selectedKarmas: Set<KarmaID> = []
    /// 계승한 야구혼을 어디에 붓는가. 2회차부터만 고른다.
    @State private var soulDomain: SoulDomain = .technique
    /// 영혼 상점에서 담은 부스트. 잔액 안에서만 담긴다.
    @State private var selectedBoosts: Set<SoulBoostID> = []
    /// 공유받은 시드로 시작하기. 비우면 랜덤.
    @State private var seedInput = ""

    @State private var harshness: DifficultyLevel = .standard
    @FocusState private var nameFocused: Bool

    /// 원버튼 환생 — 지난 회차와 같은 설정(이름·지역·유형·난이도·카르마)으로 즉시 시작.
    /// 부스트는 회차마다 다시 고르는 소비라 싣지 않는다.
    @ViewBuilder private var quickRebirthCard: some View {
        if isRebirth, seedInput.isEmpty, let last = career.lastSetup,
           let preset = presets.first(where: { $0.id == last.presetID }) {
            BaseballCard(title: "바로 환생", tone: .raised) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(last.playerName.isEmpty ? preset.pitcher.name : last.playerName) · \(last.region) · 지난 회차와 같은 설정")
                        .font(.footnote)
                        .foregroundStyle(BaseballTheme.textSecondary)
                    Button {
                        career.startCareer(
                            preset: preset,
                            playerName: last.playerName,
                            region: last.region,
                            difficulty: CareerDifficultySnapshot(
                                careerHarshness: DifficultyLevel(rawValue: last.harshness) ?? .standard),
                            karmas: last.karmas,
                            soulDomain: last.soulDomain
                        )
                    } label: {
                        Text("같은 설정으로 다시 태어나기")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity, minHeight: BaseballMetrics.minimumTapTarget)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(BaseballTheme.action)
                    .accessibilityIdentifier("hs.setup.quickRebirth")
                    Text("영혼 상점을 쓰려면 아래에서 단계대로 진행하세요.")
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
    private var isRebirth: Bool { career.inheritance.lifeNumber > 1 }

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
    private var suggestedName: String { selectedPreset?.pitcher.name ?? "이름" }

    /// "시드-회차" 토큰이면 도전 런이다. 카드의 각인과 같은 형식이다.
    private var parsedChallenge: (seed: String, lifeNumber: Int)? {
        let trimmed = seedInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: "-")
        guard parts.count == 2, UInt64(parts[0]) != nil,
              let life = Int(parts[1]), (1...999).contains(life) else { return nil }
        return (String(parts[0]), life)
    }

    /// 시드 입력의 인라인 오류. 시작 버튼이 이 값으로 잠긴다 — 오타가 커널
    /// 오류 화면까지 가면 안 된다(4차 패널 P0).
    private var seedFieldError: String? {
        let trimmed = seedInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if UInt64(trimmed) != nil || parsedChallenge != nil { return nil }
        return "시드는 숫자, 도전은 \"시드-회차\" 형식입니다. 카드의 각인을 그대로 옮겨 주세요."
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
        .animation(.snappy, value: step)
    }

    // MARK: - 머리

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(isRebirth ? "\(career.inheritance.lifeNumber)회차 · \(stepIndex + 1) / \(steps.count)"
                     : "선수 만들기 · \(stepIndex + 1) / \(steps.count)")
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
            Text(isRebirth ? "다시 태어날 이름을 정하세요" : "선수의 이름을 정하세요")
                .font(.title.bold())
                .foregroundStyle(BaseballTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("고교 3년 동안 이 이름으로 불립니다.")
                .font(.subheadline)
                .foregroundStyle(BaseballTheme.textSecondary)

            // 입력칸이 화면에서 가장 큰 요소다. 여기가 지금 할 일이라는 뜻이다.
            VStack(alignment: .leading, spacing: 8) {
                TextField(suggestedName, text: $playerName)
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
                playerName = suggestedName
                nameFocused = false
            } label: {
                Label("\(suggestedName) 쓰기", systemImage: "wand.and.stars")
                    .font(.footnote.weight(.semibold))
                    .frame(minHeight: BaseballMetrics.minimumTapTarget)
            }
            .buttonStyle(.plain)
            .foregroundStyle(BaseballTheme.action)
            .accessibilityIdentifier("hs.setup.suggestName")

            // 시드로 시작 — 커뮤니티 도전("이 시드로 5회차 안에 지명?")의 입구.
            // 대부분은 안 쓰므로 눈에 띄지 않게 한 줄만.
            TextField("시드로 시작 (선택) — 카드의 \"시드-회차\" 그대로", text: $seedInput)
                .font(.footnote.monospaced())
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numbersAndPunctuation)
                .accessibilityIdentifier("hs.setup.seed")
            if let error = seedFieldError {
                Text(error)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(BaseballTheme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let challenge = parsedChallenge {
                Text("도전 런 — \(challenge.lifeNumber)회차의 판을 맨몸으로 엽니다. 결과는 기록·계승에 남지 않습니다.")
                    .font(.caption2)
                    .foregroundStyle(BaseballTheme.milestone)
                    .fixedSize(horizontal: false, vertical: true)
            } else if !seedInput.isEmpty {
                Text("시드만 입력하면 지금 회차(\(career.inheritance.lifeNumber)회차)의 판입니다. 카드의 판 그대로 열려면 \"시드-회차\"를 입력하세요.")
                    .font(.caption2)
                    .foregroundStyle(BaseballTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if isRebirth {
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
                        Text("이 이름이 3년 동안 이 구장에서 불립니다.")
                            .font(.caption)
                            .foregroundStyle(BaseballTheme.textSecondary)
                            .padding(10)
                    }
                    .accessibilityHidden(true)
            }
        }
        .padding(.bottom, 16)
        // 환생 회차에는 키보드를 먼저 올리지 않는다 — 계승 카드("가져온 것")를 키보드가
        // 가리면 세 번째 기억이 잘린 채 시작한다(QA P2-11).
        .onAppear { nameFocused = !isRebirth }
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
                    Text("전생의 기억이 새 이름을 기다립니다.")
                        .font(.caption)
                        .foregroundStyle(BaseballTheme.textSecondary)
                        .padding(10)
                }
                .accessibilityHidden(true)
            BaseballCard(title: "가져온 것", tone: .milestone) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("야구혼 \(career.inheritance.soulPoints)").font(.subheadline.bold().monospacedDigit())
                    // 정직한 계승 안내 — 스며듦은 총량이 정하고, 잔액은 상점의 돈이다.
                    Text("자동 스며듦 최대 +\(HighSchoolCareerEngine.appliedInheritance(for: career.inheritance.soulTotal)) — 재능 벽에 막힌 몫은 만개 두드림으로 · 상점 \(remainingSoul)혼")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(BaseballTheme.textSecondary)
                    if career.inheritance.memories.isEmpty {
                        Text("가져온 기억이 없습니다.").font(.footnote).foregroundStyle(BaseballTheme.textSecondary)
                    } else {
                        ForEach(career.inheritance.memories, id: \.self) { memory in
                            let copy = HighSchoolPresentation.memory(memory)
                            HStack(spacing: 8) {
                                ArtThumb(assetName: "MemoryArt-\(memory.rawValue)", size: 34, cornerRadius: 7)
                                Text(copy.title).font(.footnote).foregroundStyle(BaseballTheme.textSecondary)
                            }
                        }
                    }
                }
            }
            soulShopCard
        }
    }

    /// 상점에서 산 것을 빼고 남는 잔액. 스며듦은 총량(soulTotal)이 정하고 이 값은 화폐다.
    private var remainingSoul: Int {
        career.inheritance.soulPoints - selectedBoosts.reduce(0) { $0 + $1.cost }
    }

    /// 영혼 상점 — 상한 너머의 야구혼이 처음으로 흘러갈 배수구.
    /// 스탯이 아니라 규칙을 판다: 재능 돌파·기억 확장·조기 성장·성장 리듬.
    private var soulShopCard: some View {
        BaseballCard(title: "영혼 상점", tone: .raised) {
            VStack(alignment: .leading, spacing: 8) {
                Text("야구혼을 소비해 이번 회차의 규칙을 삽니다. 스며듦은 평생 총량이 정합니다 — 구매해도 줄지 않습니다.")
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
                                let copy = Self.boostCopy(boost, baseSlots: selectedKarmas.contains(.erasedMemory) ? 2 : 3)
                                Text(copy.title).font(.subheadline.weight(.semibold))
                                Text(copy.detail).font(.caption).foregroundStyle(BaseballTheme.textSecondary)
                            }
                            Spacer()
                            Text("\(boost.cost)혼")
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

    /// baseSlots: 카르마(기억 소거)로 기본 슬롯이 2장인 회차도 있다 — 고정 "3장에서
    /// 4장" 문구는 그 회차에 거짓말이 된다(2차 패널 P1).
    static func boostCopy(_ boost: SoulBoostID, baseSlots: Int = 3) -> (title: String, detail: String) {
        switch boost {
        case .talentBreak: ("재능 돌파", "가장 낮은 재능 등급이 한 단계 열린 채 시작합니다.")
        case .extraMemory: ("기억 확장", "이번 회차의 기억 슬롯이 \(baseSlots)장에서 \(baseSlots + 1)장이 됩니다.")
        case .headStart: ("조기 성장", "자동 스며듦 상한 너머로 +6이 추가로 스며듭니다.")
        case .trainingRhythm: ("성장 리듬", "이번 회차 훈련 대성공 확률이 16% → 26%가 됩니다.")
        }
    }

    // MARK: - 2단계 지역

    /// 어느 지역에서 시작하는가. 지역이 학교 네 곳의 이름을 정한다 — 감독·포수·훈련 색은
    /// 학교 유형에 붙어 있으므로, 지역은 "누구와 3년을 보내는가"가 아니라 "어느 이름의
    /// 교정에서 그 3년이 흘러가는가"를 정한다. 회차마다 다른 지역을 고르면 다른 학교
    /// 이름들이 아카이브에 쌓인다.
    private var regionStep: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            Text("어느 지역에서 시작할까요?")
                .font(.title.bold())
                .foregroundStyle(BaseballTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("중학교 마지막 대회를 치른 지역입니다. 이 지역의 네 고교가 손을 내밉니다.")
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
                            Text(region)
                                .font(.subheadline.weight(.semibold))
                            Text(Self.regionFlavor[region] ?? "야구 열기가 뜨거운 동네")
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
            Text("어떤 공을 던지는 투수인가요?")
                .font(.title.bold())
                .foregroundStyle(BaseballTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("시작 능력치만 다릅니다. 3년 동안의 훈련으로 얼마든지 바뀝니다.")
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
            Text("이번 회차를 얼마나 어렵게 갈까요?")
                .font(.title.bold())
                .foregroundStyle(BaseballTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            BaseballCard(title: "난이도") {
                HStack(spacing: 6) {
                    ForEach(DifficultyLevel.allCases, id: \.self) { level in
                        Button { harshness = level } label: {
                            Text(Self.difficultyLabel(level))
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
                    }
                }
            }

            // 야구혼을 어디에 붓는지 고른다. 코어는 처음부터 이 값을 받았는데 화면이
            // 넘기지 않아 늘 기본값(제구)으로 갔다 — 회차마다 같은 곳만 오르는 원인 하나였다.
            if career.inheritance.soulPoints > 0 {
                BaseballCard(title: "야구혼 \(career.inheritance.soulPoints)\(KoreanCopy.objectParticle(number: career.inheritance.soulPoints)) 어디에") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            ForEach(SoulDomain.allCases, id: \.self) { domain in
                                Button { soulDomain = domain } label: {
                                    Text(Self.domainLabel(domain))
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
                        Text(Self.domainDetail(soulDomain))
                            .font(.caption)
                            .foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("고른 쪽에 절반이 먼저 가고, 나머지는 가장 낮은 능력부터 채웁니다. 재능의 한계는 넘지 않습니다.")
                            .font(.caption)
                            .foregroundStyle(BaseballTheme.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Text("핸디캡").font(.headline)
            Text("최대 2개. 고르면 이번 회차가 어려워집니다. 대신 다음 회차로 넘어가는 계승이 커집니다. 지금 +\(rewardPermille / 10)%")
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

    // MARK: - 발

    private var footer: some View {
        VStack(spacing: 8) {
            if isLastStep {
                PrimaryButton(title: parsedChallenge != nil ? "도전 런 시작"
                              : isRebirth ? "다시 태어나기" : "고교 1학년 시작", identifier: "hs.start") {
                    nameFocused = false
                    guard let selectedPreset, seedFieldError == nil else { return }
                    career.startCareer(
                        preset: selectedPreset,
                        playerName: playerName,
                        region: selectedRegion,
                        difficulty: CareerDifficultySnapshot(careerHarshness: harshness),
                        karmas: Array(selectedKarmas).sorted { $0.rawValue < $1.rawValue },
                        soulDomain: career.inheritance.soulPoints > 0 ? soulDomain : nil,
                        soulBoosts: Array(selectedBoosts).sorted { $0.rawValue < $1.rawValue },
                        seedOverride: parsedChallenge?.seed ?? (seedInput.isEmpty ? nil : seedInput),
                        challengeLifeNumber: parsedChallenge?.lifeNumber
                    )
                }
            } else {
                PrimaryButton(title: "다음", identifier: "hs.setup.next") { advance() }
            }

            if stepIndex > 0 {
                Button("뒤로") { back() }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(BaseballTheme.textSecondary)
                    .frame(minHeight: BaseballMetrics.minimumTapTarget)
                    .accessibilityIdentifier("hs.setup.back")
            }
        }
        .padding(BaseballMetrics.gutter)
        .background(BaseballTheme.surface)
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

    static func domainLabel(_ domain: SoulDomain) -> String {
        switch domain {
        case .body: "몸"
        case .technique: "기술"
        case .game: "경기 운영"
        }
    }

    static func domainDetail(_ domain: SoulDomain) -> String {
        switch domain {
        case .body: "구위와 체력에 먼저 들어갑니다. 긴 이닝을 버티는 쪽입니다."
        case .technique: "제구와 변화구에 먼저 들어갑니다. 원하는 곳에 꽂는 쪽입니다."
        case .game: "제구와 타자 상대법에 먼저 들어갑니다. 수 싸움으로 버티는 쪽입니다."
        }
    }

    static func difficultyLabel(_ level: DifficultyLevel) -> String {
        switch level {
        case .relaxed: "여유롭게"
        case .standard: "보통"
        case .challenging: "혹독하게"
        }
    }
}

private struct PresetRow: View {
    let preset: PitcherPresetSnapshot
    let selected: Bool
    let onSelect: () -> Void

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
                        Text(preset.name).font(.headline)
                        Text(preset.tagline).font(.subheadline).foregroundStyle(BaseballTheme.textSecondary)
                    }
                    Spacer()
                }
                AbilityGaugeView(label: "구위", value: preset.pitcher.stuff, showsMeaning: false)
                AbilityGaugeView(label: "제구", value: preset.pitcher.command, showsMeaning: false)
                AbilityGaugeView(label: "변화구", value: preset.pitcher.movement, showsMeaning: false)
                AbilityGaugeView(label: "체력", value: preset.pitcher.stamina, showsMeaning: false)
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

    private var locked: Bool { atCapacity && !selected }

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: selected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(selected ? BaseballTheme.warning : BaseballTheme.border.opacity(locked ? 0.4 : 1))
                VStack(alignment: .leading, spacing: 2) {
                    let copy = HighSchoolPresentation.karma(karma)
                    Text(copy.title).font(.subheadline.weight(.bold))
                    Text(copy.detail).font(.footnote).foregroundStyle(BaseballTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Text("+\(karma.rewardPermille / 10)%")
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
        .accessibilityHint(locked ? "핸디캡은 두 개까지 고를 수 있습니다. 다른 것을 빼면 고를 수 있습니다." : "")
    }
}
