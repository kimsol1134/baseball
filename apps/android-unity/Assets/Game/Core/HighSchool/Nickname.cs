using System.Collections.Generic;

namespace Baseball.Core.HighSchool
{
    public sealed class Nickname { public Nickname(string id,string title,string reason){Id=id;Title=title;Reason=reason;} public string Id{get;} public string Title{get;} public string Reason{get;} }
    public static class NicknameRules
    {
        public const int CatalogCount=13; public static readonly int[] StrikeoutLadder={25,50,100,200,300,500,1000};
        public static IReadOnlyList<Nickname> Earned(CareerPerformanceSnapshot p){var g=p.ImportantGamesCompleted;var k=p.Strikeouts;var w=p.Walks;var r=p.RunsAllowed;var n=new List<Nickname>();
            if(k>=45)n.Add(N("k-monster","삼진 지옥","통산 탈삼진 "+k+"개 — 상대 타선이 그 이름만으로 흔들립니다."));else if(k>=25)n.Add(N("k-machine","탈삼진 머신","통산 탈삼진 "+k+"개 — 배트가 닿지 않습니다."));else if(k>=15)n.Add(N("k-hunter","삼진 사냥꾼","통산 탈삼진 "+k+"개 — 2스트라이크가 되면 관중이 일어섭니다."));
            if(g>=5&&r==0)n.Add(N("iron-wall","철벽",g+"경기째 무실점 — 홈플레이트가 잠겨 있습니다."));else if(g>=3&&r==0)n.Add(N("zero","제로",g+"경기째 무실점 — 아직 한 점도 내주지 않았습니다."));
            if(g>=4&&w==0)n.Add(N("flawless","무결점",g+"경기 볼넷 0 — 존 밖으로 나가는 공이 없습니다."));else if(g>=3&&w<=g)n.Add(N("pinpoint","핀포인트","경기당 볼넷 1개 이하 — 공이 손끝의 말을 듣습니다."));
            if(k>=30&&r<=g)n.Add(N("untouchable","언터처블","삼진은 쌓이고 실점은 없다 — 고교 레벨을 벗어난 투구라는 평가입니다."));if(g>=4&&k>=g*6)n.Add(N("nine-k","닥터 나인","경기당 탈삼진 6개 이상 — 아웃 카운트 대부분을 혼자 책임집니다."));if(g>=5)n.Add(N("workhorse","철완",g+"번의 고교 공식 경기를 전부 소화 — 마운드에서 내려가지 않는 어깨입니다."));
            if(g>=3&&w>=g*3)n.Add(N("wild-thing","노 컨트롤","경기당 볼넷 3개 — 공이 어디로 갈지 본인도 모른다는 놀림입니다."));if(g>=3&&r>=g*4)n.Add(N("batting-practice","배팅볼","경기당 실점 4점 — 상대 타자들이 타격 훈련하러 온다는 조롱입니다."));if(g>=3&&k>=15&&r>=g*3)n.Add(N("rough-diamond","미완의 대기","삼진을 잡는 재능은 진짜인데 실점이 그만큼 따라옵니다 — 다듬으면 무엇이 될지 모른다는 기대 반 걱정 반."));return n;}
        private static Nickname N(string id,string title,string reason)=>new Nickname(id,title,reason);
    }
}
