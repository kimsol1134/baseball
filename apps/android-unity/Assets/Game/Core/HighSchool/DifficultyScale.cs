using System;
using Baseball.Core.Domain;
using Baseball.Core.Pro;

namespace Baseball.Core.HighSchool
{
    public static class DifficultyScale
    {
        public const int ChapterCeiling=3, RebirthCeiling=4, SeasonCeiling=8, TrackingCeiling=6, ArcCeiling=14;
        public static int HighSchool(int chapter,int lifeNumber) => Math.Min(ChapterCeiling,Math.Max(0,chapter-1)*ChapterCeiling/7)+Math.Min(RebirthCeiling,Math.Max(0,lifeNumber-1)*2);
        public static int Pro(int season)=>Math.Min(SeasonCeiling,Math.Max(0,season-1));
        public static int TrackingBonus(int season, ProLevel level, int skill) =>
            season >= 5 && level == ProLevel.Major ? Math.Min(TrackingCeiling, Math.Max(0, (skill - 58) / 3)) : 0;
        public static int ProArc(int season, ProLevel level, int skill, ProSeasonClimate climate)
        {
            var combined = Pro(season) + TrackingBonus(season, level, skill) + ProSeasonClimateRules.Offset(climate);
            return Math.Min(ArcCeiling, Math.Max(-2, combined));
        }
        public static BatterSnapshot Scaled(BatterSnapshot batter,int offset) => offset==0?batter:new BatterSnapshot(batter.Id,batter.Name,Bump(batter.Contact,offset),Bump(batter.Discipline,offset),Bump(batter.Power,offset),batter.BatSide);
        private static int Bump(int value,int offset)=>Math.Min(80,Math.Max(20,value+offset));
    }
}
