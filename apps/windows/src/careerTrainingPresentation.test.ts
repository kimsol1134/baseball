import { describe, expect, it } from "vitest";
import {
  expectedTrainingFatigue,
  parseAcknowledgedResult,
  trainingGrowthOutlook,
} from "./careerTrainingPresentation";

describe("career training presentation", () => {
  it("shows the actual fatigue change after clamping", () => {
    expect(expectedTrainingFatigue(98, "velocity", "intensive")).toEqual({ after: 100, change: 2 });
    expect(expectedTrainingFatigue(5, "recovery", "standard")).toEqual({ after: 0, change: -5 });
  });

  it("maps the engine's 91 possible rolls to honest outlook bands", () => {
    expect(trainingGrowthOutlook(214)).toBe("없음");
    expect(trainingGrowthOutlook(215)).toBe("낮음");
    expect(trainingGrowthOutlook(242)).toBe("보통");
    expect(trainingGrowthOutlook(264)).toBe("높음");
    expect(trainingGrowthOutlook(292)).toBe("매우 높음");
  });

  it("rejects corrupted or future result acknowledgements", () => {
    expect(parseAcknowledgedResult("3", 3)).toBe(3);
    expect(parseAcknowledgedResult("NaN", 3)).toBe(0);
    expect(parseAcknowledgedResult("4", 3)).toBe(0);
    expect(parseAcknowledgedResult("1.5", 3)).toBe(0);
  });
});
