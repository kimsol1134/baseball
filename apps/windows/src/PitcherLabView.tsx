import { useState } from "react";
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
import { downloadPitcherLabAnalysis } from "./pitcherLabAutosave";

const CREATION_METRICS: ReadonlyArray<{
  key: keyof CreationAllocationSnapshot;
  label: string;
  description: string;
}> = [
  { key: "stuff", label: "구위", description: "출력과 포심 구속" },
  { key: "command", label: "커맨드", description: "목표점과 경계 재현" },
  { key: "movement", label: "무브먼트", description: "변화구 궤적과 헛스윙" },
  { key: "stamina", label: "체력", description: "긴 이닝과 피로 저항" },
];

interface PitcherLabSetupProps {
  presets: ReadonlyArray<PitcherPresetSnapshot>;
  isRunning: boolean;
  error?: string;
  onStart: (presetID: string, allocation: CreationAllocationSnapshot) => Promise<void>;
}

export function PitcherLabSetup({ presets, isRunning, error, onStart }: PitcherLabSetupProps) {
  const [presetID, setPresetID] = useState(presets[0]?.id ?? "");
  const [allocation, setAllocation] = useState<CreationAllocationSnapshot>({
    stuff: 2,
    command: 1,
    movement: 1,
    stamina: 1,
  });
  const effectivePresetID = presetID || presets[0]?.id || "";
  const selectedPreset = presets.find((preset) => preset.id === effectivePresetID) ?? presets[0];
  const spent = Object.values(allocation).reduce((sum, value) => sum + value, 0);

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
        <p className="eyebrow">NEW PITCHER</p>
        <h2>어떤 투수로 시작할까요?</h2>
        <p>강점과 약점이 다른 네 유형 중 하나를 고른 뒤, 추가 능력 5점을 나눠 주세요.</p>
      </section>
      <section className="preset-creation-grid" aria-label="투수 프리셋 선택">
        {presets.map((preset) => (
          <button key={preset.id} type="button" className={effectivePresetID === preset.id ? "is-selected" : undefined}
            aria-pressed={effectivePresetID === preset.id} onClick={() => setPresetID(preset.id)}>
            <span>{preset.name}</span>
            <strong>{preset.pitcher.name}</strong>
            <p>{preset.tagline}</p>
            <small>{preset.strengths.join(" · ")}</small>
          </button>
        ))}
      </section>
      {selectedPreset ? (
        <section className="creation-allocation">
          <div className="creation-summary">
            <div>
              <span>선택한 선수 유형</span>
              <strong>{selectedPreset.name} · {selectedPreset.pitcher.name}</strong>
              <p>{selectedPreset.tradeoff}</p>
            </div>
            <div className="creation-points"><span>남은 생성 포인트</span><strong>{5 - spent}</strong></div>
          </div>
          <div className="allocation-grid">
            {CREATION_METRICS.map((metric) => (
              <div key={metric.key}>
                <span>{metric.label}</span>
                <small>{metric.description}</small>
                <div>
                  <button type="button" aria-label={`${metric.label} 1 감소`} disabled={allocation[metric.key] === 0}
                    onClick={() => changeAllocation(metric.key, -1)}>−</button>
                  <strong>{allocation[metric.key]}</strong>
                  <button type="button" aria-label={`${metric.label} 1 증가`} disabled={spent >= 5 || allocation[metric.key] === 5}
                    onClick={() => changeAllocation(metric.key, 1)}>+</button>
                </div>
              </div>
            ))}
          </div>
          <button className="lab-primary" type="button" disabled={isRunning || spent !== 5}
            onClick={() => void onStart(selectedPreset.id, allocation)}>
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
  { value: "velocity", label: "구속·출력", description: "포심 구위와 최고 구속을 높인다" },
  { value: "command", label: "제구·커맨드", description: "목표점 재현과 경계 공략을 다듬는다" },
  { value: "breaking_ball", label: "변화구 형태", description: "변화량과 헛스윙 능력을 높인다" },
  { value: "stamina", label: "선발 체력", description: "긴 이닝에도 구위를 유지하도록 훈련한다" },
  { value: "recovery", label: "회복 루틴", description: "피로를 낮추고 다음 훈련 준비도 회복" },
  { value: "game_planning", label: "경기 설계", description: "카운트별 구종 순서와 상대 대응을 익힌다" },
];

const INTENSITY_OPTIONS: ReadonlyArray<{
  value: TrainingIntensity;
  label: string;
  description: string;
}> = [
  { value: "light", label: "가볍게", description: "피로를 아끼며 감각 유지" },
  { value: "standard", label: "표준", description: "성장과 회복의 균형" },
  { value: "intensive", label: "집중", description: "큰 자극, 높은 피로 비용" },
];

const AWAKENING_LABELS: Record<AwakeningID, { title: string; description: string }> = {
  explosive_fastball: { title: "폭발하는 포심", description: "구위와 포심 출력이 크게 선명해집니다." },
  pinpoint_edge: { title: "바늘끝 경계", description: "ABS 경계를 반복하는 커맨드를 얻습니다." },
  disappearing_breaker: { title: "사라지는 궤적", description: "변화구의 움직임과 결정력이 강화됩니다." },
  iron_arm: { title: "강철의 어깨", description: "긴 이닝에도 구위를 지키는 체력을 얻습니다." },
  calm_under_pressure: { title: "고요한 마운드", description: "위기에서도 계획을 실행하는 힘을 얻습니다." },
  battery_sync: { title: "배터리 동기화", description: "포수의 정보와 자신의 감각을 빠르게 합칩니다." },
  rising_four_seam: { title: "떠오르는 포심", description: "높은 존 포심의 형태를 강화합니다." },
  sinker_tunnel: { title: "싱커 터널", description: "포심과 변화구의 출발 궤적을 겹칩니다." },
  frozen_changeup: { title: "멈춘 체인지업", description: "속도 차이와 낙폭을 선명하게 만듭니다." },
  sweeping_slider: { title: "스위퍼 궤도", description: "슬라이더의 수평 움직임을 키웁니다." },
  curveball_clock: { title: "커브의 시계", description: "커브의 릴리스 타이밍을 반복합니다." },
  repeatable_release: { title: "반복되는 릴리스", description: "모든 구종의 출발점을 안정시킵니다." },
  pickoff_rhythm: { title: "주자를 묶는 리듬", description: "주자가 있을 때도 투구 리듬을 지킵니다." },
  two_strike_plan: { title: "2스트라이크 설계", description: "결정구 순서를 미리 설계합니다." },
  first_pitch_strike: { title: "초구 스트라이크", description: "유리한 카운트를 빠르게 만듭니다." },
  traffic_controller: { title: "주자 교통정리", description: "복잡한 주자 상황을 단순화합니다." },
  late_inning_reserve: { title: "후반 이닝의 여력", description: "경기 후반의 구위 저하를 늦춥니다." },
  scout_composure: { title: "스카우트 앞의 평정", description: "높은 압박에서도 계획을 유지합니다." },
};

const MEMORY_LABELS: Record<MemoryCardID, { title: string; description: string }> = {
  velocity_blueprint: { title: "구속의 설계도", description: "다음 삶이 출력 훈련의 감각을 가지고 시작합니다." },
  fingertip_memory: { title: "손끝의 기억", description: "다음 삶의 변화구 학습을 앞당깁니다." },
  catcher_notebook: { title: "포수의 노트", description: "배터리의 대화에서 얻은 정보를 남깁니다." },
  rival_notebook: { title: "라이벌 노트", description: "반복 패턴과 실패의 단서를 다음 삶에 남깁니다." },
  recovery_routine: { title: "회복 루틴", description: "피로를 관리한 시행착오를 다음 몸에 남깁니다." },
  pressure_rehearsal: { title: "압박의 예행연습", description: "중요 이닝의 감각을 다음 삶에 남깁니다." },
  first_pitch_map: { title: "초구 지도", description: "타자별 첫 승부의 단서를 남깁니다." },
  two_strike_sequence: { title: "2스트라이크 시퀀스", description: "결정구 순서의 시행착오를 남깁니다." },
  fatigue_diary: { title: "피로 일지", description: "구위가 떨어진 시점의 기록을 남깁니다." },
  mechanics_video: { title: "폼 교정 영상", description: "릴리스 변화의 영상을 남깁니다." },
  school_playbook: { title: "학교 플레이북", description: "팀에서 배운 경기 운영을 남깁니다." },
  coach_letter: { title: "코치의 편지", description: "성장 과정에 대한 코치의 관찰을 남깁니다." },
  draft_report: { title: "드래프트 리포트", description: "구단이 본 강점과 우려를 남깁니다." },
  stadium_echo: { title: "구장의 메아리", description: "중요 경기의 감각을 다음 삶에 남깁니다." },
  team_first_promise: { title: "팀을 위한 약속", description: "관계에서 배운 책임을 남깁니다." },
  failure_scorebook: { title: "실패의 스코어북", description: "좋은 선택과 나쁜 결과를 구분해 남깁니다." },
  winter_program: { title: "겨울 프로그램", description: "비시즌 루틴을 다음 몸에 남깁니다." },
  bullpen_compass: { title: "불펜의 나침반", description: "등판 전 준비 순서를 남깁니다." },
};

const SOUL_OPTIONS: ReadonlyArray<{ value: SoulDomain; label: string; description: string }> = [
  { value: "body", label: "육체", description: "출력과 회복의 경험" },
  { value: "technique", label: "기술", description: "제구와 구종 학습의 경험" },
  { value: "game", label: "경기", description: "판단과 압박 대응의 경험" },
];

const METRIC_LABELS: Record<string, string> = {
  stuff: "구위",
  command: "커맨드",
  movement: "무브먼트",
  stamina: "체력",
};

const GRADE_LABELS = {
  undrafted: "미지명",
  follow: "추적 관찰",
  draftable: "지명권",
  elite: "상위 지명",
} as const;

const PHASE_LABELS = {
  training: "훈련",
  important_inning: "중요 이닝",
  relationship: "포수 면담",
  awakening: "새 강점",
  scouting: "스카우팅",
  reflection: "스카우팅 결과",
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

  return (
    <main className="lab-shell">
      <section className="lab-hero">
        <div>
          <p className="eyebrow">PITCHER LAB · LIFE {snapshot.lifeNumber}</p>
          <h2>{snapshot.pitcher.name} · {snapshot.lifeNumber === 1 ? "첫 번째" : "두 번째"} 선수</h2>
          <p>현재 능력은 정확히 보입니다. 어떤 훈련이 잘 맞는지는 직접 훈련한 뒤 반응을 확인해야 합니다.</p>
        </div>
        <div className="lab-hero-tools">
          <div className="lab-vitals">
            <div><span>준비도</span><strong>{snapshot.readiness}</strong></div>
            <div><span>피로</span><strong>{snapshot.fatigue}</strong></div>
            <div><span>포수 신뢰</span><strong>{snapshot.catcherTrust}</strong></div>
          </div>
          <div className="lab-utility-actions">
            <button type="button" onClick={() => downloadPitcherLabAnalysis(result)}>분석 JSON 내보내기</button>
            <button type="button" onClick={onNewExperiment}>새 선수</button>
          </div>
        </div>
      </section>

      <section className="lab-progress" aria-label="Pitcher Lab 진행 상황">
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

      <div className="lab-grid">
        <section className="lab-card lab-ratings">
          <div className="lab-card-heading"><span>현재 능력과 잠재 범위</span><small>훈련할수록 예상 범위가 좁아집니다</small></div>
          {snapshot.potentialRanges.map((range) => (
            <div className="potential-row" key={range.metric}>
              <span>{METRIC_LABELS[range.metric] ?? range.metric}</span>
              <strong>{ratingValue(result, range.metric)}</strong>
              <div className="potential-track" aria-label={`${range.lowerBound}에서 ${range.upperBound} 사이`}>
                <i style={{ left: `${range.lowerBound}%`, width: `${Math.max(2, range.upperBound - range.lowerBound)}%` }} />
                <b style={{ left: `${range.current}%` }} />
              </div>
              <small>{range.lowerBound}–{range.upperBound}</small>
            </div>
          ))}
          {training ? (
            <div className={`training-reaction training-reaction--${training.reaction}`}>
              <span>최근 훈련 · {training.sessionNumber}회차</span>
              <strong>{training.shortFeedback}</strong>
              <p>{training.observedClue}</p>
              <small>훈련 누적 +{training.signalGained} · 준비도 {training.readinessBefore}→{training.readinessAfter} · 피로 {training.fatigueBefore}→{training.fatigueAfter}</small>
            </div>
          ) : null}
        </section>

        <section className="lab-card lab-action">
          <div className="lab-card-heading"><span>다음 결정</span><small>{PHASE_LABELS[snapshot.phase]}</small></div>

          {snapshot.phase === "training" ? (
            <>
              <h3>훈련 {snapshot.trainingSessionsCompleted + 1}회차</h3>
              <p className="lab-copy">같은 훈련의 반복은 초기에 유리하지만 정체와 피로를 만들 수 있습니다.</p>
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
              <button className="lab-primary" type="button" disabled={isRunning} onClick={() => void onTrain(focus, intensity)}>
                {isRunning ? "훈련 결과 계산 중…" : "이 훈련 확정"}
              </button>
            </>
          ) : null}

          {snapshot.phase === "important_inning" ? (
            <div className="lab-milestone">
              <span>IMPORTANT INNING {snapshot.performance.importantInningsCompleted + 1}</span>
              <h3>{snapshot.performance.importantInningsCompleted === 0 ? "자신의 공을 확인할 첫 등판" : snapshot.performance.importantInningsCompleted === 1 ? "주자와 피로가 겹친 위기" : "라이벌 재대결과 스카우트 관전"}</h3>
              <p>직접 구종과 코스를 골라 이번 훈련 뒤 공이 어떻게 달라졌는지 확인합니다.</p>
              <button className="lab-primary" type="button" disabled={isRunning} onClick={() => void onStartImportantInning()}>
                중요 이닝 시작
              </button>
            </div>
          ) : null}

          {snapshot.phase === "relationship" ? (
            <div className="lab-milestone">
              <span>BATTERY TALK {snapshot.relationshipEventsCompleted + 1}</span>
              <h3>오늘 엇갈린 사인을 다시 맞춰 봅니다.</h3>
              <p>강민준: “낮은 변화구가 더 안전했어. 그런데 넌 왜 계속 높은 공을 골랐어?”</p>
              <div className="lab-choice-pair">
                <button type="button" disabled={isRunning} onClick={() => void onRelationship("trust_catcher")}>
                  <strong>강민준이 본 타자 반응부터 듣는다</strong><span>포수 신뢰가 오른다</span>
                </button>
                <button type="button" disabled={isRunning} onClick={() => void onRelationship("assert_own_plan")}>
                  <strong>높은 공을 고른 이유를 설명한다</strong><span>내 판단을 분명히 한다</span>
                </button>
              </div>
            </div>
          ) : null}

          {snapshot.phase === "awakening" ? (
            <div className="lab-milestone">
              <span>AWAKENING {snapshot.selectedAwakenings.length + 1}</span>
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

          {snapshot.phase === "scouting" ? (
            <div className="lab-milestone">
              <span>FINAL SCOUTING</span>
              <h3>스카우트가 세 번의 등판 기록을 펼칩니다.</h3>
              <p>현재 능력과 삼진·볼넷·실점, 훈련 뒤 달라진 점을 함께 평가합니다.</p>
              <button className="lab-primary" type="button" disabled={isRunning} onClick={() => void onFinalizeScouting()}>
                최종 스카우팅 리포트 받기
              </button>
            </div>
          ) : null}

          {snapshot.phase === "reflection" && snapshot.scoutingEvaluation ? (
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
              <button className="lab-primary" type="button" disabled={isRunning || !selectedMemory}
                onClick={() => selectedMemory ? void onSelectLegacy(soulDomain, selectedMemory) : undefined}>
                이 경험을 다음 삶에 남기기
              </button>
            </div>
          ) : null}

          {snapshot.phase === "completed" && snapshot.legacySelection ? (
            <div className="lab-milestone lab-completed">
              <span>LIFE {snapshot.lifeNumber} COMPLETE</span>
              <h3>{snapshot.lifeNumber === 1 ? "첫 번째 선수의 스카우팅이 끝났습니다." : "두 번째 선수의 스카우팅도 끝났습니다."}</h3>
              <p>{snapshot.legacySelection.summary}</p>
              <div className="legacy-reward">
                <strong>생성 포인트 +{snapshot.legacySelection.soulPointsGranted}</strong>
                <span>{MEMORY_LABELS[snapshot.legacySelection.memoryCard].title}</span>
                <span>새 학교·코치 후보 해금</span>
              </div>
              {snapshot.lifeNumber === 1 ? (
                <button className="lab-primary" type="button" disabled={isRunning} onClick={() => void onStartSecondLife()}>
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
                  <div><span>스카우팅</span><strong>{previousLifeResult.snapshot.scoutingEvaluation?.score ?? 0} → {snapshot.scoutingEvaluation?.score ?? 0}</strong></div>
                  <div><span>기대 피해</span><strong>{previousLifeResult.snapshot.performance.expectedDamage} → {snapshot.performance.expectedDamage}</strong></div>
                </div>
              ) : null}
            </div>
          ) : null}

          {error ? <p className="error-message" role="alert">{error}</p> : null}
        </section>

        <aside className="lab-card lab-log">
          <div className="lab-card-heading"><span>선수 기록</span><small>자동 저장됨</small></div>
          <div className="lab-log-stats">
            <div><span>투구</span><strong>{snapshot.performance.pitches}</strong></div>
            <div><span>삼진</span><strong>{snapshot.performance.strikeouts}</strong></div>
            <div><span>볼넷</span><strong>{snapshot.performance.walks}</strong></div>
            <div><span>실점</span><strong>{snapshot.performance.runsAllowed}</strong></div>
          </div>
          <div className="lab-signal-list">
            {TRAINING_OPTIONS.map((option) => {
              const key = option.value === "breaking_ball" ? "breakingBall" : option.value === "game_planning" ? "gamePlanning" : option.value;
              const value = snapshot.developmentSignals[key as keyof typeof snapshot.developmentSignals];
              return (
                <div key={option.value}>
                  <span>{option.label}</span><strong>{value} / 500</strong>
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
          <code>{result.eventHash}</code>
        </aside>
      </div>
    </main>
  );
}
