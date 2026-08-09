import { Audio } from "@remotion/media";
import { AbsoluteFill, CanvasImage, Easing, Interactive, interpolate, staticFile, useCurrentFrame } from "remotion";
import { Capture, COLORS, FrameGrid, MonoLabel, SafeFrame } from "./shared";

export const Scene08Draft: React.FC = () => {
  const frame = useCurrentFrame();
  const legacyPhase = interpolate(frame, [58, 76], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const mindLabPhase = interpolate(frame, [126, 146], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const mindBuildPhase = interpolate(frame, [198, 218], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const mindTriggerPhase = interpolate(frame, [274, 294], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const archivePhase = interpolate(frame, [334, 354], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const ctaPhase = interpolate(frame, [402, 424], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });

  return (
    <AbsoluteFill style={{ backgroundColor: COLORS.ink }}>
      <Capture name="First completed philosophy victory" src="game/22-victory.png" style={{ opacity: 1 - legacyPhase, filter: "brightness(0.64)" }} />
      <Capture name="First permanent signature legacy" src="game/23-signature-legacy.png" style={{ opacity: legacyPhase * (1 - mindLabPhase), filter: "brightness(0.59)" }} />
      <Capture name="Mind-game pitch lab" src="game/24-mind-pitch-lab.png" style={{ opacity: mindLabPhase * (1 - mindBuildPhase), filter: "brightness(0.59)" }} />
      <Capture name="Mind-game blueprint complete" src="game/25-pattern-thief-build.png" style={{ opacity: mindBuildPhase * (1 - mindTriggerPhase), filter: "brightness(0.59)" }} />
      <Capture name="Sequence design trigger" src="game/26-sequence-design-trigger.png" style={{ opacity: mindTriggerPhase * (1 - archivePhase), filter: "brightness(0.58)" }} />
      <Capture name="Three philosophies complete" src="game/28-legacy-archive-complete.png" style={{ opacity: archivePhase * (1 - ctaPhase), filter: "brightness(0.66)" }} />
      <Capture name="Final key art" src="art/scene-draft.webp" style={{ opacity: ctaPhase, filter: "saturate(0.66) brightness(0.34)" }} />

      <AbsoluteFill style={{ backgroundImage: "linear-gradient(90deg, rgba(3,6,5,0.97) 0 48%, rgba(3,6,5,0.42) 69%, rgba(3,6,5,0.18) 100%)" }} />
      <FrameGrid />
      <SafeFrame>
        <Interactive.Div
          name="Winning build becomes legacy"
          style={{
            width: 930,
            opacity: interpolate(frame, [8, 26, 116, 138], [0, 1, 1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.bezier(0.16, 1, 0.3, 1) }),
          }}
        >
          <MonoLabel>WIN → MASTER → INHERIT</MonoLabel>
          <div style={{ marginTop: 22, fontSize: 78, fontWeight: 950, lineHeight: 1.04, letterSpacing: "-0.06em" }}>
            승리한 투수 철학은
            <br /><span style={{ color: COLORS.acid }}>다음 빌드의 영구 유산.</span>
          </div>
          <div style={{ display: "inline-flex", marginTop: 28, gap: 18, padding: "15px 20px", border: `2px solid ${COLORS.acid}`, backgroundColor: "rgba(200,242,74,0.1)", color: COLORS.paper, fontSize: 27, fontWeight: 900 }}>
            결정구 유산 <b style={{ color: COLORS.acid }}>MASTERED · 1 / 3</b>
          </div>
        </Interactive.Div>

        <Interactive.Div
          name="Third distinct build"
          style={{
            position: "absolute",
            top: 96,
            left: 100,
            width: 960,
            opacity: interpolate(frame, [146, 168, 324, 346], [0, 1, 1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.bezier(0.16, 1, 0.3, 1) }),
          }}
        >
          <MonoLabel tone="muted">BUILD 03 · MIND GAME</MonoLabel>
          <div style={{ marginTop: 22, fontSize: 76, fontWeight: 950, lineHeight: 1.04, letterSpacing: "-0.06em" }}>
            상대가 달라지면,
            <br /><span style={{ color: COLORS.blue }}>육성의 답도 다시 달라진다.</span>
          </div>
          <div style={{ display: "flex", gap: 10, marginTop: 28 }}>
            {[
              ["CONNECT", "분석 + 제구 + 회복"],
              ["BRANCH", "역순 설계"],
              ["TRIGGER", "구종 전환 + 카운터"],
            ].map(([key, value], index) => (
              <Interactive.Div
                key={key}
                name={`${key} mind-game proof`}
                style={{
                  padding: "15px 18px",
                  borderTop: `4px solid ${index === 1 ? COLORS.blue : COLORS.acid}`,
                  backgroundColor: "rgba(7,11,10,0.9)",
                  opacity: interpolate(frame, [162 + index * 58, 180 + index * 58], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
                }}
              >
                <span style={{ display: "block", color: index === 1 ? COLORS.blue : COLORS.acid, fontFamily: 'ui-monospace, "SFMono-Regular", Menlo, monospace', fontSize: 17, fontWeight: 950 }}>{key}</span>
                <strong style={{ display: "block", marginTop: 7, color: COLORS.paper, fontSize: 24 }}>{value}</strong>
              </Interactive.Div>
            ))}
          </div>
        </Interactive.Div>

        <Interactive.Div
          name="Three philosophy archive proof"
          style={{
            position: "absolute",
            top: 104,
            left: 100,
            width: 980,
            opacity: interpolate(frame, [354, 376, 394, 414], [0, 1, 1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.bezier(0.16, 1, 0.3, 1) }),
          }}
        >
          <MonoLabel>ACTUAL GAMEPLAY · LEGACY ARCHIVE 3 / 3</MonoLabel>
          <div style={{ marginTop: 22, fontSize: 86, fontWeight: 950, lineHeight: 1.01, letterSpacing: "-0.065em" }}>
            세 가지 투수를
            <br /><span style={{ color: COLORS.acid }}>모두 완성했다.</span>
          </div>
        </Interactive.Div>

        <Interactive.Div
          name="Final game icon"
          style={{
            position: "absolute",
            top: 146,
            left: 116,
            width: 156,
            height: 156,
            opacity: interpolate(frame, [424, 442], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
            scale: interpolate(frame, [424, 448], [0.78, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.spring({ damping: 200 }), output: "perceptual-scale" }),
          }}
        >
          <CanvasImage src={staticFile("art/icon.png")} width={156} height={156} style={{ width: 156, height: 156, borderRadius: 26 }} />
        </Interactive.Div>

        <Interactive.Div
          name="Final public call to action"
          style={{
            position: "absolute",
            top: 154,
            left: 310,
            width: 1180,
            opacity: interpolate(frame, [432, 452], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.bezier(0.16, 1, 0.3, 1) }),
          }}
        >
          <div style={{ color: COLORS.paper, fontSize: 82, fontWeight: 950, lineHeight: 1, letterSpacing: "-0.065em" }}>
            <span style={{ display: "block", fontSize: 46, color: COLORS.muted }}>야구 못하면</span>
            <span style={{ color: COLORS.acid }}>또 환생함</span>
          </div>
          <p style={{ margin: "28px 0 0", color: COLORS.paper, fontSize: 38, fontWeight: 850 }}>마지막 공을 던지기 전에, 먼저 투수를 만드세요.</p>
          <div style={{ display: "inline-flex", marginTop: 28, padding: "16px 22px", border: `2px solid ${COLORS.acid}`, backgroundColor: "rgba(7,11,10,0.86)", color: COLORS.acid, fontFamily: 'ui-monospace, "SFMono-Regular", Menlo, monospace', fontSize: 25, fontWeight: 950 }}>
            baseball-rebirth-last-pitch.kimsol1134.chatgpt.site
          </div>
          <small style={{ display: "block", marginTop: 18, color: COLORS.muted, fontSize: 20, fontWeight: 750 }}>PUBLIC WEB EDITION · EFFECTS-ONLY VIDEO · 독자적 가상 야구 세계관</small>
        </Interactive.Div>
      </SafeFrame>
      <Audio src={staticFile("audio/chime.mp3")} from={16} volume={0.22} />
      <Audio src={staticFile("audio/whoosh-short.mp3")} from={64} volume={0.28} />
      <Audio src={staticFile("audio/ping.mp3")} from={96} volume={0.22} />
      <Audio src={staticFile("audio/whoosh-cinematic.mp3")} from={132} volume={0.16} />
      <Audio src={staticFile("audio/click-soft.mp3")} from={212} volume={0.25} />
      <Audio src={staticFile("audio/impact-bass-1.mp3")} from={282} volume={0.28} />
      <Audio src={staticFile("audio/chime.mp3")} from={356} volume={0.26} />
      <Audio src={staticFile("audio/whoosh-short.mp3")} from={408} volume={0.3} />
      <Audio src={staticFile("audio/impact-bass-2.mp3")} from={438} volume={0.28} />
    </AbsoluteFill>
  );
};
