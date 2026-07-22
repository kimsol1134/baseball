import type {
  GameLogSnapshot,
  GameStateSnapshot,
  HighSchoolCareerResult,
  PitchKernelResult,
  PitchPreparation,
  PlateAppearanceContext,
  RivalMemorySnapshot,
} from "./simulationTypes";
import type { LabInningStats, PitchHistoryItem } from "./pitcherLabAutosave";

const PRIMARY = "baseball.high-school-career.autosave.v1";
const BACKUP = `${PRIMARY}.backup`;
const CORRUPT = `${PRIMARY}.corrupt`;

interface StorageLike {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
  removeItem(key: string): void;
}

export interface HighSchoolCareerAutosavePayload {
  format: "BaseballHighSchoolCareerAutosave";
  schemaVersion: 2;
  savedAt: string;
  selectedPresetID: string;
  screenMode: "lab" | "pitch";
  careerResult: HighSchoolCareerResult;
  seed: string;
  context: PlateAppearanceContext;
  preparation?: PitchPreparation;
  lastResult?: PitchKernelResult;
  history: ReadonlyArray<PitchHistoryItem>;
  rivalMemory?: RivalMemorySnapshot;
  gameState: GameStateSnapshot;
  gameLog: GameLogSnapshot;
  inningStats: LabInningStats;
}

interface Envelope { checksum: string; payload: string }

function checksum(value: string) {
  let hash = 0x811c9dc5;
  for (let index = 0; index < value.length; index += 1) {
    hash ^= value.charCodeAt(index);
    hash = Math.imul(hash, 0x01000193);
  }
  return (hash >>> 0).toString(16).padStart(8, "0");
}

function encode(payload: HighSchoolCareerAutosavePayload) {
  const serialized = JSON.stringify(payload);
  return JSON.stringify({ checksum: checksum(serialized), payload: serialized });
}

function decode(raw: string): HighSchoolCareerAutosavePayload {
  const envelope = JSON.parse(raw) as Partial<Envelope>;
  if (typeof envelope.payload !== "string" || envelope.checksum !== checksum(envelope.payload)) {
    throw new Error("고교 커리어 자동 저장 체크섬이 일치하지 않습니다.");
  }
  const payload = JSON.parse(envelope.payload) as Omit<Partial<HighSchoolCareerAutosavePayload>, "schemaVersion"> & { schemaVersion?: number };
  if (payload.format !== "BaseballHighSchoolCareerAutosave" || ![1, 2].includes(payload.schemaVersion ?? 0) || !payload.careerResult) {
    throw new Error("고교 커리어 자동 저장 형식이 유효하지 않습니다.");
  }
  if (payload.schemaVersion === 1) {
    const snapshot = payload.careerResult.snapshot;
    return {
      ...payload,
      schemaVersion: 2,
      careerResult: { ...payload.careerResult, snapshot: {
        ...snapshot,
        difficulty: snapshot.difficulty ?? { careerHarshness: "standard", informationClarity: "standard", simulationDifficulty: "standard", interventionAssist: "standard" },
        karmas: snapshot.karmas ?? [], legacyRewardPermille: snapshot.legacyRewardPermille ?? 1_000,
        memorySlots: snapshot.memorySlots ?? 3,
      } },
    } as HighSchoolCareerAutosavePayload;
  }
  return payload as HighSchoolCareerAutosavePayload;
}

export function saveHighSchoolCareer(storage: StorageLike, payload: HighSchoolCareerAutosavePayload, now = Date.now()) {
  const current = storage.getItem(PRIMARY);
  if (current) {
    try {
      decode(current);
      storage.setItem(BACKUP, current);
    } catch {
      storage.setItem(`${CORRUPT}.${now}`, current);
    }
  }
  storage.setItem(PRIMARY, encode(payload));
}

export function loadHighSchoolCareer(storage: StorageLike) {
  const primary = storage.getItem(PRIMARY);
  if (primary) {
    try { return { payload: decode(primary), source: "primary" as const }; } catch { /* use backup */ }
  }
  const backup = storage.getItem(BACKUP);
  if (!backup) return undefined;
  try { return { payload: decode(backup), source: "backup" as const }; } catch { return undefined; }
}

export function clearHighSchoolCareer(storage: StorageLike) {
  storage.removeItem(PRIMARY);
  storage.removeItem(BACKUP);
}
