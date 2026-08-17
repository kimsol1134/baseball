import SwiftUI
import SimulationCore
import UIKit

struct ChapterReviewCard: View {
    let state: HighSchoolCareerSnapshot
    /// 이번 챕터에 오른 능력치(라벨→증가폭). 첫 세션의 마지막 화면이 요약문 한 줄이면
    /// 40분의 훈련이 감정 없이 접힌다 — 여기가 작은 정산이어야 한다(2차 패널 P1).
    let gains: [String: Int]
    let trainingCount: Int
    let onContinue: () -> Void
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        let title = HighSchoolPresentation.localizedChapterReviewTitle(state.chapter, resolver: copyResolver)
        let verdict = HighSchoolPresentation.localizedChapterReviewVerdict(state.performance, resolver: copyResolver)
        let statLine = HighSchoolPresentation.localizedChapterReviewStatLine(state.performance, resolver: copyResolver)
        let gainRows = HighSchoolPresentation.localizedChapterReviewGainRows(gains, resolver: copyResolver)
        let growthTitle = copyResolver.resolve(AppCopyKey.chapterReviewGrowthTitle)
        let abilitiesTitle = copyResolver.resolve(AppCopyKey.chapterReviewAbilitiesTitle)
        let continueAction = copyResolver.resolve(AppCopyKey.chapterReviewContinue)
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            BaseballCard(title: title, tone: .milestone) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: verdict)
                        .font(.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Divider()
                    Text(verbatim: statLine)
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(BaseballTheme.textSecondary)
                }
            }
            // 성장 정산 — 훈련이 실제로 몸에 남긴 것. 없으면 없다고 적는다.
            BaseballCard(title: growthTitle, tone: .raised) {
                if gainRows.isEmpty {
                    Text(verbatim: HighSchoolPresentation.localizedChapterReviewGrowthEmpty(
                        trainingCount: trainingCount,
                        resolver: copyResolver
                    ))
                        .font(.footnote)
                        .foregroundStyle(BaseballTheme.textSecondary)
                } else {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(gainRows) { row in
                            HStack {
                                Text(verbatim: row.label).font(.subheadline)
                                Spacer()
                                Text(verbatim: "+\(row.delta)")
                                    .font(.subheadline.weight(.heavy).monospacedDigit())
                                    .foregroundStyle(BaseballTheme.milestone)
                            }
                        }
                        Text(verbatim: HighSchoolPresentation.localizedChapterReviewGrowthSummary(
                            trainingCount: trainingCount,
                            resolver: copyResolver
                        ))
                            .font(.caption2)
                            .foregroundStyle(BaseballTheme.textTertiary)
                    }
                }
            }
            BaseballCard(title: abilitiesTitle) {
                VStack(alignment: .leading, spacing: 10) {
                    // 장 정산은 "어디까지 갈 수 있나"를 다시 읽는 자리다. 재능(한계)이
                    // 빠지면 다음 장의 훈련 계획을 세울 근거가 사라진다.
                    let talent = state.talent ?? .unlimited
                    PrologueAbilityGauge(
                        labelToken: TalentAbility.stuff.displayCopyToken,
                        value: state.pitcher.stuff,
                        talent: talent.stuff,
                        preservesKoreanAccessibility: true
                    )
                    PrologueAbilityGauge(
                        labelToken: TalentAbility.command.displayCopyToken,
                        value: state.pitcher.command,
                        talent: talent.command,
                        preservesKoreanAccessibility: true
                    )
                    PrologueAbilityGauge(
                        labelToken: TalentAbility.movement.displayCopyToken,
                        value: state.pitcher.movement,
                        talent: talent.movement,
                        preservesKoreanAccessibility: true
                    )
                    PrologueAbilityGauge(
                        labelToken: TalentAbility.stamina.displayCopyToken,
                        value: state.pitcher.stamina,
                        talent: talent.stamina,
                        preservesKoreanAccessibility: true
                    )
                }
            }
            if let rivalLine = HighSchoolPresentation.localizedChapterReviewRivalLine(
                state.rival,
                resolver: copyResolver
            ) {
                Text(verbatim: rivalLine)
                    .font(.footnote)
                    .foregroundStyle(BaseballTheme.textSecondary)
            }
            PrimaryButton(title: continueAction, identifier: "hs.chapter.continue", action: onContinue)
        }
    }
}

/// 대회 대진 — 같은 경기도 "왕중왕전 준결승"이라는 무대 위에서는 무게가 다르다.
/// 커널 일정은 그대로다. 이 카드는 세계를 보여 줄 뿐, 일정에 대해 거짓말하지 않는다.
struct TournamentCard: View {
    let state: HighSchoolCareerSnapshot
    let school: SchoolSnapshot
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        let playerSchoolName = school.name
        let field = TournamentBracket.field(
            careerID: state.careerID, chapterNumber: state.chapter.number, playerSchool: playerSchoolName
        )
        let playerSchoolCopy = CopyToken.schoolSelection(
            rawRegion: state.identity.region,
            schoolID: school.id
        )
        let tournamentName = HighSchoolPresentation.localizedTournamentName(
            chapterNumber: state.chapter.number,
            resolver: copyResolver
        )
        let aceStart = HighSchoolPresentation.localizedTournamentAceStart(
            round: field.playerRound,
            resolver: copyResolver
        )
        let dash = copyResolver.resolve(AppCopyKey.tournamentDash)
        let nationalNote = copyResolver.resolve(AppCopyKey.tournamentNationalNote)
        BaseballCard(title: tournamentName, tone: .milestone) {
            VStack(alignment: .leading, spacing: 8) {
                // 대회 배너 — 무대는 글보다 그림이 먼저 말한다.
                if UIImage(named: "TournamentBanner\(state.chapter.number)") != nil {
                    Image("TournamentBanner\(state.chapter.number)")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 84)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        // 배너 아래를 카드 배경으로 녹여 사진과 카드가 한 장으로 붙는다(QA P2-9).
                        .overlay {
                            LinearGradient(colors: [.clear, BaseballTheme.surface.opacity(0.55)],
                                           startPoint: .center, endPoint: .bottom)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .allowsHitTesting(false)
                        }
                }
                Text(verbatim: aceStart)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(BaseballTheme.milestone)
                // 대진: 두 팀씩 한 쌍. 내 학교가 굵게 빛난다.
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(0..<4, id: \.self) { pair in
                        HStack(spacing: 6) {
                            bracketName(
                                field.schools[pair * 2],
                                playerSchoolName: playerSchoolName,
                                playerSchoolCopy: playerSchoolCopy
                            )
                            Text(verbatim: dash).font(.caption2).foregroundStyle(BaseballTheme.textTertiary)
                            bracketName(
                                field.schools[pair * 2 + 1],
                                playerSchoolName: playerSchoolName,
                                playerSchoolCopy: playerSchoolCopy
                            )
                        }
                    }
                }
                Text(verbatim: nationalNote)
                    .font(.caption2)
                    .foregroundStyle(BaseballTheme.textTertiary)
            }
        }
        .accessibilityIdentifier("hs.tournament")
    }

    private func bracketName(
        _ rawName: String,
        playerSchoolName: String,
        playerSchoolCopy: SchoolSelectionCopyDescriptor
    ) -> some View {
        let displayName = rawName == playerSchoolName
            ? copyResolver.resolve(playerSchoolCopy.schoolNameToken)
            : HighSchoolPresentation.localizedTournamentOpponentSchool(
                rawSchoolName: rawName,
                resolver: copyResolver
            )
        return Text(verbatim: displayName)
            .font(.footnote.weight(rawName == playerSchoolName ? .bold : .regular))
            .foregroundStyle(rawName == playerSchoolName ? BaseballTheme.action : BaseballTheme.textSecondary)
    }
}

/// 이번 챕터의 숙제. "3년 뒤 드래프트"는 너무 멀다 — 오늘 훈련 하나를
/// 누르게 만드는 것은 이번 챕터의 숫자다.
struct ChapterGoalCard: View {
    let state: HighSchoolCareerSnapshot
    let career: HighSchoolCareerStore
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        let goal = ChapterGoal.goal(careerID: state.careerID, chapterNumber: state.chapter.number)
        let progress = max(0, state.performance.strikeouts - career.chapterStartStrikeouts)
        let done = career.goalCelebratedChapter == state.chapter.number || progress >= goal.targetStrikeouts
        let title = HighSchoolPresentation.localizedChapterGoalTitle(goal, resolver: copyResolver)
        let detail = done
            ? copyResolver.resolve(AppCopyKey.chapterGoalCompleted)
            : HighSchoolPresentation.localizedChapterGoalDetail(goal, resolver: copyResolver)
        let progressLabel = HighSchoolPresentation.localizedChapterGoalProgress(
            progress: min(progress, goal.targetStrikeouts),
            targetStrikeouts: goal.targetStrikeouts,
            resolver: copyResolver
        )
        BaseballCard(title: title, tone: done ? .positive : .raised) {
            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: detail)
                    .font(.footnote)
                    .foregroundStyle(BaseballTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    ProgressView(value: Double(min(progress, goal.targetStrikeouts)),
                                 total: Double(goal.targetStrikeouts))
                        .tint(done ? BaseballTheme.positive : BaseballTheme.action)
                    Text(verbatim: progressLabel)
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(done ? BaseballTheme.positive : BaseballTheme.textSecondary)
                }
            }
        }
        .accessibilityIdentifier("hs.chapterGoal")
    }
}

/// 어딘가의 게시판에서 모르는 사람들이 내 선수 얘기를 하고 있다.
///
/// 기사와 능력치는 공식 세계다. 애착은 비공식 세계에서 완성된다 — 잘 던지면
/// 감탄하고, 볼넷이 쌓이면 냉정하게 놀리는 익명의 목소리. 그 냉정함까지가 세상이다.
struct CommunityBuzzCard: View {
    private enum Line {
        case reaction(CommunityBuzzReactionLine)
        case news(CommunityBuzzRivalNewsLine)
    }

    let titleKey: GameCopyKey
    let footnoteKey: GameCopyKey
    private let lines: [Line]
    @Environment(\.gameCopyResolver) private var copyResolver

    init(reactionLines: [CommunityBuzzReactionLine]) {
        titleKey = AppCopyKey.communityBuzzTitle
        footnoteKey = AppCopyKey.communityBuzzFootnote
        lines = reactionLines.map(Line.reaction)
    }

    init(newsLines: [CommunityBuzzRivalNewsLine]) {
        titleKey = AppCopyKey.communityBuzzWorldTitle
        footnoteKey = AppCopyKey.communityBuzzWorldFootnote
        lines = newsLines.map(Line.news)
    }

    var body: some View {
        BaseballCard(title: copyResolver.resolve(titleKey)) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .top, spacing: 6) {
                        Text("└")
                            .font(.caption2)
                            .foregroundStyle(BaseballTheme.textTertiary)
                        Text(verbatim: localized(line))
                            .font(.footnote)
                            .foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Text(verbatim: copyResolver.resolve(footnoteKey))
                    .font(.caption2)
                    .foregroundStyle(BaseballTheme.textTertiary)
            }
        }
        .accessibilityIdentifier("hs.buzz")
    }

    private func localized(_ line: Line) -> String {
        switch line {
        case .reaction(let value):
            CommunityBuzzPresentation.localizedReaction(value, resolver: copyResolver)
        case .news(let value):
            CommunityBuzzPresentation.localizedNews(value, resolver: copyResolver)
        }
    }
}

/// 이 회차가 살아온 순간들. 결과(기록 카드)가 아니라 과정을 보여 준다 —
/// 드래프트 직전과 회차를 접는 순간, 두 번의 되돌아보는 자리에 선다.
struct ChronicleCard: View {
    let entries: [HighSchoolCareerStore.ChronicleEntry]
    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        if !entries.isEmpty {
            BaseballCard(title: copyResolver.resolve(AppCopyKey.conclusionChronicleTitle)) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                        let localized = HighSchoolConclusionPresentation.localizedChronicleEntry(
                            entry, resolver: copyResolver
                        )
                        VStack(alignment: .leading, spacing: 1) {
                            // localization-safe: resolved-copy
                            Text(localized.stage)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(BaseballTheme.textTertiary)
                            // localization-safe: resolved-copy
                            Text(localized.text)
                                .font(.footnote)
                                .foregroundStyle(BaseballTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .accessibilityIdentifier("hs.chronicle")
        }
    }
}
