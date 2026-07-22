import { describe, expect, it } from "vitest";
import { includesProCareer, releaseEditionFromEnvironment } from "./releaseEdition";

describe("release edition", () => {
  it("keeps local development fully playable", () => {
    const edition = releaseEditionFromEnvironment(true);
    expect(edition).toBe("development");
    expect(includesProCareer(edition)).toBe(true);
  });

  it("fails closed to the Steam demo for an unconfigured production build", () => {
    const edition = releaseEditionFromEnvironment(false);
    expect(edition).toBe("steam_demo");
    expect(includesProCareer(edition)).toBe(false);
  });

  it("includes the pro career only in the paid Steam build", () => {
    expect(includesProCareer(releaseEditionFromEnvironment(false, "steam_full"))).toBe(true);
    expect(includesProCareer(releaseEditionFromEnvironment(false, "web_teaser"))).toBe(false);
  });
});
