import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "개인정보 처리방침",
  description:
    "야구 못하면 또 환생함이 어떤 정보를 다루는지 밝힙니다. 이 게임은 개인정보를 수집하지 않습니다.",
  alternates: { canonical: "/privacy" },
};

/// App Store는 수집하는 정보가 없어도 개인정보 처리방침 URL을 필수로 요구한다.
/// 이 페이지는 앱이 실제로 하는 일만 적는다 — 없는 수집을 있는 것처럼 쓰지 않는다.
const 최종수정일 = "2026년 7월 26일";

const 섹션 = [
  {
    제목: "수집하는 개인정보",
    본문: [
      "없습니다. 이 게임은 계정을 만들지 않고, 이름·이메일·전화번호·위치·연락처·사진을 요구하지 않습니다.",
      "광고 식별자를 읽지 않으며 광고 네트워크나 분석 도구를 넣지 않았습니다. 사용자를 추적하지 않습니다.",
    ],
  },
  {
    제목: "기기에 저장되는 것",
    본문: [
      "커리어 진행 상황(선수 능력, 경기 기록, 회차, 달성한 업적)은 기기 안에만 저장됩니다.",
      "설정에서 소리·진동·자동 릴리스를 끄고 켠 값도 기기 안에 남습니다.",
      "이 데이터는 저희에게 전송되지 않습니다. 앱을 삭제하면 함께 지워집니다.",
    ],
  },
  {
    제목: "iCloud 동기화",
    본문: [
      "같은 Apple 계정의 다른 기기에서 이어서 하기 위해, 진행 상황을 Apple의 iCloud 키-값 저장소에 올립니다.",
      "이 데이터는 사용자의 iCloud 계정에 속하며 저희는 접근할 수 없습니다. 기기의 iCloud 설정에서 끌 수 있습니다.",
    ],
  },
  {
    제목: "Game Center",
    본문: [
      "업적과 순위표를 위해 Apple의 Game Center를 사용합니다. 이 기능은 Apple이 운영하며 별명과 점수 표시는 Apple의 정책을 따릅니다.",
      "Game Center에 로그인하지 않아도 게임은 그대로 동작하고, 달성 기록은 기기 안에 남습니다.",
    ],
  },
  {
    제목: "어린이",
    본문: [
      "이 게임은 개인정보를 수집하지 않으므로 어린이의 개인정보도 수집하지 않습니다.",
    ],
  },
  {
    제목: "방침이 바뀔 때",
    본문: [
      "수집하는 정보가 생기면 이 페이지를 먼저 고치고, 앱 업데이트 설명에 함께 알립니다.",
    ],
  },
];

export default function PrivacyPage() {
  return (
    <main className="legal">
      <header className="legal-head">
        <p className="legal-kicker">개인정보 처리방침</p>
        <h1>이 게임은 개인정보를 수집하지 않습니다</h1>
        <p className="legal-lede">
          야구 못하면 또 환생함(iOS)에 적용됩니다. 최종 수정일 {최종수정일}.
        </p>
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
          <h2>문의</h2>
          <p>
            이 방침에 관해 궁금한 점이 있으면{" "}
            <a href="mailto:kimsol1134@gmail.com">kimsol1134@gmail.com</a>으로 알려 주세요.
          </p>
        </section>
      </div>
    </main>
  );
}
