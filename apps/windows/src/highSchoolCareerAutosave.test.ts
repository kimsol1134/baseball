import { describe, expect, it } from "vitest";
import { loadHighSchoolCareer, saveHighSchoolCareer, type HighSchoolCareerAutosavePayload } from "./highSchoolCareerAutosave";

class MemoryStorage {
  values = new Map<string, string>();
  getItem(key: string) { return this.values.get(key) ?? null; }
  setItem(key: string, value: string) { this.values.set(key, value); }
  removeItem(key: string) { this.values.delete(key); }
}

function fixture(revision: number): HighSchoolCareerAutosavePayload {
  return {
    format: "BaseballHighSchoolCareerAutosave", schemaVersion: 2, savedAt: "2026-07-22T00:00:00Z",
    selectedPresetID: "power_prospect", screenMode: "lab", seed: "1",
    careerResult: { snapshot: { revision } } as HighSchoolCareerAutosavePayload["careerResult"],
    context: {} as HighSchoolCareerAutosavePayload["context"], history: [],
    gameState: {} as HighSchoolCareerAutosavePayload["gameState"], gameLog: {} as HighSchoolCareerAutosavePayload["gameLog"],
    inningStats: { pitches: 0, strikeouts: 0, walks: 0, runsAllowed: 0, expectedDamage: 0, actualDamage: 0, recommendationAccepted: 0 },
  };
}

describe("High school career autosave", () => {
  it("loads the newest valid revision", () => {
    const storage = new MemoryStorage();
    saveHighSchoolCareer(storage, fixture(1));
    saveHighSchoolCareer(storage, fixture(2));
    expect(loadHighSchoolCareer(storage)?.payload.careerResult.snapshot.revision).toBe(2);
  });

  it("recovers the last valid backup after primary corruption", () => {
    const storage = new MemoryStorage();
    saveHighSchoolCareer(storage, fixture(1));
    saveHighSchoolCareer(storage, fixture(2));
    const primary = [...storage.values.keys()].find((key) => !key.includes("backup"));
    storage.setItem(primary!, "broken");
    const recovered = loadHighSchoolCareer(storage);
    expect(recovered?.source).toBe("backup");
    expect(recovered?.payload.careerResult.snapshot.revision).toBe(1);
  });

  it("migrates a version 1 save with P4 defaults", () => {
    const storage = new MemoryStorage();
    const old = fixture(3) as unknown as Record<string, unknown>;
    old.schemaVersion = 1;
    const payload = JSON.stringify(old);
    let hash = 0x811c9dc5;
    for (let index = 0; index < payload.length; index += 1) { hash ^= payload.charCodeAt(index); hash = Math.imul(hash, 0x01000193); }
    storage.setItem("baseball.high-school-career.autosave.v1", JSON.stringify({ checksum: (hash >>> 0).toString(16).padStart(8, "0"), payload }));
    const migrated = loadHighSchoolCareer(storage)?.payload;
    expect(migrated?.schemaVersion).toBe(2);
    expect(migrated?.careerResult.snapshot.difficulty.careerHarshness).toBe("standard");
    expect(migrated?.careerResult.snapshot.memorySlots).toBe(3);
  });
});
