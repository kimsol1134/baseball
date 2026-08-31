import { describe, expect, it } from "vitest";
import { effectiveFatigue, proInjuryEventID, proWeekHealthForecast } from "./proHealthForecast";
import type { ProCareerSnapshot, ProInjuryEventSnapshot } from "./simulationTypes";

const state = (overrides: Partial<ProCareerSnapshot> = {}): ProCareerSnapshot => ({
  proCareerID: "pro-test",
  revision: 4,
  phase: "weekly_plan",
  identity: { name: "테스트", throwingHand: "right", bodyType: "balanced", region: "서울" },
  pitcher: { id: "p", name: "테스트", stuff: 50, command: 50, movement: 50, stamina: 50 },
  team: { id: "team", name: "가상 구단", need: "command", demand: 50, developmentPlan: "", positionCompetitor: "경쟁자", proCoach: "감독", competitorProfile: "", competitorRecord: "", coachProfile: "", coachRecord: "" },
  entitlement: { productID: "test", status: "active", source: "development", verifiedAt: "test" },
  age: 19, season: 1, week: 0, level: "minor", role: "starter", managerTrust: 42, catcherTrust: 45,
  fatigue: 0, injuryWeeks: 0, serviceYears: 0, militaryCompleted: false,
  currentStats: { season: 1, teamID: "team", games: 0, starts: 0, inningsOuts: 0, strikeouts: 0, walks: 0, runsAllowed: 0, wins: 0, saves: 0 },
  careerStats: [], awards: [], milestones: [], news: [], commitment: "",
  ...overrides,
});

describe("pro health forecast", () => {
  it("uses the shared low/caution/high thresholds and expected role workload", () => {
    const safe = proWeekHealthForecast(state(), "recover");
    expect(safe.expectedPitches).toBe(96);
    expect(safe.expectedEffectiveFatigue).toBe(0);
    expect(safe.band).toBe("low");

    const high = proWeekHealthForecast(state({ fatigue: 90, pitcher: { ...state().pitcher, stamina: 20 } }), "develop_stuff");
    expect(high.expectedRawFatigue).toBe(100);
    expect(high.expectedEffectiveFatigue).toBe(100);
    expect(high.band).toBe("high");
  });

  it("applies mastery to fatigue only at calculation time", () => {
    expect(effectiveFatigue(80, 50, 0)).toBe(80);
    expect(effectiveFatigue(80, 50, 100)).toBeLessThan(80);
    expect(effectiveFatigue(80, 50, 100)).toBe(effectiveFatigue(80, 50, 100));
  });

  it("derives the same durable injury acknowledgement ID as the result card", () => {
    const event: ProInjuryEventSnapshot = {
      cause: "overload", season: 2, week: 7, plan: "develop_stuff",
      rawFatigue: 88, effectiveFatigue: 86, pitches: 91, recoveryWeeks: 3,
      careerID: "pro-test", revision: 19,
    };
    expect(proInjuryEventID(event)).toBe("pro-injury-pro-test-s2-w7-r19-develop_stuff");
  });
});
