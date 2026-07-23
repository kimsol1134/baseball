const INTERNAL_DETAIL = /(?:\b(?:error|exception|stack|errno)\b|[A-Za-z]:\\|\/(?:Users|home|tmp|var)\/|\.swift:\d+|\.rs:\d+)/i;

export function coreRecoveryMessage(message: string): string {
  const normalized = message.trim().toLowerCase();
  if (/(?:timed?\s*out|timeout|시간\s*초과)/i.test(normalized)) {
    return "경기 데이터 응답 시간이 초과됐습니다. 잠시 후 다시 시도해 주세요.";
  }
  if (/(?:failed to fetch|fetch failed|networkerror|econnrefused|connection refused|could not connect|연결이?\s*(?:끊|거부))/.test(normalized)) {
    return "경기 데이터 서비스에 연결하지 못했습니다. 연결 상태를 확인해 주세요.";
  }
  if (/[가-힣]/.test(message) && !INTERNAL_DETAIL.test(message)) return message;
  return "경기 데이터를 불러오지 못했습니다. 다시 연결해 주세요.";
}
