import { describe, expect, it } from "vitest";
import { feedbackCueForResult } from "./gameFeedback";
import type { PitchKernelResult } from "./simulationTypes";

function result(outcome: PitchKernelResult["snapshot"]["outcome"], plateResult?: PitchKernelResult["snapshot"]["result"]) {
  return { snapshot: { outcome, result: plateResult } } as PitchKernelResult;
}

describe("game feedback", () => {
  it("prioritizes plate-ending achievements over the last pitch type", () => {
    expect(feedbackCueForResult(result("swinging_strike", "strikeout"))).toBe("strikeout");
    expect(feedbackCueForResult(result("single", "hit"))).toBe("big_hit");
  });

  it("maps ordinary pitch outcomes to restrained cues", () => {
    expect(feedbackCueForResult(result("called_strike"))).toBe("strike");
    expect(feedbackCueForResult(result("foul"))).toBe("contact");
    expect(feedbackCueForResult(result("ball"))).toBe("ball");
  });
});
