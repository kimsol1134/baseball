import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import { GrowthCelebration, growthMilestoneCopy } from "./GrowthCelebration";

describe("GrowthCelebration", () => {
  it("makes the exact gain the dominant accessible result", () => {
    const markup = renderToStaticMarkup(<GrowthCelebration label="공의 위력" before={64} after={65} />);

    expect(markup).toContain("능력치 상승!");
    expect(markup).toContain("공의 위력 능력치 상승, 64에서 65, 1 증가");
    expect(markup).toContain("+1");
  });

  it("calls out crossing a meaningful rating tier", () => {
    expect(growthMilestoneCopy(64, 65)).toContain("확실한 강점");
    expect(growthMilestoneCopy(74, 75)).toContain("전국 최고");
  });

  it("renders nothing when the rating did not rise", () => {
    expect(renderToStaticMarkup(<GrowthCelebration label="제구" before={52} after={52} />)).toBe("");
  });
});
