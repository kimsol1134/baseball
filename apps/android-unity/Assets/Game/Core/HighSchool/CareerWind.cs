using System;
using System.Collections.Generic;
using Baseball.Core.Domain;
using Baseball.Core.Random;

namespace Baseball.Core.HighSchool
{
    public enum CareerRulesVersion { V1=1, V2=2 }
    public sealed class CareerWindRules
    {
        public CareerWindRules(TrainingFocus? favoredTraining=null,int favoredTrainingBonus=0,int trainingFatigueDelta=0,TrainingFocus? extraFatigueFocus=null,int extraFatigueDelta=0,int recoveryBonus=0,RelationshipTarget? favoredRelationship=null,int favoredRelationshipBonus=0,int relationshipLossPenalty=0,int fanInterestGainBonus=0,int draftEvaluationDelta=0)
        { FavoredTraining=favoredTraining;FavoredTrainingBonus=favoredTrainingBonus;TrainingFatigueDelta=trainingFatigueDelta;ExtraFatigueFocus=extraFatigueFocus;ExtraFatigueDelta=extraFatigueDelta;RecoveryBonus=recoveryBonus;FavoredRelationship=favoredRelationship;FavoredRelationshipBonus=favoredRelationshipBonus;RelationshipLossPenalty=relationshipLossPenalty;FanInterestGainBonus=fanInterestGainBonus;DraftEvaluationDelta=draftEvaluationDelta; }
        public TrainingFocus? FavoredTraining{get;} public int FavoredTrainingBonus{get;} public int TrainingFatigueDelta{get;} public TrainingFocus? ExtraFatigueFocus{get;} public int ExtraFatigueDelta{get;} public int RecoveryBonus{get;} public RelationshipTarget? FavoredRelationship{get;} public int FavoredRelationshipBonus{get;} public int RelationshipLossPenalty{get;} public int FanInterestGainBonus{get;} public int DraftEvaluationDelta{get;}
        public int TrainingGrowthBonus(TrainingFocus focus)=>focus==FavoredTraining?FavoredTrainingBonus:0;
        public int TrainingFatigueModifier(TrainingFocus focus)=>TrainingFatigueDelta+(focus==ExtraFatigueFocus?ExtraFatigueDelta:0);
        public int AdjustedRecovery(int value)=>value+RecoveryBonus;
        public int AdjustedRelationshipTrustChange(int value,RelationshipTarget target)=>value+(target==FavoredRelationship?FavoredRelationshipBonus:0)-(value<0?RelationshipLossPenalty:0);
        public int AdjustedFanInterestChange(int value)=>value>0?value+FanInterestGainBonus:value;
        public int AdjustedDraftEvaluation(int value)=>value+DraftEvaluationDelta;
        public static CareerWindRules Neutral{get;}=new CareerWindRules();
    }
    public sealed class CareerWind
    {
        private CareerWind(string id,string title,string detail,CareerRulesVersion rulesVersion,int rivalBonus,int startingFanInterest,int rewardBonusPermille,CareerWindRules rules)
        {Id=id;Title=title;Detail=detail;RulesVersion=rulesVersion;RivalBonus=rivalBonus;StartingFanInterest=startingFanInterest;RewardBonusPermille=rewardBonusPermille;Rules=rules;}
        public string Id{get;} public string Title{get;} public string Detail{get;} public CareerRulesVersion RulesVersion{get;} public int RivalBonus{get;} public int StartingFanInterest{get;} public int RewardBonusPermille{get;} public CareerWindRules Rules{get;}
        public string NewsLine=>Id=="calm"?null:"이번 3년의 바람 — "+Title+". "+Detail;
        public IReadOnlyList<string> EffectDescriptions { get { var r=new List<string>(); if(Rules.FavoredTraining.HasValue&&Rules.FavoredTrainingBonus!=0)r.Add(FocusLabel(Rules.FavoredTraining.Value)+" 훈련 성장 "+Signed(Rules.FavoredTrainingBonus)); if(Rules.RecoveryBonus!=0)r.Add("회복 효과 "+Signed(Rules.RecoveryBonus)); if(Rules.FavoredRelationship.HasValue&&Rules.FavoredRelationshipBonus!=0)r.Add(TargetLabel(Rules.FavoredRelationship.Value)+" 믿음 변화 "+Signed(Rules.FavoredRelationshipBonus)); if(Rules.FanInterestGainBonus!=0)r.Add("팬 관심 획득 "+Signed(Rules.FanInterestGainBonus)); if(Rules.DraftEvaluationDelta!=0)r.Add("드래프트 평가 "+Signed(Rules.DraftEvaluationDelta)); if(StartingFanInterest!=5)r.Add("시작 팬 관심 "+StartingFanInterest); if(RivalBonus!=0)r.Add("숙적 능력 "+Signed(RivalBonus)); if(Rules.TrainingFatigueDelta!=0)r.Add("모든 훈련 피로 "+Signed(Rules.TrainingFatigueDelta)); if(Rules.ExtraFatigueFocus.HasValue&&Rules.ExtraFatigueDelta!=0)r.Add(FocusLabel(Rules.ExtraFatigueFocus.Value)+" 훈련 피로 "+Signed(Rules.ExtraFatigueDelta)); if(Rules.RelationshipLossPenalty!=0)r.Add("대화 실패 때 믿음 손실 +"+Rules.RelationshipLossPenalty); if(RewardBonusPermille!=0)r.Add("야구혼 보정 "+Signed(RewardBonusPermille/10)+"%"); return r; } }
        public static readonly IReadOnlyList<CareerWind> All=new[]{W("calm","바람 없는 해","특별할 것 없는 평범한 해입니다. 실력만이 말합니다.",CareerRulesVersion.V1,0,5,0),W("calm","바람 없는 해","특별할 것 없는 평범한 해입니다. 실력만이 말합니다.",CareerRulesVersion.V1,0,5,0),W("monster_generation","괴물 세대","전국에 물건들이 쏟아진 해입니다. 라이벌은 세지만, 이런 해를 버틴 야구혼은 진합니다.",CareerRulesVersion.V1,5,5,150),W("scout_frenzy","스카우트 풍년","구단들이 일찍부터 움직이는 해입니다. 시선이 처음부터 따라붙습니다.",CareerRulesVersion.V1,0,20,0),W("quiet_season","무명의 해","아무도 이 지역을 주목하지 않는 해입니다. 조용히 강해질 시간입니다.",CareerRulesVersion.V1,-3,0,80)};
        public static readonly IReadOnlyList<CareerWind> V2All=new[]{
            W("calm","바람 없는 해","특별할 것 없는 평범한 해입니다. 실력만이 말합니다.",CareerRulesVersion.V2,0,5,0),
            W("monster_generation","괴물 세대","강한 숙적과 맞서는 만큼 좋은 경기에는 더 많은 시선이 모입니다.",CareerRulesVersion.V2,5,5,150,new CareerWindRules(fanInterestGainBonus:3)),
            W("scout_frenzy","스카우트 풍년","일찍 모인 시선이 시즌 내내 따라붙습니다.",CareerRulesVersion.V2,0,10,0),
            W("quiet_season","무명의 해","관심 없이 시작하지만 숙적도 평소보다 덜 완성된 해입니다.",CareerRulesVersion.V2,-3,0,80),
            W("heatwave","긴 여름","훈련의 피로가 더 쌓이는 대신 몸을 돌보는 회복도 더 깊습니다.",CareerRulesVersion.V2,0,5,120,new CareerWindRules(trainingFatigueDelta:2,recoveryBonus:4)),
            W("command_year","코스의 해","제구 감각이 잘 붙지만 강한 공을 만드는 날에는 피로가 더 듭니다.",CareerRulesVersion.V2,0,5,50,new CareerWindRules(TrainingFocus.Command,1,extraFatigueFocus:TrainingFocus.Velocity,extraFatigueDelta:1)),
            W("power_year","강한 공의 해","구위는 빠르게 자라지만 숙적도 강한 승부에 맞춰 올라옵니다.",CareerRulesVersion.V2,3,5,100,new CareerWindRules(TrainingFocus.Velocity,1)),
            W("battery_year","배터리의 해","조용한 출발 대신 포수와 쌓는 믿음이 더 빠르게 깊어집니다.",CareerRulesVersion.V2,0,2,50,new CareerWindRules(favoredRelationship:RelationshipTarget.Catcher,favoredRelationshipBonus:2)),
            W("spotlight_year","조명의 해","좋은 장면은 더 큰 관심을 부르지만 관계에서의 실패도 더 선명하게 남습니다.",CareerRulesVersion.V2,0,5,80,new CareerWindRules(relationshipLossPenalty:2,fanInterestGainBonus:2)),
            W("underdog_year","언더독의 해","관심 없이 강한 숙적을 만나지만 끝까지 증명하면 평가가 따라옵니다.",CareerRulesVersion.V2,2,0,120,new CareerWindRules(draftEvaluationDelta:1))};
        public static CareerWind For(string careerId)=>For(careerId,CareerRulesVersion.V1);
        public static CareerWind For(string careerId,CareerRulesVersion version)
        { if(version==CareerRulesVersion.V1){var rng=new SplitMix64(StableHash.Fnv1A64Value(careerId+"|career_wind"));return All[rng.NextInt(All.Count)];} var bucket=(int)(StableHash.Fnv1A64Value(careerId+"|career_wind_v2")%100); return V2All[bucket<30?0:bucket<38?1:bucket<46?2:bucket<54?3:bucket<62?4:bucket<70?5:bucket<78?6:bucket<86?7:bucket<93?8:9]; }
        private static CareerWind W(string id,string title,string detail,CareerRulesVersion version,int rival,int fans,int reward,CareerWindRules rules=null)=>new CareerWind(id,title,detail,version,rival,fans,reward,rules??CareerWindRules.Neutral);
        private static string Signed(int n)=>n>0?"+"+n:n.ToString();
        private static string FocusLabel(TrainingFocus f){switch(f){case TrainingFocus.Velocity:return "구위";case TrainingFocus.Command:return "제구";case TrainingFocus.BreakingBall:return "변화구";case TrainingFocus.Stamina:return "체력";case TrainingFocus.Recovery:return "회복";default:return "경기 계획";}}
        private static string TargetLabel(RelationshipTarget t)=>t==RelationshipTarget.Coach?"감독":t==RelationshipTarget.Catcher?"포수":"숙적";
    }
}
