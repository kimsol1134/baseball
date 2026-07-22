import { describe, expect, it } from "vitest";
import { createAnonymousDiagnosticPackage, readLocalAnalytics, recordLocalAnalytics, validateContentPackManifest } from "./p4Services";

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

  it("removes player identity and deterministic secrets from diagnostics", () => {
    const diagnostics = createAnonymousDiagnosticPackage({
      appVersion: "1.0.0",
      analytics: [],
      save: {
        schemaVersion: 2,
        savedAt: "2026-07-22T00:00:00Z",
        screenMode: "lab",
        seed: "private-seed",
        careerResult: {
          eventHash: "private-event-hash",
          snapshot: {
            phase: "training",
            revision: 3,
            lifeNumber: 1,
            chapter: { number: 2 },
            school: { id: "busan_haenam", name: "부산해남고" },
            pitcher: { name: "비밀선수" },
            difficulty: { informationClarity: "clear" },
            karmas: [],
            performance: { pitches: 12 },
          },
        },
      } as never,
    });

    expect(diagnostics).not.toContain("비밀선수");
    expect(diagnostics).not.toContain("private-seed");
    expect(diagnostics).not.toContain("private-event-hash");
    expect(diagnostics).toContain('"schoolID": "busan_haenam"');
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
