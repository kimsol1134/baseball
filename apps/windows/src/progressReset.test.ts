import { describe, expect, it } from "vitest";
import { progressKeys, resetAllProgress } from "./progressReset";

function fakeStorage(initial: Record<string, string>) {
  const map = new Map(Object.entries(initial));
  return {
    get length() { return map.size; },
    key: (index: number) => [...map.keys()][index] ?? null,
    removeItem: (key: string) => { map.delete(key); },
    has: (key: string) => map.has(key),
  };
}

describe("progress reset", () => {
  it("removes progress keys but preserves accessibility and feedback settings", () => {
    const storage = fakeStorage({
      "baseball.pitcher-lab.autosave.v1": "{}",
      "baseball.high-school-career.autosave.v1": "{}",
      "baseball.cloud.sync": "{}",
      "baseball.a11y.contrast": "true",
      "baseball.feedback.sound": "false",
      "baseball.analytics.opt-in": "true",
      "unrelated.key": "1",
    });
    const removed = resetAllProgress(storage);
    expect(removed).toBe(3);
    expect(storage.has("baseball.a11y.contrast")).toBe(true);
    expect(storage.has("baseball.feedback.sound")).toBe(true);
    expect(storage.has("baseball.analytics.opt-in")).toBe(true);
    expect(storage.has("unrelated.key")).toBe(true);
    expect(storage.has("baseball.pitcher-lab.autosave.v1")).toBe(false);
    expect(storage.has("baseball.high-school-career.autosave.v1")).toBe(false);
  });

  it("lists progress keys without mutating", () => {
    const storage = fakeStorage({ "baseball.pitcher-lab.autosave.v1": "{}", "baseball.a11y.motion": "true" });
    expect(progressKeys(storage)).toEqual(["baseball.pitcher-lab.autosave.v1"]);
    expect(storage.has("baseball.pitcher-lab.autosave.v1")).toBe(true);
  });
});
