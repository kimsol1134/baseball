import { useCallback, useEffect, useMemo, useRef, useState, type KeyboardEvent as ReactKeyboardEvent } from "react";
import { createCareerNewsDetail, type CareerNewsCategory, type CareerNewsContext, type CareerNewsDetail } from "./careerNews";

type NewsFilter = "all" | CareerNewsCategory;

const FILTERS: ReadonlyArray<{ id: NewsFilter; label: string }> = [
  { id: "all", label: "전체" },
  { id: "game", label: "경기" },
  { id: "people", label: "인물" },
  { id: "career", label: "진로" },
  { id: "health", label: "몸 상태" },
];

interface Props {
  items: readonly string[];
  context: CareerNewsContext;
  maxItems?: number;
}

export function CareerNewsFeed({ items, context, maxItems = 9 }: Props) {
  const [filter, setFilter] = useState<NewsFilter>("all");
  const [selected, setSelected] = useState<CareerNewsDetail>();
  const [readItems, setReadItems] = useState<ReadonlySet<string>>(() => new Set());
  const dialogRef = useRef<HTMLElement>(null);
  const returnFocusRef = useRef<HTMLButtonElement>(null);
  const details = useMemo(
    () => items.map((item, index) => createCareerNewsDetail(item, index, context)),
    [items, context],
  );
  const visible = details.filter((detail) => filter === "all" || detail.category === filter).slice(0, maxItems);

  const closeDetail = useCallback(() => {
    setSelected(undefined);
    window.requestAnimationFrame(() => returnFocusRef.current?.focus());
  }, []);

  useEffect(() => {
    if (!selected) return undefined;
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === "Escape") closeDetail();
    };
    window.addEventListener("keydown", closeOnEscape);
    return () => {
      document.body.style.overflow = previousOverflow;
      window.removeEventListener("keydown", closeOnEscape);
    };
  }, [closeDetail, selected]);

  const openDetail = (detail: CareerNewsDetail, trigger: HTMLButtonElement) => {
    returnFocusRef.current = trigger;
    setReadItems((current) => new Set([...current, detail.id]));
    setSelected(detail);
  };

  const keepFocusInDialog = (event: ReactKeyboardEvent<HTMLElement>) => {
    if (event.key !== "Tab") return;
    const focusable = [...(dialogRef.current?.querySelectorAll<HTMLElement>("button, [href], [tabindex]:not([tabindex='-1'])") ?? [])]
      .filter((element) => !element.hasAttribute("disabled"));
    const first = focusable[0];
    const last = focusable.at(-1);
    if (!first || !last) return;
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault();
      last.focus();
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault();
      first.focus();
    }
  };

  return <>
    <div className="career-news-filters" role="group" aria-label="뉴스 분류">
      {FILTERS.map((item) => <button key={item.id} type="button" className={filter === item.id ? "is-active" : undefined}
        aria-pressed={filter === item.id} onClick={() => setFilter(item.id)}>{item.label}</button>)}
    </div>
    <div className="career-news-list">
      {visible.map((detail, index) => <article key={detail.id} className={readItems.has(detail.id) ? "is-read" : "is-unread"}>
        <button type="button" onClick={(event) => openDetail(detail, event.currentTarget)} aria-label={`${detail.headline} 상세 보기`}>
          <span className={`news-category news-category--${detail.tone}`}>{index === 0 && filter === "all" ? "NEW" : detail.categoryLabel}</span>
          <small>{detail.source} · {detail.timeLabel}</small>
          <p>{detail.headline}</p>
          <span className="news-open">자세히 <b aria-hidden="true">›</b></span>
        </button>
      </article>)}
      {visible.length === 0 ? <p className="career-news-empty">이 분류에 해당하는 소식이 아직 없습니다.</p> : null}
    </div>
    {selected ? <div className="career-news-modal" role="presentation" onMouseDown={(event) => {
      if (event.target === event.currentTarget) closeDetail();
    }}>
      <section ref={dialogRef} className="career-news-detail" role="dialog" aria-modal="true" aria-labelledby="career-news-title" aria-describedby="career-news-lead" onKeyDown={keepFocusInDialog}>
        <header><div><span>{selected.categoryLabel}</span><small>{selected.source} · {selected.timeLabel}</small></div>
          <button type="button" autoFocus onClick={closeDetail} aria-label="뉴스 상세 닫기">×</button></header>
        <div className="career-news-detail-scroll">
          <h2 id="career-news-title">{selected.headline}</h2>
          <p id="career-news-lead" className="news-lead">{selected.lead}</p>
          <div className="news-detail-grid">
            <article className="news-story"><h3>취재 내용</h3>{selected.paragraphs.map((paragraph) => <p key={paragraph}>{paragraph}</p>)}
              <blockquote><span>{selected.quoteSpeaker}</span><p>“{selected.quote}”</p></blockquote></article>
            <aside className="news-context"><h3>현재 상황</h3>
              <div><span>소속</span><strong>{context.affiliation}</strong></div><div><span>시점</span><strong>{context.period}</strong></div>
              {context.mode === "high_school" ? <><div><span>감독의 믿음</span><strong>{context.managerTrust ?? context.trust}</strong></div>
                <div><span>포수의 믿음</span><strong>{context.catcherTrust ?? context.trust}</strong></div>
                <div><span>라이벌의 인정</span><strong>{context.rivalTrust ?? context.trust}</strong></div></>
                : <div><span>감독의 믿음</span><strong>{context.trust}</strong></div>}
              <div><span>{context.mode === "high_school" ? "지역 팬 관심" : "소속 리그"}</span><strong>{context.mode === "high_school" ? context.fanInterest ?? "—" : context.level ?? "프로"}</strong></div>
              <h4>다음에 확인할 것</h4><p>{selected.watchPoint}</p></aside>
          </div>
          <section className="news-fan-reactions" aria-labelledby="fan-reaction-title"><div><h3 id="fan-reaction-title">팬 반응</h3><small>{selected.fanSummary}</small></div>
            <div className="fan-post-grid">{selected.fanPosts.map((post) => <article key={`${post.handle}-${post.message}`}>
              <header><strong>{post.handle}</strong><span>{post.role}</span></header><p>{post.message}</p><small>공감 {post.cheers}</small>
            </article>)}</div>
          </section>
        </div>
      </section>
    </div> : null}
  </>;
}
