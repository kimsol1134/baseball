import { useEffect, useRef, useState } from "react";
import { AbilityGauge } from "./AbilityGauge";
import { AccessibleModal } from "./AccessibleModal";
import { CareerNewsFeed } from "./CareerNewsFeed";
import { CharacterProfile } from "./CharacterProfile";
import { CoreUnavailableState } from "./CoreUnavailableState";
import { crossedGrowthMilestone, GrowthCelebration } from "./GrowthCelebration";
import catcherRoleScene from "./assets/catcher-role-scene.webp";
import coachRoleScene from "./assets/coach-role-scene.webp";
import rivalRoleScene from "./assets/rival-role-scene.webp";
import { expectedTrainingFatigue, parseAcknowledgedResult, trainingGrowthOutlook } from "./careerTrainingPresentation";
import { hasCompletedSteamDemo } from "./demoGate";
import type {
  AwakeningID,
  CreationAllocationSnapshot,
  CareerDifficultySnapshot,
  CareerEventContent,
  HighSchoolCareerResult,
  MemoryCardID,
  KarmaID,
  PlayerIdentitySnapshot,
  PitcherPresetSnapshot,
  RelationshipResponse,
  SchoolID,
  TrainingFocus,
  TrainingIntensity,
} from "./simulationTypes";

const METRICS: ReadonlyArray<{ key: keyof CreationAllocationSnapshot; label: string }> = [
  { key: "stuff", label: "공의 위력" }, { key: "command", label: "제구" },
  { key: "movement", label: "변화구" }, { key: "stamina", label: "체력" },
];

const PRO_BASEBALL_HOME_CITIES: ReadonlyArray<{ value: string; label: string }> = [
  { value: "서울", label: "서울" },
  { value: "인천", label: "인천" },
  { value: "수원", label: "수원" },
  { value: "대전", label: "대전" },
  { value: "광주", label: "광주" },
  { value: "대구", label: "대구" },
  { value: "부산", label: "부산" },
  { value: "창원", label: "창원" },
];

const OTHER_REGIONS: ReadonlyArray<{ value: string; label: string }> = [
  { value: "울산", label: "울산" },
  { value: "세종", label: "세종" },
  { value: "경기", label: "경기 · 수원 외" },
  { value: "강원", label: "강원" },
  { value: "충북", label: "충북" },
  { value: "충남", label: "충남 · 대전/세종 외" },
  { value: "전북", label: "전북" },
  { value: "전남", label: "전남 · 광주 외" },
  { value: "경북", label: "경북 · 대구 외" },
  { value: "경남", label: "경남 · 부산/울산/창원 외" },
  { value: "제주", label: "제주" },
];

const TRAININGS: ReadonlyArray<{ value: TrainingFocus; label: string; copy: string; gameEffect: string }> = [
  { value: "velocity", label: "직구 구속", copy: "공의 위력이 오를 수 있다", gameEffect: "빠른 직구와 헛스윙에 유리" },
  { value: "command", label: "제구", copy: "원하는 코스에 던지는 능력이 오를 수 있다", gameEffect: "볼넷과 한가운데 실투 감소" },
  { value: "breaking_ball", label: "변화구", copy: "변화구의 움직임이 좋아질 수 있다", gameEffect: "변화구 헛스윙과 빗맞은 타구 증가" },
  { value: "stamina", label: "선발 체력", copy: "긴 이닝을 버티는 체력이 오를 수 있다", gameEffect: "경기 후반 구속·제구 하락 감소" },
  { value: "recovery", label: "휴식과 회복", copy: "피로를 크게 낮추고 체력이 오를 수 있다", gameEffect: "다음 훈련과 등판의 실패 위험 감소" },
  { value: "game_planning", label: "타자 상대법", copy: "카운트에 맞는 구종 선택과 제구가 좋아질 수 있다", gameEffect: "타자의 노림수를 피하기 쉬워짐" },
];

const INTENSITIES: ReadonlyArray<{ value: TrainingIntensity; label: string; copy: string }> = [
  { value: "light", label: "가볍게", copy: "성장 가능성은 낮지만 피로가 적게 쌓임" },
  { value: "standard", label: "보통", copy: "성장 가능성과 피로가 균형을 이룸" },
  { value: "intensive", label: "강하게", copy: "성장 가능성이 높지만 피로가 많이 쌓임" },
];

const TRAINING_METRICS: Record<TrainingFocus, { key: keyof CreationAllocationSnapshot; label: string }> = {
  velocity: { key: "stuff", label: "공의 위력" },
  command: { key: "command", label: "제구" },
  breaking_ball: { key: "movement", label: "변화구" },
  stamina: { key: "stamina", label: "체력" },
  recovery: { key: "stamina", label: "체력" },
  game_planning: { key: "command", label: "제구" },
};

function abilityMeaning(value: number) {
  if (value >= 75) return "세대 최고 수준";
  if (value >= 65) return "프로 최상급";
  if (value >= 55) return "프로 평균 이상";
  if (value >= 50) return "프로 평균";
  if (value >= 45) return "프로 진입 가능";
  if (value >= 40) return "고교 정상급";
  if (value >= 35) return "고교 주전급";
  return "성장 단계";
}

function visibleGaugeRating(value: number, clarity: CareerDifficultySnapshot["informationClarity"]) {
  if (clarity === "relaxed") return value;
  if (clarity === "standard") return Math.floor(value / 5) * 5 + 2;
  return value >= 60 ? 67 : value >= 45 ? 52 : value >= 35 ? 40 : 27;
}

function presetPotential(preset: PitcherPresetSnapshot, key: keyof CreationAllocationSnapshot) {
  const value = preset.pitcher[key];
  const strongest = Math.max(preset.pitcher.stuff, preset.pitcher.command, preset.pitcher.movement, preset.pitcher.stamina);
  return Math.min(65, value + (value === strongest ? 18 : 12));
}

function fourSeamVelocity(pitcher: PitcherPresetSnapshot["pitcher"]) {
  const velocity = pitcher.pitchProfiles?.find((profile) => profile.pitchType === "four_seam")?.velocityTenthsKPH;
  return velocity === undefined ? "측정 전" : `${(velocity / 10).toFixed(1)} km/h`;
}

function fatigueMeaning(value: number) {
  if (value >= 80) return "부상 위험 · 휴식 필요";
  if (value >= 60) return "피로 누적 · 강훈련 주의";
  if (value >= 35) return "훈련 가능";
  return "몸 상태 좋음";
}

function trustMeaning(value: number) {
  if (value >= 75) return "중요 경기에서도 믿음";
  if (value >= 60) return "기회를 늘려 주는 단계";
  if (value >= 45) return "아직 지켜보는 중";
  return "출전 기회가 줄 수 있음";
}

function rivalTrustMeaning(value: number) {
  if (value >= 75) return "서로 인정하는 맞수";
  if (value >= 60) return "경계하는 경쟁자";
  if (value >= 45) return "승부를 지켜보는 중";
  return "도발이 앞서는 관계";
}

function fanInterestMeaning(value: number) {
  if (value >= 75) return "전국에서 주목";
  if (value >= 50) return "지역의 화제";
  if (value >= 25) return "관심이 늘어나는 중";
  return "아직 잘 알려지지 않음";
}

function readAcknowledgedTraining(careerID: string, completedTrainings: number) {
  if (typeof window === "undefined") return 0;
  try { return parseAcknowledgedResult(window.localStorage.getItem(`career-training-result:${careerID}`), completedTrainings); }
  catch { return 0; }
}

function readAcknowledgedRelationship(careerID: string, completedRelationships: number) {
  if (typeof window === "undefined") return 0;
  try { return parseAcknowledgedResult(window.localStorage.getItem(`career-relationship-result:${careerID}`), completedRelationships); }
  catch { return 0; }
}

const RELATIONSHIP_RESPONSE_SUMMARIES: Record<RelationshipResponse, string> = {
  listen: "상대의 설명을 먼저 들었습니다.",
  explain: "내 생각과 근거를 분명히 말했습니다.",
  challenge: "다음 승부로 증명하겠다고 맞섰습니다.",
};

const AWAKENINGS: Record<AwakeningID, string> = {
  explosive_fastball: "폭발하는 포심", pinpoint_edge: "바늘끝 제구",
  disappearing_breaker: "사라지는 변화구", iron_arm: "강철의 어깨",
  calm_under_pressure: "고요한 마운드", battery_sync: "포수와 한마음",
  rising_four_seam: "떠오르는 포심", sinker_tunnel: "같은 길에서 갈라지는 공",
  frozen_changeup: "멈춘 체인지업", sweeping_slider: "스위퍼 궤도",
  curveball_clock: "일정한 커브 타이밍", repeatable_release: "흔들리지 않는 투구 동작",
  pickoff_rhythm: "주자를 묶는 리듬", two_strike_plan: "2스트라이크 승부법",
  first_pitch_strike: "초구 스트라이크", traffic_controller: "주자를 두고도 침착하게",
  late_inning_reserve: "후반에도 남는 힘", scout_composure: "압박 속 침착함",
};

const AWAKENING_DETAILS: Record<AwakeningID, string> = {
  explosive_fastball: "공의 위력 +4 · 제구 -2 · 직구 구속과 헛스윙 증가",
  rising_four_seam: "직구의 위력과 헛스윙 증가 · 변화구 -1",
  pinpoint_edge: "제구 +4 · 공의 위력 -1 · 스트라이크존 끝 제구 향상",
  disappearing_breaker: "변화구 +4 · 제구 -1 · 변화구 헛스윙 증가",
  iron_arm: "체력 +5 · 변화구 -1 · 공마다 쌓이는 피로 감소",
  calm_under_pressure: "제구 +2 · 체력 +1 · 주자가 있을 때 제구 향상",
  battery_sync: "제구 +2 · 변화구 +1 · 빗맞은 타구 증가",
  sinker_tunnel: "변화구 +3 · 직구와 체인지업의 빗맞은 타구 증가",
  frozen_changeup: "체인지업 궤적·헛스윙 상승 · 체력 -1",
  sweeping_slider: "변화구 +4 · 제구 -1 · 슬라이더 헛스윙 증가",
  curveball_clock: "변화구 +4 · 체력 -1 · 커브 헛스윙 증가",
  repeatable_release: "제구 +4 · 공의 위력 -1 · 모든 구종의 제구 향상",
  pickoff_rhythm: "제구 +1 · 체력 +2 · 주자가 있을 때 흔들림 감소",
  two_strike_plan: "제구·변화구 +2 · 체력 -1 · 변화구 헛스윙 증가",
  first_pitch_strike: "제구 +3 · 체력 -1 · 초구 스트라이크 증가",
  traffic_controller: "제구·체력 +2 · 공의 위력 -1 · 빗맞은 타구 증가",
  late_inning_reserve: "체력 +4 · 공마다 쌓이는 피로 감소",
  scout_composure: "공의 위력·제구 +2 · 체력 -1",
};

const MEMORIES: Record<MemoryCardID, string> = {
  velocity_blueprint: "직구 구속 훈련법", fingertip_memory: "손끝의 기억",
  catcher_notebook: "포수의 노트", rival_notebook: "라이벌 노트",
  recovery_routine: "회복 방법", pressure_rehearsal: "압박의 예행연습",
  first_pitch_map: "초구 지도", two_strike_sequence: "2스트라이크 구종 순서",
  fatigue_diary: "피로 일지", mechanics_video: "투구 동작 교정 영상",
  school_playbook: "학교에서 배운 승부법", coach_letter: "코치의 편지",
  draft_report: "구단 평가표", stadium_echo: "구장의 메아리",
  team_first_promise: "팀을 위한 약속", failure_scorebook: "실패의 스코어북",
  winter_program: "겨울 훈련표", bullpen_compass: "불펜의 나침반",
};

const MEMORY_DETAILS: Record<MemoryCardID, string> = {
  velocity_blueprint: "직구 구속·헛스윙 증가, 제구 소폭 감소",
  fingertip_memory: "변화구 움직임 상승, 체력 소폭 감소",
  catcher_notebook: "제구와 빗맞은 타구 유도 증가",
  rival_notebook: "제구·변화구와 변화구 헛스윙 증가",
  recovery_routine: "체력 상승, 공마다 피로 소모 감소",
  pressure_rehearsal: "제구·체력과 위기 상황 제구 향상",
  first_pitch_map: "초구 제구 상승, 체력 소폭 감소",
  two_strike_sequence: "변화구 움직임·헛스윙 상승, 체력 소폭 감소",
  fatigue_diary: "체력과 후반 제구 상승",
  mechanics_video: "제구 향상, 공의 최고 위력 소폭 감소",
  school_playbook: "제구·변화구 향상",
  coach_letter: "제구·체력 향상",
  draft_report: "공의 위력·제구 향상",
  stadium_echo: "공의 위력·헛스윙 증가, 제구 소폭 감소",
  team_first_promise: "제구·체력과 빗맞은 타구 유도 증가",
  failure_scorebook: "제구·변화구 향상, 체력 소폭 감소",
  winter_program: "공의 위력·체력 향상, 피로 누적 감소",
  bullpen_compass: "공의 위력·체력 향상, 피로 누적 감소",
};

const PHASE_LABELS: Record<HighSchoolCareerResult["snapshot"]["phase"], string> = {
  prologue: "중학교 마지막 대회", school_selection: "학교 선택", training: "훈련", relationship: "면담",
  important_game: "중요 경기", awakening: "새 강점", chapter_review: "시즌 마무리", draft: "드래프트", legacy: "남길 기억", completed: "완료",
};

type RelationshipChoiceCard = { id: RelationshipResponse; title: string; copy: string };

function polishedNews(item: string, coachName?: string, catcherName?: string) {
  return item
    .replace(/([가-힣]{2,4}) 감독은/g, coachName ? `${coachName} 감독은` : "$1 감독은")
    .replace(/([가-힣]{2,4}) 포수는/g, catcherName ? `${catcherName} 포수는` : "$1 포수는")
    .replace(/ · ([가-힣]{2,4})와 이야기를 나눴습니다\. /, " · $1 — ")
    .replace(" — 대화를 마쳤습니다. ", " — ")
    .replace("상대의 말을 끝까지 듣고 대화를 마쳤습니다.", "상대가 본 상황을 끝까지 들었습니다.")
    .replace(/^반복해 온 훈련 끝에 ‘(.+)’을 익혔습니다\.$/, "‘$1’을 익혔습니다.");
}

function relationshipScene(event: CareerEventContent, state: HighSchoolCareerResult["snapshot"]): {
  speaker: string;
  quote: string;
  choices: ReadonlyArray<RelationshipChoiceCard>;
} {
  const coach = `${state.school?.coachName ?? "담당"} 감독`;
  const catcher = `${state.school?.catcherName ?? "주전"} 포수`;
  const rival = state.rival.name;

  switch (event.id) {
    case "evt-coach-role": return { speaker: coach, quote: "“다음 대회는 불펜에서 시작한다. 경기 후반을 맡아 줘.”", choices: [
      { id: "listen", title: "불펜으로 옮긴 이유를 묻는다", copy: "감독이 본 약점부터 듣는다" },
      { id: "explain", title: "최근 선발 등판 기록을 꺼내 보인다", copy: "선발로 남고 싶은 이유를 말한다" },
      { id: "challenge", title: "다음 등판으로 선발 자리를 되찾겠다고 한다", copy: "결과로 증명하겠다고 답한다" },
    ] };
    case "evt-coach-bench": return { speaker: coach, quote: "“이번 등판은 쉰다. 요즘은 팔이 몸보다 늦게 따라온다.”", choices: [
      { id: "listen", title: "어느 동작이 늦었는지 묻는다", copy: "감독의 관찰을 자세히 듣는다" },
      { id: "explain", title: "최근 피로 기록을 보여준다", copy: "몸 상태를 숨김없이 설명한다" },
      { id: "challenge", title: "불펜 투구를 보고 결정해 달라고 한다", copy: "오늘 던질 기회를 요청한다" },
    ] };
    case "evt-coach-last-advice": return { speaker: coach, quote: "“마지막 훈련은 네가 정해라. 지금 가장 부족한 게 뭐지?”", choices: [
      { id: "listen", title: "감독이라면 무엇을 고를지 묻는다", copy: "마지막 조언을 먼저 듣는다" },
      { id: "explain", title: "최근 경기에서 흔들린 장면을 짚는다", copy: "고치려는 부분을 설명한다" },
      { id: "challenge", title: "가장 자신 있는 공을 더 다듬겠다고 한다", copy: "강점으로 승부하겠다고 답한다" },
    ] };
    case "evt-catcher-sign": return { speaker: catcher, quote: "“오늘 사인이 세 번이나 바뀌었어. 내가 놓친 게 뭐였어?”", choices: [
      { id: "listen", title: "포수가 본 타자 반응부터 묻는다", copy: "내가 못 본 장면을 확인한다" },
      { id: "explain", title: "사인을 바꾼 이유를 설명한다", copy: "타자가 높은 공을 기다렸다고 말한다" },
      { id: "challenge", title: "다음 타석은 내 순서대로 가 보자고 한다", copy: "내 선택을 시험해 보자고 제안한다" },
    ] };
    case "evt-battery-dinner": return { speaker: catcher, quote: "“솔직히 네 변화구가 어디로 올지 몰라서 겁날 때가 있어.”", choices: [
      { id: "listen", title: "받기 어려웠던 공을 하나씩 묻는다", copy: "포수가 불안했던 지점을 듣는다" },
      { id: "explain", title: "손에서 빠지는 날의 감각을 말한다", copy: "변화구가 흔들린 이유를 설명한다" },
      { id: "challenge", title: "다음 불펜에서 가장 어려운 공만 받아 달라고 한다", copy: "함께 해법을 찾자고 제안한다" },
    ] };
    case "evt-new-catcher": return { speaker: catcher, quote: "“전 학교에서는 이 사인을 썼어. 우리도 다음 경기부터 바꿔 볼래?”", choices: [
      { id: "listen", title: "새 사인의 순서를 끝까지 배운다", copy: "포수가 익숙한 방식을 먼저 확인한다" },
      { id: "explain", title: "기존 사인을 유지하고 싶은 이유를 말한다", copy: "헷갈릴 수 있는 장면을 짚는다" },
      { id: "challenge", title: "불펜에서 두 방식을 모두 시험하자고 한다", copy: "경기 전에 직접 비교한다" },
    ] };
    case "evt-catcher-doubt": return { speaker: catcher, quote: "“요즘 내 사인을 자꾸 거절하잖아. 내가 못 본 게 있어?”", choices: [
      { id: "listen", title: "최근 사인이 좋았던 장면부터 묻는다", copy: "포수의 의도를 다시 듣는다" },
      { id: "explain", title: "거절했던 세 타석의 이유를 설명한다", copy: "내가 본 타자 반응을 말한다" },
      { id: "challenge", title: "다음 경기의 첫 세 타자는 내 순서로 가자고 한다", copy: "내 판단을 결과로 확인하자고 한다" },
    ] };
    case "evt-rival-video": return { speaker: rival, quote: "“높은 포심 타이밍, 이제 맞췄어.” 짧은 타격 영상이 함께 도착했다.", choices: [
      { id: "listen", title: "언제부터 타이밍을 읽었는지 묻는다", copy: "내 반복 습관을 확인한다" },
      { id: "explain", title: "그 공으로 노렸던 것을 솔직히 말한다", copy: "서로의 판단을 맞춰 본다" },
      { id: "challenge", title: "다음에는 같은 높이에서 다른 공을 던지겠다고 한다", copy: "재대결을 약속한다" },
    ] };
    case "evt-rival-final": return { speaker: rival, quote: "타석에 들어선 그가 지난 경기와 같은 코스를 배트 끝으로 가리킨다. “또 여기로 던져 봐.”", choices: [
      { id: "listen", title: "왜 그 코스를 가리켰는지 되묻는다", copy: "상대가 노리는 말을 더 끌어낸다" },
      { id: "explain", title: "지난 공은 실투가 아니었다고 답한다", copy: "그때의 선택을 숨기지 않는다" },
      { id: "challenge", title: "고개를 끄덕이고 승부를 받아들인다", copy: "다음 공으로 답한다" },
    ] };
    default:
      if (event.category === "coach") return { speaker: coach, quote: "“다음 대회는 불펜에서 시작한다. 경기 후반을 맡아 줘.”", choices: [
        { id: "listen", title: "불펜으로 옮긴 이유를 묻는다", copy: "감독이 본 약점부터 듣는다" },
        { id: "explain", title: "최근 선발 등판 기록을 꺼내 보인다", copy: "선발로 남고 싶은 이유를 말한다" },
        { id: "challenge", title: "다음 등판으로 선발 자리를 되찾겠다고 한다", copy: "결과로 증명하겠다고 답한다" },
      ] };
      if (event.category === "catcher") return { speaker: catcher, quote: "“오늘 사인이 세 번이나 바뀌었어. 내가 놓친 게 뭐였어?”", choices: [
        { id: "listen", title: "포수가 본 타자 반응부터 묻는다", copy: "내가 못 본 장면을 확인한다" },
        { id: "explain", title: "사인을 바꾼 이유를 설명한다", copy: "타자가 높은 공을 기다렸다고 말한다" },
        { id: "challenge", title: "다음 타석은 내 순서대로 가 보자고 한다", copy: "내 선택을 시험해 보자고 제안한다" },
      ] };
      return { speaker: rival, quote: "“다음에도 같은 초구를 던질 거야?”", choices: [
        { id: "listen", title: "어떤 습관을 읽었는지 묻는다", copy: "상대의 답을 들어 본다" },
        { id: "explain", title: "그 초구로 노린 것을 말한다", copy: "내 판단을 숨기지 않는다" },
        { id: "challenge", title: "다음 타석에는 다른 답을 주겠다고 한다", copy: "재대결을 약속한다" },
      ] };
  }
}

interface CareerSetupProps {
  presets: ReadonlyArray<PitcherPresetSnapshot>;
  isRunning: boolean;
  error?: string;
  coreMessage: string;
  onRetryCore: () => void;
  onStart: (presetID: string, allocation: CreationAllocationSnapshot, identity: PlayerIdentitySnapshot,
    difficulty: CareerDifficultySnapshot, karmas: ReadonlyArray<KarmaID>) => Promise<void>;
}

export function HighSchoolCareerSetup({ presets, isRunning, error, coreMessage, onRetryCore, onStart }: CareerSetupProps) {
  const [presetID, setPresetID] = useState("");
  const [allocation, setAllocation] = useState<CreationAllocationSnapshot>({ stuff: 2, command: 1, movement: 1, stamina: 1 });
  const [identity, setIdentity] = useState<PlayerIdentitySnapshot>({ name: "민서준", throwingHand: "right", bodyType: "balanced", region: "서울" });
  const [usesRecommendedName, setUsesRecommendedName] = useState(true);
  const [difficulty, setDifficulty] = useState<CareerDifficultySnapshot>({
    careerHarshness: "standard", informationClarity: "standard", simulationDifficulty: "standard", interventionAssist: "standard",
  });
  const [karmas, setKarmas] = useState<ReadonlyArray<KarmaID>>([]);
  const effectivePresetID = presetID || presets[0]?.id || "";
  const selected = presets.find((preset) => preset.id === effectivePresetID);
  const spent = Object.values(allocation).reduce((sum, value) => sum + value, 0);
  useEffect(() => {
    if (usesRecommendedName && selected) setIdentity((current) => ({ ...current, name: selected.pitcher.name }));
  }, [selected, usesRecommendedName]);
  const selectPreset = (preset: PitcherPresetSnapshot) => {
    setPresetID(preset.id);
    if (usesRecommendedName) setIdentity((current) => ({ ...current, name: preset.pitcher.name }));
  };
  const change = (key: keyof CreationAllocationSnapshot, delta: number) => setAllocation((current) => {
    const used = Object.values(current).reduce((sum, value) => sum + value, 0);
    const value = current[key] + delta;
    if (value < 0 || value > 5 || (delta > 0 && used >= 5)) return current;
    return { ...current, [key]: value };
  });
  const toggleKarma = (karma: KarmaID) => setKarmas((current) => current.includes(karma)
    ? current.filter((item) => item !== karma)
    : current.length < 2 ? [...current, karma] : current);

  return (
    <main className="career-setup">
      {presets.length > 0 ? <section className="career-intro">
        <div><p className="eyebrow">고교 커리어</p><h2>중학교의 마지막 공에서 드래프트까지</h2>
          <p>학교를 고르고, 감독과 포수에게 배우고, 라이벌과 다시 만납니다. 능력치는 프로 기준 20–80 평가입니다. 50은 가상 프로리그 1군 평균이며, 고교 1학년은 주로 20–40대에서 시작합니다.</p></div>
      </section> : null}
      {presets.length > 0 ? <section className="preset-creation-grid">
        {presets.map((preset) => <button key={preset.id} type="button" aria-pressed={preset.id === effectivePresetID}
          className={preset.id === effectivePresetID ? "is-selected" : undefined} onClick={() => selectPreset(preset)}>
          <span>{preset.name}</span><strong>{preset.pitcher.name}</strong><p>{preset.tagline}</p><small>{preset.tradeoff}</small>
          <dl className="ds-scoreboard preset-statline" aria-label={`${preset.name} 기본 능력: ${METRICS.map((metric) => `${metric.label} ${preset.pitcher[metric.key]}`).join(", ")}`}>
            {METRICS.map((metric) => <div key={metric.key}><dt>{metric.label}</dt><dd>{preset.pitcher[metric.key]}</dd>
              <AbilityGauge compact label={metric.label} value={preset.pitcher[metric.key]}
                lowerBound={preset.pitcher[metric.key] + 2} upperBound={presetPotential(preset, metric.key)} />
              <small>성장 기대 {preset.pitcher[metric.key] + 2}–{presetPotential(preset, metric.key)}</small></div>)}
          </dl>
          <small className="preset-velocity">포심 기준 구속 {fourSeamVelocity(preset.pitcher)}</small>
        </button>)}
      </section> : null}
      {presets.length === 0 ? <CoreUnavailableState message={error ?? coreMessage} isChecking={isRunning} onRetry={onRetryCore} /> : null}
      {selected ? <section className="creation-allocation career-allocation">
        <div className="creation-summary"><div><span>투수 유형</span><strong>{selected.name}</strong><p>선수마다 강점과 약점이 다릅니다. 추가 능력 5점은 어느 유형을 골라도 같습니다.</p></div>
          <div className="creation-points"><span>남은 능력치 점수</span><strong>{5 - spent}</strong></div></div>
        <div className="allocation-grid">{METRICS.map((metric) => {
          const finalRating = selected.pitcher[metric.key] + allocation[metric.key];
          const potential = Math.max(finalRating + 2, presetPotential(selected, metric.key));
          return <div key={metric.key}><span>{metric.label}</span><small>기본 {selected.pitcher[metric.key]} · 추가 +{allocation[metric.key]}</small><div>
          <button type="button" aria-label={`${metric.label} 1 감소`} disabled={allocation[metric.key] === 0} onClick={() => change(metric.key, -1)}>−</button>
          <strong aria-label={`${metric.label} 최종 ${selected.pitcher[metric.key] + allocation[metric.key]}`}>
            {selected.pitcher[metric.key] + allocation[metric.key]}<small>+{allocation[metric.key]}</small>
          </strong><button type="button" aria-label={`${metric.label} 1 증가`} disabled={spent >= 5 || allocation[metric.key] === 5} onClick={() => change(metric.key, 1)}>+</button>
        </div><AbilityGauge compact label={`${metric.label} 최종`} value={finalRating}
          lowerBound={finalRating + 2} upperBound={potential} /><small>현재 {finalRating} · 성장 기대 {finalRating + 2}–{potential}</small></div>;
        })}</div>
        <div className="identity-grid"><label className="identity-name-field"><span>선수 이름</span><div><input value={identity.name} maxLength={12} autoComplete="off"
          onChange={(event) => { setIdentity({ ...identity, name: event.target.value }); setUsesRecommendedName(false); }} />
          <button type="button" disabled={usesRecommendedName && identity.name === selected.pitcher.name}
            onClick={() => { setIdentity({ ...identity, name: selected.pitcher.name }); setUsesRecommendedName(true); }}>추천 이름 사용</button></div>
          <small>추천 이름을 그대로 쓰거나 직접 입력하세요.</small></label>
          <label><span>출신 지역</span><select value={identity.region} aria-label="출신 지역"
            onChange={(event) => setIdentity({ ...identity, region: event.target.value })}>
            <optgroup label="프로야구 연고 도시">
              {PRO_BASEBALL_HOME_CITIES.map((region) => <option key={region.value} value={region.value}>{region.label}</option>)}
            </optgroup>
            <optgroup label="그 외 지역">
              {OTHER_REGIONS.map((region) => <option key={region.value} value={region.value}>{region.label}</option>)}
            </optgroup>
          </select></label>
          <label><span>투구 손</span><select value={identity.throwingHand} onChange={(event) => setIdentity({ ...identity, throwingHand: event.target.value as PlayerIdentitySnapshot["throwingHand"] })}>
            <option value="right">우투</option><option value="left">좌투</option></select></label>
          <label><span>체격</span><select value={identity.bodyType} onChange={(event) => setIdentity({ ...identity, bodyType: event.target.value as PlayerIdentitySnapshot["bodyType"] })}>
            <option value="compact">다부진 체격</option><option value="balanced">균형 체격</option><option value="tall">장신 체격</option></select></label></div>
        <div className="difficulty-panel"><div><span>난이도 세부 설정</span><small>경기 난이도와 정보 공개량을 따로 고를 수 있습니다.</small></div><div className="difficulty-grid">
          {([{"key":"careerHarshness","label":"지명 기준"},{"key":"informationClarity","label":"능력 공개"},{"key":"simulationDifficulty","label":"상대 타자"},{"key":"interventionAssist","label":"포수 추천"}] as const).map((axis) =>
            <label key={axis.key}><span>{axis.label}</span><select value={difficulty[axis.key]} onChange={(event) => setDifficulty({ ...difficulty, [axis.key]: event.target.value })}>
              <option value={axis.key === "interventionAssist" ? "full" : "relaxed"}>{axis.key === "interventionAssist" ? "힌트 많음" : "낮음"}</option>
              <option value="standard">보통</option><option value={axis.key === "interventionAssist" ? "minimal" : "challenging"}>{axis.key === "interventionAssist" ? "힌트 최소" : "높음"}</option>
            </select></label>)}</div></div>
        <div className="karma-panel"><div><span>더 어렵게 시작하기 · 최대 2개</span><small>불리한 조건을 고르면 다음 삶에 가져갈 보상이 늘어납니다.</small></div><div className="karma-grid">
          {([{"id":"unknown_land","title":"무명의 땅","copy":"스카우트가 보러 오는 경기 감소 · 다음 삶 보상 +15%"},{"id":"stubborn_coach","title":"완고한 감독","copy":"감독과 부딪히면 믿음이 더 많이 감소 · 다음 삶 보상 +15%"},
            {"id":"single_weapon","title":"한 가지 무기","copy":"가장 높은 능력은 오르고 나머지는 낮아짐 · 다음 삶 보상 +20%"},{"id":"genius_generation","title":"천재의 세대","copy":"라이벌이 더 강해짐 · 다음 삶 보상 +25%"},
            {"id":"erased_memory","title":"지워진 기억","copy":"다음 삶에 남길 기억 2장 · 다음 삶 보상 +25%"},{"id":"no_last_chance","title":"마지막 기회 없음","copy":"낮은 평가로도 지명될 가능성이 줄어듦 · 다음 삶 보상 +35%"}] as const).map((karma) =>
            <button key={karma.id} type="button" className={karmas.includes(karma.id) ? "is-selected" : undefined} aria-pressed={karmas.includes(karma.id)} onClick={() => toggleKarma(karma.id)}>
              <strong>{karma.title}</strong><span>{karma.copy}</span></button>)}</div></div>
        <button className="ds-button ds-button--primary lab-primary" type="button" disabled={isRunning || spent !== 5 || !identity.name.trim()}
          onClick={() => void onStart(selected.id, allocation, { ...identity, name: identity.name.trim() }, difficulty, karmas)}>
          {isRunning ? "선수 생성 중…" : "고교 커리어 시작"}
        </button>{error ? <p className="error-message" role="alert">{error}</p> : null}
      </section> : null}
    </main>
  );
}

interface CareerViewProps {
  result: HighSchoolCareerResult;
  isRunning: boolean;
  error?: string;
  onSchool: (schoolID: SchoolID) => Promise<void>;
  onCompletePrologue: () => Promise<void>;
  onTraining: (focus: TrainingFocus, intensity: TrainingIntensity) => Promise<void>;
  onRelationship: (response: RelationshipResponse) => Promise<void>;
  onImportantGame: () => Promise<void>;
  onAwakening: (awakening: AwakeningID) => Promise<void>;
  onAdvanceChapter: () => Promise<void>;
  onDraft: () => Promise<void>;
  onLegacy: (memories: ReadonlyArray<MemoryCardID>) => Promise<void>;
  onNextLife: () => Promise<void>;
  onNewCareer: () => void;
  showTutorial: boolean;
  onDismissTutorial: () => void;
  onStartPro: () => Promise<void>;
  proAccessAvailable: boolean;
  demoMode: boolean;
  onMilestoneFeedback: (cue?: "progress" | "growth" | "milestone") => void;
}

export function HighSchoolCareerView({ result, isRunning, error, onSchool, onTraining, onRelationship,
  onCompletePrologue, onImportantGame, onAwakening, onAdvanceChapter, onDraft, onLegacy, onNextLife, onNewCareer,
  showTutorial, onDismissTutorial, onStartPro, proAccessAvailable, demoMode, onMilestoneFeedback }: CareerViewProps) {
  const state = result.snapshot;
  const currentFourSeamVelocity = fourSeamVelocity(state.pitcher);
  const demoComplete = hasCompletedSteamDemo(demoMode, state.performance.importantGamesCompleted);
  const [focus, setFocus] = useState<TrainingFocus>(() => state.school?.strength ?? "command");
  const [intensity, setIntensity] = useState<TrainingIntensity>("standard");
  const [memories, setMemories] = useState<ReadonlyArray<MemoryCardID>>([]);
  const [draftRevealStage, setDraftRevealStage] = useState<number | null>(null);
  const [draftRevealDone, setDraftRevealDone] = useState(false);
  const [acknowledgedTraining, setAcknowledgedTraining] = useState(() => readAcknowledgedTraining(state.careerID, state.totalTrainingsCompleted));
  const [acknowledgedRelationship, setAcknowledgedRelationship] = useState(() => readAcknowledgedRelationship(state.careerID, state.relationshipsCompleted));
  const decisionResultRef = useRef<HTMLDivElement>(null);
  const announcedResultRef = useRef("");
  useEffect(() => {
    if (draftRevealStage === null || !state.draftResult || draftRevealStage >= 4) return;
    const delay = document.body.classList.contains("reduce-motion") ? 80 : 850;
    const timer = window.setTimeout(() => setDraftRevealStage((current) => current === null ? null : Math.min(4, current + 1)), delay);
    return () => window.clearTimeout(timer);
  }, [draftRevealStage, state.draftResult]);
  useEffect(() => {
    if (draftRevealStage === 3 && state.draftResult) onMilestoneFeedback();
  }, [draftRevealStage, onMilestoneFeedback, state.draftResult]);
  useEffect(() => {
    setAcknowledgedTraining(readAcknowledgedTraining(state.careerID, state.totalTrainingsCompleted));
    setAcknowledgedRelationship(readAcknowledgedRelationship(state.careerID, state.relationshipsCompleted));
    announcedResultRef.current = "";
  }, [state.careerID]);
  useEffect(() => {
    if (state.phase === "training" && state.chapterTrainingCount === 0 && state.school?.strength) {
      setFocus(state.school.strength);
    }
  }, [state.chapter.number, state.chapterTrainingCount, state.phase, state.school?.strength]);
  const startDraftReveal = async () => {
    setDraftRevealDone(false);
    setDraftRevealStage(0);
    await onDraft();
  };
  const toggleMemory = (memory: MemoryCardID) => setMemories((current) => current.includes(memory)
    ? current.filter((item) => item !== memory)
    : current.length < state.memorySlots ? [...current, memory] : current);
  const rating = (value: number) => state.difficulty.informationClarity === "relaxed" ? String(value)
    : state.difficulty.informationClarity === "standard" ? `${Math.floor(value / 5) * 5}–${Math.floor(value / 5) * 5 + 4}`
      : value >= 65 ? "상" : value >= 50 ? "중" : "하";
  const showHints = state.difficulty.interventionAssist !== "minimal";
  const managerTrust = state.managerTrust ?? state.relationshipTrust;
  const catcherTrust = state.catcherTrust ?? state.relationshipTrust;
  const rivalTrust = state.rivalTrust ?? state.relationshipTrust;
  const pendingTraining = state.lastTraining && state.lastTraining.number > acknowledgedTraining ? state.lastTraining : undefined;
  const pendingRelationship = !pendingTraining && state.lastRelationship && state.lastRelationship.number > acknowledgedRelationship
    ? state.lastRelationship : undefined;
  const hasPendingResult = Boolean(pendingTraining || pendingRelationship);
  const resultMetric = pendingTraining ? TRAINING_METRICS[pendingTraining.focus] : undefined;
  const resultAfter = pendingTraining && resultMetric
    ? pendingTraining.metricAfter ?? state.pitcher[resultMetric.key]
    : 0;
  const resultBefore = pendingTraining?.metricBefore;
  const resultCelebrationBefore = pendingTraining
    ? resultBefore ?? Math.max(20, resultAfter - pendingTraining.growth)
    : resultAfter;
  const resultFatigueAfter = pendingTraining ? pendingTraining.fatigueAfter ?? state.fatigue : state.fatigue;
  const resultFatigueBefore = pendingTraining ? pendingTraining.fatigueBefore ?? resultFatigueAfter - pendingTraining.fatigueChange : state.fatigue;
  const relationshipAbilityMetric = pendingRelationship?.growthFocus ? TRAINING_METRICS[pendingRelationship.growthFocus] : undefined;
  const relationshipPerson = pendingRelationship?.category === "coach" ? `${state.school?.coachName ?? "감독"} 감독`
    : pendingRelationship?.category === "catcher" ? `${state.school?.catcherName ?? "포수"} 포수` : state.rival.name;
  const relationshipTrustLabel = pendingRelationship?.category === "coach" ? "감독의 믿음"
    : pendingRelationship?.category === "catcher" ? "포수의 믿음" : "라이벌의 인정";
  const selectedTraining = TRAININGS.find((option) => option.value === focus) ?? TRAININGS[0];
  const selectedIntensity = INTENSITIES.find((option) => option.value === intensity) ?? INTENSITIES[1];
  const expectedFatigue = expectedTrainingFatigue(state.fatigue, focus, intensity);
  const trainingBase = intensity === "light" ? 130 : intensity === "standard" ? 210 : 280;
  const schoolBonus = state.school?.strength === focus ? 110 : 0;
  const fatiguePenalty = Math.max(0, state.fatigue - 45) * 3;
  const growthScore = trainingBase + schoolBonus - fatiguePenalty;
  const growthOutlook = trainingGrowthOutlook(growthScore);
  const relationship = state.currentRelationshipEvent ?? (state.relationshipsCompleted % 3 === 0
    ? { id: "fallback-coach", category: "coach", title: "선발인가 불펜인가", summary: "감독이 다음 대회는 불펜에서 시작하겠다고 말합니다." }
    : state.relationshipsCompleted % 3 === 1
      ? { id: "fallback-catcher", category: "catcher", title: "엇갈린 사인", summary: "경기 중 세 번 사인이 엇갈렸고 포수가 이유를 묻습니다." }
      : { id: "fallback-rival", category: "rival", title: "라이벌의 메시지", summary: "라이벌이 ‘다음에도 같은 초구를 던질 거냐’고 메시지를 보냈습니다." });
  const resultFeedback = pendingTraining && resultMetric && pendingTraining.metricBefore === undefined
    ? pendingTraining.growth > 0
      ? `${resultMetric.label}이 ${pendingTraining.growth} 올랐습니다.`
      : pendingTraining.focus === "recovery" && pendingTraining.fatigueChange < 0
        ? `능력치는 그대로지만 피로가 ${-pendingTraining.fatigueChange} 줄었습니다.`
        : "이번 훈련에서는 능력치가 오르지 않았습니다. 피로와 훈련 강도를 조절해 다음 훈련을 준비하세요."
    : pendingTraining?.feedback ?? "";
  const nextActionLabel = state.phase === "training" ? "다음 훈련 고르기"
    : state.phase === "relationship" && relationship.category === "coach" ? `${state.school?.coachName ?? "감독"} 감독과 대화하기`
      : state.phase === "relationship" && relationship.category === "catcher" ? `${state.school?.catcherName ?? "포수"} 포수와 대화하기`
        : state.phase === "relationship" ? `${state.rival.name}의 메시지 확인`
      : state.phase === "important_game" ? "중요 경기 확인"
        : state.phase === "awakening" ? "새 강점 확인"
          : state.phase === "chapter_review" ? "시즌 마무리 확인" : "다음 일정 확인";
  useEffect(() => {
    if (!hasPendingResult) return;
    const resultKey = pendingTraining ? `training:${pendingTraining.number}` : `relationship:${pendingRelationship?.number}`;
    if (announcedResultRef.current === resultKey) return;
    announcedResultRef.current = resultKey;
    const before = pendingTraining?.metricBefore ?? pendingRelationship?.abilityBefore;
    const after = pendingTraining?.metricAfter ?? pendingRelationship?.abilityAfter;
    onMilestoneFeedback(before !== undefined && after !== undefined && crossedGrowthMilestone(before, after) ? "growth" : "progress");
    const frame = window.requestAnimationFrame(() => {
      decisionResultRef.current?.focus();
      decisionResultRef.current?.scrollIntoView({ behavior: document.body.classList.contains("reduce-motion") ? "auto" : "smooth", block: "center" });
    });
    return () => window.cancelAnimationFrame(frame);
  }, [hasPendingResult, onMilestoneFeedback, pendingRelationship?.number, pendingTraining?.number]);
  const acknowledgeTraining = () => {
    if (!pendingTraining) return;
    try { window.localStorage.setItem(`career-training-result:${state.careerID}`, String(pendingTraining.number)); } catch { /* 저장이 막혀도 현재 화면에서는 진행 */ }
    setAcknowledgedTraining(pendingTraining.number);
  };
  const acknowledgeRelationship = () => {
    if (!pendingRelationship) return;
    try { window.localStorage.setItem(`career-relationship-result:${state.careerID}`, String(pendingRelationship.number)); } catch { /* 저장이 막혀도 현재 화면에서는 진행 */ }
    setAcknowledgedRelationship(pendingRelationship.number);
  };
  const scene = relationshipScene(relationship, state);
  const relationshipArt = relationship.category === "coach" ? coachRoleScene : relationship.category === "catcher" ? catcherRoleScene : rivalRoleScene;
  const reveal = (() => {
    const draft = state.draftResult;
    if (draftRevealStage === 0 || !draft) return { label: "지명 후보 명단", title: "10개 구단이 최종 명단을 닫았습니다.", copy: "경기 기록, 현재 구종, 감독과 포수의 평가가 최종 지명 후보표에 올라갑니다." };
    if (draftRevealStage === 1) return draft.outcome === "drafted" && draft.round === 1
      ? { label: "1라운드", title: "구단 테이블에서 전화가 연결됩니다.", copy: `${draft.team?.name ?? "한 구단"}이 첫 선택을 준비합니다.` }
      : { label: "1라운드", title: "1라운드가 끝났습니다.", copy: "아직 이름은 불리지 않았습니다. 다음 라운드 명단이 올라옵니다." };
    if (draftRevealStage === 2) return draft.outcome === "drafted" && (draft.round ?? 9) <= 3
      ? { label: "2–3라운드", title: `${draft.team?.name ?? "구단"}에서 전화가 왔습니다.`, copy: "지명 순번이 확정되는 동안 구단 발표를 기다립니다." }
      : { label: "2–3라운드", title: "3라운드까지 이름은 불리지 않았습니다.", copy: "남은 구단들이 마지막 지명 후보를 다시 확인합니다." };
    if (draftRevealStage === 3) return draft.outcome === "drafted"
      ? { label: "지명 전화", title: `${draft.team?.name ?? "프로 구단"} · ${draft.round}라운드 ${draft.overallPick}순위`, copy: `${state.pitcher.name}의 프로 지명이 확정됐습니다.` }
      : { label: "최종 라운드", title: "마지막 순번이 지나갔습니다.", copy: "이번 드래프트에서는 이름이 불리지 않았습니다." };
    return { label: draft.outcome === "drafted" ? "구단 평가" : "다음 기록", title: draft.outcome === "drafted" ? `구단 평가 점수 ${draft.evaluationScore} · 예상 ${draft.projectedRange}` : `구단 평가 점수 ${draft.evaluationScore}`, copy: draft.summary };
  })();

  return <main className="career-shell stage-layout" data-stage={state.phase} data-school={state.school?.id} data-team={state.draftResult?.team?.id}>
    {showTutorial ? <AccessibleModal className="tutorial-panel" labelledBy="tutorial-title" onEscape={onDismissTutorial}>
      <div><p className="eyebrow">빠른 안내</p><h2 id="tutorial-title">고교 커리어 시작 전</h2></div>
      <ol><li><strong>현재 능력</strong><span>선수 카드에서 공의 위력·제구·변화구·체력을 확인합니다.</span></li><li><strong>중요 경기</strong><span>승부처에서는 구종·코스·강도를 직접 선택합니다.</span></li>
        <li><strong>선택 확정</strong><span>확정한 훈련과 사건 선택은 되돌릴 수 없습니다.</span></li><li><strong>자동 저장</strong><span>확정한 선택마다 이 기기에 저장됩니다.</span></li></ol>
      <button className="ds-button ds-button--primary lab-primary" type="button" onClick={onDismissTutorial}>커리어 시작</button>
    </AccessibleModal> : null}
    <section className="career-hero">
      <div><p className="eyebrow">{state.lifeNumber}번째 선수 · {state.chapter.schoolYear}학년 {state.chapter.season}</p>
        <h2>{state.chapter.number}장 · {state.chapter.title}</h2><p>{state.chapter.theme}</p></div>
      <div className="career-vitals"><div><span>피로</span><strong>{state.fatigue}</strong><small>{fatigueMeaning(state.fatigue)}</small></div>
        <div><span>감독의 믿음</span><strong>{managerTrust}</strong><small>{trustMeaning(managerTrust)}</small></div>
        <div><span>포수의 믿음</span><strong>{catcherTrust}</strong><small>{trustMeaning(catcherTrust)}</small></div>
        <div><span>라이벌의 인정</span><strong>{rivalTrust}</strong><small>{rivalTrustMeaning(rivalTrust)}</small></div>
        <div><span>지역 팬 관심</span><strong>{state.fanInterest}</strong><small>{fanInterestMeaning(state.fanInterest)}</small></div>
        <button type="button" onClick={onNewCareer}>새 커리어</button></div>
    </section>
    <section className="chapter-map" aria-label="8개 고교 시즌">{Array.from({ length: 8 }, (_, index) => index + 1).map((chapter) =>
      <div key={chapter} className={chapter === state.chapter.number ? "is-current" : chapter < state.chapter.number ? "is-complete" : undefined}>
        <span>{chapter}</span><small>{chapter < state.chapter.number ? "완료" : chapter === state.chapter.number ? "진행 중" : "잠김"}</small></div>)}</section>
    <a className="mobile-action-jump" href="#career-current-action"><span>현재 단계</span><strong>{hasPendingResult ? "결과를 확인하세요" : nextActionLabel}</strong><small>바로 이동</small></a>
    <div className="career-grid">
      <section className="ds-card ds-player-card career-panel career-player"><div className="lab-card-heading"><span>{state.pitcher.name}</span><small>{state.school?.name ?? "학교 선택 전"}</small></div>
        <div className="ds-record-grid career-rating-grid">{METRICS.map((metric) => {
          const value = state.pitcher[metric.key];
          const displayed = rating(value);
          return <div key={metric.key}><div className="career-rating-summary"><span>{metric.label}</span><strong>{displayed}</strong></div>
            <AbilityGauge label={metric.label} value={visibleGaugeRating(value, state.difficulty.informationClarity)} displayValue={displayed} />
            <small>{abilityMeaning(value)}{metric.key === "stuff" ? ` · 포심 기준 ${currentFourSeamVelocity}` : ""}</small></div>;
        })}</div>
        <small className="information-clarity">{state.difficulty.informationClarity === "relaxed" ? "정확한 숫자" : state.difficulty.informationClarity === "standard" ? "구단이 예상한 5점 범위" : "상·중·하만 표시"} · 프로 기준 20–80 · 40 고교 정상급 · 50 프로 평균 · 65 프로 최상급</small>
        {state.school ? <div className="career-personnel">
          <CharacterProfile label="감독" title={`${state.school.coachName} · ${state.school.coachArchetype}`} record={state.school.coachRecord} description={state.school.coachPersonality} />
          <CharacterProfile label="포수" title={`${state.school.catcherName} · ${state.school.catcherArchetype}`} record={state.school.catcherRecord} description={state.school.catcherPersonality} />
          <CharacterProfile label="라이벌" title={`${state.rival.name} · ${state.rival.archetype}`} record={state.rival.signatureRecord} description={state.rival.personality} />
        </div> : null}
        <div className="career-counters"><span>훈련 {state.totalTrainingsCompleted}/16</span><span>경기 {state.performance.importantGamesCompleted}/5</span>
          <span>대화 {state.relationshipsCompleted}/5</span><span>새 강점 {state.selectedAwakenings.length}/3</span></div>
      </section>

      <section id="career-current-action" className="ds-card ds-card--raised career-panel career-decision"><div className="lab-card-heading"><span>{pendingTraining ? "훈련 완료" : pendingRelationship ? "대화 완료" : "지금 할 일"}</span><small>{hasPendingResult ? "결과 확인" : PHASE_LABELS[state.phase]}</small></div>
        {demoComplete ? <div className="career-milestone demo-complete"><span>데모 기록 완료</span>
          <h3>첫 중요 경기를 마쳤습니다.</h3>
          <p>{state.pitcher.name}은 공의 위력 {rating(state.pitcher.stuff)}, 제구 {rating(state.pitcher.command)}로 첫 기록을 남겼습니다. 이 저장은 정식판에서 그대로 이어집니다.</p>
          <div className="demo-summary"><div><strong>{state.performance.pitches}</strong><span>투구</span></div><div><strong>{state.performance.strikeouts}</strong><span>삼진</span></div><div><strong>{managerTrust}</strong><span>감독의 믿음</span></div><div><strong>{catcherTrust}</strong><span>포수의 믿음</span></div></div>
          <p className="demo-next">정식판에서는 남은 고교 생활, 드래프트, 프로 입단과 은퇴까지 이어집니다.</p>
          <button className="ds-button ds-button--primary lab-primary" type="button" onClick={onNewCareer}>새 선수로 다시 해보기</button>
        </div> : null}
        {!demoComplete ? <>
        {pendingTraining && resultMetric ? <div ref={decisionResultRef} className={`ds-card ds-card--result training-result-card ${pendingTraining.growth > 0 ? "ds-card--positive is-growth" : "is-steady"}`} tabIndex={-1} role="region" aria-live="polite" aria-labelledby="training-result-heading">
          <div className="training-result-title"><span>훈련 {pendingTraining.number}회차 완료</span><h3 id="training-result-heading">{TRAININGS.find((option) => option.value === pendingTraining.focus)?.label ?? resultMetric.label} 결과</h3></div>
          <GrowthCelebration label={resultMetric.label} before={resultCelebrationBefore} after={resultAfter} />
          <div className="ds-record-grid training-result-scoreboard">
            <div><span>{resultMetric.label}</span><strong>{resultBefore === undefined ? <>현재 {resultAfter}</> : <>{resultBefore} <i aria-hidden="true">→</i> {resultAfter}</>}</strong>
              <AbilityGauge label={resultMetric.label} value={resultAfter} beforeValue={resultBefore} />
              <small className={pendingTraining.growth > 0 ? "is-positive" : "is-neutral"}>{pendingTraining.growth > 0 ? `+${pendingTraining.growth} 성장` : "이번에는 그대로"}</small></div>
            <div><span>피로</span><strong>{resultFatigueBefore} <i aria-hidden="true">→</i> {resultFatigueAfter}</strong><small className={pendingTraining.fatigueChange < 0 ? "is-positive" : pendingTraining.fatigueChange > 0 ? "is-warning" : "is-neutral"}>{pendingTraining.fatigueChange > 0 ? `+${pendingTraining.fatigueChange} 쌓임` : pendingTraining.fatigueChange < 0 ? `${-pendingTraining.fatigueChange} 회복` : "변화 없음"}</small></div>
          </div>
          <p>{resultFeedback}</p>
          <div className="training-result-next"><span>다음 일정</span><strong>{nextActionLabel}</strong><small>아래 버튼을 누르기 전에는 다음 선택으로 넘어가지 않습니다.</small></div>
          <button className="ds-button ds-button--primary lab-primary" type="button" onClick={acknowledgeTraining}>{nextActionLabel}</button>
        </div> : null}
        {pendingRelationship ? <div ref={decisionResultRef} className="ds-card ds-card--result training-result-card relationship-result-card" tabIndex={-1} role="region" aria-live="polite" aria-labelledby="relationship-result-heading">
          <div className="training-result-title"><span>대화 {pendingRelationship.number}회차 완료 · {relationshipPerson}</span><h3 id="relationship-result-heading">{pendingRelationship.title} 결과</h3></div>
          {relationshipAbilityMetric && pendingRelationship.abilityBefore !== undefined && pendingRelationship.abilityAfter !== undefined
            ? <GrowthCelebration label={relationshipAbilityMetric.label} before={pendingRelationship.abilityBefore} after={pendingRelationship.abilityAfter} /> : null}
          <p className="relationship-choice-summary">{RELATIONSHIP_RESPONSE_SUMMARIES[pendingRelationship.response]}</p>
          <div className="ds-record-grid training-result-scoreboard">
            <div><span>{relationshipTrustLabel}</span><strong>{pendingRelationship.trustBefore} <i aria-hidden="true">→</i> {pendingRelationship.trustAfter}</strong><small className={pendingRelationship.trustAfter > pendingRelationship.trustBefore ? "is-positive" : pendingRelationship.trustAfter < pendingRelationship.trustBefore ? "is-negative" : "is-neutral"}>{pendingRelationship.trustAfter === pendingRelationship.trustBefore ? "변화 없음" : `${pendingRelationship.trustAfter > pendingRelationship.trustBefore ? "+" : ""}${pendingRelationship.trustAfter - pendingRelationship.trustBefore}`}</small></div>
            <div><span>지역 팬 관심</span><strong>{pendingRelationship.fanInterestBefore} <i aria-hidden="true">→</i> {pendingRelationship.fanInterestAfter}</strong><small className={pendingRelationship.fanInterestAfter > pendingRelationship.fanInterestBefore ? "is-positive" : pendingRelationship.fanInterestAfter < pendingRelationship.fanInterestBefore ? "is-negative" : "is-neutral"}>{pendingRelationship.fanInterestAfter === pendingRelationship.fanInterestBefore ? "변화 없음" : `${pendingRelationship.fanInterestAfter > pendingRelationship.fanInterestBefore ? "+" : ""}${pendingRelationship.fanInterestAfter - pendingRelationship.fanInterestBefore}`}</small></div>
            <div><span>피로</span><strong>{pendingRelationship.fatigueBefore} <i aria-hidden="true">→</i> {pendingRelationship.fatigueAfter}</strong><small className={pendingRelationship.fatigueAfter < pendingRelationship.fatigueBefore ? "is-positive" : pendingRelationship.fatigueAfter > pendingRelationship.fatigueBefore ? "is-negative" : "is-neutral"}>{pendingRelationship.fatigueAfter === pendingRelationship.fatigueBefore ? "변화 없음" : pendingRelationship.fatigueAfter > pendingRelationship.fatigueBefore ? `+${pendingRelationship.fatigueAfter - pendingRelationship.fatigueBefore} 쌓임` : `${pendingRelationship.fatigueBefore - pendingRelationship.fatigueAfter} 회복`}</small></div>
            {relationshipAbilityMetric && pendingRelationship.abilityBefore !== undefined && pendingRelationship.abilityAfter !== undefined ? <div><span>{relationshipAbilityMetric.label}</span><strong>{pendingRelationship.abilityBefore} <i aria-hidden="true">→</i> {pendingRelationship.abilityAfter}</strong>
              <AbilityGauge label={relationshipAbilityMetric.label} value={pendingRelationship.abilityAfter} beforeValue={pendingRelationship.abilityBefore} />
              <small className={pendingRelationship.abilityAfter > pendingRelationship.abilityBefore ? "is-positive" : "is-neutral"}>{pendingRelationship.abilityAfter > pendingRelationship.abilityBefore ? `+${pendingRelationship.abilityAfter - pendingRelationship.abilityBefore} 성장` : "변화 없음"}</small></div> : null}
          </div>
          <p>{pendingRelationship.feedback}</p>
          <div className="training-result-next"><span>다음 일정</span><strong>{nextActionLabel}</strong><small>결과를 확인한 뒤 다음 일정으로 넘어갑니다.</small></div>
          <button className="ds-button ds-button--primary lab-primary" type="button" onClick={acknowledgeRelationship}>{nextActionLabel}</button>
        </div> : null}
        {!hasPendingResult && draftRevealStage !== null && !draftRevealDone ? <AccessibleModal className={`draft-reveal draft-reveal--stage-${draftRevealStage}`} live="polite" label="드래프트 결과 공개"
          onEscape={() => draftRevealStage >= 4 ? setDraftRevealDone(true) : setDraftRevealStage(4)}>
          <span>{reveal.label}</span><div className="draft-rounds" aria-hidden="true">{[0, 1, 2, 3, 4].map((step) => <i key={step} className={step <= draftRevealStage ? "is-active" : undefined} />)}</div>
          <h3>{reveal.title}</h3><p>{reveal.copy}</p>
          {draftRevealStage >= 4 ? <button className="ds-button ds-button--primary lab-primary" type="button" onClick={() => setDraftRevealDone(true)}>결과 화면 확인</button>
            : <button className="draft-skip" type="button" onClick={() => setDraftRevealStage(4)}>바로 결과 보기</button>}
        </AccessibleModal> : null}
        {!hasPendingResult && state.phase === "prologue" ? <div className="career-milestone prologue-card"><span>중학교 마지막 경기</span>
          <h3>{state.identity.region}의 마지막 중학교 대회</h3><p>{state.identity.name} · {state.identity.throwingHand === "right" ? "우투" : "좌투"} · {state.identity.bodyType === "tall" ? "장신" : state.identity.bodyType === "compact" ? "다부진" : "균형"} 체격. 경기를 마치고 나오자 {state.identity.region} 지역 네 고교에서 진학 제안이 도착했습니다. {state.karmas.length > 0 ? `더 어렵게 시작하는 조건 ${state.karmas.length}개 적용` : "추가 난이도 조건 없음"}</p>
          <button className="ds-button ds-button--primary lab-primary" type="button" disabled={isRunning} onClick={() => void onCompletePrologue()}>고교 진학 제안 확인</button></div> : null}
        {!hasPendingResult && state.phase === "school_selection" ? <><h3>{state.identity.region}에서 어느 학교로 진학할까요?</h3><p>같은 지역에서 선수 등록을 이어갈 수 있는 학교들입니다. 학교마다 잘 가르치는 훈련과 감수해야 할 단점이 다릅니다.</p>
          <div className="school-grid">{state.schoolOptions.map((school) => <button key={school.id} type="button" disabled={isRunning} onClick={() => void onSchool(school.id)}>
            <span>{school.name}</span><strong>{school.philosophy}</strong>
            <CharacterProfile className="school-staff" title={`${school.coachName} 감독 · ${school.coachArchetype}`} record={school.coachRecord} description={school.coachPersonality} />
            <CharacterProfile className="school-staff" title={`${school.catcherName} 포수 · ${school.catcherArchetype}`} record={school.catcherRecord} description={school.catcherPersonality} />
            <small className="school-tradeoff">아쉬운 점 · {school.tradeoff}</small></button>)}</div></> : null}
        {!hasPendingResult && state.phase === "training" ? <><h3>{state.chapter.season} {state.chapterTrainingCount + 1}번째 훈련 고르기</h3><p>{showHints ? `${state.school?.name ?? "학교"}는 ${TRAININGS.find((item) => item.value === state.school?.strength)?.label ?? "주력"} 훈련의 성장 가능성을 높여 줍니다. 현재 피로는 ${state.fatigue}입니다.` : `현재 피로 ${state.fatigue}. 이번에 진행할 훈련을 고르세요.`}</p>
          <div className="career-training-grid">{TRAININGS.map((option) => <button key={option.value} type="button" aria-pressed={focus === option.value}
            className={focus === option.value ? "is-selected" : undefined} onClick={() => setFocus(option.value)}><strong>{option.label}</strong><span>{option.copy}</span><small>{option.gameEffect}</small></button>)}</div>
          <div className="training-intensity-grid">{INTENSITIES.map((option) => <button key={option.value} type="button"
            className={intensity === option.value ? "is-selected" : undefined} aria-pressed={intensity === option.value} onClick={() => setIntensity(option.value)}><strong>{option.label}</strong><span>{option.copy}</span></button>)}</div>
          <div className="training-preview" aria-live="polite"><div><span>선택한 훈련</span><strong>{selectedTraining.label} · {selectedIntensity.label}</strong></div>
            <div><span>능력치 성장 가능성</span><strong>{growthOutlook}{schoolBonus > 0 ? " · 학교 강점 적용" : ""}</strong></div>
            <div><span>훈련 뒤 예상 피로</span><strong>{state.fatigue} → {expectedFatigue.after} <small>({expectedFatigue.change >= 0 ? "+" : ""}{expectedFatigue.change})</small></strong></div>
            <p>성장 여부는 학교 지원, 현재 피로와 훈련 강도에 따라 달라집니다.</p></div>
          <button className="ds-button ds-button--primary lab-primary" type="button" disabled={isRunning} onClick={() => void onTraining(focus, intensity)}>{isRunning ? "훈련 결과 계산 중…" : `${selectedTraining.label} 훈련 진행`}</button></> : null}
        {!hasPendingResult && state.phase === "relationship" ? <><div className="relationship-scene-heading"><div><span className="decision-speaker">{scene.speaker}</span><h3>{relationship.title}</h3></div><img src={relationshipArt} alt="" width="90" height="112" loading="lazy" decoding="async" /></div><p>{scene.quote}</p>
          <div className="relationship-options">{scene.choices.map((choice) => <button key={choice.id} type="button" disabled={isRunning} onClick={() => void onRelationship(choice.id)}><strong>{choice.title}</strong><span>{choice.copy}</span></button>)}</div></> : null}
        {!hasPendingResult && state.phase === "important_game" ? <div className="career-milestone"><span>중요 경기 {state.performance.importantGamesCompleted + 1}</span><h3>{state.currentGameScenario?.title ?? `${state.rival.name} 상대 중요 이닝`}</h3>
          <CharacterProfile className="rival-scouting" imageSrc={rivalRoleScene} imageAlt="" title={`${state.rival.name} · ${state.rival.archetype}`} record={state.rival.signatureRecord} description={state.rival.personality} />
          <p>{state.currentGameScenario?.narrative ?? `현재 피로 ${state.fatigue}. 직접 구종과 코스를 골라 이닝을 끝내야 합니다.`}</p>
          <button className="ds-button ds-button--primary lab-primary" type="button" disabled={isRunning} onClick={() => void onImportantGame()}>중요 이닝 직접 투구</button></div> : null}
        {!hasPendingResult && state.phase === "awakening" ? <><h3>새로 익힌 강점 {state.selectedAwakenings.length + 1}/3</h3><div className="relationship-options">{state.awakeningOptions.map((awakening) =>
          <button key={awakening} type="button" disabled={isRunning} onClick={() => void onAwakening(awakening)}><strong>{AWAKENINGS[awakening]}</strong><span>{AWAKENING_DETAILS[awakening]}</span></button>)}</div></> : null}
        {!hasPendingResult && state.phase === "chapter_review" ? <div className="career-milestone"><span>{state.chapter.season} 일정 완료</span><h3>‘{state.chapter.title}’ 종료</h3><p>다음 시즌으로 넘어가면 지금까지 고른 훈련과 대화는 바꿀 수 없습니다.</p>
          <button className="ds-button ds-button--primary lab-primary" type="button" disabled={isRunning} onClick={() => void onAdvanceChapter()}>다음 시즌으로</button></div> : null}
        {!hasPendingResult && state.phase === "draft" ? <div className="career-milestone draft-stage"><span>드래프트 당일</span><h3>드래프트가 시작됩니다.</h3>
          <p>{state.difficulty.informationClarity === "challenging" ? "구단의 평가는 이름이 불린 뒤 공개됩니다." : "10개 구단이 능력, 경기 기록, 포수·감독 평가를 함께 확인합니다."}</p><button className="ds-button ds-button--primary lab-primary" type="button" disabled={isRunning} onClick={() => void startDraftReveal()}>드래프트 시작</button></div> : null}
        {!hasPendingResult && state.phase === "legacy" && state.draftResult ? <><div className="draft-result is-undrafted"><span>미지명 · 구단 평가 점수 {state.draftResult.evaluationScore}</span><h3>이번 삶은 여기서 끝났습니다.</h3><p>{state.draftResult.summary}</p></div>
          <h4>다음 삶에 남길 기억 {state.memorySlots}장</h4><div className="memory-grid">{state.legacyOptions.map((memory) => <button key={memory} type="button" className={memories.includes(memory) ? "is-selected" : undefined}
            aria-pressed={memories.includes(memory)} onClick={() => toggleMemory(memory)}><strong>{MEMORIES[memory]}</strong><span>{MEMORY_DETAILS[memory]}</span><small>{memories.includes(memory) ? "선택됨" : "기억하기"}</small></button>)}</div>
          <button className="ds-button ds-button--primary lab-primary" type="button" disabled={isRunning || memories.length !== state.memorySlots} onClick={() => void onLegacy(memories)}>기억 {state.memorySlots}장 확정</button></> : null}
        {!hasPendingResult && state.phase === "completed" && state.draftResult ? <div className={`draft-result ${state.draftResult.outcome === "drafted" ? "is-drafted" : "is-undrafted"}`}>
          <span>{state.draftResult.outcome === "drafted" ? `${state.draftResult.round}라운드 ${state.draftResult.overallPick}순위` : "드래프트 종료"}</span>
          <h3>{state.draftResult.team?.name ?? "다음 삶을 준비합니다"}</h3><p>{state.draftResult.summary}</p>{state.draftResult.team ? <div className="pro-preview">
            <div><span>계약금</span><strong>{Math.round((state.draftResult.signingBonus ?? 0) / 10_000)}만원</strong></div><div><span>입단 뒤 계획</span><strong>{state.draftResult.team.developmentPlan}</strong></div>
            <CharacterProfile label="경쟁자" title={state.draftResult.team.positionCompetitor} record={state.draftResult.team.competitorRecord} description={state.draftResult.team.competitorProfile} />
            <CharacterProfile label="담당 코치" title={state.draftResult.team.proCoach} record={state.draftResult.team.coachRecord} description={state.draftResult.team.coachProfile} />
            <div><span>첫 시즌 목표</span><strong>2군 선발 경쟁 · 1군 데뷔</strong></div><div><span>프로에서 이어지는 내용</span><strong>훈련·선발 경쟁·계약·FA</strong></div></div> : null}
          {state.draftResult.outcome === "drafted" ? <div className="pro-lock"><span>프로 커리어</span><h4>{proAccessAvailable ? "지명 구단과 계약할 차례입니다." : "프로 커리어 확장"}</h4>
            <p>{proAccessAvailable ? "2군 선발 경쟁부터 시작합니다. 고교 기록과 구종은 그대로 이어집니다." : "프로 커리어는 정식판에서 고교 기록 그대로 이어집니다."}</p>
            <button type="button" disabled={isRunning || !proAccessAvailable} onClick={() => void onStartPro()}>{proAccessAvailable ? "프로 입단" : "데모는 여기까지"}</button></div> : null}
          {state.draftResult.outcome === "undrafted" ? <button className="ds-button ds-button--primary lab-primary" type="button" onClick={() => void onNextLife()}>기억을 가지고 다음 삶 시작</button> : null}</div> : null}
        </> : null}
        {error ? <p className="error-message" role="alert">{error}</p> : null}
      </section>

      <aside className="ds-card ds-record-grid career-panel career-news"><div className="lab-card-heading"><span>뉴스·팬 반응</span><small>눌러서 상세 보기</small></div>
        <CareerNewsFeed items={state.news.map((item) => polishedNews(item, state.school?.coachName, state.school?.catcherName))} maxItems={7} context={{
          mode: "high_school", playerName: state.pitcher.name, affiliation: state.school?.name ?? `${state.identity.region} 지역 야구계`,
          period: `${state.chapter.schoolYear}학년 ${state.chapter.season}`, trust: Math.round((managerTrust + catcherTrust + rivalTrust) / 3),
          managerTrust, catcherTrust, rivalTrust,
          fanInterest: state.fanInterest, coachName: state.school?.coachName, catcherName: state.school?.catcherName,
        }} />
        <div className="career-performance"><span>중요 경기 누적</span><div><b>{state.performance.pitches}</b><small>투구</small></div><div><b>{state.performance.strikeouts}</b><small>삼진</small></div>
          <div><b>{state.performance.walks}</b><small>볼넷</small></div><div><b>{state.performance.runsAllowed}</b><small>실점</small></div></div>
      </aside>
    </div>
  </main>;
}
