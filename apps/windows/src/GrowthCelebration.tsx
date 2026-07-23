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
  if (before < 40 && after >= 40) return "고교 정상급 능력이 됐습니다";
  return "한 단계 더 강해졌습니다";
}

export function crossedGrowthMilestone(before: number, after: number) {
  return [40, 50, 65, 75].some((threshold) => before < threshold && after >= threshold);
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
