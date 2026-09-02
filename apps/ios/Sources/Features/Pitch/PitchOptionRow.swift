import SwiftUI
import SimulationCore
import BaseballIOSDomain

/// 값 몇 개 중 하나를 고르는 가로 줄. Picker보다 조작 영역이 크고 설명을 붙이기 쉽다.
struct OptionRow<Item: Hashable>: View {
    let items: [Item]
    let selection: Item
    let onSelect: (Item) -> Void
    let label: (Item) -> String
    let itemIdentifier: (Item) -> String

    /// 접근성 글자 크기에서는 가로 3분할이 "구종 이름 두 글자 + …"가 된다 —
    /// 결정부가 읽히지 않으면 게임이 잠긴다. AX 크기부터는 세로로 눕힌다(3차 패널 P1).
    @Environment(\.dynamicTypeSize) private var typeSize

    init(
        items: [Item],
        selection: Item,
        onSelect: @escaping (Item) -> Void,
        label: @escaping (Item) -> String,
        itemIdentifier: @escaping (Item) -> String = { _ in "" }
    ) {
        self.items = items
        self.selection = selection
        self.onSelect = onSelect
        self.label = label
        self.itemIdentifier = itemIdentifier
    }

    var body: some View {
        layout {
            ForEach(items, id: \.self) { item in
                Button {
                    onSelect(item)
                } label: {
                    // localization-safe: resolved-copy
                    Text(label(item))
                        .font(BaseballType.detail.weight(.semibold))
                        .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: BaseballMetrics.minimumTapTarget)
                }
                .buttonStyle(.plain)
                .background(
                    item == selection ? BaseballTheme.selection.opacity(0.2) : BaseballTheme.surfaceRaised,
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(item == selection ? BaseballTheme.selection : BaseballTheme.border.opacity(0.6), lineWidth: item == selection ? 2 : 1)
                }
                .accessibilityAddTraits(item == selection ? .isSelected : [])
                .accessibilityIdentifier(itemIdentifier(item))
            }
        }
    }

    @ViewBuilder private func layout<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if typeSize.isAccessibilitySize {
            VStack(spacing: 6) { content() }
        } else {
            HStack(spacing: 6) { content() }
        }
    }
}
