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

export function GrowthCelebration({ label, before, after, compact = false }: GrowthCelebrationProps) {
  const gain = after - before;
  if (gain <= 0) return null;

  return <div className={`growth-celebration${compact ? " is-compact" : ""}`}
    aria-label={`${label} 능력치 상승, ${before}에서 ${after}, ${gain} 증가`}>
    <div className="growth-celebration__burst" aria-hidden="true">
      {Array.from({ length: 8 }, (_, index) => <i key={index} />)}
    </div>
    <div className="growth-celebration__copy">
      <span>능력치 상승!</span>
      <strong>{label}</strong>
      <small>{growthMilestoneCopy(before, after)}</small>
    </div>
    <div className="growth-celebration__score" aria-hidden="true">
      <span>{before}</span><i>→</i><strong>{after}</strong><b>+{gain}</b>
    </div>
  </div>;
}
