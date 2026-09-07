package com.solkim.baseball.application

/** Player-facing baseball terms. Korean names stay in the product binary; ids match the iOS catalog. */
public data class BaseballGlossaryTerm(
    val id: String,
    val name: String,
    val definition: String,
)

public object BaseballGlossary {
    public val terms: List<BaseballGlossaryTerm> = listOf(
        term("stuff", "구위", "타자를 밀어붙이는 공의 힘."),
        term("command", "제구", "원하는 코스에 꽂는 감각. 높을수록 초록 구간이 넓다."),
        term("movement", "무브먼트", "공 끝의 흔들림. 헛스윙을 만든다."),
        term("stamina", "체력", "긴 이닝을 버티는 힘."),
        term("fatigue", "피로", "던지고 훈련하면 쌓이고, 쉬면 빠진다. 높으면 미터가 빨라진다."),
        term("manager-faith", "감독의 믿음", "보직과 다음 기회를 정하는 감독의 마음."),
        term("catcher-chemistry", "포수와의 호흡", "사인이 맞을수록 공이 산다."),
        term("mastery", "숙련", "같은 구종을 던지고 또 던져 몸에 남은 것."),
        term("talent-wall", "재능의 벽", "타고난 천장. 각성이나 유산으로 열린다."),
        term("baseball-spirit", "야구혼", "한 생이 끝나며 남는 힘. 다음 생의 출발을 바꾼다."),
        term("awakening", "각성", "한 장면이 투구 감각을 바꾼다."),
        term("lineage", "계보", "지난 생의 유산이 다음 생에 스며든다."),
        term("role", "보직", "선발·구원·마무리. 내가 던지는 자리."),
        term("qs", "퀄리티 스타트", "선발이 6이닝 이상을 3자책 이하로 막은 등판."),
        term("era", "평균자책점", "9이닝당 자책점."),
        term("whip", "WHIP", "이닝당 내보낸 주자 수."),
        term("k9", "9이닝당 탈삼진", "9이닝으로 환산한 삼진 수."),
        term("fip", "FIP", "삼진·볼넷·홈런만으로 본 투수의 진짜 성적."),
        term("war", "WAR", "대체 선수보다 얼마나 더 이겼나."),
        term("k-percent", "삼진율", "타석 중 삼진으로 잡은 비율."),
        term("bb-percent", "볼넷율", "타석 중 볼넷을 준 비율."),
        term("replacement-level", "대체 수준", "언제든 불러올 수 있는 평범한 투수의 수준."),
        term("platoon", "플래툰", "좌타·우타에 따라 갈리는 승부."),
        term("pitcher-lab", "피치랩", "겨울에 구종을 다듬는 투자."),
        term("season-decision", "시즌 결정", "한 주를 훈련 대신 갈림길에 쓰는 선택."),
        term("signing-bonus", "계약금", "사인과 함께 바로 들어오는 돈."),
        term("club-interest", "구단 관심", "재계약과 FA에서 팀이 나를 얼마나 원하나."),
        term("national-team-call", "대표팀 소집", "짝수 시즌에 오는 국가대표의 부름."),
        term("military-exemption", "병역 면제", "금메달 한 번이면 복무를 마친다."),
    )

    private fun term(id: String, name: String, definition: String) = BaseballGlossaryTerm(id, name, definition)
}
