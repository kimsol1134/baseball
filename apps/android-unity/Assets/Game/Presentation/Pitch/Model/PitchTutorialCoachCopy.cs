namespace Baseball.Presentation.Pitch
{
    /// <summary>Stable Korean tutorial copy shared by the portrait HUD and contract tests.</summary>
    public static class PitchTutorialCoachCopy
    {
        public const string Windup =
            "① 길게 눌러 와인드업 — 미터가 가운데 초록에 올 때 떼자. 구종과 코스는 포수가 골라 뒀다.";
        public const string MixCalls =
            "② 같은 곳에 두 번은 없다 — 구종이나 코스를 바꿔 타자의 눈을 흔들자.";
        public const string PutAway =
            "③ 결정구 — 상대가 약한 구종으로 유인하자. 존을 살짝 벗어나도 방망이가 나온다.";

        public static string For(int pitchNumber, int strikes)
        {
            if (strikes >= 2) return PutAway;
            return pitchNumber <= 1 ? Windup : MixCalls;
        }
    }
}
