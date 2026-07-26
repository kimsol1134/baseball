import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";
import "./globals.css";

const siteUrl = process.env.NEXT_PUBLIC_SITE_URL || "http://localhost:3000";

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: {
    default: "야구 못하면 또 환생함 — 기억을 이어 드래프트를 돌파하라",
    template: "%s | 야구 못하면 또 환생함",
  },
  description:
    "승부처의 공을 한 구씩 직접 던지는 아이폰 야구 육성 게임. 고교 3년과 드래프트, 기억을 안고 다시 태어나는 회차, 프로 은퇴까지 한 번의 구매에 모두 담았습니다.",
  applicationName: "야구 못하면 또 환생함",
  keywords: [
    "야구 게임",
    "야구 육성",
    "투수 육성",
    "아이폰 야구 게임",
    "유료 게임",
    "인디 게임",
  ],
  alternates: {
    canonical: "/",
  },
  openGraph: {
    type: "website",
    locale: "ko_KR",
    url: "/",
    siteName: "야구 못하면 또 환생함",
    title: "이번 생엔, 이름이 불릴까.",
    description:
      "실패한 삶의 기억을 이어 드래프트를 돌파하고, 지명된 한 선수로 프로 은퇴까지 살아가는 데이터 야구 로그라이트 RPG.",
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
    title: "야구 못하면 또 환생함",
    description: "기억을 이어 드래프트를 돌파하는 데이터 야구 로그라이트 RPG.",
    images: ["/opengraph-image-v2.png"],
  },
  icons: {
    icon: "/icon.png",
    apple: "/icon.png",
  },
};

export const viewport: Viewport = {
  colorScheme: "dark",
  themeColor: "#080D0B",
  width: "device-width",
  initialScale: 1,
};

export default function RootLayout({ children }: Readonly<{ children: ReactNode }>) {
  return (
    <html lang="ko">
      <body>{children}</body>
    </html>
  );
}
