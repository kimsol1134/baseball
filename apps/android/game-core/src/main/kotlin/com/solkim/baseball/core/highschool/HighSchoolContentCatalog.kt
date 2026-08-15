package com.solkim.baseball.core.highschool

/**
 * Ported high-school content identifiers and immutable catalog values.
 *
 * The values in this file are copied from the current C#/Swift core catalog.  This first
 * vertical deliberately keeps content as data: Compose can project it later and the kernel
 * never needs to own a screen or a Unity object.
 */
public enum class HighSchoolPhase(public val wire: String) {
    PROLOGUE("prologue"),
    SCHOOL_SELECTION("school_selection"),
    TRAINING("training"),
    RELATIONSHIP("relationship"),
    IMPORTANT_GAME("important_game"),
    AWAKENING("awakening"),
    CHAPTER_REVIEW("chapter_review"),
    DRAFT("draft"),
    LEGACY("legacy"),
    COMPLETED("completed"),
}

public enum class HighSchoolSchoolId(public val wire: String) {
    HANBIT_TRADITIONAL("hanbit_traditional"),
    MIRAE_ANALYTICS("mirae_analytics"),
    HAEDONG_POWER("haedong_power"),
    CHEONGAM_DEVELOPMENT("cheongam_development"),
}

public enum class HighSchoolTrainingFocus(public val wire: String) {
    VELOCITY("velocity"),
    COMMAND("command"),
    BREAKING_BALL("breaking_ball"),
    STAMINA("stamina"),
    RECOVERY("recovery"),
    GAME_PLANNING("game_planning"),
}

public enum class HighSchoolTrainingIntensity(public val wire: String) {
    LIGHT("light"),
    STANDARD("standard"),
    INTENSIVE("intensive"),
}

public enum class HighSchoolRelationshipTarget(public val wire: String) {
    COACH("coach"),
    CATCHER("catcher"),
    RIVAL("rival"),
}

public enum class HighSchoolRelationshipResponse(public val wire: String) {
    LISTEN("listen"),
    EXPLAIN("explain"),
    CHALLENGE("challenge"),
}

public enum class HighSchoolDraftOutcome(public val wire: String) {
    DRAFTED("drafted"),
    UNDRAFTED("undrafted"),
}

public enum class HighSchoolSoulDomain(public val wire: String) {
    BODY("body"),
    TECHNIQUE("technique"),
    GAME("game"),
}

public enum class HighSchoolKarma(public val wire: String, public val rewardPermille: Int) {
    UNKNOWN_LAND("unknown_land", 150),
    STUBBORN_COACH("stubborn_coach", 150),
    SINGLE_WEAPON("single_weapon", 200),
    GENIUS_GENERATION("genius_generation", 250),
    ERASED_MEMORY("erased_memory", 250),
    NO_LAST_CHANCE("no_last_chance", 350),
}

public enum class HighSchoolSoulBoost(public val wire: String, public val cost: Int) {
    TALENT_BREAK("talent_break", 240),
    EXTRA_MEMORY("extra_memory", 160),
    HEAD_START("head_start", 120),
    TRAINING_RHYTHM("training_rhythm", 90),
}

public enum class HighSchoolAwakening(public val wire: String) {
    EXPLOSIVE_FASTBALL("explosive_fastball"),
    RISING_FOUR_SEAM("rising_four_seam"),
    IRON_ARM("iron_arm"),
    LATE_INNING_RESERVE("late_inning_reserve"),
    PINPOINT_EDGE("pinpoint_edge"),
    REPEATABLE_RELEASE("repeatable_release"),
    FIRST_PITCH_STRIKE("first_pitch_strike"),
    CALM_UNDER_PRESSURE("calm_under_pressure"),
    SCOUT_COMPOSURE("scout_composure"),
    DISAPPEARING_BREAKER("disappearing_breaker"),
    SWEEPING_SLIDER("sweeping_slider"),
    CURVEBALL_CLOCK("curveball_clock"),
    FROZEN_CHANGEUP("frozen_changeup"),
    SINKER_TUNNEL("sinker_tunnel"),
    BATTERY_SYNC("battery_sync"),
    TWO_STRIKE_PLAN("two_strike_plan"),
    PICKOFF_RHYTHM("pickoff_rhythm"),
    TRAFFIC_CONTROLLER("traffic_controller"),
}

public enum class HighSchoolTalentGrade(public val ceiling: Int, public val bloomThreshold: Int) {
    D(52, 2),
    C(58, 3),
    B(65, 4),
    A(72, 6),
    S(80, Int.MAX_VALUE),
}

public data class HighSchoolTalent(
    val stuff: HighSchoolTalentGrade,
    val command: HighSchoolTalentGrade,
    val movement: HighSchoolTalentGrade,
    val stamina: HighSchoolTalentGrade,
    val stuffPressure: Int = 0,
    val commandPressure: Int = 0,
    val movementPressure: Int = 0,
    val staminaPressure: Int = 0,
) {
    public fun grade(focus: HighSchoolTrainingFocus): HighSchoolTalentGrade = when (focus) {
        HighSchoolTrainingFocus.VELOCITY -> stuff
        HighSchoolTrainingFocus.COMMAND, HighSchoolTrainingFocus.GAME_PLANNING -> command
        HighSchoolTrainingFocus.BREAKING_BALL -> movement
        HighSchoolTrainingFocus.STAMINA, HighSchoolTrainingFocus.RECOVERY -> stamina
    }

    public fun pressure(focus: HighSchoolTrainingFocus): Int = when (focus) {
        HighSchoolTrainingFocus.VELOCITY -> stuffPressure
        HighSchoolTrainingFocus.COMMAND, HighSchoolTrainingFocus.GAME_PLANNING -> commandPressure
        HighSchoolTrainingFocus.BREAKING_BALL -> movementPressure
        HighSchoolTrainingFocus.STAMINA, HighSchoolTrainingFocus.RECOVERY -> staminaPressure
    }

    public fun withGrade(focus: HighSchoolTrainingFocus, value: HighSchoolTalentGrade): HighSchoolTalent = when (focus) {
        HighSchoolTrainingFocus.VELOCITY -> copy(stuff = value)
        HighSchoolTrainingFocus.COMMAND, HighSchoolTrainingFocus.GAME_PLANNING -> copy(command = value)
        HighSchoolTrainingFocus.BREAKING_BALL -> copy(movement = value)
        HighSchoolTrainingFocus.STAMINA, HighSchoolTrainingFocus.RECOVERY -> copy(stamina = value)
    }

    public fun withPressure(focus: HighSchoolTrainingFocus, value: Int): HighSchoolTalent = when (focus) {
        HighSchoolTrainingFocus.VELOCITY -> copy(stuffPressure = value)
        HighSchoolTrainingFocus.COMMAND, HighSchoolTrainingFocus.GAME_PLANNING -> copy(commandPressure = value)
        HighSchoolTrainingFocus.BREAKING_BALL -> copy(movementPressure = value)
        HighSchoolTrainingFocus.STAMINA, HighSchoolTrainingFocus.RECOVERY -> copy(staminaPressure = value)
    }

    public companion object {
        public val UNLIMITED: HighSchoolTalent = HighSchoolTalent(
            HighSchoolTalentGrade.S,
            HighSchoolTalentGrade.S,
            HighSchoolTalentGrade.S,
            HighSchoolTalentGrade.S,
        )
    }
}

public data class HighSchoolChapter(
    val number: Int,
    val title: String,
    val schoolYear: Int,
    val season: String,
    val theme: String,
)

public data class HighSchoolSchool(
    val id: HighSchoolSchoolId,
    val name: String,
    val philosophy: String,
    val coachName: String,
    val coachArchetype: String,
    val catcherName: String,
    val catcherArchetype: String,
    val strength: HighSchoolTrainingFocus,
    val tradeoff: String,
    /** Additive source fields used by the current Swift/C# read models. */
    val coachPersonality: String? = null,
    val coachRecord: String? = null,
    val catcherPersonality: String? = null,
    val catcherRecord: String? = null,
)

public data class HighSchoolRival(
    val id: String,
    val name: String,
    val archetype: String,
    val contact: Int,
    val discipline: Int,
    val power: Int,
    val personality: String? = null,
    val signatureRecord: String? = null,
)

/** Immutable relationship-card content copied from the current Swift authority. */
public data class HighSchoolRelationshipEvent(
    val id: String,
    val title: String,
    val category: String,
    val summary: String,
)

/** Immutable important-game setup copied from ImportantGameScenarioContent. */
public data class HighSchoolGameScenario(
    val id: String,
    val title: String,
    val inning: Int,
    val outs: Int,
    val firstOccupied: Boolean,
    val secondOccupied: Boolean,
    val thirdOccupied: Boolean,
    val leadRunnerSpeed: Int,
    val leverage: Int,
    val narrative: String,
    val scoreDifferential: Int? = null,
    val minChapter: Int = 1,
)

public data class HighSchoolPreset(
    val id: String,
    val baseStuff: Int,
    val baseCommand: Int,
    val baseMovement: Int,
    val baseStamina: Int,
)

public data class HighSchoolSchedule(
    val trainingsByChapter: List<Int>,
    val milestonesByChapter: List<List<HighSchoolPhase>>,
) {
    public val trainingTotal: Int get() = trainingsByChapter.sum()
}

public object HighSchoolContentCatalog {
    public const val BALANCE_VERSION: Int = 4
    public const val WORLD_RULES_VERSION: Int = 2
    public const val RECOVERY_OPPORTUNITY_FATIGUE: Int = 45
    public const val ARM_CAUTION_THRESHOLD: Int = 35
    public const val ARM_WARNING_THRESHOLD: Int = 55
    public const val ARM_INJURY_THRESHOLD: Int = 72
    public const val ARM_FATIGUE_FLOOR: Int = 55
    public const val ARM_PITCH_FLOOR: Int = 23
    public const val ARM_PUSH_THROUGH_RISK: Int = 15
    public const val ARM_REST_RELIEF: Int = 45
    public const val ARM_EXAM_RELIEF: Int = 8

    public val presets: List<HighSchoolPreset> = listOf(
        HighSchoolPreset("power_prospect", 42, 34, 36, 38),
        HighSchoolPreset("precision_commander", 34, 43, 35, 38),
        HighSchoolPreset("breaking_ball_artist", 37, 34, 44, 35),
        HighSchoolPreset("innings_eater", 37, 32, 37, 44),
    )

    public val chapters: List<HighSchoolChapter> = listOf(
        HighSchoolChapter(1, "낯선 마운드", 1, "봄", "첫 고교 훈련과 첫 공식 등판이 기다린다"),
        HighSchoolChapter(2, "첫 번째 증명", 1, "여름", "여름 대회 출전 명단과 맡을 역할이 정해진다"),
        HighSchoolChapter(3, "첫 겨울", 1, "겨울", "봄이 오기 전까지 가장 부족한 한 가지를 다듬는다"),
        HighSchoolChapter(4, "전국의 시선", 2, "봄", "전국대회에서 라이벌과 다시 만난다"),
        HighSchoolChapter(5, "흔들리는 배터리", 2, "여름", "포수와 자꾸 엇갈리는 사인을 바로잡아야 한다"),
        HighSchoolChapter(6, "에이스의 책임", 2, "가을", "피로가 쌓인 채 가을 대회 마운드에 오른다"),
        HighSchoolChapter(7, "마지막 겨울", 2, "겨울", "스카우트가 지켜볼 마지막 시즌을 준비한다"),
        HighSchoolChapter(8, "드래프트 데이", 3, "여름", "마지막 전국대회를 치르고 드래프트 결과를 기다린다"),
    )

    private val regionalNames: Map<String, List<String>> = mapOf(
        "서울" to listOf("서울덕성고", "서울배성고", "서울충림고", "서울경원고"),
        "인천" to listOf("인천해문결고", "인천동림고", "인천항성고", "인천송해고"),
        "수원" to listOf("수원화성빛고", "수원장림고", "수원화담결고", "수원매화솔고"),
        "대전" to listOf("대전갑천별고", "대전들샘결고", "대전유진고", "대전중원고"),
        "광주" to listOf("광주무등결고", "광주예향결고", "광주서빛람고", "광주무원고"),
        "대구" to listOf("대구팔공결고", "대구능금결고", "대구달원고", "대구청림고"),
        "부산" to listOf("부산해남고", "부산항성고", "부산항해솔고", "부산오륙결고"),
        "창원" to listOf("마산해강고", "창원가람솔고", "창원누리결고", "진해동림고"),
        "울산" to listOf("울산대명고", "울산문성고", "울산태원고", "울산장생고"),
        "세종" to listOf("세종한별고", "세종새빛고", "세종금빛고", "세종연서고"),
        "경기" to listOf("성남유림고", "고양서람빛고", "시흥소명고", "용인청림고"),
        "강원" to listOf("강릉해람고", "원주원흥고", "춘천호반고", "속초설해고"),
        "충북" to listOf("청주직지솔고", "청주세명고", "충주성문고", "진천덕원고"),
        "충남" to listOf("공주금강고", "천안능수결고", "아산곡교결고", "서산해명고"),
        "전북" to listOf("전주한옥솔고", "군산새만결고", "정읍인원고", "익산보석고"),
        "전남" to listOf("화순화원고", "순천정원솔고", "목포항남고", "여수진원고"),
        "경북" to listOf("포항해오름고", "경주월림고", "구미도원고", "안동하회고"),
        "경남" to listOf("마산달빛결고", "김해수로결고", "양산물빛고", "거제푸른섬고"),
        "제주" to listOf("제주한라원고", "서귀포해원고", "제주탐라빛고", "제주오름고"),
    )

    /** The setup screen renders the same 19-region catalog used by the Swift authority. */
    public val regions: List<String> get() = regionalNames.keys.toList()

    private val coachNames = listOf(
        listOf("윤태문", "강일도", "백승관", "임동혁", "조범석"),
        listOf("노재형", "한기표", "유상민", "신정록", "곽태윤"),
        listOf("오승렬", "마동준", "채희성", "도진광", "하병철"),
        listOf("배도환", "어재원", "편상욱", "소진철", "반석호"),
    )

    private val catcherNames = listOf(
        listOf("서준호", "김도현", "박성재", "이재영", "정우빈"),
        listOf("한도윤", "송지헌", "오세민", "권혁준", "남기율"),
        listOf("차민석", "변진서", "육정환", "구자헌", "표재신"),
        listOf("문하진", "안시후", "방준서", "석민규", "탁이현"),
    )

    public val rivals: List<HighSchoolRival> = listOf(
        HighSchoolRival("rival-seo", "서하준", "천재 교타형", 47, 44, 39, "배트가 공을 끝까지 따라갑니다. 같은 코스를 두 번 놓치지 않는 왼손 타자입니다.", "봄 대회 타율 .421 · 31안타"),
        HighSchoolRival("rival-lee", "권태오", "초구 거포형", 42, 37, 49, "느린 발을 감출 만큼 타구 판단이 빠릅니다. 초구 실투를 그냥 보내지 않습니다.", "전국대회 7홈런 · 22타점"),
        HighSchoolRival("rival-park", "남도현", "안타 제조형", 46, 45, 37, "파울로 버티며 투구 수를 늘리고 마지막에는 짧은 스윙으로 안타를 만듭니다.", "11경기 연속 안타 · 출루율 .492"),
        HighSchoolRival("rival-kang", "배시우", "외다리 장타형", 39, 40, 50, "높게 떠오른 공을 우측 담장으로 보내는 왼손 거포입니다. 실투 하나가 곧 실점입니다.", "장타율 .711 · 8홈런"),
        HighSchoolRival("rival-yoon", "류건우", "장신 호타준족형", 44, 40, 43, "큰 스윙 궤도와 빠른 발을 함께 씁니다. 변화구가 뜨면 주저 없이 당겨칩니다.", "18경기 14도루 · 5홈런"),
        HighSchoolRival("rival-choi", "정세현", "득점권 해결사형", 44, 43, 48, "늦은 카운트와 득점권에서 오히려 스윙이 짧아지는 해결사입니다.", "득점권 타율 .438 · 끝내기 3회"),
        HighSchoolRival("rival-home-run", "강이안", "몸쪽 사냥형", 41, 44, 50, "몸쪽 공도 피하지 않고 잡아당깁니다. 불리한 카운트에서도 장타를 버리지 않습니다.", "봄·여름 대회 14홈런 · 장타율 .804"),
        HighSchoolRival("rival-speed", "문재윤", "질주형 중심타자", 47, 40, 46, "타구가 뜨는 순간 2루를 노립니다. 실투 하나로 경기 흐름을 바꾸는 호타준족입니다.", "20도루 · 6홈런 · 21득점"),
    )

    /** Current Swift CareerEventContent catalog. Keep IDs and ordering stable for replay. */
    public val events: List<HighSchoolRelationshipEvent> = listOf(
        HighSchoolRelationshipEvent("evt-bullpen-first", "첫 불펜", "growth", "고교 포수가 공을 받아 본 뒤 각 구종을 언제 쓰고 싶은지 묻습니다."),
        HighSchoolRelationshipEvent("evt-coach-role", "선발인가 불펜인가", "coach", "감독이 다음 대회는 불펜에서 시작하겠다고 말합니다."),
        HighSchoolRelationshipEvent("evt-catcher-sign", "엇갈린 사인", "catcher", "경기 중 세 번 사인이 엇갈렸고 포수가 이유를 묻습니다."),
        HighSchoolRelationshipEvent("evt-rival-video", "라이벌의 영상", "rival", "라이벌이 당신의 포심 타이밍을 정확히 맞히는 영상이 도착했습니다."),
        HighSchoolRelationshipEvent("evt-winter-weight", "겨울의 몸", "growth", "웨이트 코치가 근력을 늘릴지 몸의 유연성을 지킬지 선택하라고 합니다."),
        HighSchoolRelationshipEvent("evt-command-wall", "제구의 벽", "growth", "불펜에서는 들어가던 공이 경기만 시작하면 한 뼘씩 벗어납니다."),
        HighSchoolRelationshipEvent("evt-breaker-grip", "새 그립", "growth", "더 크게 휘지만 제구가 어려운 새 변화구 그립을 시험합니다."),
        HighSchoolRelationshipEvent("evt-recovery-day", "쉬는 날의 불안", "health", "회복 코치가 오늘은 공을 잡지 말라고 하지만 옆 불펜에서는 경쟁자가 던지고 있습니다."),
        HighSchoolRelationshipEvent("evt-captain-talk", "주장의 질문", "team", "주장이 다음 경기에서 긴 이닝을 맡아 줄 수 있느냐고 묻습니다."),
        HighSchoolRelationshipEvent("evt-scout-stand", "백스톱 뒤의 스카우트", "draft", "불펜 뒤에 선 스카우트 둘이 매 공의 구속을 적기 시작합니다."),
        HighSchoolRelationshipEvent("evt-loss-interview", "패배 뒤 인터뷰", "media", "기자가 마지막 타자에게 던진 공을 왜 골랐는지 묻습니다."),
        HighSchoolRelationshipEvent("evt-fan-letter", "첫 팬레터", "fan", "어린 팬이 가장 좋아하는 구종을 다음 경기에서도 던져 달라고 썼습니다."),
        HighSchoolRelationshipEvent("evt-battery-dinner", "배터리의 저녁", "catcher", "포수가 밥을 먹다 말고 가장 받기 두려운 공이 무엇인지 털어놓습니다."),
        HighSchoolRelationshipEvent("evt-coach-bench", "감독의 벤치", "coach", "감독이 다음 등판을 쉬게 한 이유를 설명합니다."),
        HighSchoolRelationshipEvent("evt-rival-message", "라이벌의 메시지", "rival", "라이벌이 ‘다음에도 같은 초구를 던질 거냐’고 메시지를 보냈습니다."),
        HighSchoolRelationshipEvent("evt-mechanics-camera", "카메라에 찍힌 투구 동작", "growth", "고속 카메라에 평소보다 손에서 공이 일찍 빠지는 장면이 찍혔습니다."),
        HighSchoolRelationshipEvent("evt-velocity-drop", "2km/h의 하락", "health", "두 경기 연속 최고 구속이 2km/h 낮게 찍혔습니다."),
        HighSchoolRelationshipEvent("evt-new-catcher", "새 포수", "catcher", "새 포수가 기존 사인 대신 자신이 쓰던 손짓을 제안합니다."),
        HighSchoolRelationshipEvent("evt-school-record", "학교 기록", "fan", "다음 경기에서 탈삼진 6개를 더 잡으면 학교 기록이 바뀝니다."),
        HighSchoolRelationshipEvent("evt-rain-delay", "비가 멈춘 뒤", "game", "두 시간 동안 멈췄던 경기가 갑자기 15분 뒤 재개됩니다."),
        HighSchoolRelationshipEvent("evt-loaded-bases", "만루의 기억", "game", "지난 경기 만루에서 던진 초구가 영상실 화면에 다시 나옵니다."),
        HighSchoolRelationshipEvent("evt-first-awakening", "몸이 먼저 아는 것", "awakening", "최근 훈련에서 반복한 동작이 경기에서도 자연스럽게 나옵니다."),
        HighSchoolRelationshipEvent("evt-team-slump", "팀의 연패", "team", "세 경기 연속 패배 뒤 선수들이 자율 훈련 시간을 두고 다툽니다."),
        HighSchoolRelationshipEvent("evt-bullpen-rival", "같은 팀의 경쟁자", "team", "선발 자리를 다투는 동료가 새 변화구 그립을 보여 달라고 합니다."),
        HighSchoolRelationshipEvent("evt-scout-question", "스카우트의 한 질문", "draft", "스카우트가 최근 무너진 경기 뒤 무엇을 바꿨는지 묻습니다."),
        HighSchoolRelationshipEvent("evt-parent-call", "집에서 온 전화", "life", "부모님이 드래프트 뒤에도 야구를 계속할 생각인지 묻습니다."),
        HighSchoolRelationshipEvent("evt-exam-week", "시험 주간", "life", "시험과 원정 경기가 겹쳐 이번 주 훈련 시간이 절반으로 줄었습니다."),
        HighSchoolRelationshipEvent("evt-injury-rumor", "통증 소문", "health", "어깨를 주무르는 모습을 본 동료가 코치에게 말해야 하지 않느냐고 묻습니다."),
        HighSchoolRelationshipEvent("evt-national-stage", "전국 중계", "media", "경기 전 불펜부터 중계 카메라가 계속 따라붙습니다."),
        HighSchoolRelationshipEvent("evt-catcher-doubt", "포수의 의심", "catcher", "포수가 최근 자신의 사인을 자주 거절하는 이유를 묻습니다."),
        HighSchoolRelationshipEvent("evt-coach-last-advice", "감독의 마지막 조언", "coach", "감독이 드래프트 전 마지막 훈련 하나를 직접 고르라고 합니다."),
        HighSchoolRelationshipEvent("evt-rival-final", "마지막 재대결", "rival", "라이벌이 타석에 들어서며 지난 경기와 같은 코스를 가리킵니다."),
        HighSchoolRelationshipEvent("evt-draft-projection", "예상 순위", "draft", "언론 예상 순위와 학교가 들은 구단 평가가 두 라운드나 차이 납니다."),
        HighSchoolRelationshipEvent("evt-undrafted-room", "이름이 불리지 않은 방", "legacy", "마지막 라운드가 끝난 뒤 세 해의 기록을 다시 펼칩니다."),
        HighSchoolRelationshipEvent("evt-drafted-call", "구단의 전화", "draft", "지명 구단 담당자가 전화를 걸어 입단 뒤 첫 시즌 훈련 계획을 설명합니다."),
        HighSchoolRelationshipEvent("evt-scorebook-close", "마지막 스코어북", "legacy", "세 해 동안 가장 좋았던 경기와 가장 힘들었던 경기에 표시를 남깁니다."),
    )

    /** Rebirth-only events from the current Swift catalog. */
    public val rebirthEvents: List<HighSchoolRelationshipEvent> = listOf(
        HighSchoolRelationshipEvent("evt-deja-vu-mound", "처음 밟는데 익숙한 마운드", "rebirth", "처음 오르는 마운드인데 흙의 단단함과 발끝의 각도가 이미 알던 것 같습니다."),
        HighSchoolRelationshipEvent("evt-known-coach", "낯익은 감독", "rebirth", "감독의 말버릇과 손짓이 어디선가 본 것 같습니다. 만난 적은 없습니다."),
        HighSchoolRelationshipEvent("evt-body-remembers", "몸이 먼저 아는 그립", "rebirth", "배운 적 없는 그립이 손에 저절로 잡힙니다. 던져 보니 실제로 휩니다."),
        HighSchoolRelationshipEvent("evt-rival-deja-vu", "라이벌의 기시감", "rebirth", "라이벌이 타석에서 당신을 오래 봅니다. “우리 어디서 붙은 적 있나?”"),
        HighSchoolRelationshipEvent("evt-memory-ache", "기억의 통증", "rebirth", "지난번에 팔을 다쳤던 그 주차입니다. 아프지 않은데 그 자리가 신경 쓰입니다."),
        HighSchoolRelationshipEvent("evt-second-summer", "다시 맞는 3학년 여름", "rebirth", "같은 계절, 같은 대회. 이번에는 결과를 알고 시작합니다."),
        HighSchoolRelationshipEvent("evt-remembered-pitch", "실점의 기시감", "rebirth", "지난 삶에서 실점한 순간과 닮은 긴장이 돌아온 가운데 포수가 승부구 사인을 냅니다."),
        HighSchoolRelationshipEvent("evt-lost-teammate", "그만둔 동료", "rebirth", "지난 삶에서 끝까지 함께 던졌던 동료가, 이번 삶에서는 야구를 그만뒀다는 소식을 듣습니다."),
        HighSchoolRelationshipEvent("evt-future-news", "결말을 아는 뉴스", "rebirth", "라디오가 올해의 우승 후보를 읊습니다. 지난 삶과 한 글자도 다르지 않아, 결말을 아는 책 같습니다."),
        HighSchoolRelationshipEvent("evt-old-nickname", "지난 삶의 별명", "rebirth", "처음 만난 상대 포수가 당신을 지난 삶의 별명으로 부릅니다. 이번 삶에는 아직 없는 이름입니다."),
        HighSchoolRelationshipEvent("evt-glove-worn", "길들여진 새 글러브", "rebirth", "새 글러브인데 지난 삶에서 길들인 자리부터 부드럽습니다. 손이 먼저 접던 각도로 접힙니다."),
        HighSchoolRelationshipEvent("evt-undrafted-deja", "그 방의 기시감", "rebirth", "드래프트 중계를 트는 순간, 이름이 불리지 않은 채 끝났던 그 방의 공기가 먼저 돌아옵니다."),
    )

    public val relationshipEvents: List<HighSchoolRelationshipEvent> = events + rebirthEvents + listOf(
        HighSchoolRelationshipEvent("evt-arm-care", "팔 상태 경고", "health", "최근 등판 뒤 팔이 평소보다 무겁습니다. 트레이너가 오늘 어떻게 할지 묻습니다."),
    )

    private fun scenario(
        id: String, title: String, inning: Int, outs: Int,
        first: Boolean, second: Boolean, third: Boolean, speed: Int,
        leverage: Int, narrative: String, score: Int? = null, minChapter: Int = 1,
    ): HighSchoolGameScenario = HighSchoolGameScenario(id, title, inning, outs, first, second, third, speed, leverage, narrative, score, minChapter)

    /** Current Swift ImportantGameScenarioContent catalog, including all thirty scenarios. */
    public val scenarios: List<HighSchoolGameScenario> = listOf(
        scenario("game-debut", "고교 데뷔", 3, 0, false, false, false, 55, 350, "첫 공식 등판. 한 점 뒤진 채 받은 기회지만, 상대 타자도 아직 내 공을 본 적이 없습니다.", -1),
        scenario("game-runner-first", "1사 1루", 5, 1, true, false, false, 64, 610, "빠른 주자가 1루에서 리드를 길게 잡고 있습니다.", 1),
        scenario("game-rival-rematch", "라이벌 재대결", 6, 1, false, true, false, 61, 760, "동점 6회, 지난 경기의 구종 순서를 기억하는 중심타자가 들어섭니다.", 0),
        scenario("game-corners", "1사 1·3루", 7, 1, true, false, true, 67, 900, "땅볼 하나면 병살이지만 외야로 뜨면 동점입니다.", 1),
        scenario("game-loaded", "무사 만루", 4, 0, true, true, true, 60, 950, "볼넷을 피하면서 약한 타구가 필요한 상황", 2),
        scenario("game-two-outs", "2사 2루", 8, 2, false, true, false, 65, 880, "한 타자에 이닝이 걸린 승부", 1),
        scenario("game-fatigue", "피로한 7회", 7, 0, true, false, false, 59, 720, "직구가 느려진 7회, 어떤 공으로 버틸지 정해야 합니다.", 1),
        scenario("game-scout", "스카우트 관전", 5, 1, false, false, false, 55, 690, "팀은 한 점 뒤져 있지만, 스카우트는 점수가 아니라 같은 코스를 반복하는지 지켜봅니다.", -1),
        scenario("game-rain", "우천 중단 뒤", 6, 0, false, false, false, 55, 540, "두 시간 동안 경기가 멈춰 몸이 식은 뒤 만나는 첫 타자입니다.", 0),
        scenario("game-one-run", "한 점 차", 9, 0, false, true, false, 68, 980, "드래프트 전 마지막 고교 이닝", 1, 7),
        scenario("game-new-catcher", "새 포수와 첫 경기", 4, 1, true, false, false, 62, 570, "새 포수와 아직 구종 사인을 충분히 맞추지 못했습니다.", 1),
        scenario("game-national-final", "전국 결승", 8, 2, true, true, false, 66, 1_000, "2사 1·2루. 마지막 아웃 하나에 우승이 걸렸습니다.", 1, 4),
        scenario("game-walkoff-defense", "9회말 리드 방어", 9, 1, false, true, true, 63, 985, "한 점 앞선 9회말 1사 2·3루. 외야로 뜨기만 해도 동점, 안타면 경기가 끝납니다.", 1),
        scenario("game-extra-tiebreak", "연장 승부치기", 10, 0, true, true, false, 67, 940, "연장 승부치기. 무사 1·2루에서 시작합니다. 아웃부터 잡지 못하면 큰 이닝이 됩니다.", 0),
        scenario("game-ace-duel", "0-0 투수전", 8, 0, false, false, false, 55, 810, "8회까지 0의 행진. 상대 에이스도 지지 않습니다. 먼저 실수하는 쪽이 집니다.", 0),
        scenario("game-damage-control", "실점 뒤 수습", 6, 1, true, true, true, 58, 875, "이 이닝에만 석 점을 내줘 동점이 됐습니다. 다시 만루. 여기서 더 내주면 경기가 넘어갑니다.", 0),
        scenario("game-rain-grip", "빗속의 공", 2, 0, true, false, false, 60, 470, "빗물을 머금은 공이 손끝에서 자꾸 미끄러집니다. 노린 코스보다 한 뼘씩 벗어납니다.", 0),
        scenario("game-doubleheader", "더블헤더 2차전", 4, 2, false, true, false, 64, 640, "오늘 두 번째 경기. 한 점 뒤진 채, 낮 경기에서 이미 던진 팔이 무겁게 남아 있습니다.", -1),
        scenario("game-scout-showcase", "스카우트 총출동", 7, 2, false, false, false, 55, 960, "팀은 두 점 뒤졌지만 관중석 첫 줄은 스카우트로 가득합니다. 공 하나하나가 순위표에 적힙니다.", -2),
        scenario("game-rival-away", "라이벌 원정", 6, 2, true, false, false, 61, 830, "라이벌 학교 원정, 한 점 뒤진 6회. 마운드에 설 때마다 스탠드가 야유로 덮습니다. 소리를 지워야 공이 보입니다.", -1),
        scenario("game-cold-spring", "이른 봄의 손끝", 2, 0, false, false, false, 55, 420, "3월의 첫 대회. 입김이 보이는 추위에 공이 돌덩이처럼 미끄럽고, 손끝의 감각이 절반만 돌아와 있습니다.", 0),
        scenario("game-fireman", "떠안은 주자", 6, 0, false, true, true, 66, 930, "앞선 투수가 남긴 무사 2·3루를 떠안고 오릅니다. 여기서 들어오는 점수는 내 기록이 아니지만, 경기는 내 손에 있습니다.", -1),
        scenario("game-mercy-watch", "다섯 점의 함정", 5, 0, true, false, false, 57, 380, "다섯 점 리드. 긴장이 풀리는 딱 그 지점에서 실점이 시작됩니다. 스카우트는 큰 리드에서의 집중력을 봅니다.", 5),
        scenario("game-nightfall", "일몰 직전", 7, 1, false, true, false, 62, 700, "조명 없는 구장, 해가 산 뒤로 넘어가고 있습니다. 심판이 이 이닝이 오늘의 마지막이라고 알렸습니다. 동점이면 내일 처음부터 다시입니다.", 0),
        scenario("game-heatwave", "한여름 낮 경기", 6, 0, true, false, false, 60, 660, "35도의 낮 경기. 유니폼이 몸에 감기고 로진백도 눅눅합니다. 한 점 리드가 이 더위 속에서 여덟 아웃만큼 멀어 보입니다.", 1, 2),
        scenario("game-third-look", "세 번째 만나는 4번", 6, 2, false, true, false, 63, 850, "오늘 세 번째로 만나는 상대 4번 타자. 앞선 두 타석의 공을 전부 기억하고 있을 겁니다. 같은 순서는 이제 통하지 않습니다.", -1),
        scenario("game-perfect-bid", "5회까지 완전", 6, 1, false, false, false, 55, 780, "5회까지 한 명도 내보내지 않았습니다. 더그아웃이 조용해졌습니다 — 아무도 그 단어를 입에 올리지 않습니다.", 3, 4),
        scenario("game-backup-catcher", "백업 포수와의 승부", 7, 1, true, false, false, 61, 740, "주전 포수가 파울 타구에 손가락을 맞아 교체됐습니다. 백업 포수와는 불펜 한 번 맞춰 본 게 전부입니다.", 0),
        scenario("game-seniors-last", "선배들의 마지막", 8, 1, true, true, false, 64, 890, "두 점 뒤진 8회. 지면 3학년 선배들의 고교 야구가 오늘로 끝납니다. 더그아웃의 눈이 전부 마운드를 보고 있습니다.", -2, 2),
        scenario("game-sign-leak", "새는 사인", 5, 0, false, true, false, 65, 720, "상대 2루 주자가 타자에게 무언가를 전달하는 정황. 사인이 읽히고 있다면, 이제부터는 코스보다 배짱의 승부입니다.", -1),
    )

    public fun eligibleRebirthEvents(echo: HighSchoolRebirthEcho?): List<HighSchoolRelationshipEvent> {
        if (echo == null) return rebirthEvents
        val ids = mutableSetOf(
            "evt-deja-vu-mound", "evt-second-summer", "evt-future-news", "evt-glove-worn",
        )
        if (echo.hasInheritedPower) ids += "evt-body-remembers"
        if (echo.previousArmWarning) ids += "evt-memory-ache"
        if (echo.hasRunsAllowedFact) ids += "evt-remembered-pitch"
        if (!echo.previousRivalName.isNullOrBlank()) ids += "evt-rival-deja-vu"
        if (!echo.previousNickname.isNullOrBlank()) ids += "evt-old-nickname"
        if (echo.previousUndrafted) ids += "evt-undrafted-deja"
        if (!echo.previousCoachName.isNullOrBlank()) ids += "evt-known-coach"
        // The Swift source deliberately excludes a teammate-loss event because the current
        // archive has no authoritative teammate departure receipt.
        return rebirthEvents.filter { it.id in ids }
    }

    public fun prioritizedRebirthEvents(
        events: List<HighSchoolRelationshipEvent>,
        recentEventIds: List<String>,
    ): List<HighSchoolRelationshipEvent> {
        if (events.isEmpty() || recentEventIds.isEmpty()) return events
        val recent = recentEventIds.toSet()
        val unseen = events.filter { it.id !in recent }
        if (unseen.isNotEmpty()) return unseen
        val oldest = events.mapNotNull { event -> recentEventIds.indexOf(event.id).takeIf { it >= 0 } }.minOrNull()
        return events.filter { recentEventIds.indexOf(it.id) == oldest }
    }

    public fun schools(region: String): List<HighSchoolSchool> {
        val names = regionalNames[region] ?: regionalNames.getValue("서울")
        val regionIndex = regionalNames.keys.toList().indexOf(region).coerceAtLeast(0)
        fun coach(pool: Int): String = coachNames[pool][regionIndex % 5]
        fun catcher(pool: Int): String = catcherNames[pool][regionIndex % 5]
        return listOf(
            HighSchoolSchool(
                HighSchoolSchoolId.HANBIT_TRADITIONAL, names[0], "기본기와 긴 이닝", coach(0), "원칙형",
                catcher(0), "안정형", HighSchoolTrainingFocus.STAMINA, "새 구종을 시험할 기회가 적습니다.",
                "새벽 반복 훈련을 고집하며 핑계보다 공 하나를 더 던지게 합니다.", "재임 14년 · 전국대회 4강 6회",
                "실투 뒤에도 먼저 투수에게 공을 돌려주는 매일 출전형 포수입니다.", "중학 마지막 시즌 26경기 · 도루저지율 .438",
            ),
            HighSchoolSchool(
                HighSchoolSchoolId.MIRAE_ANALYTICS, names[1], "기록을 활용한 타자 상대법", coach(1), "분석형",
                catcher(1), "분석형", HighSchoolTrainingFocus.GAME_PLANNING, "데이터가 적을 때 판단이 흔들릴 수 있습니다.",
                "확률표를 들고 한 베이스와 불펜 교체 시점을 끝까지 계산합니다.", "데이터 코치 경력 11년 · 지역대회 우승 4회",
                "말수는 적지만 타자의 노림수를 먼저 읽고 결정적인 순간 직접 해결합니다.", "전국중학대회 포수상 · 8홈런",
            ),
            HighSchoolSchool(
                HighSchoolSchoolId.HAEDONG_POWER, names[2], "빠른 직구와 공격적인 승부", coach(2), "승부형",
                catcher(2), "공격형", HighSchoolTrainingFocus.VELOCITY, "빠른 공을 많이 던질수록 피로가 쌓이고 제구가 흔들립니다.",
                "에이스에게 가장 엄격하며 위기일수록 몸쪽 정면승부를 요구합니다.", "전국대회 결승 3회 · 프로 지명 투수 5명",
                "몸쪽 사인을 두려워하지 않고 큰 경기에서 투수를 강하게 끌고 갑니다.", "중학 마지막 시즌 24경기 선발 · 도루저지 11회",
            ),
            HighSchoolSchool(
                HighSchoolSchoolId.CHEONGAM_DEVELOPMENT, names[3], "개인별 투구 동작과 변화구 훈련", coach(3), "육성형",
                catcher(3), "공감형", HighSchoolTrainingFocus.BREAKING_BALL, "팀이 연패하면 개인 훈련 시간이 줄어듭니다.",
                "무심한 표정으로 결단을 내리지만 큰 경기에서는 선수를 먼저 믿습니다.", "7년간 프로 지명 12명 · 변화구 캠프 9회",
                "블로킹 천 번을 기본으로 여기며 투수의 버릇까지 잡아내는 완벽주의자입니다.", "중학 마지막 시즌 무실책 · 4경기 연속 장타",
            ),
        )
    }

    public val memoryCards: List<String> = listOf(
        "velocity_blueprint", "fingertip_memory", "catcher_notebook", "rival_notebook",
        "recovery_routine", "pressure_rehearsal", "first_pitch_map", "two_strike_sequence",
        "fatigue_diary", "mechanics_video", "school_playbook", "coach_letter", "draft_report",
        "stadium_echo", "team_first_promise", "failure_scorebook", "winter_program", "bullpen_compass",
    )

    public val awakeningNodes: List<AwakeningNode> = listOf(
        AwakeningNode(HighSchoolAwakening.EXPLOSIVE_FASTBALL, "power", 1, emptyList()),
        AwakeningNode(HighSchoolAwakening.RISING_FOUR_SEAM, "power", 2, listOf(HighSchoolAwakening.EXPLOSIVE_FASTBALL)),
        AwakeningNode(HighSchoolAwakening.IRON_ARM, "power", 2, listOf(HighSchoolAwakening.EXPLOSIVE_FASTBALL)),
        AwakeningNode(HighSchoolAwakening.LATE_INNING_RESERVE, "power", 3, listOf(HighSchoolAwakening.IRON_ARM)),
        AwakeningNode(HighSchoolAwakening.PINPOINT_EDGE, "command", 1, emptyList()),
        AwakeningNode(HighSchoolAwakening.REPEATABLE_RELEASE, "command", 2, listOf(HighSchoolAwakening.PINPOINT_EDGE)),
        AwakeningNode(HighSchoolAwakening.FIRST_PITCH_STRIKE, "command", 2, listOf(HighSchoolAwakening.PINPOINT_EDGE)),
        AwakeningNode(HighSchoolAwakening.CALM_UNDER_PRESSURE, "command", 3, listOf(HighSchoolAwakening.REPEATABLE_RELEASE)),
        AwakeningNode(HighSchoolAwakening.SCOUT_COMPOSURE, "command", 3, listOf(HighSchoolAwakening.FIRST_PITCH_STRIKE)),
        AwakeningNode(HighSchoolAwakening.DISAPPEARING_BREAKER, "breaking", 1, emptyList()),
        AwakeningNode(HighSchoolAwakening.SWEEPING_SLIDER, "breaking", 2, listOf(HighSchoolAwakening.DISAPPEARING_BREAKER)),
        AwakeningNode(HighSchoolAwakening.CURVEBALL_CLOCK, "breaking", 2, listOf(HighSchoolAwakening.DISAPPEARING_BREAKER)),
        AwakeningNode(HighSchoolAwakening.FROZEN_CHANGEUP, "breaking", 3, listOf(HighSchoolAwakening.SWEEPING_SLIDER)),
        AwakeningNode(HighSchoolAwakening.SINKER_TUNNEL, "breaking", 3, listOf(HighSchoolAwakening.CURVEBALL_CLOCK)),
        AwakeningNode(HighSchoolAwakening.BATTERY_SYNC, "game", 1, emptyList()),
        AwakeningNode(HighSchoolAwakening.TWO_STRIKE_PLAN, "game", 2, listOf(HighSchoolAwakening.BATTERY_SYNC)),
        AwakeningNode(HighSchoolAwakening.PICKOFF_RHYTHM, "game", 2, listOf(HighSchoolAwakening.BATTERY_SYNC)),
        AwakeningNode(HighSchoolAwakening.TRAFFIC_CONTROLLER, "game", 3, listOf(HighSchoolAwakening.TWO_STRIKE_PLAN)),
    )
}

public data class AwakeningNode(
    val id: HighSchoolAwakening,
    val branch: String,
    val tier: Int,
    val parents: List<HighSchoolAwakening>,
)
