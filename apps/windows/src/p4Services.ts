import type { HighSchoolCareerAutosavePayload } from "./highSchoolCareerAutosave";

const ANALYTICS_KEY = "diamond-soul.analytics.events.v1";

export interface LocalAnalyticsEvent {
  name: string;
  occurredAt: string;
  properties: Record<string, string | number | boolean>;
}

interface StorageLike {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
}

export function recordLocalAnalytics(
  storage: StorageLike,
  optedIn: boolean,
  event: LocalAnalyticsEvent,
) {
  if (!optedIn) return;
  let current: LocalAnalyticsEvent[] = [];
  try {
    const parsed = JSON.parse(storage.getItem(ANALYTICS_KEY) ?? "[]") as unknown;
    if (Array.isArray(parsed)) current = parsed as LocalAnalyticsEvent[];
  } catch { /* replace malformed local diagnostics */ }
  storage.setItem(ANALYTICS_KEY, JSON.stringify([...current.slice(-499), event]));
}

export function readLocalAnalytics(storage: Pick<StorageLike, "getItem">): ReadonlyArray<LocalAnalyticsEvent> {
  try {
    const parsed = JSON.parse(storage.getItem(ANALYTICS_KEY) ?? "[]") as unknown;
    return Array.isArray(parsed) ? parsed as LocalAnalyticsEvent[] : [];
  } catch {
    return [];
  }
}

export interface ContentPackManifest {
  format: "DiamondSoulContentPack";
  schemaVersion: 1;
  id: string;
  title: string;
  version: string;
  gameVersion: string;
  author: string;
  content: ReadonlyArray<{ type: "relationship_event" | "game_scenario"; id: string; path: string }>;
}

export function validateContentPackManifest(value: unknown): ContentPackManifest {
  if (!value || typeof value !== "object") throw new Error("콘텐츠 팩 선언이 객체가 아닙니다.");
  const manifest = value as Partial<ContentPackManifest>;
  if (manifest.format !== "DiamondSoulContentPack" || manifest.schemaVersion !== 1) throw new Error("지원하지 않는 콘텐츠 팩 형식입니다.");
  for (const field of ["id", "title", "version", "gameVersion", "author"] as const) {
    if (typeof manifest[field] !== "string" || !manifest[field]?.trim()) throw new Error(`${field} 필드가 필요합니다.`);
  }
  if (!/^[a-z0-9][a-z0-9._-]+$/.test(manifest.id!)) throw new Error("콘텐츠 팩 ID는 영문 소문자, 숫자, 점, 밑줄, 하이픈만 사용할 수 있습니다.");
  if (!Array.isArray(manifest.content) || manifest.content.length === 0) throw new Error("콘텐츠 항목이 한 개 이상 필요합니다.");
  const ids = new Set<string>();
  for (const entry of manifest.content) {
    if (!entry || !["relationship_event", "game_scenario"].includes(entry.type) || !entry.id || !entry.path) throw new Error("콘텐츠 항목이 유효하지 않습니다.");
    if (entry.path.startsWith("/") || entry.path.includes("..") || entry.path.includes("\\")) throw new Error("콘텐츠 경로는 팩 내부의 안전한 상대 경로여야 합니다.");
    if (ids.has(entry.id)) throw new Error(`중복 콘텐츠 ID: ${entry.id}`);
    ids.add(entry.id);
  }
  return manifest as ContentPackManifest;
}

function anonymizedCareer(save?: HighSchoolCareerAutosavePayload) {
  if (!save) return undefined;
  const state = save.careerResult.snapshot;
  return {
    schemaVersion: save.schemaVersion,
    savedAt: save.savedAt,
    screenMode: save.screenMode,
    career: {
      phase: state.phase,
      revision: state.revision,
      lifeNumber: state.lifeNumber,
      chapter: state.chapter.number,
      schoolID: state.school?.id,
      difficulty: state.difficulty,
      karmas: state.karmas,
      performance: state.performance,
    },
  };
}

export function createAnonymousDiagnosticPackage(input: {
  appVersion: string;
  coreVersion?: string;
  protocolVersion?: string;
  error?: string;
  save?: HighSchoolCareerAutosavePayload;
  analytics: ReadonlyArray<LocalAnalyticsEvent>;
}) {
  return JSON.stringify({
    format: "DiamondSoulDiagnostic",
    schemaVersion: 1,
    createdAt: new Date().toISOString(),
    appVersion: input.appVersion,
    coreVersion: input.coreVersion,
    protocolVersion: input.protocolVersion,
    platform: navigator.userAgent.replace(/\([^)]*\)/g, "(redacted)"),
    error: input.error,
    save: anonymizedCareer(input.save),
    analytics: input.analytics,
    privacy: "선수 이름, 시드, 커밋 해시, 자유 입력 텍스트는 포함하지 않음",
  }, null, 2);
}

export function downloadTextFile(filename: string, contents: string, type = "application/json") {
  const blob = new Blob([contents], { type });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = filename;
  anchor.click();
  URL.revokeObjectURL(url);
}
