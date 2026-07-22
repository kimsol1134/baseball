import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import { CoreUnavailableState } from "./CoreUnavailableState";

describe("CoreUnavailableState", () => {
  it("explains the failure, save safety, and recovery action", () => {
    const html = renderToStaticMarkup(<CoreUnavailableState message="연결이 끊어졌습니다." onRetry={() => undefined} />);

    expect(html).toContain('role="status"');
    expect(html).toContain('aria-live="polite"');
    expect(html).toContain("연결이 끊어졌습니다.");
    expect(html).toContain("저장된 커리어는 지워지지 않습니다");
    expect(html).toContain("다시 연결");
  });
});
