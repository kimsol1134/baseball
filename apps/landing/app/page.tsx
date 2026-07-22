import Image from "next/image";
import type { CSSProperties } from "react";
import { PitchDecision } from "@/components/PitchDecision";
import { SteamButton, SteamMark } from "@/components/SteamButton";
import { steamDemoUrl, steamWishlistUrl, webTeaserUrl } from "@/lib/links";

const careerSteps = [
  ["01", "지명", "누군가 당신의 이름을 부릅니다."],
  ["02", "2군 경쟁", "기회는 주어지지 않고 증명해야 합니다."],
  ["03", "1군 데뷔", "처음으로 가득 찬 관중석 앞에 섭니다."],
  ["04", "보직 변화", "선발, 불펜, 마무리. 역할은 계속 바뀝니다."],
  ["05", "우승", "한 시즌의 모든 선택이 한 경기에 모입니다."],
  ["06", "은퇴", "마지막 공도 당신이 결정합니다."],
] as const;

const faqItems = [
  {
    question: "야구 못하면 또 환생함은 어떤 게임인가요?",
    answer:
      "한 명의 선수를 만들고 고교 입학부터 프로 은퇴까지 살아가는 싱글플레이 야구 커리어 RPG입니다. 구종과 코스를 고르는 경기 판단, 훈련과 성장, 동료와의 관계가 하나의 커리어를 만듭니다.",
  },
  {
    question: "정식판에는 어디까지 플레이할 수 있나요?",
    answer:
      "고교 3년과 드래프트, 프로 데뷔부터 은퇴까지 전체 커리어를 한 번의 구매에 담습니다. 고교판과 프로 DLC를 나누어 판매하지 않습니다.",
  },
  {
    question: "어떤 플랫폼으로 출시하나요?",
    answer:
      "Windows Steam 버전을 먼저 출시하고 macOS 버전은 서명과 공증, 실기기 검증을 마친 뒤 추가할 계획입니다.",
  },
  {
    question: "Steam 데모는 어디까지 체험할 수 있나요?",
    answer:
      "핵심 투구, 성장, 관계, 첫 중요 경기까지 약 30~45분 동안 체험하는 별도 무료 데모를 준비하고 있습니다. 데모 종료 저장은 정식판에서 이어지도록 설계했습니다.",
  },
  {
    question: "모바일에서도 플레이할 수 있나요?",
    answer:
      "모바일 웹에서는 설치 없이 즐기는 10~15분 분량의 선택형 티저를 제공합니다. 전체 게임은 Steam 정식판에 집중합니다.",
  },
] as const;

function externalProps(href: string) {
  return href.startsWith("http")
    ? { target: "_blank" as const, rel: "noreferrer" }
    : {};
}

function Brand() {
  return (
    <a className="brand" href="#top" aria-label="야구 못하면 또 환생함 처음으로">
      <Image className="brand-icon" src="/icon.png" alt="" width={24} height={24} />
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
  const headerWishlist = steamWishlistUrl("header");
  const heroWishlist = steamWishlistUrl("hero");
  const demoHref = steamDemoUrl();
  const teaserHref = webTeaserUrl();
  const finalWishlist = steamWishlistUrl("final");

  return (
    <>
      <a className="skip-link" href="#main">
        본문으로 바로가기
      </a>

      <header className="site-header">
        <div className="header-inner">
          <Brand />
          <nav className="desktop-nav" aria-label="주요 메뉴">
            <a href="#game">게임 소개</a>
            <a href="#career">커리어</a>
            <a href="#demo">데모</a>
            <a href="#faq">FAQ</a>
          </nav>
          <SteamButton
            className="header-cta"
            href={headerWishlist}
            {...externalProps(headerWishlist)}
          >
            Steam 위시리스트
          </SteamButton>
        </div>
      </header>

      <main id="main">
        <section className="hero" id="top">
          <Image
            className="hero-art"
            src="/hero-key-art.png"
            alt="야간 구장의 마운드에서 포수와 마주 선 고교 투수"
            fill
            priority
            sizes="100vw"
          />
          <div className="hero-overlay" />
          <div className="hero-content shell">
            <div className="hero-copy">
              <p className="eyebrow">한 선수의 전 생애를 플레이하는 야구 RPG</p>
              <h1>
                3년 안에 지명받아라.
                <br />
                그리고 <span>마지막 공</span>까지.
              </h1>
              <p className="hero-description">
                한 공의 선택, 매일의 성장, 곁에 남은 사람들.
                <br />
                고교 입학부터 프로 은퇴까지 당신만의 기록을 만드세요.
              </p>
              <div className="hero-actions">
                <SteamButton href={heroWishlist} {...externalProps(heroWishlist)}>
                  Steam에서 위시리스트
                </SteamButton>
                <a className="button button-secondary" href="#pitch">
                  <span className="play-mark" aria-hidden="true">
                    ▶
                  </span>
                  게임플레이 미리보기
                </a>
              </div>
              <ul className="release-facts" aria-label="출시 정보">
                <li>싱글플레이</li>
                <li>Windows 우선 출시</li>
                <li>macOS 추후 지원</li>
              </ul>
            </div>

            <aside className="hero-scout-card" aria-label="선수 스카우팅 리포트">
              <div className="scout-head">
                <span>SCOUT REPORT</span>
                <strong>투수 · 우투</strong>
              </div>
              <div className="scout-player">
                <span className="player-number">26</span>
                <div>
                  <small>3학년 · 전국대회</small>
                  <strong>이준서</strong>
                </div>
                <span className="scout-grade">B+</span>
              </div>
              <div className="scout-metrics">
                <span style={{ "--value": "84%" } as CSSProperties}>
                  <small>구속</small>
                  <i />
                </span>
                <span style={{ "--value": "72%" } as CSSProperties}>
                  <small>제구</small>
                  <i />
                </span>
                <span style={{ "--value": "66%" } as CSSProperties}>
                  <small>멘탈</small>
                  <i />
                </span>
              </div>
              <p>“한 타자를 상대할 때마다 다음 선택이 궁금해지는 선수.”</p>
            </aside>
          </div>
          <a className="scroll-cue" href="#pitch" aria-label="다음 섹션으로 이동">
            <span />
          </a>
        </section>

        <section className="section section-pitch" id="pitch">
          <div className="shell">
            <SectionHeading
              eyebrow="PLAY THE MOMENT"
              title="이 한 구, 어디에 던지겠습니까?"
              description="반사신경보다 중요한 것은 타자와 상황을 읽는 판단입니다. 구종과 코스를 직접 골라보세요."
              centered
            />
            <PitchDecision />
            <p className="preview-note">인터랙티브 구성 예시이며 실제 데모에서는 선수 능력과 경기 맥락이 결과에 반영됩니다.</p>
          </div>
        </section>

        <section className="section school-section" id="game">
          <div className="shell">
            <SectionHeading
              eyebrow="THREE YEARS TO PROVE IT"
              title="프로가 될 시간은 3년뿐입니다."
              description="훈련표만 채우는 3년이 아닙니다. 어느 학교에서 누구와 성장하고, 어떤 경기에서 증명할지 선택합니다."
              centered
            />

            <div className="school-grid">
              <article className="feature-card school-card">
                <div className="feature-card-head">
                  <span>01</span>
                  <div>
                    <p>학교</p>
                    <h3>시작점부터 선택합니다</h3>
                  </div>
                </div>
                <div className="student-card">
                  <div className="student-mark">H</div>
                  <div className="student-profile">
                    <span className="student-photo">26</span>
                    <div>
                      <strong>이준서</strong>
                      <small>투수 · 우투우타 · 2학년</small>
                    </div>
                  </div>
                  <dl>
                    <div><dt>학업 성적</dt><dd>B+</dd></div>
                    <div><dt>출석률</dt><dd>96%</dd></div>
                    <div><dt>학교 평판</dt><dd>모범</dd></div>
                  </dl>
                </div>
              </article>

              <article className="feature-card growth-card">
                <div className="feature-card-head">
                  <span>02</span>
                  <div>
                    <p>성장</p>
                    <h3>오늘의 선택이 능력이 됩니다</h3>
                  </div>
                </div>
                <p className="report-title">이번 주 훈련 리포트</p>
                <div className="metric-list">
                  <div><span>구속</span><i><b style={{ width: "82%" }} /></i><strong>142</strong><em>+2</em></div>
                  <div><span>제구</span><i><b style={{ width: "58%" }} /></i><strong>58</strong><em>+4</em></div>
                  <div><span>변화구</span><i><b style={{ width: "63%" }} /></i><strong>61</strong><em>+3</em></div>
                  <div><span>체력</span><i><b style={{ width: "71%" }} /></i><strong>71</strong><em>+2</em></div>
                </div>
                <div className="choice-row"><span>A</span> 제구 안정 훈련 <strong>선택</strong></div>
              </article>

              <article className="feature-card relation-card">
                <div className="feature-card-head">
                  <span>03</span>
                  <div>
                    <p>관계</p>
                    <h3>혼자서는 완주할 수 없습니다</h3>
                  </div>
                </div>
                <div className="teammate">
                  <span className="catcher-mask" aria-hidden="true">C</span>
                  <div>
                    <strong>김태윤</strong>
                    <small>포수 · 3학년</small>
                  </div>
                  <em>신뢰 81</em>
                </div>
                <blockquote>“네 공은 분명 좋아. 자신 있게 던져.”</blockquote>
                <div className="bond-bar"><span>배터리 호흡</span><i><b /></i></div>
                <p className="card-caption">경기 밖의 관계가 마운드 위 선택지를 바꿉니다.</p>
              </article>

              <article className="feature-card game-card">
                <div className="feature-card-head">
                  <span>04</span>
                  <div>
                    <p>중요 경기</p>
                    <h3>기록은 기억으로 남습니다</h3>
                  </div>
                </div>
                <div className="mini-scoreboard">
                  <small>VS 청운고 · 야간 경기</small>
                  <strong>7 <span>:</span> 2</strong>
                  <b>WIN</b>
                </div>
                <dl className="game-stats">
                  <div><dt>이닝</dt><dd>7.0</dd></div>
                  <div><dt>피안타</dt><dd>4</dd></div>
                  <div><dt>탈삼진</dt><dd>9</dd></div>
                  <div><dt>투구 수</dt><dd>102</dd></div>
                </dl>
              </article>
            </div>
          </div>
        </section>

        <section className="section draft-section" id="career">
          <div className="draft-glow" />
          <div className="shell draft-shell">
            <SectionHeading
              eyebrow="DRAFT NIGHT"
              title="이름이 불리는 순간, 진짜 커리어가 시작됩니다."
              description="지명은 엔딩이 아니라 새로운 경쟁의 시작입니다. 역할과 팀, 몸 상태와 관계가 매 시즌 커리어를 바꿉니다."
              centered
            />

            <div className="draft-stage">
              <div className="draft-board">
                <span className="board-label">KBD DRAFT · ROUND 2</span>
                <div className="board-row is-dim"><span>04</span><b>박도현</b><small>내야수</small></div>
                <div className="board-row is-active"><span>05</span><b>이준서</b><small>한빛고 · 투수</small></div>
                <div className="board-row is-dim"><span>06</span><b>—</b><small>ON THE CLOCK</small></div>
              </div>
              <div className="draft-call">
                <span className="phone-ring">◌</span>
                <p>전화가 울립니다</p>
                <strong>KBD 구단 사무실</strong>
                <small>수신 중…</small>
              </div>
              <div className="rookie-card">
                <span className="rookie-silhouette">26</span>
                <div>
                  <small>ROOKIE CARD</small>
                  <strong>이준서</strong>
                  <p>투수 · 우투우타</p>
                </div>
                <b>2R</b>
              </div>
            </div>

            <ol className="career-roadmap">
              {careerSteps.map(([number, title, description]) => (
                <li key={number}>
                  <span>{number}</span>
                  <strong>{title}</strong>
                  <small>{description}</small>
                </li>
              ))}
            </ol>
          </div>
        </section>

        <section className="section memory-section">
          <div className="shell">
            <SectionHeading
              eyebrow="A CAREER REMEMBERS"
              title="모든 것이 기록으로 남습니다."
              description="기록표의 숫자뿐 아니라, 함께한 사람과 결정적인 순간이 한 선수의 야구 인생을 완성합니다."
              centered
            />

            <div className="memory-layout">
              <div className="memory-book">
                <article className="memory-note note-one">
                  <span>기억 01</span>
                  <div className="memory-visual"><b>11</b></div>
                  <strong>3학년 봄, 결승 멀티이닝</strong>
                  <p>마지막 아웃 카운트를 직접 잡아냈다.</p>
                </article>
                <article className="memory-note note-two">
                  <span>기억 02</span>
                  <div className="memory-visual"><b>120</b></div>
                  <strong>첫 완투승</strong>
                  <p>120구를 던진 뒤, 포수와 말없이 웃었다.</p>
                </article>
                <article className="memory-note note-three">
                  <span>기억 03</span>
                  <div className="memory-visual"><b>81</b></div>
                  <strong>포수와의 약속</strong>
                  <p>은퇴 전까지 같은 사인을 믿기로 했다.</p>
                </article>
              </div>

              <div className="legacy-card">
                <p className="micro-label">커리어 레거시</p>
                <div className="legacy-columns">
                  <div>
                    <small>첫 시즌</small>
                    <strong>지명 2R</strong>
                    <span>불펜에서 시작</span>
                  </div>
                  <span className="legacy-arrow">→</span>
                  <div>
                    <small>마지막 시즌</small>
                    <strong>통산 145승</strong>
                    <span>다음 선수에게 기억을 남김</span>
                  </div>
                </div>
                <p>끝난 커리어는 사라지지 않습니다. 다음 도전의 특별한 시작점이 됩니다.</p>
              </div>
            </div>
          </div>
        </section>

        <section className="section demo-section" id="demo">
          <div className="shell">
            <SectionHeading
              eyebrow="PLAY BEFORE RELEASE"
              title="먼저 한 선수의 가능성을 확인하세요."
              description="Steam 데모와 설치 없는 웹 티저로 핵심 선택을 직접 경험할 수 있습니다."
              centered
            />

            <div className="demo-grid">
              <article className="demo-card steam-demo-card">
                <div className="demo-card-top">
                  <span>STEAM DEMO</span>
                  <small>Windows</small>
                </div>
                <div className="demo-screen">
                  <div className="tiny-score"><span>7회 말</span><strong>7 : 5</strong></div>
                  <div className="tiny-zone">●</div>
                  <div className="tiny-stats"><i /><i /><i /></div>
                </div>
                <h3>30~45분, 첫 중요 경기까지</h3>
                <p>투구 · 성장 · 관계를 경험하고, 종료 저장을 정식판에서 이어가도록 준비하고 있습니다.</p>
                <SteamButton href={demoHref} {...externalProps(demoHref)}>
                  Steam 데모 확인
                </SteamButton>
              </article>

              <article className="demo-card teaser-card">
                <div className="demo-card-top">
                  <span>WEB TEASER</span>
                  <small>Mobile · Desktop</small>
                </div>
                <div className="teaser-screen">
                  <span className="teaser-ball">9</span>
                  <div>
                    <small>당신의 첫 승부</small>
                    <strong>무엇을 던지겠습니까?</strong>
                    <i><b /></i>
                  </div>
                </div>
                <h3>설치 없이 10~15분</h3>
                <p>한 타석의 판단과 짧은 성장 루프를 경험하고 Steam 위시리스트로 이어집니다.</p>
                <a className="button button-secondary" href={teaserHref} {...externalProps(teaserHref)}>
                  <span className="play-mark" aria-hidden="true">▶</span>
                  웹에서 바로 시작
                </a>
              </article>
            </div>
          </div>
        </section>

        <section className="promise-strip" aria-label="정식판 구성" id="steam">
          <div className="shell">
            <div className="promise-copy">
              <p className="eyebrow">ONE PURCHASE · THE WHOLE CAREER</p>
              <h2>고교 입학부터 프로 은퇴까지, 한 번의 구매로.</h2>
              <p>본편을 고교판과 프로 DLC로 나누지 않습니다.</p>
            </div>
            <ul>
              <li><span>●</span> 싱글플레이</li>
              <li><span>⊘</span> 가챠 없음</li>
              <li><span>ϟ</span> 에너지 없음</li>
              <li><span>↥</span> Steam Cloud 준비</li>
            </ul>
            <SteamButton
              variant="secondary"
              href={steamWishlistUrl("promise")}
              {...externalProps(steamWishlistUrl("promise"))}
            >
              Steam 출시 소식 받기
            </SteamButton>
          </div>
        </section>

        <section className="section faq-section" id="faq">
          <div className="shell faq-shell">
            <SectionHeading
              eyebrow="FAQ"
              title="궁금한 점을 확인하세요."
              description="출시 준비에 따라 세부 일정과 지원 환경은 계속 업데이트됩니다."
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
            <p className="eyebrow">YOUR NAME IS NEXT</p>
            <h2>다음으로 불릴 이름은, 아직 비어 있습니다.</h2>
            <div className="name-slot" aria-hidden="true">
              <span>?</span>
            </div>
            <SteamButton href={finalWishlist} {...externalProps(finalWishlist)}>
              Steam에서 위시리스트
            </SteamButton>
            <p>위시리스트에 추가하고 데모와 출시 소식을 가장 먼저 확인하세요.</p>
          </div>
        </section>
      </main>

      <footer className="site-footer">
        <div className="shell footer-inner">
          <Brand />
          <p>© {new Date().getFullYear()} 야구 못하면 또 환생함. All rights reserved.</p>
          <div className="footer-links">
            <a href="#game">게임 소개</a>
            <a href="#demo">데모</a>
            <a href="#faq">FAQ</a>
          </div>
        </div>
      </footer>

      <a className="mobile-wishlist" href={heroWishlist} {...externalProps(heroWishlist)}>
        <SteamMark />
        Steam 위시리스트
      </a>
    </>
  );
}
