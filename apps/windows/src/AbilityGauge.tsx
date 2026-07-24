import { useEffect, useState } from "react";

interface AbilityGaugeProps {
  label: string;
  value: number;
  displayValue?: string;
  beforeValue?: number;
  lowerBound?: number;
  upperBound?: number;
  compact?: boolean;
}

function clampRating(value: number) {
  return Math.min(80, Math.max(20, value));
}

function ratingPosition(value: number) {
  return (clampRating(value) - 20) / 60 * 100;
}

export function ratingTier(value: number) {
  const rating = clampRating(value);
  return rating >= 65 ? "strength" : rating >= 50 ? "above-average" : rating >= 40 ? "average" : "weakness";
}

export function AbilityGauge({ label, value, displayValue, beforeValue, lowerBound, upperBound, compact = false }: AbilityGaugeProps) {
  const current = clampRating(value);
  const previous = beforeValue === undefined ? current : clampRating(beforeValue);
  const gained = beforeValue !== undefined && current > previous;
  const [animatedValue, setAnimatedValue] = useState(gained ? previous : current);
  useEffect(() => {
    if (!gained) { setAnimatedValue(current); return; }
    setAnimatedValue(previous);
    const frame = window.requestAnimationFrame(() => setAnimatedValue(current));
    return () => window.cancelAnimationFrame(frame);
  }, [current, gained, previous]);
  const tier = ratingTier(current);
  const currentText = beforeValue === undefined
    ? `${label} ${displayValue ?? current}`
    : `${label} ${clampRating(beforeValue)}에서 ${current}`;
  const hasRange = lowerBound !== undefined && upperBound !== undefined;
  const valueText = hasRange ? `${currentText}, 성장 예상 ${clampRating(lowerBound)}에서 ${clampRating(upperBound)}` : currentText;

  if (hasRange) {
    return <div className={`ds-ability-gauge is-dual${compact ? " is-compact" : ""}`} data-tier={tier}
      role="meter" aria-label={valueText} aria-valuemin={20} aria-valuemax={80} aria-valuenow={current}>
      <span className="ds-ability-gauge__row">{compact ? null : <small aria-hidden="true">현재</small>}
        <span className="ds-ability-gauge__track"><i style={{ width: `${ratingPosition(current)}%` }} /></span></span>
      <span className="ds-ability-gauge__row is-potential">{compact ? null : <small aria-hidden="true">잠재</small>}
        <span className="ds-ability-gauge__track"><i style={{ width: `${ratingPosition(upperBound)}%` }} /></span></span>
    </div>;
  }
  return <div className={`ds-ability-gauge${compact ? " is-compact" : ""}${gained ? " is-gain" : ""}`} data-tier={tier}
    role="meter" aria-label={valueText} aria-valuemin={20} aria-valuemax={80} aria-valuenow={current}>
    <i style={{ width: `${ratingPosition(animatedValue)}%` }} />
    {beforeValue === undefined ? null : <b style={{ left: `${ratingPosition(beforeValue)}%` }} aria-hidden="true" />}
  </div>;
}
