export type CareerNewsCategory = "game" | "people" | "career" | "health";
export type CareerNewsTone = "positive" | "neutral" | "negative";

export interface CareerNewsContext {
  mode: "high_school" | "pro";
  playerName: string;
  affiliation: string;
  period: string;
  trust: number;
  managerTrust?: number;
  catcherTrust?: number;
  rivalTrust?: number;
  fanInterest?: number;
  coachName?: string;
  catcherName?: string;
  level?: string;
}

export interface CareerFanPost {
  handle: string;
  role: string;
  message: string;
  cheers: number;
}

export interface CareerNewsDetail {
  id: string;
  headline: string;
  category: CareerNewsCategory;
  categoryLabel: string;
  tone: CareerNewsTone;
  source: string;
  timeLabel: string;
  lead: string;
  paragraphs: readonly [string, string];
  quoteSpeaker: string;
  quote: string;
  watchPoint: string;
  fanSummary: string;
  fanPosts: readonly CareerFanPost[];
}

const CATEGORY_LABELS: Record<CareerNewsCategory, string> = {
  game: "경기",
  people: "라커룸",
  career: "진로",
  health: "컨디션",
};

const GAME_WORDS = ["경기", "대회", "등판", "탈삼진", "삼진", "볼넷", "실점", "무실점", "승리", "세이브", "이닝", "보직"];
const PEOPLE_WORDS = ["감독", "포수", "배터리", "사인", "면담", "훈련", "불펜", "동료", "라이벌"];
const CAREER_WORDS = ["드래프트", "지명", "스카우트", "진학", "입학", "계약", "콜업", "FA", "은퇴", "수상", "각성", "익혔"];
const HEALTH_WORDS = ["부상", "통증", "회복", "과부하", "피로", "재활"];
const NEGATIVE_WORDS = ["미지명", "패배", "볼넷", "부상", "통증", "과부하", "연패", "흔들", "무너", "탈락", "낮아"];
const POSITIVE_WORDS = ["무실점", "0실점", "0볼넷", "지명", "입학이 확정", "계약", "콜업", "수상", "우승", "익혔", "승리", "첫 공식 등판", "좋은 평가"];

function includesAny(value: string, candidates: readonly string[]) {
  return candidates.some((candidate) => value.includes(candidate));
}

function hasFinalConsonant(value: string) {
  const lastCharacter = [...value.trim()].at(-1);
  if (!lastCharacter) return false;
  const codePoint = lastCharacter.charCodeAt(0);
  return codePoint >= 0xac00 && codePoint <= 0xd7a3 && (codePoint - 0xac00) % 28 !== 0;
}

function withParticle(value: string, afterConsonant: string, afterVowel: string) {
  return `${value}${hasFinalConsonant(value) ? afterConsonant : afterVowel}`;
}

export function classifyCareerNews(item: string): CareerNewsCategory {
  if (includesAny(item, HEALTH_WORDS)) return "health";
  if (includesAny(item, CAREER_WORDS)) return "career";
  if (includesAny(item, GAME_WORDS)) return "game";
  if (includesAny(item, PEOPLE_WORDS)) return "people";
  return "people";
}

export function careerNewsTone(item: string): CareerNewsTone {
  const negativeText = item
    .replaceAll("무실점", "")
    .replaceAll("0실점", "")
    .replace(/(?:0\s*개?\s*볼넷|볼넷\s*0\s*개?|볼넷\s*(?:없이|없는))/g, "");
  const runsAllowed = negativeText.includes("실점");
  if (runsAllowed || includesAny(negativeText, NEGATIVE_WORDS)) return "negative";
  if (includesAny(item, POSITIVE_WORDS)) return "positive";
  return "neutral";
}

function stableHash(value: string) {
  let hash = 2_166_136_261;
  for (let index = 0; index < value.length; index += 1) {
    hash ^= value.charCodeAt(index);
    hash = Math.imul(hash, 16_777_619);
  }
  return hash >>> 0;
}

function sourceFor(category: CareerNewsCategory, mode: CareerNewsContext["mode"]) {
  const schoolSources: Record<CareerNewsCategory, string> = {
    game: "전국 고교야구 통신",
    people: "덕아웃 리포트",
    career: "지역 야구소식",
    health: "선수 관리 데스크",
  };
  const proSources: Record<CareerNewsCategory, string> = {
    game: "프로야구 데일리",
    people: "클럽하우스 취재팀",
    career: "베이스볼 비즈",
    health: "메디컬 리포트",
  };
  return mode === "high_school" ? schoolSources[category] : proSources[category];
}

function storyParagraphs(
  item: string,
  category: CareerNewsCategory,
  tone: CareerNewsTone,
  context: CareerNewsContext,
): readonly [string, string] {
  const player = context.playerName;
  const team = context.affiliation;
  if (category === "game") {
    if (item.includes("무실점") || item.includes("0실점")) {
      return [`${team} 관계자들은 무실점이라는 결과보다 ${withParticle(player, "이", "가")} 주자가 나간 뒤에도 투구 템포를 바꾸지 않은 장면을 높게 봤다. 포수와 정한 승부 순서를 끝까지 유지한 것도 좋은 평가를 받았다.`, `다음 상대는 이 경기의 투구 영상을 이미 확보했다. 이제 관심은 같은 코스를 노리는 타자를 상대로도 ${player}의 결정구가 통할지에 쏠린다.`];
    }
    if (tone === "negative") {
      return [`기록표에 남은 숫자보다 과정이 더 뼈아팠다. 유리한 카운트를 만들고도 마무리 공이 가운데로 몰리면서 ${withParticle(player, "이", "가")} 원하는 흐름을 이어 가지 못했다.`, `${team} 코칭스태프는 다음 등판 전 불펜에서 초구 스트라이크와 2스트라이크 이후 승부구를 따로 점검할 계획이다.`];
    }
    return [`이번 소식만으로 ${withParticle(player, "이", "가")} 잘 던지고 있는지 단정하기는 어렵다. 코칭스태프는 결과만 보지 않고 상대 타선, 투구 수, 주자가 있을 때의 투구까지 함께 살폈다.`, `${withParticle(team, "은", "는")} 다음 경기에서도 같은 순서로 공을 던질지, 상대 타자에 맞춰 바꿀지 경기 전 회의에서 결정할 예정이다.`];
  }
  if (category === "career") {
    if (item.includes("입학")) {
      return [`${team} 야구부는 ${player}의 합류를 확정한 뒤 첫 불펜 일정과 체력 측정 계획을 함께 전달했다. 지도부는 당장 구속을 올리기보다 고교 일정에 맞는 몸을 만드는 데 우선순위를 뒀다.`, `첫 훈련에서는 기존 투수들과 같은 메뉴를 소화한다. 이후 포수와의 호흡, 회복 속도, 원하는 곳에 공을 꾸준히 던지는지를 보고 봄 대회에서 맡을 역할을 정할 예정이다.`];
    }
    if (item.includes("제안") || item.includes("스카우트") || item.includes("관심")) {
      return [`지역 대회에서 ${player}의 투구를 지켜본 학교들은 최고 구속보다 볼이 연달아 나온 뒤 다시 스트라이크를 던지는 모습과 경기 후반에도 흔들리지 않는 투구에 주목했다. 여러 학교의 지도자가 같은 날 진학 의사를 확인했다.`, `제안을 보낸 학교마다 훈련 방식과 당장 비어 있는 자리가 다르다. ${player}에게는 학교의 이름보다 실제 등판 기회와 어떤 포수와 호흡을 맞출지를 비교하는 일이 중요해졌다.`];
    }
    if (item.includes("드래프트") || item.includes("지명")) {
      return [`구단들은 ${player}의 최근 경기뿐 아니라 고교 기간 동안의 구속 변화, 결장 이력, 주자가 있을 때의 투구를 한꺼번에 검토했다. 선발로 키울 수 있는지와 곧바로 경기에 내보낼 수 있는지를 두고 평가는 갈렸다.`, `지명 결과가 확정되면 ${team}에서 처음 맡을 역할과 개인 훈련 계획이 정해진다. 미지명일 경우에는 다음 진로를 결정할 시간이 곧바로 시작된다.`];
    }
    if (item.includes("계약") || item.includes("콜업")) {
      return [`${withParticle(team, "은", "는")} ${player}에게 기대하는 역할과 당장 고쳐야 할 부분을 협상 자리에서 분명히 했다. 보장된 자리는 없지만 1군이나 선발 기회를 받으려면 무엇을 보여 줘야 하는지는 구체적으로 제시됐다.`, `계약서나 등록 명단에 이름이 오르는 순간부터 경쟁 상대도 달라진다. 첫 일정의 투구 수와 회복 계획이 다음 기회를 좌우할 전망이다.`];
    }
    return [`지도자들은 ${context.period}까지 ${player}의 구속 변화, 볼넷, 변화구, 결장 여부를 다시 확인했다. 감독과 포수가 실제 경기에서 느낀 장단점도 함께 기록했다.`, `다음 경기에서 몇 이닝을 맡을지와 선발 기회를 받을지가 이 기록에 따라 달라진다. ${player}에게는 다음 등판에서 약점 하나를 줄이는 일이 가장 중요해졌다.`];
  }
  if (category === "health") {
    if (item.includes("회복") || item.includes("복귀")) {
      return [`${withParticle(team, "은", "는")} ${player}의 회복 상태를 구속보다 투구 동작이 흔들리지 않는지와 공을 던진 다음 날 통증이 생기는지로 확인했다. 현재까지 통증은 다시 나타나지 않았지만 훈련량은 조금씩 늘릴 계획이다.`, `복귀 일정은 한 번의 불펜 투구로 확정하지 않는다. 며칠 연속 훈련한 뒤에도 몸에 이상이 없는지가 실제 등판 시점을 결정한다.`];
    }
    return [`${withParticle(team, "은", "는")} ${player}의 통증 정도와 실제 투구 동작을 함께 확인하고 있다. 구속 하나만으로 몸 상태를 판단하지 않고, 경기 뒤 얼마나 빨리 회복하는지도 살핀다.`, `선수 보호가 우선이지만 경쟁 일정은 기다려 주지 않는다. 다음 훈련을 얼마나 강하게 할지가 경기력과 출전 기회에 동시에 영향을 줄 전망이다.`];
  }
  if (item.includes("포수") || item.includes("배터리") || item.includes("사인")) {
    return [`${withParticle(player, "과", "와")} 배터리를 이룬 포수는 최근 경기 영상을 함께 보며 사인이 흔들린 장면과 좋았던 승부를 따로 표시했다. 두 선수는 다음 경기의 첫 세 타자까지 사용할 순서를 미리 정했다.`, `호흡이 좋아졌다는 평가는 대화가 아니라 경기에서 확인된다. 위기에서 첫 사인을 그대로 믿을 수 있는지가 둘 사이의 다음 기준이 된다.`];
  }
  if (item.includes("훈련")) {
    return [`${team} 훈련장에서 ${player}의 반복 동작이 이전보다 안정됐다는 평가가 나왔다. 코칭스태프는 한 번의 최고 구속보다 같은 위치에 공을 되풀이한 횟수를 기록했다.`, `새 동작을 경기 강도에서도 유지할 수 있는지는 아직 확인되지 않았다. 다음 불펜과 실전 등판이 이번 훈련의 실제 성과를 가른다.`];
  }
  return [`이 대화 뒤 감독은 ${player}에게 맡길 이닝을 다시 검토했고, 포수는 다음 경기 첫 세 타자에게 던질 공의 순서를 정리했다.`, `${player}가 위기에서 포수의 첫 사인을 믿고 던지는지가 다음 출전 기회에 직접 영향을 준다.`];
}

// 결정론적 인용 순환. 주차·경기 수를 담은 context.period와 헤드라인으로 지문을 만들어
// 풀에서 하나를 고른다. 같은 소식은 늘 같은 인용을, 주차가 바뀌면 다음 인용을 돌려준다.
// (각 풀의 1번은 기존 고정 문장을 그대로 유지한다.)
export function rotateQuote(pool: readonly string[], seed: string): string {
  return pool[stableHash(seed) % pool.length];
}

const GAME_POSITIVE_QUOTES = [
  "좋았던 공 하나보다, 흔들린 뒤에도 다음 사인을 믿고 던진 게 더 중요했어요.",
  "결과보다, 주자가 나가고도 투구 템포가 안 흔들린 게 눈에 띄었어요.",
  "오늘은 승부구가 손에 붙었어요. 카운트가 몰려도 내가 먼저 급하지 않았고요.",
  "삼진 숫자는 잊어도 돼요. 위기에서 낮게 제구된 공 하나, 그거면 다음도 믿어요.",
];
const GAME_NEGATIVE_QUOTES = [
  "타자가 잘 친 공과 우리가 놓친 공을 나눠 봐야 해요. 다음에는 같은 실수를 줄일 수 있습니다.",
  "유리한 카운트에서 한가운데로 몰린 공이 아쉬웠어요. 거기만 줄이면 됩니다.",
  "오늘은 초구 스트라이크가 안 들어갔어요. 다음 등판 전에 그것부터 맞춰요.",
  "결과는 접어 두고, 흔들린 세 타석만 같이 다시 봐요.",
];
const HEALTH_RECOVERY_QUOTES = [
  "오늘 괜찮았다는 말보다 내일도 같은 동작이 나오는지가 중요합니다. 서두르지 않겠습니다.",
  "불펜 한 번으로 복귀를 정하지 않습니다. 며칠 몸이 버티는지 보고 결정하겠습니다.",
  "구속은 천천히 올려도 됩니다. 통증 없이 던지는 날이 며칠 이어지는지가 먼저예요.",
];
const HEALTH_REST_QUOTES = [
  "지금은 쉬어야 합니다. 통증 없이 던질 수 있을 때까지 경기에 내보내지 않겠습니다.",
  "한 경기 더 던지는 것보다, 다음 달을 온전히 던지는 게 팀에 낫습니다.",
  "무리하면 다음이 없습니다. 지금은 몸부터 붙잡겠습니다.",
];
const CAREER_ADMISSION_QUOTES = [
  "입학했다고 경기에 바로 나갈 수 있는 건 아닙니다. 첫 훈련부터 다른 투수들과 같은 기준으로 경쟁합니다.",
  "이름값으로 마운드에 세우지 않습니다. 첫 불펜부터 다시 봅니다.",
  "환영은 오늘까지고, 내일부터는 다른 투수들과 같은 줄에 섭니다.",
];
const CAREER_OFFER_QUOTES = [
  "제안의 숫자보다 어느 환경에서 가장 자주 던질 수 있는지를 먼저 봐야 합니다.",
  "학교 이름보다, 누구와 배터리를 맞추고 몇 이닝을 받는지가 중요합니다.",
  "제안이 많다고 좋은 게 아닙니다. 실제로 공 던질 자리가 있는 곳을 고르세요.",
];
const CAREER_DRAFT_QUOTES = [
  "평가는 끝났습니다. 이제 결과가 나오면 그 자리에서 다음 준비를 시작해야 합니다.",
  "순번은 제 손을 떠났습니다. 이름이 불리든 아니든, 다음 공은 똑같이 준비합니다.",
  "구단이 무엇을 봤는지는 곧 나옵니다. 우린 우리가 던진 걸 믿으면 됩니다.",
];
const CAREER_DEFAULT_QUOTES = [
  "다음 경기에서 초구 스트라이크를 잡는지, 위기에서도 자기 공을 던지는지 보겠습니다.",
  "기록은 다 확인했습니다. 남은 건 다음 등판에서 약점 하나를 줄이는 일입니다.",
  "평가서의 숫자보다, 주자가 있을 때 던지는 공을 보겠습니다.",
];
const PEOPLE_DEFAULT_QUOTES = [
  "감독과 포수 앞에서 한 약속은 경기에서 지켜야 합니다. 다음 등판을 보겠습니다.",
  "말은 오늘 정리됐고, 확인은 경기에서 합니다. 다음 등판을 보죠.",
  "라커룸에서 맞춘 건 마운드에서 드러납니다. 첫 위기 때 첫 사인을 믿는지 보겠습니다.",
];

function quoteFor(item: string, category: CareerNewsCategory, tone: CareerNewsTone, context: CareerNewsContext) {
  const coach = context.coachName ? `${context.coachName} 감독` : "현장 관계자";
  const catcher = context.catcherName ? `${context.catcherName} 포수` : coach;
  const seed = `${context.period}|${item}`;
  if (category === "game") {
    return tone === "positive"
      ? { speaker: catcher, quote: rotateQuote(GAME_POSITIVE_QUOTES, seed) }
      : { speaker: catcher, quote: rotateQuote(GAME_NEGATIVE_QUOTES, seed) };
  }
  if (category === "health") return item.includes("회복") || item.includes("복귀")
    ? { speaker: coach, quote: rotateQuote(HEALTH_RECOVERY_QUOTES, seed) }
    : { speaker: coach, quote: rotateQuote(HEALTH_REST_QUOTES, seed) };
  if (category === "career") {
    if (item.includes("입학")) return { speaker: coach, quote: rotateQuote(CAREER_ADMISSION_QUOTES, seed) };
    if (item.includes("제안") || item.includes("스카우트")) return { speaker: coach, quote: rotateQuote(CAREER_OFFER_QUOTES, seed) };
    if (item.includes("드래프트") || item.includes("지명")) return { speaker: coach, quote: rotateQuote(CAREER_DRAFT_QUOTES, seed) };
    return { speaker: coach, quote: rotateQuote(CAREER_DEFAULT_QUOTES, seed) };
  }
  return { speaker: coach, quote: rotateQuote(PEOPLE_DEFAULT_QUOTES, seed) };
}

// 팬 반응 풀. 각 상황당 12종으로, fanPosts가 주차·소식별 지문으로 4개를 골라 반복을 줄인다.
function fanMessages(item: string, category: CareerNewsCategory, tone: CareerNewsTone, context: CareerNewsContext) {
  const player = context.playerName;
  if (category === "career" && (item.includes("입학") || item.includes("제안") || item.includes("진학"))) return [
    `${player} 어느 학교 가는지 계속 궁금했는데 이제 정해졌네`,
    "당장 에이스 얘기보다 실제로 몇 이닝 맡길지가 중요함",
    "포수랑 호흡 맞추는 장면부터 보고 싶다",
    "지역에서 계속 뛰는 거면 직관 갈 이유 하나 늘었네",
    "학교 선택은 끝났고 이제 첫 등판이 진짜 시작이지",
    "육성 잘하는 곳인지 이번 시즌 내내 지켜본다",
    "입학 소식보다 첫 불펜 명단에 언제 들지가 더 궁금",
    "같은 지역이라 원정 안 가도 되는 게 제일 반갑다",
    `${player} 유니폼 색 바뀌는 게 벌써 적응 안 되네`,
    "학교 이름값 말고 실제로 던질 자리 많은 곳이길",
    "신입생 텃세 없이 배터리부터 잘 맞았으면",
    "첫 대회 엔트리에 이름 오르면 그때가 진짜 시작",
  ];
  if (category === "career") return tone === "negative" ? [
    "결과는 아쉽지만 다음 진로까지 끝난 건 아님",
    "평가가 왜 갈렸는지 기록부터 다시 봐야 할 듯",
    "지금은 큰말보다 다음 선택을 빨리 정해야 한다",
    `${player} 여기서 접을 선수는 아니라고 봄`,
    "미지명 하나로 고교 3년을 다 지울 순 없지",
    "다음 기회가 있다면 맡을 역할부터 현실적으로 잡자",
    "오늘 소식은 아프지만 폼이 죽은 건 아니었다",
    "평가서 숫자보다 남은 카드가 뭔지부터 보자",
    `${player} 멘탈만 다시 잡으면 반등할 구간임`,
    "급하게 결론 내지 말고 다음 진로 천천히 고르자",
    "이런 날일수록 훈련 루틴 안 흔들리는 게 중요",
    "길게 보면 오늘이 전환점이었다 소리 나올 수도",
  ] : [
    "선발인지 불펜인지부터 나와야 제대로 판단 가능",
    `${player} 새 팀에서도 자기 공 던지는지 보자`,
    "계약보다 입단 뒤 훈련 계획이 더 궁금한 팬 있음?",
    "기회 받은 건 좋고 이제 경쟁 상대가 중요함",
    "기사는 기대 쪽인데 실제 등판 일정도 알려줘",
    "이제부터는 학생 때 기록보다 프로 적응이지",
    "계약 규모보다 첫 시즌 보직이 더 알고 싶다",
    `${player} 콜업까지 얼마나 걸릴지부터 궁금하다`,
    "새 배터리랑 사인 맞추는 것부터 잘 넘겼으면",
    "입단 첫날 인터뷰 톤 보니 각오는 됐더라",
    "경쟁 팀에 같은 자리 누구 있는지부터 체크",
    "학생 때 구속 말고 프로에서 몇 이닝 버티는지 보자",
  ];
  if (category === "health") return tone === "negative" ? [
    "무리해서 한 경기 더 던지는 것보다 제대로 쉬어야 함",
    "복귀 날짜부터 잡지 말고 통증 원인부터 보자",
    "선수 보호한다는 말 이번에는 진짜 지켜줬으면",
    `${player} 빈자리는 아쉽지만 급하게 올리진 말자`,
    "구속 회복보다 다음 날 몸 상태가 더 중요함",
    "재발만 없으면 기다릴 수 있다",
    "통증 참고 던진 티가 지난 등판부터 났었음",
    "이번엔 무리 안 시키는 게 시즌 전체엔 이득",
    `${player} 없는 동안 불펜 부담 늘겠지만 그래도 쉬어야지`,
    "복귀보다 재활 과정 제대로 밟는지가 먼저",
    "팔 상태 숫자 나오기 전엔 아무도 재촉 말자",
    "조급하게 올렸다 재발한 케이스 한둘 봤나",
  ] : [
    "회복 소식은 반갑지만 실전은 천천히 가자",
    "불펜 한 번 괜찮았다고 바로 올리지는 말길",
    "투구 수 제한 걸고 시작하면 좋겠다",
    `${player} 건강하게 돌아오는 게 제일 큰 전력임`,
    "다음 날 통증 없다는 소식까지 기다린다",
    "복귀전 날짜 뜨면 보러 간다",
    "몸 돌아왔다니 반갑고 첫 등판은 짧게 갔으면",
    "재활 끝 소식보다 다음 날 리포트가 더 궁금",
    `${player} 복귀 첫 공 구속은 굳이 안 봐도 됨 천천히`,
    "실전 복귀보다 연속 훈련부터 무탈했으면",
    "돌아온다는 것만으로 이번 주 제일 좋은 소식",
    "무리 없는 일정이면 길게 볼 수 있다",
  ];
  if (category === "people") return [
    "이런 뒷이야기 보고 나면 다음 경기 사인이 더 잘 보임",
    "감독 말보다 실제로 선발인지 불펜인지 보자",
    "포수랑 맞춰 가는 과정이 생각보다 중요하네",
    `${player} 혼자 잘 던지는 게임은 아니니까 관계도 챙겨야지`,
    "훈련 분위기 좋다는 말은 경기에서 확인하면 됨",
    "다음 위기에서 첫 사인 고르는 장면이 궁금하다",
    "배터리 호흡은 결국 위기 한 번에서 드러나더라",
    "감독이랑 방향 맞춘 건 좋고 결과는 경기에서 보자",
    "라커룸 분위기까지 챙기는 선수가 오래 가더라",
    `${player} 사인 주고받는 리듬이 요즘 좋아 보인다`,
    "말로 맞춘 약속, 다음 등판 첫 이닝에 확인됨",
    "이런 대화 뒤 경기가 항상 볼 만했음",
  ];
  if (tone === "positive") return [
    `${player} 공 끝은 진짜임. 다음 등판도 챙겨본다`,
    "결과도 결과인데 포수 사인 믿고 간 게 더 좋았음",
    "아직 한 경기다. 그래도 오늘은 좀 설레도 되잖아",
    "이런 성장 보는 맛에 시즌 따라가는 거지",
    "기록표보다 마운드에서 안 쫄은 게 제일 마음에 듦",
    "다음 상대가 더 세다던데 그 등판도 보러 간다",
    "오늘 마운드에서 표정 하나 안 바뀐 거 봤음?",
    "이 정도면 다음 등판 선발로 나와도 될 듯",
    `${player} 등판날 알림 맞춰놨다`,
    "위기에서 마운드 위 템포가 진짜 좋았다",
    "다음 등판 전에 이 영상 몇 번 더 돌려본다",
    "삼진쇼는 덤이고 마운드 배짱이 진짜였음",
  ];
  if (tone === "negative") return [
    "구속보다 스트라이크부터. 다음에도 이러면 힘들다",
    "기사는 크게 났는데 경기 내용은 더 봐야 함",
    "오늘은 포수가 고생했다. 다음 등판엔 달라야지",
    "기대 안 접었음. 대신 같은 실수는 그만",
    "결과만 보고 괜찮다 하기엔 몰린 공이 너무 많았음",
    `${player}한테 지금 필요한 건 변명이 아니라 다음 아웃카운트`,
    "초구 스트라이크 비율부터 다음 등판에 고쳐 오자",
    "몰린 카운트에서 한가운데 실투가 반복됐음",
    "오늘은 리듬이 안 맞았음. 다음 마운드에선 다르길",
    `${player} 폼이 아니라 승부를 급하게 간 게 문제로 보임`,
    "삼진 욕심보다 아웃카운트 하나씩 챙겼으면",
    "기록보다 다음 등판 첫 이닝이 진짜 시험이다",
  ];
  return [
    "좋다 나쁘다 말하기엔 아직 표본이 너무 적음",
    "다음 상대가 진짜 시험일 듯. 일단 기록해 둔다",
    "감독 코멘트까지 들어봐야 판단 가능",
    "지금은 조용히 지켜보는 게 맞는 것 같음",
    `${player} 역할이 정확히 뭔지 다음 경기 보면 알겠지`,
    "이 소식 하나로 들뜨진 말자. 그래도 궁금하긴 함",
    "한 경기 표본으로 결론 내는 사람들 좀 진정하자",
    "다음 등판 상대 라인업부터 보고 얘기하자",
    "오늘은 판단 보류. 대신 기록은 남겨둔다",
    `${player} 다음 등판에서 방향 잡히면 그때 평가함`,
    "기대도 실망도 아직. 그냥 지켜보는 중",
    "소식은 소식이고 확인은 결국 경기에서",
  ];
}

function fanPosts(item: string, tone: CareerNewsTone, context: CareerNewsContext): readonly CareerFanPost[] {
  const handles = context.mode === "high_school"
    ? ["@3루측막내", "@야구부동문", "@기록실옆자리", "@원정버스", "@백스톱3열", "@지역야구광"]
    : ["@외야상단", "@퇴근후야구", "@불펜문지기", "@오늘도직관", "@기록보는팬", "@원정유니폼"];
  const roles = context.mode === "high_school"
    ? ["지역 팬", "동문", "기록 팬", "학부모 팬", "직관 팬", "중립 팬"]
    : ["시즌권 팬", "직관 팬", "투수 팬", "원정 팬", "기록 팬", "중립 팬"];
  const messages = fanMessages(item, classifyCareerNews(item), tone, context);
  const seed = stableHash(`${item}|${context.period}`);
  return Array.from({ length: 4 }, (_, offset) => {
    const index = (seed + offset * 5) % handles.length;
    return {
      handle: handles[index],
      role: roles[index],
      message: messages[(seed + offset * 7) % messages.length],
      cheers: 12 + ((seed >>> (offset * 3)) % 187),
    };
  });
}

function watchPointFor(item: string, category: CareerNewsCategory) {
  if (item.includes("입학")) return "첫 불펜에서 포수와 호흡을 맞추고 봄 대회에서 맡을 역할";
  if (item.includes("제안") || item.includes("진학")) return "학교별 훈련 방식과 실제로 경쟁해야 할 투수들";
  if (item.includes("드래프트") || item.includes("지명")) return "지명 순번과 입단 뒤 처음 맡게 될 역할";
  if (item.includes("회복") || item.includes("복귀")) return "며칠 연속 훈련한 뒤 통증이 없는지와 복귀전 투구 수";
  const watchPoints: Record<CareerNewsCategory, string> = {
    game: "다음 경기에서도 초구 스트라이크를 잡고 유리한 카운트에서 삼진을 잡아내는지",
    people: "다음 경기에서 감독·포수와 약속한 투구를 지키는지",
    career: "다음 경기나 테스트에서 맡게 될 역할과 경쟁 상대",
    health: "다음 훈련 강도와 등판 뒤 회복 속도",
  };
  return watchPoints[category];
}

function fanSummaryFor(item: string, category: CareerNewsCategory, tone: CareerNewsTone) {
  if (category === "game") {
    if (tone === "positive") return "오늘 투구가 좋았다는 반응이 많다";
    if (tone === "negative") return "다음 등판에서는 달라져야 한다는 반응이 많다";
    return "다음 경기까지 더 지켜보자는 반응이 많다";
  }
  if (category === "career") {
    if (item.includes("입학") || item.includes("제안") || item.includes("진학")) return "학교 선택을 반기며 첫 등판을 기다리고 있다";
    if (tone === "negative") return "다음 진로를 걱정하는 반응이 많다";
    return "새 기회를 반기는 반응이 많다";
  }
  if (category === "health") {
    if (tone === "negative") return "무리하지 말고 충분히 쉬라는 반응이 많다";
    return "복귀는 반갑지만 서두르지 말자는 반응이 많다";
  }
  if (item.includes("포수") || item.includes("배터리") || item.includes("사인")) return "포수와의 호흡을 더 지켜보자는 반응이 많다";
  return "다음 경기에서 실제 변화를 확인하자는 반응이 많다";
}

function leadFor(item: string, category: CareerNewsCategory, tone: CareerNewsTone, context: CareerNewsContext) {
  const player = context.playerName;
  const team = context.affiliation;
  if (item.includes("입학")) return `${withParticle(player, "이", "가")} ${team}에 입학했다. 첫 훈련을 거쳐 봄 대회에서 맡을 역할이 정해진다.`;
  if (item.includes("제안") || item.includes("진학")) return `${player}에게 진학 제안이 도착했다. 학교마다 훈련 방식과 경쟁해야 할 투수가 다르다.`;
  if (item.includes("드래프트") || item.includes("지명")) return `${player}의 지명 결과에 따라 첫 프로 구단과 입단 뒤 맡을 역할이 정해진다.`;
  if (category === "game") {
    if (tone === "positive") return `${withParticle(player, "이", "가")} 좋은 투구를 보여 줬다. 다음 경기에서도 같은 모습을 이어 갈지가 관심사다.`;
    if (tone === "negative") return `${withParticle(player, "이", "가")} 이번 경기에서 흔들렸다. 다음 등판 전 고쳐야 할 부분이 분명해졌다.`;
    return `${player}의 경기 내용에 대한 평가가 엇갈렸다. 다음 등판을 더 지켜봐야 한다.`;
  }
  if (category === "health") return `${player}의 몸 상태가 다음 훈련과 등판 일정에 영향을 주고 있다.`;
  if (category === "people") return `${player}의 훈련 방식과 동료들과의 호흡에 변화가 생겼다. 다음 경기에서 그 결과를 확인할 수 있다.`;
  return `${player}의 다음 팀과 맡을 역할에 영향을 줄 소식이다.`;
}

export function createCareerNewsDetail(item: string, index: number, context: CareerNewsContext): CareerNewsDetail {
  const headline = item.trim().replace(/\.$/, "");
  const category = classifyCareerNews(headline);
  const tone = careerNewsTone(headline);
  const quote = quoteFor(headline, category, tone, context);
  const fanSummary = fanSummaryFor(headline, category, tone);
  return {
    id: `${stableHash(`${headline}|${index}`)}`,
    headline,
    category,
    categoryLabel: CATEGORY_LABELS[category],
    tone,
    source: sourceFor(category, context.mode),
    timeLabel: index === 0 ? "방금 전" : index === 1 ? "이전 소식" : `${index}개 소식 전`,
    lead: leadFor(headline, category, tone, context),
    paragraphs: storyParagraphs(headline, category, tone, context),
    quoteSpeaker: quote.speaker,
    quote: quote.quote,
    watchPoint: watchPointFor(headline, category),
    fanSummary,
    fanPosts: fanPosts(headline, tone, context),
  };
}
