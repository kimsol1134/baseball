import Foundation
import SimulationCore
import BaseballIOSDomain

extension HighSchoolPresentation {
    /// The legacy Korean tuple above remains available to non-migrated clients. The scoped iOS
    /// skill-tree surface resolves the same stable IDs through GameContent instead.
    static func localizedAwakeningTitle(
        _ id: AwakeningID,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(id.titleCopyToken)
    }

    static func localizedAwakeningDetail(
        _ id: AwakeningID,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(id.detailCopyToken)
    }

    static func localizedAwakeningBranchTitle(
        _ branch: AwakeningTree.Branch,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(branch.titleCopyToken)
    }

    static func localizedAwakeningBranchDetail(
        _ branch: AwakeningTree.Branch,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(branch.detailCopyToken)
    }

    static func localizedAwakeningReadOnlySummary(
        selectedCount: Int,
        total: Int,
        resolver: GameCopyResolver
    ) -> String {
        guard selectedCount > 0 else {
            return resolver.resolve(AppCopyKey.awakeningReadOnlyEmpty)
        }
        return resolver.resolve(
            AppCopyKey.awakeningReadOnlyProgress,
            arguments: [
                .integer(selectedCount),
                .integer(total),
                .integer(max(0, total - selectedCount)),
            ]
        )
    }

    static func localizedAwakeningCounter(
        total: Int,
        current: Int,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(
            AppCopyKey.awakeningCounter,
            arguments: [.integer(total), .integer(current)]
        )
    }

    static func localizedAwakeningSelectionGuidance(
        total: Int,
        selectedCount: Int,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(
            AppCopyKey.awakeningSelectionGuidance,
            arguments: [.integer(max(0, total - selectedCount - 1))]
        )
    }

    static func localizedAwakeningSpark(
        sparks: Int?,
        beforeFirstGame: Bool,
        resolver: GameCopyResolver
    ) -> (text: String, tone: BaseballCardTone) {
        if (sparks ?? AwakeningTree.leapSparks) >= AwakeningTree.leapSparks {
            return (
                resolver.resolve(AppCopyKey.awakeningSparkLeaps),
                .milestone
            )
        }
        if beforeFirstGame {
            return (
                resolver.resolve(AppCopyKey.awakeningSparkBeforeFirstGame),
                .standard
            )
        }
        return (
            resolver.resolve(AppCopyKey.awakeningSparkNeedsProof),
            .standard
        )
    }

    static func localizedAwakeningConfirmationTitle(
        _ id: AwakeningID,
        resolver: GameCopyResolver
    ) -> String {
        let title = localizedAwakeningTitle(id, resolver: resolver)
        let subject = resolver.language == .korean
            ? "'\(title)'\(KoreanCopy.ro(title))"
            : "'\(title)'"
        return resolver.resolve(
            AppCopyKey.awakeningConfirmationTitle,
            arguments: [.userText(subject)]
        )
    }

    static func localizedAwakeningConfirmationMessage(
        _ id: AwakeningID,
        resolver: GameCopyResolver
    ) -> String {
        let node = AwakeningTree.node(id)
        return resolver.resolve(
            AppCopyKey.awakeningConfirmationMessage,
            arguments: [
                .userText(localizedAwakeningBranchTitle(node.branch, resolver: resolver)),
                .integer(node.tier),
                .userText(localizedAwakeningDetail(id, resolver: resolver)),
            ]
        )
    }

    static func localizedAwakeningBranchCardTitle(
        _ branch: AwakeningTree.Branch,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(
            AppCopyKey.awakeningBranchTitle,
            arguments: [.userText(localizedAwakeningBranchTitle(branch, resolver: resolver))]
        )
    }

    static func localizedAwakeningSelectedCount(
        _ count: Int,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(
            AppCopyKey.awakeningBranchSelectedCount,
            arguments: [.integer(count)]
        )
    }

    static func localizedAwakeningTierLabel(
        _ tier: Int,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(AppCopyKey.awakeningTierLabel, arguments: [.integer(tier)])
    }

    static func localizedAwakeningActionLabel(
        readOnly: Bool,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(readOnly ? AppCopyKey.awakeningNextLabel : AppCopyKey.awakeningSelectLabel)
    }

    static func localizedAwakeningLeapLabel(resolver: GameCopyResolver) -> String {
        resolver.resolve(AppCopyKey.awakeningLeapLabel)
    }

    static func localizedAwakeningLockReason(
        _ node: AwakeningTree.Node,
        selected: [AwakeningID],
        resolver: GameCopyResolver
    ) -> String? {
        let taken = Set(selected)
        let missing = node.parents.filter { !taken.contains($0) }
        guard !missing.isEmpty else { return nil }
        let names = missing
            .map { localizedAwakeningTitle($0, resolver: resolver) }
            .joined(separator: " · ")
        return resolver.resolve(
            AppCopyKey.awakeningLockReason,
            arguments: [.userText(names)]
        )
    }

    static func localizedAwakeningNodeVoiceLabel(
        _ node: AwakeningTree.Node,
        owned: Bool,
        open: Bool,
        readOnly: Bool,
        selected: [AwakeningID],
        resolver: GameCopyResolver
    ) -> String {
        let argumentsBase: [LocalizedCopyArgument] = [
            .userText(localizedAwakeningBranchTitle(node.branch, resolver: resolver)),
            .integer(node.tier),
            .userText(localizedAwakeningTitle(node.id, resolver: resolver)),
        ]
        if owned {
            return resolver.resolve(
                AppCopyKey.awakeningNodeVoiceOwned,
                arguments: argumentsBase
            )
        }
        if open {
            let key = readOnly
                ? AppCopyKey.awakeningNodeVoiceAvailableNext
                : AppCopyKey.awakeningNodeVoiceAvailableNow
            return resolver.resolve(
                key,
                arguments: argumentsBase + [
                    .userText(localizedAwakeningDetail(node.id, resolver: resolver)),
                ]
            )
        }
        return resolver.resolve(
            AppCopyKey.awakeningNodeVoiceLocked,
            arguments: argumentsBase + [
                .userText(
                    localizedAwakeningLockReason(node, selected: selected, resolver: resolver) ?? ""
                ),
            ]
        )
    }

    static func localizedAwakeningSummaryTitle(
        selectedCount: Int,
        total: Int,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(
            AppCopyKey.awakeningSummaryTitle,
            arguments: [.integer(selectedCount), .integer(total)]
        )
    }

    static func localizedAwakeningSummaryEmpty(resolver: GameCopyResolver) -> String {
        resolver.resolve(AppCopyKey.awakeningSummaryEmpty)
    }

    static func memory(_ id: MemoryCardID) -> (title: String, detail: String) {
        switch id {
        case .velocityBlueprint: ("직구 구속 훈련법", "직구 구속·헛스윙 증가, 제구 소폭 감소")
        case .fingertipMemory: ("손끝의 기억", "변화구 움직임 상승, 체력 소폭 감소")
        case .catcherNotebook: ("포수의 노트", "제구와 빗맞은 타구 유도 증가")
        case .rivalNotebook: ("라이벌 노트", "제구·변화구와 변화구 헛스윙 증가")
        case .recoveryRoutine: ("회복 방법", "체력 상승, 공마다 피로 소모 감소")
        case .pressureRehearsal: ("압박의 예행연습", "제구·체력과 위기 상황 제구 향상")
        case .firstPitchMap: ("초구 지도", "초구 제구 상승, 체력 소폭 감소")
        case .twoStrikeSequence: ("2스트라이크 구종 순서", "변화구 움직임·헛스윙 상승, 체력 소폭 감소")
        case .fatigueDiary: ("피로 일지", "체력과 후반 제구 상승")
        case .mechanicsVideo: ("투구 동작 교정 영상", "제구 향상, 공의 최고 위력 소폭 감소")
        case .schoolPlaybook: ("학교에서 배운 승부법", "제구·변화구 향상")
        case .coachLetter: ("코치의 편지", "제구·체력 향상")
        case .draftReport: ("구단 평가표", "구위·제구 향상")
        case .stadiumEcho: ("구장의 메아리", "구위·헛스윙 증가, 제구 소폭 감소")
        case .teamFirstPromise: ("팀을 위한 약속", "제구·체력과 빗맞은 타구 유도 증가")
        case .failureScorebook: ("실패의 스코어북", "제구·변화구 향상, 체력 소폭 감소")
        case .winterProgram: ("겨울 훈련표", "구위·체력 향상, 피로 누적 감소")
        case .bullpenCompass: ("불펜의 나침반", "구위·체력 향상, 피로 누적 감소")
        }
    }
}
