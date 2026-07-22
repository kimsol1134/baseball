import { useEffect, useState } from "react";
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
  { key: "stuff", label: "구위" }, { key: "command", label: "커맨드" },
  { key: "movement", label: "무브먼트" }, { key: "stamina", label: "체력" },
];

const TRAININGS: ReadonlyArray<{ value: TrainingFocus; label: string; copy: string }> = [
  { value: "velocity", label: "출력", copy: "포심 구위와 최고 구속" },
  { value: "command", label: "커맨드", copy: "경계 재현과 볼넷 억제" },
  { value: "breaking_ball", label: "변화구", copy: "궤적과 헛스윙 결정구" },
  { value: "stamina", label: "선발 체력", copy: "긴 이닝의 구위 유지" },
  { value: "recovery", label: "회복", copy: "피로 관리와 다음 경기 준비" },
  { value: "game_planning", label: "경기 설계", copy: "카운트와 상대 패턴 대응" },
];

const AWAKENINGS: Record<AwakeningID, string> = {
  explosive_fastball: "폭발하는 포심", pinpoint_edge: "바늘끝 경계",
  disappearing_breaker: "사라지는 궤적", iron_arm: "강철의 어깨",
  calm_under_pressure: "고요한 마운드", battery_sync: "배터리 동기화",
  rising_four_seam: "떠오르는 포심", sinker_tunnel: "싱커 터널",
  frozen_changeup: "멈춘 체인지업", sweeping_slider: "스위퍼 궤도",
  curveball_clock: "커브의 시계", repeatable_release: "반복되는 릴리스",
  pickoff_rhythm: "주자를 묶는 리듬", two_strike_plan: "2스트라이크 설계",
  first_pitch_strike: "초구 스트라이크", traffic_controller: "주자 교통정리",
  late_inning_reserve: "후반 이닝의 여력", scout_composure: "스카우트 앞의 평정",
};

const AWAKENING_DETAILS: Record<AwakeningID, string> = {
  explosive_fastball: "포심 구위 +4 · 커맨드 -2 · 구속과 헛스윙 상승",
  rising_four_seam: "포심 구위·헛스윙 상승 · 전체 무브먼트 -1",
  pinpoint_edge: "커맨드 +4 · 구위 -1 · 경계 제구 상승",
  disappearing_breaker: "무브먼트 +4 · 커맨드 -1 · 변화구 헛스윙 상승",
  iron_arm: "체력 +5 · 무브먼트 -1 · 공마다 피로 소모 감소",
  calm_under_pressure: "커맨드 +2 · 체력 +1 · 제구 안정",
  battery_sync: "커맨드 +2 · 무브먼트 +1 · 약한 타구 유도 상승",
  sinker_tunnel: "무브먼트 +3 · 포심과 체인지업의 약한 타구 상승",
  frozen_changeup: "체인지업 궤적·헛스윙 상승 · 체력 -1",
  sweeping_slider: "무브먼트 +4 · 커맨드 -1 · 슬라이더 결정력 상승",
  curveball_clock: "무브먼트 +4 · 체력 -1 · 커브 결정력 상승",
  repeatable_release: "커맨드 +4 · 구위 -1 · 전 구종 제구 상승",
  pickoff_rhythm: "커맨드 +1 · 체력 +2 · 주자 상황 실행 안정",
  two_strike_plan: "커맨드·무브먼트 +2 · 체력 -1 · 변화구 헛스윙 상승",
  first_pitch_strike: "커맨드 +3 · 체력 -1 · 초구 제구 상승",
  traffic_controller: "커맨드·체력 +2 · 구위 -1 · 약한 타구 상승",
  late_inning_reserve: "체력 +4 · 공마다 피로 소모 감소",
  scout_composure: "구위·커맨드 +2 · 체력 -1",
};

const MEMORIES: Record<MemoryCardID, string> = {
  velocity_blueprint: "구속의 설계도", fingertip_memory: "손끝의 기억",
  catcher_notebook: "포수의 노트", rival_notebook: "라이벌 노트",
  recovery_routine: "회복 루틴", pressure_rehearsal: "압박의 예행연습",
  first_pitch_map: "초구 지도", two_strike_sequence: "2스트라이크 시퀀스",
  fatigue_diary: "피로 일지", mechanics_video: "폼 교정 영상",
  school_playbook: "학교 플레이북", coach_letter: "코치의 편지",
  draft_report: "드래프트 리포트", stadium_echo: "구장의 메아리",
  team_first_promise: "팀을 위한 약속", failure_scorebook: "실패의 스코어북",
  winter_program: "겨울 프로그램", bullpen_compass: "불펜의 나침반",
};

const MEMORY_DETAILS: Record<MemoryCardID, string> = {
  velocity_blueprint: "포심 구속·헛스윙 상승, 커맨드 소폭 감소",
  fingertip_memory: "변화구 움직임 상승, 체력 소폭 감소",
  catcher_notebook: "커맨드와 약한 타구 유도 상승",
  rival_notebook: "커맨드·무브먼트와 변화구 헛스윙 상승",
  recovery_routine: "체력 상승, 공마다 피로 소모 감소",
  pressure_rehearsal: "커맨드·체력과 제구 안정 상승",
  first_pitch_map: "초구 제구 상승, 체력 소폭 감소",
  two_strike_sequence: "변화구 움직임·헛스윙 상승, 체력 소폭 감소",
  fatigue_diary: "체력과 후반 제구 상승",
  mechanics_video: "커맨드·제구 상승, 최고 출력 소폭 감소",
  school_playbook: "커맨드·무브먼트 상승",
  coach_letter: "커맨드·체력 상승",
  draft_report: "구위·커맨드 상승",
  stadium_echo: "구위·헛스윙 상승, 커맨드 소폭 감소",
  team_first_promise: "커맨드·체력과 약한 타구 유도 상승",
  failure_scorebook: "커맨드·무브먼트 상승, 체력 소폭 감소",
  winter_program: "구위·체력 상승, 피로 소모 감소",
  bullpen_compass: "구위·체력 상승, 피로 소모 감소",
};

const PHASE_LABELS: Record<HighSchoolCareerResult["snapshot"]["phase"], string> = {
  prologue: "중학교 마지막 대회", school_selection: "학교 선택", training: "훈련", relationship: "면담",
  important_game: "중요 경기", awakening: "새 강점", chapter_review: "계절 마무리", draft: "드래프트", legacy: "남길 기억", completed: "완료",
};

type RelationshipChoiceCard = { id: RelationshipResponse; title: string; copy: string };

function polishedNews(item: string) {
  return item
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
  onStart: (presetID: string, allocation: CreationAllocationSnapshot, identity: PlayerIdentitySnapshot,
    difficulty: CareerDifficultySnapshot, karmas: ReadonlyArray<KarmaID>) => Promise<void>;
  onBack: () => void;
}

export function HighSchoolCareerSetup({ presets, isRunning, error, onStart, onBack }: CareerSetupProps) {
  const [presetID, setPresetID] = useState("");
  const [allocation, setAllocation] = useState<CreationAllocationSnapshot>({ stuff: 2, command: 1, movement: 1, stamina: 1 });
  const [identity, setIdentity] = useState<PlayerIdentitySnapshot>({ name: "문동윤", throwingHand: "right", bodyType: "balanced", region: "서울" });
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
      <section className="career-intro">
        <div><p className="eyebrow">고교 커리어</p><h2>중학교의 마지막 공에서 드래프트까지</h2>
          <p>학교를 고르고, 감독과 포수에게 배우고, 라이벌과 다시 만납니다. 세 시즌 뒤에는 프로 구단의 선택을 받습니다.</p></div>
        <button type="button" onClick={onBack}>투수 성장실로</button>
      </section>
      <section className="preset-creation-grid">
        {presets.map((preset) => <button key={preset.id} type="button" aria-pressed={preset.id === effectivePresetID}
          className={preset.id === effectivePresetID ? "is-selected" : undefined} onClick={() => selectPreset(preset)}>
          <span>{preset.name}</span><strong>{preset.pitcher.name}</strong><p>{preset.tagline}</p><small>{preset.tradeoff}</small>
          <dl className="preset-statline" aria-label={`${preset.name} 기본 능력: ${METRICS.map((metric) => `${metric.label} ${preset.pitcher[metric.key]}`).join(", ")}`}>
            {METRICS.map((metric) => <div key={metric.key}><dt>{metric.label}</dt><dd>{preset.pitcher[metric.key]}</dd></div>)}
          </dl>
        </button>)}
      </section>
      {selected ? <section className="creation-allocation career-allocation">
        <div className="creation-summary"><div><span>투수 유형</span><strong>{selected.name}</strong><p>선수마다 강점과 약점이 다릅니다. 추가 능력 5점은 어느 유형을 골라도 같습니다.</p></div>
          <div className="creation-points"><span>남은 포인트</span><strong>{5 - spent}</strong></div></div>
        <div className="allocation-grid">{METRICS.map((metric) => <div key={metric.key}><span>{metric.label}</span><small>기본 {selected.pitcher[metric.key]} · 추가 +{allocation[metric.key]}</small><div>
          <button type="button" disabled={allocation[metric.key] === 0} onClick={() => change(metric.key, -1)}>−</button>
          <strong aria-label={`${metric.label} 최종 ${selected.pitcher[metric.key] + allocation[metric.key]}`}>
            {selected.pitcher[metric.key] + allocation[metric.key]}<small>+{allocation[metric.key]}</small>
          </strong><button type="button" disabled={spent >= 5} onClick={() => change(metric.key, 1)}>+</button>
        </div></div>)}</div>
        <div className="identity-grid"><label className="identity-name-field"><span>선수 이름</span><div><input value={identity.name} maxLength={12} autoComplete="off"
          onChange={(event) => { setIdentity({ ...identity, name: event.target.value }); setUsesRecommendedName(false); }} />
          <button type="button" disabled={usesRecommendedName && identity.name === selected.pitcher.name}
            onClick={() => { setIdentity({ ...identity, name: selected.pitcher.name }); setUsesRecommendedName(true); }}>추천 이름 사용</button></div>
          <small>추천 이름을 그대로 쓰거나 직접 입력하세요.</small></label>
          <label><span>지역</span><select value={identity.region} onChange={(event) => setIdentity({ ...identity, region: event.target.value })}>
            <option>서울</option><option>경기</option><option>충청</option><option>영남</option><option>호남</option><option>강원</option><option>제주</option></select></label>
          <label><span>투구 손</span><select value={identity.throwingHand} onChange={(event) => setIdentity({ ...identity, throwingHand: event.target.value as PlayerIdentitySnapshot["throwingHand"] })}>
            <option value="right">우투</option><option value="left">좌투</option></select></label>
          <label><span>체격</span><select value={identity.bodyType} onChange={(event) => setIdentity({ ...identity, bodyType: event.target.value as PlayerIdentitySnapshot["bodyType"] })}>
            <option value="compact">다부진 체격</option><option value="balanced">균형 체격</option><option value="tall">장신 체격</option></select></label></div>
        <div className="difficulty-panel"><div><span>난이도 세부 설정</span><small>경기 난이도와 정보 공개량을 따로 고를 수 있습니다.</small></div><div className="difficulty-grid">
          {([{"key":"careerHarshness","label":"지명 기준"},{"key":"informationClarity","label":"능력 공개"},{"key":"simulationDifficulty","label":"상대 타자"},{"key":"interventionAssist","label":"포수 추천"}] as const).map((axis) =>
            <label key={axis.key}><span>{axis.label}</span><select value={difficulty[axis.key]} onChange={(event) => setDifficulty({ ...difficulty, [axis.key]: event.target.value })}>
              <option value={axis.key === "interventionAssist" ? "full" : "relaxed"}>{axis.key === "interventionAssist" ? "힌트 많음" : "낮음"}</option>
              <option value="standard">표준</option><option value={axis.key === "interventionAssist" ? "minimal" : "challenging"}>{axis.key === "interventionAssist" ? "힌트 최소" : "높음"}</option>
            </select></label>)}</div></div>
        <div className="karma-panel"><div><span>추가 조건 · 최대 2개</span><small>더 어려운 조건을 고르면 미지명 뒤에 얻는 보상이 늘어납니다.</small></div><div className="karma-grid">
          {([{"id":"unknown_land","title":"무명의 땅","copy":"스카우트 노출 감소 · 보상 +15%"},{"id":"stubborn_coach","title":"완고한 감독","copy":"갈등 페널티 증가 · 보상 +15%"},
            {"id":"single_weapon","title":"한 가지 무기","copy":"강점 집중, 나머지 감소 · 보상 +20%"},{"id":"genius_generation","title":"천재의 세대","copy":"라이벌 능력 상승 · 보상 +25%"},
            {"id":"erased_memory","title":"지워진 기억","copy":"기억 슬롯 2장 · 보상 +25%"},{"id":"no_last_chance","title":"마지막 기회 없음","copy":"지명 안전망 감소 · 보상 +35%"}] as const).map((karma) =>
            <button key={karma.id} type="button" className={karmas.includes(karma.id) ? "is-selected" : undefined} aria-pressed={karmas.includes(karma.id)} onClick={() => toggleKarma(karma.id)}>
              <strong>{karma.title}</strong><span>{karma.copy}</span></button>)}</div></div>
        <button className="lab-primary" type="button" disabled={isRunning || spent !== 5 || !identity.name.trim()}
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
  onBackToLab: () => void;
  onNewCareer: () => void;
  showTutorial: boolean;
  onDismissTutorial: () => void;
  onStartPro: () => Promise<void>;
  proAccessAvailable: boolean;
  demoMode: boolean;
  onMilestoneFeedback: () => void;
}

export function HighSchoolCareerView({ result, isRunning, error, onSchool, onTraining, onRelationship,
  onCompletePrologue, onImportantGame, onAwakening, onAdvanceChapter, onDraft, onLegacy, onNextLife, onBackToLab, onNewCareer,
  showTutorial, onDismissTutorial, onStartPro, proAccessAvailable, demoMode, onMilestoneFeedback }: CareerViewProps) {
  const state = result.snapshot;
  const demoComplete = hasCompletedSteamDemo(demoMode, state.performance.importantGamesCompleted);
  const [focus, setFocus] = useState<TrainingFocus>("command");
  const [intensity, setIntensity] = useState<TrainingIntensity>("standard");
  const [memories, setMemories] = useState<ReadonlyArray<MemoryCardID>>([]);
  const [draftRevealStage, setDraftRevealStage] = useState<number | null>(null);
  const [draftRevealDone, setDraftRevealDone] = useState(false);
  useEffect(() => {
    if (draftRevealStage === null || !state.draftResult || draftRevealStage >= 4) return;
    const delay = document.body.classList.contains("reduce-motion") ? 80 : 850;
    const timer = window.setTimeout(() => setDraftRevealStage((current) => current === null ? null : Math.min(4, current + 1)), delay);
    return () => window.clearTimeout(timer);
  }, [draftRevealStage, state.draftResult]);
  useEffect(() => {
    if (draftRevealStage === 3 && state.draftResult) onMilestoneFeedback();
  }, [draftRevealStage, onMilestoneFeedback, state.draftResult]);
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
  const relationship = state.currentRelationshipEvent ?? (state.relationshipsCompleted % 3 === 0
    ? { id: "fallback-coach", category: "coach", title: "선발인가 불펜인가", summary: "감독이 다음 대회는 불펜에서 시작하겠다고 말합니다." }
    : state.relationshipsCompleted % 3 === 1
      ? { id: "fallback-catcher", category: "catcher", title: "엇갈린 사인", summary: "경기 중 세 번 사인이 엇갈렸고 포수가 이유를 묻습니다." }
      : { id: "fallback-rival", category: "rival", title: "라이벌의 메시지", summary: "라이벌이 ‘다음에도 같은 초구를 던질 거냐’고 메시지를 보냈습니다." });
  const scene = relationshipScene(relationship, state);
  const reveal = (() => {
    const draft = state.draftResult;
    if (draftRevealStage === 0 || !draft) return { label: "지명 후보 명단", title: "10개 구단이 최종 명단을 닫았습니다.", copy: "경기 기록, 현재 구종, 감독과 포수의 평가가 한 장의 보드에 올라갑니다." };
    if (draftRevealStage === 1) return draft.outcome === "drafted" && draft.round === 1
      ? { label: "1라운드", title: "구단 테이블에서 전화가 연결됩니다.", copy: `${draft.team?.name ?? "한 구단"}이 첫 선택을 준비합니다.` }
      : { label: "1라운드", title: "1라운드가 끝났습니다.", copy: "아직 이름은 불리지 않았습니다. 다음 라운드 명단이 올라옵니다." };
    if (draftRevealStage === 2) return draft.outcome === "drafted" && (draft.round ?? 9) <= 3
      ? { label: "2–3라운드", title: `${draft.team?.name ?? "구단"}에서 전화가 왔습니다.`, copy: "지명 순번이 확정되는 동안 구단 발표를 기다립니다." }
      : { label: "2–3라운드", title: "3라운드까지 이름은 불리지 않았습니다.", copy: "남은 구단들이 마지막 지명 후보를 다시 확인합니다." };
    if (draftRevealStage === 3) return draft.outcome === "drafted"
      ? { label: "지명 전화", title: `${draft.team?.name ?? "프로 구단"} · ${draft.round}라운드 ${draft.overallPick}순위`, copy: `${state.pitcher.name}의 프로 지명이 확정됐습니다.` }
      : { label: "최종 라운드", title: "마지막 순번이 지나갔습니다.", copy: "이번 드래프트에서는 이름이 불리지 않았습니다." };
    return { label: draft.outcome === "drafted" ? "스카우트 평가" : "다음 기록", title: draft.outcome === "drafted" ? `평가 ${draft.evaluationScore} · ${draft.projectedRange}` : `최종 평가 ${draft.evaluationScore}`, copy: draft.summary };
  })();

  return <main className="career-shell">
    {showTutorial ? <section className="tutorial-panel" role="dialog" aria-modal="true" aria-labelledby="tutorial-title">
      <div><p className="eyebrow">빠른 안내</p><h2 id="tutorial-title">고교 커리어 시작 전</h2></div>
      <ol><li><strong>현재 능력</strong><span>선수 카드에서 구위·커맨드·무브먼트·체력을 확인합니다.</span></li><li><strong>중요 경기</strong><span>승부처에서는 구종·코스·강도를 직접 선택합니다.</span></li>
        <li><strong>선택 확정</strong><span>확정한 훈련과 사건 선택은 되돌릴 수 없습니다.</span></li><li><strong>자동 저장</strong><span>확정한 선택마다 이 기기에 저장됩니다.</span></li></ol>
      <button className="lab-primary" type="button" autoFocus onClick={onDismissTutorial}>커리어 시작</button>
    </section> : null}
    <section className="career-hero">
      <div><p className="eyebrow">{state.lifeNumber}번째 선수 · {state.chapter.schoolYear}학년 {state.chapter.season}</p>
        <h2>{state.chapter.number}장 · {state.chapter.title}</h2><p>{state.chapter.theme}</p></div>
      <div className="career-vitals"><div><span>피로</span><strong>{state.fatigue}</strong></div><div><span>관계 신뢰</span><strong>{state.relationshipTrust}</strong></div>
        <div><span>팬 관심</span><strong>{state.fanInterest}</strong></div><button type="button" onClick={onBackToLab}>투수 성장실</button>
        <button type="button" onClick={onNewCareer}>새 커리어</button></div>
    </section>
    <section className="chapter-map" aria-label="8개 커리어 챕터">{Array.from({ length: 8 }, (_, index) => index + 1).map((chapter) =>
      <div key={chapter} className={chapter === state.chapter.number ? "is-current" : chapter < state.chapter.number ? "is-complete" : undefined}>
        <span>{chapter}</span><small>{chapter < state.chapter.number ? "완료" : chapter === state.chapter.number ? "진행 중" : "잠김"}</small></div>)}</section>
    <div className="career-grid">
      <section className="career-panel career-player"><div className="lab-card-heading"><span>{state.pitcher.name}</span><small>{state.school?.name ?? "학교 선택 전"}</small></div>
        <div className="career-rating-grid"><div><span>구위</span><strong>{rating(state.pitcher.stuff)}</strong></div><div><span>커맨드</span><strong>{rating(state.pitcher.command)}</strong></div>
          <div><span>무브먼트</span><strong>{rating(state.pitcher.movement)}</strong></div><div><span>체력</span><strong>{rating(state.pitcher.stamina)}</strong></div></div>
        <small className="information-clarity">정보 정확도 · {state.difficulty.informationClarity === "relaxed" ? "정확한 현재값" : state.difficulty.informationClarity === "standard" ? "스카우트 추정 범위" : "등급만 공개"}</small>
        {state.school ? <div className="career-personnel"><span>감독</span><strong>{state.school.coachName} · {state.school.coachArchetype}</strong><span>포수</span><strong>{state.school.catcherName} · {state.school.catcherArchetype}</strong>
          <span>라이벌</span><strong>{state.rival.name} · {state.rival.archetype}</strong></div> : null}
        <div className="career-counters"><span>훈련 {state.totalTrainingsCompleted}/16</span><span>경기 {state.performance.importantGamesCompleted}/5</span>
          <span>관계 {state.relationshipsCompleted}/5</span><span>각성 {state.selectedAwakenings.length}/3</span></div>
      </section>

      <section className="career-panel career-decision"><div className="lab-card-heading"><span>지금 할 일</span><small>{PHASE_LABELS[state.phase]}</small></div>
        {demoComplete ? <div className="career-milestone demo-complete"><span>데모 기록 완료</span>
          <h3>첫 중요 경기를 마쳤습니다.</h3>
          <p>{state.pitcher.name}은 구위 {rating(state.pitcher.stuff)}, 커맨드 {rating(state.pitcher.command)}로 첫 기록을 남겼습니다. 이 저장은 정식판에서 그대로 이어집니다.</p>
          <div className="demo-summary"><div><strong>{state.performance.pitches}</strong><span>투구</span></div><div><strong>{state.performance.strikeouts}</strong><span>삼진</span></div><div><strong>{state.relationshipTrust}</strong><span>관계 신뢰</span></div></div>
          <p className="demo-next">정식판에서는 남은 고교 생활, 드래프트, 프로 입단과 은퇴까지 이어집니다.</p>
          <button className="lab-primary" type="button" onClick={onNewCareer}>새 선수로 다시 해보기</button>
        </div> : null}
        {!demoComplete ? <>
        {draftRevealStage !== null && !draftRevealDone ? <div className={`draft-reveal draft-reveal--stage-${draftRevealStage}`} role="dialog" aria-live="polite" aria-label="드래프트 결과 공개">
          <span>{reveal.label}</span><div className="draft-rounds" aria-hidden="true">{[0, 1, 2, 3, 4].map((step) => <i key={step} className={step <= draftRevealStage ? "is-active" : undefined} />)}</div>
          <h3>{reveal.title}</h3><p>{reveal.copy}</p>
          {draftRevealStage >= 4 ? <button className="lab-primary" type="button" onClick={() => setDraftRevealDone(true)}>결과 화면 확인</button>
            : <button className="draft-skip" type="button" onClick={() => setDraftRevealStage(4)}>바로 결과 보기</button>}
        </div> : null}
        {state.phase === "prologue" ? <div className="career-milestone prologue-card"><span>중학교 마지막 경기</span>
          <h3>{state.identity.region}의 마지막 중학교 대회</h3><p>{state.identity.name} · {state.identity.throwingHand === "right" ? "우투" : "좌투"} · {state.identity.bodyType === "tall" ? "장신" : state.identity.bodyType === "compact" ? "다부진" : "균형"} 체격. 경기를 마치고 나오자 네 고교에서 진학 제안이 도착했습니다. {state.karmas.length > 0 ? `선택한 추가 조건 ${state.karmas.length}개` : "추가 조건 없음"}</p>
          <button className="lab-primary" type="button" disabled={isRunning} onClick={() => void onCompletePrologue()}>고교 진학 제안 확인</button></div> : null}
        {state.phase === "school_selection" ? <><h3>어느 학교로 진학할까요?</h3><p>학교마다 잘 가르치는 훈련과 감수해야 할 단점이 다릅니다.</p>
          <div className="school-grid">{state.schoolOptions.map((school) => <button key={school.id} type="button" disabled={isRunning} onClick={() => void onSchool(school.id)}>
            <span>{school.name}</span><strong>{school.philosophy}</strong><p>{school.coachName} 감독 · {school.catcherName} 포수</p><small>{school.tradeoff}</small></button>)}</div></> : null}
        {state.phase === "training" ? <><h3>이번 계절의 {state.chapterTrainingCount + 1}번째 훈련</h3><p>{showHints ? `${state.school?.name ?? "학교"}는 ${TRAININGS.find((item) => item.value === state.school?.strength)?.label ?? "주력"} 훈련을 가장 잘 지원합니다. 현재 피로는 ${state.fatigue}입니다.` : `현재 피로 ${state.fatigue}. 이번 훈련을 고르세요.`}</p>
          <div className="career-training-grid">{TRAININGS.map((option) => <button key={option.value} type="button" aria-pressed={focus === option.value}
            className={focus === option.value ? "is-selected" : undefined} onClick={() => setFocus(option.value)}><strong>{option.label}</strong><span>{option.copy}</span></button>)}</div>
          <div className="training-intensity-grid">{(["light", "standard", "intensive"] as const).map((value) => <button key={value} type="button"
            className={intensity === value ? "is-selected" : undefined} aria-pressed={intensity === value} onClick={() => setIntensity(value)}><strong>{value === "light" ? "가볍게" : value === "standard" ? "표준" : "집중"}</strong></button>)}</div>
          <button className="lab-primary" type="button" disabled={isRunning} onClick={() => void onTraining(focus, intensity)}>이 훈련 시작</button>
          {state.lastTraining ? <div className="career-feedback"><strong>{state.lastTraining.feedback}</strong><span>능력 +{state.lastTraining.growth} · 피로 {state.lastTraining.fatigueChange >= 0 ? "+" : ""}{state.lastTraining.fatigueChange}</span></div> : null}</> : null}
        {state.phase === "relationship" ? <><span className="decision-speaker">{scene.speaker}</span><h3>{relationship.title}</h3><p>{scene.quote}</p>
          <div className="relationship-options">{scene.choices.map((choice) => <button key={choice.id} type="button" disabled={isRunning} onClick={() => void onRelationship(choice.id)}><strong>{choice.title}</strong><span>{choice.copy}</span></button>)}</div></> : null}
        {state.phase === "important_game" ? <div className="career-milestone"><span>중요 경기 {state.performance.importantGamesCompleted + 1}</span><h3>{state.currentGameScenario?.title ?? `${state.rival.name} 상대 중요 이닝`}</h3>
          <p>{state.currentGameScenario?.narrative ?? `현재 피로 ${state.fatigue}. 직접 구종과 코스를 골라 이닝을 끝내야 합니다.`}</p>
          <button className="lab-primary" type="button" disabled={isRunning} onClick={() => void onImportantGame()}>중요 이닝 직접 투구</button></div> : null}
        {state.phase === "awakening" ? <><h3>새로 익힌 강점 {state.selectedAwakenings.length + 1}/3</h3><div className="relationship-options">{state.awakeningOptions.map((awakening) =>
          <button key={awakening} type="button" disabled={isRunning} onClick={() => void onAwakening(awakening)}><strong>{AWAKENINGS[awakening]}</strong><span>{AWAKENING_DETAILS[awakening]}</span></button>)}</div></> : null}
        {state.phase === "chapter_review" ? <div className="career-milestone"><span>이번 계절 완료</span><h3>‘{state.chapter.title}’ 종료</h3><p>다음 계절로 넘어가면 이번 계절의 선택은 바꿀 수 없습니다.</p>
          <button className="lab-primary" type="button" disabled={isRunning} onClick={() => void onAdvanceChapter()}>다음 계절로</button></div> : null}
        {state.phase === "draft" ? <div className="career-milestone draft-stage"><span>드래프트 당일</span><h3>드래프트가 시작됩니다.</h3>
          <p>{state.difficulty.informationClarity === "challenging" ? "구단의 평가는 이름이 불린 뒤 공개됩니다." : "10개 구단이 능력, 경기 기록, 포수·감독 평가를 함께 확인합니다."}</p><button className="lab-primary" type="button" disabled={isRunning} onClick={() => void startDraftReveal()}>드래프트 시작</button></div> : null}
        {state.phase === "legacy" && state.draftResult ? <><div className="draft-result is-undrafted"><span>미지명 · 평가 {state.draftResult.evaluationScore}</span><h3>이번 삶은 여기서 끝났습니다.</h3><p>{state.draftResult.summary}</p></div>
          <h4>다음 삶에 남길 기억 {state.memorySlots}장</h4><div className="memory-grid">{state.legacyOptions.map((memory) => <button key={memory} type="button" className={memories.includes(memory) ? "is-selected" : undefined}
            aria-pressed={memories.includes(memory)} onClick={() => toggleMemory(memory)}><strong>{MEMORIES[memory]}</strong><span>{MEMORY_DETAILS[memory]}</span><small>{memories.includes(memory) ? "선택됨" : "기억하기"}</small></button>)}</div>
          <button className="lab-primary" type="button" disabled={isRunning || memories.length !== state.memorySlots} onClick={() => void onLegacy(memories)}>기억 {state.memorySlots}장 확정</button></> : null}
        {state.phase === "completed" && state.draftResult ? <div className={`draft-result ${state.draftResult.outcome === "drafted" ? "is-drafted" : "is-undrafted"}`}>
          <span>{state.draftResult.outcome === "drafted" ? `${state.draftResult.round}라운드 ${state.draftResult.overallPick}순위` : "드래프트 종료"}</span>
          <h3>{state.draftResult.team?.name ?? "다음 삶을 준비합니다"}</h3><p>{state.draftResult.summary}</p>{state.draftResult.team ? <div className="pro-preview">
            <div><span>계약금</span><strong>{Math.round((state.draftResult.signingBonus ?? 0) / 10_000)}만원</strong></div><div><span>육성 계획</span><strong>{state.draftResult.team.developmentPlan}</strong></div>
            <div><span>경쟁자</span><strong>{state.draftResult.team.positionCompetitor}</strong></div><div><span>담당 코치</span><strong>{state.draftResult.team.proCoach}</strong></div>
            <div><span>첫 시즌 목표</span><strong>2군 선발 경쟁 · 1군 데뷔</strong></div><div><span>프로에서 할 일</span><strong>훈련·보직 경쟁·계약·FA</strong></div></div> : null}
          {state.draftResult.outcome === "drafted" ? <div className="pro-lock"><span>프로 커리어</span><h4>{proAccessAvailable ? "지명 구단과 계약할 차례입니다." : "프로 커리어 확장"}</h4>
            <p>{proAccessAvailable ? "2군 선발 경쟁부터 시작합니다. 고교 기록과 구종은 그대로 이어집니다." : "프로 커리어는 정식판에서 고교 기록 그대로 이어집니다."}</p>
            <button type="button" disabled={isRunning || !proAccessAvailable} onClick={() => void onStartPro()}>{proAccessAvailable ? "프로 입단" : "데모는 여기까지"}</button></div> : null}
          {state.draftResult.outcome === "undrafted" ? <button className="lab-primary" type="button" onClick={() => void onNextLife()}>기억을 가지고 다음 삶 시작</button> : null}</div> : null}
        </> : null}
        {error ? <p className="error-message" role="alert">{error}</p> : null}
      </section>

      <aside className="career-panel career-news"><div className="lab-card-heading"><span>뉴스·팬 반응</span><small>자동 저장됨</small></div>
        {state.news.slice(0, 7).map((item, index) => <article key={`${index}-${item}`}><span>{index === 0 ? "최신" : "이전"}</span><p>{polishedNews(item)}</p></article>)}
        <div className="career-performance"><span>중요 경기 누적</span><div><b>{state.performance.pitches}</b><small>투구</small></div><div><b>{state.performance.strikeouts}</b><small>삼진</small></div>
          <div><b>{state.performance.walks}</b><small>볼넷</small></div><div><b>{state.performance.runsAllowed}</b><small>실점</small></div></div>
      </aside>
    </div>
  </main>;
}
