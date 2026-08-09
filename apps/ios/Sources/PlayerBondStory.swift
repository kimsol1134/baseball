import SwiftUI
import SimulationCore

/// 지금 선수가 사용자에게 건네는 한마디를 만들기 위한 최소 상태.
///
/// 능력치 전체를 뷰에 넘기지 않고, 마음을 바꿀 수 있는 값만 모은다. 같은 상태에서는
/// 언제나 같은 문장이 나와야 저장·재실행 때 선수가 다른 사람이 되지 않는다.
struct PlayerHeartContext: Equatable {
    let playerName: String
    let phase: HighSchoolCareerPhase
    let fatigue: Int
    let armRisk: Int
    let injuryRecovery: Int
    let fanInterest: Int
    let managerTrust: Int
    let catcherTrust: Int
    let rivalTrust: Int
    let personalityTitle: String?
    let drafted: Bool?

    init(
        playerName: String,
        phase: HighSchoolCareerPhase,
        fatigue: Int = 0,
        armRisk: Int = 0,
        injuryRecovery: Int = 0,
        fanInterest: Int = 0,
        managerTrust: Int = 0,
        catcherTrust: Int = 0,
        rivalTrust: Int = 0,
        personalityTitle: String? = nil,
        drafted: Bool? = nil
    ) {
        self.playerName = playerName
        self.phase = phase
        self.fatigue = fatigue
        self.armRisk = armRisk
        self.injuryRecovery = injuryRecovery
        self.fanInterest = fanInterest
        self.managerTrust = managerTrust
        self.catcherTrust = catcherTrust
        self.rivalTrust = rivalTrust
        self.personalityTitle = personalityTitle
        self.drafted = drafted
    }

    init(state: HighSchoolCareerSnapshot, personality: Personality?) {
        self.init(
            playerName: state.identity.name,
            phase: state.phase,
            fatigue: state.fatigue,
            armRisk: state.armRisk ?? 0,
            injuryRecovery: state.injuryRecovery ?? 0,
            fanInterest: state.fanInterest,
            managerTrust: state.managerTrust ?? state.relationshipTrust,
            catcherTrust: state.catcherTrust ?? state.relationshipTrust,
            rivalTrust: state.rivalTrust ?? 0,
            personalityTitle: personality?.title,
            drafted: state.draftResult.map { $0.outcome == .drafted }
        )
    }
}

struct PlayerHeartline: Equatable {
    let mood: String
    let words: String
}

/// 선수의 속마음 카드가 실제로 나타난 이유. raw value는 분석에서 오래 쓰는 안정 ID다.
enum PlayerHeartlineBranch: String, Equatable {
    case injuryRecovery = "injury_recovery"
    case armWarning = "arm_warning"
    case fatigueWarning = "fatigue_warning"
    case chapterReview = "chapter_review"
    case awakening
    case draft
    case legacy
    case completed
}

struct PlayerHeartlinePresentation: Equatable {
    let branch: PlayerHeartlineBranch
    let line: PlayerHeartline
}

/// 한 선수가 떠날 때 동결해 두는 이야기.
///
/// 카피 규칙이 훗날 달라져도 이미 끝난 선수의 편지는 바뀌지 않는다. optional로
/// `LifeRecord`에 들어가므로 이 기능 이전의 저장본도 그대로 열린다.
struct PlayerLegacy: Codable, Equatable {
    let title: String
    let definingMoment: String
    let farewell: String
}

enum PlayerBondStory {
    /// 상시 상태 카드가 아니라, 선수가 실제로 말을 걸 만한 순간만 고른다.
    /// 첫 공식 경기 전에는 플레이 방법을 익히는 주 행동이 우선이므로 항상 숨긴다.
    static func heartlinePresentation(
        for context: PlayerHeartContext,
        importantGamesCompleted: Int
    ) -> PlayerHeartlinePresentation? {
        guard importantGamesCompleted > 0 else { return nil }

        let branch: PlayerHeartlineBranch
        if context.injuryRecovery > 0 {
            branch = .injuryRecovery
        } else if context.armRisk >= 55 {
            branch = .armWarning
        } else if context.fatigue >= 80 {
            branch = .fatigueWarning
        } else {
            switch context.phase {
            case .chapterReview: branch = .chapterReview
            case .awakening: branch = .awakening
            case .draft: branch = .draft
            case .legacy: branch = .legacy
            case .completed: branch = .completed
            case .prologue, .schoolSelection, .training, .relationship, .importantGame:
                return nil
            }
        }
        return PlayerHeartlinePresentation(branch: branch, line: heartline(for: context))
    }

    static func heartlinePresentation(
        for state: HighSchoolCareerSnapshot,
        personality: Personality?
    ) -> PlayerHeartlinePresentation? {
        heartlinePresentation(
            for: PlayerHeartContext(state: state, personality: personality),
            importantGamesCompleted: state.performance.importantGamesCompleted
        )
    }

    /// 상태 변화가 선수의 말로 돌아온다. 수치가 오르내려도 아무 반응이 없으면 사용자는
    /// 선수를 키운 것이 아니라 표를 관리한 느낌만 받는다.
    static func heartline(for context: PlayerHeartContext) -> PlayerHeartline {
        if context.injuryRecovery > 0 {
            return PlayerHeartline(
                mood: "다시 던지기 위해",
                words: "지금은 서두르지 말아 줘요. 제대로 돌아와서 오래 던지고 싶어요."
            )
        }
        if context.armRisk >= 55 {
            return PlayerHeartline(
                mood: "팔이 보내는 신호",
                words: "오늘은 공보다 내 팔을 먼저 봐 줬으면 해요. 다음 경기에도 함께 서고 싶어요."
            )
        }
        if context.fatigue >= 80 {
            return PlayerHeartline(
                mood: "조금 지친 마음",
                words: "조금 지쳤어요. 쉬는 날까지 같이 골라 주면 다시 힘을 낼 수 있어요."
            )
        }
        if context.phase == .importantGame {
            return PlayerHeartline(
                mood: "큰 경기를 앞두고",
                words: "무섭지 않다면 거짓말이에요. 그래도 뒤에서 보고 있다고 생각하면 한 공 더 던질 수 있어요."
            )
        }
        if context.phase == .awakening {
            return PlayerHeartline(
                mood: "달라지기 직전",
                words: "어떤 공을 갖게 될지보다, 어떤 투수가 될지 같이 골라 줘요."
            )
        }
        if context.phase == .chapterReview {
            return PlayerHeartline(
                mood: "한 시기를 지나며",
                words: "여기까지 온 나를 한번 돌아봐 줘요. 다음 이야기에서도 함께 답을 찾고 싶어요."
            )
        }
        if context.phase == .draft {
            return PlayerHeartline(
                mood: "이름을 기다리며",
                words: "이제 내 이름이 불릴 차례를 기다려요. 어떤 결과여도 우리가 보낸 3년은 기억해 줘요."
            )
        }
        if context.phase == .legacy || context.phase == .completed {
            if context.drafted == true {
                return PlayerHeartline(
                    mood: "새 유니폼 앞에서",
                    words: "내 이름이 불렸어요. 우리가 보낸 3년까지 데리고 더 멀리 가 볼게요."
                )
            }
            return PlayerHeartline(
                mood: "3년을 마치며",
                words: "결과가 아프긴 해요. 그래도 내가 보낸 3년까지 실패로 부르지는 말아 줘요."
            )
        }
        if context.fanInterest >= 30 {
            return PlayerHeartline(
                mood: "이름을 듣는 요즘",
                words: "내 이름을 불러 주는 사람이 늘었어요. 그래도 처음부터 봐 준 사람은 당신이잖아요."
            )
        }
        if context.catcherTrust >= 70 {
            return PlayerHeartline(
                mood: "혼자가 아닌 마운드",
                words: "이제 포수의 미트만 봐도 마음이 놓여요. 우리가 만든 호흡을 오래 가져가고 싶어요."
            )
        }
        if context.managerTrust >= 70 {
            return PlayerHeartline(
                mood: "믿음을 받는 중",
                words: "감독님이 내게 맡기는 일이 늘었어요. 그 믿음을 실력으로 돌려주고 싶어요."
            )
        }
        if context.rivalTrust >= 70 {
            return PlayerHeartline(
                mood: "숙적을 바라보며",
                words: "저 아이가 있어서 여기까지 왔어요. 다음에도 피하지 않고 정면으로 던질게요."
            )
        }

        switch context.personalityTitle {
        case "불같은 승부사":
            return PlayerHeartline(mood: "내가 믿는 방식", words: "물러서지 않을게요. 끝낼 공을 같이 골라 줘요.")
        case "조용한 버팀목":
            return PlayerHeartline(mood: "내가 믿는 방식", words: "많이 말하지 않아도 괜찮아요. 같이 정한 루틴은 끝까지 지킬게요.")
        case "차가운 분석가":
            return PlayerHeartline(mood: "내가 믿는 방식", words: "왜 이 공을 던지는지 알면 흔들리지 않아요. 다음 답도 같이 찾아봐요.")
        case "유연한 중심":
            return PlayerHeartline(mood: "내가 믿는 방식", words: "정답 하나만 고집하지 않을게요. 오늘 필요한 투수가 되어 볼게요.")
        default:
            return PlayerHeartline(
                mood: "아직 자라는 중",
                words: "아직 어떤 투수가 될지는 모르겠어요. 오늘 함께 고른 하나가 나를 만들겠죠."
            )
        }
    }

    /// 끝난 기록만으로 편지를 만든다. 게임 밖의 임의 서사를 덧붙이지 않고, 실제 결말·성격·
    /// 가져간 기억을 재료로 삼는다.
    static func legacy(for record: HighSchoolCareerStore.LifeRecord) -> PlayerLegacy {
        let title: String
        if record.signatureLegacy != nil {
            title = "자기 공을 남긴 투수"
        } else if record.drafted {
            title = "끝까지 키워 낸 투수"
        } else if record.pledgeAchieved == true {
            title = "자기 목표를 지킨 투수"
        } else if record.runsAllowed == 0, record.games > 0 {
            title = "끝까지 홈을 지킨 투수"
        } else if record.strikeouts >= 30 {
            title = "삼진을 믿었던 투수"
        } else {
            title = "함께 3년을 보낸 투수"
        }

        let definingMoment = definingMoment(for: record)
        let opening: String
        if record.drafted {
            opening = "내 이름이 불릴 때, 제일 먼저 우리가 한 땀씩 키운 공이 떠올랐어요."
        } else if let signatureLegacy = record.signatureLegacy {
            opening = "프로의 부름은 없었지만, \(signatureLegacy.evidence.summary) 그 시간까지 사라지는 건 아니죠."
        } else {
            opening = "프로의 부름은 없었지만, 내가 보낸 3년까지 사라지는 건 아니죠."
        }
        let closing: String
        if record.drafted, let signatureLegacy = record.signatureLegacy {
            closing = "우리가 만든 ‘\(signatureLegacy.title)’과 함께 더 큰 마운드로 가 볼게요."
        } else if let signatureLegacy = record.signatureLegacy {
            closing = "‘\(signatureLegacy.title)’이 언젠가 다른 마운드의 시작에 닿기를 바라요."
        } else if !record.memories.isEmpty {
            // 대표 유산 도입 전 기록도 당시 실제로 고른 계승을 말해야 한다. 동시에 기억
            // 하나 때문에 3년 동안 선택으로 만든 성격이 사라지지 않게, 선수다운 목소리와
            // 실제 계승을 한 문장에 함께 남긴다.
            switch record.personality {
            case "불같은 승부사":
                closing = "마지막까지 물러서지 않았던 마음과 내가 고른 기억은 다음 선수의 첫 공에 이어질 거예요."
            case "조용한 버팀목":
                closing = "말없이 오래 쌓은 하루들과 내가 고른 기억은 다음 선수의 첫 공에 이어질 거예요."
            case "차가운 분석가":
                closing = "매번 그 공을 고른 이유와 내가 고른 기억은 다음 선수의 첫 공에 이어질 거예요."
            case "유연한 중심":
                closing = "상황마다 찾은 답과 내가 고른 기억은 다음 선수의 첫 공에 이어질 거예요."
            default:
                closing = "내가 고른 기억은 다음 선수의 첫 공에 이어질 거예요."
            }
        } else {
            switch record.personality {
            case "불같은 승부사": closing = "마지막까지 물러서지 않았던 마음만은 오래 기억해 주세요."
            case "조용한 버팀목": closing = "말없이 오래 쌓은 하루들이 누군가의 시작에 힘이 되면 좋겠어요."
            case "차가운 분석가": closing = "결과뿐 아니라, 내가 매번 그 공을 고른 이유도 기억해 주세요."
            case "유연한 중심": closing = "내 기록이 다른 누군가에게 자기만의 답을 찾는 힌트가 되면 좋겠어요."
            default: closing = "내가 남긴 기록이 언젠가 다른 마운드의 시작에 힘이 되면 좋겠어요."
            }
        }

        return PlayerLegacy(
            title: title,
            definingMoment: definingMoment,
            farewell: "\(opening) \(closing)"
        )
    }

    private static func definingMoment(for record: HighSchoolCareerStore.LifeRecord) -> String {
        if let signatureLegacy = record.signatureLegacy {
            return signatureLegacy.evidence.summary
        }
        guard let chronicle = record.chronicle, !chronicle.isEmpty else {
            if record.drafted {
                return "\(record.teamName ?? "프로 구단")이 \(record.playerName)의 이름을 불렀던 날"
            }
            return "\(record.schoolName ?? "고교")에서 마지막 공을 던진 날"
        }
        let priorities = ["별명", "만개", "숙적", "무실점", "탈삼진", "지명"]
        for keyword in priorities {
            if let line = chronicle.last(where: { $0.contains(keyword) }) { return line }
        }
        return chronicle.last ?? record.outcomeLine
    }
}

/// 진행 중 선수의 표정과 한마디. 읽기 전용이라 플레이 흐름을 한 탭도 늘리지 않는다.
struct PlayerHeartCard: View {
    let state: HighSchoolCareerSnapshot
    let presentation: PlayerHeartlinePresentation

    private var line: PlayerHeartline { presentation.line }

    static func analyticsScope(
        careerID: String,
        lifeNumber: Int,
        branch: PlayerHeartlineBranch
    ) -> String {
        "heartline:\(careerID):\(lifeNumber):\(branch.rawValue)"
    }

    static func analyticsProperties(
        lifeNumber: Int,
        phase: HighSchoolCareerPhase,
        branch: PlayerHeartlineBranch
    ) -> [String: Any] {
        [
            "branch_id": branch.rawValue,
            "life_number": lifeNumber,
            "phase": phase.rawValue,
        ]
    }

    var body: some View {
        BaseballCard(title: "\(state.identity.name)의 속마음", tone: .raised) {
            HStack(alignment: .center, spacing: 12) {
                PortraitView(
                    seed: state.identity.name,
                    role: .player,
                    size: 46,
                    playerStage: state.chapter.schoolYear <= 1 ? .freshman : .ace
                )
                VStack(alignment: .leading, spacing: 4) {
                    Text(line.mood)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BaseballTheme.information)
                    Text("“\(line.words)”")
                        .font(.subheadline)
                        .foregroundStyle(BaseballTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(state.identity.name)의 속마음. \(line.mood). \(line.words)")
            .accessibilityIdentifier("hs.playerHeart")
        }
        .onAppear {
            GameAnalytics.logOnce(
                .playerHeartlineSeen,
                scope: Self.analyticsScope(
                    careerID: state.careerID,
                    lifeNumber: state.lifeNumber,
                    branch: presentation.branch
                ),
                properties: Self.analyticsProperties(
                    lifeNumber: state.lifeNumber,
                    phase: state.phase,
                    branch: presentation.branch
                )
            )
        }
    }
}

/// 결산과 아카이브가 함께 쓰는, 한 선수가 남긴 문장.
struct PlayerLegacyQuote: View {
    let legacy: PlayerLegacy
    var heading = "선수가 남긴 말"

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(heading).eyebrowStyle(BaseballTheme.milestone)
            Text("“\(legacy.farewell)”")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(BaseballTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("가장 오래 남은 순간")
                .font(.caption2.weight(.bold))
                .foregroundStyle(BaseballTheme.textTertiary)
                .padding(.top, 2)
            Text(legacy.definingMoment)
                .font(.caption)
                .foregroundStyle(BaseballTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(BaseballTheme.milestone.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(BaseballTheme.milestone.opacity(0.4), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(heading). \(legacy.farewell). 가장 오래 남은 순간, \(legacy.definingMoment)")
    }
}

/// 새 선수의 시작 화면에 도착하는 전 선수의 편지. 선택한 기억까지 함께 보여 주어
/// 환생이 단순 보너스 리셋이 아니라 한 선수에서 다음 선수로 이어지는 일임을 말한다.
struct PreviousPlayerLetterCard: View {
    let record: HighSchoolCareerStore.LifeRecord
    let currentPlayerName: String

    private var legacy: PlayerLegacy {
        record.playerLegacy ?? PlayerBondStory.legacy(for: record)
    }

    private var recipientLine: String {
        Self.recipientLine(previousName: record.playerName, currentName: currentPlayerName)
    }

    static func recipientLine(previousName: String, currentName: String) -> String {
        let previous = previousName.trimmingCharacters(in: .whitespacesAndNewlines)
        let current = currentName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !previous.isEmpty, previous.localizedCaseInsensitiveCompare(current) == .orderedSame {
            return "같은 이름을 이어받은 새 선수에게"
        }
        return "새로 시작하는 \(currentName)에게"
    }

    var body: some View {
        BaseballCard(title: "지난 선수 \(record.playerName)의 말", tone: .milestone) {
            HStack(alignment: .top, spacing: 12) {
                PortraitView(
                    seed: record.playerName,
                    role: .player,
                    size: 46,
                    playerStage: record.drafted ? .pro : .ace
                )
                VStack(alignment: .leading, spacing: 6) {
                    Text(recipientLine)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(BaseballTheme.textSecondary)
                    Text(legacy.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BaseballTheme.milestone)
                    Text("“\(legacy.farewell)”")
                        .font(.subheadline)
                        .foregroundStyle(BaseballTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if !record.memories.isEmpty {
                        Text("함께 온 기억 · " + record.memories
                            .map { HighSchoolPresentation.memory($0).title }
                            .joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let signatureLegacy = record.signatureLegacy {
                        Text("직접 이어진 대표 유산 · \(signatureLegacy.title)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(BaseballTheme.milestone)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("지난 선수 \(record.playerName)의 말. \(recipientLine). \(legacy.farewell)")
            .accessibilityIdentifier("hs.previousPlayerLetter")
        }
        .onAppear {
            GameAnalytics.logOnce(
                .playerLegacySeen,
                scope: "next_life:\(record.careerID ?? "life-\(record.lifeNumber)")",
                properties: [
                    "source": "next_life",
                    "life_number": record.lifeNumber,
                    "drafted": record.drafted,
                    "has_frozen_legacy": record.playerLegacy != nil,
                ]
            )
        }
    }
}
