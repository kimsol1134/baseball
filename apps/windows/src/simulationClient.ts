import { invoke } from "@tauri-apps/api/core";
import { createRPCRequest, parseRPCResponse } from "./rpc";
import type {
  ChooseAwakeningParams,
  ChooseCareerAwakeningParams,
  ChooseSchoolParams,
  ChooseRelationshipParams,
  CommitTrainingParams,
  CommitCareerTrainingParams,
  CareerStateParams,
  FinalizeScoutingParams,
  HealthResult,
  HighSchoolCareerResult,
  PitchKernelResult,
  PitcherLabResult,
  PitcherLabStateParams,
  PitchPreparation,
  PitcherPresetSnapshot,
  PreparePitchParams,
  RecordImportantInningParams,
  RecordCareerGameParams,
  ResolveCareerRelationshipParams,
  SelectLegacyParams,
  SelectCareerLegacyParams,
  SimulatePitchResult,
  SimulatePitchParams,
  StartPitcherLabParams,
  StartHighSchoolCareerParams,
  SubmitPitchParams,
  ProCareerResult,
  StartProCareerParams,
  ProStateParams,
  PlanProWeekParams,
  ResolveProGameParams,
  ProOffseasonParams,
} from "./simulationTypes";

async function executeRPC<TResult, TParams>(
  method: string,
  params?: TParams,
): Promise<TResult> {
  const request = createRPCRequest(method, params);
  const serializedRequest = JSON.stringify(request);
  const output = isTauriRuntime()
    ? await invoke<string>("execute_core", { request: serializedRequest })
    : await executeWebRPC(serializedRequest);

  return parseRPCResponse<TResult>(output);
}

function isTauriRuntime(): boolean {
  return typeof window === "undefined" || "__TAURI_INTERNALS__" in window;
}

function webCoreEndpoint(): string {
  const configuredOrigin = import.meta.env.VITE_CORE_API_URL?.replace(/\/$/, "") ?? "";
  return `${configuredOrigin}/api/core`;
}

async function executeWebRPC(request: string): Promise<string> {
  const response = await fetch(webCoreEndpoint(), {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: request,
  });
  const output = await response.text();
  if (!response.ok) {
    try {
      const payload = JSON.parse(output) as { message?: string };
      throw new Error(payload.message ?? `게임 서버 응답 오류 (${response.status})`);
    } catch (caught) {
      if (caught instanceof Error && !caught.message.startsWith("Unexpected")) throw caught;
      throw new Error(`게임 서버 응답 오류 (${response.status})`);
    }
  }
  return output;
}

export function checkCoreHealth(): Promise<HealthResult> {
  return executeRPC<HealthResult, undefined>("health");
}

export function listPitcherPresets(): Promise<ReadonlyArray<PitcherPresetSnapshot>> {
  return executeRPC<ReadonlyArray<PitcherPresetSnapshot>, undefined>("listPitcherPresets");
}

export function simulatePitch(
  params: SimulatePitchParams,
): Promise<SimulatePitchResult> {
  return executeRPC<SimulatePitchResult, SimulatePitchParams>(
    "simulatePitch",
    params,
  );
}

export function preparePitch(params: PreparePitchParams): Promise<PitchPreparation> {
  return executeRPC<PitchPreparation, PreparePitchParams>("preparePitch", params);
}

export function submitPitch(params: SubmitPitchParams): Promise<PitchKernelResult> {
  return executeRPC<PitchKernelResult, SubmitPitchParams>("submitPitch", params);
}

export function startPitcherLab(params: StartPitcherLabParams): Promise<PitcherLabResult> {
  return executeRPC<PitcherLabResult, StartPitcherLabParams>("startPitcherLab", params);
}

export function commitTraining(params: CommitTrainingParams): Promise<PitcherLabResult> {
  return executeRPC<PitcherLabResult, CommitTrainingParams>("commitTraining", params);
}

export function recordImportantInning(params: RecordImportantInningParams): Promise<PitcherLabResult> {
  return executeRPC<PitcherLabResult, RecordImportantInningParams>("recordImportantInning", params);
}

export function chooseRelationship(params: ChooseRelationshipParams): Promise<PitcherLabResult> {
  return executeRPC<PitcherLabResult, ChooseRelationshipParams>("chooseRelationship", params);
}

export function chooseAwakening(params: ChooseAwakeningParams): Promise<PitcherLabResult> {
  return executeRPC<PitcherLabResult, ChooseAwakeningParams>("chooseAwakening", params);
}

export function finalizeScouting(params: FinalizeScoutingParams): Promise<PitcherLabResult> {
  return executeRPC<PitcherLabResult, FinalizeScoutingParams>("finalizeScouting", params);
}

export function normalizePitcherLabBalance(params: PitcherLabStateParams): Promise<PitcherLabResult> {
  return executeRPC<PitcherLabResult, PitcherLabStateParams>("normalizePitcherLabBalance", params);
}

export function selectLegacy(params: SelectLegacyParams): Promise<PitcherLabResult> {
  return executeRPC<PitcherLabResult, SelectLegacyParams>("selectLegacy", params);
}

export function startHighSchoolCareer(params: StartHighSchoolCareerParams): Promise<HighSchoolCareerResult> {
  return executeRPC<HighSchoolCareerResult, StartHighSchoolCareerParams>("startHighSchoolCareer", params);
}

export function completeMiddleSchoolPrologue(params: CareerStateParams): Promise<HighSchoolCareerResult> {
  return executeRPC<HighSchoolCareerResult, CareerStateParams>("completeMiddleSchoolPrologue", params);
}

export function normalizeRegionalSchools(params: CareerStateParams): Promise<HighSchoolCareerResult> {
  return executeRPC<HighSchoolCareerResult, CareerStateParams>("normalizeRegionalSchools", params);
}

export function chooseSchool(params: ChooseSchoolParams): Promise<HighSchoolCareerResult> {
  return executeRPC<HighSchoolCareerResult, ChooseSchoolParams>("chooseSchool", params);
}

export function commitCareerTraining(params: CommitCareerTrainingParams): Promise<HighSchoolCareerResult> {
  return executeRPC<HighSchoolCareerResult, CommitCareerTrainingParams>("commitCareerTraining", params);
}

export function resolveCareerRelationship(params: ResolveCareerRelationshipParams): Promise<HighSchoolCareerResult> {
  return executeRPC<HighSchoolCareerResult, ResolveCareerRelationshipParams>("resolveCareerRelationship", params);
}

export function recordCareerGame(params: RecordCareerGameParams): Promise<HighSchoolCareerResult> {
  return executeRPC<HighSchoolCareerResult, RecordCareerGameParams>("recordCareerGame", params);
}

export function chooseCareerAwakening(params: ChooseCareerAwakeningParams): Promise<HighSchoolCareerResult> {
  return executeRPC<HighSchoolCareerResult, ChooseCareerAwakeningParams>("chooseCareerAwakening", params);
}

export function advanceCareerChapter(params: CareerStateParams): Promise<HighSchoolCareerResult> {
  return executeRPC<HighSchoolCareerResult, CareerStateParams>("advanceCareerChapter", params);
}

export function resolveDraft(params: CareerStateParams): Promise<HighSchoolCareerResult> {
  return executeRPC<HighSchoolCareerResult, CareerStateParams>("resolveDraft", params);
}

export function selectCareerLegacy(params: SelectCareerLegacyParams): Promise<HighSchoolCareerResult> {
  return executeRPC<HighSchoolCareerResult, SelectCareerLegacyParams>("selectCareerLegacy", params);
}

export function startProCareer(params: StartProCareerParams): Promise<ProCareerResult> {
  return executeRPC<ProCareerResult, StartProCareerParams>("startProCareer", params);
}
export function normalizeProCareerBalance(params: ProStateParams): Promise<ProCareerResult> {
  return executeRPC<ProCareerResult, ProStateParams>("normalizeProCareerBalance", params);
}
export function signProContract(params: ProStateParams): Promise<ProCareerResult> {
  return executeRPC<ProCareerResult, ProStateParams>("signProContract", params);
}
export function planProWeek(params: PlanProWeekParams): Promise<ProCareerResult> {
  return executeRPC<ProCareerResult, PlanProWeekParams>("planProWeek", params);
}
export function resolveProImportantGame(params: ResolveProGameParams): Promise<ProCareerResult> {
  return executeRPC<ProCareerResult, ResolveProGameParams>("resolveProImportantGame", params);
}
export function reviewProSeason(params: ProStateParams): Promise<ProCareerResult> {
  return executeRPC<ProCareerResult, ProStateParams>("reviewProSeason", params);
}
export function chooseProOffseason(params: ProOffseasonParams): Promise<ProCareerResult> {
  return executeRPC<ProCareerResult, ProOffseasonParams>("chooseProOffseason", params);
}
