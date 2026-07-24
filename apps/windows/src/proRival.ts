import type { BatterSnapshot, ProRivalBatter } from "./simulationTypes";

// 프로 라이벌 타자(currentRival)는 아키타입만 갖고 타격 수치가 없다. 중요 경기 투구
// 시뮬레이션에 쓰도록 아키타입 문구에서 공 맞히기·볼 고르기·장타력을 결정론적으로 파생한다.
// 이름·id는 그대로 이어받아 투구 화면 리포트의 상대가 프로 화면의 라이벌과 일치하게 하고,
// 수치는 아키타입에 맞춰 승부 성격(거포/교타/선구안 등)을 반영한다.

type BatterStats = Pick<BatterSnapshot, "contact" | "discipline" | "power">;

// 구세이브·아키타입 미상일 때의 기본값. 기존 하드코딩 상대(중심타자)와 같은 균형형 수치.
export const DEFAULT_PRO_BATTER: BatterSnapshot = {
  id: "pro-opponent-cleanup",
  name: "오재민",
  contact: 52,
  discipline: 50,
  power: 55,
};

// 아키타입 키워드 → 타격 성향. 위에서부터 먼저 걸리는 성향을 쓴다(파워 신호가 가장 강함).
// 엔진의 라이벌 풀뿐 아니라 새 아키타입이 들어와도 키워드로 무난히 파생되도록 구성한다.
const ARCHETYPE_PROFILES: ReadonlyArray<{ match: readonly string[] } & BatterStats> = [
  { match: ["거포"], contact: 48, discipline: 48, power: 63 },
  { match: ["홈런"], contact: 47, discipline: 45, power: 62 },
  { match: ["파워"], contact: 46, discipline: 49, power: 64 },
  { match: ["컨택", "무결점"], contact: 63, discipline: 56, power: 44 },
  { match: ["교타", "정확"], contact: 61, discipline: 54, power: 44 },
  { match: ["선구안", "출루"], contact: 51, discipline: 64, power: 46 },
  { match: ["갭"], contact: 55, discipline: 52, power: 52 },
  { match: ["빠른 발", "빠른발", "도루"], contact: 58, discipline: 52, power: 45 },
  { match: ["득점권", "해결사", "중심"], contact: 54, discipline: 53, power: 55 },
];

export function batterStatsForArchetype(archetype: string): BatterStats {
  for (const profile of ARCHETYPE_PROFILES) {
    if (profile.match.some((keyword) => archetype.includes(keyword))) {
      return { contact: profile.contact, discipline: profile.discipline, power: profile.power };
    }
  }
  return { contact: DEFAULT_PRO_BATTER.contact, discipline: DEFAULT_PRO_BATTER.discipline, power: DEFAULT_PRO_BATTER.power };
}

// 중요 경기 상대 타자를 프로 스냅숏의 currentRival에서 파생한다. currentRival이 없으면
// (구세이브 등) 기본 상대로 폴백한다.
export function proBatterFromRival(rival: ProRivalBatter | undefined): BatterSnapshot {
  if (!rival) return DEFAULT_PRO_BATTER;
  return { id: rival.id, name: rival.name, ...batterStatsForArchetype(rival.archetype) };
}
