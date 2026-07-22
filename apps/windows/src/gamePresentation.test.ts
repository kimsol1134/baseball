import { describe, expect, it } from "vitest";
import { gameStateForReplay, pitcherCondition } from "./gamePresentation";
import type { GameStateSnapshot, PitchKernelResult } from "./simulationTypes";

const current: GameStateSnapshot = {
  defense: { infield: 50, outfield: 50, arm: 50 },
  park: { id: "park", name: "가상 구장", hitFactor: 1000, homeRunFactor: 1000 },
  runners: { firstOccupied: false, secondOccupied: false, thirdOccupied: false, leadRunnerSpeed: 0 },
  runsAllowed: 2,
  inningState: { inning: 8, half: "top", outs: 0 },
};

describe("game presentation state", () => {
  it("keeps the just-finished half inning visible during a replay", () => {
    const result = {
      snapshot: {
        inningTransition: {
          before: { inning: 7, half: "bottom", outs: 2 },
          after: { inning: 8, half: "top", outs: 0 },
        },
        runnersBefore: { firstOccupied: true, secondOccupied: false, thirdOccupied: false, leadRunnerSpeed: 55 },
        runsScored: 1,
      },
    } as PitchKernelResult;

    expect(gameStateForReplay(current, result, true)).toMatchObject({
      inningState: { inning: 7, half: "bottom", outs: 2 },
      runners: { firstOccupied: true },
      runsAllowed: 1,
    });
  });

  it("uses fatigue bands instead of an invented fixed condition", () => {
    expect(pitcherCondition(20)).toBe("몸 상태 좋음");
    expect(pitcherCondition(68)).toBe("피로 주의");
    expect(pitcherCondition(85)).toBe("휴식 필요");
  });
});
