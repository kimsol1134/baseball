import Image from "next/image";
import { PitchDecision } from "@/components/PitchDecision";
import { AppStoreButton, AppStoreMark } from "@/components/AppStoreButton";
import { primaryCta, webTeaserLabel, webTeaserUrl } from "@/lib/links";

const memories = [
  ["손끝의 기억", "변화구 움직임 상승 · 체력 소폭 감소"],
  ["포수의 노트", "제구와 빗맞은 타구 유도 증가"],
  ["실패의 스코어북", "부족했던 승부를 다음 삶의 정보로"],
] as const;

const proSteps = [
  ["01", "신인 계약", "지명 구단의 육성 계획을 확인합니다."],
  ["02", "2군 경쟁", "보직과 첫 기회를 직접 증명합니다."],
  ["03", "1군 콜업", "가득 찬 관중석 앞에서 다시 던집니다."],
  ["04", "보직 변화", "선발·불펜·마무리의 갈림길을 만납니다."],
  ["05", "군 복무·FA", "커리어를 바꾸는 오프시즌을 선택합니다."],
  ["06", "은퇴", "통산 기록과 마지막 공을 남깁니다."],
] as const;

const faqItems = [
  {
    question: "야구 못하면 또 환생함은 어떤 게임인가요?",
    answer:
      "고교 야구 인생을 반복하며 기억을 쌓아 드래프트를 돌파하고, 지명된 한 선수로 프로 은퇴까지 살아가는 싱글플레이 야구 육성 게임입니다. 모든 경기를 치르지 않고, 결과를 바꿀 수 있는 승부처에서 한 구씩 직접 던집니다.",
  },
  {
    question: "공은 어떻게 던지나요?",
    answer:
      "구종·코스·노림·힘 배분을 고른 뒤, 화면을 길게 눌러 와인드업하고 손가락을 끌어 조준한 다음 떼면 공이 나갑니다. 릴리스 타이밍과 조준이 좋을수록 노린 코스에 가깝게 들어갑니다. 타이밍 조작이 어렵다면 설정에서 자동 릴리스를 켜세요. 게임 진행에 손해가 없습니다.",
  },
  {
    question: "환생은 어떻게 진행되나요?",
    answer:
      "드래프트에서 지명받지 못하면 이번 삶의 기록을 돌아보고 기억 카드를 골라 다음 선수로 시작합니다. 기억은 다음 생의 시작 능력에 더해지지만 성공을 보장하지는 않습니다. 스스로 짐(카르마)을 지면 이번 생은 어려워지고 다음 생에 더 많이 남습니다.",
  },
  {
    question: "한 번 사면 전부 들어있나요?",
    answer:
      "선수 생성, 고교 3년, 드래프트와 기억 계승, 지명 후 최대 12시즌의 프로 커리어와 은퇴까지 한 번의 구매에 모두 포함합니다. 앱 내 구입도, 광고도, 에너지도 없습니다.",
  },
  {
    question: "사고 나서 맞지 않으면 어떻게 하나요?",
    answer:
      "App Store 구매는 Apple의 환불 절차를 따릅니다. reportaproblem.apple.com에서 구매 내역을 열고 환불을 요청하면 Apple이 심사합니다. 개발자가 대신 처리할 수는 없지만, 판단이 서지 않으면 이 페이지의 체험으로 투구 방식을 먼저 확인해 보세요.",
  },
  {
    question: "어떤 기기에서 되나요?",
    answer:
      "iOS 17 이상의 iPhone에서 동작합니다. 세로 화면 전용이고, 아이패드는 이번 버전의 지원 대상이 아닙니다.",
  },
  {
    question: "기기를 바꾸면 진행이 사라지나요?",
    answer:
      "같은 Apple 계정이라면 iCloud로 이어집니다. 진행 상황은 기기에 저장되고 iCloud에 함께 올라가며, 새 기기에서 앱을 열면 최신 진행을 내려받습니다.",
  },
  {
    question: "인터넷이 없어도 되나요?",
    answer:
      "됩니다. 모든 계산은 기기 안에서 이뤄집니다. 인터넷은 iCloud 동기화와 Game Center 순위표에만 쓰이고, 둘 다 없어도 게임은 그대로 돌아갑니다.",
  },
] as const;

function externalProps(href: string) {
  return href.startsWith("http")
    ? { target: "_blank" as const, rel: "noreferrer" }
    : {};
}

/// 주 행동 버튼. 출시 전에는 App Store가 404이므로 목적지와 문구가 함께 바뀐다.
/// 다운로드 표식도 실제로 내려받을 수 있을 때만 붙인다.
function PrimaryCta({
  placement,
  withPrice = false,
  className = "",
}: {
  placement: Parameters<typeof primaryCta>[0];
  withPrice?: boolean;
  className?: string;
}) {
  const cta = primaryCta(placement, { withPrice });
  if (cta.external) {
    return (
      <AppStoreButton className={className} href={cta.href} target="_blank" rel="noreferrer">
        {cta.label}
      </AppStoreButton>
    );
  }
  return (
    <a className={`button button-primary ${className}`.trim()} href={cta.href}>
      <span>{cta.label}</span>
    </a>
  );
}

function Brand() {
  return (
    <a className="brand" href="#top" aria-label="야구 못하면 또 환생함 처음으로">
      <Image className="brand-icon" src="/icon.png" alt="" width={28} height={28} />
      <span>
        <small>야구 못하면</small>
        <strong>또 환생함</strong>
      </span>
    </a>
  );
}

function SectionHeading({
  eyebrow,
  title,
  description,
  centered = false,
}: {
  eyebrow: string;
  title: string;
  description?: string;
  centered?: boolean;
}) {
  return (
    <div className={centered ? "section-heading is-centered" : "section-heading"}>
      <p className="eyebrow">{eyebrow}</p>
      <h2>{title}</h2>
      {description ? <p className="section-description">{description}</p> : null}
    </div>
  );
}

export default function HomePage() {
  const teaserHref = webTeaserUrl();
  const mobileCta = primaryCta("mobile", { withPrice: true });

  return (
    <>
      <a className="skip-link" href="#main">
        본문으로 바로가기
      </a>

      <header className="site-header">
        <div className="header-inner">
          <Brand />
          <nav className="desktop-nav" aria-label="주요 메뉴">
            <a href="#trailer">영상</a>
            <a href="#gameplay">게임플레이</a>
            <a href="#rebirth">환생</a>
            <a href="#career">커리어</a>
            <a href="#screens">화면</a>
            <a href="#faq">FAQ</a>
          </nav>
          <PrimaryCta className="header-cta" placement="header" />
        </div>
      </header>

      <main id="main">
        <section className="hero" id="top">
          <Image
            className="hero-art"
            src="/hero-key-art.png"
            alt="야간 구장의 마운드에서 다음 승부를 준비하는 고교 투수"
            fill
            priority
            sizes="100vw"
          />
          <div className="hero-overlay" />

          <div className="hero-content shell">
            <div className="hero-copy">
              <p className="eyebrow">한 구가 인생을 바꾸는 투수 육성 게임</p>
              <h1>
                이번 생엔,
                <br />
                <span>이름이 불릴까.</span>
              </h1>
              <p className="hero-description">
                <strong>승부처의 공을 한 구씩 직접 던집니다.</strong>
                <br />
                지명받지 못하면 기억만 남기고 다시 태어납니다.
                <br />
                이름이 불릴 때까지, 몇 번이든.
              </p>
              <div className="hero-actions">
                <PrimaryCta placement="hero" withPrice />
                <a className="button button-secondary" href="#pitch-preview">
                  <span className="scroll-mark" aria-hidden="true">
                    ↓
                  </span>
                  설치 없이 한 타석 던져보기
                </a>
              </div>
              <p className="release-status">
                App Store에서 ₩3,300. 한 번 구매로 끝이고, 그 뒤로 결제할 것이 없습니다.
              </p>
              <ul className="release-facts" aria-label="게임과 출시 정보">
                <li>iPhone · iOS 17+</li>
                <li>한 번 구매로 전부</li>
                <li>광고·앱 내 구입 없음</li>
                <li>오프라인 플레이</li>
              </ul>
            </div>

            <aside className="life-report" aria-label="두 번째 삶의 선수 리포트">
              <div className="life-report-head">
                <span>LIFE REPORT</span>
                <strong>02번째 선수</strong>
              </div>
              <div className="life-player">
                <div className="life-photo">
                  <Image
                    src="/scene-rookie.webp"
                    alt=""
                    fill
                    sizes="110px"
                  />
                  <span>02</span>
                </div>
                <div>
                  <small>서울 · 우투 · 균형 체격</small>
                  <strong>민서준</strong>
                  <p>강속구 원석</p>
                </div>
              </div>
              <div className="inherited-title">
                <span>전생에서 가져온 기억</span>
                <strong>3 / 3</strong>
              </div>
              <ul className="inherited-list">
                {memories.map(([title]) => (
                  <li key={title}>
                    <i aria-hidden="true" />
                    {title}
                  </li>
                ))}
              </ul>
              <div className="draft-range">
                <span>현재 예상 지명</span>
                <strong>4~6 ROUND</strong>
              </div>
            </aside>
          </div>

          <div className="hero-foot shell">
            <span>선수 생성</span>
            <i />
            <span>고교 3년</span>
            <i />
            <span>드래프트</span>
            <i />
            <strong>프로 또는 다음 삶</strong>
          </div>
        </section>

        <section className="section trailer-section" id="trailer">
          <div className="shell">
            <SectionHeading
              eyebrow="27초면 어떤 게임인지 압니다"
              title="영상으로 먼저 보세요."
              description="전부 실제 앱 화면입니다. 승부 장면은 게임이 그리는 그대로를 프레임 단위로 옮겼습니다."
              centered
            />
            {/* 소리가 없는 영상이라 controls만 준다. 자동재생은 데이터를 함부로 쓰는 일이다. */}
            <div className="trailer-frame">
              <video
                controls
                playsInline
                preload="none"
                poster="/trailer-poster.jpg"
                width={1920}
                height={1080}
              >
                <source src="/trailer.mp4" type="video/mp4" />
                이 브라우저는 영상을 재생하지 못합니다. 아래 화면 캡처로 확인해 주세요.
              </video>
            </div>
          </div>
        </section>

        <section className="section proof-section" id="gameplay">
          <div className="shell">
            <div className="proof-grid">
              <div className="game-screen gamecast-screen">
                <div className="screen-label">
                  <span>실제 게임 화면</span>
                  <small>투구 궤적 분석</small>
                </div>
                {/* 헛스윙과 홈런 두 구. 무음이라 자동재생해도 남의 사무실을 시끄럽게 하지 않는다. */}
                <video
                  className="loop-video"
                  autoPlay
                  muted
                  loop
                  playsInline
                  preload="metadata"
                  poster="/gameplay-gamecast.webp"
                  aria-label="헛스윙과 홈런, 두 구의 승부 장면"
                >
                  <source src="/pitch-loop.mp4" type="video/mp4" />
                </video>
              </div>

              <div className="proof-copy">
                <p className="eyebrow">승부처만 직접 던집니다</p>
                <h2>
                  모든 공을 던지지 않습니다.
                  <br />
                  바꿀 수 있는 순간만 던집니다.
                </h2>
                <p>
                  평범한 경기는 빠르게 흐르고, 라이벌과의 재대결이나 드래프트 평가가
                  걸린 중요 이닝에서 마운드에 오릅니다.
                </p>
                <ol className="proof-steps">
                  <li>
                    <span>01</span>
                    <div>
                      <strong>포수의 사인을 읽습니다</strong>
                      <small>주 추천과 대안, 타자의 최근 반응을 비교합니다.</small>
                    </div>
                  </li>
                  <li>
                    <span>02</span>
                    <div>
                      <strong>구종과 코스를 고릅니다</strong>
                      <small>추천을 따르거나 다른 승부를 직접 선택합니다.</small>
                    </div>
                  </li>
                  <li>
                    <span>03</span>
                    <div>
                      <strong>결과의 이유를 확인합니다</strong>
                      <small>판단, 실제 제구, 타자의 노림수를 분리해 보여줍니다.</small>
                    </div>
                  </li>
                </ol>
                <a className="text-link" href="#pitch-preview">
                  인터랙티브 투구 체험 <span aria-hidden="true">↓</span>
                </a>
              </div>
            </div>

            <div id="pitch-preview" className="pitch-preview">
              <SectionHeading
                eyebrow="지금 여기서 던져보기"
                title="8회 말 2사 1·2루, 무엇을 던지겠습니까?"
                description="포수 추천을 참고하고 구종과 목표 코스를 직접 바꿔 결과를 확인해 보세요."
                centered
              />
              <PitchDecision />
              <p className="preview-note">
                랜딩페이지용 체험입니다. 실제 데모에서는 선수 능력, 피로, 타자 노림수와 이전 승부가 함께 반영됩니다.
              </p>
            </div>
          </div>
        </section>

        <section className="section rebirth-section" id="rebirth">
          <Image
            className="rebirth-art"
            src="/scene-legacy.webp"
            alt=""
            fill
            sizes="100vw"
          />
          <div className="rebirth-overlay" />
          <div className="shell rebirth-shell">
            <SectionHeading
              eyebrow="실패하고, 기억하고, 돌아온다"
              title="지명받지 못하면, 다음 선수가 시작됩니다."
              description="실패한 기록은 삭제되지 않습니다. 부족했던 승부에서 기억을 고르고, 이전에는 없던 성장 방향과 선택지를 들고 새 삶을 시작합니다."
              centered
            />

            <div className="run-loop" aria-label="게임의 반복 구조">
              <div>
                <span>01</span>
                <strong>선수 생성</strong>
                <small>유형·지역·난이도 선택</small>
              </div>
              <i aria-hidden="true">→</i>
              <div>
                <span>02</span>
                <strong>고교 3년</strong>
                <small>훈련·관계·중요 경기</small>
              </div>
              <i aria-hidden="true">→</i>
              <div>
                <span>03</span>
                <strong>드래프트</strong>
                <small>10개 가상 구단의 평가</small>
              </div>
              <i aria-hidden="true">↗</i>
              <div className="is-milestone">
                <span>04A</span>
                <strong>프로 커리어</strong>
                <small>지명된 선수로 은퇴까지</small>
              </div>
              <div className="loop-return">
                <span>04B</span>
                <strong>기억을 들고 환생</strong>
                <small>미지명 원인을 다음 삶의 선택으로</small>
              </div>
            </div>

            <div className="life-compare">
              <article className="life-card is-failed">
                <div className="life-card-head">
                  <span>LIFE 01</span>
                  <strong>미지명</strong>
                </div>
                <h3>이름은 끝까지 불리지 않았습니다.</h3>
                <p>변화구 완성도와 후반 체력이 부족했습니다. 이번 삶에서 다음 선수에게 남길 기억을 고릅니다.</p>
                <div className="memory-picks">
                  {memories.map(([title, description]) => (
                    <div key={title}>
                      <i aria-hidden="true">✓</i>
                      <span>
                        <strong>{title}</strong>
                        <small>{description}</small>
                      </span>
                    </div>
                  ))}
                </div>
              </article>

              <span className="rebirth-arrow" aria-hidden="true">
                다시
                <b>→</b>
              </span>

              <article className="life-card is-returned">
                <div className="life-card-head">
                  <span>LIFE 02</span>
                  <strong>새 선수</strong>
                </div>
                <div className="life-setup-shot">
                  <Image
                    src="/gameplay-career-setup.webp"
                    alt="실제 게임의 두 번째 선수 생성과 난이도 설정 화면"
                    fill
                    sizes="(max-width: 900px) 100vw, 42vw"
                  />
                </div>
                <div className="returned-badges">
                  <span>변화구 성장 경로 개방</span>
                  <span>지난 드래프트 정보 유지</span>
                  <span>새 학교·코치 후보</span>
                </div>
              </article>
            </div>
          </div>
        </section>

        <section className="section high-school-section">
          <div className="shell">
            <SectionHeading
              eyebrow="증명할 시간은 3년"
              title="매주를 관리하고, 중요한 순간을 직접 바꿉니다."
              description="수치만 올리는 육성이 아닙니다. 학교의 방향, 사람과의 약속, 실제 투구 선택이 같은 선수의 드래프트 평가로 이어집니다."
              centered
            />

            <div className="high-school-layout">
              <div className="high-school-visual">
                <Image
                  src="/scene-school.webp"
                  alt="가상 한국 야구 세계의 학교 운동장에서 훈련을 시작하는 투수"
                  fill
                  sizes="(max-width: 900px) 100vw, 52vw"
                />
                <div className="school-overlay-card">
                  <span>서울배성고</span>
                  <strong>기록을 활용한 타자 상대법</strong>
                  <small>분석형 감독 · 분석형 포수 · 경기 운영 성장</small>
                </div>
              </div>

              <div className="training-proof">
                <span className="screen-label-inline">실제 훈련 결과 화면</span>
                <div className="training-shot">
                  <Image
                    src="/gameplay-training-result.webp"
                    alt="실제 게임의 훈련 결과와 능력·피로 변화 화면"
                    fill
                    sizes="(max-width: 900px) 100vw, 28vw"
                  />
                </div>
              </div>
            </div>

            <div className="high-school-features">
              <article>
                <span>01 · 성장</span>
                <div className="feature-thumb">
                  <Image src="/scene-training.webp" alt="" fill sizes="32vw" />
                </div>
                <h3>훈련에는 항상 대가가 있습니다</h3>
                <p>구속·제구·변화구·체력을 성장시키되 피로와 약점을 함께 관리합니다. 행동에 따라 세 후보의 각성이 달라집니다.</p>
              </article>
              <article>
                <span>02 · 관계</span>
                <div className="feature-thumb">
                  <Image src="/scene-battery.webp" alt="" fill sizes="32vw" />
                </div>
                <h3>사람이 다음 선택을 바꿉니다</h3>
                <p>감독, 포수, 라이벌, 가족과 팬이 당신의 선택을 기억합니다. 경기 밖의 결정이 다음 중요 경기의 사인과 평가로 돌아옵니다.</p>
              </article>
              <article>
                <span>03 · 중요 경기</span>
                <div className="feature-thumb">
                  <Image src="/scene-game.webp" alt="" fill sizes="32vw" />
                </div>
                <h3>결정적인 이닝만 직접 던집니다</h3>
                <p>라이벌 재대결, 2사 만루, 전국 결승처럼 커리어 가치가 큰 순간에만 개입합니다. 결과보다 선택의 이유를 먼저 봅니다.</p>
              </article>
            </div>
          </div>
        </section>

        <section className="section draft-section" id="career">
          <Image
            className="draft-art"
            src="/scene-draft.webp"
            alt="가상 프로야구 드래프트에서 결과를 기다리는 신인 선수"
            fill
            sizes="100vw"
          />
          <div className="draft-overlay" />
          <div className="shell draft-shell">
            <SectionHeading
              eyebrow="드래프트 당일"
              title="이름이 불리면 프로로. 불리지 않으면 다음 삶으로."
              description="미리 계산된 평가를 라운드별로 공개합니다. 결과가 어느 쪽이든 이번 삶에서 무엇을 남길지 선택합니다."
              centered
            />

            <div className="draft-outcomes">
              <article className="draft-outcome is-drafted">
                <div className="outcome-top">
                  <span>ROUND 04 · PICK 37</span>
                  <strong>지명</strong>
                </div>
                <div className="rookie-card">
                  <div className="rookie-photo">
                    <Image
                      src="/scene-rookie.webp"
                      alt="서울 코메츠에 지명된 가상 신인 투수"
                      fill
                      sizes="120px"
                    />
                    <span>26</span>
                  </div>
                  <div className="rookie-copy">
                    <small>서울 코메츠</small>
                    <strong>민서준</strong>
                    <p>투수 · 우투 · 강속구 원석</p>
                  </div>
                </div>
                <p>빠른 공의 성장 가능성과 중요한 경기에서 바꾼 승부가 지명 이유로 기록됩니다.</p>
              </article>

              <article className="draft-outcome is-undrafted">
                <div className="outcome-top">
                  <span>FINAL ROUND CLOSED</span>
                  <strong>미지명</strong>
                </div>
                <div className="empty-name">
                  <span>—</span>
                  <div>
                    <small>이번 삶의 마지막 기록</small>
                    <strong>이름은 불리지 않았습니다</strong>
                  </div>
                </div>
                <ul>
                  <li>검토한 가상 구단과 부족했던 능력 확인</li>
                  <li>이번 삶에서 남길 기억 3장 선택</li>
                  <li>다음 선수의 지역·학교·성장 방향 재설계</li>
                </ul>
              </article>
            </div>

            <div className="pro-entry">
              <div className="pro-entry-art">
                <Image
                  src="/pro-career-stadium-tunnel.webp"
                  alt="가상 프로 구장의 터널을 지나 마운드로 향하는 투수"
                  fill
                  sizes="(max-width: 900px) 100vw, 48vw"
                />
              </div>
              <div className="pro-entry-copy">
                <p className="eyebrow">이름이 불린 다음</p>
                <h3>지명된 한 명은 더 이상 버리지 않습니다.</h3>
                <p>
                  같은 선수로 신인 계약을 맺고 2군 경쟁, 1군 콜업, 보직 변화,
                  군 복무와 FA를 지나 최대 12시즌의 프로 커리어를 완주합니다.
                </p>
              </div>
            </div>

            <ol className="career-roadmap">
              {proSteps.map(([number, title, description]) => (
                <li key={number}>
                  <span>{number}</span>
                  <strong>{title}</strong>
                  <small>{description}</small>
                </li>
              ))}
            </ol>
          </div>
        </section>

        <section className="section screens-section" id="screens">
          <div className="shell">
            <SectionHeading
              eyebrow="당신의 iPhone에서"
              title="실제 앱 화면입니다."
              description="승부처에서 구종과 코스를 고르고, 던진 공의 궤적과 결과를 그 자리에서 확인합니다."
              centered
            />

            <div className="screens-grid">
              {/* 세로 미리보기는 App Store에 올리는 것과 같은 파일이다. 스토어에서 보게 될
                  것을 여기서 먼저 보여 준다. */}
              <figure className="screen-card is-video">
                <video
                  controls
                  playsInline
                  preload="none"
                  poster="/preview-poster.jpg"
                  width={886}
                  height={1920}
                  aria-label="앱 미리보기 영상"
                >
                  <source src="/app-preview.mp4" type="video/mp4" />
                </video>
                <figcaption>
                  <strong>움직이는 화면</strong>
                  <span>26초 · App Store 미리보기와 같은 영상</span>
                </figcaption>
              </figure>

              <figure className="screen-card">
                <Image
                  src="/ios-pitch.png"
                  alt="구종과 코스를 고르는 승부 화면. 포수 사인과 스트라이크존 격자가 보인다."
                  width={420}
                  height={912}
                  sizes="(max-width: 900px) 80vw, 300px"
                />
                <figcaption>
                  <strong>고른다</strong>
                  <span>구종 · 코스 · 노림 · 힘 배분</span>
                </figcaption>
              </figure>

              <figure className="screen-card">
                <Image
                  src="/ios-training.png"
                  alt="고교 3년의 훈련 분야를 고르는 화면. 오늘의 기회와 능력 수치가 보인다."
                  width={420}
                  height={912}
                  sizes="(max-width: 900px) 80vw, 300px"
                />
                <figcaption>
                  <strong>자란다</strong>
                  <span>훈련 · 관계 · 각성</span>
                </figcaption>
              </figure>
            </div>

            <div className="screens-cta">
              <PrimaryCta placement="detail" withPrice />
              <a className="button button-secondary" href={teaserHref} {...externalProps(teaserHref)}>
                <span className="scroll-mark" aria-hidden="true">↓</span>
                {webTeaserLabel()}
              </a>
            </div>
          </div>
        </section>

        <section className="section faq-section" id="faq">
          <div className="shell faq-shell">
            <SectionHeading
              eyebrow="FAQ"
              title="출시 전에 궁금한 점."
              description="구매 전에 가장 많이 묻는 것들입니다."
            />
            <div className="faq-list">
              {faqItems.map((item, index) => (
                <details key={item.question} open={index === 0}>
                  <summary>
                    <span>{String(index + 1).padStart(2, "0")}</span>
                    {item.question}
                    <i aria-hidden="true">+</i>
                  </summary>
                  <p>{item.answer}</p>
                </details>
              ))}
            </div>
          </div>
        </section>

        <section className="final-cta">
          <Image
            className="final-art"
            src="/hero-key-art.png"
            alt=""
            fill
            sizes="100vw"
          />
          <div className="final-overlay" />
          <div className="shell final-content">
            <p className="eyebrow">아직 한 번 더 남았습니다</p>
            <h2>
              이번 생의 마지막은
              <br />
              아직 정해지지 않았습니다.
            </h2>
            <PrimaryCta placement="final" withPrice />
            <p>한 번 사면 고교 3년부터 프로 은퇴까지. 광고도, 앱 내 구입도 없습니다.</p>
          </div>
        </section>
      </main>

      <footer className="site-footer">
        <div className="shell footer-inner">
          <Brand />
          <p>© {new Date().getFullYear()} 야구 못하면 또 환생함. All rights reserved.</p>
          <div className="footer-links">
            <a href="#gameplay">게임플레이</a>
            <a href="#rebirth">환생</a>
            <a href="#screens">화면</a>
            <a href="#faq">FAQ</a>
            <a href="/privacy">개인정보 처리방침</a>
            <a href="mailto:kimsol1134@gmail.com">문의</a>
          </div>
        </div>
      </footer>

      <a
        className="mobile-wishlist"
        href={mobileCta.href}
        {...externalProps(mobileCta.href)}
      >
        {mobileCta.external ? <AppStoreMark /> : null}
        {mobileCta.label}
      </a>

      {/* 구조화 데이터. FAQ는 검색 결과에 그대로 펼쳐지고, 게임 정보는 가격·플랫폼을 함께 노출한다. */}
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(structuredData()) }}
      />
    </>
  );
}

function structuredData() {
  return {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "VideoGame",
        name: "야구 못하면 또 환생함",
        description:
          "고교 야구 인생을 반복하며 기억을 쌓아 드래프트를 돌파하고, 지명된 한 선수로 프로 은퇴까지 살아가는 싱글플레이 투수 육성 게임입니다.",
        url: "https://baseball-reincarnation.vercel.app/",
        image: "https://baseball-reincarnation.vercel.app/hero-key-art.png",
        trailer: {
          "@type": "VideoObject",
          name: "야구 못하면 또 환생함 – 게임플레이 트레일러",
          description:
            "승부처 투구, 고교 3년 육성, 미지명 뒤의 환생까지 실제 앱 화면으로 보여 주는 27초 트레일러입니다.",
          thumbnailUrl: "https://baseball-reincarnation.vercel.app/trailer-poster.jpg",
          contentUrl: "https://baseball-reincarnation.vercel.app/trailer.mp4",
          uploadDate: "2026-07-26",
          duration: "PT26S",
        },
        inLanguage: "ko",
        genre: ["시뮬레이션", "스포츠", "로그라이트"],
        gamePlatform: "iOS",
        applicationCategory: "GameApplication",
        operatingSystem: "iOS 17.0 이상",
        playMode: "SinglePlayer",
        offers: {
          "@type": "Offer",
          price: "3300",
          priceCurrency: "KRW",
          availability: "https://schema.org/InStock",
        },
      },
      {
        "@type": "FAQPage",
        mainEntity: faqItems.map((item) => ({
          "@type": "Question",
          name: item.question,
          acceptedAnswer: { "@type": "Answer", text: item.answer },
        })),
      },
    ],
  };
}
