using System.Collections.Generic;
using Baseball.Core.Pitching;

namespace Baseball.Core.HighSchool
{
    public sealed class CareerEventContent
    {
        public CareerEventContent(string id, string title, string category, string summary) { Id=id;Title=title;Category=category;Summary=summary; }
        public string Id{get;} public string Title{get;} public string Category{get;} public string Summary{get;}
    }

    public sealed class ImportantGameScenarioContent
    {
        public ImportantGameScenarioContent(string id, string title, int inning, int outs, BaserunnerStateSnapshot runners, int leverage, string narrative, int? scoreDifferential = null, int minChapter = 1)
        { Id=id;Title=title;Inning=inning;Outs=outs;Runners=runners;Leverage=leverage;Narrative=narrative;ScoreDifferential=scoreDifferential;MinChapter=minChapter; }
        public string Id{get;} public string Title{get;} public int Inning{get;} public int Outs{get;} public BaserunnerStateSnapshot Runners{get;} public int Leverage{get;} public string Narrative{get;} public int? ScoreDifferential{get;} public int MinChapter{get;}
    }

    public static class HighSchoolContentCatalog
    {
        public static readonly IReadOnlyList<CareerEventContent> Events = new[] {
            E("evt-bullpen-first","첫 불펜","growth","고교 포수가 공을 받아 본 뒤 각 구종을 언제 쓰고 싶은지 묻습니다."),
            E("evt-coach-role","선발인가 불펜인가","coach","감독이 다음 대회는 불펜에서 시작하겠다고 말합니다."),
            E("evt-catcher-sign","엇갈린 사인","catcher","경기 중 세 번 사인이 엇갈렸고 포수가 이유를 묻습니다."),
            E("evt-rival-video","라이벌의 영상","rival","라이벌이 당신의 포심 타이밍을 정확히 맞히는 영상이 도착했습니다."),
            E("evt-winter-weight","겨울의 몸","growth","웨이트 코치가 근력을 늘릴지 몸의 유연성을 지킬지 선택하라고 합니다."),
            E("evt-command-wall","제구의 벽","growth","불펜에서는 들어가던 공이 경기만 시작하면 한 뼘씩 벗어납니다."),
            E("evt-breaker-grip","새 그립","growth","더 크게 휘지만 제구가 어려운 새 변화구 그립을 시험합니다."),
            E("evt-recovery-day","쉬는 날의 불안","health","회복 코치가 오늘은 공을 잡지 말라고 하지만 옆 불펜에서는 경쟁자가 던지고 있습니다."),
            E("evt-captain-talk","주장의 질문","team","주장이 다음 경기에서 긴 이닝을 맡아 줄 수 있느냐고 묻습니다."),
            E("evt-scout-stand","백스톱 뒤의 스카우트","draft","불펜 뒤에 선 스카우트 둘이 매 공의 구속을 적기 시작합니다."),
            E("evt-loss-interview","패배 뒤 인터뷰","media","기자가 마지막 타자에게 던진 공을 왜 골랐는지 묻습니다."),
            E("evt-fan-letter","첫 팬레터","fan","어린 팬이 가장 좋아하는 구종을 다음 경기에서도 던져 달라고 썼습니다."),
            E("evt-battery-dinner","배터리의 저녁","catcher","포수가 밥을 먹다 말고 가장 받기 두려운 공이 무엇인지 털어놓습니다."),
            E("evt-coach-bench","감독의 벤치","coach","감독이 다음 등판을 쉬게 한 이유를 설명합니다."),
            E("evt-rival-message","라이벌의 메시지","rival","라이벌이 ‘다음에도 같은 초구를 던질 거냐’고 메시지를 보냈습니다."),
            E("evt-mechanics-camera","카메라에 찍힌 투구 동작","growth","고속 카메라에 평소보다 손에서 공이 일찍 빠지는 장면이 찍혔습니다."),
            E("evt-velocity-drop","2km/h의 하락","health","두 경기 연속 최고 구속이 2km/h 낮게 찍혔습니다."),
            E("evt-new-catcher","새 포수","catcher","새 포수가 기존 사인 대신 자신이 쓰던 손짓을 제안합니다."),
            E("evt-school-record","학교 기록","fan","다음 경기에서 탈삼진 6개를 더 잡으면 학교 기록이 바뀝니다."),
            E("evt-rain-delay","비가 멈춘 뒤","game","두 시간 동안 멈췄던 경기가 갑자기 15분 뒤 재개됩니다."),
            E("evt-loaded-bases","만루의 기억","game","지난 경기 만루에서 던진 초구가 영상실 화면에 다시 나옵니다."),
            E("evt-first-awakening","몸이 먼저 아는 것","awakening","최근 훈련에서 반복한 동작이 경기에서도 자연스럽게 나옵니다."),
            E("evt-team-slump","팀의 연패","team","세 경기 연속 패배 뒤 선수들이 자율 훈련 시간을 두고 다툽니다."),
            E("evt-bullpen-rival","같은 팀의 경쟁자","team","선발 자리를 다투는 동료가 새 변화구 그립을 보여 달라고 합니다."),
            E("evt-scout-question","스카우트의 한 질문","draft","스카우트가 최근 무너진 경기 뒤 무엇을 바꿨는지 묻습니다."),
            E("evt-parent-call","집에서 온 전화","life","부모님이 드래프트 뒤에도 야구를 계속할 생각인지 묻습니다."),
            E("evt-exam-week","시험 주간","life","시험과 원정 경기가 겹쳐 이번 주 훈련 시간이 절반으로 줄었습니다."),
            E("evt-injury-rumor","통증 소문","health","어깨를 주무르는 모습을 본 동료가 코치에게 말해야 하지 않느냐고 묻습니다."),
            E("evt-national-stage","전국 중계","media","경기 전 불펜부터 중계 카메라가 계속 따라붙습니다."),
            E("evt-catcher-doubt","포수의 의심","catcher","포수가 최근 자신의 사인을 자주 거절하는 이유를 묻습니다."),
            E("evt-coach-last-advice","감독의 마지막 조언","coach","감독이 드래프트 전 마지막 훈련 하나를 직접 고르라고 합니다."),
            E("evt-rival-final","마지막 재대결","rival","라이벌이 타석에 들어서며 지난 경기와 같은 코스를 가리킵니다."),
            E("evt-draft-projection","예상 순위","draft","언론 예상 순위와 학교가 들은 구단 평가가 두 라운드나 차이 납니다."),
            E("evt-undrafted-room","이름이 불리지 않은 방","legacy","마지막 라운드가 끝난 뒤 세 해의 기록을 다시 펼칩니다."),
            E("evt-drafted-call","구단의 전화","draft","지명 구단 담당자가 전화를 걸어 입단 뒤 첫 시즌 훈련 계획을 설명합니다."),
            E("evt-scorebook-close","마지막 스코어북","legacy","세 해 동안 가장 좋았던 경기와 가장 힘들었던 경기에 표시를 남깁니다.")
        };

        public static readonly IReadOnlyList<CareerEventContent> RebirthEvents = new[] {
            E("evt-deja-vu-mound","처음 밟는데 익숙한 마운드","rebirth","처음 오르는 마운드인데 흙의 단단함과 발끝의 각도가 이미 알던 것 같습니다."),
            E("evt-known-coach","낯익은 감독","rebirth","감독의 말버릇과 손짓이 어디선가 본 것 같습니다. 만난 적은 없습니다."),
            E("evt-body-remembers","몸이 먼저 아는 그립","rebirth","배운 적 없는 그립이 손에 저절로 잡힙니다. 던져 보니 실제로 휩니다."),
            E("evt-rival-deja-vu","라이벌의 기시감","rebirth","라이벌이 타석에서 당신을 오래 봅니다. “우리 어디서 붙은 적 있나?”"),
            E("evt-memory-ache","기억의 통증","rebirth","지난번에 팔을 다쳤던 그 주차입니다. 아프지 않은데 그 자리가 신경 쓰입니다."),
            E("evt-second-summer","다시 맞는 3학년 여름","rebirth","같은 계절, 같은 대회. 이번에는 결과를 알고 시작합니다."),
            E("evt-remembered-pitch","그 코스의 사인","rebirth","지난 삶에서 홈런을 맞았던 바로 그 코스에 사인이 나옵니다. 포수는 아무것도 모릅니다."),
            E("evt-lost-teammate","그만둔 동료","rebirth","지난 삶에서 끝까지 함께 던졌던 동료가, 이번 삶에서는 야구를 그만뒀다는 소식을 듣습니다."),
            E("evt-future-news","결말을 아는 뉴스","rebirth","라디오가 올해의 우승 후보를 읊습니다. 지난 삶과 한 글자도 다르지 않아, 결말을 아는 책 같습니다."),
            E("evt-old-nickname","지난 삶의 별명","rebirth","처음 만난 상대 포수가 당신을 지난 삶의 별명으로 부릅니다. 이번 삶에는 아직 없는 이름입니다."),
            E("evt-glove-worn","길들여진 새 글러브","rebirth","새 글러브인데 지난 삶에서 길들인 자리부터 부드럽습니다. 손이 먼저 접던 각도로 접힙니다."),
            E("evt-undrafted-deja","그 방의 기시감","rebirth","드래프트 중계를 트는 순간, 이름이 불리지 않은 채 끝났던 그 방의 공기가 먼저 돌아옵니다.")
        };

        public static readonly IReadOnlyList<ImportantGameScenarioContent> Scenarios = new[] {
            S("game-debut","고교 데뷔",3,0,false,false,false,55,350,"첫 공식 등판. 한 점 뒤진 채 받은 기회지만, 상대 타자도 아직 내 공을 본 적이 없습니다.",-1),
            S("game-runner-first","1사 1루",5,1,true,false,false,64,610,"빠른 주자가 1루에서 리드를 길게 잡고 있습니다.",1),
            S("game-rival-rematch","라이벌 재대결",6,1,false,true,false,61,760,"동점 6회, 지난 경기의 구종 순서를 기억하는 중심타자가 들어섭니다.",0),
            S("game-corners","1사 1·3루",7,1,true,false,true,67,900,"땅볼 하나면 병살이지만 외야로 뜨면 동점입니다.",1),
            S("game-loaded","무사 만루",4,0,true,true,true,60,950,"볼넷을 피하면서 약한 타구가 필요한 상황",2),
            S("game-two-outs","2사 2루",8,2,false,true,false,65,880,"한 타자에 이닝이 걸린 승부",1),
            S("game-fatigue","피로한 7회",7,0,true,false,false,59,720,"직구가 느려진 7회, 어떤 공으로 버틸지 정해야 합니다.",1),
            S("game-scout","스카우트 관전",5,1,false,false,false,55,690,"팀은 한 점 뒤져 있지만, 스카우트는 점수가 아니라 같은 코스를 반복하는지 지켜봅니다.",-1),
            S("game-rain","우천 중단 뒤",6,0,false,false,false,55,540,"두 시간 동안 경기가 멈춰 몸이 식은 뒤 만나는 첫 타자입니다.",0),
            S("game-one-run","한 점 차",9,0,false,true,false,68,980,"드래프트 전 마지막 고교 이닝",1,7),
            S("game-new-catcher","새 포수와 첫 경기",4,1,true,false,false,62,570,"새 포수와 아직 구종 사인을 충분히 맞추지 못했습니다.",1),
            S("game-national-final","전국 결승",8,2,true,true,false,66,1000,"2사 1·2루. 마지막 아웃 하나에 우승이 걸렸습니다.",1,4),
            S("game-walkoff-defense","9회말 리드 방어",9,1,false,true,true,63,985,"한 점 앞선 9회말 1사 2·3루. 외야로 뜨기만 해도 동점, 안타면 경기가 끝납니다.",1),
            S("game-extra-tiebreak","연장 승부치기",10,0,true,true,false,67,940,"연장 승부치기. 무사 1·2루에서 시작합니다. 아웃부터 잡지 못하면 큰 이닝이 됩니다.",0),
            S("game-ace-duel","0-0 투수전",8,0,false,false,false,55,810,"8회까지 0의 행진. 상대 에이스도 지지 않습니다. 먼저 실수하는 쪽이 집니다.",0),
            S("game-damage-control","실점 뒤 수습",6,1,true,true,true,58,875,"이 이닝에만 석 점을 내줘 동점이 됐습니다. 다시 만루. 여기서 더 내주면 경기가 넘어갑니다.",0),
            S("game-rain-grip","빗속의 공",2,0,true,false,false,60,470,"빗물을 머금은 공이 손끝에서 자꾸 미끄러집니다. 노린 코스보다 한 뼘씩 벗어납니다.",0),
            S("game-doubleheader","더블헤더 2차전",4,2,false,true,false,64,640,"오늘 두 번째 경기. 한 점 뒤진 채, 낮 경기에서 이미 던진 팔이 무겁게 남아 있습니다.",-1),
            S("game-scout-showcase","스카우트 총출동",7,2,false,false,false,55,960,"팀은 두 점 뒤졌지만 관중석 첫 줄은 스카우트로 가득합니다. 공 하나하나가 순위표에 적힙니다.",-2),
            S("game-rival-away","라이벌 원정",6,2,true,false,false,61,830,"라이벌 학교 원정, 한 점 뒤진 6회. 마운드에 설 때마다 스탠드가 야유로 덮습니다. 소리를 지워야 공이 보입니다.",-1),
            S("game-cold-spring","이른 봄의 손끝",2,0,false,false,false,55,420,"3월의 첫 대회. 입김이 보이는 추위에 공이 돌덩이처럼 미끄럽고, 손끝의 감각이 절반만 돌아와 있습니다.",0),
            S("game-fireman","떠안은 주자",6,0,false,true,true,66,930,"앞선 투수가 남긴 무사 2·3루를 떠안고 오릅니다. 여기서 들어오는 점수는 내 기록이 아니지만, 경기는 내 손에 있습니다.",-1),
            S("game-mercy-watch","다섯 점의 함정",5,0,true,false,false,57,380,"다섯 점 리드. 긴장이 풀리는 딱 그 지점에서 실점이 시작됩니다. 스카우트는 큰 리드에서의 집중력을 봅니다.",5),
            S("game-nightfall","일몰 직전",7,1,false,true,false,62,700,"조명 없는 구장, 해가 산 뒤로 넘어가고 있습니다. 심판이 이 이닝이 오늘의 마지막이라고 알렸습니다. 동점이면 내일 처음부터 다시입니다.",0),
            S("game-heatwave","한여름 낮 경기",6,0,true,false,false,60,660,"35도의 낮 경기. 유니폼이 몸에 감기고 로진백도 눅눅합니다. 한 점 리드가 이 더위 속에서 여덟 아웃만큼 멀어 보입니다.",1,2),
            S("game-third-look","세 번째 만나는 4번",6,2,false,true,false,63,850,"오늘 세 번째로 만나는 상대 4번 타자. 앞선 두 타석의 공을 전부 기억하고 있을 겁니다. 같은 순서는 이제 통하지 않습니다.",-1),
            S("game-perfect-bid","5회까지 완전",6,1,false,false,false,55,780,"5회까지 한 명도 내보내지 않았습니다. 더그아웃이 조용해졌습니다 — 아무도 그 단어를 입에 올리지 않습니다.",3,4),
            S("game-backup-catcher","백업 포수와의 승부",7,1,true,false,false,61,740,"주전 포수가 파울 타구에 손가락을 맞아 교체됐습니다. 백업 포수와는 불펜 한 번 맞춰 본 게 전부입니다.",0),
            S("game-seniors-last","선배들의 마지막",8,1,true,true,false,64,890,"두 점 뒤진 8회. 지면 3학년 선배들의 고교 야구가 오늘로 끝납니다. 더그아웃의 눈이 전부 마운드를 보고 있습니다.",-2,2),
            S("game-sign-leak","새는 사인",5,0,false,true,false,65,720,"상대 2루 주자가 타자에게 무언가를 전달하는 정황. 사인이 읽히고 있다면, 이제부터는 코스보다 배짱의 승부입니다.",-1)
        };

        private static CareerEventContent E(string id,string title,string category,string summary) => new CareerEventContent(id,title,category,summary);
        private static ImportantGameScenarioContent S(string id,string title,int inning,int outs,bool first,bool second,bool third,int speed,int leverage,string narrative,int score,int minChapter=1) => new ImportantGameScenarioContent(id,title,inning,outs,new BaserunnerStateSnapshot(first,second,third,speed),leverage,narrative,score,minChapter);
    }
}
