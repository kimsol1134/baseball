import { Audio } from "@remotion/media";
import { AbsoluteFill, Easing, Interactive, interpolate, staticFile, useCurrentFrame } from "remotion";
import { Capture, COLORS, MonoLabel, SafeFrame } from "./shared";

const DAYS = ["제구", "분석", "체력", "설계", "숙련", "회복"] as const;

export const Scene03Tradeoff: React.FC = () => {
  const frame = useCurrentFrame();
  const phaseTwo = interpolate(frame, [112, 132], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const phaseThree = interpolate(frame, [244, 266], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const activeStep = frame < 122 ? 0 : frame < 254 ? 1 : 3;

  return (
    <AbsoluteFill style={{ backgroundColor: COLORS.ink }}>
      <Capture name="Day one command training" src="game/04-day1-command.png" style={{ opacity: 1 - phaseTwo, filter: "brightness(0.64)" }} />
      <Capture name="Day two combo unlock" src="game/05-day2-combo.png" style={{ opacity: phaseTwo * (1 - phaseThree), filter: "brightness(0.62)" }} />
      <Capture name="Day three pitch lab branch" src="game/06-day3-pitch-lab.png" style={{ opacity: phaseThree, filter: "brightness(0.63)" }} />
      <AbsoluteFill style={{ backgroundImage: "linear-gradient(90deg, rgba(3,6,5,0.97) 0 43%, rgba(3,6,5,0.44) 65%, rgba(3,6,5,0.18) 100%)" }} />

      <SafeFrame>
        <Interactive.Div
          name="Day one message"
          style={{
            width: 720,
            opacity: interpolate(frame, [8, 30, 104, 124], [0, 1, 1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.bezier(0.16, 1, 0.3, 1) }),
          }}
        >
          <MonoLabel>D1 · FOUNDATION</MonoLabel>
          <div style={{ marginTop: 22, fontSize: 82, fontWeight: 950, lineHeight: 1.03, letterSpacing: "-0.06em" }}>
            첫날,
            <br /><span style={{ color: COLORS.acid }}>손끝을 만든다.</span>
          </div>
          <p style={{ margin: "28px 0 0", color: COLORS.muted, fontSize: 34, fontWeight: 760 }}>코스 제구 훈련 · 제구 상승 · 피로 누적</p>
        </Interactive.Div>

        <Interactive.Div
          name="Day two connection message"
          style={{
            position: "absolute",
            top: 100,
            left: 100,
            width: 780,
            opacity: interpolate(frame, [132, 154, 236, 256], [0, 1, 1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.bezier(0.16, 1, 0.3, 1) }),
          }}
        >
          <MonoLabel>D2 · CONNECT</MonoLabel>
          <div style={{ marginTop: 22, fontSize: 78, fontWeight: 950, lineHeight: 1.04, letterSpacing: "-0.06em" }}>
            제구 + 분석
            <br /><span style={{ color: COLORS.acid }}>= ‘존 설계’ 해금.</span>
          </div>
          <div style={{ display: "inline-flex", marginTop: 30, padding: "15px 20px", color: COLORS.ink, backgroundColor: COLORS.acid, fontSize: 25, fontWeight: 950, letterSpacing: "0.06em" }}>COMBO UNLOCKED</div>
        </Interactive.Div>

        <Interactive.Div
          name="Midweek branch message"
          style={{
            position: "absolute",
            top: 100,
            left: 100,
            width: 830,
            opacity: interpolate(frame, [266, 290], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.bezier(0.16, 1, 0.3, 1) }),
          }}
        >
          <MonoLabel tone="muted">D3 · MIDWEEK BRANCH</MonoLabel>
          <div style={{ marginTop: 22, fontSize: 78, fontWeight: 950, lineHeight: 1.04, letterSpacing: "-0.06em" }}>
            세 번째 선택 뒤,
            <br /><span style={{ color: COLORS.blue }}>빌드가 둘로 갈라진다.</span>
          </div>
          <p style={{ margin: "28px 0 0", color: COLORS.muted, fontSize: 33, fontWeight: 760 }}>같은 코너 공약도 어떤 피치 디자인을 고르느냐에 따라 경기 발동 조건이 달라진다.</p>
        </Interactive.Div>

        <div style={{ position: "absolute", right: 100, bottom: 104, left: 100, display: "grid", gridTemplateColumns: "repeat(6, 1fr)", gap: 10 }}>
          {DAYS.map((label, index) => {
            const reached = index <= activeStep;
            const branch = index === 3;
            return (
              <Interactive.Div
                key={label}
                name={`Development timeline step ${index + 1}`}
                style={{
                  padding: "16px 18px",
                  borderTop: `4px solid ${branch ? COLORS.blue : reached ? COLORS.acid : COLORS.line}`,
                  backgroundColor: reached || branch ? "rgba(7,11,10,0.92)" : "rgba(7,11,10,0.66)",
                  opacity: interpolate(frame, [24 + index * 8, 42 + index * 8], [0, reached || branch ? 1 : 0.48], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
                }}
              >
                <span style={{ color: branch ? COLORS.blue : reached ? COLORS.acid : COLORS.dim, fontFamily: 'ui-monospace, "SFMono-Regular", Menlo, monospace', fontSize: 18, fontWeight: 950 }}>D{branch ? "3½" : index < 3 ? index + 1 : index}</span>
                <strong style={{ display: "block", marginTop: 6, color: COLORS.paper, fontSize: 24 }}>{label}</strong>
              </Interactive.Div>
            );
          })}
        </div>
      </SafeFrame>
      <Audio src={staticFile("audio/click.mp3")} from={24} volume={0.25} />
      <Audio src={staticFile("audio/impact-bass-1.mp3")} from={124} volume={0.28} />
      <Audio src={staticFile("audio/ping.mp3")} from={170} volume={0.22} />
      <Audio src={staticFile("audio/whoosh-cinematic.mp3")} from={250} volume={0.18} />
      <Audio src={staticFile("audio/chime.mp3")} from={292} volume={0.22} />
    </AbsoluteFill>
  );
};
