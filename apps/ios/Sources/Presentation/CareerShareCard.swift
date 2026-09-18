import SwiftUI
import UIKit
import SimulationCore
import BaseballIOSDomain

enum CareerShareCardKind: String, Equatable, CaseIterable, Sendable {
    case retirement
    case draft
    case record
    case national
}

struct CareerShareStat: Equatable, Sendable {
    let label: String
    let value: String
}

struct CareerShareCardModel: Equatable, Sendable {
    let kind: CareerShareCardKind
    let playerName: String
    let portraitSeed: String
    let throwingHand: String
    let isPro: Bool
    let headline: String
    let detail: String
    let stats: [CareerShareStat]
    let badges: [String]
    let stamp: CareerDisplayRules.ChallengeStamp?
    let summary: String
    let season: Int
    let hasMedal: Bool
    /// 기록표. 카드가 지표를 골라 보여 주면 "잘한 것만 고른 표"가 되므로, 프로 카드는
    /// **정해진 칸이 전부 있는 표**를 함께 싣는다. 고교 카드는 비어 있다.
    var counting: [CareerRecordEntry] = []
    var rates: [CareerRecordEntry] = []
}

enum CareerShareCardLayout {
    static let width: CGFloat = 360
    static let height: CGFloat = 450
    static let pixelWidth: CGFloat = 1080
    static let pixelHeight: CGFloat = 1350
    static let renderScale: CGFloat = 3
    static let maxGridStats = 4
    static let maxStats = 5
    static let maxNamedBadges = 3
    static let badgeRowHeight: CGFloat = 24
    static let portraitSize: CGFloat = 56

    static func gridStats(_ stats: [CareerShareStat]) -> [CareerShareStat] {
        Array(stats.prefix(maxGridStats))
    }

    static func fifthStat(_ stats: [CareerShareStat]) -> CareerShareStat? {
        guard stats.count > maxGridStats else { return nil }
        return stats[maxGridStats]
    }

    static func visibleBadges(_ badges: [String]) -> [String] {
        if badges.count <= maxNamedBadges { return badges }
        let overflow = badges.count - maxNamedBadges
        return Array(badges.prefix(maxNamedBadges)) + ["+\(overflow)"]
    }
}

/// 1080×1350 (4:5) share card. Dark background is fixed so community posts ignore the app theme.
struct CareerShareCard: View {
    let model: CareerShareCardModel
    var fillsCanvas: Bool = true

    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: copyResolver.resolve(.appTitle))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BaseballTheme.action)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 8)
                Text(verbatim: copyResolver.resolve(ShareUICopyKey.storeBadge))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(BaseballTheme.textTertiary)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .overlay(
                        Capsule().strokeBorder(BaseballTheme.border.opacity(0.8), lineWidth: 1)
                    )
            }

            HStack(alignment: .center, spacing: BaseballMetrics.tightSpacing) {
                PortraitView(
                    seed: model.portraitSeed,
                    role: .player,
                    size: CareerShareCardLayout.portraitSize,
                    playerStage: model.isPro ? .pro : .ace
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: model.playerName)
                        .font(BaseballType.display)
                        .foregroundStyle(BaseballTheme.textPrimary)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(verbatim: model.throwingHand)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(BaseballTheme.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: model.headline)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(BaseballTheme.milestone)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(verbatim: model.detail)
                    .font(.footnote)
                    .foregroundStyle(BaseballTheme.textSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(BaseballTheme.milestoneSoft, in: RoundedRectangle(cornerRadius: 12))

            statsBlock

            recordTable

            badgeRow
                .frame(
                    maxWidth: .infinity,
                    minHeight: CareerShareCardLayout.badgeRowHeight,
                    maxHeight: CareerShareCardLayout.badgeRowHeight,
                    alignment: .leading
                )

            if fillsCanvas {
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 2) {
                if let stamp = model.stamp {
                    Text(verbatim: CareerShareCopy.stampLine(stamp, resolver: copyResolver))
                        .font(BaseballType.scoreboardLabel)
                        .foregroundStyle(BaseballTheme.textTertiary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                Text(verbatim: copyResolver.resolve(.appTitle))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(BaseballTheme.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(BaseballMetrics.gutter)
        .frame(
            width: CareerShareCardLayout.width,
            height: fillsCanvas ? CareerShareCardLayout.height : nil,
            alignment: .top
        )
        .background(BaseballTheme.fieldNight)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(BaseballTheme.border.opacity(0.6), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    /// 기록지. 없는 값은 `—`다 — 0으로 적으면 없던 일이 있었던 일이 된다.
    @ViewBuilder
    private var recordTable: some View {
        if !model.counting.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                entryRow(model.counting)
                if !model.rates.isEmpty {
                    entryRow(model.rates)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BaseballTheme.surface.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("share.recordTable")
        }
    }

    private func entryRow(_ entries: [CareerRecordEntry]) -> some View {
        HStack(spacing: 0) {
            ForEach(entries) { entry in
                VStack(spacing: 1) {
                    Text(verbatim: entry.abbreviation)
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(BaseballTheme.textTertiary)
                    Text(verbatim: entry.value ?? "—")
                        .font(.system(size: 9, weight: .semibold).monospacedDigit())
                        .foregroundStyle(BaseballTheme.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            }
        }
    }

    @ViewBuilder
    private var statsBlock: some View {
        let grid = CareerShareCardLayout.gridStats(model.stats)
        let fifth = CareerShareCardLayout.fifthStat(model.stats)
        if !grid.isEmpty {
            VStack(spacing: BaseballMetrics.tightSpacing) {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: BaseballMetrics.tightSpacing),
                        GridItem(.flexible(), spacing: BaseballMetrics.tightSpacing),
                    ],
                    spacing: BaseballMetrics.tightSpacing
                ) {
                    ForEach(Array(grid.enumerated()), id: \.offset) { _, stat in
                        statTile(stat)
                    }
                }
                if let fifth {
                    statTile(fifth)
                }
            }
        }
    }

    private func statTile(_ stat: CareerShareStat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: stat.label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(BaseballTheme.textTertiary)
                .lineLimit(1)
            Text(verbatim: stat.value)
                .font(.headline.monospacedDigit().weight(.bold))
                .foregroundStyle(BaseballTheme.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(BaseballTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var badgeRow: some View {
        let badges = CareerShareCardLayout.visibleBadges(model.badges)
        if badges.isEmpty {
            Color.clear
        } else {
            HStack(spacing: 6) {
                ForEach(Array(badges.enumerated()), id: \.offset) { _, badge in
                    Text(verbatim: badge)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(BaseballTheme.milestone)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(BaseballTheme.milestoneSoft, in: Capsule())
                }
            }
        }
    }
}

enum CareerShareCardRenderer {
    @MainActor
    static func image(
        for model: CareerShareCardModel,
        resolver: GameCopyResolver = GameCopyResolver()
    ) -> UIImage? {
        let renderer = ImageRenderer(
            content: CareerShareCard(model: model)
                .environment(\.gameCopyResolver, resolver)
        )
        renderer.scale = CareerShareCardLayout.renderScale
        renderer.isOpaque = true
        renderer.proposedSize = ProposedViewSize(
            width: CareerShareCardLayout.width,
            height: CareerShareCardLayout.height
        )
        return renderer.uiImage
    }

    @MainActor
    static func pngData(
        for model: CareerShareCardModel,
        resolver: GameCopyResolver = GameCopyResolver()
    ) -> Data? {
        image(for: model, resolver: resolver)?.pngData()
    }

    /// Intrinsic pixel size with the canvas height unlocked, used to catch clipped content.
    @MainActor
    static func unconstrainedPixelSize(
        for model: CareerShareCardModel,
        resolver: GameCopyResolver = GameCopyResolver()
    ) -> CGSize? {
        let renderer = ImageRenderer(
            content: CareerShareCard(model: model, fillsCanvas: false)
                .environment(\.gameCopyResolver, resolver)
        )
        renderer.scale = CareerShareCardLayout.renderScale
        renderer.isOpaque = true
        renderer.proposedSize = ProposedViewSize(
            width: CareerShareCardLayout.width,
            height: nil
        )
        guard let image = renderer.uiImage else { return nil }
        return CGSize(
            width: image.size.width * image.scale,
            height: image.size.height * image.scale
        )
    }
}

enum CareerShareCopy {
    static let storeURL = LifeCardShareText.storeURL

    static func stampLine(
        _ stamp: CareerDisplayRules.ChallengeStamp,
        resolver: GameCopyResolver
    ) -> String {
        resolver.resolve(
            ShareUICopyKey.stamp,
            arguments: [.userText(stamp.seed), .integer(stamp.lifeNumber)]
        )
    }

    static func body(
        for model: CareerShareCardModel,
        resolver: GameCopyResolver
    ) -> String {
        CareerSharePresentation.shareText(for: model, resolver: resolver)
    }
}

struct CareerSharePreviewSheet: View {
    let model: CareerShareCardModel

    @Environment(\.gameCopyResolver) private var copyResolver
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var renderFailed = false

    var body: some View {
        NavigationStack {
            VStack(spacing: BaseballMetrics.stackSpacing) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("share.card.preview.playerName")
                        .accessibilityLabel(model.playerName)
                } else if renderFailed {
                    Text(verbatim: copyResolver.resolve(ShareUICopyKey.renderFailed))
                        .font(.subheadline)
                        .foregroundStyle(BaseballTheme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("share.card.renderFailed")
                } else {
                    ProgressView()
                }

                shareControl
            }
            .padding(BaseballMetrics.gutter)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(BaseballTheme.canvas.ignoresSafeArea())
            .navigationTitle(copyResolver.resolve(ShareUICopyKey.previewTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(copyResolver.resolve(.actionClose)) { dismiss() }
                        .accessibilityIdentifier("share.card.preview.close")
                }
            }
        }
        .accessibilityIdentifier("share.card.preview")
        .task {
            let rendered = CareerShareCardRenderer.image(for: model, resolver: copyResolver)
            image = rendered
            renderFailed = rendered == nil
        }
    }

    @ViewBuilder
    private var shareControl: some View {
        let text = CareerShareCopy.body(for: model, resolver: copyResolver)
        let items: [Any] = {
            if let image { return [image, text] }
            return [text]
        }()
        ActivityShareButton(
            items: items,
            subject: model.headline,
            onTapped: {
                CareerTelemetry.log(.careerCardShared, [
                    "kind": model.kind.rawValue,
                    "season": model.season,
                    "has_medal": model.hasMedal ? "1" : "0",
                ])
            },
            onFinished: { _ in }
        ) {
            Label(copyResolver.resolve(ShareUICopyKey.previewShare), systemImage: "square.and.arrow.up")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 52)
        }
        .accessibilityIdentifier("share.card.preview.share")
    }
}

struct CareerShareButton: View {
    enum Style {
        case full
        case icon
    }

    let model: CareerShareCardModel
    var style: Style = .full

    @Environment(\.gameCopyResolver) private var copyResolver
    @State private var showsPreview = false

    var body: some View {
        Button {
            showsPreview = true
        } label: {
            switch style {
            case .full:
                Label(copyResolver.resolve(ShareUICopyKey.action), systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BaseballTheme.action)
                    .frame(maxWidth: .infinity, minHeight: BaseballMetrics.minimumTapTarget)
            case .icon:
                Image(systemName: "square.and.arrow.up")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(BaseballTheme.action)
                    .frame(
                        width: BaseballMetrics.minimumTapTarget,
                        height: BaseballMetrics.minimumTapTarget
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(copyResolver.resolve(ShareUICopyKey.action))
        .accessibilityIdentifier("share.card.\(model.kind.rawValue)")
        .sheet(isPresented: $showsPreview) {
            CareerSharePreviewSheet(model: model)
        }
    }
}
