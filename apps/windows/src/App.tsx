import { useCallback, useEffect, useState } from "react";
import {
  checkCoreHealth,
  listPitcherPresets,
  preparePitch,
  submitPitch,
} from "./simulationClient";
import type {
  BatterScoutingSnapshot,
  BatterSnapshot,
  CatcherRecommendationSnapshot,
  HealthResult,
  PitchIntensity,
  PitchKernelResult,
  PitchOutcome,
  PitchPreparation,
  PitchProfileSnapshot,
  PitchType,
  PitcherPresetSnapshot,
  PitchZone,
  PlateAppearanceContext,
  PlateAppearanceResult,
  SelectionQuality,
  ZoneIntent,
} from "./simulationTypes";

const BATTER: BatterSnapshot = {
  id: "batter-1",
  name: "이준호",
  contact: 56,
  discipline: 52,
  power: 58,
};

const SCOUTING: BatterScoutingSnapshot = {
  hotZone: { row: 1, column: 1 },
  coldZone: { row: 2, column: 0 },
  pitchStrength: "four_seam",
  pitchWeakness: "slider",
  chaseTendency: 48,
};

const INITIAL_SEED = "20260721";
const INITIAL_CONTEXT: PlateAppearanceContext = {
  plateAppearanceID: "pa-prototype-1",
  revision: 0,
  inning: 7,
  outs: 0,
  balls: 0,
  strikes: 0,
  pitchNumber: 1,
  scoreDifferential: 0,
  leverage: 600,
  fatigue: 12,
};

const PITCH_OPTIONS: ReadonlyArray<{
  value: PitchType;
  label: string;
}> = [
  { value: "four_seam", label: "포심" },
  { value: "slider", label: "슬라이더" },
  { value: "curveball", label: "커브" },
  { value: "changeup", label: "체인지업" },
];

const INTENSITY_OPTIONS: ReadonlyArray<{
  value: PitchIntensity;
  label: string;
  hint: string;
}> = [
  { value: "controlled", label: "제어", hint: "제구 우선" },
  { value: "normal", label: "보통", hint: "균형" },
  { value: "max_effort", label: "전력", hint: "구위 우선" },
];

const INTENT_OPTIONS: ReadonlyArray<{
  value: ZoneIntent;
  label: string;
  hint: string;
}> = [
  { value: "strike", label: "존 안", hint: "볼넷 억제" },
  { value: "edge", label: "경계", hint: "정교한 승부" },
  { value: "chase", label: "유인", hint: "헛스윙 노림" },
];

const OUTCOME_LABELS: Record<PitchOutcome, string> = {
  ball: "볼",
  called_strike: "루킹 스트라이크",
  swinging_strike: "헛스윙",
  foul: "파울",
  in_play_out: "인플레이 아웃",
  single: "안타",
  double: "2루타",
  home_run: "홈런",
};

const SELECTION_LABELS: Record<SelectionQuality, string> = {
  poor: "나쁜 선택",
  risky: "위험한 선택",
  good: "좋은 선택",
  excellent: "탁월한 선택",
};

const PLATE_RESULT_LABELS: Record<PlateAppearanceResult, string> = {
  strikeout: "삼진",
  walk: "볼넷",
  in_play_out: "범타",
  hit: "출루 허용",
};

const ZONE_LABELS = [
  "높은 몸쪽",
  "높은 가운데",
  "높은 바깥쪽",
  "가운데 몸쪽",
  "가운데",
  "가운데 바깥쪽",
  "낮은 몸쪽",
  "낮은 가운데",
  "낮은 바깥쪽",
] as const;

type CoreStatus =
  | { state: "checking" }
  | { state: "online"; health: HealthResult }
  | { state: "offline"; message: string };

interface HistoryItem {
  eventHash: string;
  outcome: PitchOutcome;
  count: string;
}

function StatRow({ label, value }: { label: string; value: number }) {
  return (
    <div className="stat-row">
      <span>{label}</span>
      <div className="stat-track" aria-hidden="true">
        <span style={{ width: `${((value - 20) / 60) * 100}%` }} />
      </div>
      <strong>{value}</strong>
    </div>
  );
}

function statusMessage(status: CoreStatus) {
  switch (status.state) {
    case "checking":
      return "코어 확인 중";
    case "online":
      return `코어 ${status.health.coreVersion} 연결됨`;
    case "offline":
      return "코어 연결 필요";
  }
}

function outcomeTone(outcome: PitchOutcome) {
  switch (outcome) {
    case "called_strike":
    case "swinging_strike":
    case "in_play_out":
      return "positive";
    case "ball":
    case "foul":
      return "neutral";
    case "single":
    case "double":
    case "home_run":
      return "negative";
  }
}

function pitchLabel(pitchType: PitchType) {
  return PITCH_OPTIONS.find((option) => option.value === pitchType)?.label ?? pitchType;
}

function zoneLabel(zone: PitchZone) {
  return ZONE_LABELS[zone.row * 3 + zone.column] ?? "알 수 없는 코스";
}

function intentLabel(intent: ZoneIntent) {
  return INTENT_OPTIONS.find((option) => option.value === intent)?.label ?? intent;
}

function recommendationTitle(recommendation: CatcherRecommendationSnapshot) {
  return `${zoneLabel(recommendation.call.zone)} ${pitchLabel(recommendation.call.pitchType)} · ${intentLabel(recommendation.call.zoneIntent)}`;
}

function roleLabel(profile: PitchProfileSnapshot) {
  switch (profile.role) {
    case "primary": return "주력";
    case "secondary": return "보조";
    case "development": return "개발 중";
  }
}

function pitchHint(profile?: PitchProfileSnapshot) {
  if (!profile) return "프로필 없음";
  return `${roleLabel(profile)} · ${(profile.velocityTenthsKPH / 10).toFixed(0)} km/h`;
}

export function App() {
  const [coreStatus, setCoreStatus] = useState<CoreStatus>({ state: "checking" });
  const [presets, setPresets] = useState<ReadonlyArray<PitcherPresetSnapshot>>([]);
  const [selectedPresetID, setSelectedPresetID] = useState<string>();
  const [pitchType, setPitchType] = useState<PitchType>("slider");
  const [intensity, setIntensity] = useState<PitchIntensity>("normal");
  const [zoneIntent, setZoneIntent] = useState<ZoneIntent>("edge");
  const [zone, setZone] = useState<PitchZone>({ row: 2, column: 0 });
  const [seed, setSeed] = useState(INITIAL_SEED);
  const [context, setContext] = useState<PlateAppearanceContext>(INITIAL_CONTEXT);
  const [preparation, setPreparation] = useState<PitchPreparation>();
  const [isRunning, setIsRunning] = useState(false);
  const [lastResult, setLastResult] = useState<PitchKernelResult>();
  const [history, setHistory] = useState<ReadonlyArray<HistoryItem>>([]);
  const [error, setError] = useState<string>();

  const selectedPreset = presets.find((preset) => preset.id === selectedPresetID);
  const pitcher = selectedPreset?.pitcher;
  const selectedPitchProfile = pitcher?.pitchProfiles?.find(
    (profile) => profile.pitchType === pitchType,
  );

  const applyRecommendation = useCallback(
    (recommendation: CatcherRecommendationSnapshot) => {
      setPitchType(recommendation.call.pitchType);
      setZone(recommendation.call.zone);
      setZoneIntent(recommendation.call.zoneIntent);
      setIntensity(recommendation.call.intensity);
    },
    [],
  );

  const connectCore = useCallback(async () => {
    setCoreStatus({ state: "checking" });
    setError(undefined);
    try {
      const [health, availablePresets] = await Promise.all([
        checkCoreHealth(),
        listPitcherPresets(),
      ]);
      const initialPreset = availablePresets[0];
      if (!initialPreset) throw new Error("사용 가능한 투수 프리셋이 없습니다.");
      const initialPreparation = await preparePitch({
        seed: INITIAL_SEED,
        pitcher: initialPreset.pitcher,
        batter: BATTER,
        scouting: SCOUTING,
        context: INITIAL_CONTEXT,
      });
      setPresets(availablePresets);
      setSelectedPresetID(initialPreset.id);
      setSeed(INITIAL_SEED);
      setContext(INITIAL_CONTEXT);
      setPreparation(initialPreparation);
      setLastResult(undefined);
      setHistory([]);
      applyRecommendation(initialPreparation.primaryRecommendation);
      setCoreStatus({ state: "online", health });
    } catch (caught) {
      const message = caught instanceof Error ? caught.message : "알 수 없는 연결 오류";
      setCoreStatus({ state: "offline", message });
    }
  }, [applyRecommendation]);

  useEffect(() => {
    void connectCore();
  }, [connectCore]);

  const handlePitch = useCallback(async () => {
    if (!preparation || !pitcher) return;
    setIsRunning(true);
    setError(undefined);
    try {
      const result = await submitPitch({
        seed,
        pitcher,
        batter: BATTER,
        scouting: SCOUTING,
        context,
        preparationToken: preparation.preparationToken,
        call: { pitchType, zone, zoneIntent, intensity },
      });
      setLastResult(result);
      setHistory((current) => [
        {
          eventHash: result.eventHash,
          outcome: result.snapshot.outcome,
          count: `${result.snapshot.balls}-${result.snapshot.strikes}`,
        },
        ...current,
      ].slice(0, 5));
      setSeed(result.nextSeed);
      setContext((current) => ({
        ...current,
        revision: result.revision,
        balls: result.snapshot.balls,
        strikes: result.snapshot.strikes,
        pitchNumber: result.nextPreparation ? current.pitchNumber + 1 : current.pitchNumber,
        fatigue: result.snapshot.fatigueAfterPitch,
      }));
      setPreparation(result.nextPreparation);
    } catch (caught) {
      const message =
        caught instanceof Error ? caught.message : "투구 결과를 계산하지 못했습니다.";
      setError(message);
      try {
        setPreparation(await preparePitch({ seed, pitcher, batter: BATTER, scouting: SCOUTING, context }));
      } catch {
        setCoreStatus({ state: "offline", message });
      }
    } finally {
      setIsRunning(false);
    }
  }, [context, intensity, pitchType, pitcher, preparation, seed, zone, zoneIntent]);

  const handleNewPlateAppearance = useCallback(async () => {
    if (!pitcher) return;
    setIsRunning(true);
    setError(undefined);
    const nextContext: PlateAppearanceContext = {
      ...INITIAL_CONTEXT,
      plateAppearanceID: `pa-prototype-${Date.now()}`,
    };
    try {
      const nextPreparation = await preparePitch({
        seed,
        pitcher,
        batter: BATTER,
        scouting: SCOUTING,
        context: nextContext,
      });
      setContext(nextContext);
      setPreparation(nextPreparation);
      setLastResult(undefined);
      applyRecommendation(nextPreparation.primaryRecommendation);
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "새 타석을 시작하지 못했습니다.");
    } finally {
      setIsRunning(false);
    }
  }, [applyRecommendation, pitcher, seed]);

  const handlePresetChange = useCallback(async (presetID: string) => {
    const nextPreset = presets.find((preset) => preset.id === presetID);
    if (!nextPreset || nextPreset.id === selectedPresetID) return;
    setIsRunning(true);
    setError(undefined);
    const nextContext: PlateAppearanceContext = {
      ...INITIAL_CONTEXT,
      plateAppearanceID: `pa-preset-${nextPreset.id}-${Date.now()}`,
    };
    try {
      const nextPreparation = await preparePitch({
        seed,
        pitcher: nextPreset.pitcher,
        batter: BATTER,
        scouting: SCOUTING,
        context: nextContext,
      });
      setSelectedPresetID(nextPreset.id);
      setContext(nextContext);
      setPreparation(nextPreparation);
      setLastResult(undefined);
      setHistory([]);
      applyRecommendation(nextPreparation.primaryRecommendation);
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "투수 프리셋을 바꾸지 못했습니다.");
    } finally {
      setIsRunning(false);
    }
  }, [applyRecommendation, presets, seed, selectedPresetID]);

  const online = coreStatus.state === "online";
  const primaryRecommendation = preparation?.primaryRecommendation;
  const alternativeRecommendation = preparation?.alternativeRecommendation;
  const plateEnded = lastResult?.snapshot.ended ?? false;

  return (
    <div className="app-shell">
      <header className="topbar">
        <div className="brand-lockup">
          <div className="brand-mark" aria-hidden="true">DS</div>
          <div>
            <p className="eyebrow">PROJECT DIAMOND SOUL</p>
            <h1>Pitch Kernel</h1>
          </div>
        </div>
        <div className={`core-status core-status--${coreStatus.state}`}>
          <span className="status-dot" aria-hidden="true" />
          <span>{statusMessage(coreStatus)}</span>
          {coreStatus.state === "offline" ? (
            <button type="button" onClick={() => void connectCore()}>다시 연결</button>
          ) : null}
        </div>
      </header>

      <main>
        <section className="game-context" aria-label="경기 상황">
          <div>
            <span className="context-label">고교 연습 경기 · 7회말</span>
            <strong>무사 1루 · B {context.balls} / S {context.strikes} · {context.pitchNumber}구</strong>
          </div>
          <div className="matchup">
            <span>{pitcher?.name ?? "투수 준비 중"}</span><b>VS</b><span>{BATTER.name}</span>
          </div>
          <div className="scoreboard" aria-label="현재 점수 2 대 2">
            <span>한빛고</span><strong>2 : 2</strong><span>대명고</span>
          </div>
        </section>

        <div className="workspace-grid">
          <aside className="panel player-panel" aria-label="선수 정보">
            <div className="panel-heading">
              <div><p className="eyebrow">YOUR PITCHER</p><h2>{pitcher?.name ?? "불러오는 중"}</h2></div>
              <span className="role-badge">{selectedPreset?.name ?? "프리셋"}</span>
            </div>
            <label className="preset-picker">
              <span>투수 프리셋</span>
              <select
                value={selectedPresetID ?? ""}
                disabled={isRunning || presets.length === 0}
                onChange={(event) => void handlePresetChange(event.target.value)}
              >
                {presets.map((preset) => (
                  <option key={preset.id} value={preset.id}>{preset.name}</option>
                ))}
              </select>
            </label>
            {selectedPreset ? (
              <div className="preset-summary">
                <p>{selectedPreset.tagline}</p>
                <div className="strength-chips">
                  {selectedPreset.strengths.map((strength) => <span key={strength}>{strength}</span>)}
                </div>
                <small>{selectedPreset.tradeoff}</small>
              </div>
            ) : null}
            <div className="player-summary">
              <div className="avatar" aria-hidden="true">17</div>
              <div><strong>2학년 · 184cm</strong><span>피로 {context.fatigue} · 컨디션 좋음</span></div>
            </div>
            {pitcher ? (
              <div className="stat-list" aria-label="현재 능력치">
                <StatRow label="구위" value={pitcher.stuff} />
                <StatRow label="제구" value={pitcher.command} />
                <StatRow label="무브먼트" value={pitcher.movement} />
                <StatRow label="체력" value={pitcher.stamina} />
              </div>
            ) : null}
            <div className="scouting-card">
              <span>상대 타자 리포트</span>
              <strong>{BATTER.name} · 우타</strong>
              <p>가운데 포심에 강하고 낮은 몸쪽 슬라이더 인식이 늦습니다.</p>
              <div className="mini-stats">
                <span>컨택 {BATTER.contact}</span><span>선구 {BATTER.discipline}</span><span>파워 {BATTER.power}</span>
              </div>
            </div>
          </aside>

          <section className="panel decision-panel" aria-label="투구 선택">
            <div className="panel-heading">
              <div><p className="eyebrow">PITCH DECISION</p><h2>어떻게 승부할까요?</h2></div>
              <span className="count-badge">B {context.balls} · S {context.strikes}</span>
            </div>

            {primaryRecommendation ? (
              <div className="catcher-call">
                <div className="catcher-icon" aria-hidden="true">C</div>
                <div>
                  <span>포수 주 추천 · 확신 {Math.round(primaryRecommendation.confidence / 10)}%</span>
                  <strong>{recommendationTitle(primaryRecommendation)}</strong>
                  <p>{primaryRecommendation.shortReason}</p>
                  <div className="recommendation-actions">
                    <button type="button" onClick={() => applyRecommendation(primaryRecommendation)}>주 추천 적용</button>
                    {alternativeRecommendation ? (
                      <button type="button" onClick={() => applyRecommendation(alternativeRecommendation)}>
                        대안: {pitchLabel(alternativeRecommendation.call.pitchType)}
                      </button>
                    ) : null}
                  </div>
                </div>
              </div>
            ) : (
              <div className="catcher-call catcher-call--loading">포수 사인을 준비하고 있습니다.</div>
            )}

            <fieldset className="choice-group">
              <legend>1. 구종</legend>
              <div className="pitch-options">
                {PITCH_OPTIONS.map((option) => {
                  const profile = pitcher?.pitchProfiles?.find(
                    (candidate) => candidate.pitchType === option.value,
                  );
                  return (
                    <button key={option.value} type="button" className={pitchType === option.value ? "is-selected" : undefined}
                      disabled={!profile} aria-pressed={pitchType === option.value} onClick={() => setPitchType(option.value)}>
                      <strong>{option.label}</strong><span>{pitchHint(profile)}</span>
                    </button>
                  );
                })}
              </div>
              {selectedPitchProfile ? (
                <div className="pitch-profile" aria-label={`${pitchLabel(pitchType)} 구종 능력치`}>
                  <span className={`pitch-role pitch-role--${selectedPitchProfile.role}`}>
                    {roleLabel(selectedPitchProfile)}
                  </span>
                  <dl>
                    <div><dt>구속</dt><dd>{(selectedPitchProfile.velocityTenthsKPH / 10).toFixed(1)}</dd></div>
                    <div><dt>제구</dt><dd>{selectedPitchProfile.control}</dd></div>
                    <div><dt>커맨드</dt><dd>{selectedPitchProfile.command}</dd></div>
                    <div><dt>무브</dt><dd>{selectedPitchProfile.movement}</dd></div>
                    <div><dt>헛스윙</dt><dd>{selectedPitchProfile.whiff}</dd></div>
                    <div><dt>약한 타구</dt><dd>{selectedPitchProfile.weakContact}</dd></div>
                  </dl>
                </div>
              ) : null}
            </fieldset>

            <div className="location-and-intensity">
              <fieldset className="choice-group location-group">
                <legend>2. 코스</legend>
                <div className="strike-zone" aria-label="3 곱하기 3 스트라이크 존">
                  {ZONE_LABELS.map((label, index) => {
                    const currentZone = { row: Math.floor(index / 3), column: index % 3 };
                    const selected = zone.row === currentZone.row && zone.column === currentZone.column;
                    return (
                      <button key={label} type="button" className={selected ? "is-selected" : undefined}
                        aria-label={label} aria-pressed={selected} onClick={() => setZone(currentZone)}>
                        <span aria-hidden="true" />
                      </button>
                    );
                  })}
                </div>
                <p className="selection-caption">선택: {zoneLabel(zone)}</p>
              </fieldset>

              <div className="pitch-modifiers">
                <fieldset className="choice-group intensity-group">
                  <legend>3. 존 의도</legend>
                  <div className="intensity-options">
                    {INTENT_OPTIONS.map((option) => (
                      <button key={option.value} type="button" className={zoneIntent === option.value ? "is-selected" : undefined}
                        aria-pressed={zoneIntent === option.value} onClick={() => setZoneIntent(option.value)}>
                        <strong>{option.label}</strong><span>{option.hint}</span>
                      </button>
                    ))}
                  </div>
                </fieldset>
                <fieldset className="choice-group intensity-group">
                  <legend>4. 강도</legend>
                  <div className="intensity-options">
                    {INTENSITY_OPTIONS.map((option) => (
                      <button key={option.value} type="button" className={intensity === option.value ? "is-selected" : undefined}
                        aria-pressed={intensity === option.value} onClick={() => setIntensity(option.value)}>
                        <strong>{option.label}</strong><span>{option.hint}</span>
                      </button>
                    ))}
                  </div>
                </fieldset>
              </div>
            </div>

            {plateEnded ? (
              <button className="primary-action" type="button" disabled={isRunning} onClick={() => void handleNewPlateAppearance()}>
                {isRunning ? "새 타석 준비 중…" : "다음 타석 시작"}
              </button>
            ) : (
              <button className="primary-action" type="button" disabled={!online || !preparation || isRunning}
                onClick={() => void handlePitch()}>
                {isRunning ? "투구 계산 중…" : online && preparation ? "이 선택으로 투구" : "포수 사인 준비 중"}
              </button>
            )}
            {error ? <p className="error-message" role="alert">{error}</p> : null}
          </section>

          <aside className="panel result-panel" aria-label="투구 결과">
            <div className="panel-heading">
              <div><p className="eyebrow">RESULT</p><h2>판단 피드백</h2></div>
              <span className="seed-label">REV {context.revision}</span>
            </div>

            {lastResult ? (
              <div className="result-content" aria-live="polite" aria-label={lastResult.snapshot.accessibilitySummary}>
                <div className={`outcome outcome--${outcomeTone(lastResult.snapshot.outcome)}`}>
                  <span>{lastResult.snapshot.ended ? "타석 결과" : "투구 결과"}</span>
                  <strong>
                    {lastResult.snapshot.result
                      ? PLATE_RESULT_LABELS[lastResult.snapshot.result]
                      : OUTCOME_LABELS[lastResult.snapshot.outcome]}
                  </strong>
                </div>
                <div className={`decision-grade decision-grade--${lastResult.snapshot.selectionQuality}`}>
                  {SELECTION_LABELS[lastResult.snapshot.selectionQuality]}
                  <span>{lastResult.snapshot.recommendationAccepted ? " · 포수 추천 수락" : " · 포수 사인 수정"}</span>
                </div>
                <p className="result-summary">{lastResult.snapshot.shortFeedback}</p>
                <p className="result-detail">{lastResult.snapshot.detailFeedback}</p>
                <dl className="result-facts">
                  <div><dt>ABS</dt><dd>{Math.abs(lastResult.snapshot.execution.actualX) <= 500 && Math.abs(lastResult.snapshot.execution.actualY) <= 500 ? "존 안" : "존 밖"}</dd></div>
                  <div><dt>구속</dt><dd>{(lastResult.snapshot.execution.velocityTenthsKPH / 10).toFixed(1)} km/h</dd></div>
                  <div><dt>실행 품질</dt><dd>{lastResult.snapshot.execution.executionQuality}</dd></div>
                </dl>
                {lastResult.snapshot.battedBall ? (
                  <dl className="result-facts batted-ball-facts">
                    <div><dt>타구 속도</dt><dd>{(lastResult.snapshot.battedBall.exitVelocityTenthsKPH / 10).toFixed(1)} km/h</dd></div>
                    <div><dt>발사각</dt><dd>{(lastResult.snapshot.battedBall.launchAngleTenthsDegrees / 10).toFixed(1)}°</dd></div>
                    <div><dt>타구 질</dt><dd>{lastResult.snapshot.battedBall.contactQuality}</dd></div>
                  </dl>
                ) : null}
                <div className="event-proof">
                  <span>계획 커밋 → 콜 → 실행 → 결과</span>
                  <code>{lastResult.eventHash}</code>
                </div>
              </div>
            ) : (
              <div className="empty-result">
                <div aria-hidden="true">◇</div><strong>타자 계획이 비공개로 확정됐습니다</strong>
                <p>포수 추천을 그대로 쓰거나 수정한 뒤 첫 공을 던져보세요.</p>
              </div>
            )}

            <div className="history-section">
              <div className="section-label"><span>이번 타석 투구</span><small>최대 5개</small></div>
              {history.length > 0 ? (
                <ol className="history-list">
                  {history.map((event) => (
                    <li key={event.eventHash}>
                      <span className={`history-dot history-dot--${outcomeTone(event.outcome)}`} aria-hidden="true" />
                      <div><strong>{OUTCOME_LABELS[event.outcome]} · {event.count}</strong><code>{event.eventHash.slice(0, 8)}</code></div>
                    </li>
                  ))}
                </ol>
              ) : (
                <p className="history-empty">투구 이벤트가 여기에 쌓입니다.</p>
              )}
            </div>
          </aside>
        </div>
      </main>

      <footer>
        <span>P1 Pitch Kernel</span>
        <span>타자 계획 선확정 · ABS · 선택/실행/결과 분리</span>
      </footer>
    </div>
  );
}
