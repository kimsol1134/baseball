using System;
using Baseball.Core.Domain;
using Baseball.Core.Pitching;

namespace Baseball.Presentation.Pitch
{
    public sealed class PitchHudContent
    {
        public PitchHudContent(
            string situation,
            string batter,
            string recommendation,
            string scouting,
            string rival,
            string pitcher)
        {
            Situation = situation ?? string.Empty;
            Batter = batter ?? string.Empty;
            Recommendation = recommendation ?? string.Empty;
            Scouting = scouting ?? string.Empty;
            Rival = rival ?? string.Empty;
            Pitcher = pitcher ?? string.Empty;
        }

        public string Situation { get; }
        public string Batter { get; }
        public string Recommendation { get; }
        public string Scouting { get; }
        public string Rival { get; }
        public string Pitcher { get; }
    }

    /// <summary>Pure Korean projection over the exact durable pitch request and Core preparation.</summary>
    public static class PitchHudProjection
    {
        public static PitchHudContent Project(PitchPlayViewState state)
        {
            if (state == null) throw new ArgumentNullException(nameof(state));
            PlateAppearanceContext context = state.Context;
            PitcherSnapshot pitcher = state.Pitcher;
            BatterSnapshot batter = state.Batter;
            BatterScoutingSnapshot scouting = state.Scouting;
            GameStateSnapshot gameState = state.GameState;
            PitchPreparation preparation = state.Preparation;

            string situation = context.Inning + "회 · " + context.Outs + "아웃 · " +
                Score(context.ScoreDifferential) + " · " + Runners(gameState) +
                " · 피로 " + context.Fatigue + " · 중요도 " + Leverage(context.Leverage);
            string batterCopy = batter.Name + " · " + BatSideName(batter.BatSide) +
                " · 컨택 " + batter.Contact + " · 선구 " + batter.Discipline + " · 장타 " + batter.Power;
            string recommendation = Recommendation(preparation?.PrimaryRecommendation, state.HoldsCall);
            string scoutingCopy = scouting == null
                ? "스카우팅 기록 없음"
                : "강점 " + PitchKoreanCopy.PitchTypeName(scouting.PitchStrength) +
                  " · 약점 " + PitchKoreanCopy.PitchTypeName(scouting.PitchWeakness) +
                  " · 뜨거운 곳 " + PitchKoreanCopy.ZoneName(scouting.HotZone) +
                  " · 차가운 곳 " + PitchKoreanCopy.ZoneName(scouting.ColdZone) +
                  " · 유인구 반응 " + scouting.ChaseTendency +
                  " · 신뢰 " + scouting.Reliability / 10 + "%";
            string rival = Rival(preparation?.RivalAdaptation, state.RivalMemory);
            string pitcherCopy = pitcher == null
                ? "육성 능력 기록 없음"
                : "구위 " + pitcher.Stuff + " · 제구 " + pitcher.Command +
                  " · 변화 " + pitcher.Movement + " · 체력 " + pitcher.Stamina;
            return new PitchHudContent(
                situation,
                batterCopy,
                recommendation,
                scoutingCopy,
                rival,
                pitcherCopy);
        }

        private static string Score(int differential) =>
            differential == 0 ? "동점" : differential > 0
                ? "우리 팀 " + differential + "점 리드"
                : "우리 팀 " + Math.Abs(differential) + "점 뒤짐";

        private static string Runners(GameStateSnapshot gameState)
        {
            if (gameState == null) return "주자 정보 없음";
            BaserunnerStateSnapshot runners = gameState.Runners;
            if (runners.OccupiedCount == 0) return "주자 없음";
            string value = string.Empty;
            if (runners.FirstOccupied) value = "1루";
            if (runners.SecondOccupied) value += (value.Length == 0 ? string.Empty : "·") + "2루";
            if (runners.ThirdOccupied) value += (value.Length == 0 ? string.Empty : "·") + "3루";
            return "주자 " + value;
        }

        private static string Leverage(int value) =>
            value >= 750 ? "매우 높음" : value >= 400 ? "높음" : "보통";

        private static string BatSideName(BatSide side)
        {
            switch (side)
            {
                case BatSide.Left: return "좌타";
                case BatSide.Switch: return "스위치 타자";
                default: return "우타";
            }
        }

        private static string Recommendation(
            CatcherRecommendationSnapshot recommendation,
            bool holdsCall)
        {
            if (recommendation?.Call == null) return "포수 사인을 준비하고 있습니다.";
            return "포수 사인 · " + PitchKoreanCopy.PitchTypeName(recommendation.Call.PitchType) +
                " · " + PitchKoreanCopy.ZoneName(recommendation.Call.Zone) +
                " · " + PitchKoreanCopy.IntentName(recommendation.Call.ZoneIntent) +
                " · 확신 " + recommendation.Confidence / 10 + "% · " +
                (holdsCall ? "내 선택 유지 중" : "포수 사인 사용 중") +
                (string.IsNullOrWhiteSpace(recommendation.ShortReason)
                    ? string.Empty
                    : "\n" + recommendation.ShortReason);
        }

        private static string Rival(
            RivalAdaptationSnapshot adaptation,
            RivalMemorySnapshot memory)
        {
            if (adaptation != null)
            {
                string band = adaptation.Band == RivalAdaptationBand.LockedOn ? "패턴을 읽음" :
                    adaptation.Band == RivalAdaptationBand.Learning ? "배합을 학습 중" :
                    adaptation.Band == RivalAdaptationBand.Watching ? "배합을 관찰 중" : "읽은 패턴 없음";
                return "라이벌 대응 · " + band + " · 근거 " + adaptation.EvidenceCount +
                    " · 확신 " + adaptation.Confidence / 10 + "%" +
                    (string.IsNullOrWhiteSpace(adaptation.Warning) ? string.Empty : " · " + adaptation.Warning);
            }
            return memory == null
                ? "라이벌 대응 기록 없음"
                : "라이벌 대응 · 맞대결 " + memory.PlateAppearancesSeen +
                  "타석 · 관찰 " + memory.TotalPitchesSeen + "구";
        }
    }
}
