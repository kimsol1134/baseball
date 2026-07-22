import { Component, useState, type ErrorInfo, type ReactNode } from "react";

interface Props {
  children: ReactNode;
}

interface State {
  failed: boolean;
}

export class ErrorBoundary extends Component<Props, State> {
  state: State = { failed: false };

  static getDerivedStateFromError(): State {
    return { failed: true };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error("게임 화면을 표시하지 못했습니다.", error, info.componentStack);
  }

  render() {
    if (this.state.failed) return <StartupFailure />;
    return this.props.children;
  }
}

export function StartupFailure() {
  return <main className="startup-failure" role="alert">
    <div className="startup-failure-card">
      <span>야구 못하면 또 환생함</span>
      <h1>게임 화면을 불러오지 못했습니다.</h1>
      <p>저장 데이터는 그대로 남아 있습니다. 게임을 다시 불러온 뒤에도 같은 문제가 생기면 앱을 완전히 종료하고 다시 실행해 주세요.</p>
      <button type="button" onClick={() => window.location.reload()}>게임 다시 불러오기</button>
    </div>
  </main>;
}

export function StorageWarning() {
  const [visible, setVisible] = useState(true);
  if (!visible) return null;
  return <div className="startup-storage-warning" role="alert">
    <span>Steam Cloud 저장을 불러오지 못해 이 기기의 저장으로 시작했습니다. 다음 선택은 로컬 저장에 계속 기록됩니다.</span>
    <button type="button" aria-label="저장 안내 닫기" onClick={() => setVisible(false)}>확인</button>
  </div>;
}
