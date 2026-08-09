import React from "react";
import { Audio, Sequence, staticFile } from "remotion";
import { BodyCopy, Headline, Kicker, PillRow, SceneChrome } from "./SceneChrome";

export const CareerScene: React.FC = () => (
  <SceneChrome image="desktop-career.jpg" focus="58% center" shade="left">
    <Sequence from={12} durationInFrames={70} layout="none">
      <Audio src={staticFile("sfx/umpire-strike.wav")} volume={0.42} />
    </Sequence>
    <div style={{ position: "absolute", left: 92, top: 112, width: 720, display: "flex", flexDirection: "column", gap: 24 }}>
      <Kicker>THREE-GATE CAREER</Kicker>
      <Headline>한 생은<br /><span style={{ color: "#C8F24A" }}>세 번의 관문</span>으로 남는다.</Headline>
      <BodyCopy>회차의 바람, 한 생의 맹세, 감독·포수·숙적과의 믿음이 다음 경기의 규칙을 바꿉니다.</BodyCopy>
      <PillRow items={["세계의 바람", "RUN PLEDGE", "3인 관계", "환생 계보"]} />
    </div>
  </SceneChrome>
);

