using System;
using Baseball.Core.Random;

namespace Baseball.Core.Pro
{
    public enum ProSeasonClimate { Hot, Even, Slump, Adapted }
    public enum AutoCallPolicy { Perfect, Mixed, Slump }

    public static class ProSeasonClimateRules
    {
        public static int Offset(ProSeasonClimate climate)
        {
            switch (climate)
            {
                case ProSeasonClimate.Hot: return -2;
                case ProSeasonClimate.Slump: return 3;
                case ProSeasonClimate.Adapted: return 2;
                default: return 0;
            }
        }

        public static AutoCallPolicy CallPolicy(ProSeasonClimate climate)
        {
            return climate == ProSeasonClimate.Slump ? AutoCallPolicy.Slump : AutoCallPolicy.Mixed;
        }

        public static string NewsLine(ProSeasonClimate climate, int week)
        {
            switch (climate)
            {
                case ProSeasonClimate.Hot:
                    return week + "주차 · 상대 타선이 흔들린다. 오늘 공은 잘 먹힐 공기가 있다.";
                case ProSeasonClimate.Slump:
                    return week + "주차 · 타선이 직구를 기다리기 시작했다. 한동안 쉽지 않다.";
                case ProSeasonClimate.Adapted:
                    return week + "주차 · 상대 벤치가 내 구종 순서를 읽고 있다.";
                default:
                    return week + "주차 · 리그는 평이하다. 리듬을 지키는 주다.";
            }
        }

        public static ProSeasonClimate Climate(string careerId, int season, int week, int strikeouts = 0, int inningsOuts = 0, int stabilizeCharges = 0)
        {
            if (week < 1) return ProSeasonClimate.Even;
            if (stabilizeCharges > 0) return ProSeasonClimate.Even;
            var block = SlumpBlock(careerId, season);
            if (week >= block.Item1 && week <= block.Item2) return ProSeasonClimate.Slump;
            if (week >= 14 && strikeouts * 27000 / Math.Max(1, inningsOuts) >= 9000)
            {
                if (Hash(careerId + "|season" + season + "|week" + week + "|adapted") % 100 < 40)
                    return ProSeasonClimate.Adapted;
            }
            if (Hash(careerId + "|season" + season + "|week" + week + "|hot") % 100 < 15)
                return ProSeasonClimate.Hot;
            return ProSeasonClimate.Even;
        }

        public static Tuple<int, int> SlumpBlock(string careerId, int season)
        {
            var start = 7 + (int)(Hash(careerId + "|season" + season + "|slump-start") % 10);
            var length = 2 + (int)(Hash(careerId + "|season" + season + "|slump-length") % 3);
            return Tuple.Create(start, Math.Min(20, start + length - 1));
        }

        private static ulong Hash(string value)
        {
            ulong hash;
            return ulong.TryParse(StableHash.Fnv1A64(value), System.Globalization.NumberStyles.HexNumber, null, out hash)
                ? hash
                : 0;
        }
    }
}
