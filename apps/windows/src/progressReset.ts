interface ResetStorage {
  readonly length: number;
  key(index: number): string | null;
  removeItem(key: string): void;
}

// 진행(자동 저장·커리어·랩·클라우드 미러)은 지우고, 사용자의 접근성·피드백·기록 동의 설정은 보존한다.
const PRESERVED_PREFIXES = ["baseball.a11y.", "baseball.feedback.", "baseball.analytics."];

export function progressKeys(storage: ResetStorage): string[] {
  const keys: string[] = [];
  for (let index = 0; index < storage.length; index += 1) {
    const key = storage.key(index);
    if (!key || !key.startsWith("baseball.")) continue;
    if (PRESERVED_PREFIXES.some((prefix) => key.startsWith(prefix))) continue;
    keys.push(key);
  }
  return keys;
}

/// 삭제한 키 수를 반환한다. 호출자는 이후 화면을 처음 상태로 다시 불러와야 한다.
export function resetAllProgress(storage: ResetStorage): number {
  const doomed = progressKeys(storage);
  for (const key of doomed) storage.removeItem(key);
  return doomed.length;
}
