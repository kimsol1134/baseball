import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "고객지원",
  description: "야구 못하면 또 환생함의 iOS 및 Android 고객지원 안내입니다.",
  alternates: {
    canonical: "/support",
    languages: { "ko-KR": "/support", "en-US": "/en/support" },
  },
};

const 섹션 = [
  {
    제목: "먼저 확인해 주세요",
    본문: [
      "게임은 인터넷 연결 없이도 진행할 수 있습니다. 화면이 멈추거나 저장 직후 문제가 생겼다면 앱을 완전히 종료한 뒤 다시 열어 주세요. 저장이 끝난 시점부터 안전하게 복구하도록 설계되어 있습니다.",
      "알림이 오지 않으면 기기의 앱 알림 권한과 앱 안의 알림 설정을 함께 확인해 주세요. Android에서 권한을 거부한 뒤에는 시스템 설정에서 직접 허용해야 할 수 있습니다.",
    ],
  },
  {
    제목: "저장과 기기 변경",
    본문: [
      "iOS 진행은 기기와 iCloud에 저장될 수 있으며, 같은 Apple 계정과 iCloud 설정을 사용하면 다른 기기에서 이어서 할 수 있습니다.",
      "Android 진행은 현재 기기 안에만 저장됩니다. 앱 삭제나 저장 데이터 초기화 뒤에는 복구할 수 없으므로 먼저 필요한 기록을 확인해 주세요.",
    ],
  },
  {
    제목: "구매와 환불",
    본문: [
      "iOS 구매와 환불은 Apple의 App Store 절차를 따릅니다. reportaproblem.apple.com에서 구매 내역을 선택해 요청할 수 있습니다.",
      "Android 구매와 환불은 Google Play의 주문 및 환불 정책을 따릅니다. Play 스토어의 결제 및 정기 결제 메뉴에서 주문 내역을 확인해 주세요.",
    ],
  },
  {
    제목: "문제 제보",
    본문: [
      "아래 이메일에 사용 플랫폼(iOS 또는 Android), 기기 모델, 운영체제 버전, 앱 버전과 문제가 생긴 순서를 적어 보내 주세요. 화면 캡처가 있으면 원인 확인에 도움이 됩니다.",
      "선수 이름, 원본 시드, 저장 파일, 연락처나 그 밖의 민감한 정보는 보내지 마세요. 답변에 필요한 최소 정보만 확인합니다.",
    ],
  },
];

export default function SupportPage() {
  return (
    <main className="legal">
      <header className="legal-head">
        <p className="legal-kicker">고객지원</p>
        <h1>게임 이용을 도와드릴게요</h1>
        <p className="legal-lede">야구 못하면 또 환생함의 iOS 및 Android 지원 안내입니다.</p>
        <p><a href="/en/support" lang="en">Read in English</a></p>
      </header>

      <div className="legal-body">
        {섹션.map((항목) => (
          <section key={항목.제목}>
            <h2>{항목.제목}</h2>
            {항목.본문.map((문단) => (
              <p key={문단}>{문단}</p>
            ))}
          </section>
        ))}

        <section>
          <h2>이메일 문의</h2>
          <p>
            <a href="mailto:kimsol1134@gmail.com">kimsol1134@gmail.com</a>
          </p>
        </section>

        <section>
          <h2>개인정보 안내</h2>
          <p>
            문의와 앱 품질 정보의 처리 방식은 <a href="/privacy">개인정보 처리방침</a>에서 확인할 수 있습니다.
          </p>
        </section>
      </div>
    </main>
  );
}
