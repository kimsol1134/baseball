package com.solkim.baseball.application

/** Player-facing baseball terms. Korean names stay in the product binary; ids match the iOS catalog. */
public data class BaseballGlossaryTerm(
    val id: String,
    val name: String,
    val definition: String,
)

public object BaseballGlossary {
    public val terms: List<BaseballGlossaryTerm> = listOf(
        term("stuff", "구위", "타자를 밀어붙이는 공의 힘입니다."),
        term("command", "제구", "원하는 코스로 공을 보내는 감각입니다."),
        term("movement", "무브먼트", "공 끝에서 흔들리는 변화입니다."),
        term("stamina", "체력", "긴 이닝을 버티는 힘입니다."),
        term("fatigue", "피로", "등판과 훈련이 쌓이면 올라가고, 회복하면 내려갑니다."),
        term("manager-faith", "감독의 믿음", "보직과 다음 기회를 좌우하는 신뢰입니다."),
        term("catcher-chemistry", "포수와의 호흡", "사인이 맞을수록 실행이 살아납니다."),
        term("mastery", "숙련", "같은 구종을 반복해 몸에 남긴 완성도입니다."),
        term("talent-wall", "재능의 벽", "더 올리기 어려운 능력의 천장입니다."),
        term("baseball-spirit", "야구혼", "다음 생에 남기는 힘입니다."),
        term("awakening", "각성", "한 장면이 투구 감각을 바꿉니다."),
        term("lineage", "계보", "이전 생의 유산이 다음 선수에 스며듭니다."),
        term("role", "보직", "선발·구원·마무리처럼 던지는 자리입니다."),
        term("qs", "퀄리티 스타트", "선발이 긴 이닝을 적은 실점으로 막은 등판입니다."),
        term("era", "평균자책점", "9이닝당 허용한 자책점입니다."),
        term("whip", "WHIP", "이닝당 출루 허용입니다."),
        term("k9", "9이닝당 탈삼진", "긴 이닝으로 환산한 삼진입니다."),
        term("fip", "FIP", "삼진·볼넷·홈런으로 본 투수 책임 지표입니다."),
        term("war", "WAR", "대체 선수 대비 기여입니다."),
        term("k-percent", "삼진율", "상대 타석에서 삼진을 잡은 비율입니다."),
        term("bb-percent", "볼넷율", "상대 타석에서 볼넷을 준 비율입니다."),
        term("replacement-level", "대체 수준", "언제든 부를 수 있는 평균 전력입니다."),
        term("platoon", "플래툰", "좌우 상대에 따라 갈리는 승부입니다."),
        term("pitcher-lab", "피치랩", "비시즌에 구종을 다듬는 투자입니다."),
        term("season-decision", "시즌 결정", "한 주의 훈련 대신 이야기의 갈림길입니다."),
        term("signing-bonus", "계약금", "서명과 함께 바로 들어오는 돈입니다."),
        term("club-interest", "구단 관심", "재계약과 FA에서 팀이 얼마나 원하는지입니다."),
        term("national-team-call", "대표팀 소집", "짝수 시즌에 열리는 국가대표 기회입니다."),
        term("military-exemption", "병역 면제", "금메달 한 번으로 복무를 마칩니다."),
    )

    private fun term(id: String, name: String, definition: String) = BaseballGlossaryTerm(id, name, definition)
}
