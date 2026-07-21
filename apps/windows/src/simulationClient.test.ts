import { beforeEach, describe, expect, it, vi } from "vitest";
import { invoke } from "@tauri-apps/api/core";
import { checkCoreHealth, simulatePitch } from "./simulationClient";

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
});
