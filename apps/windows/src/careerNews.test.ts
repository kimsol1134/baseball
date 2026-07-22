import { describe, expect, it } from "vitest";
import { careerNewsTone, classifyCareerNews, createCareerNewsDetail, type CareerNewsContext } from "./careerNews";

const context: CareerNewsContext = {
  mode: "high_school",
  playerName: "민서준",
  affiliation: "인천제문포고",
  period: "1학년 봄",
  trust: 52,
  fanInterest: 17,
  coachName: "윤태문",
  catcherName: "서준호",
};

describe("career news detail", () => {
  it("classifies gameplay, career, and health headlines", () => {
    expect(classifyCareerNews("민서준, 라이벌전 4탈삼진 무실점")).toBe("game");
    expect(classifyCareerNews("중학교 마지막 대회에서 관심을 끌었습니다")).toBe("game");
    expect(classifyCareerNews("중학교 마지막 대회 6이닝 투구")).toBe("game");
    expect(classifyCareerNews("드래프트 2라운드 지명")).toBe("career");
    expect(classifyCareerNews("고교 진학 제안 도착")).toBe("career");
    expect(classifyCareerNews("과부하로 3주 부상자 명단")).toBe("health");
  });

  it("evaluates negative signals before positive substrings", () => {
    expect(careerNewsTone("드래프트 미지명")).toBe("negative");
    expect(careerNewsTone("중요 경기 무실점")).toBe("positive");
    expect(careerNewsTone("5경기 · 18K · 0볼넷 · 0실점")).toBe("positive");
    expect(careerNewsTone("5경기 · 18K · 0볼넷 · 2실점")).toBe("negative");
    expect(careerNewsTone("볼넷 0개로 승리")).toBe("positive");
    expect(careerNewsTone("볼넷 4개로 흔들린 경기")).toBe("negative");
  });

  it("creates deterministic, contextual detail and varied fan posts", () => {
    const first = createCareerNewsDetail("민서준, 라이벌전 4탈삼진 무실점", 0, context);
    const second = createCareerNewsDetail("민서준, 라이벌전 4탈삼진 무실점", 0, context);
    expect(first).toEqual(second);
    expect(first.paragraphs.join(" ")).toContain("민서준");
    expect(first.quoteSpeaker).toBe("서준호 포수");
    expect(first.fanPosts).toHaveLength(4);
    expect(new Set(first.fanPosts.map((post) => post.handle)).size).toBe(4);
    expect(new Set(first.fanPosts.map((post) => post.message)).size).toBe(4);
  });

  it("selects natural Korean particles for names and affiliations", () => {
    const detail = createCareerNewsDetail("수상 후보에 올랐습니다.", 0, {
      ...context,
      playerName: "하루",
      affiliation: "인천제문포고",
    });

    expect(detail.lead).toContain("하루의 다음 팀");
    expect(detail.paragraphs[0]).toContain("하루의 구속 변화");
    expect(detail.paragraphs[1]).toContain("하루에게는 다음 등판");

    const admission = createCareerNewsDetail("인천제문포고 입학이 확정됐습니다.", 0, {
      ...context,
      playerName: "하루",
    });
    expect(admission.lead).toContain("하루가 인천제문포고에 입학했다");
  });

  it("changes reporting and fan reactions to match the event", () => {
    const admission = createCareerNewsDetail("인천제문포고 입학이 확정됐습니다.", 0, context);
    const game = createCareerNewsDetail("전국 대회 6이닝 무실점 승리.", 1, context);

    expect(admission.paragraphs.join(" ")).toContain("첫 불펜 일정");
    expect(admission.paragraphs.join(" ")).toContain("원하는 곳에 공을 꾸준히 던지는지");
    expect(admission.paragraphs.join(" ")).not.toContain("재현성");
    expect(admission.watchPoint).toContain("봄 대회에서 맡을 역할");
    expect(admission.fanSummary).toBe("학교 선택을 반기며 첫 등판을 기다리고 있다");
    expect(admission.fanPosts.every((post) => !post.message.includes("한 경기"))).toBe(true);
    expect(game.paragraphs.join(" ")).toContain("무실점이라는 결과");
    expect(game.fanSummary).toBe("오늘 투구가 좋았다는 반응이 많다");
    expect(game.fanPosts.some((post) => post.message.includes("등판") || post.message.includes("마운드"))).toBe(true);
  });
});
