import { describe, expect, it } from "vitest";
import { nextFontScale, parseFontScale } from "./accessibilityPreferences";

describe("accessibility preferences", () => {
  it("accepts only supported font scales from storage", () => {
    expect(parseFontScale("1.15")).toBe(1.15);
    expect(parseFontScale("1.3")).toBe(1.3);
    expect(parseFontScale("4")).toBe(1);
    expect(parseFontScale("not-a-number")).toBe(1);
  });

  it("cycles the supported scale set and recovers invalid values", () => {
    expect(nextFontScale(1)).toBe(1.15);
    expect(nextFontScale(1.15)).toBe(1.3);
    expect(nextFontScale(1.3)).toBe(1);
    expect(nextFontScale(9)).toBe(1);
  });
});
