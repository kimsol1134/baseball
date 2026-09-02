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
            //
            // 19칸을 한 그리드에 늘어놓으면 Hick의 법칙대로 고르는 시간이 늘고 훑다 만다
            // (1.2.9 가독성 교정). 권역 5개로 먼저 나누고, 그 안의 도시 3~6개만 보여 준다.
            Picker(copyResolver.resolve(AppCopyKey.setupRegionGroupTitle), selection: $selectedRegionGroup) {
                ForEach(Self.regionGroups) { group in
                    GameCopyText(group.titleKey).tag(group.id)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("hs.setup.regionGroup")
            .onChange(of: selectedRegionGroup) { _, group in
                let regions = Self.regions(in: group)
                if !regions.contains(selectedRegion), let first = regions.first { selectedRegion = first }
            }
            .onChange(of: selectedRegion) { _, region in
                let group = Self.regionGroupID(containing: region)
                if group != selectedRegionGroup { selectedRegionGroup = group }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                ForEach(Self.regions(in: selectedRegionGroup), id: \.self) { region in
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

    /// 권역. 도시 이름은 코어의 지역 목록이 원본이고, 여기서는 표시 묶음만 정한다.
    /// 코어에 새 도시가 추가되면 어느 권역에도 없는 도시는 마지막 권역(강원·제주)으로 흘러간다.
    struct RegionGroup: Identifiable {
        let id: String
        let titleKey: GameCopyKey
        let regions: [String]
    }

    static let regionGroups: [RegionGroup] = [
        RegionGroup(id: "capital", titleKey: AppCopyKey.setupRegionGroupCapital, regions: ["서울", "인천", "수원", "경기"]),
        RegionGroup(id: "chungcheong", titleKey: AppCopyKey.setupRegionGroupChungcheong, regions: ["대전", "세종", "충북", "충남"]),
        RegionGroup(id: "honam", titleKey: AppCopyKey.setupRegionGroupHonam, regions: ["광주", "전북", "전남"]),
        RegionGroup(id: "yeongnam", titleKey: AppCopyKey.setupRegionGroupYeongnam, regions: ["대구", "부산", "창원", "울산", "경북", "경남"]),
        RegionGroup(id: "gangwon-jeju", titleKey: AppCopyKey.setupRegionGroupGangwonJeju, regions: ["강원", "제주"]),
    ]

    static func regions(in groupID: String) -> [String] {
        let all = HighSchoolCareerStore.regions
        let listed = Set(regionGroups.flatMap(\.regions))
        guard let group = regionGroups.first(where: { $0.id == groupID }) else { return all }
        var regions = all.filter { group.regions.contains($0) }
        if group.id == regionGroups.last?.id {
            regions += all.filter { !listed.contains($0) }
        }
        return regions
    }

    static func regionGroupID(containing region: String) -> String {
        regionGroups.first(where: { $0.regions.contains(region) })?.id ?? regionGroups.last!.id
    }
}
