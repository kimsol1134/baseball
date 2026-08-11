using System;
using System.Collections.Generic;

namespace Baseball.Core.HighSchool
{
    public static class RelationshipVoiceCatalog
    {
        public enum TrustBand { Low, Mid, High }
        public enum SpeakerKind { Coach, Catcher, Rival, Named }
        public sealed class Speaker { private Speaker(SpeakerKind kind,string name){Kind=kind;Name=name;}public SpeakerKind Kind{get;}public string Name{get;}public static Speaker Coach{get;}=new Speaker(SpeakerKind.Coach,null);public static Speaker Catcher{get;}=new Speaker(SpeakerKind.Catcher,null);public static Speaker Rival{get;}=new Speaker(SpeakerKind.Rival,null);public static Speaker Named(string name)=>new Speaker(SpeakerKind.Named,name); }
        public sealed class Choice { public Choice(RelationshipResponse response,string title,string detail){Response=response;Title=title;Detail=detail;}public RelationshipResponse Response{get;}public string Title{get;}public string Detail{get;} }
        public sealed class Scene { public Scene(Speaker speaker,string low,string mid,string high,IReadOnlyList<Choice> choices){Speaker=speaker;Quotes=new Dictionary<TrustBand,string>{{TrustBand.Low,low},{TrustBand.Mid,mid},{TrustBand.High,high}};Choices=choices;}public Speaker Speaker{get;}public IReadOnlyDictionary<TrustBand,string> Quotes{get;}public IReadOnlyList<Choice> Choices{get;}public string Quote(TrustBand band){string value;return Quotes.TryGetValue(band,out value)?value:Quotes[TrustBand.Mid];} }
        public static TrustBand BandOf(int trust)=>trust>=65?TrustBand.High:trust<45?TrustBand.Low:TrustBand.Mid;
        public static TrustBand TrustBandFor(Speaker speaker,int manager,int catcher,int rival)=>BandOf(speaker.Kind==SpeakerKind.Coach?manager:speaker.Kind==SpeakerKind.Catcher?catcher:speaker.Kind==SpeakerKind.Rival?rival:(manager+catcher+rival)/3);

        public static readonly IReadOnlyDictionary<string,Scene> Scenes=new Dictionary<string,Scene> {
            {"evt-coach-role",S(Speaker.Coach,"“선발은 아직 이르다. 불펜부터 시작해. …이유를 따질 시간에 공이나 더 던져 봐.”","“다음 대회는 불펜에서 시작한다. 경기 후반을 맡아 줘.”","“{player}. 이번엔 네가 경기 후반을 닫아 줘. 마지막 이닝은 아무한테나 안 맡긴다.”",CoachChoices())},
            {"evt-coach-bench",S(Speaker.Coach,"“오늘은 뺀다. 몸 상태를 나한테 숨기는 선수는 더 오래 못 믿어.”","“이번 등판은 쉰다. 요즘은 팔이 몸보다 늦게 따라온다.”","“하루 쉬자. {player}가 무리하는 걸 알면서 내보내면, 그건 내 잘못이 되니까.”",CoachChoices())},
            {"evt-coach-last-advice",S(Speaker.Coach,"“마지막 훈련이다. …아직도 내가 정해 줘야 하나.”","“마지막 훈련은 네가 정해라. 지금 가장 부족한 게 뭐지?”","“마지막 훈련은 {player} 너한테 맡긴다. 이제 네 판단을 믿어 볼 때도 됐지.”",CoachChoices())},
            {"evt-catcher-sign",S(Speaker.Catcher,"“또 사인이 세 번 바뀌었어. …이럴 거면 왜 나랑 배터리를 맞춰?”","“오늘 사인이 세 번이나 바뀌었어. 내가 놓친 게 뭐였어?”","“세 번 바꾼 거, 오늘은 다 맞았어. {player} 공은 이제 내가 제일 잘 알아.”",CatcherChoices())},
            {"evt-battery-dinner",S(Speaker.Catcher,"“네 변화구, 솔직히 나도 못 받겠어. 이건 배터리가 아니라 각자 야구잖아.”","“솔직히 네 변화구가 어디로 올지 몰라서 겁날 때가 있어.”","“이제 {player} 변화구는 눈 감고도 받아. 손 떠나는 순간 어디 떨어질지 보이거든.”",CatcherChoices())},
            {"evt-catcher-doubt",S(Speaker.Catcher,"“사인을 그렇게 거절할 거면 마운드에서 혼자 다 정해.”","“요즘 내 사인을 자꾸 거절하잖아. 내가 못 본 게 있어?”","“요즘 {player}가 고개 젓는 공이 더 좋더라. 네가 보는 걸 나도 보고 싶어.”",CatcherChoices())},
            {"evt-new-catcher",S(Speaker.Catcher,"“전 학교에서는 이 사인을 썼어. …어차피 네가 다 정할 거면 아무거나 해도 되고.”","“전 학교에서는 이 사인을 썼어. 우리도 다음 경기부터 바꿔 볼래?”","“전 학교 사인이 손에 더 붙어. 근데 {player}가 편한 쪽으로 가자.”",CatcherChoices())},
            {"evt-rival-video",S(Speaker.Rival,"“네 높은 포심, 이제 안 무서워.” 헛스윙 하나 없는 타격 영상만 툭 보내왔다.","“높은 포심 타이밍, 이제 맞췄어.” 짧은 타격 영상이 함께 도착했다.","“{player}. 높은 포심, 드디어 맞췄어. …근데 이거 하나 맞추는 데 3년 걸렸다.”",RivalChoices())},
            {"evt-rival-final",S(Speaker.Rival,"타석에 선 그가 웃는다. “어차피 거기로 올 거잖아. 다 알아.”","타석에 들어선 그가 같은 코스를 가리킨다. “또 여기로 던져 봐.”","“{player}. 마지막이네. 네 제일 좋은 공으로 와. 그래야 이겨도 져도 남지.”",RivalChoices())},
            {"evt-rival-message",S(Speaker.Rival,"“어차피 또 같은 초구겠지. …너 그거밖에 없잖아.”","“다음에도 같은 초구를 던질 거야?”","“{player} 다음 초구, 뭐 던질지 맞혀 볼까. …아니다, 그건 직접 보는 게 낫지.”",RivalChoices())},
            {"evt-arm-care",S(Speaker.Named("트레이너"),"“팔이 무거워 보이는데. …말해 줘도 어차피 던질 거지?”","“최근 등판 뒤로 공을 놓는 팔이 무거워 보여. 오늘은 어떻게 할까?”","“{player}, 팔이 무거워. 참는 편인 거 아니까 내가 먼저 말한다.”",new[]{C(RelationshipResponse.Challenge,"참고 던진다","능력은 지키지만 부상 위험이 오른다"),C(RelationshipResponse.Listen,"짧은 휴식","이번엔 팔을 쉬어 피로와 위험을 크게 던다"),C(RelationshipResponse.Explain,"정밀 검진","상태를 정확히 확인하고 위험을 없앤다")})},
            {"evt-fan-letter",FixedNamed("팬","“{player} 선수님이 던지는 그 느린 공이 제일 좋아요. 다음 경기에도 꼭 던져 주세요!”")},
            {"evt-parent-call",FixedNamed("부모님","“드래프트 끝나고도 계속할 거지? …대답은 천천히 해도 돼. 밥은 챙겨 먹고 다니니.”")},
            {"evt-exam-week",FixedNamed("담임 선생님","“시험이랑 원정이 겹쳤지. 공만큼 책도 며칠은 잡아야 한다. 야구는 안 도망가.”")},
            {"evt-loss-interview",FixedNamed("기자","“마지막 타자에게 그 공을 고른 이유가 있었나요?” 녹음기가 아직 돌아가고 있다.")},
            {"evt-national-stage",FixedNamed("중계 PD","“오늘 불펜부터 그림 좀 담을게. 평소대로 던져.”")},
            {"evt-captain-talk",FixedNamed("주장","“다음 경기, 긴 이닝 맡아 줄 수 있어? 무리면 무리라고 말해.”")},
            {"evt-school-record",FixedNamed("후배","“선배, 다음 경기에서 여섯 개만 더 잡으면 학교 기록이래요.”")},
            {"evt-scout-question",FixedNamed("스카우트","“지난달 무너진 경기 다음에, 뭘 바꿨지?”")},
            {"evt-velocity-drop",FixedNamed("트레이너","“두 경기째 구속이 2km/h 빠졌어. 숫자는 거짓말을 안 해.”")},
            {"evt-deja-vu-mound",FixedNamed("나","처음 오르는 마운드다. 그런데 발끝이 흙을 파는 각도까지 이미 몸이 알고 있다.")},
            {"evt-known-coach",FixedNamed("나","감독의 말버릇이 낯익다. 다음에 무슨 말을 할지 알 것 같은데, 만난 적은 없다.")},
            {"evt-body-remembers",FixedNamed("나","배운 적 없는 그립이 손에 저절로 잡힌다. 던져 보니 정말로 휜다.")},
            {"evt-rival-deja-vu",S(Speaker.Rival,"타석에 선 그가 오래 본다. “우리… 어디서 붙은 적 있나?”","타석에 선 그가 오래 본다. “우리… 어디서 붙은 적 있나?”","타석에 선 그가 오래 본다. “우리… 어디서 붙은 적 있나?”",RivalChoices())},
            {"evt-memory-ache",FixedNamed("나","지난번에 팔이 나갔던 바로 그 주차다. 아프지 않은데 그 자리가 계속 신경 쓰인다.")},
            {"evt-second-summer",FixedNamed("나","같은 계절, 같은 대회. 이번에는 무엇이 오는지 알고 서 있다.")},
            {"evt-bullpen-rival",FixedNamed("경쟁하는 동료","“네 새 변화구 그립… 한 번만 보여줄래? 선발 자리는 서로 뺏는 사이지만, 그래도 배우고 싶어서.”")}
        };
        private static readonly IReadOnlyDictionary<string,Scene> CategoryScenes=new Dictionary<string,Scene>{{"rebirth",Category("나")},{"growth",Category("훈련 파트너")},{"health",Category("트레이너")},{"team",Category("주장")},{"draft",Category("스카우트")},{"media",Category("취재진")},{"fan",Category("팬")},{"game",CategorySpeaker(Speaker.Catcher)},{"awakening",CategorySpeaker(Speaker.Catcher)},{"life",Category("가족")},{"legacy",Category("지난 기록")}};
        public static Scene GetScene(string eventId,string category){Scene scene;if(Scenes.TryGetValue(eventId,out scene))return scene;if(CategoryScenes.TryGetValue(category,out scene))return scene;if(category=="coach")return Scenes["evt-coach-role"];if(category=="catcher")return Scenes["evt-catcher-sign"];if(category=="rival")return Scenes["evt-rival-message"];return null;}
        public static string Aftermath(Speaker speaker,string name,RelationshipResponse response,int trustChange){var who=speaker.Kind==SpeakerKind.Coach?(name==null?"감독":name+" 감독"):speaker.Kind==SpeakerKind.Catcher?(name==null?"포수":name+" 포수"):speaker.Kind==SpeakerKind.Rival?(name??"상대"):speaker.Name;if(trustChange<=-5)return response==RelationshipResponse.Listen?who+Particle(who,"은","는")+" 더 말하지 않았다. 듣기만 한 것이 이번에는 답이 아니었다.":response==RelationshipResponse.Explain?"설명은 끝까지 했지만 "+who+"의 표정은 달라지지 않았다.":who+Particle(who,"이","가")+" 짧게 고개를 저었다. 지금은 그 말을 받을 자리가 아니었다.";if(trustChange<0)return who+Particle(who,"은","는")+" 알겠다고만 했다. 남는 것이 없는 대화였다.";if(trustChange>=7)return response==RelationshipResponse.Listen?who+Particle(who,"이","가")+" 하려던 말을 다 했다. 끝까지 들은 것이 오늘의 답이었다.":response==RelationshipResponse.Explain?who+Particle(who,"이","가")+" 고개를 끄덕였다. 근거가 있는 말은 대체로 통한다.":who+Particle(who,"이","가")+" 웃었다. “그럼 보여 줘.” 다음 공에 걸린 것이 하나 늘었다.";return who+Particle(who,"과","와")+"의 대화는 조용히 마무리됐다. 서로 한 걸음씩은 알게 됐다.";}
        public static string Particle(string word,string withFinal,string withoutFinal){for(var i=word.Length-1;i>=0;i--){var c=word[i];if(c>=0xAC00&&c<=0xD7A3)return (c-0xAC00)%28==0?withoutFinal:withFinal;}return withoutFinal;}
        private static Scene FixedNamed(string name,string quote)=>S(Speaker.Named(name),quote,quote,quote,GenericChoices());
        private static Scene Category(string name)=>S(Speaker.Named(name),"","","",GenericChoices());
        private static Scene CategorySpeaker(Speaker speaker)=>S(speaker,"","","",GenericChoices());
        private static Scene S(Speaker speaker,string low,string mid,string high,IReadOnlyList<Choice> choices)=>new Scene(speaker,low,mid,high,choices);
        private static Choice C(RelationshipResponse response,string title,string detail)=>new Choice(response,title,detail);
        private static Choice[] CoachChoices()=>new[]{C(RelationshipResponse.Listen,"감독의 말을 먼저 듣는다","감독이 본 문제를 확인한다"),C(RelationshipResponse.Explain,"최근 기록을 꺼내 보인다","내 생각을 설명한다"),C(RelationshipResponse.Challenge,"다음 등판으로 증명한다","결과로 답한다")};
        private static Choice[] CatcherChoices()=>new[]{C(RelationshipResponse.Listen,"포수가 본 반응부터 묻는다","내가 못 본 장면을 확인한다"),C(RelationshipResponse.Explain,"사인을 바꾼 이유를 설명한다","내가 본 타자 반응을 말한다"),C(RelationshipResponse.Challenge,"다음 경기에서 시험한다","두 사람의 생각을 직접 맞춰 본다")};
        private static Choice[] RivalChoices()=>new[]{C(RelationshipResponse.Listen,"무엇을 읽었는지 묻는다","상대의 답을 듣는다"),C(RelationshipResponse.Explain,"그 공으로 노린 것을 말한다","판단을 숨기지 않는다"),C(RelationshipResponse.Challenge,"다음 공으로 답한다","재대결을 약속한다")};
        private static Choice[] GenericChoices()=>new[]{C(RelationshipResponse.Listen,"먼저 듣는다","떠오르는 것을 밀어내지 않는다"),C(RelationshipResponse.Explain,"설명한다","내 생각을 전한다"),C(RelationshipResponse.Challenge,"결과로 답한다","직접 시험한다")};
    }
}
