"use client";

import { useState } from "react";

const pitches = [
  {
    name: "포심",
    call: "몸쪽 높게",
    note: "구속으로 배트를 늦춥니다.",
  },
  {
    name: "슬라이더",
    call: "바깥쪽 낮게",
    note: "포수의 주 추천입니다.",
  },
  {
    name: "체인지업",
    call: "존 아래",
    note: "타이밍을 빼앗는 대안입니다.",
  },
] as const;

const zoneNames = [
  "몸쪽 높게",
  "가운데 높게",
  "바깥쪽 높게",
  "몸쪽",
  "가운데",
  "바깥쪽",
  "몸쪽 낮게",
  "가운데 낮게",
  "바깥쪽 낮게",
] as const;

function outcomeFor(pitch: number, zone: number) {
  if (pitch === 1 && zone === 8) {
    return {
      verdict: "탁월한 판단",
      title: "루킹 스트라이크",
      detail: "타자가 몸쪽 빠른 공을 기다렸고, 슬라이더가 바깥쪽 낮게 들어갔습니다.",
      path: "curve",
      tone: "positive",
    };
  }

  if (pitch === 0 && zone === 0) {
    return {
      verdict: "좋은 판단",
      title: "헛스윙",
      detail: "높은 포심으로 배트를 늦췄지만 실제 위치가 목표보다 조금 가운데로 몰렸습니다.",
      path: "rise",
      tone: "positive",
    };
  }

  if (zone === 4) {
    return {
      verdict: "위험한 선택",
      title: "강한 파울",
      detail: "타자가 기다린 코스였습니다. 판단은 위험했지만 파울로 살아남았습니다.",
      path: "flat",
      tone: "warning",
    };
  }

  return {
    verdict: "보통 판단",
    title: "볼",
    detail: "목표는 좋았지만 공이 존을 벗어났습니다. 선택과 실행은 따로 평가됩니다.",
    path: "drop",
    tone: "neutral",
  };
}

export function PitchDecision() {
  const [pitch, setPitch] = useState(1);
  const [zone, setZone] = useState(8);
  const [outcome, setOutcome] = useState<ReturnType<typeof outcomeFor> | null>(null);

  return (
    <div className="pitch-simulator">
      <div className="pitch-context" aria-label="경기 상황">
        <div>
          <small>전국 결승 · 8회 말</small>
          <strong>서울배성고 3 : 2 부산해남고</strong>
        </div>
        <span>2 OUT</span>
        <span>주자 1·2루</span>
        <span className="count-box">B 1 · S 2</span>
      </div>

      <div className="catcher-call">
        <span>포수 주 추천</span>
        <strong>슬라이더 · 바깥쪽 낮게 · 경계 승부</strong>
        <small>직전 두 공의 몸쪽 포심을 본 타자가 빠른 공을 기다립니다.</small>
      </div>

      <div className="pitch-layout">
        <div className="pitch-options">
          <p className="micro-label">구종 선택</p>
          {pitches.map((item, index) => (
            <button
              className={pitch === index ? "pitch-option is-selected" : "pitch-option"}
              key={item.name}
              onClick={() => {
                setPitch(index);
                setOutcome(null);
              }}
              type="button"
              aria-pressed={pitch === index}
            >
              <span className="option-index">{String.fromCharCode(65 + index)}</span>
              <span>
                <strong>{item.name}</strong>
                <small>{item.note}</small>
              </span>
              <em>{item.call}</em>
            </button>
          ))}
        </div>

        <div className="zone-picker">
          <p className="micro-label">목표 코스</p>
          <div className="strike-zone" role="group" aria-label="투구 위치 선택">
            {zoneNames.map((name, index) => (
              <button
                key={name}
                className={zone === index ? "zone-cell is-selected" : "zone-cell"}
                onClick={() => {
                  setZone(index);
                  setOutcome(null);
                }}
                type="button"
                aria-label={name}
                aria-pressed={zone === index}
              >
                <span>{index + 1}</span>
              </button>
            ))}
          </div>
          <strong className="zone-name">{zoneNames[zone]}</strong>
        </div>

        <div className="decision-panel">
          <p className="micro-label">이번 승부</p>
          <dl>
            <div>
              <dt>구종</dt>
              <dd>{pitches[pitch].name}</dd>
            </div>
            <div>
              <dt>목표</dt>
              <dd>{zoneNames[zone]}</dd>
            </div>
            <div>
              <dt>포수 사인</dt>
              <dd>{pitch === 1 && zone === 8 ? "수락" : "변경"}</dd>
            </div>
          </dl>

          <button
            className="throw-button"
            type="button"
            onClick={() => setOutcome(outcomeFor(pitch, zone))}
          >
            이 공을 던진다
          </button>
        </div>
      </div>

      <div className={outcome ? "pitch-result is-visible" : "pitch-result"} aria-live="polite">
        {outcome ? (
          <>
            <div className={`trajectory trajectory-${outcome.path}`} aria-hidden="true">
              <span className="target-dot" />
              <i />
              <b />
            </div>
            <div className="result-copy">
              <span className={`tone-${outcome.tone}`}>{outcome.verdict}</span>
              <strong>{outcome.title}</strong>
              <p>{outcome.detail}</p>
            </div>
            <button type="button" onClick={() => setOutcome(null)}>
              다른 공 선택
            </button>
          </>
        ) : (
          <p>구종과 목표 코스를 고른 뒤 결과를 확인하세요.</p>
        )}
      </div>
    </div>
  );
}
