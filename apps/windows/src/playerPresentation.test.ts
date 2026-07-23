import { describe, expect, it } from "vitest";
import { batterScoutingReport, pitcherRoleLabel } from "./playerPresentation";

describe("player presentation", () => {
  it("uses the actual professional pitching role", () => {
    expect(pitcherRoleLabel("starter")).toBe("선발투수");
    expect(pitcherRoleLabel("long_relief")).toBe("긴 이닝 구원");
    expect(pitcherRoleLabel("setup")).toBe("필승조");
    expect(pitcherRoleLabel("closer")).toBe("마무리투수");
  });

  it("changes the scouting report with the batter profile", () => {
    const slugger = batterScoutingReport({ id: "a", name: "A", contact: 42, discipline: 48, power: 72 });
    const patient = batterScoutingReport({ id: "b", name: "B", contact: 50, discipline: 70, power: 45 });
    expect(slugger).toContain("장타");
    expect(patient).toContain("볼을 골라");
    expect(slugger).not.toBe(patient);
  });
});
