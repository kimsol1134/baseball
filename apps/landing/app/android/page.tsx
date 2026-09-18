import type { Metadata } from "next";
import Image from "next/image";
import { googlePlayUrl } from "@/lib/links";

export const metadata: Metadata = {
  title: "안드로이드 야구 게임 · 야구 못하면 또 환생함: 투수키우기",
  description: "투구 슬라이더로 직접 던지고, 훈련하고, 환생하는 투수 성장 RPG. Google Play 4,400원. 광고·인앱 구매 없이 고교부터 프로까지.",
  alternates: { canonical: "/android" },
  openGraph: {
    url: "/android", title: "안드로이드에서도, 내가 직접 던진다.",
    description: "야구 못하면 또 환생함: 투수키우기. 4,400원 한 번 구매로 고교부터 프로까지. 광고·추가 결제 없음.",
  },
};

const screenshots = [
  ["01", "한 구의 승부, 내 손끝으로", "구종과 코스를 고르고 투구 슬라이더의 타이밍을 맞춥니다."],
  ["02", "내가 원하는 투수로 키우기", "구위, 제구, 변화구. 훈련과 회복을 선택해 다음 등판을 준비합니다."],
  ["03", "끝난 커리어는 다음 생의 시작", "대표 유산을 이어받아 다시 도전합니다. 이번엔 다른 투수로."],
] as const;
const faqs = [
  ["어떤 야구 게임인가요?", "한 명의 투수를 키우는 싱글플레이 야구 RPG입니다. 고교 훈련과 등판, 드래프트, 가상 구단의 프로 커리어와 환생을 즐깁니다. 중요한 승부에서는 직접 타이밍을 맞춰 공을 던집니다."],
  ["4,400원 외에 결제가 있나요?", "광고와 인앱 구매가 없는 유료 완전판입니다. 한 번 구매로 고교부터 프로 커리어까지 즐길 수 있습니다. 한국 Google Play 기준 4,400원이며 최종 가격은 스토어에서 확인해 주세요."],
  ["야구를 잘 몰라도 할 수 있나요?", "포수의 사인을 참고해 구종과 코스를 고를 수 있습니다. 직접 던지면서 제구와 구종의 차이를 익히고, 훈련으로 투수를 성장시켜 보세요."],
  ["인터넷이나 게임 계정이 필요한가요?", "별도 게임 계정 없이 오프라인 중심으로 즐길 수 있습니다. 구매와 다운로드에는 Google Play 계정과 인터넷 연결이 필요합니다."],
  ["내 Android 기기에서 되나요?", "Google Play 구매 페이지에서 내 기기의 설치 가능 여부를 확인할 수 있습니다. 이 페이지의 영상과 스크린샷은 실제 Android 앱에서 촬영했습니다."],
  ["저장과 환불은 어떻게 되나요?", "진행은 현재 Android 기기에 저장됩니다. 앱을 삭제하거나 데이터를 초기화하기 전에 주의해 주세요. iPhone과 세이브를 공유하지 않습니다. 구매 및 환불은 Google Play 주문 내역과 환불 절차를 따릅니다."],
] as const;

function Buy({ placement, compact = false }: { placement: "header" | "hero" | "final" | "mobile"; compact?: boolean }) {
  return <a className="button button-primary" href={googlePlayUrl(placement, "ko", "android_launch_202609")}>
    {compact ? "Google Play · ₩4,400" : "Google Play에서 구매 · ₩4,400"}<span aria-hidden="true">↗</span>
  </a>;
}

export default function AndroidPage() {
  return <div className="android-page">
    <a className="skip-link" href="#main">본문으로 바로가기</a>
    <header className="android-header shell">
      <a href="/" className="android-brand"><Image src="/icon.png" alt="" width={36} height={36} /><span>야구 못하면<br /><strong>또 환생함</strong></span></a>
      <a href="#play" className="android-header-link">실제 플레이 보기 ↓</a>
      <Buy placement="header" compact />
    </header>
    <main id="main">
      <section className="android-hero shell">
        <div className="android-copy">
          <p className="eyebrow">GOOGLE PLAY 출시 · 투수 성장 RPG</p>
          <h1>답답해서<br /><em>내가 던진다.</em></h1>
          <p className="android-lede">구종은 내 판단으로.<br />한 구는 내 손끝으로.<br />다음 야구 인생도, 내 선택으로.</p>
          <p className="android-intro">직접 던지고, 훈련하고, 환생하세요.<br />고교부터 프로까지 한 투수의 야구 인생을 키웁니다.</p>
          <Buy placement="hero" />
          <p className="android-value">한 번 구매로 전부 · 광고 없음 · 추가 결제 없음</p>
          <a className="android-text-link" href="#play">구매 전에 18초 실제 플레이 보기 ↓</a>
        </div>
        <div className="android-video" id="play">
          <video controls playsInline preload="none" poster="/android/01.png" width={1080} height={1920} aria-label="Android 실제 투구, 성장, 환생 플레이 영상 18초">
            <source src="/android/gameplay.mp4" type="video/mp4" />
            영상을 재생할 수 없다면 아래 실제 플레이 화면을 확인해 주세요.
          </video>
          <p>실제 Android 플레이 · 18초 · 소리 있음</p>
        </div>
      </section>
      <section className="android-features shell" aria-label="세 가지 플레이">
        {screenshots.map(([id, title, text]) => <article key={id}>
          <span className="eyebrow">{id}</span><h2>{title}</h2><p>{text}</p>
          <Image src={`/android/${id}.png`} alt={`${title}. 실제 Android 앱 화면`} width={1080} height={1920} sizes="(max-width: 700px) 90vw, 30vw" />
        </article>)}
      </section>
      <section className="android-journey shell">
        <p className="eyebrow">한 번 구매로 이어지는 커리어</p>
        <h2>고교 마운드에서,<br />프로의 마지막 공까지.</h2>
        <p>훈련과 회복 → 고교 등판 → 드래프트 → 프로 계약과 시즌 → 기록과 유산</p>
        <p>이번 커리어가 뜻대로 되지 않아도, 남긴 유산으로 다시 마운드에 오릅니다.</p>
      </section>
      <section className="shell faq-shell android-faq" id="faq">
        <h2>구매 전에 궁금한 점</h2>
        <div className="faq-list">{faqs.map(([question, answer], i) => <details key={question} open={i === 0}>
          <summary><span>{String(i + 1).padStart(2, "0")}</span>{question}<i aria-hidden="true">+</i></summary><p>{answer}</p>
        </details>)}</div>
      </section>
      <section className="android-final shell">
        <p className="eyebrow">야구 못하면 또 환생함: 투수키우기</p><h2>이번엔 내가,<br />마운드에 설 차례.</h2>
        <Buy placement="final" /><p>₩4,400 · 광고·인앱 구매 없는 완전판</p>
      </section>
    </main>
    <footer className="android-footer shell"><p>한국 야구의 지역 정서에서 영감을 받은 독자적인 가상 세계입니다.<br />실존 리그·구단·선수와 공식적인 관련이 없습니다.</p>
      <nav aria-label="지원"><a href="/support">고객지원</a><a href="/privacy">개인정보 처리방침</a><a href="/">iPhone 및 전체 소개</a></nav>
    </footer>
    <div className="android-sticky"><Buy placement="mobile" compact /></div>
    <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify({
      "@context": "https://schema.org", "@type": "SoftwareApplication", name: "야구 못하면 또 환생함: 투수키우기",
      operatingSystem: "Android", applicationCategory: "GameApplication", url: "https://baseball-reincarnation.vercel.app/android",
      image: "https://baseball-reincarnation.vercel.app/icon.png",
      offers: { "@type": "Offer", price: "4400", priceCurrency: "KRW", url: googlePlayUrl("hero", "ko", "android_launch_202609") },
    }) }} />
  </div>;
}
