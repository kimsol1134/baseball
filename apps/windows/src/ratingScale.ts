// 저장 20-80 값을 사용자용 1-100 눈금으로 바꾸는 단일 출처.
export interface RatingStep {
  min: number;
  label: string;
}

export const RATING_STEPS: readonly RatingStep[] = [
  { min: 75, label: "세대 최고 수준" },
  { min: 65, label: "프로 최상급" },
  { min: 55, label: "프로 평균 이상" },
  { min: 50, label: "프로 평균" },
  { min: 47, label: "지역에서 손꼽는 재능" },
  { min: 43, label: "고교 상위권 도전" },
  { min: 38, label: "고교 주전 경쟁" },
  { min: 33, label: "성장 중인 기본기" },
];

export function abilityMeaning(value: number): string {
  for (const step of RATING_STEPS) if (value >= step.min) return step.label;
  return "기본기 다지는 단계";
}

/// 현재 값 위로 다가오는 다음 단계. 최고 단계면 null.
export function nextRatingStep(value: number): RatingStep | null {
  const upcoming = [...RATING_STEPS].reverse().find((step) => step.min > value);
  return upcoming ?? null;
}

export function ratingPositionPercent(value: number): number {
  return ((displayRating(value) - 1) / 99) * 100;
}

export function displayRating(internalRating: number): number {
  const clamped = Math.min(80, Math.max(20, Math.trunc(internalRating)));
  return Math.max(1, Math.min(100, Math.floor(((clamped - 20) * 100 + 30) / 60)));
}

export function displayDelta(before: number, after: number): number {
  return displayRating(after) - displayRating(before);
}

export function displayCeiling(internalCeiling: number): number {
  return displayRating(internalCeiling);
}
