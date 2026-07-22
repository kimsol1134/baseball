import { useEffect, useRef, useState } from "react";
import { AbilityGauge } from "./AbilityGauge";
import { GrowthCelebration } from "./GrowthCelebration";
import { CoreUnavailableState } from "./CoreUnavailableState";
import type {
  AwakeningID,
  CreationAllocationSnapshot,
  MemoryCardID,
  PitcherLabResult,
  PitcherPresetSnapshot,
  RelationshipChoice,
  SoulDomain,
  TrainingFocus,
  TrainingIntensity,
} from "./simulationTypes";

const CREATION_METRICS: ReadonlyArray<{
  key: keyof CreationAllocationSnapshot;
  label: string;
  description: string;
}> = [
  { key: "stuff", label: "공의 위력", description: "직구 구속과 헛스윙을 끌어내는 힘" },
  { key: "command", label: "제구", description: "원하는 곳에 꾸준히 던지는 능력" },
  { key: "movement", label: "변화구", description: "공이 꺾이고 떨어지는 정도" },
  { key: "stamina", label: "체력", description: "긴 이닝에도 공의 힘을 유지하는 능력" },
];

function fourSeamVelocity(pitcher: PitcherPresetSnapshot["pitcher"]) {
  const velocity = pitcher.pitchProfiles?.find((profile) => profile.pitchType === "four_seam")?.velocityTenthsKPH;
  return velocity === undefined ? "측정 전" : `${(velocity / 10).toFixed(1)} km/h`;
}

interface PitcherLabSetupProps {
  presets: ReadonlyArray<PitcherPresetSnapshot>;
  isRunning: boolean;
  error?: string;
  coreMessage: string;
  onRetryCore: () => void;
  onStart: (presetID: string, allocation: CreationAllocationSnapshot, playerName: string) => Promise<void>;
}

export function PitcherLabSetup({ presets, isRunning, error, coreMessage, onRetryCore, onStart }: PitcherLabSetupProps) {
  const [presetID, setPresetID] = useState(presets[0]?.id ?? "");
  const [playerName, setPlayerName] = useState(presets[0]?.pitcher.name ?? "");
  const [usesRecommendedName, setUsesRecommendedName] = useState(true);
  const [allocation, setAllocation] = useState<CreationAllocationSnapshot>({
    stuff: 2,
    command: 1,
    movement: 1,
    stamina: 1,
  });
  const effectivePresetID = presetID || presets[0]?.id || "";
  const selectedPreset = presets.find((preset) => preset.id === effectivePresetID) ?? presets[0];
  const spent = Object.values(allocation).reduce((sum, value) => sum + value, 0);

  useEffect(() => {
    if (usesRecommendedName && selectedPreset) setPlayerName(selectedPreset.pitcher.name);
  }, [selectedPreset, usesRecommendedName]);

  const selectPreset = (nextPreset: PitcherPresetSnapshot) => {
    setPresetID(nextPreset.id);
    if (usesRecommendedName) setPlayerName(nextPreset.pitcher.name);
  };

  const changeAllocation = (key: keyof CreationAllocationSnapshot, amount: number) => {
    setAllocation((current) => {
      const currentSpent = Object.values(current).reduce((sum, value) => sum + value, 0);
      const nextValue = current[key] + amount;
      if (nextValue < 0 || nextValue > 5 || (amount > 0 && currentSpent >= 5)) return current;
      return { ...current, [key]: nextValue };
    });
  };

  return (
    <main className="lab-setup">
      <section className="lab-setup-intro">
        <p className="eyebrow">새 선수</p>
        <h2>어떤 투수로 시작할까요?</h2>
        <p>강점과 약점이 다른 네 유형 중 하나를 고른 뒤, 추가 능력 5점을 나눠 주세요. 능력치는 20–80 평가이며 80은 세대 최고 수준입니다.</p>
      </section>
      <section className="preset-creation-grid" aria-label="투수 프리셋 선택">
        {presets.map((preset) => (
          <button key={preset.id} type="button" className={effectivePresetID === preset.id ? "is-selected" : undefined}
            aria-pressed={effectivePresetID === preset.id} onClick={() => selectPreset(preset)}>
            <span>{preset.name}</span>
            <strong>{preset.pitcher.name}</strong>
            <p>{preset.tagline}</p>
            <small>{preset.strengths.join(" · ")}</small>
            <dl className="ds-scoreboard preset-statline" aria-label={`${preset.name} 기본 능력: ${CREATION_METRICS.map((metric) => `${metric.label} ${preset.pitcher[metric.key]}`).join(", ")}`}>
              {CREATION_METRICS.map((metric) => <div key={metric.key}><dt>{metric.label}</dt><dd>{preset.pitcher[metric.key]}</dd>
                <AbilityGauge compact label={metric.label} value={preset.pitcher[metric.key]} /></div>)}
            </dl>
            <small className="preset-velocity">포심 기준 구속 {fourSeamVelocity(preset.pitcher)}</small>
          </button>
        ))}
      </section>
      {presets.length === 0 ? <CoreUnavailableState message={error ?? coreMessage} isChecking={isRunning} onRetry={onRetryCore} /> : null}
      {selectedPreset ? (
        <section className="creation-allocation">
          <div className="creation-summary">
            <div>
              <span>선택한 선수 유형</span>
              <strong>{selectedPreset.name} · {selectedPreset.pitcher.name}</strong>
              <p>{selectedPreset.tradeoff}</p>
            </div>
            <div className="creation-points"><span>남은 능력치 점수</span><strong>{5 - spent}</strong></div>
          </div>
          <div className="identity-name-panel">
            <label htmlFor="lab-player-name"><span>선수 이름</span>
              <input id="lab-player-name" value={playerName} maxLength={12} autoComplete="off"
                onChange={(event) => { setPlayerName(event.target.value); setUsesRecommendedName(false); }} />
            </label>
            <button type="button" disabled={usesRecommendedName && playerName === selectedPreset.pitcher.name}
              onClick={() => { setPlayerName(selectedPreset.pitcher.name); setUsesRecommendedName(true); }}>
              추천 이름 사용
            </button>
            <small>추천 이름을 그대로 쓰거나, 최대 12자까지 직접 정할 수 있습니다.</small>
          </div>
          <div className="allocation-grid">
            {CREATION_METRICS.map((metric) => (
              <div key={metric.key}>
                <span>{metric.label}</span>
                <small>{metric.description} · 기본 {selectedPreset.pitcher[metric.key]}</small>
                <div>
                  <button type="button" aria-label={`${metric.label} 1 감소`} disabled={allocation[metric.key] === 0}
                    onClick={() => changeAllocation(metric.key, -1)}>−</button>
                  <strong aria-label={`${metric.label} 최종 ${selectedPreset.pitcher[metric.key] + allocation[metric.key]}`}>
                    {selectedPreset.pitcher[metric.key] + allocation[metric.key]}<small>+{allocation[metric.key]}</small>
                  </strong>
                  <button type="button" aria-label={`${metric.label} 1 증가`} disabled={spent >= 5 || allocation[metric.key] === 5}
                    onClick={() => changeAllocation(metric.key, 1)}>+</button>
                </div>
                <AbilityGauge compact label={`${metric.label} 최종`} value={selectedPreset.pitcher[metric.key] + allocation[metric.key]} />
              </div>
            ))}
          </div>
          <button className="ds-button ds-button--primary lab-primary" type="button" disabled={isRunning || spent !== 5 || !playerName.trim()}
            onClick={() => void onStart(selectedPreset.id, allocation, playerName.trim())}>
            {isRunning ? "선수 준비 중…" : "훈련 시작"}
          </button>
          {error ? <p className="error-message" role="alert">{error}</p> : null}
        </section>
      ) : null}
    </main>
  );
}

const TRAINING_OPTIONS: ReadonlyArray<{
  value: TrainingFocus;
  label: string;
  description: string;
}> = [
  { value: "velocity", label: "직구 구속", description: "직구를 더 빠르고 위력 있게 던진다" },
  { value: "command", label: "제구", description: "원하는 코스에 꾸준히 던지는 연습을 한다" },
  { value: "breaking_ball", label: "변화구", description: "더 크게 꺾이는 변화구로 헛스윙을 노린다" },
  { value: "stamina", label: "선발 체력", description: "긴 이닝에도 공의 힘이 떨어지지 않게 한다" },
  { value: "recovery", label: "휴식과 회복", description: "피로를 낮추고 다음 훈련을 준비한다" },
  { value: "game_planning", label: "타자 상대법", description: "카운트와 타자 약점에 맞춰 구종을 고르는 연습을 한다" },
];

const INTENSITY_OPTIONS: ReadonlyArray<{
  value: TrainingIntensity;
  label: string;
  description: string;
}> = [
  { value: "light", label: "가볍게", description: "피로를 적게 쌓고 투구 감각만 유지한다" },
  { value: "standard", label: "보통", description: "성장 가능성과 피로가 균형을 이룬다" },
  { value: "intensive", label: "강하게", description: "성장 가능성이 높지만 피로도 많이 쌓인다" },
];

function clamp(value: number, lower: number, upper: number) {
  return Math.min(upper, Math.max(lower, value));
}

export function labTrainingForecast(
  fatigue: number,
  readiness: number,
  focus: TrainingFocus,
  intensity: TrainingIntensity,
) {
  const fatigueCost = intensity === "light" ? 5 : intensity === "standard" ? 11 : 20;
  const recoveryLow = focus === "recovery" ? 18 : 0;
  const recoveryHigh = focus === "recovery" ? 26 : 0;
  const fatigueLow = clamp(fatigue + fatigueCost - recoveryHigh, 0, 100);
  const fatigueHigh = clamp(fatigue + fatigueCost - recoveryLow, 0, 100);
  const readinessCost = intensity === "light" ? 2 : intensity === "standard" ? 6 : 12;
  const readinessAfter = clamp(readiness - readinessCost + (focus === "recovery" ? 16 : 0), 20, 100);
  const growthChance = intensity === "intensive" ? "상대적으로 높음" : intensity === "standard" ? "보통" : "낮음";
  return { fatigueLow, fatigueHigh, readinessAfter, growthChance };
}

const AWAKENING_LABELS: Record<AwakeningID, { title: string; description: string }> = {
  explosive_fastball: { title: "폭발하는 포심", description: "직구 구속과 헛스윙을 잡는 힘이 크게 오릅니다." },
  pinpoint_edge: { title: "바늘끝 제구", description: "스트라이크존 끝에 계속 던질 수 있게 됩니다." },
  disappearing_breaker: { title: "사라지는 변화구", description: "변화구가 더 크게 꺾여 헛스윙을 잡기 쉬워집니다." },
  iron_arm: { title: "강철의 어깨", description: "긴 이닝에도 공의 힘이 잘 떨어지지 않습니다." },
  calm_under_pressure: { title: "고요한 마운드", description: "주자가 있어도 원하는 공을 침착하게 던집니다." },
  battery_sync: { title: "포수와 한마음", description: "포수의 사인을 빠르게 이해하고 좋은 코스를 고릅니다." },
  rising_four_seam: { title: "떠오르는 포심", description: "높은 직구로 헛스윙과 뜬공을 더 자주 만듭니다." },
  sinker_tunnel: { title: "같은 길에서 갈라지는 공", description: "직구와 싱커가 타자 앞까지 같은 공처럼 보입니다." },
  frozen_changeup: { title: "멈춘 체인지업", description: "직구와의 속도 차이가 커지고 더 많이 떨어집니다." },
  sweeping_slider: { title: "스위퍼 궤도", description: "슬라이더의 수평 움직임을 키웁니다." },
  curveball_clock: { title: "일정한 커브 타이밍", description: "매번 같은 동작으로 커브를 던집니다." },
  repeatable_release: { title: "흔들리지 않는 투구 동작", description: "어떤 구종을 던져도 팔이 나오는 위치가 일정합니다." },
  pickoff_rhythm: { title: "주자를 묶는 리듬", description: "주자가 있을 때도 투구 리듬을 지킵니다." },
  two_strike_plan: { title: "2스트라이크 승부법", description: "삼진을 잡기 위한 구종 순서를 미리 정합니다." },
  first_pitch_strike: { title: "초구 스트라이크", description: "유리한 카운트를 빠르게 만듭니다." },
  traffic_controller: { title: "주자를 두고도 침착하게", description: "주자가 여러 명 나가도 아웃 하나에 집중합니다." },
  late_inning_reserve: { title: "후반에도 남는 힘", description: "경기 후반에도 공의 위력이 덜 떨어집니다." },
  scout_composure: { title: "압박 속 침착함", description: "스카우트가 지켜봐도 평소처럼 던집니다." },
};

const MEMORY_LABELS: Record<MemoryCardID, { title: string; description: string }> = {
  velocity_blueprint: { title: "직구 구속 훈련법", description: "다음 선수는 직구 구속 훈련에 더 빨리 적응합니다." },
  fingertip_memory: { title: "손끝의 기억", description: "다음 삶의 변화구 학습을 앞당깁니다." },
  catcher_notebook: { title: "포수의 노트", description: "포수와 이야기하며 배운 타자 상대법을 남깁니다." },
  rival_notebook: { title: "라이벌 노트", description: "상대에게 읽힌 습관과 실패한 승부를 남깁니다." },
  recovery_routine: { title: "회복 방법", description: "언제 쉬고 얼마나 훈련해야 하는지 남깁니다." },
  pressure_rehearsal: { title: "압박의 예행연습", description: "중요 이닝의 감각을 다음 삶에 남깁니다." },
  first_pitch_map: { title: "초구 지도", description: "타자별 첫 승부의 단서를 남깁니다." },
  two_strike_sequence: { title: "2스트라이크 구종 순서", description: "삼진을 잡았던 구종 순서와 실패한 승부를 남깁니다." },
  fatigue_diary: { title: "피로 일지", description: "공의 힘이 떨어지기 시작한 시점을 남깁니다." },
  mechanics_video: { title: "투구 동작 교정 영상", description: "팔이 나오는 위치가 달라진 장면을 남깁니다." },
  school_playbook: { title: "학교에서 배운 승부법", description: "팀에서 배운 타자 상대법을 남깁니다." },
  coach_letter: { title: "코치의 편지", description: "성장 과정에 대한 코치의 관찰을 남깁니다." },
  draft_report: { title: "구단 평가표", description: "구단이 본 강점과 고쳐야 할 점을 남깁니다." },
  stadium_echo: { title: "구장의 메아리", description: "중요 경기의 감각을 다음 삶에 남깁니다." },
  team_first_promise: { title: "팀을 위한 약속", description: "관계에서 배운 책임을 남깁니다." },
  failure_scorebook: { title: "실패의 스코어북", description: "좋은 선택과 나쁜 결과를 구분해 남깁니다." },
  winter_program: { title: "겨울 훈련표", description: "비시즌에 효과가 좋았던 훈련 순서를 남깁니다." },
  bullpen_compass: { title: "불펜의 나침반", description: "등판 전 준비 순서를 남깁니다." },
};

const SOUL_OPTIONS: ReadonlyArray<{ value: SoulDomain; label: string; description: string }> = [
  { value: "body", label: "몸", description: "구속을 높이고 피로를 푸는 방법" },
  { value: "technique", label: "기술", description: "제구와 변화구를 익힌 방법" },
  { value: "game", label: "경기 경험", description: "위기에서 구종과 코스를 골랐던 경험" },
];

const METRIC_LABELS: Record<string, string> = {
  stuff: "공의 위력",
  command: "제구",
  movement: "변화구",
  stamina: "체력",
};

const GRADE_LABELS = {
  undrafted: "미지명 예상",
  follow: "더 지켜봄",
  draftable: "지명 가능",
  elite: "상위 순번 유력",
} as const;

const PHASE_LABELS = {
  training: "훈련",
  important_inning: "중요 이닝",
  relationship: "포수 면담",
  awakening: "새 강점",
  scouting: "구단 평가",
  reflection: "평가 결과",
  completed: "완료",
} as const;

interface PitcherLabViewProps {
  result: PitcherLabResult;
  previousLifeResult?: PitcherLabResult;
  isRunning: boolean;
  error?: string;
  onTrain: (focus: TrainingFocus, intensity: TrainingIntensity) => Promise<void>;
  onStartImportantInning: () => Promise<void>;
  onRelationship: (choice: RelationshipChoice) => Promise<void>;
  onAwakening: (awakening: AwakeningID) => Promise<void>;
  onFinalizeScouting: () => Promise<void>;
  onSelectLegacy: (domain: SoulDomain, memory: MemoryCardID) => Promise<void>;
  onStartSecondLife: () => Promise<void>;
  onNewExperiment: () => void;
}

function ratingValue(result: PitcherLabResult, metric: string) {
  const pitcher = result.snapshot.pitcher;
  switch (metric) {
    case "stuff": return pitcher.stuff;
    case "command": return pitcher.command;
    case "movement": return pitcher.movement;
    case "stamina": return pitcher.stamina;
    default: return 0;
  }
}

function trainingGrowthMetric(result: PitcherLabResult, focus: TrainingFocus) {
  const metric = focus === "velocity" ? "stuff"
    : focus === "breaking_ball" ? "movement"
      : focus === "stamina" || focus === "recovery" ? "stamina" : "command";
  return { label: METRIC_LABELS[metric], after: ratingValue(result, metric) };
}

export function PitcherLabView({
  result,
  previousLifeResult,
  isRunning,
  error,
  onTrain,
  onStartImportantInning,
  onRelationship,
  onAwakening,
  onFinalizeScouting,
  onSelectLegacy,
  onStartSecondLife,
  onNewExperiment,
}: PitcherLabViewProps) {
  const [focus, setFocus] = useState<TrainingFocus>("command");
  const [intensity, setIntensity] = useState<TrainingIntensity>("standard");
  const [soulDomain, setSoulDomain] = useState<SoulDomain>("technique");
  const firstMemory = result.snapshot.legacyOptions[0];
  const [memoryCard, setMemoryCard] = useState<MemoryCardID | undefined>(firstMemory);
  const selectedMemory = memoryCard ?? firstMemory;
  const snapshot = result.snapshot;
  const training = snapshot.lastTraining;
  const growthMetric = training ? trainingGrowthMetric(result, training.focus) : undefined;
  const [acknowledgedTraining, setAcknowledgedTraining] = useState(snapshot.trainingSessionsCompleted);
  const [acknowledgedRelationship, setAcknowledgedRelationship] = useState(snapshot.relationshipEventsCompleted);
  const [acknowledgedAwakening, setAcknowledgedAwakening] = useState(snapshot.selectedAwakenings.length);
  const resultRef = useRef<HTMLDivElement>(null);
  const pendingTraining = training && training.sessionNumber > acknowledgedTraining ? training : undefined;
  const relationshipEvent = result.events.find((event) => event.eventType === "catcher_relationship_changed");
  const pendingRelationship = snapshot.relationshipEventsCompleted > acknowledgedRelationship ? relationshipEvent?.relationshipChoice : undefined;
  const awakeningEvent = result.events.find((event) => event.eventType === "awakening_granted");
  const pendingAwakening = snapshot.selectedAwakenings.length > acknowledgedAwakening
    ? awakeningEvent?.awakening ?? snapshot.selectedAwakenings.at(-1)
    : undefined;
  const hasPendingResult = Boolean(pendingTraining || pendingRelationship || pendingAwakening);
  const selectedTraining = TRAINING_OPTIONS.find((option) => option.value === focus) ?? TRAINING_OPTIONS[0];
  const selectedIntensity = INTENSITY_OPTIONS.find((option) => option.value === intensity) ?? INTENSITY_OPTIONS[1];
  const forecast = labTrainingForecast(snapshot.fatigue, snapshot.readiness, focus, intensity);
  const pendingKey = pendingTraining ? `training:${pendingTraining.sessionNumber}`
    : pendingRelationship ? `relationship:${snapshot.relationshipEventsCompleted}`
      : pendingAwakening ? `awakening:${snapshot.selectedAwakenings.length}` : "";

  useEffect(() => {
    setAcknowledgedTraining(snapshot.trainingSessionsCompleted);
    setAcknowledgedRelationship(snapshot.relationshipEventsCompleted);
    setAcknowledgedAwakening(snapshot.selectedAwakenings.length);
  }, [snapshot.runID]);

  useEffect(() => {
    if (!pendingKey) return;
    const frame = window.requestAnimationFrame(() => {
      resultRef.current?.focus();
      resultRef.current?.scrollIntoView({
        behavior: document.body.classList.contains("reduce-motion") ? "auto" : "smooth",
        block: "center",
      });
    });
    return () => window.cancelAnimationFrame(frame);
  }, [pendingKey]);

  return (
    <main className="lab-shell stage-layout" data-stage={snapshot.phase}>
      <section className="lab-hero">
        <div>
          <p className="eyebrow">연습 모드 · {snapshot.lifeNumber}번째 선수</p>
          <h2>{snapshot.pitcher.name} · {snapshot.lifeNumber === 1 ? "첫 번째" : "두 번째"} 선수</h2>
          <p>현재 능력치는 정확히 보입니다. 어떤 훈련이 잘 맞는지는 직접 해 본 뒤 결과로 확인합니다.</p>
        </div>
        <div className="lab-hero-tools">
          <div className="lab-vitals">
            <div><span>훈련할 몸 상태</span><strong>{snapshot.readiness}</strong></div>
            <div><span>피로</span><strong>{snapshot.fatigue}</strong></div>
            <div><span>포수의 믿음</span><strong>{snapshot.catcherTrust}</strong></div>
          </div>
          <div className="lab-utility-actions"><button type="button" onClick={onNewExperiment}>새 선수</button></div>
        </div>
      </section>

      <section className="lab-progress" aria-label="연습 모드 진행 상황">
        <div>
          <span>훈련</span>
          <strong>{snapshot.trainingSessionsCompleted} / 6</strong>
          <div className="lab-progress-track"><i style={{ width: `${snapshot.trainingSessionsCompleted / 6 * 100}%` }} /></div>
        </div>
        <div>
          <span>중요 이닝</span>
          <strong>{snapshot.performance.importantInningsCompleted} / 3</strong>
          <div className="lab-progress-track"><i style={{ width: `${snapshot.performance.importantInningsCompleted / 3 * 100}%` }} /></div>
        </div>
        <div>
          <span>포수 면담</span>
          <strong>{snapshot.relationshipEventsCompleted} / 2</strong>
          <div className="lab-progress-track"><i style={{ width: `${snapshot.relationshipEventsCompleted / 2 * 100}%` }} /></div>
        </div>
        <div>
          <span>새 강점</span>
          <strong>{snapshot.selectedAwakenings.length} / 2</strong>
          <div className="lab-progress-track"><i style={{ width: `${snapshot.selectedAwakenings.length / 2 * 100}%` }} /></div>
        </div>
      </section>

      <a className="mobile-action-jump" href="#lab-current-action"><span>현재 단계</span><strong>{PHASE_LABELS[snapshot.phase]}</strong><small>바로 이동</small></a>

      <div className="lab-grid">
        <section className="ds-card ds-player-card lab-card lab-ratings">
          <div className="lab-card-heading"><span>현재 실력과 성장 가능성</span><small>훈련을 이어가면 얼마나 더 성장할지 알 수 있습니다</small></div>
          {snapshot.potentialRanges.map((range) => (
            <div className="potential-row" key={range.metric}>
              <span>{METRIC_LABELS[range.metric] ?? range.metric}</span>
              <strong>{ratingValue(result, range.metric)}</strong>
              <AbilityGauge label={METRIC_LABELS[range.metric] ?? range.metric} value={range.current}
                lowerBound={range.lowerBound} upperBound={range.upperBound} />
              <small>{range.lowerBound}–{range.upperBound}</small>
            </div>
          ))}
          <small className="rating-scale-note">20–80 평가 · 45 평균 · 65 뚜렷한 강점 · 80 세대 최고 · 포심 기준 {fourSeamVelocity(snapshot.pitcher)}</small>
          {training ? (
            <div className={`training-reaction training-reaction--${training.reaction}${training.ratingPointsGained > 0 ? " has-growth" : ""}`}>
              <span>최근 훈련 · {training.sessionNumber}회차</span>
              {growthMetric ? <GrowthCelebration compact label={growthMetric.label}
                before={growthMetric.after - training.ratingPointsGained} after={growthMetric.after} /> : null}
              <strong>{training.shortFeedback}</strong>
              <p>{training.observedClue}</p>
              <small>쌓인 훈련량 +{training.signalGained} · 몸 상태 {training.readinessBefore}→{training.readinessAfter} · 피로 {training.fatigueBefore}→{training.fatigueAfter}</small>
            </div>
          ) : null}
        </section>

        <section id="lab-current-action" className="ds-card ds-card--raised lab-card lab-action">
          <div className="lab-card-heading"><span>이번에 할 일</span><small>{PHASE_LABELS[snapshot.phase]}</small></div>

          {pendingTraining && growthMetric ? (
            <div ref={resultRef} className={`ds-card ds-card--result training-result-card ${pendingTraining.ratingPointsGained > 0 ? "ds-card--positive is-growth" : "is-steady"}`}
              tabIndex={-1} role="region" aria-live="polite" aria-labelledby="lab-training-result-heading">
              <div className="training-result-title"><span>훈련 {pendingTraining.sessionNumber}회차 완료</span><h3 id="lab-training-result-heading">{TRAINING_OPTIONS.find((option) => option.value === pendingTraining.focus)?.label ?? growthMetric.label} 결과</h3></div>
              <GrowthCelebration label={growthMetric.label} before={growthMetric.after - pendingTraining.ratingPointsGained} after={growthMetric.after} />
              <div className="ds-record-grid training-result-scoreboard">
                <div><span>{growthMetric.label}</span><strong>{growthMetric.after - pendingTraining.ratingPointsGained} <i aria-hidden="true">→</i> {growthMetric.after}</strong>
                  <AbilityGauge label={growthMetric.label} value={growthMetric.after} beforeValue={growthMetric.after - pendingTraining.ratingPointsGained} />
                  <small className={pendingTraining.ratingPointsGained > 0 ? "is-positive" : "is-neutral"}>{pendingTraining.ratingPointsGained > 0 ? `+${pendingTraining.ratingPointsGained} 성장` : "훈련량을 쌓음"}</small></div>
                <div><span>피로</span><strong>{pendingTraining.fatigueBefore} <i aria-hidden="true">→</i> {pendingTraining.fatigueAfter}</strong><small className={pendingTraining.fatigueAfter <= pendingTraining.fatigueBefore ? "is-positive" : "is-warning"}>{pendingTraining.fatigueAfter <= pendingTraining.fatigueBefore ? `${pendingTraining.fatigueBefore - pendingTraining.fatigueAfter} 회복` : `+${pendingTraining.fatigueAfter - pendingTraining.fatigueBefore} 쌓임`}</small></div>
                <div><span>몸 상태</span><strong>{pendingTraining.readinessBefore} <i aria-hidden="true">→</i> {pendingTraining.readinessAfter}</strong><small>{pendingTraining.observedClue}</small></div>
              </div>
              <p>{pendingTraining.shortFeedback}</p>
              <div className="training-result-next"><span>다음 일정</span><strong>{PHASE_LABELS[snapshot.phase]}</strong><small>결과를 확인한 뒤 다음 선택을 엽니다.</small></div>
              <button className="ds-button ds-button--primary lab-primary" type="button" onClick={() => setAcknowledgedTraining(pendingTraining.sessionNumber)}>결과 확인하고 계속</button>
            </div>
          ) : null}

          {pendingRelationship ? (
            <div ref={resultRef} className="ds-card ds-card--result training-result-card relationship-result-card" tabIndex={-1}
              role="region" aria-live="polite" aria-labelledby="lab-relationship-result-heading">
              <div className="training-result-title"><span>포수 면담 {snapshot.relationshipEventsCompleted}회차 완료</span><h3 id="lab-relationship-result-heading">엇갈린 사인을 다시 맞췄습니다.</h3></div>
              <div className="ds-record-grid training-result-scoreboard">
                <div><span>포수의 믿음</span><strong>{pendingRelationship === "trust_catcher" ? Math.max(0, snapshot.catcherTrust - 12) : Math.min(100, snapshot.catcherTrust + 7)} <i aria-hidden="true">→</i> {snapshot.catcherTrust}</strong>
                  <small className={pendingRelationship === "trust_catcher" ? "is-positive" : "is-negative"}>{pendingRelationship === "trust_catcher" ? "+12 · 포수의 관찰을 먼저 들음" : "−7 · 내 계획을 우선함"}</small></div>
              </div>
              <p>{pendingRelationship === "trust_catcher" ? "포수가 본 타자 반응을 먼저 확인해 다음 사인의 근거가 선명해졌습니다." : "내가 높은 공을 고른 근거를 분명히 했지만 포수와 다시 맞춰 볼 시간이 필요합니다."}</p>
              <button className="ds-button ds-button--primary lab-primary" type="button" onClick={() => setAcknowledgedRelationship(snapshot.relationshipEventsCompleted)}>결과 확인하고 다음 훈련</button>
            </div>
          ) : null}

          {pendingAwakening ? (
            <div ref={resultRef} className="ds-card ds-card--result training-result-card ds-card--positive" tabIndex={-1}
              role="region" aria-live="polite" aria-labelledby="lab-awakening-result-heading">
              <div className="training-result-title"><span>새 강점 {snapshot.selectedAwakenings.length}개째</span><h3 id="lab-awakening-result-heading">{AWAKENING_LABELS[pendingAwakening].title}</h3></div>
              <p>{AWAKENING_LABELS[pendingAwakening].description}</p>
              <div className="training-result-next"><span>다음 일정</span><strong>{PHASE_LABELS[snapshot.phase]}</strong><small>새 강점은 이번 선수의 남은 일정에 계속 적용됩니다.</small></div>
              <button className="ds-button ds-button--primary lab-primary" type="button" onClick={() => setAcknowledgedAwakening(snapshot.selectedAwakenings.length)}>강점 확인하고 계속</button>
            </div>
          ) : null}

          {!hasPendingResult && snapshot.phase === "training" ? (
            <>
              <h3>훈련 {snapshot.trainingSessionsCompleted + 1}회차</h3>
              <p className="lab-copy">같은 훈련을 계속하면 처음에는 빨리 늘지만, 곧 효과가 줄고 피로가 쌓입니다.</p>
              <div className="training-option-grid">
                {TRAINING_OPTIONS.map((option) => (
                  <button key={option.value} type="button" className={focus === option.value ? "is-selected" : undefined}
                    aria-pressed={focus === option.value} onClick={() => setFocus(option.value)}>
                    <strong>{option.label}</strong><span>{option.description}</span>
                  </button>
                ))}
              </div>
              <div className="training-intensity-grid">
                {INTENSITY_OPTIONS.map((option) => (
                  <button key={option.value} type="button" className={intensity === option.value ? "is-selected" : undefined}
                    aria-pressed={intensity === option.value} onClick={() => setIntensity(option.value)}>
                    <strong>{option.label}</strong><span>{option.description}</span>
                  </button>
                ))}
              </div>
              <div className="training-preview" aria-live="polite">
                <div><span>선택한 훈련</span><strong>{selectedTraining.label} · {selectedIntensity.label}</strong></div>
                <div><span>능력치 성장 가능성</span><strong>{forecast.growthChance}{training?.focus === focus ? " · 반복 효과 변동" : ""}</strong></div>
                <div><span>훈련 뒤 예상 피로</span><strong>{snapshot.fatigue} → {forecast.fatigueLow === forecast.fatigueHigh ? forecast.fatigueHigh : `${forecast.fatigueLow}–${forecast.fatigueHigh}`}</strong></div>
                <div><span>훈련 뒤 몸 상태</span><strong>{snapshot.readiness} → {forecast.readinessAfter}</strong></div>
                <p>능력 상승은 지금까지 쌓인 훈련량, 숨은 적성, 피로와 변동값에 따라 0일 수도 있습니다.</p>
              </div>
              <button className="ds-button ds-button--primary lab-primary" type="button" disabled={isRunning} onClick={() => void onTrain(focus, intensity)}>
                {isRunning ? "훈련 결과 계산 중…" : "이 훈련 확정"}
              </button>
            </>
          ) : null}

          {!hasPendingResult && snapshot.phase === "important_inning" ? (
            <div className="lab-milestone">
              <span>중요 이닝 {snapshot.performance.importantInningsCompleted + 1}</span>
              <h3>{snapshot.performance.importantInningsCompleted === 0 ? "자신의 공을 확인할 첫 등판" : snapshot.performance.importantInningsCompleted === 1 ? "주자와 피로가 겹친 위기" : "라이벌 재대결과 스카우트 관전"}</h3>
              <p>직접 구종과 코스를 골라 이번 훈련 뒤 공이 어떻게 달라졌는지 확인합니다.</p>
              <button className="ds-button ds-button--primary lab-primary" type="button" disabled={isRunning} onClick={() => void onStartImportantInning()}>
                중요 이닝 시작
              </button>
            </div>
          ) : null}

          {!hasPendingResult && snapshot.phase === "relationship" ? (
            <div className="lab-milestone">
              <span>포수 면담 {snapshot.relationshipEventsCompleted + 1}</span>
              <h3>오늘 엇갈린 사인을 다시 맞춰 봅니다.</h3>
              <p>유시환: “낮은 변화구가 더 안전했어. 그런데 넌 왜 계속 높은 공을 골랐어?”</p>
              <div className="lab-choice-pair">
                <button type="button" disabled={isRunning} onClick={() => void onRelationship("trust_catcher")}>
                  <strong>유시환이 본 타자 반응부터 듣는다</strong><span>포수가 나를 더 믿는다</span>
                </button>
                <button type="button" disabled={isRunning} onClick={() => void onRelationship("assert_own_plan")}>
                  <strong>높은 공을 고른 이유를 설명한다</strong><span>내 판단을 분명히 한다</span>
                </button>
              </div>
            </div>
          ) : null}

          {!hasPendingResult && snapshot.phase === "awakening" ? (
            <div className="lab-milestone">
              <span>새 강점 {snapshot.selectedAwakenings.length + 1}</span>
              <h3>반복해 온 훈련에서 한 가지 강점이 드러났습니다.</h3>
              <div className="lab-choice-pair">
                {snapshot.awakeningOptions.map((awakening) => (
                  <button key={awakening} type="button" disabled={isRunning} onClick={() => void onAwakening(awakening)}>
                    <strong>{AWAKENING_LABELS[awakening].title}</strong>
                    <span>{AWAKENING_LABELS[awakening].description}</span>
                  </button>
                ))}
              </div>
            </div>
          ) : null}

          {!hasPendingResult && snapshot.phase === "scouting" ? (
            <div className="lab-milestone">
              <span>최종 구단 평가</span>
              <h3>스카우트가 세 번의 등판 기록을 확인합니다.</h3>
              <p>현재 능력과 삼진·볼넷·실점, 훈련 뒤 달라진 점을 함께 봅니다.</p>
              <button className="ds-button ds-button--primary lab-primary" type="button" disabled={isRunning} onClick={() => void onFinalizeScouting()}>
                구단 평가 결과 보기
              </button>
            </div>
          ) : null}

          {!hasPendingResult && snapshot.phase === "reflection" && snapshot.scoutingEvaluation ? (
            <div className="lab-reflection">
              <span className={`scouting-grade scouting-grade--${snapshot.scoutingEvaluation.grade}`}>
                {GRADE_LABELS[snapshot.scoutingEvaluation.grade]} · {snapshot.scoutingEvaluation.score}
              </span>
              <h3>{snapshot.scoutingEvaluation.summary}</h3>
              <div className="scouting-columns">
                <div><span>강점</span>{snapshot.scoutingEvaluation.strengths.map((item) => <strong key={item}>{item}</strong>)}</div>
                <div><span>우려</span>{snapshot.scoutingEvaluation.concerns.map((item) => <strong key={item}>{item}</strong>)}</div>
              </div>
              <h4>다음 선수에게 남길 경험</h4>
              <div className="soul-options">
                {SOUL_OPTIONS.map((option) => (
                  <button key={option.value} type="button" className={soulDomain === option.value ? "is-selected" : undefined}
                    aria-pressed={soulDomain === option.value} onClick={() => setSoulDomain(option.value)}>
                    <strong>{option.label}</strong><span>{option.description}</span>
                  </button>
                ))}
              </div>
              <h4>기억 카드 1장</h4>
              <div className="lab-choice-pair">
                {snapshot.legacyOptions.map((memory) => (
                  <button key={memory} type="button" className={selectedMemory === memory ? "is-selected" : undefined}
                    aria-pressed={selectedMemory === memory} onClick={() => setMemoryCard(memory)}>
                    <strong>{MEMORY_LABELS[memory].title}</strong><span>{MEMORY_LABELS[memory].description}</span>
                  </button>
                ))}
              </div>
              <button className="ds-button ds-button--primary lab-primary" type="button" disabled={isRunning || !selectedMemory}
                onClick={() => selectedMemory ? void onSelectLegacy(soulDomain, selectedMemory) : undefined}>
                이 경험을 다음 삶에 남기기
              </button>
            </div>
          ) : null}

          {!hasPendingResult && snapshot.phase === "completed" && snapshot.legacySelection ? (
            <div className="lab-milestone lab-completed">
              <span>{snapshot.lifeNumber}번째 선수 기록 완료</span>
              <h3>{snapshot.lifeNumber === 1 ? "첫 번째 선수의 구단 평가가 끝났습니다." : "두 번째 선수의 구단 평가도 끝났습니다."}</h3>
              <p>{snapshot.legacySelection.summary}</p>
              <div className="legacy-reward">
                <strong>다음 선수 능력치 점수 +{snapshot.legacySelection.soulPointsGranted}</strong>
                <span>{MEMORY_LABELS[snapshot.legacySelection.memoryCard].title}</span>
                <span>새 학교·코치 후보 해금</span>
              </div>
              {snapshot.lifeNumber === 1 ? (
                <button className="ds-button ds-button--primary lab-primary" type="button" disabled={isRunning} onClick={() => void onStartSecondLife()}>
                  두 번째 삶 시작
                </button>
              ) : previousLifeResult ? (
                <div className="life-comparison" aria-label="첫 번째 선수와 두 번째 선수 비교">
                  <h4>두 선수의 최종 비교</h4>
                  {(["stuff", "command", "movement", "stamina"] as const).map((metric) => (
                    <div key={metric}>
                      <span>{METRIC_LABELS[metric]}</span>
                      <strong>{previousLifeResult.snapshot.pitcher[metric]} → {snapshot.pitcher[metric]}</strong>
                      <b>{snapshot.pitcher[metric] - previousLifeResult.snapshot.pitcher[metric] >= 0 ? "+" : ""}{snapshot.pitcher[metric] - previousLifeResult.snapshot.pitcher[metric]}</b>
                    </div>
                  ))}
                  <div><span>구단 평가 점수</span><strong>{previousLifeResult.snapshot.scoutingEvaluation?.score ?? 0} → {snapshot.scoutingEvaluation?.score ?? 0}</strong></div>
                  <div><span>예상 출루·장타 위험</span><strong>{previousLifeResult.snapshot.performance.expectedDamage} → {snapshot.performance.expectedDamage}</strong></div>
                </div>
              ) : null}
            </div>
          ) : null}

          {error ? <p className="error-message" role="alert">{error}</p> : null}
        </section>

        <aside className="ds-card ds-record-grid lab-card lab-log">
          <div className="lab-card-heading"><span>선수 기록</span><small>자동 저장됨</small></div>
          <div className="lab-log-stats">
            <div><span>투구</span><strong>{snapshot.performance.pitches}</strong></div>
            <div><span>삼진</span><strong>{snapshot.performance.strikeouts}</strong></div>
            <div><span>볼넷</span><strong>{snapshot.performance.walks}</strong></div>
            <div><span>실점</span><strong>{snapshot.performance.runsAllowed}</strong></div>
          </div>
          <div className="lab-signal-list" aria-label="능력별 쌓인 훈련량">
            {TRAINING_OPTIONS.map((option) => {
              const key = option.value === "breaking_ball" ? "breakingBall" : option.value === "game_planning" ? "gamePlanning" : option.value;
              const value = snapshot.developmentSignals[key as keyof typeof snapshot.developmentSignals];
              return (
                <div key={option.value}>
                  <span>{option.label} 훈련량</span><strong>{value} / 500</strong>
                  <i><b style={{ width: `${value / 5}%` }} /></i>
                </div>
              );
            })}
          </div>
          {snapshot.selectedAwakenings.length > 0 ? (
            <div className="awakening-list">
                <span>익힌 강점</span>
              {snapshot.selectedAwakenings.map((awakening) => (
                <strong key={awakening}>{AWAKENING_LABELS[awakening].title}</strong>
              ))}
            </div>
          ) : null}
        </aside>
      </div>
    </main>
  );
}
