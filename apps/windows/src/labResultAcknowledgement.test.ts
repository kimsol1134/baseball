import { describe, expect, it } from "vitest";
import { readLabResultAcknowledgement, writeLabResultAcknowledgement } from "./labResultAcknowledgement";

function memoryStorage() {
  const values = new Map<string, string>();
  return {
    getItem: (key: string) => values.get(key) ?? null,
    setItem: (key: string, value: string) => values.set(key, value),
  };
}

describe("Pitcher Lab result acknowledgement", () => {
  it("survives a view remount and stays isolated by result kind", () => {
    const storage = memoryStorage();
    writeLabResultAcknowledgement(storage, "run-1", "training", 2);
    expect(readLabResultAcknowledgement(storage, "run-1", "training")).toBe(2);
    expect(readLabResultAcknowledgement(storage, "run-1", "relationship")).toBe(0);
    expect(readLabResultAcknowledgement(storage, "run-2", "training")).toBe(0);
  });

  it("recovers corrupt or unavailable storage as unacknowledged", () => {
    expect(readLabResultAcknowledgement({ getItem: () => "NaN" }, "run", "awakening")).toBe(0);
    expect(readLabResultAcknowledgement({ getItem: () => { throw new Error("blocked"); } }, "run", "awakening")).toBe(0);
  });
});
