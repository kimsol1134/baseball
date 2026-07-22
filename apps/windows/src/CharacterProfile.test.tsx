import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import { CharacterProfile } from "./CharacterProfile";

describe("CharacterProfile", () => {
  it("omits empty optional details from older saves", () => {
    const markup = renderToStaticMarkup(<CharacterProfile label="감독" title="윤태문 · 원칙형" />);

    expect(markup).toContain("윤태문 · 원칙형");
    expect(markup).not.toContain("<small");
    expect(markup).not.toContain("<p");
  });

  it("renders complete profile details through the shared contract", () => {
    const markup = renderToStaticMarkup(<CharacterProfile
      className="rival-scouting"
      title="서하준 · 천재 교타형"
      record="봄 대회 타율 .421"
      description="같은 코스를 두 번 놓치지 않습니다."
    />);

    expect(markup).toContain('class="character-profile rival-scouting"');
    expect(markup).toContain("<small>봄 대회 타율 .421</small>");
    expect(markup).toContain("<p>같은 코스를 두 번 놓치지 않습니다.</p>");
  });
});
