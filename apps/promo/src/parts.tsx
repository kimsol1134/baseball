import React from "react";
import { AbsoluteFill, Img, interpolate, OffthreadVideo, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { fontStack, palette, type } from "./theme";

/// 실제 기기 화면. 시뮬레이터 녹화는 상태 표시줄까지 담기는데, 통신사 자리가 검게 지워져 있어
/// 그대로 두면 눈에 걸린다. 위쪽을 잘라 내고 모서리를 깎아 화면만 남긴다.
const CAPTURE = { width: 1206, height: 2622, statusBar: 130 };

export const PhoneScreen: React.FC<{
  src: string;
  /// 화면 높이(px). 폭은 캡처 비율에서 계산한다.
  height: number;
  /// 0이면 정지, 1이면 화면 높이의 1%만큼 위로 흐른다. 정지 화면에 미세한 움직임을 준다.
  drift?: number;
  children?: React.ReactNode;
}> = ({ src, height, drift = 0, children }) => {
  const visible = CAPTURE.height - CAPTURE.statusBar;
  const width = (CAPTURE.width / visible) * height;
  return (
    <div
      style={{
        width,
        height,
        borderRadius: height * 0.055,
        overflow: "hidden",
        position: "relative",
        background: palette.surface,
        border: `2px solid ${palette.hairline}`,
        boxShadow: `0 ${height * 0.04}px ${height * 0.12}px rgba(0,0,0,0.65)`,
        transform: `translateY(${-drift * height * 0.01}px)`,
      }}
    >
      <Img
        src={src}
        style={{
          position: "absolute",
          top: -(CAPTURE.statusBar / visible) * height,
          width,
          height: (CAPTURE.height / visible) * height,
        }}
      />
      {children}
    </div>
  );
};

/// 승부 장면. PitchDramaView를 60fps로 렌더한 실물 프레임이다.
export const DramaClip: React.FC<{
  src: string;
  height: number;
  startFrom?: number;
  /// 원본은 스트라이크존이 화면의 절반도 안 된다. 그대로 키우면 검은 여백만 커지므로
  /// 장면마다 필요한 만큼 당겨서 본다. 필드 2컷은 넓게 봐야 하니 거의 당기지 않는다.
  zoom?: number;
  /// 확대 중심의 세로 위치(0~1). 존은 화면 중앙보다 조금 위에 있다.
  focusY?: number;
  /// 테두리와 모서리를 없앤다. 전면으로 쓸 때 카드처럼 보이면 다른 장면들과 따로 논다.
  bare?: boolean;
}> = ({ src, height, startFrom = 0, zoom = 1, focusY = 0.5, bare = false }) => {
  const width = (1170 / 1380) * height;
  return (
    <div
      style={{
        width,
        height,
        borderRadius: bare ? 0 : height * 0.05,
        overflow: "hidden",
        background: palette.ink,
        border: bare ? "none" : `2px solid ${palette.hairline}`,
      }}
    >
      <OffthreadVideo
        src={src}
        startFrom={startFrom}
        muted
        style={{
          width,
          height,
          objectFit: "cover",
          transform: `scale(${zoom})`,
          transformOrigin: `50% ${focusY * 100}%`,
        }}
      />
    </div>
  );
};

/// 한 줄씩 올라오며 나타나는 제목. 화면마다 다른 방향으로 움직이면 산만해지므로 항상 아래에서 위로.
export const Rise: React.FC<{
  delay?: number;
  children: React.ReactNode;
  style?: React.CSSProperties;
}> = ({ delay = 0, children, style }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const progress = spring({ frame: frame - delay, fps, config: { damping: 200, mass: 0.6 } });
  return (
    <div
      style={{
        opacity: progress,
        transform: `translateY(${interpolate(progress, [0, 1], [26, 0])}px)`,
        ...style,
      }}
    >
      {children}
    </div>
  );
};

export const Eyebrow: React.FC<{ children: React.ReactNode; tone?: string }> = ({
  children,
  tone = palette.lime,
}) => (
  <p
    style={{
      margin: 0,
      fontFamily: fontStack,
      fontSize: type.label,
      fontWeight: 800,
      letterSpacing: "0.18em",
      color: tone,
    }}
  >
    {children}
  </p>
);

export const Title: React.FC<{ children: React.ReactNode; size?: number }> = ({
  children,
  size = type.title,
}) => (
  <h2
    style={{
      margin: 0,
      fontFamily: fontStack,
      fontSize: size,
      lineHeight: 1.18,
      fontWeight: 800,
      letterSpacing: "-0.03em",
      color: palette.bone,
      // 한글은 어절 단위로 끊어야 한다. 이것이 없으면 "않습니 / 다."처럼 낱말이 쪼개진다.
      wordBreak: "keep-all",
      textWrap: "balance",
    }}
  >
    {children}
  </h2>
);

export const Lead: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <p
    style={{
      margin: 0,
      fontFamily: fontStack,
      fontSize: type.lead,
      lineHeight: 1.55,
      fontWeight: 500,
      color: palette.muted,
      wordBreak: "keep-all",
    }}
  >
    {children}
  </p>
);

/// 장면 뒤에 까는 빛. 마운드 조명을 흉내 낸 타원이라 어느 장면에 깔아도 야구장으로 읽힌다.
export const StadiumGlow: React.FC<{ x?: string; y?: string; strength?: number }> = ({
  x = "50%",
  y = "30%",
  strength = 0.5,
}) => (
  <AbsoluteFill
    style={{
      background: `radial-gradient(60% 46% at ${x} ${y}, rgba(183,243,107,${0.11 * strength}) 0%, rgba(20,42,30,${
        0.5 * strength
      }) 34%, ${palette.ink} 76%)`,
    }}
  />
);
