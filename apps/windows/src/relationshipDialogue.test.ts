import { describe, expect, it } from "vitest";
import { bandedRelationshipQuote, RELATIONSHIP_QUOTE_VARIANTS, relationshipTrustBand } from "./relationshipDialogue";

describe("relationship dialogue trust bands", () => {
  it("maps trust to bands at the 45/65 boundaries", () => {
    expect(relationshipTrustBand(0)).toBe("low");
    expect(relationshipTrustBand(44)).toBe("low");
    expect(relationshipTrustBand(45)).toBe("mid");
    expect(relationshipTrustBand(52)).toBe("mid");
    expect(relationshipTrustBand(64)).toBe("mid");
    expect(relationshipTrustBand(65)).toBe("high");
    expect(relationshipTrustBand(100)).toBe("high");
  });

  it("gives every keyed scene a low and high variant distinct from the 보통 baseline", () => {
    const ids = Object.keys(RELATIONSHIP_QUOTE_VARIANTS);
    expect(ids).toContain("evt-coach-role");
    expect(ids).toContain("evt-catcher-sign");
    expect(ids).toContain("evt-rival-final");
    for (const id of ids) {
      const variant = RELATIONSHIP_QUOTE_VARIANTS[id];
      expect(variant.low).not.toBe(variant.mid);
      expect(variant.high).not.toBe(variant.mid);
      expect(variant.low).not.toBe(variant.high);
      expect(variant.low.length).toBeGreaterThan(0);
      expect(variant.high.length).toBeGreaterThan(0);
    }
  });

  it("selects the banded quote from the appropriate trust and leaves the baseline as 보통", () => {
    const lowTrust = relationshipTrustBand(30);
    const highTrust = relationshipTrustBand(80);
    expect(bandedRelationshipQuote("evt-coach-bench", lowTrust)).toBe(RELATIONSHIP_QUOTE_VARIANTS["evt-coach-bench"].low);
    expect(bandedRelationshipQuote("evt-coach-bench", highTrust)).toBe(RELATIONSHIP_QUOTE_VARIANTS["evt-coach-bench"].high);
    expect(bandedRelationshipQuote("evt-coach-bench", "mid")).toBe("“이번 등판은 쉰다. 요즘은 팔이 몸보다 늦게 따라온다.”");
    expect(bandedRelationshipQuote("evt-new-catcher", "low")).toBeUndefined();
  });
});
