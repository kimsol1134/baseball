using System;
using System.Linq;
using Baseball.Core.Domain;

namespace Baseball.Core.HighSchool
{
    public enum CareerGameGrowthReason { SequenceCommand, CleanCommand, StrikeoutStuff, StrikeoutMovement, LongOuting }
    public sealed class CareerGameGrowth
    {
        public CareerGameGrowth(TalentAbility ability,int points,CareerGameGrowthReason reason,string title,string detail,TalentSnapshot resultingTalent,TalentAbility? bloomedAbility=null){Ability=ability;Points=points;Reason=reason;Title=title;Detail=detail;ResultingTalent=resultingTalent;BloomedAbility=bloomedAbility;}
        public TalentAbility Ability{get;}public int Points{get;}public CareerGameGrowthReason Reason{get;}public string Title{get;}public string Detail{get;}public TalentSnapshot ResultingTalent{get;}public TalentAbility? BloomedAbility{get;}
        public string ReasonCode=>"game_growth."+ReasonValue(Reason);
        public static CareerGameGrowth Evaluate(HighSchoolCareerSnapshot state,ImportantInningReport report)
        {
            if(state.Talent==null||(state.BalanceVersion??1)<4||report.ScenarioNumber!=state.Performance.ImportantGamesCompleted+1||report.Pitches<=0||report.RecommendationAccepted<0||report.RecommendationAccepted>report.Pitches)return null;
            TalentAbility ability;CareerGameGrowthReason reason;string evidence;
            if(report.Strikeouts>=2&&report.RunsAllowed<=1&&report.ActualDamage<=report.ExpectedDamage){if(state.Pitcher.Stuff>=state.Pitcher.Movement){ability=TalentAbility.Stuff;reason=CareerGameGrowthReason.StrikeoutStuff;evidence=report.Strikeouts+"탈삼진 · "+report.RunsAllowed+"실점 호투가 가장 강한 구위를 더 날카롭게 만들었습니다.";}else{ability=TalentAbility.Movement;reason=CareerGameGrowthReason.StrikeoutMovement;evidence=report.Strikeouts+"탈삼진 · "+report.RunsAllowed+"실점 호투가 가장 강한 변화구 감각을 더 날카롭게 만들었습니다.";}}
            else if(report.Outs==3&&report.Pitches>=9&&report.RunsAllowed<=1&&report.ActualDamage<=report.ExpectedDamage){ability=TalentAbility.Stamina;reason=CareerGameGrowthReason.LongOuting;evidence="한 이닝의 아웃카운트 3개를 "+report.Pitches+"구 · "+report.RunsAllowed+"실점으로 책임진 호흡이 체력으로 남았습니다.";}
            else if((report.SequenceMasteryCount??0)>=4&&report.Walks==0&&report.ActualDamage<=report.ExpectedDamage){ability=TalentAbility.Command;reason=CareerGameGrowthReason.SequenceCommand;evidence="수싸움 적중 "+(report.SequenceMasteryCount??0)+"회와 무볼넷 투구가 원하는 곳에 던지는 감각으로 이어졌습니다.";}
            else return null;
            var applied=TalentRules.Apply(state.Talent,ability,Rating(ability,state.Pitcher),1);var limit=applied.Allowed==0&&!applied.Bloomed.HasValue?" 재능 한계에 닿아 능력치는 오르지 않았지만 압박이 남았습니다.":"";var bloom=applied.Bloomed.HasValue?" "+AbilityLabel(applied.Bloomed.Value)+" 재능이 "+applied.Talent.Grade(applied.Bloomed.Value)+"로 만개했습니다.":"";var title=applied.Allowed>0?"경기 기반 성장 · "+AbilityLabel(ability)+" +"+applied.Allowed:"경기 기반 성장 · "+AbilityLabel(ability)+" 한계 압박";return new CareerGameGrowth(ability,applied.Allowed,reason,title,evidence+bloom+limit,applied.Talent,applied.Bloomed);
        }
        public PitcherSnapshot Applying(PitcherSnapshot p){if(Points<=0)return p;var profiles=p.PitchProfiles==null?null:p.PitchProfiles.Select(x=>new PitchProfileSnapshot(x.PitchType,x.Role,Bound(x.VelocityTenthsKph+(Ability==TalentAbility.Stuff?Points*5:0),1000,1700),Bound(x.Control+(Ability==TalentAbility.Command?Points:0),20,80),Bound(x.Command+(Ability==TalentAbility.Command?Points:0),20,80),Bound(x.Movement+(Ability==TalentAbility.Movement&&x.PitchType!=PitchType.FourSeam?Points:0),20,80),Bound(x.Whiff+(Ability==TalentAbility.Movement&&x.PitchType!=PitchType.FourSeam?Points:0),20,80),x.WeakContact,Ability==TalentAbility.Stamina?Math.Max(0,x.FatigueCost-Points/2):x.FatigueCost)).ToArray();return new PitcherSnapshot(p.Id,p.Name,Bound(p.Stuff+(Ability==TalentAbility.Stuff?Points:0),20,80),Bound(p.Command+(Ability==TalentAbility.Command?Points:0),20,80),Bound(p.Movement+(Ability==TalentAbility.Movement?Points:0),20,80),Bound(p.Stamina+(Ability==TalentAbility.Stamina?Points:0),20,80),profiles,p.ThrowingHand);}
        private static int Rating(TalentAbility a,PitcherSnapshot p)=>a==TalentAbility.Stuff?p.Stuff:a==TalentAbility.Command?p.Command:a==TalentAbility.Movement?p.Movement:p.Stamina;
        private static int Bound(int x,int l,int h)=>Math.Min(h,Math.Max(l,x));
        private static string AbilityLabel(TalentAbility a)=>a==TalentAbility.Stuff?"구위":a==TalentAbility.Command?"제구":a==TalentAbility.Movement?"변화구":"체력";
        private static string ReasonValue(CareerGameGrowthReason r)=>r==CareerGameGrowthReason.SequenceCommand?"sequence_command":r==CareerGameGrowthReason.CleanCommand?"clean_command":r==CareerGameGrowthReason.StrikeoutStuff?"strikeout_stuff":r==CareerGameGrowthReason.StrikeoutMovement?"strikeout_movement":"long_outing";
    }
}
