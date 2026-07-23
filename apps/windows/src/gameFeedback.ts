import type { PitchKernelResult } from "./simulationTypes";

export type GameFeedbackCue = "ball" | "strike" | "strikeout" | "contact" | "big_hit" | "progress" | "growth" | "milestone";

export function feedbackCueForResult(result: PitchKernelResult): GameFeedbackCue {
  if (result.snapshot.result === "strikeout") return "strikeout";
  if (result.snapshot.result === "hit" || result.snapshot.outcome === "home_run" || result.snapshot.outcome === "double") return "big_hit";
  if (result.snapshot.outcome === "called_strike" || result.snapshot.outcome === "swinging_strike") return "strike";
  if (result.snapshot.outcome === "foul" || result.snapshot.outcome === "in_play_out" || result.snapshot.outcome === "single") return "contact";
  return "ball";
}

export class GameFeedback {
  private context?: AudioContext;

  play(cue: GameFeedbackCue, soundEnabled: boolean, hapticsEnabled: boolean) {
    if (hapticsEnabled && typeof navigator.vibrate === "function") {
      const pattern = cue === "growth" ? [22, 28, 22, 28, 75]
        : cue === "big_hit" || cue === "milestone" ? [35, 35, 70] : cue === "strikeout" ? [25, 25, 45] : [18];
      navigator.vibrate(pattern);
    }
    if (!soundEnabled) return;
    const AudioContextClass = window.AudioContext;
    if (!AudioContextClass) return;
    this.context ??= new AudioContextClass();
    void this.context.resume();
    const now = this.context.currentTime;
    const notes: Record<GameFeedbackCue, ReadonlyArray<[number, number, OscillatorType]>> = {
      ball: [[145, 0.07, "sine"]],
      strike: [[330, 0.06, "square"], [440, 0.08, "sine"]],
      strikeout: [[330, 0.06, "square"], [494, 0.07, "square"], [659, 0.14, "sine"]],
      contact: [[110, 0.05, "triangle"], [220, 0.08, "square"]],
      big_hit: [[196, 0.07, "square"], [392, 0.09, "triangle"], [587, 0.16, "sine"]],
      progress: [[294, 0.06, "sine"], [370, 0.1, "sine"]],
      growth: [[330, 0.07, "triangle"], [440, 0.08, "triangle"], [554, 0.1, "sine"], [659, 0.2, "sine"]],
      milestone: [[262, 0.08, "triangle"], [392, 0.1, "triangle"], [523, 0.18, "sine"]],
    };
    notes[cue].forEach(([frequency, duration, type], index) => {
      const oscillator = this.context!.createOscillator();
      const gain = this.context!.createGain();
      const start = now + index * 0.055;
      oscillator.type = type;
      oscillator.frequency.setValueAtTime(frequency, start);
      gain.gain.setValueAtTime(0.0001, start);
      gain.gain.exponentialRampToValueAtTime(0.07, start + 0.008);
      gain.gain.exponentialRampToValueAtTime(0.0001, start + duration);
      oscillator.connect(gain).connect(this.context!.destination);
      oscillator.start(start);
      oscillator.stop(start + duration + 0.01);
    });
  }
}
