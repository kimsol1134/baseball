import { describe, expect, it } from "vitest";
import { batterStatsForArchetype, DEFAULT_PRO_BATTER, proBatterFromRival } from "./proRival";
import type { ProRivalBatter } from "./simulationTypes";

function rival(overrides: Partial<ProRivalBatter>): ProRivalBatter {
  return {
    id: "pro-rival-seoul",
    name: "강도훈",
    archetype: "중심 타선 해결사형",
    teamID: "seoul_comets",
    teamName: "서울 코메츠",
    record: "최근 3시즌 82홈런 · OPS .901",
    profile: "카운트가 몰려도 스윙이 짧아지지 않습니다.",
    ...overrides,
  };
}

describe("pro rival batter derivation", () => {
  it("falls back to the default cleanup batter when currentRival is missing", () => {
    expect(proBatterFromRival(undefined)).toEqual(DEFAULT_PRO_BATTER);
    expect(proBatterFromRival(undefined).name).toBe("오재민");
  });

  it("carries the rival's name and id into the pitching-screen batter", () => {
    const batter = proBatterFromRival(rival({ id: "pro-rival-busan", name: "마태오", archetype: "우측 담장 거포형" }));
    expect(batter.id).toBe("pro-rival-busan");
    expect(batter.name).toBe("마태오");
  });

  it("derives contact/discipline/power that match the archetype's identity", () => {
    const slugger = batterStatsForArchetype("우측 담장 거포형");
    const contact = batterStatsForArchetype("컨택 무결점형");
    const patient = batterStatsForArchetype("선구안 출루형");
    expect(slugger.power).toBeGreaterThan(slugger.contact);
    expect(slugger.power).toBeGreaterThan(58);
    expect(contact.contact).toBeGreaterThan(contact.power);
    expect(contact.contact).toBeGreaterThan(58);
    expect(patient.discipline).toBeGreaterThan(patient.power);
    expect(patient.discipline).toBeGreaterThan(58);
  });

  it("uses balanced default stats for an unrecognized archetype", () => {
    expect(batterStatsForArchetype("정체불명형")).toEqual({
      contact: DEFAULT_PRO_BATTER.contact,
      discipline: DEFAULT_PRO_BATTER.discipline,
      power: DEFAULT_PRO_BATTER.power,
    });
  });

  it("is deterministic for a given archetype", () => {
    expect(batterStatsForArchetype("당겨치는 홈런형")).toEqual(batterStatsForArchetype("당겨치는 홈런형"));
  });
});
