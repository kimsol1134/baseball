import React from "react";
import { AbsoluteFill, Img, staticFile } from "remotion";
import { fontStack } from "../theme";

export const JudgePoster: React.FC = () => (
  <AbsoluteFill style={{ overflow: "hidden", backgroundColor: "#050807" }}>
    <Img src={staticFile("web/desktop-pitch.jpg")} style={{ width: "100%", height: "100%", objectFit: "cover", opacity: 0.3, scale: 1.12, transformOrigin: "center 55%" }} />
    <AbsoluteFill style={{ background: "linear-gradient(90deg, rgba(5,8,7,0.99) 0%, rgba(5,8,7,0.9) 48%, rgba(5,8,7,0.34) 100%)" }} />
    <div style={{ position: "absolute", top: 74, left: 82, color: "#C8F24A", fontFamily: fontStack, fontSize: 27, fontWeight: 950, letterSpacing: "0.1em" }}>야구 못하면 또 환생함 · BASEBALL ROGUELITE</div>
    <div style={{ position: "absolute", top: 154, left: 82, width: 1050 }}>
      <h1 style={{ margin: 0, color: "#EEF0DF", fontFamily: fontStack, fontSize: 115, fontWeight: 950, lineHeight: 0.94, letterSpacing: "-0.07em" }}>15번 키우고,<br /><span style={{ color: "#C8F24A" }}>한 구로 증명한다.</span></h1>
      <p style={{ margin: "34px 0 0", color: "#A8B1A4", fontFamily: fontStack, fontSize: 34, fontWeight: 800 }}>관계 · 서약 · 구종 빌드 · 세 관문 · 환생 계보</p>
    </div>
    <div style={{ position: "absolute", right: 86, top: 106, width: 520, height: 520, display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gridTemplateRows: "repeat(3, 1fr)", border: "3px solid rgba(238,240,223,0.65)", backgroundColor: "rgba(5,8,7,0.7)", boxShadow: "0 36px 100px rgba(0,0,0,0.64)" }}>
      {Array.from({ length: 9 }, (_, index) => <div key={index} style={{ borderRight: index % 3 === 2 ? "none" : "1px solid rgba(238,240,223,0.32)", borderBottom: index > 5 ? "none" : "1px solid rgba(238,240,223,0.32)", backgroundColor: index === 2 ? "rgba(200,242,74,0.26)" : "transparent" }} />)}
      <div style={{ position: "absolute", top: 58, right: 58, width: 50, height: 50, borderRadius: "50%", border: "4px solid #C8F24A", boxShadow: "0 0 0 14px rgba(200,242,74,0.14), 0 0 34px rgba(200,242,74,0.55)" }} />
      <div style={{ position: "absolute", right: 23, bottom: 18, color: "#C8F24A", fontFamily: fontStack, fontSize: 22, fontWeight: 950 }}>PERFECT RELEASE</div>
    </div>
    <div style={{ position: "absolute", left: 82, right: 82, bottom: 66, display: "grid", gridTemplateColumns: "1fr auto 1fr", alignItems: "center", gap: 22 }}>
      <div style={{ padding: "24px 28px", border: "1px solid rgba(121,201,207,0.45)", backgroundColor: "rgba(5,8,7,0.9)" }}><small style={{ color: "#79C9CF", fontFamily: fontStack, fontSize: 20, fontWeight: 900 }}>LIFE 01</small><strong style={{ display: "block", marginTop: 8, color: "#EEF0DF", fontFamily: fontStack, fontSize: 36 }}>세 관문 지명</strong></div>
      <strong style={{ color: "#C8F24A", fontFamily: fontStack, fontSize: 54 }}>→</strong>
      <div style={{ padding: "24px 28px", border: "2px solid rgba(200,242,74,0.62)", backgroundColor: "rgba(200,242,74,0.1)" }}><small style={{ color: "#C8F24A", fontFamily: fontStack, fontSize: 20, fontWeight: 900 }}>LIFE 02</small><strong style={{ display: "block", marginTop: 8, color: "#EEF0DF", fontFamily: fontStack, fontSize: 36 }}>기억·야구혼 계승</strong></div>
    </div>
  </AbsoluteFill>
);
