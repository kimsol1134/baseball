using System.Collections.Generic;
using Baseball.Core.Random;

namespace Baseball.Core.HighSchool
{
    public static class TournamentBracket
    {
        public sealed class Field { public Field(string tournamentName,IReadOnlyList<string> schools,string playerRound){TournamentName=tournamentName;Schools=schools;PlayerRound=playerRound;} public string TournamentName{get;} public IReadOnlyList<string> Schools{get;} public string PlayerRound{get;} }
        public static bool IsTournamentChapter(int chapter)=>chapter==2||chapter==4||chapter==6||chapter==8;
        public static string TournamentName(int chapter)=>chapter==2?"청룡곡 여름 초청전":chapter==4?"전국 화랑기":chapter==6?"가을 왕중왕전":"최후의 여름 — 전국 선수권";
        public static Field GetField(string careerId,int chapter,string playerSchool){var rng=new SplitMix64(StableHash.Fnv1A64Value("bracket|"+careerId+"|"+chapter));var pool=new[]{"북부상고","남해정보고","동성공고","서령고","중앙체고","한서고","대양고","청암고","금강고","삼도고","백파고","운암공고"};var used=new HashSet<string>{playerSchool};var teams=new List<string>();while(teams.Count<7){var s=pool[rng.NextInt(pool.Length)];if(used.Add(s))teams.Add(s);}teams.Insert(rng.NextInt(8),playerSchool);return new Field(TournamentName(chapter),teams,chapter>=8?"결승":chapter>=6?"준결승":"8강");}
    }
}
