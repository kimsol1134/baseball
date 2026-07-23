// @vitest-environment jsdom

import { act } from "react";
import { createRoot } from "react-dom/client";
import { renderToStaticMarkup } from "react-dom/server";
import { afterEach, describe, expect, it, vi } from "vitest";
import { CoreUnavailableState } from "./CoreUnavailableState";

Reflect.set(globalThis, "IS_REACT_ACT_ENVIRONMENT", true);

afterEach(() => document.body.replaceChildren());

describe("CoreUnavailableState", () => {
  it("explains the failure, save safety, and recovery action", () => {
    const html = renderToStaticMarkup(<CoreUnavailableState message="연결이 끊어졌습니다." onRetry={() => undefined} />);

    expect(html).toContain('role="status"');
    expect(html).toContain('aria-live="polite"');
    expect(html).toContain("연결이 끊어졌습니다.");
    expect(html).toContain("저장된 커리어는 지워지지 않습니다");
    expect(html).toContain("다시 연결");
  });

  it("runs the recovery action from the visible retry button", async () => {
    const host = document.createElement("div");
    document.body.append(host);
    const retry = vi.fn();
    const root = createRoot(host);
    await act(async () => root.render(<CoreUnavailableState message="코어 응답 시간 초과" onRetry={retry} />));

    const button = host.querySelector("button");
    expect(button?.textContent).toContain("다시 연결");
    button?.click();
    expect(retry).toHaveBeenCalledOnce();
    await act(async () => root.unmount());
  });
});
