import { AppStoreButton } from "./AppStoreButton";
import { googlePlayUrl, primaryCta, type LinkPlacement, type StorefrontLocale } from "@/lib/links";

export function StoreButtons({ placement, withPrice = false, locale = "ko", className = "" }: {
  placement: LinkPlacement; withPrice?: boolean; locale?: StorefrontLocale; className?: string;
}) {
  const apple = primaryCta(placement, { withPrice, locale });
  return <div className={`store-buttons ${className}`} aria-label={locale === "ko" ? "구매할 스토어 선택" : "Choose your store"}>
    <AppStoreButton href={googlePlayUrl(placement, locale)}>
      {locale === "ko" ? `Google Play${withPrice ? " · ₩4,400" : ""}` : "Get on Google Play"}
    </AppStoreButton>
    <AppStoreButton variant="secondary" href={apple.href}>{apple.label}</AppStoreButton>
  </div>;
}
