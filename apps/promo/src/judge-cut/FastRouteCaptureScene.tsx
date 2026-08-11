import React from "react";
import { CaptureFrame } from "./CaptureFrame";

export const FastRouteCaptureScene: React.FC = () => (
  <CaptureFrame
    video="fast-route.webm"
    kicker="ACTUAL PUBLIC BUILD"
    title="고르고, 키우고, 직접 놓는다."
    detail="빌드·강도·결정구 → 첫 투구"
    cropScale={1.27}
    cropOrigin="center 58%"
  />
);
