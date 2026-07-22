"use client";

import { useState } from "react";

const pitches = [
  {
    name: "몸쪽 포심",
    chance: "46%",
    note: "구속으로 승부",
  },
  {
    name: "낮은 바깥쪽 슬라이더",
    chance: "28%",
    note: "타자의 시선을 흔든다",
  },
  {
    name: "빠른 체인지업",
    chance: "16%",
    note: "타이밍을 빼앗는다",
  },
] as const;

function outcomeFor(pitch: number, zone: number) {
  if (pitch === 1 && (zone === 7 || zone === 8)) {
    return {
      title: "헛스윙 삼진",
      detail: "변화구에 반응이 늦었습니다.",
      tone: "positive",
    };
  }

  if (zone === 0 || zone === 2 || zone === 6) {
    return {
      title: "볼",
      detail: "승부가 깊어졌습니다. 다음 공이 더 중요합니다.",
      tone: "warning",
    };
  }

  if (pitch === 0 && zone === 4) {
    return {
      title: "강한 파울",
      detail: "타자가 빠른 공을 기다리고 있었습니다.",
      tone: "negative",
    };
  }

  return {
    title: "스트라이크",
    detail: "카운트를 유리하게 가져옵니다.",
    tone: "positive",
  };
}

export function PitchDecision() {
  const [pitch, setPitch] = useState(1);
  const [zone, setZone] = useState(8);
  const [outcome, setOutcome] = useState<ReturnType<typeof outcomeFor> | null>(null);

  return (
    <div className="pitch-simulator">
      <div className="pitch-context" aria-label="경기 상황">
        <span>7회 말</span>
        <span>2 OUT</span>
        <span>주자 1·2루</span>
        <strong>7 : 5</strong>
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
              <span className="chance">{item.chance}</span>
            </button>
          ))}
        </div>

        <div className="zone-picker">
          <p className="micro-label">스트라이크 존</p>
          <div className="strike-zone" role="group" aria-label="투구 위치 선택">
            {Array.from({ length: 9 }, (_, index) => (
              <button
                key={index}
                className={zone === index ? "zone-cell is-selected" : "zone-cell"}
                onClick={() => {
                  setZone(index);
                  setOutcome(null);
                }}
                type="button"
                aria-label={`${index + 1}번 위치`}
                aria-pressed={zone === index}
              >
                {index + 1}
              </button>
            ))}
          </div>
        </div>

        <div className="decision-panel">
          <p className="micro-label">선택 판단</p>
          <dl>
            <div>
              <dt>구종</dt>
              <dd>{pitches[pitch].name}</dd>
            </div>
            <div>
              <dt>목표</dt>
              <dd>{zone + 1}번 존</dd>
            </div>
            <div>
              <dt>리스크</dt>
              <dd>{zone === 4 ? "높음" : "보통"}</dd>
            </div>
          </dl>

          <button
            className="throw-button"
            type="button"
            onClick={() => setOutcome(outcomeFor(pitch, zone))}
          >
            이 공을 던진다
          </button>

          <div className="outcome" aria-live="polite">
            {outcome ? (
              <>
                <strong className={`tone-${outcome.tone}`}>{outcome.title}</strong>
                <span>{outcome.detail}</span>
              </>
            ) : (
              <span>구종과 위치를 고른 뒤 결과를 확인하세요.</span>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
