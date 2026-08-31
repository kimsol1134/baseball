import type { ProCareerSnapshot, ProWeekPlan, ProRole, ProWeekHealthForecast, ProInjuryEventSnapshot } from "./simulationTypes";

/** Keep the Windows forecast on the same integer contract as SimulationCore. */
export function masteryBonusPermille(level: number): number {
  if (level <= 0) return 0;
  const safe = Math.min(2_147_483_647, Math.trunc(level));
  return Math.min(120, Math.floor(120 * safe / (safe + 24)));
}

function bonusForContribution(contribution: number, level: number): number {
  if (contribution <= 0) return 0;
  const safe = Math.min(2_147_483_647, Math.trunc(contribution));
  return Math.floor((safe * masteryBonusPermille(level) + 500) / 1_000);
}

export function effectiveFatigue(rawFatigue: number, stamina: number, mastery = 0): number {
  const raw = Math.min(100, Math.max(0, Math.trunc(rawFatigue)));
  const baseContribution = Math.min(60, Math.max(0, Math.trunc(stamina) - 20));
  const effectiveStamina = Math.min(100, Math.max(20,
    20 + baseContribution + bonusForContribution(baseContribution, mastery)));
  const multiplierPermille = 1_250 - Math.floor((effectiveStamina - 20) * 500 / 60);
  return Math.min(100, Math.max(0, Math.floor(raw * multiplierPermille / 1_000)));
}

function expectedPitches(role: ProRole): number {
  switch (role) {
    case "starter": return 96;
    case "long_relief": return 84;
    case "setup":
    case "closer": return 72;
  }
}

function trainingLoad(plan: ProWeekPlan): number {
  switch (plan) {
    case "develop_stuff": return 10;
    case "develop_movement": return 8;
    case "develop_weapon": return 9;
    case "refine_command": return 6;
    case "build_stamina": return 7;
    case "earn_trust": return 5;
    case "recover": return -16;
  }
}

export function proWeekHealthForecast(state: ProCareerSnapshot, plan: ProWeekPlan): ProWeekHealthForecast {
  const pitches = expectedPitches(state.role);
  const outingLoad = plan === "recover" || state.injuryWeeks > 0 ? 0 : Math.floor((pitches + 14) / 15);
  const staminaRelief = Math.max(0, Math.floor((state.pitcher.stamina - 50) / 15));
  const expectedRawFatigue = Math.min(100, Math.max(0,
    state.fatigue + trainingLoad(plan) + outingLoad - staminaRelief));
  const expectedEffectiveFatigue = effectiveFatigue(
    expectedRawFatigue,
    state.pitcher.stamina,
    state.pitcher.mastery?.stamina ?? 0,
  );
  const band = expectedEffectiveFatigue <= 72
    ? "low"
    : expectedEffectiveFatigue <= 82 ? "caution" : "high";
  const reason = band === "low"
    ? "현재 피로와 선택한 계획을 반영해 과부하 기준 아래입니다."
    : band === "caution"
      ? "현재 피로에 훈련 부하와 예정 등판이 더해질 수 있습니다."
      : "훈련 부하와 예정 등판 뒤 유효 피로가 과부하 기준을 넘을 수 있습니다.";
  return {
    plan,
    role: state.role,
    expectedPitches: pitches,
    currentFatigue: state.fatigue,
    expectedRawFatigue,
    expectedEffectiveFatigue,
    band,
    reason,
  };
}

export function proInjuryEventID(event: ProInjuryEventSnapshot): string {
  return `pro-injury-${event.careerID ?? "unknown"}-s${event.season}-w${event.week}-r${event.revision ?? 0}-${event.plan}`;
}
