import SwiftUI
import UIKit
import BaseballIOSDomain

enum CareerShareCardKind: String, Equatable, Sendable {
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
}

enum CareerShareCardLayout {
    static let width: CGFloat = 360
    static let height: CGFloat = 450
    static let pixelWidth: CGFloat = 1080
    static let pixelHeight: CGFloat = 1350
    static let renderScale: CGFloat = 3
}

/// 1080×1350 (4:5) share card. Dark background is fixed so community posts ignore the app theme.
struct CareerShareCard: View {
    let model: CareerShareCardModel

    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: copyResolver.resolve(.appTitle))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BaseballTheme.action)
                Spacer(minLength: 8)
                Text(verbatim: copyResolver.resolve(ShareUICopyKey.storeBadge))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(BaseballTheme.textTertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .overlay(
                        Capsule().strokeBorder(BaseballTheme.border.opacity(0.8), lineWidth: 1)
                    )
            }

            HStack(alignment: .center, spacing: 14) {
                PortraitView(
                    seed: model.portraitSeed,
                    role: .player,
                    size: 64,
                    playerStage: model.isPro ? .pro : .ace
                )
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: model.playerName)
                        .font(BaseballType.display)
                        .foregroundStyle(BaseballTheme.textPrimary)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text(verbatim: model.throwingHand)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(BaseballTheme.textSecondary)
                }
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: model.headline)
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(BaseballTheme.milestone)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: model.detail)
                    .font(.subheadline)
                    .foregroundStyle(BaseballTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(BaseballTheme.milestoneSoft, in: RoundedRectangle(cornerRadius: 12))

            if !model.stats.isEmpty {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8),
                    ],
                    spacing: 8
                ) {
                    ForEach(Array(model.stats.enumerated()), id: \.offset) { _, stat in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: stat.label)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(BaseballTheme.textTertiary)
                            Text(verbatim: stat.value)
                                .font(.headline.monospacedDigit().weight(.bold))
                                .foregroundStyle(BaseballTheme.textPrimary)
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(BaseballTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }

            if !model.badges.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(model.badges, id: \.self) { badge in
                        Label(badge, systemImage: "seal.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BaseballTheme.milestone)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                if let stamp = model.stamp {
                    Text(verbatim: CareerShareCopy.stampLine(stamp, resolver: copyResolver))
                        .font(BaseballType.scoreboardLabel)
                        .foregroundStyle(BaseballTheme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(verbatim: copyResolver.resolve(.appTitle))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(BaseballTheme.textTertiary)
            }
        }
        .padding(20)
        .frame(width: CareerShareCardLayout.width, height: CareerShareCardLayout.height, alignment: .top)
        .background(BaseballTheme.fieldNight)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(BaseballTheme.border.opacity(0.6), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
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
        var lines = [model.summary]
        if let stamp = model.stamp {
            lines.append(
                resolver.resolve(
                    ShareUICopyKey.bodyChallenge,
                    arguments: [.userText(stamp.seed), .integer(stamp.lifeNumber)]
                )
            )
        }
        lines.append(storeURL)
        return lines.joined(separator: "\n")
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
