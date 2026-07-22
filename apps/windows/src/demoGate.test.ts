import { describe, expect, it } from "vitest";
import { hasCompletedSteamDemo } from "./demoGate";

describe("hasCompletedSteamDemo", () => {
  it("ends the demo after the first completed important game", () => {
    expect(hasCompletedSteamDemo(true, 0)).toBe(false);
    expect(hasCompletedSteamDemo(true, 1)).toBe(true);
    expect(hasCompletedSteamDemo(true, 2)).toBe(true);
  });

  it("never truncates the full edition", () => {
    expect(hasCompletedSteamDemo(false, 0)).toBe(false);
    expect(hasCompletedSteamDemo(false, 1)).toBe(false);
    expect(hasCompletedSteamDemo(false, 5)).toBe(false);
  });
});
