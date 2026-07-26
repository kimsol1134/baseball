type LinkPlacement = "header" | "hero" | "detail" | "promise" | "final" | "mobile";

/// App Store 앱 페이지. 심사 통과 전에도 Apple ID가 정해져 있어 주소는 확정이다.
const APP_STORE_ID = "6794754217";
const DEFAULT_APP_STORE_URL = `https://apps.apple.com/kr/app/id${APP_STORE_ID}`;

function trackedUrl(rawUrl: string, content: string, campaign: string) {
  try {
    const url = new URL(rawUrl);
    // App Store는 Apple의 캠페인 파라미터(pt·ct)만 집계한다. 어디를 눌러 들어왔는지 남긴다.
    url.searchParams.set("ct", content);
    url.searchParams.set("pt", campaign);
    url.searchParams.set("mt", "8");
    return url.toString();
  } catch {
    return rawUrl;
  }
}

export function appStoreUrl(placement: LinkPlacement) {
  const base = process.env.NEXT_PUBLIC_APP_STORE_URL?.trim() || DEFAULT_APP_STORE_URL;
  return trackedUrl(base, placement, "official_site");
}

/// 화면의 주 행동. 목적지는 언제나 App Store 앱 페이지다.
export function primaryCta(placement: LinkPlacement, options?: { withPrice?: boolean }) {
  return {
    href: appStoreUrl(placement),
    label: options?.withPrice ? "App Store에서 받기 · ₩3,300" : "App Store에서 받기",
    external: true,
  };
}

/// 설치 없이 판단 방식만 보여 주는 체험. 별도 주소가 없으면 이 페이지 안의 위젯으로 간다.
export function webTeaserUrl() {
  return process.env.NEXT_PUBLIC_WEB_TEASER_URL?.trim() || "#pitch-preview";
}

/// 체험 버튼 문구. 같은 페이지 안으로 스크롤할 뿐인데 "웹에서 시작"이라고 쓰면 가짜 버튼이 된다.
export function webTeaserLabel() {
  return process.env.NEXT_PUBLIC_WEB_TEASER_URL?.trim()
    ? "웹에서 한 타석 체험"
    : "이 페이지에서 한 타석 체험";
}
