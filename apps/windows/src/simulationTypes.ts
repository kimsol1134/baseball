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
export type FielderPosition =
  | "pitcher"
  | "catcher"
  | "first_base"
  | "second_base"
  | "third_base"
  | "shortstop"
  | "left_field"
  | "center_field"
  | "right_field";
export type HalfInning = "top" | "bottom";

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

export interface FielderSnapshot {
  id: string;
  name: string;
  position: FielderPosition;
  range: number;
  glove: number;
  arm: number;
}

export interface DefenseSnapshot {
  infield: number;
  outfield: number;
  arm: number;
  fielders?: ReadonlyArray<FielderSnapshot>;
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
  inningState?: InningStateSnapshot;
}

export interface InningStateSnapshot {
  inning: number;
  half: HalfInning;
  outs: number;
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
  fielderPosition?: FielderPosition;
  fielderName?: string;
  landingDistanceTenthsMeters?: number;
  hangTimeMilliseconds?: number;
  apexHeightTenthsMeters?: number;
  ballFlightSeries?: ReadonlyArray<number>;
  shortExplanation: string;
}

export interface StealAttemptSnapshot {
  fromBase: number;
  toBase: number;
  runnerSpeed: number;
  catcherArm: number;
  succeeded: boolean;
  shortExplanation: string;
}

export interface InningTransitionSnapshot {
  before: InningStateSnapshot;
  after: InningStateSnapshot;
  outsRecorded: number;
  doublePlayCompleted: boolean;
  inningEnded: boolean;
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
  flightTimeMilliseconds?: number;
  trajectoryControlX?: number;
  trajectoryControlY?: number;
  trajectorySeries?: ReadonlyArray<number>;
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
  stealAttempt?: StealAttemptSnapshot;
  inningTransition?: InningTransitionSnapshot;
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
  runnersBefore?: BaserunnerStateSnapshot;
  runnersAfter: BaserunnerStateSnapshot;
  runsScored: number;
  stealAttempt?: StealAttemptSnapshot;
  inningTransition?: InningTransitionSnapshot;
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

export type TrainingFocus =
  | "velocity"
  | "command"
  | "breaking_ball"
  | "stamina"
  | "recovery"
  | "game_planning";
export type TrainingIntensity = "light" | "standard" | "intensive";
export type TrainingReactionBand = "muted" | "steady" | "strong" | "breakthrough";
export type PitcherLabPhase =
  | "training"
  | "important_inning"
  | "relationship"
  | "awakening"
  | "scouting"
  | "reflection"
  | "completed";
export type RelationshipChoice = "trust_catcher" | "assert_own_plan";
export type AwakeningID =
  | "explosive_fastball"
  | "pinpoint_edge"
  | "disappearing_breaker"
  | "iron_arm"
  | "calm_under_pressure"
  | "battery_sync"
  | "rising_four_seam"
  | "sinker_tunnel"
  | "frozen_changeup"
  | "sweeping_slider"
  | "curveball_clock"
  | "repeatable_release"
  | "pickoff_rhythm"
  | "two_strike_plan"
  | "first_pitch_strike"
  | "traffic_controller"
  | "late_inning_reserve"
  | "scout_composure";
export type SoulDomain = "body" | "technique" | "game";
export type MemoryCardID =
  | "velocity_blueprint"
  | "fingertip_memory"
  | "catcher_notebook"
  | "rival_notebook"
  | "recovery_routine"
  | "pressure_rehearsal"
  | "first_pitch_map"
  | "two_strike_sequence"
  | "fatigue_diary"
  | "mechanics_video"
  | "school_playbook"
  | "coach_letter"
  | "draft_report"
  | "stadium_echo"
  | "team_first_promise"
  | "failure_scorebook"
  | "winter_program"
  | "bullpen_compass";
export type ScoutingGrade = "undrafted" | "follow" | "draftable" | "elite";

export interface PotentialRangeSnapshot {
  metric: string;
  current: number;
  lowerBound: number;
  upperBound: number;
  confidence: number;
}

export interface DevelopmentSignalsSnapshot {
  velocity: number;
  command: number;
  breakingBall: number;
  stamina: number;
  recovery: number;
  gamePlanning: number;
}

export interface TrainingSessionSnapshot {
  sessionNumber: number;
  focus: TrainingFocus;
  intensity: TrainingIntensity;
  reaction: TrainingReactionBand;
  signalGained: number;
  ratingPointsGained: number;
  readinessBefore: number;
  readinessAfter: number;
  fatigueBefore: number;
  fatigueAfter: number;
  observedClue: string;
  shortFeedback: string;
}

export interface ImportantInningReport {
  scenarioNumber: number;
  pitches: number;
  strikeouts: number;
  walks: number;
  runsAllowed: number;
  expectedDamage: number;
  actualDamage: number;
  recommendationAccepted: number;
}

export interface LabPerformanceSnapshot extends Omit<ImportantInningReport, "scenarioNumber"> {
  importantInningsCompleted: number;
}

export interface ScoutingEvaluationSnapshot {
  grade: ScoutingGrade;
  score: number;
  strengths: ReadonlyArray<string>;
  concerns: ReadonlyArray<string>;
  summary: string;
}

export interface LegacySelectionSnapshot {
  soulDomain: SoulDomain;
  memoryCard: MemoryCardID;
  soulPointsGranted: number;
  unlockedSchoolID: string;
  unlockedCoachID: string;
  summary: string;
}

export interface PitcherLabSnapshot {
  runID: string;
  revision: number;
  lifeNumber: number;
  presetID: string;
  phase: PitcherLabPhase;
  pitcher: PitcherSnapshot;
  trainingSessionsCompleted: number;
  relationshipEventsCompleted: number;
  selectedAwakenings: ReadonlyArray<AwakeningID>;
  awakeningOptions: ReadonlyArray<AwakeningID>;
  readiness: number;
  fatigue: number;
  catcherTrust: number;
  developmentSignals: DevelopmentSignalsSnapshot;
  potentialRanges: ReadonlyArray<PotentialRangeSnapshot>;
  performance: LabPerformanceSnapshot;
  lastTraining?: TrainingSessionSnapshot;
  scoutingEvaluation?: ScoutingEvaluationSnapshot;
  legacyOptions: ReadonlyArray<MemoryCardID>;
  legacySelection?: LegacySelectionSnapshot;
  stateCommitment: string;
}

export interface PitcherLabEvent {
  eventType: string;
  sequence: number;
  training?: TrainingSessionSnapshot;
  importantInning?: ImportantInningReport;
  relationshipChoice?: RelationshipChoice;
  awakening?: AwakeningID;
  scouting?: ScoutingEvaluationSnapshot;
  legacy?: LegacySelectionSnapshot;
  reasonCodes: ReadonlyArray<string>;
}

export interface PitcherLabResult {
  revision: number;
  nextSeed: string;
  events: ReadonlyArray<PitcherLabEvent>;
  snapshot: PitcherLabSnapshot;
  eventHash: string;
}

export interface StartPitcherLabParams {
  seed: string;
  presetID: string;
  lifeNumber: number;
  inheritedSoulPoints: number;
  inheritedSoulDomain?: SoulDomain;
  inheritedMemory?: MemoryCardID;
  creationAllocation?: CreationAllocationSnapshot;
}

export interface CreationAllocationSnapshot {
  stuff: number;
  command: number;
  movement: number;
  stamina: number;
}

export type HighSchoolCareerPhase =
  | "prologue"
  | "school_selection"
  | "training"
  | "relationship"
  | "important_game"
  | "awakening"
  | "chapter_review"
  | "draft"
  | "legacy"
  | "completed";

export type SchoolID =
  | "hanbit_traditional"
  | "mirae_analytics"
  | "haedong_power"
  | "cheongam_development";

export type RelationshipResponse = "listen" | "explain" | "challenge";
export type DraftOutcome = "drafted" | "undrafted";
export type ThrowingHand = "right" | "left";
export type BodyType = "compact" | "balanced" | "tall";
export type DifficultyLevel = "relaxed" | "standard" | "challenging";
export type InterventionAssist = "full" | "standard" | "minimal";
export type KarmaID =
  | "unknown_land"
  | "stubborn_coach"
  | "single_weapon"
  | "genius_generation"
  | "erased_memory"
  | "no_last_chance";

export interface CareerDifficultySnapshot {
  careerHarshness: DifficultyLevel;
  informationClarity: DifficultyLevel;
  simulationDifficulty: DifficultyLevel;
  interventionAssist: InterventionAssist;
}

export interface PlayerIdentitySnapshot {
  name: string;
  throwingHand: ThrowingHand;
  bodyType: BodyType;
  region: string;
}

export interface SchoolSnapshot {
  id: SchoolID;
  name: string;
  philosophy: string;
  coachName: string;
  coachArchetype: string;
  catcherName: string;
  catcherArchetype: string;
  strength: TrainingFocus;
  tradeoff: string;
}

export interface RivalSnapshot {
  id: string;
  name: string;
  archetype: string;
  contact: number;
  discipline: number;
  power: number;
}

export interface CareerChapterSnapshot {
  number: number;
  title: string;
  schoolYear: number;
  season: string;
  theme: string;
}

export interface CareerPerformanceSnapshot {
  importantGamesCompleted: number;
  pitches: number;
  strikeouts: number;
  walks: number;
  runsAllowed: number;
  expectedDamage: number;
  actualDamage: number;
}

export interface ImportantGameScenarioContent {
  id: string;
  title: string;
  inning: number;
  outs: number;
  runners: BaserunnerStateSnapshot;
  leverage: number;
  narrative: string;
}

export interface CareerEventContent { id: string; title: string; category: string; summary: string }

export interface DraftTeamSnapshot {
  id: string;
  name: string;
  need: TrainingFocus;
  demand: number;
  developmentPlan: string;
  positionCompetitor: string;
  proCoach: string;
}

export interface DraftResultSnapshot {
  outcome: DraftOutcome;
  evaluationScore: number;
  projectedRange: string;
  team?: DraftTeamSnapshot;
  round?: number;
  overallPick?: number;
  signingBonus?: number;
  firstSeasonGoal?: string;
  summary: string;
}

export interface CareerTrainingSnapshot {
  number: number;
  focus: TrainingFocus;
  intensity: TrainingIntensity;
  growth: number;
  fatigueChange: number;
  feedback: string;
}

export interface HighSchoolCareerSnapshot {
  careerID: string;
  revision: number;
  lifeNumber: number;
  phase: HighSchoolCareerPhase;
  identity: PlayerIdentitySnapshot;
  difficulty: CareerDifficultySnapshot;
  karmas: ReadonlyArray<KarmaID>;
  legacyRewardPermille: number;
  memorySlots: number;
  pitcher: PitcherSnapshot;
  schoolOptions: ReadonlyArray<SchoolSnapshot>;
  school?: SchoolSnapshot;
  rival: RivalSnapshot;
  chapter: CareerChapterSnapshot;
  chapterTrainingCount: number;
  totalTrainingsCompleted: number;
  milestoneIndex: number;
  relationshipsCompleted: number;
  relationshipTrust: number;
  selectedAwakenings: ReadonlyArray<AwakeningID>;
  awakeningOptions: ReadonlyArray<AwakeningID>;
  fatigue: number;
  performance: CareerPerformanceSnapshot;
  currentGameScenario?: ImportantGameScenarioContent;
  currentRelationshipEvent?: CareerEventContent;
  lastTraining?: CareerTrainingSnapshot;
  news: ReadonlyArray<string>;
  fanInterest: number;
  draftResult?: DraftResultSnapshot;
  legacyOptions: ReadonlyArray<MemoryCardID>;
  selectedMemories: ReadonlyArray<MemoryCardID>;
  stateCommitment: string;
}

export interface HighSchoolCareerEvent {
  eventType: string;
  sequence: number;
  reasonCodes: ReadonlyArray<string>;
}

export interface HighSchoolCareerResult {
  revision: number;
  nextSeed: string;
  events: ReadonlyArray<HighSchoolCareerEvent>;
  snapshot: HighSchoolCareerSnapshot;
  eventHash: string;
}

export interface StartHighSchoolCareerParams {
  seed: string;
  presetID: string;
  lifeNumber: number;
  creationAllocation: CreationAllocationSnapshot;
  inheritedSoulPoints: number;
  inheritedSoulDomain?: SoulDomain;
  inheritedMemories: ReadonlyArray<MemoryCardID>;
  identity: PlayerIdentitySnapshot;
  difficulty: CareerDifficultySnapshot;
  karmas: ReadonlyArray<KarmaID>;
}

export interface ChooseSchoolParams {
  seed: string;
  state: HighSchoolCareerSnapshot;
  schoolID: SchoolID;
}

export interface CommitCareerTrainingParams {
  seed: string;
  state: HighSchoolCareerSnapshot;
  focus: TrainingFocus;
  intensity: TrainingIntensity;
}

export interface ResolveCareerRelationshipParams {
  seed: string;
  state: HighSchoolCareerSnapshot;
  response: RelationshipResponse;
}

export interface RecordCareerGameParams {
  seed: string;
  state: HighSchoolCareerSnapshot;
  report: ImportantInningReport;
}

export interface ChooseCareerAwakeningParams {
  seed: string;
  state: HighSchoolCareerSnapshot;
  awakening: AwakeningID;
}

export interface CareerStateParams {
  seed: string;
  state: HighSchoolCareerSnapshot;
}

export interface SelectCareerLegacyParams extends CareerStateParams {
  memoryCards: ReadonlyArray<MemoryCardID>;
}

export interface CommitTrainingParams {
  seed: string;
  state: PitcherLabSnapshot;
  focus: TrainingFocus;
  intensity: TrainingIntensity;
}

export interface RecordImportantInningParams {
  seed: string;
  state: PitcherLabSnapshot;
  report: ImportantInningReport;
}

export interface ChooseRelationshipParams {
  seed: string;
  state: PitcherLabSnapshot;
  choice: RelationshipChoice;
}

export interface ChooseAwakeningParams {
  seed: string;
  state: PitcherLabSnapshot;
  awakening: AwakeningID;
}

export interface FinalizeScoutingParams {
  seed: string;
  state: PitcherLabSnapshot;
}

export interface SelectLegacyParams {
  seed: string;
  state: PitcherLabSnapshot;
  soulDomain: SoulDomain;
  memoryCard: MemoryCardID;
}

export type EntitlementStatus = "locked" | "active";
export type EntitlementSource = "purchase" | "restore" | "offline_cache" | "development";
export interface ProEntitlementSnapshot { productID: string; status: EntitlementStatus; source: EntitlementSource; verifiedAt: string; offlineValidUntil?: string }
export type ProCareerPhase = "contract_offer" | "weekly_plan" | "important_game" | "season_review" | "offseason_decision" | "retirement_decision" | "completed";
export type ProLevel = "minor" | "major";
export type ProRole = "starter" | "long_relief" | "setup" | "closer";
export type ProWeekPlan = "develop_weapon" | "refine_command" | "build_stamina" | "recover" | "earn_trust";
export type OffseasonDecision = "continue" | "military_service" | "free_agency" | "retire";
export interface ProSeasonStats { season: number; teamID: string; games: number; starts: number; inningsOuts: number; strikeouts: number; walks: number; runsAllowed: number; wins: number; saves: number }
export interface ProContractSnapshot { yearsRemaining: number; annualSalary: number; rolePromise: ProRole }
export interface ProCareerSnapshot {
  proCareerID: string; revision: number; phase: ProCareerPhase; identity: PlayerIdentitySnapshot; pitcher: PitcherSnapshot;
  team: DraftTeamSnapshot; entitlement: ProEntitlementSnapshot; age: number; season: number; week: number; level: ProLevel; role: ProRole;
  managerTrust: number; catcherTrust: number; fatigue: number; injuryWeeks: number; serviceYears: number; militaryCompleted: boolean;
  contract?: ProContractSnapshot; currentStats: ProSeasonStats; careerStats: ReadonlyArray<ProSeasonStats>; awards: ReadonlyArray<string>;
  milestones: ReadonlyArray<string>; news: ReadonlyArray<string>; hallOfFameScore?: number; commitment: string;
}
export interface ProCareerResult { snapshot: ProCareerSnapshot; nextSeed: string; events: ReadonlyArray<string> }
export interface StartProCareerParams { seed: string; identity: PlayerIdentitySnapshot; pitcher: PitcherSnapshot; draftResult: DraftResultSnapshot; entitlement: ProEntitlementSnapshot }
export interface ProStateParams { seed: string; state: ProCareerSnapshot }
export interface PlanProWeekParams extends ProStateParams { plan: ProWeekPlan }
export interface ResolveProGameParams extends ProStateParams { report: ImportantInningReport }
export interface ProOffseasonParams extends ProStateParams { decision: OffseasonDecision }
