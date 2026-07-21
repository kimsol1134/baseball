interface RPCErrorPayload {
  code: number;
  message: string;
  data?: unknown;
}

export interface RPCRequest<TParams> {
  jsonrpc: "2.0";
  id: string;
  method: string;
  params?: TParams;
}

export interface RPCResponse<TResult> {
  jsonrpc: "2.0";
  id: string;
  result?: TResult;
  error?: RPCErrorPayload;
}

let requestSequence = 0;

export function createRPCRequest<TParams>(
  method: string,
  params?: TParams,
): RPCRequest<TParams> {
  requestSequence += 1;
  return {
    jsonrpc: "2.0",
    id: `desktop-${requestSequence}`,
    method,
    ...(params === undefined ? {} : { params }),
  };
}

export function parseRPCResponse<TResult>(value: string): TResult {
  const normalized = value.trim().split("\n").at(-1);
  if (!normalized) {
    throw new Error("시뮬레이션 코어가 빈 응답을 반환했습니다.");
  }

  let response: RPCResponse<TResult>;
  try {
    response = JSON.parse(normalized) as RPCResponse<TResult>;
  } catch {
    throw new Error("시뮬레이션 코어의 응답을 읽을 수 없습니다.");
  }

  if (response.jsonrpc !== "2.0") {
    throw new Error("지원하지 않는 시뮬레이션 프로토콜입니다.");
  }
  if (response.error) {
    const detail =
      typeof response.error.data === "string" ? ` ${response.error.data}` : "";
    throw new Error(`${response.error.message}${detail}`);
  }
  if (response.result === undefined) {
    throw new Error("시뮬레이션 결과가 없습니다.");
  }

  return response.result;
}

