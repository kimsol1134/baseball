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
            .high: "\u{201C}이번엔 네가 경기 후반을 닫아 줘. 마지막 이닝은 아무한테나 안 맡긴다.\u{201D}",
        ], choices: [
            listen("불펜으로 옮긴 이유를 묻는다", "감독이 본 약점부터 듣는다"),
            explain("최근 선발 등판 기록을 꺼내 보인다", "선발로 남고 싶은 이유를 말한다"),
            challenge("다음 등판으로 선발 자리를 되찾겠다고 한다", "결과로 증명하겠다고 답한다"),
        ]),
        "evt-coach-bench": Scene(speaker: .coach, quotes: [
            .low: "\u{201C}오늘은 뺀다. 몸 상태를 나한테 숨기는 선수는 더 오래 못 믿어.\u{201D}",
            .mid: "\u{201C}이번 등판은 쉰다. 요즘은 팔이 몸보다 늦게 따라온다.\u{201D}",
            .high: "\u{201C}하루 쉬자. 네가 무리하는 걸 알면서 내보내면, 그건 내 잘못이 되니까.\u{201D}",
        ], choices: [
            listen("어느 동작이 늦었는지 묻는다", "감독의 관찰을 자세히 듣는다"),
            explain("최근 피로 기록을 보여준다", "몸 상태를 숨김없이 설명한다"),
            challenge("불펜 투구를 보고 결정해 달라고 한다", "오늘 던질 기회를 요청한다"),
        ]),
        "evt-coach-last-advice": Scene(speaker: .coach, quotes: [
            .low: "\u{201C}마지막 훈련이다. …아직도 내가 정해 줘야 하나. 스스로 못 고르면 프로에선 더 헤맨다.\u{201D}",
            .mid: "\u{201C}마지막 훈련은 네가 정해라. 지금 가장 부족한 게 뭐지?\u{201D}",
            .high: "\u{201C}마지막 훈련은 너한테 맡긴다. 3년을 봤으니, 이제 네 판단을 믿어 볼 때도 됐지.\u{201D}",
        ], choices: [
            listen("감독이라면 무엇을 고를지 묻는다", "마지막 조언을 먼저 듣는다"),
            explain("최근 경기에서 흔들린 장면을 짚는다", "고치려는 부분을 설명한다"),
            challenge("가장 자신 있는 공을 더 다듬겠다고 한다", "강점으로 승부하겠다고 답한다"),
        ]),

        // 포수 4장면
        "evt-catcher-sign": Scene(speaker: .catcher, quotes: [
            .low: "\u{201C}또 사인이 세 번 바뀌었어. …이럴 거면 왜 나랑 배터리를 맞춰?\u{201D}",
            .mid: "\u{201C}오늘 사인이 세 번이나 바뀌었어. 내가 놓친 게 뭐였어?\u{201D}",
            .high: "\u{201C}세 번 바꾼 거, 오늘은 다 맞았어. 이제 네가 뭘 보는지 대충 읽혀.\u{201D}",
        ], choices: [
            listen("포수가 본 타자 반응부터 묻는다", "내가 못 본 장면을 확인한다"),
            explain("사인을 바꾼 이유를 설명한다", "타자가 높은 공을 기다렸다고 말한다"),
            challenge("다음 타석은 내 순서대로 가 보자고 한다", "내 선택을 시험해 보자고 제안한다"),
        ]),
        "evt-battery-dinner": Scene(speaker: .catcher, quotes: [
            .low: "\u{201C}네 변화구, 솔직히 나도 못 받겠어. 이건 배터리가 아니라 각자 야구잖아.\u{201D}",
            .mid: "\u{201C}솔직히 네 변화구가 어디로 올지 몰라서 겁날 때가 있어.\u{201D}",
            .high: "\u{201C}이제 네 변화구는 눈 감고도 받아. 손 떠나는 순간 어디 떨어질지 보이거든.\u{201D}",
        ], choices: [
            listen("받기 어려웠던 공을 하나씩 묻는다", "포수가 불안했던 지점을 듣는다"),
            explain("손에서 빠지는 날의 감각을 말한다", "변화구가 흔들린 이유를 설명한다"),
            challenge("다음 불펜에서 가장 어려운 공만 받아 달라고 한다", "함께 해법을 찾자고 제안한다"),
        ]),
        "evt-catcher-doubt": Scene(speaker: .catcher, quotes: [
            .low: "\u{201C}사인을 그렇게 거절할 거면 마운드에서 혼자 다 정해. …난 뭐 하러 앉아 있어?\u{201D}",
            .mid: "\u{201C}요즘 내 사인을 자꾸 거절하잖아. 내가 못 본 게 있어?\u{201D}",
            .high: "\u{201C}요즘 네가 고개 젓는 공이 더 좋더라. 네가 보는 걸 나도 보고 싶어.\u{201D}",
        ], choices: [
            listen("최근 사인이 좋았던 장면부터 묻는다", "포수의 의도를 다시 듣는다"),
            explain("거절했던 세 타석의 이유를 설명한다", "내가 본 타자 반응을 말한다"),
            challenge("다음 경기의 첫 세 타자는 내 순서로 가자고 한다", "내 판단을 결과로 확인하자고 한다"),
        ]),
        "evt-new-catcher": Scene(
            speaker: .catcher,
            quotes: flat("\u{201C}전 학교에서는 이 사인을 썼어. 우리도 다음 경기부터 바꿔 볼래?\u{201D}"),
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
            .high: "\u{201C}높은 포심, 드디어 맞췄어. …근데 이거 하나 맞추는 데 3년 걸렸다.\u{201D} 영상 끝엔 웃는 표시가 붙어 있었다.",
        ], choices: [
            listen("언제부터 타이밍을 읽었는지 묻는다", "내 반복 습관을 확인한다"),
            explain("그 공으로 노렸던 것을 솔직히 말한다", "서로의 판단을 맞춰 본다"),
            challenge("다음에는 같은 높이에서 다른 공을 던지겠다고 한다", "재대결을 약속한다"),
        ]),
        "evt-rival-final": Scene(speaker: .rival, quotes: [
            .low: "타석에 선 그가 포수 미트도 보지 않고 웃는다. \u{201C}어차피 거기로 올 거잖아. 다 알아.\u{201D}",
            .mid: "타석에 들어선 그가 지난 경기와 같은 코스를 배트 끝으로 가리킨다. \u{201C}또 여기로 던져 봐.\u{201D}",
            .high: "타석에 들어선 그가 배트를 고쳐 쥐며 낮게 말한다. \u{201C}마지막이네. 네 제일 좋은 공으로 와. 그래야 이겨도 져도 남지.\u{201D}",
        ], choices: [
            listen("왜 그 코스를 가리켰는지 되묻는다", "상대가 노리는 말을 더 끌어낸다"),
            explain("지난 공은 실투가 아니었다고 답한다", "그때의 선택을 숨기지 않는다"),
            challenge("고개를 끄덕이고 승부를 받아들인다", "다음 공으로 답한다"),
        ]),
        "evt-rival-message": Scene(speaker: .rival, quotes: [
            .low: "\u{201C}어차피 또 같은 초구겠지. …너 그거밖에 없잖아.\u{201D}",
            .mid: "\u{201C}다음에도 같은 초구를 던질 거야?\u{201D}",
            .high: "\u{201C}다음 초구, 뭐 던질지 맞혀 볼까. …아니다, 그건 직접 보는 게 낫지.\u{201D}",
        ], choices: [
            listen("어떤 습관을 읽었는지 묻는다", "상대의 답을 들어 본다"),
            explain("그 초구로 노린 것을 말한다", "내 판단을 숨기지 않는다"),
            challenge("다음 타석에는 다른 답을 주겠다고 한다", "재대결을 약속한다"),
        ]),

        // 팔 상태(합성 이벤트)
        "evt-arm-care": Scene(
            speaker: .named("트레이너"),
            quotes: flat("\u{201C}최근 등판 뒤로 공을 놓는 팔이 무거워 보여. 오늘은 어떻게 할까?\u{201D}"),
            choices: [
                challenge("참고 던진다", "능력은 지키지만 부상 위험이 오른다"),
                listen("짧은 휴식", "이번엔 팔을 쉬어 피로와 위험을 크게 던다"),
                explain("정밀 검진", "상태를 정확히 확인하고 위험을 없앤다"),
            ]
        ),

        // 확장 카테고리 손대사 장면
        "evt-fan-letter": Scene(
            speaker: .named("팬"),
            quotes: flat("\u{201C}선수님이 던지는 그 느린 공이 제일 좋아요. 다음 경기에도 꼭 던져 주세요!\u{201D} 삐뚤빼뚤한 글씨 밑에 그림도 그려져 있다."),
            choices: [
                listen("어떤 공을 좋아하는지 다시 읽는다", "팬이 아끼는 공을 확인한다"),
                explain("그 공을 던지는 이유를 답장에 적는다", "왜 그 공인지 편지에 담는다"),
                challenge("다음 경기에서 꼭 보여주겠다고 약속한다", "기대에 공으로 답한다"),
            ]
        ),
        "evt-parent-call": Scene(
            speaker: .named("부모님"),
            quotes: flat("\u{201C}드래프트 끝나고도 계속할 거지? …아니, 대답은 천천히 해도 돼. 밥은 챙겨 먹고 다니니.\u{201D}"),
            choices: [
                listen("먼저 부모님 이야기를 듣는다", "집의 걱정을 끝까지 듣는다"),
                explain("지금의 계획을 담담히 말한다", "야구를 계속할 생각을 전한다"),
                challenge("결과로 안심시키겠다고 말한다", "다음 경기로 보여주겠다고 답한다"),
            ]
        ),
        "evt-exam-week": Scene(
            speaker: .named("담임 선생님"),
            quotes: flat("\u{201C}시험이랑 원정이 겹쳤지. 공만큼 책도 며칠은 잡아야 한다. …야구는 안 도망가.\u{201D}"),
            choices: [
                listen("선생님 말을 먼저 새겨듣는다", "며칠은 책상 앞에 앉는다"),
                explain("시간을 어떻게 쪼갤지 말한다", "둘 다 놓지 않을 계획을 설명한다"),
                challenge("남는 시간을 훈련으로 메우겠다고 한다", "줄어든 시간을 아껴 쓴다"),
            ]
        ),
        "evt-loss-interview": Scene(
            speaker: .named("기자"),
            quotes: flat("\u{201C}마지막 타자에게 그 공을 고른 이유가 있었나요?\u{201D} 녹음기가 아직 돌아가고 있다."),
            choices: [
                listen("질문의 뜻을 되묻는다", "무엇을 궁금해하는지 먼저 듣는다"),
                explain("그 공을 고른 이유를 말한다", "그 순간의 판단을 설명한다"),
                challenge("다음 경기로 답하겠다고 한다", "말 대신 결과로 보여준다"),
            ]
        ),
        "evt-national-stage": Scene(
            speaker: .named("중계 PD"),
            quotes: flat("\u{201C}오늘 불펜부터 그림 좀 담을게. 평소대로 던져. …평소대로가 제일 어렵지?\u{201D}"),
            choices: [
                listen("카메라 동선을 확인한다", "어디를 비추는지 듣는다"),
                explain("준비는 평소 그대로 하겠다고 한다", "달라질 것 없다고 말한다"),
                challenge("카메라를 잊고 공에만 집중한다", "중계는 신경 쓰지 않기로 한다"),
            ]
        ),
        "evt-captain-talk": Scene(
            speaker: .named("주장"),
            quotes: flat("\u{201C}다음 경기, 긴 이닝 맡아 줄 수 있어? 무리면 무리라고 말해. 그게 팀엔 더 나아.\u{201D}"),
            choices: [
                listen("팀이 필요한 이닝부터 듣는다", "주장이 그린 그림을 확인한다"),
                explain("지금 던질 수 있는 이닝을 말한다", "몸 상태를 솔직히 전한다"),
                challenge("끝까지 책임지겠다고 나선다", "긴 이닝을 자청한다"),
            ]
        ),
        "evt-school-record": Scene(
            speaker: .named("후배"),
            quotes: flat("\u{201C}선배, 다음 경기에서 여섯 개만 더 잡으면 학교 기록이래요. …저 그거 옆에서 보고 싶어요.\u{201D}"),
            choices: [
                listen("후배가 아는 기록을 들어 본다", "무슨 기록인지 확인한다"),
                explain("기록은 신경 쓰지 않는다고 말한다", "한 타자씩 가겠다고 답한다"),
                challenge("그 기록 보여주겠다고 웃는다", "다음 경기에서 노려 보겠다고 한다"),
            ]
        ),
        "evt-scout-question": Scene(
            speaker: .named("스카우트"),
            quotes: flat("\u{201C}지난달 무너진 경기 다음에, 뭘 바꿨지? …바꾼 게 있다면 그게 제일 궁금해.\u{201D}"),
            choices: [
                listen("무엇을 눈여겨보는지 먼저 듣는다", "스카우트가 보는 지점을 확인한다"),
                explain("그 경기 뒤 바꾼 것을 말한다", "달라진 준비를 설명한다"),
                challenge("가장 좋은 공으로 답하겠다고 한다", "다음 등판으로 증명한다"),
            ]
        ),
        "evt-velocity-drop": Scene(
            speaker: .named("트레이너"),
            quotes: flat("\u{201C}두 경기째 구속이 2km/h 빠졌어. 숫자는 거짓말을 안 해. 몸이 뭔가 말하는 중이야.\u{201D}"),
            choices: [
                listen("무엇을 점검해야 하는지 듣는다", "트레이너의 판단을 먼저 듣는다"),
                explain("요즘 몸 상태를 그대로 말한다", "느껴지는 피로를 설명한다"),
                challenge("며칠 조정하고 다시 끌어올리겠다고 한다", "구속은 곧 돌아온다고 답한다"),
            ]
        ),
        "evt-bullpen-rival": Scene(
            speaker: .named("경쟁하는 동료"),
            quotes: flat("\u{201C}네 새 변화구 그립… 한 번만 보여줄래? 선발 자리는 서로 뺏는 사이지만, 그래도 배우고 싶어서.\u{201D}"),
            choices: [
                listen("왜 그 그립이 궁금한지 듣는다", "동료의 생각을 먼저 듣는다"),
                explain("그립 잡는 법을 설명해 준다", "숨기지 않고 알려 준다"),
                challenge("자리는 마운드에서 겨루자고 한다", "선발은 경기로 정하자고 답한다"),
            ]
        ),
    ]

    /// 카테고리 기본 장면. 인용 대사는 비워 두고 화면이 이벤트 요약을 쓴다.
    public static let categoryScenes: [String: Scene] = [
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
    public static func aftermath(speaker: Speaker, response: RelationshipResponse, trustChange: Int) -> String {
        let who: String
        switch speaker {
        case .coach: who = "감독"
        case .catcher: who = "포수"
        case .rival: who = "상대"
        case .named(let name): who = name
        }
        if trustChange <= -5 {
            switch response {
            case .listen: return "\(who)은(는) 더 말하지 않았다. 듣기만 한 것이 이번에는 답이 아니었다."
            case .explain: return "설명은 끝까지 했지만 \(who)의 표정은 달라지지 않았다."
            case .challenge: return "\(who)이(가) 짧게 고개를 저었다. 지금은 그 말을 받을 자리가 아니었다."
            }
        }
        if trustChange < 0 {
            return "\(who)은(는) 알겠다고만 했다. 남는 것이 없는 대화였다."
        }
        if trustChange >= 7 {
            switch response {
            case .listen: return "\(who)이(가) 하려던 말을 다 했다. 끝까지 들은 것이 오늘의 답이었다."
            case .explain: return "\(who)이(가) 고개를 끄덕였다. 근거가 있는 말은 대체로 통한다."
            case .challenge: return "\(who)이(가) 웃었다. \u{201C}그럼 보여 줘.\u{201D} 다음 공에 걸린 것이 하나 늘었다."
            }
        }
        return "\(who)과(와)의 대화는 조용히 마무리됐다. 서로 한 걸음씩은 알게 됐다."
    }
}
