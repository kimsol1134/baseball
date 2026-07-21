import { invoke } from "@tauri-apps/api/core";
import { createRPCRequest, parseRPCResponse } from "./rpc";
import type {
  HealthResult,
  SimulatePitchResult,
  SimulatePitchParams,
} from "./simulationTypes";

async function executeRPC<TResult, TParams>(
  method: string,
  params?: TParams,
): Promise<TResult> {
  const request = createRPCRequest(method, params);
  const output = await invoke<string>("execute_core", {
    request: JSON.stringify(request),
  });

  return parseRPCResponse<TResult>(output);
}

export function checkCoreHealth(): Promise<HealthResult> {
  return executeRPC<HealthResult, undefined>("health");
}

export function simulatePitch(
  params: SimulatePitchParams,
): Promise<SimulatePitchResult> {
  return executeRPC<SimulatePitchResult, SimulatePitchParams>(
    "simulatePitch",
    params,
  );
}
