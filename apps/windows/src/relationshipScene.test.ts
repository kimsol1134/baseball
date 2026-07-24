import { describe, expect, it } from "vitest";
import { relationshipScene } from "./HighSchoolCareerView";
import type { CareerEventContent, HighSchoolCareerResult } from "./simulationTypes";

// relationshipScene가 읽는 최소 상태. 확장 커스텀 장면은 신뢰도 밴드를 쓰지 않지만
// 함수 상단에서 rival.name과 trust 값을 참조하므로 채워 둔다.
const baseState = {
  relationshipTrust: 50,
  managerTrust: 50,
  catcherTrust: 50,
  rivalTrust: 50,
  rival: { name: "라이벌" },
  school: { coachName: "김감독", catcherName: "이포수" },
} as unknown as HighSchoolCareerResult["snapshot"];

function event(id: string, category: string, summary: string): CareerEventContent {
  return { id, title: "제목", category, summary };
}

describe("relationshipScene 확장 커스텀 장면", () => {
  it("서사 가치가 높은 확장 이벤트에 역할 화자·손대사·듣기/설명/도전 3선택지를 준다", () => {
    const custom: ReadonlyArray<{ id: string; category: string; speaker: string }> = [
      { id: "evt-fan-letter", category: "fan", speaker: "팬" },
      { id: "evt-parent-call", category: "life", speaker: "부모님" },
      { id: "evt-exam-week", category: "life", speaker: "담임 선생님" },
      { id: "evt-loss-interview", category: "media", speaker: "기자" },
      { id: "evt-national-stage", category: "media", speaker: "중계 PD" },
      { id: "evt-captain-talk", category: "team", speaker: "주장" },
      { id: "evt-school-record", category: "fan", speaker: "후배" },
      { id: "evt-scout-question", category: "draft", speaker: "스카우트" },
      { id: "evt-velocity-drop", category: "health", speaker: "트레이너" },
      { id: "evt-bullpen-rival", category: "team", speaker: "경쟁하는 동료" },
    ];
    for (const { id, category, speaker } of custom) {
      const summary = `${id} 기본 카테고리 요약`;
      const scene = relationshipScene(event(id, category, summary), baseState);
      expect(scene.speaker).toBe(speaker);
      // 커스텀 장면은 카테고리 기본 장면(요약을 그대로 인용)으로 떨어지면 안 된다.
      expect(scene.quote).not.toBe(summary);
      expect(scene.quote.length).toBeGreaterThan(0);
      expect(scene.choices).toHaveLength(3);
      expect(scene.choices.map((choice) => choice.id)).toEqual(["listen", "explain", "challenge"]);
      for (const choice of scene.choices) {
        expect(choice.title.length).toBeGreaterThan(0);
        expect(choice.copy.length).toBeGreaterThan(0);
      }
    }
  });

  it("커스텀 장면이 없는 확장 이벤트는 카테고리 기본 장면(요약 인용)을 유지한다", () => {
    const summary = "카테고리 기본 문구를 그대로 인용";
    const scene = relationshipScene(event("evt-winter-weight", "growth", summary), baseState);
    expect(scene.quote).toBe(summary);
    expect(scene.choices).toHaveLength(3);
  });

  it("팔 상태 장면(evt-arm-care)은 그대로 보존한다", () => {
    const scene = relationshipScene(event("evt-arm-care", "health", "무시되는 요약"), baseState);
    expect(scene.speaker).toBe("트레이너");
    expect(scene.quote).not.toBe("무시되는 요약");
    expect([...scene.choices.map((choice) => choice.id)].sort()).toEqual(["challenge", "explain", "listen"]);
  });
});
