using System;
using Baseball.Core.Random;

namespace Baseball.Core.HighSchool
{
    public static class ChapterGoal
    {
        public sealed class Goal
        {
            public Goal(string title,string detail,int targetStrikeouts){Title=title;Detail=detail;TargetStrikeouts=targetStrikeouts;}
            public string Title{get;} public string Detail{get;} public int TargetStrikeouts{get;}
        }
        public static Goal Get(string careerId,int chapterNumber)
        {
            var generator=new SplitMix64(StableHash.Fnv1A64Value("goal|"+careerId+"|"+chapterNumber));
            var target=3+Math.Min(chapterNumber,5)+generator.NextInt(3);
            var frames=new[] {
                new[]{"감독의 숙제","감독이 지나가듯 말했다 — 이번 이야기에 삼진 "+target+"개는 잡아 보라고."},
                new[]{"스카우트의 시선","관중석 뒤편의 수첩이 이번 이야기 탈삼진 "+target+"개를 기다립니다."},
                new[]{"포수의 내기","포수가 장비를 챙기며 웃었다 — 이번 이야기 삼진 "+target+"개, 내기할까?"},
                new[]{"나와의 약속","소등 전에 적어 둔 한 줄 — 이번 이야기, 삼진 "+target+"개."}
            };
            var frame=frames[generator.NextInt(frames.Length)]; return new Goal(frame[0],frame[1],target);
        }
    }
}
