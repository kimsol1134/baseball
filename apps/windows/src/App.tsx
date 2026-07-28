import { useCallback, useEffect, useRef, useState } from "react";
import {
  checkCoreHealth,
  advanceCareerChapter,
  chooseCareerAwakening,
  chooseSchool,
  chooseAwakening,
  chooseRelationship,
  commitTraining,
  commitCareerTraining,
  completeMiddleSchoolPrologue,
  normalizePitcherLabBalance,
  normalizeProCareerBalance,
  normalizeRegionalSchools,
  finalizeScouting,
  listPitcherPresets,
  preparePitch,
  recordImportantInning,
  recordCareerGame,
  resolveCareerRelationship,
  resolveDraft,
  selectLegacy,
  selectCareerLegacy,
  startHighSchoolCareer,
  startPitcherLab,
  submitPitch,
  startProCareer,
  signProContract,
  planProWeek,
  resolveProImportantGame,
  reviewProSeason,
  chooseProOffseason,
} from "./simulationClient";
import { PitcherLabSetup, PitcherLabView } from "./PitcherLabView";
import { HighSchoolCareerSetup, HighSchoolCareerView } from "./HighSchoolCareerView";
import { gameStateForReplay, pitcherCondition } from "./gamePresentation";
import { ProCareerView } from "./ProCareerView";
import { GameCastReplay } from "./TrajectoryReplay";
import {
  clearPitcherLabAutosave,
  loadPitcherLabAutosave,
  savePitcherLabAutosave,
  type LabInningStats,
  type PitchHistoryItem,
  type PitcherLabAutosavePayload,
} from "./pitcherLabAutosave";
import {
  clearHighSchoolCareer,
  loadHighSchoolCareer,
  saveHighSchoolCareer,
  type HighSchoolCareerAutosavePayload,
} from "./highSchoolCareerAutosave";
import { clearProCareer, loadProCareer, saveProCareer } from "./proCareerAutosave";
import { nextFontScale, parseFontScale } from "./accessibilityPreferences";
import { batterScoutingReport, pitcherRoleLabel } from "./playerPresentation";
import { proBatterFromRival } from "./proRival";
import { coreRecoveryMessage } from "./coreRecoveryMessage";
import { crossedGrowthMilestone } from "./GrowthCelebration";
import { feedbackCueForResult, GameFeedback } from "./gameFeedback";
import { AvatarFace } from "./AvatarFace";
import { resetAllProgress } from "./progressReset";
import { includesProCareer, releaseEditionFromEnvironment } from "./releaseEdition";
import { getAppStorage } from "./cloudStorage";
import {
  createAnonymousDiagnosticPackage,
  downloadTextFile,
  readLocalAnalytics,
  recordLocalAnalytics,
} from "./p4Services";
import type {
  AwakeningID,
  BatterScoutingSnapshot,
  BatterSnapshot,
  BaserunnerStateSnapshot,
  CatcherRecommendationSnapshot,
  CareerDifficultySnapshot,
  CreationAllocationSnapshot,
  FielderPosition,
  GameLogSnapshot,
  GameStateSnapshot,
  HealthResult,
  HighSchoolCareerResult,
  ImportantInningReport,
  KarmaID,
  MemoryCardID,
  PitchIntensity,
  PitchCall,
  PitchKernelResult,
  PitcherLabResult,
  PitchOutcome,
  PitchPreparation,
  PitchProfileSnapshot,
  PitchType,
  PitcherPresetSnapshot,
  ProCareerResult,
  ProWeekPlan,
  OffseasonDecision,
  PitchZone,
  PlayerIdentitySnapshot,
  PlateAppearanceContext,
  PlateAppearanceResult,
  RivalAdaptationBand,
  RivalMemorySnapshot,
  RelationshipChoice,
  RelationshipResponse,
  SelectionQuality,
  SoulDomain,
  SchoolID,
  ExtendedPitchOutcome,
  TrainingFocus,
  TrainingIntensity,
  ZoneIntent,
} from "./simulationTypes";

const BATTER: BatterSnapshot = {
  id: "batter-1",
  name: "김도겸",
  contact: 44,
  discipline: 41,
  power: 46,
};

const SCOUTING: BatterScoutingSnapshot = {
  hotZone: { row: 1, column: 1 },
  coldZone: { row: 2, column: 0 },
  pitchStrength: "four_seam",
  pitchWeakness: "slider",
  chaseTendency: 48,
};

// Where the scouting read starts, by the difficulty's information-clarity axis: a relaxed run is
// handed the truth outright, a challenging one has to earn it by watching the batter. Observation
// lifts every case toward full confidence inside the core (see ScoutingEstimate).
function scoutBaselineReliability(clarity: string | undefined): number {
  switch (clarity) {
    case "relaxed":
      return 100;
    case "challenging":
      return 22;
    default:
      return 45;
  }
}

const INITIAL_SEED = "20260721";
const appStorage = getAppStorage();
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

const INITIAL_GAME_STATE: GameStateSnapshot = {
  defense: {
    infield: 58,
    outfield: 55,
    arm: 57,
    fielders: [
      { id: "f-p", name: "민서준", position: "pitcher", range: 51, glove: 54, arm: 64 },
      { id: "f-c", name: "유시환", position: "catcher", range: 48, glove: 61, arm: 67 },
      { id: "f-1b", name: "임태오", position: "first_base", range: 52, glove: 60, arm: 51 },
      { id: "f-2b", name: "나건우", position: "second_base", range: 61, glove: 64, arm: 57 },
      { id: "f-3b", name: "오재민", position: "third_base", range: 57, glove: 58, arm: 66 },
      { id: "f-ss", name: "배준서", position: "shortstop", range: 67, glove: 65, arm: 63 },
      { id: "f-lf", name: "하민규", position: "left_field", range: 54, glove: 53, arm: 56 },
      { id: "f-cf", name: "조유찬", position: "center_field", range: 65, glove: 61, arm: 59 },
      { id: "f-rf", name: "신태양", position: "right_field", range: 56, glove: 55, arm: 65 },
    ],
  },
  park: {
    id: "practice-park",
    name: "연습 구장",
    hitFactor: 980,
    homeRunFactor: 930,
  },
  runners: {
    firstOccupied: true,
    secondOccupied: false,
    thirdOccupied: false,
    leadRunnerSpeed: 62,
  },
  runsAllowed: 0,
  inningState: { inning: 7, half: "bottom", outs: 0 },
};

const INITIAL_GAME_LOG: GameLogSnapshot = {
  gameID: "practice-game-20260721",
  revision: 0,
  totalPitches: 0,
  entries: [],
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
  { value: "controlled", label: "힘 조절", hint: "제구 우선" },
  { value: "normal", label: "보통", hint: "균형" },
  { value: "max_effort", label: "전력투구", hint: "구속 우선" },
];

const INTENT_OPTIONS: ReadonlyArray<{
  value: ZoneIntent;
  label: string;
  hint: string;
}> = [
  { value: "strike", label: "스트라이크", hint: "볼넷 억제" },
  { value: "edge", label: "존 끝", hint: "코스 공략" },
  { value: "chase", label: "존 밖 유인", hint: "헛스윙 노림" },
];

const OUTCOME_LABELS: Record<ExtendedPitchOutcome, string> = {
  ball: "볼",
  called_strike: "루킹 스트라이크",
  swinging_strike: "헛스윙",
  foul: "파울",
  in_play_out: "타구 아웃",
  single: "안타",
  double: "2루타",
  triple: "3루타",
  home_run: "홈런",
  hit_by_pitch: "몸에 맞는 공",
};

const SELECTION_LABELS: Record<SelectionQuality, string> = {
  poor: "공 선택이 아쉬웠습니다",
  risky: "위험한 공을 골랐습니다",
  good: "좋은 공을 골랐습니다",
  excellent: "상황에 가장 알맞은 공이었습니다",
};

const PLATE_RESULT_LABELS: Record<PlateAppearanceResult, string> = {
  strikeout: "삼진",
  walk: "볼넷",
  in_play_out: "범타",
  hit: "출루 허용",
};

const ADAPTATION_LABELS: Record<RivalAdaptationBand, string> = {
  no_data: "첫 대결",
  watching: "아직 파악 못 함",
  learning: "투구 습관을 읽는 중",
  locked_on: "노림수가 분명함",
};

const SCOUT_BAND_LABELS: Record<"low" | "developing" | "trusted", string> = {
  low: "낮음",
  developing: "보통",
  trusted: "높음",
};

const FIELDER_LABELS: Record<FielderPosition, string> = {
  pitcher: "투수",
  catcher: "포수",
  first_base: "1루수",
  second_base: "2루수",
  third_base: "3루수",
  shortstop: "유격수",
  left_field: "좌익수",
  center_field: "중견수",
  right_field: "우익수",
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

const EMPTY_LAB_INNING_STATS: LabInningStats = {
  pitches: 0,
  strikeouts: 0,
  walks: 0,
  runsAllowed: 0,
  expectedDamage: 0,
  actualDamage: 0,
  recommendationAccepted: 0,
};

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

function AccessibilityControls({ highContrast, reducedMotion, systemReducedMotion, fontScale, analyticsOptIn, soundEnabled, hapticsEnabled, onContrast, onMotion, onFontScale, onAnalytics, onSound, onHaptics, onDiagnostics, onResetProgress }: {
  highContrast: boolean;
  reducedMotion: boolean;
  systemReducedMotion: boolean;
  fontScale: number;
  analyticsOptIn: boolean;
  soundEnabled: boolean;
  hapticsEnabled: boolean;
  onContrast: () => void;
  onMotion: () => void;
  onFontScale: () => void;
  onAnalytics: () => void;
  onSound: () => void;
  onHaptics: () => void;
  onDiagnostics: () => void;
  onResetProgress: () => void;
}) {
  const hapticsSupported = typeof navigator.vibrate === "function";
  const [resetArmed, setResetArmed] = useState(false);
  return <details className="settings-menu" onToggle={(event) => { if (!(event.target as HTMLDetailsElement).open) setResetArmed(false); }}>
    <summary>설정</summary>
    <div className="accessibility-controls" aria-label="접근성 및 환경 설정">
      <span className="settings-menu-label">화면</span>
      <button type="button" aria-pressed={highContrast} onClick={onContrast}>고대비 {highContrast ? "켜짐" : "꺼짐"}</button>
      <button type="button" disabled={systemReducedMotion} aria-pressed={reducedMotion} onClick={onMotion}>모션 감소 {systemReducedMotion ? "시스템 설정" : reducedMotion ? "켜짐" : "꺼짐"}</button>
      <button type="button" onClick={onFontScale}>글자 {fontScale === 1 ? "보통" : fontScale === 1.15 ? "크게" : "매우 크게"}</button>
      <span className="settings-menu-label">피드백</span>
      <button type="button" aria-pressed={soundEnabled} onClick={onSound}>효과음 {soundEnabled ? "켜짐" : "꺼짐"}</button>
      <button type="button" disabled={!hapticsSupported} aria-pressed={hapticsSupported ? hapticsEnabled : undefined} onClick={onHaptics}>진동 {hapticsSupported ? hapticsEnabled ? "켜짐" : "꺼짐" : "지원 안 됨"}</button>
      <span className="settings-menu-label">데이터</span>
      <button type="button" aria-pressed={analyticsOptIn} onClick={onAnalytics}>플레이 기록 {analyticsOptIn ? "저장함" : "저장 안 함"}</button>
      <button type="button" onClick={onDiagnostics}>문제 해결 자료 저장</button>
      <button type="button" className={resetArmed ? "settings-reset is-armed" : "settings-reset"}
        onClick={() => { if (resetArmed) { onResetProgress(); } else { setResetArmed(true); } }}>
        {resetArmed ? "정말 모든 진행을 지우고 처음부터 시작합니다" : "처음부터 다시 시작"}
      </button>
      {resetArmed ? <small className="settings-explanation">저장된 커리어·연습 기록이 모두 삭제됩니다. 화면·소리 설정은 유지됩니다. 다시 누르면 실행됩니다.</small> : null}
      <small className="settings-explanation">플레이 기록은 동의할 때만 이 기기에 저장되며 외부로 전송되지 않습니다. 문제 해결 자료에도 선수 이름과 자유 입력은 포함하지 않습니다.</small>
      <span className="settings-menu-label">게임 정보</span>
      <small className="settings-version">버전 1.0.0 · 선택 확정마다 자동 저장 · Windows와 macOS 지원</small>
    </div>
  </details>;
}

/// 결정적 순간(삼진·득점·장타·이닝 종료·병살)만 풀스크린 TRACKLAB으로 자동 확장한다.
function isDecisiveResult(result: PitchKernelResult) {
  const snapshot = result.snapshot;
  const outcome = snapshot.outcome as ExtendedPitchOutcome;
  return snapshot.result === "strikeout"
    || snapshot.runsScored > 0
    || outcome === "double" || outcome === "triple" || outcome === "home_run"
    || snapshot.inningTransition?.inningEnded === true
    || snapshot.inningTransition?.doublePlayCompleted === true;
}

function statusMessage(status: CoreStatus) {
  switch (status.state) {
    case "checking":
      return "게임 준비 중";
    case "online":
      return "게임 준비 완료";
    case "offline":
      return "경기 데이터 연결 필요";
  }
}

function statusDetail(status: CoreStatus) {
  return status.state === "offline" ? coreRecoveryMessage(status.message) : statusMessage(status);
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
    case "development": return "연마 중";
  }
}

function runnerLabel(runners: BaserunnerStateSnapshot) {
  const occupied = [
    runners.firstOccupied ? "1루" : undefined,
    runners.secondOccupied ? "2루" : undefined,
    runners.thirdOccupied ? "3루" : undefined,
  ].filter(Boolean);
  return occupied.length > 0 ? `주자 ${occupied.join("·")}` : "주자 없음";
}

function halfInningLabel(gameState: GameStateSnapshot) {
  const inningState = gameState.inningState;
  if (!inningState) return `${INITIAL_CONTEXT.inning}회말`;
  return `${inningState.inning}회${inningState.half === "top" ? "초" : "말"}`;
}

function outsLabel(gameState: GameStateSnapshot) {
  switch (gameState.inningState?.outs ?? 0) {
    case 1: return "1사";
    case 2: return "2사";
    default: return "무사";
  }
}

function fielderLabel(position?: FielderPosition) {
  return position ? FIELDER_LABELS[position] : "담당 야수";
}

function rateLabel(value: number) {
  return `${(value / 10).toFixed(1)}%`;
}

function confidenceLabel(value: PitchKernelResult["postgameAnalysis"]["confidence"]) {
  switch (value) {
    case "low": return "아직 던진 공이 적음";
    case "developing": return "투구 습관이 보이기 시작함";
    case "reliable": return "충분한 투구로 분석함";
  }
}

function pitchHint(profile?: PitchProfileSnapshot) {
  if (!profile) return "프로필 없음";
  return `${roleLabel(profile)} · ${(profile.velocityTenthsKPH / 10).toFixed(0)} km/h`;
}

export function App() {
  const releaseEdition = releaseEditionFromEnvironment(
    import.meta.env.DEV,
    import.meta.env.VITE_RELEASE_EDITION,
  );
  const bundledProAccess = includesProCareer(releaseEdition);
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
  const [history, setHistory] = useState<ReadonlyArray<PitchHistoryItem>>([]);
  const [rivalMemory, setRivalMemory] = useState<RivalMemorySnapshot>();
  const [gameState, setGameState] = useState<GameStateSnapshot>(INITIAL_GAME_STATE);
  const [gameLog, setGameLog] = useState<GameLogSnapshot>(INITIAL_GAME_LOG);
  const [screenMode, setScreenMode] = useState<"lab" | "pitch">("lab");
  const [experienceMode, setExperienceMode] = useState<"lab" | "career">("career");
  const [labResult, setLabResult] = useState<PitcherLabResult>();
  const [previousLifeResult, setPreviousLifeResult] = useState<PitcherLabResult>();
  const [careerResult, setCareerResult] = useState<HighSchoolCareerResult>();
  const [proResult, setProResult] = useState<ProCareerResult>();
  const [proVisible, setProVisible] = useState(false);
  const [labInningStats, setLabInningStats] = useState<LabInningStats>(EMPTY_LAB_INNING_STATS);
  const [error, setError] = useState<string>();
  const [saveNotice, setSaveNotice] = useState<string>();
  const [highContrast, setHighContrast] = useState(() => appStorage.getItem("baseball.a11y.contrast") === "true");
  const [reducedMotion, setReducedMotion] = useState(() => appStorage.getItem("baseball.a11y.motion") === "true");
  const [systemReducedMotion, setSystemReducedMotion] = useState(() => typeof window !== "undefined" && window.matchMedia("(prefers-reduced-motion: reduce)").matches);
  const [fontScale, setFontScale] = useState(() => parseFontScale(appStorage.getItem("baseball.a11y.font-scale")));
  const [analyticsOptIn, setAnalyticsOptIn] = useState(() => appStorage.getItem("baseball.analytics.opt-in") === "true");
  const [tutorialDismissed, setTutorialDismissed] = useState(() => appStorage.getItem("baseball.tutorial.completed") === "true");
  const [soundEnabled, setSoundEnabled] = useState(() => appStorage.getItem("baseball.feedback.sound") !== "false");
  const [hapticsEnabled, setHapticsEnabled] = useState(() => appStorage.getItem("baseball.feedback.haptics") !== "false");
  const [lastCall, setLastCall] = useState<PitchCall>();
  const [resultStage, setResultStage] = useState<"idle" | "impact" | "summary">("idle");
  const [showResultDetails, setShowResultDetails] = useState(false);
  const [showGameCast, setShowGameCast] = useState(false);
  const [stageExpanded, setStageExpanded] = useState(false);
  const [feedback] = useState(() => new GameFeedback());
  const gameCastRegionRef = useRef<HTMLElement | null>(null);
  const gameCastWasOpen = useRef(false);
  const pitchDecisionStartedAt = useRef(performance.now());
  const pitchInteractionCount = useRef(0);
  const careerDecisionStartedAt = useRef(performance.now());
  const proDecisionStartedAt = useRef(performance.now());
  const lastCareerTelemetryRevision = useRef<number | undefined>(undefined);
  const lastProTelemetryRevision = useRef<number | undefined>(undefined);
  const effectiveReducedMotion = reducedMotion || systemReducedMotion;

  const selectedPreset = presets.find((preset) => preset.id === selectedPresetID);
  const pitcher = experienceMode === "career"
    ? proVisible && proResult ? proResult.snapshot.pitcher : careerResult?.snapshot.pitcher ?? selectedPreset?.pitcher
    : labResult?.snapshot.pitcher ?? selectedPreset?.pitcher;
  const activeBatter: BatterSnapshot = experienceMode === "career" && proVisible && proResult
    ? proBatterFromRival(proResult.snapshot.currentRival)
    : experienceMode === "career" && careerResult ? {
        id: careerResult.snapshot.rival.id,
        name: careerResult.snapshot.rival.name,
        contact: careerResult.snapshot.rival.contact,
        discipline: careerResult.snapshot.rival.discipline,
        power: careerResult.snapshot.rival.power,
      }
    : BATTER;
  const selectedPitchProfile = pitcher?.pitchProfiles?.find(
    (profile) => profile.pitchType === pitchType,
  );

  // The scouting baseline follows the active run's information-clarity difficulty. Held in a ref so
  // prepare and submit read the same value within a plate appearance without re-creating handlers.
  const scoutReliabilityRef = useRef(scoutBaselineReliability(undefined));
  useEffect(() => {
    scoutReliabilityRef.current = scoutBaselineReliability(
      careerResult?.snapshot.difficulty?.informationClarity,
    );
  }, [careerResult?.snapshot.difficulty?.informationClarity]);

  const applyPitchCall = useCallback((call: PitchCall) => {
    setPitchType(call.pitchType);
    setZone(call.zone);
    setZoneIntent(call.zoneIntent);
    setIntensity(call.intensity);
  }, []);
  const applyManualPitchCall = useCallback((call: PitchCall) => {
    pitchInteractionCount.current += 1;
    applyPitchCall(call);
  }, [applyPitchCall]);
  const applyRecommendation = useCallback(
    (recommendation: CatcherRecommendationSnapshot) => applyPitchCall(recommendation.call),
    [applyPitchCall],
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
      const restored = loadPitcherLabAutosave(appStorage);
      const restoredCareer = loadHighSchoolCareer(appStorage);
      const restoredProCandidate = loadProCareer(appStorage);
      const restoredPro = restoredProCandidate
        && (bundledProAccess || restoredProCandidate.payload.proCareer.snapshot.entitlement.source !== "development")
        ? restoredProCandidate
        : undefined;
      if (restoredPro) {
        const saved = restoredPro.payload;
        const savedPreset = availablePresets.find((preset) => preset.id === saved.selectedPresetID);
        if (!savedPreset) throw new Error("저장된 프로 커리어의 투수 프리셋을 찾을 수 없습니다.");
        const normalizedCareer = await normalizeRegionalSchools({ seed: saved.highSchoolCareer.nextSeed, state: saved.highSchoolCareer.snapshot });
        const normalizedPro = await normalizeProCareerBalance({ seed: saved.proCareer.nextSeed, state: saved.proCareer.snapshot });
        setPresets(availablePresets); setSelectedPresetID(saved.selectedPresetID); setCareerResult(normalizedCareer);
        setProResult(normalizedPro); setProVisible(true); setScreenMode("lab"); setExperienceMode("career");
        setSaveNotice(restoredPro.source === "backup" ? "손상된 프로 저장 대신 마지막 정상 백업을 복구했습니다." : "프로 커리어 자동 저장에서 이어서 시작했습니다.");
        setCoreStatus({ state: "online", health }); return;
      }
      if (restoredCareer) {
        const saved = restoredCareer.payload;
        const savedPreset = availablePresets.find((preset) => preset.id === saved.selectedPresetID);
        if (!savedPreset) throw new Error("저장된 고교 커리어의 투수 프리셋을 찾을 수 없습니다.");
        const normalizedCareer = await normalizeRegionalSchools({ seed: saved.careerResult.nextSeed, state: saved.careerResult.snapshot });
        const careerBalanceChanged = normalizedCareer.snapshot.balanceVersion !== saved.careerResult.snapshot.balanceVersion;
        setPresets(availablePresets);
        setSelectedPresetID(saved.selectedPresetID);
        setSeed(saved.seed);
        setContext(saved.context);
        setPreparation(careerBalanceChanged ? undefined : saved.preparation);
        setLastResult(careerBalanceChanged ? undefined : saved.lastResult);
        setHistory(careerBalanceChanged ? [] : saved.history);
        setRivalMemory(careerBalanceChanged ? undefined : saved.rivalMemory);
        setGameState(saved.gameState);
        setGameLog(saved.gameLog);
        setCareerResult(normalizedCareer);
        setLabInningStats(saved.inningStats);
        setScreenMode(!careerBalanceChanged && saved.screenMode === "pitch" && saved.preparation ? "pitch" : "lab");
        setExperienceMode("career");
        if (!careerBalanceChanged && saved.preparation) applyRecommendation(saved.preparation.primaryRecommendation);
        setSaveNotice(restoredCareer.source === "backup"
          ? "손상된 고교 커리어 저장 대신 마지막 정상 백업을 복구했습니다."
          : "고교 커리어 자동 저장에서 이어서 시작했습니다.");
        setCoreStatus({ state: "online", health });
        return;
      }
      if (restored) {
        const saved = restored.payload;
        const savedPreset = availablePresets.find((preset) => preset.id === saved.selectedPresetID);
        if (!savedPreset) throw new Error("저장된 선수의 투수 유형을 찾을 수 없습니다.");
        const normalizedLab = await normalizePitcherLabBalance({ seed: saved.labResult.nextSeed, state: saved.labResult.snapshot });
        const balanceChanged = normalizedLab.snapshot.balanceVersion !== saved.labResult.snapshot.balanceVersion;
        setPresets(availablePresets);
        setSelectedPresetID(saved.selectedPresetID);
        setSeed(saved.seed);
        setContext(saved.context);
        setPreparation(balanceChanged ? undefined : saved.preparation);
        setLastResult(balanceChanged ? undefined : saved.lastResult);
        setHistory(balanceChanged ? [] : saved.history);
        setRivalMemory(balanceChanged ? undefined : saved.rivalMemory);
        setGameState(saved.gameState);
        setGameLog(saved.gameLog);
        setLabResult(normalizedLab);
        setExperienceMode("lab");
        setPreviousLifeResult(saved.previousLifeResult);
        setLabInningStats(saved.labInningStats);
        setScreenMode(!balanceChanged && saved.screenMode === "pitch" && saved.preparation ? "pitch" : "lab");
        if (!balanceChanged && saved.preparation) applyRecommendation(saved.preparation.primaryRecommendation);
        setSaveNotice(restored.source === "backup"
          ? "손상된 최신 저장 대신 마지막 정상 백업을 복구했습니다."
          : "자동 저장에서 이어서 시작했습니다.");
        setCoreStatus({ state: "online", health });
        return;
      }
      const initialPreparation = await preparePitch({
        seed: INITIAL_SEED,
        pitcher: initialPreset.pitcher,
        batter: BATTER,
        scouting: { ...SCOUTING, reliability: scoutReliabilityRef.current },
        context: INITIAL_CONTEXT,
        gameState: INITIAL_GAME_STATE,
        gameLog: INITIAL_GAME_LOG,
      });
      setPresets(availablePresets);
      setSelectedPresetID(initialPreset.id);
      setSeed(INITIAL_SEED);
      setContext(INITIAL_CONTEXT);
      setPreparation(initialPreparation);
      setLastResult(undefined);
      setHistory([]);
      setRivalMemory(undefined);
      setGameState(INITIAL_GAME_STATE);
      setGameLog(INITIAL_GAME_LOG);
      setLabResult(undefined);
      setPreviousLifeResult(undefined);
      setCareerResult(undefined);
      setLabInningStats(EMPTY_LAB_INNING_STATS);
      setScreenMode("lab");
      setExperienceMode("career");
      setSaveNotice(undefined);
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

  useEffect(() => {
    const handleCloudSave = (event: Event) => {
      const detail = (event as CustomEvent<{ state: "saved" | "error"; message: string }>).detail;
      if (detail?.state === "error") setSaveNotice(detail.message);
    };
    window.addEventListener("baseball:cloud-save", handleCloudSave);
    return () => window.removeEventListener("baseball:cloud-save", handleCloudSave);
  }, []);

  useEffect(() => {
    const query = window.matchMedia("(prefers-reduced-motion: reduce)");
    const handleChange = (event: MediaQueryListEvent) => setSystemReducedMotion(event.matches);
    setSystemReducedMotion(query.matches);
    query.addEventListener("change", handleChange);
    return () => query.removeEventListener("change", handleChange);
  }, []);

  useEffect(() => {
    document.body.classList.toggle("high-contrast", highContrast);
    document.body.classList.toggle("reduce-motion", effectiveReducedMotion);
    document.documentElement.style.setProperty("--font-scale", String(fontScale));
    appStorage.setItem("baseball.a11y.contrast", String(highContrast));
    appStorage.setItem("baseball.a11y.motion", String(reducedMotion));
    appStorage.setItem("baseball.a11y.font-scale", String(fontScale));
  }, [effectiveReducedMotion, fontScale, highContrast, reducedMotion]);

  useEffect(() => {
    appStorage.setItem("baseball.analytics.opt-in", String(analyticsOptIn));
  }, [analyticsOptIn]);

  useEffect(() => {
    appStorage.setItem("baseball.feedback.sound", String(soundEnabled));
    appStorage.setItem("baseball.feedback.haptics", String(hapticsEnabled));
  }, [hapticsEnabled, soundEnabled]);

  useEffect(() => {
    setShowResultDetails(false);
    if (!lastResult) { setResultStage("idle"); setShowGameCast(false); setStageExpanded(false); return; }
    setShowGameCast(true);
    setStageExpanded(isDecisiveResult(lastResult));
    if (effectiveReducedMotion) { setResultStage("summary"); return; }
    setResultStage("impact");
    const timer = window.setTimeout(() => setResultStage("summary"), 360);
    return () => window.clearTimeout(timer);
  }, [effectiveReducedMotion, lastResult?.eventHash]);

  useEffect(() => {
    if (!showGameCast || !lastResult) return;
    const frame = window.requestAnimationFrame(() => {
      const region = gameCastRegionRef.current;
      region?.scrollIntoView({
        behavior: effectiveReducedMotion ? "auto" : "smooth",
        block: "start",
      });
      region?.focus({ preventScroll: true });
    });
    return () => window.cancelAnimationFrame(frame);
  }, [effectiveReducedMotion, lastResult?.eventHash, showGameCast]);

  useEffect(() => {
    if (showGameCast) {
      gameCastWasOpen.current = true;
      return;
    }
    if (!lastResult || !gameCastWasOpen.current) return;
    gameCastWasOpen.current = false;
    const frame = window.requestAnimationFrame(() => {
      gameCastRegionRef.current?.querySelector<HTMLButtonElement>("button:not(:disabled)")?.focus();
    });
    return () => window.cancelAnimationFrame(frame);
  }, [lastResult?.eventHash, showGameCast]);

  useEffect(() => {
    pitchDecisionStartedAt.current = performance.now();
    pitchInteractionCount.current = 0;
  }, [preparation?.preparationToken]);

  useEffect(() => {
    if (!careerResult) {
      lastCareerTelemetryRevision.current = undefined;
      careerDecisionStartedAt.current = performance.now();
      return;
    }
    const revision = careerResult.snapshot.revision;
    if (lastCareerTelemetryRevision.current === undefined) {
      lastCareerTelemetryRevision.current = revision;
      careerDecisionStartedAt.current = performance.now();
      return;
    }
    if (lastCareerTelemetryRevision.current === revision) return;
    recordLocalAnalytics(appStorage, analyticsOptIn, {
      name: "career_decision_completed",
      occurredAt: new Date().toISOString(),
      properties: { event: careerResult.events[0]?.eventType ?? "unknown", phase: careerResult.snapshot.phase, revision, decisionMs: Math.round(performance.now() - careerDecisionStartedAt.current), life: careerResult.snapshot.lifeNumber, chapter: careerResult.snapshot.chapter.number, trainings: careerResult.snapshot.totalTrainingsCompleted, relationships: careerResult.snapshot.relationshipsCompleted, games: careerResult.snapshot.performance.importantGamesCompleted, awakenings: careerResult.snapshot.selectedAwakenings.length },
    });
    lastCareerTelemetryRevision.current = revision;
    careerDecisionStartedAt.current = performance.now();
  }, [analyticsOptIn, careerResult]);

  useEffect(() => {
    if (!proResult) {
      lastProTelemetryRevision.current = undefined;
      proDecisionStartedAt.current = performance.now();
      return;
    }
    const revision = proResult.snapshot.revision;
    if (lastProTelemetryRevision.current === undefined) {
      lastProTelemetryRevision.current = revision;
      proDecisionStartedAt.current = performance.now();
      return;
    }
    if (lastProTelemetryRevision.current === revision) return;
    recordLocalAnalytics(appStorage, analyticsOptIn, {
      name: "pro_decision_completed",
      occurredAt: new Date().toISOString(),
      properties: { event: proResult.events[0] ?? "unknown", phase: proResult.snapshot.phase, revision, decisionMs: Math.round(performance.now() - proDecisionStartedAt.current), season: proResult.snapshot.season, week: proResult.snapshot.week, level: proResult.snapshot.level, role: proResult.snapshot.role },
    });
    lastProTelemetryRevision.current = revision;
    proDecisionStartedAt.current = performance.now();
  }, [analyticsOptIn, proResult]);

  useEffect(() => {
    if (experienceMode !== "lab" || coreStatus.state !== "online" || !labResult || !selectedPresetID) return;
    const payload: PitcherLabAutosavePayload = {
      format: "BaseballPitcherLabAutosave",
      schemaVersion: 1,
      savedAt: new Date().toISOString(),
      selectedPresetID,
      screenMode,
      labResult,
      previousLifeResult,
      seed,
      context,
      preparation,
      lastResult,
      history,
      rivalMemory,
      gameState,
      gameLog,
      labInningStats,
    };
    try {
      savePitcherLabAutosave(appStorage, payload);
      setSaveNotice("자동 저장 완료");
    } catch (caught) {
      setSaveNotice(caught instanceof Error ? `자동 저장 실패 · ${caught.message}` : "자동 저장 실패");
    }
  }, [context, coreStatus.state, experienceMode, gameLog, gameState, history, labInningStats, labResult, lastResult, preparation, previousLifeResult, rivalMemory, screenMode, seed, selectedPresetID]);

  useEffect(() => {
    if (experienceMode !== "career" || coreStatus.state !== "online" || !careerResult || !selectedPresetID) return;
    const payload: HighSchoolCareerAutosavePayload = {
      format: "BaseballHighSchoolCareerAutosave",
      schemaVersion: 2,
      savedAt: new Date().toISOString(),
      selectedPresetID,
      screenMode,
      careerResult,
      seed,
      context,
      preparation,
      lastResult,
      history,
      rivalMemory,
      gameState,
      gameLog,
      inningStats: labInningStats,
    };
    try {
      saveHighSchoolCareer(appStorage, payload);
      setSaveNotice("고교 커리어 자동 저장 완료");
    } catch (caught) {
      setSaveNotice(caught instanceof Error ? `고교 커리어 자동 저장 실패 · ${caught.message}` : "고교 커리어 자동 저장 실패");
    }
  }, [careerResult, context, coreStatus.state, experienceMode, gameLog, gameState, history, labInningStats, lastResult, preparation, rivalMemory, screenMode, seed, selectedPresetID]);

  useEffect(() => {
    if (coreStatus.state !== "online" || !proResult || !careerResult || !selectedPresetID) return;
    try {
      saveProCareer(appStorage, { format: "BaseballProCareerAutosave", schemaVersion: 1, savedAt: new Date().toISOString(), selectedPresetID, highSchoolCareer: careerResult, proCareer: proResult });
      setSaveNotice("프로 커리어 자동 저장 완료");
    } catch (caught) { setSaveNotice(caught instanceof Error ? `프로 자동 저장 실패 · ${caught.message}` : "프로 자동 저장 실패"); }
  }, [careerResult, coreStatus.state, proResult, selectedPresetID]);

  const handleNewExperiment = useCallback(() => {
    if (!window.confirm("현재 선수의 훈련 기록을 지우고 새 선수를 만들까요?")) return;
    clearPitcherLabAutosave(appStorage);
    setLabResult(undefined);
    setPreviousLifeResult(undefined);
    setScreenMode("lab");
    setRivalMemory(undefined);
    setGameLog(INITIAL_GAME_LOG);
    setGameState(INITIAL_GAME_STATE);
    setLabInningStats(EMPTY_LAB_INNING_STATS);
    setLastResult(undefined);
    setHistory([]);
    setSaveNotice("새 선수를 만들 수 있습니다.");
  }, []);

  const handlePitch = useCallback(async () => {
    if (!preparation || !pitcher) return;
    setIsRunning(true);
    setError(undefined);
    try {
      const submittedCall: PitchCall = { pitchType, zone, zoneIntent, intensity };
      const result = await submitPitch({
        seed,
        pitcher,
        batter: activeBatter,
        scouting: { ...SCOUTING, reliability: scoutReliabilityRef.current },
        context,
        preparationToken: preparation.preparationToken,
        call: submittedCall,
        rivalMemory,
        gameState,
        gameLog,
      });
      setLastResult(result);
      setLastCall(submittedCall);
      setRivalMemory(result.rivalMemory);
      setGameState(result.gameState);
      setGameLog(result.gameLog);
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
        inning: result.gameState.inningState?.inning ?? current.inning,
        outs: result.gameState.inningState?.outs ?? current.outs,
        balls: result.snapshot.balls,
        strikes: result.snapshot.strikes,
        pitchNumber: result.nextPreparation ? current.pitchNumber + 1 : current.pitchNumber,
        fatigue: result.snapshot.fatigueAfterPitch,
      }));
      setPreparation(result.nextPreparation);
      if (result.nextPreparation) applyRecommendation(result.nextPreparation.primaryRecommendation);
      feedback.play(feedbackCueForResult(result), soundEnabled, hapticsEnabled);
      recordLocalAnalytics(appStorage, analyticsOptIn, {
        name: "pitch_resolved",
        occurredAt: new Date().toISOString(),
        properties: { outcome: result.snapshot.outcome, ended: result.snapshot.ended, acceptedCatcherCall: result.snapshot.recommendationAccepted, selectionQuality: result.snapshot.selectionQuality, pitchNumber: context.pitchNumber, decisionMs: Math.round(performance.now() - pitchDecisionStartedAt.current), interactionsBeforeThrow: pitchInteractionCount.current + 1, mode: experienceMode, importantGame: screenMode === "pitch" },
      });
      if (screenMode === "pitch" && (
        (experienceMode === "lab" && labResult?.snapshot.phase === "important_inning")
        || (experienceMode === "career" && careerResult?.snapshot.phase === "important_game" && !proVisible)
        || (experienceMode === "career" && proResult?.snapshot.phase === "important_game" && proVisible)
      )) {
        const latestEntry = result.gameLog.entries[result.gameLog.entries.length - 1];
        setLabInningStats((current) => ({
          pitches: current.pitches + 1,
          strikeouts: current.strikeouts + (result.snapshot.result === "strikeout" ? 1 : 0),
          walks: current.walks + (result.snapshot.result === "walk" ? 1 : 0),
          runsAllowed: current.runsAllowed + result.snapshot.runsScored,
          expectedDamage: current.expectedDamage + (latestEntry?.expectedDamage ?? 0),
          actualDamage: current.actualDamage + (latestEntry?.actualDamage ?? 0),
          recommendationAccepted: current.recommendationAccepted + (result.snapshot.recommendationAccepted ? 1 : 0),
        }));
      }
    } catch (caught) {
      const message =
        caught instanceof Error ? caught.message : "투구 결과를 계산하지 못했습니다.";
      setError(message);
      try {
        setPreparation(await preparePitch({
          seed,
          pitcher,
          batter: activeBatter,
          scouting: { ...SCOUTING, reliability: scoutReliabilityRef.current },
          context,
          rivalMemory,
          gameState,
          gameLog,
        }));
      } catch {
        setCoreStatus({ state: "offline", message });
      }
    } finally {
      setIsRunning(false);
    }
  }, [activeBatter, analyticsOptIn, applyRecommendation, careerResult?.snapshot.phase, context, experienceMode, feedback, gameLog, gameState, hapticsEnabled, intensity, labResult?.snapshot.phase, pitchType, pitcher, preparation, proResult?.snapshot.phase, proVisible, rivalMemory, screenMode, seed, soundEnabled, zone, zoneIntent]);

  const handleNewPlateAppearance = useCallback(async () => {
    if (!pitcher) return;
    setIsRunning(true);
    setError(undefined);
    const nextContext: PlateAppearanceContext = {
      ...INITIAL_CONTEXT,
      plateAppearanceID: `pa-prototype-${Date.now()}`,
      inning: gameState.inningState?.inning ?? context.inning,
      outs: gameState.inningState?.outs ?? context.outs,
      fatigue: context.fatigue,
    };
    try {
      const nextPreparation = await preparePitch({
        seed,
        pitcher,
        batter: activeBatter,
        scouting: { ...SCOUTING, reliability: scoutReliabilityRef.current },
        context: nextContext,
        rivalMemory,
        gameState,
        gameLog,
      });
      setContext(nextContext);
      setPreparation(nextPreparation);
      setLastResult(undefined);
      setHistory([]);
      applyRecommendation(nextPreparation.primaryRecommendation);
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "새 타석을 시작하지 못했습니다.");
    } finally {
      setIsRunning(false);
    }
  }, [activeBatter, applyRecommendation, context.fatigue, context.inning, context.outs, gameLog, gameState, pitcher, rivalMemory, seed]);

  const handlePresetChange = useCallback(async (presetID: string) => {
    const nextPreset = presets.find((preset) => preset.id === presetID);
    if (!nextPreset || nextPreset.id === selectedPresetID) return;
    setIsRunning(true);
    setError(undefined);
    const nextContext: PlateAppearanceContext = {
      ...INITIAL_CONTEXT,
      plateAppearanceID: `pa-preset-${nextPreset.id}-${Date.now()}`,
    };
    const nextGameLog: GameLogSnapshot = {
      ...INITIAL_GAME_LOG,
      gameID: `practice-game-${nextPreset.id}-${Date.now()}`,
    };
    try {
      const nextPreparation = await preparePitch({
        seed,
        pitcher: nextPreset.pitcher,
        batter: activeBatter,
        scouting: { ...SCOUTING, reliability: scoutReliabilityRef.current },
        context: nextContext,
        gameState: INITIAL_GAME_STATE,
        gameLog: nextGameLog,
      });
      setSelectedPresetID(nextPreset.id);
      setContext(nextContext);
      setPreparation(nextPreparation);
      setLastResult(undefined);
      setHistory([]);
      setRivalMemory(undefined);
      setGameState(INITIAL_GAME_STATE);
      setGameLog(nextGameLog);
      applyRecommendation(nextPreparation.primaryRecommendation);
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "투수 프리셋을 바꾸지 못했습니다.");
    } finally {
      setIsRunning(false);
    }
  }, [applyRecommendation, presets, seed, selectedPresetID]);

  const runLabAction = useCallback(async (action: () => Promise<PitcherLabResult>) => {
    setIsRunning(true);
    setError(undefined);
    try {
      const next = await action();
      setLabResult(next);
      return next;
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "선택을 처리하지 못했습니다. 다시 시도해 주세요.");
    } finally {
      setIsRunning(false);
    }
  }, []);

  const handleStartLab = useCallback(async (
    presetID: string,
    creationAllocation: CreationAllocationSnapshot,
    playerName: string,
  ) => {
    await runLabAction(() => startPitcherLab({
      seed: "20260722",
      presetID,
      playerName,
      lifeNumber: 1,
      inheritedSoulPoints: 0,
      creationAllocation,
    }));
    setSelectedPresetID(presetID);
  }, [runLabAction]);

  const handleTraining = useCallback(async (focus: TrainingFocus, trainingIntensity: TrainingIntensity) => {
    if (!labResult) return;
    const next = await runLabAction(() => commitTraining({
      seed: labResult.nextSeed,
      state: labResult.snapshot,
      focus,
      intensity: trainingIntensity,
    }));
    const training = next?.snapshot.lastTraining;
    if ((training?.ratingPointsApplied ?? 0) > 0 && training?.ratingBefore !== undefined && training.ratingAfter !== undefined) {
      feedback.play(crossedGrowthMilestone(training.ratingBefore, training.ratingAfter) ? "growth" : "progress", soundEnabled, hapticsEnabled);
    }
  }, [feedback, hapticsEnabled, labResult, runLabAction, soundEnabled]);

  const handleRelationship = useCallback(async (choice: RelationshipChoice) => {
    if (!labResult) return;
    await runLabAction(() => chooseRelationship({
      seed: labResult.nextSeed,
      state: labResult.snapshot,
      choice,
    }));
  }, [labResult, runLabAction]);

  const handleAwakening = useCallback(async (awakening: AwakeningID) => {
    if (!labResult) return;
    await runLabAction(() => chooseAwakening({
      seed: labResult.nextSeed,
      state: labResult.snapshot,
      awakening,
    }));
  }, [labResult, runLabAction]);

  const handleFinalizeScouting = useCallback(async () => {
    if (!labResult) return;
    await runLabAction(() => finalizeScouting({
      seed: labResult.nextSeed,
      state: labResult.snapshot,
    }));
  }, [labResult, runLabAction]);

  const handleSelectLegacy = useCallback(async (soulDomain: SoulDomain, memoryCard: MemoryCardID) => {
    if (!labResult) return;
    await runLabAction(() => selectLegacy({
      seed: labResult.nextSeed,
      state: labResult.snapshot,
      soulDomain,
      memoryCard,
    }));
  }, [labResult, runLabAction]);

  const handleStartSecondLife = useCallback(async () => {
    const legacy = labResult?.snapshot.legacySelection;
    if (!labResult || !legacy) return;
    await runLabAction(() => startPitcherLab({
      seed: labResult.nextSeed,
      presetID: labResult.snapshot.presetID,
      playerName: labResult.snapshot.pitcher.name,
      lifeNumber: labResult.snapshot.lifeNumber + 1,
      inheritedSoulPoints: legacy.soulPointsGranted,
      inheritedSoulDomain: legacy.soulDomain,
      inheritedMemory: legacy.memoryCard,
      creationAllocation: { stuff: 2, command: 1, movement: 1, stamina: 1 },
    }));
    setPreviousLifeResult(labResult);
    setRivalMemory(undefined);
    setGameLog(INITIAL_GAME_LOG);
    setLabInningStats(EMPTY_LAB_INNING_STATS);
  }, [labResult, runLabAction]);

  const handleStartImportantInning = useCallback(async () => {
    if (!labResult) return;
    const scenario = labResult.snapshot.performance.importantInningsCompleted + 1;
    const scenarioInning = scenario === 1 ? 3 : scenario === 2 ? 5 : 7;
    const scenarioOuts = scenario === 1 ? 0 : 1;
    const scenarioRunners: BaserunnerStateSnapshot = scenario === 1
      ? { firstOccupied: false, secondOccupied: false, thirdOccupied: false, leadRunnerSpeed: 55 }
      : scenario === 2
        ? { firstOccupied: true, secondOccupied: false, thirdOccupied: false, leadRunnerSpeed: 62 }
        : { firstOccupied: true, secondOccupied: false, thirdOccupied: true, leadRunnerSpeed: 64 };
    const scenarioContext: PlateAppearanceContext = {
      ...INITIAL_CONTEXT,
      plateAppearanceID: `lab-${labResult.snapshot.runID}-inning-${scenario}-pa-1`,
      inning: scenarioInning,
      outs: scenarioOuts,
      leverage: scenario === 1 ? 420 : scenario === 2 ? 720 : 930,
      fatigue: labResult.snapshot.fatigue,
    };
    const scenarioState: GameStateSnapshot = {
      ...INITIAL_GAME_STATE,
      runners: scenarioRunners,
      runsAllowed: 0,
      inningState: { inning: scenarioInning, half: "bottom", outs: scenarioOuts },
    };
    const scenarioLog: GameLogSnapshot = {
      ...INITIAL_GAME_LOG,
      gameID: `${labResult.snapshot.runID}-important-inning-${scenario}`,
    };
    setIsRunning(true);
    setError(undefined);
    try {
      const nextPreparation = await preparePitch({
        seed: labResult.nextSeed,
        pitcher: labResult.snapshot.pitcher,
        batter: BATTER,
        scouting: { ...SCOUTING, reliability: scoutReliabilityRef.current },
        context: scenarioContext,
        rivalMemory,
        gameState: scenarioState,
        gameLog: scenarioLog,
      });
      setSeed(labResult.nextSeed);
      setContext(scenarioContext);
      setGameState(scenarioState);
      setGameLog(scenarioLog);
      setPreparation(nextPreparation);
      setLastResult(undefined);
      setHistory([]);
      setLabInningStats(EMPTY_LAB_INNING_STATS);
      applyRecommendation(nextPreparation.primaryRecommendation);
      setScreenMode("pitch");
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "중요 이닝을 시작하지 못했습니다.");
    } finally {
      setIsRunning(false);
    }
  }, [activeBatter, applyRecommendation, labResult, rivalMemory]);

  const handleCompleteImportantInning = useCallback(async () => {
    if (!labResult || labInningStats.pitches === 0) return;
    const report: ImportantInningReport = {
      scenarioNumber: labResult.snapshot.performance.importantInningsCompleted + 1,
      ...labInningStats,
    };
    setIsRunning(true);
    setError(undefined);
    try {
      const nextLab = await recordImportantInning({
        seed: labResult.nextSeed,
        state: labResult.snapshot,
        report,
      });
      setLabResult(nextLab);
      setScreenMode("lab");
      setLastResult(undefined);
      setHistory([]);
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "중요 이닝 결과를 반영하지 못했습니다.");
    } finally {
      setIsRunning(false);
    }
  }, [labInningStats, labResult]);

  const runCareerAction = useCallback(async (action: () => Promise<HighSchoolCareerResult>) => {
    setIsRunning(true);
    setError(undefined);
    try {
      setCareerResult(await action());
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "고교 커리어 결정을 처리하지 못했습니다.");
    } finally {
      setIsRunning(false);
    }
  }, []);

  const handleStartCareer = useCallback(async (presetID: string, creationAllocation: CreationAllocationSnapshot,
    identity: PlayerIdentitySnapshot, difficulty: CareerDifficultySnapshot, karmas: ReadonlyArray<KarmaID>) => {
    await runCareerAction(() => startHighSchoolCareer({
      seed: "20260723",
      presetID,
      lifeNumber: 1,
      creationAllocation,
      inheritedSoulPoints: 0,
      inheritedMemories: [],
      identity,
      difficulty,
      karmas,
    }));
    setSelectedPresetID(presetID);
    setExperienceMode("career");
  }, [runCareerAction]);

  const handleCompleteCareerPrologue = useCallback(async () => {
    if (!careerResult) return;
    await runCareerAction(() => completeMiddleSchoolPrologue({ seed: careerResult.nextSeed, state: careerResult.snapshot }));
  }, [careerResult, runCareerAction]);

  const handleCareerSchool = useCallback(async (schoolID: SchoolID) => {
    if (!careerResult) return;
    await runCareerAction(() => chooseSchool({ seed: careerResult.nextSeed, state: careerResult.snapshot, schoolID }));
  }, [careerResult, runCareerAction]);

  const handleCareerTraining = useCallback(async (focus: TrainingFocus, trainingIntensity: TrainingIntensity) => {
    if (!careerResult) return;
    await runCareerAction(() => commitCareerTraining({ seed: careerResult.nextSeed, state: careerResult.snapshot, focus, intensity: trainingIntensity }));
  }, [careerResult, runCareerAction]);

  const handleCareerRelationship = useCallback(async (response: RelationshipResponse) => {
    if (!careerResult) return;
    await runCareerAction(() => resolveCareerRelationship({ seed: careerResult.nextSeed, state: careerResult.snapshot, response }));
  }, [careerResult, runCareerAction]);

  const handleCareerAwakening = useCallback(async (awakening: AwakeningID) => {
    if (!careerResult) return;
    await runCareerAction(() => chooseCareerAwakening({ seed: careerResult.nextSeed, state: careerResult.snapshot, awakening }));
    feedback.play("milestone", soundEnabled, hapticsEnabled);
  }, [careerResult, feedback, hapticsEnabled, runCareerAction, soundEnabled]);

  const handleAdvanceCareerChapter = useCallback(async () => {
    if (!careerResult) return;
    await runCareerAction(() => advanceCareerChapter({ seed: careerResult.nextSeed, state: careerResult.snapshot }));
  }, [careerResult, runCareerAction]);

  const handleCareerDraft = useCallback(async () => {
    if (!careerResult) return;
    recordLocalAnalytics(appStorage, analyticsOptIn, { name: "draft_reveal_started", occurredAt: new Date().toISOString(), properties: { life: careerResult.snapshot.lifeNumber, evaluationBand: careerResult.snapshot.difficulty.informationClarity } });
    await runCareerAction(() => resolveDraft({ seed: careerResult.nextSeed, state: careerResult.snapshot }));
  }, [analyticsOptIn, careerResult, runCareerAction]);

  const handleCareerLegacy = useCallback(async (memoryCards: ReadonlyArray<MemoryCardID>) => {
    if (!careerResult) return;
    await runCareerAction(() => selectCareerLegacy({ seed: careerResult.nextSeed, state: careerResult.snapshot, memoryCards }));
  }, [careerResult, runCareerAction]);

  const handleStartCareerGame = useCallback(async () => {
    if (!careerResult) return;
    const scenario = careerResult.snapshot.performance.importantGamesCompleted + 1;
    const careerBatter: BatterSnapshot = {
      id: careerResult.snapshot.rival.id,
      name: careerResult.snapshot.rival.name,
      contact: careerResult.snapshot.rival.contact,
      discipline: careerResult.snapshot.rival.discipline,
      power: careerResult.snapshot.rival.power,
    };
    const content = careerResult.snapshot.currentGameScenario;
    const inning = content?.inning ?? Math.min(9, 2 + scenario);
    const outs = content?.outs ?? scenario % 2;
    const runners: BaserunnerStateSnapshot = content?.runners ?? (scenario === 1
      ? { firstOccupied: false, secondOccupied: false, thirdOccupied: false, leadRunnerSpeed: 58 }
      : scenario % 2 === 0
        ? { firstOccupied: true, secondOccupied: false, thirdOccupied: false, leadRunnerSpeed: 64 }
        : { firstOccupied: true, secondOccupied: false, thirdOccupied: true, leadRunnerSpeed: 66 });
    const nextContext: PlateAppearanceContext = {
      ...INITIAL_CONTEXT,
      plateAppearanceID: `${careerResult.snapshot.careerID}-game-${scenario}-pa-1`,
      inning,
      outs,
      leverage: content?.leverage ?? Math.min(980, 380 + scenario * 120),
      fatigue: careerResult.snapshot.fatigue,
    };
    const nextState: GameStateSnapshot = {
      ...INITIAL_GAME_STATE,
      park: careerResult.snapshot.school ? {
        ...INITIAL_GAME_STATE.park,
        id: `${careerResult.snapshot.school.id}-park`,
        name: `${careerResult.snapshot.school.name} 야구장`,
      } : INITIAL_GAME_STATE.park,
      runners,
      runsAllowed: 0,
      inningState: { inning, half: "bottom", outs },
    };
    const nextLog: GameLogSnapshot = {
      ...INITIAL_GAME_LOG,
      gameID: `${careerResult.snapshot.careerID}-important-game-${scenario}`,
    };
    setIsRunning(true);
    setError(undefined);
    try {
      const nextPreparation = await preparePitch({
        seed: careerResult.nextSeed,
        pitcher: careerResult.snapshot.pitcher,
        batter: careerBatter,
        scouting: { ...SCOUTING, reliability: scoutReliabilityRef.current },
        context: nextContext,
        rivalMemory,
        gameState: nextState,
        gameLog: nextLog,
      });
      setSeed(careerResult.nextSeed);
      setContext(nextContext);
      setGameState(nextState);
      setGameLog(nextLog);
      setPreparation(nextPreparation);
      setLastResult(undefined);
      setHistory([]);
      setLabInningStats(EMPTY_LAB_INNING_STATS);
      applyRecommendation(nextPreparation.primaryRecommendation);
      setScreenMode("pitch");
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "중요 경기를 시작하지 못했습니다.");
    } finally {
      setIsRunning(false);
    }
  }, [applyRecommendation, careerResult, rivalMemory]);

  const handleCompleteCareerGame = useCallback(async () => {
    if (!careerResult || labInningStats.pitches === 0) return;
    const report: ImportantInningReport = {
      scenarioNumber: careerResult.snapshot.performance.importantGamesCompleted + 1,
      ...labInningStats,
    };
    setIsRunning(true);
    setError(undefined);
    try {
      setCareerResult(await recordCareerGame({ seed: careerResult.nextSeed, state: careerResult.snapshot, report }));
      setScreenMode("lab");
      setLastResult(undefined);
      setHistory([]);
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "중요 경기 결과를 반영하지 못했습니다.");
    } finally {
      setIsRunning(false);
    }
  }, [careerResult, labInningStats]);

  const handleNextCareerLife = useCallback(async () => {
    if (!careerResult || !selectedPresetID || careerResult.snapshot.selectedMemories.length !== careerResult.snapshot.memorySlots) return;
    await runCareerAction(() => startHighSchoolCareer({
      seed: careerResult.nextSeed,
      presetID: selectedPresetID,
      lifeNumber: careerResult.snapshot.lifeNumber + 1,
      creationAllocation: { stuff: 2, command: 1, movement: 1, stamina: 1 },
      inheritedSoulPoints: 2,
      inheritedSoulDomain: "game",
      inheritedMemories: careerResult.snapshot.selectedMemories,
      identity: careerResult.snapshot.identity,
      difficulty: careerResult.snapshot.difficulty,
      karmas: careerResult.snapshot.karmas,
    }));
    setRivalMemory(undefined);
    setGameLog(INITIAL_GAME_LOG);
  }, [careerResult, runCareerAction, selectedPresetID]);

  const handleOpenCareer = useCallback(() => {
    setExperienceMode("career");
    setScreenMode("lab");
    setError(undefined);
  }, []);

  const handleNewCareer = useCallback(() => {
    if (!window.confirm("현재 고교 커리어 진행을 지우고 새 삶을 시작할까요?")) return;
    clearHighSchoolCareer(appStorage);
    clearProCareer(appStorage);
    setCareerResult(undefined);
    setProResult(undefined);
    setProVisible(false);
    setScreenMode("lab");
    setRivalMemory(undefined);
    setGameLog(INITIAL_GAME_LOG);
    setGameState(INITIAL_GAME_STATE);
    setLabInningStats(EMPTY_LAB_INNING_STATS);
    setLastResult(undefined);
    setHistory([]);
    setSaveNotice("새 고교 커리어를 준비했습니다.");
  }, []);

  const handleOpenPractice = useCallback(() => {
    setExperienceMode("lab");
    setScreenMode("lab");
    setError(undefined);
  }, []);

  const runProAction = useCallback(async (action: () => Promise<ProCareerResult>) => {
    setIsRunning(true); setError(undefined);
    try { setProResult(await action()); } catch (caught) { setError(caught instanceof Error ? caught.message : String(caught)); }
    finally { setIsRunning(false); }
  }, []);
  const handleStartPro = useCallback(async () => {
    if (proResult) { setProVisible(true); return; }
    if (!careerResult?.snapshot.draftResult || careerResult.snapshot.draftResult.outcome !== "drafted") return;
    if (!bundledProAccess) {
      setError("프로 커리어는 정식판에서 이어서 플레이할 수 있습니다.");
      return;
    }
    setProVisible(true);
    await runProAction(() => startProCareer({ seed: careerResult.nextSeed, identity: careerResult.snapshot.identity, pitcher: careerResult.snapshot.pitcher,
      draftResult: careerResult.snapshot.draftResult!, entitlement: {
        productID: releaseEdition === "steam_full" ? "baseball_steam_full" : "baseball_development",
        status: "active",
        source: releaseEdition === "steam_full" ? "purchase" : "development",
        verifiedAt: new Date().toISOString(),
      } }));
  }, [bundledProAccess, careerResult, proResult, releaseEdition, runProAction]);
  const handleSignPro = useCallback(async () => { if (proResult) await runProAction(() => signProContract({ seed: proResult.nextSeed, state: proResult.snapshot })); }, [proResult, runProAction]);
  const handlePlanPro = useCallback(async (plan: ProWeekPlan) => { if (proResult) await runProAction(() => planProWeek({ seed: proResult.nextSeed, state: proResult.snapshot, plan })); }, [proResult, runProAction]);
  const handlePlanProBlock = useCallback(async (plan: ProWeekPlan) => {
    if (!proResult) return;
    setIsRunning(true); setError(undefined);
    try {
      let current = proResult;
      for (let index = 0; index < 3 && current.snapshot.phase === "weekly_plan"; index += 1) {
        current = await planProWeek({ seed: current.nextSeed, state: current.snapshot, plan });
      }
      setProResult(current);
      // 1군 콜업(major_call_up) 스팅어는 ProCareerView가 데뷔 단계 진입에서 한 번 울린다.
      // 여기서 또 재생하면 3주 진행 경로에서만 이중으로 울려 단주 경로와 어긋나므로 두지 않는다.
    } catch (caught) { setError(caught instanceof Error ? caught.message : String(caught)); }
    finally { setIsRunning(false); }
  }, [proResult]);
  const handleProGame = useCallback(async () => {
    if (!proResult) return;
    const inning = proResult.snapshot.role === "starter" ? 7 : proResult.snapshot.role === "closer" ? 9 : 8;
    const proContext: PlateAppearanceContext = {
      ...INITIAL_CONTEXT,
      plateAppearanceID: `${proResult.snapshot.proCareerID}-season-${proResult.snapshot.season}-week-${proResult.snapshot.week}-pa-1`,
      inning,
      outs: 1,
      leverage: 920,
      fatigue: proResult.snapshot.fatigue,
    };
    const proState: GameStateSnapshot = {
      ...INITIAL_GAME_STATE,
      runners: { firstOccupied: false, secondOccupied: true, thirdOccupied: false, leadRunnerSpeed: 67 },
      runsAllowed: 0,
      inningState: { inning, half: "bottom", outs: 1 },
    };
    const proLog: GameLogSnapshot = {
      ...INITIAL_GAME_LOG,
      gameID: `${proResult.snapshot.proCareerID}-season-${proResult.snapshot.season}-week-${proResult.snapshot.week}`,
    };
    setIsRunning(true);
    setError(undefined);
    try {
      const nextPreparation = await preparePitch({
        seed: proResult.nextSeed,
        pitcher: proResult.snapshot.pitcher,
        batter: proBatterFromRival(proResult.snapshot.currentRival),
        scouting: { ...SCOUTING, reliability: scoutReliabilityRef.current },
        context: proContext,
        rivalMemory,
        gameState: proState,
        gameLog: proLog,
      });
      setSeed(proResult.nextSeed);
      setContext(proContext);
      setGameState(proState);
      setGameLog(proLog);
      setPreparation(nextPreparation);
      setLastResult(undefined);
      setHistory([]);
      setLabInningStats(EMPTY_LAB_INNING_STATS);
      applyRecommendation(nextPreparation.primaryRecommendation);
      setScreenMode("pitch");
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "중요 경기를 시작하지 못했습니다.");
    } finally {
      setIsRunning(false);
    }
  }, [applyRecommendation, proResult, rivalMemory]);
  const handleCompleteProGame = useCallback(async () => {
    if (!proResult || labInningStats.pitches === 0) return;
    const report: ImportantInningReport = { scenarioNumber: proResult.snapshot.week, ...labInningStats };
    setIsRunning(true);
    setError(undefined);
    try {
      setProResult(await resolveProImportantGame({ seed: proResult.nextSeed, state: proResult.snapshot, report }));
      setScreenMode("lab");
      setLastResult(undefined);
      setHistory([]);
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "중요 경기 결과를 반영하지 못했습니다.");
    } finally {
      setIsRunning(false);
    }
  }, [labInningStats, proResult]);
  const handleReviewPro = useCallback(async () => { if (proResult) await runProAction(() => reviewProSeason({ seed: proResult.nextSeed, state: proResult.snapshot })); }, [proResult, runProAction]);
  const handleProOffseason = useCallback(async (decision: OffseasonDecision) => { if (proResult) await runProAction(() => chooseProOffseason({ seed: proResult.nextSeed, state: proResult.snapshot, decision })); }, [proResult, runProAction]);

  const cycleFontScale = useCallback(() => setFontScale(nextFontScale), []);
  const handleMilestoneFeedback = useCallback((cue: "progress" | "growth" | "milestone" = "milestone") => {
    feedback.play(cue, soundEnabled, hapticsEnabled);
  }, [feedback, hapticsEnabled, soundEnabled]);
  const dismissTutorial = useCallback(() => {
    setTutorialDismissed(true);
    appStorage.setItem("baseball.tutorial.completed", "true");
  }, []);
  const downloadDiagnostics = useCallback(() => {
    const save = loadHighSchoolCareer(appStorage)?.payload;
    const health = coreStatus.state === "online" ? coreStatus.health : undefined;
    downloadTextFile(`baseball-diagnostic-${new Date().toISOString().slice(0, 10)}.json`, createAnonymousDiagnosticPackage({
      appVersion: "1.0.0", coreVersion: health?.coreVersion, protocolVersion: health?.protocolVersion,
      error, save, analytics: readLocalAnalytics(appStorage),
    }));
    setSaveNotice("개인 식별 정보를 제외한 문제 해결 자료를 저장했습니다.");
  }, [coreStatus, error]);
  const accessibilityProps = {
    highContrast, reducedMotion: effectiveReducedMotion, systemReducedMotion, fontScale, analyticsOptIn, soundEnabled, hapticsEnabled,
    onContrast: () => setHighContrast((value) => !value),
    onMotion: () => setReducedMotion((value) => !value),
    onFontScale: cycleFontScale,
    onAnalytics: () => setAnalyticsOptIn((value) => !value),
    onSound: () => setSoundEnabled((value) => !value),
    onHaptics: () => setHapticsEnabled((value) => !value),
    onDiagnostics: downloadDiagnostics,
    onResetProgress: () => {
      resetAllProgress(appStorage);
      window.location.reload();
    },
  };

  const online = coreStatus.state === "online";
  const primaryRecommendation = preparation?.primaryRecommendation;
  const alternativeRecommendation = preparation?.alternativeRecommendation;
  const plateEnded = lastResult?.snapshot.ended ?? false;
  const rivalAdaptation = preparation?.rivalAdaptation ?? lastResult?.rivalAdaptation;
  const scoutingReport = preparation?.scoutingReport;
  const importantInningEnded = Boolean(lastResult?.snapshot.inningTransition?.inningEnded && (
    (experienceMode === "career" && (
      (proVisible && proResult?.snapshot.phase === "important_game")
      || (!proVisible && careerResult?.snapshot.phase === "important_game")
    ))
    || labResult?.snapshot.phase === "important_inning"
  ));
  const gameCastContinueLabel = isRunning
    ? "다음 장면 준비 중…"
    : importantInningEnded
      ? "중요 이닝 종료 · 기록 화면으로"
      : lastResult?.snapshot.inningTransition?.inningEnded
        ? "다음 수비 이닝 시작"
        : plateEnded
          ? "다음 타석 시작"
          : "다음 투구 선택";
  const careerSchool = careerResult?.snapshot.school;
  const showingProCareer = Boolean(proVisible && proResult);
  const careerModeTitle = showingProCareer ? "프로 커리어" : "고교 커리어";
  const careerModeFooter = showingProCareer
    ? `${proResult?.snapshot.team.name ?? "프로 구단"} · ${proResult?.snapshot.level === "major" ? "1군" : "2군"}`
    : `고교 커리어${careerResult ? ` · ${careerResult.snapshot.chapter.schoolYear}학년 ${careerResult.snapshot.chapter.season}` : ""}`;
  const displayedGameState = gameStateForReplay(gameState, lastResult, showGameCast);
  const handleGameCastContinue = () => {
    setStageExpanded(false);
    if (!plateEnded) { setShowGameCast(false); return; }
    if (lastResult?.snapshot.inningTransition?.inningEnded && experienceMode === "career" && proVisible && proResult?.snapshot.phase === "important_game") {
      void handleCompleteProGame();
    } else if (lastResult?.snapshot.inningTransition?.inningEnded && experienceMode === "career" && careerResult?.snapshot.phase === "important_game") {
      void handleCompleteCareerGame();
    } else if (lastResult?.snapshot.inningTransition?.inningEnded && labResult?.snapshot.phase === "important_inning") {
      void handleCompleteImportantInning();
    } else {
      void handleNewPlateAppearance();
    }
  };

  if (screenMode === "lab" && experienceMode === "career") {
    return (
      <div className={`app-shell app-shell--career ${showingProCareer ? "app-shell--pro" : "app-shell--high-school"}`}>
        <header className="topbar">
          <div className="brand-lockup"><img className="brand-mark" src="/128x128.png" alt="" /><div>
            <p className="eyebrow">야구 못하면 또 환생함</p><h1>{careerModeTitle}</h1>
          </div></div>
          <nav className="mode-tabs" aria-label="모드 선택">
            <button className="ds-chip" type="button" aria-current="page">커리어</button>
            <button className="ds-chip" type="button" onClick={handleOpenPractice}>연습 모드</button>
          </nav>
          {coreStatus.state !== "online" ? <div className={`core-status core-status--${coreStatus.state}`} role="status" aria-live="polite"><span className="status-dot" aria-hidden="true" /><span>{statusMessage(coreStatus)}</span>
            {coreStatus.state === "offline" && (careerResult || proResult || presets.length > 0)
              ? <button type="button" onClick={() => void connectCore()}>다시 연결</button>
              : null}</div> : null}
          <AccessibilityControls {...accessibilityProps} />
        </header>
        {saveNotice ? <div className="save-notice" role="status">{saveNotice}</div> : null}
        {proVisible && proResult ? <ProCareerView result={proResult} isRunning={isRunning} error={error} onSign={handleSignPro} onPlan={handlePlanPro} onPlanBlock={handlePlanProBlock}
          onGame={handleProGame} onReview={handleReviewPro} onOffseason={handleProOffseason} onBack={() => setProVisible(false)} onMilestoneFeedback={handleMilestoneFeedback} />
        : careerResult ? <HighSchoolCareerView key={careerResult.snapshot.careerID} result={careerResult} isRunning={isRunning} error={error}
          showTutorial={!tutorialDismissed && careerResult.snapshot.lifeNumber === 1} onDismissTutorial={dismissTutorial}
          onSchool={handleCareerSchool} onTraining={handleCareerTraining} onRelationship={handleCareerRelationship}
          onCompletePrologue={handleCompleteCareerPrologue}
          onImportantGame={handleStartCareerGame} onAwakening={handleCareerAwakening}
          onAdvanceChapter={handleAdvanceCareerChapter} onDraft={handleCareerDraft}
          onLegacy={handleCareerLegacy} onNextLife={handleNextCareerLife}
          onNewCareer={handleNewCareer} onStartPro={handleStartPro}
          proAccessAvailable={bundledProAccess || (proResult?.snapshot.entitlement.status === "active" && proResult.snapshot.entitlement.source !== "development")}
          demoMode={releaseEdition === "steam_demo" || releaseEdition === "web_teaser"}
          onMilestoneFeedback={handleMilestoneFeedback} />
          : <HighSchoolCareerSetup presets={presets} isRunning={isRunning || coreStatus.state === "checking"}
            error={error} coreMessage={statusDetail(coreStatus)} onRetryCore={() => void connectCore()} onStart={handleStartCareer} />}
        <footer><span>{careerModeFooter}</span>
          <span>선택이 확정될 때마다 자동 저장됩니다.</span></footer>
      </div>
    );
  }

  if (screenMode === "lab") {
    return (
      <div className="app-shell app-shell--lab">
        <header className="topbar">
          <div className="brand-lockup">
            <img className="brand-mark" src="/128x128.png" alt="" />
            <div>
              <p className="eyebrow">야구 못하면 또 환생함</p>
              <h1>연습 모드</h1>
            </div>
          </div>
          <nav className="mode-tabs" aria-label="모드 선택">
            <button className="ds-chip" type="button" onClick={handleOpenCareer}>커리어</button>
            <button className="ds-chip" type="button" aria-current="page">연습 모드</button>
          </nav>
          {coreStatus.state !== "online" ? <div className={`core-status core-status--${coreStatus.state}`} role="status" aria-live="polite">
            <span className="status-dot" aria-hidden="true" />
            <span>{statusMessage(coreStatus)}</span>
            {coreStatus.state === "offline" && (labResult || presets.length > 0) ? (
              <button type="button" onClick={() => void connectCore()}>다시 연결</button>
            ) : null}
          </div> : null}
          <AccessibilityControls {...accessibilityProps} />
        </header>
        {saveNotice ? <div className="save-notice" role="status">{saveNotice}</div> : null}
        {labResult ? (
          <PitcherLabView
            result={labResult}
            previousLifeResult={previousLifeResult}
            isRunning={isRunning}
            error={error}
            onTrain={handleTraining}
            onStartImportantInning={handleStartImportantInning}
            onRelationship={handleRelationship}
            onAwakening={handleAwakening}
            onFinalizeScouting={handleFinalizeScouting}
            onSelectLegacy={handleSelectLegacy}
            onStartSecondLife={handleStartSecondLife}
            onNewExperiment={handleNewExperiment}
          />
        ) : (
          <PitcherLabSetup
            presets={presets}
            isRunning={isRunning || coreStatus.state === "checking"}
            error={error}
            coreMessage={statusDetail(coreStatus)}
            onRetryCore={() => void connectCore()}
            onStart={handleStartLab}
          />
        )}
        <footer>
          <span>연습 모드{labResult ? ` · ${labResult.snapshot.lifeNumber}번째 선수` : " · 새 선수"}</span>
          <span>선택이 확정될 때마다 자동 저장됩니다.</span>
        </footer>
      </div>
    );
  }

  return (
    <div className={`app-shell app-shell--pitch ${showGameCast && lastResult && stageExpanded ? "app-shell--gamecast" : ""}`}
      data-team={proVisible && proResult ? proResult.snapshot.team.id : careerResult?.snapshot.draftResult?.team?.id}>
      <header className="topbar">
        <div className="brand-lockup">
          <img className="brand-mark" src="/128x128.png" alt="" />
          <div>
            <p className="eyebrow">야구 못하면 또 환생함</p>
            <h1>{experienceMode === "career" ? proVisible ? "프로 중요 경기" : "고교 중요 경기" : labResult?.snapshot.phase === "important_inning" ? "중요 이닝" : "투구 연습"}</h1>
          </div>
        </div>
        {coreStatus.state !== "online" ? <div className={`core-status core-status--${coreStatus.state}`} role="status" aria-live="polite">
          <span className="status-dot" aria-hidden="true" />
          <span>{statusMessage(coreStatus)}</span>
          {coreStatus.state === "offline" ? (
            <button type="button" onClick={() => void connectCore()}>다시 연결</button>
          ) : null}
        </div> : null}
        <AccessibilityControls {...accessibilityProps} />
      </header>

      <main>
        <section className="game-context" aria-label="경기 상황">
          <div>
            <span className="context-label">{experienceMode === "career" ? proVisible && proResult ? `${proResult.snapshot.team.name} 중요 경기` : `${careerResult?.snapshot.school?.name ?? "고교"} 중요 경기` : "고교 연습 경기"} · {halfInningLabel(displayedGameState)}</span>
            <strong>{outsLabel(displayedGameState)} · {runnerLabel(displayedGameState.runners)} · B {context.balls} / S {context.strikes} · {context.pitchNumber}구</strong>
          </div>
          <div className="matchup">
            <span>{pitcher?.name ?? "투수 준비 중"}</span><b>VS</b><span>{activeBatter.name}</span>
          </div>
          <div className="ds-scoreboard scoreboard" aria-label={`현재 허용 실점 ${displayedGameState.runsAllowed}`}>
            <span>수비 기록</span><strong>{displayedGameState.runsAllowed}실점</strong><span>{displayedGameState.park.name}</span>
          </div>
        </section>

        <div className={`workspace-grid workspace-grid--split ${showGameCast && lastResult && stageExpanded ? "workspace-grid--gamecast" : ""}`}>
          <section ref={gameCastRegionRef} tabIndex={showGameCast && lastResult ? -1 : undefined}
            className={`ds-card panel pitch-stage-panel${stageExpanded ? " is-expanded" : ""}`}
            aria-label={showGameCast && lastResult ? "플레이 리플레이" : "경기장"}>
            {showGameCast && lastResult ? <>
              <button className="ds-chip pitch-stage-toggle" type="button"
                onClick={() => setStageExpanded((value) => !value)}>
                {stageExpanded ? "작게 보기" : "크게 보기 ⤢"}
              </button>
              <GameCastReplay
                key={lastResult.eventHash}
                result={lastResult}
                pitchType={lastCall?.pitchType}
                situationLabel={`${halfInningLabel(displayedGameState)} · ${outsLabel(displayedGameState)} · ${runnerLabel(displayedGameState.runners)}`}
                pitcherName={pitcher?.name ?? "투수"}
                batterName={activeBatter.name}
                continueLabel={gameCastContinueLabel}
                isRunning={isRunning}
                reducedMotion={effectiveReducedMotion}
                onContinue={handleGameCastContinue}
              />
            </> : <div className="gamecast-idle" aria-hidden="true">
              <div className="gamecast-idle__zone" />
              <p>공을 고르고 던지면 이 자리에서 궤적이 재생됩니다</p>
            </div>}
            {error ? <p className="error-message" role="alert">{error}</p> : null}
          </section>
          <aside className="ds-card ds-player-card panel player-panel" aria-label="선수 정보">
            <div className="panel-heading">
              <div><p className="eyebrow">내 투수</p><h2>{pitcher?.name ?? "불러오는 중"}</h2></div>
              <span className="ds-badge role-badge">{selectedPreset?.name ?? "투수 유형"}</span>
            </div>
            <label className="preset-picker">
              <span>투수 유형</span>
              <select
                value={selectedPresetID ?? ""}
                disabled={isRunning || presets.length === 0 || experienceMode === "career" || labResult?.snapshot.phase === "important_inning"}
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
              <AvatarFace className="avatar" seed={pitcher?.name ?? "선수"} role="player" width={44} height={56} />
              <div><strong>{pitcherRoleLabel(experienceMode === "career" && proVisible ? proResult?.snapshot.role : undefined)} · {pitchHint(pitcher?.pitchProfiles?.find((profile) => profile.pitchType === "four_seam"))}</strong><span>피로 {context.fatigue} · {pitcherCondition(context.fatigue)}</span></div>
            </div>
            {pitcher ? (
              <div className="stat-list" aria-label="현재 능력치">
                <StatRow label="구위" value={pitcher.stuff} />
                <StatRow label="제구" value={pitcher.command} />
                <StatRow label="변화구" value={pitcher.movement} />
                <StatRow label="체력" value={pitcher.stamina} />
              </div>
            ) : null}
            <div className="environment-card" aria-label="수비와 구장 환경">
              <div><span>수비 지원</span><strong>내야 {gameState.defense.infield} · 외야 {gameState.defense.outfield}</strong></div>
              <div className="fielder-strip">
                {gameState.defense.fielders
                  ?.filter((fielder) => ["catcher", "shortstop", "center_field"].includes(fielder.position))
                  .map((fielder) => (
                    <span key={fielder.id}>{fielderLabel(fielder.position)} {fielder.name} · {fielder.glove}</span>
                  ))}
              </div>
              <div><span>구장</span><strong>{gameState.park.name}</strong></div>
              <small>안타 {rateLabel(gameState.park.hitFactor)} · 홈런 {rateLabel(gameState.park.homeRunFactor)}</small>
            </div>
            <div className="scouting-card">
              <span>상대 타자 리포트</span>
              <strong>{activeBatter.name}</strong>
              <p>{batterScoutingReport(activeBatter)}</p>
              <div className="mini-stats">
                <span>공 맞히기 {activeBatter.contact}</span><span>볼 고르기 {activeBatter.discipline}</span><span>장타력 {activeBatter.power}</span>
              </div>
              {scoutingReport ? (
                <div className={`scouting-confidence scouting-confidence--${scoutingReport.band}`}>
                  <div>
                    <span>스카우팅 신뢰도</span>
                    <strong>{SCOUT_BAND_LABELS[scoutingReport.band]}</strong>
                  </div>
                  <div className="adaptation-track" aria-label={`스카우팅 신뢰도 ${scoutingReport.reliability} / 100`}>
                    <span style={{ width: `${scoutingReport.reliability}%` }} />
                  </div>
                  <p>
                    {scoutingReport.band === "trusted"
                      ? `약점은 ${pitchLabel(scoutingReport.estimatedWeakness)} · ${zoneLabel(scoutingReport.estimatedColdZone)}로 굳어졌습니다.`
                      : `아직 추정입니다. 약점은 ${pitchLabel(scoutingReport.estimatedWeakness)} · ${zoneLabel(scoutingReport.estimatedColdZone)} 근처로 보이며, 관측이 쌓이면 정확해집니다.`}
                  </p>
                  <small>
                    관측 {scoutingReport.observationCount}구 · 적극성 {scoutingReport.chaseTendencyMargin > 0
                      ? `${Math.max(20, scoutingReport.estimatedChaseTendency - scoutingReport.chaseTendencyMargin)}–${Math.min(80, scoutingReport.estimatedChaseTendency + scoutingReport.chaseTendencyMargin)}`
                      : scoutingReport.estimatedChaseTendency}
                  </small>
                </div>
              ) : null}
              {rivalAdaptation ? (
                <div className={`rival-adaptation rival-adaptation--${rivalAdaptation.band}`}>
                  <div>
                    <span>타자가 내 투구를 읽는 정도</span>
                    <strong>{ADAPTATION_LABELS[rivalAdaptation.band]}</strong>
                  </div>
                  <div className="adaptation-track" aria-label={`라이벌 적응도 ${rivalAdaptation.level} / 900`}>
                    <span style={{ width: `${Math.min(100, rivalAdaptation.level / 9)}%` }} />
                  </div>
                  <p>{rivalAdaptation.warning}</p>
                  <small>
                    상대가 본 투구 {rivalAdaptation.evidenceCount}구
                    {rivalMemory ? ` · 재대결 ${rivalMemory.plateAppearancesSeen}회` : ""}
                  </small>
                </div>
              ) : null}
            </div>
          </aside>

          <section className="ds-card ds-card--raised panel decision-panel" aria-label="투구 선택">
            <>
            <div className="panel-heading">
              <div><p className="eyebrow">승부 선택</p><h2>어떻게 승부할까요?</h2></div>
              <span className="ds-badge count-badge">B {context.balls} · S {context.strikes}</span>
            </div>

            {primaryRecommendation ? (
              <div className="catcher-call">
                <div className="catcher-icon" aria-hidden="true">C</div>
                <div>
                  <span>포수 추천 · 자신감 {Math.round(primaryRecommendation.confidence / 10)}%</span>
                  <strong>{recommendationTitle(primaryRecommendation)}</strong>
                  <p>{primaryRecommendation.shortReason}</p>
                  <div className="recommendation-actions">
                    <button type="button" onClick={() => applyManualPitchCall(primaryRecommendation.call)}>포수 추천으로 되돌리기</button>
                    {alternativeRecommendation ? (
                      <button type="button" onClick={() => applyManualPitchCall(alternativeRecommendation.call)}>
                        대안: {pitchLabel(alternativeRecommendation.call.pitchType)}
                      </button>
                    ) : null}
                    {lastCall ? <button type="button" onClick={() => applyManualPitchCall(lastCall)}>직전 선택 반복</button> : null}
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
                      disabled={!profile} aria-pressed={pitchType === option.value} onClick={() => { pitchInteractionCount.current += 1; setPitchType(option.value); }}>
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
                    <div><dt>스트라이크</dt><dd>{selectedPitchProfile.control}</dd></div>
                    <div><dt>코스 제구</dt><dd>{selectedPitchProfile.command}</dd></div>
                    <div><dt>변화량</dt><dd>{selectedPitchProfile.movement}</dd></div>
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
                        aria-label={label} aria-pressed={selected} onClick={() => { pitchInteractionCount.current += 1; setZone(currentZone); }}>
                        <span aria-hidden="true" />
                      </button>
                    );
                  })}
                </div>
                <p className="selection-caption">선택: {zoneLabel(zone)}</p>
              </fieldset>

              <div className="pitch-modifiers">
                <fieldset className="choice-group intensity-group">
                  <legend>3. 승부 범위</legend>
                  <div className="intensity-options">
                    {INTENT_OPTIONS.map((option) => (
                      <button key={option.value} type="button" className={zoneIntent === option.value ? "is-selected" : undefined}
                        aria-pressed={zoneIntent === option.value} onClick={() => { pitchInteractionCount.current += 1; setZoneIntent(option.value); }}>
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
                        aria-pressed={intensity === option.value} onClick={() => { pitchInteractionCount.current += 1; setIntensity(option.value); }}>
                        <strong>{option.label}</strong><span>{option.hint}</span>
                      </button>
                    ))}
                  </div>
                </fieldset>
              </div>
            </div>

            {plateEnded ? (
              <button className="ds-button ds-button--primary primary-action" type="button" disabled={isRunning}
                onClick={() => lastResult?.snapshot.inningTransition?.inningEnded && experienceMode === "career" && proVisible && proResult?.snapshot.phase === "important_game"
                  ? void handleCompleteProGame()
                  : lastResult?.snapshot.inningTransition?.inningEnded && experienceMode === "career" && careerResult?.snapshot.phase === "important_game"
                    ? void handleCompleteCareerGame()
                  : lastResult?.snapshot.inningTransition?.inningEnded && labResult?.snapshot.phase === "important_inning"
                    ? void handleCompleteImportantInning()
                  : void handleNewPlateAppearance()}>
                {isRunning
                  ? "새 타석 준비 중…"
                  : lastResult?.snapshot.inningTransition?.inningEnded && ((experienceMode === "career" && ((proVisible && proResult?.snapshot.phase === "important_game") || (!proVisible && careerResult?.snapshot.phase === "important_game"))) || labResult?.snapshot.phase === "important_inning")
                    ? "중요 이닝 종료 · 기록 화면으로"
                    : lastResult?.snapshot.inningTransition?.inningEnded
                      ? "다음 수비 이닝 시작"
                    : "다음 타석 시작"}
              </button>
            ) : (
              <button className="ds-button ds-button--primary primary-action" type="button" disabled={!online || !preparation || isRunning}
                onClick={() => void handlePitch()}>
                {isRunning ? "투구 계산 중…" : online && preparation ? "던지기" : "포수 사인 준비 중"}
              </button>
            )}
            {error ? <p className="error-message" role="alert">{error}</p> : null}
            </>
          </section>

          <aside className="ds-card ds-card--result panel result-panel" aria-label="투구 결과">
            <div className="panel-heading">
              <div><p className="eyebrow">결과</p><h2>투구 결과</h2></div>
                  <span className="ds-badge seed-label">{context.pitchNumber}구째</span>
            </div>

            {lastResult ? (
              <div className={`result-content result-content--${resultStage} ${showResultDetails ? "is-expanded" : ""}`} aria-live="polite" aria-label={lastResult.snapshot.accessibilitySummary}>
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
                {resultStage === "summary" ? <button className="result-details-toggle" type="button" aria-expanded={showResultDetails} onClick={() => setShowResultDetails((value) => !value)}>
                  {showResultDetails ? "핵심 결과만 보기" : "투구·타구·분석 자세히 보기"}
                </button> : null}
                <p className="result-detail">{lastResult.snapshot.detailFeedback}</p>
                <dl className="result-facts">
                  <div><dt>존 판정</dt><dd>{Math.abs(lastResult.snapshot.execution.actualX) <= 500 && Math.abs(lastResult.snapshot.execution.actualY) <= 500 ? "존 안" : "존 밖"}</dd></div>
                  <div><dt>구속</dt><dd>{(lastResult.snapshot.execution.velocityTenthsKPH / 10).toFixed(1)} km/h</dd></div>
                  <div><dt>코스 정확도</dt><dd>{lastResult.snapshot.execution.executionQuality} / 1000</dd></div>
                </dl>
                {lastResult.snapshot.battedBall ? (
                  <dl className="result-facts batted-ball-facts">
                    <div><dt>타구 속도</dt><dd>{(lastResult.snapshot.battedBall.exitVelocityTenthsKPH / 10).toFixed(1)} km/h</dd></div>
                    <div><dt>발사각</dt><dd>{(lastResult.snapshot.battedBall.launchAngleTenthsDegrees / 10).toFixed(1)}°</dd></div>
                    <div><dt>타구 강도</dt><dd>{lastResult.snapshot.battedBall.contactQuality} / 1000</dd></div>
                  </dl>
                ) : null}
                {lastResult.snapshot.fieldingResolution ? (
                  <div className={`fielding-resolution fielding-resolution--${lastResult.snapshot.fieldingResolution.impact}`}>
                    <div>
                      <span>타구만 본 결과</span>
                      <strong>{OUTCOME_LABELS[lastResult.snapshot.fieldingResolution.neutralOutcome]}</strong>
                      <b aria-hidden="true">→</b>
                      <span>최종 결과</span>
                      <strong>{OUTCOME_LABELS[lastResult.snapshot.fieldingResolution.finalOutcome]}</strong>
                    </div>
                    <p>{lastResult.snapshot.fieldingResolution.shortExplanation}</p>
                    <small>
                      {lastResult.snapshot.fieldingResolution.fielderName
                        ? `${fielderLabel(lastResult.snapshot.fieldingResolution.fielderPosition)} ${lastResult.snapshot.fieldingResolution.fielderName} · `
                        : ""}
                      수비 {lastResult.snapshot.fieldingResolution.defenseRating}
                      {` · 구장 영향 ${lastResult.snapshot.fieldingResolution.parkAdjustment >= 0 ? "+" : ""}${lastResult.snapshot.fieldingResolution.parkAdjustment}`}
                    </small>
                  </div>
                ) : null}
                {lastResult.snapshot.stealAttempt ? (
                  <div className={`situation-resolution situation-resolution--${lastResult.snapshot.stealAttempt.succeeded ? "positive" : "negative"}`}>
                    <span>주루 승부 · {lastResult.snapshot.stealAttempt.fromBase}루 → {lastResult.snapshot.stealAttempt.toBase}루</span>
                    <strong>{lastResult.snapshot.stealAttempt.succeeded ? "도루 성공" : "도루 저지"}</strong>
                    <p>{lastResult.snapshot.stealAttempt.shortExplanation}</p>
                    <small>주력 {lastResult.snapshot.stealAttempt.runnerSpeed} · 포수 송구 {lastResult.snapshot.stealAttempt.catcherArm}</small>
                  </div>
                ) : null}
                {lastResult.snapshot.inningTransition && (
                  lastResult.snapshot.inningTransition.outsRecorded > 0
                  || lastResult.snapshot.inningTransition.inningEnded
                ) ? (
                  <div className="situation-resolution situation-resolution--inning">
                    <span>아웃카운트</span>
                    <strong>
                      {lastResult.snapshot.inningTransition.doublePlayCompleted
                        ? "병살 완성"
                        : lastResult.snapshot.inningTransition.inningEnded
                          ? `${halfInningLabel({ ...gameState, inningState: lastResult.snapshot.inningTransition.after })}로 전환`
                          : `${lastResult.snapshot.inningTransition.outsRecorded}아웃 추가`}
                    </strong>
                    <p>{lastResult.snapshot.inningTransition.shortExplanation}</p>
                  </div>
                ) : null}
                {lastResult.snapshot.ended ? (
                  <div className="runner-resolution">
                    <span>{runnerLabel(lastResult.snapshot.runnersAfter)}</span>
                    <strong>{lastResult.snapshot.runsScored > 0 ? `${lastResult.snapshot.runsScored}실점` : "실점 없음"}</strong>
                  </div>
                ) : null}
                <div className="event-proof">
                  <span>타자 노림수 → 포수 사인 → 나의 선택 → 결과</span>
                  <strong>선택을 확정한 뒤 결과가 계산됩니다.</strong>
                </div>
              </div>
            ) : (
              <div className="empty-result">
                <div aria-hidden="true">◇</div><strong>타자의 노림수는 이미 정해졌습니다</strong>
                <p>포수 추천을 그대로 쓰거나 수정한 뒤 첫 공을 던져보세요.</p>
              </div>
            )}

            {lastResult && showResultDetails ? (
              <section className="postgame-analysis" aria-label="경기 후 분석 미리보기">
                <div className="section-label">
                  <span>경기 후 분석 미리보기</span>
                  <small>{confidenceLabel(lastResult.postgameAnalysis.confidence)} · {lastResult.postgameAnalysis.sampleSize}구</small>
                </div>
                <div className="analysis-metrics">
                  <div><span>스트라이크존 비율</span><strong>{rateLabel(lastResult.postgameAnalysis.zoneRate)}</strong></div>
                  <div><span>헛스윙률</span><strong>{rateLabel(lastResult.postgameAnalysis.whiffRate)}</strong></div>
                  <div><span>강한 타구</span><strong>{rateLabel(lastResult.postgameAnalysis.hardHitRate)}</strong></div>
                  <div><span>평균 코스 정확도</span><strong>{lastResult.postgameAnalysis.averageExecutionQuality} / 1000</strong></div>
                  <div><span>예상 출루·장타 위험</span><strong>{(lastResult.postgameAnalysis.expectedDamage / 1000).toFixed(2)}</strong></div>
                  <div><span>실제 출루·장타 위험</span><strong>{(lastResult.postgameAnalysis.actualDamage / 1000).toFixed(2)}</strong></div>
                </div>
                <p>{lastResult.postgameAnalysis.patternWarning}</p>
                <strong className="growth-signal">{lastResult.postgameAnalysis.growthSignal}</strong>
                {lastResult.postgameAnalysis.pitchBreakdowns.length > 0 ? (
                  <div className="pitch-analysis-list">
                    {lastResult.postgameAnalysis.pitchBreakdowns.map((breakdown) => (
                      <div key={breakdown.pitchType}>
                        <strong>{pitchLabel(breakdown.pitchType)} <small>{breakdown.pitches}구</small></strong>
                        <span>존 {rateLabel(breakdown.zoneRate)} · 헛스윙 {rateLabel(breakdown.whiffRate)} · 강타 {rateLabel(breakdown.hardHitRate)}</span>
                      </div>
                    ))}
                  </div>
                ) : null}
              </section>
            ) : null}

            <div className="history-section">
              <div className="section-label"><span>이번 타석 투구</span><small>최대 5개</small></div>
              {history.length > 0 ? (
                <ol className="history-list">
                  {history.map((event) => (
                    <li key={event.eventHash}>
                      <span className={`history-dot history-dot--${outcomeTone(event.outcome)}`} aria-hidden="true" />
                      <div><strong>{OUTCOME_LABELS[event.outcome]} · {event.count}</strong></div>
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
        <span>중요 이닝</span>
        <span>선택이 확정될 때마다 자동 저장됩니다.</span>
      </footer>
    </div>
  );
}
