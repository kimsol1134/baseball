// 관계 씬 인용 대사를 신뢰도 구간(낮음/보통/높음)에 따라 고르는 순수 로직.
// 화면(HighSchoolCareerView)에서 감독=managerTrust, 포수=catcherTrust, 라이벌=rivalTrust를
// 각각 구간으로 바꿔 넘긴다. 같은 인물의 회차가 지날수록 신뢰도가 오르내리므로
// 갈등(낮음)→시험(보통)→회수(높음)의 톤 아크가 자연히 만들어진다.

export type TrustBand = "low" | "mid" | "high";

// 화면의 trustMeaning 경계와 맞춘 구간. 낮음<45, 보통 45–64, 높음≥65.
export function relationshipTrustBand(trust: number): TrustBand {
  if (trust >= 65) return "high";
  if (trust < 45) return "low";
  return "mid";
}

// 키 씬별 낮음/보통/높음 대사. "보통"은 기존 손대사를 글자 그대로 유지하고,
// 낮음/높음만 새로 더한다. 대사는 제목의 능청을 아주 옅게 허용하되 관찰형 캐릭터 보이스를 지킨다.
export const RELATIONSHIP_QUOTE_VARIANTS: Record<string, Record<TrustBand, string>> = {
  // 감독 3장면
  "evt-coach-role": {
    low: "“선발은 아직 이르다. 불펜부터 시작해. …이유를 따질 시간에 공이나 더 던져 봐.”",
    mid: "“다음 대회는 불펜에서 시작한다. 경기 후반을 맡아 줘.”",
    high: "“{player}. 이번엔 네가 경기 후반을 닫아 줘. 마지막 이닝은 아무한테나 안 맡긴다.”",
  },
  "evt-coach-bench": {
    low: "“오늘은 뺀다. 몸 상태를 나한테 숨기는 선수는 더 오래 못 믿어.”",
    mid: "“이번 등판은 쉰다. 요즘은 팔이 몸보다 늦게 따라온다.”",
    high: "“하루 쉬자. {player}가 무리하는 걸 알면서 내보내면, 그건 내 잘못이 되니까.”",
  },
  "evt-coach-last-advice": {
    low: "“마지막 훈련이다. …아직도 내가 정해 줘야 하나. 스스로 못 고르면 프로에선 더 헤맨다.”",
    mid: "“마지막 훈련은 네가 정해라. 지금 가장 부족한 게 뭐지?”",
    high: "“마지막 훈련은 {player} 너한테 맡긴다. 3년을 봤으니, 이제 네 판단을 믿어 볼 때도 됐지.”",
  },
  // 포수 3장면
  "evt-catcher-sign": {
    low: "“또 사인이 세 번 바뀌었어. …이럴 거면 왜 나랑 배터리를 맞춰?”",
    mid: "“오늘 사인이 세 번이나 바뀌었어. 내가 놓친 게 뭐였어?”",
    high: "“세 번 바꾼 거, 오늘은 다 맞았어. {player} 공은 이제 내가 제일 잘 알아.”",
  },
  "evt-battery-dinner": {
    low: "“네 변화구, 솔직히 나도 못 받겠어. 이건 배터리가 아니라 각자 야구잖아.”",
    mid: "“솔직히 네 변화구가 어디로 올지 몰라서 겁날 때가 있어.”",
    high: "“이제 {player} 변화구는 눈 감고도 받아. 손 떠나는 순간 어디 떨어질지 보이거든.”",
  },
  "evt-catcher-doubt": {
    low: "“사인을 그렇게 거절할 거면 마운드에서 혼자 다 정해. …난 뭐 하러 앉아 있어?”",
    mid: "“요즘 내 사인을 자꾸 거절하잖아. 내가 못 본 게 있어?”",
    high: "“요즘 {player}가 고개 젓는 공이 더 좋더라. 네가 보는 걸 나도 보고 싶어.”",
  },
  // 라이벌 2장면
  "evt-rival-video": {
    low: "“네 높은 포심, 이제 안 무서워.” 헛스윙 하나 없는 타격 영상만 툭 보내왔다.",
    mid: "“높은 포심 타이밍, 이제 맞췄어.” 짧은 타격 영상이 함께 도착했다.",
    high: "“{player}. 높은 포심, 드디어 맞췄어. …근데 이거 하나 맞추는 데 3년 걸렸다.” 영상 끝엔 웃는 표시가 붙어 있었다.",
  },
  "evt-rival-final": {
    low: "타석에 선 그가 포수 미트도 보지 않고 웃는다. “어차피 거기로 올 거잖아. 다 알아.”",
    mid: "타석에 들어선 그가 지난 경기와 같은 코스를 배트 끝으로 가리킨다. “또 여기로 던져 봐.”",
    high: "타석에 들어선 그가 배트를 고쳐 쥐며 낮게 말한다. “{player}. 마지막이네. 네 제일 좋은 공으로 와. 그래야 이겨도 져도 남지.”",
  },
  // 카테고리 폴백(고정 이벤트가 없을 때 순번으로 도는 대사)
  "fallback-rival": {
    low: "“어차피 또 같은 초구겠지. …너 그거밖에 없잖아.”",
    mid: "“다음에도 같은 초구를 던질 거야?”",
    high: "“{player} 다음 초구, 뭐 던질지 맞혀 볼까. …아니다, 그건 직접 보는 게 낫지.”",
  },
};

// 키 씬의 신뢰도별 대사. 변형이 없는 씬은 undefined를 돌려 화면이 기존 고정 대사를 쓰게 한다.
export function bandedRelationshipQuote(eventId: string, band: TrustBand): string | undefined {
  return RELATIONSHIP_QUOTE_VARIANTS[eventId]?.[band];
}
