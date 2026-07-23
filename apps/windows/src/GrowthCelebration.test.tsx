import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import { crossedGrowthMilestone, GrowthCelebration, growthMilestoneCopy } from "./GrowthCelebration";

describe("GrowthCelebration", () => {
  it("makes the exact gain the dominant accessible result", () => {
    const markup = renderToStaticMarkup(<GrowthCelebration label="공의 위력" before={64} after={65} />);

    expect(markup).toContain("등급 돌파!");
    expect(markup).toContain("공의 위력 능력치 상승, 64에서 65, 1 증가");
    expect(markup).toContain("+1");
  });

  it("calls out crossing a meaningful rating tier", () => {
    expect(growthMilestoneCopy(39, 40)).toContain("고교 정상급");
    expect(growthMilestoneCopy(49, 50)).toContain("프로 평균 수준");
    expect(growthMilestoneCopy(64, 65)).toContain("프로에서도");
    expect(growthMilestoneCopy(74, 75)).toContain("세대 최고");
    expect(crossedGrowthMilestone(64, 65)).toBe(true);
  });

  it("keeps ordinary gains compact without milestone particles", () => {
    const markup = renderToStaticMarkup(<GrowthCelebration label="제구" before={51} after={52} />);

    expect(markup).toContain("is-compact");
    expect(markup).toContain("능력치 성장");
    expect(markup).not.toContain("growth-celebration__burst");
    expect(crossedGrowthMilestone(51, 52)).toBe(false);
  });

  it("renders nothing when the rating did not rise", () => {
    expect(renderToStaticMarkup(<GrowthCelebration label="제구" before={52} after={52} />)).toBe("");
  });
});
