import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import { AvatarFace } from "./AvatarFace";

describe("AvatarFace", () => {
  it("renders the same face for the same seed", () => {
    const first = renderToStaticMarkup(<AvatarFace seed="윤태문" role="coach" />);
    const second = renderToStaticMarkup(<AvatarFace seed="윤태문" role="coach" />);
    expect(first).toBe(second);
  });

  it("renders different faces for different seeds", () => {
    const names = ["윤태문", "노재형", "오승렬", "배도환", "서준호", "차민석", "강이안", "민서준", "고태윤", "진서율"];
    const faces = new Set(names.map((name) => renderToStaticMarkup(<AvatarFace seed={name} role="player" />)));
    expect(faces.size).toBeGreaterThanOrEqual(names.length - 1);
  });

  it("adds role props such as the catcher mask and rival helmet", () => {
    const catcher = renderToStaticMarkup(<AvatarFace seed="서준호" role="catcher" />);
    const rival = renderToStaticMarkup(<AvatarFace seed="강이안" role="rival" />);
    const player = renderToStaticMarkup(<AvatarFace seed="민서준" role="player" />);
    expect(catcher).not.toBe(player);
    expect(rival).not.toBe(player);
  });
});
