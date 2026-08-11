import React from "react";
import { CaptureFrame } from "./CaptureFrame";

export const RebirthCaptureScene: React.FC = () => (
  <CaptureFrame
    video="rebirth.webm"
    kicker="FULL CAREER RESULT"
    title="지명 뒤에도 계보는 계속된다."
    detail="세 관문 지명 → 야구혼 → LIFE 02"
    sound="bat-contact-hard.wav"
    cropScale={1.2}
    cropOrigin="center 54%"
  />
);
