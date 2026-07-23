// @vitest-environment jsdom

import { act } from "react";
import { createRoot } from "react-dom/client";
import { renderToStaticMarkup } from "react-dom/server";
import { afterEach, describe, expect, it, vi } from "vitest";
import { AccessibleModal } from "./AccessibleModal";

Reflect.set(globalThis, "IS_REACT_ACT_ENVIRONMENT", true);

afterEach(() => {
  document.body.replaceChildren();
  vi.restoreAllMocks();
});

describe("AccessibleModal", () => {
  it("renders the dialog and modal accessibility contract", () => {
    const html = renderToStaticMarkup(
      <AccessibleModal className="test-modal" labelledBy="modal-title"><h2 id="modal-title">안내</h2></AccessibleModal>,
    );

    expect(html).toContain('role="dialog"');
    expect(html).toContain('aria-modal="true"');
    expect(html).toContain('aria-labelledby="modal-title"');
    expect(html).toContain('tabindex="-1"');
  });

  it("moves focus in, traps Tab, handles Escape, and restores focus", async () => {
    const opener = document.createElement("button");
    const outside = document.createElement("div");
    const host = document.createElement("div");
    document.body.append(opener, outside, host);
    opener.focus();
    vi.spyOn(window, "requestAnimationFrame").mockImplementation((callback) => { callback(0); return 1; });
    vi.spyOn(window, "cancelAnimationFrame").mockImplementation(() => undefined);
    const onEscape = vi.fn();
    const root = createRoot(host);

    await act(async () => root.render(
      <AccessibleModal className="test-modal" label="확인" onEscape={onEscape}>
        <button type="button">첫 버튼</button><button type="button">마지막 버튼</button>
      </AccessibleModal>,
    ));

    const [first, last] = Array.from(host.querySelectorAll("button"));
    expect(document.activeElement).toBe(first);
    expect(outside.inert).toBe(true);
    last.focus();
    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Tab", bubbles: true, cancelable: true }));
    expect(document.activeElement).toBe(first);
    first.focus();
    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Tab", shiftKey: true, bubbles: true, cancelable: true }));
    expect(document.activeElement).toBe(last);
    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true, cancelable: true }));
    expect(onEscape).toHaveBeenCalledOnce();

    await act(async () => root.unmount());
    expect(outside.inert).not.toBe(true);
    expect(document.activeElement).toBe(opener);
  });
});
