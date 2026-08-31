import SwiftUI
import SimulationCore
import BaseballIOSDomain

extension HighSchoolSetupView {
    var regionStep: some View {
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
                ForEach(HighSchoolCareerStore.regions, id: \.self) { region in
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
}
