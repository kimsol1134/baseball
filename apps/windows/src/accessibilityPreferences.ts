export const FONT_SCALES = [1, 1.15, 1.3] as const;

export function parseFontScale(storedValue: string | null | undefined): number {
  const parsed = Number(storedValue);
  return FONT_SCALES.includes(parsed as (typeof FONT_SCALES)[number]) ? parsed : 1;
}

export function nextFontScale(current: number): number {
  const index = FONT_SCALES.indexOf(current as (typeof FONT_SCALES)[number]);
  return FONT_SCALES[(index + 1 + FONT_SCALES.length) % FONT_SCALES.length];
}
