import type { GameStateSnapshot, PitchKernelResult } from "./simulationTypes";

export function gameStateForReplay(
  current: GameStateSnapshot,
  result: PitchKernelResult | undefined,
  replayVisible: boolean,
): GameStateSnapshot {
  if (!replayVisible || !result) return current;
  return {
    ...current,
    inningState: result.snapshot.inningTransition?.before ?? current.inningState,
    runners: result.snapshot.runnersBefore ?? current.runners,
    runsAllowed: Math.max(0, current.runsAllowed - result.snapshot.runsScored),
  };
}

export function pitcherCondition(fatigue: number) {
  if (fatigue >= 80) return "휴식 필요";
  if (fatigue >= 60) return "피로 주의";
  if (fatigue >= 35) return "투구 가능";
  return "몸 상태 좋음";
}
