import { describe, expect, it } from "vitest";
import { coreRecoveryMessage } from "./coreRecoveryMessage";

describe("core recovery message", () => {
  it("localizes common network and timeout failures", () => {
    expect(coreRecoveryMessage("Failed to fetch")).toContain("연결하지 못했습니다");
    expect(coreRecoveryMessage("connect ECONNREFUSED 127.0.0.1:8787")).toContain("연결하지 못했습니다");
    expect(coreRecoveryMessage("simulation sidecar timed out")).toContain("시간이 초과됐습니다");
  });

  it("does not expose internal paths or unknown English errors", () => {
    const pathFailure = coreRecoveryMessage("Error: /Users/name/game/simulation-sidecar failed");
    expect(pathFailure).toBe("경기 데이터를 불러오지 못했습니다. 다시 연결해 주세요.");
    expect(pathFailure).not.toContain("/Users");
  });

  it("keeps already safe Korean guidance", () => {
    expect(coreRecoveryMessage("경기 데이터 연결이 잠시 불안정합니다.")).toBe("경기 데이터 연결이 잠시 불안정합니다.");
  });
});
