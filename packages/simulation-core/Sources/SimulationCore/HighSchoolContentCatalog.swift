import Foundation

public struct CareerEventContent: Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let category: String
    public let summary: String
    public init(id: String, title: String, category: String, summary: String) {
        self.id = id; self.title = title; self.category = category; self.summary = summary
    }
}

public struct ImportantGameScenarioContent: Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let inning: Int
    public let outs: Int
    public let runners: BaserunnerStateSnapshot
    public let leverage: Int
    public let narrative: String
    public init(id: String, title: String, inning: Int, outs: Int, runners: BaserunnerStateSnapshot, leverage: Int, narrative: String) {
        self.id = id; self.title = title; self.inning = inning; self.outs = outs; self.runners = runners; self.leverage = leverage; self.narrative = narrative
    }
}

public enum HighSchoolContentCatalog {
    public static let events: [CareerEventContent] = [
        .init(id: "evt-bullpen-first", title: "첫 불펜", category: "growth", summary: "고교 포수가 공을 받아 본 뒤 각 구종을 언제 쓰고 싶은지 묻습니다."),
        .init(id: "evt-coach-role", title: "선발인가 불펜인가", category: "coach", summary: "감독이 다음 대회는 불펜에서 시작하겠다고 말합니다."),
        .init(id: "evt-catcher-sign", title: "엇갈린 사인", category: "catcher", summary: "경기 중 세 번 사인이 엇갈렸고 포수가 이유를 묻습니다."),
        .init(id: "evt-rival-video", title: "라이벌의 영상", category: "rival", summary: "라이벌이 당신의 포심 타이밍을 정확히 맞히는 영상이 도착했습니다."),
        .init(id: "evt-winter-weight", title: "겨울의 몸", category: "growth", summary: "웨이트 코치가 근력을 늘릴지 가동성을 지킬지 선택하라고 합니다."),
        .init(id: "evt-command-wall", title: "커맨드의 벽", category: "growth", summary: "불펜에서는 들어가던 공이 경기만 시작하면 한 뼘씩 벗어납니다."),
        .init(id: "evt-breaker-grip", title: "새 그립", category: "growth", summary: "더 크게 휘지만 제구가 어려운 새 변화구 그립을 시험합니다."),
        .init(id: "evt-recovery-day", title: "쉬는 날의 불안", category: "health", summary: "회복 코치가 오늘은 공을 잡지 말라고 하지만 옆 불펜에서는 경쟁자가 던지고 있습니다."),
        .init(id: "evt-captain-talk", title: "주장의 질문", category: "team", summary: "주장이 다음 경기에서 긴 이닝을 맡아 줄 수 있느냐고 묻습니다."),
        .init(id: "evt-scout-stand", title: "백스톱 뒤의 스카우트", category: "draft", summary: "불펜 뒤에 선 스카우트 둘이 매 공의 구속을 적기 시작합니다."),
        .init(id: "evt-loss-interview", title: "패배 뒤 인터뷰", category: "media", summary: "기자가 마지막 타자에게 던진 공을 왜 골랐는지 묻습니다."),
        .init(id: "evt-fan-letter", title: "첫 팬레터", category: "fan", summary: "어린 팬이 가장 좋아하는 구종을 다음 경기에서도 던져 달라고 썼습니다."),
        .init(id: "evt-battery-dinner", title: "배터리의 저녁", category: "catcher", summary: "포수가 밥을 먹다 말고 가장 받기 두려운 공이 무엇인지 털어놓습니다."),
        .init(id: "evt-coach-bench", title: "감독의 벤치", category: "coach", summary: "감독이 다음 등판을 쉬게 한 이유를 설명합니다."),
        .init(id: "evt-rival-message", title: "라이벌의 메시지", category: "rival", summary: "라이벌이 ‘다음에도 같은 초구를 던질 거냐’고 메시지를 보냈습니다."),
        .init(id: "evt-mechanics-camera", title: "카메라 앞의 릴리스", category: "growth", summary: "고속 카메라에는 손이 평소보다 일찍 공에서 떨어지는 장면이 찍혔습니다."),
        .init(id: "evt-velocity-drop", title: "2km/h의 하락", category: "health", summary: "두 경기 연속 최고 구속이 2km/h 낮게 찍혔습니다."),
        .init(id: "evt-new-catcher", title: "새 포수", category: "catcher", summary: "새 포수가 기존 사인 대신 자신이 쓰던 손짓을 제안합니다."),
        .init(id: "evt-school-record", title: "학교 기록", category: "fan", summary: "다음 경기에서 탈삼진 6개를 더 잡으면 학교 기록이 바뀝니다."),
        .init(id: "evt-rain-delay", title: "비가 멈춘 뒤", category: "game", summary: "두 시간 동안 멈췄던 경기가 갑자기 15분 뒤 재개됩니다."),
        .init(id: "evt-loaded-bases", title: "만루의 기억", category: "game", summary: "지난 경기 만루에서 던진 초구가 영상실 화면에 다시 나옵니다."),
        .init(id: "evt-first-awakening", title: "몸이 먼저 아는 것", category: "awakening", summary: "최근 훈련에서 반복한 동작이 경기에서도 자연스럽게 나옵니다."),
        .init(id: "evt-team-slump", title: "팀의 연패", category: "team", summary: "세 경기 연속 패배 뒤 선수들이 자율 훈련 시간을 두고 다툽니다."),
        .init(id: "evt-bullpen-rival", title: "같은 팀의 경쟁자", category: "team", summary: "선발 자리를 다투는 동료가 새 변화구 그립을 보여 달라고 합니다."),
        .init(id: "evt-scout-question", title: "스카우트의 한 질문", category: "draft", summary: "스카우트가 최근 무너진 경기 뒤 무엇을 바꿨는지 묻습니다."),
        .init(id: "evt-parent-call", title: "집에서 온 전화", category: "life", summary: "부모님이 드래프트 뒤에도 야구를 계속할 생각인지 묻습니다."),
        .init(id: "evt-exam-week", title: "시험 주간", category: "life", summary: "시험과 원정 경기가 겹쳐 이번 주 훈련 시간이 절반으로 줄었습니다."),
        .init(id: "evt-injury-rumor", title: "통증 소문", category: "health", summary: "어깨를 주무르는 모습을 본 동료가 코치에게 말해야 하지 않느냐고 묻습니다."),
        .init(id: "evt-national-stage", title: "전국 중계", category: "media", summary: "경기 전 불펜부터 중계 카메라가 계속 따라붙습니다."),
        .init(id: "evt-catcher-doubt", title: "포수의 의심", category: "catcher", summary: "포수가 최근 자신의 사인을 자주 거절하는 이유를 묻습니다."),
        .init(id: "evt-coach-last-advice", title: "감독의 마지막 조언", category: "coach", summary: "감독이 드래프트 전 마지막 훈련 하나를 직접 고르라고 합니다."),
        .init(id: "evt-rival-final", title: "마지막 재대결", category: "rival", summary: "라이벌이 타석에 들어서며 지난 경기와 같은 코스를 가리킵니다."),
        .init(id: "evt-draft-projection", title: "예상 순위", category: "draft", summary: "언론 예상 순위와 학교가 들은 구단 평가가 두 라운드나 차이 납니다."),
        .init(id: "evt-undrafted-room", title: "이름이 불리지 않은 방", category: "legacy", summary: "마지막 라운드가 끝난 뒤 세 해의 기록을 다시 펼칩니다."),
        .init(id: "evt-drafted-call", title: "구단의 전화", category: "draft", summary: "지명 구단 담당자가 전화를 걸어 첫 시즌 육성 계획을 설명합니다."),
        .init(id: "evt-scorebook-close", title: "마지막 스코어북", category: "legacy", summary: "세 해 동안 가장 좋았던 경기와 가장 힘들었던 경기에 표시를 남깁니다.")
    ]

    private static func runners(_ first: Bool, _ second: Bool, _ third: Bool, speed: Int) -> BaserunnerStateSnapshot {
        BaserunnerStateSnapshot(firstOccupied: first, secondOccupied: second, thirdOccupied: third, leadRunnerSpeed: speed)
    }

    public static let scenarios: [ImportantGameScenarioContent] = [
        .init(id: "game-debut", title: "고교 데뷔", inning: 3, outs: 0, runners: runners(false, false, false, speed: 55), leverage: 350, narrative: "첫 공식 등판. 상대 타자도 아직 내 공을 본 적이 없습니다."),
        .init(id: "game-runner-first", title: "1사 1루", inning: 5, outs: 1, runners: runners(true, false, false, speed: 64), leverage: 610, narrative: "빠른 주자가 1루에서 리드를 길게 잡고 있습니다."),
        .init(id: "game-rival-rematch", title: "라이벌 재대결", inning: 6, outs: 1, runners: runners(false, true, false, speed: 61), leverage: 760, narrative: "지난 경기의 구종 순서를 기억하는 중심타자가 들어섭니다."),
        .init(id: "game-corners", title: "1사 1·3루", inning: 7, outs: 1, runners: runners(true, false, true, speed: 67), leverage: 900, narrative: "땅볼 하나면 병살이지만 외야로 뜨면 동점입니다."),
        .init(id: "game-loaded", title: "무사 만루", inning: 4, outs: 0, runners: runners(true, true, true, speed: 60), leverage: 950, narrative: "볼넷을 피하면서 약한 타구가 필요한 상황"),
        .init(id: "game-two-outs", title: "2사 2루", inning: 8, outs: 2, runners: runners(false, true, false, speed: 65), leverage: 880, narrative: "한 타자에 이닝이 걸린 승부"),
        .init(id: "game-fatigue", title: "피로한 7회", inning: 7, outs: 0, runners: runners(true, false, false, speed: 59), leverage: 720, narrative: "최고 구속이 떨어진 뒤의 계획"),
        .init(id: "game-scout", title: "스카우트 관전", inning: 5, outs: 1, runners: runners(false, false, false, speed: 55), leverage: 690, narrative: "스카우트가 구속보다 같은 코스를 반복하는지 지켜봅니다."),
        .init(id: "game-rain", title: "우천 중단 뒤", inning: 6, outs: 0, runners: runners(false, false, false, speed: 55), leverage: 540, narrative: "루틴이 끊긴 뒤 첫 타자"),
        .init(id: "game-one-run", title: "한 점 차", inning: 9, outs: 0, runners: runners(false, true, false, speed: 68), leverage: 980, narrative: "드래프트 전 마지막 고교 이닝"),
        .init(id: "game-new-catcher", title: "새 포수와 첫 경기", inning: 4, outs: 1, runners: runners(true, false, false, speed: 62), leverage: 570, narrative: "새 포수와 아직 구종 사인을 충분히 맞추지 못했습니다."),
        .init(id: "game-national-final", title: "전국 결승", inning: 8, outs: 2, runners: runners(true, true, false, speed: 66), leverage: 1_000, narrative: "2사 1·2루. 마지막 아웃 하나에 우승이 걸렸습니다.")
    ]
}
