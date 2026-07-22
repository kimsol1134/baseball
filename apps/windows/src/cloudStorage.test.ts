import { describe, expect, it, vi } from "vitest";
import { CloudBackedStorage, hydrateCloudStorage } from "./cloudStorage";

class MemoryStorage implements Storage {
  private readonly values = new Map<string, string>();
  get length() { return this.values.size; }
  clear() { this.values.clear(); }
  getItem(key: string) { return this.values.get(key) ?? null; }
  key(index: number) { return [...this.values.keys()][index] ?? null; }
  removeItem(key: string) { this.values.delete(key); }
  setItem(key: string, value: string) { this.values.set(key, value); }
}

describe("Steam Cloud backed storage", () => {
  it("hydrates only Diamond Soul keys from the newest file", async () => {
    const storage = new MemoryStorage();
    storage.setItem("diamond-soul.old", "remove-me");
    storage.setItem("unrelated", "keep-me");
    const invokeCommand = vi.fn().mockResolvedValue(JSON.stringify({
      format: "DiamondSoulSteamCloudStorage",
      schemaVersion: 1,
      values: { "diamond-soul.career": "cloud-value" },
    }));

    await hydrateCloudStorage(storage, { desktop: true, invokeCommand });

    expect(storage.getItem("diamond-soul.old")).toBeNull();
    expect(storage.getItem("diamond-soul.career")).toBe("cloud-value");
    expect(storage.getItem("unrelated")).toBe("keep-me");
  });

  it("batches synchronous mutations into one file write", async () => {
    const storage = new MemoryStorage();
    const invokeCommand = vi.fn().mockResolvedValue(undefined);
    const backed = new CloudBackedStorage(storage, true, invokeCommand);

    backed.setItem("diamond-soul.primary", "one");
    backed.setItem("diamond-soul.backup", "two");
    await Promise.resolve();
    await backed.flush();

    expect(invokeCommand).toHaveBeenCalled();
    const lastCall = invokeCommand.mock.calls.at(-1);
    const payload = JSON.parse((lastCall?.[1] as { contents: string }).contents);
    expect(payload.values).toEqual({
      "diamond-soul.backup": "two",
      "diamond-soul.primary": "one",
    });
  });

  it("does not write browser-only sessions to the desktop file API", async () => {
    const invokeCommand = vi.fn();
    const backed = new CloudBackedStorage(new MemoryStorage(), false, invokeCommand);
    backed.setItem("diamond-soul.primary", "one");
    await backed.flush();
    expect(invokeCommand).not.toHaveBeenCalled();
  });
});
