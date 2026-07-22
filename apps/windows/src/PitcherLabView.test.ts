import { describe, expect, it } from "vitest";
import { labTrainingForecast } from "./PitcherLabView";

describe("Pitcher Lab training forecast", () => {
  it("uses the same visible fatigue and readiness costs as the simulation", () => {
    expect(labTrainingForecast(30, 70, "command", "standard")).toEqual({
      fatigueLow: 41,
      fatigueHigh: 41,
      readinessAfter: 64,
      growthChance: "보통",
    });
  });

  it("shows the hidden recovery trait as an honest range", () => {
    expect(labTrainingForecast(50, 55, "recovery", "intensive")).toEqual({
      fatigueLow: 44,
      fatigueHigh: 52,
      readinessAfter: 59,
      growthChance: "상대적으로 높음",
    });
  });
});
