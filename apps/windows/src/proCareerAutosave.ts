import type { HighSchoolCareerResult, ProCareerResult } from "./simulationTypes";

const PRIMARY = "baseball.pro-career.autosave.v1";
const BACKUP = `${PRIMARY}.backup`;
const CORRUPT = `${PRIMARY}.corrupt`;

interface StorageLike { getItem(key: string): string | null; setItem(key: string, value: string): void; removeItem(key: string): void }
interface Envelope { checksum: string; payload: string }
export interface ProCareerAutosavePayload {
  format: "BaseballProCareerAutosave";
  schemaVersion: 1;
  savedAt: string;
  selectedPresetID: string;
  highSchoolCareer: HighSchoolCareerResult;
  proCareer: ProCareerResult;
}

function checksum(value: string) {
  let hash = 0x811c9dc5;
  for (let i = 0; i < value.length; i += 1) { hash ^= value.charCodeAt(i); hash = Math.imul(hash, 0x01000193); }
  return (hash >>> 0).toString(16).padStart(8, "0");
}
function encode(value: ProCareerAutosavePayload) { const payload = JSON.stringify(value); return JSON.stringify({ checksum: checksum(payload), payload }); }
function decode(raw: string): ProCareerAutosavePayload {
  const envelope = JSON.parse(raw) as Partial<Envelope>;
  if (typeof envelope.payload !== "string" || envelope.checksum !== checksum(envelope.payload)) throw new Error("프로 저장 체크섬이 일치하지 않습니다.");
  const value = JSON.parse(envelope.payload) as Partial<ProCareerAutosavePayload>;
  if (value.format !== "BaseballProCareerAutosave" || value.schemaVersion !== 1 || !value.proCareer || !value.highSchoolCareer) throw new Error("프로 저장 형식이 유효하지 않습니다.");
  return value as ProCareerAutosavePayload;
}
export function saveProCareer(storage: StorageLike, value: ProCareerAutosavePayload, now = Date.now()) {
  const current = storage.getItem(PRIMARY);
  if (current) { try { decode(current); storage.setItem(BACKUP, current); } catch { storage.setItem(`${CORRUPT}.${now}`, current); } }
  storage.setItem(PRIMARY, encode(value));
}
export function loadProCareer(storage: StorageLike) {
  const primary = storage.getItem(PRIMARY);
  if (primary) { try { return { payload: decode(primary), source: "primary" as const }; } catch { /* recover backup */ } }
  const backup = storage.getItem(BACKUP);
  if (!backup) return undefined;
  try { return { payload: decode(backup), source: "backup" as const }; } catch { return undefined; }
}
export function clearProCareer(storage: StorageLike) { storage.removeItem(PRIMARY); storage.removeItem(BACKUP); }
