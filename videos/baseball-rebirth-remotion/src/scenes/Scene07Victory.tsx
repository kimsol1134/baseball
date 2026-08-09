import { Audio } from "@remotion/media";
import { AbsoluteFill, Easing, Interactive, interpolate, staticFile, useCurrentFrame } from "remotion";
import { Capture, COLORS, MonoLabel, SafeFrame } from "./shared";

export const Scene07Victory: React.FC = () => {
  const frame = useCurrentFrame();
  const masteryPhase = interpolate(frame, [76, 94], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const completePhase = interpolate(frame, [154, 174], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const matchPhase = interpolate(frame, [224, 246], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const strikeoutPhase = interpolate(frame, [330, 350], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });

  return (
    <AbsoluteFill style={{ backgroundColor: COLORS.ink }}>
      <Capture name="Sweeping slider design" src="game/16-power-design.png" style={{ opacity: 1 - masteryPhase, filter: "brightness(0.61)" }} />
      <Capture name="Power training mastery" src="game/17-power-mastery.png" style={{ opacity: masteryPhase * (1 - completePhase), filter: "brightness(0.6)" }} />
      <Capture name="Power blueprint complete" src="game/18-next-build-complete.png" style={{ opacity: completePhase * (1 - matchPhase), filter: "brightness(0.61)" }} />
      <Capture name="Pitch design visibly triggers" src="game/19-design-trigger.png" style={{ opacity: matchPhase * (1 - strikeoutPhase), filter: "brightness(0.59)" }} />
      <Capture name="Power build earns the strikeout" src="game/21-strikeout.png" style={{ opacity: strikeoutPhase, filter: "brightness(0.62)" }} />
      <AbsoluteFill style={{ backgroundImage: "linear-gradient(90deg, rgba(3,6,5,0.97) 0 44%, rgba(3,6,5,0.38) 66%, rgba(3,6,5,0.14) 100%)" }} />

      <SafeFrame>
        <Interactive.Div
          name="Second build identity"
          style={{
            width: 830,
            opacity: interpolate(frame, [8, 28, 214, 236], [0, 1, 1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.bezier(0.16, 1, 0.3, 1) }),
          }}
        >
          <MonoLabel>BUILD 02 · POWER BLUEPRINT</MonoLabel>
          <div style={{ marginTop: 22, fontSize: 75, fontWeight: 950, lineHeight: 1.04, letterSpacing: "-0.06em" }}>
            이번엔 변화량을 키우고,
            <br /><span style={{ color: COLORS.acid }}>결정구를 두 번 숙련한다.</span>
          </div>
        </Interactive.Div>

        <div style={{ position: "absolute", top: 370, left: 100, width: 760, display: "grid", gap: 10, opacity: interpolate(frame, [26, 46, 214, 236], [0, 1, 1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }) }}>
          {[
            ["BRANCH", "가로지르는 슬라이더", "코너 질 +7 · 판단 +3"],
            ["REPEAT", "결정구 불펜 LV.2", "변화구 핵심 능력 +2"],
            ["COMPLETE", "압도형 에이스", "터널 설계 · 노림수 파괴"],
          ].map(([key, title, detail], index) => (
            <Interactive.Div
              key={key}
              name={`${key} second build step`}
              style={{
                display: "grid",
                gridTemplateColumns: "120px 1fr auto",
                alignItems: "center",
                gap: 16,
                padding: "16px 18px",
                borderLeft: `4px solid ${index === 0 ? COLORS.blue : COLORS.acid}`,
                backgroundColor: "rgba(7,11,10,0.9)",
                opacity: interpolate(frame, [34 + index * 70, 52 + index * 70], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
              }}
            >
              <span style={{ color: index === 0 ? COLORS.blue : COLORS.acid, fontFamily: 'ui-monospace, "SFMono-Regular", Menlo, monospace', fontSize: 18, fontWeight: 950 }}>{key}</span>
              <strong style={{ color: COLORS.paper, fontSize: 27 }}>{title}</strong>
              <small style={{ color: COLORS.muted, fontSize: 20, fontWeight: 750 }}>{detail}</small>
            </Interactive.Div>
          ))}
        </div>

        <Interactive.Div
          name="Design trigger proof"
          style={{
            position: "absolute",
            top: 108,
            left: 100,
            width: 900,
            opacity: interpolate(frame, [246, 270, 322, 342], [0, 1, 1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.bezier(0.16, 1, 0.3, 1) }),
          }}
        >
          <MonoLabel tone="muted">TRAINING → LIVE TRIGGER</MonoLabel>
          <div style={{ marginTop: 22, fontSize: 80, fontWeight: 950, lineHeight: 1.03, letterSpacing: "-0.06em" }}>
            코너에 슬라이더를 고르자,
            <br /><span style={{ color: COLORS.blue }}>설계 효과가 발동한다.</span>
          </div>
          <div style={{ display: "inline-flex", marginTop: 28, padding: "14px 20px", border: `2px solid ${COLORS.blue}`, backgroundColor: "rgba(121,201,207,0.1)", color: COLORS.blue, fontSize: 28, fontWeight: 950 }}>공의 질 +7 · 카운터 판단 +3</div>
        </Interactive.Div>

        <Interactive.Div
          name="Development payoff strikeout"
          style={{
            position: "absolute",
            top: 124,
            left: 100,
            width: 1220,
            opacity: interpolate(frame, [350, 374], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.bezier(0.16, 1, 0.3, 1) }),
          }}
        >
          <MonoLabel>THE PAYOFF</MonoLabel>
          <div style={{ marginTop: 22, fontSize: 80, fontWeight: 950, lineHeight: 1.02, letterSpacing: "-0.06em" }}>
            삼진은 버튼 보상이 아니라,
            <br /><span style={{ color: COLORS.acid }}>5일 육성의 결과.</span>
          </div>
        </Interactive.Div>
      </SafeFrame>
      <Audio src={staticFile("audio/whoosh-cinematic.mp3")} volume={0.16} />
      <Audio src={staticFile("audio/click-soft.mp3")} from={48} volume={0.24} />
      <Audio src={staticFile("audio/ping.mp3")} from={102} volume={0.23} />
      <Audio src={staticFile("audio/chime.mp3")} from={176} volume={0.2} />
      <Audio src={staticFile("audio/whoosh-short.mp3")} from={230} volume={0.3} />
      <Audio src={staticFile("audio/impact-bass-1.mp3")} from={258} volume={0.3} />
      <Audio src={staticFile("audio/impact-bass-2.mp3")} from={344} volume={0.34} />
      <Audio src={staticFile("audio/chime.mp3")} from={378} volume={0.23} />
    </AbsoluteFill>
  );
};
