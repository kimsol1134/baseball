interface CoreUnavailableStateProps {
  message: string;
  isChecking?: boolean;
  onRetry: () => void;
}

export function CoreUnavailableState({ message, isChecking = false, onRetry }: CoreUnavailableStateProps) {
  return (
    <section className="core-unavailable-state ds-card" role="status" aria-live="polite">
      <span>{isChecking ? "경기 데이터 확인 중" : "경기 데이터 연결 필요"}</span>
      <h2>{isChecking ? "선수 명단을 준비하고 있습니다." : "선수 명단을 아직 불러오지 못했습니다."}</h2>
      <p>{message}</p>
      <small>이 기기에 저장된 커리어는 지워지지 않습니다. 연결이 복구되면 마지막 확정 선택부터 이어집니다.</small>
      <button className="ds-button ds-button--primary" type="button" disabled={isChecking} onClick={onRetry}>
        {isChecking ? "연결 확인 중…" : "다시 연결"}
      </button>
    </section>
  );
}
