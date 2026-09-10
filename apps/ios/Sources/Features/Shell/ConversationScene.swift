import SwiftUI
import SimulationCore
import BaseballIOSDomain

/// 대화 한 장면의 공용 관용구.
///
/// 프로 시즌 결정과 고교 관계 사건은 같은 게임 안에서 같은 일을 한다 — 누군가 말을 걸고,
/// 플레이어가 셋 중 하나를 고른다. 그런데 두 화면은 서로 다른 모양이었다. 프로는 키아트
/// 배너 + 작은 카드 + 확인 알럿이었고, 고교는 44pt 얼굴 + 제목만 있는 버튼이었다.
/// **한 게임 안에서 대화가 두 모양이면 그건 한 게임이 아니다.**
///
/// 규칙은 셋이다.
/// 1. 얼굴이 크다(84pt). 말하는 사람이 먼저 보여야 대화가 된다.
/// 2. 선택지는 풀카드다. 비용을 **고르기 전에** 카드 위에서 읽는다.
/// 3. 모달이 없다. 확인은 같은 화면 아래의 버튼이고, 결과도 같은 화면에 남는다.
struct ConversationStage<Content: View>: View {
    /// "대화" 또는 "선택이 남긴 변화".
    let eyebrow: String
    /// 사람 화자면 초상, 아니면 nil이다. 없는 인물을 지어내지 않는다.
    let portrait: Portrait?
    /// 사람이 아닌 화자(집·취재·팬·몸 상태…)의 상황 그림. 얼굴 대신 이 자리를 채운다.
    var sceneArtAsset: String?
    /// "감독"·"포수"처럼 관계를 먼저 알리는 짧은 말.
    let roleLabel: String?
    let speakerName: String?
    /// 인물의 결 한 줄. 이름만으로는 누구인지 알 수 없다.
    let situation: String?
    /// 장면 본문. 이 화면에서 가장 큰 글이다.
    let line: String
    /// 보조 기술이 읽을 머리글 한 덩어리. 없으면 보이는 글을 그대로 읽는다.
    var headerAccessibilityText: String?
    @ViewBuilder var content: () -> Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    struct Portrait {
        let seed: String
        let role: AvatarFace.Role
        var stage: PortraitView.PlayerStage = .ace
    }

    /// 84pt가 기본이다. 글자를 키운 사람은 글이 먼저라 얼굴을 64pt로 줄인다.
    private var portraitSize: CGFloat {
        dynamicTypeSize >= .accessibility1 ? 64 : 84
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            Text(verbatim: eyebrow).eyebrowStyle(BaseballTheme.textTertiary)
            HStack(alignment: .center, spacing: 14) {
                if let portrait {
                    PortraitView(
                        seed: portrait.seed,
                        role: portrait.role,
                        size: portraitSize,
                        playerStage: portrait.stage
                    )
                    .accessibilityIdentifier("conversation.portrait")
                } else if let sceneArtAsset {
                    ArtThumb(assetName: sceneArtAsset, size: portraitSize, cornerRadius: 12)
                }
                VStack(alignment: .leading, spacing: 3) {
                    if let roleLabel {
                        Text(verbatim: roleLabel).eyebrowStyle(BaseballTheme.milestone)
                    }
                    if let speakerName {
                        Text(verbatim: speakerName)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(BaseballTheme.textPrimary)
                    }
                    if let situation {
                        Text(verbatim: situation)
                            .detailStyle()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            .accessibilityHidden(headerAccessibilityText != nil)
            Text(verbatim: line)
                .font(.title3.weight(.semibold))
                .foregroundStyle(BaseballTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("conversation.line")
                .accessibilityLabel(Text(verbatim: headerAccessibilityText ?? line))
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("conversation.stage")
    }
}

/// 효과 칩 하나. 프로와 고교가 같은 값 모양을 쓴다.
struct ConversationChip: Identifiable, Equatable {
    let id: String
    let text: String
    let tone: EffectChip.Tone
    var systemImage: String?

    init(id: String, text: String, tone: EffectChip.Tone, systemImage: String? = nil) {
        self.id = id
        self.text = text
        self.tone = tone
        self.systemImage = systemImage
    }
}

/// 선택지 풀카드.
///
/// 비용 칩이 카드 위에 있는 것이 요점이다. 예전 프로 화면은 "구위 +1 · 피로 +12"를 한
/// 문장에 섞었고, 고교 화면은 설명을 아예 보조 기술에만 남겨 **수치상 이득처럼 보이는
/// 비용**(부상 위험 같은)이 선택 전에는 보이지 않았다.
struct ConversationChoiceCard: View {
    let title: String
    /// 선택지 한 줄 설명. 비용이 숫자가 아닐 때 이 줄이 비용이다.
    let detail: String?
    let chips: [ConversationChip]
    /// 카드 아래에 붙는 시점 안내("바로" / "3주 뒤").
    var timingLines: [(systemImage: String, text: String)] = []
    var isSelected = false
    var identifier: String?
    var accessibilityText: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verbatim: title)
                        .font(.headline)
                        .foregroundStyle(BaseballTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? BaseballTheme.selection : BaseballTheme.border)
                        .accessibilityHidden(true)
                }
                // 효과 요약이 설명보다 위다(1.2.9). 숫자를 먼저 읽고 문장으로 확인한다.
                if !chips.isEmpty {
                    EffectChipFlow {
                        ForEach(chips) { chip in
                            EffectChip(text: chip.text, tone: chip.tone, systemImage: chip.systemImage)
                        }
                    }
                }
                if let detail, !detail.isEmpty {
                    Text(verbatim: detail)
                        .detailStyle()
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(timingLines.indices, id: \.self) { index in
                    Label(timingLines[index].text, systemImage: timingLines[index].systemImage)
                        .detailStyle()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(minHeight: 76)
        .background(
            isSelected ? BaseballTheme.selectionSoft : BaseballTheme.surface,
            in: RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
        )
        .overlay {
            RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                .stroke(
                    isSelected ? BaseballTheme.selection : BaseballTheme.border,
                    lineWidth: isSelected ? 2 : 1
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: accessibilityText ?? title))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier(identifier ?? "conversation.choice")
    }
}
