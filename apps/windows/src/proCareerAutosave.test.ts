import { describe, expect, it } from "vitest";
import { loadProCareer, saveProCareer, type ProCareerAutosavePayload } from "./proCareerAutosave";

class MemoryStorage { values = new Map<string, string>(); getItem(k: string) { return this.values.get(k) ?? null; } setItem(k: string, v: string) { this.values.set(k, v); } removeItem(k: string) { this.values.delete(k); } }
const fixture = (revision: number): ProCareerAutosavePayload => ({ format: "BaseballProCareerAutosave", schemaVersion: 1, savedAt: "2026-07-22", selectedPresetID: "power_prospect", highSchoolCareer: { snapshot: {} } as ProCareerAutosavePayload["highSchoolCareer"], proCareer: { snapshot: { revision } } as ProCareerAutosavePayload["proCareer"] });

describe("Pro career autosave", () => {
  it("round trips and rotates a valid backup", () => { const storage = new MemoryStorage(); saveProCareer(storage, fixture(1)); saveProCareer(storage, fixture(2)); expect(loadProCareer(storage)?.payload.proCareer.snapshot.revision).toBe(2); });
  it("recovers after primary corruption", () => { const storage = new MemoryStorage(); saveProCareer(storage, fixture(1)); saveProCareer(storage, fixture(2)); const primary = [...storage.values.keys()].find((key) => !key.includes("backup"))!; storage.setItem(primary, "broken"); expect(loadProCareer(storage)?.payload.proCareer.snapshot.revision).toBe(1); });
});
