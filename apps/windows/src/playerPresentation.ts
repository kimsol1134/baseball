import type { BatterSnapshot, ProRole } from "./simulationTypes";

const PRO_ROLE_LABELS: Record<ProRole, string> = {
  starter: "선발투수",
  long_relief: "긴 이닝 구원",
  setup: "필승조",
  closer: "마무리투수",
};

export function pitcherRoleLabel(role?: ProRole): string {
  return role ? PRO_ROLE_LABELS[role] : "선발투수";
}

export function batterScoutingReport(batter: BatterSnapshot): string {
  const top = Math.max(batter.contact, batter.discipline, batter.power);
  const weakness = Math.min(batter.contact, batter.discipline, batter.power);
  const strengthCopy = batter.power === top
    ? "실투를 장타로 바꾸는 힘이 가장 위협적입니다."
    : batter.contact === top
      ? "존 안의 공을 오래 따라가며 맞히는 능력이 가장 좋습니다."
      : "볼을 골라 유리한 카운트를 만드는 능력이 가장 좋습니다.";
  const planCopy = batter.discipline === weakness
    ? "경계에 걸치는 변화구로 먼저 반응을 확인하세요."
    : batter.contact === weakness
      ? "스트라이크 존 가장자리를 넓게 쓰면 헛스윙을 노릴 수 있습니다."
      : "가운데 높은 공을 피하고 낮은 코스로 장타를 억제하세요.";
  return `${strengthCopy} ${planCopy}`;
}
