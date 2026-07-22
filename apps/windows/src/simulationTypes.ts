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
  pitchProfiles?: ReadonlyArray<PitchProfileSnapshot>;
}

export type PitchUsageRole = "primary" | "secondary" | "development";

export interface PitchProfileSnapshot {
  pitchType: PitchType;
  role: PitchUsageRole;
  velocityTenthsKPH: number;
  control: number;
  command: number;
  movement: number;
  whiff: number;
  weakContact: number;
  fatigueCost: number;
}

export interface PitcherPresetSnapshot {
  id: string;
  name: string;
  tagline: string;
  strengths: ReadonlyArray<string>;
  tradeoff: string;
  pitcher: PitcherSnapshot;
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

export type ZoneIntent = "strike" | "edge" | "chase";
export type SelectionQuality = "poor" | "risky" | "good" | "excellent";
export type PlateAppearanceResult = "strikeout" | "walk" | "in_play_out" | "hit";
export type RivalAdaptationBand = "no_data" | "watching" | "learning" | "locked_on";
export type FieldingSector = "infield" | "outfield" | "fence";
export type DefenseImpact = "helped_pitcher" | "neutral" | "hurt_pitcher";
export type AnalysisConfidenceBand = "low" | "developing" | "reliable";

export interface PitchCall {
  pitchType: PitchType;
  zone: PitchZone;
  zoneIntent: ZoneIntent;
  intensity: PitchIntensity;
}

export interface BatterScoutingSnapshot {
  hotZone: PitchZone;
  coldZone: PitchZone;
  pitchStrength: PitchType;
  pitchWeakness: PitchType;
  chaseTendency: number;
}

export interface PlateAppearanceContext {
  plateAppearanceID: string;
  revision: number;
  inning: number;
  outs: number;
  balls: number;
  strikes: number;
  pitchNumber: number;
  scoreDifferential: number;
  leverage: number;
  fatigue: number;
}

export interface RivalPitchObservation {
  pitchType: PitchType;
  zone: PitchZone;
  zoneIntent: ZoneIntent;
  balls: number;
  strikes: number;
  outcome: PitchOutcome;
}

export interface RivalMemorySnapshot {
  matchupID: string;
  revision: number;
  plateAppearancesSeen: number;
  totalPitchesSeen: number;
  recentObservations: ReadonlyArray<RivalPitchObservation>;
}

export interface RivalAdaptationSnapshot {
  level: number;
  band: RivalAdaptationBand;
  evidenceCount: number;
  detectedPitch?: PitchType;
  detectedZone?: PitchZone;
  confidence: number;
  warning: string;
}

export interface DefenseSnapshot {
  infield: number;
  outfield: number;
  arm: number;
}

export interface ParkSnapshot {
  id: string;
  name: string;
  hitFactor: number;
  homeRunFactor: number;
}

export interface BaserunnerStateSnapshot {
  firstOccupied: boolean;
  secondOccupied: boolean;
  thirdOccupied: boolean;
  leadRunnerSpeed: number;
}

export interface GameStateSnapshot {
  defense: DefenseSnapshot;
  park: ParkSnapshot;
  runners: BaserunnerStateSnapshot;
  runsAllowed: number;
}

export interface FieldingResolutionSnapshot {
  neutralOutcome: PitchOutcome;
  finalOutcome: PitchOutcome;
  sector: FieldingSector;
  difficulty: number;
  defenseRating: number;
  defenseAdjustment: number;
  parkAdjustment: number;
  impact: DefenseImpact;
  shortExplanation: string;
}

export interface BaserunnerAdvanceSnapshot {
  before: BaserunnerStateSnapshot;
  after: BaserunnerStateSnapshot;
  runsScored: number;
  shortExplanation: string;
}

export interface PitchAnalysisEntry {
  pitchType: PitchType;
  wasInZone: boolean;
  batterSwung: boolean;
  outcome: PitchOutcome;
  selectionQuality: SelectionQuality;
  executionQuality: number;
  contactQuality?: number;
  expectedDamage: number;
  actualDamage: number;
  recommendationAccepted: boolean;
}

export interface GameLogSnapshot {
  gameID: string;
  revision: number;
  totalPitches: number;
  entries: ReadonlyArray<PitchAnalysisEntry>;
}

export interface PitchAnalysisBreakdown {
  pitchType: PitchType;
  pitches: number;
  zoneRate: number;
  whiffRate: number;
  hardHitRate: number;
  expectedDamage: number;
}

export interface PostgameAnalysisSnapshot {
  sampleSize: number;
  confidence: AnalysisConfidenceBand;
  zoneRate: number;
  whiffRate: number;
  hardHitRate: number;
  averageSelectionQuality: number;
  averageExecutionQuality: number;
  expectedDamage: number;
  actualDamage: number;
  pitchBreakdowns: ReadonlyArray<PitchAnalysisBreakdown>;
  patternWarning: string;
  growthSignal: string;
}

export interface PreparePitchParams {
  seed: string;
  pitcher: PitcherSnapshot;
  batter: BatterSnapshot;
  scouting: BatterScoutingSnapshot;
  context: PlateAppearanceContext;
  rivalMemory?: RivalMemorySnapshot;
  gameState?: GameStateSnapshot;
  gameLog?: GameLogSnapshot;
}

export interface SubmitPitchParams extends PreparePitchParams {
  preparationToken: string;
  call: PitchCall;
}

export interface CatcherRecommendationSnapshot {
  call: PitchCall;
  confidence: number;
  reasonCodes: ReadonlyArray<string>;
  shortReason: string;
}

export interface PitchPreparation {
  seed: string;
  revision: number;
  pitchNumber: number;
  preparationToken: string;
  planCommitment: string;
  primaryRecommendation: CatcherRecommendationSnapshot;
  alternativeRecommendation: CatcherRecommendationSnapshot;
  rivalAdaptation: RivalAdaptationSnapshot;
}

export interface PitchExecution {
  targetX: number;
  targetY: number;
  actualX: number;
  actualY: number;
  velocityTenthsKPH: number;
  horizontalBreakTenthsCM: number;
  verticalBreakTenthsCM: number;
  executionQuality: number;
}

export interface BattedBall {
  exitVelocityTenthsKPH: number;
  launchAngleTenthsDegrees: number;
  directionTenthsDegrees: number;
  contactQuality: number;
}

export interface PitchKernelEvent {
  eventType: string;
  sequence: number;
  planCommitment?: string;
  outcome?: PitchOutcome;
  reasonCodes: ReadonlyArray<string>;
  rivalAdaptation?: RivalAdaptationSnapshot;
  fieldingResolution?: FieldingResolutionSnapshot;
  baserunnerAdvance?: BaserunnerAdvanceSnapshot;
  postgameAnalysis?: PostgameAnalysisSnapshot;
}

export interface PlateAppearanceSnapshot {
  revision: number;
  balls: number;
  strikes: number;
  pitchNumber: number;
  ended: boolean;
  result?: PlateAppearanceResult;
  outcome: PitchOutcome;
  selectionQuality: SelectionQuality;
  recommendationAccepted: boolean;
  fatigueAfterPitch: number;
  execution: PitchExecution;
  battedBall?: BattedBall;
  fieldingResolution?: FieldingResolutionSnapshot;
  runnersAfter: BaserunnerStateSnapshot;
  runsScored: number;
  reasonCodes: ReadonlyArray<string>;
  shortFeedback: string;
  detailFeedback: string;
  accessibilitySummary: string;
}

export interface PitchKernelResult {
  revision: number;
  nextSeed: string;
  events: ReadonlyArray<PitchKernelEvent>;
  snapshot: PlateAppearanceSnapshot;
  nextPreparation?: PitchPreparation;
  rivalMemory: RivalMemorySnapshot;
  rivalAdaptation: RivalAdaptationSnapshot;
  gameState: GameStateSnapshot;
  gameLog: GameLogSnapshot;
  postgameAnalysis: PostgameAnalysisSnapshot;
  eventHash: string;
}
