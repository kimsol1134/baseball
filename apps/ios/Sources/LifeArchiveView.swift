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

    var body: some View {
        BaseballCard(title: "지금까지 키운 선수 \(records.count)명") {
            VStack(alignment: .leading, spacing: 0) {
                if !records.isEmpty {
                    PlayerLineageRibbon(records: orderedRecords)
                        .padding(.bottom, 10)
                    Rectangle()
                        .fill(BaseballTheme.border.opacity(0.35))
                        .frame(height: 1)
                }
                if records.count >= 2 {
                    HStack(spacing: 16) {
                        archiveStat("지명", "\(totals.drafted)/\(records.count)")
                        archiveStat("통산 K", "\(totals.strikeouts)")
                        archiveStat("최고 평가", "\(totals.bestEvaluation)")
                        archiveStat("모은 계승 포인트", "\(totals.soul)")
                    }
                    .padding(.bottom, 10)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("지난 선수 통산. 지명 \(totals.drafted)회, 통산 탈삼진 \(totals.strikeouts), 최고 평가 \(totals.bestEvaluation)점, 모은 계승 포인트 \(totals.soul)")
                    Rectangle()
                        .fill(BaseballTheme.border.opacity(0.35))
                        .frame(height: 1)
                }
                if !records.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        if let next = nextStrikeoutMilestone {
                            Text("통산 탈삼진 \(next)까지 \(next - totals.strikeouts)개 — 모든 선수의 기록은 영원히 쌓입니다.")
                        }
                        if let best = bestStrikeoutLife, best.strikeouts > 0 {
                            Text("한 선수 최다 탈삼진 \(best.strikeouts) (\(best.lifeNumber)번째 선수) — 역대 기록은 깨라고 있는 것입니다.")
                        }
                        Text("별명 도감 \(collectedNicknames.count)/\(NicknameRules.catalogCount)"
                             + (collectedNicknames.count >= NicknameRules.catalogCount
                                ? " — 세상이 부르는 모든 이름을 모았습니다."
                                : " — 아직 못 얻은 이름이 있습니다."))
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
    }

    private func archiveStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(BaseballTheme.textTertiary)
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.bold))
                .foregroundStyle(BaseballTheme.textPrimary)
        }
    }
}

/// 숫자 목록보다 먼저 얼굴과 이름을 보여 주는 선수 계보. 오래 할수록 통산 수치뿐 아니라
/// 함께 키운 사람들의 행렬이 길어진다.
private struct PlayerLineageRibbon: View {
    let records: [HighSchoolCareerStore.LifeRecord]

    private var ordered: [HighSchoolCareerStore.LifeRecord] {
        LifeArchiveOrdering.newestFirst(records)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("함께 키운 선수들")
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
                                seed: record.playerName,
                                role: .player,
                                size: 34,
                                playerStage: record.drafted ? .pro : .ace
                            )
                            Text(record.playerName)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(BaseballTheme.textPrimary)
                                .lineLimit(1)
                            Text("\(record.lifeNumber)번째")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(BaseballTheme.textTertiary)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(record.lifeNumber)번째 선수 \(record.playerName), \(record.drafted ? "지명" : "미지명")")
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
                    PortraitView(seed: record.playerName, role: .player, size: 30,
                                 playerStage: record.drafted ? .pro : .ace)
                    Text("\(record.lifeNumber)번째 선수")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(BaseballTheme.textPrimary)
                    Text(record.schoolName ?? "학교 미정")
                        .font(.footnote)
                        .foregroundStyle(BaseballTheme.textSecondary)
                    Spacer(minLength: 0)
                    Text(record.drafted ? "지명" : "미지명")
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
            .accessibilityLabel("\(record.lifeNumber)번째 선수, \(record.schoolName ?? "학교 미정"), \(record.outcomeLine)")

            if expanded {
                VStack(alignment: .leading, spacing: 6) {
                    LifeCardShareButton(record: record)
                        .padding(.bottom, 2)
                    PlayerLegacyQuote(
                        legacy: record.playerLegacy ?? PlayerBondStory.legacy(for: record),
                        heading: "\(record.playerName)이 남긴 말"
                    )
                    .padding(.bottom, 2)
                    .accessibilityIdentifier("archive.playerLegacy.\(record.lifeNumber)")
                    .onAppear(perform: logLegacySeen)
                    if let chronicle = record.chronicle, !chronicle.isEmpty {
                        ForEach(chronicle, id: \.self) { line in
                            Text(line)
                                .font(.caption)
                                .foregroundStyle(BaseballTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Rectangle().fill(BaseballTheme.border.opacity(0.3)).frame(height: 1)
                    }
                    if let nicknames = record.nicknames, !nicknames.isEmpty {
                        Text("세상이 부른 이름: \(nicknames.map { "'\($0)'" }.joined(separator: " "))")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(BaseballTheme.milestone)
                    }
                    Text(record.outcomeLine)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(record.drafted ? BaseballTheme.positive : BaseballTheme.textSecondary)
                    Text("\(record.games)등판 · \(record.strikeouts)K \(record.walks)BB \(record.runsAllowed)실점 · 계승 포인트 +\(record.soulPoints)")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(BaseballTheme.textSecondary)
                    if let signature = record.signatureLegacy {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("대표 유산 · \(signature.title)")
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(BaseballTheme.milestone)
                            Text(signature.evidence.summary)
                                .font(.caption2)
                                .foregroundStyle(BaseballTheme.information)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(HighSchoolSetupView.signatureLegacyEffectLine(signature.effect))
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
                                .map(\.title)
                            if !otherTitles.isEmpty {
                                Text("함께 발견한 유산 · \(otherTitles.joined(separator: " · "))")
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
                        let progressLine = record.pledgeProgressLine ?? "현재 \(current) / 목표 \(target)"
                        let status = achieved ? "이행" : ratio >= 800 ? "아슬아슬" : "미완"
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text("\(pledge.tier.title) 목표")
                                    .font(.caption2.weight(.heavy))
                                    .foregroundStyle(BaseballTheme.milestone)
                                Text(pledge.title)
                                    .font(.caption.weight(.semibold))
                                Spacer(minLength: 0)
                                Text(status)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(achieved ? BaseballTheme.positive : BaseballTheme.textTertiary)
                            }
                            Text("\(progressLine) · 보상 계승 포인트 +\(pledge.rewardPermille / 10)%")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(BaseballTheme.textSecondary)
                            ProgressView(value: Double(ratio), total: 1_000)
                                .tint(achieved ? BaseballTheme.positive : BaseballTheme.milestone)
                        }
                        .padding(8)
                        .background(BaseballTheme.milestone.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(pledge.accessibilityLabel(
                            progressLine: progressLine, status: status
                        ))
                    }
                    if let windTitle = record.windTitle {
                        Label("3년의 바람 · \(windTitle)", systemImage: "wind")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BaseballTheme.information)
                            .accessibilityIdentifier("archive.wind")
                    }
                    // 왜 그 회차가 그렇게 끝났는지. 숫자만 있으면 "3회차는 왜 실패했나"에
                    // 아카이브가 답하지 못한다.
                    if let talent = record.talent {
                        Text("재능 · " + TalentAbility.allCases
                            .map { "\($0.label) \(talent.grade($0).label)" }
                            .joined(separator: " · "))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(BaseballTheme.textSecondary)
                    }
                    if let awakenings = record.awakenings, !awakenings.isEmpty {
                        Text("각성 · " + awakenings.map { HighSchoolPresentation.awakening($0).title }
                            .joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let karmas = record.karmas, !karmas.isEmpty {
                        Text("핸디캡 · " + karmas.map { HighSchoolPresentation.karma($0).title }
                            .joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(BaseballTheme.warning)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let strength = record.schoolStrength {
                        Text("학교 강점 · \(strength)")
                            .font(.caption)
                            .foregroundStyle(BaseballTheme.textTertiary)
                    }
                    if !record.memories.isEmpty {
                        Text("가져간 기억 · " + record.memories.map { HighSchoolPresentation.memory($0).title }.joined(separator: " · "))
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

/// 회차 요약을 이미지로 내보낸다.
///
/// 바이럴은 유저가 만들지만 **소재는 게임이 줘야 한다**(품질 평가 P1-1). "2회차 · 서울덕성고 ·
/// 81K · 미지명" 같은 한 장이 곧 밈 포맷이다. 스크린샷을 직접 찍게 두면 UI 크롬과 상태 표시줄이
/// 함께 나가서 아무도 올리지 않는다.
struct LifeShareButton: View {
    let record: HighSchoolCareerStore.LifeRecord

    @Environment(\.displayScale) private var displayScale
    @State private var rendered: UIImage?

    var body: some View {
        Group {
            if let rendered {
                ActivityShareButton(
                    items: [rendered],
                    subject: "\(record.lifeNumber)번째 선수 요약",
                    onTapped: {
                        let properties: [String: Any] = ["life_number": record.lifeNumber]
                        GameAnalytics.log(.lifeCardShareTapped, properties)
                        GameAnalytics.log(.lifeCardShared, properties)
                    },
                    onCompleted: {
                        GameAnalytics.log(.lifeCardShareCompleted, ["life_number": record.lifeNumber])
                    }
                ) {
                    Label("이 선수 기록 공유", systemImage: "square.and.arrow.up")
                        .font(.footnote.weight(.semibold))
                        .frame(minHeight: BaseballMetrics.minimumTapTarget)
                }
                .accessibilityIdentifier("record.share.\(record.lifeNumber)")
            } else {
                // 렌더가 끝나기 전에는 자리만 잡는다. 버튼이 나타났다 사라지면 목록이 튄다.
                Label("이 선수 기록 공유", systemImage: "square.and.arrow.up")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(BaseballTheme.textTertiary)
                    .frame(minHeight: BaseballMetrics.minimumTapTarget)
            }
        }
        .task(id: record.lifeNumber) {
            rendered = Self.render(record, scale: displayScale)
        }
    }

    /// 카드 한 장을 이미지로 굽는다. `ImageRenderer`는 메인 액터에서만 동작한다.
    @MainActor
    static func render(_ record: HighSchoolCareerStore.LifeRecord, scale: CGFloat) -> UIImage? {
        let renderer = ImageRenderer(content: LifeSummaryCard(record: record))
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(record.lifeNumber)번째 선수")
                        .font(.system(.largeTitle, design: .monospaced, weight: .black))
                        .foregroundStyle(BaseballTheme.action)

                    Text(record.playerName)
                        .font(.title.bold())
                        .foregroundStyle(BaseballTheme.textPrimary)
                        .padding(.top, 2)
                }
                Spacer(minLength: 0)
                // 회차 카드와 같은 얼굴. 공유물 두 장의 주인공이 같아야 한다.
                // 헤더 텍스트 블록(회차+이름 ≈ 76pt)과 같은 높이로 맞춘다.
                PortraitView(seed: record.playerName, role: .player, size: 58,
                             playerStage: record.drafted ? .pro : .ace)
            }

            Text(record.schoolName ?? "학교 미정")
                .font(.subheadline)
                .foregroundStyle(BaseballTheme.textSecondary)
                .padding(.top, 1)

            Text(record.drafted ? "지명" : "미지명")
                .font(.system(.title2, design: .default, weight: .heavy))
                .foregroundStyle(record.drafted ? BaseballTheme.positive : BaseballTheme.negative)
                .padding(.top, 14)

            Text(record.drafted ? (record.teamName ?? "구단 미정") : "평가 \(record.evaluationScore)점")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BaseballTheme.textSecondary)

            Rectangle()
                .fill(BaseballTheme.border)
                .frame(height: 1)
                .padding(.vertical, 14)

            HStack(spacing: 16) {
                stat("등판", "\(record.games)")
                stat("탈삼진", "\(record.strikeouts)")
                stat("볼넷", "\(record.walks)")
                stat("실점", "\(record.runsAllowed)")
            }

            Text("야구 못하면 또 환생함")
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
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(BaseballTheme.textTertiary)
            Text(value)
                .font(.system(.title3, design: .monospaced, weight: .bold))
                .foregroundStyle(BaseballTheme.textPrimary)
        }
    }
}
