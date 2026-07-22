import { beforeEach, describe, expect, it, vi } from "vitest";
import { invoke } from "@tauri-apps/api/core";
import {
  checkCoreHealth,
  listPitcherPresets,
  preparePitch,
  simulatePitch,
  startHighSchoolCareer,
  startPitcherLab,
  startProCareer,
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
      '{"id":"desktop-1","jsonrpc":"2.0","result":{"status":"ok","protocolVersion":"3.0","coreVersion":"1.0.0"}}',
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
        '{"id":"desktop-2","jsonrpc":"2.0","result":{"status":"ok","protocolVersion":"3.0","coreVersion":"1.0.0"}}',
      );

    await expect(checkCoreHealth()).rejects.toThrow("sidecar exited");
    await expect(checkCoreHealth()).resolves.toMatchObject({ status: "ok" });
    expect(invokeMock).toHaveBeenCalledTimes(2);
  });

  it("loads pitcher presets from the simulation core", async () => {
    invokeMock.mockResolvedValue(
      '{"id":"desktop-3","jsonrpc":"2.0","result":[{"id":"power_prospect","name":"강속구 원석","tagline":"빠른 포심","strengths":["포심"],"tradeoff":"제구","pitcher":{"id":"p1","name":"김도윤","stuff":72,"command":44,"movement":52,"stamina":52,"pitchProfiles":[]}}]}',
    );

    const presets = await listPitcherPresets();

    expect(presets[0]?.id).toBe("power_prospect");
    expect(invokeMock).toHaveBeenCalledWith(
      "execute_core",
      expect.objectContaining({ request: expect.stringContaining('"method":"listPitcherPresets"') }),
    );
  });

  it("starts Pitcher Lab through the typed RPC boundary", async () => {
    invokeMock.mockResolvedValue(
      '{"id":"desktop-lab","jsonrpc":"2.0","result":{"revision":0,"nextSeed":"2","events":[],"snapshot":{"phase":"training","trainingSessionsCompleted":0},"eventHash":"lab-hash"}}',
    );

    const result = await startPitcherLab({
      seed: "1",
      presetID: "power_prospect",
      lifeNumber: 1,
      inheritedSoulPoints: 0,
    });

    expect(result.snapshot.phase).toBe("training");
    expect(invokeMock).toHaveBeenCalledWith(
      "execute_core",
      expect.objectContaining({ request: expect.stringContaining('"method":"startPitcherLab"') }),
    );
  });

  it("starts the high school career through the typed RPC boundary", async () => {
    invokeMock.mockResolvedValue(
      '{"id":"desktop-career","jsonrpc":"2.0","result":{"revision":0,"nextSeed":"2","events":[],"snapshot":{"phase":"prologue","schoolOptions":[]},"eventHash":"career-hash"}}',
    );

    const result = await startHighSchoolCareer({
      seed: "1",
      presetID: "power_prospect",
      lifeNumber: 1,
      creationAllocation: { stuff: 2, command: 1, movement: 1, stamina: 1 },
      inheritedSoulPoints: 0,
      inheritedMemories: [],
      identity: { name: "김도윤", throwingHand: "right", bodyType: "balanced", region: "서울" },
      difficulty: { careerHarshness: "standard", informationClarity: "standard", simulationDifficulty: "standard", interventionAssist: "standard" },
      karmas: [],
    });

    expect(result.snapshot.phase).toBe("prologue");
    expect(invokeMock).toHaveBeenCalledWith(
      "execute_core",
      expect.objectContaining({ request: expect.stringContaining('"method":"startHighSchoolCareer"') }),
    );
  });

  it("starts the pro career through the entitlement boundary", async () => {
    invokeMock.mockResolvedValue('{"id":"desktop-pro","jsonrpc":"2.0","result":{"nextSeed":"2","events":[],"snapshot":{"phase":"contract_offer"}}}');
    const result = await startProCareer({
      seed: "1", identity: { name: "김도윤", throwingHand: "right", bodyType: "balanced", region: "서울" },
      pitcher: { id: "p", name: "김도윤", stuff: 58, command: 56, movement: 55, stamina: 57 },
      draftResult: { outcome: "drafted", evaluationScore: 72, projectedRange: "2라운드", team: { id: "seoul", name: "서울", need: "command", demand: 60, developmentPlan: "2군", positionCompetitor: "선발", proCoach: "코치" }, summary: "지명" },
      entitlement: { productID: "diamond_soul_pro_career", status: "active", source: "development", verifiedAt: "2026-07-22" },
    });
    expect(result.snapshot.phase).toBe("contract_offer");
    expect(invokeMock).toHaveBeenCalledWith("execute_core", expect.objectContaining({ request: expect.stringContaining('"method":"startProCareer"') }));
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
        '{"id":"desktop-3","jsonrpc":"2.0","result":{"seed":"1","revision":0,"pitchNumber":1,"preparationToken":"token","planCommitment":"commitment","primaryRecommendation":{"call":{"pitchType":"slider","zone":{"row":2,"column":0},"zoneIntent":"edge","intensity":"normal"},"confidence":600,"reasonCodes":["scouting.cold_zone"],"shortReason":"낮은 몸쪽을 공략합니다."},"alternativeRecommendation":{"call":{"pitchType":"four_seam","zone":{"row":0,"column":2},"zoneIntent":"edge","intensity":"normal"},"confidence":500,"reasonCodes":["sequence.change_speed"],"shortReason":"다른 속도를 보여줍니다."},"rivalAdaptation":{"level":0,"band":"no_data","evidenceCount":0,"confidence":0,"warning":"표본 없음"}}}',
      )
      .mockResolvedValueOnce(
        '{"id":"desktop-4","jsonrpc":"2.0","result":{"revision":1,"nextSeed":"2","events":[{"eventType":"batter_plan_committed","sequence":0,"planCommitment":"commitment","reasonCodes":[]},{"eventType":"pitch_call_committed","sequence":1,"reasonCodes":[]}],"snapshot":{"revision":1,"balls":1,"strikes":2,"pitchNumber":1,"ended":false,"outcome":"called_strike","selectionQuality":"excellent","recommendationAccepted":true,"fatigueAfterPitch":13,"execution":{"targetX":-400,"targetY":-400,"actualX":-390,"actualY":-410,"velocityTenthsKPH":1300,"horizontalBreakTenthsCM":-140,"verticalBreakTenthsCM":30,"executionQuality":800},"runnersAfter":{"firstOccupied":true,"secondOccupied":false,"thirdOccupied":false,"leadRunnerSpeed":62},"runsScored":0,"inningTransition":{"before":{"inning":7,"half":"bottom","outs":0},"after":{"inning":7,"half":"bottom","outs":0},"outsRecorded":0,"doublePlayCompleted":false,"inningEnded":false,"shortExplanation":"아웃카운트 유지"},"reasonCodes":["outcome.called_strike"],"shortFeedback":"스트라이크","detailFeedback":"좋은 선택","accessibilitySummary":"스트라이크 좋은 선택"},"rivalMemory":{"matchupID":"p1:b1","revision":1,"plateAppearancesSeen":0,"totalPitchesSeen":1,"recentObservations":[]},"rivalAdaptation":{"level":10,"band":"watching","evidenceCount":1,"confidence":50,"warning":"관찰 중"},"gameState":{"defense":{"infield":58,"outfield":55,"arm":57},"park":{"id":"park","name":"한빛고 야구장","hitFactor":980,"homeRunFactor":930},"runners":{"firstOccupied":true,"secondOccupied":false,"thirdOccupied":false,"leadRunnerSpeed":62},"runsAllowed":0,"inningState":{"inning":7,"half":"bottom","outs":0}},"gameLog":{"gameID":"game","revision":1,"totalPitches":1,"entries":[]},"postgameAnalysis":{"sampleSize":1,"confidence":"low","zoneRate":1000,"whiffRate":0,"hardHitRate":0,"averageSelectionQuality":900,"averageExecutionQuality":800,"expectedDamage":0,"actualDamage":0,"pitchBreakdowns":[],"patternWarning":"표본 부족","growthSignal":"실행 안정"},"eventHash":"hash"}}',
      );

    const preparation = await preparePitch(baseParams);
    const result = await submitPitch({
      ...baseParams,
      preparationToken: preparation.preparationToken,
      call: preparation.primaryRecommendation.call,
    });

    expect(preparation.planCommitment).toBe("commitment");
    expect(result.snapshot.strikes).toBe(2);
    expect(result.rivalMemory.totalPitchesSeen).toBe(1);
    expect(result.gameLog.totalPitches).toBe(1);
    expect(result.gameState.inningState).toEqual({ inning: 7, half: "bottom", outs: 0 });
    expect(result.snapshot.inningTransition?.outsRecorded).toBe(0);
    expect(result.postgameAnalysis.confidence).toBe("low");
    expect(invokeMock.mock.calls[0]?.[1]).toEqual(
      expect.objectContaining({ request: expect.stringContaining('"method":"preparePitch"') }),
    );
    expect(invokeMock.mock.calls[1]?.[1]).toEqual(
      expect.objectContaining({ request: expect.stringContaining('"method":"submitPitch"') }),
    );
  });
});
