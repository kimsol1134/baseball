export type LabResultKind = "training" | "relationship" | "awakening";

interface ReadableStorage {
  getItem(key: string): string | null;
}

interface WritableStorage extends ReadableStorage {
  setItem(key: string, value: string): void;
}

function key(runID: string, kind: LabResultKind) {
  return `pitcher-lab-result:${runID}:${kind}`;
}

export function readLabResultAcknowledgement(storage: ReadableStorage, runID: string, kind: LabResultKind): number {
  try {
    const parsed = Number(storage.getItem(key(runID, kind)) ?? "0");
    return Number.isInteger(parsed) && parsed >= 0 ? parsed : 0;
  } catch {
    return 0;
  }
}

export function writeLabResultAcknowledgement(storage: WritableStorage, runID: string, kind: LabResultKind, revision: number) {
  try {
    storage.setItem(key(runID, kind), String(Math.max(0, Math.trunc(revision))));
  } catch {
    // A blocked storage backend must not trap the player on the current screen.
  }
}
