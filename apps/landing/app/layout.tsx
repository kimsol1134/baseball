import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";
import "./globals.css";

const siteUrl = process.env.NEXT_PUBLIC_SITE_URL || "http://localhost:3000";

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: {
    default: "야구 못하면 또 환생함 — 한 선수의 전 생애를 플레이하다",
    template: "%s | 야구 못하면 또 환생함",
  },
  description:
    "고교 입학부터 프로 은퇴까지. 매 경기의 한 공과 관계, 성장의 선택이 한 선수의 커리어가 되는 싱글플레이 야구 RPG.",
  applicationName: "야구 못하면 또 환생함",
  keywords: [
    "야구 게임",
    "야구 RPG",
    "커리어 시뮬레이션",
    "Steam 게임",
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
    title: "3년 안에 지명받아라. 그리고 마지막 공까지.",
    description:
      "고교 입학부터 프로 은퇴까지, 한 선수의 전 생애를 플레이하는 야구 커리어 RPG.",
    images: [
      {
        url: "/opengraph-image.png",
        width: 1200,
        height: 630,
        alt: "야구 못하면 또 환생함 Steam 출시 예정",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: "야구 못하면 또 환생함",
    description: "한 선수의 전 생애를 플레이하는 야구 커리어 RPG.",
    images: ["/opengraph-image.png"],
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
