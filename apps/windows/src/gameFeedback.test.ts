import { afterEach, describe, expect, it, vi } from "vitest";
import { feedbackCueForResult, GameFeedback } from "./gameFeedback";
import type { PitchKernelResult } from "./simulationTypes";

function fakeParam() {
  return { setValueAtTime: vi.fn(), exponentialRampToValueAtTime: vi.fn() };
}

function makeFakeAudioContext() {
  const started: string[] = [];
  const makeNode = (kind: string) => ({
    kind,
    type: "",
    buffer: null as unknown,
    loop: false,
    onended: null as null | (() => void),
    gain: fakeParam(),
    frequency: fakeParam(),
    detune: fakeParam(),
    Q: fakeParam(),
    connect(target: unknown) { return target; },
    start() { started.push(kind); },
    stop() {},
  });
  class FakeAudioContext {
    currentTime = 0;
    sampleRate = 44_100;
    destination = {};
    resume = vi.fn(() => Promise.resolve());
    createGain() { return makeNode("gain"); }
    createOscillator() { return makeNode("oscillator"); }
    createBiquadFilter() { return makeNode("filter"); }
    createBufferSource() { return makeNode("noise"); }
    createBuffer(_channels: number, length: number) {
      return { getChannelData: () => new Float32Array(length) };
    }
  }
  return { FakeAudioContext, started };
}

function result(outcome: PitchKernelResult["snapshot"]["outcome"], plateResult?: PitchKernelResult["snapshot"]["result"]) {
  return { snapshot: { outcome, result: plateResult } } as PitchKernelResult;
}

describe("game feedback", () => {
  it("prioritizes plate-ending achievements over the last pitch type", () => {
    expect(feedbackCueForResult(result("swinging_strike", "strikeout"))).toBe("strikeout");
    expect(feedbackCueForResult(result("single", "hit"))).toBe("big_hit");
  });

  it("maps ordinary pitch outcomes to restrained cues", () => {
    expect(feedbackCueForResult(result("called_strike"))).toBe("strike");
    expect(feedbackCueForResult(result("foul"))).toBe("contact");
    expect(feedbackCueForResult(result("ball"))).toBe("ball");
  });
});

describe("game feedback synthesis", () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it("creates no audio nodes while sound is muted", () => {
    const { FakeAudioContext, started } = makeFakeAudioContext();
    const constructorSpy = vi.fn(() => new FakeAudioContext());
    vi.stubGlobal("window", { AudioContext: constructorSpy });
    new GameFeedback().play("big_hit", false, false);
    expect(constructorSpy).not.toHaveBeenCalled();
    expect(started).toHaveLength(0);
  });

  it("layers tone and noise voices for a mitt pop", () => {
    const { FakeAudioContext, started } = makeFakeAudioContext();
    vi.stubGlobal("window", { AudioContext: FakeAudioContext });
    new GameFeedback().play("strike", true, false);
    expect(started.filter((kind) => kind === "oscillator").length).toBeGreaterThan(0);
    expect(started.filter((kind) => kind === "noise").length).toBeGreaterThan(0);
  });

  it("caps simultaneous voices to avoid audio pileup", () => {
    const { FakeAudioContext, started } = makeFakeAudioContext();
    vi.stubGlobal("window", { AudioContext: FakeAudioContext });
    const feedback = new GameFeedback();
    for (let index = 0; index < 6; index += 1) feedback.play("big_hit", true, false);
    expect(started.length).toBeLessThanOrEqual(10);
  });
});
