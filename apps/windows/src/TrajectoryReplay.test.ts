import { describe, expect, it } from "vitest";
import { createBattedBallPlot, createPitchPlot } from "./TrajectoryReplay";

describe("trajectory replay geometry", () => {
  it("keeps an extreme pitch inside the plotting board", () => {
    const plot = createPitchPlot({
      targetX: -400,
      targetY: -400,
      actualX: -1_600,
      actualY: 1_600,
      velocityTenthsKPH: 1_430,
      horizontalBreakTenthsCM: -180,
      verticalBreakTenthsCM: 60,
      executionQuality: 480,
    });

    expect(plot.target.x).toBeCloseTo(81.6);
    expect(plot.actual.x).toBe(14);
    expect(plot.actual.y).toBe(10);
    expect(plot.path).toContain("M 120 9 C");
  });

  it("plots left- and right-side contact on the matching side of center field", () => {
    const common = {
      exitVelocityTenthsKPH: 1_420,
      launchAngleTenthsDegrees: 240,
      contactQuality: 760,
    };
    const left = createBattedBallPlot({ ...common, directionTenthsDegrees: -320 }, "outfield");
    const right = createBattedBallPlot({ ...common, directionTenthsDegrees: 320 }, "outfield");

    expect(left.landing.x).toBeLessThan(120);
    expect(right.landing.x).toBeGreaterThan(120);
    expect(left.landing.y).toBeCloseTo(right.landing.y);
    expect(left.estimatedDistanceMeters).toBeGreaterThanOrEqual(48);
  });

  it("places fence contact deeper than an infield ball", () => {
    const ball = {
      exitVelocityTenthsKPH: 1_480,
      launchAngleTenthsDegrees: 280,
      directionTenthsDegrees: 0,
      contactQuality: 850,
    };

    const infield = createBattedBallPlot(ball, "infield");
    const fence = createBattedBallPlot(ball, "fence");
    expect(fence.landing.y).toBeLessThan(infield.landing.y);
    expect(fence.estimatedDistanceMeters).toBeGreaterThanOrEqual(105);
  });
});
