/** Foundation cannot safely mix positional (%1$lld) and sequential (%@) arguments. */
export function hasMixedPlaceholderAddressing(value) {
  const tokens = [...value.matchAll(/%%|%(?:(\d+)\$)?[-+ #0]*\d*(?:\.\d+)?l{0,2}[@diufFeEgG]/gu)]
    .filter((match) => match[0] !== "%%");
  return tokens.some((match) => match[1]) && tokens.some((match) => !match[1]);
}
