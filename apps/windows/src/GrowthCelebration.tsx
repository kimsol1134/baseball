interface GrowthCelebrationProps {
  label: string;
  before: number;
  after: number;
  compact?: boolean;
}

export function growthMilestoneCopy(before: number, after: number) {
  if (before < 75 && after >= 75) return "전국 최고 수준에 올라섰습니다";
  if (before < 65 && after >= 65) return "경기의 흐름을 바꿀 확실한 강점입니다";
  if (before < 55 && after >= 55) return "고교 평균을 확실히 넘어섰습니다";
  if (before < 45 && after >= 45) return "이제 약점으로 보이지 않습니다";
  return "한 단계 더 강해졌습니다";
}

export function crossedGrowthMilestone(before: number, after: number) {
  return [45, 55, 65, 75].some((threshold) => before < threshold && after >= threshold);
}

export function GrowthCelebration({ label, before, after, compact = false }: GrowthCelebrationProps) {
  const gain = after - before;
  if (gain <= 0) return null;
  const isMilestone = crossedGrowthMilestone(before, after);
  const useCompactLayout = compact || !isMilestone;

  return <div className={`growth-celebration${useCompactLayout ? " is-compact" : " is-milestone"}`}
    aria-label={`${label} 능력치 상승, ${before}에서 ${after}, ${gain} 증가`}>
    {isMilestone ? <div className="growth-celebration__burst" aria-hidden="true">
      {Array.from({ length: 8 }, (_, index) => <i key={index} />)}
    </div> : null}
    <div className="growth-celebration__copy">
      <span>{isMilestone ? "등급 돌파!" : "능력치 성장"}</span>
      <strong>{label}</strong>
      <small>{growthMilestoneCopy(before, after)}</small>
    </div>
    <div className="growth-celebration__score" aria-hidden="true">
      <span>{before}</span><i>→</i><strong>{after}</strong><b>+{gain}</b>
    </div>
  </div>;
}
