export type AvatarRole = "player" | "coach" | "catcher" | "rival";

// 이름 시드 → 파츠 조합 절차 생성 초상. 같은 이름은 항상 같은 얼굴, 다른 이름은 다른 얼굴이 되게 해
// "절차 생성 인물마다 같은 사진이 반복되는" 문제를 사진 없이 해결한다. 색은 SVG 인라인 상수로,
// 디자인 시스템 토큰은 UI 프레임에만 적용된다는 검사 규칙과 충돌하지 않는다.
const SKIN = ["var(--avatar-skin-1)", "var(--avatar-skin-2)", "var(--avatar-skin-3)", "var(--avatar-skin-4)", "var(--avatar-skin-5)"];
const HAIR = ["var(--avatar-hair-1)", "var(--avatar-hair-2)", "var(--avatar-hair-3)", "var(--avatar-hair-gray)"];
const JERSEY = ["var(--avatar-jersey-1)", "var(--avatar-jersey-2)", "var(--avatar-jersey-3)", "var(--avatar-jersey-4)", "var(--avatar-jersey-5)"];
const CAP = "var(--avatar-cap)";
const CAP_BRIM = "var(--avatar-cap-brim)";
const HELMET = "var(--avatar-helmet)";
const MASK = "var(--avatar-mask)";
const LINE = "var(--avatar-line)";

function hashSeed(seed: string): number {
  let hash = 0x811c9dc5;
  for (let index = 0; index < seed.length; index += 1) {
    hash ^= seed.charCodeAt(index);
    hash = Math.imul(hash, 0x01000193);
  }
  return hash >>> 0;
}

interface Props {
  seed: string;
  role?: AvatarRole;
  width?: number;
  height?: number;
  className?: string;
}

export function AvatarFace({ seed, role = "player", width = 58, height = 76, className }: Props) {
  const hash = hashSeed(`${role}:${seed}`);
  const pick = (shift: number, count: number) => (hash >>> shift) % count;

  const skin = SKIN[pick(0, SKIN.length)];
  const agedCoach = role === "coach" && pick(21, 3) > 0;
  const hairColor = agedCoach ? HAIR[3] : HAIR[pick(3, 3)];
  const jersey = JERSEY[pick(6, JERSEY.length)];
  const faceShape = pick(9, 3);
  const eyeStyle = pick(11, 3);
  const browStyle = pick(13, 3);
  const mouthStyle = pick(15, 4);
  const hairStyle = pick(17, 5);
  const cheekMark = pick(19, 4) === 0;

  const faceRx = faceShape === 0 ? 13.5 : faceShape === 1 ? 12.2 : 14.5;
  const faceRy = faceShape === 1 ? 15.8 : 14.6;
  const showHat = role === "player" || role === "rival" || (role === "coach" && pick(20, 2) === 0);

  const eyes = eyeStyle === 0
    ? <g fill={LINE}><circle cx="23" cy="34" r="1.7" /><circle cx="35" cy="34" r="1.7" /></g>
    : eyeStyle === 1
      ? <g stroke={LINE} strokeWidth="1.7" strokeLinecap="round"><line x1="21" y1="34" x2="25" y2="34" /><line x1="33" y1="34" x2="37" y2="34" /></g>
      : <g fill={LINE}><circle cx="23" cy="34" r="2.1" /><circle cx="35" cy="34" r="2.1" /><circle cx="23.7" cy="33.3" r="0.6" fill="var(--avatar-highlight)" /><circle cx="35.7" cy="33.3" r="0.6" fill="var(--avatar-highlight)" /></g>;

  const brows = browStyle === 0
    ? <g stroke={LINE} strokeWidth="1.6" strokeLinecap="round"><line x1="20.5" y1="29.5" x2="25.5" y2="29" /><line x1="32.5" y1="29" x2="37.5" y2="29.5" /></g>
    : browStyle === 1
      ? <g stroke={LINE} strokeWidth="1.9" strokeLinecap="round"><line x1="20.5" y1="30" x2="25.5" y2="28.6" /><line x1="32.5" y1="28.6" x2="37.5" y2="30" /></g>
      : <g stroke={LINE} strokeWidth="1.4" strokeLinecap="round"><path d="M20.5 29.6 Q23 28.2 25.5 29.4" fill="none" /><path d="M32.5 29.4 Q35 28.2 37.5 29.6" fill="none" /></g>;

  const mouth = mouthStyle === 0
    ? <path d="M25.5 43.5 Q29 45.2 32.5 43.5" stroke={LINE} strokeWidth="1.5" fill="none" strokeLinecap="round" />
    : mouthStyle === 1
      ? <line x1="25.5" y1="44" x2="32.5" y2="44" stroke={LINE} strokeWidth="1.6" strokeLinecap="round" />
      : mouthStyle === 2
        ? <path d="M25.5 44.5 Q29 42.8 32.5 44.5" stroke={LINE} strokeWidth="1.5" fill="none" strokeLinecap="round" />
        : <ellipse cx="29" cy="44" rx="2.6" ry="1.6" fill={LINE} />;

  const hair = (() => {
    if (showHat) return null;
    switch (hairStyle) {
      case 0: return <path d={`M${29 - faceRx} 32 Q${29 - faceRx} ${30 - faceRy} 29 ${30 - faceRy} Q${29 + faceRx} ${30 - faceRy} ${29 + faceRx} 32 L${29 + faceRx} 29 Q29 ${24 - faceRy} ${29 - faceRx} 29 Z`} fill={hairColor} />;
      case 1: return <path d={`M${29 - faceRx - 1} 33 Q${29 - faceRx} ${28 - faceRy} 33 ${28.5 - faceRy} Q${29 + faceRx + 1} ${30 - faceRy} ${29 + faceRx + 1} 33 Q${29 + faceRx - 4} ${31 - faceRy} 24 ${31 - faceRy} Q${29 - faceRx + 1} ${32 - faceRy} ${29 - faceRx - 1} 33 Z`} fill={hairColor} />;
      case 2: return <g fill={hairColor}><circle cx="20" cy="24" r="4.6" /><circle cx="26" cy="21.5" r="4.9" /><circle cx="32.5" cy="21.5" r="4.9" /><circle cx="38" cy="24" r="4.6" /></g>;
      case 3: return <path d={`M${29 - faceRx} 30 Q29 ${26.5 - faceRy} ${29 + faceRx} 30 L${29 + faceRx} 27.5 Q29 ${23.8 - faceRy} ${29 - faceRx} 27.5 Z`} fill={hairColor} opacity="0.85" />;
      default: return <path d={`M${29 - faceRx - 0.5} 34 Q${29 - faceRx - 0.5} ${26 - faceRy} 29 ${26 - faceRy} Q${29 + faceRx + 0.5} ${26 - faceRy} ${29 + faceRx + 0.5} 34 L${29 + faceRx - 3} 30 Q29 ${29.5 - faceRy} ${29 - faceRx + 3} 30 Z`} fill={hairColor} />;
    }
  })();

  return <svg
    className={["avatar-face", className].filter(Boolean).join(" ")}
    viewBox="0 0 58 76"
    width={width}
    height={height}
    role="img"
    aria-hidden="true"
    focusable="false"
  >
    <rect x="0" y="0" width="58" height="76" rx="9" fill={jersey} opacity="0.28" />
    {/* 어깨·유니폼 */}
    <path d="M9 76 Q9 58 29 57 Q49 58 49 76 Z" fill={jersey} />
    <path d="M25 60 L29 66 L33 60 L33 57 L25 57 Z" fill={skin} opacity="0.9" />
    {/* 목 */}
    <rect x="25.4" y="49" width="7.2" height="9" rx="3" fill={skin} />
    {/* 얼굴 */}
    <ellipse cx="29" cy="36" rx={faceRx} ry={faceRy} fill={skin} />
    {/* 귀 */}
    <circle cx={29 - faceRx} cy="36.5" r="2.4" fill={skin} />
    <circle cx={29 + faceRx} cy="36.5" r="2.4" fill={skin} />
    {hair}
    {agedCoach ? <path d="M22 40.5 Q23.4 41.6 24.8 40.5" stroke={LINE} strokeWidth="0.9" fill="none" opacity="0.55" /> : null}
    {cheekMark ? <circle cx={29 + faceRx - 4} cy="40" r="0.8" fill={LINE} opacity="0.45" /> : null}
    {brows}
    {eyes}
    <path d="M28.4 36.5 Q27.7 38.8 28.6 39.6" stroke={LINE} strokeWidth="1.1" fill="none" strokeLinecap="round" opacity="0.7" />
    {mouth}
    {/* 역할 소품 */}
    {role === "rival" ? <g>
      <path d={`M${29 - faceRx - 1.5} 30 Q29 ${18.5 - faceRy + 8} ${29 + faceRx + 1.5} 30 L${29 + faceRx + 1.5} 26 Q29 ${13.5 - faceRy + 8} ${29 - faceRx - 1.5} 26 Z`} fill={HELMET} />
      <ellipse cx="29" cy={27.4 - faceRy + 8} rx={faceRx + 1.6} ry="4.6" fill={HELMET} />
      <rect x={29 + faceRx - 3} y="29" width="7.5" height="3.4" rx="1.7" fill={HELMET} />
    </g> : null}
    {showHat && role !== "rival" ? <g>
      <ellipse cx="29" cy={28.2 - faceRy + 8} rx={faceRx + 0.9} ry="5.2" fill={CAP} />
      <path d={`M${29 - faceRx - 0.9} ${28.6 - faceRy + 8} Q29 ${21 - faceRy + 8} ${29 + faceRx + 0.9} ${28.6 - faceRy + 8} L${29 + faceRx + 0.9} ${30.6 - faceRy + 8} L${29 - faceRx - 0.9} ${30.6 - faceRy + 8} Z`} fill={CAP} />
      <rect x="20" y={29.4 - faceRy + 8} width="18" height="2.6" rx="1.3" fill={CAP_BRIM} />
    </g> : null}
    {role === "catcher" ? <g>
      <rect x={29 - faceRx - 1} y="22.5" width={faceRx * 2 + 2} height="3" rx="1.5" fill={MASK} />
      <path d="M20 17.5 Q29 12.5 38 17.5 L38 23 L20 23 Z" fill={MASK} opacity="0.9" />
      <g stroke={LINE} strokeWidth="0.8" opacity="0.6"><line x1="23" y1="15.5" x2="23" y2="22.5" /><line x1="29" y1="14" x2="29" y2="22.5" /><line x1="35" y1="15.5" x2="35" y2="22.5" /></g>
    </g> : null}
    {role === "coach" && !showHat ? <path d="M17 57 L23 52 L29 58 L35 52 L41 57 L41 62 L17 62 Z" fill={jersey} stroke={LINE} strokeWidth="0.8" opacity="0.95" /> : null}
  </svg>;
}
