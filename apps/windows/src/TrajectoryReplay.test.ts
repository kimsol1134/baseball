import { describe, expect, it } from "vitest";
import {
  createBattedBallPlot,
  createGameCastTimeline,
  createPitchPlot,
  shouldCommitReplayFrame,
  createRunnerMotions,
  decodeTrajectorySeries,
  gameCastPhase,
  gameCastViewMode,
  interpolateTrajectory,
  runnerPoint,
} from "./TrajectoryReplay";

describe("trajectory replay geometry", () => {
  it("caps React replay state commits at 30 frames per second", () => {
    expect(shouldCommitReplayFrame(1016, 1000, false)).toBe(false);
    expect(shouldCommitReplayFrame(1034, 1000, false)).toBe(true);
    expect(shouldCommitReplayFrame(1001, 1000, true)).toBe(true);
  });
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
      flightTimeMilliseconds: 470,
      trajectoryControlX: -320,
      trajectoryControlY: 410,
    });

    expect(plot.target.x).toBe(128);
    expect(plot.actual.x).toBe(48);
    expect(plot.actual.y).toBe(87);
    expect(plot.path).toContain("M 160 116 Q");
  });

  it("plots left- and right-side contact on the matching side of center field", () => {
    const common = {
      exitVelocityTenthsKPH: 1_420,
      launchAngleTenthsDegrees: 240,
      contactQuality: 760,
    };
    const fielding = {
      neutralOutcome: "single" as const,
      finalOutcome: "single" as const,
      sector: "outfield" as const,
      difficulty: 400,
      defenseRating: 55,
      defenseAdjustment: 0,
      parkAdjustment: 0,
      impact: "neutral" as const,
      landingDistanceTenthsMeters: 820,
      hangTimeMilliseconds: 2_800,
      apexHeightTenthsMeters: 96,
      shortExplanation: "외야 방향 타구",
    };
    const left = createBattedBallPlot({ ...common, directionTenthsDegrees: -320 }, fielding);
    const right = createBattedBallPlot({ ...common, directionTenthsDegrees: 320 }, fielding);

    expect(left.landing.x).toBeLessThan(320);
    expect(right.landing.x).toBeGreaterThan(320);
    expect(left.landing.y).toBeCloseTo(right.landing.y);
    expect(left.distanceMeters).toBe(82);
  });

  it("places fence contact deeper than an infield ball", () => {
    const ball = {
      exitVelocityTenthsKPH: 1_480,
      launchAngleTenthsDegrees: 280,
      directionTenthsDegrees: 0,
      contactQuality: 850,
    };

    const commonFielding = {
      neutralOutcome: "home_run" as const,
      finalOutcome: "home_run" as const,
      difficulty: 200,
      defenseRating: 55,
      defenseAdjustment: 0,
      parkAdjustment: 0,
      impact: "neutral" as const,
      hangTimeMilliseconds: 3_900,
      apexHeightTenthsMeters: 180,
      shortExplanation: "중앙 타구",
    };
    const infield = createBattedBallPlot(ball, { ...commonFielding, sector: "infield", landingDistanceTenthsMeters: 350 });
    const fence = createBattedBallPlot(ball, { ...commonFielding, sector: "fence", landingDistanceTenthsMeters: 1180 });
    expect(fence.landing.y).toBeLessThan(infield.landing.y);
    expect(fence.distanceMeters).toBe(118);
  });

  it("decodes and interpolates the core 3D time series", () => {
    const samples = decodeTrajectorySeries([
      0, 0, 18_440, 1_850,
      250, -80, 9_220, 1_300,
      500, -160, 0, 760,
    ]);
    expect(samples).toHaveLength(3);
    expect(interpolateTrajectory(samples, 125)).toMatchObject({
      timeMilliseconds: 125,
      lateralTenthsCM: -40,
      forwardTenthsCM: 13_830,
      heightTenthsCM: 1_575,
    });
  });

  it("stages pitch, contact, fielding, and result without revealing early", () => {
    const timeline = createGameCastTimeline({
      targetX: 0,
      targetY: 0,
      actualX: 0,
      actualY: 0,
      velocityTenthsKPH: 1_450,
      horizontalBreakTenthsCM: 70,
      verticalBreakTenthsCM: 160,
      executionQuality: 800,
      flightTimeMilliseconds: 460,
    }, {
      neutralOutcome: "single",
      finalOutcome: "single",
      sector: "outfield",
      difficulty: 400,
      defenseRating: 55,
      defenseAdjustment: 0,
      parkAdjustment: 0,
      impact: "neutral",
      hangTimeMilliseconds: 2_800,
      shortExplanation: "외야 방향 타구",
    });
    expect(gameCastPhase(0, timeline, true)).toBe("pitch");
    expect(gameCastPhase(timeline.pitchEnd + 1, timeline, true)).toBe("contact");
    expect(gameCastPhase(timeline.contactAt + 1, timeline, true)).toBe("field");
    expect(gameCastPhase(timeline.resultAt, timeline, true)).toBe("result");
  });

  it("keeps every outcome on the same pitch camera until contact is confirmed", () => {
    expect(gameCastViewMode("pitch", false)).toBe("pitch");
    expect(gameCastViewMode("pitch", true)).toBe("pitch");
    expect(gameCastViewMode("contact", false)).toBe("pitch");
    expect(gameCastViewMode("contact", true)).toBe("pitch");
    expect(gameCastViewMode("field", true)).toBe("field");
    expect(gameCastViewMode("result", true)).toBe("field");
    expect(gameCastViewMode("result", false)).toBe("pitch");
  });

  it("creates visible batter and lead-runner movement before final base state", () => {
    const motions = createRunnerMotions(
      { firstOccupied: true, secondOccupied: false, thirdOccupied: false, leadRunnerSpeed: 60 },
      { firstOccupied: true, secondOccupied: true, thirdOccupied: false, leadRunnerSpeed: 60 },
      "single",
      0,
    );
    expect(motions.find((motion) => motion.id === "batter")).toMatchObject({ fromBase: 0, toBase: 1, isOut: false });
    expect(motions.find((motion) => motion.id === "runner-1")).toMatchObject({ fromBase: 1, toBase: 2, isOut: false });
    expect(runnerPoint({ id: "batter", fromBase: 0, toBase: 1, isOut: false }, 0.5).x).toBeGreaterThan(320);
  });
});
