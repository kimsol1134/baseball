using System;
using System.Collections.Generic;
using Baseball.Core.Random;

namespace Baseball.Core.HighSchool
{
    public static class ProspectRanking
    {
        public sealed class Entry { public Entry(int rank,string name,string school,string tag,bool isPlayer){Rank=rank;Name=name;School=school;Tag=tag;IsPlayer=isPlayer;} public int Rank{get;} public string Name{get;} public string School{get;} public string Tag{get;} public bool IsPlayer{get;} }
        public const int BoardSize=20;
        public static int? PlayerRank(CareerPerformanceSnapshot p){if(p.ImportantGamesCompleted<=0)return null;var score=p.Strikeouts*3-p.Walks*2-p.RunsAllowed*3+p.ImportantGamesCompleted*4;return Math.Max(1,60-score*59/90);}
        public static IReadOnlyList<Entry> Board(string careerId,string playerName,string playerSchool,CareerPerformanceSnapshot performance)
        {
            var rng=new SplitMix64(StableHash.Fnv1A64Value("prospect|"+careerId));
            var surnames=new[]{"강","고","권","김","도","문","박","배","서","신","안","유","이","임","정","조","차","최","한","황"};
            var given=new[]{"도현","민재","서준","예준","시우","하준","지호","은찬","준서","건우","현빈","태윤","재민","성민","규현","동주","찬영","우진","석현","영웅"};
            var schools=new[]{"북부상고","남해정보고","동성공고","서령고","중앙체고","한서고","대양고","청암고","금강고","삼도고"};
            var tags=new[]{"최고 구속으로 스카우트 보고서 첫 줄을 차지한 파이어볼러","존 네 귀퉁이를 마음대로 쓰는 완성형 제구","각이 다른 종변화구 — 헛스윙 유도 1위","3학년 여름에 만개한 늦깎이 에이스","이닝을 먹는 체력 — 완투가 기본","위기에서만 구속이 오르는 승부사","중학 시절부터 이름난 엘리트 코스","무명 학교에서 혼자 팀을 끌어올린 화제의 투수","타자들이 타이밍을 못 잡는 디셉션","부상 복귀 후 더 강해져 돌아온 재활의 표본"};
            var used=new HashSet<string>{playerName};var rivals=new List<string[]>();
            while(rivals.Count<BoardSize){var name=surnames[rng.NextInt(surnames.Length)]+given[rng.NextInt(given.Length)];if(!used.Add(name))continue;rivals.Add(new[]{name,schools[rng.NextInt(schools.Length)],tags[rng.NextInt(tags.Length)]});}
            var mine=PlayerRank(performance);var result=new List<Entry>();var ri=0;
            for(var rank=1;rank<=BoardSize;rank++){if(mine.HasValue&&rank==mine.Value)result.Add(new Entry(rank,playerName,playerSchool,"이 명단에서 유일하게 당신이 키우는 선수",true));else{var r=rivals[ri++];result.Add(new Entry(rank,r[0],r[1],r[2],false));}}
            return result;
        }
    }
}
