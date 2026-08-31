import type { Metadata } from "next";
import Image from "next/image";
import { AppStoreButton } from "@/components/AppStoreButton";
import { primaryCta } from "@/lib/links";

export const metadata: Metadata = {
  title: "Mound Reborn: Baseball Career",
  description:
    "Throw every important pitch. Build a high-school pitcher, chase the draft, and carry one legacy into the next career. Pay once. No ads.",
  alternates: {
    canonical: "/en",
    languages: { "ko-KR": "/", "en-US": "/en" },
  },
  openGraph: {
    locale: "en_US",
    url: "/en",
    title: "Mound Reborn: Baseball Career",
    description:
      "A premium baseball career game. You throw the pitch. Pay once. No ads or in-app purchases.",
  },
};

function EnglishCta({
  placement,
  withPrice = false,
  className = "",
}: {
  placement: Parameters<typeof primaryCta>[0];
  withPrice?: boolean;
  className?: string;
}) {
  const cta = primaryCta(placement, { withPrice, locale: "en" });
  return (
    <AppStoreButton className={className} href={cta.href} target="_blank" rel="noreferrer">
      {cta.label}
    </AppStoreButton>
  );
}

export default function EnglishHomePage() {
  const mobileCta = primaryCta("mobile", { withPrice: true, locale: "en" });

  return (
    <>
      <a className="skip-link" href="#main">
        Skip to content
      </a>

      <header className="site-header">
        <div className="header-inner">
          <a className="brand" href="/en" lang="en" aria-label="Mound Reborn home">
            <Image className="brand-icon" src="/icon.png" alt="" width={28} height={28} />
            <span>
              <small>Mound Reborn</small>
              <strong>Baseball Career</strong>
            </span>
          </a>
          <nav className="desktop-nav" aria-label="Primary">
            <a href="#play">Play</a>
            <a href="#buy">Buy</a>
            <a href="/en/support">Support</a>
            <a href="/" hrefLang="ko" lang="ko">
              한국어
            </a>
          </nav>
          <EnglishCta className="header-cta" placement="header" />
        </div>
      </header>

      <main id="main" lang="en">
        <section className="hero" id="top">
          <Image
            className="hero-art"
            src="/hero-key-art.png"
            alt="A high-school pitcher on the mound at night"
            fill
            priority
            sizes="100vw"
          />
          <div className="hero-overlay" />
          <div className="hero-content shell">
            <div className="hero-copy">
              <p className="eyebrow">Premium baseball career · iPhone</p>
              <h1>
                You throw
                <br />
                <span>every important pitch.</span>
              </h1>
              <p className="hero-description">
                <strong>Build a pitcher through three years of high school.</strong>
                <br />
                Chase the draft. If your name is not called, carry one legacy into the next career.
                <br />
                Pay once. No ads. No in-app purchases.
              </p>
              <div className="hero-actions">
                <EnglishCta placement="hero" withPrice />
                <a className="button button-secondary" href="#play">
                  See how a pitch works
                </a>
              </div>
              <p className="release-status">
                $2.99 on the App Store. One purchase includes high school, the draft, a professional
                career, retirement, and rebirth.
              </p>
              <ul className="release-facts" aria-label="Product facts">
                <li>iPhone · iOS 17+</li>
                <li>Pay once</li>
                <li>No ads or IAP</li>
                <li>Playable offline</li>
              </ul>
            </div>
          </div>
        </section>

        <section className="section" id="play">
          <div className="shell">
            <div className="section-heading">
              <p className="eyebrow">The core</p>
              <h2>Call the pitch. Pick your spot. Finish the throw.</h2>
              <p className="section-description">
                This is not a GM sim you watch. On the at-bats that change a career, you choose the
                pitch and location, then release the ball yourself.
              </p>
            </div>
            <div className="screens-grid">
              <figure className="screen-card">
                <Image
                  src="/ios-pitch.png"
                  alt="Pitch selection and release slider"
                  width={660}
                  height={1434}
                />
                <figcaption>Choose the pitch, then throw it.</figcaption>
              </figure>
              <figure className="screen-card">
                <Image
                  src="/ios-result.png"
                  alt="Strike-zone result after a thrown pitch"
                  width={660}
                  height={1434}
                />
                <figcaption>See the result land in the zone.</figcaption>
              </figure>
            </div>
          </div>
        </section>

        <section className="section" id="buy">
          <div className="shell">
            <div className="section-heading is-centered">
              <p className="eyebrow">Get the game</p>
              <h2>Mound Reborn on the App Store</h2>
              <p className="section-description">
                English, Korean, and Japanese in one paid app. Original fictional baseball world —
                not affiliated with any real league, club, or player.
              </p>
            </div>
            <div className="hero-actions" style={{ justifyContent: "center" }}>
              <EnglishCta placement="final" withPrice />
            </div>
          </div>
        </section>
      </main>

      <div className="mobile-cta">
        <AppStoreButton href={mobileCta.href} target="_blank" rel="noreferrer">
          {mobileCta.label}
        </AppStoreButton>
      </div>
    </>
  );
}
