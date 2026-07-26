import { nextRatingStep, ratingPositionPercent, RATING_STEPS } from "./ratingScale";

interface GrowthCelebrationProps {
  label: string;
  before: number;
  after: number;
  compact?: boolean;
}

export function growthMilestoneCopy(before: number, after: number) {
  if (before < 75 && after >= 75) return "세대 최고 수준에 올라섰습니다";
  if (before < 65 && after >= 65) return "프로에서도 경기를 지배할 강점입니다";
  if (before < 50 && after >= 50) return "프로 평균 수준에 도달했습니다";
  if (before < 47 && after >= 47) return "지역에서 손꼽는 재능이 됐습니다";
  return "한 단계 더 강해졌습니다";
}

export function crossedGrowthMilestone(before: number, after: number) {
  return [47, 50, 65, 75].some((threshold) => before < threshold && after >= threshold);
}

// 사다리 눈금: 라벨을 다 붙이면 시끄러우니 대표 단계만 이름을 보여준다.
const LADDER_TICKS = [
  { value: 38, label: "주전 경쟁" },
  { value: 50, label: "프로 평균" },
  { value: 65, label: "프로 최상급" },
];

export function GrowthCelebration({ label, before, after, compact = false }: GrowthCelebrationProps) {
  const gain = after - before;
  if (gain <= 0) return null;
  const isMilestone = crossedGrowthMilestone(before, after);
  const next = nextRatingStep(after);
  const remaining = next ? next.min - after : 0;

  return <div className={`growth-celebration${isMilestone ? " is-milestone" : " is-compact"}`}
    aria-label={`${label} 능력치 상승, ${before}에서 ${after}, ${gain} 증가${next ? `, 다음 목표 ${next.label}까지 ${remaining}` : ""}`}>
    {isMilestone ? <div className="growth-celebration__burst" aria-hidden="true">
      {Array.from({ length: 8 }, (_, index) => <i key={index} />)}
    </div> : null}
    <div className="growth-celebration__top">
      <div className="growth-celebration__copy">
        <span>{isMilestone ? "등급 돌파!" : "능력치 성장"}</span>
        <strong>{label}</strong>
      </div>
      <div className="growth-celebration__score" aria-hidden="true">
        <span>{before}</span><i>→</i><strong>{after}</strong><b>+{gain}</b>
      </div>
    </div>
    <div className="growth-ladder" aria-hidden="true">
      <div className="growth-ladder__track">
        {RATING_STEPS.map((step) => <span key={step.min} className="growth-ladder__seg" style={{ left: `${ratingPositionPercent(step.min)}%` }} />)}
        <span className="growth-ladder__fill" style={{ width: `${ratingPositionPercent(after)}%` }} />
        <span className="growth-ladder__jump" style={{ left: `${ratingPositionPercent(before)}%` }} />
        <span className="growth-ladder__marker" style={{ left: `${ratingPositionPercent(after)}%` }} />
      </div>
      <div className="growth-ladder__labels">
        <span>20</span>
        {LADDER_TICKS.map((tick) => <span key={tick.value} className={`growth-ladder__tick${after >= tick.value ? " is-reached" : ""}`}
          style={{ left: `${ratingPositionPercent(tick.value)}%` }}>{tick.value}{compact ? "" : ` ${tick.label}`}</span>)}
        <span className="growth-ladder__end">80</span>
      </div>
    </div>
    <p className="growth-celebration__meaning">{growthMilestoneCopy(before, after)}</p>
    {next
      ? <p className="growth-celebration__next">다음 목표 · <b>{next.label}({next.min})</b>까지 {remaining} 남았습니다</p>
      : <p className="growth-celebration__next">최고 단계에 올라 있습니다</p>}
  </div>;
}
