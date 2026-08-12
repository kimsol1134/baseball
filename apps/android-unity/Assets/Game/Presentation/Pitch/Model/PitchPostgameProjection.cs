using System;
using System.Collections.Generic;
using System.Linq;
using Baseball.Application.HighSchool;
using Baseball.Application.Persistence;

namespace Baseball.Presentation.Pitch
{
    public sealed class PitchPostgameLine
    {
        public PitchPostgameLine(string title, string detail)
        {
            Title = title ?? string.Empty;
            Detail = detail ?? string.Empty;
        }

        public string Title { get; }
        public string Detail { get; }
    }

    public sealed class PitchPostgameContent
    {
        public PitchPostgameContent(
            string summary,
            string analysis,
            string growth,
            IReadOnlyList<PitchPostgameLine> pitches)
        {
            Summary = summary ?? string.Empty;
            Analysis = analysis ?? string.Empty;
            Growth = growth ?? string.Empty;
            Pitches = pitches ?? Array.Empty<PitchPostgameLine>();
        }

        public string Summary { get; }
        public string Analysis { get; }
        public string Growth { get; }
        public IReadOnlyList<PitchPostgameLine> Pitches { get; }
    }

    public static class PitchPostgameProjection
    {
        public static PitchPostgameContent Project(
            PitchGameReport report,
            IReadOnlyList<PitchLogEntryState> pitchLog)
        {
            if (report == null) throw new ArgumentNullException(nameof(report));
            var log = (pitchLog ?? Array.Empty<PitchLogEntryState>())
                .Where(value => value != null)
                .ToArray();
            string summary = report.Batters + "타자 · " + report.Pitches + "구 · " +
                report.Outs + "아웃 · 탈삼진 " + report.Strikeouts + " · 볼넷 " + report.Walks +
                " · 피안타 " + report.Hits + " · 실점 " + report.RunsAllowed;
            string analysis = "기대 피해 " + report.ExpectedDamage + " · 실제 피해 " + report.ActualDamage +
                " · 포수 사인 수락 " + report.RecommendationAccepted + "/" + report.Pitches;
            string abilityTypes = report.AbilityMomentTypes == null || report.AbilityMomentTypes.Count == 0
                ? "없음"
                : string.Join("·", report.AbilityMomentTypes.Select(AbilityName));
            string growth = "수싸움 성장 " + report.SequenceMasteryCount +
                " · 능력 발현 " + report.AbilityMomentCount + "(" + abilityTypes + ")" +
                " · 직접 릴리스 " + report.DirectDeliveryCount +
                " · 완벽 릴리스 " + report.PerfectDeliveryCount;
            var lines = log.Select(value => new PitchPostgameLine(
                (value.BatterIndex + 1) + "번 타자 · " + value.PitchNumber + "구 · " +
                PitchTypeName(value.PitchType) + " · " + ZoneName(value.ZoneRow, value.ZoneColumn) +
                " · " + OutcomeName(value.Outcome),
                value.VelocityTenthsKph / 10.0 + "km/h · 구질 변화 " +
                value.HorizontalBreakTenthsCm / 10.0 + "/" + value.VerticalBreakTenthsCm / 10.0 + "cm" +
                " · 실행 " + value.ExecutionQuality + " · 목표 " + Coordinate(value.TargetX, value.TargetY) +
                " → 실제 " + Coordinate(value.ActualX, value.ActualY) +
                " · " + (value.SignAccepted ? "포수 사인 수락" : "직접 배합"))).ToArray();
            return new PitchPostgameContent(summary, analysis, growth, lines);
        }

        private static string PitchTypeName(string value)
        {
            switch (value)
            {
                case "four_seam": return "직구";
                case "slider": return "슬라이더";
                case "curveball": return "커브";
                case "changeup": return "체인지업";
                default: return "구종 기록 없음";
            }
        }

        private static string OutcomeName(string value)
        {
            switch (value)
            {
                case "ball": return "볼";
                case "called_strike": return "스트라이크";
                case "swinging_strike": return "헛스윙";
                case "foul": return "파울";
                case "in_play_out": return "범타";
                case "single": return "안타";
                case "double": return "2루타";
                case "triple": return "3루타";
                case "home_run": return "홈런";
                case "hit_by_pitch": return "몸에 맞는 공";
                default: return "결과 기록 없음";
            }
        }

        private static string ZoneName(int row, int column) =>
            PitchKoreanCopy.ZoneName(new Baseball.Core.Domain.PitchZone(row, column));

        private static string Coordinate(int x, int y) =>
            "(" + x + "," + y + ")";

        private static string AbilityName(string value)
        {
            switch (value)
            {
                case "power": return "구위";
                case "command": return "제구";
                case "movement": return "변화";
                default: return "기록 없음";
            }
        }
    }
}
