import Foundation

/// 관계 장면의 목소리 — 누가 말하는지, 뭐라고 하는지, 어떤 답을 고를 수 있는지.
///
/// 이 내용은 원래 데스크톱 화면 파일(`apps/windows/src/relationshipDialogue.ts`와
/// `HighSchoolCareerView.tsx`) 안에만 있었다. 그래서 **iOS에는 손으로 쓴 대사가 하나도
/// 없었다** — 관계 국면이 코어 이벤트의 한 문장 요약과 버튼 세 개로만 존재했고, 인물의
/// 목소리가 들리는 곳은 프롤로그의 감독 한 줄뿐이었다(품질 평가 §4.3, 결격 3).
///
/// 콘텐츠는 코어에 있어야 두 플랫폼이 갈리지 않는다. 그래서 여기로 올린다.
///
/// **저장 형식은 건드리지 않는다.** `CareerEventContent`(스냅숏에 저장된다)에 필드를
/// 더하지 않고, 이벤트 id와 신뢰도만 받아 목소리를 되돌려 주는 순수 조회로 만든다.
/// 옛 저장본도 그대로 열린다.
///
/// 데스크톱 TS 표는 아직 자기 사본을 쓴다(데스크톱은 현재 중단 상태다). 두 사본이
/// 갈라지지 않도록 `tools/check-dialogue-parity.mjs`가 인용 대사를 대조한다.
public enum RelationshipVoiceCatalog {

    /// 신뢰도 구간. 화면의 신뢰도 의미 경계와 같다 — 낮음 <45, 보통 45–64, 높음 ≥65.
    ///
    /// 같은 인물의 신뢰도가 오르내리므로 갈등(낮음) → 시험(보통) → 회수(높음)의 톤 아크가
    /// 저절로 만들어진다. 대사만 갈리고 선택지는 그대로 둔다 — 선택지가 신뢰도로 잠기면
    /// 낮은 신뢰도가 곧 적은 선택이 되어 회복이 어려워진다.
    public enum TrustBand: String, Sendable {
        case low, mid, high

        public static func of(_ trust: Int) -> TrustBand {
            if trust >= 65 { return .high }
            if trust < 45 { return .low }
            return .mid
        }
    }

    /// 말하는 사람이 누구인가. 이름은 회차마다 달라지므로 화면이 채운다.
    public enum Speaker: Equatable, Sendable {
        /// 이 회차의 감독. 화면이 학교의 `coachName`을 넣는다.
        case coach
        /// 이 회차의 주전 포수.
        case catcher
        /// 이 회차의 라이벌.
        case rival
        /// 회차와 무관한 사람("팬", "기자", "트레이너"). 이름이 곧 역할이다.
        case named(String)
    }

    public struct Choice: Equatable, Sendable {
        public let response: RelationshipResponse
        public let title: String
        public let detail: String

        public init(response: RelationshipResponse, title: String, detail: String) {
            self.response = response
            self.title = title
            self.detail = detail
        }
    }

    public struct Scene: Equatable, Sendable {
        public let speaker: Speaker
        /// 인용 대사. 신뢰도로 갈리지 않는 장면은 세 구간이 같은 문장을 갖는다.
        public let quotes: [TrustBand: String]
        public let choices: [Choice]

        public func quote(_ band: TrustBand) -> String {
            quotes[band] ?? quotes[.mid] ?? ""
        }
    }

    // MARK: - 조회

    /// 이벤트에 붙은 장면. 고정 장면이 없으면 카테고리 기본 장면으로 떨어진다.
    ///
    /// 카테고리 기본 장면에는 인용 대사가 없다 — 이벤트 요약을 그대로 쓰는 것이 맞다.
    /// 없는 대사를 지어내는 것보다 요약을 정직하게 보여 주는 편이 낫다.
    public static func scene(eventID: String, category: String) -> Scene? {
        scenes[eventID] ?? categoryScenes[category] ?? coreFallback(category)
    }

    /// 이 장면의 화자가 어느 신뢰도를 따르는가.
    public static func trustBand(for speaker: Speaker, manager: Int, catcher: Int, rival: Int) -> TrustBand {
        switch speaker {
        case .coach: .of(manager)
        case .catcher: .of(catcher)
        case .rival: .of(rival)
        case .named: .of((manager + catcher + rival) / 3)
        }
    }

    // MARK: - 표

    private static func listen(_ title: String, _ detail: String) -> Choice {
        Choice(response: .listen, title: title, detail: detail)
    }
    private static func explain(_ title: String, _ detail: String) -> Choice {
        Choice(response: .explain, title: title, detail: detail)
    }
    private static func challenge(_ title: String, _ detail: String) -> Choice {
        Choice(response: .challenge, title: title, detail: detail)
    }
    /// 신뢰도로 갈리지 않는 한 문장.
    private static func flat(_ quote: String) -> [TrustBand: String] {
        [.low: quote, .mid: quote, .high: quote]
    }

    /// 고정 장면. 이벤트 id 하나에 손으로 쓴 대사와 선택지가 붙는다.
    public static let scenes: [String: Scene] = [
        // 감독 3장면
        "evt-coach-role": Scene(speaker: .coach, quotes: [
            .low: "\u{201C}선발은 아직 이르다. 불펜부터 시작해. …이유를 따질 시간에 공이나 더 던져 봐.\u{201D}",
            .mid: "\u{201C}다음 대회는 불펜에서 시작한다. 경기 후반을 맡아 줘.\u{201D}",
            .high: "\u{201C}{player}. 이번엔 네가 경기 후반을 닫아 줘. 마지막 이닝은 아무한테나 안 맡긴다.\u{201D}",
        ], choices: [
            listen("불펜으로 옮긴 이유를 묻는다", "감독이 본 약점부터 듣는다"),
            explain("최근 선발 등판 기록을 꺼내 보인다", "선발로 남고 싶은 이유를 말한다"),
            challenge("다음 등판으로 선발 자리를 되찾겠다고 한다", "결과로 증명하겠다고 답한다"),
        ]),
        "evt-coach-bench": Scene(speaker: .coach, quotes: [
            .low: "\u{201C}오늘은 뺀다. 몸 상태를 나한테 숨기는 선수는 더 오래 못 믿어.\u{201D}",
            .mid: "\u{201C}이번 등판은 쉰다. 요즘은 팔이 몸보다 늦게 따라온다.\u{201D}",
            .high: "\u{201C}하루 쉬자. {player}가 무리하는 걸 알면서 내보내면, 그건 내 잘못이 되니까.\u{201D}",
        ], choices: [
            listen("어느 동작이 늦었는지 묻는다", "감독의 관찰을 자세히 듣는다"),
            explain("최근 피로 기록을 보여준다", "몸 상태를 숨김없이 설명한다"),
            challenge("불펜 투구를 보고 결정해 달라고 한다", "오늘 던질 기회를 요청한다"),
        ]),
        "evt-coach-last-advice": Scene(speaker: .coach, quotes: [
            .low: "\u{201C}마지막 훈련이다. …아직도 내가 정해 줘야 하나. 스스로 못 고르면 프로에선 더 헤맨다.\u{201D}",
            .mid: "\u{201C}마지막 훈련은 네가 정해라. 지금 가장 부족한 게 뭐지?\u{201D}",
            .high: "\u{201C}마지막 훈련은 {player} 너한테 맡긴다. 3년을 봤으니, 이제 네 판단을 믿어 볼 때도 됐지.\u{201D}",
        ], choices: [
            listen("감독이라면 무엇을 고를지 묻는다", "마지막 조언을 먼저 듣는다"),
            explain("최근 경기에서 흔들린 장면을 짚는다", "고치려는 부분을 설명한다"),
            challenge("가장 자신 있는 공을 더 다듬겠다고 한다", "강점으로 승부하겠다고 답한다"),
        ]),

        // 포수 4장면
        "evt-catcher-sign": Scene(speaker: .catcher, quotes: [
            .low: "\u{201C}또 사인이 세 번 바뀌었어. …이럴 거면 왜 나랑 배터리를 맞춰?\u{201D}",
            .mid: "\u{201C}오늘 사인이 세 번이나 바뀌었어. 내가 놓친 게 뭐였어?\u{201D}",
            .high: "\u{201C}세 번 바꾼 거, 오늘은 다 맞았어. {player} 공은 이제 내가 제일 잘 알아.\u{201D}",
        ], choices: [
            listen("포수가 본 타자 반응부터 묻는다", "내가 못 본 장면을 확인한다"),
            explain("타자가 높은 공을 기다렸다고 말한다", "세 번의 변경이 독단이 아니었음을 포수와 맞춘다"),
            challenge("다음 타석은 내 순서대로 가 보자고 한다", "내 선택을 시험해 보자고 제안한다"),
        ]),
        "evt-battery-dinner": Scene(speaker: .catcher, quotes: [
            .low: "\u{201C}네 변화구, 솔직히 나도 못 받겠어. 이건 배터리가 아니라 각자 야구잖아.\u{201D}",
            .mid: "\u{201C}솔직히 네 변화구가 어디로 올지 몰라서 겁날 때가 있어.\u{201D}",
            .high: "\u{201C}이제 {player} 변화구는 눈 감고도 받아. 손 떠나는 순간 어디 떨어질지 보이거든.\u{201D}",
        ], choices: [
            listen("받기 어려웠던 공을 하나씩 묻는다", "포수가 불안했던 지점을 듣는다"),
            explain("손에서 빠지는 날의 감각을 말한다", "변화구가 흔들린 이유를 설명한다"),
            challenge("다음 불펜에서 가장 어려운 공만 받아 달라고 한다", "함께 해법을 찾자고 제안한다"),
        ]),
        "evt-catcher-doubt": Scene(speaker: .catcher, quotes: [
            .low: "\u{201C}사인을 그렇게 거절할 거면 마운드에서 혼자 다 정해. …난 뭐 하러 앉아 있어?\u{201D}",
            .mid: "\u{201C}요즘 내 사인을 자꾸 거절하잖아. 내가 못 본 게 있어?\u{201D}",
            .high: "\u{201C}요즘 {player}가 고개 젓는 공이 더 좋더라. 네가 보는 걸 나도 보고 싶어.\u{201D}",
        ], choices: [
            listen("최근 사인이 좋았던 장면부터 묻는다", "포수의 의도를 다시 듣는다"),
            explain("거절한 세 타석의 노림수를 짚는다", "내가 본 타자 반응을 포수와 맞춘다"),
            challenge("다음 경기의 첫 세 타자는 내 순서로 가자고 한다", "내 판단을 결과로 확인하자고 한다"),
        ]),
        "evt-new-catcher": Scene(
            speaker: .catcher,
            quotes: [
                .low: "\u{201C}전 학교에서는 이 사인을 썼어. …어차피 네가 다 정할 거면 아무거나 해도 되고.\u{201D}",
                .mid: "\u{201C}전 학교에서는 이 사인을 썼어. 우리도 다음 경기부터 바꿔 볼래?\u{201D}",
                .high: "\u{201C}전 학교 사인이 손에 더 붙어. 근데 {player}가 편한 쪽으로 가자. 나는 맞출 수 있어.\u{201D}",
            ],
            choices: [
                listen("새 사인의 순서를 끝까지 배운다", "포수가 익숙한 방식을 먼저 확인한다"),
                explain("기존 사인을 유지하고 싶은 이유를 말한다", "헷갈릴 수 있는 장면을 짚는다"),
                challenge("불펜에서 두 방식을 모두 시험하자고 한다", "경기 전에 직접 비교한다"),
            ]
        ),

        // 라이벌 2장면
        "evt-rival-video": Scene(speaker: .rival, quotes: [
            .low: "\u{201C}네 높은 포심, 이제 안 무서워.\u{201D} 헛스윙 하나 없는 타격 영상만 툭 보내왔다.",
            .mid: "\u{201C}높은 포심 타이밍, 이제 맞췄어.\u{201D} 짧은 타격 영상이 함께 도착했다.",
            .high: "\u{201C}{player}. 높은 포심, 드디어 맞췄어. …근데 이거 하나 맞추는 데 3년 걸렸다.\u{201D} 영상 끝엔 웃는 표시가 붙어 있었다.",
        ], choices: [
            listen("언제부터 타이밍을 읽었는지 묻는다", "내 반복 습관을 확인한다"),
            explain("그 공으로 노렸던 것을 솔직히 말한다", "서로의 판단을 맞춰 본다"),
            challenge("다음에는 같은 높이에서 다른 공을 던지겠다고 한다", "재대결을 약속한다"),
        ]),
        "evt-rival-final": Scene(speaker: .rival, quotes: [
            .low: "타석에 선 그가 포수 미트도 보지 않고 웃는다. \u{201C}어차피 거기로 올 거잖아. 다 알아.\u{201D}",
            .mid: "타석에 들어선 그가 지난 경기와 같은 코스를 배트 끝으로 가리킨다. \u{201C}또 여기로 던져 봐.\u{201D}",
            .high: "타석에 들어선 그가 배트를 고쳐 쥐며 낮게 말한다. \u{201C}{player}. 마지막이네. 네 제일 좋은 공으로 와. 그래야 이겨도 져도 남지.\u{201D}",
        ], choices: [
            listen("왜 그 코스를 가리켰는지 되묻는다", "상대가 노리는 말을 더 끌어낸다"),
            explain("지난 공은 실투가 아니었다고 답한다", "그때의 선택을 숨기지 않는다"),
            challenge("고개를 끄덕이고 승부를 받아들인다", "다음 공으로 답한다"),
        ]),
        "evt-rival-message": Scene(speaker: .rival, quotes: [
            .low: "\u{201C}어차피 또 같은 초구겠지. …너 그거밖에 없잖아.\u{201D}",
            .mid: "\u{201C}다음에도 같은 초구를 던질 거야?\u{201D}",
            .high: "\u{201C}{player} 다음 초구, 뭐 던질지 맞혀 볼까. …아니다, 그건 직접 보는 게 낫지.\u{201D}",
        ], choices: [
            listen("어떤 습관을 읽었는지 묻는다", "상대의 답을 들어 본다"),
            explain("그 초구로 노린 것을 말한다", "내 판단을 숨기지 않는다"),
            challenge("다음 타석에는 다른 답을 주겠다고 한다", "재대결을 약속한다"),
        ]),

        // 팔 상태(합성 이벤트)
        "evt-arm-care": Scene(
            speaker: .named("트레이너"),
            quotes: [
                .low: "\u{201C}팔이 무거워 보이는데. …말해 줘도 어차피 던질 거지?\u{201D}",
                .mid: "\u{201C}최근 등판 뒤로 공을 놓는 팔이 무거워 보여. 오늘은 어떻게 할까?\u{201D}",
                .high: "\u{201C}{player}, 팔이 무거워. 참는 편인 거 아니까 내가 먼저 말한다. 오늘은 어떻게 할까?\u{201D}",
            ],
            choices: [
                challenge("참고 던진다", "능력은 지키지만 부상 위험이 오른다"),
                listen("짧은 휴식", "이번엔 팔을 쉬어 피로와 위험을 크게 던다"),
                explain("정밀 검진", "상태를 정확히 확인하고 위험을 없앤다"),
            ]
        ),

        // 확장 카테고리 손대사 장면
        "evt-fan-letter": Scene(
            speaker: .named("팬"),
            quotes: [
                .low: "\u{201C}저번에 진 거 봤어요. 그래도 그 느린 공은 좋았어요.\u{201D} 짧은 편지 한 장이다.",
                .mid: "\u{201C}{player} 선수님이 던지는 그 느린 공이 제일 좋아요. 다음 경기에도 꼭 던져 주세요!\u{201D} 삐뚤빼뚤한 글씨 밑에 그림도 그려져 있다.",
                .high: "\u{201C}그 느린 공 던질 때 제가 제일 크게 소리쳐요. 다음에도 던져 주실 거죠?\u{201D} 편지가 세 장이나 왔다.",
            ],
            choices: [
                listen("어떤 공을 좋아하는지 다시 읽는다", "팬이 아끼는 공을 확인한다"),
                explain("그 공을 던지는 이유를 답장에 적는다", "왜 그 공인지 편지에 담는다"),
                challenge("다음 경기에서 꼭 보여주겠다고 약속한다", "기대에 공으로 답한다"),
            ]
        ),
        "evt-parent-call": Scene(
            speaker: .named("부모님"),
            quotes: [
                .low: "\u{201C}요즘 연락이 없더라. …드래프트 끝나고는 어떻게 할 생각이니.\u{201D}",
                .mid: "\u{201C}드래프트 끝나고도 계속할 거지? …아니, 대답은 천천히 해도 돼. 밥은 챙겨 먹고 다니니.\u{201D}",
                .high: "\u{201C}경기 봤다. 잘하더라. …드래프트 끝나고도 계속할 거지? 뭘 하든 밥은 챙겨 먹고.\u{201D}",
            ],
            choices: [
                listen("오늘 집에서 있었던 일부터 묻는다", "드래프트 걱정에 가렸던 가족의 하루를 되찾는다"),
                explain("지금의 계획을 담담히 말한다", "야구를 계속할 생각을 전한다"),
                challenge("결과로 안심시키겠다고 말한다", "다음 경기로 보여주겠다고 답한다"),
            ]
        ),
        "evt-exam-week": Scene(
            speaker: .named("담임 선생님"),
            quotes: [
                .low: "\u{201C}시험이랑 원정이 겹쳤지. 공만 잡고 있으면 나중에 갈 데가 좁아진다.\u{201D}",
                .mid: "\u{201C}시험이랑 원정이 겹쳤지. 공만큼 책도 며칠은 잡아야 한다. …야구는 안 도망가.\u{201D}",
                .high: "\u{201C}{player}, 시험이랑 원정이 겹쳤더라. 알아서 할 거 아니까 길게 말 안 한다. 며칠만.\u{201D}",
            ],
            choices: [
                listen("며칠치 시험 범위를 수첩에 옮긴다", "원정 전까지 책상 앞에 앉을 시간을 확보한다"),
                explain("시간을 어떻게 쪼갤지 말한다", "둘 다 놓지 않을 계획을 설명한다"),
                challenge("남는 시간을 훈련으로 메우겠다고 한다", "줄어든 시간을 아껴 쓴다"),
            ]
        ),
        "evt-loss-interview": Scene(
            speaker: .named("기자"),
            quotes: [
                .low: "\u{201C}마지막 그 공, 실투였습니까?\u{201D} 녹음기가 아직 돌아가고 있다.",
                .mid: "\u{201C}마지막 타자에게 그 공을 고른 이유가 있었나요?\u{201D} 녹음기가 아직 돌아가고 있다.",
                .high: "\u{201C}{player} 선수, 마지막 그 공 노리고 던진 거죠? 그 판단이 궁금해서 기다렸습니다.\u{201D}",
            ],
            choices: [
                listen("질문의 뜻을 되묻는다", "무엇을 궁금해하는지 먼저 듣는다"),
                explain("그 공을 고른 이유를 말한다", "그 순간의 판단을 설명한다"),
                challenge("다음 경기로 답하겠다고 한다", "말 대신 결과로 보여준다"),
            ]
        ),
        "evt-national-stage": Scene(
            speaker: .named("중계 PD"),
            quotes: [
                .low: "\u{201C}오늘 불펜부터 카메라 붙는다. 부담되면 어쩔 수 없고.\u{201D}",
                .mid: "\u{201C}오늘 불펜부터 그림 좀 담을게. 평소대로 던져. …평소대로가 제일 어렵지?\u{201D}",
                .high: "\u{201C}오늘은 {player} 중심으로 간다. 평소대로만 하면 그림은 알아서 나와.\u{201D}",
            ],
            choices: [
                listen("카메라가 지날 선을 바닥에 짚어 달라 한다", "루틴을 끊지 않을 공간을 미리 확보한다"),
                explain("준비는 평소 그대로 하겠다고 한다", "달라질 것 없다고 말한다"),
                challenge("카메라를 잊고 공에만 집중한다", "중계는 신경 쓰지 않기로 한다"),
            ]
        ),
        "evt-captain-talk": Scene(
            speaker: .named("주장"),
            quotes: [
                .low: "\u{201C}다음 경기 긴 이닝… 맡을 수 있겠어? 요즘 네가 어떤지 잘 몰라서 묻는다.\u{201D}",
                .mid: "\u{201C}다음 경기, 긴 이닝 맡아 줄 수 있어? 무리면 무리라고 말해. 그게 팀엔 더 나아.\u{201D}",
                .high: "\u{201C}다음 경기는 {player}가 길게 가 줘야 해. 다들 그렇게 생각하고 있어.\u{201D}",
            ],
            choices: [
                listen("몇 회부터 맡아야 하는지 묻는다", "팀의 계투 순서에서 내 몫을 분명히 안다"),
                explain("지금 던질 수 있는 이닝을 말한다", "몸 상태를 솔직히 전한다"),
                challenge("끝까지 책임지겠다고 나선다", "긴 이닝을 자청한다"),
            ]
        ),
        "evt-school-record": Scene(
            speaker: .named("후배"),
            quotes: [
                .low: "\u{201C}선배, 여섯 개만 더 잡으면 학교 기록이래요. …아, 부담 드리려던 건 아니고요.\u{201D}",
                .mid: "\u{201C}선배, 다음 경기에서 여섯 개만 더 잡으면 학교 기록이래요. …저 그거 옆에서 보고 싶어요.\u{201D}",
                .high: "\u{201C}선배, 여섯 개예요. 저 오늘 그거 보려고 왔어요.\u{201D}",
            ],
            choices: [
                listen("후배가 아는 기록을 들어 본다", "무슨 기록인지 확인한다"),
                explain("기록은 신경 쓰지 않는다고 말한다", "한 타자씩 가겠다고 답한다"),
                challenge("그 기록 보여주겠다고 웃는다", "다음 경기에서 노려 보겠다고 한다"),
            ]
        ),
        "evt-scout-question": Scene(
            speaker: .named("스카우트"),
            quotes: [
                .low: "\u{201C}지난달 그 경기 봤다. …그 뒤로 뭘 바꿨나?\u{201D}",
                .mid: "\u{201C}지난달 무너진 경기 다음에, 뭘 바꿨지? …바꾼 게 있다면 그게 제일 궁금해.\u{201D}",
                .high: "\u{201C}{player}. 지난달 그 경기 뒤로 확실히 달라졌더라. 뭘 바꿨는지 듣고 싶어서 왔다.\u{201D}",
            ],
            choices: [
                listen("보고서에서 멈춘 장면을 가리켜 달라 한다", "다음 등판에서 바꿀 평가 항목을 하나 얻는다"),
                explain("그 경기 뒤 바꾼 것을 말한다", "달라진 준비를 설명한다"),
                challenge("가장 좋은 공으로 답하겠다고 한다", "다음 등판으로 증명한다"),
            ]
        ),
        "evt-velocity-drop": Scene(
            speaker: .named("트레이너"),
            quotes: [
                .low: "\u{201C}두 경기째 구속이 빠졌어. …말해도 안 들을 거면 기록만 남겨 둘게.\u{201D}",
                .mid: "\u{201C}두 경기째 구속이 2km/h 빠졌어. 숫자는 거짓말을 안 해. 몸이 뭔가 말하는 중이야.\u{201D}",
                .high: "\u{201C}두 경기째 2km/h. 네가 먼저 느꼈을 거라 생각하는데, 어때?\u{201D}",
            ],
            choices: [
                listen("팔이 늦어지는 동작을 짚어 달라 한다", "구속 저하가 시작된 몸의 신호를 놓치지 않는다"),
                explain("요즘 몸 상태를 그대로 말한다", "느껴지는 피로를 설명한다"),
                challenge("며칠 조정하고 다시 끌어올리겠다고 한다", "구속은 곧 돌아온다고 답한다"),
            ]
        ),

        // 성장·경기·진로·기록 장면. 카테고리 문구로 대신하지 않고 사건의 물성과
        // 상대가 당장 보고 있는 것을 말하게 한다.
        "evt-bullpen-first": Scene(
            speaker: .catcher,
            quotes: [
                .low: "\u{201C}직구 다음 변화구는 아직 못 받겠어. 손에서 떠난 뒤에야 보여.\u{201D}",
                .mid: "\u{201C}직구 뒤엔 어떤 공을 가장 던지고 싶어? 그 순서부터 외워 둘게.\u{201D}",
                .high: "\u{201C}{player}, 네 직구가 살면 다음 공도 같이 살아. 오늘 배터리 순서 하나 만들자.\u{201D}",
            ],
            choices: [
                listen("포수 미트가 늦은 구종을 짚어 달라 한다", "받는 쪽의 불안을 알면 첫 공식전의 폭투 위험을 줄일 수 있다"),
                explain("직구 뒤에 떨어지는 공을 원한다고 말한다", "내가 그리는 두 공의 순서를 포수와 공유한다"),
                challenge("마지막 열 공은 포수 사인대로 던진다", "새 배터리의 호흡을 실전 속도로 검증한다"),
            ]
        ),
        "evt-winter-weight": Scene(
            speaker: .named("웨이트 코치"),
            quotes: [
                .low: "\u{201C}무게만 좇으면 네 어깨 회전이 먼저 닫힌다. 그래도 숫자만 볼 거냐?\u{201D}",
                .mid: "\u{201C}하체 힘을 더 붙일 수도 있고, 지금 가동 범위를 지킬 수도 있어. 둘 다 한꺼번에는 어렵다.\u{201D}",
                .high: "\u{201C}{player}, 네 몸은 힘을 받을 준비가 됐다. 다만 지금의 부드러운 팔의 길도 자산이야. 네가 골라.\u{201D}",
            ],
            choices: [
                listen("스쿼트 무게보다 어깨 각도를 지킨다", "겨울 내내 같은 팔의 길을 보존해 투구 동작이 굳는 일을 막는다"),
                explain("하체 중량을 단계별로 올리자고 제안한다", "기록표를 남겨 힘과 가동 범위가 무너지는 지점을 찾는다"),
                challenge("이번 겨울은 힘을 붙이는 데 건다", "구속 상승을 노리지만 뻣뻣해진 몸을 다시 풀 부담도 떠안는다"),
            ]
        ),
        "evt-command-wall": Scene(
            speaker: .named("투수 코치"),
            quotes: [
                .low: "\u{201C}불펜 포수 미트만 맞히면 뭐 하나. 타자가 서면 또 한 뼘 빠지는데.\u{201D}",
                .mid: "\u{201C}타자가 서는 순간 앞발이 빨리 열린다. 공이 아니라 시선을 먼저 고쳐 보자.\u{201D}",
                .high: "\u{201C}{player}, 불펜의 공은 충분해. 이제 타자를 세워 놓고도 그 선을 지키는 연습만 남았다.\u{201D}",
            ],
            choices: [
                listen("타자 모형을 세우고 낮은 바깥쪽만 노린다", "빈 타석의 편안함을 버리고 경기와 같은 시야를 만든다"),
                explain("앞발이 열리는 순간을 영상에 표시한다", "제구가 흐트러지는 원인을 다음 훈련의 기준점으로 남긴다"),
                challenge("볼카운트마다 목표 코스를 바꿔 던진다", "실전 압박을 재현해 불펜 제구가 경기에서도 남는지 본다"),
            ]
        ),
        "evt-breaker-grip": Scene(
            speaker: .catcher,
            quotes: [
                .low: "\u{201C}많이 휘긴 하는데 미트가 아니라 네 발 앞으로 떨어져. 경기에서 요구하긴 어렵겠어.\u{201D}",
                .mid: "\u{201C}이 그립은 크게 휘고, 원래 건 네가 원하는 데 와. 어느 쪽을 먼저 살릴까?\u{201D}",
                .high: "\u{201C}{player}, 방금 건 타자가 알아도 못 닿겠다. 스트라이크로 시작하는 길만 찾으면 돼.\u{201D}",
            ],
            choices: [
                listen("원래 그립으로 스트라이크를 먼저 잡는다", "큰 궤적을 미루는 대신 경기에서 꺼낼 공 하나를 지킨다"),
                explain("새 그립의 빠지는 지점을 포수와 맞춘다", "포수가 막아 줄 범위를 정해 폭투 부담을 나눈다"),
                challenge("새 그립으로 연속 다섯 개를 존에 넣어 본다", "성공하면 곧 실전 카드가 되지만 흔들리면 처음부터 다시 잡는다"),
            ]
        ),
        "evt-recovery-day": Scene(
            speaker: .named("회복 코치"),
            quotes: [
                .low: "\u{201C}옆에서 누가 던지든 네 팔은 네 팔이야. 오늘 또 잡으면 내일부터 공이 더 무거워져.\u{201D}",
                .mid: "\u{201C}공을 놓는 날도 훈련이다. 경쟁자 불펜보다 네 회복 속도를 보자.\u{201D}",
                .high: "\u{201C}{player}, 오늘 쉬면 다음 불펜의 스무 공이 산다. 네가 그 차이를 아는 선수라고 믿는다.\u{201D}",
            ],
            choices: [
                listen("글러브를 두고 회복실로 간다", "오늘의 불안을 견디는 대신 다음 등판의 팔 힘을 지킨다"),
                explain("가벼운 밴드 운동만 하겠다고 약속한다", "완전 휴식과 감각 유지 사이에서 팔 상태를 기록한다"),
                challenge("경쟁자의 마지막 열 공만 곁에서 본다", "공은 잡지 않되 선발 경쟁의 흐름은 놓치지 않는다"),
            ]
        ),
        "evt-scout-stand": Scene(
            speaker: .named("스카우트"),
            quotes: [
                .low: "\u{201C}전광판 숫자 말고도 적을 건 많아. 같은 동작으로 다시 던질 수 있는지 보지.\u{201D}",
                .mid: "\u{201C}구속은 이미 봤다. 힘 빠진 뒤에도 포수 무릎으로 가는지가 오늘 질문이야.\u{201D}",
                .high: "\u{201C}{player}, 첫 공은 충분히 빨랐다. 이제 마지막 공까지 네 투구인지 보여 줘.\u{201D}",
            ],
            choices: [
                listen("전광판을 보지 않고 같은 코스를 반복한다", "한 번의 최고 구속보다 재현성을 평가표에 남긴다"),
                explain("오늘 점검할 구종 순서를 먼저 밝힌다", "힘자랑이 아니라 계획대로 던진다는 점을 평가표에 남긴다"),
                challenge("마지막 공까지 전력으로 밀어붙인다", "최고 수치를 노리지만 힘이 빠진 뒤의 제구도 함께 드러난다"),
            ]
        ),
        "evt-mechanics-camera": Scene(
            speaker: .named("투수 코치"),
            quotes: [
                .low: "\u{201C}네가 괜찮다 해도 화면엔 손이 먼저 나가. 이대로면 높은 공이 계속 빠진다.\u{201D}",
                .mid: "\u{201C}공이 손에서 두 프레임 일찍 떨어진다. 앞쪽 어깨가 버티는 시간을 늘려 보자.\u{201D}",
                .high: "\u{201C}{player}, 차이는 딱 두 프레임이다. 네 몸이면 오늘 안에 되찾을 수 있어.\u{201D}",
            ],
            choices: [
                listen("공 없이 앞어깨를 닫는 동작부터 반복한다", "구속을 잠시 내려놓고 릴리스의 기준점을 되찾는다"),
                explain("좋았던 영상과 나란히 겹쳐 본다", "달라진 두 프레임을 눈으로 남겨 혼자서도 교정할 수 있게 한다"),
                challenge("바로 마운드에서 수정 동작을 던져 본다", "빠른 교정을 노리지만 감각이 어긋나면 투구 수가 늘어난다"),
            ]
        ),
        "evt-rain-delay": Scene(
            speaker: .catcher,
            quotes: [
                .low: "\u{201C}팔 식었는데 초구부터 세게 갈 거야? 또 사인 바꾸지 말고 지금 정해.\u{201D}",
                .mid: "\u{201C}불펜 다섯 개밖에 못 던져. 초구는 손에 가장 빨리 붙는 공으로 가자.\u{201D}",
                .high: "\u{201C}{player}, 네 손 아직 차갑지? 내가 낮게 붙여 줄게. 첫 공부터 같이 잡자.\u{201D}",
            ],
            choices: [
                listen("초구는 낮은 직구로 미트를 맞춘다", "재개 직후 장타보다 볼넷을 먼저 막는다"),
                explain("손가락 감각이 돌아올 때까지 변화구를 미룬다", "포수가 초반 배합을 단순하게 가져갈 수 있다"),
                challenge("첫 타자부터 주무기 변화구를 꺼낸다", "타이밍을 빼앗는 만큼 젖은 공의 미끄러짐도 계산해야 한다"),
            ]
        ),
        "evt-loaded-bases": Scene(
            speaker: .catcher,
            quotes: [
                .low: "\u{201C}그때도 네가 고개 저었지. 또 만루가 오면 이번엔 내 사인 볼 거야?\u{201D}",
                .mid: "\u{201C}만루 초구, 나는 땅볼을 원했고 넌 헛스윙을 노렸어. 다음엔 하나로 맞추자.\u{201D}",
                .high: "\u{201C}{player}, 그 초구 선택은 틀리지 않았어. 다만 다음엔 내가 왜 그 공인지 먼저 알고 싶어.\u{201D}",
            ],
            choices: [
                listen("포수가 원했던 낮은 코스를 화면에 찍는다", "다음 만루에는 배터리의 첫 판단을 한곳에 모은다"),
                explain("헛스윙을 노린 타자 습관을 영상으로 보여준다", "독단이 아니라 근거 있는 선택이었다는 점을 공유한다"),
                challenge("같은 타자를 세워 두 배합을 모두 시험한다", "논쟁을 다음 경기까지 끌지 않고 훈련장에서 결론낸다"),
            ]
        ),
        "evt-first-awakening": Scene(
            speaker: .named("나"),
            quotes: [
                .low: "훈련 때 붙잡으려 할수록 달아났던 동작이 경기에서 먼저 나왔다. 우연이라고 넘기기엔 공 끝이 달랐다.",
                .mid: "앞발이 닿는 순간 팔이 늦지 않았다. 생각하기 전에 몸이 최근의 반복을 꺼냈다.",
                .high: "공을 놓기 전부터 미트가 가까워 보였다. 이제 이 동작은 빌린 감각이 아니라 내 것이었다.",
            ],
            choices: [
                listen("다음 공도 같은 호흡으로 이어 간다", "좋은 감각을 붙잡으려 힘주지 않고 몸의 순서를 지킨다"),
                explain("더그아웃에서 발 디딤 위치를 표시한다", "우연이 아니도록 재현할 단서를 남긴다"),
                challenge("가장 어려운 코스에 새 동작을 건다", "확신을 얻을 수 있지만 흔들리면 경기 흐름까지 내준다"),
            ]
        ),
        "evt-team-slump": Scene(
            speaker: .named("주장"),
            quotes: [
                .low: "\u{201C}세 번 졌다고 각자 하겠다는 게 팀이냐. 네 불펜부터 시간 맞춰.\u{201D}",
                .mid: "\u{201C}자율 훈련을 늘릴지, 다 같이 일찍 끝낼지 정해야 해. 말 없는 사람도 책임은 같아.\u{201D}",
                .high: "\u{201C}{player}, 투수조가 먼저 방향을 잡아 줘. 지금은 네 한마디를 다들 기다린다.\u{201D}",
            ],
            choices: [
                listen("각 포지션이 필요한 시간을 차례로 받는다", "서로 다른 불만을 먼저 모아 훈련 파행을 막는다"),
                explain("투수조는 짧고 집중된 불펜을 제안한다", "연패 속 과훈련을 막되 준비 부족의 책임은 투수조가 진다"),
                challenge("내일부터 전원이 같은 시간에 나오자고 한다", "팀을 한데 묶는 만큼 지친 동료를 설득할 책임도 진다"),
            ]
        ),
        "evt-injury-rumor": Scene(
            speaker: .named("동료"),
            quotes: [
                .low: "\u{201C}어깨 계속 만지잖아. 네가 말 안 하면 내가 코치한테 말할 거야.\u{201D}",
                .mid: "\u{201C}두 번 봤어. 괜찮다면 왜 자꾸 같은 데를 눌러? 같이 트레이너한테 가자.\u{201D}",
                .high: "\u{201C}{player}, 네가 숨길 때 어떤 표정인지 알아. 오늘은 나랑 바로 가자.\u{201D}",
            ],
            choices: [
                listen("동료와 함께 트레이너실로 향한다", "등판 기회가 미뤄져도 작은 통증을 부상 전에 잡는다"),
                explain("언제부터 뻐근했는지 날짜를 말한다", "소문 대신 기록으로 몸 상태를 판단하게 한다"),
                challenge("불펜 열 공 뒤 다시 보자고 한다", "문제가 없음을 보일 수 있지만 통증을 키울 위험도 남는다"),
            ]
        ),
        "evt-draft-projection": Scene(
            speaker: .named("스카우트"),
            quotes: [
                .low: "\u{201C}기사의 라운드보다 우리 기록표가 낮다. 지금은 그 차이를 인정해야 해.\u{201D}",
                .mid: "\u{201C}예상 순위는 두 라운드 높더군. 우리는 최근 세 경기의 제구를 더 무겁게 본다.\u{201D}",
                .high: "\u{201C}{player}, 기사보다 현장이 늦게 움직일 때도 있다. 다음 등판이면 표를 바꿀 근거가 생겨.\u{201D}",
            ],
            choices: [
                listen("평가표에서 낮게 잡힌 항목을 묻는다", "막연한 순위 불안 대신 다음 등판에서 바꿀 한 가지를 얻는다"),
                explain("최근 제구 수정 과정을 짧게 전한다", "낮은 기록 뒤에 이어진 변화를 평가 자료에 보탠다"),
                challenge("다음 등판의 마지막 이닝까지 보라고 한다", "말의 자신감만큼 경기 후 평가가 크게 움직인다"),
            ]
        ),
        "evt-undrafted-room": Scene(
            speaker: .named("나"),
            quotes: [
                .low: "마지막 이름까지 지나갔다. 방 안에는 꺼지지 않은 중계 화면과 세 해의 숫자만 남았다.",
                .mid: "전화는 오지 않았다. 스코어북을 펴자 잘 던진 날보다 다시 던진 날이 먼저 보였다.",
                .high: "이름은 불리지 않았다. 그래도 세 해 동안 쌓은 공이 사라진 것은 아니었다. 다음 마운드를 고를 차례다.",
            ],
            choices: [
                listen("가장 버텨 낸 경기 페이지를 펼친다", "탈락의 밤을 실패 한 줄로만 남기지 않는다"),
                explain("내일 연락할 팀과 학교를 적는다", "상실감이 가라앉기 전 다음 야구의 문을 만든다"),
                challenge("새벽 훈련 알람을 그대로 둔다", "진로가 정해지지 않아도 선수의 하루는 멈추지 않는다"),
            ]
        ),
        "evt-drafted-call": Scene(
            speaker: .named("구단 담당자"),
            quotes: [
                .low: "\u{201C}입단 뒤엔 처음부터 다시 경쟁입니다. 고교 성적은 오늘까지만 봅니다.\u{201D}",
                .mid: "\u{201C}첫 시즌은 몸부터 만들고 짧은 이닝으로 시작할 계획입니다. 본인 생각도 듣고 싶습니다.\u{201D}",
                .high: "\u{201C}{player} 선수, 지금 장점을 지우지 않는 선에서 첫 시즌을 설계했습니다. 함께 맞춰 봅시다.\u{201D}",
            ],
            choices: [
                listen("첫 시즌의 등판 계획을 메모한다", "입단의 흥분보다 새 경쟁에서 필요한 준비를 먼저 챙긴다"),
                explain("고교에서 지켜 온 루틴을 전한다", "새 훈련표가 내 강점을 지우지 않도록 기준을 공유한다"),
                challenge("짧은 이닝부터 자리를 따내겠다고 한다", "빠른 기회를 원한다는 뜻과 그에 따른 경쟁을 받아들인다"),
            ]
        ),
        "evt-scorebook-close": Scene(
            speaker: .named("나"),
            quotes: [
                .low: "잘 던진 날과 무너진 날 사이에 빈칸이 많다. 마지막 표시를 어디에 둘지 쉽게 정해지지 않는다.",
                .mid: "세 해의 스코어북을 넘기자 숫자보다 그날의 미트 소리가 먼저 돌아온다.",
                .high: "마지막 장을 덮기 전, 가장 좋았던 경기와 다시 일어선 경기에 같은 표시를 남겼다.",
            ],
            choices: [
                listen("가장 힘들었던 경기에도 별표를 친다", "좋은 기록만이 아니라 버틴 과정까지 다음 삶의 기억으로 남긴다"),
                explain("배운 한 문장을 표지 안쪽에 적는다", "다음 팀에서도 흔들릴 때 돌아올 기준을 만든다"),
                challenge("빈 마지막 장은 남겨 둔 채 덮는다", "고교 기록을 끝으로 보지 않고 다음 마운드의 여백으로 둔다"),
            ]
        ),
        // 환생 사건(2회차부터). 신뢰도로 갈리지 않는다 — 이건 사람과의 관계가 아니라
        // 자기 몸이 기억하는 일이다.
        "evt-deja-vu-mound": Scene(
            speaker: .named("나"),
            quotes: flat("처음 오르는 마운드다. 그런데 발끝이 흙을 파는 각도까지 이미 몸이 알고 있다."),
            choices: [
                listen("그 감각을 그대로 둔다", "설명하지 않고 받아들인다"),
                explain("마운드 흙을 다시 밟으며 호흡을 센다", "기시감보다 지금의 첫 타자에 집중한다"),
                challenge("아는 대로 던져 본다", "몸이 아는 쪽을 믿는다"),
            ]
        ),
        "evt-known-coach": Scene(
            speaker: .named("나"),
            quotes: flat("감독의 말버릇이 낯익다. 다음에 무슨 말을 할지 알 것 같은데, 만난 적은 없다."),
            choices: [
                listen("끝까지 들어 본다", "정말 아는 말인지 확인한다"),
                explain("먼저 아는 척하지 않는다", "처음 만난 사람으로 대한다"),
                challenge("다음 말을 먼저 꺼내 본다", "맞는지 시험해 본다"),
            ]
        ),
        "evt-body-remembers": Scene(
            speaker: .named("나"),
            quotes: flat("배운 적 없는 그립이 손에 저절로 잡힌다. 던져 보니 정말로 휜다."),
            choices: [
                listen("손이 하는 대로 둔다", "생각을 끄고 반복한다"),
                explain("새 그립을 포수 손에 직접 쥐여 준다", "둘만 아는 변화구로 만들 수 있다"),
                challenge("다음 경기에서 바로 쓴다", "실전에서 시험한다"),
            ]
        ),
        "evt-rival-deja-vu": Scene(
            speaker: .rival,
            quotes: flat("타석에 선 그가 오래 본다. \u{201C}우리… 어디서 붙은 적 있나?\u{201D}"),
            choices: [
                listen("무슨 말인지 되묻는다", "상대가 무엇을 느꼈는지 듣는다"),
                explain("처음이라고 답한다", "사실대로 말한다"),
                challenge("있다고 답한다", "설명하지 않고 던진다"),
            ]
        ),
        "evt-memory-ache": Scene(
            speaker: .named("나"),
            quotes: flat("지난번에 팔이 나갔던 바로 그 주차다. 아프지 않은데 그 자리가 계속 신경 쓰인다."),
            choices: [
                listen("오늘은 아낀다", "같은 일을 반복하지 않는다"),
                explain("트레이너에게 미리 말한다", "느낌만이라도 남겨 둔다"),
                challenge("신경 쓰지 않고 던진다", "이번엔 다르다고 믿는다"),
            ]
        ),
        "evt-second-summer": Scene(
            speaker: .named("나"),
            quotes: flat("같은 계절, 같은 대회. 이번에는 무엇이 오는지 알고 서 있다."),
            choices: [
                listen("아는 것을 믿고 준비한다", "지난번의 실수를 피한다"),
                explain("팀에 미리 알려 둔다", "혼자 지고 가지 않는다"),
                challenge("다르게 가 본다", "아는 길을 일부러 벗어난다"),
            ]
        ),
        "evt-remembered-pitch": Scene(
            speaker: .catcher,
            quotes: flat("지난 삶에서 실점했던 순간과 닮은 긴장이 돌아왔다. 포수는 아무것도 모른 채 승부구 사인을 낸다. \u{201C}여기, 어때?\u{201D}"),
            choices: [
                listen("고개를 끄덕이고 이번 삶의 포수를 믿는다", "같은 코스라도 다른 배터리와 다른 결과를 만들 기회를 연다"),
                explain("그 코스만은 피하고 싶다고 말한다", "이유를 다 밝힐 수 없어도 포수와 위험을 나눈다"),
                challenge("지난번보다 공 하나 높게 승부한다", "기억을 이용해 결말을 바꾸지만 또 맞으면 상처도 깊어진다"),
            ]
        ),
        "evt-lost-teammate": Scene(
            speaker: .named("옛 동료"),
            quotes: flat("지난 삶에서 끝까지 함께 던졌던 동료가 이번에는 유니폼을 벗었다. \u{201C}이번엔 여기까지 할래. 너는 계속 던져.\u{201D}"),
            choices: [
                listen("그만두게 된 날부터 차근차근 묻는다", "붙잡는 말보다 친구가 고른 삶을 존중한다"),
                explain("함께 던졌던 시간을 잊지 않겠다고 한다", "다른 길로 가도 관계가 끝나는 것은 아님을 전한다"),
                challenge("마지막 캐치볼 한 번을 청한다", "작별을 공의 감촉으로 남기되 미련까지 함께 돌아올 수 있다"),
            ]
        ),
        "evt-future-news": Scene(
            speaker: .named("라디오 진행자"),
            quotes: flat("라디오는 올해 우승 후보를 지난 삶과 같은 순서로 읊는다. 결말을 아는 책이 다시 첫 장을 펼쳤다."),
            choices: [
                listen("끝까지 들어 달라지는 이름이 있는지 센다", "기억이 정확한지 확인해 이번 시즌의 지도로 삼는다"),
                explain("라디오를 끄고 오늘 훈련표를 펼친다", "정해진 결말보다 지금 바꿀 수 있는 한 칸에 집중한다"),
                challenge("예상에서 빠진 팀의 경기를 찾아본다", "지난 삶에 없던 변수를 찾아 익숙한 결말을 흔든다"),
            ]
        ),
        "evt-old-nickname": Scene(
            speaker: .named("상대 포수"),
            quotes: flat("처음 만난 상대 포수가 지난 삶의 별명을 불렀다. \u{201C}왜 그렇게 봐? 다들 그렇게 부르는 줄 알았는데.\u{201D}"),
            choices: [
                listen("그 별명을 어디서 들었는지 캐묻는다", "기억이 나만의 것인지 알아낼 실마리를 얻는다"),
                explain("이번에는 아직 없는 이름이라고 털어놓는다", "이상하게 보이더라도 기억의 단서를 상대와 나눈다"),
                challenge("그 이름에 어울리는 공을 보여 주겠다고 한다", "당혹감을 승부욕으로 바꿔 다음 타석에 건다"),
            ]
        ),
        "evt-glove-worn": Scene(
            speaker: .named("나"),
            quotes: flat("새 글러브가 처음부터 손바닥 안쪽으로 부드럽게 접힌다. 지난 삶에서 수백 번 닫았던 바로 그 각도다."),
            choices: [
                listen("글러브가 접히는 길을 그대로 따른다", "몸의 기억을 받아들여 새 장비에 적응할 시간을 줄인다"),
                explain("가죽 안쪽에 오늘 날짜를 적는다", "지난 삶의 물건과 이번 삶의 시작을 구분할 표식을 남긴다"),
                challenge("일부러 반대 방향으로 다시 길들인다", "정해진 감각을 벗어나지만 익숙한 포구감도 포기한다"),
            ]
        ),
        "evt-undrafted-deja": Scene(
            speaker: .named("나"),
            quotes: flat("중계 화면이 켜지자 이름이 끝내 불리지 않았던 방의 공기가 먼저 돌아왔다. 아직 첫 순서도 시작하지 않았다."),
            choices: [
                listen("숨을 세 번 고르고 첫 순서를 지켜본다", "과거의 결말이 현재의 모든 이름을 삼키지 않게 한다"),
                explain("가족에게 잠시 창문을 열어 달라고 한다", "혼자 버티던 지난 삶과 달리 방 안의 긴장을 함께 나눈다"),
                challenge("전화기를 손에 쥔 채 끝까지 자리를 지킨다", "도망치지 않지만 같은 침묵이 오면 정면으로 견뎌야 한다"),
            ]
        ),
        "evt-bullpen-rival": Scene(
            speaker: .named("경쟁하는 동료"),
            quotes: [
                .low: "\u{201C}네 그 그립… 뭐, 안 보여줘도 되고. 어차피 자리는 하나니까.\u{201D}",
                .mid: "\u{201C}네 새 변화구 그립… 한 번만 보여줄래? 선발 자리는 서로 뺏는 사이지만, 그래도 배우고 싶어서.\u{201D}",
                .high: "\u{201C}{player}, 그 그립 좀 보여줘. 대신 내 슬라이더 쥐는 법 알려줄게. 서로 늘어야 팀이 산다.\u{201D}",
            ],
            choices: [
                listen("어느 움직임을 배우고 싶은지 묻는다", "경쟁자가 탐내는 공의 장점을 새로 알 수 있다"),
                explain("그립 잡는 법을 설명해 준다", "숨기지 않고 알려 준다"),
                challenge("자리는 마운드에서 겨루자고 한다", "선발은 경기로 정하자고 답한다"),
            ]
        ),
    ]

    /// 카테고리 기본 장면. 인용 대사는 비워 두고 화면이 이벤트 요약을 쓴다.
    public static let categoryScenes: [String: Scene] = [
        // 2회차부터의 환생 사건. 화자는 자기 자신이다 — 이 감각을 설명해 줄 사람이 없다.
        "rebirth": Scene(speaker: .named("나"), quotes: [:], choices: [
            listen("가만히 그 감각을 따라가 본다", "떠오르는 것을 밀어내지 않는다"),
            explain("착각이라고 정리한다", "지금 해야 할 일에 집중한다"),
            challenge("아는 대로 해 본다", "그 감각을 믿고 그대로 던진다"),
        ]),
        "growth": Scene(speaker: .named("훈련 파트너"), quotes: [:], choices: [
            listen("무엇을 바꾸면 좋을지 듣는다", "상대의 제안을 먼저 듣는다"),
            explain("지금 잡은 감각을 설명한다", "내가 느낀 그립을 말한다"),
            challenge("경기에서 바로 시험하겠다고 한다", "다음 등판에서 써 본다"),
        ]),
        "health": Scene(speaker: .named("트레이너"), quotes: [:], choices: [
            listen("오늘은 쉬라는 말을 따른다", "회복을 우선한다"),
            explain("몸 상태를 기록으로 보여준다", "지금 느낌을 설명한다"),
            challenge("그래도 오늘 던지겠다고 한다", "쉬는 대신 공을 잡는다"),
        ]),
        "team": Scene(speaker: .named("주장"), quotes: [:], choices: [
            listen("팀이 정한 순서를 받아들인다", "맡겨진 역할을 따른다"),
            explain("맡을 역할을 분명히 말한다", "내 생각을 팀에 전한다"),
            challenge("더 긴 이닝을 맡겠다고 나선다", "책임을 자청한다"),
        ]),
        "draft": Scene(speaker: .named("스카우트"), quotes: [:], choices: [
            listen("무엇을 평가하는지 듣는다", "스카우트가 보는 것을 듣는다"),
            explain("무엇을 바꿨는지 설명한다", "달라진 점을 말한다"),
            challenge("가장 좋은 공으로 승부한다", "실력으로 답한다"),
        ]),
        "media": Scene(speaker: .named("취재진"), quotes: [:], choices: [
            listen("질문의 뜻을 되묻는다", "무엇을 궁금해하는지 듣는다"),
            explain("그 공을 고른 이유를 말한다", "내 판단을 설명한다"),
            challenge("다음 경기로 답하겠다고 한다", "결과로 보여준다"),
        ]),
        "fan": Scene(speaker: .named("팬"), quotes: [:], choices: [
            listen("바라는 것을 귀담아듣는다", "팬이 좋아하는 공을 확인한다"),
            explain("그 공을 아끼는 이유를 적는다", "내 마음을 답장에 담는다"),
            challenge("다음 경기에서 보여주겠다고 약속한다", "기대에 답한다"),
        ]),
        "game": Scene(speaker: .catcher, quotes: [:], choices: [
            listen("지난 상황을 포수와 되짚는다", "무엇이 문제였는지 듣는다"),
            explain("그때의 선택을 설명한다", "내 판단을 말한다"),
            challenge("다음엔 더 공격적으로 가겠다고 한다", "같은 상황을 정면으로 맞선다"),
        ]),
        "awakening": Scene(speaker: .catcher, quotes: [:], choices: [
            listen("익은 동작을 다시 확인한다", "몸의 감각을 점검한다"),
            explain("그 감각을 말로 정리한다", "무엇이 달라졌는지 설명한다"),
            challenge("경기에서 바로 써 보겠다고 한다", "실전에서 시험한다"),
        ]),
        "life": Scene(speaker: .named("가족"), quotes: [:], choices: [
            listen("가족의 이야기를 먼저 듣는다", "마음을 가라앉힌다"),
            explain("지금의 계획을 설명한다", "내 생각을 전한다"),
            challenge("부족한 시간을 훈련으로 메우겠다고 한다", "남은 시간을 아껴 쓴다"),
        ]),
        "legacy": Scene(speaker: .named("지난 기록"), quotes: [:], choices: [
            listen("가장 좋았던 경기를 되짚는다", "지난 세 해를 돌아본다"),
            explain("남길 기록을 골라 적는다", "무엇을 남길지 정리한다"),
            challenge("다음 선수에게 남길 한 가지를 정한다", "가장 중요한 하나를 고른다"),
        ]),
    ]

    /// 핵심 3인은 고정 장면이 없어도 자기 목소리로 말한다.
    private static func coreFallback(_ category: String) -> Scene? {
        switch category {
        case "coach": scenes["evt-coach-role"]
        case "catcher": scenes["evt-catcher-sign"]
        case "rival": scenes["evt-rival-message"]
        default: nil
        }
    }

    // MARK: - 응답 뒤의 서사

    /// 응답을 고른 뒤 그 사람이 어떻게 반응했는가.
    ///
    /// 예전에는 응답을 누르면 요약 배너 한 줄로 끝났다. "포수가 어떻게 반응했는지"가 없으니
    /// 관계가 숫자(팀의 믿음 60)로만 존재했다(품질 평가 §4.3).
    ///
    /// 같은 장면에서도 무엇을 골랐는지에 따라 즉시 이어지는 행동이 달라진다.
    /// `name`은 이 회차의 실명(감독·포수·라이벌). 넣으면 "윤태문 감독은 웃었다"가 되고,
    /// 안 넣으면 예전처럼 역할명으로 말한다 — 세계가 내 사람을 이름으로 부르는 것이
    /// 이 게임이 파는 애착의 최소 단위다(3차 패널 P2).
    public static func aftermath(
        eventID: String,
        speaker: Speaker,
        name: String? = nil,
        response: RelationshipResponse,
        trustChange: Int
    ) -> String {
        let who: String
        switch speaker {
        case .coach: who = name.map { "\($0) 감독" } ?? "감독"
        case .catcher: who = name.map { "\($0) 포수" } ?? "포수"
        case .rival: who = name ?? "상대"
        case .named(let named): who = named
        }
        // 받침을 보고 조사를 고른다. "감독은(는)"은 기계가 쓴 문장이고,
        // 하필 매 관계 장면의 마지막 줄 — 가장 집중해서 읽는 자리다.
        guard let outcomes = aftermathOutcomes[eventID] else {
            return legacyAftermath(who: who, response: response, trustChange: trustChange)
        }
        let immediate = switch response {
        case .listen: outcomes.listen
        case .explain: outcomes.explain
        case .challenge: outcomes.challenge
        }
        return immediate
    }

    /// 새 콘텐츠가 추가될 때 반응문도 함께 저술되었는지 테스트가 확인하는 공개 목록이다.
    public static let aftermathEventIDs: Set<String> = Set(aftermathOutcomes.keys)

    private struct AftermathOutcomes: Sendable {
        let listen: String
        let explain: String
        let challenge: String
    }

    private static func outcomes(_ listen: String, _ explain: String, _ challenge: String) -> AftermathOutcomes {
        AftermathOutcomes(listen: listen, explain: explain, challenge: challenge)
    }

    private static let aftermathOutcomes: [String: AftermathOutcomes] = [
        "evt-bullpen-first": outcomes("포수는 가장 늦게 보였던 변화구를 꼽고 미트 높이를 다시 잡았다.", "직구 뒤 떨어지는 공의 사인을 둘만의 첫 순서로 정했다.", "마지막 열 공을 받은 포수가 성공한 사인마다 손가락을 접어 셌다."),
        "evt-coach-role": outcomes("감독은 경기 후반에 내 공이 필요한 이유와 아직 부족한 한 가지를 짚었다.", "최근 선발 기록을 넘겨 본 감독이 다음 평가 등판의 기준을 적었다.", "감독은 다음 등판 날짜에 동그라미를 치고 선발 경쟁을 다시 열어 두었다."),
        "evt-catcher-sign": outcomes("포수는 세 타석에서 타자가 보인 반응을 미트 위치와 함께 되짚었다.", "높은 공을 기다렸다는 말을 들은 포수가 바뀐 사인마다 이유를 붙였다.", "포수는 다음 타석 첫 사인을 내게 맡기고 자기 미트를 두드렸다."),
        "evt-rival-video": outcomes("라이벌은 타이밍을 읽기 시작한 경기와 반복 습관 하나를 답장으로 보냈다.", "내가 높은 공으로 노렸던 것을 읽고 영상의 같은 장면을 다시 잘라 보냈다.", "라이벌은 다른 공까지 맞혀 보겠다며 재대결 날짜를 물었다."),
        "evt-winter-weight": outcomes("웨이트 코치는 어깨 각도를 지키는 주간 측정표를 훈련표에 보탰다.", "중량을 올릴 때마다 가동 범위를 다시 재는 계단식 계획을 적었다.", "겨울 중량 목표에 선을 긋고 뻣뻣해진 몸을 풀 일정까지 함께 정했다."),
        "evt-command-wall": outcomes("타자 모형의 바깥쪽 무릎에 표적을 붙이고 공 스무 개를 같은 높이로 받았다.", "좋았던 영상과 겹친 코치가 앞발이 먼저 열리는 프레임에 선을 그었다.", "볼카운트를 외치는 타자를 세우자 불펜의 편한 호흡이 사라졌다."),
        "evt-breaker-grip": outcomes("포수는 원래 그립의 스트라이크를 받은 뒤 그 사인을 경기용으로 남겼다.", "새 공이 빠지는 자리까지 몸으로 막아 보고 허용할 낙폭을 정했다.", "연속 다섯 공의 위치를 적어 새 그립을 실전에 쓸 기준을 만들었다."),
        "evt-recovery-day": outcomes("회복 코치는 글러브를 보관함에 넣고 다음 불펜의 스무 공을 예약했다.", "밴드 운동 뒤 좌우 어깨 각도를 재고 더 넘지 말아야 할 선을 표시했다.", "경쟁자의 마지막 열 공을 함께 본 뒤 오늘 내 투구 수에는 0을 적었다."),
        "evt-captain-talk": outcomes("주장은 필요한 시작 이닝과 뒤에 대기할 투수를 차례로 알려 주었다.", "내가 말한 투구 수에 맞춰 계투 순서를 한 칸 당겼다.", "주장은 긴 이닝 계획 첫 줄에 내 이름을 써 넣었다."),
        "evt-scout-stand": outcomes("전광판을 보지 않은 내 마지막 열 공 옆에 같은 곳으로 간 공의 수가 따로 적혔다.", "스카우트는 내가 밝힌 점검 순서대로 기록지를 세 칸으로 나눴다.", "마지막 전력투구 뒤에도 미트 위치가 남았는지 기록표를 한 장 더 채웠다."),
        "evt-loss-interview": outcomes("기자는 질문을 고쳐 마지막 공을 던질 때 본 타자의 반응부터 물었다.", "그 공을 고른 이유가 녹음기에 남자 후속 질문은 더 짧아졌다.", "기자는 다음 경기 날짜를 묻고 녹음기를 껐다."),
        "evt-fan-letter": outcomes("편지를 다시 읽자 느린 공을 좋아한 정확한 경기와 타석이 눈에 들어왔다.", "그 공을 던지는 이유를 적은 답장이 어린 팬에게 돌아갔다.", "다음 경기에서 보여 주겠다는 약속 아래 날짜를 크게 써 보냈다."),
        "evt-battery-dinner": outcomes("포수는 받기 두려웠던 공 세 개의 낙폭을 냅킨에 그렸다.", "손에서 빠지는 날의 감각을 듣고 포수가 막아 줄 범위를 정했다.", "다음 불펜에는 가장 어려운 공만 스무 개 받기로 했다."),
        "evt-coach-bench": outcomes("감독은 팔이 늦었던 동작을 영상에서 멈춰 보여 주었다.", "피로 기록을 훑은 뒤 쉬는 하루와 복귀 투구 수를 함께 정했다.", "불펜 투구를 지켜본 감독이 오늘 등판 여부를 그 자리에서 결정했다."),
        "evt-rival-message": outcomes("라이벌은 내가 반복한 초구의 높이와 타이밍을 숫자로 답했다.", "그 초구의 노림수를 읽고도 다음에는 기다려 보겠다고 했다.", "라이벌은 다른 답을 맞혀 보겠다며 웃는 표시를 붙였다."),
        "evt-mechanics-camera": outcomes("공 없이 앞어깨를 닫자 코치가 좋아진 프레임에서 영상을 멈췄다.", "두 영상을 겹쳐 보니 릴리스가 빨라진 순간이 선 하나로 드러났다.", "고친 동작의 첫 열 공이 새 영상 파일로 남았다."),
        "evt-velocity-drop": outcomes("트레이너는 구속이 빠진 두 경기에서 팔이 늦은 동작을 나란히 보여 주었다.", "내가 말한 피로와 등판 간격을 기록표 한 줄에 함께 적었다.", "며칠 뒤 다시 잰 구속과 회복 속도가 같은 표에 올랐다."),
        "evt-new-catcher": outcomes("새 포수가 손짓 순서를 천천히 보이고 헷갈릴 동작마다 멈췄다.", "기존 사인을 지켜야 할 주자 상황을 둘이 따로 표시했다.", "두 사인 체계를 불펜에서 번갈아 써 보고 경기용 한 장으로 합쳤다."),
        "evt-school-record": outcomes("후배는 기록이 시작된 해와 남은 여섯 칸을 스코어북에서 찾아 보여 주었다.", "한 타자씩 가겠다는 말에 후배는 기록표를 조용히 접었다.", "후배는 다음 경기 스코어북을 들고 가장 먼저 오겠다고 했다."),
        "evt-rain-delay": outcomes("낮은 직구가 미트에 들어오자 포수가 같은 높이로 초구 사인을 냈다.", "변화구를 미루기로 한 포수가 첫 타자의 두 공을 단순하게 맞췄다.", "젖은 주무기 변화구가 바닥에 닿기 전 포수 미트에 걸렸다."),
        "evt-loaded-bases": outcomes("포수가 원했던 낮은 코스가 화면에 찍히고 다음 만루의 첫 사인으로 남았다.", "타자 습관을 본 포수가 헛스윙을 노린 이유 옆에 자기 의견을 적었다.", "두 배합을 모두 시험한 뒤 더 약한 타구가 나온 순서에 동그라미를 쳤다."),
        "evt-first-awakening": outcomes("같은 호흡으로 던진 다음 공에서도 팔이 늦지 않았다.", "더그아웃 바닥에 표시한 발 위치가 다음 이닝의 기준점이 됐다.", "가장 어려운 코스에서도 새 동작이 무너지지 않고 미트 소리를 남겼다."),
        "evt-team-slump": outcomes("주장은 포지션마다 필요한 시간을 받아 겹치지 않는 훈련표를 만들었다.", "투수조의 짧은 불펜안이 하루 시험 일정으로 회의판에 올랐다.", "같은 시작 시간에 모인 동료들 앞에서 내가 첫 훈련 순서를 맡았다."),
        "evt-bullpen-rival": outcomes("동료는 배우고 싶은 손가락 움직임을 짚으며 자기 공의 고민도 털어놓았다.", "내 그립을 받아 든 동료가 자기 슬라이더 쥐는 법도 내밀었다.", "둘은 그립 이야기를 접고 다음 등판의 이닝으로 선발 자리를 겨루기로 했다."),
        "evt-scout-question": outcomes("스카우트는 보고서에서 가장 오래 멈춘 장면과 평가 항목 하나를 짚었다.", "수정한 훈련 과정을 들은 뒤 다음 등판에서 볼 동작을 적었다.", "스카우트는 가장 좋은 공을 확인할 이닝까지 남아 있겠다고 했다."),
        "evt-parent-call": outcomes("부모님은 집에서 있었던 일을 한참 말한 뒤에야 야구 이야기를 꺼냈다.", "내 계획을 들은 부모님이 다음 통화 날짜를 달력에 적었다.", "다음 경기를 보겠다는 말 뒤에 밥부터 챙기라는 당부가 따라왔다."),
        "evt-exam-week": outcomes("선생님은 수첩에 옮긴 시험 범위를 보고 원정 전 자습 시간을 비워 주었다.", "내가 나눈 시간표에서 빠진 과목 하나를 선생님이 채워 주었다.", "선생님은 남는 시간을 훈련에 쓰는 대신 제출 기한만은 지키라고 못 박았다."),
        "evt-injury-rumor": outcomes("동료는 내 가방을 들어 주고 트레이너실까지 함께 걸었다.", "뻐근함이 시작된 날짜와 어깨 위치를 동료가 대신 기록해 주었다.", "동료는 불펜 열 공을 끝까지 보고 어깨를 다시 만지는 순간을 놓치지 않았다."),
        "evt-national-stage": outcomes("중계 PD는 내가 짚은 선 밖으로 카메라 동선을 옮겼다.", "평소 루틴을 이어 가겠다는 말에 촬영 시작 시각만 알려 주었다.", "공에만 집중하는 동안 카메라는 마지막 불펜 공까지 조용히 따라왔다."),
        "evt-catcher-doubt": outcomes("포수는 좋았던 사인의 타자 반응부터 말하고 자기 의도를 다시 짚었다.", "거절한 세 타석을 함께 보며 내가 읽은 움직임마다 표시를 남겼다.", "다음 경기 첫 세 타자를 내 순서대로 가고 네 번째부터 다시 맞추기로 했다."),
        "evt-coach-last-advice": outcomes("감독은 자기가 고를 훈련 하나와 그 이유를 짧게 들려주었다.", "내가 짚은 흔들린 장면에 마지막 훈련의 확인 항목을 붙였다.", "감독은 가장 자신 있는 공을 다듬는 훈련의 시작과 끝을 전부 맡겼다."),
        "evt-rival-final": outcomes("라이벌은 그 코스를 가리킨 이유를 말하다가 마지막 한마디는 삼켰다.", "지난 공이 실투가 아니었다는 대답에 같은 자리로 배트 끝을 돌려놓았다.", "승부를 받자 라이벌은 내 가장 좋은 공을 기다리며 타석 흙을 다시 골랐다."),
        "evt-draft-projection": outcomes("스카우트는 낮게 잡힌 평가 항목과 최근 세 경기의 근거를 차례로 짚었다.", "제구를 고친 과정을 듣고 다음 등판에서 달라질 수 있는 칸을 표시했다.", "스카우트는 마지막 이닝까지 보고 순위표를 고치겠다고 했다."),
        "evt-undrafted-room": outcomes("가장 버텨 낸 경기의 페이지를 펼치자 끝내지 않은 이닝들이 먼저 보였다.", "빈 장에 적은 팀과 학교 이름 옆으로 내일 걸 전화 순서를 매겼다.", "새벽 훈련 알람을 끄지 않은 채 다음 마운드의 연락을 기다렸다."),
        "evt-drafted-call": outcomes("담당자는 첫 시즌의 등판 간격과 짧은 이닝 계획을 천천히 읽어 주었다.", "내 루틴을 들은 뒤 새 훈련표에서 지켜 줄 순서에 표시했다.", "짧은 이닝부터 경쟁하겠다는 말에 첫 평가 날짜를 알려 주었다."),
        "evt-scorebook-close": outcomes("가장 힘들었던 경기에도 별표를 치자 다시 오른 다음 페이지가 함께 펼쳐졌다.", "표지 안쪽의 한 문장이 다음 팀에서도 돌아올 기준으로 남았다.", "빈 마지막 장을 남겨 둔 채 스코어북을 덮었다."),
        "evt-deja-vu-mound": outcomes("감각을 억지로 붙잡지 않자 발끝이 익숙한 각도를 스스로 찾았다.", "마운드 흙을 다시 밟고 센 호흡이 지금의 첫 타자를 앞으로 데려왔다.", "몸이 아는 대로 던진 공이 처음 밟은 마운드의 미트에 꽂혔다."),
        "evt-known-coach": outcomes("감독의 말을 끝까지 듣자 기억과 다른 마지막 한마디가 남았다.", "처음 만난 사람처럼 답하자 낯익은 말버릇만 조용히 지나갔다.", "다음 말을 먼저 꺼내자 감독은 잠시 멈춘 뒤 전혀 다른 지시를 내렸다."),
        "evt-body-remembers": outcomes("생각을 끄고 반복하자 낯익은 궤적이 같은 자리로 세 번 휘었다.", "포수 손에 쥐여 준 그립이 둘만 아는 새 변화구가 됐다.", "경기에서 바로 꺼낸 공은 타자의 배트 아래로 사라졌다."),
        "evt-rival-deja-vu": outcomes("무엇을 느꼈는지 묻자 라이벌은 내 투구 동작 하나가 낯익다고 했다.", "처음이라는 대답 뒤에도 라이벌은 타석에서 오래 시선을 떼지 않았다.", "붙은 적 있다고 하자 라이벌은 이유를 묻지 않고 다음 공을 기다렸다."),
        "evt-memory-ache": outcomes("오늘 공을 아끼자 지난 삶에서 다쳤던 주차가 조용히 지나갔다.", "트레이너 기록에 통증 없는 자리와 지난 기억의 날짜가 함께 남았다.", "신경 쓰지 않고 던진 뒤에도 그 자리는 오래 팔을 움직일 때마다 따라왔다."),
        "evt-second-summer": outcomes("지난 실수를 피하는 준비가 이번 팀의 첫 경기 계획에 반영됐다.", "팀에 미리 알린 기억 덕분에 혼자 결정해야 할 순간이 줄었다.", "아는 길을 벗어난 선택 하나가 같은 여름에 다른 장면을 만들었다."),
        "evt-remembered-pitch": outcomes("이번 삶의 포수를 믿고 던지자 미트 소리만 남았다.", "지난 실점이 떠오른다는 말에 포수가 미트를 한 칸 옮겼다.", "공 하나 높인 승부가 타자의 배트 끝을 비껴갔다."),
        "evt-lost-teammate": outcomes("동료는 그만두게 된 날부터 천천히 말하고 유니폼을 접었다.", "함께 던진 시간을 잊지 않겠다는 말 뒤에 연락할 약속이 남았다.", "마지막 캐치볼의 공을 둘이 한 번씩 오래 쥐었다."),
        "evt-future-news": outcomes("방송을 끝까지 들으며 기억과 다른 이름 하나에 표시했다.", "라디오를 끄자 오늘 바꿀 수 있는 훈련 한 칸이 다시 보였다.", "예상에서 빠진 팀의 경기에서 지난 삶에 없던 선수를 찾아냈다."),
        "evt-old-nickname": outcomes("별명을 어디서 들었는지 묻자 상대 포수는 처음 들은 장소를 정확히 댔다.", "이번에는 아직 없는 이름이라는 말에 상대 포수가 웃음을 거두었다.", "그 별명에 어울리는 공을 약속하자 다음 타석의 승부가 정해졌다."),
        "evt-glove-worn": outcomes("글러브가 접히는 길을 따르자 새 가죽이 손바닥에 빠르게 붙었다.", "안쪽에 적은 오늘 날짜가 지난 삶의 물건과 경계를 만들었다.", "반대 방향으로 길들이자 이번 삶만의 두 번째 접힘이 생겼다."),
        "evt-undrafted-deja": outcomes("숨을 세 번 고른 뒤 첫 순서가 끝날 때까지 자리를 지켰다.", "가족이 연 창문으로 바람이 들어와 오래된 방의 공기를 밀어냈다.", "전화기를 쥔 손을 풀지 않고 마지막 순서까지 화면을 바라봤다."),
        "evt-arm-care": outcomes("트레이너가 공을 치우고 팔이 가벼워질 때까지 짧은 휴식을 잡았다.", "정밀 검진표에 통증 위치와 다음 투구 가능일이 함께 적혔다.", "참고 던진 공 뒤로 트레이너가 즉시 팔을 감싸 투구를 중단시켰다."),
    ]

    private static func legacyAftermath(who: String, response: RelationshipResponse, trustChange: Int) -> String {
        let eun = particle(who, final: "은", open: "는")
        let i = particle(who, final: "이", open: "가")
        if trustChange < 0 { return "\(who)\(eun) 짧게 답하고 대화를 마쳤다." }
        switch response {
        case .listen: return "\(who)\(i) 하려던 말을 끝까지 이어 갔다."
        case .explain: return "\(who)\(i) 내 말을 메모해 두었다."
        case .challenge: return "\(who)\(i) 다음 승부를 지켜보겠다고 했다."
        }
    }

    /// 받침 유무로 조사를 고른다. 앱의 KoreanCopy와 같은 규칙 — 커널 문자열은
    /// 커널이 완성해서 내보낸다(화면이 조사를 고치게 두면 두 규칙이 갈라진다).
    static func particle(_ word: String, final withFinal: String, open withoutFinal: String) -> String {
        let scalar = word.unicodeScalars.reversed().first { (0xAC00...0xD7A3).contains(Int($0.value)) }
        guard let scalar else { return withoutFinal }
        return (Int(scalar.value) - 0xAC00) % 28 == 0 ? withoutFinal : withFinal
    }
}
