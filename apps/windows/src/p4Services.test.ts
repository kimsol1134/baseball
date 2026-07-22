import { describe, expect, it } from "vitest";
import { readLocalAnalytics, recordLocalAnalytics, validateContentPackManifest } from "./p4Services";

class MemoryStorage {
  values = new Map<string, string>();
  getItem(key: string) { return this.values.get(key) ?? null; }
  setItem(key: string, value: string) { this.values.set(key, value); }
}

describe("P4 release services", () => {
  it("records analytics only after explicit opt-in", () => {
    const storage = new MemoryStorage();
    const event = { name: "career_started", occurredAt: "2026-07-22T00:00:00Z", properties: { life: 1 } };
    recordLocalAnalytics(storage, false, event);
    expect(readLocalAnalytics(storage)).toHaveLength(0);
    recordLocalAnalytics(storage, true, event);
    expect(readLocalAnalytics(storage)).toEqual([event]);
  });

  it("validates a safe declarative content pack", () => {
    expect(validateContentPackManifest({
      format: "BaseballContentPack", schemaVersion: 1, id: "community.seoul", title: "서울 이야기",
      version: "1.0.0", gameVersion: "0.4", author: "Community",
      content: [{ type: "relationship_event", id: "community.seoul.event.1", path: "events/one.json" }],
    }).id).toBe("community.seoul");
  });

  it("rejects duplicate IDs and directory traversal", () => {
    const base = { format: "BaseballContentPack", schemaVersion: 1, id: "community.safe", title: "팩", version: "1", gameVersion: "0.4", author: "A" } as const;
    expect(() => validateContentPackManifest({ ...base, content: [{ type: "game_scenario", id: "x", path: "../x.json" }] })).toThrow("안전한 상대 경로");
    expect(() => validateContentPackManifest({ ...base, content: [{ type: "game_scenario", id: "x", path: "x.json" }, { type: "relationship_event", id: "x", path: "y.json" }] })).toThrow("중복 콘텐츠 ID");
  });
});
