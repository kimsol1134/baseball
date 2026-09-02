import type { Metadata } from "next";
import Image from "next/image";
import { AppStoreButton } from "@/components/AppStoreButton";
import { APP_STORE_ID, STOREFRONT_NEUTRAL_APP_STORE_URL } from "@/lib/links";

type ChallengePageProps = {
  params: Promise<{ token: string }>;
};

function challengeSchemeURL(token: string) {
  return `yagurebirth://challenge/${encodeURIComponent(token)}`;
}

export async function generateMetadata({ params }: ChallengePageProps): Promise<Metadata> {
  const { token } = await params;
  const title = `같은 시드로 도전 · ${token}`;
  const description =
    "같은 시드로 누가 더 잘 키우나. 앱에서 도전을 열거나 App Store에서 설치하세요.";
  return {
    title,
    description,
    openGraph: {
      title,
      description,
      images: [
        {
          url: "/opengraph-image-v2.png",
          width: 1200,
          height: 630,
          alt: "야구 못하면 또 환생함 — 이번 생엔, 이름이 불릴까.",
        },
      ],
    },
    twitter: {
      card: "summary_large_image",
      title,
      description,
      images: ["/opengraph-image-v2.png"],
    },
  };
}

export default async function ChallengePage({ params }: ChallengePageProps) {
  const { token } = await params;
  const schemeHref = challengeSchemeURL(token);
  const storeHref = STOREFRONT_NEUTRAL_APP_STORE_URL;

  return (
    <main className="challenge-page">
      <a className="skip-link" href="#challenge-open">
        앱 열기로 건너뛰기
      </a>
      <header className="challenge-header">
        <a className="brand" href="/">
          <Image className="brand-icon" src="/icon.png" alt="" width={28} height={28} />
          <span>
            <small>야구 못하면</small>
            <strong>또 환생함</strong>
          </span>
        </a>
      </header>
      <section className="challenge-card" id="challenge-open">
        <p className="eyebrow">시드 도전</p>
        <h1>같은 시드로 누가 더 잘 키우나</h1>
        <p className="challenge-token" aria-label={`도전 코드 ${token}`}>
          {token}
        </p>
        <p className="section-description">
          앱이 있으면 바로 열고, 없으면 App Store에서 설치한 뒤 같은 코드로 시작하세요.
        </p>
        <div className="challenge-actions">
          <a className="button button-primary" href={schemeHref}>
            앱에서 도전 열기
          </a>
          <AppStoreButton href={storeHref} target="_blank" rel="noreferrer">
            App Store에서 받기
          </AppStoreButton>
        </div>
        <p className="challenge-store-id">App Store id{APP_STORE_ID}</p>
      </section>
    </main>
  );
}
