import { useCallback, useEffect, useState } from "react";
import { checkCoreHealth, simulatePitch } from "./simulationClient";
import type {
  BatterSnapshot,
  HealthResult,
  PitchIntensity,
  PitchOutcome,
  PitchResolvedEvent,
  PitchType,
  PitcherSnapshot,
  PitchZone,
  SimulatePitchResult,
} from "./simulationTypes";

const PITCHER: PitcherSnapshot = {
  id: "pitcher-1",
  name: "김도윤",
  stuff: 62,
  command: 54,
  movement: 58,
  stamina: 60,
};

const BATTER: BatterSnapshot = {
  id: "batter-1",
  name: "이준호",
  contact: 56,
  discipline: 52,
  power: 58,
};

const PITCH_OPTIONS: ReadonlyArray<{
  value: PitchType;
  label: string;
  hint: string;
}> = [
  { value: "four_seam", label: "포심", hint: "구위 + / 무브먼트 -" },
  { value: "slider", label: "슬라이더", hint: "무브먼트 + / 제구 -" },
  { value: "curveball", label: "커브", hint: "무브먼트 ++ / 제구 --" },
  { value: "changeup", label: "체인지업", hint: "균형형" },
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

export function App() {
  const [coreStatus, setCoreStatus] = useState<CoreStatus>({ state: "checking" });
  const [pitchType, setPitchType] = useState<PitchType>("slider");
  const [intensity, setIntensity] = useState<PitchIntensity>("normal");
  const [zone, setZone] = useState<PitchZone>({ row: 2, column: 0 });
  const [seed, setSeed] = useState("20260721");
  const [isRunning, setIsRunning] = useState(false);
  const [lastResult, setLastResult] = useState<SimulatePitchResult>();
  const [history, setHistory] = useState<ReadonlyArray<PitchResolvedEvent>>([]);
  const [error, setError] = useState<string>();

  const connectCore = useCallback(async () => {
    setCoreStatus({ state: "checking" });
    try {
      const health = await checkCoreHealth();
      setCoreStatus({ state: "online", health });
    } catch (caught) {
      const message = caught instanceof Error ? caught.message : "알 수 없는 연결 오류";
      setCoreStatus({ state: "offline", message });
    }
  }, []);

  useEffect(() => {
    void connectCore();
  }, [connectCore]);

  const handlePitch = useCallback(async () => {
    setIsRunning(true);
    setError(undefined);
    try {
      const result = await simulatePitch({
        seed,
        pitcher: PITCHER,
        batter: BATTER,
        count: { balls: 1, strikes: 1 },
        fatigue: 12,
        selection: { pitchType, zone, intensity },
      });
      const event = result.events[0];
      if (!event) {
        throw new Error("투구 이벤트가 생성되지 않았습니다.");
      }
      setLastResult(result);
      setHistory((current) => [event, ...current].slice(0, 5));
      setSeed(event.nextSeed);
    } catch (caught) {
      const message =
        caught instanceof Error ? caught.message : "투구 결과를 계산하지 못했습니다.";
      setError(message);
      setCoreStatus({ state: "offline", message });
    } finally {
      setIsRunning(false);
    }
  }, [intensity, pitchType, seed, zone]);

  const online = coreStatus.state === "online";

  return (
    <div className="app-shell">
      <header className="topbar">
        <div className="brand-lockup">
          <div className="brand-mark" aria-hidden="true">
            DS
          </div>
          <div>
            <p className="eyebrow">PROJECT DIAMOND SOUL</p>
            <h1>Pitch Kernel</h1>
          </div>
        </div>
        <div className={`core-status core-status--${coreStatus.state}`}>
          <span className="status-dot" aria-hidden="true" />
          <span>{statusMessage(coreStatus)}</span>
          {coreStatus.state === "offline" ? (
            <button type="button" onClick={() => void connectCore()}>
              다시 연결
            </button>
          ) : null}
        </div>
      </header>

      <main>
        <section className="game-context" aria-label="경기 상황">
          <div>
            <span className="context-label">고교 연습 경기 · 7회말</span>
            <strong>무사 1루 · 1–1 카운트</strong>
          </div>
          <div className="matchup">
            <span>{PITCHER.name}</span>
            <b>VS</b>
            <span>{BATTER.name}</span>
          </div>
          <div className="scoreboard" aria-label="현재 점수 2 대 2">
            <span>한빛고</span>
            <strong>2 : 2</strong>
            <span>대명고</span>
          </div>
        </section>

        <div className="workspace-grid">
          <aside className="panel player-panel" aria-label="선수 정보">
            <div className="panel-heading">
              <div>
                <p className="eyebrow">YOUR PITCHER</p>
                <h2>{PITCHER.name}</h2>
              </div>
              <span className="role-badge">우완 선발</span>
            </div>
            <div className="player-summary">
              <div className="avatar" aria-hidden="true">17</div>
              <div>
                <strong>2학년 · 184cm</strong>
                <span>피로 12 · 컨디션 좋음</span>
              </div>
            </div>
            <div className="stat-list" aria-label="현재 능력치">
              <StatRow label="구위" value={PITCHER.stuff} />
              <StatRow label="제구" value={PITCHER.command} />
              <StatRow label="무브먼트" value={PITCHER.movement} />
              <StatRow label="체력" value={PITCHER.stamina} />
            </div>
            <div className="scouting-card">
              <span>상대 타자 리포트</span>
              <strong>{BATTER.name} · 우타</strong>
              <p>낮은 변화구 대처가 늦지만, 가운데 몰린 공의 장타 위험이 높습니다.</p>
              <div className="mini-stats">
                <span>컨택 {BATTER.contact}</span>
                <span>선구 {BATTER.discipline}</span>
                <span>파워 {BATTER.power}</span>
              </div>
            </div>
          </aside>

          <section className="panel decision-panel" aria-label="투구 선택">
            <div className="panel-heading">
              <div>
                <p className="eyebrow">PITCH DECISION</p>
                <h2>어떻게 승부할까요?</h2>
              </div>
              <span className="count-badge">B 1 · S 1</span>
            </div>

            <div className="catcher-call">
              <div className="catcher-icon" aria-hidden="true">C</div>
              <div>
                <span>포수 추천</span>
                <strong>낮은 몸쪽 슬라이더</strong>
                <p>타자의 약한 코스를 공략하되, 제구 실패 시 몸에 맞을 위험이 있습니다.</p>
              </div>
            </div>

            <fieldset className="choice-group">
              <legend>1. 구종</legend>
              <div className="pitch-options">
                {PITCH_OPTIONS.map((option) => (
                  <button
                    key={option.value}
                    type="button"
                    className={pitchType === option.value ? "is-selected" : undefined}
                    aria-pressed={pitchType === option.value}
                    onClick={() => setPitchType(option.value)}
                  >
                    <strong>{option.label}</strong>
                    <span>{option.hint}</span>
                  </button>
                ))}
              </div>
            </fieldset>

            <div className="location-and-intensity">
              <fieldset className="choice-group location-group">
                <legend>2. 코스</legend>
                <div className="strike-zone" aria-label="3 곱하기 3 스트라이크 존">
                  {ZONE_LABELS.map((label, index) => {
                    const currentZone = { row: Math.floor(index / 3), column: index % 3 };
                    const selected = zone.row === currentZone.row && zone.column === currentZone.column;
                    return (
                      <button
                        key={label}
                        type="button"
                        className={selected ? "is-selected" : undefined}
                        aria-label={label}
                        aria-pressed={selected}
                        onClick={() => setZone(currentZone)}
                      >
                        <span aria-hidden="true" />
                      </button>
                    );
                  })}
                </div>
                <p className="selection-caption">
                  선택: {ZONE_LABELS[zone.row * 3 + zone.column]}
                </p>
              </fieldset>

              <fieldset className="choice-group intensity-group">
                <legend>3. 강도</legend>
                <div className="intensity-options">
                  {INTENSITY_OPTIONS.map((option) => (
                    <button
                      key={option.value}
                      type="button"
                      className={intensity === option.value ? "is-selected" : undefined}
                      aria-pressed={intensity === option.value}
                      onClick={() => setIntensity(option.value)}
                    >
                      <strong>{option.label}</strong>
                      <span>{option.hint}</span>
                    </button>
                  ))}
                </div>
                <div className="risk-note">
                  <span>선택 영향</span>
                  <p>전력 투구는 구위를 높이지만 제구 변동을 키웁니다.</p>
                </div>
              </fieldset>
            </div>

            <button
              className="primary-action"
              type="button"
              disabled={!online || isRunning}
              onClick={() => void handlePitch()}
            >
              {isRunning ? "투구 계산 중…" : online ? "이 선택으로 투구" : "코어 연결 후 투구 가능"}
            </button>
            {error ? <p className="error-message" role="alert">{error}</p> : null}
          </section>

          <aside className="panel result-panel" aria-label="투구 결과">
            <div className="panel-heading">
              <div>
                <p className="eyebrow">RESULT</p>
                <h2>판단 피드백</h2>
              </div>
              <span className="seed-label">SEED {seed.slice(-8)}</span>
            </div>

            {lastResult && lastResult.events[0] ? (
              <div
                className="result-content"
                aria-live="polite"
                aria-label={lastResult.snapshot.accessibilitySummary}
              >
                <div className={`outcome outcome--${outcomeTone(lastResult.snapshot.outcome)}`}>
                  <span>투구 결과</span>
                  <strong>{OUTCOME_LABELS[lastResult.snapshot.outcome]}</strong>
                </div>
                <p className="result-summary">{lastResult.snapshot.shortFeedback}</p>
                <p className="result-detail">{lastResult.snapshot.detailFeedback}</p>
                <dl className="result-facts">
                  <div>
                    <dt>존 판정</dt>
                    <dd>{lastResult.snapshot.wasInZone ? "존 안" : "존 밖"}</dd>
                  </div>
                  <div>
                    <dt>타자 반응</dt>
                    <dd>{lastResult.snapshot.batterSwung ? "스윙" : "지켜봄"}</dd>
                  </div>
                  <div>
                    <dt>실행 지수</dt>
                    <dd>{lastResult.snapshot.executionScore}</dd>
                  </div>
                </dl>
                <div className="event-proof">
                  <span>결정론 이벤트 해시</span>
                  <code>{lastResult.events[0].eventHash}</code>
                </div>
              </div>
            ) : (
              <div className="empty-result">
                <div aria-hidden="true">◇</div>
                <strong>아직 투구하지 않았습니다</strong>
                <p>구종, 코스, 강도를 선택하면 결과와 원인을 분리해 보여줍니다.</p>
              </div>
            )}

            <div className="history-section">
              <div className="section-label">
                <span>최근 이벤트</span>
                <small>최대 5개</small>
              </div>
              {history.length > 0 ? (
                <ol className="history-list">
                  {history.map((event) => (
                    <li key={event.eventHash}>
                      <span className={`history-dot history-dot--${outcomeTone(event.outcome)}`} aria-hidden="true" />
                      <div>
                        <strong>{OUTCOME_LABELS[event.outcome]}</strong>
                        <code>{event.eventHash.slice(0, 8)}</code>
                      </div>
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
        <span>P0 관통 프로토타입</span>
        <span>동일 시드 + 동일 명령 = 동일 결과</span>
      </footer>
    </div>
  );
}
