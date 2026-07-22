import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { getAppStorage, hydrateCloudStorage, installCloudSaveCloseGuard } from "./cloudStorage";
import { ErrorBoundary, StartupFailure, StorageWarning } from "./ErrorBoundary";
import "./styles.css";
import "./release.css";

const root = document.getElementById("root");

if (!root) {
  throw new Error("Root element was not found");
}

async function start() {
  let storageUnavailable = false;
  try {
    await hydrateCloudStorage(window.localStorage);
    await installCloudSaveCloseGuard(getAppStorage());
  } catch (caught) {
    storageUnavailable = true;
    console.error("Steam Cloud 저장을 불러오지 못했습니다.", caught);
  }
  const { App } = await import("./App");
  createRoot(root!).render(
    <StrictMode>
      <ErrorBoundary>
        <App />
        {storageUnavailable ? <StorageWarning /> : null}
      </ErrorBoundary>
    </StrictMode>,
  );
}

void start().catch((caught) => {
  console.error("게임을 시작하지 못했습니다.", caught);
  createRoot(root).render(<StartupFailure />);
});
