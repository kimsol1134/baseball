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
    /// 우리 팀 기준 점수 차(+면 리드). 이 필드가 없던 동안 화면이 전부 "1점 앞섬"으로
    /// 고정돼, 고교 3년의 모든 승부가 리드를 지키는 경기였다 — 지고 있는 마운드가 없었다.
    /// 옵셔널이라 이 필드가 없는 옛 저장본도 그대로 열린다.
    public let scoreDifferential: Int?
    /// 이 장면이 성립하는 최소 챕터. "드래프트 전 마지막 이닝"이 1학년 봄에 나오면
    /// 첫 하이라이트에서 서사가 3년 뒤를 말한다(QA 재검증 신규 1).
    public let minChapter: Int

    public init(id: String, title: String, inning: Int, outs: Int, runners: BaserunnerStateSnapshot, leverage: Int, narrative: String, scoreDifferential: Int? = nil, minChapter: Int = 1) {
        self.id = id; self.title = title; self.inning = inning; self.outs = outs; self.runners = runners; self.leverage = leverage; self.narrative = narrative
        self.scoreDifferential = scoreDifferential
        self.minChapter = minChapter
    }
}

public enum HighSchoolContentCatalog {
    public static let events: [CareerEventContent] = [
        .init(id: "evt-bullpen-first", title: "첫 불펜", category: "growth", summary: "고교 포수가 공을 받아 본 뒤 각 구종을 언제 쓰고 싶은지 묻습니다."),
        .init(id: "evt-coach-role", title: "선발인가 불펜인가", category: "coach", summary: "감독이 다음 대회는 불펜에서 시작하겠다고 말합니다."),
        .init(id: "evt-catcher-sign", title: "엇갈린 사인", category: "catcher", summary: "경기 중 세 번 사인이 엇갈렸고 포수가 이유를 묻습니다."),
        .init(id: "evt-rival-video", title: "라이벌의 영상", category: "rival", summary: "라이벌이 당신의 포심 타이밍을 정확히 맞히는 영상이 도착했습니다."),
        .init(id: "evt-winter-weight", title: "겨울의 몸", category: "growth", summary: "웨이트 코치가 근력을 늘릴지 몸의 유연성을 지킬지 선택하라고 합니다."),
        .init(id: "evt-command-wall", title: "제구의 벽", category: "growth", summary: "불펜에서는 들어가던 공이 경기만 시작하면 한 뼘씩 벗어납니다."),
        .init(id: "evt-breaker-grip", title: "새 그립", category: "growth", summary: "더 크게 휘지만 제구가 어려운 새 변화구 그립을 시험합니다."),
        .init(id: "evt-recovery-day", title: "쉬는 날의 불안", category: "health", summary: "회복 코치가 오늘은 공을 잡지 말라고 하지만 옆 불펜에서는 경쟁자가 던지고 있습니다."),
        .init(id: "evt-captain-talk", title: "주장의 질문", category: "team", summary: "주장이 다음 경기에서 긴 이닝을 맡아 줄 수 있느냐고 묻습니다."),
        .init(id: "evt-scout-stand", title: "백스톱 뒤의 스카우트", category: "draft", summary: "불펜 뒤에 선 스카우트 둘이 매 공의 구속을 적기 시작합니다."),
        .init(id: "evt-loss-interview", title: "패배 뒤 인터뷰", category: "media", summary: "기자가 마지막 타자에게 던진 공을 왜 골랐는지 묻습니다."),
        .init(id: "evt-fan-letter", title: "첫 팬레터", category: "fan", summary: "어린 팬이 가장 좋아하는 구종을 다음 경기에서도 던져 달라고 썼습니다."),
        .init(id: "evt-battery-dinner", title: "배터리의 저녁", category: "catcher", summary: "포수가 밥을 먹다 말고 가장 받기 두려운 공이 무엇인지 털어놓습니다."),
        .init(id: "evt-coach-bench", title: "감독의 벤치", category: "coach", summary: "감독이 다음 등판을 쉬게 한 이유를 설명합니다."),
        .init(id: "evt-rival-message", title: "라이벌의 메시지", category: "rival", summary: "라이벌이 ‘다음에도 같은 초구를 던질 거냐’고 메시지를 보냈습니다."),
        .init(id: "evt-mechanics-camera", title: "카메라에 찍힌 투구 동작", category: "growth", summary: "고속 카메라에 평소보다 손에서 공이 일찍 빠지는 장면이 찍혔습니다."),
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
        .init(id: "evt-drafted-call", title: "구단의 전화", category: "draft", summary: "지명 구단 담당자가 전화를 걸어 입단 뒤 첫 시즌 훈련 계획을 설명합니다."),
        .init(id: "evt-scorebook-close", title: "마지막 스코어북", category: "legacy", summary: "세 해 동안 가장 좋았던 경기와 가장 힘들었던 경기에 표시를 남깁니다.")
    ]

    /// 2회차부터만 나오는 사건들.
    ///
    /// 환생 게임인데 회차를 알아보는 텍스트가 프롤로그 뉴스 한 줄뿐이었다. 그래서 3회차나
    /// 1회차나 만나는 장면이 같았고, 그것이 "계속 똑같다"는 감각의 절반이었다.
    ///
    /// 여기 있는 것들은 **이미 살아 본 사람만 겪을 수 있는 일**이다. 처음 하는 사람에게는
    /// 뜻이 통하지 않으므로 1회차에는 아예 뽑지 않는다.
    public static let rebirthEvents: [CareerEventContent] = [
        .init(id: "evt-deja-vu-mound", title: "처음 밟는데 익숙한 마운드", category: "rebirth",
              summary: "처음 오르는 마운드인데 흙의 단단함과 발끝의 각도가 이미 알던 것 같습니다."),
        .init(id: "evt-known-coach", title: "낯익은 감독", category: "rebirth",
              summary: "감독의 말버릇과 손짓이 어디선가 본 것 같습니다. 만난 적은 없습니다."),
        .init(id: "evt-body-remembers", title: "몸이 먼저 아는 그립", category: "rebirth",
              summary: "배운 적 없는 그립이 손에 저절로 잡힙니다. 던져 보니 실제로 휩니다."),
        .init(id: "evt-rival-deja-vu", title: "라이벌의 기시감", category: "rebirth",
              summary: "라이벌이 타석에서 당신을 오래 봅니다. \u{201C}우리 어디서 붙은 적 있나?\u{201D}"),
        .init(id: "evt-memory-ache", title: "기억의 통증", category: "rebirth",
              summary: "지난번에 팔을 다쳤던 그 주차입니다. 아프지 않은데 그 자리가 신경 쓰입니다."),
        .init(id: "evt-second-summer", title: "다시 맞는 3학년 여름", category: "rebirth",
              summary: "같은 계절, 같은 대회. 이번에는 결과를 알고 시작합니다."),
        .init(id: "evt-remembered-pitch", title: "그 코스의 사인", category: "rebirth",
              summary: "지난 삶에서 홈런을 맞았던 바로 그 코스에 사인이 나옵니다. 포수는 아무것도 모릅니다."),
        .init(id: "evt-lost-teammate", title: "그만둔 동료", category: "rebirth",
              summary: "지난 삶에서 끝까지 함께 던졌던 동료가, 이번 삶에서는 야구를 그만뒀다는 소식을 듣습니다."),
        .init(id: "evt-future-news", title: "결말을 아는 뉴스", category: "rebirth",
              summary: "라디오가 올해의 우승 후보를 읊습니다. 지난 삶과 한 글자도 다르지 않아, 결말을 아는 책 같습니다."),
        .init(id: "evt-old-nickname", title: "지난 삶의 별명", category: "rebirth",
              summary: "처음 만난 상대 포수가 당신을 지난 삶의 별명으로 부릅니다. 이번 삶에는 아직 없는 이름입니다."),
        .init(id: "evt-glove-worn", title: "길들여진 새 글러브", category: "rebirth",
              summary: "새 글러브인데 지난 삶에서 길들인 자리부터 부드럽습니다. 손이 먼저 접던 각도로 접힙니다."),
        .init(id: "evt-undrafted-deja", title: "그 방의 기시감", category: "rebirth",
              summary: "드래프트 중계를 트는 순간, 이름이 불리지 않은 채 끝났던 그 방의 공기가 먼저 돌아옵니다.")
    ]

    /// Presentation-only union of every event ID that can reach the relationship card. The
    /// synthetic arm-care event is included so its localized title and summary have the same
    /// registry coverage as authored events; gameplay selection continues to use `events` and
    /// `rebirthEvents` exactly as before.
    public static let relationshipEvents: [CareerEventContent] = events + rebirthEvents + [
        .init(
            id: "evt-arm-care",
            title: "팔 상태 경고",
            category: "health",
            summary: "최근 등판 뒤 팔이 평소보다 무겁습니다. 트레이너가 오늘 어떻게 할지 묻습니다."
        ),
    ]

    private static func runners(_ first: Bool, _ second: Bool, _ third: Bool, speed: Int) -> BaserunnerStateSnapshot {
        BaserunnerStateSnapshot(firstOccupied: first, secondOccupied: second, thirdOccupied: third, leadRunnerSpeed: speed)
    }

    // scoreDifferential은 서사와 반드시 일치해야 한다 — "동점입니다"라고 말하며 화면이
    // "1점 앞섬"을 띄우면 플레이어가 배우는 상황 읽기 자체가 틀린다.
    // 분포: 리드 8 · 동점 6 · 열세 6. 뒤진 마운드에도 개인 스테이크(스카우트·기록·라이벌)를
    // 남겨서 "이미 진 경기"가 아니라 "잃을 수 없는 공"으로 읽히게 한다.
    public static let scenarios: [ImportantGameScenarioContent] = [
        .init(id: "game-debut", title: "고교 데뷔", inning: 3, outs: 0, runners: runners(false, false, false, speed: 55), leverage: 350, narrative: "첫 공식 등판. 한 점 뒤진 채 받은 기회지만, 상대 타자도 아직 내 공을 본 적이 없습니다.", scoreDifferential: -1),
        .init(id: "game-runner-first", title: "1사 1루", inning: 5, outs: 1, runners: runners(true, false, false, speed: 64), leverage: 610, narrative: "빠른 주자가 1루에서 리드를 길게 잡고 있습니다.", scoreDifferential: 1),
        .init(id: "game-rival-rematch", title: "라이벌 재대결", inning: 6, outs: 1, runners: runners(false, true, false, speed: 61), leverage: 760, narrative: "동점 6회, 지난 경기의 구종 순서를 기억하는 중심타자가 들어섭니다.", scoreDifferential: 0),
        .init(id: "game-corners", title: "1사 1·3루", inning: 7, outs: 1, runners: runners(true, false, true, speed: 67), leverage: 900, narrative: "땅볼 하나면 병살이지만 외야로 뜨면 동점입니다.", scoreDifferential: 1),
        .init(id: "game-loaded", title: "무사 만루", inning: 4, outs: 0, runners: runners(true, true, true, speed: 60), leverage: 950, narrative: "볼넷을 피하면서 약한 타구가 필요한 상황", scoreDifferential: 2),
        .init(id: "game-two-outs", title: "2사 2루", inning: 8, outs: 2, runners: runners(false, true, false, speed: 65), leverage: 880, narrative: "한 타자에 이닝이 걸린 승부", scoreDifferential: 1),
        .init(id: "game-fatigue", title: "피로한 7회", inning: 7, outs: 0, runners: runners(true, false, false, speed: 59), leverage: 720, narrative: "직구가 느려진 7회, 어떤 공으로 버틸지 정해야 합니다.", scoreDifferential: 1),
        .init(id: "game-scout", title: "스카우트 관전", inning: 5, outs: 1, runners: runners(false, false, false, speed: 55), leverage: 690, narrative: "팀은 한 점 뒤져 있지만, 스카우트는 점수가 아니라 같은 코스를 반복하는지 지켜봅니다.", scoreDifferential: -1),
        .init(id: "game-rain", title: "우천 중단 뒤", inning: 6, outs: 0, runners: runners(false, false, false, speed: 55), leverage: 540, narrative: "두 시간 동안 경기가 멈춰 몸이 식은 뒤 만나는 첫 타자입니다.", scoreDifferential: 0),
        .init(id: "game-one-run", title: "한 점 차", inning: 9, outs: 0, runners: runners(false, true, false, speed: 68), leverage: 980, narrative: "드래프트 전 마지막 고교 이닝", scoreDifferential: 1, minChapter: 7),
        .init(id: "game-new-catcher", title: "새 포수와 첫 경기", inning: 4, outs: 1, runners: runners(true, false, false, speed: 62), leverage: 570, narrative: "새 포수와 아직 구종 사인을 충분히 맞추지 못했습니다.", scoreDifferential: 1),
        .init(id: "game-national-final", title: "전국 결승", inning: 8, outs: 2, runners: runners(true, true, false, speed: 66), leverage: 1_000, narrative: "2사 1·2루. 마지막 아웃 하나에 우승이 걸렸습니다.", scoreDifferential: 1, minChapter: 4),
        .init(id: "game-walkoff-defense", title: "9회말 리드 방어", inning: 9, outs: 1, runners: runners(false, true, true, speed: 63), leverage: 985, narrative: "한 점 앞선 9회말 1사 2·3루. 외야로 뜨기만 해도 동점, 안타면 경기가 끝납니다.", scoreDifferential: 1),
        .init(id: "game-extra-tiebreak", title: "연장 승부치기", inning: 10, outs: 0, runners: runners(true, true, false, speed: 67), leverage: 940, narrative: "연장 승부치기. 무사 1·2루에서 시작합니다. 아웃부터 잡지 못하면 큰 이닝이 됩니다.", scoreDifferential: 0),
        .init(id: "game-ace-duel", title: "0-0 투수전", inning: 8, outs: 0, runners: runners(false, false, false, speed: 55), leverage: 810, narrative: "8회까지 0의 행진. 상대 에이스도 지지 않습니다. 먼저 실수하는 쪽이 집니다.", scoreDifferential: 0),
        .init(id: "game-damage-control", title: "실점 뒤 수습", inning: 6, outs: 1, runners: runners(true, true, true, speed: 58), leverage: 875, narrative: "이 이닝에만 석 점을 내줘 동점이 됐습니다. 다시 만루. 여기서 더 내주면 경기가 넘어갑니다.", scoreDifferential: 0),
        .init(id: "game-rain-grip", title: "빗속의 공", inning: 2, outs: 0, runners: runners(true, false, false, speed: 60), leverage: 470, narrative: "빗물을 머금은 공이 손끝에서 자꾸 미끄러집니다. 노린 코스보다 한 뼘씩 벗어납니다.", scoreDifferential: 0),
        .init(id: "game-doubleheader", title: "더블헤더 2차전", inning: 4, outs: 2, runners: runners(false, true, false, speed: 64), leverage: 640, narrative: "오늘 두 번째 경기. 한 점 뒤진 채, 낮 경기에서 이미 던진 팔이 무겁게 남아 있습니다.", scoreDifferential: -1),
        .init(id: "game-scout-showcase", title: "스카우트 총출동", inning: 7, outs: 2, runners: runners(false, false, false, speed: 55), leverage: 960, narrative: "팀은 두 점 뒤졌지만 관중석 첫 줄은 스카우트로 가득합니다. 공 하나하나가 순위표에 적힙니다.", scoreDifferential: -2),
        .init(id: "game-rival-away", title: "라이벌 원정", inning: 6, outs: 2, runners: runners(true, false, false, speed: 61), leverage: 830, narrative: "라이벌 학교 원정, 한 점 뒤진 6회. 마운드에 설 때마다 스탠드가 야유로 덮습니다. 소리를 지워야 공이 보입니다.", scoreDifferential: -1),
        // 확장 10종(볼륨 20→30). 분포 합계: 리드 11 · 동점 9 · 열세 10.
        .init(id: "game-cold-spring", title: "이른 봄의 손끝", inning: 2, outs: 0, runners: runners(false, false, false, speed: 55), leverage: 420, narrative: "3월의 첫 대회. 입김이 보이는 추위에 공이 돌덩이처럼 미끄럽고, 손끝의 감각이 절반만 돌아와 있습니다.", scoreDifferential: 0),
        .init(id: "game-fireman", title: "떠안은 주자", inning: 6, outs: 0, runners: runners(false, true, true, speed: 66), leverage: 930, narrative: "앞선 투수가 남긴 무사 2·3루를 떠안고 오릅니다. 여기서 들어오는 점수는 내 기록이 아니지만, 경기는 내 손에 있습니다.", scoreDifferential: -1),
        .init(id: "game-mercy-watch", title: "다섯 점의 함정", inning: 5, outs: 0, runners: runners(true, false, false, speed: 57), leverage: 380, narrative: "다섯 점 리드. 긴장이 풀리는 딱 그 지점에서 실점이 시작됩니다. 스카우트는 큰 리드에서의 집중력을 봅니다.", scoreDifferential: 5),
        .init(id: "game-nightfall", title: "일몰 직전", inning: 7, outs: 1, runners: runners(false, true, false, speed: 62), leverage: 700, narrative: "조명 없는 구장, 해가 산 뒤로 넘어가고 있습니다. 심판이 이 이닝이 오늘의 마지막이라고 알렸습니다. 동점이면 내일 처음부터 다시입니다.", scoreDifferential: 0),
        .init(id: "game-heatwave", title: "한여름 낮 경기", inning: 6, outs: 0, runners: runners(true, false, false, speed: 60), leverage: 660, narrative: "35도의 낮 경기. 유니폼이 몸에 감기고 로진백도 눅눅합니다. 한 점 리드가 이 더위 속에서 여덟 아웃만큼 멀어 보입니다.", scoreDifferential: 1, minChapter: 2),
        .init(id: "game-third-look", title: "세 번째 만나는 4번", inning: 6, outs: 2, runners: runners(false, true, false, speed: 63), leverage: 850, narrative: "오늘 세 번째로 만나는 상대 4번 타자. 앞선 두 타석의 공을 전부 기억하고 있을 겁니다. 같은 순서는 이제 통하지 않습니다.", scoreDifferential: -1),
        .init(id: "game-perfect-bid", title: "5회까지 완전", inning: 6, outs: 1, runners: runners(false, false, false, speed: 55), leverage: 780, narrative: "5회까지 한 명도 내보내지 않았습니다. 더그아웃이 조용해졌습니다 — 아무도 그 단어를 입에 올리지 않습니다.", scoreDifferential: 3, minChapter: 4),
        .init(id: "game-backup-catcher", title: "백업 포수와의 승부", inning: 7, outs: 1, runners: runners(true, false, false, speed: 61), leverage: 740, narrative: "주전 포수가 파울 타구에 손가락을 맞아 교체됐습니다. 백업 포수와는 불펜 한 번 맞춰 본 게 전부입니다.", scoreDifferential: 0),
        .init(id: "game-seniors-last", title: "선배들의 마지막", inning: 8, outs: 1, runners: runners(true, true, false, speed: 64), leverage: 890, narrative: "두 점 뒤진 8회. 지면 3학년 선배들의 고교 야구가 오늘로 끝납니다. 더그아웃의 눈이 전부 마운드를 보고 있습니다.", scoreDifferential: -2, minChapter: 2),
        .init(id: "game-sign-leak", title: "새는 사인", inning: 5, outs: 0, runners: runners(false, true, false, speed: 65), leverage: 720, narrative: "상대 2루 주자가 타자에게 무언가를 전달하는 정황. 사인이 읽히고 있다면, 이제부터는 코스보다 배짱의 승부입니다.", scoreDifferential: -1)
    ]
}
