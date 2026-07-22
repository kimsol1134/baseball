import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";
import { AccessibleModal } from "./AccessibleModal";

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
});
