using Baseball.Core.Domain;
using Baseball.Core.Pitching;

namespace Baseball.Presentation.Pitch
{
    public static class PitchKoreanCopy
    {
        public static string PitchTypeName(PitchType pitchType)
        {
            switch (pitchType)
            {
                case PitchType.FourSeam: return "직구";
                case PitchType.Slider: return "슬라이더";
                case PitchType.Curveball: return "커브";
                default: return "체인지업";
            }
        }

        public static string ZoneName(PitchZone zone)
        {
            string vertical = zone.Row == 0 ? "높은" : zone.Row == 2 ? "낮은" : "가운데";
            string horizontal = zone.Column == 0 ? "왼쪽" : zone.Column == 2 ? "오른쪽" : "가운데";
            if (zone.Row == 1 && zone.Column == 1) return "한가운데";
            return vertical + " " + horizontal;
        }

        public static string IntentName(ZoneIntent intent)
        {
            switch (intent)
            {
                case ZoneIntent.Edge: return "경계";
                case ZoneIntent.Chase: return "유인구";
                default: return "스트라이크";
            }
        }

        public static string IntensityName(PitchIntensity intensity)
        {
            switch (intensity)
            {
                case PitchIntensity.Controlled: return "힘 조절";
                case PitchIntensity.MaxEffort: return "전력";
                default: return "보통";
            }
        }

        public static string OutcomeName(PitchOutcome outcome)
        {
            switch (outcome)
            {
                case PitchOutcome.Ball: return "볼";
                case PitchOutcome.CalledStrike: return "스트라이크";
                case PitchOutcome.SwingingStrike: return "헛스윙 스트라이크";
                case PitchOutcome.Foul: return "파울";
                case PitchOutcome.InPlayOut: return "범타";
                case PitchOutcome.Single: return "안타";
                case PitchOutcome.Double: return "2루타";
                case PitchOutcome.Triple: return "3루타";
                case PitchOutcome.HomeRun: return "홈런";
                default: return "몸에 맞는 공";
            }
        }

        public static string AbilityMomentName(string abilityMomentType)
        {
            switch (abilityMomentType)
            {
                case "power": return "구위가 빛난 공";
                case "command": return "제구가 빛난 공";
                case "movement": return "움직임이 빛난 공";
                default: return string.Empty;
            }
        }
    }
}
