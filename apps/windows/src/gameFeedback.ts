import type { ExtendedPitchOutcome, PitchKernelResult } from "./simulationTypes";

export type GameFeedbackCue = "ball" | "strike" | "strikeout" | "contact" | "big_hit" | "progress" | "growth" | "milestone";

export function feedbackCueForResult(result: PitchKernelResult): GameFeedbackCue {
  // The kernel may report `triple`/`hit_by_pitch`, which are not in the base `PitchOutcome` union.
  const outcome = result.snapshot.outcome as ExtendedPitchOutcome;
  if (result.snapshot.result === "strikeout") return "strikeout";
  // A hit-by-pitch is a quiet free base — the same low-key cue as a ball.
  if (outcome === "hit_by_pitch") return "ball";
  if (result.snapshot.result === "hit" || outcome === "home_run" || outcome === "double" || outcome === "triple") return "big_hit";
  if (outcome === "called_strike" || outcome === "swinging_strike") return "strike";
  if (outcome === "foul" || outcome === "in_play_out" || outcome === "single") return "contact";
  return "ball";
}

const MASTER_GAIN = 0.26;
const MAX_ACTIVE_VOICES = 10;

interface TonePart {
  frequency: number;
  endFrequency?: number;
  duration: number;
  type: OscillatorType;
  gain: number;
  delay?: number;
  detune?: number;
}

interface NoisePart {
  duration: number;
  gain: number;
  delay?: number;
  filterType: BiquadFilterType;
  filterFrequency: number;
  filterQ?: number;
  attack?: number;
  fade?: "burst" | "swell";
}

interface CueRecipe {
  tones: ReadonlyArray<TonePart>;
  noises: ReadonlyArray<NoisePart>;
}

// 절차 합성 레시피: 미트 팡 = 저역 thump + 고역 노이즈 버스트, 배트 크랙 = 밴드패스 임펄스 + 바디 노크,
// 관중 = 저역 통과 노이즈 스웰. 라이선스 자산 없이 손맛을 만드는 게 목적이다.
const RECIPES: Record<GameFeedbackCue, CueRecipe> = {
  ball: {
    tones: [{ frequency: 150, endFrequency: 96, duration: 0.09, type: "sine", gain: 0.5 }],
    noises: [{ duration: 0.05, gain: 0.18, filterType: "highpass", filterFrequency: 2400, fade: "burst" }],
  },
  strike: {
    tones: [{ frequency: 170, endFrequency: 92, duration: 0.11, type: "sine", gain: 0.72 }],
    noises: [
      { duration: 0.06, gain: 0.42, filterType: "highpass", filterFrequency: 2000, fade: "burst" },
      { duration: 0.045, gain: 0.24, filterType: "bandpass", filterFrequency: 900, filterQ: 1.4, fade: "burst" },
    ],
  },
  strikeout: {
    tones: [
      { frequency: 175, endFrequency: 90, duration: 0.12, type: "sine", gain: 0.78 },
      { frequency: 392, duration: 0.09, type: "triangle", gain: 0.3, delay: 0.16 },
      { frequency: 587, duration: 0.16, type: "sine", gain: 0.34, delay: 0.24 },
    ],
    noises: [
      { duration: 0.06, gain: 0.46, filterType: "highpass", filterFrequency: 1900, fade: "burst" },
      { duration: 1.15, gain: 0.2, filterType: "lowpass", filterFrequency: 950, attack: 0.3, fade: "swell", delay: 0.1 },
    ],
  },
  contact: {
    tones: [{ frequency: 185, endFrequency: 120, duration: 0.07, type: "triangle", gain: 0.5 }],
    noises: [
      { duration: 0.045, gain: 0.5, filterType: "bandpass", filterFrequency: 1500, filterQ: 1.1, fade: "burst" },
      { duration: 0.03, gain: 0.3, filterType: "highpass", filterFrequency: 3200, fade: "burst" },
    ],
  },
  big_hit: {
    tones: [{ frequency: 205, endFrequency: 125, duration: 0.09, type: "triangle", gain: 0.62 }],
    noises: [
      { duration: 0.055, gain: 0.66, filterType: "bandpass", filterFrequency: 1350, filterQ: 0.9, fade: "burst" },
      { duration: 0.04, gain: 0.4, filterType: "highpass", filterFrequency: 2800, fade: "burst" },
      { duration: 1.9, gain: 0.3, filterType: "lowpass", filterFrequency: 1100, attack: 0.5, fade: "swell", delay: 0.12 },
    ],
  },
  progress: {
    tones: [
      { frequency: 294, duration: 0.08, type: "sine", gain: 0.3 },
      { frequency: 370, duration: 0.12, type: "sine", gain: 0.3, delay: 0.07, detune: 6 },
    ],
    noises: [],
  },
  growth: {
    tones: [
      { frequency: 330, duration: 0.09, type: "triangle", gain: 0.32 },
      { frequency: 440, duration: 0.09, type: "triangle", gain: 0.32, delay: 0.08, detune: 5 },
      { frequency: 554, duration: 0.11, type: "sine", gain: 0.34, delay: 0.16, detune: -5 },
      { frequency: 659, duration: 0.24, type: "sine", gain: 0.36, delay: 0.24, detune: 6 },
    ],
    noises: [],
  },
  milestone: {
    tones: [
      { frequency: 262, duration: 0.1, type: "triangle", gain: 0.34 },
      { frequency: 330, duration: 0.1, type: "triangle", gain: 0.3, delay: 0.09, detune: -6 },
      { frequency: 392, duration: 0.12, type: "triangle", gain: 0.34, delay: 0.18, detune: 5 },
      { frequency: 523, duration: 0.3, type: "sine", gain: 0.4, delay: 0.27, detune: 7 },
    ],
    noises: [
      { duration: 1.6, gain: 0.24, filterType: "lowpass", filterFrequency: 1000, attack: 0.45, fade: "swell", delay: 0.2 },
    ],
  },
};

export class GameFeedback {
  private context?: AudioContext;
  private masterGain?: GainNode;
  private noiseBuffer?: AudioBuffer;
  private activeVoices = 0;

  play(cue: GameFeedbackCue, soundEnabled: boolean, hapticsEnabled: boolean) {
    if (hapticsEnabled && typeof navigator.vibrate === "function") {
      const pattern = cue === "growth" ? [22, 28, 22, 28, 75]
        : cue === "big_hit" || cue === "milestone" ? [35, 35, 70] : cue === "strikeout" ? [25, 25, 45] : [18];
      navigator.vibrate(pattern);
    }
    if (!soundEnabled) return;
    const AudioContextClass = window.AudioContext;
    if (!AudioContextClass) return;
    if (!this.context) {
      this.context = new AudioContextClass();
      this.masterGain = this.context.createGain();
      this.masterGain.gain.setValueAtTime(MASTER_GAIN, this.context.currentTime);
      this.masterGain.connect(this.context.destination);
    }
    void this.context.resume();
    const recipe = RECIPES[cue];
    const now = this.context.currentTime;
    for (const tone of recipe.tones) this.playTone(tone, now);
    for (const noise of recipe.noises) this.playNoise(noise, now);
  }

  private acquireVoice(): boolean {
    if (this.activeVoices >= MAX_ACTIVE_VOICES) return false;
    this.activeVoices += 1;
    return true;
  }

  private playTone(part: TonePart, now: number) {
    const context = this.context;
    const destination = this.masterGain;
    if (!context || !destination || !this.acquireVoice()) return;
    const start = now + (part.delay ?? 0);
    const oscillator = context.createOscillator();
    const gain = context.createGain();
    oscillator.type = part.type;
    oscillator.frequency.setValueAtTime(part.frequency, start);
    if (part.endFrequency) oscillator.frequency.exponentialRampToValueAtTime(part.endFrequency, start + part.duration);
    if (part.detune && oscillator.detune) oscillator.detune.setValueAtTime(part.detune, start);
    gain.gain.setValueAtTime(0.0001, start);
    gain.gain.exponentialRampToValueAtTime(part.gain, start + 0.008);
    gain.gain.exponentialRampToValueAtTime(0.0001, start + part.duration);
    oscillator.connect(gain).connect(destination);
    oscillator.onended = () => { this.activeVoices = Math.max(0, this.activeVoices - 1); };
    oscillator.start(start);
    oscillator.stop(start + part.duration + 0.02);
  }

  private playNoise(part: NoisePart, now: number) {
    const context = this.context;
    const destination = this.masterGain;
    if (!context || !destination || !this.acquireVoice()) return;
    if (!this.noiseBuffer) {
      const length = Math.floor(context.sampleRate * 2);
      this.noiseBuffer = context.createBuffer(1, length, context.sampleRate);
      const channel = this.noiseBuffer.getChannelData(0);
      for (let index = 0; index < length; index += 1) channel[index] = Math.random() * 2 - 1;
    }
    const start = now + (part.delay ?? 0);
    const source = context.createBufferSource();
    source.buffer = this.noiseBuffer;
    source.loop = true;
    const filter = context.createBiquadFilter();
    filter.type = part.filterType;
    filter.frequency.setValueAtTime(part.filterFrequency, start);
    if (part.filterQ) filter.Q.setValueAtTime(part.filterQ, start);
    const gain = context.createGain();
    if (part.fade === "swell") {
      const attack = part.attack ?? 0.3;
      gain.gain.setValueAtTime(0.0001, start);
      gain.gain.exponentialRampToValueAtTime(part.gain, start + attack);
      gain.gain.exponentialRampToValueAtTime(0.0001, start + part.duration);
    } else {
      gain.gain.setValueAtTime(part.gain, start);
      gain.gain.exponentialRampToValueAtTime(0.0001, start + part.duration);
    }
    source.connect(filter).connect(gain).connect(destination);
    source.onended = () => { this.activeVoices = Math.max(0, this.activeVoices - 1); };
    source.start(start);
    source.stop(start + part.duration + 0.03);
  }
}
