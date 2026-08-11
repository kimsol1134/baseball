using System;

namespace Baseball.Core.Domain
{
    public enum PersonalityTrait { Closer, Anchor, Tactician, Opener }

    public sealed class Personality
    {
        public Personality(string title, string scoutLine, PersonalityTrait trait)
        {
            Title = title;
            ScoutLine = scoutLine;
            Trait = trait;
        }

        public string Title { get; }
        public string ScoutLine { get; }
        public PersonalityTrait Trait { get; }
    }

    public static class PersonalityRules
    {
        public const int CrystallizationThreshold = 5;

        public static Personality Resolve(int listen, int explain, int challenge)
        {
            var total = listen + explain + challenge;
            if (total < CrystallizationThreshold) return null;
            var dominant = Math.Max(listen, Math.Max(explain, challenge));
            if (dominant * 100 < total * 45)
            {
                return new Personality(
                    "유연한 중심",
                    "상황에 맞는 얼굴을 꺼낼 줄 압니다. 어느 클럽하우스에 놓아도 제 몫을 하는 유형.",
                    PersonalityTrait.Opener);
            }

            if (dominant == challenge)
            {
                return new Personality(
                    "불같은 승부사",
                    "물러서는 법을 모릅니다. 큰 경기, 큰 타자 앞에서 구속이 오르는 유형.",
                    PersonalityTrait.Closer);
            }

            if (dominant == listen)
            {
                return new Personality(
                    "조용한 버팀목",
                    "끝까지 듣고 먼저 움직입니다. 시간이 지나면 클럽하우스가 이 선수를 중심으로 돕니다.",
                    PersonalityTrait.Anchor);
            }

            return new Personality(
                "차가운 분석가",
                "감정을 빼고 근거로 답합니다. 타자와의 수싸움을 스스로 설계할 줄 아는 머리.",
                PersonalityTrait.Tactician);
        }
    }

    public static class PersonalityTraitRules
    {
        public static string Title(this PersonalityTrait trait)
        {
            switch (trait)
            {
                case PersonalityTrait.Closer: return "결정구";
                case PersonalityTrait.Anchor: return "위기의 어깨";
                case PersonalityTrait.Tactician: return "수싸움";
                case PersonalityTrait.Opener: return "초구 장악";
                default: throw new ArgumentOutOfRangeException(nameof(trait));
            }
        }

        public static bool Fires(
            this PersonalityTrait trait,
            int strikes,
            int pitchNumber,
            bool hasRunner)
        {
            switch (trait)
            {
                case PersonalityTrait.Closer: return strikes == 2;
                case PersonalityTrait.Anchor: return hasRunner;
                case PersonalityTrait.Tactician: return pitchNumber >= 5;
                case PersonalityTrait.Opener: return pitchNumber == 1;
                default: return false;
            }
        }

        public static int ContactAdjustment(this PersonalityTrait trait)
        {
            switch (trait)
            {
                case PersonalityTrait.Closer: return -14;
                case PersonalityTrait.Anchor: return -12;
                case PersonalityTrait.Tactician: return -16;
                case PersonalityTrait.Opener: return -10;
                default: return 0;
            }
        }

        public static int QualityAdjustment(this PersonalityTrait trait)
        {
            switch (trait)
            {
                case PersonalityTrait.Closer: return -12;
                case PersonalityTrait.Anchor: return -10;
                case PersonalityTrait.Tactician: return -12;
                case PersonalityTrait.Opener: return -10;
                default: return 0;
            }
        }
    }
}
