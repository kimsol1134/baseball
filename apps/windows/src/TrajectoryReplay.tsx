import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { CSSProperties } from "react";
import type {
  BaserunnerStateSnapshot,
  BattedBall,
  FieldingResolutionSnapshot,
  FielderPosition,
  PitchExecution,
  PitchKernelResult,
  PitchOutcome,
  PitchType,
} from "./simulationTypes";

type Point = { x: number; y: number };

export interface TrajectoryPoint3D {
  timeMilliseconds: number;
  lateralTenthsCM: number;
  forwardTenthsCM: number;
  heightTenthsCM: number;
}

export interface PitchPlot {
  target: Point;
  actual: Point;
  control: Point;
  path: string;
}

export interface BattedBallPlot {
  landing: Point;
  control: Point;
  path: string;
  distanceMeters: number;
  hangTimeSeconds: number;
  apexHeightMeters: number;
}

export interface GameCastTimeline {
  pitchEnd: number;
  contactAt: number;
  fieldEnd: number;
  resultAt: number;
  total: number;
}

export type GameCastPhase = "pitch" | "contact" | "field" | "result";

export interface RunnerMotion {
  id: string;
  fromBase: number;
  toBase: number;
  isOut: boolean;
}

const PITCH_LABELS: Record<PitchType, string> = {
  four_seam: "포심",
  slider: "슬라이더",
  curveball: "커브",
  changeup: "체인지업",
};

const OUTCOME_LABELS: Record<PitchOutcome, string> = {
  ball: "볼",
  called_strike: "루킹 스트라이크",
  swinging_strike: "헛스윙",
  foul: "파울",
  in_play_out: "범타",
  single: "안타",
  double: "2루타",
  home_run: "홈런",
};

const SELECTION_QUALITY_LABELS = {
  poor: "나쁜 판단",
  risky: "위험 감수",
  good: "좋은 판단",
  excellent: "탁월한 판단",
} as const;

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

const FIELD_MARKERS: ReadonlyArray<{ position: FielderPosition; x: number; y: number; short: string }> = [
  { position: "catcher", x: 320, y: 374, short: "포" },
  { position: "pitcher", x: 320, y: 270, short: "투" },
  { position: "first_base", x: 486, y: 250, short: "1" },
  { position: "second_base", x: 385, y: 222, short: "2" },
  { position: "third_base", x: 154, y: 250, short: "3" },
  { position: "shortstop", x: 255, y: 222, short: "유" },
  { position: "left_field", x: 170, y: 188, short: "좌" },
  { position: "center_field", x: 320, y: 175, short: "중" },
  { position: "right_field", x: 470, y: 188, short: "우" },
];

const FIELD_HOME: Point = { x: 320, y: 365 };

const BASE_ROUTE: ReadonlyArray<Point> = [
  FIELD_HOME,
  { x: 486, y: 257 },
  { x: 320, y: 218 },
  { x: 154, y: 257 },
  FIELD_HOME,
];

const EMPTY_RUNNERS: BaserunnerStateSnapshot = {
  firstOccupied: false,
  secondOccupied: false,
  thirdOccupied: false,
  leadRunnerSpeed: 50,
};

const clamp = (value: number, lower: number, upper: number) => Math.min(upper, Math.max(lower, value));
const lerp = (start: number, end: number, progress: number) => start + (end - start) * progress;

export function decodeTrajectorySeries(series?: ReadonlyArray<number>): ReadonlyArray<TrajectoryPoint3D> {
  if (!series) return [];
  const samples: TrajectoryPoint3D[] = [];
  for (let index = 0; index + 3 < series.length; index += 4) {
    const values = series.slice(index, index + 4);
    if (values.some((value) => !Number.isFinite(value))) continue;
    samples.push({
      timeMilliseconds: values[0],
      lateralTenthsCM: values[1],
      forwardTenthsCM: values[2],
      heightTenthsCM: values[3],
    });
  }
  return samples.sort((left, right) => left.timeMilliseconds - right.timeMilliseconds);
}

export function interpolateTrajectory(
  samples: ReadonlyArray<TrajectoryPoint3D>,
  timeMilliseconds: number,
): TrajectoryPoint3D | undefined {
  if (samples.length === 0) return undefined;
  if (timeMilliseconds <= samples[0].timeMilliseconds) return samples[0];
  const finalSample = samples[samples.length - 1];
  if (timeMilliseconds >= finalSample.timeMilliseconds) return finalSample;
  for (let index = 1; index < samples.length; index += 1) {
    const next = samples[index];
    if (next.timeMilliseconds < timeMilliseconds) continue;
    const previous = samples[index - 1];
    const duration = Math.max(1, next.timeMilliseconds - previous.timeMilliseconds);
    const progress = (timeMilliseconds - previous.timeMilliseconds) / duration;
    return {
      timeMilliseconds,
      lateralTenthsCM: lerp(previous.lateralTenthsCM, next.lateralTenthsCM, progress),
      forwardTenthsCM: lerp(previous.forwardTenthsCM, next.forwardTenthsCM, progress),
      heightTenthsCM: lerp(previous.heightTenthsCM, next.heightTenthsCM, progress),
    };
  }
  return finalSample;
}

function platePoint(x: number, y: number): Point {
  return {
    x: clamp(160 + x * 0.11, 18, 302),
    y: clamp(198 - y * 0.105, 24, 286),
  };
}

/** Legacy-compatible summary geometry; live playback uses the complete 3D series. */
export function createPitchPlot(execution: PitchExecution): PitchPlot {
  const target = platePoint(execution.targetX, execution.targetY);
  const actual = platePoint(execution.actualX, execution.actualY);
  const fallbackControlX = execution.actualX * 0.62 - execution.horizontalBreakTenthsCM * 1.25;
  const fallbackControlY = 494 + execution.actualY * 0.62 + execution.verticalBreakTenthsCM;
  const control = platePoint(
    execution.trajectoryControlX ?? fallbackControlX,
    execution.trajectoryControlY ?? fallbackControlY,
  );
  return {
    target,
    actual,
    control,
    path: `M 160 18 Q ${control.x.toFixed(1)} ${control.y.toFixed(1)}, ${actual.x.toFixed(1)} ${actual.y.toFixed(1)}`,
  };
}

function projectPitchSample(
  sample: TrajectoryPoint3D,
  samples: ReadonlyArray<TrajectoryPoint3D>,
  execution: PitchExecution,
): Point {
  const first = samples[0];
  const last = samples[samples.length - 1];
  const progress = clamp(
    (first.forwardTenthsCM - sample.forwardTenthsCM)
      / Math.max(1, first.forwardTenthsCM - last.forwardTenthsCM),
    0,
    1,
  );
  const actual = platePoint(execution.actualX, execution.actualY);
  const linearLateral = lerp(first.lateralTenthsCM, last.lateralTenthsCM, progress);
  const linearHeight = lerp(first.heightTenthsCM, last.heightTenthsCM, progress);
  const perspective = 0.45 + progress * 0.55;
  return {
    x: lerp(160, actual.x, progress)
      + ((sample.lateralTenthsCM - linearLateral) / 10) * 1.15 * perspective,
    y: lerp(18, actual.y, progress)
      - ((sample.heightTenthsCM - linearHeight) / 10) * 0.48 * perspective,
  };
}

function pitchReplayPoints(execution: PitchExecution): ReadonlyArray<{ time: number; point: Point }> {
  const samples = decodeTrajectorySeries(execution.trajectorySeries);
  if (samples.length >= 2) {
    return samples.map((sample) => ({
      time: sample.timeMilliseconds,
      point: projectPitchSample(sample, samples, execution),
    }));
  }
  const plot = createPitchPlot(execution);
  const duration = execution.flightTimeMilliseconds ?? 480;
  return [
    { time: 0, point: { x: 160, y: 18 } },
    { time: Math.round(duration * 0.62), point: plot.control },
    { time: duration, point: plot.actual },
  ];
}

function interpolateReplayPoint(
  samples: ReadonlyArray<{ time: number; point: Point }>,
  time: number,
): Point {
  if (time <= samples[0].time) return samples[0].point;
  const last = samples[samples.length - 1];
  if (time >= last.time) return last.point;
  for (let index = 1; index < samples.length; index += 1) {
    const next = samples[index];
    if (next.time < time) continue;
    const previous = samples[index - 1];
    const progress = (time - previous.time) / Math.max(1, next.time - previous.time);
    return {
      x: lerp(previous.point.x, next.point.x, progress),
      y: lerp(previous.point.y, next.point.y, progress),
    };
  }
  return last.point;
}

function legacyDistance(battedBall: BattedBall, fielding: FieldingResolutionSnapshot) {
  const velocity = battedBall.exitVelocityTenthsKPH / 10;
  const launchAngle = battedBall.launchAngleTenthsDegrees / 10;
  const carry = velocity * 0.42 + Math.max(0, launchAngle) * 1.1 + battedBall.contactQuality * 0.02;
  switch (fielding.sector) {
    case "infield": return clamp(carry * 0.38, 12, 42);
    case "outfield": return clamp(carry, 48, 104);
    case "fence": return clamp(carry, 105, 140);
  }
}

function projectFieldSample(sample: TrajectoryPoint3D): Point {
  return {
    x: clamp(FIELD_HOME.x + (sample.lateralTenthsCM / 1_000) * 2.5, 72, 568),
    y: clamp(FIELD_HOME.y - (sample.forwardTenthsCM / 1_000) * 2.35, 76, FIELD_HOME.y),
  };
}

/** Projects the core-resolved landing point onto the top-down stadium. */
export function createBattedBallPlot(
  battedBall: BattedBall,
  fielding: FieldingResolutionSnapshot,
): BattedBallPlot {
  const samples = decodeTrajectorySeries(fielding.ballFlightSeries);
  const directionDegrees = clamp(battedBall.directionTenthsDegrees / 10, -45, 45);
  const directionRadians = directionDegrees * Math.PI / 180;
  const distanceMeters = (fielding.landingDistanceTenthsMeters ?? legacyDistance(battedBall, fielding) * 10) / 10;
  const seriesLanding = samples.length > 0 ? projectFieldSample(samples[samples.length - 1]) : undefined;
  const lateral = Math.sin(directionRadians) * distanceMeters;
  const forward = Math.cos(directionRadians) * distanceMeters;
  const landing = seriesLanding ?? {
    x: clamp(FIELD_HOME.x + lateral * 2.5, 72, 568),
    y: clamp(FIELD_HOME.y - forward * 2.35, 76, FIELD_HOME.y - 7),
  };
  const curveDirection = directionDegrees === 0 ? 1 : Math.sign(directionDegrees);
  const control = {
    x: FIELD_HOME.x + (landing.x - FIELD_HOME.x) * 0.48 - curveDirection * Math.min(12, Math.abs(directionDegrees) * 0.22),
    y: FIELD_HOME.y - (FIELD_HOME.y - landing.y) * 0.54,
  };
  return {
    landing,
    control,
    path: `M ${FIELD_HOME.x} ${FIELD_HOME.y} Q ${control.x.toFixed(1)} ${control.y.toFixed(1)}, ${landing.x.toFixed(1)} ${landing.y.toFixed(1)}`,
    distanceMeters,
    hangTimeSeconds: (fielding.hangTimeMilliseconds ?? 1_200) / 1_000,
    apexHeightMeters: (fielding.apexHeightTenthsMeters ?? 0) / 10,
  };
}

export function createGameCastTimeline(
  execution: PitchExecution,
  fielding?: FieldingResolutionSnapshot,
): GameCastTimeline {
  const pitchEnd = clamp(execution.flightTimeMilliseconds ?? 480, 330, 650);
  const hasContact = Boolean(fielding);
  const contactAt = pitchEnd + (hasContact ? 90 : 0);
  const fieldDuration = hasContact
    ? clamp((fielding?.hangTimeMilliseconds ?? 1_200) * 0.45, 760, 1_850)
    : 0;
  const fieldEnd = contactAt + fieldDuration;
  const resultAt = hasContact ? fieldEnd + 120 : pitchEnd + 150;
  return { pitchEnd, contactAt, fieldEnd, resultAt, total: resultAt };
}

export function gameCastPhase(
  elapsed: number,
  timeline: GameCastTimeline,
  hasContact: boolean,
): GameCastPhase {
  if (elapsed < timeline.pitchEnd) return "pitch";
  if (!hasContact) return elapsed < timeline.resultAt ? "contact" : "result";
  if (elapsed < timeline.contactAt) return "contact";
  if (elapsed < timeline.resultAt) return "field";
  return "result";
}

function occupiedBases(runners: BaserunnerStateSnapshot): number[] {
  return [
    runners.firstOccupied ? 1 : 0,
    runners.secondOccupied ? 2 : 0,
    runners.thirdOccupied ? 3 : 0,
  ].filter(Boolean);
}

export function createRunnerMotions(
  before: BaserunnerStateSnapshot,
  after: BaserunnerStateSnapshot,
  outcome: PitchOutcome,
  runsScored: number,
): ReadonlyArray<RunnerMotion> {
  const finalBases = occupiedBases(after);
  const motions: RunnerMotion[] = [];
  const batterDestination = outcome === "single" ? 1 : outcome === "double" ? 2 : outcome === "home_run" ? 4 : 1;
  const batterOut = outcome === "in_play_out";
  if (["single", "double", "home_run", "in_play_out"].includes(outcome)) {
    motions.push({ id: "batter", fromBase: 0, toBase: batterDestination, isOut: batterOut });
    const index = finalBases.indexOf(batterDestination);
    if (index >= 0) finalBases.splice(index, 1);
  }

  occupiedBases(before).sort((left, right) => right - left).forEach((fromBase, index) => {
    const destinationIndex = finalBases.findIndex((base) => base >= fromBase);
    if (destinationIndex >= 0) {
      const [toBase] = finalBases.splice(destinationIndex, 1);
      motions.push({ id: `runner-${fromBase}`, fromBase, toBase, isOut: false });
      return;
    }
    const scores = runsScored > index || outcome === "home_run";
    motions.push({
      id: `runner-${fromBase}`,
      fromBase,
      toBase: Math.min(4, fromBase + 1),
      isOut: !scores,
    });
  });
  return motions;
}

export function runnerPoint(motion: RunnerMotion, progress: number): Point {
  const start = clamp(motion.fromBase, 0, 4);
  const end = clamp(Math.max(start, motion.toBase), start, 4);
  if (start === end) return BASE_ROUTE[start];
  const segmentProgress = clamp(progress, 0, 1) * (end - start);
  const segment = Math.min(end - 1, start + Math.floor(segmentProgress));
  const localProgress = segmentProgress - Math.floor(segmentProgress);
  return {
    x: lerp(BASE_ROUTE[segment].x, BASE_ROUTE[segment + 1].x, localProgress),
    y: lerp(BASE_ROUTE[segment].y, BASE_ROUTE[segment + 1].y, localProgress),
  };
}

function outcomeTone(outcome: PitchOutcome) {
  switch (outcome) {
    case "called_strike":
    case "swinging_strike":
    case "in_play_out": return "positive";
    case "ball":
    case "foul": return "neutral";
    case "single":
    case "double":
    case "home_run": return "negative";
  }
}

function executionLabel(score: number) {
  if (score >= 780) return "정확한 실행";
  if (score >= 600) return "안정적 실행";
  if (score >= 420) return "흔들린 실행";
  return "큰 실투";
}

function directionLabel(degrees: number) {
  if (degrees < -7) return `좌측 ${Math.abs(degrees).toFixed(1)}°`;
  if (degrees > 7) return `우측 ${degrees.toFixed(1)}°`;
  return `중앙 ${Math.abs(degrees).toFixed(1)}°`;
}

function fielderAction(fielding: FieldingResolutionSnapshot) {
  if (!fielding.fielderPosition) return "수비 위치";
  const label = FIELDER_LABELS[fielding.fielderPosition];
  return fielding.finalOutcome === "in_play_out" ? `${label} 포구` : `${label} 방향`;
}

function pointsPath(points: ReadonlyArray<Point>): string {
  if (points.length === 0) return "";
  return points.map((point, index) => `${index === 0 ? "M" : "L"} ${point.x.toFixed(1)} ${point.y.toFixed(1)}`).join(" ");
}

function Metric({ label, value, accent }: { label: string; value: string; accent?: boolean }) {
  return <div className={accent ? "is-accent" : undefined}><span>{label}</span><strong>{value}</strong></div>;
}

function Base({ x, y, occupied, label }: { x: number; y: number; occupied: boolean; label: string }) {
  return <g className={`gamecast-base ${occupied ? "is-occupied" : ""}`} transform={`translate(${x} ${y})`}>
    <rect x="-8" y="-8" width="16" height="16" transform="rotate(45)" />
    <text y="3" textAnchor="middle">{label}</text>
  </g>;
}

function PlayerFigure({
  x,
  y,
  short,
  active,
}: {
  x: number;
  y: number;
  short: string;
  active: boolean;
}) {
  return <g className={`gamecast-fielder ${active ? "is-responsible" : ""}`} transform={`translate(${x} ${y})`}>
    <ellipse className="gamecast-player-shadow" cy="10" rx="9" ry="3.2" />
    <path className="gamecast-player-legs" d="M -3 4 L -5 11 M 3 4 L 5 11" />
    <path className="gamecast-player-body" d="M -6 -8 Q 0 -12 6 -8 L 5 4 Q 0 7 -5 4 Z" />
    <circle className="gamecast-player-head" cy="-14" r="4" />
    <path className="gamecast-player-cap" d="M -4 -16 Q 0 -20 4 -16 L 8 -15" />
    <g className="gamecast-player-label" transform="translate(0 -25)">
      <rect x="-9" y="-7" width="18" height="13" rx="6.5" />
      <text y="2" textAnchor="middle">{short}</text>
    </g>
  </g>;
}

function PitchView({
  execution,
  tone,
  progress,
  revealResult,
  compact = false,
}: {
  execution: PitchExecution;
  tone: string;
  progress: number;
  revealResult: boolean;
  compact?: boolean;
}) {
  const plot = createPitchPlot(execution);
  const replayPoints = pitchReplayPoints(execution);
  const finalTime = replayPoints[replayPoints.length - 1].time;
  const currentTime = finalTime * clamp(progress, 0, 1);
  const currentPoint = interpolateReplayPoint(replayPoints, currentTime);
  const trail = replayPoints.filter((sample) => sample.time <= currentTime).map((sample) => sample.point);
  if (trail.length === 0 || trail[trail.length - 1] !== currentPoint) trail.push(currentPoint);
  const glowID = `pitch-glow-${compact ? "compact" : "main"}`;
  const skyID = `pitch-sky-${compact ? "compact" : "main"}`;
  const turfID = `pitch-turf-${compact ? "compact" : "main"}`;
  const canvasWidth = compact ? 320 : 480;
  const sceneOffsetX = (canvasWidth - 320) / 2;
  return <div className={`gamecast-pitch-view ${compact ? "is-compact" : ""}`}>
    <div className="gamecast-camera-hud" aria-hidden="true">
      <span className="gamecast-live-indicator"><i /> 생중계</span>
      <strong>{compact ? "투구 추적" : "포수 시점"}</strong>
    </div>
    <svg viewBox={`0 0 ${canvasWidth} 310`} role="img" aria-label={`투구 3D 좌표 ${replayPoints.length}개 중 ${Math.max(1, trail.length)}개 재생`}>
      <defs>
        <linearGradient id={skyID} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" className="gamecast-pitch-sky-top" />
          <stop offset="1" className="gamecast-pitch-sky-bottom" />
        </linearGradient>
        <linearGradient id={turfID} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" className="gamecast-pitch-turf-far" />
          <stop offset="1" className="gamecast-pitch-turf-near" />
        </linearGradient>
        <filter id={glowID} x="-200%" y="-200%" width="400%" height="400%">
          <feGaussianBlur stdDeviation="4" result="blur" />
          <feMerge><feMergeNode in="blur" /><feMergeNode in="SourceGraphic" /></feMerge>
        </filter>
      </defs>
      <rect width={canvasWidth} height="310" fill={`url(#${skyID})`} />
      <path d={`M 0 83 Q ${canvasWidth / 2} 48 ${canvasWidth} 83 V 121 H 0 Z`} className="gamecast-pitch-stands" />
      <path d={`M 0 104 Q ${canvasWidth / 2} 74 ${canvasWidth} 104 L ${canvasWidth} 310 H 0 Z`} fill={`url(#${turfID})`} />
      <g transform={`translate(${sceneOffsetX} 0)`}>
      <path d="M 160 22 L 278 310 H 42 Z" className="gamecast-pitch-lane" />
      <ellipse cx="160" cy="58" rx="34" ry="9" className="gamecast-pitch-mound" />
      <path d="M 118 258 L 94 306 M 202 258 L 226 306" className="gamecast-batter-box" />
      <g className="gamecast-pitcher-silhouette" transform="translate(160 47)">
        <ellipse cy="19" rx="11" ry="3" />
        <path d="M -5 0 Q 0 -8 5 0 L 4 13 L 9 22 M -4 13 L -9 22 M -4 2 L -12 9 M 4 2 L 12 -2" />
        <circle cy="-8" r="4" />
      </g>
      <g className="gamecast-catcher-silhouette" transform="translate(160 278)">
        <ellipse cy="17" rx="18" ry="4" />
        <path d="M -8 -2 Q 0 -12 8 -2 L 13 13 M -13 13 L -6 3 M 6 3 L 13 13" />
        <circle cy="-13" r="6" />
      </g>
      <path d="M 105 145 H 215 V 250 H 105 Z M 141.7 145 V 250 M 178.3 145 V 250 M 105 180 H 215 M 105 215 H 215" className="gamecast-strike-grid" />
      <path d="M 146 287 H 174 L 166 296 H 154 Z" className="gamecast-home-plate" />
      <path d={pointsPath(trail)} className="gamecast-pitch-shadow" />
      <path d={pointsPath(trail)} className="gamecast-pitch-line" />
      <g className="gamecast-target" transform={`translate(${plot.target.x} ${plot.target.y})`}>
        <circle r="8" /><path d="M -13 0 H 13 M 0 -13 V 13" />
      </g>
      {progress > 0 ? <g className={`gamecast-live-ball gamecast-live-ball--${tone}`} transform={`translate(${currentPoint.x} ${currentPoint.y})`} filter={`url(#${glowID})`}>
        <circle r={compact ? 5 : 6} /><path d="M -2.5 -5 Q 0 -2 2.5 -5 M -2.5 5 Q 0 2 2.5 5" />
      </g> : null}
      {revealResult ? <g className={`gamecast-actual gamecast-actual--${tone}`} transform={`translate(${plot.actual.x} ${plot.actual.y})`}>
        <circle r="9" /><path d="M -14 0 H 14 M 0 -14 V 14" />
      </g> : null}
      <text x="12" y="20" className="gamecast-axis-label">릴리스</text>
      <text x="249" y="298" className="gamecast-axis-label">홈플레이트</text>
      </g>
    </svg>
    {!compact ? <div className="gamecast-view-caption"><span>포수 중계 시점</span><span>＋ 포수 미트</span><span>● 실제 공</span><strong>{revealResult ? "ABS 판독 완료" : `${Math.round(progress * 100)}% 추적`}</strong></div> : null}
  </div>;
}

function FieldView({
  battedBall,
  fielding,
  runnersBefore,
  runnersAfter,
  runsScored,
  tone,
  progress,
  revealResult,
}: {
  battedBall: BattedBall;
  fielding: FieldingResolutionSnapshot;
  runnersBefore: BaserunnerStateSnapshot;
  runnersAfter: BaserunnerStateSnapshot;
  runsScored: number;
  tone: string;
  progress: number;
  revealResult: boolean;
}) {
  const plot = createBattedBallPlot(battedBall, fielding);
  const coreSamples = decodeTrajectorySeries(fielding.ballFlightSeries);
  const fallbackTime = fielding.hangTimeMilliseconds ?? 1_200;
  const fallbackSamples: ReadonlyArray<TrajectoryPoint3D> = [
    { timeMilliseconds: 0, lateralTenthsCM: 0, forwardTenthsCM: 0, heightTenthsCM: 0 },
    {
      timeMilliseconds: fallbackTime,
      lateralTenthsCM: ((plot.landing.x - 320) / 2.5) * 1_000,
      forwardTenthsCM: ((FIELD_HOME.y - plot.landing.y) / 2.35) * 1_000,
      heightTenthsCM: 0,
    },
  ];
  const samples = coreSamples.length >= 2 ? coreSamples : fallbackSamples;
  const currentTime = samples[samples.length - 1].timeMilliseconds * clamp(progress, 0, 1);
  const currentSample = interpolateTrajectory(samples, currentTime) ?? samples[0];
  const currentGround = projectFieldSample(currentSample);
  const trailPoints = samples.filter((sample) => sample.timeMilliseconds <= currentTime).map(projectFieldSample);
  if (trailPoints.length === 0) trailPoints.push(projectFieldSample(samples[0]));
  trailPoints.push(currentGround);
  const heightMeters = currentSample.heightTenthsCM / 1_000;
  const ballLift = Math.min(46, heightMeters * 2.1);
  const responsible = fielding.fielderPosition
    ? FIELD_MARKERS.find((marker) => marker.position === fielding.fielderPosition)
    : undefined;
  const approachProgress = clamp((progress - 0.18) / 0.7, 0, 1);
  const approachRatio = fielding.finalOutcome === "in_play_out" ? 1 : 0.72;
  const fielderPoint = responsible ? {
    x: lerp(responsible.x, plot.landing.x, approachProgress * approachRatio),
    y: lerp(responsible.y, plot.landing.y, approachProgress * approachRatio),
  } : undefined;
  const cameraStyle = {
    "--gamecast-camera-x": `${clamp((320 - currentGround.x) * 0.015, -4, 4).toFixed(2)}px`,
    "--gamecast-camera-y": `${clamp((220 - currentGround.y) * 0.012, -3, 3).toFixed(2)}px`,
    "--gamecast-camera-scale": (1.012 + clamp(progress, 0, 1) * 0.008).toFixed(3),
  } as CSSProperties;
  const runnerMotions = createRunnerMotions(runnersBefore, runnersAfter, fielding.finalOutcome, runsScored);
  const displayedRunners = revealResult ? runnersAfter : runnersBefore;
  return <div className="gamecast-field-view">
    <div className="gamecast-camera-hud" aria-hidden="true">
      <span className="gamecast-live-indicator"><i /> 생중계</span>
      <strong>외야 카메라</strong>
      <small>{directionLabel(battedBall.directionTenthsDegrees / 10)}</small>
    </div>
    <div className="gamecast-flight-hud" aria-hidden="true">
      <span>타구 속도</span>
      <strong>{progress > 0 ? (battedBall.exitVelocityTenthsKPH / 10).toFixed(1) : "—"}</strong>
      <small>km/h</small>
    </div>
    <svg viewBox="0 0 640 420" style={cameraStyle} role="img" aria-label={`${directionLabel(battedBall.directionTenthsDegrees / 10)} 방향 3D 타구 좌표 ${samples.length}개 재생`}>
      <defs>
        <linearGradient id="stadium-sky" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" className="gamecast-stadium-sky-top" />
          <stop offset="1" className="gamecast-stadium-sky-bottom" />
        </linearGradient>
        <pattern id="stadium-crowd" width="10" height="8" patternUnits="userSpaceOnUse">
          <rect width="10" height="8" className="gamecast-crowd-base" />
          <circle cx="2" cy="3" r="1" className="gamecast-crowd-light" />
          <circle cx="7" cy="5" r="1" className="gamecast-crowd-mid" />
        </pattern>
        <linearGradient id="stadium-grass" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" className="gamecast-grass-far" />
          <stop offset="1" className="gamecast-grass-near" />
        </linearGradient>
        <radialGradient id="stadium-light" cx="50%" cy="92%" r="84%">
          <stop offset="0" className="gamecast-light-near" />
          <stop offset="1" className="gamecast-light-far" />
        </radialGradient>
        <filter id="live-ball-glow" x="-200%" y="-200%" width="400%" height="400%">
          <feGaussianBlur stdDeviation="5" result="blur" />
          <feMerge><feMergeNode in="blur" /><feMergeNode in="SourceGraphic" /></feMerge>
        </filter>
      </defs>
      <rect width="640" height="420" fill="url(#stadium-sky)" />
      <image href="/gamecast-stadium-night.webp" width="640" height="420" preserveAspectRatio="xMidYMid slice" className="gamecast-stadium-plate" />
      <path d="M 0 42 Q 320 -26 640 42 V 105 Q 320 39 0 105 Z" fill="url(#stadium-crowd)" className="gamecast-grandstand" />
      <path d="M 0 86 Q 320 19 640 86 V 108 Q 320 48 0 108 Z" className="gamecast-outfield-wall" />
      <g className="gamecast-light-rigs">
        <path d="M 58 91 L 44 8 M 582 91 L 596 8" />
        <rect x="24" y="5" width="42" height="12" rx="2" />
        <rect x="574" y="5" width="42" height="12" rx="2" />
      </g>
      <g className="gamecast-center-scoreboard" transform="translate(275 30)">
        <rect width="90" height="42" rx="3" />
        <text x="45" y="16" textAnchor="middle">환생 야구</text>
        <text x="45" y="32" textAnchor="middle">생중계</text>
      </g>
      <path d="M 320 365 L 65 73 Q 320 14 575 73 L 320 365 Z" fill="url(#stadium-grass)" className="gamecast-outfield" />
      <path d="M 88 103 Q 320 48 552 103" className="gamecast-warning-track" />
      <path d="M 118 139 Q 320 82 522 139 M 153 184 Q 320 132 487 184 M 191 231 Q 320 190 449 231" className="gamecast-mowing-lines" />
      <path d="M 320 365 L 497 254 320 210 143 254 Z" className="gamecast-infield-dirt" />
      <path d="M 320 360 L 486 257 320 218 154 257 Z" className="gamecast-diamond" />
      <path d="M 320 365 L 65 73 M 320 365 L 575 73" className="gamecast-foul-lines" />
      <path d="M 306 358 H 334 L 326 368 H 314 Z" className="gamecast-home-plate" />
      <Base x={486} y={257} occupied={displayedRunners.firstOccupied} label="1" />
      <Base x={320} y={218} occupied={displayedRunners.secondOccupied} label="2" />
      <Base x={154} y={257} occupied={displayedRunners.thirdOccupied} label="3" />
      {FIELD_MARKERS.map((marker) => {
        const isResponsible = marker.position === fielding.fielderPosition;
        const point = isResponsible && fielderPoint ? fielderPoint : marker;
        const isActive = isResponsible && (progress > 0.58 || revealResult);
        return <PlayerFigure key={marker.position} x={point.x} y={point.y} short={marker.short} active={isActive} />;
      })}
      {progress > 0 && progress < 0.22 ? <g className="gamecast-contact-burst" transform={`translate(${FIELD_HOME.x} ${FIELD_HOME.y})`}>
        <circle r="12" /><circle r="25" /><path d="M -34 0 H 34 M 0 -34 V 34 M -24 -24 L 24 24 M 24 -24 L -24 24" />
      </g> : null}
      {progress > 0 ? <>
        <path d={pointsPath(trailPoints)} className="gamecast-hit-shadow" />
        <path d={pointsPath(trailPoints)} className={`gamecast-hit-line gamecast-hit-line--${tone}`} />
        {trailPoints.slice(-5, -1).map((point, index) => <circle key={`${point.x}-${point.y}-${index}`} cx={point.x} cy={point.y} r={1.7 + index * 0.5} className="gamecast-ball-ghost" />)}
        <ellipse cx={currentGround.x} cy={currentGround.y + 3} rx={7 + heightMeters * 0.15} ry="4" className="gamecast-ball-shadow" />
        <line x1={currentGround.x} y1={currentGround.y} x2={currentGround.x} y2={currentGround.y - ballLift} className="gamecast-height-guide" />
        <g className={`gamecast-live-ball gamecast-live-ball--${tone}`} transform={`translate(${currentGround.x} ${currentGround.y - ballLift})`} filter="url(#live-ball-glow)">
          <circle r="6" />
        </g>
      </> : null}
      {runnerMotions.map((motion) => {
        const point = runnerPoint(motion, clamp((progress - 0.08) / 0.88, 0, 1));
        const fading = motion.isOut && progress > 0.84;
        return <g key={motion.id} className={`gamecast-runner ${fading ? "is-out" : ""}`} transform={`translate(${point.x} ${point.y})`}>
          <circle r="6" /><path d="M -3 0 H 3 M 0 -3 V 3" />
        </g>;
      })}
      {revealResult ? <g className={`gamecast-landing gamecast-landing--${tone}`} transform={`translate(${plot.landing.x} ${plot.landing.y})`}>
        <circle r="7" /><circle r="15" className="gamecast-landing-ring" />
      </g> : null}
      <text x="12" y="411" className="gamecast-axis-label">환생 야구 · 타구 추적</text>
    </svg>
    <div className="gamecast-view-caption"><span>중계 카메라</span><span>{plot.apexHeightMeters.toFixed(1)} m 최고점</span><span>{plot.hangTimeSeconds.toFixed(1)} s 체공</span><strong>{revealResult ? fielderAction(fielding) : `타구 추적 ${Math.round(progress * 100)}%`}</strong></div>
  </div>;
}

interface GameCastReplayProps {
  result: PitchKernelResult;
  pitchType?: PitchType;
  situationLabel: string;
  pitcherName: string;
  batterName: string;
  continueLabel: string;
  isRunning: boolean;
  reducedMotion: boolean;
  onContinue: () => void;
}

const PHASE_LABELS: Record<GameCastPhase, string> = {
  pitch: "투구 추적 중",
  contact: "컨택 판정 중",
  field: "타구·수비 추적 중",
  result: "플레이 확정",
};

export function GameCastReplay({
  result,
  pitchType,
  situationLabel,
  pitcherName,
  batterName,
  continueLabel,
  isRunning,
  reducedMotion,
  onContinue,
}: GameCastReplayProps) {
  const { snapshot } = result;
  const execution = snapshot.execution;
  const battedBall = snapshot.battedBall;
  const fielding = snapshot.fieldingResolution;
  const hasContact = Boolean(battedBall && fielding);
  const tone = outcomeTone(snapshot.outcome);
  const timeline = useMemo(() => createGameCastTimeline(execution, fielding), [execution, fielding]);
  const [elapsed, setElapsed] = useState(reducedMotion ? timeline.total : 0);
  const elapsedRef = useRef(elapsed);
  const [status, setStatus] = useState<"playing" | "paused" | "complete">(reducedMotion ? "complete" : "playing");
  const [playbackRate, setPlaybackRate] = useState(1);

  useEffect(() => {
    elapsedRef.current = elapsed;
  }, [elapsed]);

  useEffect(() => {
    if (status !== "playing" || reducedMotion) return;
    let frame = 0;
    let previous = performance.now();
    const tick = (now: number) => {
      const next = Math.min(timeline.total, elapsedRef.current + (now - previous) * playbackRate);
      previous = now;
      elapsedRef.current = next;
      setElapsed(next);
      if (next >= timeline.total) {
        setStatus("complete");
        return;
      }
      frame = window.requestAnimationFrame(tick);
    };
    frame = window.requestAnimationFrame(tick);
    return () => window.cancelAnimationFrame(frame);
  }, [playbackRate, reducedMotion, status, timeline.total]);

  const phase = gameCastPhase(elapsed, timeline, hasContact);
  const phaseLabel = !hasContact && phase === "contact" ? "ABS·스윙 판정 중" : PHASE_LABELS[phase];
  const revealResult = phase === "result" || status === "complete";
  const pitchProgress = clamp(elapsed / Math.max(1, timeline.pitchEnd), 0, 1);
  const fieldProgress = hasContact
    ? clamp((elapsed - timeline.contactAt) / Math.max(1, timeline.fieldEnd - timeline.contactAt), 0, 1)
    : 0;
  const pitchLabel = pitchType ? PITCH_LABELS[pitchType] : "실제 투구";
  const fieldPlot = battedBall && fielding ? createBattedBallPlot(battedBall, fielding) : undefined;
  const outcome = snapshot.result === "strikeout"
    ? "삼진"
    : snapshot.result === "walk"
      ? "볼넷"
      : snapshot.result === "hit"
        ? OUTCOME_LABELS[snapshot.outcome]
        : snapshot.result === "in_play_out"
          ? "범타"
          : OUTCOME_LABELS[snapshot.outcome];
  const cinematicResult = revealResult && (hasContact || snapshot.ended);
  const resetPlayback = useCallback(() => {
    elapsedRef.current = reducedMotion ? timeline.total : 0;
    setElapsed(elapsedRef.current);
    setStatus(reducedMotion ? "complete" : "playing");
  }, [reducedMotion, timeline.total]);
  const togglePlayback = () => {
    if (status === "complete") { resetPlayback(); return; }
    setStatus((current) => current === "playing" ? "paused" : "playing");
  };
  const skipPlayback = () => {
    elapsedRef.current = timeline.total;
    setElapsed(timeline.total);
    setStatus("complete");
  };
  const cycleSpeed = () => setPlaybackRate((rate) => rate === 0.5 ? 1 : rate === 1 ? 2 : 0.5);
  const motionStyle = { "--gamecast-progress": `${(elapsed / timeline.total) * 100}%` } as CSSProperties;
  const runnersBefore = snapshot.runnersBefore ?? EMPTY_RUNNERS;
  const causalitySummary = revealResult ? <div className="gamecast-causality" aria-label={`선택 ${SELECTION_QUALITY_LABELS[snapshot.selectionQuality]}, 실행 ${executionLabel(execution.executionQuality)}, 결과 ${outcome}`}>
    <span><small>선택</small><b>{SELECTION_QUALITY_LABELS[snapshot.selectionQuality]}</b></span>
    <i aria-hidden="true">›</i>
    <span><small>실행</small><b>{executionLabel(execution.executionQuality)}</b></span>
    <i aria-hidden="true">›</i>
    <span><small>결과</small><b>{outcome}</b></span>
  </div> : null;

  return <section className={`gamecast-replay gamecast-replay--${tone} gamecast-phase--${phase} ${hasContact ? "has-contact" : "is-pitch-only"}`} style={motionStyle} aria-label="환생 야구 플레이 재생">
    <div className="sr-only" role="status" aria-live="polite">
      {revealResult ? snapshot.accessibilitySummary : phaseLabel}
    </div>
    <header className="gamecast-header">
      <div className="gamecast-brand"><i /> <span>환생 야구</span><strong>경기 중계</strong></div>
      <div className="gamecast-matchup"><span><small>투</small>{pitcherName}</span><b>VS</b><span><small>타</small>{batterName}</span></div>
      <div className="gamecast-situation"><span>{situationLabel}</span><strong><i>B</i> {snapshot.balls} <i>S</i> {snapshot.strikes}</strong></div>
      <div className="gamecast-playback-controls" aria-label="재생 제어">
        <button type="button" onClick={togglePlayback} disabled={reducedMotion} aria-label={status === "playing" ? "일시정지" : status === "paused" ? "재생" : "다시 보기"}>
          {status === "playing" ? "Ⅱ" : "▶"}
        </button>
        <button type="button" onClick={resetPlayback} disabled={reducedMotion}>다시</button>
        <button type="button" onClick={cycleSpeed} disabled={reducedMotion} aria-label={`재생 속도 ${playbackRate}배`}>{playbackRate}×</button>
        <button type="button" onClick={skipPlayback} disabled={revealResult}>건너뛰기</button>
      </div>
    </header>

    <div className="gamecast-outcome-strip">
      <div><span>{revealResult ? snapshot.ended ? "최종 결과" : "투구 결과" : "생중계"}</span><strong>{revealResult ? outcome : phaseLabel}</strong></div>
      <div className="gamecast-play-sequence" aria-label="플레이 재생 순서">
        <span className={phase === "pitch" ? "is-current is-pitch" : "is-complete"}>01 투구</span>
        <i />
        <span className={!hasContact ? "is-muted" : phase === "contact" ? "is-current is-contact" : ["field", "result"].includes(phase) ? "is-complete" : ""}>02 컨택</span>
        <i />
        <span className={phase === "field" ? "is-current is-result" : phase === "result" ? "is-complete" : ""}>03 결과</span>
      </div>
      <small>{pitchLabel} · {(execution.velocityTenthsKPH / 10).toFixed(1)} km/h</small>
    </div>

    <div className={`gamecast-visuals ${hasContact ? "has-field" : "has-pitch"}`}>
      {battedBall && fielding ? <>
        <FieldView
          battedBall={battedBall}
          fielding={fielding}
          runnersBefore={runnersBefore}
          runnersAfter={snapshot.runnersAfter}
          runsScored={snapshot.runsScored}
          tone={tone}
          progress={fieldProgress}
          revealResult={revealResult}
        />
        <aside className="gamecast-telemetry">
          <div className="gamecast-telemetry-heading"><span>타구 추적</span><strong>{phase === "pitch" ? pitchLabel : directionLabel(battedBall.directionTenthsDegrees / 10)}</strong></div>
          <PitchView execution={execution} tone={tone} compact progress={pitchProgress} revealResult={revealResult} />
          <div className="gamecast-contact-card">
            <span>타구 속도</span>
            <div><strong>{phase === "pitch" ? "—" : (battedBall.exitVelocityTenthsKPH / 10).toFixed(1)}</strong><em>km/h</em></div>
            <small>{phase === "pitch" ? "타구 대기" : `발사각 ${(battedBall.launchAngleTenthsDegrees / 10).toFixed(1)}°`}</small>
          </div>
          <div className="gamecast-metrics gamecast-metrics--stacked">
            <Metric label="투구" value={`${pitchLabel} · ${(execution.velocityTenthsKPH / 10).toFixed(1)} km/h`} />
            <Metric label="방향" value={phase === "pitch" ? "추적 대기" : directionLabel(battedBall.directionTenthsDegrees / 10)} />
            <Metric label="비거리" value={revealResult ? `${fieldPlot?.distanceMeters.toFixed(1)} m` : "측정 중"} accent />
            <Metric label="수비" value={revealResult ? fielderAction(fielding) : "반응 중"} />
          </div>
          {causalitySummary}
          <div className="gamecast-rival-read"><span>타자 대응</span><strong>{revealResult ? result.rivalAdaptation.warning : "타자 반응 기록 중"}</strong></div>
        </aside>
      </> : <>
        <PitchView execution={execution} tone={tone} progress={pitchProgress} revealResult={revealResult} />
        <aside className="gamecast-telemetry gamecast-telemetry--result">
          <div className="gamecast-telemetry-heading"><span>투구 정보</span><strong>{pitchLabel}</strong></div>
          <div className="gamecast-speed"><strong>{(execution.velocityTenthsKPH / 10).toFixed(1)}</strong><span>km/h</span></div>
          <div className="gamecast-metrics gamecast-metrics--stacked">
            <Metric label="비행시간" value={`${execution.flightTimeMilliseconds ?? 0} ms`} />
            <Metric label="수평 무브" value={`${execution.horizontalBreakTenthsCM >= 0 ? "+" : ""}${(execution.horizontalBreakTenthsCM / 10).toFixed(1)} cm`} />
            <Metric label="수직 무브" value={`${execution.verticalBreakTenthsCM >= 0 ? "+" : ""}${(execution.verticalBreakTenthsCM / 10).toFixed(1)} cm`} />
            <Metric label="실행 품질" value={revealResult ? `${execution.executionQuality}` : "계산 중"} accent />
          </div>
          <div className={`gamecast-zone-call gamecast-zone-call--${revealResult ? tone : "pending"}`}><span>ABS 판정</span><strong>{revealResult ? Math.abs(execution.actualX) <= 500 && Math.abs(execution.actualY) <= 500 ? "존 안" : "존 밖" : "판독 중"}</strong></div>
          {causalitySummary}
          <div className="gamecast-rival-read"><span>타자 대응</span><strong>{revealResult ? result.rivalAdaptation.warning : "타자 반응 기록 중"}</strong></div>
        </aside>
      </>}
      {cinematicResult ? <div className={`gamecast-result-sting gamecast-result-sting--${tone}`} aria-hidden="true">
        <span>최종 결과</span>
        <strong>{outcome}</strong>
        <small>{fielding?.fielderName ? `${fielding.fielderName} · ${fielderAction(fielding)}` : snapshot.shortFeedback}</small>
      </div> : null}
    </div>

    <footer className="gamecast-footer">
      <div className="gamecast-result-copy">
        <span className={revealResult ? `decision-grade decision-grade--${snapshot.selectionQuality}` : "gamecast-live-badge"}>{revealResult ? snapshot.recommendationAccepted ? "포수 추천 수락" : "포수 사인 수정" : "생중계"}</span>
        <div><strong>{revealResult ? snapshot.shortFeedback : phaseLabel}</strong><p>{revealResult ? fielding?.shortExplanation ?? snapshot.detailFeedback : phase === "pitch" ? "포수 시점에서 릴리스와 무브먼트를 추적합니다." : "중계 카메라가 타구와 수비 반응을 따라갑니다."}</p></div>
      </div>
      <button className="primary-action gamecast-continue" type="button" disabled={isRunning || !revealResult} onClick={onContinue}>
        {isRunning ? "다음 장면 준비 중…" : revealResult ? continueLabel : "플레이 재생 중…"}
      </button>
    </footer>
  </section>;
}
