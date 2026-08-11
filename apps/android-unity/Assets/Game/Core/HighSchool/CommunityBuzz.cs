using System.Collections.Generic;
using System.Linq;
using Baseball.Core.Random;

namespace Baseball.Core.HighSchool
{
    public static class CommunityBuzz
    {
        public static IReadOnlyList<string> Reactions(string careerId,int gameNumber,int strikeouts,int walks,int runsAllowed,string newNickname=null){var rng=new SplitMix64(StableHash.Fnv1A64Value("buzz|"+careerId+"|"+gameNumber));var r=new List<string>();if(newNickname!=null)r.Add(Pick(ref rng,new[]{"'"+newNickname+"' 별명 붙은 거 봤음? 인정할 수밖에 없긴 함","요즘 다들 '"+newNickname+"' 하고 부르던데 찰떡이긴 하다","별명이 '"+newNickname+"'... 고교야구에서 별명 생기면 진짜라는 뜻임"}));
            if(runsAllowed==0&&strikeouts>=5)r.Add(Pick(ref rng,new[]{"오늘 경기 직관했는데 상대 타자들이 공을 아예 못 봄","무실점에 탈삼진 "+strikeouts+"개면 고교 레벨이 아닌 듯","저 나이에 저런 공을 던진다고? 더 크면 어떻게 되는 거임?","스카우트들 오늘 수첩에 뭐라고 적었을지 궁금하다"}));else if(runsAllowed==0)r.Add(Pick(ref rng,new[]{"화려하진 않은데 점수를 안 줌. 이런 투수가 무서운 거임","오늘도 무실점. 조용히 꾸준한 게 제일 어려운 건데","상대 팀 응원석이 조용해지는 게 보이더라"}));else if(walks>=3)r.Add(Pick(ref rng,new[]{"공은 좋은데 볼넷 "+walks+"개는 좀... 제구 잡히는 게 관건일 듯","오늘 볼넷이 너무 많았음. 본인이 제일 답답했을 듯","구위는 진짜인데 어디로 갈지 모르는 게 함정"}));else if(runsAllowed>=4)r.Add(Pick(ref rng,new[]{"오늘은 공이 다 몰리더라. 이런 날도 있는 거지",runsAllowed+"실점... 다음 경기에서 어떻게 나오는지가 진짜 시험임","무너진 날 다음이 진짜라고 생각함. 지켜본다"}));else if(strikeouts>=4)r.Add(Pick(ref rng,new[]{"탈삼진 "+strikeouts+"개 ㅎㄷㄷ 2스트라이크 잡히면 끝나는 분위기였음","헛스윙 나오는 각도가 다르던데 저거 무슨 공임?","삼진 잡는 리듬이 좋아졌음. 작년이랑 완전 다른 선수 같음"}));
            var general=new[]{"저 선수 몇 학년임? 체격 좋아 보이던데","다음 경기 언제임? 직관 가고 싶은데","훈련을 어떻게 하길래 저렇게 던짐?","프로 갈 생각 있는 선수임? 벌써 궁금하네","경기 밖에서는 어떤 스타일인지 궁금함","부상 없이 쭉 갔으면 좋겠다. 관리 잘 받고 있겠지?","작년에도 이 정도였음? 갑자기 좋아진 것 같은데","저 학교 갑자기 왜 이렇게 강해짐?"};while(r.Count<3){var s=Pick(ref rng,general);if(!r.Contains(s))r.Add(s);}return r;}
        public static IReadOnlyList<string> RivalNews(string careerId,int chapter){var rng=new SplitMix64(StableHash.Fnv1A64Value("rival-news|"+careerId+"|"+chapter));var board=ProspectRanking.Board(careerId,"","",new CareerPerformanceSnapshot()).Where(x=>!x.IsPlayer).ToArray();var k=10+rng.NextInt(5);var v=2+rng.NextInt(4);var templates=new System.Func<int,string>[] {i=>board[i].Name+"("+board[i].School+")이 지역 대회 결승에서 완봉승. 스카우트석이 가득 찼다는 후문.",i=>board[i].Name+"("+board[i].School+"), 팔꿈치 통증으로 등판을 걸렀다. 관리 실패라는 말과 신중하다는 말이 갈린다.",i=>board[i].Name+"("+board[i].School+")이 한 경기 탈삼진 "+k+"개 — 또래 최고 기록에 다가섰다.",i=>board[i].Name+"("+board[i].School+")의 구속이 봄보다 "+v+"km/h 올랐다. 겨울에 무엇을 했는지 다들 궁금해한다.",i=>board[i].Name+"("+board[i].School+"), 부진 끝에 선발에서 밀렸다. 재조정이 필요해 보인다."};var result=new List<string>();var people=new HashSet<int>();var used=new HashSet<int>();while(result.Count<2){var who=rng.NextInt(System.Math.Min(8,board.Length));var t=rng.NextInt(templates.Length);if(!people.Add(who)||!used.Add(t))continue;result.Add(templates[t](who));}return result;}
        private static string Pick(ref SplitMix64 rng,string[] pool)=>pool[rng.NextInt(pool.Length)];
    }
}
