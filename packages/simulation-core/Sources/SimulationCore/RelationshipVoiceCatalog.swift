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
            explain("사인을 바꾼 이유를 설명한다", "타자가 높은 공을 기다렸다고 말한다"),
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
            explain("거절했던 세 타석의 이유를 설명한다", "내가 본 타자 반응을 말한다"),
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
                listen("먼저 부모님 이야기를 듣는다", "집의 걱정을 끝까지 듣는다"),
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
                listen("선생님 말을 먼저 새겨듣는다", "며칠은 책상 앞에 앉는다"),
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
                listen("카메라 동선을 확인한다", "어디를 비추는지 듣는다"),
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
                listen("팀이 필요한 이닝부터 듣는다", "주장이 그린 그림을 확인한다"),
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
                listen("무엇을 눈여겨보는지 먼저 듣는다", "스카우트가 보는 지점을 확인한다"),
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
                listen("무엇을 점검해야 하는지 듣는다", "트레이너의 판단을 먼저 듣는다"),
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
                .high: "\u{201C}{player}, 네 몸은 힘을 받을 준비가 됐다. 다만 지금의 부드러운 팔길도 자산이야. 네가 골라.\u{201D}",
            ],
            choices: [
                listen("스쿼트 무게보다 어깨 각도를 지킨다", "구속 욕심을 늦추는 대신 겨울 내내 같은 팔길을 보존한다"),
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
                .low: "\u{201C}많이 휘긴 하는데 미트가 아니라 네 발앞으로 떨어져. 경기에서 요구하긴 어렵겠어.\u{201D}",
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
                explain("오늘 점검할 구종 순서를 먼저 밝힌다", "훈련 목적이 분명한 투수라는 인상을 건다"),
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
                challenge("첫 타자부터 주무기 변화구를 꺼낸다", "타이밍을 빼앗지만 젖은 공이 미끄러질 위험을 감수한다"),
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
                .low: "훈련 때 붙잡으려 할수록 달아났던 동작이 경기에서 먼저 나왔다. 우연이라고 넘기기엔 공끝이 달랐다.",
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
                challenge("내일부터 전원이 같은 시간에 나오자고 한다", "팀을 한데 묶지만 지친 동료들의 반발도 감수한다"),
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
                explain("긴장 탓이라고 정리한다", "지금 할 일에 집중한다"),
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
                explain("포수에게 새 그립이라고 말한다", "함께 확인해 본다"),
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
            quotes: flat("포수가 지난 삶에서 홈런을 맞았던 바로 그 코스에 사인을 냈다. 그는 아무것도 모른 채 미트를 댄다. \u{201C}여기, 어때?\u{201D}"),
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
                listen("그만두기로 한 날의 이야기를 곁에서 받는다", "붙잡는 말보다 친구가 고른 삶을 존중한다"),
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
                explain("이번에는 아직 없는 이름이라고 털어놓는다", "이상한 사람으로 보일 위험을 감수하고 진실의 반을 내민다"),
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
                listen("왜 그 그립이 궁금한지 듣는다", "동료의 생각을 먼저 듣는다"),
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
    /// 신뢰도가 실제로 올랐는지 내렸는지에 따라 갈린다 — 코어가 이미 계산한 값만 읽는다.
    /// `name`은 이 회차의 실명(감독·포수·라이벌). 넣으면 "윤태문 감독은 웃었다"가 되고,
    /// 안 넣으면 예전처럼 역할명으로 말한다 — 세계가 내 사람을 이름으로 부르는 것이
    /// 이 게임이 파는 애착의 최소 단위다(3차 패널 P2).
    public static func aftermath(speaker: Speaker, name: String? = nil, response: RelationshipResponse, trustChange: Int) -> String {
        let who: String
        switch speaker {
        case .coach: who = name.map { "\($0) 감독" } ?? "감독"
        case .catcher: who = name.map { "\($0) 포수" } ?? "포수"
        case .rival: who = name ?? "상대"
        case .named(let named): who = named
        }
        // 받침을 보고 조사를 고른다. "감독은(는)"은 기계가 쓴 문장이고,
        // 하필 매 관계 장면의 마지막 줄 — 가장 집중해서 읽는 자리다.
        let eun = particle(who, final: "은", open: "는")
        let i = particle(who, final: "이", open: "가")
        let gwa = particle(who, final: "과", open: "와")
        if trustChange <= -5 {
            switch response {
            case .listen: return "\(who)\(eun) 더 말하지 않았다. 듣기만 한 것이 이번에는 답이 아니었다."
            case .explain: return "설명은 끝까지 했지만 \(who)의 표정은 달라지지 않았다."
            case .challenge: return "\(who)\(i) 짧게 고개를 저었다. 지금은 그 말을 받을 자리가 아니었다."
            }
        }
        if trustChange < 0 {
            return "\(who)\(eun) 알겠다고만 했다. 남는 것이 없는 대화였다."
        }
        if trustChange >= 7 {
            switch response {
            case .listen: return "\(who)\(i) 하려던 말을 다 했다. 끝까지 들은 것이 오늘의 답이었다."
            case .explain: return "\(who)\(i) 고개를 끄덕였다. 근거가 있는 말은 대체로 통한다."
            case .challenge: return "\(who)\(i) 웃었다. \u{201C}그럼 보여 줘.\u{201D} 다음 공에 걸린 것이 하나 늘었다."
            }
        }
        return "\(who)\(gwa)의 대화는 조용히 마무리됐다. 서로 한 걸음씩은 알게 됐다."
    }

    /// 받침 유무로 조사를 고른다. 앱의 KoreanCopy와 같은 규칙 — 커널 문자열은
    /// 커널이 완성해서 내보낸다(화면이 조사를 고치게 두면 두 규칙이 갈라진다).
    static func particle(_ word: String, final withFinal: String, open withoutFinal: String) -> String {
        let scalar = word.unicodeScalars.reversed().first { (0xAC00...0xD7A3).contains(Int($0.value)) }
        guard let scalar else { return withoutFinal }
        return (Int(scalar.value) - 0xAC00) % 28 == 0 ? withoutFinal : withFinal
    }
}
