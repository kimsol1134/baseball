import type {
  GameLogSnapshot,
  GameStateSnapshot,
  PitchKernelResult,
  PitchOutcome,
  PitchPreparation,
  PitcherLabResult,
  PlateAppearanceContext,
  RivalMemorySnapshot,
} from "./simulationTypes";

const PRIMARY_KEY = "diamond-soul.pitcher-lab.autosave.v1";
const BACKUP_KEY = "diamond-soul.pitcher-lab.autosave.v1.backup";
const CORRUPT_KEY_PREFIX = "diamond-soul.pitcher-lab.autosave.v1.corrupt";

export interface PitchHistoryItem {
  eventHash: string;
  outcome: PitchOutcome;
  count: string;
}

export interface LabInningStats {
  pitches: number;
  strikeouts: number;
  walks: number;
  runsAllowed: number;
  expectedDamage: number;
  actualDamage: number;
  recommendationAccepted: number;
}

export interface PitcherLabAutosavePayload {
  format: "DiamondSoulPitcherLabAutosave";
  schemaVersion: 1;
  savedAt: string;
  selectedPresetID: string;
  screenMode: "lab" | "pitch";
  labResult: PitcherLabResult;
  previousLifeResult?: PitcherLabResult;
  seed: string;
  context: PlateAppearanceContext;
  preparation?: PitchPreparation;
  lastResult?: PitchKernelResult;
  history: ReadonlyArray<PitchHistoryItem>;
  rivalMemory?: RivalMemorySnapshot;
  gameState: GameStateSnapshot;
  gameLog: GameLogSnapshot;
  labInningStats: LabInningStats;
}

interface AutosaveEnvelope {
  checksumAlgorithm: "fnv1a32";
  checksum: string;
  payload: string;
}

interface StorageLike {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
  removeItem(key: string): void;
}

export interface AutosaveLoadResult {
  payload: PitcherLabAutosavePayload;
  source: "primary" | "backup";
  recoveredCorruption: boolean;
}

function checksum(value: string) {
  let hash = 0x811c9dc5;
  for (let index = 0; index < value.length; index += 1) {
    hash ^= value.charCodeAt(index);
    hash = Math.imul(hash, 0x01000193);
  }
  return (hash >>> 0).toString(16).padStart(8, "0");
}

function encode(payload: PitcherLabAutosavePayload) {
  const serialized = JSON.stringify(payload);
  const envelope: AutosaveEnvelope = {
    checksumAlgorithm: "fnv1a32",
    checksum: checksum(serialized),
    payload: serialized,
  };
  return JSON.stringify(envelope);
}

function decode(raw: string): PitcherLabAutosavePayload {
  const envelope = JSON.parse(raw) as Partial<AutosaveEnvelope>;
  if (envelope.checksumAlgorithm !== "fnv1a32" || typeof envelope.payload !== "string") {
    throw new Error("지원하지 않는 자동 저장 형식입니다.");
  }
  if (envelope.checksum !== checksum(envelope.payload)) {
    throw new Error("자동 저장 체크섬이 일치하지 않습니다.");
  }
  const payload = JSON.parse(envelope.payload) as Partial<PitcherLabAutosavePayload>;
  if (
    payload.format !== "DiamondSoulPitcherLabAutosave"
    || payload.schemaVersion !== 1
    || !payload.labResult
    || typeof payload.selectedPresetID !== "string"
  ) {
    throw new Error("자동 저장 데이터가 유효하지 않습니다.");
  }
  return payload as PitcherLabAutosavePayload;
}

export function savePitcherLabAutosave(
  storage: StorageLike,
  payload: PitcherLabAutosavePayload,
  now = Date.now(),
) {
  const current = storage.getItem(PRIMARY_KEY);
  if (current) {
    try {
      decode(current);
      storage.setItem(BACKUP_KEY, current);
    } catch {
      storage.setItem(`${CORRUPT_KEY_PREFIX}.${now}`, current);
    }
  }
  storage.setItem(PRIMARY_KEY, encode(payload));
}

export function loadPitcherLabAutosave(storage: StorageLike): AutosaveLoadResult | undefined {
  const primary = storage.getItem(PRIMARY_KEY);
  if (primary) {
    try {
      return { payload: decode(primary), source: "primary", recoveredCorruption: false };
    } catch {
      // The backup remains untouched and is evaluated below.
    }
  }
  const backup = storage.getItem(BACKUP_KEY);
  if (backup) {
    try {
      return { payload: decode(backup), source: "backup", recoveredCorruption: Boolean(primary) };
    } catch {
      return undefined;
    }
  }
  return undefined;
}

export function clearPitcherLabAutosave(storage: StorageLike) {
  storage.removeItem(PRIMARY_KEY);
  storage.removeItem(BACKUP_KEY);
}

export function createPitcherLabAnalysis(result: PitcherLabResult) {
  const snapshot = result.snapshot;
  return {
    format: "DiamondSoulPitcherLabAnalysis",
    schemaVersion: 1,
    exportedAt: new Date().toISOString(),
    run: {
      runID: snapshot.runID,
      lifeNumber: snapshot.lifeNumber,
      presetID: snapshot.presetID,
      phase: snapshot.phase,
      revision: snapshot.revision,
    },
    pitcher: snapshot.pitcher,
    potentialRanges: snapshot.potentialRanges,
    developmentSignals: snapshot.developmentSignals,
    performance: snapshot.performance,
    awakenings: snapshot.selectedAwakenings,
    scoutingEvaluation: snapshot.scoutingEvaluation,
    legacySelection: snapshot.legacySelection,
    events: result.events,
    eventHash: result.eventHash,
  };
}

export function downloadPitcherLabAnalysis(result: PitcherLabResult) {
  const contents = JSON.stringify(createPitcherLabAnalysis(result), null, 2);
  const url = URL.createObjectURL(new Blob([contents], { type: "application/json" }));
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = `diamond-soul-lab-${result.snapshot.runID}-life-${result.snapshot.lifeNumber}.json`;
  anchor.click();
  URL.revokeObjectURL(url);
}
