import { describe, expect, it } from "vitest";
import {
  clearPitcherLabAutosave,
  loadPitcherLabAutosave,
  savePitcherLabAutosave,
  type PitcherLabAutosavePayload,
} from "./pitcherLabAutosave";

class MemoryStorage {
  values = new Map<string, string>();
  getItem(key: string) { return this.values.get(key) ?? null; }
  setItem(key: string, value: string) { this.values.set(key, value); }
  removeItem(key: string) { this.values.delete(key); }
}

function fixture(revision: number): PitcherLabAutosavePayload {
  return {
    format: "BaseballPitcherLabAutosave",
    schemaVersion: 1,
    savedAt: "2026-07-22T00:00:00.000Z",
    selectedPresetID: "power_prospect",
    screenMode: "lab",
    labResult: { snapshot: { revision } } as PitcherLabAutosavePayload["labResult"],
    seed: "1",
    context: { revision } as PitcherLabAutosavePayload["context"],
    history: [],
    gameState: {} as PitcherLabAutosavePayload["gameState"],
    gameLog: { revision } as PitcherLabAutosavePayload["gameLog"],
    labInningStats: {
      pitches: 0,
      strikeouts: 0,
      walks: 0,
      runsAllowed: 0,
      expectedDamage: 0,
      actualDamage: 0,
      recommendationAccepted: 0,
    },
  };
}

describe("Pitcher Lab autosave", () => {
  it("loads the latest valid confirmed revision", () => {
    const storage = new MemoryStorage();
    savePitcherLabAutosave(storage, fixture(1));
    savePitcherLabAutosave(storage, fixture(2));

    expect(loadPitcherLabAutosave(storage)?.payload.labResult.snapshot.revision).toBe(2);
  });

  it("recovers the backup when the primary is corrupt", () => {
    const storage = new MemoryStorage();
    savePitcherLabAutosave(storage, fixture(1));
    savePitcherLabAutosave(storage, fixture(2));
    const primaryKey = [...storage.values.keys()].find((key) => !key.includes("backup"));
    storage.setItem(primaryKey!, "{corrupt");

    const loaded = loadPitcherLabAutosave(storage);
    expect(loaded?.source).toBe("backup");
    expect(loaded?.recoveredCorruption).toBe(true);
    expect(loaded?.payload.labResult.snapshot.revision).toBe(1);
  });

  it("does not rotate a corrupt primary over the last valid backup", () => {
    const storage = new MemoryStorage();
    savePitcherLabAutosave(storage, fixture(1));
    savePitcherLabAutosave(storage, fixture(2));
    const primaryKey = [...storage.values.keys()].find((key) => !key.includes("backup"));
    storage.setItem(primaryKey!, "broken");
    savePitcherLabAutosave(storage, fixture(3), 42);

    expect(loadPitcherLabAutosave(storage)?.payload.labResult.snapshot.revision).toBe(3);
    expect([...storage.values.keys()].some((key) => key.endsWith("corrupt.42"))).toBe(true);
  });

  it("clears both active slots for an explicit new experiment", () => {
    const storage = new MemoryStorage();
    savePitcherLabAutosave(storage, fixture(1));
    savePitcherLabAutosave(storage, fixture(2));
    clearPitcherLabAutosave(storage);
    expect(loadPitcherLabAutosave(storage)).toBeUndefined();
  });
});
