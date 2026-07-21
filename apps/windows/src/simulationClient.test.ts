import { beforeEach, describe, expect, it, vi } from "vitest";
import { invoke } from "@tauri-apps/api/core";
import {
  checkCoreHealth,
  preparePitch,
  simulatePitch,
  submitPitch,
} from "./simulationClient";

vi.mock("@tauri-apps/api/core", () => ({
  invoke: vi.fn(),
}));

const invokeMock = vi.mocked(invoke);

describe("simulation client", () => {
  beforeEach(() => {
    invokeMock.mockReset();
  });

  it("checks the embedded core through the Tauri boundary", async () => {
    invokeMock.mockResolvedValue(
      '{"id":"desktop-1","jsonrpc":"2.0","result":{"status":"ok","protocolVersion":"1.0","coreVersion":"0.1.0"}}',
    );

    const result = await checkCoreHealth();

    expect(result.status).toBe("ok");
    expect(invokeMock).toHaveBeenCalledWith(
      "execute_core",
      expect.objectContaining({ request: expect.stringContaining('"method":"health"') }),
    );
  });

  it("checks the core again when the user reconnects", async () => {
    invokeMock
      .mockRejectedValueOnce(new Error("sidecar exited"))
      .mockResolvedValueOnce(
        '{"id":"desktop-2","jsonrpc":"2.0","result":{"status":"ok","protocolVersion":"1.0","coreVersion":"0.1.0"}}',
      );

    await expect(checkCoreHealth()).rejects.toThrow("sidecar exited");
    await expect(checkCoreHealth()).resolves.toMatchObject({ status: "ok" });
    expect(invokeMock).toHaveBeenCalledTimes(2);
  });

  it("sends a typed pitch command and returns the event", async () => {
    invokeMock.mockResolvedValue(
      '{"id":"desktop-2","jsonrpc":"2.0","result":{"revision":1,"events":[{"eventType":"pitch_resolved","seed":"1","nextSeed":"2","outcome":"called_strike","wasInZone":true,"batterSwung":false,"executionScore":600,"reasonCodes":["outcome.called_strike"],"eventHash":"abc123"}],"snapshot":{"outcome":"called_strike","wasInZone":true,"batterSwung":false,"executionScore":600,"shortFeedback":"strike","detailFeedback":"detail","accessibilitySummary":"strike detail"}}}',
    );

    const result = await simulatePitch({
      seed: "1",
      pitcher: {
        id: "p1",
        name: "김도윤",
        stuff: 62,
        command: 54,
        movement: 58,
        stamina: 60,
      },
      batter: {
        id: "b1",
        name: "이준호",
        contact: 56,
        discipline: 52,
        power: 58,
      },
      count: { balls: 1, strikes: 1 },
      fatigue: 12,
      selection: {
        pitchType: "slider",
        zone: { row: 2, column: 0 },
        intensity: "normal",
      },
    });

    expect(result.snapshot.outcome).toBe("called_strike");
    expect(invokeMock).toHaveBeenCalledWith(
      "execute_core",
      expect.objectContaining({
        request: expect.stringContaining('"method":"simulatePitch"'),
      }),
    );
  });

  it("prepares the hidden plan before submitting a pitch call", async () => {
    const baseParams = {
      seed: "1",
      pitcher: {
        id: "p1",
        name: "김도윤",
        stuff: 62,
        command: 54,
        movement: 58,
        stamina: 60,
      },
      batter: {
        id: "b1",
        name: "이준호",
        contact: 56,
        discipline: 52,
        power: 58,
      },
      scouting: {
        hotZone: { row: 1, column: 1 },
        coldZone: { row: 2, column: 0 },
        pitchStrength: "four_seam" as const,
        pitchWeakness: "slider" as const,
        chaseTendency: 48,
      },
      context: {
        plateAppearanceID: "pa-1",
        revision: 0,
        inning: 7,
        outs: 0,
        balls: 1,
        strikes: 1,
        pitchNumber: 1,
        scoreDifferential: 0,
        leverage: 600,
        fatigue: 12,
      },
    };
    invokeMock
      .mockResolvedValueOnce(
        '{"id":"desktop-3","jsonrpc":"2.0","result":{"seed":"1","revision":0,"pitchNumber":1,"preparationToken":"token","planCommitment":"commitment","primaryRecommendation":{"call":{"pitchType":"slider","zone":{"row":2,"column":0},"zoneIntent":"edge","intensity":"normal"},"confidence":600,"reasonCodes":["scouting.cold_zone"],"shortReason":"낮은 몸쪽을 공략합니다."},"alternativeRecommendation":{"call":{"pitchType":"four_seam","zone":{"row":0,"column":2},"zoneIntent":"edge","intensity":"normal"},"confidence":500,"reasonCodes":["sequence.change_speed"],"shortReason":"다른 속도를 보여줍니다."}}}',
      )
      .mockResolvedValueOnce(
        '{"id":"desktop-4","jsonrpc":"2.0","result":{"revision":1,"nextSeed":"2","events":[{"eventType":"batter_plan_committed","sequence":0,"planCommitment":"commitment","reasonCodes":[]},{"eventType":"pitch_call_committed","sequence":1,"reasonCodes":[]}],"snapshot":{"revision":1,"balls":1,"strikes":2,"pitchNumber":1,"ended":false,"outcome":"called_strike","selectionQuality":"excellent","recommendationAccepted":true,"execution":{"targetX":-400,"targetY":-400,"actualX":-390,"actualY":-410,"velocityTenthsKPH":1300,"horizontalBreakTenthsCM":-140,"verticalBreakTenthsCM":30,"executionQuality":800},"reasonCodes":["outcome.called_strike"],"shortFeedback":"스트라이크","detailFeedback":"좋은 선택","accessibilitySummary":"스트라이크 좋은 선택"},"eventHash":"hash"}}',
      );

    const preparation = await preparePitch(baseParams);
    const result = await submitPitch({
      ...baseParams,
      preparationToken: preparation.preparationToken,
      call: preparation.primaryRecommendation.call,
    });

    expect(preparation.planCommitment).toBe("commitment");
    expect(result.snapshot.strikes).toBe(2);
    expect(invokeMock.mock.calls[0]?.[1]).toEqual(
      expect.objectContaining({ request: expect.stringContaining('"method":"preparePitch"') }),
    );
    expect(invokeMock.mock.calls[1]?.[1]).toEqual(
      expect.objectContaining({ request: expect.stringContaining('"method":"submitPitch"') }),
    );
  });
});
