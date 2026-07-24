import { useEffect, useState } from "react";
import { CareerNewsFeed } from "./CareerNewsFeed";
import { CharacterProfile } from "./CharacterProfile";
import type { OffseasonDecision, ProCareerResult, ProSeasonSegment, ProSeasonTrigger, ProWeekPlan } from "./simulationTypes";

const PLANS: ReadonlyArray<{ id: ProWeekPlan; title: string; copy: string }> = [
  { id: "develop_weapon", title: "결정구 훈련", copy: "변화구와 공의 위력이 오르지만 피로가 쌓인다" },
  { id: "refine_command", title: "코스 제구", copy: "볼넷을 줄이고 원하는 코스에 꾸준히 던지는 연습을 한다" },
  { id: "build_stamina", title: "긴 이닝 훈련", copy: "선발 체력을 키우지만 피로가 쌓인다" },
  { id: "recover", title: "회복", copy: "등판을 줄이고 피로와 부상을 회복한다" },
  { id: "earn_trust", title: "이번 주 경기에 집중", copy: "능력 성장은 없지만 감독의 믿음을 얻기 쉽다" },
];

const ROLE_LABELS: Record<ProCareerResult["snapshot"]["role"], string> = {
  starter: "선발", long_relief: "긴 이닝 구원", setup: "필승조", closer: "마무리",
};

const SEGMENT_LABELS: Record<ProSeasonSegment, string> = {
  spring_camp: "스프링캠프", opening: "개막", first_half: "전반기",
  all_star_break: "올스타 휴식기", pennant_race: "순위 경쟁", season_finale: "시즌 결말",
};

// 중요 경기 트리거별 헤드라인. 서버(ProCareer.swift)와 같은 트리거 집합을 쓴다.
const TRIGGER_HEADLINES: Record<ProSeasonTrigger, string> = {
  opening_statement: "개막 시리즈에서 첫인상을 만드는 승부",
  call_up_audition: "콜업을 눈앞에 둔 증명의 등판",
  major_debut: "처음으로 1군 마운드에 오르는 데뷔전",
  record_chase: "시즌 기록에 다가서는 등판",
  role_showdown: "다음 역할이 걸린 자리 싸움",
  standings_race: "순위가 걸린 시즌 종반 승부",
};

// 스냅숏에 구간이 없는 구세이브를 위해 주차에서 파생한다(엔진과 동일 경계).
function segmentForWeek(week: number): ProSeasonSegment {
  if (week < 1) return "spring_camp";
  if (week <= 4) return "opening";
  if (week <= 10) return "first_half";
  if (week <= 13) return "all_star_break";
  if (week <= 20) return "pennant_race";
  return "season_finale";
}

interface Props {
  result: ProCareerResult;
  isRunning: boolean;
  error?: string;
  onSign: () => Promise<void>;
  onPlan: (plan: ProWeekPlan) => Promise<void>;
  onPlanBlock: (plan: ProWeekPlan) => Promise<void>;
  onGame: () => Promise<void>;
  onReview: () => Promise<void>;
  onOffseason: (decision: OffseasonDecision) => Promise<void>;
  onBack: () => void;
  onMilestoneFeedback: (cue?: "progress" | "growth" | "milestone") => void;
}

export function ProCareerView({ result, isRunning, error, onSign, onPlan, onPlanBlock, onGame, onReview, onOffseason, onBack, onMilestoneFeedback }: Props) {
  const state = result.snapshot;
  const [plan, setPlan] = useState<ProWeekPlan>("earn_trust");
  // Runs allowed per nine innings (RA/9), not earned-run average — the sim does
  // not track earned runs, so this is labelled "9이닝당 실점", not "ERA".
  const runsPer9 = state.currentStats.inningsOuts === 0 ? "-.--" : (state.currentStats.runsAllowed * 27 / state.currentStats.inningsOuts).toFixed(2);
  const isProDebut = state.phase === "weekly_plan" && state.currentStats.games === 0;
  const isMajorDebut = state.phase === "important_game" && state.level === "major" && !state.milestones.includes("1군 첫 중요 승부");
  const stage = isProDebut ? "pro_debut" : isMajorDebut ? "major_debut" : state.phase;
  const segment = state.seasonSegment ?? segmentForWeek(state.week);
  const tensions = state.seasonTensions ?? [];
  const rival = state.currentRival;
  const gameTrigger = state.seasonTrigger;
  const gameHeadline = isMajorDebut ? "처음으로 1군 마운드에 오릅니다."
    : gameTrigger ? TRIGGER_HEADLINES[gameTrigger]
    : state.level === "major" ? "1군에서 자리를 굳힐 승부"
    : state.managerTrust < 55 ? "다음 등판 기회를 따낼 경기" : "선발·불펜 역할을 결정할 경기";
  // 1군 데뷔 화면에 처음 들어설 때 마일스톤 스팅어를 울린다. 단계 진입 기준이라 콜업이
  // 단주·3주 진행 중 어느 경로로 잡혔든, 저장을 다시 열어 데뷔전에 들어와도 한 번 재생된다.
  useEffect(() => {
    if (isMajorDebut) onMilestoneFeedback("milestone");
  }, [isMajorDebut, onMilestoneFeedback]);
  return <main className="career-shell pro-career-shell stage-layout" data-stage={stage} data-team={state.team.id} data-segment={segment}>
    <section className="career-hero"><div><p className="eyebrow">프로 커리어 · {state.season}시즌 · {SEGMENT_LABELS[segment]}</p><h2>{state.team.name} · {state.age}세</h2><p>{state.level === "major" ? "1군" : "2군"} {ROLE_LABELS[state.role]} · {state.week}/24주</p></div>
      <div className="career-vitals"><div><span>감독의 믿음</span><strong>{state.managerTrust}</strong></div><div><span>피로</span><strong>{state.fatigue}</strong></div><div><span>1군 등록</span><strong>{state.serviceYears}년</strong></div><button type="button" onClick={onBack}>고교 기록</button></div></section>
    <div className="career-grid">
      <section className="ds-card ds-player-card career-panel career-player"><div className="lab-card-heading"><span>시즌 기록</span><small>{state.level === "major" ? "1군" : "2군"}</small></div>
        <div className="ds-record-grid career-rating-grid"><div><span>경기</span><strong>{state.currentStats.games}</strong></div><div><span>선발</span><strong>{state.currentStats.starts}</strong></div><div><span>탈삼진</span><strong>{state.currentStats.strikeouts}</strong></div><div><span>9이닝당 실점</span><strong>{runsPer9}</strong></div></div>
        <div className="career-personnel"><span>계약</span><strong>{state.contract ? `${state.contract.yearsRemaining}년 · ${Math.round(state.contract.annualSalary / 10_000)}만원` : "서명 전"}</strong><span>부상</span><strong>{state.injuryWeeks > 0 ? `${state.injuryWeeks}주 회복` : "정상"}</strong><span>통산</span><strong>{state.careerStats.length}시즌 · 수상 {state.awards.length}회</strong></div>
        {tensions.length > 0 ? <div className="pro-season-tensions"><span className="pro-tensions-heading">올해의 세 가지 긴장</span>{tensions.map((tension) => <div key={tension.kind} className="pro-tension" data-tension={tension.kind}><strong>{tension.title}</strong><small>{tension.detail}</small></div>)}</div> : null}
        <div className="pro-character-duo"><CharacterProfile label="같은 자리를 다투는 투수" title={state.team.positionCompetitor} record={state.team.competitorRecord} description={state.team.competitorProfile} /><CharacterProfile label="감독" title={state.team.proCoach} record={state.team.coachRecord} description={state.team.coachProfile} /></div>
        <div className="career-timeline"><span>주요 기록</span>{[...state.milestones].reverse().slice(0, 6).map((milestone, index) => <div key={milestone} className={index === 0 ? "is-latest" : undefined}><i aria-hidden="true" /><strong>{milestone}</strong></div>)}</div>
      </section>
      <section className="ds-card ds-card--raised career-panel career-decision"><div className="lab-card-heading"><span>지금 할 일</span><small>{state.phase === "weekly_plan" ? "이번 주" : state.phase === "important_game" ? "중요 경기" : state.phase === "season_review" ? "시즌 마무리" : state.phase === "offseason_decision" ? "오프시즌" : state.phase === "contract_offer" ? "신인 계약" : "커리어"}</small></div>
        {state.phase === "contract_offer" ? <div className="career-milestone"><span>신인 계약</span><h3>지명 구단과 첫 계약을 맺습니다.</h3><p>계약 뒤 2군 선발 경쟁부터 시작하며, 고교 기록과 구종은 그대로 이어집니다.</p><button className="ds-button ds-button--primary lab-primary" disabled={isRunning} onClick={() => void onSign()}>신인 계약 서명</button></div> : null}
        {state.phase === "weekly_plan" ? <><h3>{isProDebut ? "프로 데뷔를 준비합니다." : `${state.week + 1}주차`}</h3><p>{isProDebut ? "첫 공식 등판 전, 훈련과 휴식 중 이번 주에 집중할 것을 고르세요." : `현재 피로 ${state.fatigue}, 감독의 믿음 ${state.managerTrust}. 이번 주에 할 훈련이나 휴식을 고르세요.`}</p><div className="career-training-grid">{PLANS.map((item) => <button key={item.id} className={plan === item.id ? "is-selected" : undefined} aria-pressed={plan === item.id} onClick={() => setPlan(item.id)}><strong>{item.title}</strong><span>{item.copy}</span></button>)}</div><div className="pro-plan-actions"><button className="ds-button ds-button--primary lab-primary" disabled={isRunning} onClick={() => void onPlan(plan)}>{isProDebut ? "데뷔 주간 시작" : "1주 진행"}</button><button type="button" disabled={isRunning || isProDebut} onClick={() => void onPlanBlock(plan)}>같은 훈련으로 3주 진행<small>{isProDebut ? "첫 공식 등판 뒤부터 사용할 수 있습니다" : "중요 경기가 잡히거나 역할이 바뀌면 자동으로 멈춥니다"}</small></button></div></> : null}
        {state.phase === "important_game" ? <div className={`career-milestone${isMajorDebut ? " major-debut-card" : ""}`}><span>{isMajorDebut ? "1군 데뷔전" : `${state.week}주차 중요 경기`}</span><h3>{gameHeadline}</h3>
          {isMajorDebut ? <div className="major-debut-sequence" aria-live="polite">
            <p>2군의 긴 겨울을 지나, 처음으로 가득 찬 관중석 앞에 섭니다.</p>
            <p>{state.team.name} 유니폼을 입고 오르는 첫 1군 마운드입니다.</p>
            <p>여기서부터는 던지는 공 하나하나가 기록에 남습니다.</p>
          </div> : null}
          {rival
          ? <CharacterProfile className="rival-scouting" avatarRole="rival" label={`${rival.teamName} 중심타자`} title={`${rival.name} · ${rival.archetype}`} record={rival.record} description={rival.profile} />
          : <CharacterProfile className="rival-scouting" avatarRole="rival" label="상대 중심타자" title="상대 팀 간판 타자" description="상대 구단의 핵심 타자와 승부합니다." />}<p>한 점 차, 1사 2루. 잘 막으면 감독의 믿음을 얻고 더 중요한 등판 기회를 받습니다.</p><button className="ds-button ds-button--primary lab-primary" disabled={isRunning} onClick={() => void onGame()}>{isMajorDebut ? "1군 데뷔 마운드로" : "마운드로 나가기"}</button></div> : null}
        {state.phase === "season_review" ? <div className="career-milestone"><span>시즌 종료</span><h3>{state.season}시즌이 끝났습니다.</h3><button className="ds-button ds-button--primary lab-primary" disabled={isRunning} onClick={() => void onReview()}>시즌 기록 확인</button></div> : null}
        {state.phase === "offseason_decision" ? <><h3>내년에는 어디에서 던질까요?</h3><div className="relationship-options"><button disabled={isRunning} onClick={() => void onOffseason("continue")}><strong>현재 구단에 남는다</strong><span>같은 팀에서 선발·불펜 자리 경쟁을 계속한다</span></button><button disabled={isRunning || state.militaryCompleted} onClick={() => void onOffseason("military_service")}><strong>군 복무를 시작한다</strong><span>두 시즌 뒤 복귀한다</span></button><button disabled={isRunning || state.serviceYears < 6} onClick={() => void onOffseason("free_agency")}><strong>FA 시장에 나간다</strong><span>1군 등록 6년부터 선택 가능</span></button><button disabled={isRunning} onClick={() => void onOffseason("retire")}><strong>은퇴한다</strong><span>이 선수의 통산 기록을 확정한다</span></button></div></> : null}
        {state.phase === "retirement_decision" ? <div className="career-milestone"><span>마지막 시즌</span><h3>마지막 공을 기록에 남깁니다.</h3><button className="ds-button ds-button--primary lab-primary" disabled={isRunning} onClick={() => void onOffseason("retire")}>은퇴식 진행</button></div> : null}
        {state.phase === "completed" ? <div className="draft-result is-drafted"><span>프로 기록 완료</span><h3>{state.hallOfFameScore && state.hallOfFameScore >= 70 ? "명예의 전당 헌액" : "프로 커리어 종료"}</h3><p>명예의 전당 점수 {state.hallOfFameScore} · {state.careerStats.length}시즌 · 수상 {state.awards.length}회</p></div> : null}
        {error ? <p className="error-message" role="alert">{error}</p> : null}
      </section>
      <aside className="ds-card ds-record-grid career-panel career-news"><div className="lab-card-heading"><span>구단·리그 뉴스</span><small>눌러서 상세 보기</small></div>{state.awards.length > 0 ? <div className="award-strip"><span>수상</span>{state.awards.slice(-3).reverse().map((award) => <strong key={award}>{award}</strong>)}</div> : null}
        <CareerNewsFeed items={state.news} context={{ mode: "pro", playerName: state.pitcher.name, affiliation: state.team.name,
          period: `${state.season}시즌 ${state.week}주차`, trust: state.managerTrust, coachName: state.team.proCoach,
          level: state.level === "major" ? "1군" : "2군" }} />
      </aside>
    </div>
  </main>;
}
