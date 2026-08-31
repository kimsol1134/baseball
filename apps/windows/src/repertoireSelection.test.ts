import { describe, expect, it } from "vitest";
import { recommendedRepertoire, repertoireWithLearningPitch } from "./HighSchoolCareerView";

describe("repertoire selection", () => {
  it("always recommends two ready breaking pitches and one different learning pitch", () => {
    for (const preset of ["power_prospect", "precision_commander", "breaking_ball_artist", "innings_eater"]) {
      const selection = recommendedRepertoire(preset);
      expect(selection.readyBreakingPitches).toHaveLength(2);
      expect(new Set(selection.readyBreakingPitches).size).toBe(2);
      expect(selection.readyBreakingPitches).not.toContain(selection.learningPitch);
    }
  });

  it("moves a newly selected learning pitch out of the ready set and protects primary", () => {
    const current = recommendedRepertoire("breaking_ball_artist");
    const changed = repertoireWithLearningPitch(current, "slider");
    expect(changed.readyBreakingPitches).toEqual(["curveball", "changeup"]);
    expect(changed.primaryPitch).toBe("four_seam");
    expect(changed.learningPitch).toBe("slider");
  });
});
