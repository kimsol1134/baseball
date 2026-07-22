import type { TrainingFocus, TrainingIntensity } from "./simulationTypes";

function clamp(value: number, lower: number, upper: number) {
  return Math.min(upper, Math.max(lower, value));
}

export function expectedTrainingFatigue(
  currentFatigue: number,
  focus: TrainingFocus,
  intensity: TrainingIntensity,
) {
  const fatigueCost = intensity === "light" ? 3 : intensity === "standard" ? 8 : 15;
  const recovery = focus === "recovery" ? 18 : 0;
  const after = clamp(currentFatigue + fatigueCost - recovery, 0, 100);
  return { after, change: after - currentFatigue };
}

export function trainingGrowthOutlook(scoreBeforeRandomness: number) {
  const successfulRolls = clamp(scoreBeforeRandomness - 214, 0, 91);
  if (successfulRolls >= 78) return "매우 높음";
  if (successfulRolls >= 50) return "높음";
  if (successfulRolls >= 28) return "보통";
  if (successfulRolls > 0) return "낮음";
  return "없음";
}

export function parseAcknowledgedResult(value: string | null, completedDecisions: number) {
  const parsed = Number(value ?? 0);
  return Number.isInteger(parsed) && parsed >= 0 && parsed <= completedDecisions ? parsed : 0;
}
