import SwiftUI
import SimulationCore

struct AwakeningCard: View {
    let options: [AwakeningID]
    /// 각성의 전조(코어 값). nil은 전조 개념이 없던 저장본이다.
    var sparks: Int? = nil
    /// 아직 중요 경기를 안 던진 회차 초입인가. 증명할 무대가 없었던 선수에게
    /// "전조가 부족해"라고 벌점 문구를 주면 안 된다(4차 패널 P2).
    var beforeFirstGame = false
    /// 이번 회차에서 이미 찍은 각성.
    var selected: [AwakeningID] = []
    /// 평상시 확인 화면에서는 현재·다음 상태만 보여 주고 선택은 받지 않는다.
    var readOnly = false
    let onChoose: (AwakeningID) -> Void

    /// 회차당 각성 횟수. 코어의 마일스톤 배치(2 + 마지막 장 1)와 업적 `awakenedThrice`가
    /// 같은 값을 전제한다.
    static let totalAwakenings = 3

    @State private var pending: AwakeningID?
    @Environment(\.gameCopyResolver) private var copyResolver

    private var availableSet: Set<AwakeningID> { Set(options) }
    private var takenSet: Set<AwakeningID> { Set(selected) }

    /// 전조는 이제 "갈래를 몇 개 보여 줄까"가 아니라 **한 단계를 건너뛸 수 있는가**를
    /// 정한다. 트리에서는 그쪽이 훨씬 분명한 보상이다 — 2단을 건너뛰고 3단에 닿는다.
    private var sparkLine: (text: String, tone: Color) {
        let copy = HighSchoolPresentation.localizedAwakeningSpark(
            sparks: sparks,
            beforeFirstGame: beforeFirstGame,
            resolver: copyResolver
        )
        return (copy.text, copy.tone.accent)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            if readOnly {
                Text(verbatim: HighSchoolPresentation.localizedAwakeningReadOnlySummary(
                    selectedCount: selected.count,
                    total: Self.totalAwakenings,
                    resolver: copyResolver
                ))
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(BaseballTheme.milestone)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("hs.skillTree.progress")
                Text(verbatim: copyResolver.resolve(AppCopyKey.awakeningGuide))
                    .font(.footnote)
                    .foregroundStyle(BaseballTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                // 회차당 세 번뿐인 순간 — 목록이 아니라 무대를 준다(QA P2-2).
                KeyArtHeader(
                    art: .awakening,
                    eyebrow: copyResolver.resolve(AppCopyKey.awakeningEyebrow),
                    title: copyResolver.resolve(AppCopyKey.awakeningKeyArtTitle),
                    accent: BaseballTheme.milestone
                )
                Text(verbatim: HighSchoolPresentation.localizedAwakeningCounter(
                    total: Self.totalAwakenings,
                    current: selected.count + 1,
                    resolver: copyResolver
                ))
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(BaseballTheme.milestone)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("hs.awakening.counter")
                Text(verbatim: HighSchoolPresentation.localizedAwakeningSelectionGuidance(
                    total: Self.totalAwakenings,
                    selectedCount: selected.count,
                    resolver: copyResolver
                ))
                    .font(.footnote)
                    .foregroundStyle(BaseballTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(verbatim: sparkLine.text)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(sparkLine.tone)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(AwakeningTree.Branch.allCases, id: \.self) { branch in
                branchSection(branch)
            }
        }
        // 마지막 선택지가 탭바에 잘리지 않게 — 잘린 선택지는 없는 선택지다.
        .padding(.bottom, 24)
        .confirmationDialog(
            pending.map {
                HighSchoolPresentation.localizedAwakeningConfirmationTitle(
                    $0,
                    resolver: copyResolver
                )
            } ?? "",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            titleVisibility: .visible,
            presenting: pending
        ) { option in
            Button {
                onChoose(option)
                pending = nil
            } label: {
                Text(verbatim: copyResolver.resolve(AppCopyKey.awakeningConfirmationAction))
            }
            .accessibilityIdentifier("hs.awakening.confirm")
            // iOS 26 팝오버는 .cancel을 그리지 않는다 — 역할 없이 넣어 취소를 항상 보이게 한다.
            Button {
                pending = nil
            } label: {
                Text(verbatim: copyResolver.resolve(AppCopyKey.awakeningConfirmationCancel))
            }
        } message: { option in
            Text(verbatim: HighSchoolPresentation.localizedAwakeningConfirmationMessage(
                option,
                resolver: copyResolver
            ))
        }
    }

    @ViewBuilder private func branchSection(_ branch: AwakeningTree.Branch) -> some View {
        let branchNodes = AwakeningTree.nodes.filter { $0.branch == branch }
        let ownedCount = branchNodes.filter { takenSet.contains($0.id) }.count
        BaseballCard(
            title: HighSchoolPresentation.localizedAwakeningBranchCardTitle(
                branch,
                resolver: copyResolver
            ),
            tone: ownedCount > 0 ? .milestone : .standard
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: branch.symbol).foregroundStyle(BaseballTheme.milestone)
                    Text(verbatim: HighSchoolPresentation.localizedAwakeningBranchDetail(
                        branch,
                        resolver: copyResolver
                    ))
                        .font(.caption)
                        .foregroundStyle(BaseballTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    if ownedCount > 0 {
                        Text(verbatim: HighSchoolPresentation.localizedAwakeningSelectedCount(
                            ownedCount,
                            resolver: copyResolver
                        ))
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(BaseballTheme.milestone)
                    }
                }
                ForEach(branchNodes, id: \.id) { node in
                    nodeRow(node)
                }
            }
        }
    }

    @ViewBuilder private func nodeRow(_ node: AwakeningTree.Node) -> some View {
        let owned = takenSet.contains(node.id)
        let open = availableSet.contains(node.id)
        // **찍을 수 있는 노드만 버튼이다.**
        //
        // 처음에는 18개 노드를 전부 버튼으로 그리고 잠긴 것을 `.disabled`로 두었다. 화면은
        // 같아 보이지만 접근성 트리에 18개의 조작 요소가 생겨, XCUI가 화면을 한 번 훑는
        // 비용이 폭발했다 — 3년 완주 스모크가 330초에서 685초로 늘고 결국 쿼리 타임아웃으로
        // 죽었다. 실제 사용자에게도 같은 값을 치른다(보이스오버가 못 누르는 항목 18개를
        // 하나씩 읽는다). 누를 수 없는 것은 조작 요소가 아니라 그림이어야 한다.
        if open && !owned && !readOnly {
            Button { pending = node.id } label: { nodeBody(node, owned: false, open: true) }
                .buttonStyle(.plain)
                .accessibilityLabel(nodeVoiceLabel(node, owned: false, open: true))
                .accessibilityIdentifier("hs.awakening.\(node.id.rawValue)")
        } else {
            nodeBody(node, owned: owned, open: readOnly && open)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(nodeVoiceLabel(node, owned: owned, open: readOnly && open))
        }
    }

    @ViewBuilder private func nodeBody(_ node: AwakeningTree.Node, owned: Bool, open: Bool) -> some View {
        let leap = open && AwakeningTree.isLeap(node.id, selected: selected)
        let tone: Color = owned ? BaseballTheme.positive
            : open ? BaseballTheme.milestone : BaseballTheme.textTertiary

        HStack(alignment: .top, spacing: 10) {
            // 단수만큼 들여쓴다. 줄기가 아래로 자라는 모양이 한눈에 읽힌다.
            // 세로 강조 레일은 쓰지 않으므로(DOC-19 §7.2) 여백과 갈래 기호로만 깊이를 말한다.
            if node.tier > 1 {
                Image(systemName: "arrow.turn.down.right")
                    .font(.caption2)
                    .foregroundStyle(tone.opacity(owned || open ? 0.8 : 0.35))
                    .padding(.leading, CGFloat((node.tier - 1) * 12))
                    .accessibilityHidden(true)
            }
            Image(systemName: owned ? "checkmark.circle.fill" : open ? "circle.circle" : "lock.fill")
                .font(.subheadline)
                .foregroundStyle(tone)
                .frame(width: 20)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(verbatim: HighSchoolPresentation.localizedAwakeningTitle(
                        node.id,
                        resolver: copyResolver
                    ))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(owned || open ? BaseballTheme.textPrimary : BaseballTheme.textTertiary)
                    Text(verbatim: HighSchoolPresentation.localizedAwakeningTierLabel(
                        node.tier,
                        resolver: copyResolver
                    ))
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(tone)
                    if leap {
                        Text(verbatim: HighSchoolPresentation.localizedAwakeningLeapLabel(
                            resolver: copyResolver
                        ))
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(BaseballTheme.canvas)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(BaseballTheme.milestone, in: Capsule())
                    }
                    Spacer(minLength: 0)
                    if open {
                        Text(verbatim: HighSchoolPresentation.localizedAwakeningActionLabel(
                            readOnly: readOnly,
                            resolver: copyResolver
                        ))
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(BaseballTheme.milestone)
                    }
                }
                // 잠긴 가지는 **제목만** 보여 준다. 앞으로 갈 길이 보이는 것이 목적이지
                // 지금 읽을 설명이 아니고, 18개 분량의 설명문이 한 화면에 깔리면 정작
                // 지금 고를 수 있는 네 가지가 그 안에 묻힌다.
                if owned || open {
                    Text(verbatim: HighSchoolPresentation.localizedAwakeningDetail(
                        node.id,
                        resolver: copyResolver
                    ))
                        .font(.footnote)
                        .foregroundStyle(BaseballTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else if let reason = lockReason(node) {
                    // 잠긴 이유는 그 자리에 적는다. "왜 못 누르지"가 남으면 트리가 벽이 된다.
                    Text(verbatim: reason)
                        .font(.caption2)
                        .foregroundStyle(BaseballTheme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: BaseballMetrics.minimumTapTarget, alignment: .leading)
        .background(
            owned ? BaseballTheme.positive.opacity(0.12)
                : open ? BaseballTheme.milestone.opacity(0.12) : BaseballTheme.surfaceRaised.opacity(0.5),
            in: RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
        )
        .overlay {
            RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                .stroke(tone.opacity(owned || open ? 1 : 0.35), lineWidth: open ? 2 : 1)
        }
        .contentShape(Rectangle())
    }

    private func nodeVoiceLabel(_ node: AwakeningTree.Node, owned: Bool, open: Bool) -> String {
        HighSchoolPresentation.localizedAwakeningNodeVoiceLabel(
            node,
            owned: owned,
            open: open,
            readOnly: readOnly,
            selected: selected,
            resolver: copyResolver
        )
    }

    private func lockReason(_ node: AwakeningTree.Node) -> String? {
        HighSchoolPresentation.localizedAwakeningLockReason(
            node,
            selected: selected,
            resolver: copyResolver
        )
    }
}

/// 현재 국면을 떠나지 않고 보유·다음 스킬을 확인하는 입구.
struct SkillTreeSummaryRow: View {
    let selected: [AwakeningID]
    let onOpen: () -> Void
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(BaseballTheme.milestone)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: HighSchoolPresentation.localizedAwakeningSummaryTitle(
                        selectedCount: selected.count,
                        total: AwakeningCard.totalAwakenings,
                        resolver: copyResolver
                    ))
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(BaseballTheme.textPrimary)
                    Text(verbatim: selected.isEmpty
                          ? HighSchoolPresentation.localizedAwakeningSummaryEmpty(resolver: copyResolver)
                          : selected.map {
                              HighSchoolPresentation.localizedAwakeningTitle(
                                  $0,
                                  resolver: copyResolver
                              )
                          }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(BaseballTheme.textSecondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BaseballTheme.textTertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: BaseballMetrics.minimumTapTarget, alignment: .leading)
            .background(BaseballTheme.surface, in: RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius))
            .overlay {
                RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                    .stroke(BaseballTheme.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("hs.skillTree.open")
    }
}

/// 시트가 닫기 동작을 직접 소유해 호출 화면의 상태를 단순하게 유지한다.
struct SkillTreeSheet: View {
    let selected: [AwakeningID]
    let sparks: Int?
    let beforeFirstGame: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.gameCopyResolver) private var copyResolver

    private var nextOptions: [AwakeningID] {
        guard selected.count < AwakeningCard.totalAwakenings else { return [] }
        return AwakeningTree.available(selected: selected, sparks: sparks)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                AwakeningCard(
                    options: nextOptions,
                    sparks: sparks,
                    beforeFirstGame: beforeFirstGame,
                    selected: selected,
                    readOnly: true,
                    onChoose: { _ in }
                )
                .padding(BaseballMetrics.gutter)
            }
            .background(BaseballTheme.canvas)
            .navigationTitle(Text(verbatim: copyResolver.resolve(AppCopyKey.awakeningSheetTitle)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text(verbatim: copyResolver.resolve(AppCopyKey.awakeningSheetDone))
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
}
