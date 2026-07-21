export type PitchType = "four_seam" | "slider" | "curveball" | "changeup";
export type PitchIntensity = "controlled" | "normal" | "max_effort";
export type PitchOutcome =
  | "ball"
  | "called_strike"
  | "swinging_strike"
  | "foul"
  | "in_play_out"
  | "single"
  | "double"
  | "home_run";

export interface PitchZone {
  row: number;
  column: number;
}

export interface PitcherSnapshot {
  id: string;
  name: string;
  stuff: number;
  command: number;
  movement: number;
  stamina: number;
}

export interface BatterSnapshot {
  id: string;
  name: string;
  contact: number;
  discipline: number;
  power: number;
}

export interface CountState {
  balls: number;
  strikes: number;
}

export interface SimulatePitchParams {
  seed: string;
  pitcher: PitcherSnapshot;
  batter: BatterSnapshot;
  count: CountState;
  fatigue: number;
  selection: {
    pitchType: PitchType;
    zone: PitchZone;
    intensity: PitchIntensity;
  };
}

export interface PitchResolvedEvent {
  eventType: "pitch_resolved";
  seed: string;
  nextSeed: string;
  outcome: PitchOutcome;
  wasInZone: boolean;
  batterSwung: boolean;
  executionScore: number;
  contactQuality?: number;
  reasonCodes: ReadonlyArray<string>;
  eventHash: string;
}

export interface PitchDecisionSnapshot {
  outcome: PitchOutcome;
  wasInZone: boolean;
  batterSwung: boolean;
  executionScore: number;
  contactQuality?: number;
  shortFeedback: string;
  detailFeedback: string;
  accessibilitySummary: string;
}

export interface SimulatePitchResult {
  revision: number;
  events: ReadonlyArray<PitchResolvedEvent>;
  snapshot: PitchDecisionSnapshot;
}

export interface HealthResult {
  status: "ok";
  protocolVersion: string;
  coreVersion: string;
}
