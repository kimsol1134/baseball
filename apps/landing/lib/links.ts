type SteamPlacement =
  | "header"
  | "hero"
  | "demo"
  | "promise"
  | "final";

function trackedUrl(rawUrl: string | undefined, content: string, campaign: string) {
  const value = rawUrl?.trim();

  if (!value) {
    return undefined;
  }

  try {
    const url = new URL(value);
    url.searchParams.set("utm_source", "official_site");
    url.searchParams.set("utm_medium", "web");
    url.searchParams.set("utm_campaign", campaign);
    url.searchParams.set("utm_content", content);
    return url.toString();
  } catch {
    return value;
  }
}

export function steamWishlistUrl(placement: SteamPlacement) {
  return (
    trackedUrl(process.env.NEXT_PUBLIC_STEAM_URL, placement, "steam_wishlist") ??
    "#steam"
  );
}

export function steamDemoUrl() {
  return (
    trackedUrl(process.env.NEXT_PUBLIC_STEAM_DEMO_URL, "demo_card", "steam_demo") ??
    "#steam"
  );
}

export function webTeaserUrl() {
  return process.env.NEXT_PUBLIC_WEB_TEASER_URL?.trim() || "#pitch";
}
