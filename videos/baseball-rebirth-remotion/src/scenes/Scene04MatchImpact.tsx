import { Audio } from "@remotion/media";
import { AbsoluteFill, Easing, Interactive, interpolate, staticFile, useCurrentFrame } from "remotion";
import { Capture, COLORS, MonoLabel, SafeFrame } from "./shared";

const BUILD_STEPS = [
  { key: "BRANCH", title: "검은 선 제구", detail: "코너 실행 +7" },
  { key: "REPEAT", title: "제구 훈련 LV.2", detail: "핵심 능력 +2" },
  { key: "RECOVER", title: "회복과 가동성", detail: "피로 57 → 33" },
] as const;

export const Scene04MatchImpact: React.FC = () => {
  const frame = useCurrentFrame();
  const masteryPhase = interpolate(frame, [108, 128], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const completePhase = interpolate(frame, [228, 248], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });

  return (
    <AbsoluteFill style={{ backgroundColor: COLORS.ink }}>
      <Capture name="Precision pitch design selected" src="game/07-precision-design.png" style={{ opacity: 1 - masteryPhase, filter: "brightness(0.63)" }} />
      <Capture name="Repeated training reaches mastery level two" src="game/08-repeat-mastery.png" style={{ opacity: masteryPhase * (1 - completePhase), filter: "brightness(0.62)" }} />
      <Capture name="Five-day signature build complete" src="game/09-training-complete.png" style={{ opacity: completePhase, filter: "brightness(0.65)" }} />
      <AbsoluteFill style={{ backgroundImage: "linear-gradient(90deg, rgba(3,6,5,0.97) 0 45%, rgba(3,6,5,0.4) 67%, rgba(3,6,5,0.14) 100%)" }} />

      <SafeFrame>
        <Interactive.Div
          name="Pitch design choice"
          style={{
            width: 780,
            opacity: interpolate(frame, [8, 28, 100, 120], [0, 1, 1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.bezier(0.16, 1, 0.3, 1) }),
          }}
        >
          <MonoLabel tone="muted">BRANCH · COMMAND LAB</MonoLabel>
          <div style={{ marginTop: 22, fontSize: 80, fontWeight: 950, lineHeight: 1.03, letterSpacing: "-0.06em" }}>
            경기에서 쓸 무기,
            <br /><span style={{ color: COLORS.blue }}>‘검은 선 제구’.</span>
          </div>
          <p style={{ margin: "28px 0 0", color: COLORS.muted, fontSize: 33, fontWeight: 760 }}>릴리스 +1%p · 네 곳의 코너에서 실행 +7</p>
        </Interactive.Div>

        <Interactive.Div
          name="Repeat mastery choice"
          style={{
            position: "absolute",
            top: 100,
            left: 100,
            width: 800,
            opacity: interpolate(frame, [128, 150, 218, 240], [0, 1, 1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.bezier(0.16, 1, 0.3, 1) }),
          }}
        >
          <MonoLabel>D4 · REPEAT MASTERY</MonoLabel>
          <div style={{ marginTop: 22, fontSize: 80, fontWeight: 950, lineHeight: 1.03, letterSpacing: "-0.06em" }}>
            같은 훈련을 다시.
            <br /><span style={{ color: COLORS.acid }}>숙련 LV.2.</span>
          </div>
          <p style={{ margin: "28px 0 0", color: COLORS.muted, fontSize: 33, fontWeight: 760 }}>제구 훈련 두 번째 선택 · 핵심 능력 추가 +2 · 대신 추가 피로</p>
        </Interactive.Div>

        <Interactive.Div
          name="Completed development identity"
          style={{
            position: "absolute",
            top: 92,
            left: 100,
            width: 880,
            opacity: interpolate(frame, [248, 272], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.bezier(0.16, 1, 0.3, 1) }),
          }}
        >
          <MonoLabel>D5 · RECOVER · BLUEPRINT COMPLETE</MonoLabel>
          <div style={{ marginTop: 22, fontSize: 77, fontWeight: 950, lineHeight: 1.04, letterSpacing: "-0.06em" }}>
            다섯 선택이 하나의
            <br /><span style={{ color: COLORS.acid }}>투수로 완성된다.</span>
          </div>
          <div style={{ display: "inline-flex", marginTop: 30, padding: "16px 22px", border: `2px solid ${COLORS.acid}`, backgroundColor: "rgba(200,242,74,0.1)", color: COLORS.acid, fontSize: 30, fontWeight: 950 }}>
            한 뼘 승부 · 검은 선 제구
          </div>
        </Interactive.Div>

        <div style={{ position: "absolute", right: 100, bottom: 94, left: 100, display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 12 }}>
          {BUILD_STEPS.map((step, index) => {
            const reachedAt = index === 0 ? 36 : index === 1 ? 152 : 272;
            return (
              <Interactive.Div
                key={step.key}
                name={`${step.key} build proof`}
                style={{
                  padding: "18px 20px",
                  borderLeft: `4px solid ${index === 0 ? COLORS.blue : COLORS.acid}`,
                  backgroundColor: "rgba(7,11,10,0.9)",
                  opacity: interpolate(frame, [reachedAt, reachedAt + 18], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
                }}
              >
                <span style={{ color: index === 0 ? COLORS.blue : COLORS.acid, fontFamily: 'ui-monospace, "SFMono-Regular", Menlo, monospace', fontSize: 18, fontWeight: 950 }}>{step.key}</span>
                <strong style={{ display: "block", marginTop: 6, color: COLORS.paper, fontSize: 27 }}>{step.title}</strong>
                <small style={{ display: "block", marginTop: 4, color: COLORS.muted, fontSize: 21, fontWeight: 760 }}>{step.detail}</small>
              </Interactive.Div>
            );
          })}
        </div>
      </SafeFrame>
      <Audio src={staticFile("audio/whoosh-short.mp3")} from={10} volume={0.28} />
      <Audio src={staticFile("audio/impact-bass-1.mp3")} from={116} volume={0.26} />
      <Audio src={staticFile("audio/ping.mp3")} from={158} volume={0.25} />
      <Audio src={staticFile("audio/whoosh-cinematic.mp3")} from={234} volume={0.17} />
      <Audio src={staticFile("audio/chime.mp3")} from={278} volume={0.24} />
    </AbsoluteFill>
  );
};
