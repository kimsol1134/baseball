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
  RivalAdaptationBand,
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

const RIVAL_ADAPTATION_LABELS: Record<RivalAdaptationBand, string> = {
  no_data: "기록 없음",
  watching: "관찰 중",
  learning: "학습 중",
  locked_on: "노림수 읽힘",
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
    x: clamp(160 + x * 0.08, 48, 272),
    y: clamp(215 - y * 0.08, 48, 282),
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
    path: `M 160 116 Q ${control.x.toFixed(1)} ${control.y.toFixed(1)}, ${actual.x.toFixed(1)} ${actual.y.toFixed(1)}`,
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
    y: lerp(116, actual.y, progress)
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
    { time: 0, point: { x: 160, y: 116 } },
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
    ? clamp((fielding?.hangTimeMilliseconds ?? 1_200) * 0.4, 700, 1_500)
    : 0;
  const fieldEnd = contactAt + fieldDuration;
  const resultAt = hasContact ? fieldEnd + 90 : pitchEnd + 150;
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

/** Keeps the result unknowable until the contact adjudication has completed. */
export function gameCastViewMode(phase: GameCastPhase, hasContact: boolean): "pitch" | "field" {
  return hasContact && (phase === "field" || phase === "result") ? "field" : "pitch";
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
  if (score >= 780) return "원한 코스에 들어감";
  if (score >= 600) return "코스가 조금 벗어남";
  if (score >= 420) return "코스가 크게 벗어남";
  return "한가운데 실투";
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

function FielderMarker({
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
    <circle className="gamecast-fielder-marker-ring" r="11" />
    <circle className="gamecast-fielder-marker-dot" r="4" />
    <g className="gamecast-player-label" transform="translate(0 -19)">
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
  const skyID = `tracking-sky-${compact ? "compact" : "main"}`;
  const turfID = `tracking-turf-${compact ? "compact" : "main"}`;
  const dirtID = `tracking-dirt-${compact ? "compact" : "main"}`;
  const lightID = `tracking-light-${compact ? "compact" : "main"}`;
  const textureID = `tracking-texture-${compact ? "compact" : "main"}`;
  const canvasWidth = compact ? 320 : 480;
  const sceneOffsetX = (canvasWidth - 320) / 2;
  return <div className={`gamecast-pitch-view ${compact ? "is-compact" : ""}`}>
    <div className="gamecast-camera-hud" aria-hidden="true">
      <span className="gamecast-live-indicator"><i /> TRACKLAB</span>
      <strong>{compact ? "투구 위치" : "투구 분석 카메라"}</strong>
    </div>
    <svg viewBox={`0 0 ${canvasWidth} 310`} role="img" aria-label={`투구 3D 좌표 ${replayPoints.length}개 중 ${Math.max(1, trail.length)}개 재생`}>
      <defs>
        <linearGradient id={skyID} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" className="gamecast-tracking-sky-top" />
          <stop offset="1" className="gamecast-tracking-sky-bottom" />
        </linearGradient>
        <linearGradient id={turfID} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" className="gamecast-tracking-turf-far" />
          <stop offset="1" className="gamecast-tracking-turf-near" />
        </linearGradient>
        <linearGradient id={dirtID} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" className="gamecast-tracking-dirt-far" />
          <stop offset="1" className="gamecast-tracking-dirt-near" />
        </linearGradient>
        <radialGradient id={lightID} cx="50%" cy="0%" r="72%">
          <stop offset="0" className="gamecast-tracking-light-core" />
          <stop offset="1" className="gamecast-tracking-light-edge" />
        </radialGradient>
        <filter id={textureID} x="-15%" y="-15%" width="130%" height="130%">
          <feTurbulence type="fractalNoise" baseFrequency=".8" numOctaves="2" seed="17" result="noise" />
          <feColorMatrix in="noise" type="saturate" values="0" result="mono" />
          <feComponentTransfer in="mono"><feFuncA type="table" tableValues="0 .075" /></feComponentTransfer>
        </filter>
        <filter id={glowID} x="-200%" y="-200%" width="400%" height="400%">
          <feGaussianBlur stdDeviation="4" result="blur" />
          <feMerge><feMergeNode in="blur" /><feMergeNode in="SourceGraphic" /></feMerge>
        </filter>
      </defs>
      <g className="gamecast-pitch-environment">
        <rect width={canvasWidth} height="310" fill={`url(#${skyID})`} />
        <ellipse cx={canvasWidth / 2} cy="72" rx={canvasWidth * .48} ry="150" fill={`url(#${lightID})`} />
        <path d={`M 0 75 Q ${canvasWidth / 2} 39 ${canvasWidth} 75 V 119 Q ${canvasWidth / 2} 88 0 119 Z`} className="gamecast-tracking-grandstand" />
        <path d={`M 0 102 Q ${canvasWidth / 2} 74 ${canvasWidth} 102 V 124 Q ${canvasWidth / 2} 100 0 124 Z`} className="gamecast-tracking-crowd" />
        <path d={`M 0 116 Q ${canvasWidth / 2} 94 ${canvasWidth} 116 V 133 H 0 Z`} className="gamecast-tracking-wall" />
        <g className="gamecast-tracking-light-rigs">
          <path d={`M 38 104 L 28 13 M ${canvasWidth - 38} 104 L ${canvasWidth - 28} 13`} />
          <rect x="10" y="8" width="38" height="12" rx="2" />
          <rect x={canvasWidth - 48} y="8" width="38" height="12" rx="2" />
        </g>
        <g className="gamecast-tracking-scoreboard" transform={`translate(${canvasWidth / 2 - 45} 48)`}>
          <rect width="90" height="37" rx="3" />
          <text x="45" y="14" textAnchor="middle">환성 야구장</text>
          <text x="45" y="28" textAnchor="middle">NIGHT GAME</text>
        </g>
        <path d={`M 0 120 H ${canvasWidth} V 310 H 0 Z`} fill={`url(#${turfID})`} />
        <path d={`M ${canvasWidth / 2 - 14} 121 L ${canvasWidth / 2 - 88} 310 H ${canvasWidth / 2 + 88} L ${canvasWidth / 2 + 14} 121 Z`} fill={`url(#${dirtID})`} className="gamecast-tracking-lane" />
        <path d={`M 0 166 Q ${canvasWidth / 2} 139 ${canvasWidth} 166 M 0 216 Q ${canvasWidth / 2} 187 ${canvasWidth} 216 M 0 274 Q ${canvasWidth / 2} 242 ${canvasWidth} 274`} className="gamecast-tracking-mow" />
        <ellipse cx={canvasWidth / 2} cy="122" rx="27" ry="7" className="gamecast-tracking-mound" />
        <path d={`M ${canvasWidth / 2 - 62} 258 L ${canvasWidth / 2 - 91} 307 M ${canvasWidth / 2 + 62} 258 L ${canvasWidth / 2 + 91} 307`} className="gamecast-tracking-box" />
        <path d={`M ${canvasWidth / 2 - 14} 290 H ${canvasWidth / 2 + 14} L ${canvasWidth / 2 + 7} 300 H ${canvasWidth / 2 - 7} Z`} className="gamecast-home-plate" />
        <rect width={canvasWidth} height="310" filter={`url(#${textureID})`} className="gamecast-tracking-texture" />
      </g>
      <g transform={`translate(${sceneOffsetX} 0)`}>
      <path d="M 120 175 H 200 V 255 H 120 Z M 146.7 175 V 255 M 173.3 175 V 255 M 120 201.7 H 200 M 120 228.3 H 200" className="gamecast-strike-grid" />
      <g className="gamecast-release-point" transform="translate(160 116)"><circle r="4" /><circle r="9" /></g>
      <path d={pointsPath(trail)} className="gamecast-pitch-shadow" />
      <path d={pointsPath(trail)} className="gamecast-pitch-line" />
      {trail.slice(0, -1).filter((_, index) => index % 2 === 0).map((point, index) => <circle key={`${point.x}-${point.y}-${index}`} cx={point.x} cy={point.y} r={1.2 + index * .16} className="gamecast-pitch-depth-dot" />)}
      <g className="gamecast-target" transform={`translate(${plot.target.x} ${plot.target.y})`}>
        <circle r="8" /><path d="M -13 0 H 13 M 0 -13 V 13" />
      </g>
      {progress > 0 ? <g className={`gamecast-live-ball gamecast-live-ball--${revealResult ? tone : "tracking"}`} transform={`translate(${currentPoint.x} ${currentPoint.y})`} filter={`url(#${glowID})`}>
        <circle r={compact ? 5 : 6} /><path d="M -2.5 -5 Q 0 -2 2.5 -5 M -2.5 5 Q 0 2 2.5 5" />
      </g> : null}
      {revealResult ? <g className={`gamecast-actual gamecast-actual--${tone}`} transform={`translate(${plot.actual.x} ${plot.actual.y})`}>
        <circle r="9" /><path d="M -14 0 H 14 M 0 -14 V 14" />
      </g> : null}
      </g>
    </svg>
    {!compact ? <div className="gamecast-view-caption"><span>18.44 m 투구 좌표</span><span>＋ 목표</span><span>● 실제 위치</span><strong>{revealResult ? "위치 판독 완료" : `${Math.round(progress * 100)}% 분석`}</strong></div> : null}
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
        <filter id="live-ball-glow" x="-200%" y="-200%" width="400%" height="400%">
          <feGaussianBlur stdDeviation="5" result="blur" />
          <feMerge><feMergeNode in="blur" /><feMergeNode in="SourceGraphic" /></feMerge>
        </filter>
      </defs>
      <Base x={486} y={257} occupied={displayedRunners.firstOccupied} label="1" />
      <Base x={320} y={218} occupied={displayedRunners.secondOccupied} label="2" />
      <Base x={154} y={257} occupied={displayedRunners.thirdOccupied} label="3" />
      {FIELD_MARKERS.map((marker) => {
        const isResponsible = marker.position === fielding.fielderPosition;
        const point = isResponsible && fielderPoint ? fielderPoint : marker;
        const isActive = isResponsible && (progress > 0.58 || revealResult);
        return <FielderMarker key={marker.position} x={point.x} y={point.y} short={marker.short} active={isActive} />;
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

function GameCastImpact({ result, revealResult }: { result: PitchKernelResult; revealResult: boolean }) {
  const { snapshot, rivalAdaptation, postgameAnalysis } = result;
  const batterySummary = snapshot.recommendationAccepted ? "추천 수락" : "사인 수정";
  const adaptationSummary = `${RIVAL_ADAPTATION_LABELS[rivalAdaptation.band]} · ${rivalAdaptation.level}`;
  return <div className={`gamecast-impact-summary ${revealResult ? "is-revealed" : "is-pending"}`} aria-label={revealResult
    ? `이번 공의 기록. 피로 ${snapshot.fatigueAfterPitch}, 배터리 ${batterySummary}, 상대 학습 ${adaptationSummary}. ${postgameAnalysis.growthSignal}`
    : "이번 공이 선수에게 남기는 기록은 판정 후 공개됩니다."}>
    <div><span>이번 공이 남긴 기록</span><small>{revealResult ? "선수 시점" : "판정 대기"}</small></div>
    {revealResult ? <>
      <strong title={postgameAnalysis.growthSignal}>{postgameAnalysis.growthSignal}</strong>
      <div className="gamecast-impact-meta">
        <span><small>피로</small><b>{snapshot.fatigueAfterPitch}</b></span>
        <span><small>배터리</small><b>{batterySummary}</b></span>
        <span><small>상대 학습</small><b>{adaptationSummary}</b></span>
      </div>
    </> : <p>투구 내용과 관계·성장 신호를 계산하고 있습니다.</p>}
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
  contact: "타격 판정 중",
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
  const viewMode = gameCastViewMode(phase, hasContact);
  const showField = viewMode === "field" && Boolean(battedBall && fielding);
  const adjudicationLabel = hasContact && (phase === "field" || phase === "result") ? "02 타격" : "02 판정";
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
  const causalitySummary = revealResult ? <div className="gamecast-causality" aria-label={`공 선택 ${SELECTION_QUALITY_LABELS[snapshot.selectionQuality]}, 코스 ${executionLabel(execution.executionQuality)}, 결과 ${outcome}`}>
    <span><small>선택</small><b>{SELECTION_QUALITY_LABELS[snapshot.selectionQuality]}</b></span>
    <i aria-hidden="true">›</i>
    <span><small>실제 코스</small><b>{executionLabel(execution.executionQuality)}</b></span>
    <i aria-hidden="true">›</i>
    <span><small>결과</small><b>{outcome}</b></span>
  </div> : null;

  return <section className={`gamecast-replay gamecast-replay--${tone} gamecast-phase--${phase} gamecast-camera--${viewMode}`} style={motionStyle} aria-label="환생 야구 플레이 재생">
    <div className="sr-only" role="status" aria-live="polite">
      {revealResult ? snapshot.accessibilitySummary : phaseLabel}
    </div>
    <header className="gamecast-header">
      <div className="gamecast-brand"><i /> <span>환생 야구</span><strong>TRACKLAB</strong></div>
      <div className="gamecast-matchup"><span><small>투</small>{pitcherName}</span><b>VS</b><span><small>타</small>{batterName}</span></div>
      <div className="gamecast-situation"><span>{situationLabel}</span><strong><i>B</i> {revealResult ? snapshot.balls : "—"} <i>S</i> {revealResult ? snapshot.strikes : "—"}</strong></div>
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
      <div><span>{revealResult ? snapshot.ended ? "최종 기록" : "투구 기록" : "플레이 분석"}</span><strong>{revealResult ? outcome : phaseLabel}</strong></div>
      <div className="gamecast-play-sequence" aria-label="플레이 재생 순서">
        <span className={phase === "pitch" ? "is-current is-pitch" : "is-complete"}>01 투구</span>
        <i />
        <span className={phase === "contact" ? "is-current is-contact" : ["field", "result"].includes(phase) ? "is-complete" : ""}>{adjudicationLabel}</span>
        <i />
        <span className={phase === "field" ? "is-current is-result" : phase === "result" ? "is-complete" : ""}>03 결과</span>
      </div>
      <small>{pitchLabel} · {(execution.velocityTenthsKPH / 10).toFixed(1)} km/h</small>
    </div>

    <div className={`gamecast-visuals ${showField ? "has-field" : "has-pitch"}`}>
      {showField && battedBall && fielding ? <>
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
          <div className="gamecast-telemetry-heading"><span>타구 추적</span><strong>{directionLabel(battedBall.directionTenthsDegrees / 10)}</strong></div>
          <PitchView execution={execution} tone={tone} compact progress={pitchProgress} revealResult={revealResult} />
          <div className="gamecast-contact-card">
            <span>타구 속도</span>
            <div><strong>{(battedBall.exitVelocityTenthsKPH / 10).toFixed(1)}</strong><em>km/h</em></div>
            <small>발사각 {(battedBall.launchAngleTenthsDegrees / 10).toFixed(1)}°</small>
          </div>
          <div className="gamecast-metrics gamecast-metrics--stacked">
            <Metric label="투구" value={`${pitchLabel} · ${(execution.velocityTenthsKPH / 10).toFixed(1)} km/h`} />
            <Metric label="방향" value={directionLabel(battedBall.directionTenthsDegrees / 10)} />
            <Metric label="비거리" value={revealResult ? `${fieldPlot?.distanceMeters.toFixed(1)} m` : "측정 중"} accent />
            <Metric label="수비" value={revealResult ? fielderAction(fielding) : "반응 중"} />
          </div>
          {causalitySummary}
          <GameCastImpact result={result} revealResult={revealResult} />
        </aside>
      </> : <>
        <PitchView execution={execution} tone={tone} progress={pitchProgress} revealResult={revealResult} />
        <aside className="gamecast-telemetry gamecast-telemetry--result">
          <div className="gamecast-telemetry-heading"><span>투구 리포트</span><strong>{pitchLabel}</strong></div>
          {causalitySummary}
          <div className="gamecast-speed"><strong>{(execution.velocityTenthsKPH / 10).toFixed(1)}</strong><span>km/h</span></div>
          <div className="gamecast-metrics gamecast-metrics--stacked">
            <Metric label="비행시간" value={`${execution.flightTimeMilliseconds ?? 0} ms`} />
            <Metric label="수평 움직임" value={`${execution.horizontalBreakTenthsCM >= 0 ? "+" : ""}${(execution.horizontalBreakTenthsCM / 10).toFixed(1)} cm`} />
            <Metric label="수직 움직임" value={`${execution.verticalBreakTenthsCM >= 0 ? "+" : ""}${(execution.verticalBreakTenthsCM / 10).toFixed(1)} cm`} />
            <Metric label="코스 정확도" value={revealResult ? `${execution.executionQuality} / 1000` : "계산 중"} accent />
          </div>
          <div className={`gamecast-zone-call gamecast-zone-call--${revealResult ? tone : "pending"}`}><span>ABS 판정</span><strong>{revealResult ? Math.abs(execution.actualX) <= 500 && Math.abs(execution.actualY) <= 500 ? "존 안" : "존 밖" : "판독 중"}</strong></div>
          <GameCastImpact result={result} revealResult={revealResult} />
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
        <span className={revealResult ? `decision-grade decision-grade--${snapshot.selectionQuality}` : "gamecast-live-badge"}>{revealResult ? snapshot.recommendationAccepted ? "포수 추천 수락" : "포수 사인 수정" : "TRACKING"}</span>
        <div><strong>{revealResult ? snapshot.shortFeedback : phaseLabel}</strong><p>{revealResult ? fielding?.shortExplanation ?? snapshot.detailFeedback : phase === "field" ? "판정된 타구와 수비 반응을 같은 좌표계에서 추적합니다." : phase === "contact" ? "투구가 끝났습니다. 스윙·존·접촉 여부를 판정합니다." : "릴리스부터 홈플레이트까지 실제 공의 움직임을 분석합니다."}</p></div>
      </div>
      <button className="ds-button ds-button--primary primary-action gamecast-continue" type="button" disabled={isRunning || !revealResult} onClick={onContinue}>
        {isRunning ? "다음 장면 준비 중…" : revealResult ? continueLabel : "플레이 재생 중…"}
      </button>
    </footer>
  </section>;
}
