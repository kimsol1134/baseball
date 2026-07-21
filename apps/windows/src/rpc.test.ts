import { describe, expect, it } from "vitest";
import { createRPCRequest, parseRPCResponse } from "./rpc";

describe("JSON-RPC client", () => {
  it("creates a JSON-RPC 2.0 request", () => {
    const request = createRPCRequest("health");

    expect(request.jsonrpc).toBe("2.0");
    expect(request.method).toBe("health");
    expect(request.id).toMatch(/^desktop-\d+$/);
  });

  it("returns a successful result", () => {
    const result = parseRPCResponse<{ status: string }>(
      '{"id":"1","jsonrpc":"2.0","result":{"status":"ok"}}',
    );

    expect(result).toEqual({ status: "ok" });
  });

  it("surfaces protocol errors", () => {
    expect(() =>
      parseRPCResponse(
        '{"id":"1","jsonrpc":"2.0","error":{"code":-32602,"message":"Invalid params","data":"bad zone"}}',
      ),
    ).toThrow("Invalid params bad zone");
  });

  it("reads the final complete line from process output", () => {
    const result = parseRPCResponse<{ status: string }>(
      'debug line\n{"id":"1","jsonrpc":"2.0","result":{"status":"ok"}}\n',
    );

    expect(result.status).toBe("ok");
  });
});

