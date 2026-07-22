import { invoke } from "@tauri-apps/api/core";

const FORMAT = "DiamondSoulSteamCloudStorage";
const SAVE_PREFIXES = [
  "diamond-soul.pitcher-lab.autosave.",
  "diamond-soul.high-school-career.autosave.",
  "diamond-soul.pro-career.autosave.",
] as const;

interface CloudStoragePayload {
  format: typeof FORMAT;
  schemaVersion: 1;
  values: Record<string, string>;
}

interface StorageLike {
  readonly length: number;
  clear(): void;
  getItem(key: string): string | null;
  key(index: number): string | null;
  removeItem(key: string): void;
  setItem(key: string, value: string): void;
}

type InvokeCommand = <T>(command: string, args?: Record<string, unknown>) => Promise<T>;

function isDesktopRuntime() {
  return typeof window !== "undefined" && "__TAURI_INTERNALS__" in window;
}

function isCloudSaveKey(key: string) {
  return SAVE_PREFIXES.some((prefix) => key.startsWith(prefix));
}

function managedKeys(storage: StorageLike): string[] {
  const keys: string[] = [];
  for (let index = 0; index < storage.length; index += 1) {
    const key = storage.key(index);
    if (key && isCloudSaveKey(key)) keys.push(key);
  }
  return keys.sort();
}

function snapshot(storage: StorageLike): CloudStoragePayload {
  const values: Record<string, string> = {};
  for (const key of managedKeys(storage)) {
    const value = storage.getItem(key);
    if (value !== null) values[key] = value;
  }
  return { format: FORMAT, schemaVersion: 1, values };
}

function decode(raw: string): CloudStoragePayload {
  const payload = JSON.parse(raw) as Partial<CloudStoragePayload>;
  if (payload.format !== FORMAT || payload.schemaVersion !== 1 || !payload.values || typeof payload.values !== "object") {
    throw new Error("Steam Cloud 저장 형식이 올바르지 않습니다.");
  }
  for (const [key, value] of Object.entries(payload.values)) {
    if (!isCloudSaveKey(key) || typeof value !== "string") {
      throw new Error("Steam Cloud 저장 항목이 올바르지 않습니다.");
    }
  }
  return payload as CloudStoragePayload;
}

function announce(state: "saved" | "error", message: string) {
  if (typeof window === "undefined") return;
  window.dispatchEvent(new CustomEvent("diamond-soul:cloud-save", {
    detail: { state, message },
  }));
}

export async function hydrateCloudStorage(
  storage: StorageLike,
  options: { desktop?: boolean; invokeCommand?: InvokeCommand } = {},
) {
  const desktop = options.desktop ?? isDesktopRuntime();
  if (!desktop) return;
  const invokeCommand = options.invokeCommand ?? invoke;
  const raw = await invokeCommand<string | null>("load_cloud_storage");
  if (!raw) return;
  const payload = decode(raw);
  for (const key of managedKeys(storage)) storage.removeItem(key);
  for (const [key, value] of Object.entries(payload.values)) storage.setItem(key, value);
}

export class CloudBackedStorage implements StorageLike {
  private persistQueued = false;
  private persistChain: Promise<void> = Promise.resolve();

  constructor(
    private readonly local: StorageLike,
    private readonly desktop = isDesktopRuntime(),
    private readonly invokeCommand: InvokeCommand = invoke,
  ) {}

  get length() { return this.local.length; }
  key(index: number) { return this.local.key(index); }
  getItem(key: string) { return this.local.getItem(key); }

  setItem(key: string, value: string) {
    this.local.setItem(key, value);
    if (isCloudSaveKey(key)) this.schedulePersist();
  }

  removeItem(key: string) {
    this.local.removeItem(key);
    if (isCloudSaveKey(key)) this.schedulePersist();
  }

  clear() {
    this.local.clear();
    this.schedulePersist();
  }

  async flush() {
    if (!this.desktop) return;
    const contents = JSON.stringify(snapshot(this.local));
    this.persistChain = this.persistChain
      .catch(() => undefined)
      .then(async () => {
        await this.invokeCommand("write_cloud_storage", { contents });
        announce("saved", "파일 저장 완료");
      })
      .catch((caught: unknown) => {
        const message = caught instanceof Error ? caught.message : String(caught);
        announce("error", `파일 저장 실패 · ${message}`);
        throw caught;
      });
    await this.persistChain;
  }

  private schedulePersist() {
    if (!this.desktop || this.persistQueued) return;
    this.persistQueued = true;
    queueMicrotask(() => {
      this.persistQueued = false;
      void this.flush().catch(() => undefined);
    });
  }
}

let appStorage: CloudBackedStorage | undefined;

export function getAppStorage(): CloudBackedStorage {
  if (!appStorage) appStorage = new CloudBackedStorage(window.localStorage);
  return appStorage;
}

export async function installCloudSaveCloseGuard(storage: CloudBackedStorage) {
  if (!isDesktopRuntime()) return;
  const { getCurrentWindow } = await import("@tauri-apps/api/window");
  const currentWindow = getCurrentWindow();
  await currentWindow.onCloseRequested(async (event) => {
    event.preventDefault();
    try {
      await storage.flush();
    } finally {
      await currentWindow.destroy();
    }
  });
}
