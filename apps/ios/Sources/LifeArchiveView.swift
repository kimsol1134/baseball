import SwiftUI
import SimulationCore

enum LifeArchiveOrdering {
    /// 저장 배열의 과거 구현 순서에 기대지 않고, 화면 계보는 항상 최신 선수를 먼저 둔다.
    static func newestFirst(
        _ records: [HighSchoolCareerStore.LifeRecord]
    ) -> [HighSchoolCareerStore.LifeRecord] {
        records.enumerated()
            .sorted {
                if $0.element.lifeNumber != $1.element.lifeNumber {
                    return $0.element.lifeNumber > $1.element.lifeNumber
                }
                return $0.offset < $1.offset
            }
            .map(\.element)
    }

    /// A lineage is causal, so the ribbon runs from the first player toward the newest player.
    static func oldestFirst(
        _ records: [HighSchoolCareerStore.LifeRecord]
    ) -> [HighSchoolCareerStore.LifeRecord] {
        records.enumerated()
            .sorted {
                if $0.element.lifeNumber != $1.element.lifeNumber {
                    return $0.element.lifeNumber < $1.element.lifeNumber
                }
                return $0.offset < $1.offset
            }
            .map(\.element)
    }
}

struct ArchivedPledgePresentation: Equatable {
    let title: String
    let tier: RunPledgeTier
    let rewardPermille: Int

    static func resolve(_ record: HighSchoolCareerStore.LifeRecord) -> ArchivedPledgePresentation? {
        guard let pledgeID = record.pledgeID else { return nil }
        // Records without snapshots were closed by the v1 catalog. New records always freeze
        // title/tier/reward at settlement, so this fallback never reinterprets a newer contract.
        let catalog = RunPledge.pledge(id: pledgeID, rulesVersion: RunPledge.legacyRulesVersion)
        let tier = record.pledgeTier.flatMap(RunPledgeTier.init(rawValue:))
            ?? catalog?.tier
            ?? .bold
        return ArchivedPledgePresentation(
            title: record.pledgeTitle ?? catalog?.title ?? "지난 고교 3년의 목표",
            tier: tier,
            rewardPermille: record.pledgeRewardPermille ?? catalog?.rewardPermille ?? tier.rewardPermille
        )
    }

    func accessibilityLabel(progressLine: String, status: String) -> String {
        "\(tier.title) 목표, \(title), \(progressLine), \(status), 보상 계승 포인트 \(rewardPermille / 10)퍼센트 추가"
    }
}

/// 지난 회차들.
///
/// 환생 게임인데 **지난 회차를 볼 방법이 아예 없었다**(품질 평가 §4.3, P1-5). "N회차의 나"가
/// 쌓이는 것이 이 게임의 구조인데 그 역사가 어디에도 남지 않으면, 회차를 반복할 이유가
/// 다음 회차의 시작 능력치뿐이 된다.
///
/// 한 줄에 회차·학교·결말이 들어간다. 펼치면 기록과 가져간 기억이 나온다.
struct LifeArchiveSection: View {
    let records: [HighSchoolCareerStore.LifeRecord]

    @Environment(\.gameCopyResolver) private var copyResolver

    private var orderedRecords: [HighSchoolCareerStore.LifeRecord] {
        LifeArchiveOrdering.newestFirst(records)
    }

    /// 회차를 가로지르는 누적. 아카이브가 목록로만 있으면 "다음 회차에 깨야 할 숫자"가
    /// 생기지 않는다 — 로그라이트 아카이브의 핵심은 목록이 아니라 누적 곡선이다.
    private var totals: (drafted: Int, strikeouts: Int, bestEvaluation: Int, soul: Int) {
        records.reduce((0, 0, 0, 0)) {
            ($0.0 + ($1.drafted ? 1 : 0), $0.1 + $1.strikeouts,
             max($0.2, $1.evaluationScore), $0.3 + $1.soulPoints)
        }
    }

    /// 역대 얻은 별명(중복 제거). 도감이 채워질수록 "다 모아 보고 싶다"가 환생의 이유가 된다.
    private var collectedNicknames: Set<String> {
        Set(records.flatMap { $0.nicknames ?? [] })
    }

    /// 통산 탈삼진의 다음 이정표. 전부 넘었으면 nil — 그때는 숫자 자체가 전설이다.
    private var nextStrikeoutMilestone: Int? {
        NicknameRules.strikeoutLadder.first { $0 > totals.strikeouts }
    }

    /// 한 회차 최다 탈삼진 — 역대 최고 기록은 깨라고 있는 것이다.
    private var bestStrikeoutLife: HighSchoolCareerStore.LifeRecord? {
        records.max { $0.strikeouts < $1.strikeouts }
    }

    private var lineageMasteries: [CareerLineageMastery] {
        HighSchoolCareerStore.lineageMasteries(from: records)
    }

    private func familyName(_ family: CareerSignatureLegacyFamily) -> String {
        let key: LegacyUICopyKey = switch family {
        case .power: .masteryFamilyPower
        case .command: .masteryFamilyCommand
        case .breaking: .masteryFamilyBreaking
        case .endurance: .masteryFamilyEndurance
        case .gamecraft: .masteryFamilyGamecraft
        case .battery: .masteryFamilyBattery
        }
        return copyResolver.resolve(key)
    }

    var body: some View {
        BaseballCard(
            title: copyResolver.resolve(.archiveTitle, arguments: [.integer(records.count)])
        ) {
            VStack(alignment: .leading, spacing: 0) {
                if !records.isEmpty {
                    PlayerLineageRibbon(records: orderedRecords)
                        .padding(.bottom, 10)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verbatim: copyResolver.resolve(LegacyUICopyKey.masteryArchiveHeading))
                            .eyebrowStyle(BaseballTheme.information)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                            ForEach(lineageMasteries, id: \.family) { mastery in
                                HStack {
                                    Text(verbatim: familyName(mastery.family))
                                        .font(.caption.weight(.semibold))
                                    Spacer(minLength: 4)
                                    Text(verbatim: copyResolver.resolve(
                                        LegacyUICopyKey.masteryRank,
                                        arguments: [.integer(mastery.rank), .integer(mastery.contributions)]
                                    ))
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(BaseballTheme.textSecondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(BaseballTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .padding(.bottom, 10)
                    Rectangle()
                        .fill(BaseballTheme.border.opacity(0.35))
                        .frame(height: 1)
                }
                if records.count >= 2 {
                    HStack(spacing: 16) {
                        archiveStat(copyResolver.resolve(.archiveStatDrafted), "\(totals.drafted)/\(records.count)")
                        archiveStat(copyResolver.resolve(.archiveStatStrikeouts), "\(totals.strikeouts)")
                        archiveStat(copyResolver.resolve(.archiveStatEvaluation), "\(totals.bestEvaluation)")
                        archiveStat(copyResolver.resolve(.archiveStatPoints), "\(totals.soul)")
                    }
                    .padding(.bottom, 10)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        copyResolver.resolve(
                            .archiveTotalsAccessibility,
                            arguments: [
                                .integer(totals.drafted), .integer(totals.strikeouts),
                                .integer(totals.bestEvaluation), .integer(totals.soul),
                            ]
                        )
                    )
                    Rectangle()
                        .fill(BaseballTheme.border.opacity(0.35))
                        .frame(height: 1)
                }
                if !records.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        if let next = nextStrikeoutMilestone {
                            Text(
                                verbatim: copyResolver.resolve(
                                    .archiveNextStrikeouts,
                                    arguments: [.integer(next - totals.strikeouts), .integer(next)]
                                )
                            )
                        }
                        if let best = bestStrikeoutLife, best.strikeouts > 0 {
                            Text(
                                verbatim: copyResolver.resolve(
                                    .archiveBestStrikeouts,
                                    arguments: [.integer(best.strikeouts), .integer(best.lifeNumber)]
                                )
                            )
                        }
                        Text(
                            verbatim: copyResolver.resolve(
                                collectedNicknames.count >= NicknameRules.catalogCount
                                    ? .archiveNicknameComplete : .archiveNicknameIncomplete,
                                arguments: [
                                    .integer(collectedNicknames.count), .integer(NicknameRules.catalogCount),
                                ]
                            )
                        )
                    }
                    .font(.caption)
                    .foregroundStyle(BaseballTheme.textSecondary)
                    .padding(.vertical, 8)
                    .accessibilityIdentifier("archive.legacyBoard")
                    Rectangle()
                        .fill(BaseballTheme.border.opacity(0.35))
                        .frame(height: 1)
                }
                ForEach(orderedRecords) { record in
                    // 최신 회차는 기본 펼침 — 방금 끝낸 3년이 접힌 한 줄로 수축되면
                    // 2회차를 시작할 이유가 화면에 없다(QA P0-3).
                    LifeArchiveRow(record: record, initiallyExpanded: record.id == orderedRecords.first?.id)
                    if record.id != orderedRecords.last?.id {
                        Rectangle()
                            .fill(BaseballTheme.border.opacity(0.35))
                            .frame(height: 1)
                    }
                }
            }
            .accessibilityIdentifier("record.lifeArchive")
        }
        .onAppear {
            guard !records.isEmpty else { return }
            GameAnalytics.logOnce(
                .lineageArchiveOpened,
                scope: "lineage-archive:\(records.count):\(records.map(\.lifeNumber).max() ?? 0)",
                properties: [
                    "life_count": records.count,
                    "drafted_count": totals.drafted,
                    "highest_mastery_rank": lineageMasteries.map(\.rank).max() ?? 1,
                    "signature_family_count": Set(records.compactMap { $0.signatureLegacy?.family }).count,
                ]
            )
        }
    }

    private func archiveStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(verbatim: label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(BaseballTheme.textTertiary)
            Text(verbatim: value)
                .font(.subheadline.monospacedDigit().weight(.bold))
                .foregroundStyle(BaseballTheme.textPrimary)
        }
    }
}

/// 숫자 목록보다 먼저 얼굴과 이름을 보여 주는 선수 계보. 오래 할수록 통산 수치뿐 아니라
/// 함께 키운 사람들의 행렬이 길어진다.
private struct PlayerLineageRibbon: View {
    let records: [HighSchoolCareerStore.LifeRecord]

    @Environment(\.gameCopyResolver) private var copyResolver

    private var ordered: [HighSchoolCareerStore.LifeRecord] {
        LifeArchiveOrdering.oldestFirst(records)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: copyResolver.resolve(.archiveLineage))
                .font(.caption.weight(.bold))
                .foregroundStyle(BaseballTheme.textSecondary)
            ScrollView(.horizontal) {
                HStack(alignment: .center, spacing: 8) {
                    ForEach(Array(ordered.enumerated()), id: \.element.id) { index, record in
                        if index > 0 {
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundStyle(BaseballTheme.textTertiary)
                                .accessibilityHidden(true)
                        }
                        VStack(spacing: 4) {
                            PortraitView(
                                seed: record.portraitSeed,
                                role: .player,
                                size: 34,
                                playerStage: record.drafted ? .pro : .ace
                            )
                            Text(verbatim: record.playerName)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(BaseballTheme.textPrimary)
                                .lineLimit(1)
                            Text(
                                verbatim: copyResolver.resolve(
                                    .archivePlayerNumber,
                                    arguments: [.integer(record.lifeNumber)]
                                )
                            )
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(BaseballTheme.textTertiary)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(
                            copyResolver.resolve(
                                .archivePlayerAccessibility,
                                arguments: [
                                    .integer(record.lifeNumber), .userText(record.playerName),
                                    .userText(HighSchoolConclusionPresentation.localizedSchoolName(
                                        record.schoolName, resolver: copyResolver
                                    )),
                                    .userText(copyResolver.resolve(record.drafted ? .archiveDrafted : .archiveUndrafted)),
                                ]
                            )
                        )
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("archive.playerLineage")
        }
    }
}

private struct LifeArchiveRow: View {
    let record: HighSchoolCareerStore.LifeRecord

    @State private var expanded: Bool
    @Environment(\.gameCopyResolver) private var copyResolver

    private var schoolName: String {
        HighSchoolConclusionPresentation.localizedSchoolName(record.schoolName, resolver: copyResolver)
    }

    private var draftStatus: String {
        copyResolver.resolve(record.drafted ? .archiveDrafted : .archiveUndrafted)
    }

    private var outcome: String {
        LegacyPresentation.archiveOutcome(record, resolver: copyResolver)
    }

    init(record: HighSchoolCareerStore.LifeRecord, initiallyExpanded: Bool = false) {
        self.record = record
        _expanded = State(initialValue: initiallyExpanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                expanded.toggle()
            } label: {
                HStack(alignment: .center, spacing: 8) {
                    // 지난 회차들이 "숫자 목록"이 아니라 "살았던 사람들"로 읽히게 —
                    // 이름 시드가 같으면 그때 그 얼굴 그대로다.
                    PortraitView(seed: record.portraitSeed, role: .player, size: 30,
                                 playerStage: record.drafted ? .pro : .ace)
                    Text(
                        verbatim: copyResolver.resolve(
                            .archivePlayerNumber,
                            arguments: [.integer(record.lifeNumber)]
                        )
                    )
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(BaseballTheme.textPrimary)
                    Text(verbatim: schoolName)
                        .font(.footnote)
                        .foregroundStyle(BaseballTheme.textSecondary)
                    Spacer(minLength: 0)
                    Text(verbatim: draftStatus)
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(record.drafted ? BaseballTheme.positive : BaseballTheme.textTertiary)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(BaseballTheme.textTertiary)
                }
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                copyResolver.resolve(
                    .archivePlayerAccessibility,
                    arguments: [
                        .integer(record.lifeNumber), .userText(record.playerName),
                        .userText(schoolName), .userText(outcome),
                    ]
                )
            )

            if expanded {
                VStack(alignment: .leading, spacing: 6) {
                    LifeCardShareButton(record: record)
                        .padding(.bottom, 2)
                    PlayerLegacyQuote(
                        legacy: LegacyPresentation.playerLegacy(for: record, resolver: copyResolver),
                        heading: copyResolver.resolve(
                            .quoteHeadingPlayer,
                            arguments: [.userText(record.playerName)]
                        )
                    )
                    .padding(.bottom, 2)
                    .accessibilityIdentifier("archive.playerLegacy.\(record.lifeNumber)")
                    .onAppear(perform: logLegacySeen)
                    ArchivedRelationshipsCard(record: record)
                    if let memories = record.bondMemories, !memories.isEmpty {
                        PlayerBondMemoryList(
                            memories: memories,
                            surface: .archive,
                            lifeNumber: record.lifeNumber
                        )
                    }
                    if let chronicle = record.chronicle, !chronicle.isEmpty {
                        ForEach(chronicle, id: \.self) { line in
                            Text(
                                verbatim: HighSchoolConclusionPresentation.localizedChronicleLine(
                                    line, resolver: copyResolver
                                )
                            )
                                .font(.caption)
                                .foregroundStyle(BaseballTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Rectangle().fill(BaseballTheme.border.opacity(0.3)).frame(height: 1)
                    }
                    if let nicknames = record.nicknames, !nicknames.isEmpty {
                        let titles = nicknames.map {
                            "'\(HighSchoolConclusionPresentation.localizedNicknameTitle($0, resolver: copyResolver))'"
                        }.joined(separator: " ")
                        Text(
                            verbatim: copyResolver.resolve(
                                .archiveCalledNames,
                                arguments: [.userText(titles)]
                            )
                        )
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(BaseballTheme.milestone)
                    }
                    Text(verbatim: outcome)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(record.drafted ? BaseballTheme.positive : BaseballTheme.textSecondary)
                    Text(
                        verbatim: copyResolver.resolve(
                            .archiveRecordLine,
                            arguments: [
                                .integer(record.games), .integer(record.strikeouts), .integer(record.walks),
                                .integer(record.runsAllowed), .integer(record.soulPoints),
                            ]
                        )
                    )
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(BaseballTheme.textSecondary)
                    if let signature = record.signatureLegacy {
                        let localizedSignature = HighSchoolConclusionPresentation.localizedSignature(
                            signature, resolver: copyResolver
                        )
                        VStack(alignment: .leading, spacing: 4) {
                            Text(
                                verbatim: copyResolver.resolve(
                                    .archiveSignature,
                                    arguments: [.userText(localizedSignature.title)]
                                )
                            )
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(BaseballTheme.milestone)
                            Text(verbatim: localizedSignature.evidence)
                                .font(.caption2)
                                .foregroundStyle(BaseballTheme.information)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(
                                verbatim: HighSchoolConclusionPresentation.localizedSignatureEffect(
                                    signature.effect, resolver: copyResolver
                                )
                            )
                                .font(.caption2.weight(.bold).monospacedDigit())
                                .foregroundStyle(BaseballTheme.textSecondary)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            BaseballTheme.milestone.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("archive.signatureLegacy.\(record.lifeNumber)")
                        if let candidates = record.signatureLegacyCandidates {
                            let otherTitles = candidates
                                .filter { $0.id != signature.id }
                                .map {
                                    HighSchoolConclusionPresentation.localizedSignature(
                                        $0, resolver: copyResolver
                                    ).title
                                }
                            if !otherTitles.isEmpty {
                                Text(
                                    verbatim: copyResolver.resolve(
                                        .archiveOtherSignatures,
                                        arguments: [.userText(otherTitles.joined(separator: " · "))]
                                    )
                                )
                                    .font(.caption2)
                                    .foregroundStyle(BaseballTheme.textTertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .accessibilityIdentifier("archive.signatureLegacyCandidates.\(record.lifeNumber)")
                            }
                        }
                    }
                    if let pledge = ArchivedPledgePresentation.resolve(record) {
                        let current = record.pledgeProgressCurrent ?? 0
                        let target = max(1, record.pledgeProgressTarget ?? 1)
                        let achieved = record.pledgeAchieved == true
                        let ratio = achieved ? 1_000 : record.pledgeProgressRatioPermille
                            ?? min(999, max(0, current) * 1_000 / target)
                        let progressLine = LegacyPresentation.archivedPledgeProgress(
                            current: current, target: target, rawLine: record.pledgeProgressLine,
                            resolver: copyResolver
                        )
                        let status = copyResolver.resolve(
                            achieved ? .archivePledgeStatusAchieved
                                : ratio >= 800 ? .archivePledgeStatusClose : .archivePledgeStatusIncomplete
                        )
                        let tier = LegacyPresentation.pledgeTier(pledge.tier, resolver: copyResolver)
                        let title = record.pledgeID.map {
                            LegacyPresentation.archivedPledgeTitle(
                                id: $0, rawTitle: record.pledgeTitle, resolver: copyResolver
                            )
                        } ?? pledge.title
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(
                                    verbatim: copyResolver.resolve(
                                        .archivePledgeProgress,
                                        arguments: [.userText(tier)]
                                    )
                                )
                                    .font(.caption2.weight(.heavy))
                                    .foregroundStyle(BaseballTheme.milestone)
                                Text(verbatim: title)
                                    .font(.caption.weight(.semibold))
                                Spacer(minLength: 0)
                                Text(verbatim: status)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(achieved ? BaseballTheme.positive : BaseballTheme.textTertiary)
                            }
                            Text(
                                verbatim: copyResolver.resolve(
                                    .archivePledgeReward,
                                    arguments: [.userText(progressLine), .integer(pledge.rewardPermille / 10)]
                                )
                            )
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(BaseballTheme.textSecondary)
                            ProgressView(value: Double(ratio), total: 1_000)
                                .tint(achieved ? BaseballTheme.positive : BaseballTheme.milestone)
                        }
                        .padding(8)
                        .background(BaseballTheme.milestone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(
                            copyResolver.resolve(
                                .pledgeAccessibility,
                                arguments: [
                                    .userText(tier), .userText(title), .userText(progressLine),
                                    .integer(pledge.rewardPermille / 10),
                                ]
                            ) + ". \(status)"
                        )
                    }
                    if let windTitle = HighSchoolConclusionPresentation.localizedLifeWind(
                        id: record.windID, rawTitle: record.windTitle, resolver: copyResolver
                    ) {
                        Label {
                            Text(
                                verbatim: copyResolver.resolve(
                                    .archiveWind,
                                    arguments: [.userText(windTitle)]
                                )
                            )
                        } icon: {
                            Image(systemName: "wind")
                        }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BaseballTheme.information)
                            .accessibilityIdentifier("archive.wind")
                    }
                    // 왜 그 회차가 그렇게 끝났는지. 숫자만 있으면 "3회차는 왜 실패했나"에
                    // 아카이브가 답하지 못한다.
                    if let talent = record.talent {
                        let line = TalentAbility.allCases.map {
                            "\(copyResolver.resolve($0.displayCopyToken)) \(copyResolver.resolve(talent.grade($0).displayCopyToken))"
                        }.joined(separator: " · ")
                        Text(
                            verbatim: copyResolver.resolve(
                                .archiveTalent,
                                arguments: [.userText(line)]
                            )
                        )
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(BaseballTheme.textSecondary)
                    }
                    if let awakenings = record.awakenings, !awakenings.isEmpty {
                        Text(
                            verbatim: copyResolver.resolve(
                                .archiveAwakenings,
                                arguments: [.userText(awakenings.map {
                                    HighSchoolPresentation.localizedAwakeningTitle($0, resolver: copyResolver)
                                }.joined(separator: " · "))]
                            )
                        )
                            .font(.caption)
                            .foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let karmas = record.karmas, !karmas.isEmpty {
                        Text(
                            verbatim: copyResolver.resolve(
                                .archiveHandicaps,
                                arguments: [.userText(karmas.map {
                                    HighSchoolSetupView.localizedKarmaCopy($0, resolver: copyResolver).title
                                }.joined(separator: " · "))]
                            )
                        )
                            .font(.caption)
                            .foregroundStyle(BaseballTheme.warning)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let strength = record.schoolStrength {
                        Text(
                            verbatim: copyResolver.resolve(
                                .archiveSchoolStrength,
                                arguments: [
                                    .userText(LegacyPresentation.schoolStrength(strength, resolver: copyResolver)),
                                ]
                            )
                        )
                            .font(.caption)
                            .foregroundStyle(BaseballTheme.textTertiary)
                    }
                    if !record.memories.isEmpty {
                        Text(
                            verbatim: copyResolver.resolve(
                                .archiveMemories,
                                arguments: [.userText(record.memories.map {
                                    HighSchoolConclusionPresentation.localizedMemory($0, resolver: copyResolver).title
                                }.joined(separator: " · "))]
                            )
                        )
                            .font(.caption)
                            .foregroundStyle(BaseballTheme.milestone)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    LifeShareButton(record: record)
                }
                .padding(.bottom, 10)
            }
        }
    }

    private func logLegacySeen() {
        GameAnalytics.logOnce(
            .playerLegacySeen,
            scope: "archive:\(record.careerID ?? "life-\(record.lifeNumber)")",
            properties: [
                "source": "archive",
                "life_number": record.lifeNumber,
                "drafted": record.drafted,
                "has_frozen_legacy": record.playerLegacy != nil,
            ]
        )
    }
}

private struct ArchivedRelationshipsCard: View {
    let record: HighSchoolCareerStore.LifeRecord

    @Environment(\.gameCopyResolver) private var copyResolver

    private var rows: [(LegacyUICopyKey, String, Int)] {
        var values: [(LegacyUICopyKey, String, Int)] = []
        if let name = record.coachName, let trust = record.coachTrust {
            values.append((.archiveRelationshipCoach, name, trust))
        }
        if let name = record.catcherName, let trust = record.catcherTrust {
            values.append((.archiveRelationshipCatcher, name, trust))
        }
        if let name = record.rivalName, let trust = record.rivalTrust {
            values.append((.archiveRelationshipRival, name, trust))
        }
        return values
    }

    var body: some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                Text(verbatim: copyResolver.resolve(.archiveRelationships))
                    .eyebrowStyle(BaseballTheme.information)
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    Text(verbatim: copyResolver.resolve(
                        row.0,
                        arguments: [.userText(row.1), .integer(row.2)]
                    ))
                        .font(.caption)
                        .foregroundStyle(BaseballTheme.textSecondary)
                }
            }
            .padding(10)
            .background(BaseballTheme.information.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("archive.relationships.\(record.lifeNumber)")
        }
    }
}

/// 회차 요약을 이미지로 내보낸다.
///
/// 바이럴은 유저가 만들지만 **소재는 게임이 줘야 한다**(품질 평가 P1-1). "2회차 · 서울덕성고 ·
/// 81K · 미지명" 같은 한 장이 곧 밈 포맷이다. 스크린샷을 직접 찍게 두면 UI 크롬과 상태 표시줄이
/// 함께 나가서 아무도 올리지 않는다.
struct LifeShareButton: View {
    let record: HighSchoolCareerStore.LifeRecord

    @Environment(\.displayScale) private var displayScale
    @Environment(\.gameCopyResolver) private var copyResolver
    @State private var rendered: UIImage?

    var body: some View {
        Group {
            if let rendered {
                ActivityShareButton(
                    items: [rendered],
                    subject: copyResolver.resolve(
                        .archiveShareSubject,
                        arguments: [.integer(record.lifeNumber)]
                    ),
                    onTapped: {
                        let properties: [String: Any] = ["life_number": record.lifeNumber]
                        GameAnalytics.log(.lifeCardShareTapped, properties)
                        GameAnalytics.log(.lifeCardShared, properties)
                    },
                    onCompleted: {
                        GameAnalytics.log(.lifeCardShareCompleted, ["life_number": record.lifeNumber])
                    }
                ) {
                    Label {
                        Text(verbatim: copyResolver.resolve(.archiveShare))
                    } icon: {
                        Image(systemName: "square.and.arrow.up")
                    }
                        .font(.footnote.weight(.semibold))
                        .frame(minHeight: BaseballMetrics.minimumTapTarget)
                }
                .accessibilityIdentifier("record.share.\(record.lifeNumber)")
            } else {
                // 렌더가 끝나기 전에는 자리만 잡는다. 버튼이 나타났다 사라지면 목록이 튄다.
                Label {
                    Text(verbatim: copyResolver.resolve(.archiveShare))
                } icon: {
                    Image(systemName: "square.and.arrow.up")
                }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(BaseballTheme.textTertiary)
                    .frame(minHeight: BaseballMetrics.minimumTapTarget)
            }
        }
        .task(id: record.lifeNumber) {
            rendered = Self.render(record, scale: displayScale, resolver: copyResolver)
        }
    }

    /// 카드 한 장을 이미지로 굽는다. `ImageRenderer`는 메인 액터에서만 동작한다.
    @MainActor
    static func render(
        _ record: HighSchoolCareerStore.LifeRecord,
        scale: CGFloat,
        resolver: GameCopyResolver
    ) -> UIImage? {
        let renderer = ImageRenderer(
            content: LifeSummaryCard(record: record)
                .environment(\.gameCopyResolver, resolver)
        )
        renderer.scale = max(2, scale)
        return renderer.uiImage
    }
}

/// 공유용 한 장. 화면이 아니라 **이미지 전용 레이아웃**이다.
///
/// 크롬을 넣지 않는다. 회차 번호, 이름, 학교, 결말, 기록 넉 줄, 그리고 게임 이름.
/// 이 정도가 커뮤니티 게시물의 썸네일에서 읽히는 최대치다.
struct LifeSummaryCard: View {
    let record: HighSchoolCareerStore.LifeRecord

    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(
                        verbatim: copyResolver.resolve(
                            .archivePlayerNumber,
                            arguments: [.integer(record.lifeNumber)]
                        )
                    )
                        .font(.system(.largeTitle, design: .monospaced, weight: .black))
                        .foregroundStyle(BaseballTheme.action)

                    Text(verbatim: record.playerName)
                        .font(.title.bold())
                        .foregroundStyle(BaseballTheme.textPrimary)
                        .padding(.top, 2)
                }
                Spacer(minLength: 0)
                // 회차 카드와 같은 얼굴. 공유물 두 장의 주인공이 같아야 한다.
                // 헤더 텍스트 블록(회차+이름 ≈ 76pt)과 같은 높이로 맞춘다.
                PortraitView(seed: record.portraitSeed, role: .player, size: 58,
                             playerStage: record.drafted ? .pro : .ace)
            }

            Text(
                verbatim: HighSchoolConclusionPresentation.localizedSchoolName(
                    record.schoolName, resolver: copyResolver
                )
            )
                .font(.subheadline)
                .foregroundStyle(BaseballTheme.textSecondary)
                .padding(.top, 1)

            Text(verbatim: copyResolver.resolve(record.drafted ? .archiveDrafted : .archiveUndrafted))
                .font(.system(.title2, design: .default, weight: .heavy))
                .foregroundStyle(record.drafted ? BaseballTheme.positive : BaseballTheme.negative)
                .padding(.top, 14)

            Text(
                verbatim: record.drafted
                    ? HighSchoolConclusionPresentation.localizedLifeTeamName(
                        record.teamName, resolver: copyResolver
                    ) ?? copyResolver.resolve(.archiveTeamUnknown)
                    : copyResolver.resolve(
                        .archiveEvaluation,
                        arguments: [.integer(record.evaluationScore)]
                    )
            )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BaseballTheme.textSecondary)

            Rectangle()
                .fill(BaseballTheme.border)
                .frame(height: 1)
                .padding(.vertical, 14)

            HStack(spacing: 16) {
                stat(copyResolver.resolve(.archiveStatOutings), "\(record.games)")
                stat(copyResolver.resolve(.archiveStatStrikeouts), "\(record.strikeouts)")
                stat(copyResolver.resolve(.archiveStatWalks), "\(record.walks)")
                stat(copyResolver.resolve(.archiveStatRuns), "\(record.runsAllowed)")
            }

            Text(verbatim: copyResolver.resolve(.archiveSummaryFooter))
                .font(.caption.weight(.semibold))
                .foregroundStyle(BaseballTheme.textTertiary)
                .padding(.top, 18)
        }
        .padding(28)
        .frame(width: 480, alignment: .leading)
        .background(BaseballTheme.canvas)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(verbatim: label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(BaseballTheme.textTertiary)
            Text(verbatim: value)
                .font(.system(.title3, design: .monospaced, weight: .bold))
                .foregroundStyle(BaseballTheme.textPrimary)
        }
    }
}
