import SwiftUI
import SimulationCore
import BaseballIOSDomain

struct StrikeZoneGrid: View {
    let selected: PitchZone
    let recommended: PitchZone
    /// 타자가 강한 칸·약한 칸. 격자에 칠해 두지 않으면 유저는 9칸을 매번 고민하면서도
    /// 무엇이 다른지 모른다. 추정이 없는 상황(스카우팅 리포트 없음)에서는 nil이다.
    var hotZone: PitchZone? = nil
    var coldZone: PitchZone? = nil
    /// 코스 이름을 읽어 줄 기준. 좌타자면 몸쪽·바깥쪽이 뒤집힌다.
    var batSide: BatSide = .right
    let onSelect: (PitchZone) -> Void
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { column in
                            cell(row: row, column: column)
                        }
                    }
                }
            }
            // 표적 기호가 무엇을 뜻하는지 한 줄로 못 박는다. 아이콘만으로는 읽히지 않는다.
            Label(copyResolver.resolve(.zoneRecommended), systemImage: "target")
                .font(.caption)
                .foregroundStyle(BaseballTheme.information)
            if hotZone != nil || coldZone != nil {
                HStack(spacing: 10) {
                    Label(copyResolver.resolve(.zoneHot), systemImage: "square.fill")
                        .foregroundStyle(BaseballTheme.warning)
                    Label(copyResolver.resolve(.zoneCold), systemImage: "square.fill")
                        .foregroundStyle(BaseballTheme.positive)
                }
                .font(.caption2)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(copyResolver.resolve(.zoneLegendAccessibility))
            }
        }
    }

    private func cell(row: Int, column: Int) -> some View {
        let zone = PitchZone(row: row, column: column)
        let isSelected = zone == selected
        let isRecommended = zone == recommended
        let isHot = zone == hotZone
        let isCold = zone == coldZone
        return Button {
            onSelect(zone)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? BaseballTheme.selection.opacity(0.35) : BaseballTheme.surfaceRaised)
                // 색은 선택 표시를 덮지 않을 만큼만 옅게 깐다 — 어느 칸을 골랐는지가 먼저다.
                if isHot || isCold {
                    RoundedRectangle(cornerRadius: 6)
                        .fill((isHot ? BaseballTheme.warning : BaseballTheme.positive).opacity(0.22))
                }
                if isRecommended {
                    Image(systemName: "target")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BaseballTheme.information)
                        .accessibilityHidden(true)
                }
            }
            .frame(height: BaseballMetrics.minimumTapTarget)
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? BaseballTheme.selection : BaseballTheme.border.opacity(0.6), lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            PitchCopy.localized(zone, batSide: batSide, resolver: copyResolver)
                + (isRecommended ? copyResolver.resolve(.zoneCellRecommended) : "")
                + (isHot ? copyResolver.resolve(.zoneCellHot) : isCold ? copyResolver.resolve(.zoneCellCold) : "")
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// 방금 공의 위치 요약 — 3×3 존 위에 목표(점선 링)와 실제 도달점(점).
///
/// 승부 장면(PitchDramaView)은 1.6초 재생으로 흐르고 지나간다. "그래서 공이 어디로
/// 갔는데?"의 답이 화면 어디에도 남지 않아서, 존을 벗어난 공이 어느 쪽으로 얼마나
/// 빠졌는지 알 수 없었다. 이 미니맵은 결과 카드에 상시로 남는다.
struct ZoneMiniMap: View {
    let execution: PitchExecution
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        Canvas { context, size in
            // 좌표계 ±800(존은 ±500). 존 밖 실투도 어느 쪽으로 빠졌는지 보인다.
            func place(_ x: Int, _ y: Int) -> CGPoint {
                let cx = min(780, max(-780, x))
                let cy = min(780, max(-780, y))
                return CGPoint(
                    x: size.width / 2 + CGFloat(cx) / 800 * size.width / 2,
                    y: size.height / 2 - CGFloat(cy) / 800 * size.height / 2
                )
            }
            let topLeft = place(-500, 500)
            let bottomRight = place(500, -500)
            let zone = CGRect(x: topLeft.x, y: topLeft.y,
                              width: bottomRight.x - topLeft.x, height: bottomRight.y - topLeft.y)
            context.fill(Path(zone), with: .color(BaseballTheme.fieldChalk.opacity(0.05)))
            context.stroke(Path(zone), with: .color(BaseballTheme.border), lineWidth: 1)
            for i in 1...2 {
                let x = zone.minX + zone.width * CGFloat(i) / 3
                let y = zone.minY + zone.height * CGFloat(i) / 3
                var vertical = Path(); vertical.move(to: CGPoint(x: x, y: zone.minY)); vertical.addLine(to: CGPoint(x: x, y: zone.maxY))
                var horizontal = Path(); horizontal.move(to: CGPoint(x: zone.minX, y: y)); horizontal.addLine(to: CGPoint(x: zone.maxX, y: y))
                context.stroke(vertical, with: .color(BaseballTheme.border.opacity(0.4)), lineWidth: 0.5)
                context.stroke(horizontal, with: .color(BaseballTheme.border.opacity(0.4)), lineWidth: 0.5)
            }
            // 목표 — 포수가 미트를 댄 자리.
            let target = place(execution.targetX, execution.targetY)
            context.stroke(
                Path(ellipseIn: CGRect(x: target.x - 5, y: target.y - 5, width: 10, height: 10)),
                with: .color(BaseballTheme.textTertiary),
                style: StrokeStyle(lineWidth: 1, dash: [2, 2])
            )
            // 실제 — 공이 지나간 자리.
            let actual = place(execution.actualX, execution.actualY)
            let inZone = abs(execution.actualX) <= 500 && abs(execution.actualY) <= 500
            context.fill(
                Path(ellipseIn: CGRect(x: actual.x - 4, y: actual.y - 4, width: 8, height: 8)),
                with: .color(inZone ? BaseballTheme.positive : BaseballTheme.warning)
            )
        }
        .frame(width: 64, height: 64)
        .background(BaseballTheme.fieldNight, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel(
            copyResolver.resolve(
                abs(execution.actualX) <= 500 && abs(execution.actualY) <= 500 ? .zoneMiniIn : .zoneMiniOut
            )
        )
    }
}
