import type {
  BattedBall,
  FieldingSector,
  FielderPosition,
  PitchExecution,
  PitchKernelResult,
  PitchOutcome,
  PitchType,
} from "./simulationTypes";

type Point = { x: number; y: number };

export interface PitchPlot {
  target: Point;
  actual: Point;
  controlOne: Point;
  controlTwo: Point;
  path: string;
}

export interface BattedBallPlot {
  landing: Point;
  control: Point;
  path: string;
  estimatedDistanceMeters: number;
}

const PITCH_LABELS: Record<PitchType, string> = {
  four_seam: "포심",
  slider: "슬라이더",
  curveball: "커브",
  changeup: "체인지업",
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
  { position: "catcher", x: 120, y: 169, short: "포" },
  { position: "pitcher", x: 120, y: 139, short: "투" },
  { position: "first_base", x: 153, y: 124, short: "1" },
  { position: "second_base", x: 139, y: 105, short: "2" },
  { position: "third_base", x: 87, y: 124, short: "3" },
  { position: "shortstop", x: 101, y: 105, short: "유" },
  { position: "left_field", x: 69, y: 69, short: "좌" },
  { position: "center_field", x: 120, y: 48, short: "중" },
  { position: "right_field", x: 171, y: 69, short: "우" },
];

const clamp = (value: number, lower: number, upper: number) => Math.min(upper, Math.max(lower, value));

/** Maps the simulation's plate coordinates and measured break to a catcher-view plot. */
export function createPitchPlot(execution: PitchExecution): PitchPlot {
  const platePoint = (x: number, y: number): Point => ({
    x: clamp(120 + x * 0.096, 14, 226),
    y: clamp(79 - y * 0.084, 10, 148),
  });
  const target = platePoint(execution.targetX, execution.targetY);
  const actual = platePoint(execution.actualX, execution.actualY);
  const horizontalBreak = execution.horizontalBreakTenthsCM / 10;
  const verticalBreak = execution.verticalBreakTenthsCM / 10;
  const controlOne = {
    x: clamp(120 - horizontalBreak * 0.18, 72, 168),
    y: clamp(40 + verticalBreak * 0.12, 28, 53),
  };
  const controlTwo = {
    x: clamp(actual.x - horizontalBreak * 0.72, 18, 222),
    y: clamp(87 + verticalBreak * 0.38, 62, 110),
  };
  return {
    target,
    actual,
    controlOne,
    controlTwo,
    path: `M 120 9 C ${controlOne.x.toFixed(1)} ${controlOne.y.toFixed(1)}, ${controlTwo.x.toFixed(1)} ${controlTwo.y.toFixed(1)}, ${actual.x.toFixed(1)} ${actual.y.toFixed(1)}`,
  };
}

function estimatedDistance(battedBall: BattedBall, sector: FieldingSector) {
  const velocity = battedBall.exitVelocityTenthsKPH / 10;
  const launchAngle = battedBall.launchAngleTenthsDegrees / 10;
  const carry = velocity * 0.42 + Math.max(0, launchAngle) * 1.15 + battedBall.contactQuality * 0.025;
  switch (sector) {
    case "infield": return Math.round(clamp(carry * 0.38, 12, 42));
    case "outfield": return Math.round(clamp(carry, 48, 108));
    case "fence": return Math.round(clamp(carry, 105, 135));
  }
}

/** Uses direction, contact, launch angle and resolved sector to place the ball on a field plot. */
export function createBattedBallPlot(battedBall: BattedBall, sector: FieldingSector): BattedBallPlot {
  const direction = clamp(battedBall.directionTenthsDegrees / 10, -45, 45);
  const quality = battedBall.contactQuality / 1_000;
  const launchAngle = battedBall.launchAngleTenthsDegrees / 10;
  let landingY: number;
  switch (sector) {
    case "infield":
      landingY = clamp(143 - quality * 23 - Math.max(0, launchAngle) * 0.24, 108, 143);
      break;
    case "outfield":
      landingY = clamp(100 - quality * 34 - Math.max(0, launchAngle) * 0.45, 49, 96);
      break;
    case "fence":
      landingY = clamp(28 + Math.abs(direction) * 0.14, 28, 35);
      break;
  }
  const fieldHalfWidth = (165 - landingY) * 0.68;
  const landing = {
    x: 120 + (direction / 45) * fieldHalfWidth,
    y: landingY,
  };
  const handedCurve = direction === 0 ? 1 : Math.sign(direction);
  const control = {
    x: 120 + (landing.x - 120) * 0.38 - handedCurve * Math.min(12, Math.abs(launchAngle) * 0.28),
    y: 165 - (165 - landing.y) * 0.56,
  };
  return {
    landing,
    control,
    path: `M 120 165 Q ${control.x.toFixed(1)} ${control.y.toFixed(1)}, ${landing.x.toFixed(1)} ${landing.y.toFixed(1)}`,
    estimatedDistanceMeters: estimatedDistance(battedBall, sector),
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

function sectorLabel(sector: FieldingSector) {
  switch (sector) {
    case "infield": return "내야";
    case "outfield": return "외야";
    case "fence": return "펜스";
  }
}

function Metric({ label, value }: { label: string; value: string }) {
  return <div><span>{label}</span><strong>{value}</strong></div>;
}

export function TrajectoryReplay({ result, pitchType }: { result: PitchKernelResult; pitchType?: PitchType }) {
  const execution = result.snapshot.execution;
  const pitchPlot = createPitchPlot(execution);
  const battedBall = result.snapshot.battedBall;
  const sector = result.snapshot.fieldingResolution?.sector;
  const ballPlot = battedBall && sector ? createBattedBallPlot(battedBall, sector) : undefined;
  const responsibleFielder = result.snapshot.fieldingResolution?.fielderPosition;
  const breakHorizontal = execution.horizontalBreakTenthsCM / 10;
  const breakVertical = execution.verticalBreakTenthsCM / 10;
  const tone = outcomeTone(result.snapshot.outcome);

  return (
    <section className="trajectory-replay" aria-label="실제 투구와 타구 궤적 리플레이">
      <div className="trajectory-replay-heading">
        <div><span>PLAY TRAJECTORY</span><strong>실시간 궤적 리플레이</strong></div>
        <small>SIM DATA</small>
      </div>

      <div className={`trajectory-replay-grid ${ballPlot ? "has-batted-ball" : ""}`}>
        <article className="trajectory-card trajectory-card--pitch">
          <header><div><span>투구 궤적</span><strong>{pitchType ? PITCH_LABELS[pitchType] : "실제 투구"}</strong></div><small>포수 시점</small></header>
          <div className="trajectory-stage">
            <svg viewBox="0 0 240 158" role="img" aria-label={`목표 지점에서 실제 도착 지점까지의 투구 궤적. 수평 무브 ${breakHorizontal.toFixed(1)} 센티미터, 수직 무브 ${breakVertical.toFixed(1)} 센티미터`}>
              <defs>
                <pattern id="pitch-checker" width="20" height="20" patternUnits="userSpaceOnUse">
                  <rect width="20" height="20" className="trajectory-grid-base" />
                  <rect width="10" height="10" className="trajectory-grid-check" />
                  <rect x="10" y="10" width="10" height="10" className="trajectory-grid-check" />
                  <path d="M 20 0 L 0 0 0 20" className="trajectory-grid-rule" />
                </pattern>
                <filter id="ball-glow" x="-200%" y="-200%" width="400%" height="400%">
                  <feGaussianBlur stdDeviation="3" result="blur" />
                  <feMerge><feMergeNode in="blur" /><feMergeNode in="SourceGraphic" /></feMerge>
                </filter>
              </defs>
              <rect width="240" height="158" rx="9" fill="url(#pitch-checker)" />
              <path d="M 72 37 H 168 V 121 H 72 Z M 104 37 V 121 M 136 37 V 121 M 72 65 H 168 M 72 93 H 168" className="trajectory-strike-grid" />
              <path d="M 108 149 H 132 L 126 155 H 114 Z" className="trajectory-home-plate" />
              <path d={pitchPlot.path} pathLength="100" className="trajectory-pitch-shadow" />
              <path d={pitchPlot.path} pathLength="100" className="trajectory-pitch-line" />
              <g className="trajectory-target-marker" transform={`translate(${pitchPlot.target.x} ${pitchPlot.target.y})`}>
                <circle r="7" /><path d="M -10 0 H 10 M 0 -10 V 10" />
              </g>
              <g className={`trajectory-ball-marker trajectory-ball-marker--${tone}`} transform={`translate(${pitchPlot.actual.x} ${pitchPlot.actual.y})`} filter="url(#ball-glow)">
                <circle r="5" /><path d="M -2 -4 Q 0 -1 2 -4 M -2 4 Q 0 1 2 4" />
              </g>
              <text x="9" y="15" className="trajectory-axis-label">RELEASE</text>
              <text x="174" y="151" className="trajectory-axis-label">PLATE</text>
            </svg>
          </div>
          <div className="trajectory-metrics">
            <Metric label="구속" value={`${(execution.velocityTenthsKPH / 10).toFixed(1)} km/h`} />
            <Metric label="수평 무브" value={`${breakHorizontal > 0 ? "+" : ""}${breakHorizontal.toFixed(1)} cm`} />
            <Metric label="수직 무브" value={`${breakVertical > 0 ? "+" : ""}${breakVertical.toFixed(1)} cm`} />
          </div>
          <div className="trajectory-legend"><span><i className="is-target" />목표</span><span><i className={`is-actual is-${tone}`} />실제 도착</span><strong>실행 {execution.executionQuality}</strong></div>
        </article>

        {ballPlot && battedBall && sector ? (
          <article className="trajectory-card trajectory-card--field">
            <header><div><span>타구 궤적</span><strong>{sectorLabel(sector)} 방향</strong></div><small>구장 탑뷰</small></header>
            <div className="trajectory-stage trajectory-stage--field">
              <svg viewBox="0 0 240 180" role="img" aria-label={`${directionLabel(battedBall.directionTenthsDegrees / 10)} 방향의 타구. 예상 비거리 ${ballPlot.estimatedDistanceMeters} 미터`}>
                <defs>
                  <pattern id="field-checker" width="20" height="20" patternUnits="userSpaceOnUse">
                    <rect width="20" height="20" className="trajectory-field-base" />
                    <rect width="10" height="10" className="trajectory-field-check" />
                    <rect x="10" y="10" width="10" height="10" className="trajectory-field-check" />
                    <path d="M 20 0 L 0 0 0 20" className="trajectory-grid-rule" />
                  </pattern>
                  <filter id="landing-glow" x="-200%" y="-200%" width="400%" height="400%">
                    <feGaussianBlur stdDeviation="4" result="blur" />
                    <feMerge><feMergeNode in="blur" /><feMergeNode in="SourceGraphic" /></feMerge>
                  </filter>
                </defs>
                <rect width="240" height="180" rx="9" fill="url(#field-checker)" />
                <path d="M 120 165 L 24 26 M 120 165 L 216 26 M 24 26 Q 120 2 216 26" className="trajectory-foul-lines" />
                <path d="M 120 163 L 153 131 120 101 87 131 Z" className="trajectory-infield-dirt" />
                <path d="M 120 160 L 149 132 120 105 91 132 Z" className="trajectory-diamond" />
                <path d="M 108 164 H 132 L 126 170 H 114 Z" className="trajectory-home-plate" />
                {FIELD_MARKERS.map((marker) => (
                  <g key={marker.position} className={`trajectory-fielder ${responsibleFielder === marker.position ? "is-responsible" : ""}`} transform={`translate(${marker.x} ${marker.y})`}>
                    <circle r={responsibleFielder === marker.position ? 7 : 5} />
                    <text y="2.5" textAnchor="middle">{marker.short}</text>
                  </g>
                ))}
                <path d={ballPlot.path} pathLength="100" className="trajectory-hit-shadow" />
                <path d={ballPlot.path} pathLength="100" className={`trajectory-hit-line trajectory-hit-line--${tone}`} />
                <g className={`trajectory-landing trajectory-landing--${tone}`} transform={`translate(${ballPlot.landing.x} ${ballPlot.landing.y})`} filter="url(#landing-glow)">
                  <circle r="5" /><circle r="10" className="trajectory-landing-ring" />
                </g>
                <text x="8" y="16" className="trajectory-axis-label">BATTED BALL</text>
                <text x="174" y="173" className="trajectory-axis-label">HOME</text>
              </svg>
            </div>
            <div className="trajectory-metrics">
              <Metric label="타구 속도" value={`${(battedBall.exitVelocityTenthsKPH / 10).toFixed(1)} km/h`} />
              <Metric label="발사각" value={`${(battedBall.launchAngleTenthsDegrees / 10).toFixed(1)}°`} />
              <Metric label="예상 비거리" value={`${ballPlot.estimatedDistanceMeters} m`} />
            </div>
            <div className="trajectory-legend trajectory-legend--field"><span>{directionLabel(battedBall.directionTenthsDegrees / 10)}</span><span>타구 질 {battedBall.contactQuality}</span>{responsibleFielder ? <strong>{FIELDER_LABELS[responsibleFielder]} 처리</strong> : null}</div>
          </article>
        ) : null}
      </div>
    </section>
  );
}
