import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Support — Mound Reborn",
  description: "Support information for Mound Reborn on iOS.",
  alternates: {
    canonical: "/en/support",
    languages: { "ko-KR": "/support", "en-US": "/en/support" },
  },
};

const sections = [
  {
    title: "Start here",
    paragraphs: [
      "Mound Reborn can be played without an internet connection. If the screen stops responding or a problem occurs just after saving, fully close the app and open it again. The game is designed to resume from its most recent completed save point.",
      "If reminders do not arrive, check both the app's notification permission in iOS Settings and the reminder option inside the game.",
    ],
  },
  {
    title: "Language",
    paragraphs: [
      "The iOS app supports English and Korean. To change languages, open iOS Settings, select Mound Reborn, choose Language, and then reopen the app.",
      "Both languages use the same career and save data. Switching languages does not create a new save slot or change game results.",
    ],
  },
  {
    title: "Saves and changing devices",
    paragraphs: [
      "Your iOS progress is stored on your device and may also be synchronized through iCloud. To continue on another device, use the same Apple Account and make sure iCloud is enabled for the app.",
      "Before resetting game data or deleting the app, confirm that any progress you want to keep is available on the intended device. Locally deleted data may not be recoverable.",
    ],
  },
  {
    title: "Purchases and refunds",
    paragraphs: [
      "Mound Reborn is a one-time paid app with no in-app purchases. Purchases and refunds follow Apple's App Store process.",
      "To request a refund or review your purchase history, visit reportaproblem.apple.com while signed in with the Apple Account used for the purchase.",
    ],
  },
  {
    title: "Report a problem",
    paragraphs: [
      "Email us with your iPhone model, iOS version, app version and build, selected app language, and the steps that led to the problem. A screenshot can help us identify the cause.",
      "Do not send a player name, original seed, save file, contact information, or other sensitive information. We will ask only for the minimum information needed to investigate.",
    ],
  },
];

export default function EnglishSupportPage() {
  return (
    <main className="legal" lang="en">
      <header className="legal-head">
        <p className="legal-kicker">Support</p>
        <h1>We're here to help with Mound Reborn</h1>
        <p className="legal-lede">Support information for the English iOS edition.</p>
        <p><a href="/support" lang="ko">한국어로 보기</a></p>
      </header>

      <div className="legal-body">
        {sections.map((section) => (
          <section key={section.title}>
            <h2>{section.title}</h2>
            {section.paragraphs.map((paragraph) => (
              <p key={paragraph}>{paragraph}</p>
            ))}
          </section>
        ))}

        <section>
          <h2>Email support</h2>
          <p><a href="mailto:kimsol1134@gmail.com">kimsol1134@gmail.com</a></p>
        </section>

        <section>
          <h2>Privacy</h2>
          <p>
            Learn how support requests and product-quality information are handled in our{" "}
            <a href="/en/privacy">Privacy Policy</a>.
          </p>
        </section>
      </div>
    </main>
  );
}
