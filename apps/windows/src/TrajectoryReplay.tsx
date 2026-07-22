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
  { position: "catcher", x: 320, y: 394, short: "포" },
  { position: "pitcher", x: 320, y: 315, short: "투" },
  { position: "first_base", x: 395, y: 272, short: "1" },
  { position: "second_base", x: 360, y: 228, short: "2" },
  { position: "third_base", x: 245, y: 272, short: "3" },
  { position: "shortstop", x: 280, y: 228, short: "유" },
  { position: "left_field", x: 190, y: 142, short: "좌" },
  { position: "center_field", x: 320, y: 92, short: "중" },
  { position: "right_field", x: 450, y: 142, short: "우" },
];

const BASE_ROUTE: ReadonlyArray<Point> = [
  { x: 320, y: 385 },
  { x: 395, y: 288 },
  { x: 320, y: 216 },
  { x: 245, y: 288 },
  { x: 320, y: 385 },
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
    x: clamp(320 + (sample.lateralTenthsCM / 1_000) * 2.5, 72, 568),
    y: clamp(385 - (sample.forwardTenthsCM / 1_000) * 2.4, 34, 385),
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
    x: clamp(320 + lateral * 2.5, 72, 568),
    y: clamp(385 - forward * 2.4, 34, 378),
  };
  const curveDirection = directionDegrees === 0 ? 1 : Math.sign(directionDegrees);
  const control = {
    x: 320 + (landing.x - 320) * 0.48 - curveDirection * Math.min(12, Math.abs(directionDegrees) * 0.22),
    y: 385 - (385 - landing.y) * 0.54,
  };
  return {
    landing,
    control,
    path: `M 320 385 Q ${control.x.toFixed(1)} ${control.y.toFixed(1)}, ${landing.x.toFixed(1)} ${landing.y.toFixed(1)}`,
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
  const patternID = `pitch-grid-${compact ? "compact" : "main"}`;
  const glowID = `pitch-glow-${compact ? "compact" : "main"}`;
  return <div className={`gamecast-pitch-view ${compact ? "is-compact" : ""}`}>
    <svg viewBox="0 0 320 310" role="img" aria-label={`투구 3D 좌표 ${replayPoints.length}개 중 ${Math.max(1, trail.length)}개 재생`}>
      <defs>
        <pattern id={patternID} width="24" height="24" patternUnits="userSpaceOnUse">
          <rect width="24" height="24" className="gamecast-grid-base" />
          <rect width="12" height="12" className="gamecast-grid-check" />
          <rect x="12" y="12" width="12" height="12" className="gamecast-grid-check" />
          <path d="M 24 0 L 0 0 0 24" className="gamecast-grid-rule" />
        </pattern>
        <filter id={glowID} x="-200%" y="-200%" width="400%" height="400%">
          <feGaussianBlur stdDeviation="4" result="blur" />
          <feMerge><feMergeNode in="blur" /><feMergeNode in="SourceGraphic" /></feMerge>
        </filter>
      </defs>
      <rect width="320" height="310" rx="12" fill={`url(#${patternID})`} />
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
      <text x="12" y="20" className="gamecast-axis-label">RELEASE</text>
      <text x="249" y="298" className="gamecast-axis-label">PLATE</text>
    </svg>
    {!compact ? <div className="gamecast-view-caption"><span>포수 시점</span><span>＋ 목표</span><span>● 실시간 공</span><strong>{revealResult ? "◎ 실제 도착" : `${Math.round(progress * 100)}%`}</strong></div> : null}
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
      forwardTenthsCM: ((385 - plot.landing.y) / 2.4) * 1_000,
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
  const ballLift = Math.min(24, heightMeters * 1.35);
  const responsible = fielding.fielderPosition
    ? FIELD_MARKERS.find((marker) => marker.position === fielding.fielderPosition)
    : undefined;
  const approachProgress = clamp((progress - 0.18) / 0.7, 0, 1);
  const approachRatio = fielding.finalOutcome === "in_play_out" ? 1 : 0.72;
  const fielderPoint = responsible ? {
    x: lerp(responsible.x, plot.landing.x, approachProgress * approachRatio),
    y: lerp(responsible.y, plot.landing.y, approachProgress * approachRatio),
  } : undefined;
  const runnerMotions = createRunnerMotions(runnersBefore, runnersAfter, fielding.finalOutcome, runsScored);
  const displayedRunners = revealResult ? runnersAfter : runnersBefore;
  return <div className="gamecast-field-view">
    <svg viewBox="0 0 640 420" role="img" aria-label={`${directionLabel(battedBall.directionTenthsDegrees / 10)} 방향 3D 타구 좌표 ${samples.length}개 재생`}>
      <defs>
        <pattern id="stadium-grid" width="28" height="28" patternUnits="userSpaceOnUse">
          <rect width="28" height="28" className="gamecast-field-base" />
          <rect width="14" height="14" className="gamecast-field-check" />
          <rect x="14" y="14" width="14" height="14" className="gamecast-field-check" />
          <path d="M 28 0 L 0 0 0 28" className="gamecast-grid-rule" />
        </pattern>
        <radialGradient id="stadium-light" cx="50%" cy="92%" r="84%">
          <stop offset="0" className="gamecast-light-near" />
          <stop offset="1" className="gamecast-light-far" />
        </radialGradient>
        <filter id="live-ball-glow" x="-200%" y="-200%" width="400%" height="400%">
          <feGaussianBlur stdDeviation="5" result="blur" />
          <feMerge><feMergeNode in="blur" /><feMergeNode in="SourceGraphic" /></feMerge>
        </filter>
      </defs>
      <rect width="640" height="420" rx="12" fill="url(#stadium-grid)" />
      <path d="M 320 385 L 65 26 M 320 385 L 575 26 M 65 26 Q 320 -18 575 26 L 320 385 Z" fill="url(#stadium-light)" className="gamecast-outfield" />
      <path d="M 320 382 L 405 286 320 205 235 286 Z" className="gamecast-infield-dirt" />
      <path d="M 320 377 L 395 288 320 216 245 288 Z" className="gamecast-diamond" />
      <path d="M 306 386 H 334 L 326 396 H 314 Z" className="gamecast-home-plate" />
      <Base x={395} y={288} occupied={displayedRunners.firstOccupied} label="1" />
      <Base x={320} y={216} occupied={displayedRunners.secondOccupied} label="2" />
      <Base x={245} y={288} occupied={displayedRunners.thirdOccupied} label="3" />
      {FIELD_MARKERS.map((marker) => {
        const isResponsible = marker.position === fielding.fielderPosition;
        const point = isResponsible && fielderPoint ? fielderPoint : marker;
        const isActive = isResponsible && (progress > 0.58 || revealResult);
        return <g key={marker.position} className={`gamecast-fielder ${isActive ? "is-responsible" : ""}`} transform={`translate(${point.x} ${point.y})`}>
          <circle r={isActive ? 13 : 10} />
          <text y="4" textAnchor="middle">{marker.short}</text>
        </g>;
      })}
      {progress > 0 ? <>
        <path d={pointsPath(trailPoints)} className="gamecast-hit-shadow" />
        <path d={pointsPath(trailPoints)} className={`gamecast-hit-line gamecast-hit-line--${tone}`} />
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
      <text x="14" y="23" className="gamecast-axis-label">환생 야구 · LIVE FIELD</text>
      <text x="528" y="405" className="gamecast-axis-label">HOME</text>
    </svg>
    <div className="gamecast-view-caption"><span>구장 탑뷰</span><span>{directionLabel(battedBall.directionTenthsDegrees / 10)}</span><strong>{revealResult ? fielderAction(fielding) : `타구 추적 ${Math.round(progress * 100)}%`}</strong></div>
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
        ? "출루 허용"
        : snapshot.result === "in_play_out"
          ? "범타"
          : OUTCOME_LABELS[snapshot.outcome];
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

  return <section className={`gamecast-replay gamecast-replay--${tone} ${hasContact ? "has-contact" : "is-pitch-only"}`} style={motionStyle} aria-label="환생 야구 플레이 재생">
    <div className="sr-only" role="status" aria-live="polite">
      {revealResult ? snapshot.accessibilitySummary : PHASE_LABELS[phase]}
    </div>
    <header className="gamecast-header">
      <div className="gamecast-brand"><span>환생 야구</span><strong>GAMECAST</strong></div>
      <div className="gamecast-matchup"><span>{pitcherName}</span><b>VS</b><span>{batterName}</span></div>
      <div className="gamecast-situation"><span>{situationLabel}</span><strong>B {snapshot.balls} · S {snapshot.strikes}</strong></div>
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
      <div><span>{revealResult ? snapshot.ended ? "타석 결과" : "투구 결과" : "LIVE PLAY"}</span><strong>{revealResult ? outcome : PHASE_LABELS[phase]}</strong></div>
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
          <div className="gamecast-telemetry-heading"><span>PITCH TRACK</span><strong>{pitchLabel}</strong></div>
          <PitchView execution={execution} tone={tone} compact progress={pitchProgress} revealResult={revealResult} />
          <div className="gamecast-metrics gamecast-metrics--stacked">
            <Metric label="구속" value={`${(execution.velocityTenthsKPH / 10).toFixed(1)} km/h`} />
            <Metric label="수평 / 수직 무브" value={`${execution.horizontalBreakTenthsCM >= 0 ? "+" : ""}${(execution.horizontalBreakTenthsCM / 10).toFixed(1)} / ${execution.verticalBreakTenthsCM >= 0 ? "+" : ""}${(execution.verticalBreakTenthsCM / 10).toFixed(1)} cm`} />
            <Metric label="타구 속도" value={phase === "pitch" ? "대기" : `${(battedBall.exitVelocityTenthsKPH / 10).toFixed(1)} km/h`} accent />
            <Metric label="발사각 / 방향" value={phase === "pitch" ? "—" : `${(battedBall.launchAngleTenthsDegrees / 10).toFixed(1)}° · ${directionLabel(battedBall.directionTenthsDegrees / 10)}`} />
            <Metric label="비거리 / 체공" value={revealResult ? `${fieldPlot?.distanceMeters.toFixed(1)} m · ${fieldPlot?.hangTimeSeconds.toFixed(1)} s` : "측정 중"} />
            <Metric label="최고 높이" value={revealResult ? `${fieldPlot?.apexHeightMeters.toFixed(1)} m` : "측정 중"} />
          </div>
        </aside>
      </> : <>
        <PitchView execution={execution} tone={tone} progress={pitchProgress} revealResult={revealResult} />
        <aside className="gamecast-telemetry gamecast-telemetry--result">
          <div className="gamecast-telemetry-heading"><span>PITCH DATA</span><strong>{pitchLabel}</strong></div>
          <div className="gamecast-speed"><strong>{(execution.velocityTenthsKPH / 10).toFixed(1)}</strong><span>km/h</span></div>
          <div className="gamecast-metrics gamecast-metrics--stacked">
            <Metric label="비행시간" value={`${execution.flightTimeMilliseconds ?? 0} ms`} />
            <Metric label="수평 무브" value={`${execution.horizontalBreakTenthsCM >= 0 ? "+" : ""}${(execution.horizontalBreakTenthsCM / 10).toFixed(1)} cm`} />
            <Metric label="수직 무브" value={`${execution.verticalBreakTenthsCM >= 0 ? "+" : ""}${(execution.verticalBreakTenthsCM / 10).toFixed(1)} cm`} />
            <Metric label="실행 품질" value={revealResult ? `${execution.executionQuality}` : "계산 중"} accent />
          </div>
          <div className={`gamecast-zone-call gamecast-zone-call--${revealResult ? tone : "pending"}`}><span>ABS 판정</span><strong>{revealResult ? Math.abs(execution.actualX) <= 500 && Math.abs(execution.actualY) <= 500 ? "존 안" : "존 밖" : "판독 중"}</strong></div>
        </aside>
      </>}
    </div>

    <footer className="gamecast-footer">
      <div className="gamecast-result-copy">
        <span className={revealResult ? `decision-grade decision-grade--${snapshot.selectionQuality}` : "gamecast-live-badge"}>{revealResult ? snapshot.recommendationAccepted ? "포수 추천 수락" : "포수 사인 수정" : "LIVE"}</span>
        <div><strong>{revealResult ? snapshot.shortFeedback : PHASE_LABELS[phase]}</strong><p>{revealResult ? fielding?.shortExplanation ?? snapshot.detailFeedback : "공과 선수의 실제 좌표를 시간순으로 재생하고 있습니다."}</p></div>
      </div>
      <button className="primary-action gamecast-continue" type="button" disabled={isRunning || !revealResult} onClick={onContinue}>
        {isRunning ? "다음 장면 준비 중…" : revealResult ? continueLabel : "플레이 재생 중…"}
      </button>
    </footer>
  </section>;
}
