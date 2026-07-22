import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { getAppStorage, hydrateCloudStorage, installCloudSaveCloseGuard } from "./cloudStorage";
import "./styles.css";

const root = document.getElementById("root");

if (!root) {
  throw new Error("Root element was not found");
}

async function start() {
  try {
    await hydrateCloudStorage(window.localStorage);
    await installCloudSaveCloseGuard(getAppStorage());
  } catch (caught) {
    console.error("Steam Cloud 저장을 불러오지 못했습니다.", caught);
  }
  const { App } = await import("./App");
  createRoot(root!).render(
    <StrictMode>
      <App />
    </StrictMode>,
  );
}

void start();
